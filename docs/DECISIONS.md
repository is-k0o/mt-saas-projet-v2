# DECISIONS — mt-saas v2

> Lightweight decision log (ADR-style but simple).  
> Each entry should explain *why* the decision was taken.

---

## D001 — Mono-repo structure
**Date:** 2025-12-12  
**Status:** Accepted  
**Decision:** Use a single repository containing docs + infra + DB migrations + API + SPA.  
**Why:** Avoid drift; one commit can include infra + schema + code + docs.  
**Consequences:** Need clean folder structure (`docs/`, `infra/`, `db/`, `src/`, `.github/`).

---

## D002 — Two-plane data architecture
**Date:** 2025-12-12  
**Status:** Accepted  
**Decision:** Two planes:
- Write plane = Azure SQL (core + directory) + Storage
- Read plane = Fabric Lakehouse (analytics/reporting)  
**Why:** SQL is transactional source of truth; Fabric is for analytics without slowing the app.  
**Consequences:** APIM can’t “filter” Fabric side → isolation must be enforced in SQL/WebApp and in Fabric access model.

---

## D003 — Tenancy model and URLs
**Date:** 2025-12-12  
**Status:** Accepted  
**Decision:** Routing: `/t/{cabinet_slug}/companies/{company_slug}/...`  
DB: `cabinet_id` + `company_id` everywhere.  
**Why:** Scales better than “one Entra role per tenant slug” as tenant count grows.  
**Consequences:** Directory DB must map users → cabinets/companies; WebApp must enforce membership.

---

## D004 — Security model (Option B)
**Date:** 2025-12-12  
**Status:** Accepted  
**Decision:** APIM is coarse-grained (token validation + app roles), fine-grained access is enforced by:
- WebApp membership check (Directory DB)  
- SQL RLS (hard stop)  
- Storage metadata scope checks (hard stop)  
**Why:** URL can be tampered; APIM alone shouldn’t be the only guard.  
**Consequences:** RLS + membership must be correct; require deterministic storage metadata.

---

## D005 — Auth approach in Entra (App Roles via Groups)
**Date:** 2025-12-12  
**Status:** Accepted  
**Decision:** Use App Roles assigned to groups (avoid relying on `groups` claim directly).  
**Why:** `groups` claim can overflow; roles are stable & APIM-friendly.  
**Consequences:** Maintain role/group assignments during pilot.

---

## D006 — IaC strategy (Terraform + remote state)
**Date:** 2025-12-12  
**Status:** Accepted  
**Decision:** Terraform for infra; remote state in Azure Blob; CI/CD via GitHub Actions (OIDC).  
**Why:** Reproducibility; avoid clickops; no long-lived secrets for Azure auth.  
**Consequences:** Bootstrap workflow required once per env; state backend must exist before `terraform init`.

---

## D007 — Public-first, harden later
**Date:** 2025-12-12  
**Status:** Accepted  
**Decision:** First make pipeline fully functional with public access (dev), then harden gradually.  
**Why:** Debugging private networking + CI/CD + DB migrations at once is too costly.  
**Consequences:** Track hardening as explicit steps; avoid renaming resources to prevent replacements.

---

## D008 — DB migrations mechanism (DbUp)
**Date:** 2026-01-02  
**Status:** Accepted  
**Decision:** Use DbUp for ordered SQL migrations + schema history via `dbo.__schema_migrations`.  
**Why:** Prevent drift; repeatable deployments; can be run locally or in CI the same way.  
**Consequences:** Maintain migration scripts as append-only files; avoid editing applied scripts in shared envs.

---

## D009 — CI DB migrations: dynamic firewall rule for GitHub runner
**Date:** 2026-01-02  
**Status:** Accepted  
**Decision:** `db-migrate-dev` workflow temporarily adds a SQL firewall rule for the GitHub runner public IP, runs DbUp, then removes the rule.  
**Why:** Runner IP changes every run; we keep SQL in “selected networks” while still allowing CI to connect.  
**Consequences:** The workflow must be idempotent and ensure cleanup (best-effort delete even on failure).

---

## D010 — Dev DB authentication: SQL auth for now
**Date:** 2026-01-02  
**Status:** Accepted  
**Decision:** Use SQL admin login (`sqladmin`) for dev DbUp runs, with password stored in GitHub Secrets.  
**Why:** Fast to iterate while infra + schema stabilize.  
**Consequences:** Later we migrate to Entra admin + Entra-only auth, and stop using SQL auth for CI.

---

## D011 — Tenant columns duplicated on child tables (Option B)
**Date:** 2026-01-03  
**Status:** Accepted  
**Decision:** Add `cabinet_id` + `company_id` to core “child” tables (ex: `document_line`, `posting_line`, `exception_comment`).  
**Why:** Makes RLS and tenant-scoped queries simpler and more robust (no dependency on joins to parent to enforce scope).  
**Consequences:** Must keep tenant columns consistent with the parent rows (enforced by write-path + sanity checks).

---

## D012 — RLS enforced in Core DB only
**Date:** 2026-01-03  
**Status:** Accepted  
**Decision:** Implement SQL Row-Level Security only in the **Core** DB, not in **Directory**.  
**Why:** Core is the transactional data plane (documents/postings/exceptions) and the highest risk for leakage; Directory is mostly membership + routing data, and we keep it simpler initially.  
**Consequences:** API must treat Directory as an authorization source (membership), but the *hard-stop* is in Core RLS.

---

## D013 — Stable runtime DB role (decouple from identity naming)
**Date:** 2026-01-03  
**Status:** Accepted  
**Decision:** Create a stable DB role (ex: `app_runtime`) and grant it the minimum rights needed by the API. Add actual identities (Managed Identity / Entra users) later as role members.  
**Why:** Avoids blocking progress on identity naming and deployment order; keeps DB permissions deterministic.  
**Consequences:** Need a clear “role contract” (what rights the API needs) and a repeatable script to add users to the role.

---

## D014 — Sanity checks are not migrations
**Date:** 2026-01-03  
**Status:** Accepted  
**Decision:** Keep sanity checks as standalone scripts (ex: `db/sanity/*.sql`) rather than running them as DbUp migrations.  
**Why:** Checks are useful to run repeatedly (and sometimes interactively) without modifying schema history.  
**Consequences:** Add them to the runbook and optionally run them in CI as a separate step later.
