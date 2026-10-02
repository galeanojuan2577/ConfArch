# ConfArch — Ambiente Arch Linux + Hyprland (HyDE)

Respaldo completo de mi configuración. Con esto reconstruyo mi escritorio
completo en un Arch nuevo en unos minutos.

```bash
git clone -b main git@github.com:galeanojuan2577/ConfArch.git ~/Hyprdots
cd ~/Hyprdots
./bootstrap.sh            # o ./bootstrap.sh --dry-run para ver qué haría
```

> **Nota de ramas:** en GitHub la rama `main` es la que se respalda (viene de la
> rama local `confarch`). El `-b main` evita clonar por error la rama de pruebas
> `seed-test`. Ver sección *Arquitectura de respaldo*.

---

## Estructura

| Ruta | Qué es |
|---|---|
| `Configs/` | Dotfiles (HyDE) — se copian a `$HOME` |
| `Configs/.config/hypr/` | Hyprland: `hyprland.conf`, `keybindings`, `windowrules`, `animations`, `userprefs.conf` |
| `Configs/.local/share/bin/` | Scripts HyDE (`swwwallpaper.sh`, `rofilaunch.sh`, …) |
| `Configs/.zshrc`, `.p10k.zsh` | Shell (zsh + powerlevel10k + **fastfetch con el logo de Arch**) |
| `pkglist/pacman.txt` | Paquetes oficiales (`pacman -Qe`) |
| `pkglist/aur.txt` | Paquetes AUR (`yay -Qm`) |
| `bootstrap.sh` | Instala todo + restaura dots (ver `--dry-run`) |
| `.gitignore` | Excluye caches, `.bak`, mozilla, `colors.conf` (wallbash), etc. |

## Recuperación en un Arch nuevo

1. **Base**: `pacman -S git base-devel`, clonar este repo, `./bootstrap.sh`
2. **Aur**: el script instala `yay-bin` automáticamente desde AUR
3. **Re-login** una vez (para el grupo `input` → gestos de touchpad)
4. **Symlinks**: el script crea `/usr/local/bin/swww{,-daemon} → /usr/bin/awww`
   (Arch renombró el paquete `swww` a `awww`)
5. HyDE restore funciona igual: `Hyde restore Config` (los fixes están en ambos lados)

## Decisiones no estándar (importante)

- **Teclado `latam`** → en `Configs/.config/hypr/userprefs.conf` (flag *Preserve* de HyDE,
  sobrevive a los restores). Nunca borrar `hyprland.conf` (si falta, HyDE regenera la versión lua).
- **`swww` → `awww`** → symlinks en `/usr/local/bin` + `--format argb` en `swwwallpaper.sh`
  (Hyprland rechaza `xrgb`: *"Format invalid"*).
- **Consola**: `fastfetch --logo arch` en `.zshrc` (sin Pokémon).
- **swaylock**: fuente `CaskaydiaCove Nerd Font Mono` (la Inter no estaba instalada).
- **Grupo `input`** obligatorio para `libinput-gestures`.

## Atajos esenciales

| Atajo | Acción |
|---|---|
| `Super+1..9` / `Super+0` | Workspaces 1–10 |
| `Super+Ctrl+←/→` | Workspace siguiente/anterior |
| `Super+A` | Launcher (rofi) |
| `Super+Shift+T` | Selector de temas |
| `Super+Shift+W` | Selector de wallpapers |
| `Super+Alt+A` | Selector de animaciones (19 estilos) |
| `Super+L` | Bloquear pantalla |
| `Super+Alt+F` | Filtro luz azul (hyprsunset) — *si está activo* |
| `Super+Alt+←/→` | Wallpaper anterior/siguiente |

## Backup actualizado

```bash
./backup.sh "mensaje opcional"   # add + commit + espejo confarch + push
```

### Arquitectura de respaldo (importante)

`~/Hyprdots` **no** es el repo que se sube directamente: es un *shallow clone*
del upstream de HyDE (~974 MB de historia recortada). Si se hace `push` de
`main`, Git intenta enviar los padres que faltan en el corte y GitHub lo
rechaza (`did not receive expected object`).

Por eso el script usa **dos ramas locales**:

| Rama local | Rol | ¿Se sube? |
|---|---|---|
| `main` | Historial completo + vínculo con HyDE (`origin`) | ❌ (es shallow) |
| `confarch` | Commit **raíz** (sin padres) con el mismo contenido | ✅ → `main` en GitHub |

`backup.sh` automático: commit en `main` → espeja el árbol a `confarch`
(siempre *fast-forward*) → `git push backup confarch:main`.

**Para recuperar** en un Arch nuevo: `git clone -b main …` + `./bootstrap.sh`.

**Restaurar los fixes sobre una copia de HyDE:** si algún día clonas el upstream
original de HyDE, copia encima `Configs/`, `pkglist/`, `bootstrap.sh`,
`backup.sh`, `.gitignore` y `README.md` desde este respaldo.

---

*Hardware: AMD A10-8730B + Radeon R5 · 1366×768 · Logitech G305 · Arch Linux + Hyprland 0.56*
