# Worklog

Every agent MUST read this file before starting and append an entry after
finishing each Task ID. Never overwrite prior entries.

---

## 2026-11-25 — Session 2 (data corpora + data layer + toolchain lockstep)

- Sandbox was recycled mid-session; repo and Flutter rebuilt from remote
  (protocol push-verification proved its worth: baseline commit `011eca2`
  was intact on GitHub).
- Real offline corpora extracted and bundled (all counts verified):
  - Hadith v2: 16 collections, 50,508 hadiths (Arabic + English), 601 books,
    15,305 chapters, 25,260 scholars (npm `hadith` v1.3.0 SQLite dump).
  - Nawawi 40 supplemented from fawazahmed0/hadith-api (source DB lacked it).
  - Word-by-word sciences: all 114 surahs validated against /chapters
    endpoint (sum 6236); word translation + transliteration + exact Madani
    page/line per word; 604-page start table + per-surah page ranges
    (quran.com API v4). wbw.json.gz = 0.94MB.
  - Morphology: Quranic Arabic Corpus v0.4 — 77,429 words with root/lemma/
    POS/features; 1,651 roots indexed for root exploration.
  - Tajweed: letter-level annotations for all 6236 ayahs (quran/quran-tajweed).
  - Tafseer: 6 editions (Ibn Kathir EN 3.96MB/AR 9.2MB, Muyassar AR,
    Jalalayn EN/AR, Sa'di AR) — spa5k/tafsir_api; multi-format loader.
- `lib/data/repositories/hadith_repository.dart` rewritten for v2 gzip
  corpus: isolate decode, bounded LRU (2 collections), chapter enrichment,
  scholars, diacritic-insensitive search; models extended (HadithChapter,
  HadithScholar, isnad parts, narrator ids).
- `lib/data/repositories/quran_science_repository.dart` added: single loader
  for WBW + tajweed + morphology + root index + tafseer editions + page
  metadata.
- Old stub hadith assets deleted; pubspec updated (archive dep, v2 dirs);
  app_constants updated (16 collections, v2 paths, ghost entries fixed).
- Toolchain: local + CI now Flutter 3.50.1; analyze errors 28 → 0
  (DialogTheme/CardTheme/TabBarTheme → *ThemeData, Cupertino import,
  RepeatMode ambiguity).
- docs/DATA_PROVENANCE.md documents every dataset source + schema.

## 2026-11-25 — Session 1 (setup, audit, protocol)

- Cloned `ridwanullahh/Quran_Hadith-App` and pushed `main` to the dedicated
  repo `ridwanullahh/Quran_Hadith-App_gl3fn` (baseline commit
  `1365d25f257f571f13829185e6801cca5394d869`).
- Strengthened `Core_Working_Protocol.md` (14 binding discipline rules).
- Installed Flutter 3.50.1 stable locally (`/home/z/my-project/tools/flutter`).
- Set GitHub Actions secrets on the dedicated repo: `PAT_TOKEN`,
  `SIGNING_KEYSTORE_BASE64`, `SIGNING_STORE_PASSWORD`, `SIGNING_KEY_PASSWORD`,
  `SIGNING_KEY_ALIAS` (stable release keystore generated once, stored outside
  the repo; same key signs every release so OTA installs update cleanly).
- Full codebase audit completed (see `docs/AUDIT.md`). Baseline
  `flutter analyze`: 28 errors, 82 warnings, 1266 infos — errors are Flutter
  3.50 breaking changes in `app_theme.dart` (DialogTheme/CardTheme/TabBarTheme)
  plus missing cupertino import; CI workflow still pins Flutter 3.24.3 and
  must be moved to 3.50.1 in lockstep.
- Generated implementation roadmap (see `docs/IMPLEMENTATION_ROADMAP.md`) —
  the tracking file for all tasks/subtasks/sub-subtasks.
- No "lightbase API docs" found anywhere in the repo (searched all files for
  "lightbase"/"api docs"); closest reference material is the BirrJS repo
  (https://github.com/ridwanullahh/Quran_Hadith-BirrJS) whose extraction
  pipeline (`scripts/extract-all-hadith.cjs`) and 16-collection gzip corpus
  (14 MB) serve as the hadith data-compression reference.
