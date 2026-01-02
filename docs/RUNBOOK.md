# RUNBOOK — mt-saas-projet-v2 (Terraform + DbUp + GitHub Actions)

> Objectif : avoir **une check-list reproductible** pour (re)déployer l’infra SQL + exécuter les migrations DbUp,
> avec les points de contrôle et les “gotchas” rencontrés (drift, firewall, mots réservés…).

---

## 0) Vue d’ensemble

### Workflows (ordre logique)
1. **bootstrap-tfstate-dev**  
   Crée (idempotent) : RG + Storage Account + Container du **remote state Terraform**.

2. **terraform-plan-infra-dev**  
   Plan Terraform (dev) — utile pour valider les changements avant apply.

3. **terraform-apply-infra-dev**  
   Apply Terraform (dev) — crée/maintient le SQL Server + DBs.

4. **db-migrate-dev**  
   Exécute DbUp (Directory puis Core) via `dotnet run` et journalise via `dbo.__schema_migrations`.

> TL;DR : **Bootstrap state → Apply infra → DbUp**

---

## 1) Pré-requis

### Azure / Entra
- Un **App Registration** (service principal) pour GitHub OIDC (déploiements).
- Le SP doit avoir au minimum **Contributor** sur la subscription (pour dev).

### GitHub (repo + env)
- Repo : `is-k0o/mt-saas-projet-v2`
- Environment GitHub : `dev` (si tes workflows sont environment-based).

