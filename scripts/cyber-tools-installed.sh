#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# cyber-tools-installed.sh — inventario del toolchain de pentesting
#
# Es el script que Eco_Ciber cita en sus reglas (`opencode/rules/cyber/`)
# pero que no existe upstream: lo creé aquí para verificar la instalación
# de verdad, en vez de asumir que `yay` terminó bien.
#
# Comprueba que el COMANDO existe, está en el PATH **y arranca de verdad**.
# Una herramienta instalada rota no sirve de nada, y `command -v` solo
# confirma que hay un fichero con ese nombre — nada más.
#
# Ese era el agujero: con la comprobación antigua daban ✅ cuatro binarios
# que al ejecutarse echaban Traceback (droopescan, commix), exigían un
# módulo Perl ausente (nikto) o arrancaban el CLI equivocado (httpx). Por eso
# la invocación real es ahora LA POR DEFECTO y lo que falla pasa a ROTO.
#
# Uso:
#   ./cyber-tools-installed.sh              tabla completa (invoca cada una)
#   ./cyber-tools-installed.sh --missing    solo las que faltan o están rotas
#   ./cyber-tools-installed.sh --json       para consumo de Eco_Ciber
#   ./cyber-tools-installed.sh --group=web  filtrado por grupo
#   ./cyber-tools-installed.sh --fast       solo `command -v` (al instante)
#   ./cyber-tools-installed.sh --run        idéntico al modo por defecto
#   ./cyber-tools-installed.sh --help
#
# Estados que devuelve la invocación:
#   ejecuta        respondió a --help/-h/--version con exit 0
#   interactivo    imprime su banner y se queda esperando entrada (p. ej.
#                  hash-identifier): está sano, simplemente no admite banderas
#   sin-ayuda      corre, pero ninguna bandera devuelve 0
#   timeout        no contestó en 8 s (herramientas lentas: msfconsole)
#   ROTO           dejó una firma de fallo -> NO cuenta como presente
#
# Nunca se llama a cada herramienta sin argumentos: algunas (responder,
# netdiscover) empiezan a trabajar nada más arrancar.
# ═══════════════════════════════════════════════════════════════
set -uo pipefail

export PATH="$HOME/.local/bin:$HOME/go/bin:$HOME/.local/share/bin:$PATH"

