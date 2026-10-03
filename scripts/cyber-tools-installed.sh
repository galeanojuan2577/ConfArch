#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# cyber-tools-installed.sh — inventario del toolchain de pentesting
#
# Es el script que Eco_Ciber cita en sus reglas (`opencode/rules/cyber/`)
# pero que no existe upstream: lo creé aquí para verificar la instalación
# de verdad, en vez de asumir que `yay` terminó bien.
#
# Comprueba que el COMANDO existe y está en el PATH — no que el paquete
# esté en pacman. Una herramienta instalada rota no sirve de nada.
#
# Uso:
#   ./cyber-tools-installed.sh              tabla completa
#   ./cyber-tools-installed.sh --missing    solo las que faltan
#   ./cyber-tools-installed.sh --json       para consumo de Eco_Ciber
#   ./cyber-tools-installed.sh --group=web  filtrado por grupo
#   ./cyber-tools-installed.sh --run        además intenta invocarlas
#   ./cyber-tools-installed.sh --help
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
commix|web|commix
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

MODE="table"; GROUP=""; DO_RUN=0
for a in "$@"; do
  case "$a" in
    --missing) MODE="missing" ;;
    --json)    MODE="json" ;;
    --run)     DO_RUN=1 ;;
    --group=*) GROUP="${a#--group=}"; MODE="group" ;;
    --help|-h)
      awk 'NR>1 && /^#/ { sub(/^# ?/,""); print; next } NR>1 { exit }' "${BASH_SOURCE[0]}"
      exit 0 ;;
    *) echo "flag desconocido: $a  (usa --help)" >&2; exit 1 ;;
  esac
done

rows=(); total=0; present=0; missing_list=()
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
  if command -v "$name" >/dev/null 2>&1; then
    path="$(command -v "$name")"; present=$((present+1)); st="ok"
  else
    path="-"; st="MISSING"; missing_list+=("$cmd")
  fi
  runres="-"
  if [ "$DO_RUN" -eq 1 ] && [ "$st" = "ok" ]; then
    if timeout 8 "$name" --help >/dev/null 2>&1 || timeout 8 "$name" -h >/dev/null 2>&1; then
      runres="ejecuta"
    else
      runres="no-invoca"
    fi
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
    printf '{"command":"%s","group":"%s","package":"%s","status":"%s","path":"%s"}' \
           "$c" "$g" "$p" "$s" "$pa"
  done
  printf '],"summary":{"total":%d,"present":%d,"missing":%d,"percent":%d}}\n' \
         "$total" "$present" "$((total-present))" "$pct"
  exit 0
fi

if [ "$MODE" = "missing" ]; then
  if [ ${#missing_list[@]} -eq 0 ]; then
    echo "✅ Ninguna herramienta falta ($present/$total)"
  else
    echo "Faltan ${#missing_list[@]} de $total:"
    printf '  %s\n' "${missing_list[@]}"
  fi
  exit 0
fi

echo "═══════════════════════════════════════════════"
echo "  Toolchain de pentesting — $present/$total ($pct%)"
[ -n "$GROUP" ] && echo "  grupo: $GROUP"
echo "═══════════════════════════════════════════════"
printf '  %-20s %-11s %-26s %s\n' "COMANDO" "GRUPO" "PAQUETE" "ESTADO"
printf '  %-20s %-11s %-26s %s\n' "--------------------" "-----------" "--------------------------" "------"
for r in "${rows[@]}"; do
  IFS='|' read -r c g p s pa ru <<< "$r"
  [ "$s" = "ok" ] && mark="✅" || mark="❌"
  extra=""; [ "$ru" != "-" ] && extra=" ($ru)"
  printf '  %-20s %-11s %-26s %s%s\n' "$c" "$g" "$p" "$mark" "$extra"
done
echo
echo "  ✅ $present   ❌ $((total-present))   total $total   ($pct%)"
[ ${#missing_list[@]} -gt 0 ] && echo "  faltan: ${missing_list[*]}"
echo "═══════════════════════════════════════════════"
echo "  Nota: frida/objection requieren frida-v8 (compila el motor V8"
echo "  desde fuente, ~1301 objetivos ninja). Se instalan aparte."
echo "  Nota: wapiti exige Python <3.14 y el sistema trae 3.14.7."
echo "  Nota: autopsy exige java-openjfx=17 y hay 28.11."
echo "═══════════════════════════════════════════════"
