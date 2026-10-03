#!/usr/bin/env bash
# obsidian-bisync.sh — sincronización bidireccional del vault Obsidian con Google Drive
#
# Uso:
#   obsidian-bisync.sh              sync normal (cortacircuito --max-delete activo)
#   obsidian-bisync.sh --force      permite borrados masivos (>10 archivos)
#   obsidian-bisync.sh --resync     fuerza resync completo (estado perdido/corrupto)
#
# Seguridad:
#   * --max-delete 10  → si intenta borrar más de 10 archivos de golpe, ABORTA
#     y deja Drive intacto (protege contra borrado accidental masivo).
#   * --recover/--resilient → se auto-recupera de interrupciones sin --resync.
#   * Filtros simétricos → basura local nunca viaja a Drive ni a Windows.
#   * flock → el timer cada 5 min no solapa ejecuciones.
#
# Estado : ~/.cache/rclone/bisync/obsidian
# Log    : ~/.local/state/rclone/obsidian-bisync.log

set -uo pipefail

VAULT_LOCAL="$HOME/Drive/Obsidian Vault"
VAULT_REMOTE="ovault:"
WORKDIR="$HOME/.cache/rclone/bisync/obsidian"
LOGDIR="$HOME/.local/state/rclone"
LOG="$LOGDIR/obsidian-bisync.log"
LOCK="$LOGDIR/obsidian-bisync.lock"
MAX_DELETE=10

FORCE=0
RESYNC=0
for arg in "$@"; do
    case "$arg" in
        --force)  FORCE=1 ;;
        --resync) RESYNC=1 ;;
        -h|--help) sed -n '2,16p' "$0"; exit 0 ;;
        *) echo "argumento desconocido: $arg  (ver --help)" >&2; exit 2 ;;
    esac
done

mkdir -p "$WORKDIR" "$LOGDIR"

# rotación del log si pasa de 1 MB
if [[ -f "$LOG" && "$(stat -c%s "$LOG")" -gt 1048576 ]]; then
    mv -f "$LOG" "$LOG.1"
fi

# --- lock: evita ejecuciones solapadas -------------------------------------
exec 9>"$LOCK"
if ! flock -n 9; then
    echo "$(date -Is) [aviso] otra instancia en curso → se omite este run" >>"$LOG"
    exit 0
fi

# --- salvaguarda: si el vault no existe, NO sincronizar ---------------------
if [[ ! -d "$VAULT_LOCAL" ]]; then
    msg="$(date -Is) [FALLO] no existe: $VAULT_LOCAL — sync abortado (no se borra nada)"
    echo "$msg" >>"$LOG"
    notify-send -u critical "🔒 Vault Obsidian no encontrado" \
        "No existe $VAULT_LOCAL. Sincronización abortada; Drive queda intacto." 2>/dev/null
    exit 1
fi

# --- aviso: nombres con caracteres que WINDOWS no permite --------------------
# (\ / : * ? " < > |) → Drive los guarda, pero Drive for Desktop NO puede
# crearlos en NTFS y se saltará esa carpeta/fichero en el PC de Windows.
# Solo avisa; no bloquea la sincronización.
# (%P → ruta RELATIVA. OJO: '/' va FUERA de la clase: es el separador que
#  introduce %P y en Linux es imposible dentro de un nombre, así que cualquier
#  match restante viene sí o sí del nombre real del fichero/carpeta.)
bad=$(find "$VAULT_LOCAL" -depth -printf '%P\n' 2>/dev/null | LC_ALL=C grep -E '[\\:*?"<>|]' || true)
if [[ -n "$bad" ]]; then
    n=$(printf '%s\n' "$bad" | wc -l)
    echo "$(date -Is) [aviso-caracteres] $n ruta(s) con caracteres ilegales para Windows:" >>"$LOG"
    printf '%s\n' "$bad" | sed 's/^/    /' >>"$LOG"
    notify-send -u normal "⚠️ Nombre incompatible con Windows" \
        "$n ruta(s) en el vault usan \\ / : * ? \" < > | — Drive las guarda, pero Windows no podrá crearlas.
Revisa el log: $LOG" 2>/dev/null
fi

# --- flags -------------------------------------------------------------------
ARGS=(
    bisync "$VAULT_LOCAL" "$VAULT_REMOTE"
    --workdir "$WORKDIR"
    --verbose
    --recover
    --resilient
    --conflict-suffix conflict
    --max-delete "$MAX_DELETE"
    --create-empty-src-dirs
    --exclude ".directory"
    --exclude ".trash/**"
    --exclude ".obsidian/workspace*.json"
    --exclude "*.tmp"
)

# primera ejecución (sin estado) o resync forzado
if [[ "$RESYNC" == 1 || -z "$(ls -A "$WORKDIR" 2>/dev/null)" ]]; then
    ARGS+=(--resync)
fi

[[ "$FORCE" == 1 ]] && ARGS+=(--force)

# --- ejecución ---------------------------------------------------------------
echo "$(date -Is) [inicio] max-delete=$MAX_DELETE force=$FORCE resync=$RESYNC" >>"$LOG"
rclone "${ARGS[@]}" >>"$LOG" 2>&1
rc=$?

if [[ $rc -eq 0 ]]; then
    echo "$(date -Is) [ok] sincronización correcta" >>"$LOG"
    exit 0
fi

# --- fallo: diagnosticar y avisar --------------------------------------------
tail -n 40 "$LOG" >"$LOGDIR/.last-error"
if grep -qiE 'max delete|MaxDelete|--max-delete' "$LOGDIR/.last-error"; then
    notify-send -u critical "🔒 Borrado masivo bloqueado" \
        "Se intentaron borrar más de $MAX_DELETE archivos del vault y se ABORTÓ (Drive intacto).
Si era intencional: obsidian-bisync.sh --force" 2>/dev/null
    echo "$(date -Is) [BLOQUEO] --max-delete superado → sync abortado" >>"$LOG"
elif grep -qiE 'directory not found|no such file' "$LOGDIR/.last-error"; then
    notify-send -u critical "⚠️ Ruta de sync no encontrada" \
        "Revisa la configuración del vault (ovault: / $VAULT_LOCAL)." 2>/dev/null
    echo "$(date -Is) [FALLO] ruta no encontrada" >>"$LOG"
else
    notify-send -u critical "⚠️ Bisync del vault falló" \
        "Exit $rc. Detalle en $LOG" 2>/dev/null
    echo "$(date -Is) [FALLO] exit=$rc" >>"$LOG"
fi
exit $rc
