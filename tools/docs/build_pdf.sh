#!/usr/bin/env bash
# Linux wrapper for tools/docs/build_pdf.py (VS Code task "Docs: Build PDF").
# Creates a Python venv with requirements-docs.txt and Playwright's Chromium
# when the docs tools are missing, then builds site/SmartManipulator-X.pdf.
# "--serve" starts the live HTML preview instead; other arguments are passed
# to build_pdf.py.
#
# If the repository is shared with Windows (bind mount), a Windows .venv
# (Scripts/) is left alone and a separate .venv-linux is used instead.
set -euo pipefail

cd "$(dirname "$0")/../.."

venv=.venv
if [ -d .venv/Scripts ] && [ ! -x .venv/bin/python ]; then
    venv=.venv-linux
fi
py=$venv/bin/python

if ! { [ -x "$py" ] && "$py" -c 'import mkdocs, material, mkdocs_print_site_plugin, playwright, pypdf' >/dev/null 2>&1; }; then
    echo "Setting up documentation tools in ${venv}."
    python3 -m venv "$venv"
    "$py" -m pip install --upgrade pip
    "$py" -m pip install -r requirements-docs.txt
    if [ "$(id -u)" = 0 ]; then
        "$py" -m playwright install --with-deps chromium
    else
        "$py" -m playwright install chromium
    fi
fi

export NO_MKDOCS_2_WARNING=1
if [ "${1:-}" = "--serve" ]; then
    echo 'Live preview: http://127.0.0.1:8000 (print view: /print_page/). Ctrl+C stops it.'
    exec "$py" -m mkdocs serve
fi

echo 'Building the PDF manual (mkdocs + Chromium).'
"$py" tools/docs/build_pdf.py "$@"
