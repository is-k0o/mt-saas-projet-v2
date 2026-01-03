/*
  0004_rls.sql
  Row-Level Security (RLS) via SESSION_CONTEXT('cabinet_id','company_id')
  Option B: all tables now have cabinet_id + company_id (incl. child tables).
*/

-- Ensure schema sec exists
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'sec')
    EXEC('CREATE SCHEMA sec AUTHORIZATION dbo;');
GO

-- Optional bypass role (useful for ops/ETL later)
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'sec_rls_bypass' AND type = 'R')
    CREATE ROLE sec_rls_bypass AUTHORIZATION dbo;
GO

-- Tenant context setter
CREATE OR ALTER PROCEDURE sec.usp_set_tenant_context
    @cabinet_id UNIQUEIDENTIFIER,
    @company_id UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    IF @cabinet_id IS NULL
        THROW 50020, 'cabinet_id is required', 1;

    IF @company_id IS NULL
        THROW 50021, 'company_id is required', 1;

    -- read_only = 0 : évite les galères avec le connection pooling pour l’instant
    EXEC sys.sp_set_session_context @key = N'cabinet_id', @value = @cabinet_id, @read_only = 0;
    EXEC sys.sp_set_session_context @key = N'company_id', @value = @company_id, @read_only = 0;
END
GO

-- Predicate function (SCHEMABINDING required)
CREATE OR ALTER FUNCTION sec.fn_tenant_predicate(
    @cabinet_id UNIQUEIDENTIFIER,
    @company_id UNIQUEIDENTIFIER
)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
    SELECT 1 AS fn_access_result
    WHERE
        -- Allow admins / migrations / ops
        IS_MEMBER('db_owner') = 1
        OR IS_ROLEMEMBER('sec_rls_bypass') = 1
        OR (
            @cabinet_id = TRY_CONVERT(UNIQUEIDENTIFIER, SESSION_CONTEXT(N'cabinet_id'))
            AND @company_id = TRY_CONVERT(UNIQUEIDENTIFIER, SESSION_CONTEXT(N'company_id'))
        );
GO

-- Relançable sans conflit
DROP SECURITY POLICY IF EXISTS sec.CompanySecurityPolicy;
GO

