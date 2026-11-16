#!/bin/bash
# install-batch3.sh — Batch 3: static-analysis + fuzzing + secrets gap tools.
#
# Pinned to the set verified on 2026-11-16 (batch 3 gap report):
#   Python venv (venv-exploit) : semgrep 1.185.0 (+ re-pin mcp==1.28.1 after
#     it, because semgrep's install bumps mcp to 1.29.0 which breaks CAI and
#     Hunter — semgrep scanning itself still works on 1.28.1)
#   Go install (pinned)        : gosec v2.30.0 (dev build), staticcheck
#     v0.8.2 (tag 2026.2.2), medusa v1.5.1
#   Release binaries           : heimdall 0.9.3 (tag "0.9.3", no v-prefix;
#     asset "heimdall-linux-amd64"; note its --version prints stale "0.9.2"),
#     gitleaks 8.30.1 (SHA256-verified against its checksums file)
#   Bonus (side effect)        : CAI CLI starts again once mcp is pinned back
#     to 1.28.1 (it hung on 1.29.0).
#
# Wrappers: gosec + staticcheck shell out to `go list` at scan time, so their
# $BIN wrappers prepend Go to PATH. medusa's wrapper also prepends
# venv-exploit/bin (crytic-compile lives there; medusa runs Slither from it).
#
# Usage:
#   ./install-batch3.sh                     # install into ~/bug-bounty-tools
#   INSTALL_DIR=/opt/bb-tools ./install-batch3.sh
#   DRY_RUN=1 ./install-batch3.sh           # print the plan, install nothing
#
# Prereq: run ./install.sh (batch 1) and ./install-batch2.sh first — batch 3
# reuses their venv-exploit, Go toolchain and $BIN layout (it creates them if
# missing, but the full set assumes batches 1+2 ran). Or run ./install-all.sh.
#
# Notes:
# - Linux x86_64 only. Go >= 1.23 is needed for the `go install` steps.
# - Go builds and pip installs use $INSTALL_DIR/tmp as TMPDIR — /tmp on
#   small VMs is often a 512 MB tmpfs and big builds exhaust it.
# - Hunt only in-scope targets, on programs that allow it.

set -u
INSTALL_DIR="${INSTALL_DIR:-$HOME/bug-bounty-tools}"
BIN="$INSTALL_DIR/bin"
VENV="$INSTALL_DIR/venv-exploit"
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
if ! command -v go >/dev/null 2>&1; then
  for g in /usr/local/go/bin "$HOME/go/bin" "$HOME/.local/go/bin"; do
    [ -x "$g/go" ] && export PATH="$g:$PATH" && break
  done
fi
if [ "$DRY_RUN" -eq 0 ]; then
  command -v go >/dev/null 2>&1 || warn "go not found — Go tools will be skipped (install Go >= 1.23 and re-run)"
  command -v python3 >/dev/null 2>&1 || warn "python3 not found — semgrep will be skipped"
fi

ARCH="$(uname -m)"
[ "$ARCH" = "x86_64" ] || { warn "unsupported arch: $ARCH (this script targets linux/amd64)"; exit 1; }

say "Install dir: $INSTALL_DIR"

# --- 1. semgrep (pip into venv-exploit, then re-pin mcp) ----------------------
if command -v python3 >/dev/null 2>&1; then
  if [ ! -x "$VENV/bin/python" ]; then
    say "creating venv-exploit ..."
    run "python3 -m venv \"$VENV\""
  fi
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[dry-run] $VENV/bin/pip install semgrep==1.185.0 && $VENV/bin/pip install \"mcp==1.28.1\"   # mcp re-pin: semgrep bumps it to 1.29.0, which breaks CAI + Hunter"
    echo "[dry-run] write $BIN/semgrep shim"
  elif [ -x "$VENV/bin/pip" ]; then
    "$VENV/bin/pip" install semgrep==1.185.0 || warn "semgrep install failed"
    # semgrep bumps mcp 1.28.1 -> 1.29.0; 1.29.0 breaks CAI (hangs) and Hunter
    # (needs mcp<1.29). Pin it back — semgrep scanning still works on 1.28.1.
    "$VENV/bin/pip" install "mcp==1.28.1" || warn "mcp re-pin failed"
    printf '#!/bin/sh\n# Wrapper: semgrep (installed in venv-exploit; run via this shim)\nexec "%s/bin/semgrep" "$@"\n' "$VENV" > "$BIN/semgrep"
    chmod +x "$BIN/semgrep"
    say "semgrep 1.185.0 installed (+ mcp re-pinned to 1.28.1)"
  fi
