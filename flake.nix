{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/default";

    typst-packages.url = "github:typst/packages";
    typst-packages.flake = false;
  };

  outputs = {
    self,
    nixpkgs,
    systems,
    typst-packages,
    ...
  }: let
    forAllSystems = f: nixpkgs.lib.genAttrs (import systems) (s: f nixpkgs.legacyPackages.${s});
  in {
    packages = forAllSystems (pkgs: {
      default = pkgs.stdenv.mkDerivation {
        pname = "cloud-monitoring-oss";
        version = self.lastModifiedDate;
        src = ./.;
        buildInputs = [
          pkgs.typst
          pkgs.pandoc
          # Tooling
          pkgs.tinymist
          pkgs.typstyle
          pkgs.harper
          # For reprod
          (pkgs.python3.withPackages (p: [
            p.pyyaml
            p.openai
            p.networkx
            p.matplotlib
            # Tooling
            p.ruff
          ]))
        ];
        TYPST_FEATURES = "html";
        TYPST_PACKAGE_PATH = "${typst-packages}/packages";
        TYPST_FONT_PATHS = pkgs.inconsolata + ":" + pkgs.libertine;
        buildPhase = ''
          typst compile main.typ main.pdf

          typst compile main.typ main.html
          pandoc main.html --biblatex --shift-heading-level-by=-1 --lua-filter=pandoc-filter.lua --extract-media -o main.tex
          sed -i 's/autocite/cite/g' main.tex
        '';
        installPhase = ''
          mkdir -p $out
          mv main.pdf $out/

          mkdir -p $out/latex
          mv main.tex assets $out/latex/
        '';
      };
    });
  };
}
