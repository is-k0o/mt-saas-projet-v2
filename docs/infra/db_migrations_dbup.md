# DbUp migrations (Directory + Core)

**Last updated:** 2026-01-03  
**Scope:** dev (public-first), pipeline-ready

---

## 1) Le principe

On applique des scripts SQL **ordonnés par nom de fichier** (0001_, 0002_, …) via un runner .NET (DbUp).
DbUp maintient l’historique d’exécution dans une table journal : **`dbo.__schema_migrations`**.

- Directory DB : `db/migrations/directory/*`
- Core DB      : `db/migrations/core/*`

Le workflow `db-migrate-dev` exécute d’abord **Directory**, puis **Core**.

---

## 2) Runner (src/migrations/ComptaPlus.Migrations)

### Comportement important
- **Transaction par fichier** : `WithTransactionPerScript()`
  - Objectif : éviter le drift si un script “gros” casse au milieu.
  - Chaque fichier est censé être **atomique** (tout passe, ou tout rollback).
- Journal : `JournalToSqlTable("dbo", "__schema_migrations")`
- Scripts : `WithScriptsFromFileSystem(dir)` → ordre lexical des fichiers.

### Variables d’environnement attendues
Le runner prend :
- `SQL_SERVER_FQDN`
- `CORE_DB_NAME`
- `DIRECTORY_DB_NAME`
- `SQL_ADMIN_PASSWORD` (dev)
- optionnel : `SQL_ADMIN_LOGIN` (défaut `sqladmin`)
- optionnel : `MIGRATIONS_ROOT` (sinon il remonte depuis le bin)

---

## 3) Convention de migration (règles “anti-drift”)

### Append-only
- Une migration **déjà appliquée** ne doit plus être modifiée en env partagé.
- En dev perso, tu peux bricoler… mais dès que CI/CD tourne, considère les scripts comme immuables.

### Idempotence
Pour que `db-migrate-dev` soit relançable sans “réinstaller les DB” :
- privilégier `IF NOT EXISTS` / `CREATE OR ALTER` (proc/fn/views) / `DROP ... IF EXISTS`
- éviter d’écrire des scripts qui explosent si l’objet existe déjà

> NB : La table journal empêche DbUp de rejouer un script “déjà OK”.
> L’idempotence est surtout utile pour les scripts utilitaires, les “CREATE OR ALTER”, et le confort quand tu reset.

---

## 4) Drift — ce qui peut encore arriver

Même avec `WithTransactionPerScript()`, tu peux avoir du drift si :
- un script fait des opérations non transactionnelles (rare en pratique)
- tu lances des modifications manuelles “à côté”

**Réflexe dev** : si tu t’es mis dans un état chelou, le plus rapide est souvent :
- drop/recreate les DB dev
- relancer `db-migrate-dev`

---

## 5) État attendu des scripts (référence)

### Directory
- `0001_init.sql` (schemas + tables minimales : cabinet/company/membership)

### Core
- `0001_init.sql` (core tables + indexes)
- `0002_finalize_posting_sproc.sql` (proc `core.usp_finalize_posting`)
- `0003_add_tenant_columns_children.sql` (tenant columns sur child tables)
- `0004_rls.sql` (schema `sec`, proc `sec.usp_set_tenant_context`, policy RLS)
- `0005_core_runtime_role.sql` (rôle `app_runtime` pour l’API)

---

## 6) Où mettre les sanity checks ?

Les checks “à rejouer 100 fois” ne doivent pas polluer l’historique des migrations.
➡️ Place-les dans `db/sanity/*.sql` et référence-les dans `docs/RUNBOOK.md`.
