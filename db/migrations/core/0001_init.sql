/*
  CORE DB — 0001_init.sql
  Pilot preprod-friendly accounting primitives.

  Tenancy columns: cabinet_id + company_id everywhere (API-friendly indexing).

  NOTE:
  - [rule] is a reserved keyword in SQL Server (legacy CREATE RULE), so the table name is escaped: core.[rule].
*/

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'core')
    EXEC('CREATE SCHEMA core');
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'sec')
    EXEC('CREATE SCHEMA sec');
GO

-- Parties (supplier/customer)
CREATE TABLE core.party (
    party_id UNIQUEIDENTIFIER NOT NULL,
    cabinet_id UNIQUEIDENTIFIER NOT NULL,
    company_id UNIQUEIDENTIFIER NOT NULL,

    party_kind CHAR(1) NOT NULL, -- 'S' supplier / 'C' customer
    display_name NVARCHAR(200) NOT NULL,
    vat_number NVARCHAR(32) NULL,

    created_at DATETIME2(3) NOT NULL CONSTRAINT DF_core_party_created_at DEFAULT SYSUTCDATETIME(),
    updated_at DATETIME2(3) NOT NULL CONSTRAINT DF_core_party_updated_at DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_core_party PRIMARY KEY (party_id),
    CONSTRAINT CK_core_party_kind CHECK (party_kind IN ('S','C'))
);
GO

CREATE INDEX IX_core_party_api
ON core.party (cabinet_id, company_id, display_name);
GO

-- Documents
CREATE TABLE core.document (
    document_id UNIQUEIDENTIFIER NOT NULL,
    cabinet_id UNIQUEIDENTIFIER NOT NULL,
    company_id UNIQUEIDENTIFIER NOT NULL,

    document_type NVARCHAR(32) NOT NULL,     -- Invoice / CreditNote / etc.
    external_ref NVARCHAR(80) NULL,          -- invoice number / reference
    document_hash VARBINARY(32) NULL,        -- SHA-256 stored as 32 bytes (optional)

    party_id UNIQUEIDENTIFIER NULL,          -- supplier/customer

    currency_code CHAR(3) NOT NULL,
    issue_date DATE NOT NULL,
    due_date DATE NULL,

    status NVARCHAR(24) NOT NULL CONSTRAINT DF_core_document_status DEFAULT 'DRAFT',

    total_net DECIMAL(18,2) NOT NULL CONSTRAINT DF_core_document_total_net DEFAULT (0),
    total_tax DECIMAL(18,2) NOT NULL CONSTRAINT DF_core_document_total_tax DEFAULT (0),
    total_gross DECIMAL(18,2) NOT NULL CONSTRAINT DF_core_document_total_gross DEFAULT (0),

    created_at DATETIME2(3) NOT NULL CONSTRAINT DF_core_document_created_at DEFAULT SYSUTCDATETIME(),
    updated_at DATETIME2(3) NOT NULL CONSTRAINT DF_core_document_updated_at DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_core_document PRIMARY KEY (document_id),
    CONSTRAINT FK_core_document_party FOREIGN KEY (party_id) REFERENCES core.party(party_id),

    CONSTRAINT CK_core_document_currency CHECK (currency_code NOT LIKE '%[^A-Z]%' AND LEN(currency_code) = 3),
    CONSTRAINT CK_core_document_dates CHECK (due_date IS NULL OR due_date >= issue_date),
    CONSTRAINT CK_core_document_amounts CHECK (total_net >= 0 AND total_tax >= 0 AND total_gross >= 0)
);
GO

-- Dedup (per tenant/company) when hash is provided
CREATE UNIQUE INDEX UX_core_document_dedup_hash
ON core.document (cabinet_id, company_id, document_hash)
WHERE document_hash IS NOT NULL;
GO

-- API-friendly index: tenant + company + date + status
CREATE INDEX IX_core_document_api
ON core.document (cabinet_id, company_id, issue_date DESC, status)
INCLUDE (document_type, external_ref, total_gross, currency_code);
GO

