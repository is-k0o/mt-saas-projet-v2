# Auth Contract (v1) — Option B (Coarse at APIM, Fine in WebApp + RLS)

**Status:** Draft  
**Last updated:** YYYY-MM-DD  
**Audience (API):** `api://<your-api-app-id-uri>`  
**Token version:** v2

## 1) Goals
- Entra ID authenticates the user (identity).
- APIM enforces coarse-grained access (token validity + global permissions).
- WebApp enforces fine-grained access (user ↔ cabinet/company membership).
- SQL RLS is the hard safety net (no cross-tenant leakage even if the app has a bug).

## 2) Claims used (expected)
From the access token:
- `tid` → `entra_tenant_id`
- `oid` → `user_oid`
- `aud` → must equal API App ID URI (`api://...`) (or the configured audience)
- `scp` → scopes (delegated permissions) for SPA callers
- `roles` → optional: global roles (e.g., `CabinetAdmin`) if you choose App Roles

## 3) Entra configuration (recommended for pilot)
### API App Registration (Resource API)
Create **Scopes** (delegated permissions) for the SPA:
- `Documents.Read`
- `Documents.ReadWrite`
- `Exceptions.Read`
- `Exceptions.Resolve`

Optional **App Roles** (RBAC-style, global):
- `CabinetUser`
- `CabinetAdmin`

Notes:
- Use scopes for endpoint-level permissions (easy for SPA).
- Use roles only for elevated/global actions (admin endpoints).

### SPA App Registration (Client)
- Use **Authorization Code Flow with PKCE**
- Request scopes: `api://<api-app-id>/Documents.ReadWrite` etc.

## 4) APIM responsibilities (coarse-grained)
APIM MUST:
- Validate token (issuer, signature, exp, audience)
- Require minimum scopes for each operation
- Optionally require `roles` for admin-only operations
- Apply rate limiting, size limits, and logging/correlation

### Policy rules (conceptual)
- For `GET /.../documents` require `scp` contains `Documents.Read`
- For `POST /.../documents` require `scp` contains `Documents.ReadWrite`
- For `POST /.../exceptions/{id}/resolve` require `scp` contains `Exceptions.Resolve`

APIM MUST NOT try to enforce cabinet/company membership (dynamic data).

## 5) WebApp responsibilities (fine-grained)
For every tenant-scoped request:
1) Extract `{cabinet_slug}` and `{company_slug}` from the route
2) Resolve slugs → `cabinet_id`, `company_id` via Directory DB
3) Check membership:
   - `dir.user_company_access` contains `(user_oid, cabinet_id, company_id)`
   - If not, return **403**
4) Resolve shard for `(cabinet_id, company_id)`
5) Call `sec.usp_set_tenant_context(cabinet_id, company_id, user_oid)`
6) Execute queries normally (RLS filters automatically)

Recommended endpoint:
- `GET /me/companies` → returns list of cabinets/companies accessible to `user_oid`
  (used by SPA to populate the tenant selector)

## 6) Directory DB minimum tables (suggested)
- `dir.cabinet(cabinet_id, cabinet_slug, name, ...)`
- `dir.company(company_id, company_slug, cabinet_id, name, ...)`
- `dir.user_company_access(user_oid, cabinet_id, company_id, role, created_at, ...)`
- `dir.company_shard_map(company_id, shard_id, ...)` (or cabinet+company mapping)

## 7) SQL / RLS contract
- Stored proc: `sec.usp_set_tenant_context(@cabinet_id, @company_id, @user_oid)`
- RLS predicate uses `SESSION_CONTEXT('cabinet_id')` and `SESSION_CONTEXT('company_id')`
- Apply RLS to ALL tenant tables (documents, lines, postings, exceptions, rules, files, audit)

## 8) Test cases (must pass)
- Token valid but user has no membership → 403
- User has membership in cabinet A/company X:
  - `/t/A/companies/X/...` → 200
  - `/t/B/companies/Y/...` → 403
- If WebApp check is intentionally bypassed (test-only):
  - SQL RLS still prevents cross-tenant reads (returns 0 rows)

## 9) Future: optional “tenant-aware gateway” (if you ever need it)
You can later add a cabinet-level role (e.g., `cab:alpha`) if you want APIM to block earlier,
but keep WebApp + RLS as the source of truth.
