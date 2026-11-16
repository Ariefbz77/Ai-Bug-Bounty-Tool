---
name: hunter
description: Use for authorized web/API security assessment, CTF vulnerability research, Hunter health checks, MCP orchestration, local knowledge-base lookup, evidence registration, and report generation. All HTTP tools go through RequestBroker — WAF blocks, captchas, and rate limits never produce false findings.
---

# Hunter v8.3

> Multi-vertical SRC (edu/OA/ecom/finance/API/cloud/modern). exact_core=179 + re_*=105 → 284.
> Preflight: `python3 scripts/campaign_preflight.py`


Hunter is the authorized security-research framework exposed through one FastMCP server:

- Server name: `hunter_tools`
- Entrypoint: `mcp_server.py`
- Total tools: 231 (126 core + 105 extensions)
- Contract: `integration-contract.json`
- Persistent workspace: `OPEN_TGTYLAB_ROOT`

All HTTP tools (auto_sqli, auto_xss, auto_ssrf, etc.) go through **RequestBroker** — a unified policy layer with WAF detection, captcha handling, rate-limit awareness, baseline/probe/post-baseline control, and persistent cooling state.

## Operating Modes

| Mode | What it does | Evidence path |
|------|-------------|---------------|
| `discover` | Low-overhead audit and candidate discovery | No baseline, metadata-only |
| `probe` | Broker runs baseline/probe/post-baseline | Baseline comparison artifact |
| `verify` | Full experiment + EventKernel + Oracle | EventKernel canonical evidence |
| `race` | Broker pre-check + RaceCoordinator | Parallel gate with state oracle |

## Required Startup

1. Read `cases/<slug>/state.json` and continue from `next_steps`.
2. FULL CONTEXT RESET: CMS/framework = UNKNOWN until HTTP evidence.
3. State the concrete result sought in this session (verifiable, not "scan around").
4. `hunter_healthcheck` (+ `hunter_capabilities` if integration looks wrong).
5. `hunter_case_open` / `hunter_case_status`; `hunter_memory_query(target)`.
6. `hunter_fingerprint_detect` + surface_discover / fast_recon / tech_detect.
7. **HARD GATE (before any `hunter_auto_*` spray):**
   - Collect path/title/JS/header/footer signals.
   - `hunter_project_kb_search(query=signals, board="ctf-website"|"web"|"auto")` — CJK queries OK.
   - On vertical hit → `hunter_project_kb_read` full playbook → follow steps with Burp/stealth.
   - No vertical hit → only then `hunter_experiment_run` / targeted `hunter_auto_*`.
   - Before injection classes: `hunter_payload_get("waf-bypass")` char/keyword matrix ≥1 round.
   - Route table: `PLAYBOOKS.md` + `kb/ctf-website/techniques/kb-index.json` v1.1.
8. After auto_*: only `ALLOWED_APP` (or OAST nonce) may become findings; run oracle/FP protocol.
9. Verdict ladder: VERIFIED→confirmed; LIKELY marked; QUARANTINED→ledger.quarantined + verification_backlog (never promote); REFUTED→false_positives.
10. Time-based requires `[TIME_BASED] samples≥3`; SSRF fingerprint must be ∉baseline and ∉payload; size/status alone never confirms.
11. Dual ledger v1.1: confirmed / quarantined / false_positives / verification_backlog / blockers before `finding_promote`.
12. `hunter_recommend_next` / `hunter_workspace_recommend` when stuck.

**Anti-pattern:** jumping to `auto_sqli`/`auto_xss` before fingerprint + project_kb; promoting single-sample time-based or size-only SSRF.
**KB split:** `hunter_kb_*` searches `payloads/`; edu/CMS playbooks live under `hunter_project_kb_*`.


## Autonomy Doctrine (hard)

Operator does **not** want mid-engagement questions. Default behavior:

1. **Never ask** "下一步做什么 / 要不要继续 / 选哪个方向". Pick the highest-EV action and execute.
2. **Default mode = autopilot** for `hunter_auto_pentest` and workflow policy.
3. After every tool result: write ledger (confirmed / quarantined / false_positives) → choose next attack from `verification_backlog` or surface queue → execute.
4. Only stop for the **credential red line** (token/password/salt found → report, do not dump) or hard infrastructure failure (MCP down after doctor).
5. Dead-end rule still holds: try ≥2 different methods before rotating vector; rotating is automatic, not a question.
6. Report only `VERIFIED`. Quarantined stays in backlog and keeps driving probes.
7. When a stage returns `confirmation_required` under autopilot, treat it as auto-approved and continue.

One-line mission: **find more real vulns, fewer false positives, zero operator babysitting.**

## Zero Hallucination — Absolute Rules (v8.3, ported from Bingo v6.2.330)

These rules are injected into every tool-using agent session. Violations are blocked by
`ExecutionAnchorEngine` Layer 6 (`FabricatedProgressGuard`).

1. **NEVER claim "we already found/extracted/confirmed X"** unless a `TOOL_RESULT`
   in this conversation explicitly contains that data.
2. **NEVER fabricate** signing algorithms, encryption keys, API secrets, or
   technical details that were not returned in a tool result.
3. **If you cannot recall the specific TOOL_RESULT** that proves a claim,
   the claim is HALLUCINATED. Re-execute the tool to verify.
4. **Each discovery MUST cite its source:** which tool call returned it.
5. **"Based on conversation history" or "as we found earlier"** without
   a concrete tool output reference = HALLUCINATION.
6. **When a tool fails repeatedly (same error 2+ times), CHANGE STRATEGY.**
   Do NOT retry the same failing approach more than twice.

Supporting automation (keep current):
- `auto_*` → hard_gate + VerdictEngine + auto_result_writeback (ledger/memory/next_steps)
- `hunter_recommend_next` → playbook hits + verification_backlog (ask_operator=false)
- `python3 .../scripts/autonomy_maintain.py` → dump-index + seed_from_dump + proxy prune
- `rebuild_dump_index.py` / `seed_from_dump.py` / `proxy_health_prune.py`
- Stealth auto-loads `OPEN_TGTYLAB_ROOT/data/proxies.txt` (or `HUNTER_PROXY_FILE`)
- Default mode: **autopilot** (workflow create/policy/pentest/attack/kernel/policy model)


## Key Architecture

### RequestBroker — All HTTP Goes Through One Gate

- **`BrokerClient.request(RequestSpec)`** — Python tools (auto_sqli, auto_xss, etc.)
- **Local MITM Proxy** — External CLI tools (nuclei, sqlmap, ffuf) via `HTTP_PROXY` + Hunter CA
- **BrowserPool** — JS Challenge / Cloudflare clearance (optional, requires Playwright)

Each request is classified by 8 hard-coded Python rules:

```
ALLOWED_APP → real application response
WAF_BLOCK → WAF page / empty 200 / header fingerprint / identical body hash
CAPTCHA → captcha / JS challenge page
RATE_LIMITED → 429 with Retry-After
SOFT_BAN → status OK but structurally different from healthy baseline
LOGIN_REDIRECT → redirected to login page
```

Only `ALLOWED_APP` results may enter vulnerability evaluation. The other classifications never produce findings.

### WAF State Machine

```
HEALTHY → SUSPECTED_BLOCK → COOLING_DOWN → PROBING_RECOVERY
CAPTCHA_REQUIRED | LOGIN_REQUIRED | HARD_BLOCKED
```

- On block: 30s cooldown, exponential backoff to 600s max
- Recovery probe: clean GET to origin homepage with standard browser UA
- All proxies exhausted → HARD_BLOCKED, no more requests to this origin
- State persisted to SQLite with WAL mode, survives MCP restart

### Response Projection

Each response generates a structured `ResponseProjection` with HTTP metadata, HTML SimHash/DOM histogram, JSON schema/path analysis, and WAF keyword matching. Similarity is computed via fixed rules (model-independent):

- HTML: title 15% + DOM 25% + SimHash 30% + length 10% + headers 10% + paths/forms 10%
- JSON: business code 25% + key paths 35% + schema hash 25% + headers 15%

### Dual Verdict Paths

**Response-based** (IDOR, SQLi, XSS, upload, auth):

```
ALLOWED_APP baseline + ALLOWED_APP probe + ALLOWED_APP post-baseline
+ category Oracle + reproduction = VERIFIED
```

