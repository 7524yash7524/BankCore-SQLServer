USE BankCore;
GO

/* 1. Overall transaction summary */
SELECT
    TransactionType,
    TransactionStatus,
    COUNT(*) AS TransactionCount,
    SUM(Amount) AS TotalAmount,
    AVG(Amount) AS AverageAmount
FROM dbo.Transactions
GROUP BY TransactionType,TransactionStatus
ORDER BY TransactionType,TransactionStatus;
GO

/* 2. Monthly transaction trend */
SELECT *
FROM dbo.vw_MonthlyTransactionSummary
ORDER BY TransactionMonth,TransactionType,TransactionStatus;
GO

/* 3. Top 20 customers by outgoing value */
SELECT TOP (20)
    CustomerID,FirstName,LastName,
    TotalDebits,
    DENSE_RANK() OVER (ORDER BY TotalDebits DESC) AS CustomerRank
FROM dbo.vw_CustomerTransactionSummary
ORDER BY CustomerRank;
GO

/* 4. Top 20 customers by incoming value */
SELECT TOP (20)
    CustomerID,FirstName,LastName,
    TotalCredits,
    DENSE_RANK() OVER (ORDER BY TotalCredits DESC) AS CustomerRank
FROM dbo.vw_CustomerTransactionSummary
ORDER BY CustomerRank;
GO

/* 5. Branch performance */
SELECT *
FROM dbo.vw_BranchPerformance
ORDER BY RelatedTransactions DESC;
GO

/* 6. Account type distribution */
SELECT
    AccountType,
    COUNT(*) AS AccountCount,
    AVG(B.CurrentBalance) AS AverageBalance,
    SUM(B.CurrentBalance) AS TotalBalance
FROM dbo.Accounts A
JOIN dbo.vw_AccountBalances B ON A.AccountID=B.AccountID
WHERE A.AccountNumber<>'999999999999'
GROUP BY AccountType
ORDER BY TotalBalance DESC;
GO

/* 7. Running monthly transaction total */
WITH Monthly AS
(
    SELECT
        DATEFROMPARTS(YEAR(TransactionDate),MONTH(TransactionDate),1) AS MonthStart,
        SUM(Amount) AS MonthlyAmount
    FROM dbo.Transactions
    WHERE TransactionStatus='SUCCESS'
    GROUP BY DATEFROMPARTS(YEAR(TransactionDate),MONTH(TransactionDate),1)
)
SELECT
    MonthStart,
    MonthlyAmount,
    SUM(MonthlyAmount) OVER
    (
        ORDER BY MonthStart
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS RunningTotal
FROM Monthly
ORDER BY MonthStart;
GO

/* 8. Month-over-month transaction value */
WITH Monthly AS
(
    SELECT
        DATEFROMPARTS(YEAR(TransactionDate),MONTH(TransactionDate),1) AS MonthStart,
        SUM(Amount) AS MonthlyAmount
    FROM dbo.Transactions
    WHERE TransactionStatus='SUCCESS'
    GROUP BY DATEFROMPARTS(YEAR(TransactionDate),MONTH(TransactionDate),1)
)
SELECT
    MonthStart,
    MonthlyAmount,
    LAG(MonthlyAmount) OVER (ORDER BY MonthStart) AS PreviousMonth,
    MonthlyAmount -
        LAG(MonthlyAmount) OVER (ORDER BY MonthStart) AS AbsoluteChange
FROM Monthly
ORDER BY MonthStart;
GO

/* 9. Large-transaction screening */
SELECT TOP (50)
    TransactionID,ReferenceNumber,TransactionType,Amount,TransactionDate
FROM dbo.Transactions
WHERE TransactionStatus='SUCCESS'
ORDER BY Amount DESC;
GO

/* 10. Repeated account-pair transfers */
SELECT TOP (20)
    E1.AccountID AS FromAccount,
    E2.AccountID AS ToAccount,
    COUNT(*) AS TransferCount,
    SUM(E1.Amount) AS TotalTransferred
FROM dbo.TransactionEntries E1
JOIN dbo.TransactionEntries E2
  ON E1.TransactionID=E2.TransactionID
 AND E1.EntryType='DEBIT'
 AND E2.EntryType='CREDIT'
JOIN dbo.Transactions T
  ON T.TransactionID=E1.TransactionID
WHERE T.TransactionType='TRANSFER'
  AND T.TransactionStatus='SUCCESS'
GROUP BY E1.AccountID,E2.AccountID
HAVING COUNT(*)>=3
ORDER BY TransferCount DESC;
GO

/* 11. Loan portfolio */
SELECT *
FROM dbo.vw_LoanPortfolio
ORDER BY PrincipalValue DESC;
GO

/* 12. Overdue/late payments */
SELECT
    L.LoanID,
    L.CustomerID,
    L.LoanType,
    L.PrincipalAmount,
    LP.DueDate,
    LP.AmountDue,
    LP.AmountPaid,
    LP.PaymentStatus
FROM dbo.Loans L
JOIN dbo.LoanPayments LP ON L.LoanID=LP.LoanID
WHERE LP.PaymentStatus IN ('LATE','DUE')
ORDER BY LP.DueDate;
GO

/* 13. Potentially high-activity accounts */
WITH AccountActivity AS
(
    SELECT
        A.AccountID,
        A.AccountNumber,
        COUNT(*) AS SuccessfulEntryCount,
        SUM(E.Amount) AS EntryValue
    FROM dbo.Accounts A
    JOIN dbo.TransactionEntries E ON A.AccountID=E.AccountID
    JOIN dbo.Transactions T
      ON E.TransactionID=T.TransactionID
     AND T.TransactionStatus='SUCCESS'
    WHERE A.AccountNumber<>'999999999999'
    GROUP BY A.AccountID,A.AccountNumber
)
SELECT TOP (25)
    AccountID,AccountNumber,SuccessfulEntryCount,EntryValue,
    RANK() OVER (ORDER BY SuccessfulEntryCount DESC) AS ActivityRank
FROM AccountActivity
ORDER BY ActivityRank;
GO
