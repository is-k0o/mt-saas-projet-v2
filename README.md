# mt-saas v2 — Archived Azure IaC / SQL Multi-Tenant POC

> **Status: archived / discontinued proof of concept**
>
> This project is no longer under active development.
> It was stopped before the application/API layer was implemented and is kept
> public as a technical proof of work around Azure infrastructure,
> Terraform, GitHub Actions OIDC and SQL multi-tenant isolation.

## Overview

`mt-saas-v2` started as a second iteration of a multi-tenant SaaS architecture.

The project was ultimately discontinued, but the infrastructure and database
foundation reached a functional proof-of-concept stage.

The repository demonstrates:

- Azure infrastructure provisioning with **Terraform**
- Terraform **remote state** on Azure Storage
- **GitHub Actions → Azure authentication through OIDC**
- CI/CD workflows for Terraform `plan` and `apply`
- Azure SQL deployment
- automated SQL migrations with **DbUp**
- separation between a tenant directory database and an application database
- initial multi-tenant authorization primitives
- SQL Server **Row-Level Security (RLS)** as a defense-in-depth mechanism
- basic infrastructure and database validation / sanity checks

It is **not a finished SaaS application** and does not contain the API or
frontend originally planned for the project.

---

## Architecture

```text
                    GitHub Actions
                         |
                         | OIDC
                         v
                  Microsoft Entra ID
                         |
                         v
                       Azure
                         |
            +------------+-------------+
            |                          |
            v                          v
     Terraform state              Azure SQL
     Azure Storage                   |
                                     |
                         +-----------+-----------+
                         |                       |
                         v                       v
                 Directory database       Core database
                         |                       |
                 tenant membership       application data
                 tenant resolution       tenant-scoped RLS
                         |                       |
                         +-----------+-----------+
                                     |
                              Future API layer
                              (not implemented)
```

---

## Infrastructure as Code

Terraform is used to provision the development infrastructure.

The repository contains:

- reusable Terraform modules
- a dedicated `dev` environment
- an Azure Storage backend for remote Terraform state
- Azure SQL logical server provisioning
- two Azure SQL databases:
  - Directory database
  - Core application database

The Terraform backend itself can be bootstrapped through a dedicated
GitHub Actions workflow.

---

## GitHub Actions and OIDC

GitHub Actions authenticates to Azure using **OpenID Connect federation**.

No long-lived Azure client secret is required for the Terraform workflows.

The implemented workflow model includes:

```text
bootstrap Terraform backend
        |
        v
Pull Request
        |
        v
terraform plan
        |
        v
merge / push to main
        |
        v
terraform apply
        |
        v
database migrations
```

The main workflows cover:

- Terraform backend bootstrap
- Terraform plan on infrastructure changes
- Terraform apply
- database migration execution

Azure access is granted to the GitHub workflow identity through an
Entra ID federated credential and Azure RBAC.

---

## Database Design

The proof of concept uses two logical databases.

### Directory database

The Directory database models tenant discovery and membership.

Implemented objects include entities for:

- cabinets / parent tenants
- companies
- user memberships

The runtime SQL surface includes stored procedures used to:

- resolve a company from an external identifier
- verify tenant membership
- enumerate companies available to a user

This was intended to become the first authorization step for the future API.

---

### Core database

The Core database contains the application-oriented data model.

The project introduced tenant identifiers across application tables and uses
SQL Server **Row-Level Security** as an additional isolation boundary.

The intended runtime flow was:

```text
request
   |
   v
resolve tenant in Directory DB
   |
   v
verify membership
   |
   v
set tenant context in Core DB
   |
   v
SQL Row-Level Security
   |
   v
tenant-scoped data
```

A dedicated SQL procedure sets the tenant context used by the RLS policy.

A restricted runtime database role was also prepared for the future
application identity.

---

## Database Migrations

Schema evolution is managed through a small **.NET / DbUp** migration runner.

Migrations are applied:

1. to the Directory database
2. to the Core database

Migration execution is journaled in the database and uses transactions
per script.

The repository contains migrations for:

- initial schemas
- tenant columns
- runtime stored procedures
- Row-Level Security
- runtime database permissions

---

## Validation

The project includes manual sanity checks for the database layer.

These checks were used to validate:

- expected tenant columns
- RLS objects and policy state
- tenant context behavior
- Directory tenant resolution
- authorization allow / deny behavior
- basic schema consistency

One important testing lesson from the project is that RLS should not be
validated using a highly privileged `db_owner` connection, as administrative
privileges can invalidate the assumptions being tested.

---

## Security Model

This POC explored several security principles rather than attempting to
deliver a production-ready security architecture.

### Implemented

- GitHub Actions authentication through OIDC
- Azure RBAC for deployment workflows
- tenant membership verification primitives
- SQL Row-Level Security
- restricted future runtime role
- separation of tenant directory and application data responsibilities

### Not completed

The planned hardening phase was never implemented.

In particular, the development environment still relied on:

- public Azure SQL network access
- temporary firewall access for GitHub-hosted runners
- SQL authentication for database migrations

The planned next stage included:

- Azure SQL Private Endpoint
- disabling public network access
- Entra-only SQL authentication
- Managed Identity for the future application
- additional diagnostics and security monitoring

These items should therefore be understood as **planned design work, not
implemented controls**.

---

## What Was Not Implemented

Development stopped before the application layer.

The following components were planned but never completed:

- application/API authentication
- API routes
- application runtime identity
- application-to-database integration
- document storage
- frontend
- pre-production environment
- production networking and hardening

This repository should therefore be read as an **infrastructure and database
architecture POC**, not as a complete SaaS product.

---

## What This Project Demonstrates

Although incomplete, the project was useful for hands-on work with:

- **Microsoft Azure**
- **Terraform**
- **GitHub Actions**
- **OIDC / workload identity federation**
- **Microsoft Entra ID**
- **Azure RBAC**
- **Azure SQL**
- **SQL migrations**
- **Row-Level Security**
- **multi-tenant data isolation concepts**
- infrastructure troubleshooting and documentation

---

## Repository Structure

```text
.github/workflows/        GitHub Actions CI/CD
infra/terraform/          Terraform modules and environments
db/migrations/            SQL database migrations
db/sanity/                Database validation scripts
src/migrations/           .NET / DbUp migration runner
docs/                     Architecture and implementation notes
```

---

## Project Status

**Archived.**

The original SaaS project was discontinued before completion.

The repository is preserved because the infrastructure, CI/CD, identity
federation and SQL isolation work remain useful as a technical portfolio
artifact and historical proof of implementation.
