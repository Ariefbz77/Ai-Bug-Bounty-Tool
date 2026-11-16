#!/bin/bash
# install-batch4.sh — Batch 4: Caido CLI, Burp Suite Community, HexStrike AI MCP.
#
# Pinned to the set verified on 2026-11-16 (batch 4 install report):
#   Caido CLI 0.59.1        : tarball from caido.download (51.8 MB)
#     -> $BIN/caido. The Desktop AppImage is NOT installed (GUI-only);
#     the CLI is the usable form on a headless machine.
#   Burp Suite Community    : version-less download
#     https://portswigger.net/burp/releases/download?product=community&type=linux
#     (lowercase type=linux, NO version param — every other form 404s).
#     Serves current Stable; verified as 2026.3.3-47134 on 2026-11-16 — a
#     later run may get a newer Stable. Installed unattended to
#     ${BURP_DIR:-/opt/BurpSuiteCommunity} (override BURP_DIR if /opt needs
#     no sudo on your machine, or point it at a user-writable dir).
#   HexStrike AI MCP v6.0.0 : clone 0x4m4/hexstrike-ai (pinned d689933; the
#     same clone batch 2 installed — reused if present), own venv, pip install
#     from requirements.txt MINUS pwntools/angr (only referenced inside
#     generated-script template strings, never imported — installing angr
#     costs ~1 GB for zero benefit). SECURITY PATCH: the server hardcodes
#     app.run(host="0.0.0.0") — patched to host="127.0.0.1" (original saved
#     as hexstrike_server.py.orig). Verified running + responding on
#     127.0.0.1:8888 (19/127 tools resolve with $BIN on PATH), then STOPPED.
#     The server is unauthenticated local exec by design — it is NEVER left
#     running and NEVER exposed beyond loopback.
#
# Usage:
#   ./install-batch4.sh                     # install into ~/bug-bounty-tools
#   INSTALL_DIR=/opt/bb-tools ./install-batch4.sh
#   BURP_DIR=$HOME/burp ./install-batch4.sh # Burp somewhere user-writable
#   DRY_RUN=1 ./install-batch4.sh           # print the plan, install nothing
#   BURP_SKIP=1 ./install-batch4.sh         # skip Burp (368 MB download)
#   HEXSTRIKE_SKIP=1 ./install-batch4.sh    # skip the HexStrike MCP setup
#
# Prereq: run ./install.sh (batch 1) + ./install-batch2.sh + ./install-batch3.sh
# first — batch 4 reuses their $BIN tools (HexStrike resolves more of its 127
# tools when the batch 1-3 binaries are on PATH). Or run ./install-all.sh.
#
# Notes:
# - Linux x86_64 only. Burp needs ~368 MB download + a JRE it bundles itself.
# - RAM: Burp's launcher caps heap at 50% of system RAM — heavy on small VMs;
#   prefer --help/--version checks, launch the GUI only when actually needed.
# - Hunt only in-scope targets, on programs that allow it.

set -u
INSTALL_DIR="${INSTALL_DIR:-$HOME/bug-bounty-tools}"
BIN="$INSTALL_DIR/bin"
HEXDIR="$INSTALL_DIR/hexstrike-ai"
BURP_DIR="${BURP_DIR:-/opt/BurpSuiteCommunity}"
DRY_RUN="${DRY_RUN:-0}"
mkdir -p "$INSTALL_DIR/tmp" "$BIN"
export GOTMPDIR="$INSTALL_DIR/tmp" TMPDIR="$INSTALL_DIR/tmp"
trap 'rm -rf "$INSTALL_DIR/tmp/dl"' EXIT

say()  { echo "[+] $*"; }
warn() { echo "[!] $*" >&2; }
run()  { if [ "$DRY_RUN" -eq 1 ]; then echo "[dry-run] $*"; else eval "$*"; fi; }

need() {
  command -v "$1" >/dev/null 2>&1 || { warn "missing required command: $1"; exit 1; }
}

need curl; need git
command -v python3 >/dev/null 2>&1 || warn "python3 not found — HexStrike MCP setup will be skipped"

ARCH="$(uname -m)"
[ "$ARCH" = "x86_64" ] || { warn "unsupported arch: $ARCH (this script targets linux/amd64)"; exit 1; }

say "Install dir: $INSTALL_DIR"
say "Burp dir:    $BURP_DIR"

# --- 1. Caido CLI 0.59.1 -------------------------------------------------------
if [ -x "$BIN/caido" ] && [ "$DRY_RUN" -eq 0 ]; then
  say "caido already present in $BIN — skip (delete it to force reinstall)"
