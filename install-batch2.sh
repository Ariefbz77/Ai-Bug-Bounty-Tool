#!/bin/bash
# install-batch2.sh — Batch 2: hunting skill packs, frameworks, recon CLIs,
# Python audit tools, smart-contract audit binaries, wordlists.
#
# Pinned to the set verified on 2026-11-16 (batch 2 install report):
#   Skills (vendored in this repo) : 198 skills (hm-* 52, bg-find-* 17,
#     cbh-* 83, tc-* 43, hs-* 3) + 8 index skills — skills/batch2/
#   Framework repos (pinned)      : HuntMCP 1fc17bb, BountyGrimoire c55f833,
#     Claude-BugHunter 2cfe533, HexStrike AI d689933 (code only, server NOT
#     started), Hunter 333d0c5, CAI 6dc7925, communitytools 95fdc12,
#     cybersecurity-claude-skills 802e2f2
#   Go install (pinned)           : naabu 2.7.0, tlsx 1.4.5, uncover 1.2.1,
#     chaos 0.5.2, waybackurls 0.1.0, anew 0.1.1, gf (20200618 pseudo),
#     assetfinder 0.1.1, hakrawler (20260805 pseudo)
#   Go build from clone           : trufflehog @ 72cae0f (go install fails on
#     its go.mod replace directives — build from the clone instead)
#   Python venv (venv-exploit)    : arjun 2.2.7, commix 0.1,
#     slither-analyzer 0.11.6, solc-select 1.2.0 (solc 0.8.26 set current),
#     mythril 0.24.8, huntkit 0.3.0, cai-framework 0.5.10,
#     ParamSpider (git clone, editable), XSStrike v3.1.5 (git clone)
#   Release binaries              : echidna 2.4.0, sisakulint 0.3.8
#     (SHA256-verified against its checksums file)
#   Wordlists / patterns          : SecLists (git clone, ~2.5 GB),
#     Gf-Patterns (clone, 14 *.json copied to ~/.gf/)
#   Ollama (OPT-IN only)          : binary 0.40.16, NO models pulled.
#     Local Ollama needs ~5-9 GB free RAM for 7b/14b models — NOT viable on
#     small VMs. Set OLLAMA_INSTALL=1 to install the binary anyway; the
#     recommended free provider stays Groq/DeepSeek (key via Secure Vault).
#
# Deliberately NOT installed: Aderyn (retired upstream — its installer now
# refuses; Slither covers the same ground), Burp/Caido (batch 4, GUI apps).
#
# Usage:
#   ./install-batch2.sh                     # install into ~/bug-bounty-tools
#   INSTALL_DIR=/opt/bb-tools ./install-batch2.sh
#   DRY_RUN=1 ./install-batch2.sh           # print the plan, install nothing
#   SKILLS_SKIP=1 ./install-batch2.sh       # skip the skills copy
#   SECLISTS_SKIP=1 ./install-batch2.sh     # skip the 2.5 GB SecLists clone
#   OLLAMA_INSTALL=1 ./install-batch2.sh    # also install the Ollama binary
#   SKILLS_DIR=/path ./install-batch2.sh    # where the skill packs go
#
# Notes:
# - Linux x86_64 only. Go >= 1.23 is needed for the `go install` steps.
# - Go builds and pip installs use $INSTALL_DIR/tmp as TMPDIR — /tmp on
#   small VMs is often a 512 MB tmpfs and big builds exhaust it.
# - `bughunter setup` and any LLM key are intentionally NOT done here.
# - Hunt only in-scope targets, on programs that allow it.

set -u
INSTALL_DIR="${INSTALL_DIR:-$HOME/bug-bounty-tools}"
BIN="$INSTALL_DIR/bin"
VENV="$INSTALL_DIR/venv-exploit"
VENV_HUNTER="$INSTALL_DIR/venv-hunter"
SKILLS_DIR="${SKILLS_DIR:-$HOME/workspace/custom-skills}"
DRY_RUN="${DRY_RUN:-0}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
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
  command -v python3 >/dev/null 2>&1 || warn "python3 not found — Python tools will be skipped"
