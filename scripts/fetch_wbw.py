#!/usr/bin/env python3
"""
Bismillah: Fetch word-by-word Qur'an data (translation + transliteration +
exact Madani page/line layout) from the quran.com API v4 for all 114 surahs,
then produce compact gzip assets for the Flutter app.

Output: assets/data/quran_science/wbw.json.gz
  {
    "w": {"1:1": [["بِسْمِ","bis'mi","In (the) name"], ...], ...},
    "p": {"1:1": [1,1,1,1,1], ...},          # word page numbers
    "l": {"1:1": [2,2,2,2,2], ...},          # word line numbers on page
    "v": {"1:1": {"p":1,"j":1,"h":1,"r":1,"saj":0}, ...}  # verse meta
  }
Provenance: quran.com API v4 (Fadel Alsolaimi corpus, QUL-derived), see
docs/DATA_PROVENANCE.md.
"""
import gzip
import json
import os
import sys
import time
import urllib.request
import urllib.error

OUT = "/home/z/my-project/Quran_Hadith-App_gl3fn/assets/data/quran_science"
RAW = "/home/z/my-project/refs/wbw_raw"
API = "https://api.quran.com/api/v4/verses/by_chapter/{n}?words=true&word_fields=text_uthmani,location&per_page=300"
UA = {"User-Agent": "Minhaajulhudaa-DataPrep/1.0 (offline Qur'an app; contact: repo owner)"}

# Authoritative ayah counts are fetched from the /chapters endpoint at runtime
# (single request) instead of a hand-maintained table, and cross-checked to
# total 6236 ayahs for the whole Qur'an.
EXPECTED_TOTAL = 6236


def fetch(url, retries=4):
    for attempt in range(retries):
        try:
            req = urllib.request.Request(url, headers=UA)
            with urllib.request.urlopen(req, timeout=60) as r:
                return json.loads(r.read().decode("utf-8"))
        except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError, json.JSONDecodeError) as e:
            print(f"  retry {attempt+1} for {url[:80]}: {e}", file=sys.stderr)
            time.sleep(2 * (attempt + 1))
    raise RuntimeError(f"Failed to fetch {url}")


def main():
    os.makedirs(RAW, exist_ok=True)
    os.makedirs(OUT, exist_ok=True)
    total_pages = set()

    chapters_meta = fetch("https://api.quran.com/api/v4/chapters?language=en")
    expected_counts = {c["id"]: c["verses_count"] for c in chapters_meta["chapters"]}
    assert sum(expected_counts.values()) == EXPECTED_TOTAL, "chapter counts do not sum to 6236"
    surah_pages = {c["id"]: c["pages"] for c in chapters_meta["chapters"]}
    print(f"chapter counts verified: sum={sum(expected_counts.values())}")

    for n in range(1, 115):
        raw_path = os.path.join(RAW, f"{n}.json")
        if os.path.exists(raw_path) and os.path.getsize(raw_path) > 100:
            with open(raw_path, encoding="utf-8") as f:
                data = json.load(f)
        else:
            data = fetch(API.format(n=n))
            with open(raw_path, "w", encoding="utf-8") as f:
                json.dump(data, f, ensure_ascii=False)
        verses = data.get("verses", [])
        if len(verses) != expected_counts[n]:
            print(f"MISMATCH surah {n}: got {len(verses)} expected {expected_counts[n]}", file=sys.stderr)
            os.remove(raw_path)
            raise SystemExit(f"Ayah count mismatch for surah {n}")
        print(f"surah {n}: {len(verses)} ayahs OK")
        time.sleep(0.35)
    print("FETCH_COMPLETE")

    # ── transform ─────────────────────────────────────────────────
    words, pages, lines, vmeta = {}, {}, {}, {}
    for n in range(1, 115):
        with open(os.path.join(RAW, f"{n}.json"), encoding="utf-8") as f:
            verses = json.load(f)["verses"]
        for v in verses:
            key = f"{n}:{v['verse_number']}"
            w_list, p_list, l_list = [], [], []
            for w in v.get("words", []):
                if w.get("char_type_name") != "word":
                    continue
                w_list.append([
                    w.get("text_uthmani", ""),
                    w.get("transliteration", {}).get("text", ""),
                    w.get("translation", {}).get("text", ""),
                ])
                p_list.append(w.get("page_number", 1))
                l_list.append(w.get("line_number", 1))
            words[key] = w_list
            pages[key] = p_list
            lines[key] = l_list
            vmeta[key] = {
                "p": v.get("page_number", 1),
                "j": v.get("juz_number", 1),
                "h": v.get("hizb_number", 1),
                "r": v.get("ruku_number", 1),
                "saj": 1 if v.get("sajdah_number") else 0,
            }
            total_pages.add(v.get("page_number", 1))

    payload = {"w": words, "p": pages, "l": lines, "v": vmeta}
    raw = json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    out_path = os.path.join(OUT, "wbw.json.gz")
    with open(out_path, "wb") as f:
        f.write(gzip.compress(raw, compresslevel=9))

    # ── page start table validation ───────────────────────────────
    page_starts = {}
    for n in range(1, 115):
        with open(os.path.join(RAW, f"{n}.json"), encoding="utf-8") as f:
            verses = json.load(f)["verses"]
        for v in verses:
            pg = v.get("page_number", 1)
            if pg not in page_starts:
                page_starts[pg] = f"{n}:{v['verse_number']}"
    print(f"pages covered: {len(total_pages)} (max {max(total_pages)})")
    print(f"page starts: {len(page_starts)} entries")
    print(f"wbw.json.gz: {os.path.getsize(out_path)/1048576:.2f}MB (raw {len(raw)/1048576:.1f}MB)")
    with open(os.path.join(OUT, "page_starts.json"), "w", encoding="utf-8") as f:
        json.dump({str(k): v for k, v in sorted(page_starts.items())}, f, ensure_ascii=False, separators=(",", ":"))
    with open(os.path.join(OUT, "surah_pages.json"), "w", encoding="utf-8") as f:
        json.dump({str(k): v for k, v in sorted(surah_pages.items())}, f, ensure_ascii=False, separators=(",", ":"))
    print("TRANSFORM_COMPLETE")


if __name__ == "__main__":
    main()
