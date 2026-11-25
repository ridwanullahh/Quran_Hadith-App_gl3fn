# Implementation Roadmap & Task Tracker

> This file is the live todo tracker. Update checkboxes at each milestone.
> Legend: [ ] pending · [~] in progress · [x] done · [!] blocked

## T1 — Toolchain & CI integrity

- [x] T1.1 Local Flutter 3.50.1 installed and verified
- [x] T1.2 GitHub secrets set (PAT_TOKEN, SIGNING_KEYSTORE_BASE64, passwords, alias)
- [ ] T1.3 Fix all `flutter analyze` errors (Flutter 3.50 API changes)
  - [ ] T1.3.1 `app_theme.dart` DialogTheme/CardTheme/TabBarTheme → *ThemeData
  - [ ] T1.3.2 CupertinoPageTransitionsBuilder import/const fixes
  - [ ] T1.3.3 Remaining errors to zero
- [ ] T1.4 CI workflow: Flutter 3.24.3 → 3.50.1, enable icon tree-shake attempt,
  keep stable signing flow; verify with a real tag release
- [ ] T1.5 `flutter build apk --debug` local green (Android SDK present)

## T2 — Data acquisition (all real, fully offline, provenance-documented)

- [ ] T2.1 Hadith corpus: 16 collections from the `hadith` npm SQLite DB
  - [ ] T2.1.1 Fetch/extract package DB
  - [ ] T2.1.2 Python extractor → per-collection gzipped compact JSON
    (`assets/data/hadith/v2/<id>.json.gz`), dictionary-encoded
  - [ ] T2.1.3 collections.json v2 metadata (16 collections)
  - [ ] T2.1.4 Data provenance doc entries
- [ ] T2.2 Word-by-word sciences dataset (per-word transliteration, meaning,
  root, POS, morphology) from a real source (QUL/corpus dumps)
- [ ] T2.3 Tafseer dataset (Ibn Kathir EN, Al-Jalalayn, Al-Muyassar, As-Sa'di
  as available) from tafsir_api
- [ ] T2.4 Letter-level tajweed annotation dataset (quran-tajweed)
- [ ] T2.5 Exact King Fahd 604-page start table + surah page ranges
- [ ] T2.6 Sajdah metadata + juz table correction data

## T3 — Hadith module rebuild

- [ ] T3.1 Hadith v2 repository (gzip assets, lazy per-collection load,
  isolate decode, bounded caches)
- [ ] T3.2 Search rework: Arabic normalization (strip tashkeel/hamza), index
  by collection, bounded memory
- [ ] T3.3 Remove ALL hardcoded collections/narrator/of-day/random/comparison/
  glossary/topics/isnad data; screens consume repository + new data assets
  - [ ] T3.3.1 Collection detail + overview from collections.json
  - [ ] T3.3.2 Of-day + random from full corpus (seeded deterministic)
  - [ ] T3.3.3 Narrators data file + screens rewired
  - [ ] T3.3.4 Topics reference real hadith coordinates
  - [ ] T3.3.5 Glossary/isnad/grader content into assets
  - [ ] T3.3.6 Remove sample bookmark demo, ghost constants, dead provider
- [ ] T3.4 16 collections visible, browsable, searchable, all screens functional
- [ ] T3.5 Hadith UX upgrades (frictionless reader, inline actions, share cards)

## T4 — Qur'an sciences bottom sheets (reading + mushaf)

- [ ] T4.1 Word model v2 + parser for enriched WBW dataset
- [ ] T4.2 Word detail sheet: transliteration, meaning, root, POS, morphology,
  occurrences, related root words — all populated
- [ ] T4.3 Per-word tap detection in reading mode (TextSpan recognizers)
- [ ] T4.4 Ayah action sheet (bookmark, note, share, play, tafseer, copy)
- [ ] T4.5 Tafseer screen + inline toggle driven by real tafseer assets
- [ ] T4.6 Same word-tap sciences inside Mushaf mode

## T5 — Mushaf Mode rebuild (King Fahd style)

- [ ] T5.1 Exact 604-page data + correct page boundaries
- [ ] T5.2 Surah headers on every page-top start; Arabic-Indic numerals;
  corner page medallion; sajdah markers; juz markers
- [ ] T5.3 Letter-level tajweed rendering from annotation data + legend
- [ ] T5.4 Bismillah dedup + juz table fix (app-wide)
- [ ] T5.5 Mushaf features: pinch/double-tap zoom, page jump grid, bookmark
  page, night mode, quick surah/page jump, share page, settings
- [ ] T5.6 Performance: page virtualization, smooth scrolling on low-end devices

## T6 — Hifdh room

- [ ] T6.1 Fix hang: DB timeout + retry + degrade path; isolate JSON decode;
  singleton repository
- [ ] T6.2 Revision schedule UI over existing backend; history screen wiring
- [ ] T6.3 Listen mode audio wired to real recitations
- [ ] T6.4 Hide/reveal ratio setting + per-ayah status picker
- [ ] T6.5 Goals, achievements, calendar heatmap, mistake log display fix
- [ ] T6.6 Per-surah test entry points; 100x richer feature set documented
  and implemented

## T7 — Periodic popup

- [ ] T7.1 Navigator fix (rootNavigatorKey context) — popups actually show
- [ ] T7.2 Data-driven content from real corpora (verse + hadith rotation)
- [ ] T7.3 Settings: interval, content type, quiet hours; notification init await

## T8 — OTA auto-update

- [ ] T8.1 REQUEST_INSTALL_PACKAGES + install flow end-to-end
- [ ] T8.2 Update check against the dedicated repo; startup hook in app scope
  + in-app banner
- [ ] T8.3 SHA256 verification, retry, download cancel
- [ ] T8.4 Version source unification (PackageInfo everywhere)

## T9 — UI/UX polish (all apps, no emojis)

- [ ] T9.1 Shell: tab highlight fix, transition tuning, RTL audit
- [ ] T9.2 Settings: wire dead controls (font size, translation language,
  reciter, audio quality), PackageInfo version
- [ ] T9.3 Consistent premium visuals per PRD palette; empty/error states
- [ ] T9.4 Haptics + micro-interactions on key actions

## T10 — APK size reduction

- [ ] T10.1 ABI-split release APKs (arm64 primary) + universal artifact
- [ ] T10.2 Icon tree-shaking / font pruning / asset audit
- [ ] T10.3 gzip-level data compression audit (hadith + quran assets)

## T11 — Security hardening

- [ ] T11.1 Manifest permission audit (least privilege), cleartext off
- [ ] T11.2 Input validation on user data (notes, search, backup import)
- [ ] T11.3 No secrets in code; update checks unauthenticated by default

## T12 — Verification & release

- [ ] T12.1 Flutter web build + browser-agent battle test of all major flows
- [ ] T12.2 Update TODO_TRACKER to reflect reality
- [ ] T12.3 Tag release, verify signed APK + checksums on the dedicated repo
- [ ] T12.4 Final audit delta note in worklog
