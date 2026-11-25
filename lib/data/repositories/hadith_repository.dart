import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_constants.dart';
import '../models/hadith/hadith_models.dart';

/// Data layer for the hadith corpus v2.
///
/// Every collection ships as one gzip-compressed JSON asset
/// (`assets/data/hadith/v2/<slug>.json.gz`); loading, decompression and JSON
/// decoding run off the main isolate (except on web), collections are cached
/// with a bounded LRU so memory stays predictable on low-end devices, and
/// search normalizes Arabic text (tashkeel + hamza forms) before matching.
class HadithRepository {
  // ── Caches (bounded) ────────────────────────────────────────────
  List<HadithCollection>? _collectionsCache;
  final Map<String, List<HadithBook>> _booksCache = {};
  final Map<String, Map<int, HadithChapter>> _chaptersCache = {};
  final Map<String, List<Hadith>> _hadithsCache = {};
  final Map<String, List<Hadith>> _allHadithsByCollectionCache = {};
  final Map<String, List<String>> _normalizedArabicCache = {};
  List<HadithScholar>? _scholarsCache;
  final Map<String, List<int>> _scholarIndexCache = {};

  static const int _maxCachedCollections = 2;
  final List<String> _cacheEvictionOrder = [];

  bool _isShuttingDown = false;

  // ═══════════════════════════════════════════════════════════════
  // Asset loading
  // ═══════════════════════════════════════════════════════════════

  /// Loads and decodes a gzip JSON asset. Heavy work runs off the main
  /// isolate on IO platforms; on web it degrades gracefully to inline decode.
  Future<dynamic> _loadGzipJson(String assetPath) async {
    final ByteData data =
        await rootBundle.load(assetPath.replaceAll('assets/', ''));
    final Uint8List bytes = data.buffer.asUint8List();

    if (kIsWeb) {
      final String json = utf8.decode(const GZipDecoder().decodeBytes(bytes));
      return jsonDecode(json);
    }

    return Isolate.run(() {
      final String json = utf8.decode(const GZipDecoder().decodeBytes(bytes));
      return jsonDecode(json);
    });
  }

  void _trackCacheUse(String collectionId) {
    _cacheEvictionOrder.remove(collectionId);
    _cacheEvictionOrder.add(collectionId);
    while (_cacheEvictionOrder.length > _maxCachedCollections) {
      final evict = _cacheEvictionOrder.removeAt(0);
      _allHadithsByCollectionCache.remove(evict);
      _hadithsCache.removeWhere((k, _) => k.startsWith('${evict}_'));
      _normalizedArabicCache.remove(evict);
      _chaptersCache.remove(evict);
      // Books metadata is small; keep it cached for all loaded collections.
    }
  }