fi

ARCH="$(uname -m)"
[ "$ARCH" = "x86_64" ] || { warn "unsupported arch: $ARCH (this script targets linux/amd64)"; exit 1; }

say "Install dir: $INSTALL_DIR"
say "Skills dir:  $SKILLS_DIR"

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

# --- 1. Go recon CLIs (pinned via Go proxy, verified 2026-11-16) --------------
go_tool() { # $1=tool $2=package@version
  local tool="$1" pkg="$2"
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[dry-run] GOBIN=$BIN go install $pkg"
    return 0
  fi
  if [ -x "$BIN/$tool" ]; then
    say "$tool already present in $BIN — skip (delete it to force reinstall)"
    return 0
  fi
  if ! command -v go >/dev/null 2>&1; then warn "go missing — skipping $tool"; return 0; fi
  say "go install $tool ($pkg) ..."
  GOBIN="$BIN" go install "$pkg" || { warn "go install failed: $tool"; return 1; }
  say "$tool installed"
}

go_tool naabu       github.com/projectdiscovery/naabu/v2/cmd/naabu@v2.7.0
go_tool tlsx        github.com/projectdiscovery/tlsx/cmd/tlsx@v1.4.5
go_tool uncover     github.com/projectdiscovery/uncover/cmd/uncover@v1.2.1
go_tool chaos       github.com/projectdiscovery/chaos-client/cmd/chaos@v0.5.2
go_tool waybackurls github.com/tomnomnom/waybackurls@v0.1.0
go_tool anew        github.com/tomnomnom/anew@v0.1.1
go_tool gf          github.com/tomnomnom/gf@v0.0.0-20200618134122-dcd4c361f9f5
go_tool assetfinder github.com/tomnomnom/assetfinder@v0.1.1
go_tool hakrawler   github.com/hakluke/hakrawler@v0.0.0-20260805040537-52a16fe61bd1

# --- 2. trufflehog (build from clone: go install fails on replace dirs) -------
if [ "$DRY_RUN" -eq 1 ]; then
  echo "[dry-run] git clone https://github.com/trufflesecurity/trufflehog.git $INSTALL_DIR/trufflehog-src && git -C $INSTALL_DIR/trufflehog-src checkout 72cae0fbb6d5580138ab1e2310bc61a1e420b321"
  echo "[dry-run] cd $INSTALL_DIR/trufflehog-src && go build -o $BIN/trufflehog ."
elif [ -x "$BIN/trufflehog" ]; then
  say "trufflehog already present in $BIN — skip"
elif ! command -v go >/dev/null 2>&1; then
  warn "go missing — skipping trufflehog"
else
  clone_pinned https://github.com/trufflesecurity/trufflehog.git "$INSTALL_DIR/trufflehog-src" 72cae0fbb6d5580138ab1e2310bc61a1e420b321
  say "building trufflehog ..."
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[dry-run] cd $INSTALL_DIR/trufflehog-src && go build -o $BIN/trufflehog ."
  else
    (cd "$INSTALL_DIR/trufflehog-src" && go build -o "$BIN/trufflehog" .) || warn "trufflehog build failed"
    [ -x "$BIN/trufflehog" ] && say "trufflehog installed"
  fi
fi

