#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out="$root/build/latex"
input="$root/main.typ"
bibliography="$root/references.bib"
build_pdf=1

while (($#)); do
  case "$1" in
    --output)
      out="$(realpath -m "$2")"
      shift 2
      ;;
    --input)
      input="$(realpath -m "$2")"
      shift 2
      ;;
    --bibliography)
      bibliography="$(realpath -m "$2")"
      shift 2
      ;;
    --no-pdf)
      build_pdf=0
      shift
      ;;
    -h|--help)
      cat <<'EOF'
Usage: latex/export.sh [OPTIONS]

Generate an acmart LaTeX project from a Typst manuscript. By default, main.typ
and references.bib are converted into build/latex and compiled to
build/latex/build/main.pdf.

Options:
  --input FILE         Typst entrypoint
  --bibliography FILE  BibLaTeX bibliography
  --output DIR         Destination directory
  --no-pdf             Generate source without compiling it
EOF
      exit 0
      ;;
    *)
      printf 'unknown argument: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

required=(typst pandoc rsvg-convert)
if ((build_pdf)); then required+=(latexmk); fi
for command in "${required[@]}"; do
  command -v "$command" >/dev/null || {
    printf 'missing required command: %s\n' "$command" >&2
    exit 127
  }
done
rm -rf "$out"
mkdir -p "$out"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

typst compile \
  --features html \
  --format html \
  --root "$root" \
  "$input" \
  "$work/typst.html"

(
  cd "$out"
  pandoc "$work/typst.html" \
    --from=html \
    --to=latex \
    --standalone \
    --natbib \
    --lua-filter="$root/latex/filter.lua" \
    --template="$root/latex/template.tex" \
    --extract-media=assets \
    --output=main.tex
)

cp "$bibliography" "$out/references.bib"
cp "$root/latex/latexmkrc" "$out/.latexmkrc"

if ((build_pdf)); then
  (
    cd "$out"
    latexmk -pdf -interaction=nonstopmode -halt-on-error main.tex
  )
fi

printf 'LaTeX export written to %s\n' "$out"
if ((build_pdf)); then
  printf 'PDF written to %s\n' "$out/build/main.pdf"
fi
