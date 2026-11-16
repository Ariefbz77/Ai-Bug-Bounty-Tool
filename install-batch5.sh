#!/bin/bash
# install-batch5.sh — Batch 5: OOB interaction, dir busting, LLM red-team,
# screenshot recon, hidden-param discovery.
#
# Pinned to the set verified on 2026-11-16 (batch 5 install report):
#   interactsh-client 1.4.1 : OOB (out-of-band) interaction client — generate
#     payloads for SSRF / blind XSS / blind SQLi and watch for callbacks.
#     Zip from github.com/projectdiscovery/interactsh, SHA256-verified
#     against the release checksums file. -> $BIN/interactsh-client
#   interactsh-server 1.4.1 : self-hosted OOB server (same release, same
#     verification). Needs a domain + DNS to be useful; the client defaults
#     to ProjectDiscovery's public instance (oast.pro). -> $BIN/interactsh-server
#   feroxbuster 2.14.0      : fast Rust content-discovery / dir busting.
#     Tarball x86_64-linux-feroxbuster.tar.gz, extracted with
#     --no-same-owner (plain tar fails on ownership in some sandboxes).
#     -> $BIN/feroxbuster
#   garak 0.17.1            : LLM red-teaming scanner (jailbreaks, prompt
#     injection, data leakage, ...). Own venv $INSTALL_DIR/venv-garak,
#     pip install garak==0.17.1, thin wrapper $BIN/garak. NO models are
#     downloaded — garak talks to an API generator (OpenAI/Groq/...) or a
#     local model you point it at. Heavy install (~1 GB venv); GARAK_SKIP=1
#     to skip it.
#   gowitness 3.2.2         : screenshot recon — mass screenshots of URLs
#     (scan file -f targets.txt), plus a report mode. Single 50 MB binary.
#     -> $BIN/gowitness. Needs a Chrome/Chromium binary at SCAN time:
#     gowitness downloads one itself by default; pass --chrome-path to use
#     an existing one (e.g. a Playwright chromium-headless-shell).
#   x8 4.3.0                : hidden-parameter discovery for URLs/APIs.
#     Release asset x86_64-linux-x8.gz, gunzipped. -> $BIN/x8
#
# NOT installed: aquatone (v1.7.0, 2019, unmaintained — gowitness 3.2.2 is
# the maintained replacement and does the same job). The other 8 tools named
# for batch 5 (naabu, tlsx, uncover, chaos, hakrawler, waybackurls, anew,
# arjun) were ALREADY installed by batch 2 — they are not reinstalled here.
#
# Usage:
#   ./install-batch5.sh                     # install into ~/bug-bounty-tools
#   INSTALL_DIR=/opt/bb-tools ./install-batch5.sh
#   DRY_RUN=1 ./install-batch5.sh           # print the plan, install nothing
#   GARAK_SKIP=1 ./install-batch5.sh        # skip garak (heavy pip install)
#
# Prereq: run ./install.sh (batch 1) first — batch 5 reuses its $BIN layout
# (it creates it if missing). Or run ./install-all.sh.
#
# Notes:
# - Linux x86_64 only.
# - Hunt only in-scope targets, on programs that allow it. interactsh payloads
#   phone home to an OOB server — use the public instance only for in-scope
#   testing, or self-host interactsh-server on your own domain.

set -u
INSTALL_DIR="${INSTALL_DIR:-$HOME/bug-bounty-tools}"
BIN="$INSTALL_DIR/bin"
GARAK_VENV="$INSTALL_DIR/venv-garak"
DRY_RUN="${DRY_RUN:-0}"
mkdir -p "$INSTALL_DIR/tmp" "$BIN"
export GOTMPDIR="$INSTALL_DIR/tmp" TMPDIR="$INSTALL_DIR/tmp"
trap 'rm -rf "$INSTALL_DIR/tmp/dl5"' EXIT

say()  { echo "[+] $*"; }
warn() { echo "[!] $*" >&2; }
run()  { if [ "$DRY_RUN" -eq 1 ]; then echo "[dry-run] $*"; else eval "$*"; fi; }

need() {
  command -v "$1" >/dev/null 2>&1 || { warn "missing required command: $1"; exit 1; }
}

need curl
command -v python3 >/dev/null 2>&1 || warn "python3 not found — garak will be skipped"
command -v unzip >/dev/null 2>&1 || warn "unzip not found — interactsh zips need it"

ARCH="$(uname -m)"
[ "$ARCH" = "x86_64" ] || { warn "unsupported arch: $ARCH (this script targets linux/amd64)"; exit 1; }

say "Install dir: $INSTALL_DIR"

dl() { # dl <url> <dest> — fail loudly, keep going is the caller's job
  if [ "$DRY_RUN" -eq 1 ]; then echo "[dry-run] curl -fsSL $1 -> $2"; return 0; fi
  mkdir -p "$INSTALL_DIR/tmp/dl5"
  curl -fsSL "$1" -o "$2" || { warn "download failed: $1"; return 1; }
}