-- Document lines
CREATE TABLE core.document_line (
    line_id UNIQUEIDENTIFIER NOT NULL,
    document_id UNIQUEIDENTIFIER NOT NULL,

    line_no INT NOT NULL,
    description NVARCHAR(500) NULL,

    quantity DECIMAL(18,6) NOT NULL CONSTRAINT DF_core_docline_qty DEFAULT (1),
    unit_price DECIMAL(18,6) NOT NULL CONSTRAINT DF_core_docline_unit DEFAULT (0),
    line_amount DECIMAL(18,2) NOT NULL CONSTRAINT DF_core_docline_amount DEFAULT (0),

    vat_rate DECIMAL(5,2) NULL,            -- e.g. 20.00
    vat_amount DECIMAL(18,2) NOT NULL CONSTRAINT DF_core_docline_vat_amount DEFAULT (0),

    created_at DATETIME2(3) NOT NULL CONSTRAINT DF_core_docline_created_at DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_core_document_line PRIMARY KEY (line_id),
    CONSTRAINT FK_core_document_line_doc FOREIGN KEY (document_id) REFERENCES core.document(document_id),

    CONSTRAINT CK_core_docline_line_no CHECK (line_no > 0),
    CONSTRAINT CK_core_docline_amounts CHECK (quantity >= 0 AND unit_price >= 0 AND line_amount >= 0 AND vat_amount >= 0),
    CONSTRAINT CK_core_docline_vatrate CHECK (vat_rate IS NULL OR (vat_rate >= 0 AND vat_rate <= 100))
);
GO

CREATE INDEX IX_core_document_line_doc
ON core.document_line (document_id, line_no);
GO

-- Payment events
CREATE TABLE core.payment_event (
    payment_event_id UNIQUEIDENTIFIER NOT NULL,
    cabinet_id UNIQUEIDENTIFIER NOT NULL,
    company_id UNIQUEIDENTIFIER NOT NULL,

    document_id UNIQUEIDENTIFIER NULL,
    currency_code CHAR(3) NOT NULL,
    amount DECIMAL(18,2) NOT NULL,
    occurred_at DATETIME2(3) NOT NULL,
    method NVARCHAR(32) NULL,

    created_at DATETIME2(3) NOT NULL CONSTRAINT DF_core_payment_created_at DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_core_payment_event PRIMARY KEY (payment_event_id),
    CONSTRAINT FK_core_payment_doc FOREIGN KEY (document_id) REFERENCES core.document(document_id),
    CONSTRAINT CK_core_payment_currency CHECK (currency_code NOT LIKE '%[^A-Z]%' AND LEN(currency_code) = 3),
    CONSTRAINT CK_core_payment_amount CHECK (amount >= 0)
);
GO

CREATE INDEX IX_core_payment_api
ON core.payment_event (cabinet_id, company_id, occurred_at DESC);
GO

-- Posting (journal entries): header + lines
CREATE TABLE core.posting_header (
    posting_id UNIQUEIDENTIFIER NOT NULL,
    cabinet_id UNIQUEIDENTIFIER NOT NULL,
    company_id UNIQUEIDENTIFIER NOT NULL,

    source_document_id UNIQUEIDENTIFIER NULL,
    status NVARCHAR(16) NOT NULL CONSTRAINT DF_core_posting_status DEFAULT 'DRAFT', -- DRAFT/FINALIZED
    posted_on DATE NULL,

    created_at DATETIME2(3) NOT NULL CONSTRAINT DF_core_posting_created_at DEFAULT SYSUTCDATETIME(),
    finalized_at DATETIME2(3) NULL,

    CONSTRAINT PK_core_posting_header PRIMARY KEY (posting_id),
    CONSTRAINT FK_core_posting_source FOREIGN KEY (source_document_id) REFERENCES core.document(document_id),
    CONSTRAINT CK_core_posting_status CHECK (status IN ('DRAFT','FINALIZED'))
);
GO

CREATE INDEX IX_core_posting_api
ON core.posting_header (cabinet_id, company_id, created_at DESC, status);
GO

CREATE TABLE core.posting_line (
    posting_line_id UNIQUEIDENTIFIER NOT NULL,
    posting_id UNIQUEIDENTIFIER NOT NULL,

    line_no INT NOT NULL,
    account_code NVARCHAR(32) NOT NULL,
    label NVARCHAR(200) NULL,

    debit DECIMAL(18,2) NOT NULL CONSTRAINT DF_core_postline_debit DEFAULT (0),
    credit DECIMAL(18,2) NOT NULL CONSTRAINT DF_core_postline_credit DEFAULT (0),

    created_at DATETIME2(3) NOT NULL CONSTRAINT DF_core_postline_created_at DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_core_posting_line PRIMARY KEY (posting_line_id),
    CONSTRAINT FK_core_postline_posting FOREIGN KEY (posting_id) REFERENCES core.posting_header(posting_id),
    CONSTRAINT CK_core_postline_amounts CHECK (debit >= 0 AND credit >= 0 AND NOT (debit > 0 AND credit > 0)),
    CONSTRAINT CK_core_postline_line_no CHECK (line_no > 0)
);
GO

