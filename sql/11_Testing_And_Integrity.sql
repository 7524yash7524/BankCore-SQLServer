USE BankCore;
GO

/* A. Row-count audit */
SELECT 'Branches' AS Entity, COUNT_BIG(*) AS RowCount FROM dbo.Branches
UNION ALL SELECT 'Customers',COUNT_BIG(*) FROM dbo.Customers
UNION ALL SELECT 'Employees',COUNT_BIG(*) FROM dbo.Employees
UNION ALL SELECT 'Accounts',COUNT_BIG(*) FROM dbo.Accounts
UNION ALL SELECT 'Transactions',COUNT_BIG(*) FROM dbo.Transactions
UNION ALL SELECT 'TransactionEntries',COUNT_BIG(*) FROM dbo.TransactionEntries
UNION ALL SELECT 'Loans',COUNT_BIG(*) FROM dbo.Loans
UNION ALL SELECT 'LoanPayments',COUNT_BIG(*) FROM dbo.LoanPayments
UNION ALL SELECT 'AuditLog',COUNT_BIG(*) FROM dbo.AuditLog;
GO

/* B. Orphan checks */
SELECT COUNT(*) AS OrphanAccounts
FROM dbo.Accounts A LEFT JOIN dbo.Customers C ON A.CustomerID=C.CustomerID
WHERE C.CustomerID IS NULL;
GO

SELECT COUNT(*) AS OrphanEntries
FROM dbo.TransactionEntries E LEFT JOIN dbo.Transactions T ON E.TransactionID=T.TransactionID
WHERE T.TransactionID IS NULL;
GO

/* C. Successful transactions: exactly two entries and balanced */
SELECT T.TransactionID,T.ReferenceNumber,
       COUNT(E.EntryID) AS EntryCount,
       SUM(CASE WHEN E.EntryType='DEBIT' THEN E.Amount ELSE -E.Amount END) AS LedgerDifference
FROM dbo.Transactions T
LEFT JOIN dbo.TransactionEntries E ON T.TransactionID=E.TransactionID
WHERE T.TransactionStatus='SUCCESS'
GROUP BY T.TransactionID,T.ReferenceNumber
HAVING COUNT(E.EntryID)<>2
    OR SUM(CASE WHEN E.EntryType='DEBIT' THEN E.Amount ELSE -E.Amount END)<>0;
GO

/* D. Failed/reversed transactions should have no entries */
SELECT T.TransactionID,T.ReferenceNumber,T.TransactionStatus,COUNT(E.EntryID) AS EntryCount
FROM dbo.Transactions T
LEFT JOIN dbo.TransactionEntries E ON T.TransactionID=E.TransactionID
WHERE T.TransactionStatus IN ('FAILED','REVERSED')
GROUP BY T.TransactionID,T.ReferenceNumber,T.TransactionStatus
HAVING COUNT(E.EntryID)<>0;
GO

/* E. Negative customer balances */
SELECT COUNT(*) AS NegativeCustomerAccounts
FROM dbo.vw_AccountBalances
WHERE AccountNumber<>'999999999999' AND CurrentBalance<0;
GO

/* F. Invalid transaction amounts */
SELECT COUNT(*) AS InvalidTransactionAmounts
FROM dbo.Transactions WHERE Amount<=0;
GO

/* G. Snapshot vs ledger reconciliation */
SELECT COUNT(*) AS SnapshotMismatches
FROM dbo.vw_AccountBalanceReconciliation
WHERE Difference<>0;
GO

/* H. Concurrency/transaction procedure validation: valid transfer */
DECLARE @Before BIGINT=(SELECT COUNT(*) FROM dbo.Transactions);
DECLARE @BeforeBalance1 DECIMAL(18,2)=(SELECT CurrentBalance FROM dbo.vw_AccountBalances WHERE AccountID=1);
DECLARE @BeforeBalance2 DECIMAL(18,2)=(SELECT CurrentBalance FROM dbo.vw_AccountBalances WHERE AccountID=2);

EXEC dbo.usp_TransferMoney
    @FromAccountID=1,@ToAccountID=2,@Amount=100,
    @Description='Integrity test transfer';

DECLARE @After BIGINT=(SELECT COUNT(*) FROM dbo.Transactions);
DECLARE @AfterBalance1 DECIMAL(18,2)=(SELECT CurrentBalance FROM dbo.vw_AccountBalances WHERE AccountID=1);
DECLARE @AfterBalance2 DECIMAL(18,2)=(SELECT CurrentBalance FROM dbo.vw_AccountBalances WHERE AccountID=2);

SELECT @Before AS TransactionsBefore,@After AS TransactionsAfter,
       @After-@Before AS NewTransactions,
       @BeforeBalance1-@AfterBalance1 AS DebitChange,
       @AfterBalance2-@BeforeBalance2 AS CreditChange;
GO

/* I. Expected failure: insufficient funds; row count must remain unchanged */
DECLARE @BeforeFailed BIGINT=(SELECT COUNT(*) FROM dbo.Transactions);
BEGIN TRY
    EXEC dbo.usp_TransferMoney
        @FromAccountID=1,@ToAccountID=2,@Amount=999999999999,
        @Description='Intentional failure test';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS ErrorNumber,ERROR_MESSAGE() AS ExpectedError;
END CATCH;
DECLARE @AfterFailed BIGINT=(SELECT COUNT(*) FROM dbo.Transactions);
SELECT @BeforeFailed AS TransactionsBefore,@AfterFailed AS TransactionsAfter,
       @AfterFailed-@BeforeFailed AS UnexpectedRows;
GO

/* J. Audit coverage */
SELECT TableName,ActionType,COUNT(*) AS AuditRows
FROM dbo.AuditLog
GROUP BY TableName,ActionType
ORDER BY TableName,ActionType;
GO

/* K. Clean up snapshot after test transfer and reconcile again. */
EXEC dbo.usp_RefreshAccountBalanceSnapshot;
SELECT COUNT(*) AS SnapshotMismatchesAfterRefresh
FROM dbo.vw_AccountBalanceReconciliation
WHERE Difference<>0;
GO
