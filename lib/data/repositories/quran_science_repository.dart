import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_constants.dart';

/// A single word of an ayah with its full sciences payload.
class QuranWord {
  final String text; // Uthmani script
  final String transliteration;
  final String translation;
  final int page;
  final int line;

  const QuranWord({
    required this.text,
    required this.transliteration,
    required this.translation,
    required this.page,
    required this.line,
  });
}

/// Verse-level metadata for layout and sciences.
class AyahMeta {
  final int page;
  final int juz;
  final int hizb;
  final int ruku;
  final bool hasSajdah;

  const AyahMeta({
    required this.page,
    required this.juz,
    required this.hizb,
    required this.ruku,
    required this.hasSajdah,
  });
}

/// One tajweed annotation span (character range within the ayah text).
class TajweedSpan {
  final int start;
  final int end;
  final String rule;

  const TajweedSpan(this.start, this.end, this.rule);
}

/// A tafseer edition descriptor.
class TafseerEdition {
  final String id;
  final String name;
  final String lang;
  final String? provenance;

  const TafseerEdition({
    required this.id,
    required this.name,
    required this.lang,
    this.provenance,
  });

  factory TafseerEdition.fromJson(Map<String, dynamic> json) {
    return TafseerEdition(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      lang: json['lang'] as String? ?? 'en',
      provenance: json['provenance'] as String?,
    );
  }
}

/// Single load result for one ayah's words.
class AyahWordAnalysis {
  final int surahNumber;
  final int ayahNumber;
  final List<QuranWord> words;
  final List<TajweedSpan> tajweed;

  const AyahWordAnalysis({
    required this.surahNumber,
    required this.ayahNumber,
    required this.words,
    this.tajweed = const [],
  });
}

/// Morphological information for one word (Quranic Arabic Corpus v0.4).
class WordMorphology {
  final String root;
  final String pos;
  final String lemma;
  final List<String> features;

  const WordMorphology({
    required this.root,
    required this.pos,
    required this.lemma,
    required this.features,
  });

  bool get hasRoot => root.isNotEmpty;
}

/// One location of a root occurrence: surah, ayah, word index.
class RootOccurrence {
  final int surah;
  final int ayah;
  final int wordIndex;

  const RootOccurrence(this.surah, this.ayah, this.wordIndex);
}

/// Repository for all Qur'an sciences data (fully offline, gzip assets):
/// word-by-word translation + transliteration + exact Madani layout,
/// tafseer editions, tajweed letter-level annotations, morphology/root
/// corpus, page/juz metadata.
class QuranScienceRepository {
  bool _loaded = false;

  Map<String, List<List<String>>>? _words; // "s:a" -> [text, translit, translation]
  Map<String, List<int>>? _wordPages;
  Map<String, List<int>>? _wordLines;
  Map<String, Map<String, int>>? _verseMeta;
  Map<String, String>? _pageStarts; // "604" -> "114:6"
  Map<String, List<int>>? _surahPages; // "1" -> [startPage, endPage]
  final Map<String, Map<String, String>> _tafseerCache = {};
  Map<String, List<TajweedSpan>>? _tajweed;
  List<TafseerEdition>? _tafseerIndex;
  Map<String, List<List<String>>>? _morphology; // "s:a" -> [root,pos,lemma,feats]
  Map<String, List<List<int>>>? _rootIndex; // root -> [[s,a,w], ...]

  static const Map<String, String> tajweedRuleColors = {
    'hamzat_wasl': '0xFFAAAAAA',
    'silent': '0xFFAAAAAA',
    'slnt': '0xFFAAAAAA',
    'lam_shamsiyyah': '0xFF26A69A',
    'lam_qamariyyah': '0xFF42A5F5',
    'madd_2': '0xFFEF5350',
    'madd_246': '0xFFEF5350',
    'madd_6': '0xFFEF5350',
    'madd_leen_ghunnah': '0xFFEF5350',
    'madd_leen': '0xFFEF5350',
    'madd_necessary': '0xFFEF5350',
    'madd_obligatory': '0xFFEF5350',
    'madd_permitted': '0xFFEF5350',
    'ikhafa': '0xFF7E57C2',
    'ikhafa_ghunnah': '0xFF7E57C2',
    'iqlab': '0xFF5C6BC0',
    'idgham_ghunnah': '0xFF66BB6A',
    'idgham_wo_ghunnah': '0xFF66BB6A',
    'idgham_mutajanisayn': '0xFF66BB6A',
    'idgham_mutaqaribayn': '0xFF66BB6A',
    'izhar': '0xFF26C6DA',
    'izhar_ghunnah': '0xFF26C6DA',
    'ghunnah': '0xFFFFB300',
    'qalqalah': '0xFFFF7043',
    'qalaqah': '0xFFFF7043',
    'laqn': '0xFF8D6E63',
    'sukun': '0xFF8D6E63',
    'shaddah': '0xFFD4E157',
    'small_alef': '0xFFEF5350',
    'small_waw': '0xFFEF5350',
    'small_ya': '0xFFEF5350',
  };

