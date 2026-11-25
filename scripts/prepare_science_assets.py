#!/usr/bin/env python3
"""
Bismillah: Build compact gzip Qur'an science assets:
  1. tafseer_<id>.json.gz  - from spa5k/tafsir_api sparse clone
  2. tajweed.json.gz       - from quran/quran-tajweed output
  3. nawawi40.json.gz      - supplement from fawazahmed0/hadith-api
Provenance documented in docs/DATA_PROVENANCE.md.
"""
import gzip
import json
import os
import sys
import urllib.request
import urllib.error

APP = "/home/z/my-project/Quran_Hadith-App_gl3fn"
SC = os.path.join(APP, "assets/data/quran_science")
TAFSIR_SRC = "/home/z/my-project/refs/tafsir_api/tafsir"
TAJWEED_SRC = "/home/z/my-project/refs/quran-tajweed/output/tajweed.hafs.uthmani-pause-sajdah.json"

TAFSIR_EDITIONS = [
    ("en-tafisr-ibn-kathir", "ibn_kathir_en", "Tafsir Ibn Kathir (English)",
     "Tafseer Ibn Kaseer (Abridged) - compiled from tafsir.app", "en"),
    ("ar-tafsir-ibn-kathir", "ibn_kathir_ar", "تفسير ابن كثير",
     "Tafsir Ibn Kathir (Arabic full) - tafsir.app", "ar"),
    ("ar-tafsir-muyassar", "muyassar_ar", "التفسير الميسر",
     "King Fahd Complex simplified tafsir - tafsir.app", "ar"),
    ("en-al-jalalayn", "jalalayn_en", "Tafsir Al-Jalalayn (English)",
     "Tafsir Al-Jalalayn English - tafsir.app", "en"),
    ("ar-tafsir-al-jalalayn", "jalalayn_ar", "تفسير الجلالين",
     "Tafsir Al-Jalalayn Arabic - tafsir.app", "ar"),
    ("ar-tafsir-as-saadi", "saadi_ar", "تيسير الكريم الرحمن (السعدي)",
     "Taysir al-Karim ar-Rahman - tafsir.app", "ar"),
]


def clean(t):
    if t is None:
        return ""
    return str(t).replace("\r\n", "\n").strip()


def load_edition_surah(src_dir, surah):
    """Load one surah's tafsir, normalizing all known source shapes:
    1) [text, text, ...] indexed by ayah
    2) {"ayahs": [{"ayah": n, "surah": s, "text": ...}]}
    3) <surah>/<ayah>.json per-ayah files with {"surah","ayah","text"}"""
    p = os.path.join(src_dir, f"{surah}.json")
    out = {}
    if os.path.exists(p):
        with open(p, encoding="utf-8") as f:
            obj = json.load(f)
        if isinstance(obj, list):
            for idx, text in enumerate(obj):
                out[f"{surah}:{idx+1}"] = clean(text)
            return out
        if isinstance(obj, dict):
            arr = obj.get("ayahs")
            if isinstance(arr, list):
                for it in arr:
                    out[f"{it['surah']}:{it['ayah']}"] = clean(it.get("text"))
                return out
    subdir = os.path.join(src_dir, str(surah))
    if os.path.isdir(subdir):
        for fname in os.listdir(subdir):
            if not fname.endswith(".json"):
                continue
            with open(os.path.join(subdir, fname), encoding="utf-8") as f:
                obj = json.load(f)
            if isinstance(obj, dict) and "text" in obj:
                out[f"{obj.get('surah', surah)}:{obj.get('ayah', fname[:-5])}"] = \
                    clean(obj["text"])
    return out


