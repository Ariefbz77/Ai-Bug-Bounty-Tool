---
name: bounty-grimoire
description: BountyGrimoire (N1neKitsune) — 17 parallel find-* specialist skills for web bug bounty, one per vuln class, plus a skeptical Validator agent. Use when the user says "bounty grimoire", names a find-* skill, or wants parallel per-class hunting with independent validation. Source repo (cloned, read-only reference): ~/bug-bounty-tools/BountyGrimoire/. The repo's install.sh requires Claude Code CLI — do NOT run it; skills were copied here manually.
---

# BountyGrimoire

Upstream: https://github.com/N1neKitsune/BountyGrimoire (MIT). 18 parallel agents, one per vuln class, built on curl + reasoning — no heavy tool dependencies. A dedicated Validator agent independently reproduces every finding before it counts.

## Sub-skills (17, installed as separate skills `bg-find-*`)

- `bg-find-xss`, `bg-find-sqli`, `bg-find-ssrf`, `bg-find-idor`, `bg-find-rce`, `bg-find-ssti`, `bg-find-xxe`, `bg-find-auth`, `bg-find-bizlogic`, `bg-find-callback`, `bg-find-checksum`, `bg-find-enumerable`, `bg-find-insecure`, `bg-find-otp`, `bg-find-pii`, `bg-find-referer`, `bg-find-secrets`

Each skill holds detection patterns extracted from real paid bounty reports for its class.

## Workflow

1. Load scope first (program rules + in-scope assets only).
2. Run the relevant `bg-find-*` skill(s) — one class at a time, or several in parallel.
3. Validator re-checks every candidate finding independently (reproduce with curl, confirm impact).
4. Only validated findings go to a report. Theoretical / unreproduced = dropped.

## Notes

- `generate-skill.py` in the source repo streams the latest resolved HackerOne reports and extracts new attack patterns into skills — rerun it manually if the bundle needs refreshing.
- Authorized targets only, in-scope assets only.
