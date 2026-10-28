# ru-stem-fixes

Russian full-text search in Postgres stems words with Snowball, which cuts endings but knows nothing
about how a word changes inside. So a search for `кошелёк` misses `кошелька`, `щенок` misses `щенка`,
`ковёр` misses `ковра`, `рот` misses `рту`, `идти` misses `шла`.

This repo lists every Russian word form (from the [OpenCorpora](https://opencorpora.org) dictionary,
via [pymorphy3](https://github.com/no-plagiarism/pymorphy3)) whose Snowball stem differs from the stem
of its lemma, mapped onto the lemma's stem:

```
ковра ковер
кошелька кошелек
людей человек
рту рот
шла идт
щенка щенок
```

Put it in front of Snowball and those forms meet their lemma; every other word is stemmed exactly as
before. About 336k forms, a 13 MB file.

## Does it help

[`test/pairs.tsv`](test/pairs.tsv) holds 30 query/text pairs that a Russian speaker expects to match,
checked on every build against a real Postgres:

| configuration             | pairs matched |
| ------------------------- | ------------- |
| `russian` (Snowball)      | 9 of 30       |
| `russian` + ru-stem-fixes | 30 of 30      |

The usual alternative, the Hunspell `ru_RU` dictionary from LibreOffice as an `ispell` dictionary,
matched 11 of 18 fleeting-vowel pairs in our tests: it is a spelling dictionary, and it lists many
oblique forms (`ковра`, `сна`, `угля`, `посла`) as words of their own. It also keeps `ё`, so
`ребенок` stops matching `ребёнка`, which Snowball handles.

What it deliberately leaves alone:

- Forms whose lemmas disagree (`стекла` is a form of `стекло` and of `стечь`) stay with Snowball.
- Participles, gerunds and comparatives keep their own stems: merging `сделанный` into `сделать`
  or `быстрее` into `быстрый` adds noise to search.

## Postgres

Put `ru_stem_fixes.syn` into Postgres' `tsearch_data` directory
(`$(pg_config --sharedir)/tsearch_data`), then:

```sql
create text search dictionary ru_stem_fixes (template = synonym, synonyms = ru_stem_fixes);
create text search configuration russian_fixed (copy = russian);
alter text search configuration russian_fixed
  alter mapping for word, hword, hword_part with ru_stem_fixes, russian_stem;

select to_tsvector('russian_fixed', 'потерял кошелька') @@ websearch_to_tsquery('russian_fixed', 'кошелёк');
-- t
```

Existing `tsvector` columns have to be recomputed with the new configuration.

Each Postgres connection loads the dictionary the first time it uses it: about 0.3 s and 50 MB of
memory per connection. `to_tsvector` gets about twice as slow (1.5 s per 100k short messages instead
of 0.7 s).

### NixOS

```nix
# flake.nix
inputs.ru-stem-fixes.url = "github:pltanton/ru-stem-fixes";

# configuration
services.postgresql.extensions = ps: [inputs.ru-stem-fixes.packages.${pkgs.stdenv.hostPlatform.system}.default];
```

## Elasticsearch / OpenSearch

The package also writes `share/ru-stem-fixes/stemmer_override.txt` with `form => stem` rules for a
[`stemmer_override`](https://www.elastic.co/guide/en/elasticsearch/reference/current/analysis-stemmer-override-tokenfilter.html)
filter placed before the `russian` stemmer.

## Files without Nix

Each [release](https://github.com/pltanton/ru-stem-fixes/releases) has both files attached. To build
them yourself: `pip install pymorphy3 pymorphy3-dicts-ru snowballstemmer`, then
`python3 generate.py ru_stem_fixes.syn stemmer_override.txt` (under a minute).

## License

The code is MIT. The generated files derive from the OpenCorpora dictionary and are under
[CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/), like the dictionary itself.
