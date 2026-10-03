#!/usr/bin/env bash
# obsidian-offsite.sh — copia CIFRADA diaria del repo de respaldo hacia Google Drive
#
# Protege contra muerte del disco (el historial sobrevive fuera de este equipo).
# El repo de restic ya está cifrado → Google nunca ve el contenido en claro.
#
# Uso: obsidian-offsite.sh
#
# Seguridad:
#   * --max-delete 100 → si el repo local estuviera corrupto/vacío, ABORTA
#     en vez de vaciar la copia remota de un saque.
#   * flock compartido con obsidian-restic.sh → nunca copia paquetes a medias.
#   * rclone sync (no copy) → tras el prune, los paquetes ya no referenciados
#     se retiran también del remoto.
#
# Log: ~/.local/state/rclone/obsidian-offsite.log

set -uo pipefail

REPO="$HOME/Backups/obsidian-restic"
DEST="archdive:Respaldos/obsidian-restic"
LOGDIR="$HOME/.local/state/rclone"
LOG="$LOGDIR/obsidian-offsite.log"
LOCK="$LOGDIR/obsidian-backup.lock"   # lock compartido con obsidian-restic.sh

mkdir -p "$LOGDIR"
[[ -f "$LOG" && "$(stat -c%s "$LOG")" -gt 1048576 ]] && mv -f "$LOG" "$LOG.1"

exec 9>"$LOCK"
if ! flock -n 9; then
    # El backup local puede estar corriendo (mismo lock). Esperamos y reintentamos:
    # perder este run significaría 24 h sin copia offsite.
    echo "$(date -Is) [aviso] respaldo local en curso → espero 60 s" >>"$LOG"
    sleep 60
    if ! flock -n 9; then
        echo "$(date -Is) [aviso] sigue ocupado → se omite este run" >>"$LOG"
        exit 0
    fi
fi

# Salvaguardas antes de tocar el remoto.
# (El vault es de 13 MB → apenas 2 packs; por eso verificamos la ESTRUCTURA
#  del repo en lugar de un conteo arbitrario de ficheros.)
n_packs=$(find "$REPO/data" -type f 2>/dev/null | wc -l)
n_snaps=$(find "$REPO/snapshots" -type f 2>/dev/null | wc -l)
if [[ ! -f "$REPO/config" || "$n_snaps" -lt 1 || "$n_packs" -lt 1 ]]; then
    echo "$(date -Is) [FALLO] repo local inválido (config=$([[ -f $REPO/config ]] && echo sí || echo no), snaps=$n_snaps, packs=$n_packs) → sync abortado" >>"$LOG"
    notify-send -u critical "⚠️ Copia offsite cancelada" "Repo local inválido; copia en Drive intacta." 2>/dev/null
    exit 1
fi

{
    echo "$(date -Is) [inicio] sync offsite ($n_packs packs, $n_snaps snapshots)"
    rclone sync "$REPO" "$DEST" \
        --max-delete 100 \
        --transfers 4 --checkers 4 \
        --low-level-retries 3 --retries 2 \
        --stats-one-line --stats 10s
    rc=$?
    if [[ $rc -ne 0 ]]; then
        echo "$(date -Is) [FALLO] rclone sync exit=$rc"
        notify-send -u critical "⚠️ Copia offsite del respaldo falló" "exit=$rc · ver $LOG" 2>/dev/null
        exit $rc
    fi
    echo "$(date -Is) [ok] offsite sincronizado → $DEST"
} >>"$LOG" 2>&1

exit 0
