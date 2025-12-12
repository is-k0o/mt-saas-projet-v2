# Current State (Template)

**Goal:** quick snapshot so you (and the AI) can resume work across multiple chats without losing context.

**Last updated:** YYYY-MM-DD  
**Environment:** local | dev | preprod | prod  
**Branch:** <main/dev/feature/...>

---

## 1) What works end-to-end (checklist)
- [ ] Entra auth (PKCE) → token acquired in SPA
- [ ] APIM validates token + enforces scopes
- [ ] WebApp resolves cabinet/company slugs → IDs (Directory DB)
- [ ] Membership check: user_oid ↔ cabinet/company returns 403 when missing
- [ ] SQL RLS applied to all tenant tables
- [ ] Storage upload writes required metadata + sha256
- [ ] Storage download enforces metadata scope check
- [ ] Fabric: incremental export job runs (watermark)
- [ ] Fabric: basic report/dashboard built with correct isolation

---

## 2) In progress (now)
- <bullet>
- <bullet>

---

## 3) Next 3 actions (most important)
1) <action>
2) <action>
3) <action>

---

## 4) Risks / blockers
- <risk>
- <blocker>

---

## 5) Decisions recently made (link to DECISIONS.md)
- <DEC-...>

---

## 6) Technical notes (useful reminders)
- API audience (App ID URI): `api://<...>`
- URL pattern: `/t/{cabinet_slug}/companies/{company_slug}`
- RLS context keys: `cabinet_id`, `company_id`, `user_oid`
- Storage contract: required metadata keys in `docs/contracts/storage.md`
- Fabric refresh cadence: <15m/60m/etc>
