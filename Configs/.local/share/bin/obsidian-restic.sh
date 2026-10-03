#!/usr/bin/env bash
# obsidian-restic.sh — respaldo de emergencia del vault Obsidian (versionado + cifrado)
#
# Uso:
#   obsidian-restic.sh            backup + retención + check
#   obsidian-restic.sh --list     listar snapshots
#   obsidian-restic.sh --restore  restaurar el último snapshot (ver abajo)
#
# El repo vive FUERA de ~/Drive → bisync jamás lo toca.
# La contraseña vive en ~/.config/restic/password (chmod 600) → NUNCA al git.
#
# Retención: 48 h · 14 días · 8 semanas · 6 meses
# Log: ~/.local/state/rclone/obsidian-restic.log

set -uo pipefail

REPO="$HOME/Backups/obsidian-restic"
VAULT="$HOME/Drive/Obsidian Vault"
PW="$HOME/.config/restic/password"
LOGDIR="$HOME/.local/state/rclone"
LOG="$LOGDIR/obsidian-restic.log"
LOCK="$LOGDIR/obsidian-backup.lock"   # lock compartido con obsidian-offsite.sh
KEEP=(
    --keep-hourly 48
    --keep-daily 14
    --keep-weekly 8
    --keep-monthly 6
)

export RESTIC_REPOSITORY="$REPO"
export RESTIC_PASSWORD_FILE="$PW"

mkdir -p "$LOGDIR"
[[ -f "$LOG" && "$(stat -c%s "$LOG")" -gt 1048576 ]] && mv -f "$LOG" "$LOG.1"

case "${1:-}" in
    --list)    exec restic snapshots ;;
    --restore)
        restic snapshots | tail -20
        echo
        echo "Para restaurar:"
        echo "  RESTIC_REPOSITORY=$REPO RESTIC_PASSWORD_FILE=$PW \\"
        echo "    restic restore latest --target /tmp/restaurar-obsidian"
        echo "  # revisar y copiar de vuelta a: $VAULT"
        exit 0 ;;
    -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
    "") : ;;
    *) echo "argumento desconocido: $1 (ver --help)" >&2; exit 2 ;;
esac

# --- lock compartido (evita que el offsite copie paquetes a medias) ---------
# Si el offsite está corriendo esperamos: perder este run alargaría la
# ventana de riesgo de 15 a 30 min.
exec 9>"$LOCK"
if ! flock -n 9; then
    echo "$(date -Is) [aviso] otra tarea de respaldo en curso → espero 60 s" >>"$LOG"
    sleep 60
    if ! flock -n 9; then
        echo "$(date -Is) [aviso] sigue ocupado → se omite este run (nuevo intento en 15 min)" >>"$LOG"
        exit 0
    fi
fi

if [[ ! -d "$VAULT" ]]; then
    echo "$(date -Is) [FALLO] no existe $VAULT → no se hace respaldo" >>"$LOG"
    notify-send -u critical "🔒 Vault no encontrado" "No hay vault que respaldar: $VAULT" 2>/dev/null
    exit 1
fi

{
    echo "$(date -Is) [inicio] backup del vault"
    restic backup "$VAULT" \
        --exclude "*.tmp" --exclude ".trash/**" \
        --tag obsidian --quiet --quiet
    rc=$?
    if [[ $rc -ne 0 ]]; then
        echo "$(date -Is) [FALLO] restic backup exit=$rc"
        notify-send -u critical "⚠️ Respaldo del vault falló" "restic backup exit=$rc · ver $LOG" 2>/dev/null
        exit $rc
    fi

    # retención: nunca borra los snapshots necesarios, solo los viejos
    restic forget "${KEEP[@]}" --prune --quiet
    rc=$?
    [[ $rc -ne 0 ]] && echo "$(date -Is) [AVISO] forget/prune exit=$rc"

    # verificación de integridad del repo
    restic check --quiet
    rc=$?
    if [[ $rc -ne 0 ]]; then
        echo "$(date -Is) [FALLO] restic check exit=$rc"
        notify-send -u critical "⚠️ Integridad del respaldo dudosa" "restic check exit=$rc · ver $LOG" 2>/dev/null
        exit $rc
    fi

    n=$(restic snapshots --tag obsidian --latest 1 2>/dev/null | grep -c snapshot || true)
    echo "$(date -Is) [ok] backup+prune+check correctos"
} >>"$LOG" 2>&1

exit 0