# Formato:  comando|grupo|paquete de Arch
#   · comando que empieza por '/' -> paquete de DATOS (wordlists): se
#     comprueba que exista el fichero, porque no tiene binario propio.
#   · paquete 'go:x' o 'pipx:x' -> se instala con go install / pipx
DATA=$(cat <<'EOF'
# ── reconocimiento y enumeración ──
subfinder|recon|subfinder
amass|recon|amass
httpx|recon|httpx-bin
dnsx|recon|dnsx
naabu|recon|naabu-bin
gau|recon|gau
waybackurls|recon|waybackurls
hakrawler|recon|hakrawler-git
unfurl|recon|unfurl
notify|recon|notify
interactsh-client|recon|interactsh-client
nuclei|recon|nuclei-bin
katana|recon|go:katana
gf|recon|go:gf
anew|recon|go:anew
qsreplace|recon|go:qsreplace
haktrails|recon|go:haktrails
kxss|recon|go:kxss
arjun|recon|arjun
fierce|recon|pipx:fierce
theHarvester|recon|theharvester-git
dnsrecon|recon|python-dnsrecon
enum4linux|recon|enum4linux
enum4linux-ng|recon|enum4linux-ng
onesixtyone|recon|onesixtyone-git
whatweb|recon|whatweb
netdiscover|recon|netdiscover
recon-ng|recon|git:recon-ng
LinkFinder|recon|pipx:linkfinder
SecretFinder|recon|pipx:secretfinder
# ── fuzzing ──
ffuf|fuzz|ffuf
feroxbuster|fuzz|feroxbuster
wfuzz|fuzz|wfuzz
dirsearch|fuzz|dirsearch-git
gobuster|fuzz|gobuster
# ── vulnerabilidades web ──
sqlmap|web|sqlmap
nikto|web|nikto
wapiti|web|wapiti
dalfox|web|dalfox
xsstrike|web|xsstrike
joomscan|web|joomscan
wpscan|web|wpscan
commix|web|pipx:commix
droopescan|web|pipx:droopescan
# ── proxy e interceptación ──
burpsuite|proxy|burpsuite
caido|proxy|caido-desktop
mitmdump|proxy|mitmproxy
# ── explotación ──
msfconsole|exploit|metasploit
searchsploit|exploit|exploitdb
# ── contraseñas y hash ──
hashcat|pass|hashcat
john|pass|john
hydra|pass|hydra
crunch|pass|crunch
cewl|pass|cewl-git
cupp|pass|cupp-git
hash-identifier|pass|hash-identifier
patator|pass|pipx:patator
medusa|pass|medusa
# ── red y sniffing ──
bettercap|net|bettercap
Responder|net|responder
masscan|net|masscan
rustscan|net|rustscan
arpspoof|net|dsniff
secretsdump|net|impacket
tcpdump|net|tcpdump
tshark|net|wireshark-cli
dumpcap|net|wireshark-cli
aircrack-ng|net|aircrack-ng
airodump-ng|net|aircrack-ng
netexec|net|netexec
smbclient|net|smbclient
chisel|net|go:chisel
ligolo-ng|net|ligolo-ng
proxychains4|net|proxychains-ng
socat|net|socat
# ── forense y esteganografía ──
binwalk|forense|binwalk
steghide|forense|steghide
stegseek|forense|stegseek
zsteg|forense|zsteg
exiftool|forense|perl-image-exiftool
foremost|forense|foremost
vol|forense|volatility3
fls|forense|sleuthkit
mmls|forense|sleuthkit
# ── ingeniería inversa ──
ghidra|reverse|ghidra
r2|reverse|radare2
gdb|reverse|gdb
apktool|reverse|android-apktool-bin
dex2jar|reverse|dex2jar
jadx|reverse|jadx
strace|reverse|strace
ltrace|reverse|ltrace
adb|reverse|android-tools
fastboot|reverse|android-tools
# ── móvil (requieren frida — ver nota final) ──
frida|mobil|frida
frida-ps|mobil|frida-tools
objection|mobil|objection
# ── wordlists: paquetes de DATOS, sin binario propio ──
/usr/share/wordlists/seclists|wordlists|seclists
/usr/share/dict/rockyou.txt|wordlists|rockyou
/usr/share/wordlists|wordlists|wordlists
# ── base común ──
docker|base|docker
git|base|git
go|base|go
python3|base|python
jq|base|jq
curl|base|curl
EOF
)

# El comando real no siempre es el de la lista
#   · responder: el paquete 'responder' instala /usr/bin/responder (NO responder.py)
#   · netexec:   el paquete 'netexec' instala /usr/bin/nxc (nombre corto upstream)
#   · chisel:    el de AUR era el HDL de Scala, no el túnel -> va por go install
declare -A ALIAS=(
  [theHarvester]=theHarvester
  [Responder]=responder
  [netexec]=nxc
  [LinkFinder]=linkfinder.py
  [SecretFinder]=SecretFinder.py
  [secretsdump]=secretsdump.py
  [apktool]=apktool
)

MODE="table"; GROUP=""; DO_RUN=1
for a in "$@"; do
  case "$a" in
    --missing) MODE="missing" ;;
    --json)    MODE="json" ;;
    --run)     DO_RUN=1 ;;
    --fast)    DO_RUN=0 ;;
    --group=*) GROUP="${a#--group=}"; MODE="group" ;;
    --help|-h)
      awk 'NR>1 && /^#/ { sub(/^# ?/,""); print; next } NR>1 { exit }' "${BASH_SOURCE[0]}"
      exit 0 ;;
    *) echo "flag desconocido: $a  (usa --help)" >&2; exit 1 ;;
  esac
done

# ── invocación real ──────────────────────────────────────────────
# Tres firmas, y EL ORDEN IMPORTA:
#   1. módulo ausente / binario incapaz de arrancar -> roto, sin discusión.
#      Un módulo que falta nunca es culpa del stdin.
#   2. timeout -> es lenta, no rota; no se insiste (cuesta 8 s por banda).
#   3. EOFError -> alguien esperaba entrada y no la hubo: está INTERACTIVO,
#      y su Traceback no significa que esté roto. Es el caso de
#      hash-identifier, que imprime su banner y luego hace raw_input().
#   4. cualquier otro Traceback -> roto.
FIRMA_MODULO='ModuleNotFoundError|No module named|ImportError:|Required module not found|could not run because|command not found|Exec format error|Segmentation fault'
FIRMA_INTER='EOFError|EOF when reading a line|stdin has unexpectedly closed'
FIRMA_TRACE='Traceback \(most recent call last\)'
PROBE_TIMEOUT=8

# invocar <binario> -> imprime el estado
invocar() {
  local name="$1" probe out rc
  for probe in --help -h --version; do
    out=$(timeout "$PROBE_TIMEOUT" "$name" "$probe" 2>&1 </dev/null); rc=$?
    if printf '%s' "$out" | grep -qiE "$FIRMA_MODULO"; then echo "ROTO"; return 0; fi
    if [ "$rc" -eq 124 ]; then echo "timeout"; return 0; fi
    # Murió por señal o ni siquiera se pudo ejecutar:
    #   126 no ejecutable / 127 intérprete del shebang ausente
    #   129..165 muerto por señal 128+n (SIGSEGV 139, SIGABRT 134…)
    # CUALQUIERA OTRA cosa por encima de 128 es un exit() del propio
    # programa y es perfectamente normal: hydra devuelve 255 (exit(-1))
    # con todas las banderas, y searchsploit/patator 2. Sin este matiz,
    # hydra aparecía como ROTO.
    if [ "$rc" -eq 126 ] || [ "$rc" -eq 127 ] || { [ "$rc" -ge 129 ] && [ "$rc" -le 165 ]; }; then
      echo "ROTO"; return 0
    fi
    if printf '%s' "$out" | grep -qiE "$FIRMA_INTER"; then echo "interactivo"; return 0; fi
    if printf '%s' "$out" | grep -qiE "$FIRMA_TRACE"; then echo "ROTO"; return 0; fi
    if [ "$rc" -eq 0 ]; then echo "ejecuta"; return 0; fi
  done
  echo "sin-ayuda"; return 0
}

rows=(); total=0; present=0; missing_list=(); broken_list=()
while IFS='|' read -r cmd grp pkg; do
  [[ -z "$cmd" || "$cmd" == \#* ]] && continue
  if [ -n "$GROUP" ] && [ "$grp" != "$GROUP" ]; then continue; fi
  total=$((total+1))

  if [[ "$cmd" == /* ]]; then
    # entrada de tipo ruta: paquete de datos
    if [ -e "$cmd" ]; then
      rows+=("${cmd##*/}|$grp|$pkg|ok|$cmd|-")
      present=$((present+1))
    else
      rows+=("${cmd##*/}|$grp|$pkg|MISSING|-|-")
      missing_list+=("$cmd")
    fi
    continue
  fi

  name="${ALIAS[$cmd]:-$cmd}"
  if ! command -v "$name" >/dev/null 2>&1; then
    rows+=("$cmd|$grp|$pkg|MISSING|-|-")
    missing_list+=("$cmd")
    continue
  fi
  path="$(command -v "$name")"; st="ok"

  runres="-"
  if [ "$DO_RUN" -eq 1 ]; then
    runres="$(invocar "$name")"
    if [ "$runres" = "ROTO" ]; then
      # está en el PATH pero no arranca: NO cuenta como presente
      st="ROTO"; broken_list+=("$cmd")
    else
      present=$((present+1))
    fi
  else
    present=$((present+1))
  fi
  rows+=("$cmd|$grp|$pkg|$st|$path|$runres")
done <<< "$DATA"

pct=0; [ "$total" -gt 0 ] && pct=$(( present*100/total ))

if [ "$MODE" = "json" ]; then
  printf '{"tools":['
  first=1
  for r in "${rows[@]}"; do
    IFS='|' read -r c g p s pa ru <<< "$r"
    [ $first -eq 1 ] && first=0 || printf ','
    printf '{"command":"%s","group":"%s","package":"%s","status":"%s","path":"%s","run":"%s"}' \
           "$c" "$g" "$p" "$s" "$pa" "$ru"
  done
  printf '],"summary":{"total":%d,"present":%d,"missing":%d,"broken":%d,"checked":%s,"percent":%d}}\n' \
         "$total" "$present" "${#missing_list[@]}" "${#broken_list[@]}" \
         "$([ "$DO_RUN" -eq 1 ] && echo true || echo false)" "$pct"
  exit 0
fi

if [ "$MODE" = "missing" ]; then
  if [ "$DO_RUN" -eq 0 ]; then
    echo "⚠️  modo --fast: solo se comprobó que el comando existe."
    echo "   Sin invocar nada no se puede descartar que estén rotos."
  fi
  if [ ${#missing_list[@]} -eq 0 ] && [ ${#broken_list[@]} -eq 0 ]; then
    echo "✅ Ninguna herramienta falta ni está rota ($present/$total)"
  else
    [ ${#missing_list[@]} -gt 0 ] && {
      echo "Faltan ${#missing_list[@]} de $total:"
      printf '  %s\n' "${missing_list[@]}"
    }
    [ ${#broken_list[@]} -gt 0 ] && {
      echo "Instaladas pero ROTAS ${#broken_list[@]} (en el PATH, no arrancan):"
      printf '  %s\n' "${broken_list[@]}"
    }
  fi
  exit 0
fi

echo "═══════════════════════════════════════════════"
if [ "$DO_RUN" -eq 1 ]; then
  echo "  Toolchain de pentesting — $present/$total ($pct%)  [invocado]"
else
  echo "  Toolchain de pentesting — $present/$total ($pct%)  [solo PATH, --fast]"
fi
[ -n "$GROUP" ] && echo "  grupo: $GROUP"
echo "═══════════════════════════════════════════════"
printf '  %-20s %-11s %-26s %s\n' "COMANDO" "GRUPO" "PAQUETE" "ESTADO"
printf '  %-20s %-11s %-26s %s\n' "--------------------" "-----------" "--------------------------" "------"
for r in "${rows[@]}"; do
  IFS='|' read -r c g p s pa ru <<< "$r"
  case "$s" in
    ok)      mark="✅" ;;
    ROTO)    mark="❌" ;;
    MISSING) mark="❌" ;;
    *)       mark="❓" ;;
  esac
  extra=""; [ "$ru" != "-" ] && extra=" ($ru)"
  printf '  %-20s %-11s %-26s %s%s\n' "$c" "$g" "$p" "$mark" "$extra"
done
echo
echo "  ✅ $present   ❌ $((total-present))   total $total   ($pct%)"
[ ${#missing_list[@]} -gt 0 ] && echo "  ausentes : ${missing_list[*]}"
[ ${#broken_list[@]} -gt 0 ] && echo "  ROTAS    : ${broken_list[*]}"
[ "$DO_RUN" -eq 1 ] && echo "  invocadas: sí — cada binario se ejecutó con un timeout de ${PROBE_TIMEOUT}s"
echo "═══════════════════════════════════════════════"
echo "  Nota: frida/objection requieren frida-v8 (compila el motor V8"
echo "  desde fuente, ~1301 objetivos ninja). Se instalan aparte."
echo "  Nota: wapiti DESCARTADO — exige Python <3.14 y el sistema trae"
echo "  3.14.7, y Eco_Ciber no lo pide ni en su flujo ni entre sus"
echo "  herramientas críticas (lo cubren nuclei, sqlmap, dalfox, nikto)."
echo "  Nota: autopsy exige java-openjfx=17 y hay 28.11."
echo "  Nota: pkg_resources desapareció de setuptools 84; el shim en"
echo "  ~/.local/lib/python3.14/site-packages/pkg_resources lo repone"
echo "  (lo siembra pentest-repair.sh). Sin él, wfuzz no arranca."
echo "═══════════════════════════════════════════════"
