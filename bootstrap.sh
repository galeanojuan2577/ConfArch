#!/usr/bin/env bash
# =============================================================================
# bootstrap.sh — Recupera el ambiente HyDE/Arch desde este repo
# Uso en un Arch nuevo (o tras reinstalar):
#   git clone git@github.com:galeanojuan2577/ConfArch.git ~/Hyprdots
#   cd ~/Hyprdots && ./bootstrap.sh [--dry-run] [--pentest]
#
# Flags:
#   --dry-run / -n   no modifica nada (ni pide sudo); solo imprime lo que haría
#   --pentest        además instala el toolchain de pentesting/bug bounty
#   --help / -h      muestra esta ayuda
#
# Pasos que ejecuta:
#   1. Habilita multilib (Steam/32-bit)
#   2. Instala paquetes oficiales desde pkglist/pacman.txt
#   3. Instala yay (si falta) y paquetes AUR desde pkglist/aur.txt
#   4. Restaura los dotfiles de Configs/ hacia $HOME (sin pisar lo tuyo con --dry-run)
#   5. Crea los symlinks de compatibilidad swww -> awww (Arch renombró el paquete)
#   6. Agrega el usuario al grupo input (gestos de touchpad; requiere relogin)
#   7. Aplica teclado latam + verifica la config de Hyprland
#   8. Activa los timers del vault Obsidian (sync + respaldo de emergencia)
#   9. (--pentest) instala el toolchain desde pkglist/pentest.txt, repara los
#      PKGBUILDs rotos de AUR, aplica permisos de red (grupo wireshark + setcap
#      en nmap/bettercap) y corre los scripts de scripts/pentest-*.sh (Go/pipx,
#      recon-ng y las 4 herramientas Python que pipx no puede empaquetar)
# =============================================================================
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRCDIR="$REPO_DIR/Configs"
DRYRUN=""
PENTEST=""

log()  { printf '\033[1;36m==> %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m  ✔ %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m  ! %s\033[0m\n' "$*"; }
die()  { printf '\033[1;31m  ✖ %s\033[0m\n' "$*" >&2; exit 1; }

run() {
    if [[ -n "$DRYRUN" ]]; then printf '  [dry-run] %s\n' "$*"; else eval "$@"; fi
}

# --- Flags -------------------------------------------------------------------
for _arg in "$@"; do
    case "$_arg" in
        --dry-run|-n) DRYRUN="--dry-run" ;;
        --pentest)    PENTEST="--pentest" ;;
        --help|-h)
            # imprime el bloque de comentario inicial hasta la primera línea no-comentario
            awk 'NR>1 && /^#/ { sub(/^# ?/,""); print; next } NR>1 { exit }' \
                "${BASH_SOURCE[0]}"
            exit 0 ;;
        *) die "Flag desconocido: $_arg  (usa --dry-run, --pentest o --help)" ;;
    esac
done

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

