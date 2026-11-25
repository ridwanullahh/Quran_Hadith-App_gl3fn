# Data Provenance & Schema Documentation

Every bundled dataset in this app is real, verifiable, and fully offline.
This file records the source, edition, and exact asset schema for each
corpus so future agents never fabricate data.

## 1. Qur'an text

- `assets/data/quran_uthmani.json` — Uthmani (Hafs) text, 6236 ayahs.
  Source: Tanzil.net Uthmani text (verified exact against quran.com corpus).
- `assets/data/surah_info.json` — 114 surah metadata.
- `assets/data/quran_en_translation.json` — English translation (Saheeh
  International).

## 2. Word-by-word sciences — `assets/data/quran_science/wbw.json.gz`

- Source: quran.com API v4 `verses/by_chapter/{1..114}?words=true`
  (QUL-derived word corpus, Fadel Alsolaimi segmentation; fetched 2026-11-25).
- Counts validated against the API `/chapters` endpoint; sum = 6236.
- Schema (gzip JSON):
  - `w` : `{"<s>:<a>": [["uthmaniText","transliteration","englishTranslation"], ...]}`
    — `char_type_name == "word"` entries only (punctuation marks excluded).
  - `p` : `{"<s>:<a>": [pageNumberPerWord, ...]}` — Madani page of each word.
  - `l` : `{"<s>:<a>": [lineNumberPerWord, ...]}` — line on that page (1-15).
  - `v` : `{"<s>:<a>": {"p":page,"j":juz,"h":hizb,"r":ruku,"saj":0|1}}` —
    verse-level metadata (sajdah marker included).
- `assets/data/quran_science/page_starts.json` — derived exact
  page→first-ayah table for all 604 Madani pages.

## 3. Tafseer — `assets/data/quran_science/tafsir_<id>.json.gz`

- Source: spa5k/tafsir_api (tafsir.app editions; fetched 2026-11-25).
- Editions shipped (`tafseer_index.json` lists id/name/lang):
  - `ibn_kathir_en` — Tafsir Ibn Kathir (abridged English)
  - `ibn_kathir_ar` — Tafsir Ibn Kathir (Arabic)
  - `muyassar_ar` — At-Tafsir Al-Muyassar (King Fahd Complex)
  - `jalalayn_en` / `jalalayn_ar` — Tafsir Al-Jalalayn
  - `saadi_ar` — Taysir al-Karim ar-Rahman (As-Sa'di)
- Schema: `{"<s>:<a>": "tafseer text"}`.

## 4. Tajweed annotations — `assets/data/quran_science/tajweed.json.gz`

- Source: github.com/quran/quran-tajweed
  (`output/tajweed.hafs.uthmani-pause-sajdah.json`, letter-level rules for
  Hafs Uthmani text; fetched 2026-11-25).
- Schema: `{"<s>:<a>": [[start,end,"ruleName"], ...]}` — character offsets
  into the Uthmani ayah string. Rule names include hamzat_wasl,
  lam_shamsiyyah/lam_qamariyyah, madd_2/madd_246/madd_6, ikhafa, iqlab,
  idgham_*, izhar, ghunnah, qalqalah, slnt, etc.

## 5. Hadith corpus v2 — `assets/data/hadith/v2/`

- Source: npm package `hadith` v1.3.0 SQLite dump (sunnah.com dataset,
  Abdul Haq compilation; fetched 2026-11-25 via registry.npmjs.org).
- 16 collections, 50,508 Arabic hadiths, 50,495 English translations,
  601 books, 15,305 chapters, 25,260 scholars. Real numbering per each
  collection's numbering scheme (recorded per collection in
  `collections.json.numberingNote`).
- `collections.json` — array of collection metadata
  (`id,key,name,nameAr,type,status,author,authorAr,authorDeath,
  totalHadiths,totalBooks,hasBooks,hasChapters,introduction,numberingNote`).
  `totalHadiths` is the ACTUAL extracted count.
- `<slug>.json.gz` — one gzip per collection:
  - `books`: `[{id,n,ar,en,s,e,c}]` (id = stable book id; n = display number;
    s/e/c = hadith start/end/count).
  - `chapters`: `[{id,b,n,ar,en,ia?,ie?}]` (b = book id; ia/ie = optional
    intro Arabic/English, e.g. Qur'anic support verses in Bukhari/Muslim).
  - `hadiths`: `[{u,n,b,ch,ap,a,apf,ga,ca?,ep?,e,epf?,ge?,ce?,ref?,ns?}]`
    - `u` urn, `n` display number (string), `b` book id, `ch` chapter id
    - `ap`/`a`/`apf` Arabic isnad prefix / matn / postfix
    - `ep`/`e`/`epf` English equivalents
    - `ga`/`ge` Arabic/English grading(s), `ca`/`ce` comments
    - `ref` full English reference, `ns` narrator scholar ids (int array)
- `nawawi40.json.gz` — An-Nawawi 40 (supplement; empty in source DB).
  Source: fawazahmed0/hadith-api v1 (ara-nawawi + eng-nawawi editions).
- `scholars.json.gz` — `[{i,n,k?,b?,d?,l?}]` narrator biographies
  (id, famous name, kunya, born, died, lived-in).

## 6. Audio

Recitation audio streams/downloads from mp3quran.net / islamic.network CDN
at runtime only (user-initiated); nothing fabricated offline.

## 7. Prayer times / Qibla

Computed locally from astronomical formulae bundled in-app (no fabricated
data); location via device GPS.
