---
name: hacking-skills
description: Modular hacking skills (web only) — web-hacking (OWASP Top 10 exploitation, payloads, WAF bypass), pentest-recon (OSINT, enumeration, attack-surface + CVE mapping), poc-development (isolated PoC scripts to prove repro). Use when the user says "hacking skills" or wants a small modular web-hacking skill set. Source repo (cloned, read-only reference): ~/bug-bounty-tools/cybersecurity-claude-skills/.
---

# Hacking Skills (web only)

Note: no GitHub repo literally named "hacking-skills" exists. This pack installs the modular web subset of `mahmutka/cybersecurity-claude-skills` (https://github.com/mahmutka/cybersecurity-claude-skills) — the closest maintained match: small standalone skill folders, take only what you need.

## Sub-skills (3, installed as separate skills `hs-*`)

- `hs-web-hacking` — full OWASP Top 10 (2025): broken access control (IDOR, CORS, path traversal), injection, WAF bypass, payload crafting. Best for pentest + bug bounty.
- `hs-pentest-recon` — OSINT, enumeration, attack-surface mapping, CVE mapping. Best for pentest + red team.
- `hs-poc-development` — isolated PoC scripts; run before/after a fix to prove repro and remediation. Best for AppSec + bug bounty.

The source repo also has `ctf-solver`, `secure-code-review`, `security-hardening`, `threat-modeling`, `vulnerability-triage` — NOT installed (user asked web only).

## Notes

- Skills are methodology + payload references, not executables. Pair with the installed CLI tools (nuclei, ffuf, dalfox, httpx, katana) for live testing.
- Authorized targets only, in-scope assets only.
