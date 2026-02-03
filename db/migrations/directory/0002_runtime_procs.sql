/*
  DIRECTORY DB — 0002_runtime_procs.sql
  Runtime contract:
   - resolve slugs -> ids
   - check membership -> allowed + effective role
   - list my companies -> for GET /me/companies
*/

SET NOCOUNT ON;
GO

-- Ensure schema dir exists (defensive)
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'dir')
    EXEC('CREATE SCHEMA dir');
GO


/* ------------------------------------------------------------
   dir.usp_resolve_company
   Input : cabinet_slug + company_slug
   Output: cabinet_id + company_id (+ echoes slugs, display names)
------------------------------------------------------------ */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'dir.usp_resolve_company') AND type IN (N'P', N'PC'))
    EXEC('CREATE PROCEDURE dir.usp_resolve_company AS BEGIN SET NOCOUNT ON; END');
GO

ALTER PROCEDURE dir.usp_resolve_company
    @cabinet_slug NVARCHAR(64),
    @company_slug NVARCHAR(64)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @cabinet_slug_norm NVARCHAR(64) = LOWER(@cabinet_slug);
    DECLARE @company_slug_norm NVARCHAR(64) = LOWER(@company_slug);

    SELECT TOP (1)
        c.cabinet_id,
        co.company_id,
        c.cabinet_slug,
        co.company_slug,
        c.display_name  AS cabinet_display_name,
        co.display_name AS company_display_name
    FROM dir.cabinet c
    INNER JOIN dir.company co
        ON co.cabinet_id = c.cabinet_id
    WHERE
        c.cabinet_slug = @cabinet_slug_norm
        AND co.company_slug = @company_slug_norm;
END
GO


/* ------------------------------------------------------------
   dir.usp_check_membership
   Input : user_oid + cabinet_id + company_id
   Output: is_allowed + role_code + role_scope
   Notes : picks the highest privilege role among:
           CabinetAdmin > CompanyAdmin > CabinetUser > CompanyUser
------------------------------------------------------------ */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'dir.usp_check_membership') AND type IN (N'P', N'PC'))
    EXEC('CREATE PROCEDURE dir.usp_check_membership AS BEGIN SET NOCOUNT ON; END');
GO

ALTER PROCEDURE dir.usp_check_membership
    @user_oid UNIQUEIDENTIFIER,
    @cabinet_id UNIQUEIDENTIFIER,
    @company_id UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH m AS (
        SELECT
            role_code,
            role_scope = CASE WHEN company_id IS NULL THEN 'CABINET' ELSE 'COMPANY' END,
            role_rank = CASE role_code
                WHEN 'CabinetAdmin' THEN 40
                WHEN 'CompanyAdmin' THEN 30
                WHEN 'CabinetUser'  THEN 20
                WHEN 'CompanyUser'  THEN 10
                ELSE 0
            END
        FROM dir.user_membership
        WHERE
            user_oid = @user_oid
            AND cabinet_id = @cabinet_id
            AND (company_id = @company_id OR company_id IS NULL)
    )
    SELECT
        is_allowed = CAST(CASE WHEN EXISTS (SELECT 1 FROM m) THEN 1 ELSE 0 END AS bit),
        role_code  = (SELECT TOP (1) role_code  FROM m ORDER BY role_rank DESC),
        role_scope = (SELECT TOP (1) role_scope FROM m ORDER BY role_rank DESC);
END
GO


/* ------------------------------------------------------------
   dir.usp_get_my_companies
   Input : user_oid
   Output: list of accessible companies (ids + slugs + display names + effective role)
   Notes : expands cabinet-level memberships to all companies under the cabinet,
           then picks the highest privilege per (cabinet_id, company_id).
------------------------------------------------------------ */

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'dir.usp_get_my_companies') AND type IN (N'P', N'PC'))
    EXEC('CREATE PROCEDURE dir.usp_get_my_companies AS BEGIN SET NOCOUNT ON; END');
GO

ALTER PROCEDURE dir.usp_get_my_companies
    @user_oid UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH expanded AS (
        -- Company-level memberships (already scoped)
        SELECT
            um.cabinet_id,
            um.company_id,
            um.role_code,
            role_rank = CASE um.role_code
                WHEN 'CabinetAdmin' THEN 40
                WHEN 'CompanyAdmin' THEN 30
                WHEN 'CabinetUser'  THEN 20
                WHEN 'CompanyUser'  THEN 10
                ELSE 0
            END
        FROM dir.user_membership um
        WHERE um.user_oid = @user_oid
          AND um.company_id IS NOT NULL

        UNION ALL

        -- Cabinet-level memberships expanded to all companies of the cabinet
        SELECT
            um.cabinet_id,
            co.company_id,
            um.role_code,
            role_rank = CASE um.role_code
                WHEN 'CabinetAdmin' THEN 40
                WHEN 'CompanyAdmin' THEN 30
                WHEN 'CabinetUser'  THEN 20
                WHEN 'CompanyUser'  THEN 10
                ELSE 0
            END
        FROM dir.user_membership um
        INNER JOIN dir.company co
            ON co.cabinet_id = um.cabinet_id
        WHERE um.user_oid = @user_oid
          AND um.company_id IS NULL
    ),
    ranked AS (
        SELECT
            cabinet_id,
            company_id,
            role_code,
            role_rank,
            rn = ROW_NUMBER() OVER (
                PARTITION BY cabinet_id, company_id
                ORDER BY role_rank DESC
            )
        FROM expanded
    )
    SELECT
        c.cabinet_id,
        c.cabinet_slug,
        c.display_name  AS cabinet_display_name,
        co.company_id,
        co.company_slug,
        co.display_name AS company_display_name,
        r.role_code     AS effective_role_code
    FROM ranked r
    INNER JOIN dir.cabinet c
        ON c.cabinet_id = r.cabinet_id
    INNER JOIN dir.company co
        ON co.company_id = r.company_id
    WHERE r.rn = 1
    ORDER BY c.cabinet_slug, co.company_slug;
END
GO
