USE BankCore;
GO

/*
   Generate 100,000 synthetic transactions set-wise.
   Successful transactions are created as PENDING, receive both ledger
   entries, and are then posted to SUCCESS. Failed transactions remain
   FAILED and receive no entries. The posting trigger validates balance.
*/

IF (SELECT COUNT(*) FROM dbo.Transactions)<>7500
    THROW 50200,'Expected exactly 7,500 opening transactions.',1;

IF EXISTS (SELECT 1 FROM dbo.Transactions WHERE TransactionStatus='PENDING')
    THROW 50202,'Pending transactions already exist; resolve them before generation.',1;

IF OBJECT_ID('tempdb..#ActiveAccounts') IS NOT NULL DROP TABLE #ActiveAccounts;
IF OBJECT_ID('tempdb..#Generated') IS NOT NULL DROP TABLE #Generated;
IF OBJECT_ID('tempdb..#NewTransactions') IS NOT NULL DROP TABLE #NewTransactions;

SELECT AccountID,
       ROW_NUMBER() OVER(ORDER BY AccountID) AS RN,
       COUNT(*) OVER() AS TotalAccounts
INTO #ActiveAccounts
FROM dbo.Accounts
WHERE AccountNumber<>'999999999999'
  AND AccountStatus='ACTIVE';

;WITH Numbers AS
(
    SELECT TOP (100000)
        ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) AS N
    FROM sys.all_objects A CROSS JOIN sys.all_objects B
),
SourceRows AS
(
    SELECT
        N.N,
        S.AccountID AS SourceAccountID,
        S.RN AS SourceRN,
        S.TotalAccounts,
        ((N.N*31+7-1)%S.TotalAccounts)+1 AS RawDestinationRN
    FROM Numbers N
    JOIN #ActiveAccounts S
      ON S.RN=((N.N*17-1)%S.TotalAccounts)+1
)
SELECT
    N AS SequenceNumber,
    CONCAT('GEN-',RIGHT('000000000000'+CAST(N AS VARCHAR(12)),12)) AS ReferenceNumber,
    CASE WHEN N%100<60 THEN 'TRANSFER'
         WHEN N%100<85 THEN 'DEPOSIT'
         WHEN N%100<95 THEN 'WITHDRAWAL'
         WHEN N%100<98 THEN 'FEE'
         ELSE 'INTEREST' END AS TransactionType,
    CASE WHEN N%20=0 THEN 'FAILED' ELSE 'SUCCESS' END AS FinalStatus,
    CAST(CASE
        WHEN N%100<60 THEN 50+((N*73)%951)
        WHEN N%100<85 THEN 1000+((N*97)%4001)
        WHEN N%100<95 THEN 50+((N*53)%951)
        WHEN N%100<98 THEN 10+((N*29)%91)
        ELSE 25+((N*31)%176) END AS DECIMAL(18,2)) AS Amount,
    SourceAccountID,
    D.AccountID AS DestinationAccountID,
    DATEADD(SECOND,(N*123457)%70000000,CAST('2024-01-01 00:00:00' AS DATETIME2)) AS TransactionDate,
    CASE WHEN N%100<60 THEN 'Synthetic account-to-account transfer'
         WHEN N%100<85 THEN 'Synthetic customer deposit'
         WHEN N%100<95 THEN 'Synthetic cash withdrawal'
         WHEN N%100<98 THEN 'Synthetic banking service fee'
         ELSE 'Synthetic interest credit' END AS Description
INTO #Generated
FROM SourceRows R
JOIN #ActiveAccounts D
  ON D.RN=CASE
            WHEN R.RawDestinationRN=R.SourceRN
                THEN CASE WHEN R.SourceRN=R.TotalAccounts THEN 1 ELSE R.SourceRN+1 END
            ELSE R.RawDestinationRN
          END;

IF (SELECT COUNT(*) FROM #Generated)<>100000
    THROW 50201,'The transaction generator did not create exactly 100,000 rows.',1;

CREATE TABLE #NewTransactions
(
    TransactionID BIGINT NOT NULL,
    ReferenceNumber VARCHAR(30) NOT NULL PRIMARY KEY
);

/* Failed rows are final FAILED; successful rows are PENDING until posted. */
INSERT INTO dbo.Transactions
(ReferenceNumber,TransactionType,TransactionStatus,Amount,CurrencyCode,TransactionDate,Description)
OUTPUT INSERTED.TransactionID,INSERTED.ReferenceNumber INTO #NewTransactions
SELECT ReferenceNumber,TransactionType,
       CASE WHEN FinalStatus='FAILED' THEN 'FAILED' ELSE 'PENDING' END,
       Amount,'INR',TransactionDate,Description
FROM #Generated;

INSERT INTO dbo.TransactionEntries(TransactionID,AccountID,EntryType,Amount)
SELECT NT.TransactionID,G.SourceAccountID,'DEBIT',G.Amount
FROM #NewTransactions NT JOIN #Generated G ON NT.ReferenceNumber=G.ReferenceNumber
WHERE G.FinalStatus='SUCCESS'
  AND G.TransactionType IN ('TRANSFER','WITHDRAWAL','FEE');

INSERT INTO dbo.TransactionEntries(TransactionID,AccountID,EntryType,Amount)
SELECT NT.TransactionID,G.DestinationAccountID,'CREDIT',G.Amount
FROM #NewTransactions NT JOIN #Generated G ON NT.ReferenceNumber=G.ReferenceNumber
WHERE G.FinalStatus='SUCCESS'
  AND G.TransactionType IN ('TRANSFER','DEPOSIT','INTEREST');

DECLARE @SystemAccountID BIGINT =
(
    SELECT AccountID FROM dbo.Accounts WHERE AccountNumber='999999999999'
);

INSERT INTO dbo.TransactionEntries(TransactionID,AccountID,EntryType,Amount)
SELECT NT.TransactionID,@SystemAccountID,'DEBIT',G.Amount
FROM #NewTransactions NT JOIN #Generated G ON NT.ReferenceNumber=G.ReferenceNumber
WHERE G.FinalStatus='SUCCESS'
  AND G.TransactionType IN ('DEPOSIT','INTEREST');

INSERT INTO dbo.TransactionEntries(TransactionID,AccountID,EntryType,Amount)
SELECT NT.TransactionID,@SystemAccountID,'CREDIT',G.Amount
FROM #NewTransactions NT JOIN #Generated G ON NT.ReferenceNumber=G.ReferenceNumber
WHERE G.FinalStatus='SUCCESS'
  AND G.TransactionType IN ('WITHDRAWAL','FEE');

/* Posting trigger validates every successful transaction before it is committed. */
UPDATE T
SET TransactionStatus='SUCCESS'
FROM dbo.Transactions T
JOIN #NewTransactions N ON N.TransactionID=T.TransactionID
WHERE T.TransactionStatus='PENDING';

EXEC dbo.usp_RefreshAccountBalanceSnapshot;

SELECT COUNT(*) AS TotalTransactions FROM dbo.Transactions;
SELECT COUNT(*) AS TotalEntries FROM dbo.TransactionEntries;
