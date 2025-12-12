# Decisions Log (Template)

**Purpose:** capture decisions that affect architecture, naming, security, or data contracts.  
**Rule:** any breaking change must also be recorded in `docs/BREAKING_CHANGES.md`.

---

## Decision format
**ID:** DEC-YYYYMMDD-XX  
**Date:** YYYY-MM-DD  
**Status:** Proposed | Accepted | Deprecated  
**Area:** Auth | API | DB | Storage | Terraform | Fabric | UX | Other  
**Decision:** <one sentence>  
**Context:** <why this mattered>  
**Options considered:**  
- A) ...  
- B) ...  
- C) ...  
**Chosen option:** <A/B/C>  
**Rationale:** <why chosen>  
**Consequences:** <what this changes / what it enables / what it risks>  
**Implementation notes:** <where/how to implement>  
**Links:** <PR/commit/docs>

---

## Examples (fill with your real decisions)

**ID:** DEC-YYYYMMDD-01  
**Date:** YYYY-MM-DD  
**Status:** Accepted  
**Area:** Auth  
**Decision:** Use Option B authorization (APIM coarse, WebApp fine + RLS).  
**Context:** Two-plane architecture; Fabric entry cannot be filtered by APIM.  
**Options considered:** A) Tenant-aware roles at gateway  B) Directory DB membership + RLS  
**Chosen option:** B  
**Rationale:** Scales better; reduces Entra role sprawl; keeps hard stop at DB.  
**Consequences:** WebApp must implement membership checks on every request.  
**Implementation notes:** `docs/contracts/auth.md`; middleware + Directory DB lookups.  
