{
  pkgs ? import <nixpkgs> { },
}:

let
  typst = pkgs.typst.withPackages (p: [
    p.fletcher_0_5_8
    p.cetz_0_3_4
    p."cetz-plot_0_1_1"
  ]);
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "cloud-observability-paper";
  version = "unstable";
  src = pkgs.lib.cleanSource ./.;

  nativeBuildInputs = [ typst ];

  dontConfigure = true;

  buildPhase = ''
    runHook preBuild
    typst compile \
      --features html \
      --font-path ${pkgs.libertine}/share/fonts/opentype/public \
      --font-path ${pkgs.inconsolata}/share/fonts/truetype \
      main.typ main.pdf
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp main.pdf $out/main.pdf
    runHook postInstall
  '';
}
