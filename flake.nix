{
  description = "Russian word forms the Snowball stemmer splits from their lemma, as a Postgres synonym dictionary";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = {
    self,
    nixpkgs,
  }: let
    systems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
    forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
  in {
    packages = forAllSystems (pkgs: {
      default = pkgs.callPackage ./package.nix {};
    });

    checks = forAllSystems (pkgs: {
      default = pkgs.callPackage ./test {ru-stem-fixes = self.packages.${pkgs.stdenv.hostPlatform.system}.default;};
    });
  };
}
