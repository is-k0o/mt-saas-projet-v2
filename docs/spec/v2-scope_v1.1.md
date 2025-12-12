# v2 Scope — Pilot (3–10 cabinets)

**Status:** Draft  
**Last updated:** 2025-12-12  
**Target users:** Accounting firms (cabinet) managing multiple client companies  
**Architecture:** Two-plane (Write = Azure SQL + Storage, Read = Fabric Lakehouse)  
**Security model:** Option B (APIM coarse-grained, WebApp fine-grained + SQL RLS + Storage metadata checks)

---

## 1) Purpose (product)
Build a preprod-quality pilot of **ComptaPlus** that accelerates “bilan → bilan” workflows by:
- Ingesting accounting documents (e-invoice formats + PDFs)
- Producing **postings** (journal entries) and surfacing **exceptions**
- Providing analytics (“TVA gap”, “bilan variance”, KPIs) via Fabric

The pilot must be usable by a small number of cabinets (3–10) with strong tenant isolation and traceability.

---

## 2) Non-goals (explicitly out of scope for v2 pilot)
- Full production hardening (SOC-grade, complete compliance, full HA across regions)
- Unlimited cabinet scaling / self-serve onboarding
- Full OCR pipeline / heavy ML extraction (optional later)
- Full e-invoicing integration lifecycle (PDP, directory, routing, etc.) beyond basic import/export
- Perfect accounting coverage of every edge case (focus on a minimal but coherent subset)

---

## 3) Tenancy model (fixed)
- URL scope: `/t/{cabinet_slug}/companies/{company_slug}/...`
- Internal IDs: `cabinet_id`, `company_id` everywhere in SQL and Storage metadata
- Authentication: Entra ID (PKCE for SPA)
- Authorization:
  - APIM: token validation + scopes/roles (coarse)
  - WebApp: membership check (Directory DB) (fine)
  - SQL: RLS on all tenant tables (hard stop)
  - Storage: blob metadata scope checks (hard stop for files)

---

## 4) MVP features (v2 pilot)

### 4.1 Write Plane (Transactional)
**Documents**
- Create/ingest document metadata (invoice, credit note)
- Attach files (PDF, XML Factur-X/UBL/CII, original)
- Deduplicate by `document_hash` (and optionally by source IDs)
- List / get documents (paged, filtered)

**Posting**
- Create draft postings from documents
- Finalize posting via stored procedure:
  - refuses if not balanced (Σdebit != Σcredit)
  - sets status + finalized_at
- Link postings back to document(s) for traceability

**Exceptions**
- Detect exceptions during ingest/posting (code + severity)
- Queue + assign + resolve (with audit trail)
- Resolution requires a justification (free text + optional payload)

**Audit & traceability**
- Record key actions (ingest, post, resolve exception, export)
- Ensure “document → posting → export” trace chain

**Storage contract**
- Deterministic blob path
- Required metadata keys
- sha256 stored and optionally verified

### 4.2 Read Plane (Analytics / Fabric)
**Incremental export (SQL → Fabric Lakehouse)**
- Watermark-based incremental extraction
- Upsert on stable keys (`document_id`, `posting_id`, `exception_id`)
- Minimal curated tables for analytics

**Pilot analytics outputs**
- TVA cockpit: expected vs observed + top variance drivers (v1)
- Bilan cockpit: N vs N-1 variance (v1, requires baseline import — see Section 6)
- Ops KPIs: exceptions per day, time-to-resolve, dedup rate

---

## 5) Pack France v1 (minimal)
**PCG**
- Load a basic PCG dataset (account_code + labels + category)
- Allow mapping of postings to PCG accounts (simple validation)

**TVA FR**
- Minimal VAT codes/rates (start with common cases)
- Basic checks + analytics “VAT gap”

**FEC**
- Generate a basic FEC export from finalized postings (pilot-quality)
- Validate required fields exist (best-effort, with exceptions)

---

