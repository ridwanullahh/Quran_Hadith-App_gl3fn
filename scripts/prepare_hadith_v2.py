#!/usr/bin/env python3
"""
Bismillah: Extract all 16 hadith collections from the `hadith` npm package
SQLite DB into compact gzip-per-collection JSON assets for the Flutter app.

Output (assets/data/hadith/v2/):
  collections.json   - 16 collection metadata entries (real counts)
  <slug>.json.gz     - {"id","key","books":[...],"chapters":[...],"hadiths":[...]}
  scholars.json.gz   - 25k narrator/scholar bios for isnad features

Provenance: npm package `hadith` v1.3.0 (sunnah.com dataset dump), see
docs/DATA_PROVENANCE.md.
"""
import gzip
import json
import os
import re
import sys

DB = "/home/z/my-project/refs/hadith-pkg/package/data/hadith.db"
OUT = "/home/z/my-project/Quran_Hadith-App_gl3fn/assets/data/hadith/v2"

# (db_id, slug, name, name_ar, type, author_en, author_ar, author_death)
COLLECTIONS = [
    (1, "bukhari", "Sahih al-Bukhari", "صحيح البخاري", "collection",
     "Imam Muhammad ibn Ismail al-Bukhari", "الإمام محمد بن إسماعيل البخاري", "256 AH"),
    (2, "muslim", "Sahih Muslim", "صحيح مسلم", "collection",
     "Imam Muslim ibn al-Hajjaj al-Naysaburi", "الإمام مسلم بن الحجاج النيسابوري", "261 AH"),
    (3, "nasai", "Sunan an-Nasa'i", "سنن النسائي", "collection",
     "Imam Ahmad ibn Shu'ayb an-Nasa'i", "الإمام أحمد بن شعيب النسائي", "303 AH"),
    (10, "abudawud", "Sunan Abi Dawud", "سنن أبي داود", "collection",
     "Imam Sulayman ibn al-Ash'ath as-Sijistani", "الإمام سليمان بن الأشعث السجستاني", "275 AH"),
    (30, "tirmidhi", "Jami' at-Tirmidhi", "جامع الترمذي", "collection",
     "Imam Muhammad ibn Isa at-Tirmidhi", "الإمام محمد بن عيسى الترمذي", "279 AH"),
    (38, "ibnmajah", "Sunan Ibn Majah", "سنن ابن ماجه", "collection",
     "Imam Muhammad ibn Yazid Ibn Majah", "الإمام محمد بن يزيد ابن ماجه", "273 AH"),
    (40, "malik", "Muwatta Malik", "موطأ مالك", "collection",
     "Imam Malik ibn Anas", "الإمام مالك بن أنس", "179 AH"),
    (50, "ahmad", "Musnad Ahmad", "مسند أحمد", "collection",
     "Imam Ahmad ibn Hanbal", "الإمام أحمد بن حنبل", "241 AH"),
    (101, "nawawi40", "An-Nawawi's 40 Hadith", "الأربعون النووية", "selection",
     "Imam Yahya ibn Sharaf an-Nawawi", "الإمام يحيى بن شرف النووي", "676 AH"),
    (102, "forty", "Collections of Forty", "الأربعينات", "selection",
     "Various scholars", "مختلف العلماء", None),
    (110, "riyad", "Riyad as-Salihin", "رياض الصالحين", "selection",
     "Imam Yahya ibn Sharaf an-Nawawi", "الإمام يحيى بن شرف النووي", "676 AH"),
    (113, "mishkat", "Mishkat al-Masabih", "مشكاة المصابيح", "selection",
     "Imam Khatib at-Tabrizi", "الإمام الخطيب التبريزي", "741 AH"),
    (115, "adab", "Al-Adab Al-Mufrad", "الأدب المفرد", "collection",
     "Imam Muhammad ibn Ismail al-Bukhari", "الإمام محمد بن إسماعيل البخاري", "256 AH"),
    (130, "shamail", "Ash-Shama'il Al-Muhammadiyah", "الشمائل المحمدية", "selection",
     "Imam Muhammad ibn Isa at-Tirmidhi", "الإمام محمد بن عيسى الترمذي", "279 AH"),
    (200, "bulugh", "Bulugh al-Maram", "بلوغ المرام", "collection",
     "Imam Ibn Hajar al-Asqalani", "الإمام ابن حجر العسقلاني", "852 AH"),
    (300, "hisn", "Hisn al-Muslim", "حصن المسلم", "selection",
     "Sa'id ibn Ali ibn Wahf al-Qahtani", "سعيد بن علي بن وهف القحطاني", None),
]


def clean(s):
    """Normalize whitespace in DB text; strip HTML tags used in intros."""
    if s is None:
        return ""
    s = str(s)
    s = s.replace("\r\n", "\n").replace("\r", "\n")
    s = s.replace("<br>", "\n").replace("<br/>", "\n").replace("<br />", "\n")
    s = re.sub(r"<[^>]+>", "", s)
    return s.strip()


def i(v):
    """DB stores some ids as floats; convert to int safely."""
    if v is None:
        return None
    try:
        return int(float(v))
    except (ValueError, TypeError):
        return None


