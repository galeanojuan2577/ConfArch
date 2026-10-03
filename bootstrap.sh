#!/usr/bin/env bash
# =============================================================================
# bootstrap.sh — Recupera el ambiente HyDE/Arch desde este repo
# Uso en un Arch nuevo (o tras reinstalar):
#   git clone git@github.com:galeanojuan2577/ConfArch.git ~/Hyprdots
#   cd ~/Hyprdots && ./bootstrap.sh [--dry-run]
#
# Pasos que ejecuta:
#   1. Habilita multilib (Steam/32-bit)
#   2. Instala paquetes oficiales desde pkglist/pacman.txt
#   3. Instala yay (si falta) y paquetes AUR desde pkglist/aur.txt
#   4. Restaura los dotfiles de Configs/ hacia $HOME (sin pisar lo tuyo con --dry-run)
#   5. Crea los symlinks de compatibilidad swww -> awww (Arch renombró el paquete)
#   6. Agrega el usuario al grupo input (gestos de touchpad; requiere relogin)
#   7. Aplica teclado latam + verifica la config de Hyprland
# =============================================================================
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRCDIR="$REPO_DIR/Configs"
DRYRUN="${1:-}"

log()  { printf '\033[1;36m==> %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m  ✔ %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m  ! %s\033[0m\n' "$*"; }
die()  { printf '\033[1;31m  ✖ %s\033[0m\n' "$*" >&2; exit 1; }

run() {
    if [[ -n "$DRYRUN" ]]; then printf '  [dry-run] %s\n' "$*"; else eval "$@"; fi
}

[[ -d "$SRCDIR" ]] || die "No se encontró $SRCDIR — clona el repo completo."

# --- 0) Requisitos -----------------------------------------------------------
if [[ -n "$DRYRUN" ]]; then
    log "MODO DRY-RUN: no se modifica nada (ni se pide sudo)"
else
    [[ $EUID -ne 0 ]] || die "Ejecuta como usuario normal (usa sudo dentro)."
    command -v sudo >/dev/null || die "sudo no disponible"
    if ! sudo -n true 2>/dev/null; then
        log "Se pedirá tu contraseña sudo"
        sudo -v || die "Se requiere sudo"
    fi
fi

# --- 1) multilib -------------------------------------------------------------
if ! grep -q '^\[multilib\]' /etc/pacman.conf 2>/dev/null; then
    log "Habilitando repo multilib"
    run "sudo sed -i '/^#\[multilib\]/,/^\[core\]/ s/^#\[multilib\]/[multilib]/; /^#Include = \/etc\/pacman.d\/mirrorlist/ s/^#Include/Include/' /etc/pacman.conf"
    run "sudo pacman -Sy --noconfirm"
else
    ok "multilib ya habilitado"
fi

# --- 2) Paquetes oficiales ---------------------------------------------------
log "Instalando paquetes oficiales ($(grep -c . "$REPO_DIR/pkglist/pacman.txt") en lista)"
# pkglist/pacman.txt tiene formato "nombre versión" -> nos quedamos con el nombre,
# y filtramos los -debug (símbolos, opcionales) para un sistema limpio.
mapfile -t PKGS < <(awk '{print $1}' "$REPO_DIR/pkglist/pacman.txt" | grep -v -- '-debug$')
run "sudo pacman -S --needed --noconfirm ${PKGS[*]}"

# --- 3) yay + AUR ------------------------------------------------------------
if ! command -v yay >/dev/null; then
    log "Instalando yay desde AUR"
    run "sudo pacman -S --needed --noconfirm git base-devel"
    run "cd /tmp && rm -rf yay-build && git clone --quiet https://aur.archlinux.org/yay-bin.git yay-build && cd yay-build && makepkg -si --noconfirm --needed"
fi
ok "yay disponible: $(command -v yay || echo pendiente)"

log "Instalando paquetes AUR ($(wc -l < "$REPO_DIR/pkglist/aur.txt"))"
mapfile -t AURPKGS < <(awk '{print $1}' "$REPO_DIR/pkglist/aur.txt" | grep -v -- '-debug$')
if command -v yay >/dev/null; then
    # opencode-beta puede no existir en AUR en el futuro -> no fatal
    run "yay -S --needed --noconfirm ${AURPKGS[*]}" || warn "Algún paquete AUR falló (revisa arriba); continúo"
else
    warn "yay no instalado -> se omiten los AUR"
fi

