@echo off
REM Foolproof compile sequence for Windows
cd /d "%~dp0"
del /q main.aux main.bbl main.blg main.log main.out main.toc main.pdf 2>nul
pdflatex -interaction=nonstopmode main.tex
bibtex main
pdflatex -interaction=nonstopmode main.tex
pdflatex -interaction=nonstopmode main.tex
echo Done. See main.pdf
pause
