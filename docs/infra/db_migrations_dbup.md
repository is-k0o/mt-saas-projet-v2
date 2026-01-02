# DbUp migrations — dev/public-first

Generated: 2026-01-02

This is intentionally "public-first" so the pipeline works end-to-end quickly.

Next hardening steps (later):
- Switch migrations auth to Entra-only (no SQL password)
- Disable public network access + add private endpoints
- Add RLS policies + `sec.usp_set_tenant` context in later migrations
