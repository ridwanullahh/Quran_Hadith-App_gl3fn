#!/usr/bin/env python3
"""
Bismillah: Build word morphology + root index assets from the Quranic
Arabic Corpus v0.4 (mustafa0x/quran-morphology mirror).

Outputs (assets/data/quran_science/):
  morphology.json.gz  {"<s>:<a>": [[root, pos, lemma, features, form], ...]}
                      per WORD (segments merged), matching quran.com word
                      positions 1:1.
  root_index.json.gz  {"<root>": [[s, a, w], ...]} every rooted word's
                      location, powering root exploration + occurrences.
  morphology_terms_ar.json  Arabic labels for POS/feature terms.
Provenance: Quranic Arabic Corpus v0.4 (corpus.quran.com), see
docs/DATA_PROVENANCE.md.
"""
import gzip
import json
import os
from collections import defaultdict

SRC = "/home/z/my-project/refs/quran-morphology/quran-morphology.txt"
TERMS = "/home/z/my-project/refs/quran-morphology/morphology-terms-ar.json"
OUT = "/home/z/my-project/Quran_Hadith-App_gl3fn/assets/data/quran_science"


def main():
    os.makedirs(OUT, exist_ok=True)
    words = defaultdict(list)   # (s,a,w) -> list of segment dicts
    with open(SRC, encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\n")
            if not line.strip():
                continue
            parts = line.split("\t")
            if len(parts) < 4:
                continue
            loc, form, pos, features = parts[0], parts[1], parts[2], parts[3]
            seg = loc.split(":")
            if len(seg) != 4:
                continue
            s, a, w, _segnum = map(int, seg)
            words[(s, a, w)].append({"form": form, "pos": pos, "feat": features})

    # ── word-level morphology ──────────────────────────────────────
    morphology = {}
    root_index = defaultdict(list)
    word_count = 0
    for (s, a, w), segs in sorted(words.items()):
        root = ""
        pos = ""
        lemma = ""
        feats = []
        for seg in segs:
            for tok in seg["feat"].split("|"):
                if tok.startswith("ROOT:"):
                    root = tok[5:]
                elif tok.startswith("LEM:"):
                    lemma = tok[4:]
                else:
                    feats.append(tok)
            if seg["pos"]:
                pos = seg["pos"]
        morphology.setdefault(f"{s}:{a}", []).append(
            [root, pos, lemma, "|".join(dict.fromkeys(feats))])
        word_count += 1
        if root:
            root_index[root].append([s, a, w])

    raw = json.dumps(morphology, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    with open(os.path.join(OUT, "morphology.json.gz"), "wb") as f:
        f.write(gzip.compress(raw, compresslevel=9))
    print(f"morphology: {word_count} words, {os.path.join(OUT, 'morphology.json.gz')}: "
          f"{os.path.getsize(os.path.join(OUT, 'morphology.json.gz'))/1048576:.2f}MB")

    raw = json.dumps(root_index, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    with open(os.path.join(OUT, "root_index.json.gz"), "wb") as f:
        f.write(gzip.compress(raw, compresslevel=9))
    print(f"root_index: {len(root_index)} roots, "
          f"{os.path.getsize(os.path.join(OUT, 'root_index.json.gz'))/1048576:.2f}MB")

    with open(TERMS, encoding="utf-8") as f:
        terms = json.load(f)
    with open(os.path.join(OUT, "morphology_terms_ar.json"), "w", encoding="utf-8") as f:
        json.dump(terms, f, ensure_ascii=False, separators=(",", ":"))
    print("morphology_terms_ar.json written")


if __name__ == "__main__":
    main()
