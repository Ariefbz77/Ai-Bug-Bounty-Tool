---
name: hexstrike-ai
description: HexStrike AI MCP (0x4m4) — MCP server bridging 150+ security tools (nmap, sqlmap, nuclei, ffuf, httpx, subfinder, katana, dalfox, hashcat, gobuster, mitmproxy, volatility3, Ghidra, Prowler…) to any MCP-compatible AI client. Use when the user says "hexstrike" or wants one MCP entry point to the whole CLI arsenal. Source repo (cloned, read-only reference): ~/bug-bounty-tools/hexstrike-ai/. The server is NOT running — install is code only.
---

# HexStrike AI

Upstream: https://github.com/0x4m4/hexstrike-ai (MIT, v6.0, 13.6k stars). Two processes: `hexstrike_mcp.py` (FastMCP adapter over stdio, the part an AI host launches) + `hexstrike_server.py` (Flask API on 127.0.0.1:8888 that actually executes tools).

## How to run (when needed — not auto-started)

```bash
cd ~/bug-bounty-tools/hexstrike-ai
python3 hexstrike_server.py --debug --port 8888   # terminal 1: tool-execution API
# terminal 2 / MCP client config: launch hexstrike_mcp.py over stdio
```

Dependencies: Python 3 + `pip install -r requirements.txt` (FastMCP, Flask). Check `hexstrike-ai-mcp.json` in the repo for a sample MCP client config.

## SELECTIVE USE (free-tier rule — do not run everything at once)

Start with only these five tools, the ones already installed locally:

- `nuclei` — templated vuln scanning
- `httpx` — live-host probing + tech detection
- `subfinder` — subdomain enumeration
- `katana` — crawling / endpoint discovery
- `ffuf` — content discovery / fuzzing

Add others (sqlmap, naabu, dalfox, gobuster…) one at a time, only when a lead needs them. The bridge exposes ~150 tools; fanning out to all of them in one session burns context and rate limit for nothing.

## SAFETY WARNING — read before running

The server has NO authentication, NO approval step, and NO sandbox: any client driving the MCP bridge runs shell commands with the full authority of the server's OS user (per the project's own docs and independent reviews). Only ever run it in a disposable environment, on localhost, and only against authorized in-scope targets. Never expose port 8888. Never set `alwaysAllow` to allow all tools without review.
