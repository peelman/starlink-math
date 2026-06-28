# The Starlink Math Problem

Source and build pipeline for the technical position paper *The Starlink Math Problem*,
published at **<https://starlink-math.peelman.us/>**.

The entire paper is generated from a single source file, [`build.js`](./build.js), which emits
two artifacts from one content definition:

- `index.html` — a self-contained static web page (the canonical published artifact)
- `starlink_analysis.docx` — a Microsoft Word version

A print-optimized `starlink-math.pdf` is rendered from the HTML for download and archival.

## Why a build script

The paper is long, heavily cross-referenced, and maintained over time. Keeping the prose in one
place and generating every output format from it avoids the usual failure mode where edits drift
out of sync between a Word document and a web page. `build.js` is the single source of truth; the
`.docx` and `.html` are build products.

## Requirements

- Node.js 18 or newer
- The [`docx`](https://www.npmjs.com/package/docx) package:

  ```bash
  npm install docx
  ```

## Build

```bash
node build.js          # both index.html and starlink_analysis.docx (default)
node build.js html     # index.html only
node build.js docx     # starlink_analysis.docx only
node build.js summary  # summary.html only (the short companion page)
node build.js all      # index.html + starlink_analysis.docx + summary.html
```

Outputs are written to the current working directory. To write elsewhere:

```bash
OUT_DIR=./dist node build.js
```

## Rendering the PDF

The downloadable PDF is the HTML rendered through a print-media browser engine
([`wkhtmltopdf`](https://wkhtmltopdf.org/)), so it matches the web page exactly:

```bash
wkhtmltopdf --print-media-type \
  --enable-internal-links --enable-external-links \
  --outline -s Letter -T 18mm -B 18mm -L 18mm -R 18mm \
  index.html starlink-math.pdf
```

The `@media print` rules drop the table of contents and the on-page "Download PDF" buttons,
leaving a clean document. Endnote markers stay linked to their notes, and DOI/arXiv references
link out. (The published PDF additionally has bookmarks and title/author metadata applied with a
tool such as [`pikepdf`](https://pikepdf.readthedocs.io/); that step is optional cosmetic polish.)

## How it works

`build.js` assembles an in-memory array of format-neutral content nodes (`DOC`) as a side effect
of the same helper calls that build the Word document, and two emitters consume it:

- the **DOCX emitter** uses the `docx` library;
- the **HTML emitter** walks `DOC` to produce a single self-contained `index.html`
  (inline CSS, no external assets).

Because both outputs derive from the same helper calls, the prose lives in exactly one place.

### Content helpers

Prose is written with a small set of helpers:

| Helper             | Produces                                        |
| ------------------ | ----------------------------------------------- |
| `h1(text)`         | top-level section heading                       |
| `h2(text)`         | subsection heading                              |
| `body(text)`       | paragraph                                       |
| `bullet(text)`     | list item                                       |
| `endnote(n, text)` | a numbered note in the **Notes** section        |
| `ref(n, text)`     | a numbered entry in the **References** list      |

Inline markup inside `body()`:

- `**bold**`, `*italic*`
- `[[N]]` — a superscript endnote marker that links to note *N* (and the note links back)

### Two-tier citations

The paper deliberately runs two separate reference systems:

- **Notes** — superscript-numbered endnotes (`[[N]]` → note *N*), each carrying its own inline
  `Source:` line.
- **References** — a standalone bibliography numbered independently, with full citations and
  DOI/arXiv identifiers.

These are intentionally **not** cross-linked: a note never points into the References list. The
HTML emitter preserves this — it hyperlinks DOI/arXiv identifiers in the References only, and never
turns a bracketed `[N]` into a link.

### Two things to watch when editing

1. **Endnote numbering is positional.** Markers (`[[N]]`) must run in document order, and the
   `endnote(N, …)` definitions must match. Inserting or removing a note cascades the numbering of
   every later marker and note. The cascade is mechanical but easy to get wrong by hand.

2. **Character encoding differs by helper.** `body()` and table-cell strings store special
   characters as literal JavaScript escapes (`\u2014`, `\u2019`, `\u201C`). `endnote()` and `ref()`
   strings use real Unicode characters (—, ’, “ ”). Match the convention of the helper you are
   editing.

## Deployment

Static hosting, no CMS. Expected document root:

```
starlink-math.peelman.us/
  index.html
  starlink-math.pdf
```

`index.html` references the PDF by relative path, so the two must sit in the same directory. The
canonical URL is set in the page head:

```html
<link rel="canonical" href="https://starlink-math.peelman.us/">
```

A vanity domain, if used, should be a **301 redirect** to the canonical URL — never a duplicate
copy of the content.

## Repository layout

```
build.js                 # single source of truth (prose + build logic)
build-pdf.sh             # PDF render (wkhtmltopdf + metadata/bookmarks)
package.json             # docx dependency + npm scripts
README.md
LICENSE                  # MIT (build software)
LICENSE-CONTENT.md       # CC BY-ND 4.0 (paper text)
.gitignore
# build products (generated — gitignored by default):
index.html
summary.html
starlink_analysis.docx
starlink-math.pdf
```

## Independence

The paper is an independent critical analysis. It is not affiliated with, endorsed by, or
sponsored by any company named in it, and the author holds no financial position in any of them.
"Starlink" and "SpaceX," along with other company and product names, are trademarks of their
respective owners and are used only for identification and commentary. The full disclaimer appears
at the foot of the published page.

## License

Two works, two licenses:

- **Build software** (`build.js`, `build-pdf.sh`) — MIT. See [`LICENSE`](./LICENSE).
- **Paper text** (the prose in `build.js` and the generated `index.html`,
  `starlink_analysis.docx`, `starlink-math.pdf`) — Creative Commons
  Attribution-NoDerivatives 4.0 International (CC BY-ND 4.0).
  See [`LICENSE-CONTENT.md`](./LICENSE-CONTENT.md).

You may share the paper, including the compiled PDF, with attribution; you may not
distribute modified versions of the text. You may reuse the build code under the MIT terms.
