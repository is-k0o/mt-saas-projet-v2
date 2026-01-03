/* 0005_core_runtime_role.sql
   Stable runtime role for the API (works with SQL auth dev + AAD/MI later)
*/

SET NOCOUNT ON;

-- 1) Role
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'app_runtime' AND type = 'R')
BEGIN
    CREATE ROLE app_runtime AUTHORIZATION dbo;
END
GO

-- 2) Must be able to set tenant context
GRANT EXECUTE ON OBJECT::sec.usp_set_tenant_context TO app_runtime;
GO

-- 3) Data access (start permissive, you can tighten later)
-- If you want safer-by-default, remove DELETE for now.
GRANT SELECT, INSERT, UPDATE ON SCHEMA::core TO app_runtime;
GO

-- Optional: if you want the API to be able to execute other security procs later
-- GRANT EXECUTE ON SCHEMA::sec TO app_runtime;
-- GO
