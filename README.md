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

**Caso E — creé una carpeta y no aparece en el otro equipo:**

1. ¿Está **vacía**? → ya está resuelto con `--create-empty-src-dirs`
   (si el script es anterior a ese cambio, hay que actualizarlo).
2. ¿Tiene **caracteres `\ / : * ? " < > |`** en el nombre? → Windows no los
   admite; renómbrala. El script avisa por notificación si detecta alguno.
3. Comprueba en los logs: `grep 'nothing to transfer'` significa que bisync
   no vio nada que copiar.

```bash
rclone lsf ovault:            # ver qué hay realmente en Drive
grep -i 'aviso-caracteres' ~/.local/state/rclone/obsidian-bisync.log
```

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
| **Carpetas vacías** | **Sí se sincronizan** (flag `--create-empty-src-dirs`) — creas una carpeta en un lado y aparece en el otro, aunque esté vacía |
| **Nombres válidos** | Evita `\ / : * ? " < > \|` en nombres: **Windows no los permite**. Drive los guardaría pero tu PC no podría crearlos. El script te avisa con una notificación si detecta alguno |
| **Si Windows no recibe cambios** | Revisa que Drive for Desktop esté en modo *Espejo* y no *Solo respaldo* |

**Si en Windows borras la carpeta entera:** no entres en pánico — este PC la
tiene y el respaldo de 15 min también. Vuelve a sincronizar y todo vuelve.

---

## 🔧 Toolchain de pentesting (bug bounty)

Conjunto de herramientas Kali-style + extras para bug bounty, tomados de lo que
el ecosistema **Eco_Ciber** pide en sus reglas (`opencode/rules/cyber/`,
`opencode/commands/pentest/`) más los tópicos de Kali. Aquí solo están las
**herramientas**; la integración con Eco_Ciber es un paso aparte.

**Estado del inventario** (`./scripts/cyber-tools-installed.sh`):

| | |
|---|---|
| **105 / 106** | herramientas **invocadas de verdad** (no solo `command -v`): **99 %** |
| 462 | paquetes en `pkglist/pentest.txt` |
| 4 | instaladas con `go install` / `pipx` |
| 5 | instaladas por clon + venv (recon-ng, patator, LinkFinder, SecretFinder, theHarvester) |
| 3 | `frida` + `frida-tools` + `objection`, aparte (compilan el motor V8) |

Desglose de las 106 entradas: **87 `ejecuta`** (contestaron a
`--help`/`-h`/`--version` con exit 0), **13 `sin-ayuda`** (corren, pero
esas banderas no las admiten — se comprobó aparte con la propia de cada
una: `hydra -h`, `searchsploit <término>`, `go version`, `fls`, `masscan`…
todas con salida correcta; `hydra` de hecho devuelve 255 con *todas* las
banderas, porque hace `exit(-1)`, y por eso el detector distingue un
`exit()` arbitrario de un muerto por señal), **1 `interactivo`**
(`hash-identifier`, que imprime su banner y espera `raw_input()`; su
`EOFError` no es una avería), **1 `timeout`** (`caido`, GUI), **3 paquetes
de datos** sin binario propio (seclists, rockyou, wordlists) y **1 ausente**
(`wapiti`). **0 rotas.**

Ese número es el de la versión **endurecida** del inventario. La anterior
solo hacía `command -v`, y con ella daban ✅ cinco binarios que al
ejecutarse no arrancaban:

| Herramienta | Aparecía | Al invocarla | Arreglo |
|---|---|---|---|
| `httpx` | ✅ | salía el CLI de *python-httpx*, no el de ProjectDiscovery | enlace `~/.local/bin/httpx` → `httpx-toolkit` |
| `nikto` | ✅ | `ERROR: Required module not found: XML::Writer` | `perl-xml-writer` |
| `droopescan` | ✅ | `ModuleNotFoundError: 'imp'` y luego `'distutils'` | `zombie-imp` + `setuptools` en su venv |
| `commix` | ✅ | `No module named 'src.thirdparty.six.moves'` | pasa a pipx `@v4.1` (AUR sólo tenía el 3.4) |
| `wfuzz` | ✅ | `ModuleNotFoundError: 'pkg_resources'` | shim en el site del usuario |

Los cuatro primeros los cazó la primera pasada del inventario endurecido;
`wfuzz` cayó en cuanto se ampliaron las firmas de fallo. La causa de fondo
de `wfuzz` es que **`setuptools` 84 dejó de incluir `pkg_resources`** (0
ficheros) y Arch no publicó ningún paquete que lo sustituya, así que
`pentest-repair.sh` siembra ese directorio en el site del usuario desde el
último setuptools que lo traía (80.9). Todo lo demás que necesita
(`packaging`, `jaraco.text`, `jaraco.functools`, `more_itertools`) ya está
en el sistema, y el `setuptools` 84 del sistema queda intacto.

**La única que falta es `wapiti`, y es deliberado**: exige Python
`>=3.12,<3.14` y el sistema trae 3.14.7, sin alternativa en ningún repo —
pero además **Eco_Ciber no lo pide en ninguna parte** (ni en su flujo de 10
fases ni entre sus herramientas críticas), y su función la cubren `nuclei`,
`sqlmap`, `dalfox`, `xsstrike`, `nikto` y compañía. Se descarta.
`autopsy` ni siquiera entra en el inventario por un motivo análogo (pide
`java-openjfx=17` y hay 28.11). El detalle está en las secciones siguientes.

Sobre `frida`: hay que saber que **tarda**. `frida-v8` compila el motor V8 desde
fuente (1301 objetos ninja) y después `frida` construye su SDK entero. En esta
máquina fueron unas 4 h 30 con `MAKEFLAGS=-j4`. Es un `yay -S` normal y se puede
reanudar: `yay` llama a `makepkg --noextract`, así que lo ya compilado se
conserva.

### Instalar

```bash
cd ~/Hyprdots
./bootstrap.sh --pentest            # solo las herramientas
./bootstrap.sh --dry-run --pentest  # ver qué haría, sin tocar nada
```

El paso 9 de `bootstrap.sh` hace cinco cosas, en este orden:

1. instala los **462 paquetes** de `pkglist/pentest.txt`
2. ejecuta `scripts/pentest-repair.sh`, que arregla lo que viene roto de
   fábrica: los PKGBUILDs de AUR que fallan en `check()` (los reintenta con
   `makepkg --nocheck`), el enlace que hace que `httpx` apunte al binario
   correcto, y el shim de `pkg_resources` que necesita `wfuzz`
3. ejecuta `scripts/pentest-gopipx.sh` (Go/pipx que no existen en pacman ni AUR)
4. aplica los permisos de red (grupo `wireshark` + `setcap`)
5. ejecuta `scripts/pentest-reconng.sh` y `scripts/pentest-pytools.sh`
   (las herramientas que sólo se pueden instalar clonando el repo)

Si se corta a mitad, **se puede reanudar**: todo usa `--needed` y es
idempotente. `./bootstrap.sh --dry-run --pentest` imprime los 462 paquetes y
los 4 scripts que correría, sin tocar nada.

### Los scripts

| Script | Qué hace |
|---|---|
| `scripts/pentest-maestro.sh` | Orquestador: encadena todo en orden y da el informe final |
| `scripts/pentest-repair.sh` | Repara lo que viene rotos de fábrica: 4 sustitutos de AUR, `python2 --nocheck`, el enlace de `httpx` y el shim de `pkg_resources` |
| `scripts/pentest-gopipx.sh` | 7 módulos `go install` + 3 `pipx` (fierce, droopescan, commix) |
| `scripts/pentest-reconng.sh` | `recon-ng` desde git con su propio venv |
| `scripts/pentest-pytools.sh` | `patator`, `LinkFinder`, `SecretFinder` y `theHarvester` (clon + venv) |
| `scripts/cyber-tools-installed.sh` | Inventario: **invoca** cada herramienta y marca ROTO si no arranca, no solo si el comando existe |
| `scripts/pentest-frida.sh` | `frida` + `objection`, aparte (ver abajo) |

```bash
./scripts/cyber-tools-installed.sh              # tabla completa (invoca cada una, ~60 s)
./scripts/cyber-tools-installed.sh --missing    # solo lo que falta o está roto
./scripts/cyber-tools-installed.sh --json       # para Eco_Ciber
./scripts/cyber-tools-installed.sh --group=web  # por área
./scripts/cyber-tools-installed.sh --fast       # solo `command -v` (instantáneo)
```

La comprobación en tiempo de ejecución **es la por defecto** porque es la
única que descubre averías reales: `command -v` solo dice que hay un
fichero con ese nombre. Cada binario se lanza con `--help`, y si no contesta
con `-h` y `--version`, bajo un `timeout` de 8 s y con la entrada cerrada
(para que ninguna herramienta se trague la lista que sigue). Nunca se le pasa
la orden de arrancar sin argumentos: `responder` y `netdiscover` empiezan a
trabajar en cuanto se ejecutan.

### ⚠️ Permiso de root y sudo sin TTY

Los scripts de este repositorio **no piden la contraseña por pantalla**: los
procesos que lanza el asistente no tienen terminal y `sudo` se niega a leer la
clave de stdin en ese caso. La solución es `SUDO_ASKPASS`:

```bash
# fuera del repo, en ~/.config/ — permisos 700, NUNCA se sube a GitHub
printf '#!/bin/sh\nexec printf %s\\n "<tu-clave>"\n' > ~/.config/askpass-sudo
chmod 700 ~/.config/askpass-sudo
export SUDO_ASKPASS=~/.config/askpass-sudo
sudo -A <comando>
```

### ⚠️ `nmap -sS` necesita `sudo` (el setcap no lo arregla)

Hallazgo importante, comprobado con `strace`:

```
nmap -sS   →  geteuid() = 1000  →  sale con 1 SIN llegar a socket()
nmap -sT   →  2 llamadas a socket()  →  funciona sin root
```

nmap no intenta abrir el socket: hace **una sola** `geteuid()` y aborta. El
`setcap` no puede ayudar porque nmap nunca pregunta por capacidades. Y no es
un error nuestro: el **PKGBUILD de Arch** configura nmap con
`--with-libpcap --with-libpcre --with-zlib --with-libssh2 --with-liblua` —
**sin `--with-libcap`**, y `libcap` ni siquiera figura en `makedepends`.
Consecuencia práctica:

```bash
sudo nmap -sS ...        # escaneos SYN: así, siempre
nmap -sT ...             # TCP connect: sin privilegios, va perfecto
nmap --script vuln ...   # NSE: sin privilegios
```

Sí que sirve el `setcap` en **bettercap**, que sí usa la cap. Y **se pierde**
cada vez que `pacman -Syu` reemplaza esos binarios; para reaplicar:

```bash
sudo setcap cap_net_raw,cap_net_admin+eip /usr/bin/nmap /usr/bin/bettercap
sudo usermod -aG wireshark "$USER"   # el grupo solo hay que darlo una vez
```

Los scripts comprueban las tres cosas de verdad: que `nmap -sT` clasifica
puertos sin root, que `sudo nmap -sS` responde, y que el `setcap` sigue
puesto (se verifica con `getcap`, no se asume).

### PKGBUILDs rotos que hubo que sustituir

Auditoría previa: se clonó cada PKGBUILD, se leyó el código y se descartó todo
lo que usara `curl|sh`, `eval`, `base64`, `rm -rf /` o checksums vacíos.
De 58 revisados, **4 se rechazaron por no ser lo que prometían** — todas
fueron **homónimos**: nombre igual, proyecto completamente distinto:

| Herramienta | Qué era realmente | Sustituto |
|---|---|---|
| `katana` (AUR) | Una herramienta de **VFX de Foundery**, no ProjectDiscovery | `go install …/katana/cmd/katana` |
| `gf` (AUR) | Un **framework de juegos en C++**, no el `gf` de tomnomnom | `go install github.com/tomnomnom/gf` |
| `chisel` (AUR) | El lenguaje **HDL de Scala para FPGAS** (solo un `.jar` en `/usr/share/scala`) | `go install github.com/jpillora/chisel` |
| `apktool-toolbox` | Repacketea cosas sin necesidad | `android-apktool-bin` |

> 💡 **Cómo se detectaron:** no mirando el nombre del paquete, sino su campo
> `URL`. `pacman -Qi <pkg> | grep '^URL'` es la comprobación más rápida para
> saber si un paquete de AUR es realmente la herramienta que buscas. Se revisó
> así la URL de los 97 paquetes AUR instalados.

Y 5 más que **compilan mal** hoy; los 4 primeros, sustituidos por variantes
`-bin`/`-git` con el mismo origen oficial y checksums:

| Paquete | Causa raíz |
|---|---|
| `httpx` | Declara `conflicts=('python-httpx')` sin motivo real (no se solapan los archivos); bloqueaba `wapiti` y `python-dnsrecon` |
| `naabu` | El PKGBUILD hace `cd naabu-2.6.1/v2/cmd/naabu` y esa ruta ya no existe en el tarball |
| `dirsearch` | `No module named 'pkg_resources'` — Python 3.14 lo eliminó |
| `android-apktool` | Exporta `JAVA_HOME=…java-26-openjdk`, pero Arch instala `java-26-jdk` |
| `python2` | Su `check()` ejecuta la suite de Python 2.7: **361 tests OK, 2 KO** en kernels modernos (`test_regrtest.test_interrupted`, `test_subprocess.test_send_signal`). No se sustituye: se reintenta con `makepkg --nocheck` |

`python2` no es opcional: **lo necesita `hash-identifier`**. Por eso
`pentest-repair.sh` lo lleva *antes* que `hash-identifier` en su lista — si no,
en una instalación limpia `yay` rechazaría ambos y el paso 5 no podría
reintentar `hash-identifier` porque le faltaría su dependencia.

### 📦 Cuatro herramientas que no se pueden empaquetar

No son paquetes de pacman ni se resuelven con `pipx`; cada una falla por un
motivo distinto, y las cuatro van en `scripts/pentest-pytools.sh`
(clon + venv propio + lanzador en `~/.local/bin`):

| Herramienta | Por qué falla |
|---|---|
| `patator` | Su `pyproject` declara `cx_Oracle` como dependencia dura; `cx_Oracle` ya no se mantiene y su build necesita `pkg_resources`, que setuptools ≥81 no trae. Se instala **sin** `cx_Oracle`: en el código ese import es perezoso (hay un `notfound.append('cx_Oracle')`), así que sólo avisa el módulo Oracle |
| `LinkFinder` | Su `setup.py` declara `py_modules=['linkfinder']` pero **no** `entry_points`; pip no genera ningún binario y pipx no sabe qué exponer |
| `SecretFinder` | El repositorio no lleva `setup.py` ni `pyproject.toml`: sólo `SecretFinder.py` y `requirements.txt` |
| `theHarvester` | El AUR `theharvester-git` fija un commit que arrastra `python-aiomultiprocess`, roto desde que flit_core 4 rechaza la tabla `[tool.flit.metadata]`. El HEAD de upstream ya no lo necesita y su `pyproject` exige Python ≥3.14, que es exactamente el del sistema |

> ⚠️ **`theHarvester` en PyPI es un squatter** (versión `0.0.1`, no es la
> herramienta). El código real sólo está en `github.com/laramies/theHarvester`.

También va por este camino `recon-ng` (`scripts/pentest-reconng.sh`): no hay
PKGBUILD viable, porque el que circulaba exigía `python-flasgger`, un paquete
que no existe en ningún repo.

### 📦 Paquetes que NO se pueden instalar hoy

No son fallos de seguridad: son incompatibilidades de versiones upstream.

| Herramienta | Motivo | Alternativa |
|---|---|---|
| `autopsy` | Exige `java-openjfx=17`, en Arch solo hay 28.11 | ninguna hoy |
| `wapiti` | Exige Python **≥3.12, <3.14**; el sistema tiene 3.14.7, y no hay otro Python en los repos | **descartado a propósito**: Eco_Ciber no lo pide ni en su flujo ni entre sus herramientas críticas, y lo cubren `nuclei`, `sqlmap`, `dalfox`, `xsstrike`, `nikto` y compañía |
| `frida` / `objection` | Ambos dependen de `frida-v8`, que **compila el motor V8 desde fuente** (ninja, 1301 objetivos) — horas, y tira el lote entero | `scripts/pentest-frida.sh`, sola y sin timeout |
| `arachni`, `w3af`, `sslstrip` | Proyectos muertos | — |
| `crackmapexec` | Renombrado | `netexec` |

Y dos que **sí están**, pero no por la vía obvia:

| Herramienta | Por qué la vía normal falla | Vía usada |
|---|---|---|
| `commix` | La AUR sólo tiene el **3.4-1**, con un `six` vendorizado anterior a 1.16.0: sin `find_spec`, y Python 3.14 ya no acepta el viejo hook `find_module` → muere con `No module named 'src.thirdparty.six.moves'`. El `commix` de **PyPI es además un squatter** (v0.1, 3,7 KB, no es el proyecto) | `pipx` desde el repo oficial `@v4.1` (audito su `setup.py`: sólo metadata y `console_scripts`); el paquete de sistema se retiró |
| `wfuzz` | Le falta `pkg_resources`, que **`setuptools` 84 dejó de incluir** (0 ficheros) y Arch no sustituyó con ningún paquete | shim de ese directorio en el site del usuario, siembra `pentest-repair.sh` |

### Herramientas cuyo nombre de comando no coincide

Algunas existen vía `go install` o `pipx`; otras **el binario se llama
distinto** que la herramienta (fácil de perder de vista: el paquete está
instalado y la orden "no existe"):

| Se busca | Paquete de Arch | Binario real |
|---|---|---|
| `Responder` | `responder` | `responder` (no `responder.py`) |
| `netexec` | `netexec` | **`nxc`** |
| `chisel` | *ninguno* | `go install github.com/jpillora/chisel` |
| `searchsploit` | `exploitdb` | — |
| `hping3` | `hping` | — |
| `netcat` | `openbsd-netcat` | — |
| `tshark` / `dumpcap` | `wireshark-cli` | — |
| `dnsutils` | `bind` | — |
| `arpspoof` | `dsniff` | — |
| `theHarvester` | *ninguno* | `scripts/pentest-pytools.sh` (clon + venv) |
| `patator` / `linkfinder.py` / `SecretFinder.py` | *ninguno* | `scripts/pentest-pytools.sh` (clon + venv) |
| `dnsrecon` | `python-dnsrecon` | — |
| `ghidra` | `ghidra` | binario `ghidraRun` |
| `volatility3` | `volatility3` | binario `vol` |

El inventario ya lleva estos alias (`declare -A ALIAS`), así que comprueba el
binario que de verdad se ejecuta.

---

*Hardware: AMD A10-8730B + Radeon R5 · 1366×768 · Logitech G305 · Arch Linux + Hyprland 0.56*
