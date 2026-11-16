---
name: huntmcp
description: HuntMCP (ankitsingh015) — multi-level AI agent orchestration for bug bounty inside OpenCode/Claude Code: HuntBrain orchestrator + specialist agents (Recon, Scan, Exploit, Report), 22 MCP servers, Writeup RAG + memory knowledge layer, 30+ vuln classes across OWASP WSTG. Use when the user says "huntmcp" or "huntbrain", or wants orchestrated autonomous hunting with validation. Source repo (cloned, read-only reference): ~/bug-bounty-tools/HuntMCP/. MCP servers are installed as code only — no platform credentials configured.
---

# HuntMCP

Upstream: https://github.com/ankitsingh015/HuntMCP. Architecture: Level 1 HuntBrain decides strategy → Level 2 specialists (Recon, Scan, Exploit, Report + dynamic specialists) → Knowledge Layer (writeup RAG + memory DB) learns from past hunts and public writeups.

## Sub-skills (52, installed as separate skills `hm-*`)

In `huntmcp/agents/` (6): `huntbrain.md`, `recon-agent.md`, `scan-agent.md`, `exploit-agent.md`, `report-agent.md`, `chain-planner.md`.
In `huntmcp/rules/` (5): `autonomous-execution.md`, `benchmarks.md`, `git-worktrees.md`, `security.md`, `testing.md`.

`hm-*` skills cover: access-control-and-idor, api-security-top10, auth-and-session, bounty-report-writing, cicd-and-supply-chain, crlf-injection, csrf-cors-origin, cryptography-and-padding-oracle, dos-and-resilience, file-upload-and-traversal, hacker-mindset-and-testing-engines, and more (52 total — see `~/workspace/custom-skills/hm-*/`).

## MCP servers (in the source repo `HuntMCP/mcp-servers/`)

22 servers wrapping subfinder, httpx, katana, nmap, dalfox, nuclei, sqlmap, ffuf, burp-import, osint (Shodan/VirusTotal/Censys/SecurityTrails — needs API keys, NOT configured), oob, waf-bypass, hackerone (needs account credentials, NOT configured). MCP servers are code only here; wire them into an MCP client when needed.

## How to use (lightweight)

- Do NOT run the full autonomous multi-agent loop on the free tier — it burns context fast. Use one specialist at a time: Recon → rank → one vuln class → validate → report.
- Scope is enforced by `HuntMCP/mcp-servers/bounty_scope.py` — read it before any hunt.
- Authorized targets only, in-scope assets only.