def build_tafseer():
    index = []
    for src_id, out_id, name, provenance, lang in TAFSIR_EDITIONS:
        src_dir = os.path.join(TAFSIR_SRC, src_id)
        if not os.path.isdir(src_dir):
            print(f"WARN: missing tafsir dir {src_dir}", file=sys.stderr)
            continue
        data = {}
        for surah in range(1, 115):
            data.update(load_edition_surah(src_dir, surah))
        payload = json.dumps(data, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
        out = os.path.join(SC, f"tafsir_{out_id}.json.gz")
        with open(out, "wb") as f:
            f.write(gzip.compress(payload, compresslevel=9))
        index.append({"id": out_id, "name": name, "lang": lang,
                      "provenance": provenance,
                      "ayahs": len(data),
                      "sizeKB": round(os.path.getsize(out) / 1024)})
        print(f"tafsir_{out_id}: {len(data)} ayahs, {os.path.getsize(out)/1048576:.2f}MB")
    with open(os.path.join(SC, "tafseer_index.json"), "w", encoding="utf-8") as f:
        json.dump(index, f, ensure_ascii=False, separators=(",", ":"))


def build_tajweed():
    with open(TAJWEED_SRC, encoding="utf-8") as f:
        raw = json.load(f)
    data = {}
    for entry in raw:
        key = f"{entry['surah']}:{entry['ayah']}"
        data[key] = [[a["start"], a["end"], a["rule"]] for a in entry.get("annotations", [])]
    payload = json.dumps(data, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    out = os.path.join(SC, "tajweed.json.gz")
    with open(out, "wb") as f:
        f.write(gzip.compress(payload, compresslevel=9))
    print(f"tajweed: {len(data)} ayahs, {os.path.getsize(out)/1048576:.2f}MB")


def build_nawawi():
    """Fetch An-Nawawi 40 from fawazahmed0/hadith-api (nawawi collection)."""
    UA = {"User-Agent": "Minhaajulhudaa-DataPrep/1.0"}
    ar_urns, en_map = [], {}
    try:
        url = "https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions/ara-nawawi/sections/1.min.json"
        req = urllib.request.Request(url, headers=UA)
        with urllib.request.urlopen(req, timeout=60) as r:
            ar = json.loads(r.read().decode("utf-8"))
        url2 = "https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions/eng-nawawi/sections/1.min.json"
        req = urllib.request.Request(url2, headers=UA)
        with urllib.request.urlopen(req, timeout=60) as r:
            en = json.loads(r.read().decode("utf-8"))
    except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError) as e:
        print(f"WARN: nawawi fetch failed: {e}", file=sys.stderr)
        return
    ar_h = ar["hadiths"]
    en_h = en["hadiths"]
    en_by_num = {h["hadithnumber"]: h for h in en_h}
    hadiths = []
    for h in ar_h:
        num = h["hadithnumber"]
        eh = en_by_num.get(num, {})
        arabic = clean(h["text"])
        english = clean(eh.get("text", ""))
        hadiths.append({
            "u": f"nawawi40_{num}",
            "n": str(num),
            "b": 1, "ch": None,
            "ap": "", "a": arabic, "apf": "",
            "ga": clean(h.get("grades", [{}])[0].get("grade", "")) if h.get("grades") else "",
            "ep": "", "e": english, "epf": "",
            "ge": clean(eh.get("grades", [{}])[0].get("grade", "")) if eh.get("grades") else "",
            "ref": clean(eh.get("reference", {}).get("hadith", [""])[0] if isinstance(eh.get("reference", {}).get("hadith", []), list) and eh.get("reference", {}).get("hadith") else ""),
        })
    payload = {"id": 101, "key": "nawawi40", "books": [], "chapters": [], "hadiths": hadiths}
    raw = json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    out = os.path.join(APP, "assets/data/hadith/v2/nawawi40.json.gz")
    with open(out, "wb") as f:
        f.write(gzip.compress(raw, compresslevel=9))
    print(f"nawawi40: {len(hadiths)} hadiths, {os.path.getsize(out)/1024:.0f}KB")


if __name__ == "__main__":
    build_tafseer()
    build_tajweed()
    build_nawawi()
    print("SCIENCE_ASSETS_DONE")
