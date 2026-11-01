# Nature-style LaTeX Generator

A PowerShell tool that generates a **Nature Communications-inspired LaTeX reading copy** for drafting and colleague review. It writes a `.tex` file; it does not compile a PDF.

Keep manuscript content in `main.tex`, presentation labels in `config.json`, and generated files in `output/`.

> **Unofficial project.** Not affiliated with or endorsed by Nature Portfolio or Springer Nature. This is not an official submission template or an exact reproduction of the journal's typography. Generated documents are labelled as reading copies, not published articles.

## Features

- Two-column manuscript layout with a full-width title and abstract block.
- Title, author names, affiliations and abstract extracted from `main.tex`.
- Bottom-of-page affiliation float, intended for the first page.
- Configurable article type, running header and draft/review labels.
- Superscript citations through `natbib` and full-width floats for the supported input format.
- Times-style serif text and Helvetica-style labels using standard LaTeX packages.
- Separate generated output; the original manuscript is not modified.

## Requirements

### Required to generate the `.tex` file

- **PowerShell only.** The current workflow has been tested on Windows; other platforms have not been verified.
- A `main.tex` manuscript and a `config.json` file beside the script. Both are included as examples.

**No LaTeX installation is needed to run the generator.**

### Optional: compile the generated file into a PDF

Choose either:

- **Local compilation:** install a LaTeX distribution, such as TeX Live or MiKTeX, providing `pdflatex`. BibTeX is needed for BibTeX bibliographies.
- **Overleaf:** upload the generated `.tex` file and its manuscript dependencies; no local LaTeX installation is needed.

For compilation, the generated document uses these LaTeX packages: `extarticle`, `fontenc`, `inputenc`, `geometry`, `newtxtext`, `newtxmath`, `helvet`, `graphicx`, `xcolor`, `microtype`, `natbib`, `titlesec`, `caption`, `fancyhdr`, `stfloats` and `hyperref`. These are compilation dependencies, not generator dependencies.

The included example requires no external images or bibliography.

## Quick start

Download or clone the repository and open PowerShell in its root folder.

### 1. Generate

```powershell
.\nature-tex-gen.ps1
```

This creates `output/main_nature_style.tex`. The script does not automatically compile a PDF.

If Windows blocks the script, review its contents first. Where your organisation's policy permits, use a process-only execution-policy override:

```powershell
powershell -ExecutionPolicy Bypass -File .\nature-tex-gen.ps1
```

### 2. Compile locally (optional)

This step requires a local LaTeX installation. Skip it if you only need the generated `.tex` file or plan to use Overleaf.

Run from the **project root**, not inside `output/`, so relative manuscript paths resolve:

```powershell
pdflatex -interaction=nonstopmode -halt-on-error -output-directory=output output/main_nature_style.tex
pdflatex -interaction=nonstopmode -halt-on-error -output-directory=output output/main_nature_style.tex
```

Open `output/main_nature_style.pdf` to review the result.

For BibTeX bibliographies, run this after the first LaTeX pass, then run LaTeX twice more:

```powershell
bibtex output/main_nature_style
```

The manuscript must supply compatible bibliography commands and a bibliography style. The current generated preamble uses `natbib`, not `biblatex`.

### Use Overleaf instead (optional)

Upload `output/main_nature_style.tex` to the root of an Overleaf project and select it as the main document. Include your figures, bibliography and other referenced files, retaining their paths relative to the original manuscript root. Select pdfLaTeX as the compiler. The PowerShell script runs locally, not in Overleaf.

## Project structure

```text
nature-style-latex/
|-- nature-tex-gen.ps1        # Generator and layout definition
|-- config.json               # Presentation settings
|-- main.tex                  # Example / manuscript source
|-- README.md
|-- .gitignore
`-- output/                   # Created automatically; ignored by Git
    |-- main_nature_style.tex
    `-- main_nature_style.pdf  # Created by the LaTeX compilation step
```

## Use your own manuscript

Back up your manuscript, then replace the example `main.tex`. Keep figures, bibliography files and other dependencies at the paths referenced in your manuscript.

Use this input structure:

