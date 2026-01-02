/*
  CORE DB — 0002_finalize_posting_sproc.sql
  Balanced postings enforced at FINALIZE time.
*/

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'core.usp_finalize_posting') AND type IN (N'P', N'PC'))
    EXEC('CREATE PROCEDURE core.usp_finalize_posting AS BEGIN SET NOCOUNT ON; END');
GO

ALTER PROCEDURE core.usp_finalize_posting
    @posting_id UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM core.posting_header WHERE posting_id = @posting_id AND status = 'DRAFT')
        THROW 50001, 'Posting not found or not in DRAFT.', 1;

    DECLARE @debit DECIMAL(18,2) = (SELECT COALESCE(SUM(debit),0) FROM core.posting_line WHERE posting_id = @posting_id);
    DECLARE @credit DECIMAL(18,2) = (SELECT COALESCE(SUM(credit),0) FROM core.posting_line WHERE posting_id = @posting_id);

    IF (@debit <> @credit)
        THROW 50002, 'Posting is not balanced (debit != credit).', 1;

    UPDATE core.posting_header
    SET status = 'FINALIZED', finalized_at = SYSUTCDATETIME()
    WHERE posting_id = @posting_id;
END
GO
