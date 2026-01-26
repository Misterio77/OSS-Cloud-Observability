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
    devShells = forAllSystems (pkgs: {
      default = pkgs.mkShell {
        packages = [
          pkgs.typst
          pkgs.pandoc
          pkgs.texliveFull
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
      };
    });

    packages = forAllSystems (pkgs: {
      default = pkgs.stdenv.mkDerivation {
        pname = "cloud-monitoring-oss";
        version = self.lastModifiedDate;
        src = ./.;
        buildInputs = [pkgs.typst];
        TYPST_FEATURES = "html";
        TYPST_PACKAGE_PATH = "${typst-packages}/packages";
        TYPST_FONT_PATHS = pkgs.inconsolata + ":" + pkgs.libertine;
        buildPhase = ''
          typst compile main.typ main.pdf
        '';
        installPhase = ''
          mkdir -p $out
          mv main.pdf $out/
        '';
      };

      camera-ready = pkgs.stdenv.mkDerivation {
        pname = "cloud-monitoring-oss-cr";
        version = self.lastModifiedDate;
        src = ./latex;
        buildInputs = [pkgs.texliveFull pkgs.inkscape];
        buildPhase = ''
          latexmk
        '';
        installPhase = ''
          mkdir -p $out
          mv build/main.pdf $out/
        '';
      };
    });
  };
}