# --- 1. interactsh client + server 1.4.1 (SHA256-verified) -------------------
if [ -x "$BIN/interactsh-client" ] && [ -x "$BIN/interactsh-server" ] && [ "$DRY_RUN" -eq 0 ]; then
  say "interactsh-client + interactsh-server already present in $BIN — skip"
else
  say "downloading interactsh 1.4.1 (client + server) ..."
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[dry-run] curl -fsSL https://github.com/projectdiscovery/interactsh/releases/download/v1.4.1/interactsh-client_1.4.1_linux_amd64.zip"
    echo "[dry-run] curl -fsSL https://github.com/projectdiscovery/interactsh/releases/download/v1.4.1/interactsh-server_1.4.1_linux_amd64.zip"
    echo "[dry-run] sha256sum -c against interactsh_1.4.1_checksums.txt, unzip -> $BIN/interactsh-client + $BIN/interactsh-server"
  else
    dl "https://github.com/projectdiscovery/interactsh/releases/download/v1.4.1/interactsh-client_1.4.1_linux_amd64.zip" "$INSTALL_DIR/tmp/dl5/interactsh-client_1.4.1_linux_amd64.zip" && \
    dl "https://github.com/projectdiscovery/interactsh/releases/download/v1.4.1/interactsh-server_1.4.1_linux_amd64.zip" "$INSTALL_DIR/tmp/dl5/interactsh-server_1.4.1_linux_amd64.zip" && \
    dl "https://github.com/projectdiscovery/interactsh/releases/download/v1.4.1/interactsh_1.4.1_checksums.txt" "$INSTALL_DIR/tmp/dl5/interactsh_1.4.1_checksums.txt"
    if [ -f "$INSTALL_DIR/tmp/dl5/interactsh-client_1.4.1_linux_amd64.zip" ] && [ -f "$INSTALL_DIR/tmp/dl5/interactsh-server_1.4.1_linux_amd64.zip" ]; then
      if ( cd "$INSTALL_DIR/tmp/dl5" && sha256sum -c <(grep -E "linux_amd64" interactsh_1.4.1_checksums.txt) >/dev/null 2>&1 ); then
        say "interactsh checksums OK"
      else
        warn "interactsh checksum verification FAILED — refusing to install"
        rm -f "$INSTALL_DIR/tmp/dl5/interactsh-"*
      fi
      if [ -f "$INSTALL_DIR/tmp/dl5/interactsh-client_1.4.1_linux_amd64.zip" ]; then
        unzip -o -q "$INSTALL_DIR/tmp/dl5/interactsh-client_1.4.1_linux_amd64.zip" interactsh-client -d "$INSTALL_DIR/tmp/dl5" && mv "$INSTALL_DIR/tmp/dl5/interactsh-client" "$BIN/interactsh-client" && chmod +x "$BIN/interactsh-client" && say "interactsh-client 1.4.1 installed"
        unzip -o -q "$INSTALL_DIR/tmp/dl5/interactsh-server_1.4.1_linux_amd64.zip" interactsh-server -d "$INSTALL_DIR/tmp/dl5" && mv "$INSTALL_DIR/tmp/dl5/interactsh-server" "$BIN/interactsh-server" && chmod +x "$BIN/interactsh-server" && say "interactsh-server 1.4.1 installed"
      fi
    fi
  fi
fi

# --- 2. feroxbuster 2.14.0 ------------------------------------------------------
if [ -x "$BIN/feroxbuster" ] && [ "$DRY_RUN" -eq 0 ]; then
  say "feroxbuster already present in $BIN — skip (delete it to force reinstall)"
else
  say "downloading feroxbuster 2.14.0 ..."
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[dry-run] curl -fsSL https://github.com/epi052/feroxbuster/releases/download/v2.14.0/x86_64-linux-feroxbuster.tar.gz -> tar --no-same-owner -xzf -> $BIN/feroxbuster"
  else
    if dl "https://github.com/epi052/feroxbuster/releases/download/v2.14.0/x86_64-linux-feroxbuster.tar.gz" "$INSTALL_DIR/tmp/dl5/feroxbuster.tar.gz"; then
      tar --no-same-owner -xzf "$INSTALL_DIR/tmp/dl5/feroxbuster.tar.gz" -C "$INSTALL_DIR/tmp/dl5" feroxbuster && mv "$INSTALL_DIR/tmp/dl5/feroxbuster" "$BIN/feroxbuster" && chmod +x "$BIN/feroxbuster" && say "feroxbuster 2.14.0 installed"
    fi
  fi
fi

# --- 3. garak 0.17.1 (own venv + wrapper; no models downloaded) ---------------
if [ "${GARAK_SKIP:-0}" -eq 1 ]; then
  say "GARAK_SKIP=1 — skipping garak"
elif [ -x "$GARAK_VENV/bin/garak" ] && [ -x "$BIN/garak" ] && [ "$DRY_RUN" -eq 0 ]; then
  say "garak already present (venv + wrapper) — skip (delete $GARAK_VENV to force reinstall)"