else
  say "downloading Caido CLI 0.59.1 ..."
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[dry-run] curl -fsSL https://caido.download/releases/v0.59.1/caido-cli-v0.59.1-linux-x86_64.tar.gz -> extract caido-cli -> $BIN/caido"
  else
    mkdir -p "$INSTALL_DIR/tmp/dl"
    # NOTE: use GET, not HEAD — this host answers HEAD with 404 for a valid asset.
    curl -fsSL "https://caido.download/releases/v0.59.1/caido-cli-v0.59.1-linux-x86_64.tar.gz" -o "$INSTALL_DIR/tmp/dl/caido.tar.gz" || warn "caido download failed"
    if [ -f "$INSTALL_DIR/tmp/dl/caido.tar.gz" ]; then
      tar -xzf "$INSTALL_DIR/tmp/dl/caido.tar.gz" -C "$INSTALL_DIR/tmp/dl" caido-cli && mv "$INSTALL_DIR/tmp/dl/caido-cli" "$BIN/caido" && chmod +x "$BIN/caido" && say "caido 0.59.1 installed"
    fi
  fi
fi

# --- 2. Burp Suite Community (current Stable; verified 2026.3.3-47134) --------
if [ "${BURP_SKIP:-0}" -eq 1 ]; then
  say "BURP_SKIP=1 — skipping Burp Suite"
elif [ -x "$BURP_DIR/BurpSuiteCommunity" ] && [ "$DRY_RUN" -eq 0 ]; then
  say "Burp Suite already installed at $BURP_DIR — skip"
else
  say "downloading Burp Suite Community (version-less URL, ~368 MB) ..."
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[dry-run] curl -fsSL \"https://portswigger.net/burp/releases/download?product=community&type=linux\" -> $INSTALL_DIR/tmp/dl/burpsuite_community_linux.sh"
    echo "[dry-run] ./burpsuite_community_linux.sh -q -dir $BURP_DIR   (sudo if $BURP_DIR is not writable)"
  else
    mkdir -p "$INSTALL_DIR/tmp/dl"
    # The version-less, lowercase form is the ONLY one that returns the
    # installer (type=Linux or any version= param 302s to /burp -> 404).
    curl -fsSL "https://portswigger.net/burp/releases/download?product=community&type=linux" -o "$INSTALL_DIR/tmp/dl/burpsuite_community_linux.sh" || warn "burp download failed"
    if [ -f "$INSTALL_DIR/tmp/dl/burpsuite_community_linux.sh" ]; then
      chmod +x "$INSTALL_DIR/tmp/dl/burpsuite_community_linux.sh"
      if [ -w "$(dirname "$BURP_DIR")" ]; then
        "$INSTALL_DIR/tmp/dl/burpsuite_community_linux.sh" -q -dir "$BURP_DIR" || warn "burp install failed"
      else
        say "need sudo to install into $BURP_DIR (or re-run with BURP_DIR=\$HOME/burp)"
        sudo "$INSTALL_DIR/tmp/dl/burpsuite_community_linux.sh" -q -dir "$BURP_DIR" || warn "burp install failed"
      fi
      [ -x "$BURP_DIR/BurpSuiteCommunity" ] && say "Burp Suite Community installed at $BURP_DIR"
    fi
  fi
fi

# --- 3. HexStrike AI MCP v6.0.0 (127.0.0.1 only, verified, then STOPPED) -------
if [ "${HEXSTRIKE_SKIP:-0}" -eq 1 ]; then
  say "HEXSTRIKE_SKIP=1 — skipping HexStrike MCP setup"
else
  # Clone (pinned) — batch 2 already cloned this; reuse if present.
  if [ -d "$HEXDIR/.git" ]; then
    say "hexstrike-ai already cloned — skip (git -C $HEXDIR checkout d689933 to pin)"
  else
    say "cloning hexstrike-ai ..."
    if [ "$DRY_RUN" -eq 1 ]; then
      echo "[dry-run] git clone https://github.com/0x4m4/hexstrike-ai.git $HEXDIR && git -C $HEXDIR checkout d689933ff579d839c676c82b231f8e98326c5f04"
    else
      git clone https://github.com/0x4m4/hexstrike-ai.git "$HEXDIR" || warn "hexstrike-ai clone failed"
      git -C "$HEXDIR" checkout d689933ff579d839c676c82b231f8e98326c5f04 || warn "hexstrike checkout failed (staying on default branch)"
    fi
  fi

  if command -v python3 >/dev/null 2>&1; then
    if [ "$DRY_RUN" -eq 1 ]; then
      echo "[dry-run] python3 -m venv $HEXDIR/venv && $HEXDIR/venv/bin/pip install -r $HEXDIR/requirements.txt (MINUS pwntools/angr)"
      echo "[dry-run] patch $HEXDIR/hexstrike_server.py: host 0.0.0.0 -> 127.0.0.1 (keep .orig)"
      echo "[dry-run] start server on 127.0.0.1:8888, GET /health, count resolving tools, STOP server"
    elif [ -d "$HEXDIR" ]; then
      if [ ! -x "$HEXDIR/venv/bin/python" ]; then
        say "creating hexstrike-ai venv ..."
        python3 -m venv "$HEXDIR/venv" || warn "hexstrike venv creation failed"
      fi
      if [ -x "$HEXDIR/venv/bin/pip" ]; then
        # requirements.txt MINUS pwntools/angr: only referenced inside
        # generated-script template strings, never imported; angr costs ~1 GB.
        grep -vE "^(pwntools|angr)" "$HEXDIR/requirements.txt" > "$INSTALL_DIR/tmp/dl/hexstrike-requirements.txt" 2>/dev/null || warn "requirements.txt not found"
        "$HEXDIR/venv/bin/pip" install -r "$INSTALL_DIR/tmp/dl/hexstrike-requirements.txt" || warn "hexstrike deps install failed"
      fi
      # SECURITY PATCH: the server hardcodes app.run(host="0.0.0.0") — it would
      # listen on ALL interfaces. Bind loopback only. Keep the original.
      if grep -q 'host="0.0.0.0"' "$HEXDIR/hexstrike_server.py" 2>/dev/null; then
        cp "$HEXDIR/hexstrike_server.py" "$HEXDIR/hexstrike_server.py.orig"
        sed -i 's/host="0.0.0.0"/host="127.0.0.1"/' "$HEXDIR/hexstrike_server.py"
        say "hexstrike_server.py patched to 127.0.0.1 (original saved as .orig)"
      elif grep -q 'host="127.0.0.1"' "$HEXDIR/hexstrike_server.py" 2>/dev/null; then
        say "hexstrike_server.py already patched to 127.0.0.1 — skip"
      else
        warn "hexstrike_server.py host line not found — check the patch manually"
      fi
      # Verify: start on loopback only, check /health, then STOP it.
      # The server is unauthenticated local exec by design — never left running.
      if [ -x "$HEXDIR/venv/bin/python" ] && command -v curl >/dev/null 2>&1; then
        say "verifying HexStrike server (starts, /health, then STOPPED) ..."
        PATH="$BIN:$PATH" "$HEXDIR/venv/bin/python" "$HEXDIR/hexstrike_server.py" --port 8888 >/dev/null 2>&1 &
        HEX_PID=$!
        sleep 8
        if curl -fsSL --max-time 10 "http://127.0.0.1:8888/health" 2>/dev/null | grep -q '"status":"healthy"'; then
          say "HexStrike /health OK (127.0.0.1:8888)"
        else
          warn "HexStrike /health check failed — see server output (not fatal for install)"
        fi
        kill "$HEX_PID" 2>/dev/null
        sleep 2
        kill -9 "$HEX_PID" 2>/dev/null || true
        say "HexStrike server STOPPED (port 8888 free)"
      fi
    fi
  else
    warn "python3 missing — skipping HexStrike MCP setup"
  fi
fi

# --- done ---------------------------------------------------------------------
echo ""
say "Batch 4 install complete."
echo "  Caido CLI : $BIN/caido (0.59.1; listens 127.0.0.1:8080 by default)"
echo "  Burp      : $BURP_DIR (Community; installer bundles its own JRE)"
echo "  HexStrike : $HEXDIR (MCP server v6.0.0, venv ready, patched to 127.0.0.1, STOPPED)"
echo ""
echo "To run the HexStrike MCP server (only when needed, loopback only):"
echo "  cd $HEXDIR"
echo "  PATH=\"$BIN:\$PATH\" ./venv/bin/python hexstrike_server.py --port 8888"
echo "  # then in another shell: ./venv/bin/python hexstrike_mcp.py --server http://127.0.0.1:8888"
echo "  # STOP it when done. Never expose port 8888."
echo ""
echo "All batches done — ./install-all.sh runs 1-4 in order."
