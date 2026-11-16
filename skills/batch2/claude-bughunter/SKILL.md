---
name: claude-bughunter
description: Claude-BugHunter (elementalsouls / Sachin Sharma) — 83 skills, 15 slash commands, 681 disclosed HackerOne report patterns across 24 vuln classes, plus enterprise identity + infrastructure attack matrices. Use when the user says "claude-bughunter", names a hunt-* skill, or wants pattern-backed web/API hunting. Source repo (cloned, read-only reference): ~/bug-bounty-tools/Claude-BugHunter/. The repo's installers target Claude Code paths — do NOT run them; skills were copied here manually.
---

# Claude-BugHunter

Upstream: https://github.com/elementalsouls/Claude-BugHunter (MIT). 83 skills · 15 commands · 681 disclosed-report patterns (433 individually cited) across 24 core vulnerability classes. Covers the external attack surface only — no internal AD / lateral-movement phases.

## Sub-skills (83, installed as separate skills `cbh-*`)

Hunt skills (per class): `cbh-hunt-xss`, `cbh-hunt-sqli`, `cbh-hunt-ssrf`, `cbh-hunt-idor`, `cbh-hunt-rce`, `cbh-hunt-ssti`, `cbh-hunt-xxe`, `cbh-hunt-auth-bypass`, `cbh-hunt-oauth`, `cbh-hunt-jwt-crypto`, `cbh-hunt-graphql`, `cbh-hunt-grpc`, `cbh-hunt-llm-ai`, `cbh-hunt-race-condition`, `cbh-hunt-file-upload`, `cbh-hunt-cors`, `cbh-hunt-csrf`, `cbh-hunt-lfi`, `cbh-hunt-deserialization`, `cbh-hunt-open-redirect`, `cbh-hunt-host-header`, `cbh-hunt-http-smuggling`, `cbh-hunt-websocket`, `cbh-hunt-dom`, `cbh-hunt-clickjacking`, `cbh-hunt-cache-poison`, `cbh-hunt-session`, `cbh-hunt-mfa-bypass`, `cbh-hunt-forgot-password`, `cbh-hunt-ato`, `cbh-hunt-business-logic`, `cbh-hunt-api-misconfig`, `cbh-hunt-shadow-api`, `cbh-hunt-subdomain`, `cbh-hunt-brute-force`, `cbh-hunt-captcha-bypass`, `cbh-hunt-ldap`, `cbh-hunt-nosqli`, `cbh-hunt-ntlm-info`, `cbh-hunt-saml`, `cbh-hunt-aspnet`, `cbh-hunt-laravel`, `cbh-hunt-nextjs`, `cbh-hunt-nodejs`, `cbh-hunt-springboot`, `cbh-hunt-fintech-graphql`, `cbh-hunt-html-injection`, `cbh-hunt-tls-network`, `cbh-hunt-k8s`, `cbh-hunt-cloud-misconfig`, `cbh-hunt-source-leak`, `cbh-hunt-spa-api`, `cbh-hunt-rag-vector`, `cbh-hunt-exceptional-conditions`, `cbh-hunt-cicd`, `cbh-hunt-misc`, `cbh-hunt-dispatch`, `cbh-hunt-sharepoint`.

Methodology + workflow: `cbh-bug-bounty`, `cbh-bb-methodology`, `cbh-bb-local-toolkit`, `cbh-web2-recon`, `cbh-recon-scope-triage`, `cbh-offensive-osint`, `cbh-osint-methodology`, `cbh-security-arsenal`, `cbh-triage-validation`, `cbh-report-writing`, `cbh-redteam-mindset`, `cbh-evidence-hygiene`, `cbh-mid-engagement-ir-detection`, `cbh-redteam-report-template`.

Web3 / other: `cbh-web3-audit`, `cbh-meme-coin-audit`, `cbh-bugcrowd-reporting`, `cbh-cloud-iam-deep`.

Enterprise matrices: `cbh-m365-entra-attack`, `cbh-okta-attack`, `cbh-enterprise-vpn-attack`, `cbh-vmware-vcenter-attack`, `cbh-apk-redteam-pipeline`, `cbh-ios-redteam-pipeline`, `cbh-supply-chain-attack-recon`.

## How to use

Skills trigger by topic — describe what is being tested and the matching skill loads. Each hunt skill carries per-class detection patterns, payloads, bypass tables and chain templates from disclosed reports.

## Notes

- Validation gates auto-trigger: reproduce before reporting, never submit theoretical findings.
- Optional: Burp Suite (Community works) for proxy logging; `cbh` CLI runner in the repo (`cbh/` + `engine/`, Python 3.9+) runs curl-only recon without Burp. Not installed as a command here — run from the repo checkout if needed.
- Authorized targets only, in-scope assets only.
