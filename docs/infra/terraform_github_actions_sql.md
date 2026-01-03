# CI/CD — Terraform (infra dev) + GitHub OIDC

**Last updated:** 2026-01-03

Ce guide documente la partie infra (Terraform) et l’auth GitHub → Azure via **OIDC**.

> Note : pour l’instant, les migrations DbUp utilisent encore **SQL auth** en dev (password en secret).
> Le plan long terme est de passer en **Entra-only** (admin Entra + Managed Identity + rôles DB).

---

## 1) Ce que tu as dans le repo

Workflows :
- `terraform-bootstrap-tfstate-dev.yml` — crée le backend Terraform (run 1 fois)
- `terraform-plan-infra-dev.yml` — plan sur PR
- `terraform-apply-infra-dev.yml` — apply sur `main`
- `db-migrate-dev.yml` — exécute DbUp (Directory + Core) après lecture des outputs Terraform

Terraform :
- `infra/terraform/environments/dev/*`
- modules : `infra/terraform/modules/sql/*`

---

## 2) Pré-requis Azure (OIDC)

### 2.1 App Registration (service principal)
Créer une application Entra (service principal) dédiée aux workflows GitHub.
Ce SP sera utilisé via OIDC (pas de secret long-lived).

Tu auras besoin de :
- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`

### 2.2 Federated credential (GitHub OIDC)
Ajouter un “Federated identity credential” sur l’app, typiquement basé sur l’environment GitHub :
- Subject recommandé : `repo:<OWNER>/<REPO>:environment:dev`
- Issuer : `https://token.actions.githubusercontent.com`
- Audience : `api://AzureADTokenExchange`

### 2.3 RBAC minimal
- Sur le RG cible (dev) : **Contributor**
- Sur le Storage Account du state Terraform : **Storage Blob Data Contributor**

---

## 3) Pré-requis GitHub (Environment dev)

### 3.1 Créer l’environment `dev`
Repo → Settings → Environments → `dev`.
Optionnel : exiger une approval manuelle sur `terraform-apply-infra-dev`.

### 3.2 Secrets (env `dev`)
- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`
- `TF_VAR_SQL_ADMIN_PASSWORD` (temporaire ; SQL auth pour Azure SQL)

### 3.3 Variables (env `dev`)
Backend state :
- `TFSTATE_RG`
- `TFSTATE_LOCATION`
- `TFSTATE_STORAGE_ACCOUNT`
- `TFSTATE_CONTAINER`

Optionnel (DbUp dev) :
- `SQL_ADMIN_LOGIN` (défaut runner : `sqladmin`)

---

## 4) Backend Terraform (backend.dev.hcl)

Fichier : `infra/terraform/environments/dev/backend.dev.hcl`

Il référence :
- `resource_group_name`
- `storage_account_name`
- `container_name`
- `key`

Le workflow **bootstrap** est là pour te créer RG/SA/container si besoin.

---

## 5) Flux normal

1) Bootstrap (une fois)
- Actions → `bootstrap-tfstate-dev` → Run

2) PR infra
- Ouvrir une PR avec des changements dans `infra/terraform/**`
- `terraform-plan-infra-dev` tourne

3) Merge / push main
- `terraform-apply-infra-dev` tourne

4) Migrations DB
- Après un push dans `db/migrations/**` ou `src/migrations/**` : `db-migrate-dev` tourne

---

## 6) Troubleshooting rapide

- **OIDC login fails**
  - vérifier subject/issuer/audience du federated credential
  - vérifier `permissions: id-token: write` dans le workflow

- **Terraform backend access denied**
  - manque `Storage Blob Data Contributor` sur le Storage Account (state)

- **DbUp ne se connecte pas au SQL**
  - public access / firewall : `db-migrate-dev` ajoute une règle temporaire
  - si tu as désactivé le public network access, il faudra une approche Private Endpoint (plus tard)

---

## 7) Hardening (plus tard)

1) SQL Server : désactiver public access + Private Endpoint
2) Activer admin Entra sur le SQL Server
3) Remplacer SQL auth par Entra-only (DbUp + API via MI)
4) Diagnostics + Defender for SQL
