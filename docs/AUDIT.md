# Codebase Audit — Minhaajulhudaa (2026-11-25)

> Baseline: commit `1365d25` · Flutter 3.50.1 local / 3.24.3 CI · 61 routes,
> ~59.5k lines of Dart across `lib/`.

## 1. Qur'an Module

### 1.1 Word-by-word / Ayah "empty bottom sheet" (root causes)

1. `assets/data/quran_wbw.json` (1.5 MB) contains ONLY bare Arabic word
   strings (`{"1":{"1":["بِسْمِ","ٱللَّهِ",...]}}`). Every sciences field the
   UI displays — transliteration, translation, root letters, related root
   words, part of speech, morphology, grammar note, occurrences — is absent
   from the asset.
2. `quran_repository.dart:399-410` builds `WordData` with
   `textTransliteration: ''` and all analysis fields null — no enrichment
   path exists. `word_detail_sheet.dart:255-294` renders sections only for
   non-empty fields, so expanding any word shows only
   `_buildComingSoonMessage` (`word_detail_sheet.dart:640-667`).
3. There is no per-word tap detection in reading text — `ayah_widget.dart`
   renders each ayah as one plain `Text` with no `TextSpan` recognizers.
4. Tafseer is entirely unimplemented: `quran_repository.dart:325-337`
   returns an empty list; no tafseer assets exist; `TafseerScreen` always
   shows "not yet loaded"; the reading-screen tafseer toggle never renders.
5. Verified NOT causes: absolute-ayah mapping correct (all 6236), provider
   scoping correct, assets registered, ayah counts consistent across files.

### 1.2 Mushaf mode defects

- `_madaniPageStarts` (`mushaf_provider.dart:17-19`) is an approximation:
  page 2 starts at 2:4 (real: 2:6); only 9 surahs beyond Al-Fatihah ever
  start a page; `[96,1]`, `[97,1]`, `[67,1]` missing; surah headers render
  on ~9 of ~88 pages where they should.
- `AppConstants.juzBreakdown` has 31 entries for 30 juz (extra `{22,39}`;
  wrong starts 6:151, 36:23) → "Juz 31" badges, surahs 78-114 unreachable
  via juz navigation.
- Bismillah duplicated: asset merges bismillah into ayah 1 of surahs 2-114
  (except 9) while both mushaf (`mushaf_screen.dart:336-356`) and reading
  screen (`surah_reading_screen.dart:425-461`) prepend another banner.
- Tajweed overlay is whole-word heuristics (`tajweed_overlay.dart`):
  cross-word rules (ikhfa/iqlab/idgham/izhhar) misclassified because analysis
  is per-word; izhhar letter set covers almost the whole alphabet; no
  letter-level spans; no madd duration classes; no waqf rendering.
- Ayah badges use Latin digits; no corner page medallion; pages are
  vertical-scrolling columns, not fixed 15-line layouts.

### 1.3 Reading mode bugs

- Sajdah hardcoded false (`quran_repository.dart:167`); `getAyahsByPage`
  always returns [] (`page: null`).
- "Play from Last Read" computes the start ayah but always plays from the
  beginning (`surah_actions_sheet.dart:68-89`).
- Non-English translations unsupported (`quran_repository.dart:272-277`).

## 2. Hadith Module

### 2.1 Data reality

- Each of the 6 collections ships ONE stub file (`001.json`, 2-6 KB) with
  37 total famous hadiths, fabricated numbering, mixed book metadata;
  Bukhari `books.json` declares book 2 but no `002.json` exists → error
  screen on tap. `collections.json` totals (7563/7470/...) are claims only.

### 2.2 Hardcoded data inventory (all to be removed/replaced)

| File | Contents |
|---|---|
| `hadith_collection_detail_screen.dart` | `_collections` map: bios + Kitab lists, conflicts with collections.json |
| `hadith_collection_overview_screen.dart` | 6 entries + fabricated QuickStats |
| `narrator_screen.dart` | 22 narrator bios |
| `hadith_chain_narrators_screen.dart` | 13 narrators (overlaps above) |
| `hadith_of_day_screen.dart` | 65-entry daily pool |
| `hadith_random_screen.dart` | 21-entry random pool |
| `hadith_comparison_screen.dart` | 6 comparison groups |
| `hadith_glossary_screen.dart` | 24 glossary entries |
| `hadith_topics_screen.dart` | 12 topics with references to nonexistent data |
| `hadith_isnad_visualizer_screen.dart` | 5 sample isnads |
| `grading_screen.dart` | educational copy (acceptable static content) |
| `hadith_bookmark_folders_screen.dart` | `_addSampleBookmark()` demo action |
| `hadith_study_planner_screen.dart` | hardcoded collection ids, `endBook=7` default |
| `popup_service.dart` | 25 verses + 25 hadiths |
| `app_constants.dart:303-312` | ghost `'malik'` entry, `totalHadithCollections = 7` |