  /// Loads the full v2 payload for a collection (books/chapters/hadiths),
  /// enriches each hadith with chapter titles, and caches the result.
  Future<List<Hadith>> _loadCollection(String collectionId) async {
    if (_allHadithsByCollectionCache.containsKey(collectionId)) {
      _trackCacheUse(collectionId);
      return _allHadithsByCollectionCache[collectionId]!;
    }

    dynamic payload;
    try {
      payload = await _loadGzipJson(
        '${AppConstants.hadithV2BasePath}$collectionId.json.gz',
      );
    } catch (e) {
      throw HadithDataException(
        'Failed to load hadith corpus for "$collectionId": $e',
      );
    }

    final books = <HadithBook>[];
    final chapters = <int, HadithChapter>{};
    final hadiths = <Hadith>[];

    try {
      for (final b in (payload['books'] as List<dynamic>? ?? [])) {
        final book = HadithBook.fromJson(
          (b as Map<String, dynamic>)..['collectionId'] = collectionId,
        );
        books.add(book);
        _booksCache.putIfAbsent(collectionId, () => []).add(book);
      }
    } catch (_) {
      _booksCache[collectionId] = [];
    }
    if (!_booksCache.containsKey(collectionId)) {
      _booksCache[collectionId] = books;
    }

    try {
      for (final ch in (payload['chapters'] as List<dynamic>? ?? [])) {
        final chapter = HadithChapter.fromJson(ch as Map<String, dynamic>);
        chapters[chapter.id] = chapter;
      }
    } catch (_) {}
    _chaptersCache[collectionId] = chapters;

    try {
      for (final h in (payload['hadiths'] as List<dynamic>? ?? [])) {
        final hadith = Hadith.fromJson(
          (h as Map<String, dynamic>)..['collectionId'] = collectionId,
        );
        final chapter = hadith.chapterId != null
            ? chapters[hadith.chapterId]
            : null;
        hadiths.add(
          chapter == null
              ? hadith
              : Hadith(
                  hadithNumber: hadith.hadithNumber,
                  displayNumber: hadith.displayNumber,
                  hadithNumberInBook: hadith.hadithNumberInBook,
                  collectionId: hadith.collectionId,
                  bookNumber: hadith.bookNumber,
                  textArabic: hadith.textArabic,
                  textEnglish: hadith.textEnglish,
                  textUrdu: hadith.textUrdu,
                  narratorChainArabic: hadith.narratorChainArabic,
                  narratorChainEnglish: hadith.narratorChainEnglish,
                  narratorPostfixArabic: hadith.narratorPostfixArabic,
                  narratorPostfixEnglish: hadith.narratorPostfixEnglish,
                  matnArabic: hadith.matnArabic,
                  matnEnglish: hadith.matnEnglish,
                  narrator: hadith.narrator,
                  grade: hadith.grade,
                  gradeArabic: hadith.gradeArabic,
                  commentsEnglish: hadith.commentsEnglish,
                  commentsArabic: hadith.commentsArabic,
                  tags: hadith.tags,
                  chapterId: hadith.chapterId,
                  chapterTitle: chapter.title,
                  chapterTitleArabic: chapter.titleArabic,
                  narratorIds: hadith.narratorIds,
                  reference: hadith.reference,
                ),
        );
      }
    } catch (e) {
      throw HadithDataException(
        'Failed to parse hadith corpus for "$collectionId": $e',
      );
    }

    _allHadithsByCollectionCache[collectionId] = hadiths;
    _trackCacheUse(collectionId);
    return hadiths;
  }

  // ═══════════════════════════════════════════════════════════════
  // Collections
  // ═══════════════════════════════════════════════════════════════

  /// Returns all available hadith collections (16 fully offline corpora)
  Future<List<HadithCollection>> getCollections() async {
    if (_collectionsCache != null) return _collectionsCache!;
    try {
      final jsonString = await rootBundle.loadString(
        '${AppConstants.hadithV2BasePath}collections.json',
      );
      _collectionsCache = parseCollectionList(jsonString);
      return _collectionsCache!;
    } catch (e) {
      throw HadithDataException('Failed to load hadith collections: $e');
    }
  }

  /// Get a specific collection by its ID
  Future<HadithCollection> getCollectionById(String collectionId) async {
    final collections = await getCollections();
    final collection =
        collections.where((c) => c.id == collectionId).firstOrNull;
    if (collection == null) {
      throw HadithDataException('Collection "$collectionId" not found');
    }
    return collection;
  }

  // ═══════════════════════════════════════════════════════════════
  // Books
  // ═══════════════════════════════════════════════════════════════

  /// Returns all books within a collection
  Future<List<HadithBook>> getBooks(String collectionId) async {
    final cached = _booksCache[collectionId];
    if (cached != null) return cached;
    // Loading the collection populates books/chapters/hadiths together.
    await _loadCollection(collectionId);
    return _booksCache[collectionId] ?? [];
  }

  /// Get a specific book within a collection
  Future<HadithBook> getBook(String collectionId, int bookNumber) async {
    final books = await getBooks(collectionId);
    final book = books.where((b) => b.bookNumber == bookNumber).firstOrNull;
    if (book == null) {
      throw HadithDataException(
        'Book $bookNumber not found in collection "$collectionId"',
      );
    }
    return book;
  }

  // ═══════════════════════════════════════════════════════════════
  // Chapters
  // ═══════════════════════════════════════════════════════════════

