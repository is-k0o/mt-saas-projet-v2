/*
  core_sanity_check.sql
  --------------------
  Quick sanity checks for the Core DB after migrations (tenant columns + RLS + basic consistency).

  Output: a small report (OK/WARN/KO) + helpful details.

  Notes:
  - Some checks depend on having data; if the DB is empty, you'll get WARN/KO for those, which is normal.
  - To really validate RLS behavior, run this script after creating a low-priv test user (WITHOUT LOGIN),
    e.g. 'api_local'. See docs/RUNBOOK.md.
*/

SET NOCOUNT ON;

DECLARE @checks TABLE (
    check_name NVARCHAR(200) NOT NULL,
    status     NVARCHAR(10)  NOT NULL,
    details    NVARCHAR(4000) NULL
);

DECLARE @failCount INT = 0;

-------------------------------------------------------------------------------
-- 0) Helpers
-------------------------------------------------------------------------------
DECLARE @schema_sec_id INT = SCHEMA_ID('sec');

-------------------------------------------------------------------------------
-- 1) RLS objects present
-------------------------------------------------------------------------------
DECLARE @sec_schema_exists BIT = CASE WHEN @schema_sec_id IS NOT NULL THEN 1 ELSE 0 END;
DECLARE @proc_exists BIT = CASE WHEN OBJECT_ID('sec.usp_set_tenant_context', 'P') IS NOT NULL THEN 1 ELSE 0 END;
DECLARE @policy_exists BIT = CASE WHEN EXISTS (
    SELECT 1
    FROM sys.security_policies p
    WHERE p.schema_id = @schema_sec_id
) THEN 1 ELSE 0 END;

DECLARE @policy_name SYSNAME = (
    SELECT TOP 1 p.name
    FROM sys.security_policies p
    WHERE p.schema_id = @schema_sec_id
    ORDER BY p.name
);

DECLARE @policy_enabled BIT = CASE WHEN EXISTS (
    SELECT 1
    FROM sys.security_policies p
    WHERE p.schema_id = @schema_sec_id
      AND p.name = @policy_name
      AND p.is_enabled = 1
) THEN 1 ELSE 0 END;

INSERT INTO @checks(check_name, status, details)
SELECT
    'RLS objects present (schema + proc + policy)',
    CASE WHEN @sec_schema_exists = 1 AND @proc_exists = 1 AND @policy_exists = 1 THEN 'OK' ELSE 'KO' END,
    CONCAT('sec_schema=', @sec_schema_exists, ' | proc=', @proc_exists, ' | policy_exists=', @policy_exists,
           CASE WHEN @policy_exists = 1 THEN CONCAT(' | policy_name=', @policy_name) ELSE '' END);

IF NOT (@sec_schema_exists = 1 AND @proc_exists = 1 AND @policy_exists = 1)
    SET @failCount += 1;

INSERT INTO @checks(check_name, status, details)
SELECT
    'Security policy enabled (informational)',
    CASE WHEN @policy_exists = 0 THEN 'KO'
         WHEN @policy_enabled = 1 THEN 'OK'
         ELSE 'WARN'
    END,
    CONCAT('policy_name=', COALESCE(@policy_name, '<none>'), ' | enabled=', @policy_enabled);

IF @policy_exists = 0
    SET @failCount += 1;

-------------------------------------------------------------------------------
-- 2) Tenant columns exist + NOT NULL (core tables)
-------------------------------------------------------------------------------
DECLARE @expected TABLE (schema_name SYSNAME, table_name SYSNAME);

-- Parent tables already include tenant columns in 0001
INSERT INTO @expected(schema_name, table_name)
VALUES
('core','document'),
('core','posting_header'),
('core','exception_queue'),
('core','payment_event'),
('core','party'),
('core','audit_event'),
('core','rule');

-- Child tables get tenant columns in 0003
INSERT INTO @expected(schema_name, table_name)
VALUES
('core','document_line'),
('core','posting_line'),
('core','exception_comment');

IF OBJECT_ID('tempdb..#cols') IS NOT NULL DROP TABLE #cols;
CREATE TABLE #cols (
    schema_name SYSNAME NOT NULL,
    table_name  SYSNAME NOT NULL,
    has_cabinet BIT NOT NULL,
    has_company BIT NOT NULL,
    cabinet_notnull BIT NOT NULL,
    company_notnull BIT NOT NULL
);

INSERT INTO #cols(schema_name, table_name, has_cabinet, has_company, cabinet_notnull, company_notnull)
SELECT
    e.schema_name,
    e.table_name,
    MAX(CASE WHEN c.name = 'cabinet_id' THEN 1 ELSE 0 END) AS has_cabinet,
    MAX(CASE WHEN c.name = 'company_id' THEN 1 ELSE 0 END) AS has_company,
    MAX(CASE WHEN c.name = 'cabinet_id' AND c.is_nullable = 0 THEN 1 ELSE 0 END) AS cabinet_notnull,
    MAX(CASE WHEN c.name = 'company_id' AND c.is_nullable = 0 THEN 1 ELSE 0 END) AS company_notnull