**OAST blind** (SSRF, blind XXE, blind SQLi, blind RCE, webhook):

```
Broker-sent request with unique nonce
+ matching DNS/HTTP/SMTP callback with same workflow/action/attempt nonce
+ negative control has no callback
= VERIFIED (does not require ALLOWED_APP response)
```

### RaceCoordinator

Race conditions do NOT go through serialized baseline/probe/post-baseline. Broker does a serial health pre-check, then `RaceCoordinator` requests a `RaceLease` that pauses per-request rate limiting for registered members. EventKernel creates one logical action + one attempt for the race group. Individual observations are collected per member, but a single evidence manifest is generated after the batch completes.

### IdentityPool

- Supports anonymous, cookie, Bearer, form login, token refresh, CSRF extraction, browser context
- `IdentityPool.switch(name)` — all following requests (Broker, CLI Proxy, BrowserPool) use that identity
- No credentials → anonymous discovery mode
- Missing identity conditions → returns `missing_inputs` instead of fabricated auth conclusions

### Event Kernel

Evidence path: Broker artifact → Experiment manifest → EventKernel `attest_evidence()` / `record_verdict()`.

- Canonical evidence ID: `workflow + generation + action + attempt + kind` (no artifact hash)
- Multiple retries within same attempt → single manifest
- Same binding can only produce one final attestation; new evidence requires new attempt
- EventKernel stores canonical ID, manifest/source digest, verification summary — never raw body

### Artifact Storage & GC

- Discover: projection + 1 KiB sample
- Probe: projection + 8 KiB sample
- Verify: full evidence, 256 KiB max per artifact
- Content-addressed compressed files with SQLite reference index
- Default quotas: 500 MiB global, 100 MiB per target
- GC tiers: unref 7d, inconclusive/refuted archive 7d → delete 30d, verified keep compressed 180d

## Safety Boundary

- Operate only on targets and artifacts within the user's authorized scope.
- Prefer targeted proof collection over broad or destructive execution.
- Do not report a vulnerability without reproducible evidence.
- High-impact exploitation and post-exploitation require an exact, action-bound approval descriptor.
- Treat memory and fingerprint recommendations as non-executing guidance.
- Redact secrets from logs, notes, screenshots, and persisted hook results.

## Tool Priority

- High-level task tools first: `hunter_surface_discover` → `hunter_experiment_run` → `hunter_identity_switch`
- HTTP execution: RequestBroker handles all HTTP; Burp bridge for manual/interactive inspection
- JavaScript source inspection: `hunter_js_extract_api`; do not download source merely to read it
- PE triage: `triage_pe`, then `ghidra_headless_analyze`
- Android dynamic work: `android_frida_run_script`
- Packer detection: `die_scan`
- Full suspicious-sample analysis: `sample_full_workup`

## Capability Groups

### Diagnostics and Routing

- `hunter_healthcheck`
- `hunter_capabilities`
- `hunter_recommend_next`
- `hunter_doctor`
- `hunter_config_audit`
- `hunter_runtime_status`
- `hunter_contract_check`
- `hunter_broker_state` — check origin WAF/cooldown/proxy state

### High-Level Task Tools (model-friendly)

- `hunter_surface_discover` — passive attack surface from Burp/JS/browser traffic
- `hunter_experiment_run` — executes baseline/probe/post-baseline with oracle
- `hunter_identity_switch` — switch authentication identity for subsequent requests
- `hunter_broker_benchmark` — local fixture performance baseline

### Recon and Scanning

- `hunter_scan`
- `hunter_recon`
- `hunter_vuln_scan`
- `hunter_subdomain`
- `hunter_port_scan`
- `hunter_tech_detect`
- `hunter_dir_enum`
- `hunter_js_analyze`
- `hunter_fast_scan`
- `hunter_scan_plan`
- `hunter_scan_benchmark`

### Targeted Proof Tools (all via RequestBroker)

