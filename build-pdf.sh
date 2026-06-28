#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# The Starlink Math Problem — PDF build
# Copyright (c) 2026 Nick Peelman · Code: MIT, paper text: CC BY-ND 4.0. See LICENSE.
# Source: https://github.com/peelman/starlink-math
#
# build-pdf.sh — render the downloadable PDF from the HTML.
#
# Pipeline:
#   1. (re)generate index.html from build.js
#   2. render it through wkhtmltopdf in print media  -> starlink-math.pdf
#   3. add title/author metadata and a section bookmark outline (pikepdf)
#
# Requirements: node + docx, wkhtmltopdf, poppler-utils (pdftotext),
#               python3 with pikepdf  (pip install pikepdf)
#
# Note: some Linux-distro wkhtmltopdf packages are built against "unpatched qt"
#       and print warnings that --print-media-type / --outline are "ignored".
#       Output is still correct: those builds default to print media (TOC and
#       download buttons are dropped), and the bookmark outline is added by the
#       pikepdf step below regardless. For guaranteed behavior on any machine,
#       install the patched build from https://wkhtmltopdf.org/.
#
set -euo pipefail

HTML="index.html"
PDF="starlink-math.pdf"
PAGE="Letter"          # or A4
MARGIN="18mm"

echo "1/3  building ${HTML} ..."
node build.js html

echo "2/3  rendering ${PDF} (print media) ..."
wkhtmltopdf \
  --print-media-type \
  --enable-internal-links --enable-external-links \
  --outline -s "${PAGE}" \
  -T "${MARGIN}" -B "${MARGIN}" -L "${MARGIN}" -R "${MARGIN}" \
  --title "The Starlink Math Problem" \
  "${HTML}" "${PDF}"

echo "3/3  adding metadata + bookmarks ..."
python3 - "${HTML}" "${PDF}" <<'PYEOF'
import re, subprocess, sys, pikepdf

html_path, pdf_path = sys.argv[1], sys.argv[2]
html = open(html_path, encoding="utf-8").read()

# ordered list of top-level section titles, as rendered
secs = re.findall(r'<h2 class="section" id="[^"]+"><a class="anchor"[^>]*>([^<]+)</a></h2>', html)

# per-page text of the rendered PDF
pages = subprocess.run(["pdftotext", "-layout", pdf_path, "-"],
                       capture_output=True, text=True).stdout.split("\f")
def norm(s): return re.sub(r"\s+", " ", s).strip().lower()
pages_n = [norm(p) for p in pages]

# map each section to the first page at/after the previous one
items, start = [], 0
for title in secs:
    key = norm(title)
    cands = [key, key[:24], norm(title.split(":")[0])]
    found = next((pg for pg in range(start, len(pages_n))
                  if any(c and c in pages_n[pg] for c in cands)), None)
    if found is None:
        found = next((pg for pg in range(len(pages_n)) if key in pages_n[pg]), None)
    if found is not None:
        items.append((title, found)); start = found

pdf = pikepdf.open(pdf_path, allow_overwriting_input=True)
with pdf.open_metadata() as m:
    m["dc:title"] = "The Starlink Math Problem"
    m["dc:creator"] = ["Nick Peelman"]
    m["dc:description"] = ("Economics, launch cadence, orbital risk, "
                           "atmospheric externalities, and a sustainable path.")
pdf.docinfo["/Title"] = "The Starlink Math Problem"
pdf.docinfo["/Author"] = "Nick Peelman"
pdf.docinfo["/Subject"] = ("Economics, launch cadence, orbital risk, "
                           "atmospheric externalities, and a sustainable path.")
with pdf.open_outline() as ol:
    ol.root.clear()
    for title, pg in items:
        ol.root.append(pikepdf.OutlineItem(title, pg))
pdf.save(pdf_path)
pdf.close()
print(f"     {len(items)} bookmarks, metadata set")
PYEOF

echo "done -> ${PDF}"
