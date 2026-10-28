# Lists Russian word forms whose Snowball stem differs from the stem of their lemma (fleeting vowels:
# ковра -> ковер, рту -> рот; suppletion: людей -> человек), mapped onto the lemma's stem. Forms with
# several lemmas that disagree are left to Snowball. Participles, gerunds and comparatives would merge
# into their verb or adjective and only add noise, so they keep their own stems.
#
# Writes a Postgres synonym file and an Elasticsearch/OpenSearch stemmer_override rules file.
import sys
from collections import defaultdict

import pymorphy3
import snowballstemmer

stem = snowballstemmer.stemmer("russian").stemWord
morph = pymorphy3.MorphAnalyzer()
skip = {"PRTF", "PRTS", "GRND", "COMP"}

lemmas = defaultdict(set)
for word, tag, normal, _para, _idx in morph.dictionary.iter_known_words():
    if word.isalpha() and tag.POS not in skip:
        lemmas[word].add(stem(normal.replace("ё", "е")))

fixes = {}
for word, targets in lemmas.items():
    key = word.replace("ё", "е")
    if len(targets) != 1 or stem(key) in targets:
        continue
    target = next(iter(targets))
    fixes[key] = target if fixes.get(key, target) == target else None

# Text keeps its ё and lookups are exact, so a key spelled with ё goes in both ways.
spelled = defaultdict(set)
for word in lemmas:
    spelled[word.replace("ё", "е")].add(word)

pg_path, es_path = sys.argv[1], sys.argv[2]
n = 0
with open(pg_path, "w") as pg, open(es_path, "w") as es:
    for key in sorted(fixes):
        if fixes[key] is None:
            continue
        for form in sorted(spelled[key] | {key}):
            pg.write(f"{form} {fixes[key]}\n")
            es.write(f"{form} => {fixes[key]}\n")
            n += 1
print(f"{n} forms", file=sys.stderr)
