import 'dart:convert';

/// Represents a hadith collection (e.g., Sahih al-Bukhari).
/// Parsed from `assets/data/hadith/v2/collections.json`.
class HadithCollection {
  final String id; // slug, e.g., 'bukhari'
  final int dbId; // stable numeric id from the source dataset
  final String name;
  final String? nameArabic;
  final String? shortName;
  final String? author;
  final String? authorArabic;
  final String? authorDeath;
  final String? type; // 'collection' or 'selection'
  final String? status;
  final int totalHadiths;
  final int totalBooks;
  final String? introduction;
  final String? numberingNote;
  final bool hasVolumes;
  final int? totalVolumes;

  const HadithCollection({
    required this.id,
    this.dbId = 0,
    required this.name,
    this.nameArabic,
    this.shortName,
    this.author,
    this.authorArabic,
    this.authorDeath,
    this.type,
    this.status,
    required this.totalHadiths,
    required this.totalBooks,
    this.introduction,
    this.numberingNote,
    this.hasVolumes = false,
    this.totalVolumes,
  });

  factory HadithCollection.fromJson(Map<String, dynamic> json) {
    return HadithCollection(
      id: json['id'] as String? ?? json['key'] as String? ?? '',
      dbId: json['dbId'] as int? ?? json['db_id'] as int? ?? 0,
      name: json['name'] as String? ?? json['collection_name'] as String? ?? '',
      nameArabic: json['name_arabic'] as String? ??
          json['nameArabic'] as String? ??
          json['nameAr'] as String?,
      shortName: json['short_name'] as String? ??
          json['shortName'] as String?,
      author: json['author'] as String? ?? json['imam'] as String?,
      authorArabic: json['author_arabic'] as String? ??
          json['authorArabic'] as String? ??
          json['authorAr'] as String?,
      authorDeath: json['authorDeath'] as String? ??
          json['author_death'] as String?,
      type: json['type'] as String?,
      status: json['status'] as String?,
      totalHadiths: json['total_hadiths'] as int? ??
          json['totalHadiths'] as int? ??
          json['hadith_count'] as int? ?? 0,
      totalBooks: json['total_books'] as int? ??
          json['totalBooks'] as int? ??
          json['book_count'] as int? ?? 0,
      introduction: json['introduction'] as String?,
      numberingNote: json['numberingNote'] as String? ??
          json['numbering_note'] as String?,
      hasVolumes: json['has_volumes'] as bool? ??
          json['hasVolumes'] as bool? ?? false,
      totalVolumes: json['total_volumes'] as int? ??
          json['totalVolumes'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'dbId': dbId,
      'name': name,
      'name_arabic': nameArabic,
      'short_name': shortName,
      'author': author,
      'author_arabic': authorArabic,
      'authorDeath': authorDeath,
      'type': type,
      'status': status,
      'total_hadiths': totalHadiths,
      'total_books': totalBooks,
      'introduction': introduction,
      'numberingNote': numberingNote,
      'has_volumes': hasVolumes,
      'total_volumes': totalVolumes,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HadithCollection && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'HadithCollection($id: $name)';
}

/// Represents a book within a hadith collection.
class HadithBook {
  final int bookNumber; // stable numeric book id within the collection
  final String collectionId;
  final String bookName;
  final String? bookNameArabic;
  final int? hadithStartNumber;
  final int? hadithEndNumber;
  final int totalHadiths;
  final String? description;
  final int? volumeNumber;

  const HadithBook({
    required this.bookNumber,
    required this.collectionId,
    required this.bookName,
    this.bookNameArabic,
    this.hadithStartNumber,
    this.hadithEndNumber,
    required this.totalHadiths,
    this.description,
    this.volumeNumber,
  });

  /// Unique identifier combining collection and book number
  String get uniqueId => '${collectionId}_$bookNumber';

  factory HadithBook.fromJson(Map<String, dynamic> json) {
    return HadithBook(
      bookNumber: json['book_number'] as int? ??
          json['bookNumber'] as int? ??
          json['book'] as int? ??
          json['id'] as int? ??
          0,
      collectionId: json['collection_id'] as String? ??
          json['collectionId'] as String? ??
          '',
      bookName: json['book_name'] as String? ??
          json['bookName'] as String? ??
          json['name'] as String? ??
          json['en'] as String? ??
          '',
      bookNameArabic: json['book_name_arabic'] as String? ??
          json['bookNameArabic'] as String? ??
          json['ar'] as String?,
      hadithStartNumber: json['hadith_start_number'] as int? ??
          json['hadithStartNumber'] as int? ??
          json['s'] as int?,
      hadithEndNumber: json['hadith_end_number'] as int? ??
          json['hadithEndNumber'] as int? ??
          json['e'] as int?,
      totalHadiths: json['total_hadiths'] as int? ??
          json['totalHadiths'] as int? ??
          json['hadith_count'] as int? ??
          json['c'] as int? ??
          0,
      description: json['description'] as String?,
      volumeNumber: json['volume_number'] as int? ??
          json['volumeNumber'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'book_number': bookNumber,
      'collection_id': collectionId,
      'book_name': bookName,
      'book_name_arabic': bookNameArabic,
      'hadith_start_number': hadithStartNumber,
      'hadith_end_number': hadithEndNumber,
      'total_hadiths': totalHadiths,
      'description': description,
      'volume_number': volumeNumber,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HadithBook && other.uniqueId == uniqueId;
  }

  @override
  int get hashCode => uniqueId.hashCode;

  @override
  String toString() => 'HadithBook($uniqueId: $bookName)';
}

/// Represents a chapter (باب) within a hadith book.
class HadithChapter {
  final int id;
  final int bookNumber;
  final int? number;
  final String title;
  final String? titleArabic;
  final String? intro;
  final String? introArabic;

  const HadithChapter({
    required this.id,
    required this.bookNumber,
    this.number,
    required this.title,
    this.titleArabic,
    this.intro,
    this.introArabic,
  });

  factory HadithChapter.fromJson(Map<String, dynamic> json) {
    return HadithChapter(
      id: json['id'] as int? ?? 0,
      bookNumber: json['b'] as int? ??
          json['book_number'] as int? ??
          json['bookNumber'] as int? ??
          0,
      number: json['n'] as int? ?? json['number'] as int?,
      title: json['en'] as String? ??
          json['title'] as String? ??
          json['title_en'] as String? ??
          '',
      titleArabic: json['ar'] as String? ??
          json['title_arabic'] as String? ??
          json['titleArabic'] as String?,
      intro: json['ie'] as String? ?? json['intro'] as String?,
      introArabic: json['ia'] as String? ?? json['intro_arabic'] as String?,
    );
  }
}

/// Narrator / scholar biography for isnad exploration.
class HadithScholar {
  final int id;
  final String name;
  final String? kunya;
  final String? born;
  final String? died;
  final String? livedIn;

  const HadithScholar({
    required this.id,
    required this.name,
    this.kunya,
    this.born,
    this.died,
    this.livedIn,
  });

  factory HadithScholar.fromJson(Map<String, dynamic> json) {
    return HadithScholar(
      id: json['i'] as int? ?? json['id'] as int? ?? 0,
      name: json['n'] as String? ?? json['name'] as String? ?? '',
      kunya: json['k'] as String? ?? json['kunya'] as String?,
      born: json['b'] as String? ?? json['born'] as String?,
      died: json['d'] as String? ?? json['died'] as String?,
      livedIn: json['l'] as String? ?? json['lived_in'] as String?,
    );
  }
}

/// Represents a single hadith (narration).
class Hadith {
  final int hadithNumber; // stable urn-based id
  final String? displayNumber; // per-collection numbering ('1', '1a', ...)
  final int? hadithNumberInBook;
  final String collectionId;
  final int bookNumber;
  final String textArabic; // composed: isnad + matn + postfix
  final String? textEnglish;
  final String? textUrdu;
  final String? narratorChainArabic; // isnad prefix
  final String? narratorChainEnglish;
  final String? narratorPostfixArabic;
  final String? narratorPostfixEnglish;
  final String? matnArabic; // body text without isnad
  final String? matnEnglish;
  final String? narrator; // primary narrator/sahabi
  final String? grade; // authenticity grade (Sahih, Hasan, Daif, etc.)
  final String? gradeArabic;
  final String? commentsEnglish;
  final String? commentsArabic;
  final List<String>? tags;
  final int? chapterId;
  final String? chapterTitle;
  final String? chapterTitleArabic;
  final List<int>? narratorIds; // scholar ids for isnad exploration
  final String? reference;

  const Hadith({
    required this.hadithNumber,
    this.displayNumber,
    this.hadithNumberInBook,
    required this.collectionId,
    required this.bookNumber,
    required this.textArabic,
    this.textEnglish,
    this.textUrdu,
    this.narratorChainArabic,
    this.narratorChainEnglish,
    this.narratorPostfixArabic,
    this.narratorPostfixEnglish,
    this.matnArabic,
    this.matnEnglish,
    this.narrator,
    this.grade,
    this.gradeArabic,
    this.commentsEnglish,
    this.commentsArabic,
    this.tags,
    this.chapterId,
    this.chapterTitle,
    this.chapterTitleArabic,
    this.narratorIds,
    this.reference,
  });

  /// Unique identifier
  String get uniqueId => '${collectionId}_${bookNumber}_$hadithNumber';

  /// Get the text in the specified language
  String getText(String language) {
    switch (language.toLowerCase()) {
      case 'ar':
        return textArabic;
      case 'ur':
        return textUrdu ?? textEnglish ?? textArabic;
      default:
        return textEnglish ?? textArabic;
    }
  }

  /// Whether this hadith has a graded authenticity
  bool get hasGrade =>
      (grade != null && grade!.isNotEmpty) ||
      (gradeArabic != null && gradeArabic!.isNotEmpty);

  /// Whether this hadith is Sahih (authentic)
  bool get isSahih {
    if (grade == null && gradeArabic == null) return false;
    final g = '${grade ?? ''} ${gradeArabic ?? ''}'.toLowerCase();
    return g.contains('sahih') || g.contains('صحيح');
  }

  /// Whether this hadith is Hasan (good)
  bool get isHasan {
    if (grade == null && gradeArabic == null) return false;
    final g = '${grade ?? ''} ${gradeArabic ?? ''}'.toLowerCase();
    return g.contains('hasan') || g.contains('حسن');
  }

  /// Whether this hadith is Daif (weak)
  bool get isDaif {
    if (grade == null && gradeArabic == null) return false;
    final g = '${grade ?? ''} ${gradeArabic ?? ''}'.toLowerCase();
    return g.contains('daif') || g.contains("da'if") || g.contains('ضعيف');
  }

  /// Truncated Arabic text for preview
  String get arabicPreview {
    if (textArabic.length <= 100) return textArabic;
    return '${textArabic.substring(0, 100)}...';
  }

  factory Hadith.fromJson(Map<String, dynamic> json) {
    String compose(String? prefix, String? body, String? postfix) {
      final buf = StringBuffer();
      for (final part in [prefix, body, postfix]) {
        if (part == null || part.isEmpty) continue;
        if (buf.isNotEmpty) buf.write(' ');
        buf.write(part);
      }
      return buf.toString();
    }

    final urn = json['u'] ?? json['hadithNumber'] ?? json['urn'];
    final int hadithNumber = urn is int
        ? urn
        : int.tryParse(urn?.toString() ?? '') ?? 0;
    final display = json['n']?.toString() ??
        json['display_number']?.toString() ??
        json['hadithNumberInBook']?.toString();
    final ap = json['ap'] as String? ??
        json['narrator_chain_arabic'] as String? ??
        json['narratorChainArabic'] as String?;
    final a = json['a'] as String? ??
        json['text_arabic'] as String? ??
        json['textArabic'] as String? ??
        json['arabic'] as String?;
    final apf = json['apf'] as String? ?? json['narrator_postfix'] as String?;
    final ep = json['ep'] as String? ??
        json['narrator_chain_english'] as String? ??
        json['narratorChainEnglish'] as String?;
    final e = json['e'] as String? ??
        json['text_english'] as String? ??
        json['textEnglish'] as String? ??
        json['english'] as String?;
    final epf = json['epf'] as String?;
    final textArabic = compose(ap, a, apf);
    final textEnglish = (ep != null || epf != null)
        ? compose(ep, e, epf)
        : e;
    List<int>? narratorIds;
    if (json['ns'] is List) {
      narratorIds = (json['ns'] as List)
          .map((x) => x is int ? x : int.tryParse(x.toString()) ?? 0)
          .where((x) => x > 0)
          .toList();
    }
    return Hadith(
      hadithNumber: hadithNumber,
      displayNumber: display,
      hadithNumberInBook: int.tryParse(display ?? '') ??
          json['hadith_number_in_book'] as int? ??
          json['hadithNumberInBook'] as int?,
      collectionId: json['collectionId'] as String? ??
          json['collection_id'] as String? ??
          '',
      bookNumber: json['b'] as int? ??
          json['bookNumber'] as int? ??
          json['book_number'] as int? ??
          json['book'] as int? ??
          0,
      textArabic: textArabic,
      textEnglish: textEnglish,
      textUrdu: json['textUrdu'] as String? ?? json['text_urdu'] as String?,
      narratorChainArabic: (ap != null && ap.isNotEmpty) ? ap : null,
      narratorChainEnglish: (ep != null && ep.isNotEmpty) ? ep : null,
      narratorPostfixArabic: (apf != null && apf.isNotEmpty) ? apf : null,
      narratorPostfixEnglish: (epf != null && epf.isNotEmpty) ? epf : null,
      matnArabic: (a != null && a.isNotEmpty) ? a : null,
      matnEnglish: (e != null && e.isNotEmpty) ? e : null,
      narrator: json['narrator'] as String? ?? json['rawi'] as String?,
      grade: (json['ge'] ?? json['grade'] ?? json['authenticity']) as String?,
      gradeArabic: (json['ga'] ?? json['grade_arabic'] ?? json['gradeArabic'])
          as String?,
      commentsEnglish:
          (json['ce'] ?? json['comments_english']) as String?,
      commentsArabic: (json['ca'] ?? json['comments_arabic']) as String?,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>(),
      chapterId: json['ch'] as int? ?? json['chapter_id'] as int?,
      chapterTitle: json['chapterTitle'] as String? ??
          json['chapter_title'] as String?,
      chapterTitleArabic: json['chapterTitleArabic'] as String? ??
          json['chapter_title_arabic'] as String?,
      narratorIds: narratorIds,
      reference: json['ref'] as String? ??
          json['reference'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hadith_number': hadithNumber,
      'display_number': displayNumber,
      'hadith_number_in_book': hadithNumberInBook,
      'collection_id': collectionId,
      'book_number': bookNumber,
      'text_arabic': textArabic,
      'text_english': textEnglish,
      'text_urdu': textUrdu,
      'narrator_chain_arabic': narratorChainArabic,
      'narrator_chain_english': narratorChainEnglish,
      'matn_arabic': matnArabic,
      'matn_english': matnEnglish,
      'narrator': narrator,
      'grade': grade,
      'grade_arabic': gradeArabic,
      'chapter_id': chapterId,
      'chapter_title': chapterTitle,
      'chapter_title_arabic': chapterTitleArabic,
      'narrator_ids': narratorIds,
      'reference': reference,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Hadith && other.uniqueId == uniqueId;
  }

  @override
  int get hashCode => uniqueId.hashCode;

  @override
  String toString() => 'Hadith($uniqueId: ${arabicPreview})';
}

/// Search result for hadith queries
class HadithSearchResult {
  final Hadith hadith;
  final String? collectionName;
  final String? bookName;
  final String? highlightedArabic;
  final String? highlightedEnglish;
  final int matchStartIndex;
  final int matchLength;

  const HadithSearchResult({
    required this.hadith,
    this.collectionName,
    this.bookName,
    this.highlightedArabic,
    this.highlightedEnglish,
    this.matchStartIndex = 0,
    this.matchLength = 0,
  });

  factory HadithSearchResult.fromJson(Map<String, dynamic> json) {
    return HadithSearchResult(
      hadith: Hadith.fromJson(json['hadith'] as Map<String, dynamic>),
      collectionName: json['collection_name'] as String? ??
          json['collectionName'] as String?,
      bookName: json['book_name'] as String? ??
          json['bookName'] as String?,
      highlightedArabic: json['highlighted_arabic'] as String? ??
          json['highlightedArabic'] as String?,
      highlightedEnglish: json['highlighted_english'] as String? ??
          json['highlightedEnglish'] as String?,
      matchStartIndex: json['match_start_index'] as int? ?? 0,
      matchLength: json['match_length'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hadith': hadith.toJson(),
      'collection_name': collectionName,
      'book_name': bookName,
      'highlighted_arabic': highlightedArabic,
      'highlighted_english': highlightedEnglish,
      'match_start_index': matchStartIndex,
      'match_length': matchLength,
    };
  }
}

// ── JSON List Parsers ─────────────────────────────────────────────

List<HadithCollection> parseCollectionList(String jsonString) {
  final List<dynamic> decoded = json.decode(jsonString);
  return decoded
      .map((item) => HadithCollection.fromJson(item as Map<String, dynamic>))
      .toList();
}

List<HadithBook> parseBookList(String jsonString) {
  final List<dynamic> decoded = json.decode(jsonString);
  return decoded
      .map((item) => HadithBook.fromJson(item as Map<String, dynamic>))
      .toList();
}

List<Hadith> parseHadithList(String jsonString) {
  final List<dynamic> decoded = json.decode(jsonString);
  return decoded
      .map((item) => Hadith.fromJson(item as Map<String, dynamic>))
      .toList();
}

List<HadithSearchResult> parseHadithSearchResults(String jsonString) {
  final List<dynamic> decoded = json.decode(jsonString);
  return decoded
      .map((item) => HadithSearchResult.fromJson(item as Map<String, dynamic>))
      .toList();
}