# --- 9) Toolchain de pentesting (solo con --pentest) --------------------------
if [[ -n "$PENTEST" ]]; then
    log "Instalando toolchain de pentesting (bug bounty)"

    # 9a) paquetes — yay resuelve tanto repo oficial como AUR desde una sola lista
    #     IMPORTANTE: quitar comentarios y líneas en blanco ANTES de extraer el
    #     nombre. Si no, awk devuelve '#' por cada comentario, y al interpolarse
    #     dentro del comando ese '#' comenta el resto de la línea en la shell:
    #     yay no recibiría ni un solo paquete y el paso parecería haber ido bien.
    if [[ -f "$REPO_DIR/pkglist/pentest.txt" ]]; then
        mapfile -t PT < <(
            grep -vE '^[[:space:]]*(#|$)' "$REPO_DIR/pkglist/pentest.txt" \
              | awk '{print $1}' \
              | grep -v -- '-debug$'
        )
        log "  ${#PT[@]} herramientas en pkglist/pentest.txt"
        if [[ ${#PT[@]} -eq 0 ]]; then
            warn "pkglist/pentest.txt no aportó ningún paquete (¿solo comentarios?)"
        elif command -v yay >/dev/null; then
            # no fatal: algún PKGBUILD puede estar roto upstream (ver README)
            run "yay -S --needed --noconfirm ${PT[*]}" \
                || warn "Algún paquete del toolchain falló (revisa arriba); continúo"
        else
            warn "yay no disponible -> se omite el toolchain AUR"
        fi
    else
        warn "FALTA pkglist/pentest.txt -> se omite el toolchain"
    fi

    # 9b) reparación de los PKGBUILDs que sabemos que vienen rotos de AUR
    #     Algunos paquetes de arriba NO se instalan al intentar, y no por nuestra
    #     culpa: los PKGBUILDs de AUR no compilan tal cual (httpx, naabu,
    #     dirsearch, android-apktool, y python2 porque su test() de Python 2.7
    #     falla 2 tests en kernels modernos). El paso anterior ya lo avisa con un
    #     warn y sigue; aquí se arreglan de verdad, con sustitutos auditados y
    #     makepkg --nocheck. Es idempotente: lo que ya está instalado lo omite.
    #     Ver la cabecera de scripts/pentest-repair.sh (5 pasos).
    if [[ -f "$REPO_DIR/scripts/pentest-repair.sh" ]]; then
        log "  pentest-repair.sh (PKGBUILDs rotos de AUR)"
        if [[ -n "$DRYRUN" ]]; then
            printf '  [dry-run] %s\n' "bash scripts/pentest-repair.sh"
        else
            bash "$REPO_DIR/scripts/pentest-repair.sh" \
                || warn "pentest-repair con fallos; el inventario dirá qué queda"
        fi
    else
        warn "FALTA scripts/pentest-repair.sh -> los PKGBUILDs rotos quedan sin arreglar"
    fi

    # 9c) herramientas Go/Python que no están en pacman ni AUR
    #     (gf, anew, qsreplace, haktrails, katana, kxss + fierce, droopescan)
    if [[ -f "$REPO_DIR/scripts/pentest-gopipx.sh" ]]; then
        log "  Go modules + pipx"
        if [[ -n "$DRYRUN" ]]; then
            printf '  [dry-run] %s\n' "bash scripts/pentest-gopipx.sh"
        else
            bash "$REPO_DIR/scripts/pentest-gopipx.sh" || warn "go/pipx con fallos; revisa arriba"
        fi
    else
        warn "FALTA scripts/pentest-gopipx.sh -> se omiten Go modules y pipx"
    fi

    # 9d) permisos de red para escanear sin root
    log "Aplicando permisos de red (grupo wireshark + setcap)"
    if getent group wireshark >/dev/null; then
        ok "grupo 'wireshark' ya existe"
    else
        run "sudo groupadd --system wireshark" && ok "grupo 'wireshark' creado"
    fi
    if id -nG "${USER:-$(id -un)}" | tr ' ' '\n' | grep -qx wireshark; then
        ok "usuario ya en el grupo wireshark"
    else
        run "sudo usermod -aG wireshark ${USER:-$(id -un)}"
        warn "grupo wireshark: surtirá efecto al volver a entrar en la sesión"
    fi
    # setcap concede cap_net_raw/cap_net_admin al binario.
    # ⚠️  En nmap NO desbloquea -sS: Arch compila nmap sin --with-libcap (lo
    #     dice su PKGBUILD) y su compuerta de privilegios es un geteuid() a
    #     secas, que el setcap no puede satisfacer. Escaneos SYN: sudo nmap -sS.
    #     Sí aprovecha a bettercap, que sí usa la cap.
    # ⚠️  además se PIERDE cada vez que pacman actualiza esos paquetes;
    #     reaplicar con: sudo setcap cap_net_raw,cap_net_admin+eip /usr/bin/nmap
    for _bin in /usr/bin/nmap /usr/bin/bettercap; do
        [[ -e "$_bin" ]] || continue
        run "sudo setcap cap_net_raw,cap_net_admin+eip $_bin" \
            && ok "$(basename "$_bin"): capabilities aplicadas"
    done
    # setcap en nmap puede romper los scripts NSE (Lua). Verificación real:
    if [[ -z "$DRYRUN" && -x /usr/bin/nmap ]]; then
        if nmap --script vuln -p 80,443 --max-retries 1 -T4 127.0.0.1 >/dev/null 2>&1; then
            ok "nmap --script vuln funciona CON setcap (sin conflicto NSE)"
        else
            warn "NSE roto por setcap -> revirtiendo capabilities de nmap"
            run "sudo setcap -r /usr/bin/nmap"
            warn "usa 'sudo nmap -sS' mientras tanto"
        fi
    fi

    # 9e) herramientas Python que no se pueden empaquetar
    #     recon-ng: sin PKGBUILD viable (exigía python-flasgger, inexistente)
    #     patator/LinkFinder/SecretFinder/theHarvester: ver la cabecera de
    #     pentest-pytools.sh — cada una falla por un motivo distinto de pipx.
    for _s in pentest-reconng.sh pentest-pytools.sh; do
        if [[ -f "$REPO_DIR/scripts/$_s" ]]; then
            log "  $_s"
            if [[ -n "$DRYRUN" ]]; then
                printf '  [dry-run] %s\n' "bash scripts/$_s"
            else
                bash "$REPO_DIR/scripts/$_s" || warn "$_s con fallos; revisa su log"
            fi
        else
            warn "FALTA scripts/$_s -> se omiten esas herramientas"
        fi
    done

    ok "toolchain: verifica el inventario con cyber-tools-installed.sh"
fi

log "Listo. Próximos pasos manuales:"
cat <<'EOF'
  · Reinicia sesión (grupo input + gestos activos)
  · Abre una consola: verás el logo de Arch (fastfetch)
  · Atajos: Super+1..9 workspaces · Super+A launcher · Super+Shift+T temas
EOF
