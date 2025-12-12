# v1 Lessons Learned — What to keep vs what to avoid

**Status:** Draft  
**Last updated:** YYYY-MM-DD  
**Purpose:** capture the most important v1 learnings to accelerate v2 and avoid repeating mistakes.

---

## 1) What worked really well (keep these patterns)

### 1.1 Defense in depth (the big win)
- **SQL RLS as the hard stop**: setting tenant context per request and relying on RLS prevented cross-tenant leakage even if routes were tampered with.
- **Storage scope verification**: enforcing required blob metadata (`tenant_id`/etc.) and returning **403 on mismatch** was an excellent second hard stop for file access.
- **Deterministic blob paths**: helped debugging and prevented “mystery files”.

### 1.2 Sharding / routing approach
- The **Directory DB → Shard DB** routing pattern is clean and scales.
- Encapsulating “with shard” logic in a service reduced accidental mistakes (e.g., forgetting to set context).

### 1.3 Small, testable endpoints
- Early MVP endpoints (`upload/get/list/health`) + E2E smoke tests gave fast feedback and caught regressions.

---

## 2) Pain points and mistakes (avoid in v2)

### 2.1 Naming drift (routes, env vars, IDs)
- Renames across days caused breakage (e.g., SPA env var key changes like `VITE_SCOPE` → `VITE_API_SCOPE`).
- Ambiguous naming (`tenant_id`) mixed Entra tenant vs business tenant semantics.

**v2 fix**
- Freeze naming in `docs/contracts/naming.md` + record renames in `docs/BREAKING_CHANGES.md`.

### 2.2 Data model drift (scripts vs code)
- Mismatch between schema and code usage (e.g., table A created but code reads table B / legacy index).
- RLS applied to one table while the API reads another table → false sense of safety.

**v2 fix**
- One source of truth for migrations (DbUp/Flyway) + sanity checks.
- Apply RLS to **all** tenant tables and validate with automated tests.

### 2.3 Auth policy confusion (audience / token version / validation)
- Audience mismatches and token version issues caused intermittent 401/403.
- Gateway-level “tenant filtering” worked in pilot but can become unmanageable at scale (role sprawl).

**v2 fix**
- Use Option B: APIM coarse + WebApp fine-grained + RLS.
- Freeze auth contract in `docs/contracts/auth.md`.

### 2.4 “ClickOps” drift
- Manual portal configuration makes reproduction hard and introduces subtle inconsistencies.

**v2 fix**
- Terraform first + CI/CD for infra and app deployments.

### 2.5 Secrets and sensitive artifacts in repo/zip
- Keeping files like `.PublishSettings` or `*.kdbx` around increases risk.

**v2 fix**
- Strong `.gitignore` + “no secrets in repo” rule + documented secret handling.

---

## 3) v1 decisions worth reusing in v2

- **RLS-first mindset**: DB remains the final authority for isolation.
- **Metadata-hardening for blobs**: metadata scope keys required on every blob.
- **Route space planning**: reserving future route paths to avoid collisions.
- **Evidence-driven dev logs**: include “validation/evidence” sections for each milestone.

---

## 4) v2 changes inspired by v1

- Introduce contracts (`naming/api/storage/auth`) to prevent drift.
- Add DbUp migrations + schema version tracking.
- Adopt a two-plane architecture (SQL = write truth; Fabric = read analytics).
- Add a short “Top exceptions” list and expand iteratively.
- Establish Terraform modules and a consistent Azure resource naming convention.

---

## 5) Quick checklist before declaring “preprod pilot”

- [ ] Contracts are present and respected (naming/api/storage/auth)
- [ ] Schema migrations reproducible (DbUp) + sanity checks pass
- [ ] WebApp membership checks tested (403 on cabinet/company mismatch)
- [ ] SQL RLS verified on all tenant tables (no cross-tenant reads)
- [ ] Storage metadata scope check verified (403 on mismatch)
- [ ] APIM enforces scopes/roles + rate limits + logs
- [ ] Fabric read plane has workspace permissions + RLS on semantic model
