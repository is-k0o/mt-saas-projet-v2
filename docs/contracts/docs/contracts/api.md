# API Contract (v1)

**Base path:** `/`  
**Tenant scope:** `/t/{cabinet_slug}/companies/{company_slug}`  
**Auth:** Entra ID (PKCE for SPA) + APIM validate token  
**Status:** Draft | Active  
**Last updated:** YYYY-MM-DD

## 1) Common rules
- All tenant-scoped endpoints require valid token.
- Backend MUST enforce: user_oid has access to (cabinet_id, company_id).
- RLS is enforced at SQL level (defense in depth).

## 2) Standard response envelope
### Success (list)
```json
{
  "items": [],
  "skip": 0,
  "take": 50,
  "count": 0
}
