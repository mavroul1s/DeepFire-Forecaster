#!/usr/bin/env bash
# Foolproof compile sequence for main.tex with refs.bib
set -e
cd "$(dirname "$0")"
rm -f main.aux main.bbl main.blg main.log main.out main.toc main.pdf
pdflatex -interaction=nonstopmode main.tex
bibtex main
pdflatex -interaction=nonstopmode main.tex
pdflatex -interaction=nonstopmode main.tex
echo "Done — see main.pdf"
