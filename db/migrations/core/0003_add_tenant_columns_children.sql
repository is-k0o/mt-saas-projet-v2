/*
  0003_add_tenant_columns_children.sql
  Option B: add cabinet_id + company_id to child tables for simpler RLS + API indexing.
*/

-------------------------
-- core.document_line
-------------------------
IF COL_LENGTH('core.document_line', 'cabinet_id') IS NULL
    ALTER TABLE core.document_line ADD cabinet_id UNIQUEIDENTIFIER NULL;
GO
IF COL_LENGTH('core.document_line', 'company_id') IS NULL
    ALTER TABLE core.document_line ADD company_id UNIQUEIDENTIFIER NULL;
GO

UPDATE dl
SET
    dl.cabinet_id = d.cabinet_id,
    dl.company_id = d.company_id
FROM core.document_line dl
JOIN core.document d ON d.document_id = dl.document_id
WHERE dl.cabinet_id IS NULL OR dl.company_id IS NULL;
GO

IF EXISTS (SELECT 1 FROM core.document_line WHERE cabinet_id IS NULL OR company_id IS NULL)
    THROW 50010, 'Backfill failed: core.document_line has NULL tenant columns', 1;
GO

IF EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID('core.document_line') AND name = 'cabinet_id' AND is_nullable = 1
)
    ALTER TABLE core.document_line ALTER COLUMN cabinet_id UNIQUEIDENTIFIER NOT NULL;
GO

IF EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID('core.document_line') AND name = 'company_id' AND is_nullable = 1
)
    ALTER TABLE core.document_line ALTER COLUMN company_id UNIQUEIDENTIFIER NOT NULL;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('core.document_line') AND name = 'IX_core_document_line_tenant'
)
BEGIN
    CREATE INDEX IX_core_document_line_tenant
    ON core.document_line (cabinet_id, company_id, document_id, line_no);
END
GO

-------------------------
-- core.posting_line
-------------------------
IF COL_LENGTH('core.posting_line', 'cabinet_id') IS NULL
    ALTER TABLE core.posting_line ADD cabinet_id UNIQUEIDENTIFIER NULL;
GO
IF COL_LENGTH('core.posting_line', 'company_id') IS NULL
    ALTER TABLE core.posting_line ADD company_id UNIQUEIDENTIFIER NULL;
GO

UPDATE pl
SET
    pl.cabinet_id = ph.cabinet_id,
    pl.company_id = ph.company_id
FROM core.posting_line pl
JOIN core.posting_header ph ON ph.posting_id = pl.posting_id
WHERE pl.cabinet_id IS NULL OR pl.company_id IS NULL;
GO

IF EXISTS (SELECT 1 FROM core.posting_line WHERE cabinet_id IS NULL OR company_id IS NULL)
    THROW 50011, 'Backfill failed: core.posting_line has NULL tenant columns', 1;
GO

IF EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID('core.posting_line') AND name = 'cabinet_id' AND is_nullable = 1
)
    ALTER TABLE core.posting_line ALTER COLUMN cabinet_id UNIQUEIDENTIFIER NOT NULL;
GO

IF EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID('core.posting_line') AND name = 'company_id' AND is_nullable = 1
)
    ALTER TABLE core.posting_line ALTER COLUMN company_id UNIQUEIDENTIFIER NOT NULL;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('core.posting_line') AND name = 'IX_core_posting_line_tenant'
)
BEGIN
    CREATE INDEX IX_core_posting_line_tenant
    ON core.posting_line (cabinet_id, company_id, posting_id, line_no);
END
GO

-------------------------
-- core.exception_comment
-------------------------
IF COL_LENGTH('core.exception_comment', 'cabinet_id') IS NULL
    ALTER TABLE core.exception_comment ADD cabinet_id UNIQUEIDENTIFIER NULL;
GO
IF COL_LENGTH('core.exception_comment', 'company_id') IS NULL
    ALTER TABLE core.exception_comment ADD company_id UNIQUEIDENTIFIER NULL;
GO

UPDATE ec
SET
    ec.cabinet_id = eq.cabinet_id,
    ec.company_id = eq.company_id
FROM core.exception_comment ec
JOIN core.exception_queue eq ON eq.exception_id = ec.exception_id
WHERE ec.cabinet_id IS NULL OR ec.company_id IS NULL;
GO

IF EXISTS (SELECT 1 FROM core.exception_comment WHERE cabinet_id IS NULL OR company_id IS NULL)
    THROW 50012, 'Backfill failed: core.exception_comment has NULL tenant columns', 1;
GO

IF EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID('core.exception_comment') AND name = 'cabinet_id' AND is_nullable = 1
)
    ALTER TABLE core.exception_comment ALTER COLUMN cabinet_id UNIQUEIDENTIFIER NOT NULL;
GO

IF EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID('core.exception_comment') AND name = 'company_id' AND is_nullable = 1
)
    ALTER TABLE core.exception_comment ALTER COLUMN company_id UNIQUEIDENTIFIER NOT NULL;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('core.exception_comment') AND name = 'IX_core_exception_comment_tenant'
)
BEGIN
    CREATE INDEX IX_core_exception_comment_tenant
    ON core.exception_comment (cabinet_id, company_id, exception_id, created_at DESC);
END
GO