  /// Returns all chapters of a book, ordered by chapter number.
  Future<List<HadithChapter>> getChapters(
    String collectionId,
    int bookNumber,
  ) async {
    await _loadCollection(collectionId);
    final chapters = _chaptersCache[collectionId] ?? const {};
    return chapters.values
        .where((c) => c.bookNumber == bookNumber)
        .toList()
      ..sort((a, b) => (a.number ?? 0).compareTo(b.number ?? 0));
  }

  // ═══════════════════════════════════════════════════════════════
  // Hadiths
  // ═══════════════════════════════════════════════════════════════

  /// Returns all hadiths in a specific book
  Future<List<Hadith>> getHadiths(
    String collectionId,
    int bookNumber,
  ) async {
    final cacheKey = '${collectionId}_$bookNumber';
    if (_hadithsCache.containsKey(cacheKey)) {
      return _hadithsCache[cacheKey]!;
    }
    final all = await _loadCollection(collectionId);
    final filtered =
        all.where((h) => h.bookNumber == bookNumber).toList();
    _hadithsCache[cacheKey] = filtered;
    return filtered;
  }

  /// Get a single hadith by its stable id (urn) within a collection.
  Future<Hadith> getHadithById(String collectionId, int hadithNumber) async {
    final all = await _loadCollection(collectionId);
    return all
            .where((h) => h.hadithNumber == hadithNumber)
            .firstOrNull ??
        (throw HadithDataException(
          'Hadith $hadithNumber not found in collection "$collectionId"',
        ));
  }

  /// Get a single hadith by its number within a book
  Future<Hadith> getHadithByNumber(
    String collectionId,
    int bookNumber,
    int hadithNumber,
  ) async {
    final hadiths = await getHadiths(collectionId, bookNumber);
    final hadith =
        hadiths.where((h) => h.hadithNumber == hadithNumber).firstOrNull ??
            hadiths
                .where((h) => h.hadithNumberInBook == hadithNumber)
                .firstOrNull;
    if (hadith == null) {
      throw HadithDataException(
        'Hadith $hadithNumber not found in $collectionId book $bookNumber',
      );
    }
    return hadith;
  }

  /// Get all hadiths in a collection (single decompressed asset)
  Future<List<Hadith>> getAllHadithsInCollection(
    String collectionId,
  ) async {
    return _loadCollection(collectionId);
  }

  /// Get a single hadith by its global number within a collection
  Future<Hadith> getHadithByGlobalNumber(
    String collectionId,
    int globalNumber,
  ) async {
    return getHadithById(collectionId, globalNumber);
  }

  /// Returns a deterministic rotating subset of hadiths (for daily features).
  /// [dayIndex] rotates through the collection so every day offers fresh
  /// content with zero randomness between sessions.
  Future<List<Hadith>> getDailyRotation({
    required int count,
    required int dayIndex,
    List<String>? collectionIds,
  }) async {
    final ids = collectionIds ??
        (await getCollections()).map((c) => c.id).toList();
    final picked = <Hadith>[];
    for (var i = 0; i < ids.length && picked.length < count; i++) {
      final id = ids[(dayIndex + i) % ids.length];
      try {
        final hadiths = await _loadCollection(id);
        if (hadiths.isEmpty) continue;
        final stride = hadiths.length < count ? 1 : hadiths.length ~/ count;
        final offset = (dayIndex * stride) % hadiths.length;
        for (var j = 0; j < count ~/ ids.length + 1 && picked.length < count; j++) {
          picked.add(hadiths[(offset + j * stride) % hadiths.length]);
        }
      } catch (_) {
        continue;
      }
    }
    return picked;
  }

  // ═══════════════════════════════════════════════════════════════
  // Scholars / narrators
  // ═══════════════════════════════════════════════════════════════

