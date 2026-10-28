{
  lib,
  runCommand,
  python3,
}: let
  python = python3.withPackages (p: [p.pymorphy3 p.pymorphy3-dicts-ru p.snowballstemmer]);
in
  runCommand "ru-stem-fixes-${python3.pkgs.pymorphy3-dicts-ru.version}" {
    nativeBuildInputs = [python];
    meta = {
      description = "Russian word forms the Snowball stemmer splits from their lemma, mapped onto the lemma's stem";
      homepage = "https://github.com/pltanton/ru-stem-fixes";
      license = [lib.licenses.mit lib.licenses.cc-by-sa-30];
    };
  } ''
    mkdir -p $out/share/postgresql/tsearch_data $out/share/ru-stem-fixes
    python3 ${./generate.py} \
      $out/share/postgresql/tsearch_data/ru_stem_fixes.syn \
      $out/share/ru-stem-fixes/stemmer_override.txt
  ''