- `hunter_auto_sqli` — SQLi detection
- `hunter_auto_xss` — XSS detection
- `hunter_auto_ssrf` — SSRF detection (OAST blind verification)
- `hunter_auto_ssti` — SSTI detection with engine identification
- `hunter_auto_cmd` — Command injection detection
- `hunter_auto_xxe` — XXE detection (OAST OOB verification)
- `hunter_auto_idor` — IDOR/BOLA with two-account differential
- `hunter_auto_csrf` — CSRF detection and exploit generation
- `hunter_auto_cors` — CORS misconfiguration detection
- `hunter_auto_jwt` — JWT vulnerability detection
- `hunter_auto_graphql` — GraphQL vulnerability scan
- `hunter_auto_websocket` — WebSocket vulnerability scan
- `hunter_auto_race` — Race condition via RaceCoordinator
- `hunter_auto_access_control` — Access-control detection
- `hunter_unified_scan` — Multi-phase unified scan

### Knowledge, Payloads, and Burp

- `hunter_kb_list`, `hunter_kb_search`, `hunter_kb_read`, `hunter_kb_recommend`
- `hunter_payload_list`, `hunter_payload_search`, `hunter_payload_get`, `hunter_payload_generate`
- `hunter_burp_bridge`, `hunter_burp_repeater`, `hunter_burp_proxy_search`, `hunter_burp_scanner_issues`, `hunter_burp_collaborator_workflow`, `hunter_burp_import`

### Workspace and Evidence

- `hunter_workspace_health`
- `hunter_case_open`, `hunter_case_status`, `hunter_case_update`, `hunter_case_next_steps`
- `hunter_project_kb_search`, `hunter_project_kb_read`
- `hunter_evidence_save`, `hunter_note_write`, `hunter_report_publish`
- `hunter_workspace_recommend`

### Workflow Kernel

- `hunter_workflow_create`, `hunter_workflow_open`, `hunter_workflow_status`
- `hunter_workflow_route`, `hunter_workflow_plan`, `hunter_workflow_run`
- `hunter_workflow_transition`, `hunter_workflow_checkpoint`, `hunter_workflow_resume`, `hunter_workflow_policy`
- `hunter_hypothesis_add`, `hunter_evidence_register`, `hunter_finding_promote`
- `hunter_backend_status`, `hunter_lane_catalog`

### Stateful HTTP and Attack Sessions

- `hunter_stealth_request`, `hunter_stealth_scan`
- `hunter_session_create`, `hunter_session_state`, `hunter_set_proxy_pool`
- `hunter_session_start`, `hunter_session_execute_chain`, `hunter_session_checkpoint`
- `hunter_post_exploit`

### Browser Bridge

- `hunter_browser_navigate`, `hunter_browser_interact`, `hunter_browser_capture_network`
- `hunter_browser_inject_hooks`, `hunter_browser_get_hook_results`, `hunter_browser_snapshot`

### JavaScript Analysis

- `hunter_js_unpack`, `hunter_js_deobfuscate`, `hunter_js_extract_api`
- `hunter_js_extract_signature`, `hunter_js_full_analysis`

### Reverse Analysis

- `hunter_reverse_binary`, `hunter_reverse_step`, `hunter_reverse_extract_iocs`
- `hunter_reverse_generate_rules`, `hunter_reverse_decrypt_plan`

### Local Memory

- `hunter_memory_query`, `hunter_memory_record`, `hunter_memory_recommend`
- `hunter_fingerprint_detect`, `hunter_memory_stats`

### Unified Orchestration

- `hunter_auto_pentest`

## Evidence Workflow

Use this sequence for authorized assessments:

```text
case state
→ surface_discover (passive attack surface)
→ identity_switch (if credentials available)
→ experiment_run (baseline/probe/verify)
→ event_kernel evidence attestation
→ finding promotion
→ checkpoint
→ note/report publication
→ case state update
```

Store project artifacts under:
- `D:\Open-tgtylab\exports\notes`
- `D:\Open-tgtylab\exports\reports`
- `D:\Open-tgtylab\exports\evidence`

Hunter-owned runtime evidence remains under the Hunter repository's `evidence/` and `sessions/` directories.

## Session Handoff (P0) — 2026-07-20

Login walls use **manual/browser session import**, not empty `identity_switch`.

Tools: `hunter_identity_import` / `list` / `switch` / `export` / `hunter_browser_export_session`.