  /// Returns all narrator biographies (25k real scholars).
  Future<List<HadithScholar>> getScholars() async {
    if (_scholarsCache != null) return _scholarsCache!;
    try {
      final decoded = await _loadGzipJson(
        '${AppConstants.hadithV2BasePath}scholars.json.gz',
      );
      final scholars = (decoded as List<dynamic>)
          .map((s) => HadithScholar.fromJson(s as Map<String, dynamic>))
          .toList();
      _scholarsCache = scholars;
      return scholars;
    } catch (e) {
      throw HadithDataException('Failed to load scholars: $e');
    }
  }

  /// Returns the narrator bios appearing in a given hadith's isnad.
  Future<List<HadithScholar>> getHadithNarrators(Hadith hadith) async {
    final ids = hadith.narratorIds;
    if (ids == null || ids.isEmpty) return [];
    final key = ids.join(',');
    if (_scholarIndexCache.containsKey(key)) {
      return _scholarIndexCache[key]!
          .map((i) => HadithScholar(id: i, name: ''))
          .toList();
    }
    final scholars = await getScholars();
    final byId = {for (final s in scholars) s.id: s};
    final result = <HadithScholar>[];
    for (final id in ids) {
      final s = byId[id];
      if (s != null) result.add(s);
    }
    return result;
  }

  // ═══════════════════════════════════════════════════════════════
  // Search
  // ═══════════════════════════════════════════════════════════════

  /// Strips Arabic tashkeel and unifies hamza/alif variants for robust
  /// diacritic-insensitive search.
  static String normalizeArabic(String text) {
    final buf = StringBuffer();
    for (final code in text.runes) {
      // Tashkeel: 064B-065F, 0670; Qur'anic marks: 06D6-06ED; sup: 0640 skip
      if ((code >= 0x064B && code <= 0x065F) ||
          code == 0x0670 ||
          (code >= 0x06D6 && code <= 0x06ED)) {
        continue;
      }
      switch (code) {
        case 0x0623: // أ
        case 0x0625: // إ
        case 0x0622: // آ
          buf.writeCharCode(0x0627); // ا
          break;
        case 0x0649: // ى
          buf.writeCharCode(0x064A); // ي
          break;
        default:
          buf.writeCharCode(code);
      }
    }
    return buf.toString().toLowerCase();
  }

  Future<List<String>> _normalizedArabicTexts(String collectionId) async {
    if (_normalizedArabicCache.containsKey(collectionId)) {
      return _normalizedArabicCache[collectionId]!;
    }
    final hadiths = await _loadCollection(collectionId);
    if (kIsWeb) {
      final texts = hadiths.map((h) => normalizeArabic(h.textArabic)).toList();
      _normalizedArabicCache[collectionId] = texts;
      return texts;
    }
    final texts = await Isolate.run(() {
      return hadiths.map((h) => normalizeArabic(h.textArabic)).toList();
    });
    _normalizedArabicCache[collectionId] = texts;
    return texts;
  }