CREATE INDEX IX_core_posting_line_posting
ON core.posting_line (posting_id, line_no);
GO

-- Rules (versioned)
CREATE TABLE core.[rule] (
    rule_id UNIQUEIDENTIFIER NOT NULL,
    cabinet_id UNIQUEIDENTIFIER NOT NULL,
    company_id UNIQUEIDENTIFIER NOT NULL,

    rule_key NVARCHAR(64) NOT NULL,
    version INT NOT NULL,
    is_enabled BIT NOT NULL CONSTRAINT DF_core_rule_enabled DEFAULT (1),

    definition_json NVARCHAR(MAX) NOT NULL,
    created_at DATETIME2(3) NOT NULL CONSTRAINT DF_core_rule_created_at DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_core_rule PRIMARY KEY (rule_id),
    CONSTRAINT UQ_core_rule_key_version UNIQUE (cabinet_id, company_id, rule_key, version),
    CONSTRAINT CK_core_rule_version CHECK (version > 0)
);
GO

CREATE INDEX IX_core_rule_api
ON core.[rule] (cabinet_id, company_id, rule_key, version DESC);
GO

-- Exceptions + comments
CREATE TABLE core.exception_queue (
    exception_id UNIQUEIDENTIFIER NOT NULL,
    cabinet_id UNIQUEIDENTIFIER NOT NULL,
    company_id UNIQUEIDENTIFIER NOT NULL,

    entity_type NVARCHAR(64) NOT NULL,     -- Document / Posting / etc.
    entity_id UNIQUEIDENTIFIER NOT NULL,
    severity NVARCHAR(16) NOT NULL,        -- INFO/WARN/ERROR
    status NVARCHAR(16) NOT NULL CONSTRAINT DF_core_exception_status DEFAULT 'OPEN', -- OPEN/RESOLVED

    created_at DATETIME2(3) NOT NULL CONSTRAINT DF_core_exception_created_at DEFAULT SYSUTCDATETIME(),
    resolved_at DATETIME2(3) NULL,

    CONSTRAINT PK_core_exception PRIMARY KEY (exception_id),
    CONSTRAINT CK_core_exception_sev CHECK (severity IN ('INFO','WARN','ERROR')),
    CONSTRAINT CK_core_exception_status CHECK (status IN ('OPEN','RESOLVED'))
);
GO

CREATE INDEX IX_core_exception_api
ON core.exception_queue (cabinet_id, company_id, status, created_at DESC);
GO

CREATE TABLE core.exception_comment (
    exception_comment_id UNIQUEIDENTIFIER NOT NULL,
    exception_id UNIQUEIDENTIFIER NOT NULL,
    author_oid UNIQUEIDENTIFIER NULL,
    comment_text NVARCHAR(2000) NOT NULL,
    created_at DATETIME2(3) NOT NULL CONSTRAINT DF_core_exception_comment_created_at DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_core_exception_comment PRIMARY KEY (exception_comment_id),
    CONSTRAINT FK_core_exception_comment_ex FOREIGN KEY (exception_id) REFERENCES core.exception_queue(exception_id)
);
GO

CREATE INDEX IX_core_exception_comment
ON core.exception_comment (exception_id, created_at DESC);
GO

-- Audit
CREATE TABLE core.audit_event (
    audit_event_id UNIQUEIDENTIFIER NOT NULL,
    cabinet_id UNIQUEIDENTIFIER NOT NULL,
    company_id UNIQUEIDENTIFIER NOT NULL,

    actor_oid UNIQUEIDENTIFIER NULL,
    action NVARCHAR(64) NOT NULL,
    entity_type NVARCHAR(64) NULL,
    entity_id UNIQUEIDENTIFIER NULL,
    detail_json NVARCHAR(MAX) NULL,

    occurred_at DATETIME2(3) NOT NULL CONSTRAINT DF_core_audit_occurred_at DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_core_audit_event PRIMARY KEY (audit_event_id)
);
GO

CREATE INDEX IX_core_audit_api
ON core.audit_event (cabinet_id, company_id, occurred_at DESC);
GO