```text
You login (real browser) → cookie/JWT paste
→ hunter_identity_import(name, cookie_header=..., bearer_token=..., target=..., switch=true)
→ hunter_identity_list
→ experiment_run / auto_* with that identity
```

Or: `hunter_browser_navigate(execute=true)` → `hunter_browser_export_session(identity="operator")`.

Shared process IdentityPool; RequestBroker defaults to it. Profiles: `sessions/auth_profiles.json` (or `HUNTER_AUTH_PROFILES`).
Core tools: 141. Contract note: core_bump_2026_07_20.


## Scope + Blind Dump (Ghost runtime · 2026-07-20)

Bingo-inspired, **Hunter-owned**. Do not patch bingo package.

### Same-apex scope (subdomain pivot)
1. `hunter_scope_set(target="https://www.example.edu.cn", case_slug="...")`
2. `hunter_subdomain` — auto-expands same-apex hosts into scope
3. `hunter_scope_status` / `hunter_scope_check(url=...)`
4. Attack `mail/oa/jwxt/...` **without** re-binding target
5. Cross-org host → out of scope (intentional)

### Boolean oracle dump with checkpoint
After boolean blind is confirmed:
```
hunter_bool_oracle_extract(
  target="https://.../item?id=1",
  param="id",
  extract_expr="database()",
  case_slug="a-loan-info",
  resume=true,
)
```
- Progress → `cases/<slug>/sqli_checkpoints/*.json`
- Resume after process death; do not restart from char 1
- `extract_expr` examples: `database()`, `user()`, `(SELECT table_name FROM information_schema.tables LIMIT 0,1)`

### Coverage flags (dual_ledger)
- `coverage.subdomain_enum` / `coverage.subdomain_pivot` / `coverage.bool_oracle_checkpoint`


## Visual Browser (Real Windows Chrome)

主浏览器 = **本机 Google Chrome**（CDP `127.0.0.1:9222`），不是 headless / 假壳 / Burp 内嵌。

| 工具 | 作用 |
|------|------|
| `hunter_browser_ensure(url?)` | 确保真 Chrome 已开（挂 Burp 8080 + hunter profile） |
| `hunter_browser_status` | CDP 是否活着、当前 url/title |
| `hunter_browser_navigate(execute=true)` | 在真 Chrome 里打开 |
| `hunter_browser_snapshot(execute=true)` | 看页面 |
| `hunter_browser_export_session` | cookie/HttpOnly → IdentityPool |

启动：全自动。渗透开局由 Ghost 调 `hunter_browser_ensure` / `ensure_chrome`，内部跑
`C:\Users\USERNAME\.hunter\bin\start-hunter-chrome.ps1`。**你不用手动开浏览器。**

纪律：
1. 渗透开局自动 ensure 真 Chrome（失败再报 missing_inputs）
2. 登录/验证码：停，等你说「过了/继续」→ `export_session`
3. 批量扫/盲注：**不要**循环浏览器，走 Broker/Burp
4. 你插话优先级最高（「先看支付」「别扫了」）
5. 禁止把 Playwright headless 当主可视化（仅 `HUNTER_BROWSER_ALLOW_HEADLESS=1` 才允许兜底）


## Engagement Open（开案一条龙）

一条命令开战场，不靠你记步骤：

```
hunter_engagement_open(target="https://www.xxx.edu.cn", case_slug="optional")
```

自动：
1. apex `scope_set`（同注册域子域 in-scope）
2. 真 Chrome CDP ensure + 导航目标
3. 子域枚举 + scope expand
4. 探活排序 → `cases/<slug>/engagement/live_hosts.json`
5. dual_ledger coverage：`subdomain_enum` / `subdomain_pivot`
6. 返回 `next_actions`（pivot 主机 / 登录提示 / API 扫）

你只需要：
- 正常说目标开打
- 人机/登录时点一下，回「过了」
- 有想法回「先看支付/OA」

不要：
- 手动开 bat
- 用浏览器循环枚举/盲注


## HITL 人机卡点（needs_operator）

页面像验证码/登录墙，或 Broker 分类 `CAPTCHA` / `LOGIN_REDIRECT` → 自动停：

