# AI Bug Bounty Tool

AI agent frameworks & toolkits for bug bounty hunting — install guide, curated list, and a ready-to-run recon pipeline. Built so anyone can install the tools and start hunting.

## Batch 1 — What's inside (install with `./install.sh`)

Batch 1 is the first verified install (2026-11-16). Binaries are **not** vendored here — `install.sh` downloads them from their official releases, pinned to the versions below. Batches 2–4 (more tools) are coming next, in the same style.

| Tool | Version | Installed by |
|------|---------|--------------|
| subfinder | 2.17.0 | release binary |
| httpx | 1.12.0 | release binary |
| nuclei | 3.11.1 | release binary |
| katana | 1.8.0 | release binary |
| dnsx | 1.3.1 | release binary |
| ffuf | 2.3.0 | release binary |
| gau | 2.2.4 | release binary |
| amass | 4.2.0 | `go install` |
| dalfox | 2.13.0 | `go install` |
| subjack | pinned pseudo-version `v0.0.0-20260316055456-b53899ce6230` | `go install` |
| nmap | 7.94 | apt |
| agentic-bug-hunter (`bughunter`) | 6.0.2 | pipx |
| sqlmap | 1.10.11 | pipx |
| bbot | 3.1.0 | pipx |
| nuclei-templates | git HEAD `fe25b05` (at install time) | git clone → `~/nuclei-templates` |
| Agentic-Bug-Hunter (framework repo) | commit `82f4512` | git clone |
| pentest-agents (framework repo) | commit `41d49b6` | git clone |

**Files in this repo (Batch 1):**

- `install.sh` — installs everything above. Re-running is safe (present tools are skipped). `DRY_RUN=1 ./install.sh` prints the plan without installing anything.
- `recon.sh` — the verified recon pipeline (amass + subfinder → dnsx → httpx → nuclei). See `RECON-PIPELINE.md` for the file-first workflow.
- `RECON-PIPELINE.md` — how to run recon and hand the results to your AI agent without burning context.

**Quick start:**

```bash
./install.sh
export PATH="$HOME/bug-bounty-tools/bin:$HOME/.local/bin:$PATH"
bughunter setup        # pick a free provider (Ollama / Groq / DeepSeek)
./recon.sh example.com # results in recon_example.com/SUMMARY.md
```

Note: `recon.sh` looks for the tools next to itself (`./bin`), then in `~/bug-bounty-tools/bin` (the `install.sh` default), then on `PATH` — override with `BUG_BOUNTY_BIN=/path/to/bin`.

## Top AI Agent Frameworks / Toolkits for Bug Bounty

| Tool / Project | Type | Key Strengths | Notes |
|---------------|------|---------------|-------|
| **Agentic-Bug-Hunter** (AwareXone) | CLI + Claude Code plugin + MCP | Full pipeline (recon → hunt → validate → report), 9 specialist agents, free-first LLM support (Ollama, Groq, DeepSeek…), wraps subfinder/httpx/nuclei/ffuf/nmap/etc., strict 7-Question validation gate | One of the most complete ready-to-use options. Works standalone or as agent skills. |
| **pentest-agents** (H-mmer) | Multi-agent suite for Claude Code / Codex / Gemini / Cursor / etc. | ~50 specialized agents, 26 commands, 19 CLI helpers, MCP servers for bounty platforms (HackerOne, Bugcrowd, etc.), persistent memory, exploit chaining | Very comprehensive; strong on methodology and platform integration. |
| **HuntMCP** | Multi-level agent orchestration (OpenCode / Claude Code) | HuntBrain orchestrator + specialist agents (Recon, Scan, Exploit, Chain, Report). MCP wrappers for nuclei, sqlmap, subfinder, katana, ffuf, etc. | Good architecture for autonomous hunting with validation. |
| **BountyGrimoire** | Parallel specialized hunters | 18 agents focused on specific vuln classes (IDOR, SSRF, SQLi, XSS, Auth, RCE, etc.) + built-in validator | Strong for parallel hunting of common web vuln classes. |
| **CAI** (Cybersecurity AI) | Lightweight agent framework | Built-in security tools, modular agents, tested on real bug bounties & CTFs | More of a foundation to build your own agents on. |

Other notable mentions:
- **Claude-BugHunter** skill bundles
- Various MCP servers that expose Burp Suite / Caido / Kali tools to agentic CLIs (Claude Code, Gemini CLI, Codex)

## 1. Best Starting Point: Agentic-Bug-Hunter (Recommended)

Currently one of the most complete and usable agent toolkits.

**What it gives you:**
- Standalone CLI (`bughunter`) that works with free/local models
- Claude Code / OpenCode plugin with specialist agents + slash commands
- MCP server support
- Built-in 7-Question validation gate (kills weak/theoretical findings)
- Memory across sessions
- Wraps real tools: subfinder, httpx, nuclei, katana, ffuf, nmap, dalfox, etc.

**Quick install (standalone — works without paid subscription):**

```bash
# Fastest way
uv tool install agentic-bug-hunter
# or
pipx install agentic-bug-hunter

bughunter setup          # Choose Ollama (local/free), Groq, DeepSeek, etc.
```

**Alternative (full repo + tools):**

```bash
git clone https://github.com/Awarexone/Agentic-Bug-Hunter.git
cd Agentic-Bug-Hunter
./install.sh --agent standalone
./install_tools.sh       # Installs the recon/scanning arsenal
bughunter setup
```

**Core workflow:**

```bash
bughunter recon target.com
bughunter hunt target.com
bughunter validate "description of finding"
bughunter report
```