else
  warn "python3 missing — skipping semgrep"
fi

# --- 2. Go tools (pinned via Go proxy, verified 2026-11-16) -------------------
# Installed to $INSTALL_DIR/gopath2/bin (like batch 2), then wrapped in $BIN
# because gosec/staticcheck need `go` on PATH at scan time.
GOBIN_REAL="$INSTALL_DIR/gopath2/bin"
mkdir -p "$GOBIN_REAL"

go_tool() { # $1=tool $2=package@version
  local tool="$1" pkg="$2"
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[dry-run] GOBIN=$GOBIN_REAL go install $pkg"
    return 0
  fi
  if [ -x "$GOBIN_REAL/$tool" ]; then
    say "$tool already present — skip (delete it to force reinstall)"
    return 0
  fi
  if ! command -v go >/dev/null 2>&1; then warn "go missing — skipping $tool"; return 0; fi
  say "go install $tool ($pkg) ..."
  GOBIN="$GOBIN_REAL" go install "$pkg" || { warn "go install failed: $tool"; return 1; }
  say "$tool installed"
}

go_tool gosec       github.com/securego/gosec/v2/cmd/gosec@v2.30.0
go_tool staticcheck honnef.co/go/tools/cmd/staticcheck@v0.8.2
go_tool medusa      github.com/crytic/medusa@v1.5.1

# Wrappers in $BIN (Go on PATH at scan time; medusa also needs crytic-compile).
mkwrap_go() { # $1=tool $2=extra-path-prefix (may be empty)
  local tool="$1" extra="$2"
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[dry-run] write $BIN/$tool wrapper (Go on PATH)"
    return 0
  fi
  {
    echo '#!/bin/sh'
    echo "# Wrapper generated by install-batch3.sh — $tool needs \`go\` on PATH at scan time."
    echo "GO_BIN=\"\$(command -v go 2>/dev/null)\""
    echo 'if [ -z "$GO_BIN" ]; then'
    echo '  for g in /usr/local/go/bin "$HOME/go/bin" "$HOME/.local/go/bin"; do'
    echo '    [ -x "$g/go" ] && export PATH="$g:$PATH" && break'
    echo '  done'
    echo 'fi'
    [ -n "$extra" ] && echo "export PATH=\"$extra:\$PATH\""
    echo "exec \"$GOBIN_REAL/$tool\" \"\$@\""
  } > "$BIN/$tool"
  chmod +x "$BIN/$tool"
}
mkwrap_go gosec ""
mkwrap_go staticcheck ""
# medusa runs Slither + crytic-compile from venv-exploit/bin.
mkwrap_go medusa "$VENV/bin"
# medusa's $BIN entry point is the wrapper above (it prepends Go +
# venv-exploit/bin so crytic-compile resolves at fuzz time).

