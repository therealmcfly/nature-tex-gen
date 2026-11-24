param(
    [string]$OutputFile = '',
    [string]$Title = '',
    [string]$ConfigFile = 'config.json'
)
$ErrorActionPreference = 'Stop'
$settings = @{
    outputFile = 'output/main_nature_style.tex'
    runningHeader = 'Manuscript reading copy'
    documentStatus = 'Draft manuscript'
    reviewNote = 'Draft for colleague review'
    articleType = 'Article'
}
$configPath = Join-Path $PSScriptRoot $ConfigFile
try {
    $config = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
} catch { throw "Could not read JSON configuration '$configPath': $($_.Exception.Message)" }
if ($null -eq $config -or $config -isnot [pscustomobject]) { throw 'Configuration must be a JSON object.' }
foreach ($property in $config.PSObject.Properties) {
    if (-not $settings.ContainsKey($property.Name)) { throw "Unknown configuration setting: $($property.Name)" }
    if ($property.Value -isnot [string]) { throw "Configuration setting '$($property.Name)' must be a string." }
    $settings[$property.Name] = $property.Value
}
if (-not $PSBoundParameters.ContainsKey('OutputFile')) { $OutputFile = $settings.outputFile }
if ([string]::IsNullOrWhiteSpace($OutputFile)) { throw 'OutputFile must not be empty.' }

