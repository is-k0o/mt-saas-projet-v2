# Storage Contract (v1)

**Storage account:** <name>  
**Container(s):** `documents` (recommended)  
**Status:** Draft  
**Last updated:** YYYY-MM-DD

## 1) Goals
- Deterministic paths (easy to debug)
- No cross-tenant leakage
- Strong integrity checks (hash + metadata)
- Ready for Private Endpoint later

## 2) Blob path convention (MUST)
```
cabinet=<cabinet_slug>/company=<company_slug>/yyyy/MM/<document_id>/<kind>.<ext>
```

### Examples
- `cabinet=alpha/company=acme/2025/12/4f3c.../pdf.pdf`
- `cabinet=alpha/company=acme/2025/12/4f3c.../xml.xml`

## 3) `kind` values (fixed)
- `pdf | xml | original | extracted_text | preview`

## 4) Metadata (REQUIRED)
These keys MUST exist on every blob:
- `cabinet_id` (GUID)
- `company_id` (GUID)
- `document_id` (GUID)
- `kind` (enum)
- `sha256` (hex lowercase, raw file bytes)
- `mime` (recommended)
- `uploaded_by` (optional, `user_oid`)
- `uploaded_at` (optional, UTC ISO 8601)

## 5) Validation rules (server-side)
- On upload, API MUST:
  - compute sha256
  - write metadata
  - verify `(cabinet_id, company_id, document_id)` match request scope
- On read, API MUST:
  - refuse if metadata scope != request scope (403)
  - optionally verify sha256 when high-integrity mode is enabled

## 6) Dedup strategy (recommended)
- SQL dedup: `document_hash` unique per `(cabinet_id, company_id)`
- File integrity: `file_sha256` stored in DB table `core.document_file`

## 7) Security
- Container access: private (no public access)
- Access to blobs only through API (Managed Identity)
- No SAS to clients in v1 (optional later with strict scope)

## 8) Lifecycle / retention (optional)
- Raw/original: keep X months
- Extracted/preview: keep Y months
