#!/bin/bash
# recon.sh — Full Recon Pipeline (Amass + Subfinder + Live Check) -> Agentic-Bug-Hunter
# Dibuat 2026-11-16 atas order user. Setup Muse Free: ringan, hasil disimpan ke file,
# Muse baca file-nya (hemat token), hunting fokus ke host menarik saja.
#
# CARA PAKAI:
#   ./recon.sh target.com              # mode default: amass PASSIVE (cepat) + subfinder
#   ./recon.sh target.com --deep       # amass full enum (aktif+pasif, lebih lama)
#   ./recon.sh target.com --nuclei     # + nuclei scan ringan di live hosts
#   ./recon.sh target.com --deep --nuclei
#
# HASIL (di recon_<target>/):
#   amass.txt / subfinder.txt  - subdomain mentah per tool
#   all_subs.txt               - gabungan unik
#   resolved.txt               - yang resolve DNS (dnsx)
#   live.txt                   - host hidup + status/title/tech (httpx)
#   interesting.txt            - host menarik (admin/api/staging/dev/login/dll)
#   nuclei.txt                 - hasil nuclei (hanya dengan --nuclei)
#   SUMMARY.md                 - ringkasan buat dikasih ke Muse
#
# LANJUTAN (manual, JANGAN otomatis):
#   1. Review live.txt + interesting.txt, kasih ke Muse buat analisis + prioritasi.
#   2. Baru hunting fokus:  bughunter hunt <host-menarik>   (bukan langsung semua target)
#   3. Validasi manual setiap finding, baru:  bughunter validate "deskripsi finding"
#   4. Generate report:  bughunter report
# JANGAN jalankan script ini ke target tanpa scope/izin program bounty yang berlaku.

set -u
TARGET="${1:-}"
[ -z "$TARGET" ] && { echo "Pakai: $0 <target.com> [--deep] [--nuclei]"; exit 1; }
shift || true

DEEP=0; NUCLEI=0
for arg in "$@"; do
  case "$arg" in
    --deep) DEEP=1 ;;
    --nuclei) NUCLEI=1 ;;
    *) echo "Argumen tidak dikenal: $arg"; exit 1 ;;
  esac
done

# Tool dir — override with BUG_BOUNTY_BIN; else a ./bin next to this script;
# else the install.sh default (~/bug-bounty-tools/bin); else rely on PATH.
# (Adapted from the original, which pointed at the author's own VM path.)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="${BUG_BOUNTY_BIN:-}"
if [ -z "$BIN" ] && [ -d "$SCRIPT_DIR/bin" ]; then BIN="$SCRIPT_DIR/bin"; fi
if [ -z "$BIN" ] && [ -d "$HOME/bug-bounty-tools/bin" ]; then BIN="$HOME/bug-bounty-tools/bin"; fi
[ -n "$BIN" ] && export PATH="$BIN:$PATH"
for t in amass subfinder dnsx httpx; do
  command -v "$t" >/dev/null 2>&1 || { echo "Tool tidak ketemu: $t (cek $BIN)"; exit 1; }
done

OUTDIR="recon_${TARGET}"
mkdir -p "$OUTDIR"
cd "$OUTDIR" || exit 1

echo "[+] Recon $TARGET -> $OUTDIR (deep=$DEEP nuclei=$NUCLEI)"

# 1. Amass — default PASSIVE (cepat, hemat). --deep = full enum.
AMASS_CFG="$HOME/.config/amass/config.yaml"
AMASS_ARGS=(-d "$TARGET" -o amass.txt)
[ -f "$AMASS_CFG" ] && AMASS_ARGS+=(-config "$AMASS_CFG")
if [ "$DEEP" -eq 1 ]; then
  echo "[+] Amass full enum..."
  amass enum "${AMASS_ARGS[@]}"
else
  echo "[+] Amass passive..."
  amass enum -passive "${AMASS_ARGS[@]}"
fi

# 2. Subfinder (cepat & complementary)
echo "[+] Subfinder..."
subfinder -d "$TARGET" -silent -all -o subfinder.txt || touch subfinder.txt

# 3. Gabung + unik (anew kalau ada, kalau tidak sort -u)
echo "[+] Gabung subdomain..."
if command -v anew >/dev/null 2>&1; then
  cat amass.txt subfinder.txt 2>/dev/null | anew all_subs.txt
else
  cat amass.txt subfinder.txt 2>/dev/null | sort -u > all_subs.txt
fi
echo "[+] Total unique subdomain: $(wc -l < all_subs.txt)"

# 4. Resolve + live hosts
echo "[+] dnsx resolve..."
cat all_subs.txt | dnsx -silent -o resolved.txt || touch resolved.txt
echo "[+] httpx live check..."
cat resolved.txt | httpx -silent -sc -title -td -tech-detect -o live.txt || touch live.txt
echo "[+] Total live: $(wc -l < live.txt)"

# 5. Host menarik (admin/api/staging/dev/login/sso/internal/dll)
echo "[+] Filter host menarik..."
grep -iE 'admin|api|staging|stage|dev|test|qa|internal|intranet|login|sso|auth|vpn|portal|dashboard|panel|beta|preprod|uat|legacy|old|backup|git|jenkins|jira|confluence' live.txt > interesting.txt || true
echo "[+] Host menarik: $(wc -l < interesting.txt)"

# 6. Opsional: nuclei ringan di live hosts (severity medium+ biar tidak banjir)
if [ "$NUCLEI" -eq 1 ]; then
  command -v nuclei >/dev/null 2>&1 || { echo "nuclei tidak ketemu, skip"; }
  if command -v nuclei >/dev/null 2>&1; then
    echo "[+] Nuclei (live hosts, severity medium,high,critical)..."
    cut -d' ' -f1 live.txt | sed 's/^\[//;s/\]$//' > live_urls.txt
    nuclei -l live_urls.txt -severity medium,high,critical -silent -o nuclei.txt || touch nuclei.txt
    echo "[+] Temuan nuclei: $(wc -l < nuclei.txt)"
  fi
fi

# 7. Ringkasan buat Muse (hemat token: kasih file ini + live.txt + interesting.txt)
{
  echo "# Recon $TARGET — $(date '+%Y-%m-%d %H:%M WIB')"
  echo ""
  echo "- Subdomain unik: $(wc -l < all_subs.txt)"
  echo "- Resolve DNS: $(wc -l < resolved.txt)"
  echo "- Live hosts: $(wc -l < live.txt)"
  echo "- Host menarik: $(wc -l < interesting.txt)"
  [ "$NUCLEI" -eq 1 ] && echo "- Temuan nuclei: $(wc -l < nuclei.txt)"
  echo ""
  echo "## Host menarik"
  cat interesting.txt
} > SUMMARY.md

echo "[+] Selesai. File: $OUTDIR/{all_subs,resolved,live,interesting}.txt + SUMMARY.md"
echo "[*] Langkah berikut: review live.txt + interesting.txt -> kasih ke Muse -> bughunter hunt <host-menarik>"