# Configuration labels are plain text, not LaTeX source.
function ConvertTo-LatexText([string]$Text) {
    $escapes = @{
        '\' = '\textbackslash{}'; '{' = '\{'; '}' = '\}'
        '$' = '\$'; '&' = '\&'; '#' = '\#'; '%' = '\%'
        '_' = '\_'; '^' = '\textasciicircum{}'; '~' = '\textasciitilde{}'
    }
    $result = [System.Text.StringBuilder]::new()
    foreach ($character in $Text.ToCharArray()) {
        $key = [string]$character
        if ($escapes.ContainsKey($key)) { [void]$result.Append($escapes[$key]) }
        elseif ($character -eq "`r" -or $character -eq "`n") { [void]$result.Append(' ') }
        else { [void]$result.Append($character) }
    }
    return $result.ToString()
}
# Generates a reading copy from main.tex; rerunning replaces the chosen output.
$outputPath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot $OutputFile))
if ($outputPath -eq (Join-Path $PSScriptRoot 'main.tex')) { throw 'Output must not overwrite main.tex.' }
if ([System.IO.Path]::GetExtension($outputPath) -ne '.tex') { throw 'OutputFile must have a .tex extension.' }
$source = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'main.tex') -Raw -Encoding UTF8
function Get-LatexArgument([string]$Text, [string]$Command) {
    $start = [regex]::Match($Text, '\\' + [regex]::Escape($Command) + '\s*\{')
    if (-not $start.Success) { throw "Missing LaTeX command: $Command" }
    $first = $start.Index + $start.Length
    $level = 1
    for ($i = $first; $i -lt $Text.Length; $i++) {
        if ($Text[$i - 1] -eq '\') { continue }
        if ($Text[$i] -eq '{') { $level++ }
        if ($Text[$i] -eq '}') { $level-- }
        if ($level -eq 0) { return $Text.Substring($first, $i - $first).Trim() }
    }
    throw "Unbalanced argument in LaTeX command: $Command"
}
function Get-SourcePreamble([string]$Text, [string]$Template) {
    $documentStart = [regex]::Match($Text, '\\begin\s*\{document\}')
    if (-not $documentStart.Success) { throw 'main.tex must contain \begin{document}.' }
    $extra = $Text.Substring(0, $documentStart.Index)

    # Remove only document metadata, using balanced braces for nested author/title macros.
    $metadata = [regex]::Matches($extra, '\\(?:documentclass|title|author|date)\b(?:\s*\[[^\]]*\])?\s*\{')
    for ($m = $metadata.Count - 1; $m -ge 0; $m--) {
        $start = $metadata[$m]
        $depth = 1
        $end = $start.Index + $start.Length
        while ($end -lt $extra.Length -and $depth -gt 0) {
            $slashes = 0
            for ($j = $end - 1; $j -ge 0 -and $extra[$j] -eq '\'; $j--) { $slashes++ }
            if ($slashes % 2 -eq 0) {
                if ($extra[$end] -eq '{') { $depth++ }
                elseif ($extra[$end] -eq '}') { $depth-- }
            }
            $end++
        }
        if ($depth -ne 0) { throw 'Unbalanced braces in source preamble metadata.' }
        $extra = $extra.Remove($start.Index, $end - $start.Index)
    }

    # Layout/font/citation packages are owned by the reading-copy template.
    $managed = @('fontenc', 'inputenc', 'geometry', 'newtxtext', 'newtxmath',
        'newpxtext', 'newpxmath', 'helvet', 'times', 'mathptmx', 'mathpazo',
        'palatino', 'lmodern', 'fontspec', 'unicode-math', 'natbib', 'titlesec',
        'caption', 'fancyhdr', 'stfloats', 'microtype')
    $packagePattern = '\\(?:usepackage|RequirePackage)\s*(?:\[(?<options>[^\]]*)\]\s*)?\{(?<names>[^{}]+)\}(?:\s*\[(?<version>[^\]]*)\])?'
    $loaded = @{}
    foreach ($match in [regex]::Matches($Template, $packagePattern)) {
        foreach ($name in $match.Groups['names'].Value.Split(',')) { $loaded[$name.Trim()] = $true }
    }
    $packages = [System.Collections.Generic.List[string]]::new()
    $options = [System.Collections.Generic.List[string]]::new()
    $matches = [regex]::Matches($extra, $packagePattern)
    # Process packages in source order, including comma-separated declarations.
    foreach ($match in $matches) {
        foreach ($item in $match.Groups['names'].Value.Split(',')) {
            $name = $item.Trim()
            if ($name -eq 'biblatex') { throw 'biblatex is incompatible with the generated natbib preamble.' }
            if ($name -in $managed) {
                if (-not $loaded.ContainsKey($name) -or $match.Groups['options'].Success) {
                    Write-Warning "Source package '$name' uses the reading-copy template's font/layout/citation settings instead."
                }
                continue
            }
            if ($match.Groups['options'].Success) {
                $options.Add('\PassOptionsToPackage{' + $match.Groups['options'].Value + '}{' + $name + '}')
            }
            if (-not $loaded.ContainsKey($name)) {
                $version = ''
                if ($match.Groups['version'].Success) { $version = '[' + $match.Groups['version'].Value + ']' }
                $packages.Add('\usepackage{' + $name + '}' + $version)
                $loaded[$name] = $true
            }
        }
    }
    for ($m = $matches.Count - 1; $m -ge 0; $m--) {
        $extra = $extra.Remove($matches[$m].Index, $matches[$m].Length)
    }
    return @{
        Options = ($options -join [Environment]::NewLine)
        Packages = ($packages -join [Environment]::NewLine)
        Definitions = $extra.Trim()
    }
}
# Read the author argument with balanced braces (superscripts contain braces).
$metadataSource = [regex]::Replace($source, '(?m)(?<!\\)%.*$', '')
if (-not $Title) { $Title = Get-LatexArgument $metadataSource 'title' }
$abstractMatch = [regex]::Match($metadataSource, '(?s)\\begin\{abstract\}(.*?)\\end\{abstract\}')
$abstract = '\textcolor{red}{[Abstract to be drafted after the results are available.]}'
if ($abstractMatch.Success) { $abstract = $abstractMatch.Groups[1].Value.Trim() }
$authorStart = [regex]::Match($metadataSource, '\\author\s*\{')
if (-not $authorStart.Success) { throw 'main.tex must contain an author block.' }
$contentStart = $authorStart.Index + $authorStart.Length
$depth = 1
$position = $contentStart
while ($position -lt $metadataSource.Length -and $depth -gt 0) {
    $character = $metadataSource[$position]
    if ($position -eq 0 -or $metadataSource[$position - 1] -ne '\') {
        if ($character -eq '{') { $depth++ }
        elseif ($character -eq '}') { $depth-- }
    }
    $position++
}
if ($depth -ne 0) { throw 'Unbalanced braces in the author block.' }
$authorBlock = $metadataSource.Substring($contentStart, $position - $contentStart - 1).Trim()
# Supported layout: names first, then \\[optional spacing], then affiliations.
# Keep all names on the first logical line; further line breaks are affiliations.
if ($authorBlock -match '\\and\b') {
    throw 'Use a single author list followed by \\ and the affiliations, rather than separate \and blocks.'
}
$authorParts = [regex]::new('\\\\(?:\s*\[[^\]]*\])?').Split($authorBlock, 2)
$authors = $authorParts[0].Trim()
# Remove the centred wrapper used by main.tex; this layout sets names flush left.
$authorWrapper = [regex]::Match($authors, '(?s)^\\parbox\{0\.95\\linewidth\}\{\\centering\s+(.*)\}$')
if ($authorWrapper.Success) { $authors = $authorWrapper.Groups[1].Value.Trim() }
if ($authorParts.Count -gt 1) {
    $affiliations = [regex]::Replace($authorParts[1], '\\small\b\s*', '').Trim()
    $affiliations = [regex]::Replace($affiliations, '\\\\(?:\s*\[[^\]]*\])?', ' ')
    $affiliations = [regex]::Replace($affiliations, '\s+', ' ').Trim()
    $affiliations = [regex]::Replace($affiliations, ' (?=\\textsuperscript)', '\quad ')
} else {
    $affiliations = '\textcolor{red}{[Affiliations to be added to the author block in main.tex.]}'
}
if ($source.IndexOf('\section{Introduction}') -lt 0) { throw 'Introduction section marker not found.' }
$body = $source.Substring($source.IndexOf('\section{Introduction}'))
# Published examples begin directly with introductory text, without a heading.
# Retain the source marker in main.tex; suppress only its printed heading here.
$body = $body.Substring('\section{Introduction}'.Length).TrimStart()
$body = $body.Replace('\begin{figure}[htbp]', '\begin{figure*}[tp]').Replace('\end{figure}', '\end{figure*}')
$body = $body.Replace('\begin{table}[htbp]', '\begin{table*}[tp]').Replace('\end{table}', '\end{table*}')
$body = $body.Replace('\includegraphics[width=\textwidth]', '\includegraphics[width=\textwidth,height=0.70\textheight,keepaspectratio]')
$preamble = @'
% Separate reading copy; manuscript wording retained from main.tex.
% Nature Communications-inspired layout, not an official journal template.
\documentclass[9pt,twocolumn]{extarticle}
@@SOURCE_PACKAGE_OPTIONS@@
\usepackage[T1]{fontenc}
\usepackage[utf8]{inputenc}
\usepackage[paperwidth=210mm,paperheight=279mm,left=14mm,right=14mm,top=17mm,bottom=18mm,columnsep=4mm]{geometry}
% Compact Times-style approximation; not the journal's proprietary typeface.
\usepackage{newtxtext,newtxmath}
\usepackage[scaled=0.95]{helvet}
% Reference body is approximately 8.2 pt; use 8.3 pt with 10.3 pt leading.
\makeatletter
\renewcommand\normalsize{\@setfontsize\normalsize{8.3}{10.3}\abovedisplayskip 6pt plus 2pt minus 2pt\belowdisplayskip 6pt plus 2pt minus 2pt}
\makeatother
\normalsize
\usepackage{graphicx,xcolor}
\definecolor{readingCopyRed}{HTML}{EF3829}
\usepackage{microtype}
\usepackage[super,sort&compress]{natbib}
\usepackage{titlesec}
\usepackage{caption}
\usepackage{fancyhdr}
\usepackage{stfloats}
% Additional packages retained from main.tex.
@@SOURCE_PACKAGES@@
\usepackage{hyperref}
% Custom commands and definitions retained from main.tex.
@@SOURCE_DEFINITIONS@@
\hypersetup{colorlinks=true,citecolor=blue,linkcolor=blue,urlcolor=blue}
\setcounter{secnumdepth}{0}
\titleformat{\section}{\rmfamily\fontsize{10.5}{12}\selectfont\bfseries}{\thesection}{0pt}{}
\titleformat{\subsection}{\rmfamily\fontsize{8.5}{10.3}\selectfont\bfseries}{\thesubsection}{0pt}{}
\titlespacing*{\section}{0pt}{9pt}{2pt}
\titlespacing*{\subsection}{0pt}{6pt}{1pt}
\DeclareCaptionLabelSeparator{bar}{\enspace|\enspace}
\captionsetup{font=footnotesize,labelfont=bf,labelsep=bar,justification=justified,singlelinecheck=false}
\renewcommand{\figurename}{Fig.}
\setlength{\parindent}{1em}
\setlength{\parskip}{0pt}
\setlength{\headheight}{13pt}
\pagestyle{fancy}
\fancyhf{}
\fancyhead[L]{\sffamily\fontsize{8}{9.5}\selectfont\bfseries @@CONFIG_HEADER@@}
\fancyhead[R]{\sffamily\fontsize{8}{9.5}\selectfont @@CONFIG_STATUS@@}
\fancyfoot[L]{\sffamily\fontsize{7.5}{9}\selectfont Nature Journal-style reading copy}
\fancyfoot[R]{\sffamily\fontsize{7.5}{9}\selectfont\bfseries\thepage}
\renewcommand{\headrulewidth}{0.65pt}
\renewcommand{\footrulewidth}{0.65pt}
\newcommand{\readingCopyRule}{\par\nointerlineskip\hrule height 0.65pt\relax}
\fancypagestyle{firstpage}{\fancyhead{}\renewcommand{\headrulewidth}{0pt}}
\raggedbottom
\renewcommand{\dbltopfraction}{0.95}
\renewcommand{\textfraction}{0.05}
\renewcommand{\dblfloatpagefraction}{0.85}
\makeatletter
\setlength{\@dblfptop}{0pt}
\makeatother
% Imported from main.tex. Edit author details there before regenerating.
\newcommand{\manuscriptAuthors}{@@AUTHORS@@}
\newcommand{\manuscriptAffiliations}{@@AFFILIATIONS@@}
\newcommand{\manuscriptTitle}{@@TITLE@@}
\begin{document}
\twocolumn[{
\vspace*{-5mm}
{\color{readingCopyRed}\hrule height 4pt}\vspace{3pt}
{\fontsize{20}{22}\selectfont\bfseries nature communications style\par}
\vspace{12mm}
\noindent{\sffamily\fontsize{10.5}{12}\selectfont\bfseries @@CONFIG_ARTICLE_TYPE@@}\par
\vspace{3pt}\readingCopyRule\vspace{4pt}
{\raggedright\fontsize{28}{29}\selectfont\bfseries\manuscriptTitle\par}
\vspace{12mm}\readingCopyRule\vspace{5pt}
\noindent\begin{minipage}[t]{0.32\textwidth}
\sffamily\fontsize{9}{11}\selectfont @@CONFIG_REVIEW@@\par
\vspace{5pt}\readingCopyRule\vspace{5pt}Not a published article\par
\vspace{5pt}\readingCopyRule
\end{minipage}\hfill
\begin{minipage}[t]{0.66\textwidth}
{\raggedright\sffamily\fontsize{10}{12}\selectfont\bfseries\manuscriptAuthors\par}
\vspace{14pt}\readingCopyRule\vspace{6pt}
\fontsize{11}{13.5}\selectfont
@@ABSTRACT@@\par
\end{minipage}
\vspace{20pt}
}]
\thispagestyle{firstpage}
% Full-width bottom float: affiliations sit above the first-page footer.
% Keep this as the first float, immediately after the title block.
\begin{figure*}[!b]
\readingCopyRule\vspace{4pt}
{\sffamily\fontsize{7.5}{9}\selectfont\raggedright\manuscriptAffiliations\par}
\end{figure*}
'@
$sourcePreamble = Get-SourcePreamble $metadataSource $preamble
$preamble = $preamble.Replace('@@SOURCE_PACKAGE_OPTIONS@@', $sourcePreamble.Options)
$preamble = $preamble.Replace('@@SOURCE_PACKAGES@@', $sourcePreamble.Packages)
$preamble = $preamble.Replace('@@SOURCE_DEFINITIONS@@', $sourcePreamble.Definitions)
$preamble = $preamble.Replace('@@AUTHORS@@', $authors).Replace('@@AFFILIATIONS@@', $affiliations)
$preamble = $preamble.Replace('@@TITLE@@', $Title).Replace('@@ABSTRACT@@', $abstract)
$configLabels = @{
    '@@CONFIG_HEADER@@' = (ConvertTo-LatexText $settings.runningHeader)
    '@@CONFIG_STATUS@@' = (ConvertTo-LatexText $settings.documentStatus)
    '@@CONFIG_REVIEW@@' = (ConvertTo-LatexText $settings.reviewNote)
    '@@CONFIG_ARTICLE_TYPE@@' = (ConvertTo-LatexText $settings.articleType)
}
$preamble = [regex]::Replace($preamble, '@@CONFIG_(?:HEADER|STATUS|REVIEW|ARTICLE_TYPE)@@', { param($match) $configLabels[$match.Value] })
[System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($outputPath)) | Out-Null
[System.IO.File]::WriteAllText($outputPath, $preamble + "`r`n" + $body, [System.Text.UTF8Encoding]::new($false))
Write-Output "Generated $outputPath"