else
  say "installing garak 0.17.1 into its own venv (heavy: ~1 GB, no models) ..."
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[dry-run] python3 -m venv $GARAK_VENV && $GARAK_VENV/bin/pip install garak==0.17.1"
    echo "[dry-run] write wrapper $BIN/garak -> exec $GARAK_VENV/bin/garak"
  elif command -v python3 >/dev/null 2>&1; then
    [ -x "$GARAK_VENV/bin/python" ] || python3 -m venv "$GARAK_VENV" || warn "garak venv creation failed"
    if [ -x "$GARAK_VENV/bin/pip" ]; then
      "$GARAK_VENV/bin/pip" install --quiet --upgrade pip || warn "pip upgrade failed (continuing)"
      "$GARAK_VENV/bin/pip" install "garak==0.17.1" || warn "garak pip install failed"
    fi
    if [ -x "$GARAK_VENV/bin/garak" ]; then
      printf '#!/bin/sh\n# wrapper: garak lives in its own venv (see install-batch5.sh)\nexec "%s/bin/garak" "$@"\n' "$GARAK_VENV" > "$BIN/garak" && chmod +x "$BIN/garak" && say "garak 0.17.1 installed (wrapper $BIN/garak)"
    fi
  else
    warn "python3 missing — skipping garak"
  fi
fi

# --- 4. gowitness 3.2.2 (single binary; needs Chrome at scan time) -------------
if [ -x "$BIN/gowitness" ] && [ "$DRY_RUN" -eq 0 ]; then
  say "gowitness already present in $BIN — skip (delete it to force reinstall)"
else
  say "downloading gowitness 3.2.2 ..."
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[dry-run] curl -fsSL https://github.com/sensepost/gowitness/releases/download/3.2.2/gowitness-3.2.2-linux-amd64 -> $BIN/gowitness"
  else
    if dl "https://github.com/sensepost/gowitness/releases/download/3.2.2/gowitness-3.2.2-linux-amd64" "$BIN/gowitness"; then
      chmod +x "$BIN/gowitness" && say "gowitness 3.2.2 installed"
    fi
  fi
fi

# --- 5. x8 4.3.0 -----------------------------------------------------------------
if [ -x "$BIN/x8" ] && [ "$DRY_RUN" -eq 0 ]; then
  say "x8 already present in $BIN — skip (delete it to force reinstall)"
else
  say "downloading x8 4.3.0 ..."
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[dry-run] curl -fsSL https://github.com/Sh1Yo/x8/releases/download/v4.3.0/x86_64-linux-x8.gz -> gunzip -> $BIN/x8"
  else
    if dl "https://github.com/Sh1Yo/x8/releases/download/v4.3.0/x86_64-linux-x8.gz" "$INSTALL_DIR/tmp/dl5/x8.gz"; then
      gunzip -kf "$INSTALL_DIR/tmp/dl5/x8.gz" && mv "$INSTALL_DIR/tmp/dl5/x8" "$BIN/x8" && chmod +x "$BIN/x8" && say "x8 4.3.0 installed"
    fi
  fi
fi

# --- verify --------------------------------------------------------------------
if [ "$DRY_RUN" -eq 0 ]; then
  echo ""
  say "verifying ..."
  for t in interactsh-client interactsh-server feroxbuster gowitness x8 garak; do
    if [ -x "$BIN/$t" ]; then
      case "$t" in
        feroxbuster) "$BIN/$t" --version 2>&1 | head -1 ;;
        x8)          "$BIN/$t" --help 2>&1 | head -1 ;;
        garak)       "$BIN/$t" --help 2>&1 | head -1 ;;
        *)           "$BIN/$t" -h 2>&1 | head -1 ;;
      esac
    else
      warn "$t NOT found in $BIN"
    fi
  done
fi

# --- done ---------------------------------------------------------------------
echo ""
say "Batch 5 install complete."
echo "  interactsh-client/server : $BIN/interactsh-client + $BIN/interactsh-server (1.4.1)"
echo "  feroxbuster              : $BIN/feroxbuster (2.14.0)"
echo "  garak                    : $BIN/garak (0.17.1, venv $GARAK_VENV; no models downloaded)"
echo "  gowitness                : $BIN/gowitness (3.2.2; needs Chrome at scan time)"
echo "  x8                       : $BIN/x8 (4.3.0)"
echo ""
echo "Quick uses (in-scope targets only):"
echo "  interactsh-client -v            # get a callback URL, watch for hits"
echo "  feroxbuster -u https://target/ -w wordlist.txt"
echo "  garak --model_type openai --model_name gpt-4o -p promptinject  # needs an API key"
echo "  printf 'https://target/\n' > targets.txt && gowitness scan file -f targets.txt"
echo "  x8 -u 'https://target/?x=1' -w wordlist.txt"
echo ""
echo "All batches done — ./install-all.sh runs 1-5 in order."