FROM @expected e
LEFT JOIN sys.tables t
    ON t.name = e.table_name
   AND t.schema_id = SCHEMA_ID(e.schema_name)
LEFT JOIN sys.columns c
    ON c.object_id = t.object_id
   AND c.name IN ('cabinet_id','company_id')
GROUP BY e.schema_name, e.table_name;

-- Report per-table
INSERT INTO @checks(check_name, status, details)
SELECT
    CONCAT('Tenant columns exist + NOT NULL: ', schema_name, '.', table_name),
    CASE WHEN has_cabinet = 1 AND has_company = 1 AND cabinet_notnull = 1 AND company_notnull = 1 THEN 'OK' ELSE 'KO' END,
    CONCAT('cab(', has_cabinet, '/', cabinet_notnull, ') | comp(', has_company, '/', company_notnull, ')')
FROM #cols
ORDER BY schema_name, table_name;

IF EXISTS (
    SELECT 1 FROM #cols
    WHERE has_cabinet <> 1 OR has_company <> 1 OR cabinet_notnull <> 1 OR company_notnull <> 1
)
    SET @failCount += 1;

-------------------------------------------------------------------------------
-- 3) NULL rows check (should be 0) — only for tables that have both columns
-------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#nulls') IS NOT NULL DROP TABLE #nulls;
CREATE TABLE #nulls(tbl SYSNAME NOT NULL, null_rows BIGINT NOT NULL);

DECLARE @sql NVARCHAR(MAX) = N'';

SELECT @sql = @sql +
    N'INSERT INTO #nulls(tbl, null_rows) ' +
    N'SELECT N''' + REPLACE(CONCAT(schema_name, '.', table_name),'''','''''') + N''', COUNT_BIG(*) ' +
    N'FROM ' + QUOTENAME(schema_name) + N'.' + QUOTENAME(table_name) + N' ' +
    N'WHERE cabinet_id IS NULL OR company_id IS NULL;' + CHAR(10)
FROM #cols
WHERE has_cabinet = 1 AND has_company = 1;

EXEC sys.sp_executesql @sql;

DECLARE @total_nulls BIGINT = (SELECT COALESCE(SUM(null_rows), 0) FROM #nulls);

INSERT INTO @checks(check_name, status, details)
VALUES (
    'No NULL tenant values in core tables',
    CASE WHEN @total_nulls = 0 THEN 'OK' ELSE 'KO' END,
    CONCAT('total_nulls=', @total_nulls)
);

IF @total_nulls <> 0
    SET @failCount += 1;

-------------------------------------------------------------------------------
-- 4) Pick a sample tenant (informational)
-------------------------------------------------------------------------------
DECLARE @cab UNIQUEIDENTIFIER = NULL, @comp UNIQUEIDENTIFIER = NULL;

SELECT TOP 1 @cab = cabinet_id, @comp = company_id FROM core.audit_event;
IF @comp IS NULL SELECT TOP 1 @cab = cabinet_id, @comp = company_id FROM core.document;
IF @comp IS NULL SELECT TOP 1 @cab = cabinet_id, @comp = company_id FROM core.party;
IF @comp IS NULL SELECT TOP 1 @cab = cabinet_id, @comp = company_id FROM core.posting_header;

INSERT INTO @checks(check_name, status, details)
VALUES (
    'Sample tenant selected (for RLS test)',
    CASE WHEN @cab IS NOT NULL AND @comp IS NOT NULL THEN 'OK' ELSE 'KO' END,
    CONCAT('cabinet_id=', COALESCE(CONVERT(NVARCHAR(36), @cab), 'NULL'),
           ' | company_id=', COALESCE(CONVERT(NVARCHAR(36), @comp), 'NULL'),
           CASE WHEN @cab IS NULL OR @comp IS NULL THEN ' | (No data yet?)' ELSE '' END)
);

-------------------------------------------------------------------------------
-- 5) Child → Parent tenant consistency
-------------------------------------------------------------------------------
-- document_line -> document
IF OBJECT_ID('core.document_line','U') IS NOT NULL
BEGIN
    DECLARE @m1 BIGINT = (
        SELECT COUNT_BIG(*)
        FROM core.document_line dl
        JOIN core.document d ON d.document_id = dl.document_id
        WHERE dl.cabinet_id <> d.cabinet_id OR dl.company_id <> d.company_id
    );

    INSERT INTO @checks(check_name, status, details)
    VALUES ('Tenant consistency: document_line -> document', CASE WHEN @m1 = 0 THEN 'OK' ELSE 'KO' END, CONCAT('mismatch_rows=', @m1));

    IF @m1 <> 0 SET @failCount += 1;