| 工具 | 作用 |
|------|------|
| `hunter_hitl_detect(...)` | 嗅探墙；默认 auto_raise |
| `hunter_hitl_status(case_slug)` | 是否 pause |
| `hunter_hitl_raise(case_slug, reason)` | 手动停 |
| `hunter_hitl_clear(case_slug, note="过了")` | 你回「过了」后调；建议 export_session |

状态落盘：`cases/<slug>/hitl/state.json`  
`needs_operator=true` 时：**禁止继续 auto_*/spray**，等操作员。

## Critical 收口四件套（硬门）

Critical/High 确认后强制：

1. **impact** — 影响数据/blast radius  
2. **privilege_chain** — 权限链  
3. **evidence_dir** — `cases/<slug>/evidence/<id>/` 有 req/截图  
4. **src_draft** — SRC/报告草稿  

| 工具 | 作用 |
|------|------|
| `hunter_closeout_open(case_slug, title, severity)` | 开收口 |
| `hunter_closeout_update(case_slug, finding_id, piece, content/path)` | 填一件 |
| `hunter_closeout_status(case_slug?)` | 查缺口（空=扫全库） |
| `hunter_closeout_gate(new_case_slug)` | 切目标前硬检 |

未齐 → `hunter_engagement_open` 换目标返回 `status=blocked`（`force=true` 可强切）。  
纪律：**洞确认当天收口，未齐禁止切目标。**


## JS 表面增强（DesJsFinder 思路，Hunter 自有）

国产框架字典 + 路径风险分级 + 响应体指纹 + baseURL 提取。

| 工具 | 作用 |
|------|------|
| `hunter_js_extract_api` | 现在附带 `framework` / `path_risk` |
| `hunter_js_framework_dict(text\|framework=yudao)` | 框架字典路径 |
| `hunter_js_path_risk(paths)` | CRITICAL/HIGH 排序 |
| `hunter_response_fingerprint(body,status)` | 候选指纹（**永不直接 VERIFIED**） |

`hunter_dir_enum` wordlist 别名：
`yudao` / `ruoyi` / `spring` / `framework` / `api` / `generic-api`

字典目录：`wordlists/framework/*.txt`

纪律：
1. 响应指纹 = 候选，走 experiment/oracle 再升
2. 框架字典 Fuzz 走 Broker，不在浏览器裸喷
3. 浏览器运行时抓 API：`hooks/runtime_api_capture.js`（CDP inject）

## Acunetix / AWVS Bridge (2026-07-22)

Scanner is **lead generator only**. Never promote Acu findings without Broker/Burp verification.

| Tool | Purpose |
|------|---------|
| `hunter_acunetix_status` | API health + running scans |
| `hunter_acunetix_targets` / `scans` | Inventory |
| `hunter_acunetix_add_target` / `start_scan` | Kick Full Scan (`profile=full\|high\|sqli\|xss\|...`) |
| `hunter_acunetix_findings` | Export findings (noise filter optional) |
| `hunter_acunetix_import` | → `cases/<slug>/dual_ledger.json` as **QUARANTINED** + verification_backlog |

Config: `/root/.config/acunetix/config.json` (password = SHA-256 hex; Cookie+X-Auth session).  
Standalone CLI: `python3 /root/tools/acunetix/client.py ...`  
Logs: `/mnt/d/AWVS/logs/backend.log`, events `/mnt/d/AWVS/shared/temp/*/events.json`, reports `/mnt/d/AWVS/shared/reports/`.

### Standard dual-scanner battle rhythm

```
1. hunter_engagement_open / subdomain → deliver main+subs to operator (or auto)
2. hunter_acunetix_add_target(url, start_scan=true, profile="full")  # breadth
3. Wait / hunter_acunetix_scans until completed
4. hunter_acunetix_import(case_slug, target, min_sev=2, drop_noise=true)
5. Walk verification_backlog → Burp/Broker replay → auto_* only on typed leads
6. VERIFIED → finding_promote + evidence; REFUTED stays FP
```

Burp stays the depth plane (auth, business logic, manual chains). Acunetix stays the breadth plane.


## AutoHunter ports (2026-07-23)

