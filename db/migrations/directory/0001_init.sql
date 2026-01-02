/*
  DIRECTORY DB — 0001_init.sql
  Minimal directory model for cabinet/company/user membership.
*/

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'dir')
    EXEC('CREATE SCHEMA dir');
GO

CREATE TABLE dir.cabinet (
    cabinet_id UNIQUEIDENTIFIER NOT NULL,
    cabinet_slug NVARCHAR(64) NOT NULL,
    display_name NVARCHAR(200) NOT NULL,
    created_at DATETIME2(3) NOT NULL CONSTRAINT DF_dir_cabinet_created_at DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_dir_cabinet PRIMARY KEY (cabinet_id),
    CONSTRAINT UQ_dir_cabinet_slug UNIQUE (cabinet_slug),
    CONSTRAINT CK_dir_cabinet_slug CHECK (cabinet_slug NOT LIKE '%[^a-z0-9\-]%' AND LEN(cabinet_slug) BETWEEN 3 AND 64)
);
GO

CREATE TABLE dir.company (
    company_id UNIQUEIDENTIFIER NOT NULL,
    cabinet_id UNIQUEIDENTIFIER NOT NULL,
    company_slug NVARCHAR(64) NOT NULL,
    display_name NVARCHAR(200) NOT NULL,
    siren NVARCHAR(9) NULL,
    created_at DATETIME2(3) NOT NULL CONSTRAINT DF_dir_company_created_at DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_dir_company PRIMARY KEY (company_id),
    CONSTRAINT FK_dir_company_cabinet FOREIGN KEY (cabinet_id) REFERENCES dir.cabinet(cabinet_id),
    CONSTRAINT UQ_dir_company_slug UNIQUE (cabinet_id, company_slug),
    CONSTRAINT CK_dir_company_slug CHECK (company_slug NOT LIKE '%[^a-z0-9\-]%' AND LEN(company_slug) BETWEEN 2 AND 64)
);
GO

CREATE TABLE dir.user_membership (
    membership_id UNIQUEIDENTIFIER NOT NULL CONSTRAINT DF_dir_membership_id DEFAULT NEWID(),
    user_oid UNIQUEIDENTIFIER NOT NULL, -- Entra user object id
    cabinet_id UNIQUEIDENTIFIER NOT NULL,
    company_id UNIQUEIDENTIFIER NULL,   -- NULL means cabinet-level membership
    role_code NVARCHAR(32) NOT NULL,    -- e.g. CabinetUser/CabinetAdmin/CompanyUser/CompanyAdmin
    created_at DATETIME2(3) NOT NULL CONSTRAINT DF_dir_membership_created_at DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_dir_membership PRIMARY KEY (membership_id),
    CONSTRAINT FK_dir_membership_cabinet FOREIGN KEY (cabinet_id) REFERENCES dir.cabinet(cabinet_id),
    CONSTRAINT FK_dir_membership_company FOREIGN KEY (company_id) REFERENCES dir.company(company_id),
    CONSTRAINT CK_dir_role_code CHECK (role_code IN ('CabinetUser','CabinetAdmin','CompanyUser','CompanyAdmin')),
    CONSTRAINT CK_dir_membership_scope CHECK (
        (company_id IS NULL AND role_code IN ('CabinetUser','CabinetAdmin'))
        OR
        (company_id IS NOT NULL AND role_code IN ('CompanyUser','CompanyAdmin'))
    )
);
GO

-- Unicité (évite les doublons) :
--  - cabinet-level : company_id NULL
--  - company-level : company_id NOT NULL
CREATE UNIQUE INDEX UX_dir_membership_cabinet
ON dir.user_membership (user_oid, cabinet_id, role_code)
WHERE company_id IS NULL;
GO

CREATE UNIQUE INDEX UX_dir_membership_company
ON dir.user_membership (user_oid, cabinet_id, company_id, role_code)
WHERE company_id IS NOT NULL;
GO

CREATE INDEX IX_dir_membership_lookup
ON dir.user_membership (user_oid, cabinet_id, company_id);
GO