```tex
\documentclass{article}
\title{Your paper title}
\author{First Author\textsuperscript{1}, Second Author\textsuperscript{2}\\
\small\textsuperscript{1}First affiliation\\
\small\textsuperscript{2}Second affiliation}

\begin{document}
\maketitle
\begin{abstract}
Your abstract.
\end{abstract}

\section{Introduction}
Your introduction.

\section{Results}
Your results.

\section{Discussion}
Your discussion.

\section{Methods}
Your methods.

\end{document}
```

- Keep all author names before the first LaTeX line break (`\\`), followed by affiliations. Separate `\and` author blocks are not supported.
- Keep the exact `\section{Introduction}` marker. It locates the manuscript body; its printed heading is suppressed in the reading copy.
- The source preamble is **replaced, not merged**. Add required custom packages or commands to the generator's `$preamble` block.
- Edit `main.tex`, not the generated document. Regenerating overwrites the selected output. The script refuses to overwrite the root `main.tex`.

## Configuration

Edit `config.json`:

```json
{
  "outputFile": "output/main_nature_style.tex",
  "runningHeader": "Manuscript reading copy",
  "documentStatus": "Draft manuscript",
  "reviewNote": "Draft for colleague review",
  "articleType": "Article"
}
```

| Setting | Purpose |
| --- | --- |
| `outputFile` | Generated `.tex` path relative to the script folder; parent folders are created automatically. |
| `runningHeader` | Left-hand running header on subsequent pages. |
| `documentStatus` | Right-hand running header on subsequent pages. |
| `reviewNote` | First-page note beside the author/abstract block. |
| `articleType` | Label above the title, such as `Article` or `Review`. |

All values must be strings. Display labels accept plain text, with LaTeX special characters escaped automatically. Omitted settings use the defaults above; unknown settings produce an error. The configuration file itself must exist and contain a valid JSON object.

Title, authors, affiliations, abstract and paper content remain in `main.tex`.

### Command-line options

```powershell
.\nature-tex-gen.ps1 -OutputFile output/review_copy.tex -Title 'Alternative review title'
.\nature-tex-gen.ps1 -ConfigFile my_config.json
```

`-OutputFile` overrides the JSON setting. A title override is LaTeX text: escape special characters as you would in `\title{...}`.

## Limitations

- **Not a general LaTeX converter.** Text matching assumes the input structure above. Complex macros and alternative document structures may require manual changes.
- **Format-sensitive float conversion.** Use `\begin{figure}[htbp]` and `\begin{table}[htbp]`. The current conversion is not safe for arbitrary placement options; inspect the generated environments if your source uses other forms.
- **Dependencies are not bundled.** Figures, included files, bibliography databases and custom styles are not copied to `output/`. Compile from the project root and share the complete project when needed.
- **Approximate typography and layout.** Fonts are substitutes, not the journal's proprietary typefaces. Long titles, abstracts and author lists affect pagination. The affiliation float is not guaranteed to remain on page one.
- **Short examples leave empty space.** The included example demonstrates syntax, not realistic article length. Full-width figures can move to later pages.
- **No guarantee of submission compliance.** Follow the target journal's current instructions and inspect the compiled PDF before sharing.

## Troubleshooting

| Problem | What to check |
| --- | --- |
| Introduction marker not found | Use the exact `\section{Introduction}` command. |
| Missing author block or unbalanced braces | Check `\author{...}` and the supported affiliation format. |
| Configuration error | Check JSON syntax, setting names and string values. |
| Missing package or undefined command during PDF compilation | Install the package or add custom definitions to `$preamble`; neither is needed merely to run the generator. |
| Missing image or bibliography | Compile from the project root and verify referenced paths. |
| Changes disappear after regeneration | Edit the source, configuration or generator, not the generated `.tex`. |

## Reporting issues

Include a minimal non-confidential manuscript, relevant configuration, PowerShell version and the error message or screenshot. For PDF compilation problems, also include the LaTeX version and relevant log output. Do not upload unpublished research or third-party artwork without permission.

## Attribution

The layout is inspired by published Nature Communications articles. No proprietary font files or publisher logos are bundled. Journal names identify the visual reference and do not imply endorsement, affiliation or publication status.
