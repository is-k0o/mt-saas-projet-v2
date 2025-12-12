# API Contract (v1)

**Base path:** `/`  
**Tenant scope:** `/t/{cabinet_slug}/companies/{company_slug}`  
**Auth:** Entra ID (PKCE for SPA) + APIM validates token  
**Status:** Draft  
**Last updated:** YYYY-MM-DD

## 1) Common rules
- All tenant-scoped endpoints require a valid access token.
- Backend MUST enforce: `user_oid` has access to `(cabinet_id, company_id)` resolved from slugs.
- SQL Row-Level Security (RLS) is enforced at DB level (defense in depth).

## 2) Standard response envelope

### Success (list)
```json
{
  "items": [],
  "skip": 0,
  "take": 50,
  "count": 0
}
```

### Error (standard)
```json
{
  "error": {
    "code": "FORBIDDEN",
    "message": "You do not have access to this company.",
    "correlationId": "00000000-0000-0000-0000-000000000000"
  }
}
```

## 3) Pagination
- Query: `?skip=0&take=50`
- Max `take`: 200
- Stable ordering: default `created_at DESC` unless specified

## 4) Routes (MVP)

### Health
- `GET /health` → 200

### Companies available to user
- `GET /me/companies`
  - Returns cabinets/companies the current `user_oid` can access (slugs + IDs).

### Documents
- `POST /t/{cabinet_slug}/companies/{company_slug}/documents`
- `GET  /t/{cabinet_slug}/companies/{company_slug}/documents?skip=&take=&q=`
- `GET  /t/{cabinet_slug}/companies/{company_slug}/documents/{document_id}`

### Document files
- `POST /t/{cabinet_slug}/companies/{company_slug}/documents/{document_id}/files`
- `GET  /t/{cabinet_slug}/companies/{company_slug}/documents/{document_id}/files`
- `GET  /t/{cabinet_slug}/companies/{company_slug}/documents/{document_id}/files/{file_id}`

### Exceptions
- `GET  /t/{cabinet_slug}/companies/{company_slug}/exceptions?skip=&take=&status=OPEN`
- `POST /t/{cabinet_slug}/companies/{company_slug}/exceptions/{exception_id}/assign`
- `POST /t/{cabinet_slug}/companies/{company_slug}/exceptions/{exception_id}/resolve`

## 5) Status enums (fixed)

### document.status
- `DRAFT | READY | POSTED | REJECTED | CANCELLED`

### exception.status
- `OPEN | IN_REVIEW | RESOLVED | IGNORED`

## 6) HTTP status codes
- 200/201: success
- 400: validation error (bad payload)
- 401: no/invalid token
- 403: authenticated but not allowed (tenant/company mismatch)
- 404: not found (within allowed scope)
- 409: conflict (dedup/idempotency violation)
- 429: throttled
- 500: unexpected error

## 7) Correlation & logging
- Accept `x-correlation-id` from client; generate if missing.
- Return it in all responses and include it in logs.

## 8) Idempotency (writes)
- Writes may accept `Idempotency-Key` header (recommended).
- Same key within same `(cabinet_id, company_id)` must return the same result,
  or return `409` with a pointer to the existing resource.