# --- 3. Python venv (venv-exploit) + wrappers ---------------------------------
if command -v python3 >/dev/null 2>&1; then
  if [ ! -x "$VENV/bin/python" ]; then
    say "creating venv-exploit ..."
    run "python3 -m venv \"$VENV\""
  fi
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[dry-run] $VENV/bin/pip install setuptools==80.9.0 arjun==2.2.7 commix==0.1 slither-analyzer==0.11.6 solc-select==1.2.0 mythril==0.24.8 huntkit==0.3.0 cai-framework==0.5.10 \"mcp==1.28.1\" beautifulsoup4 fuzzywuzzy requests"
  elif [ -x "$VENV/bin/pip" ]; then
    # setuptools 80.9.0 first: mythril imports pkg_resources, removed in >= 81.
    "$VENV/bin/pip" install "setuptools==80.9.0" || warn "setuptools pin failed"
    "$VENV/bin/pip" install arjun==2.2.7 commix==0.1 slither-analyzer==0.11.6 solc-select==1.2.0 mythril==0.24.8 huntkit==0.3.0 cai-framework==0.5.10 || warn "pip install failed (see above)"
    # mcp MUST be 1.28.1: cai-framework pulls a broken older mcp, and
    # semgrep (batch 3) bumps it to 1.29.0 which breaks CAI + Hunter.
    "$VENV/bin/pip" install "mcp==1.28.1" || warn "mcp pin failed"
    "$VENV/bin/pip" install beautifulsoup4 fuzzywuzzy requests || warn "XSStrike deps failed"
    # solc 0.8.26 set current (0.8.38 also installed by batch-2 verification).
    "$VENV/bin/solc-select" install 0.8.26 >/dev/null 2>&1 || warn "solc 0.8.26 install failed"
    "$VENV/bin/solc-select" use 0.8.26 >/dev/null 2>&1 || warn "solc-select use 0.8.26 failed"
    say "venv-exploit ready"
  fi
else
  warn "python3 missing — skipping Python tools"
fi

# Wrappers: small shims so the venv tools are callable from $BIN.
mkshim() { # $1=name $2=body-command (already quoted as needed)
  local name="$1" body="$2"
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[dry-run] write $BIN/$name shim"
    return 0
  fi
  printf '#!/bin/sh\n# Wrapper generated by install-batch2.sh — do not edit by hand.\n%s "$@"\n' "$body" > "$BIN/$name"
  chmod +x "$BIN/$name"
}
if [ -x "$VENV/bin/python" ] || [ "$DRY_RUN" -eq 1 ]; then
  mkshim arjun       "exec \"$VENV/bin/arjun\""
  mkshim commix      "exec \"$VENV/bin/commix\""
  mkshim slither     "exec \"$VENV/bin/slither\""
  mkshim myth        "exec \"$VENV/bin/myth\""
  mkshim huntkit     "exec \"$VENV/bin/huntkit\""
  mkshim solc-select "exec \"$VENV/bin/solc-select\""
  mkshim solc        "exec \"$VENV/bin/solc\""
  # CAI: the host's NO_PROXY may contain bracketed IPv6 entries ([::1]) that
  # crash httpx at startup — export a clean list in the wrapper.
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[dry-run] write $BIN/cai shim (clean NO_PROXY)"
  else
    printf '#!/bin/sh\n# Wrapper: cai (CAI 0.5.10, PyPI open-source line; needs an LLM API key to run).\nexport NO_PROXY=localhost,127.0.0.1,::1\nexport no_proxy=localhost,127.0.0.1,::1\nexec "%s/bin/cai" "$@"\n' "$VENV" > "$BIN/cai"
    chmod +x "$BIN/cai"
  fi
fi

# --- 4. ParamSpider + XSStrike (git clones, NOT on PyPI) ----------------------
clone_pinned https://github.com/devanshbatham/ParamSpider.git "$INSTALL_DIR/ParamSpider" c44bdaae54789b237028e309b603d1aa5ad52e5e
clone_pinned https://github.com/s0md3v/XSStrike.git               "$INSTALL_DIR/XSStrike"     ab27955d367432f944d8f29897e09c15356e76f7
if [ "$DRY_RUN" -eq 1 ]; then
  echo "[dry-run] $VENV/bin/pip install -e $INSTALL_DIR/ParamSpider   # paramspider 0.1.0 (editable)"
  echo "[dry-run] write $BIN/paramspider shim + $BIN/xsstrike shim"
