USE BankCore;
GO

/*
   PERFORMANCE LAB
   In SSMS press Ctrl+M to enable Actual Execution Plan.
   Keep the Messages tab visible. STATISTICS IO/TIME provides
   objective logical-read, CPU, and elapsed-time measurements.
*/

SET STATISTICS IO ON;
SET STATISTICS TIME ON;
GO

/* =========================================================
   TEST 1A: CONTROLLED BASELINE
   Force a scan of Transactions. Record logical reads/time.
   ========================================================= */
SELECT TOP (100)
    TransactionID,ReferenceNumber,Amount,TransactionDate
FROM dbo.Transactions WITH (INDEX(0))
WHERE TransactionStatus='SUCCESS'
  AND TransactionDate>='2025-01-01'
ORDER BY TransactionDate DESC;
GO

/* =========================================================
   TEST 1B: INDEXED VERSION
   Compare with IX_Transactions_Date_Status.
   ========================================================= */
SELECT TOP (100)
    TransactionID,ReferenceNumber,Amount,TransactionDate
FROM dbo.Transactions
WHERE TransactionStatus='SUCCESS'
  AND TransactionDate>='2025-01-01'
ORDER BY TransactionDate DESC;
GO

/* =========================================================
   TEST 2A: CONTROLLED BASELINE FOR ACCOUNT HISTORY
   ========================================================= */
SELECT TOP (100)
    E.EntryID,E.TransactionID,E.AccountID,E.EntryType,E.Amount
FROM dbo.TransactionEntries WITH (INDEX(0)) E
WHERE E.AccountID=1
ORDER BY E.TransactionID DESC;
GO

/* =========================================================
   TEST 2B: COVERING INDEX VERSION
   Compare with IX_TransactionEntries_AccountID_Covering.
   ========================================================= */
SELECT TOP (100)
    E.EntryID,E.TransactionID,E.AccountID,E.EntryType,E.Amount
FROM dbo.TransactionEntries E
WHERE E.AccountID=1
ORDER BY E.TransactionID DESC;
GO

/* =========================================================
   TEST 3A: LEDGER-DERIVED BALANCE
   Authoritative but aggregation-heavy.
   ========================================================= */
SELECT TOP (100) AccountID,CurrentBalance
FROM dbo.vw_AccountBalances
WHERE AccountID BETWEEN 1 AND 100
ORDER BY AccountID;
GO

/* =========================================================
   TEST 3B: SNAPSHOT BALANCE
   Read-optimized copy, reconciled against the ledger.
   ========================================================= */
SELECT TOP (100) AccountID,CurrentBalance
FROM dbo.AccountBalanceSnapshot
WHERE AccountID BETWEEN 1 AND 100
ORDER BY AccountID;
GO

/* =========================================================
   TEST 3C: RECONCILIATION
   Must return zero mismatches after refresh.
   ========================================================= */
SELECT COUNT(*) AS SnapshotMismatches
FROM dbo.vw_AccountBalanceReconciliation
WHERE Difference<>0;
GO

/* =========================================================
   TEST 4: INDEX METADATA
   ========================================================= */
SELECT OBJECT_NAME(I.object_id) AS TableName,
       I.name AS IndexName,
       I.type_desc,
       I.is_unique,
       I.is_disabled
FROM sys.indexes I
WHERE I.object_id IN
(
    OBJECT_ID('dbo.Transactions'),
    OBJECT_ID('dbo.TransactionEntries'),
    OBJECT_ID('dbo.Accounts')
)
ORDER BY TableName,IndexName;
GO

/* =========================================================
   TEST 5: MISSING-INDEX DMV SNAPSHOT
   Advisory only; validate before adding anything.
   ========================================================= */
SELECT TOP (20)
    DB_NAME(mid.database_id) AS DatabaseName,
    OBJECT_NAME(mid.object_id,mid.database_id) AS TableName,
    migs.user_seeks,
    migs.user_scans,
    migs.avg_total_user_cost,
    migs.avg_user_impact,
    mid.equality_columns,
    mid.inequality_columns,
    mid.included_columns
FROM sys.dm_db_missing_index_group_stats migs
JOIN sys.dm_db_missing_index_groups mig
  ON migs.group_handle=mig.index_group_handle
JOIN sys.dm_db_missing_index_details mid
  ON mig.index_handle=mid.index_handle
WHERE mid.database_id=DB_ID()
ORDER BY migs.avg_user_impact DESC;
GO

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO
