# Naming Contract (v1)

**Status:** Draft | Active  
**Last updated:** 2025-12-12  
**Owner:** <you>  
**Scope:** API + DB + Storage + Logs + Analytics

## 1) Goals
- Eliminate ambiguity (ex: “tenant_id” could mean Entra tenant or business tenant).
- Make renames explicit and traceable.
- Keep identifiers stable across SQL, Storage, Fabric.

## 2) Glossary (single source of truth)
### Identity (Entra)
- `entra_tenant_id` : GUID of Entra tenant (claim `tid`)
- `user_oid` : GUID of user object id (claim `oid`)
- `app_client_id` : GUID of App Registration (client id)
- `api_audience` : App ID URI (recommended) e.g. `api://...`

### Business tenancy
- `cabinet_id` : GUID (internal, DB)
- `company_id` : GUID (internal, DB)
- `cabinet_slug` : string used in URL (stable, human-friendly)
- `company_slug` : string used in URL (stable, human-friendly)

### Documents
- `document_id` : GUID (internal, stable pivot)
- `document_ref` : human/business reference (ex: invoice number)
- `document_hash` : SHA-256 of canonical fields (dedup)
- `file_sha256` : SHA-256 of raw uploaded file (artifact integrity)

## 3) Canonical casing + formatting rules
- IDs: GUID lowercase in logs, stored as `uniqueidentifier` in SQL.
- Slugs: lowercase, `[a-z0-9-]` only.
- Dates: UTC everywhere (`sysutcdatetime()`), expose ISO 8601.

## 4) Reserved words (DO NOT USE)
- `tenant_id` (ambiguous) → use `entra_tenant_id` or `cabinet_id` explicitly.

## 5) Cross-layer mapping (URL → DB → RLS)
- URL uses: `{cabinet_slug}` + `{company_slug}`
- Backend resolves slugs → `cabinet_id/company_id` via Directory DB
- SQL uses `SESSION_CONTEXT('cabinet_id')` and `SESSION_CONTEXT('company_id')`

## 6) Versioning & breaking changes
- Any rename of: route params, env vars, DB columns, storage metadata keys
  MUST be recorded in `docs/BREAKING_CHANGES.md`.
- Backward-compat window: <define if any>.
