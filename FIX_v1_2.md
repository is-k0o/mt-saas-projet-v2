# Fix v1.2 — core.[rule]

Date: 2026-01-02

Error:
- SQL Server: "Incorrect syntax near the keyword 'rule'."

Cause:
- RULE is a reserved keyword in SQL Server (legacy CREATE RULE).

Fix:
- Escape table name: `core.[rule]`
- Updated index references accordingly.

Action:
- Commit the updated `db/migrations/core/0001_init.sql` and re-run `db-migrate-dev`.
- No need to delete directory DB (already migrated). Core script failed, so it is not journaled yet.
