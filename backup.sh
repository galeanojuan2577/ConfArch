#!/usr/bin/env bash
# =============================================================================
# backup.sh — Sube los cambios de configuración a GitHub (ConfArch) en un comando
#
# Uso:   ./backup.sh "mensaje opcional"
#
# Por qué usa la rama 'confarch' y no 'main':
#   ~/Hyprdots es un *shallow clone* del upstream de HyDE (~974 MB de historia
#   recortada). Si haces push de 'main', Git intenta enviar los padres que
#   faltan en el corte y GitHub rechaza el pack ("did not receive expected
#   object"). La rama 'confarch' nace como commit RAÍZ (sin padres) con el
#   mismo contenido que 'main', por eso se puede empujar sin problemas.
#   Cada backup crea un commit encima de 'confarch' → historial incremental
#   limpio en https://github.com/galeanojuan2577/ConfArch
# =============================================================================
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

MSG="${1:-"backup: $(date '+%Y-%m-%d %H:%M')"}"

# 1) Stage de todo cambio (los ignorados por .gitignore quedan fuera)
git add -A

# 2) Commit local en main (para que 'git status' quede limpio y haya historial)
if ! git diff --cached --quiet; then
    git commit -q -m "$MSG"
    echo "✔ Commit local en main: $(git log --oneline -1)"
else
    echo "· Sin cambios nuevos en main"
fi

# 3) Espejar el árbol de main hacia confarch (historial independiente)
main_tree=$(git rev-parse 'main^{tree}')
conf_tree=$(git rev-parse 'confarch^{tree}' 2>/dev/null || true)

if [[ "$main_tree" != "$conf_tree" ]]; then
    prev=$(git rev-parse confarch)
    new=$(printf '%s\n' "$MSG" | git commit-tree "$main_tree" -p "$prev")
    git update-ref refs/heads/confarch "$new"
    echo "✔ confarch actualizado: $(git log --oneline -1 confarch)"
else
    echo "· confarch ya refleja a main"
fi

# 4) Push a GitHub (confarch → main remoto; fast-forward seguro)
echo "==> Subiendo a ConfArch…"
if git push backup confarch:main; then
    echo
    echo "✔ Respaldado: https://github.com/galeanojuan2577/ConfArch"
    echo "  rama local 'main'      → historial + HyDE upstream (no se sube, es shallow)"
    echo "  rama local 'confarch'  → la que vive en GitHub como 'main'"
else
    echo "✖ El push falló. Revisa el mensaje de git arriba." >&2
    exit 1
fi
