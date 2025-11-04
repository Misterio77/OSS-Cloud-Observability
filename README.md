# Cloud OSS Monitoring

This repository contains the reproduction package and source code for the paper.

The paper itself, `main.typ`, was typeset with [Typst](https://typst.app), with the figures (except the graph) created, also in Typst (through the Cetz package), located in the `parts` directory.

The directory `reprod` contains the data and scripts (written in Python) utilized in the research. The paper provides information on the role of which file, with Figure 1 providing a useful overview on them. Refer to it for more information.

## Dependencies and usage

### Nix

The repository contains a [Nix](https://nixos.org/nix) flake, for reproducible dependencies (including typst compiler, typst packages, python, and python packages).

To build the paper:

```
nix build .
```

Or, use a devshell:

```
nix develop .
typst compile main.typ
```

To run the reproduction scripts:

```
nix develop .
cd reprod
python3 xx-yyyy.py
```

### Manually

Alternatively, install Typst and Python following your OS' steps. Then install the python libraries using:

```
pip install -r reprod/requirements.txt
```