elif [ -x "$VENV/bin/pip" ]; then
  "$VENV/bin/pip" install -e "$INSTALL_DIR/ParamSpider" || warn "ParamSpider editable install failed"
  printf '#!/bin/sh\n# Wrapper: paramspider (git clone, NOT on PyPI)\nexec "%s/bin/paramspider" "$@"\n' "$VENV" > "$BIN/paramspider"
  printf '#!/bin/sh\n# Wrapper: XSStrike v3.1.5 (source checkout; deps in venv-exploit)\nexec "%s/bin/python" "%s/XSStrike/xsstrike.py" "$@"\n' "$VENV" "$INSTALL_DIR" > "$BIN/xsstrike"
  chmod +x "$BIN/paramspider" "$BIN/xsstrike"
  say "paramspider + xsstrike ready"
fi

# --- 5. Release binaries: echidna + sisakulint --------------------------------
dl_bin() { # $1=tool $2=url $3=archive-path-inside (empty = whole file is the binary)
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

dl_bin echidna https://github.com/crytic/echidna/releases/download/v2.4.0/echidna-2.4.0-x86_64-linux.tar.gz echidna

# sisakulint: SHA256-verified against its checksums file (v0.3.8).
if [ -x "$BIN/sisakulint" ] && [ "$DRY_RUN" -eq 0 ]; then
  say "sisakulint already present in $BIN — skip"
else
  say "downloading sisakulint 0.3.8 ..."
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[dry-run] curl -fsSL https://github.com/sisaku-security/sisakulint/releases/download/v0.3.8/sisakulint_0.3.8_linux_amd64.tar.gz + checksums, sha256sum -c, extract -> $BIN/sisakulint"
  else
    mkdir -p "$INSTALL_DIR/tmp/dl"
    curl -fsSL "https://github.com/sisaku-security/sisakulint/releases/download/v0.3.8/sisakulint_0.3.8_linux_amd64.tar.gz" -o "$INSTALL_DIR/tmp/dl/sisakulint.tar.gz" || warn "sisakulint download failed"
    curl -fsSL "https://github.com/sisaku-security/sisakulint/releases/download/v0.3.8/sisakulint_0.3.8_checksums.txt" -o "$INSTALL_DIR/tmp/dl/sisakulint_checksums.txt" || warn "sisakulint checksums download failed"
    if [ -f "$INSTALL_DIR/tmp/dl/sisakulint.tar.gz" ] && [ -f "$INSTALL_DIR/tmp/dl/sisakulint_checksums.txt" ]; then
      (cd "$INSTALL_DIR/tmp/dl" && grep "sisakulint_0.3.8_linux_amd64.tar.gz" sisakulint_checksums.txt | sha256sum -c -) || { warn "sisakulint SHA256 mismatch — NOT installing"; }
      tar -xzf "$INSTALL_DIR/tmp/dl/sisakulint.tar.gz" -C "$INSTALL_DIR/tmp/dl" sisakulint && mv "$INSTALL_DIR/tmp/dl/sisakulint" "$BIN/sisakulint" && chmod +x "$BIN/sisakulint" && say "sisakulint installed"
    fi
  fi
fi

# --- 6. Agent frameworks (pinned to the commits verified 2026-11-16) ---------
clone_pinned https://github.com/ankitsingh015/HuntMCP.git                    "$INSTALL_DIR/HuntMCP"                    1fc17bb6d4f7470a2b79cf65530917ad9699e5c5
clone_pinned https://github.com/N1neKitsune/BountyGrimoire.git              "$INSTALL_DIR/BountyGrimoire"              c55f83349d92f8de05882db688afbbf21526ae8f
clone_pinned https://github.com/elementalsouls/Claude-BugHunter.git         "$INSTALL_DIR/Claude-BugHunter"            2cfe533df8efa2ced87c91299e1f62b88cb26108
clone_pinned https://github.com/0x4m4/hexstrike-ai.git                      "$INSTALL_DIR/hexstrike-ai"                d689933ff579d839c676c82b231f8e98326c5f04
clone_pinned https://github.com/GeniusHu-tgty/Hunter.git                    "$INSTALL_DIR/Hunter"                      333d0c57fb3bbc152be06242fc93bf50c12f89ef
clone_pinned https://github.com/aliasrobotics/cai.git                       "$INSTALL_DIR/CAI"                         6dc79257777f5f1c9500b4d2319935d34a47412e
clone_pinned https://github.com/transilienceai/communitytools.git           "$INSTALL_DIR/communitytools"              95fdc128af4ca1ae16b3226f9430f1bad97b0656
clone_pinned https://github.com/mahmutka/cybersecurity-claude-skills.git   "$INSTALL_DIR/cybersecurity-claude-skills" 802e2f2bf1d1b66c4336d8595c3db3ad125514e3

# Hunter MCP server: its own venv (mcp 1.28.1) — CAI's venv pins mcp older,
# Hunter needs mcp>=1.20,<1.29. The server is installed, NOT auto-started.
if command -v python3 >/dev/null 2>&1; then
  if [ ! -x "$VENV_HUNTER/bin/python" ]; then
    say "creating venv-hunter ..."
    run "python3 -m venv \"$VENV_HUNTER\""
  fi
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[dry-run] $VENV_HUNTER/bin/pip install \"mcp==1.28.1\" dnspython pyyaml requests"
    echo "[dry-run] write $BIN/hunter-mcp shim"
  elif [ -x "$VENV_HUNTER/bin/pip" ]; then
    "$VENV_HUNTER/bin/pip" install "mcp==1.28.1" dnspython pyyaml requests || warn "venv-hunter deps failed"
    printf '#!/bin/sh\n# Wrapper: Hunter MCP server (FastMCP, 179 tools) — own venv.\nexec "%s/bin/python" "%s/Hunter/mcp_server.py" "$@"\n' "$VENV_HUNTER" "$INSTALL_DIR" > "$BIN/hunter-mcp"
    chmod +x "$BIN/hunter-mcp"
    say "hunter-mcp ready (server not started — run it from an MCP client)"
  fi
fi

# --- 7. Hunting skill packs (vendored in this repo: skills/batch2/) -----------
if [ "${SKILLS_SKIP:-0}" -eq 1 ]; then
  say "SKILLS_SKIP=1 — skipping skill packs"
elif [ ! -d "$SCRIPT_DIR/skills/batch2" ]; then
  warn "skills/batch2 not found next to this script — clone the full repo (skills are vendored there)"
else
  say "copying 198 skills + 8 index skills -> $SKILLS_DIR ..."
  run "mkdir -p \"$SKILLS_DIR\""
  run "cp -r \"$SCRIPT_DIR/skills/batch2/.\" \"$SKILLS_DIR/\""
  say "skills installed (198 sub-skills + 8 index skills)"
fi

# --- 8. Gf-Patterns + SecLists -------------------------------------------------
clone_pinned https://github.com/1ndianl33t/Gf-Patterns.git "$INSTALL_DIR/Gf-Patterns" f686f06ae647726578920084c894100d702496cc
if [ "$DRY_RUN" -eq 1 ]; then
  echo "[dry-run] cp $INSTALL_DIR/Gf-Patterns/*.json -> \$HOME/.gf/ (14 patterns)"
else
  mkdir -p "$HOME/.gf"
  cp "$INSTALL_DIR/Gf-Patterns"/*.json "$HOME/.gf/" 2>/dev/null && say "gf patterns installed to ~/.gf"
fi

if [ "${SECLISTS_SKIP:-0}" -eq 1 ]; then
  say "SECLISTS_SKIP=1 — skipping SecLists clone (~2.5 GB)"
else
  if [ -d "$INSTALL_DIR/SecLists/.git" ]; then
    say "SecLists already cloned — skip"
  else
    say "cloning SecLists (~2.5 GB — takes a while) ..."
    run "git clone --depth 1 https://github.com/danielmiessler/SecLists.git \"$INSTALL_DIR/SecLists\""
  fi
fi

# --- 9. Ollama binary (OPT-IN only — see header) ------------------------------
if [ "${OLLAMA_INSTALL:-0}" -eq 1 ]; then
  if [ -x "$BIN/ollama" ] && [ "$DRY_RUN" -eq 0 ]; then
    say "ollama already present in $BIN — skip"
  else
    say "downloading Ollama 0.40.16 (1.47 GB tarball, zstd) ..."
    if [ "$DRY_RUN" -eq 1 ]; then
      echo "[dry-run] curl -fsSL https://github.com/ollama/ollama/releases/download/v0.40.16/ollama-linux-amd64.tar.zst -> extract (zstd or python zstandard) -> $BIN/ollama"
    else
      mkdir -p "$INSTALL_DIR/tmp/dl"
      curl -fsSL "https://github.com/ollama/ollama/releases/download/v0.40.16/ollama-linux-amd64.tar.zst" -o "$INSTALL_DIR/tmp/dl/ollama.tar.zst" || warn "ollama download failed"
      if [ -f "$INSTALL_DIR/tmp/dl/ollama.tar.zst" ]; then
        if command -v zstd >/dev/null 2>&1; then
          (cd "$INSTALL_DIR/tmp/dl" && zstd -d -q -f ollama.tar.zst && mkdir -p ollama-x && tar -xf ollama.tar -C ollama-x && cp ollama-x/bin/ollama "$BIN/ollama") || warn "ollama extract failed"
        else
          python3 - "$INSTALL_DIR/tmp/dl/ollama.tar.zst" "$BIN/ollama" <<'PYEOF' || warn "ollama extract failed (needs zstd or python zstandard)"
import sys, tarfile, io
try:
    import zstandard
except ImportError:
    sys.exit("python zstandard module missing: pip install zstandard, then re-run")
src, dst = sys.argv[1], sys.argv[2]
dctx = zstandard.ZstdDecompressor()
with open(src, "rb") as f, dctx.stream_reader(f) as r, tarfile.open(fileobj=r, mode="r|") as t:
    m = t.next()
    while m is not None:
        if m.name.endswith("/bin/ollama"):
            with open(dst, "wb") as out:
                out.write(t.extractfile(m).read())
            break
        m = t.next()
PYEOF
        fi
        chmod +x "$BIN/ollama" 2>/dev/null && say "ollama 0.40.16 installed (binary only — NO models pulled)"
      fi
    fi
  fi
else
  say "Ollama binary skipped (OLLAMA_INSTALL not set) — local Ollama needs ~5-9 GB free RAM; use Groq/DeepSeek free tier instead"
fi

# --- done ---------------------------------------------------------------------
echo ""
say "Batch 2 install complete."
echo "  Go tools : naabu, tlsx, uncover, chaos, waybackurls, anew, gf, assetfinder, hakrawler, trufflehog"
echo "  Python   : $VENV (arjun, commix, slither 0.11.6, solc-select, mythril 0.24.8, huntkit, cai 0.5.10, ParamSpider, XSStrike)"
echo "  Binaries : $BIN (echidna 2.4.0, sisakulint 0.3.8)"
echo "  Frameworks: HuntMCP, BountyGrimoire, Claude-BugHunter, HexStrike AI (code only), Hunter, CAI, communitytools, cybersecurity-claude-skills"
echo "  Skills   : $SKILLS_DIR (198 sub-skills + 8 index skills)"
echo "  Wordlists: $INSTALL_DIR/SecLists, ~/.gf (14 patterns)"
echo ""
echo "Notes:"
echo "  - Aderyn was NOT installed: retired upstream (its installer refuses)."
echo "  - HexStrike server is code only here — see install-batch4.sh to run it (127.0.0.1 only)."
echo "  - CAI needs an LLM API key to do anything — supply it yourself, never in a file."
echo "  - Next: ./install-batch3.sh"
