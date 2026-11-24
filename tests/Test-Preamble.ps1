param(
    [string[]]$GeneratorPaths = @((Join-Path (Split-Path $PSScriptRoot -Parent) 'nature-tex-gen.ps1'))
)
$ErrorActionPreference = 'Stop'
$fixture = @'
\documentclass{article}
\usepackage{graphicx,booktabs,tabularx,multirow}
\usepackage[table]{xcolor}
\RequirePackage{array}
\usepackage{graphicx}
\title{A {nested} title}
\author{First Author\textsuperscript{1}\\\small\textsuperscript{1}Test affiliation}
\date{}
\newcommand{\sample}[1]{\textbf{#1}}
\newcolumntype{L}{>{\raggedright\arraybackslash}X}
\begin{document}
\maketitle
\begin{abstract}A test abstract.\end{abstract}
\section{Introduction}
\sample{A retained custom command.}
\begin{table}[htbp]
\centering
\begin{tabularx}{\linewidth}{LL}
\toprule
\multirow{2}{*}{A} & B \\
 & C \\
\bottomrule
\end{tabularx}
\caption{A retained table package and column-type test.}
\end{table}
\end{document}
'@
foreach ($generator in $GeneratorPaths) {
    $generator = (Resolve-Path -LiteralPath $generator).Path
    $testDirectory = Join-Path (Split-Path $PSScriptRoot -Parent) ('output/preamble-test-' + [guid]::NewGuid().ToString('N'))
    [System.IO.Directory]::CreateDirectory($testDirectory) | Out-Null
    $testScript = Join-Path $testDirectory 'generator.ps1'
    Copy-Item -LiteralPath $generator -Destination $testScript
    [System.IO.File]::WriteAllText((Join-Path $testDirectory 'main.tex'), $fixture)
    [System.IO.File]::WriteAllText((Join-Path $testDirectory 'config.json'), '{}')
    & $testScript -OutputFile result.tex
    $generated = Get-Content -LiteralPath (Join-Path $testDirectory 'result.tex') -Raw
    foreach ($required in @('\usepackage{booktabs}', '\usepackage{tabularx}', '\usepackage{multirow}',
        '\newcommand{\sample}[1]{\textbf{#1}}', '\newcolumntype{L}', '\PassOptionsToPackage{table}{xcolor}')) {
        if (-not $generated.Contains($required)) { throw "Missing retained definition: $required" }
    }
    $graphicxLoads = 0
    foreach ($match in [regex]::Matches($generated, '\\usepackage(?:\[[^\]]*\])?\{([^}]+)\}')) {
        if ('graphicx' -in $match.Groups[1].Value.Split(',')) { $graphicxLoads++ }
    }
    if ($graphicxLoads -ne 1) { throw 'graphicx was not deduplicated.' }
    Push-Location $testDirectory
    try {
        & pdflatex -interaction=nonstopmode -halt-on-error result.tex | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Fixture compilation failed; inspect $testDirectory/result.log" }
    } finally { Pop-Location }
    Write-Output "PASS: packages, options, deduplication, nested metadata and custom commands: $generator"
}