- Search: linear in-memory scan, diacritic-sensitive (bare-letter Arabic
  queries return nothing), unbounded caches, 50-result cap.
- `hadith_history_provider.dart` is dead code (no consumers).

## 3. Hifdh / Popup / OTA / Shell

### 3.1 Hifdh

- Probable hang #1: dashboard spinner has no timeout —
  `hifzhStatsProvider` awaits 5 sqflite calls; a stalled future = eternal
  spinner with no error path (`hifdh_dashboard_screen.dart:42-45`).
- Probable hang #2: 1.4 MB `json.decode` of `quran_uthmani.json` on the main
  isolate when starting a test (`quran_repository.dart:29-37`), repeated
  because `hifdhQuranRepoProvider` rebuilds discard caches.
- Listen mode has NO audio (`hifdh_test_screen.dart:735-813`).
- Revision scheduling backend (`scheduleRevision`, `getPendingRevisions`,
  ...) has zero UI callers; Revision History button is dead UI; mistakes
  stream orders by nonexistent `logged_at` column (`database.dart:123`) and
  always emits [].
- `HifdhTestState.copyWith` wipes `finalResult` on every copy
  (`hifdh_providers.dart:313`).

### 3.2 Periodic popup

- `showDialog` is called with the `PopupOverlay` context created in
  `MaterialApp.builder` — ABOVE the Navigator — so it throws every cycle and
  popups never display; `_recordShownTime()` persists before showing, so the
  failure repeats silently (`popup_service.dart:486-502`, `app.dart:54-59`).
- Content: 25+25 hardcoded strings, disconnected from real corpora.
- Notification plugin `initialize` is unawaited before `zonedSchedule`
  (`notification_provider.dart:84-93`).

### 3.3 OTA update

- `REQUEST_INSTALL_PACKAGES` missing from AndroidManifest → installer can
  never launch on Android 8+ (targetSdk 35).
- Startup auto-check runs in a detached `ProviderContainer` (`main.dart:91-95`)
  — its state is invisible to the UI.
- Update check hits the OLD repo URL (`update_provider.dart:124-125`).
- Version drift: gradle env version vs pubspec vs hardcoded settings tile.
- Loose APK asset matching, no checksum verification, no retry.

### 3.4 Shell / settings

- Tab highlight falls back to Quran for More-section routes;
  `debugLogDiagnostics: true` leaks in release; darkTheme set to light theme
  in light mode (`app.dart:46-48`).
- Dead settings controls: Arabic font size, translation language, default
  reciter (key mismatch `default_reciter` vs `default_reciter_id`), audio
  quality. Version tile hardcoded.

## 4. Android build

- applicationId `com.minhaajulhudaa.quran`; minSdk 21, target/compile 35;
  AGP 8.5.0, Kotlin 1.9.22, Gradle 8.9 — compatible with Flutter 3.50.
- Release signing fails hard without `key.properties` (no debug fallback) —
  CI must always provide it (secrets now set).
- Fat APK (3 ABIs) → size reduction must come from ABI splits + data
  compression.

## 5. Priority fix order

1. Toolchain lockstep (CI → Flutter 3.50.1) + analyze errors to zero.
2. Data acquisition: hadith corpus (16 collections), WBW sciences, tafseer,
   tajweed annotations, exact mushaf page table, sajdah + page metadata.
3. Hadith v2 data layer + hardcoded-data removal + search rework.
4. Word/ayah sciences bottom sheets (reading + mushaf) with real data.
5. Mushaf rebuild (real page boundaries, headers, Arabic numerals, letter
   tajweed, zoom).
6. Hifdh hang fix + revision schedule UI + audio listen mode + goals/heatmap.
7. Popup navigator fix + data-driven content; notification init await.
8. OTA fixes (manifest, repo URL, startup hook, checksum, version source).
9. UI/UX polish pass + settings wiring.
10. APK size reduction (splits, tree-shake, asset compression) + release.