It also supports Claude Code slash commands (`/recon`, `/hunt`, `/validate`, `/report`, `/chain`, `/autopilot`, etc.) once installed as a plugin.

## 2. Heavy-Duty Alternative: pentest-agents (H-mmer)

Larger and more methodology-heavy (~50 specialized agents).

**Key features:**
- Dedicated agents for almost every vuln class (IDOR, SSRF, SQLi, XSS, GraphQL, race conditions, business logic, Web3, LLM-specific, etc.)
- Persistent "brain" with endpoint tracking
- Scope enforcement hooks
- 7-Question Gate + never-submit rules
- MCP servers for HackerOne / Bugcrowd / etc.
- Works with Claude Code, Codex, Gemini, Cursor, Windsurf, Copilot, OpenClaw

**Typical start:**

```bash
git clone https://github.com/H-mmer/pentest-agents.git
# Use the scaffold tool to create a workspace for a specific program
uv run python3 tools/scaffold.py hackerone program-name
cd ~/bounties/hackerone-program-name
claude   # or codex / gemini etc.
```

Then use commands like `/hunt`, `/brain init`, `/sync`, etc.

This one is excellent if you want deep methodology baked into the agents rather than just tool orchestration.

## 3. Essential CLI Tools Agents Commonly Drive

These are the workhorses most agent frameworks wrap:

**Recon / Surface Mapping**
- `subfinder`, `amass`, `assetfinder`, `bbot`
- `dnsx`, `httpx` (live host probing + tech detection)
- `katana`, `gau`, `waybackurls` (URL / endpoint discovery)
- `ffuf` (content discovery / fuzzing)

**Scanning / Exploitation**
- `nuclei` (templated vuln scanning — still king)
- `sqlmap`, `dalfox` (XSS)
- `nmap` / masscan
- Custom or AI-generated payloads + browser automation

**Supporting**
- Scope checking / rate-limiting scripts
- Report generators that output HackerOne/Bugcrowd-ready Markdown

## 4. Architecture That Actually Works in 2026

Successful AI-assisted hunting usually looks like this:

| Layer | Responsibility | Who owns it |
|-------|----------------|-------------|
| **Scope Guard** | Hard-coded allow/deny lists + rate limits | Your code / hooks (never trust the LLM) |
| **Recon Engine** | subfinder → dnsx → httpx → katana/gau → tech detection | Deterministic tools |
| **Prioritizer** | Rank assets by likelihood of high-value bugs | AI agent |
| **Specialist Hunters** | One agent per vuln class or tech stack | AI agents |
| **Validator** | Independent reproduction + impact check | Separate agent + human |
| **Reporter** | Draft only (never auto-submit) | AI drafts → human finalizes |

**Critical rule from current platform policies:**
Use AI heavily for recon, prioritization, payload ideas, and report drafting.
**Never** let it submit. You must personally reproduce every finding.

## 5. Minimal Reliable Pipeline You Can Run Today

Even without the full frameworks, this is a solid agent-friendly flow:

```bash
# 1. Subdomains
subfinder -d target.com -silent -all | anew subs.txt

# 2. Resolve + live
cat subs.txt | dnsx -silent | httpx -silent -sc -title -td -o live.txt

# 3. Crawl
cat live.txt | katana -silent -d 3 -o urls.txt
# or gau + waybackurls for historical

# 4. Nuclei (passive-ish first)
nuclei -l live.txt -t cves/,exposures/,misconfiguration/ -severity medium,high,critical -o nuclei.txt

# 5. Feed interesting hosts/endpoints to your AI agent for deeper analysis
```

Then hand the high-signal output to an agent for:
- JS analysis
- Parameter mining
- IDOR / auth testing ideas
- Business logic review

## 6. Guardrails (Do Not Skip)

1. **Scope enforcement in code** — the agent should not be able to touch out-of-scope hosts even if it wants to.
2. **Read-only by default** for network tools where possible.
3. **Human approval gate** before any report is written or submitted.
4. **Validation gate** (the 7-Question style) before calling something "confirmed".
5. Prefer local models (Ollama) or cheap fast ones (Groq) for high-volume recon loops.
6. Keep session notes / findings in structured files the agent can read across sessions.

## Recommended Setup Patterns

1. **Agentic CLI + MCP** (most powerful right now)
   Run Claude Code / Gemini CLI / Codex → connect MCP servers for your proxy (Burp/Caido) + recon tools + scope enforcement. The model can read history, replay requests, run tools, and keep notes.

2. **Specialist multi-agent systems**
   One orchestrator + focused agents (recon-agent, validator, report-writer, chain-builder, etc.). This is what Agentic-Bug-Hunter, HuntMCP, and pentest-agents do.

3. **Hybrid (recommended in practice)**
   Let the agent handle recon ranking, prioritization, payload suggestion, report drafting, and initial triage.
   **You** still manually reproduce and confirm impact before submitting. Platforms dislike pure AI-generated reports with no human validation.

## Credits

- [Agentic-Bug-Hunter](https://github.com/Awarexone/Agentic-Bug-Hunter) by AwareXone
- [pentest-agents](https://github.com/H-mmer/pentest-agents) by H-mmer
- [HuntMCP](https://github.com/search?q=HuntMCP) · [BountyGrimoire](https://github.com/search?q=BountyGrimoire) · [CAI](https://github.com/aliasrobotics/cai)

> Hunt only in-scope targets, on programs that allow it. Never submit a finding you have not reproduced yourself.