| Tool | Use |
|------|-----|
| `hunter_edu_lookup` | EduSRC 报告归属：IP/host → 高校（离线 edu_ip.db） |
| `hunter_finding_dedup` | promote 前软查重（参数名指纹） |
| `hunter_half_baked_check` | 半成品闸：data:0 / 公开接口 / 死规矩信息泄露 |
| `hunter_deepen` | 第三裁决：线索真未打穿 → backlog（cap=2） |

`add_confirmed` / `promote_finding` 已默认过 half_baked 闸。Bingo ports 后 exact_core **179**。

## CVE 专用扫描器 (v8.4 / 2026-08-01)

12 个 bingo CVE/技术专用链移植，Broker-gated、证据优先、安全探测器（不做真实 RCE gadget 落地）：

| 工具 | 目标 | 验证方式 |
|------|------|---------|
| `hunter_cve_panos` | CVE-2025-0108 PAN-OS 认证绕过 | 双编码路径穿越 → PHP 免认证执行 |
| `hunter_cve_ingress` | CVE-2025-1974 K8s IngressNightmare | admission controller 暴露 + 注入面映射 |
| `hunter_cve_druid` | CVE-2025-27888 Druid SSRF | proxy 端点 → 云 metadata/内网 |
| `hunter_cve_ivanti` | CVE-2026-10520 Ivanti Sentry RCE | handleMessage commandexec（只读命令） |
| `hunter_cve_mssql2025` | SQL2025 AI 功能利用 | sp_invoke_external_rest_endpoint 检测 |
| `hunter_cve_redis_repl` | CVE-2026-23631 Redis UAF | 版本 + 权限检测（不触发 UAF） |
| `hunter_cve_nextjs_sxss` | Next.js 0-click 缓存投毒 SXSS | header 反射 + 可缓存性 |
| `hunter_cve_cswsh` | CSWSH + EXE 暴露 → 0-click RCE | EXE 暴露 + WS 握手验证 |
| `hunter_cve_cf_acme` | Cloudflare ACME 验证绕过 | HTTP-01 验证逻辑差分 |
| `hunter_cve_aruba_xxe` | ArubaOS 预认证 XXE→OOB SSRF | OOB 回调确认（VERIFIED）否则 LIKELY |
| `hunter_cve_dompurify` | CVE-2026-41238 DOMPurify PP 绕过 | payload 注入 → 反射验证 |
| `hunter_cve_copyfail` | CVE-2026-31431 Linux LPE | authencesn 配置可写性（本地/远程模式） |

硬规则不变：WAF/captcha/rate-limit ≠ 漏洞；只 VERIFIED 可报告；凭据红线。CVE 工具走 `_safe_auto_json_tool`（HITL + auto_gate + dual_ledger 全挂），自产 verdict 不经 VerdictEngine（无对应 `_assess_cve` handler）。

## Bingo method ports (v8.3.1 / 2026-07-27)

New MCP tools (broker-gated, evidence-first):

| Tool | Purpose |
|------|---------|
| `hunter_auto_oauth` | OAuth/OIDC chain A/B scoring (open reg / unauth authorize / CORS* / email trust) |
| `hunter_auto_upload` | Upload polyglot/MIME/ext matrix + canary confirmation |
| `hunter_auto_smuggling` | CL.TE / TE.CL / TE.TE desync scan |
| `hunter_auto_modern` | Next.js cache reflection + React2Shell **safe** grammar differentials |
| `hunter_target_context_reset` | FULL CONTEXT RESET (CMS/framework=UNKNOWN) |
| `hunter_target_context_register` | Register HTTP-proven stack facts only |
| `hunter_target_context_snapshot` | Read current target context |

Hard rules still apply: WAF/captcha/rate-limit ≠ vuln; only VERIFIED reportable; credentials red-line.


## Bingo v7.0.66 deep-import (2026-08-02)

Full-source study of local bingo (123k lines) — 37 modules → 6 KB docs + payload upgrades + 9 new MCP tools:

