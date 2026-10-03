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
| `.gitignore` | Excluye caches, `.bak`, mozilla, `colors.conf` (wallbash), **secretos** (`rclone.conf`, contraseña restic), etc. |

### Sync del vault Obsidian + respaldo de emergencia

| Ruta | Qué es |
|---|---|
| `Configs/.local/share/bin/obsidian-bisync.sh` | Sync bidireccional con Drive (cortacircuito anti-borrado) |
| `Configs/.local/share/bin/obsidian-restic.sh` | **Respaldo de emergencia** versionado y cifrado |
| `Configs/.local/share/bin/obsidian-offsite.sh` | Copia cifrada del respaldo hacia Drive (1×/día) |
| `Configs/.config/systemd/user/*.timer` | Los 3 timers (5 min / 15 min / diario) |

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
- **Login (SDDM Candy)**: `FontSize="7"` en `/usr/share/sddm/themes/Candy/theme.conf`
  (por defecto `height/80` ≈ 9.6pt a 1366×768 y se cortaba el nombre de usuario).
  El tema Candy **no es un paquete** → el cambio sobrevive a actualizaciones.
- **Firewall**: `firewalld` activo y habilitado (`systemctl is-active firewalld`).
- **Paquetes añadidos**: `btop` (monitor, atajo `Ctrl+Shift+Esc`),
  `hyprsunset` (luz azul), `noto-fonts` (la usaba el login sin estar instalada).
  `inter-font` NO se instaló: swaylock quedó con CaskaydiaCove (fuente existente).

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
| `Super+Alt+F` | Filtro luz azul ON/OFF (hyprsunset 3500K) |
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

## 📓 Vault Obsidian: sync + respaldo de emergencia

El vault vive en `~/Drive/Obsidian Vault` y se sincroniza **bidireccionalmente**
con Google Drive (modo espejo), de donde lo lee también el PC de Windows.

| Timer | Frecuencia | Qué hace |
|---|---|---|
| `rclone-obsidian.timer` | **cada 5 min** | `obsidian-bisync.sh` → sync local ↔ Drive |
| `obsidian-restic.timer` | **cada 15 min** | `obsidian-restic.sh` → snapshot versionado + cifrado |
| `obsidian-offsite.timer` | **1×/día** | `obsidian-offsite.sh` → copia cifrada del respaldo a Drive |

```bash
systemctl --user list-timers            # ver los 3
systemctl --user status rclone-obsidian # ver uno concreto
journalctl --user -u obsidian-restic    # logs vía systemd
tail -f ~/.local/state/rclone/obsidian-bisync.log
```

### Dónde vive cada cosa

| Qué | Ruta | ¿Al git? |
|---|---|---|
| Vault (sync) | `~/Drive/Obsidian Vault` | ❌ (ni a GitHub ni al repo) |
| Estado de bisync | `~/.cache/rclone/bisync/obsidian/` | ❌ |
| Logs | `~/.local/state/rclone/*.log` | ❌ |
| **Respaldo restic** | `~/Backups/obsidian-restic/` | ❌ (`.gitignore`: `Backups/`) |
| **Contraseña restic** | `~/.config/restic/password` (`600`) | ❌ **NUNCA** |
| Copia offsite | Drive → `Respaldos/obsidian-restic/` | ❌ |
| Remote `ovault:` | `~/.config/rclone/rclone.conf` | ❌ (`.gitignore`) |

> ⚠️ **La contraseña de restic es la única llave del respaldo.** Si la pierdes,
> el historial es irrecuperable. Guárdala donde lleves tus credenciales
> (p. ej. en `Util/Credenciales.md`, que ya está en Drive).

### Capas de protección

```
Borras el vault (o muchos archivos) en este PC
  ├─► bisync --max-delete 10  → ABORTA y deja Drive intacto  🛡️
  ├─► restic (≤15 min atrás)  → restauras el historial       ✅
  ├─► Papelera de Drive       → 30 días                      ✅
  └─► Copia offsite en Drive  → sobrevive a muerte del disco ✅

Borras en Windows  →  mismas capas (todo converge en Drive)
```

**Probado en producción**: con 15 archivos borrados de golpe, bisync devolvió
`too many deletes` y **Drive quedó 100 % intacto**; el `restic restore` +
`diff -r` devolvió los 93 archivos idénticos.

### ♻️ Recuperar el vault de Obsidian (paso a paso)

**Caso A — borraste archivos hace poco (≤15 min):**

```bash
# 1) mira qué hay
RESTIC_REPOSITORY=$HOME/Backups/obsidian-restic \
RESTIC_PASSWORD_FILE=$HOME/.config/restic/password restic snapshots

# 2) restaura el último snapshot a /tmp (nunca directo encima)
RESTIC_REPOSITORY=$HOME/Backups/obsidian-restic \
RESTIC_PASSWORD_FILE=$HOME/.config/restic/password \
  restic restore latest --target /tmp/restaurar-obsidian

# 3) revisa y copia de vuelta
ls /tmp/restaurar-obsidian/home/diego/Drive/
cp -r "/tmp/restaurar-obsidian/home/diego/Drive/Obsidian Vault/." \
      "$HOME/Drive/Obsidian Vault/"
```

**Caso B — borraste una nota concreta:** en Drive, *Papelera* → restaurar
(google.com/drive/quota/trash, 30 días).

**Caso C — el vault entero desapareció:** mismo paso 2 de arriba, y si el
disco murió, primero restaura desde la copia offsite:

```bash
rclone copy archdive:Respaldos/obsidian-restic ~/Backups/obsidian-restic
# y después restic restore (igual que arriba)
```

**Caso D — bisync se queja de `too many deletes`:** era intencional →
`obsidian-bisync.sh --force`. Si no lo era, **déjalo así**: es la protección
haciendo su trabajo.

### Atajos de los scripts

```bash
obsidian-bisync.sh --resync     # reconstruir el estado si se corrompe
obsidian-bisync.sh --force      # permitir borrados masivos
obsidian-restic.sh --list       # listar snapshots
obsidian-restic.sh --restore    # ver cómo restaurar
```

---

## 🪟 PC de Windows: notas de la sincronización

| Tema | Detalle |
|---|---|
| **Modo** | **Espejo (bidireccional)** — verificado con el test `zz-prueba-desde-arch.md` |
| **Carpeta** | Google Drive for Desktop → *Mi PC › Drive › Obsidian Vault* |
| **Borrados** | Viajan a Drive y de ahí a este PC — por eso existe el respaldo local |
| **Conflicto** | Si editas en ambos lados a la vez, rclone renombra con sufijo `conflict` (nada se pierde) |
| **No sincronizados** | `.directory`, `.trash/**`, `.obsidian/workspace*.json`, `*.tmp` (basura/descartables) |
| **Si Windows no recibe cambios** | Revisa que Drive for Desktop esté en modo *Espejo* y no *Solo respaldo* |

**Si en Windows borras la carpeta entera:** no entres en pánico — este PC la
tiene y el respaldo de 15 min también. Vuelve a sincronizar y todo vuelve.

---

*Hardware: AMD A10-8730B + Radeon R5 · 1366×768 · Logitech G305 · Arch Linux + Hyprland 0.56*
