# Windows wrapper for tools/docs/build_pdf.py (VS Code task "Docs: Build PDF").
# Creates the repository .venv from requirements-docs.txt when the docs tools
# are missing, then builds site/SmartManipulator-X.pdf. Extra arguments are
# passed to build_pdf.py (for example -Serve to start the live HTML preview).

param(
    [switch]$Serve,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$PdfArgs = @()
)

# Native tools (pip) write warnings to stderr; failures are detected through
# exit codes below instead of PowerShell error records.
$ErrorActionPreference = 'Continue'

$Root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$Venv = Join-Path $Root '.venv'
$VenvPython = Join-Path $Venv 'Scripts\python.exe'
$Requirements = Join-Path $Root 'requirements-docs.txt'

function Stop-WithError([string]$Message) {
    Write-Host "ERROR: $Message" -ForegroundColor Red
    exit 1
}

function Invoke-Checked([string]$Exe, [string[]]$Arguments) {
    & $Exe @Arguments
    if ($LASTEXITCODE -ne 0) {
        Stop-WithError "Command failed ($LASTEXITCODE): $Exe $($Arguments -join ' ')"
    }
}

function Test-DocsTools {
    if (-not (Test-Path $VenvPython)) { return $false }
    & $VenvPython -c 'import mkdocs, material, mkdocs_print_site_plugin, playwright, pypdf' *> $null
    return ($LASTEXITCODE -eq 0)
}

if (-not (Test-DocsTools)) {
    if (-not (Test-Path $VenvPython)) {
        Write-Host "Creating virtual environment in $Venv"
        if (Get-Command py -ErrorAction SilentlyContinue) {
            Invoke-Checked 'py' @('-3', '-m', 'venv', $Venv)
        }
        elseif (Get-Command python -ErrorAction SilentlyContinue) {
            Invoke-Checked 'python' @('-m', 'venv', $Venv)
        }
        else {
            Stop-WithError 'Python 3.9+ was not found. Install it from https://www.python.org/ and try again.'
        }
    }
    Write-Host 'Installing documentation tools.'
    Invoke-Checked $VenvPython @('-m', 'pip', 'install', '--upgrade', 'pip')
    Invoke-Checked $VenvPython @('-m', 'pip', 'install', '-r', $Requirements)
}

Set-Location $Root
$env:NO_MKDOCS_2_WARNING = '1'
if ($Serve) {
    Write-Host 'Live preview: http://127.0.0.1:8000 (print view: /print_page/). Ctrl+C stops it.'
    Invoke-Checked $VenvPython @('-m', 'mkdocs', 'serve')
}
else {
    Write-Host 'Building the PDF manual (mkdocs + Chromium/Edge).'
    Invoke-Checked $VenvPython (@((Join-Path $Root 'tools\docs\build_pdf.py')) + $PdfArgs)
}
