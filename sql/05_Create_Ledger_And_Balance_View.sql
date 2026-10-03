USE BankCore;
GO

/* Ledger-derived balance: authoritative for reconciliation. */
CREATE OR ALTER VIEW dbo.vw_AccountBalances
AS
SELECT
    A.AccountID,
    A.AccountNumber,
    A.CustomerID,
    A.BranchID,
    A.AccountType,
    A.AccountStatus,
    COALESCE(SUM(CASE
        WHEN T.TransactionStatus='SUCCESS' AND E.EntryType='CREDIT' THEN E.Amount
        WHEN T.TransactionStatus='SUCCESS' AND E.EntryType='DEBIT' THEN -E.Amount
        ELSE 0
    END),0) AS CurrentBalance
FROM dbo.Accounts A
LEFT JOIN dbo.TransactionEntries E ON A.AccountID=E.AccountID
LEFT JOIN dbo.Transactions T ON E.TransactionID=T.TransactionID
GROUP BY
    A.AccountID,A.AccountNumber,A.CustomerID,A.BranchID,
    A.AccountType,A.AccountStatus;
GO

/*
   Optional balance snapshot for read-heavy workloads.
   It is deliberately separate from the ledger: the ledger remains
   the source of truth and this table is reconciled against it.
*/
CREATE TABLE dbo.AccountBalanceSnapshot
(
    AccountID BIGINT NOT NULL
        CONSTRAINT PK_AccountBalanceSnapshot PRIMARY KEY,
    CurrentBalance DECIMAL(18,2) NOT NULL,
    RefreshedAt DATETIME2 NOT NULL
        CONSTRAINT DF_AccountBalanceSnapshot_RefreshedAt DEFAULT SYSDATETIME(),
    CONSTRAINT FK_AccountBalanceSnapshot_Accounts
        FOREIGN KEY (AccountID) REFERENCES dbo.Accounts(AccountID)
);
GO

CREATE OR ALTER PROCEDURE dbo.usp_RefreshAccountBalanceSnapshot
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    TRUNCATE TABLE dbo.AccountBalanceSnapshot;

    INSERT INTO dbo.AccountBalanceSnapshot(AccountID,CurrentBalance,RefreshedAt)
    SELECT AccountID,CurrentBalance,SYSDATETIME()
    FROM dbo.vw_AccountBalances;
END;
GO

CREATE OR ALTER VIEW dbo.vw_AccountBalanceReconciliation
AS
SELECT
    S.AccountID,
    S.CurrentBalance AS SnapshotBalance,
    V.CurrentBalance AS LedgerBalance,
    S.CurrentBalance - V.CurrentBalance AS Difference
FROM dbo.AccountBalanceSnapshot S
JOIN dbo.vw_AccountBalances V ON V.AccountID=S.AccountID;
GO

SELECT TOP 10 * FROM dbo.vw_AccountBalances ORDER BY AccountID;
