#!/bin/bash
# install-all.sh — run all batches in order: 1 -> 2 -> 3 -> 4.
#
#   ./install-all.sh                 # full install into ~/bug-bounty-tools
#   INSTALL_DIR=/opt/bb-tools ./install-all.sh
#   DRY_RUN=1 ./install-all.sh       # print every batch's plan, install nothing
#
# Env knobs pass through to the batch scripts: SKILLS_SKIP, SECLISTS_SKIP,
# OLLAMA_INSTALL, BURP_SKIP, HEXSTRIKE_SKIP, SKILLS_DIR, BURP_DIR.
# Each batch script is idempotent — re-running skips what is already present.
# Stops at the first failing batch and reports which one failed.

set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FAILED=""

for b in install.sh install-batch2.sh install-batch3.sh install-batch4.sh; do
  echo "=== $b ==="
  if [ ! -x "$SCRIPT_DIR/$b" ] && [ ! -f "$SCRIPT_DIR/$b" ]; then
    echo "[!] missing: $SCRIPT_DIR/$b — aborting"
    FAILED="$FAILED $b(missing)"
    break
  fi
  if ! bash "$SCRIPT_DIR/$b"; then
    echo "[!] $b FAILED — stopping here (fix it, then re-run ./install-all.sh; finished batches are skipped on re-run)"
    FAILED="$FAILED $b"
    break
  fi
  echo ""
done

if [ -n "$FAILED" ]; then
  echo "[!] install-all.sh stopped early. Failed:${FAILED}"
  exit 1
fi

echo "[+] install-all.sh complete — all 4 batches installed."
echo "  Add to your shell PATH (e.g. in ~/.bashrc):"
echo "    export PATH=\"\$HOME/bug-bounty-tools/bin:\$HOME/.local/bin:\$PATH\""
echo "  Then: bughunter setup   # pick a free provider (Ollama / Groq / DeepSeek)"
echo "        ./recon.sh example.com"