CREATE SECURITY POLICY sec.CompanySecurityPolicy
    -- FILTER predicates (read isolation)
    ADD FILTER PREDICATE sec.fn_tenant_predicate(cabinet_id, company_id) ON core.party,
    ADD FILTER PREDICATE sec.fn_tenant_predicate(cabinet_id, company_id) ON core.[rule],
    ADD FILTER PREDICATE sec.fn_tenant_predicate(cabinet_id, company_id) ON core.document,
    ADD FILTER PREDICATE sec.fn_tenant_predicate(cabinet_id, company_id) ON core.document_line,
    ADD FILTER PREDICATE sec.fn_tenant_predicate(cabinet_id, company_id) ON core.payment_event,
    ADD FILTER PREDICATE sec.fn_tenant_predicate(cabinet_id, company_id) ON core.posting_header,
    ADD FILTER PREDICATE sec.fn_tenant_predicate(cabinet_id, company_id) ON core.posting_line,
    ADD FILTER PREDICATE sec.fn_tenant_predicate(cabinet_id, company_id) ON core.exception_queue,
    ADD FILTER PREDICATE sec.fn_tenant_predicate(cabinet_id, company_id) ON core.exception_comment,
    ADD FILTER PREDICATE sec.fn_tenant_predicate(cabinet_id, company_id) ON core.audit_event,

    -- BLOCK predicates (write isolation) : ça va “casser” si tu tries d’écrire sans contexte → voulu
    ADD BLOCK PREDICATE sec.fn_tenant_predicate(cabinet_id, company_id) ON core.party AFTER INSERT,
    ADD BLOCK PREDICATE sec.fn_tenant_predicate(cabinet_id, company_id) ON core.party AFTER UPDATE,
    ADD BLOCK PREDICATE sec.fn_tenant_predicate(cabinet_id, company_id) ON core.party BEFORE DELETE,

    ADD BLOCK PREDICATE sec.fn_tenant_predicate(cabinet_id, company_id) ON core.[rule] AFTER INSERT,
    ADD BLOCK PREDICATE sec.fn_tenant_predicate(cabinet_id, company_id) ON core.[rule] AFTER UPDATE,
    ADD BLOCK PREDICATE sec.fn_tenant_predicate(cabinet_id, company_id) ON core.[rule] BEFORE DELETE,

    ADD BLOCK PREDICATE sec.fn_tenant_predicate(cabinet_id, company_id) ON core.document AFTER INSERT,
    ADD BLOCK PREDICATE sec.fn_tenant_predicate(cabinet_id, company_id) ON core.document AFTER UPDATE,
    ADD BLOCK PREDICATE sec.fn_tenant_predicate(cabinet_id, company_id) ON core.document BEFORE DELETE,

    ADD BLOCK PREDICATE sec.fn_tenant_predicate(cabinet_id, company_id) ON core.document_line AFTER INSERT,
    ADD BLOCK PREDICATE sec.fn_tenant_predicate(cabinet_id, company_id) ON core.document_line AFTER UPDATE,
    ADD BLOCK PREDICATE sec.fn_tenant_predicate(cabinet_id, company_id) ON core.document_line BEFORE DELETE,

    ADD BLOCK PREDICATE sec.fn_tenant_predicate(cabinet_id, company_id) ON core.payment_event AFTER INSERT,
    ADD BLOCK PREDICATE sec.fn_tenant_predicate(cabinet_id, company_id) ON core.payment_event AFTER UPDATE,
    ADD BLOCK PREDICATE sec.fn_tenant_predicate(cabinet_id, company_id) ON core.payment_event BEFORE DELETE,

    ADD BLOCK PREDICATE sec.fn_tenant_predicate(cabinet_id, company_id) ON core.posting_header AFTER INSERT,
    ADD BLOCK PREDICATE sec.fn_tenant_predicate(cabinet_id, company_id) ON core.posting_header AFTER UPDATE,
    ADD BLOCK PREDICATE sec.fn_tenant_predicate(cabinet_id, company_id) ON core.posting_header BEFORE DELETE,

    ADD BLOCK PREDICATE sec.fn_tenant_predicate(cabinet_id, company_id) ON core.posting_line AFTER INSERT,
    ADD BLOCK PREDICATE sec.fn_tenant_predicate(cabinet_id, company_id) ON core.posting_line AFTER UPDATE,
    ADD BLOCK PREDICATE sec.fn_tenant_predicate(cabinet_id, company_id) ON core.posting_line BEFORE DELETE,

    ADD BLOCK PREDICATE sec.fn_tenant_predicate(cabinet_id, company_id) ON core.exception_queue AFTER INSERT,
    ADD BLOCK PREDICATE sec.fn_tenant_predicate(cabinet_id, company_id) ON core.exception_queue AFTER UPDATE,
    ADD BLOCK PREDICATE sec.fn_tenant_predicate(cabinet_id, company_id) ON core.exception_queue BEFORE DELETE,

    ADD BLOCK PREDICATE sec.fn_tenant_predicate(cabinet_id, company_id) ON core.exception_comment AFTER INSERT,
    ADD BLOCK PREDICATE sec.fn_tenant_predicate(cabinet_id, company_id) ON core.exception_comment AFTER UPDATE,
    ADD BLOCK PREDICATE sec.fn_tenant_predicate(cabinet_id, company_id) ON core.exception_comment BEFORE DELETE,

    ADD BLOCK PREDICATE sec.fn_tenant_predicate(cabinet_id, company_id) ON core.audit_event AFTER INSERT,
    ADD BLOCK PREDICATE sec.fn_tenant_predicate(cabinet_id, company_id) ON core.audit_event AFTER UPDATE,
    ADD BLOCK PREDICATE sec.fn_tenant_predicate(cabinet_id, company_id) ON core.audit_event BEFORE DELETE
WITH (STATE = ON);
GO
