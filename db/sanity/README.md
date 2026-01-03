# Sanity checks (manual)

Ces scripts ne sont **pas** des migrations DbUp.
Ils servent à valider rapidement que l’état DB est cohérent après un déploiement (migrations), et à diagnostiquer les erreurs.

## Core
- `core_sanity_check.sql` : rapport OK/WARN/KO (tenant columns, RLS objects, policy enabled, cohérence child→parent).

### Pour tester RLS “comme l’API”
Le script peut aussi exécuter un test RLS si un user `api_local` existe.
En dev, tu peux le créer ainsi :

```sql
CREATE USER [api_local] WITHOUT LOGIN;
EXEC sp_addrolemember 'app_runtime', 'api_local';
```

Puis relancer `core_sanity_check.sql`.

> ⚠️ RLS peut être contourné par un compte `db_owner` : les tests les plus fiables sont faits en “low-priv”.
