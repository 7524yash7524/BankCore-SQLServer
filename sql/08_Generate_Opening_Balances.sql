USE BankCore;
GO

DECLARE @SystemAccountID BIGINT =
(
    SELECT AccountID FROM dbo.Accounts WHERE AccountNumber='999999999999'
);

IF @SystemAccountID IS NULL
    THROW 50100,'System account was not found.',1;

IF (SELECT COUNT(*) FROM dbo.Transactions)<>0
    THROW 50101,'Opening balances should be generated on a fresh BankCore database.',1;

CREATE TABLE #Opening
(
    AccountID BIGINT PRIMARY KEY,
    Amount DECIMAL(18,2) NOT NULL,
    TransactionID BIGINT NULL
);

INSERT INTO #Opening(AccountID,Amount)
SELECT AccountID,
       CAST(250000 + ((AccountID*7919)%250001) AS DECIMAL(18,2))
FROM dbo.Accounts
WHERE AccountNumber<>'999999999999';

INSERT INTO dbo.Transactions
(ReferenceNumber,TransactionType,TransactionStatus,Amount,CurrencyCode,TransactionDate,Description)
SELECT CONCAT('OPEN-',RIGHT('000000000000'+CAST(AccountID AS VARCHAR(12)),12)),
       'DEPOSIT','PENDING',Amount,'INR',
       DATEADD(DAY,-(AccountID%1500),CAST(GETDATE() AS DATETIME2)),
       'Initial synthetic account funding'
FROM #Opening;

UPDATE O
SET TransactionID=T.TransactionID
FROM #Opening O
JOIN dbo.Transactions T
  ON T.ReferenceNumber=CONCAT('OPEN-',RIGHT('000000000000'+CAST(O.AccountID AS VARCHAR(12)),12));

INSERT INTO dbo.TransactionEntries(TransactionID,AccountID,EntryType,Amount)
SELECT TransactionID,AccountID,'CREDIT',Amount FROM #Opening;

INSERT INTO dbo.TransactionEntries(TransactionID,AccountID,EntryType,Amount)
SELECT TransactionID,@SystemAccountID,'DEBIT',Amount FROM #Opening;

UPDATE T
SET TransactionStatus='SUCCESS'
FROM dbo.Transactions T
JOIN #Opening O ON O.TransactionID=T.TransactionID;

EXEC dbo.usp_RefreshAccountBalanceSnapshot;

SELECT COUNT(*) AS OpeningTransactions FROM dbo.Transactions;
SELECT COUNT(*) AS OpeningEntries FROM dbo.TransactionEntries;