  // ── Loading ─────────────────────────────────────────────────────

  Future<dynamic> _loadGzipJson(String assetPath) async {
    final ByteData data = await rootBundle.load(assetPath);
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

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final base = AppConstants.quranScienceBasePath;

    final results = await Future.wait([
      _loadGzipJson('${base}wbw.json.gz'),
      _loadGzipJson('${base}tajweed.json.gz'),
      _loadGzipJson('${base}morphology.json.gz'),
      _loadGzipJson('${base}root_index.json.gz'),
      rootBundle.loadString('${base}page_starts.json'),
      rootBundle.loadString('${base}surah_pages.json'),
      rootBundle.loadString('${base}tafseer_index.json'),
    ]);

    final wbw = results[0] as Map<String, dynamic>;
    _words = (wbw['w'] as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, (v as List<dynamic>).cast<List<String>>()));
    _wordPages = (wbw['p'] as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, (v as List<dynamic>).cast<int>()));
    _wordLines = (wbw['l'] as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, (v as List<dynamic>).cast<int>()));
    _verseMeta = (wbw['v'] as Map<String, dynamic>).map((k, v) {
      final m = v as Map<String, dynamic>;
      return MapEntry(k, {
        'p': m['p'] as int? ?? 1,
        'j': m['j'] as int? ?? 1,
        'h': m['h'] as int? ?? 1,
        'r': m['r'] as int? ?? 1,
        'saj': m['saj'] as int? ?? 0,
      });
    });

    final taj = results[1] as Map<String, dynamic>;
    _tajweed = taj.map((k, v) => MapEntry(
          k,
          (v as List<dynamic>)
              .map((s) => TajweedSpan(
                    (s as List<dynamic>)[0] as int,
                    s[1] as int,
                    s[2] as String,
                  ))
              .toList(),
        ));

    _morphology = (results[2] as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, (v as List<dynamic>).cast<List<String>>()));
    _rootIndex = (results[3] as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, (v as List<dynamic>).cast<List<int>>()));

    _pageStarts =
        (json.decode(results[4] as String) as Map<String, dynamic>)
            .cast<String, String>();
    _surahPages =
        (json.decode(results[5] as String) as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, (v as List<dynamic>).cast<int>()),
    );
    _tafseerIndex = (json.decode(results[6] as String) as List<dynamic>)
        .map((e) => TafseerEdition.fromJson(e as Map<String, dynamic>))
        .toList();

    _loaded = true;
  }

  // ── Word sciences ───────────────────────────────────────────────

  /// Full word analysis for one ayah (translation, transliteration, layout).
  Future<AyahWordAnalysis> getWordAnalysis(int surah, int ayah) async {
    await _ensureLoaded();
    final key = '$surah:$ayah';
    final rawWords = _words![key] ?? const [];
    final pages = _wordPages![key] ?? const [];
    final lines = _wordLines![key] ?? const [];
    final words = <QuranWord>[];
    for (var i = 0; i < rawWords.length; i++) {
      final w = rawWords[i];
      words.add(QuranWord(
        text: w[0],
        transliteration: w.length > 1 ? w[1] : '',
        translation: w.length > 2 ? w[2] : '',
        page: i < pages.length ? pages[i] : 1,
        line: i < lines.length ? lines[i] : 1,
      ));
    }
    return AyahWordAnalysis(
      surahNumber: surah,
      ayahNumber: ayah,
      words: words,
      tajweed: getTajweedSpansSync(surah, ayah),
    );
  }

  /// Word list for one ayah (synchronous after first load).
  List<QuranWord> getWordsSync(int surah, int ayah) {
    if (!_loaded || _words == null) return const [];
    final key = '$surah:$ayah';
    final rawWords = _words![key] ?? const [];
    final pages = _wordPages![key] ?? const [];
    final lines = _wordLines![key] ?? const [];
    return List.generate(rawWords.length, (i) {
      final w = rawWords[i];
      return QuranWord(
        text: w[0],
        transliteration: w.length > 1 ? w[1] : '',
        translation: w.length > 2 ? w[2] : '',
        page: i < pages.length ? pages[i] : 1,
        line: i < lines.length ? lines[i] : 1,
      );
    });
  }

  /// Whether word-by-word data is available for an ayah.
  bool hasWords(int surah, int ayah) {
    if (!_loaded) return false;
    return _words?.containsKey('$surah:$ayah') ?? false;
  }

  // ── Layout / navigation metadata ────────────────────────────────

  /// Verse metadata (page, juz, hizb, ruku, sajdah).
  AyahMeta? getAyahMeta(int surah, int ayah) {
    if (!_loaded) return null;
    final m = _verseMeta?['$surah:$ayah'];
    if (m == null) return null;
    return AyahMeta(
      page: m['p'] ?? 1,
      juz: m['j'] ?? 1,
      hizb: m['h'] ?? 1,
      ruku: m['r'] ?? 1,
      hasSajdah: (m['saj'] ?? 0) == 1,
    );
  }

  /// The first ayah key ("s:a") on a given Madani page (1-604).
  String? pageStart(int page) {
    if (!_loaded) return null;
    return _pageStarts?['$page'];
  }

  /// [startPage, endPage] for a surah (Madani mushaf pages).
  List<int>? surahPageRange(int surah) {
    if (!_loaded) return null;
    return _surahPages?['$surah'];
  }

  /// Total Madani pages (604).
  int get totalPages => 604;

  /// Parse an ayah key like "2:255" into (surah, ayah); null if invalid.
  static (int, int)? parseAyahKey(String key) {
    final parts = key.split(':');
    if (parts.length != 2) return null;
    final s = int.tryParse(parts[0]);
    final a = int.tryParse(parts[1]);
    if (s == null || a == null || s < 1 || s > 114 || a < 1) return null;
    return (s, a);
  }

  // ── Tajweed ─────────────────────────────────────────────────────

  /// Letter-level tajweed annotations for one ayah.
  List<TajweedSpan> getTajweedSpansSync(int surah, int ayah) {
    if (!_loaded) return const [];
    return _tajweed?['$surah:$ayah'] ?? const [];
  }

  // ── Morphology / roots ──────────────────────────────────────────

  /// Morphology for every word of one ayah (aligned with word positions).
  List<WordMorphology> getMorphologySync(int surah, int ayah) {
    if (!_loaded) return const [];
    final rows = _morphology?['$surah:$ayah'] ?? const [];
    return rows.map((r) {
      final feats = (r.length > 3 && r[3].isNotEmpty)
          ? r[3].split('|')
          : const <String>[];
      return WordMorphology(
        root: r.isNotEmpty ? r[0] : '',
        pos: r.length > 1 ? r[1] : '',
        lemma: r.length > 2 ? r[2] : '',
        features: feats,
      );
    }).toList();
  }

  /// All locations where a root occurs (real corpus-derived index).
  List<RootOccurrence> getRootOccurrences(String root) {
    if (!_loaded) return const [];
    final locs = _rootIndex?[root] ?? const [];
    return locs
        .map((l) => RootOccurrence(l[0], l[1], l[2]))
        .toList();
  }

  /// The ayah text of one word occurrence (for root exploration lists).
  String? wordTextAt(int surah, int ayah, int wordIndex) {
    if (!_loaded) return null;
    final words = _words?['$surah:$ayah'];
    if (words == null || wordIndex < 1 || wordIndex > words.length) {
      return null;
    }
    return words[wordIndex - 1][0];
  }

  /// Distinct word forms sharing the same root, with counts.
  Map<String, int> getRootWordForms(String root) {
    final counts = <String, int>{};
    for (final occ in getRootOccurrences(root)) {
      final text = wordTextAt(occ.surah, occ.ayah, occ.wordIndex);
      if (text == null) continue;
      counts[text] = (counts[text] ?? 0) + 1;
    }
    return counts;
  }

  // ── Tafseer ─────────────────────────────────────────────────────

  /// Available tafseer editions.
  Future<List<TafseerEdition>> getTafseerEditions() async {
    await _ensureLoaded();
    return _tafseerIndex ?? const [];
  }

  /// Tafseer text for one ayah in the given edition (cached per edition).
  Future<String?> getTafseer(String editionId, int surah, int ayah) async {
    await _ensureLoaded();
    final cache = _tafseerCache.putIfAbsent(editionId, () => {});
    final key = '$surah:$ayah';
    if (cache.containsKey(key)) return cache[key];
    try {
      final decoded = await _loadGzipJson(
        '${AppConstants.quranScienceBasePath}tafsir_$editionId.json.gz',
      );
      final map = decoded as Map<String, dynamic>;
      for (final entry in map.entries) {
        cache[entry.key] = entry.value as String? ?? '';
      }
    } catch (_) {
      cache[key] = '';
    }
    final value = cache[key];
    return (value == null || value.isEmpty) ? null : value;
  }

  /// Tafseer for a whole surah (concatenated with ayah numbers).
  Future<Map<int, String>> getSurahTafseer(
    String editionId,
    int surah, {
    required int ayahCount,
  }) async {
    final result = <int, String>{};
    for (var a = 1; a <= ayahCount; a++) {
      final t = await getTafseer(editionId, surah, a);
      if (t != null) result[a] = t;
    }
    return result;
  }
}