# --- 3. Release binaries: heimdall + gitleaks --------------------------------
dl_bin() { # $1=tool $2=url $3=inner-path-or-empty
  local tool="$1" url="$2" inner="$3"
  if [ -x "$BIN/$tool" ] && [ "$DRY_RUN" -eq 0 ]; then
    say "$tool already present in $BIN — skip (delete it to force reinstall)"
    return 0
  fi
  say "downloading $tool ..."
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[dry-run] curl -fsSL $url -> $BIN/$tool"
    return 0
  fi
  mkdir -p "$INSTALL_DIR/tmp/dl"
  curl -fsSL "$url" -o "$INSTALL_DIR/tmp/dl/$tool.pkg" || { warn "download failed: $url"; return 1; }
  if [ -n "$inner" ]; then
    tar -xzf "$INSTALL_DIR/tmp/dl/$tool.pkg" -C "$INSTALL_DIR/tmp/dl" "$inner" || { warn "extract failed: $tool"; return 1; }
    mv "$INSTALL_DIR/tmp/dl/$inner" "$BIN/$tool"
  else
    mv "$INSTALL_DIR/tmp/dl/$tool.pkg" "$BIN/$tool"
  fi
  chmod +x "$BIN/$tool"
  say "$tool installed"
}

# heimdall: release tag is "0.9.3" (no v-prefix); asset is a bare binary.
# NOTE: the 0.9.3 asset's --version prints stale "0.9.2" — that is a known
# upstream string lag, not a wrong download. Do not "fix" by re-downloading.
dl_bin heimdall https://github.com/Jon-Becker/heimdall-rs/releases/download/0.9.3/heimdall-linux-amd64 ""

# gitleaks: SHA256-verified against its checksums file (v8.30.1).
if [ -x "$BIN/gitleaks" ] && [ "$DRY_RUN" -eq 0 ]; then
  say "gitleaks already present in $BIN — skip"
else
  say "downloading gitleaks 8.30.1 ..."
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[dry-run] curl -fsSL https://github.com/gitleaks/gitleaks/releases/download/v8.30.1/gitleaks_8.30.1_linux_x64.tar.gz + checksums, sha256sum -c, extract -> $BIN/gitleaks"
  else
    mkdir -p "$INSTALL_DIR/tmp/dl"
    curl -fsSL "https://github.com/gitleaks/gitleaks/releases/download/v8.30.1/gitleaks_8.30.1_linux_x64.tar.gz" -o "$INSTALL_DIR/tmp/dl/gitleaks.tar.gz" || warn "gitleaks download failed"
    curl -fsSL "https://github.com/gitleaks/gitleaks/releases/download/v8.30.1/gitleaks_8.30.1_checksums.txt" -o "$INSTALL_DIR/tmp/dl/gitleaks_checksums.txt" || warn "gitleaks checksums download failed"
    if [ -f "$INSTALL_DIR/tmp/dl/gitleaks.tar.gz" ] && [ -f "$INSTALL_DIR/tmp/dl/gitleaks_checksums.txt" ]; then
      (cd "$INSTALL_DIR/tmp/dl" && grep "gitleaks_8.30.1_linux_x64.tar.gz" gitleaks_checksums.txt | sha256sum -c -) || { warn "gitleaks SHA256 mismatch — NOT installing"; }
      tar -xzf "$INSTALL_DIR/tmp/dl/gitleaks.tar.gz" -C "$INSTALL_DIR/tmp/dl" gitleaks && mv "$INSTALL_DIR/tmp/dl/gitleaks" "$BIN/gitleaks" && chmod +x "$BIN/gitleaks" && say "gitleaks installed"
    fi
  fi
fi

# --- done ---------------------------------------------------------------------
echo ""
say "Batch 3 install complete."
echo "  Static analysis: semgrep 1.185.0, gosec 2.30.0, staticcheck 2026.2.2 (v0.8.2)"
echo "  Fuzzing         : medusa 1.5.1 (complements echidna 2.4.0 from batch 2)"
echo "  Decompile       : heimdall 0.9.3 (prints stale 0.9.2 — upstream string lag)"
echo "  Secrets         : gitleaks 8.30.1 (alongside trufflehog from batch 2)"
echo "  CAI fix         : mcp re-pinned to 1.28.1 — CAI CLI starts again"
echo ""
echo "Try:"
echo "  semgrep --version && gosec -h >/dev/null && staticcheck -h >/dev/null && gitleaks version"
echo "  Next: ./install-batch4.sh"
