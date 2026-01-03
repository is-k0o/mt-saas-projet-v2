# RUNBOOK — mt-saas-projet-v2 (Terraform + DbUp + GitHub Actions)

> Objectif : avoir une check-list **reproductible** pour (re)déployer l’infra SQL + exécuter les migrations DbUp,
> avec les points de contrôle et les “gotchas” rencontrés (drift, firewall, mots réservés, RLS...).

---

## 0) Vue d’ensemble

### Workflows (ordre logique)
1. **bootstrap-tfstate-dev** (manuel)
   - Crée (idempotent) : RG + Storage Account + Container du **remote state Terraform**.

2. **terraform-plan-infra-dev** (PR)
   - Plan Terraform (dev) — utile pour valider les changements avant apply.

3. **terraform-apply-infra-dev** (push main / manuel)
   - Apply Terraform (dev) — crée/maintient le SQL Server + DBs.

4. **db-migrate-dev** (push main / manuel)
   - Lit les outputs Terraform (SQL server + noms des DB)
   - Ajoute une règle firewall temporaire pour l’IP du runner GitHub
   - Exécute DbUp (Directory puis Core)
   - Retire la règle firewall (best-effort, même si ça casse)

> TL;DR : **Bootstrap state → Apply infra → DbUp**

---

## 1) Pré-requis

### Azure / Entra
- Un **App Registration** (service principal) pour GitHub OIDC (déploiements).
- Le SP doit avoir au minimum **Contributor** sur la subscription (dev).
- Pour le backend Terraform (state) : `Storage Blob Data Contributor` sur le Storage Account (ou container).

### GitHub (repo + env)
- Repo : `is-k0o/mt-saas-projet-v2`
- Environment GitHub : `dev` (les workflows sont `environment: dev`).

### Secrets / Variables GitHub
**Secrets**
- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`
- `TF_VAR_SQL_ADMIN_PASSWORD` (temporaire : SQL auth pour DbUp)

**Variables**
- `TFSTATE_RG`
- `TFSTATE_STORAGE_ACCOUNT`
- `TFSTATE_CONTAINER`
- `TFSTATE_LOCATION`
- `SQL_ADMIN_LOGIN` (optionnel ; défaut runner = `sqladmin`)

---

## 2) “Source of truth” — valeurs dev actuelles

> À la date du run. Si tu changes le naming, modifie aussi `docs/CURRENT_STATE.md`.

- RG dev : `rg-mtsaas-v2-dev-weu`
- DB directory : `mtsaas_dev_directory`
- DB core : `mtsaas_dev_core`
- Public network access : **Enabled** (dev)
- Firewall rules :
  - `AllowAzureServices 0.0.0.0/0` (dev convenience)
  - `gha-dbup-<runid>` (temporaire, créé/supprimé par le workflow)

---

## 3) Exécution standard (happy path)

### Step A — Bootstrap remote state (une fois, puis idempotent)
1. Lance **bootstrap-tfstate-dev**
2. Vérifie dans Azure :
   - RG tfstate existe
   - Storage Account existe
   - Container existe

**Symptôme si oublié :** `terraform init` échoue (RG/SA/container not found).

---

### Step B — Plan + Apply infra (à chaque changement infra)
1. Lance **terraform-plan-infra-dev** (ou laisse-le tourner sur PR)
2. Si OK, lance **terraform-apply-infra-dev**
3. Vérifie côté Azure :
   - SQL Server présent
   - DBs présentes (`directory` + `core`)

---

### Step C — Migrations DbUp (à chaque changement DB)
1. Lance **db-migrate-dev**
2. Le workflow :
   - ajoute une règle firewall temporaire (IP runner)
   - `dotnet restore`
   - `dotnet run -c Release --no-build`
   - exécute d’abord **directory**, puis **core**
   - journalise dans `dbo.__schema_migrations`

**Vérifs rapides SQL**
- Dans chaque DB :
  ```sql
  SELECT * FROM dbo.__schema_migrations ORDER BY Applied;
  ```

- Core :
  ```sql
  SELECT OBJECT_ID('core.usp_finalize_posting') AS finalize_proc;
  SELECT OBJECT_ID('sec.usp_set_tenant_context') AS set_ctx_proc;
  SELECT name, is_enabled FROM sys.security_policies;
  ```

---

## 4) Sanity checks RLS (reproductible)

### 4.1 Script “rapport” (recommandé)
Dans **Core DB**, exécute :
- `db/sanity/core_sanity_check.sql`

Ce script sort un petit tableau (OK/WARN/KO) pour :
- présence des colonnes tenant (`cabinet_id`, `company_id`) y compris dans les child tables
- objets RLS (proc + predicate + policy)
- policy enabled
- checks de cohérence (child → parent)

> Si tu n’as pas encore de data, le check “sample tenant selected” peut être KO/WARN (normal).

---

### 4.2 Test RLS “comme si c’était l’API” (EXECUTE AS)
**But:** éviter les faux positifs quand tu es connecté en admin / db_owner.

1) (Optionnel) créer un user local de test **WITHOUT LOGIN** :
```sql
-- Une seule fois (dev)
CREATE USER [api_local] WITHOUT LOGIN;
-- L'ajouter au rôle runtime (créé par migration 0005)
EXEC sp_addrolemember 'app_runtime', 'api_local';
```

2) Simuler l’API :
```sql
EXECUTE AS USER = 'api_local';

