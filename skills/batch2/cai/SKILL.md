---
name: cai
description: CAI — Cybersecurity AI (Alias Robotics). Agentic security framework: AI agents for pentesting, CTFs, bug bounty, code review and automation, driven by an LLM. Use when the user says "cai" or wants a general-purpose security agent CLI. Source repo (cloned, read-only reference): ~/bug-bounty-tools/CAI/. The repo line (v1.1.5) is subscription-gated — the installed CLI is the frozen open-source line from PyPI.
---

# CAI (Cybersecurity AI)

Upstream: https://github.com/aliasrobotics/cai (Alias Robotics). Agents (`cai/agents`) cover pentesting, CTF solving, bug bounty, code review, reverse engineering, OSINT and more, all driven by an LLM backend.

## Install (this VM)

```bash
~/bug-bounty-tools/venv-exploit/bin/pip install cai-framework   # open-source line, frozen at 0.5.10 (PyPI, Dec 2025)
~/bug-bounty-tools/venv-exploit/bin/cai --help
```

The repo checkout at `~/bug-bounty-tools/CAI/` is v1.1.5 — do NOT `pip install -e` it; the current line is subscription-gated per the README.

## Running it

CAI needs an LLM provider key to do anything (OpenAI, or other providers via its config). No key is configured here — when the user wants to run it, they supply a key via Secure Vault; never create accounts or keys on their behalf.

```bash
export OPENAI_API_KEY='<via Secure Vault>'
cai --help
```

## Notes

- Lightweight to install, heavy to run: every agent turn is LLM calls — use selectively on the free tier, 1–2 tasks per session, and prefer the file-based recon workflow (recon to file → Muse reads the file).
- Authorized targets only, in-scope assets only.