def main():
    os.makedirs(OUT, exist_ok=True)
    import sqlite3
    con = sqlite3.connect(DB)
    con.row_factory = sqlite3.Row
    cur = con.cursor()

    db_collections = {}
    for r in cur.execute("SELECT * FROM collection"):
        db_collections[r["id"]] = r

    books_by_col = {}
    for r in cur.execute("SELECT * FROM book ORDER BY collection_id, order_in_collection"):
        books_by_col.setdefault(r["collection_id"], []).append(r)

    chapters_by_col = {}
    for r in cur.execute("SELECT * FROM chapter ORDER BY collection_id, book_id, number"):
        chapters_by_col.setdefault(r["collection_id"], []).append(r)

    print("Loading arabic hadiths...")
    ar_by_urn = {}
    for r in cur.execute("SELECT * FROM hadith"):
        ar_by_urn[r["urn"]] = r
    print("Loading english hadiths...")
    en_by_urn = {}
    for r in cur.execute("SELECT * FROM hadith_en"):
        en_by_urn[r["arabic_urn"]] = r

    collections_meta = []
    total_h = 0
    for cid, slug, name, name_ar, ctype, author, author_ar, death in COLLECTIONS:
        c = db_collections.get(cid)
        if c is None:
            print(f"WARN: collection {cid} missing in DB", file=sys.stderr)
            continue
        books = []
        for b in books_by_col.get(cid, []):
            books.append({
                "id": i(b["id"]),
                "n": b["display_number"],
                "ar": clean(b["title"]),
                "en": clean(b["title_en"]),
                "s": i(b["hadith_start"]),
                "e": i(b["hadith_end"]),
                "c": i(b["hadith_count"]),
            })
        chapters = []
        for ch in chapters_by_col.get(cid, []):
            entry = {
                "id": i(ch["id"]),
                "b": i(ch["book_id"]),
                "n": i(ch["number"]),
                "ar": clean(ch["title"]),
                "en": clean(ch["title_en"]),
            }
            intro = clean(ch["intro"])
            intro_en = clean(ch["intro_en"])
            if intro:
                entry["ia"] = intro
            if intro_en:
                entry["ie"] = intro_en
            chapters.append(entry)
        hadiths = []
        for r in cur.execute(
            "SELECT * FROM hadith WHERE collection_id=? ORDER BY book_id, order_in_book", (cid,)
        ):
            urn = r["urn"]
            e = en_by_urn.get(urn)
            ns = []
            if r["narrators"]:
                try:
                    ns = [i(x) for x in str(r["narrators"]).split(",") if x.strip()]
                    ns = [x for x in ns if x is not None]
                except Exception:
                    ns = []
            h = {
                "u": urn,
                "n": r["display_number"],
                "b": i(r["book_id"]),
                "ch": i(r["chapter_id"]),
                "ap": clean(r["narrator_prefix"]),
                "a": clean(r["content"]),
                "apf": clean(r["narrator_postfix"]),
                "ga": clean(r["grades"]),
            }
            if r["comments"]:
                h["ca"] = clean(r["comments"])
            if e:
                if e["narrator_prefix"]:
                    h["ep"] = clean(e["narrator_prefix"])
                h["e"] = clean(e["content"])
                if e["narrator_postfix"]:
                    h["epf"] = clean(e["narrator_postfix"])
                if e["grades"]:
                    h["ge"] = clean(e["grades"])
                if e["comments"]:
                    h["ce"] = clean(e["comments"])
                if e["reference"]:
                    h["ref"] = clean(e["reference"])
            if ns:
                h["ns"] = ns
            hadiths.append(h)

        total = len(hadiths)
        total_h += total
        meta = {
            "id": cid,
            "key": slug,
            "name": name,
            "nameAr": name_ar,
            "type": ctype,
            "status": c["status"] or "complete",
            "author": author,
            "authorAr": author_ar,
            "authorDeath": death,
            "totalHadiths": total,
            "totalBooks": len(books),
            "hasBooks": bool(c["has_books"]),
            "hasChapters": bool(c["has_chapters"]),
            "introduction": clean(c["short_description_en"]) or None,
            "numberingNote": clean(c["numbering_source_en"]) or None,
        }
        collections_meta.append(meta)
        payload = {"id": cid, "key": slug, "books": books, "chapters": chapters, "hadiths": hadiths}
        raw = json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
        gz_path = os.path.join(OUT, f"{slug}.json.gz")
        with open(gz_path, "wb") as f:
            f.write(gzip.compress(raw, compresslevel=9))
        print(f"{slug}: {total} hadiths, {len(books)} books, {len(chapters)} chapters, "
              f"raw={len(raw)/1048576:.1f}MB gz={os.path.getsize(gz_path)/1048576:.1f}MB")

    with open(os.path.join(OUT, "collections.json"), "w", encoding="utf-8") as f:
        json.dump(collections_meta, f, ensure_ascii=False, separators=(",", ":"))

    scholars = []
    for r in cur.execute("SELECT * FROM scholar ORDER BY id"):
        s = {"i": r["id"], "n": clean(r["famous_name"])}
        if r["nick_name"]:
            s["k"] = clean(r["nick_name"])
        if r["born_on"]:
            s["b"] = clean(r["born_on"])
        if r["died_on"]:
            s["d"] = clean(r["died_on"])
        if r["lived_in"]:
            s["l"] = clean(r["lived_in"])
        scholars.append(s)
    raw = json.dumps(scholars, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    with open(os.path.join(OUT, "scholars.json.gz"), "wb") as f:
        f.write(gzip.compress(raw, compresslevel=9))
    print(f"scholars: {len(scholars)} gz={os.path.getsize(os.path.join(OUT, 'scholars.json.gz'))/1048576:.1f}MB")

    grand = sum(os.path.getsize(os.path.join(OUT, f)) for f in os.listdir(OUT))
    print(f"TOTAL hadiths: {total_h}, total asset size: {grand/1048576:.1f}MB")


if __name__ == "__main__":
    main()
