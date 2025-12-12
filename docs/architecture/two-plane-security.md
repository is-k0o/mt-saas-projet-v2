# Two‑Plane Security — Write Plane (API) + Read Plane (Fabric)

**Status:** Draft  
**Last updated:** YYYY‑MM‑DD  
**Scope:** ComptaPlus / mt‑saas v2 (Pilot: 3–10 cabinets)  
**Goal:** Clearly separate security responsibilities between the transactional **Write Plane** and the analytical **Read Plane**.

---

## 1) Context

The platform is designed as a **two‑entry architecture**:

- **Write Plane (Transactional):** SPA → Front Door → APIM → WebApp → Azure SQL (Core + Directory) + Storage (PDF/XML)
- **Read Plane (Analytical):** Fabric (Lakehouse / Semantic Model / Reports) ← (incremental export from SQL/Storage)

Because the Read Plane is not served through APIM, **APIM cannot be the single “tenant filter”** for the whole system.
Tenant isolation must be enforced at each plane with the correct mechanisms.

---

## 2) Security Principles

1. **Defense in depth:** multiple independent controls prevent cross‑tenant leakage.
2. **Do not trust client input:** URL path parameters (`cabinet_slug`, `company_slug`) are not proof of authorization.
3. **Separation of concerns:** APIM enforces coarse controls; fine‑grained authorization is owned by the WebApp + DB.
4. **Stable identifiers:** use `cabinet_id`/`company_id` internally; slugs are for UX/routing only.
5. **Least privilege everywhere:** Managed Identity to access SQL/Storage; minimal SQL permissions; minimal Fabric access.

---

## 3) Write Plane — Responsibilities & Controls

### 3.1 Components
- **SPA:** obtains Entra token (PKCE) and calls the API.
- **Front Door / WAF:** edge protections and routing.
- **APIM:** token validation, coarse authorization, throttling, logging.
- **WebApp:** tenant/company authorization, shard routing, business logic.
- **Azure SQL:** Row‑Level Security (RLS) + data constraints.
- **Storage:** private container, metadata scope checks, MI access.

### 3.2 Primary controls (Option B)
**Control A — APIM (Coarse‑grained)**
- Validate token: issuer, signature, expiration, audience.
- Enforce scopes per operation (read vs write vs resolve exceptions).
- Apply rate limits, size limits, content‑type checks.
- Add/propagate correlation ID and emit logs.

**Control B — WebApp (Fine‑grained)**
For every tenant‑scoped request:
1) Extract `{cabinet_slug}` and `{company_slug}` from the route.  
2) Resolve slugs → `cabinet_id/company_id` via **Directory DB**.  
3) Check membership: `dir.user_company_access` contains `(user_oid, cabinet_id, company_id)`; else **403**.  
4) Resolve shard for `(cabinet_id, company_id)`.  
5) Call `sec.usp_set_tenant_context(cabinet_id, company_id, user_oid)`.  
6) Execute queries normally; **RLS** filters data.

**Control C — SQL RLS (Hard stop)**
- RLS predicate filters all tenant tables using `SESSION_CONTEXT('cabinet_id')` and `SESSION_CONTEXT('company_id')`.
- Apply RLS to **all tenant tables** (documents, lines, postings, exceptions, files, rules, audit).

**Control D — Storage metadata scope (Hard stop for files)**
- All blobs include metadata keys: `cabinet_id`, `company_id`, `document_id`, `kind`, `sha256`.
- On download/stream, WebApp refuses (403) if blob metadata scope != request scope.

### 3.3 What APIM should *not* do (in Option B)
- Do **not** attempt to check cabinet/company membership (dynamic, data‑driven) inside APIM.
- Do **not** rely on the `groups` claim (can overflow); prefer scopes and global roles.

---

## 4) Read Plane — Responsibilities & Controls (Fabric)

### 4.1 What the Read Plane is for
- Analytics and reporting (TVA, bilan “bilan → bilan”, trend analysis).
- “Explain the gap” logic (variance explanations).
- Not for transactional CRUD screens (documents/exceptions should stay on SQL).

### 4.2 Data movement model (pilot)
- Incremental export from Azure SQL → Fabric Lakehouse (upsert on stable keys).
- Optional: store derived/curated tables in Fabric for report performance.

**Key invariant:** `cabinet_id` and `company_id` must be present in the analytical tables to enforce isolation.

### 4.3 Read Plane controls (no APIM)
**Control E — Fabric Workspace Access**
- Only authorized users/groups can access the workspace/items.

**Control F — RLS at the Semantic Model / BI layer**
- Apply RLS filters on `cabinet_id/company_id` for report consumers.
- Keep admin/engineer roles separate from business viewers.

**Control G — Network / Private Access (when you harden)**
- Use Fabric Private Link / Managed Private Endpoints where relevant.
- Ensure data sources (SQL/Storage) can be reached privately if required.

---

## 5) Contracts that must exist (source of truth)
- `docs/contracts/naming.md` (IDs vs slugs; reserved words; mapping)
- `docs/contracts/api.md` (routes, pagination, error model)
- `docs/contracts/storage.md` (blob path + metadata + sha256)
- `docs/contracts/auth.md` (Option B: APIM coarse + WebApp fine + RLS)

---

## 6) Threat model (quick)
- **URL tampering:** user changes `/t/cabA/...` → `/t/cabB/...`  
  - Expected result: **403** at WebApp, and **0 data** at SQL due to RLS.
- **Blob path guessing:** user guesses a blob path  
  - Expected result: cannot access container directly; API returns **403** due to metadata scope check.
- **Over‑permissive SQL identity:** MI has too many rights  
  - Mitigation: least privilege + prefer stored procedures for sensitive operations.
- **Analytics leakage:** user has Fabric report access but sees other cabinets  
  - Mitigation: workspace perms + RLS on semantic model + test suite.

---

## 7) Minimal test suite (must pass before preprod)
### Write Plane
1) Valid token + no membership → **403**
2) Member of cabinet A / company X:
   - `/t/A/companies/X/...` → **200**
   - `/t/B/companies/Y/...` → **403**
3) RLS test: bypass WebApp check (test-only) → SQL returns **0 rows** for other tenants
4) Blob metadata mismatch → **403**
5) Scope enforcement:
   - read scope cannot call write endpoint → **403/401** depending on policy

### Read Plane (Fabric)
1) Viewer of cabinet A cannot see cabinet B in reports (RLS)
2) Workspace permissions prevent unauthorized access to Lakehouse/semantic model
3) Data freshness check: last refresh timestamp is visible and within expected window

---

## 8) Operational notes
- Prefer short refresh cycles for pilot only if needed; otherwise start with 15–60 min.
- Keep a clear UI separation:
  - **Operational UI:** documents/exceptions from SQL
  - **Analytics UI:** VAT/bilan/explanations from Fabric
- Log correlation IDs end-to-end (Front Door → APIM → WebApp → SQL queries/jobs).

---

## 9) Future extensions (optional)
- Introduce a “tenant session token” (issued by WebApp) only if you need extra friction against URL tampering.
- Add CDC instead of incremental export if refresh latency becomes a product requirement.
- Add automated sync from Entra groups to Directory DB (Graph job) if membership management needs automation.

---

## TL;DR
- **APIM protects the API entry** (coarse).  
- **WebApp + Directory DB decide tenant/company access** (fine).  
- **SQL RLS + Storage metadata are the hard safety net**.  
- **Fabric must enforce its own isolation** (workspace + semantic model RLS), because it is a separate entry.
