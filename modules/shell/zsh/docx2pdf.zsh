# convert a docx (or any libreoffice-readable doc) to pdf.
# usage: docx2pdf file.docx [outdir]   (outdir defaults to the current dir)
docx2pdf() {
  if [[ -z "$1" ]]; then
    echo "usage: docx2pdf file.docx [outdir]" >&2
    return 1
  fi
  libreoffice --headless --convert-to pdf --outdir "${2:-.}" "$1"
}
