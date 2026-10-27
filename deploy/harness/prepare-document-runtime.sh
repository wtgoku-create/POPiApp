#!/usr/bin/env bash
set -euo pipefail
export PATH=/opt/popi-harness/node/bin:/usr/bin:/bin:/usr/sbin:/sbin

# Document parsing runs on the server; no office suite enters client packages.
if [[ "${1:-}" == "--install" ]]; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y --no-install-recommends \
    python3 poppler-utils tesseract-ocr tesseract-ocr-eng \
    tesseract-ocr-chi-sim tesseract-ocr-chi-tra fonts-noto-cjk
elif [[ $# -ne 0 ]]; then
  printf 'Usage: %s [--install]\n' "$0" >&2
  exit 2
fi

for executable in node python3 pdfinfo pdftotext pdftoppm tesseract; do
  command -v "$executable" >/dev/null
done
for language in eng chi_sim chi_tra; do
  tesseract --list-langs 2>/dev/null | grep -Fx "$language" >/dev/null
done
id popi-harness >/dev/null
if ! id popi-document-converter >/dev/null 2>&1; then
  useradd --system --home-dir /var/lib/popi-document-converter \
    --shell /usr/sbin/nologin popi-document-converter
fi
install -d -m 0700 -o popi-document-converter -g popi-harness \
  /var/lib/popi-document-converter
printf 'POPi document parser and OCR prerequisites ready\n'