-- Sans contexte : tu dois voir 0 (ou très peu selon ta policy)
SELECT COUNT(*) AS cnt_docs FROM core.document;

-- Prendre un tenant existant
DECLARE @cab UNIQUEIDENTIFIER, @comp UNIQUEIDENTIFIER;
SELECT TOP 1 @cab = cabinet_id, @comp = company_id FROM core.audit_event;
IF @comp IS NULL SELECT TOP 1 @cab = cabinet_id, @comp = company_id FROM core.document;

-- Appliquer le contexte
EXEC sec.usp_set_tenant_context @cabinet_id = @cab, @company_id = @comp;

-- Avec contexte : tu dois voir des rows (si le tenant a de la data)
SELECT COUNT(*) AS cnt_docs_ctx FROM core.document;

REVERT;
```

3) Nettoyage (si tu veux) :
```sql
DROP USER IF EXISTS [api_local];
```

---

## 5) Dépannage (pannes fréquentes)

### A) DbUp timeout / connexion impossible
**Causes :** firewall, public access off, IP runner pas ajoutée, mauvais FQDN.

**À vérifier :**
- `publicNetworkAccess` = Enabled (dev)
- la règle firewall temporaire `gha-dbup-*` est bien créée pendant le job

---

### B) “There is already an object named …” (drift)
**Cause :** objets existants mais `dbo.__schema_migrations` vide/inexistant (DbUp rejoue).

**Fix clean (dev) :** drop/recreate DB(s) puis relancer.

---

### C) RLS “ça marche chez moi” mais pas en prod
**Cause fréquente :** tests faits en `db_owner` (RLS bypass) ou avec un user trop permissif.

**Fix :** refaire le test avec `EXECUTE AS USER = 'api_local'` + rôle minimal.

---

## 6) Bonnes pratiques

- Migrations = **append-only** : ne modifie pas un script déjà appliqué en env partagé.
- Dev : si drift, c’est souvent plus rapide de **reset** (drop/recreate) que de patcher à la main.
- Toujours maintenir `CURRENT_STATE.md` + `DECISIONS.md` quand tu ajoutes une “brique” structurante.
- RLS : tester avec un user **non-db_owner** (sinon tu te racontes des histoires).

---

## 7) Patchnote (mini-changelog des galères)
- Ajout règle firewall runner + cleanup best-effort
- Fix mot réservé `rule` → `core.[rule]`
- Fix PK nullable sur `user_membership` (Directory)
- Mise en place journal `dbo.__schema_migrations`
- RLS Core (proc + policy) + colonnes tenant sur child tables
- Rôle DB `app_runtime` pour l’identité API (plus tard)

---

*Dernière mise à jour : 2026-01-03*
