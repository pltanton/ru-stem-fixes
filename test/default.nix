# Loads the dictionary into a throwaway Postgres and checks every pair in pairs.tsv matches with it.
{
  runCommand,
  postgresql,
  ru-stem-fixes,
}: let
  pg = postgresql.withPackages (_: [ru-stem-fixes]);
in
  runCommand "ru-stem-fixes-test" {nativeBuildInputs = [pg];} ''
    export PGDATA=$TMPDIR/db PGHOST=$TMPDIR PGUSER=postgres
    initdb -U postgres -A trust -E UTF8 --locale-provider=builtin --builtin-locale=C.UTF-8 --locale=C.UTF-8 >/dev/null
    pg_ctl -o "-k $TMPDIR -c listen_addresses=" -l $TMPDIR/log start >/dev/null
    psql -q -d postgres <<'SQL'
    create text search dictionary ru_stem_fixes (template = synonym, synonyms = ru_stem_fixes);
    create text search configuration russian_fixed (copy = russian);
    alter text search configuration russian_fixed alter mapping for word, hword, hword_part with ru_stem_fixes, russian_stem;
    create table pairs (query text, doc text);
    SQL
    psql -q -d postgres -c "\copy pairs from '${./pairs.tsv}'"
    psql -At -d postgres -c "
      select 'snowball ' || count(*) filter (where to_tsvector('russian', doc) @@ websearch_to_tsquery('russian', query))
        || ', fixed ' || count(*) filter (where to_tsvector('russian_fixed', doc) @@ websearch_to_tsquery('russian_fixed', query))
        || ' of ' || count(*) from pairs" | tee $out
    missed=$(psql -At -d postgres -c "select query || ' / ' || doc from pairs
      where not to_tsvector('russian_fixed', doc) @@ websearch_to_tsquery('russian_fixed', query)")
    pg_ctl stop >/dev/null
    if [ -n "$missed" ]; then echo "missed: $missed"; exit 1; fi
  ''
