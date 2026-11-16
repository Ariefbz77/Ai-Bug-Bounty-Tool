#!/bin/bash
# install.sh — Batch 1: bug-bounty recon tools + agent frameworks
#
# Installs the pinned, verified toolset (versions tested 2026-11-16):
#   Release binaries : subfinder 2.17.0, httpx 1.12.0, nuclei 3.11.1,
#                      katana 1.8.0, dnsx 1.3.1, ffuf 2.3.0, gau 2.2.4
#   Go install       : amass v4.2.0, dalfox v2.13.0, subjack (pinned pseudo-version)
#   System package   : nmap 7.94 (apt; Debian/Ubuntu)
#   Python (pipx)    : agentic-bug-hunter 6.0.2, sqlmap 1.10.11, bbot 3.1.0
#   Git clones       : nuclei-templates, Agentic-Bug-Hunter (82f4512),
#                      pentest-agents (41d49b6)
#
# Binaries are NOT vendored in this repo — this script downloads them from
# their official releases. Re-running is safe: tools already present are skipped.
#
# Usage:
#   ./install.sh                        # install into ~/bug-bounty-tools
#   INSTALL_DIR=/opt/bb-tools ./install.sh
#   DRY_RUN=1 ./install.sh              # print the plan, install nothing
#
# After install, add the tools to your PATH (the script prints the line):
#   export PATH="$HOME/bug-bounty-tools/bin:$HOME/.local/bin:$PATH"
#
# Notes:
# - Linux x86_64 only. Go >= 1.23 is needed for the `go install` steps.
# - `bughunter setup` is intentionally NOT run here — it asks for a provider
#   and possibly an API key. Run it yourself afterwards (free options:
#   Ollama local, Groq free tier, DeepSeek). Never put API keys in a file.
# - Hunt only in-scope targets, on programs that allow it.

set -u
INSTALL_DIR="${INSTALL_DIR:-$HOME/bug-bounty-tools}"
BIN="$INSTALL_DIR/bin"
DRY_RUN="${DRY_RUN:-0}"
TMPDIR_WORK="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_WORK"' EXIT

say()  { echo "[+] $*"; }
warn() { echo "[!] $*" >&2; }
run()  { if [ "$DRY_RUN" -eq 1 ]; then echo "[dry-run] $*"; else eval "$*"; fi; }

need() {
  command -v "$1" >/dev/null 2>&1 || { warn "missing required command: $1"; exit 1; }
}

# --- prereqs ----------------------------------------------------------------
need curl; need unzip; need git
# Go is often installed outside PATH (e.g. /usr/local/go/bin) — pick it up if so.
if ! command -v go >/dev/null 2>&1; then
  for g in /usr/local/go/bin "$HOME/go/bin" "$HOME/.local/go/bin"; do
    [ -x "$g/go" ] && export PATH="$g:$PATH" && break
  done
fi
if [ "$DRY_RUN" -eq 0 ]; then
  command -v go >/dev/null 2>&1 || warn "go not found — amass/dalfox/subjack steps will be skipped (install Go >= 1.23 and re-run)"
  command -v pipx >/dev/null 2>&1 || command -v python3 >/dev/null 2>&1 || warn "neither pipx nor python3 found — Python tools will be skipped"
fi

ARCH="$(uname -m)"
[ "$ARCH" = "x86_64" ] || { warn "unsupported arch: $ARCH (this script targets linux/amd64)"; exit 1; }

say "Install dir: $INSTALL_DIR"
run "mkdir -p \"$BIN\""

# --- 1. Prebuilt release binaries (ProjectDiscovery, ffuf, gau) --------------
# Asset names verified to resolve (HTTP 200) on 2026-11-16.
dl_release() { # $1=tool $2=version $3=repo $4=asset $5=archive-kind(zip|tgz)
  local tool="$1" ver="$2" repo="$3" asset="$4" kind="$5"
  if [ -x "$BIN/$tool" ] && [ "$DRY_RUN" -eq 0 ]; then
    say "$tool already present in $BIN — skip (delete it to force reinstall)"
    return 0
  fi
  local url="https://github.com/$repo/releases/download/v$ver/$asset"
  say "downloading $tool v$ver ..."
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[dry-run] curl -fsSL $url -> $TMPDIR_WORK/$asset ; extract $tool -> $BIN/$tool"
    return 0
  fi
  curl -fsSL "$url" -o "$TMPDIR_WORK/$asset" || { warn "download failed: $url"; return 1; }
  if [ "$kind" = "zip" ]; then
    unzip -o -q "$TMPDIR_WORK/$asset" "$tool" -d "$TMPDIR_WORK" || { warn "unzip failed: $asset"; return 1; }
  else
    tar -xzf "$TMPDIR_WORK/$asset" -C "$TMPDIR_WORK" "$tool" || { warn "extract failed: $asset"; return 1; }
  fi
  mv "$TMPDIR_WORK/$tool" "$BIN/$tool" && chmod +x "$BIN/$tool"
  say "$tool v$ver installed"
}

dl_release subfinder 2.17.0 projectdiscovery/subfinder subfinder_2.17.0_linux_amd64.zip zip
dl_release httpx    1.12.0 projectdiscovery/httpx    httpx_1.12.0_linux_amd64.zip    zip
dl_release nuclei   3.11.1 projectdiscovery/nuclei   nuclei_3.11.1_linux_amd64.zip   zip
dl_release katana   1.8.0  projectdiscovery/katana   katana_1.8.0_linux_amd64.zip   zip
dl_release dnsx     1.3.1  projectdiscovery/dnsx     dnsx_1.3.1_linux_amd64.zip     zip
dl_release ffuf     2.3.0  ffuf/ffuf                 ffuf_2.3.0_linux_amd64.tar.gz  tgz
dl_release gau      2.2.4  lc/gau                    gau_2.2.4_linux_amd64.tar.gz   tgz