# --- 4) Restaurar dotfiles ---------------------------------------------------
log "Restaurando dotfiles desde Configs/ → \$HOME"
# Copia preservando estructura. Los archivos que ya existen y difieren se
# respaldan con sufijo .pre-restore la primera vez.
restore() {
    local src="$1" dst="$2"
    if [[ -n "$DRYRUN" ]]; then printf '  [dry-run] %s -> %s\n' "$src" "$dst"; return; fi
    mkdir -p "$(dirname "$dst")"
    if [[ -e "$dst" && ! -L "$dst" ]] && ! cmp -s "$src" "$dst"; then
        cp -a "$dst" "$dst.pre-restore"
    fi
    cp -a "$src" "$dst"
}
while IFS= read -r -d '' f; do
    rel="${f#"$SRCDIR"/}"
    # basura que no debe restaurarse (mismos excludes que .gitignore)
    case "$rel" in
        *.bak|*.save|*_backup/*|*/_lua_backup/*|*_pre_compat_fix/*|*cfg_backups/*|*themes/colors.conf) continue ;;
    esac
    restore "$f" "$HOME/$rel"
done < <(find "$SRCDIR" -type f -print0)
ok "dotfiles restaurados (los reemplazados guardan *.pre-restore)"

# --- 5) Symlinks swww -> awww ------------------------------------------------
log "Creando symlinks de compatibilidad swww → awww"
if command -v awww >/dev/null && [[ ! -e /usr/local/bin/swww ]]; then
    run "sudo ln -sf /usr/bin/awww /usr/local/bin/swww"
    run "sudo ln -sf /usr/bin/awww-daemon /usr/local/bin/swww-daemon"
    ok "swww -> awww"
elif [[ -e /usr/local/bin/swww ]]; then
    ok "symlinks ya existen"
else
    warn "awww no instalado (falta el paquete) — se omite"
fi

# --- 6) Grupo input (gestos) -------------------------------------------------
if ! id -nG | tr ' ' '\n' | grep -qx input; then
    log "Agregando usuario al grupo input (gestos de touchpad)"
    run "sudo usermod -aG input $USER"
    warn "Requiere cerrar sesión para surtir efecto"
else
    ok "usuario ya en el grupo input"
fi

# --- 7) Teclado latam + verificación ----------------------------------------
log "Verificando teclado latam en userprefs.conf"
if grep -q 'kb_layout = latam' "$HOME/.config/hypr/userprefs.conf" 2>/dev/null; then
    ok "kb_layout = latam presente"
else
    warn "No encontré 'kb_layout = latam' en userprefs.conf — revísalo"
fi

if command -v Hyprland >/dev/null; then
    log "Validando config de Hyprland"
    if Hyprland --verify-config 2>&1 | grep -q 'config ok'; then
        ok "Hyprland: config ok"
    else
        warn "Hyprland reportó problemas — ejecuta: Hyprland --verify-config"
    fi
fi

# --- 8) Timers del vault Obsidian (sync + respaldo de emergencia) ------------
log "Activando timers del vault Obsidian"
if command -v systemctl >/dev/null && systemctl --user show-environment >/dev/null 2>&1; then
    run "systemctl --user daemon-reload" || warn "daemon-reload falló"
    for t in rclone-obsidian.timer obsidian-restic.timer obsidian-offsite.timer; do
        if [[ -f "$HOME/.config/systemd/user/$t" ]]; then
            run "systemctl --user enable --now $t" && ok "$t"
        else
            warn "$t no está en ~/.config/systemd/user"
        fi
    done
    # El remote 'ovault:' vive en rclone.conf, que POR DISEÑO no va al git.
    if rclone listremotes 2>/dev/null | grep -qx 'ovault:'; then
        ok "remote 'ovault:' presente"
    else
        warn "FALTA el remote 'ovault:' en ~/.config/rclone/rclone.conf"
        warn "  → sin él, rclone-obsidian fallará (el resto funciona)"
        warn "  → ver README: sección 'Vault Obsidian'"
    fi
    # El repo de restic + su contraseña tampoco van al git.
    if [[ -f "$HOME/.config/restic/password" && -d "$HOME/Backups/obsidian-restic" ]]; then
        ok "repo de respaldo restic presente"
    else
        warn "FALTA el repo de respaldo restic (ver README: 'Recuperar el vault')"
        warn "  → restic init + generar contraseña en ~/.config/restic/password"
    fi
else
    warn "systemctl --user no disponible — activa los timers a mano"
fi

log "Listo. Próximos pasos manuales:"
cat <<'EOF'
  · Reinicia sesión (grupo input + gestos activos)
  · Abre una consola: verás el logo de Arch (fastfetch)
  · Atajos: Super+1..9 workspaces · Super+A launcher · Super+Shift+T temas
EOF
