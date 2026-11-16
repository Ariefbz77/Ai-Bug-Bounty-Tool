---
name: communitytools
description: Transilience AI Community Tools — lightweight Claude Code skill pack: 23 skills, 8 agents, 2 tool integrations, 100% OWASP Top 10 + OWASP LLM Top 10, incl. a HackerOne bug bounty workflow. Use when the user says "communitytools", "transilience", or wants a light (non-50-agent) bounty/pentest skill set. Source repo (cloned, read-only reference): ~/bug-bounty-tools/communitytools/. Do NOT run its Kali/Docker setup script on this VM.
---

# Transilience Community Tools

Upstream: https://github.com/transilienceai/communitytools (MIT, 2026). Lighter than pentest-agents / HuntMCP: plain markdown skills + agents, no heavy orchestration. Their autonomous pentest agent scored 100% (104/104) on a published CTF benchmark using only structured skill files.

## Sub-skills (43, installed as separate skills `tc-*`)

Recon + hunting: `tc-reconnaissance`, `tc-osint`, `tc-essential-tools`, `tc-techstack-identification`, `tc-hackerone`, `tc-pentest-engagement`, `tc-source-code-scanning`, `tc-api-security`, `tc-injection`, `tc-authentication`, `tc-client-side`, `tc-server-side`, `tc-web-app-logic`, `tc-attack-path-stitcher`, `tc-authenticated-session-acquisition`, `tc-coordination`, `tc-cve-poc-generator`, `tc-cve-risk-score`, `tc-risk-prioritiser`, `tc-regression-sweep`, `tc-script-generator`, `tc-patt-fetcher`, `tc-ti-ingest`.

Platform / infra: `tc-infrastructure`, `tc-cloud-containers`, `tc-cloud-defense`, `tc-firewall-review`, `tc-network-appliance-offensive`, `tc-mobile-security`, `tc-reverse-engineering`, `tc-blockchain-security`, `tc-cryptography`, `tc-dfir`, `tc-github-workflow`, `tc-hackthebox`, `tc-ai-threat-testing`, `tc-social-engineering`, `tc-system`, `tc-protect-with-password`, `tc-pci-secure-software`, `tc-skill-prune`, `tc-skill-update`, `tc-transilience-report-style`.

## How to use (lightweight, free-tier friendly)

- `/hackerone` equivalent: load `tc-hackerone` — scope parsing, parallel asset testing, PoC validation, submission-ready reports.
- One skill at a time, 1–2 vuln classes per session — do NOT fan out to all agents at once on a free tier.
- Skills live in `communitytools/skills/`; agents under `communitytools/projects/pentest/.claude/` in the source repo.

## Notes

- The repo's `scripts/kali-claude-setup.sh` builds a Kali Docker image — NOT run here (Docker not available on this VM, and the setup is heavy).
- Authorized targets only, in-scope assets only.