## 6) Onboarding data prerequisites (for “bilan → bilan”)

To compute **true N vs N-1** (e.g., 2025 vs 2024) variance, the platform must have **at least** a baseline for **N-1**.
You do **not** need accounting history back to 2010, but you **do** need a minimal prior-year baseline.

**Level 0 — Minimum viable (recommended for pilot)**
- Import **Trial Balance / Balance générale N-1** (per `account_code`) as a snapshot.
- Enables: “Bilan N vs N-1” variance **by account** (explainable at account level, limited drill-down).

**Level 1 — Recommended for “Explain the gap”**
- Import **FEC N-1** (or general ledger export) to enable deeper analysis:
  - variance drivers by journals, counterparties, document types, etc.
  - stronger controls (duplicates, tax anomalies, cut-off patterns).

**Level 2 — Fallback if N-1 is not available**
- Import **Opening balances (à-nouveaux) for year N**.
- Enables: comparisons **within year N** (opening → current), but **does not** enable true N vs N-1 variance.

**Behavior rule (must be explicit in UX)**
- If no N-1 snapshot exists, “N vs N-1” dashboards must show:
  - a clear message (“Baseline N-1 not available”)
  - the alternative view: “Opening (N) → Current”

---

## 7) Exceptions — v1 list (10–20 max)
Start with a small, high-value set. Example:
- `DUPLICATE_DOCUMENT`
- `DOC_TOTAL_MISMATCH`
- `MISSING_REQUIRED_FIELDS`
- `MISSING_SUPPLIER_VAT_ID`
- `VAT_AMOUNT_SUSPECT`
- `ACCOUNT_MAPPING_MISSING`
- `POSTING_UNBALANCED`
- `CUT_OFF_SUSPECT`
- `DATE_IN_FUTURE`
- `FILE_METADATA_SCOPE_MISMATCH`

For each exception code, define:
- trigger condition (when it is raised)
- severity (LOW/MED/HIGH)
- expected resolution actions (and required justification)

---

## 8) API surface (MVP)
Reference: `docs/contracts/api.md`.

Minimum endpoints:
- `GET /health`
- `GET /me/companies`
- `POST/GET /t/{cabinet_slug}/companies/{company_slug}/documents`
- `POST/GET /.../documents/{document_id}/files`
- `GET /.../exceptions` + `POST /.../exceptions/{id}/resolve`
- (optional pilot) `POST /.../exports/fec`
- (optional onboarding) `POST /.../onboarding/balance-snapshot`

---

## 9) Infra/IaC scope (Terraform)
**Must-have for v2 pilot**
- Resource groups, networking baseline (VNet if needed)
- Azure SQL + firewall rules/Private Endpoint (phase-based)
- Storage account (private)
- App Service (API) + Managed Identity
- APIM (policies, products)
- Front Door + WAF (optional early, recommended)
- Log Analytics / App Insights

**Fabric**
- Workspace + Lakehouse + connectivity (Managed Private Endpoints / Private Link) as needed

---

## 10) Definition of Done (pilot release)
- Tenant isolation validated:
  - URL tampering → 403 + no data leakage (RLS)
  - Storage scope mismatch → 403
- End-to-end scenario works for 2 cabinets and 3 companies:
  - ingest → posting draft → finalize → export (pilot) → analytics refresh
- Deploy is reproducible via Terraform (+ CI/CD for app + migrations)
- Minimal analytics dashboard/report is viewable with correct isolation
- N vs N-1 variance works when baseline is imported (Section 6)

---

## 11) Open questions (to decide early)
- Does `cabinet_slug` represent the cabinet only, or can it be a “workspace” grouping?
- What is the refresh cadence for Fabric (15min / 60min)?
- What is the minimal set of VAT cases for pilot (standard rate only vs + exemptions)?
- How are cabinet/company memberships managed initially (manual vs sync from Entra groups)?
- What is the minimum onboarding dataset you will request from cabinets (Level 0 vs Level 1)?