# --- 2. Go installs (no usable release asset existed for these) ---------------
go_tool() { # $1=tool $2=package@version
  local tool="$1" pkg="$2"
  if [ -x "$BIN/$tool" ] && [ "$DRY_RUN" -eq 0 ]; then
    say "$tool already present in $BIN — skip (delete it to force reinstall)"
    return 0
  fi
  if ! command -v go >/dev/null 2>&1; then warn "go missing — skipping $tool"; return 0; fi
  say "go install $tool ($pkg) ..."
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[dry-run] GOBIN=$BIN go install $pkg"
    return 0
  fi
  GOBIN="$BIN" go install "$pkg" || { warn "go install failed: $tool"; return 1; }
  say "$tool installed"
}

# subjack has no versioned release; this pseudo-version is the one verified 2026-11-16.
go_tool amass   github.com/owasp-amass/amass/v4/cmd/amass@v4.2.0
go_tool dalfox  github.com/hahwul/dalfox/v2@v2.13.0
go_tool subjack github.com/haccer/subjack@v0.0.0-20260316055456-b53899ce6230


# --- 3. nmap (system package) -------------------------------------------------
if command -v nmap >/dev/null 2>&1; then
  say "nmap already present — skip"
elif command -v apt-get >/dev/null 2>&1; then
  say "installing nmap via apt ..."
  run "sudo apt-get update"
  run "sudo apt-get install -y nmap"
else
  warn "nmap not found and no apt-get — install nmap manually and re-run"
fi

# --- 4. Python tools (pipx preferred, pip --user fallback) --------------------
pip_install() { # $1=pkg $2=version
  local pkg="$1" ver="$2"
  if command -v "$pkg" >/dev/null 2>&1 && [ "$DRY_RUN" -eq 0 ]; then
    say "$pkg already on PATH — skip (pipx reinstall to force)"
    return 0
  fi
  say "installing $pkg $ver ..."
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[dry-run] pipx install $pkg==$ver   (or: python3 -m pip install --user $pkg==$ver)"
    return 0
  fi
  if command -v pipx >/dev/null 2>&1; then
    pipx install "$pkg==$ver" || { warn "pipx install failed: $pkg"; return 1; }
  else
    python3 -m pip install --user "$pkg==$ver" || { warn "pip install failed: $pkg"; return 1; }
  fi
  say "$pkg $ver installed"
}

pip_install agentic-bug-hunter 6.0.2
pip_install sqlmap 1.10.11
pip_install bbot 3.1.0

# --- 5. Nuclei templates (nuclei expects them at ~/nuclei-templates) ---------
if [ -d "$HOME/nuclei-templates/.git" ]; then
  say "nuclei-templates already cloned — updating ..."
  run "git -C \"$HOME/nuclei-templates\" pull --ff-only"
else
  say "cloning nuclei-templates ..."
  run "git clone --depth 1 https://github.com/projectdiscovery/nuclei-templates.git \"$HOME/nuclei-templates\""
fi

# --- 6. Agent frameworks (pinned to the commits verified 2026-11-16) ---------
clone_pinned() { # $1=repo-url $2=dir $3=commit
  local url="$1" dir="$2" commit="$3"
  if [ -d "$dir/.git" ]; then
    say "$(basename "$dir") already cloned — skip (git -C $dir checkout $commit to pin)"
    return 0
  fi
  say "cloning $(basename "$dir") ..."
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[dry-run] git clone $url $dir && git -C $dir checkout $commit"
    return 0
  fi
  git clone "$url" "$dir" || { warn "clone failed: $url"; return 1; }
  git -C "$dir" checkout "$commit" || warn "checkout $commit failed in $dir (repo moved on — staying on default branch)"
  say "$(basename "$dir") cloned @ $commit"
}

clone_pinned https://github.com/Awarexone/Agentic-Bug-Hunter.git "$INSTALL_DIR/Agentic-Bug-Hunter" 82f4512ec432765297c36e6b3ef7dc3fe5a58be2
clone_pinned https://github.com/H-mmer/pentest-agents.git        "$INSTALL_DIR/pentest-agents"    41d49b644e1bc0f3031819410fc5406918360c4e

# --- done ---------------------------------------------------------------------
echo ""
say "Batch 1 install complete."
echo "  Binaries : $BIN (subfinder, httpx, nuclei, katana, dnsx, ffuf, gau, amass, dalfox, subjack)"
echo "  Templates: \$HOME/nuclei-templates"
echo "  Frameworks: $INSTALL_DIR/Agentic-Bug-Hunter  $INSTALL_DIR/pentest-agents"
echo ""
echo "Add to your shell PATH (e.g. in ~/.bashrc):"
echo "  export PATH=\"$BIN:\$HOME/.local/bin:\$PATH\""
echo ""
echo "Next steps:"
echo "  1. bughunter setup        # pick a free provider (Ollama / Groq / DeepSeek)"
echo "  2. ./recon.sh example.com # recon -> recon_example.com/SUMMARY.md"
echo "  3. Read RECON-PIPELINE.md for the file-first workflow."