END

-- posting_line -> posting_header
IF OBJECT_ID('core.posting_line','U') IS NOT NULL
BEGIN
    DECLARE @m2 BIGINT = (
        SELECT COUNT_BIG(*)
        FROM core.posting_line pl
        JOIN core.posting_header ph ON ph.posting_id = pl.posting_id
        WHERE pl.cabinet_id <> ph.cabinet_id OR pl.company_id <> ph.company_id
    );

    INSERT INTO @checks(check_name, status, details)
    VALUES ('Tenant consistency: posting_line -> posting_header', CASE WHEN @m2 = 0 THEN 'OK' ELSE 'KO' END, CONCAT('mismatch_rows=', @m2));

    IF @m2 <> 0 SET @failCount += 1;
END

-- exception_comment -> exception_queue
IF OBJECT_ID('core.exception_comment','U') IS NOT NULL
BEGIN
    DECLARE @m3 BIGINT = (
        SELECT COUNT_BIG(*)
        FROM core.exception_comment ec
        JOIN core.exception_queue eq ON eq.exception_id = ec.exception_id
        WHERE ec.cabinet_id <> eq.cabinet_id OR ec.company_id <> eq.company_id
    );

    INSERT INTO @checks(check_name, status, details)
    VALUES ('Tenant consistency: exception_comment -> exception_queue', CASE WHEN @m3 = 0 THEN 'OK' ELSE 'KO' END, CONCAT('mismatch_rows=', @m3));

    IF @m3 <> 0 SET @failCount += 1;
END

-------------------------------------------------------------------------------
-- 6) RLS behavior check (only if a low-priv test user exists)
-------------------------------------------------------------------------------
DECLARE @api_user_exists BIT = CASE WHEN EXISTS (
    SELECT 1
    FROM sys.database_principals
    WHERE name = 'api_local'
      AND type_desc IN ('SQL_USER','EXTERNAL_USER')
) THEN 1 ELSE 0 END;

IF @api_user_exists = 1 AND @cab IS NOT NULL AND @comp IS NOT NULL
BEGIN
    DECLARE @noctx BIGINT = 0;
    DECLARE @ctx BIGINT = 0;

    EXECUTE AS USER = 'api_local';

    -- Without context: should be 0 visible rows (defense-in-depth)
    SELECT @noctx =
        COALESCE((SELECT COUNT_BIG(*) FROM core.document), 0)
      + COALESCE((SELECT COUNT_BIG(*) FROM core.posting_header), 0)
      + COALESCE((SELECT COUNT_BIG(*) FROM core.exception_queue), 0);

    EXEC sec.usp_set_tenant_context @cabinet_id = @cab, @company_id = @comp;

    -- With context: should be >= 0; ideally > 0 if you have data for this tenant
    SELECT @ctx =
        COALESCE((SELECT COUNT_BIG(*) FROM core.document), 0)
      + COALESCE((SELECT COUNT_BIG(*) FROM core.posting_header), 0)
      + COALESCE((SELECT COUNT_BIG(*) FROM core.exception_queue), 0);

    REVERT;

    INSERT INTO @checks(check_name, status, details)
    VALUES (
        'RLS behavior (using api_local) — no_ctx should be 0',
        CASE WHEN @noctx = 0 THEN 'OK' ELSE 'KO' END,
        CONCAT('sum_no_ctx=', @noctx, ' | sum_with_ctx=', @ctx)
    );

    IF @noctx <> 0 SET @failCount += 1;

    INSERT INTO @checks(check_name, status, details)
    VALUES (
        'RLS behavior (using api_local) — with_ctx informational',
        CASE WHEN @ctx > 0 THEN 'OK' ELSE 'WARN' END,
        CONCAT('sum_with_ctx=', @ctx, ' (WARN is normal if tenant has no data yet)')
    );
END
ELSE
BEGIN
    INSERT INTO @checks(check_name, status, details)
    VALUES (
        'RLS behavior (using api_local)',
        'WARN',
        CASE
            WHEN @api_user_exists = 0 THEN 'api_local user not found. Create it (WITHOUT LOGIN) to test RLS like the API.'
            WHEN @cab IS NULL OR @comp IS NULL THEN 'No sample tenant found (DB empty?). Seed some data first.'
            ELSE 'Skipped.'
        END
    );
END

-------------------------------------------------------------------------------
-- 7) Final report
-------------------------------------------------------------------------------
SELECT check_name, status, details
FROM @checks
ORDER BY
    CASE status WHEN 'KO' THEN 1 WHEN 'WARN' THEN 2 ELSE 3 END,
    check_name;

-- Optional: return a non-zero “hint” (manual reading) - not used by ADS
SELECT @failCount AS fail_count;
