# Cloud OSS Monitoring

This repository contains the reproduction package and source code for the paper.

The paper itself, `main.typ`, was typeset with [Typst](https://typst.app), with the figures (except the graph) created, also in Typst (through the Cetz package), located in the `parts` directory.

A disposable `acmart` LaTeX project is generated from the Typst source by `camera-ready.nix`; `main.typ` remains the source of truth. See the build commands below.

The directory `reprod` contains the data and scripts (written in Python) utilized in the research. The paper provides information on the role of which file, with Figure 1 providing a useful overview on them. Refer to it for more information.

## Dependencies and usage

### Nix

The repository contains [Nix](https://nixos.org/nix) expressions for reproducible Typst and submission builds.

To build the Typst paper:

```sh
nix-build default.nix
```

To build the LaTeX submission package (`main.pdf` and `paper.zip`):

```sh
nix-build camera-ready.nix
```

For conversion work outside Nix, `latex/export.sh` writes the generated project to `build/latex/` when Typst, Pandoc, librsvg, and the required TeX packages are already available. It accepts `--input`, `--bibliography`, and `--output` when used for another manuscript.

The conversion lives in `latex/` and is manuscript-independent. LaTeX semantics and optional layout choices are declared in Typst with the `acmart-*` helpers from `parts/layout.typ`; the conversion scripts do not contain paper-specific figure labels, section names, or table contents. The submission build packages generated assets and the complete `reprod/` directory automatically.

### Manually

Alternatively, install Typst and Python following your OS' steps. To run the reproduction scripts, install their Python dependencies with:

```
pip install -r reprod/requirements.txt
```

## License

This work is licensed under the [Creative Commons Attribution 4.0 International License](LICENSE).
