{
  pkgs ? import <nixpkgs> { },
}:

let
  typst = pkgs.typst.withPackages (p: [
    p.fletcher_0_5_8
    p.cetz_0_3_4
    p."cetz-plot_0_1_1"
  ]);
  texlive = pkgs.texliveMedium.withPackages (
    p: with p; [
      acmart
      collection-latexextra
      inconsolata
      newtx
      libertine
      fontaxes
    ]
  );
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "cloud-observability-submission";
  version = "unstable";
  src = pkgs.lib.cleanSource ./.;

  nativeBuildInputs = [
    typst
    pkgs.pandoc
    pkgs.librsvg
    texlive
    pkgs.zip
  ];

  dontConfigure = true;
  TYPST_FONT_PATHS = pkgs.lib.makeSearchPath "share/fonts" [
    pkgs.libertine
    pkgs.inconsolata
  ];
  FONTCONFIG_FILE = pkgs.makeFontsConf {
    fontDirectories = [
      pkgs.libertine
      pkgs.inconsolata
    ];
  };

  buildPhase = ''
        runHook preBuild
        export XDG_CACHE_HOME="$TMPDIR/font-cache"
        mkdir -p "$XDG_CACHE_HOME"
        patchShebangs latex
        latex/export.sh --output "$PWD/build/latex"

        mkdir -p package/source package/supplements
        cp build/latex/main.tex package/source/main.tex
        cp build/latex/references.bib package/source/references.bib
        cp build/latex/.latexmkrc package/source/.latexmkrc
        cp -r build/latex/assets package/source/assets

        cp -r reprod package/supplements/reprod

        find package -exec touch -h -d @1 {} +
        (
          cd package
          zip -X -r ../paper.zip source supplements
        )
        runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp build/latex/build/main.pdf $out/main.pdf
    cp paper.zip $out/paper.zip
    runHook postInstall
  '';
}
