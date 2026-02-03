# Sanity check — Directory runtime (slug → IDs → authz)

## Goal
Validate the **runtime contract** used by the future API:

1. Resolve `cabinet_slug + company_slug` → `cabinet_id + company_id`
2. Verify authorization for a given `user_oid`
3. List accessible companies for `GET /me/companies`

Implemented by migration: `db/migrations/directory/0002_runtime_procs.sql`.

## Prerequisites
You need minimal data in **Directory DB**:
- 1 cabinet
- 2 companies inside that cabinet (one accessible, one not)
- 1 membership for a test user (`user_oid`) **only** on the accessible company (company-level membership)

Example dev values (used during initial validation):
- `cabinet_slug`: `cab-dev`
- `company_slug (OK)`: `co-ok`
- `company_slug (NOPE)`: `co-nope`
- `cabinet_id`: `11111111-1111-1111-1111-111111111111`
- `company_id (OK)`: `22222222-2222-2222-2222-222222222222`
- `company_id (NOPE)`: `33333333-3333-3333-3333-333333333333`
- `user_oid`: `aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa`

> Note: if you use a **cabinet-level membership** (`company_id IS NULL`), the user will see **all** companies of the cabinet, so you won't be able to validate the deny path with `co-nope`.

## Tests

### 1) Resolve (OK)
```sql
EXEC dir.usp_resolve_company @cabinet_slug='cab-dev', @company_slug='co-ok';
```
**Expected:** returns non-null `cabinet_id` and `company_id` for `co-ok`.

### 2) Check membership (OK)
```sql
EXEC dir.usp_check_membership
  @user_oid='aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  @cabinet_id='11111111-1111-1111-1111-111111111111',
  @company_id='22222222-2222-2222-2222-222222222222';
```
**Expected:** `is_allowed = true` and `role_code` not null (example: `CompanyUser`).

### 3) Resolve (NOPE)
```sql
EXEC dir.usp_resolve_company @cabinet_slug='cab-dev', @company_slug='co-nope';
```
**Expected:** returns non-null IDs for `co-nope` (slug resolution works independently of auth).

### 4) Check membership (NOPE)
```sql
EXEC dir.usp_check_membership
  @user_oid='aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  @cabinet_id='11111111-1111-1111-1111-111111111111',
  @company_id='33333333-3333-3333-3333-333333333333';
```
**Expected:** `is_allowed = false`, `role_code = NULL`, `role_scope = NULL`.

### 5) List my companies
```sql
EXEC dir.usp_get_my_companies @user_oid='aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
```
**Expected:** lists only `co-ok` (and NOT `co-nope`) with `effective_role_code`.

## Evidence (optional)
Attach screenshots of:
- `usp_resolve_company` (NOPE) returning the correct IDs
- `usp_check_membership` (NOPE) returning `is_allowed=false`
