#!/usr/bin/env bash
# backup.sh — Sube los cambios de configuración a GitHub en un comando
# Uso:  ./backup.sh "mensaje opcional"
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

MSG="${1:-"backup: $(date '+%Y-%m-%d %H:%M')"}"

git add -A

if git diff --cached --quiet; then
    echo "✔ Nada que respaldar (todo ya está subido)."
    exit 0
fi

echo "==> Cambios a respaldar:"
git status --short
echo

git commit -m "$MSG"
git push backup main
echo
echo "✔ Respaldado en GitHub: https://github.com/galeanojuan2577/ConfArch"