### Secrets / Variables GitHub (déjà vus)
**Repository secrets**
- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`
- `TF_VAR_SQL_ADMIN_PASSWORD`

**Repository variables**
- `TFSTATE_RG`
- `TFSTATE_STORAGE_ACCOUNT`
- `TFSTATE_CONTAINER`
- `TFSTATE_LOCATION`

> Note : `sql_admin_login` a un default Terraform (`sqladmin`). Pas besoin de variable GitHub dédiée, sauf si tu veux le rendre configurable.

---

## 2) “Source of truth” — valeurs dev actuelles (à mettre à jour si tu renames)

> À la date du run (exemple). Si tu changes le naming, modifie cette section + `CURRENT_STATE.md`.

- RG dev : `rg-mtsaas-v2-dev-weu`
- SQL Server : `mtsaas-dev-weu-sql-2qb3j4`
- DB directory : `mtsaas_dev_directory`
- DB core : `mtsaas_dev_core`
- Public network access : **Enabled**
- Firewall rules (minimum) : `AllowAzureServices 0.0.0.0/0` + IP runner ajoutée au moment du DbUp

---

## 3) Exécution standard (happy path)

### Step A — Bootstrap remote state (une fois, puis idempotent)
1. Lance **bootstrap-tfstate-dev**
2. Vérifie dans Azure :
   - RG tfstate existe
   - Storage Account existe
   - Container existe

**Symptôme si oublié :** `terraform init` échoue avec `ResourceGroupNotFound` / storage account not found.

---

### Step B — Plan + Apply infra (à chaque changement infra)
1. Lance **terraform-plan-infra-dev**
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
- Directory :
  ```sql
  SELECT * FROM dbo.__schema_migrations ORDER BY Applied;
  SELECT COUNT(*) AS tables_count FROM sys.tables WHERE schema_id = SCHEMA_ID('dir');
  ```
- Core :
  ```sql
  SELECT * FROM dbo.__schema_migrations ORDER BY Applied;
  SELECT COUNT(*) AS tables_count FROM sys.tables WHERE schema_id = SCHEMA_ID('core');
  SELECT OBJECT_ID('core.usp_finalize_posting') AS finalize_proc;
  ```

---

## 4) Déclenchement : éviter les runs automatiques (recommandé)

Si tu ne veux pas que ça parte **à chaque push** :
- Mets les workflows en **manuel** :
  ```yaml
  on:
    workflow_dispatch:
  ```
- Ou limite via `paths:` (ex : infra seulement quand `infra/terraform/**` change)
- Ou exige une validation humaine via **Environment protection rules** (approvals) sur `dev` / `preprod`.

---

## 5) Dépannage (les pannes les plus fréquentes)

### A) DbUp timeout / connexion impossible
**Symptômes :**
- `Connection Timeout Expired` pendant login/post-login.

**Causes fréquentes :**
- Public access désactivé / “Selected networks” sans rule pour le runner
- Firewall runner IP pas ajoutée (ou ajout tardif)
- SQL Server “cold” (rare sur Standard, plus vrai sur serverless)

**Actions :**
1. Vérifie `publicNetworkAccess` = Enabled
2. Vérifie firewall rules :
   ```powershell
   $RG="rg-mtsaas-v2-dev-weu"
   $SERVER="mtsaas-dev-weu-sql-2qb3j4"
   az sql server firewall-rule list -g $RG -s $SERVER -o table
   ```
3. Ajoute log de l’IP runner dans le workflow DbUp (tu l’as déjà) et confirme qu’une rule `gha-dbup-*` est créée.

---

### B) “There is already an object named …” (drift)
**Symptôme :** DbUp tente de rejouer `0001_init.sql` alors que des tables existent déjà.

**Cause :**
- La DB contient déjà des objets mais **pas** la table `dbo.__schema_migrations` (ou elle est vide), donc DbUp pense que rien n’a été appliqué.

**Fix clean (dev) :**
- Le plus simple : **drop/recreate** les DBs (core + directory) puis relancer `db-migrate-dev`.
- Alternative (plus risquée) : créer `dbo.__schema_migrations` et y insérer les scripts “déjà appliqués” (pas recommandé en dev au début).

---

### C) “Incorrect syntax near the keyword 'rule'”
**Cause :**
- Mot réservé / conflit SQL (ex : table `rule`, colonne, etc.).

**Fix :**
- Renommer ou échapper correctement (ex : `[rule]`), idéalement en restant cohérent côté schéma `core.rule`.
- Une fois corrigé : relancer `db-migrate-dev` (DbUp rejouera le script non journalisé).

---

### D) “Cannot define PRIMARY KEY constraint on nullable column …”
**Cause :**
- PK sur colonne nullable (ex : `user_membership` mal défini).

**Fix :**
- S’assurer que toutes les colonnes d’une PK sont `NOT NULL`.
- Rebuild dev DB si besoin (si drift).

---

### E) “Login failed for user 'sqladmin'” / mot de passe perdu
**Cause :**
- Password oublié / différent de celui dans `TF_VAR_SQL_ADMIN_PASSWORD`.

**Fix :**
- Le plus clean : **reset** le password SQL admin, puis mettre à jour le secret GitHub.
  ```powershell
  az sql server update -g $RG -n $SERVER --admin-password "<NEW_PASSWORD>"
  ```
  (Puis update `TF_VAR_SQL_ADMIN_PASSWORD` dans GitHub secrets.)

---

## 6) Bonnes pratiques (pour éviter de se refaire piéger)

- Toujours faire un **bootstrap state** avant le premier `terraform init` remote.
- En dev, privilégier le reset DB plutôt que “réparer à la main” un drift.
- Garder `0001_init.sql` le plus stable possible ; les évolutions vont dans `0002_...`, `0003_...` etc.
- Un script DbUp = idéalement transactionnel (DbUp gère selon la stratégie choisie).
- Après chaque étape importante : update `CURRENT_STATE.md` + `DECISIONS.md`.

---

## 7) Patchnote (mini-changelog des galères)
- Ajout règle firewall runner + log IP pour DbUp
- Fix mot réservé `rule`
- Fix PK nullable sur `user_membership`
- Mise en place journal `dbo.__schema_migrations`
- Séparation Directory/Core + exécution séquentielle

---

*Dernière mise à jour : 2026-01-02 07:12:05*