| New Tool | Source | Capability |
|----------|--------|------------|
| `hunter_bingo_waf_bypass` | waf_bypass.py | WAF detect → per-vendor priority strategy → 9-class bypass → combined fallback |
| `hunter_bingo_waf_detect` | waf_bypass.py | 20+ vendor signatures (incl. Korean Wapples/KISA, CN 360/safedog/D盾/云锁) |
| `hunter_bingo_waf_sqli_db` | waf_sqli_payloads.py | Blocked SQL fn → alternatives (SUBSTR/ASCII/SLEEP/AND/OR + RIGHT-only strategy) |
| `hunter_bingo_korean_cms` | korean_cms.py | 6-CMS fingerprint + admin/SQLi/LFI/IDOR/OTP-leak/bo_table scan |
| `hunter_bingo_gnuboard_attack` | gnuboard.py | Full chain: login (g5_is_admin cookie) → CSRF dual-token → GIF polyglot → AntSword |
| `hunter_bingo_subdomain_takeover` | subdomain_takeover.py | 24 service sigs (Naver/Cafe24) + 84 subdomains + takeover instructions |
| `hunter_bingo_wcd` | web_cache_deception.py | 3-condition WCD (cacheable+sensitive+confirmed) + SameSite Lax meta-refresh |
| `hunter_bingo_db_dump` | db_dumper.py | 5-dialect SQL plans + GROUP_CONCAT paged UNION + table priority |
| `hunter_bingo_bizlogic` | bizlogic_fuzzer.py | Negative amounts / qty manipulation / coupon abuse / workflow skip |

KB docs: `kb/ctf-website/techniques/bingo-import/01..06` (WAF master / Korean CMS / upload-auth-2FA / cache-xss-smuggling / sqli-db-api / apt-anti-hallucination). Payload upgrades: waf-bypass +180 lines, xss +130, dom-xss +70, cache-poisoning +55, smuggling +45.

Key lesson absorbed: bingo's "confirmable-only" philosophy (two-stage cache verification, timeout/exception-based smuggling, 3-condition WCD) is isomorphic with Hunter's RequestBroker/EventKernel — payloads grafted directly.

## Fingerprint Browser Engine (2026-08-02)

替代脏代理池的指纹浏览器方案 — 9 工具:

| Tool | Function |
|------|----------|
| `hunter_fingerprint_create` | 新指纹浏览器 (随机 UA/时区/语言/viewport/region 映射) |
| `hunter_fingerprint_open` | 打开 (独立 Chrome profile + 反检测注入 + 可选代理) |
| `hunter_fingerprint_execute` | 打开 URL + 执行 JS (返回 title/webdriver 验证) |
| `hunter_fingerprint_fetch` | 用指纹浏览器请求 URL |
| `hunter_fingerprint_close` | 关闭 (保留 profile) |
| `hunter_fingerprint_delete` | 销毁 (含数据目录) — 轮换用 |
| `hunter_fingerprint_list` | 列出所有 profile |
| `hunter_fingerprint_switch` | 被封 → 销毁旧 → 建新 → 打开 (一键轮换) |
| `hunter_fingerprint_health` | 引擎健康 (playwright/profiles) |

用法 (崩了一个换一个):
```
hunter_fingerprint_create(region="kr") → profile_id
hunter_fingerprint_open(profile_id) → 独立指纹浏览器
hunter_fingerprint_execute(profile_id, url, js) → 操作
→ 被封 → hunter_fingerprint_switch(profile_id, blocked=true) → 新指纹
```

vs 代理池分工:
- 指纹浏览器: 登录/验证码/身份敏感/需要完整指纹 → 精细操作
- 代理池 (Broker): SQLi/路径枚举/批量请求 → 量大不怕脏
- 启动: playwright async API (MCP 是 asyncio, 不能用 sync)

### Fingerprint auto-rotate (v2)

`hunter_fingerprint_auto` — 一键自动轮换: 建新指纹 → 打开 → 验证目标可达 → 不可达自动销毁重试 (max 3)。
broker 报 ip_blocked / WAF_BLOCK / CAPTCHA 后的升级路径:

```
hunter_broker_state(target) → ip_blocked
  → hunter_fingerprint_auto(target, region="kr") → active_profile
  → hunter_fingerprint_execute(active_profile, url, js) 继续打
```

三级防线 (broker 已内建, 从轻到重):
1. runtime fingerprint 轮换 (JA3/UA — 403 自动, broker 内建)
2. 代理池轮换 (proxy_rotator 三振出局 — 批量扫描)
3. fingerprint browser (Playwright 独立 profile — 精细操作/登录/验证码)