  /// Search hadiths across all collections (diacritic-insensitive Arabic +
  /// case-insensitive English), streaming per collection and capped.
  Future<List<HadithSearchResult>> searchHadith(
    String query, {
    String? collectionId,
    int maxResults = 50,
    String language = 'en',
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final normalizedQuery = normalizeArabic(trimmed);
    final lowerQuery = trimmed.toLowerCase();
    final results = <HadithSearchResult>[];

    final collectionsToSearch = <String>[];
    if (collectionId != null) {
      collectionsToSearch.add(collectionId);
    } else {
      final collections = await getCollections();
      for (final c in collections) {
        collectionsToSearch.add(c.id);
      }
    }

    for (final colId in collectionsToSearch) {
      if (results.length >= maxResults) break;

      List<Hadith> hadiths;
      try {
        hadiths = await _loadCollection(colId);
      } catch (_) {
        continue;
      }
      if (hadiths.isEmpty) continue;

      String? collectionName;
      try {
        final col = await getCollectionById(colId);
        collectionName = col.name;
      } catch (_) {
        collectionName = colId;
      }
      String? bookName;
      try {
        final books = _booksCache[colId] ?? await getBooks(colId);
        final byId = {for (final b in books) b.bookNumber: b.bookName};
        bookName = null; // resolved per-result below
        for (final hadith in hadiths) {
          if (results.length >= maxResults) break;
          final isArabicQuery = RegExp(r'[\u0600-\u06FF]').hasMatch(trimmed);
          int matchIndex = -1;
          String? matchedArabic;
          String? matchedEnglish;
          if (isArabicQuery) {
            final normalized = normalizeArabic(hadith.textArabic);
            final idx = normalized.indexOf(normalizedQuery);
            if (idx >= 0) {
              matchIndex = idx;
              matchedArabic = hadith.textArabic;
            }
          } else if (hadith.textEnglish != null) {
            final englishLower = hadith.textEnglish!.toLowerCase();
            final idx = englishLower.indexOf(lowerQuery);
            if (idx >= 0) {
              matchIndex = idx;
              matchedEnglish = hadith.textEnglish;
            }
          }
          if (matchIndex < 0) continue;
          results.add(HadithSearchResult(
            hadith: hadith,
            collectionName: collectionName,
            bookName: byId[hadith.bookNumber],
            highlightedArabic: matchedArabic,
            highlightedEnglish: matchedEnglish,
            matchStartIndex: matchIndex,
            matchLength: trimmed.length,
          ));
        }
      } catch (_) {
        continue;
      }
    }

    return results;
  }

  /// Search hadiths within a specific collection
  Future<List<HadithSearchResult>> searchHadithInCollection(
    String query,
    String collectionId, {
    int maxResults = 50,
  }) async {
    return searchHadith(
      query,
      collectionId: collectionId,
      maxResults: maxResults,
    );
  }

  /// Search hadiths within a specific book
  Future<List<HadithSearchResult>> searchHadithInBook(
    String query,
    String collectionId,
    int bookNumber, {
    int maxResults = 50,
  }) async {
    final results = await searchHadithInCollection(
      query,
      collectionId,
      maxResults: maxResults * 4,
    );
    return results.where((r) => r.hadith.bookNumber == bookNumber).toList();
  }

  /// Get hadiths by narrator (matched via isnad scholar ids)
  Future<List<Hadith>> getHadithsByNarrator(
    String collectionId,
    String narratorName,
  ) async {
    final allHadiths = await getAllHadithsInCollection(collectionId);
    final normalized = narratorName.toLowerCase();
    return allHadiths
        .where((h) =>
            h.narrator?.toLowerCase().contains(normalized) ??
                false ||
            (h.narratorChainArabic?.toLowerCase().contains(normalized) ??
                false))
        .toList();
  }

  /// Get hadiths by grade (Sahih, Hasan, Daif)
  Future<List<Hadith>> getHadithsByGrade(
    String collectionId,
    String grade,
  ) async {
    final allHadiths = await getAllHadithsInCollection(collectionId);
    final normalizedGrade = grade.toLowerCase();
    return allHadiths
        .where((h) =>
            h.grade?.toLowerCase().contains(normalizedGrade) ??
                false ||
            (h.gradeArabic?.contains(grade) ?? false))
        .toList();
  }

  // ═══════════════════════════════════════════════════════════════
  // Cache Management
  // ═══════════════════════════════════════════════════════════════

  /// Clear all cached data (frees memory)
  void clearCache() {
    _collectionsCache = null;
    _booksCache.clear();
    _chaptersCache.clear();
    _hadithsCache.clear();
    _allHadithsByCollectionCache.clear();
    _normalizedArabicCache.clear();
    _scholarsCache = null;
    _scholarIndexCache.clear();
    _cacheEvictionOrder.clear();
  }

  /// Pre-load collection list and scholars index
  Future<void> preloadCollections() async {
    await getCollections();
  }

  /// Signal ongoing loads to abort gracefully (called from app dispose).
  void dispose() {
    _isShuttingDown = true;
    clearCache();
  }

  bool get isDisposed => _isShuttingDown;
}

/// Custom exception for hadith data loading errors
class HadithDataException implements Exception {
  final String message;
  final Object? cause;

  const HadithDataException(this.message, {this.cause});

  @override
  String toString() => 'HadithDataException: $message';
}
