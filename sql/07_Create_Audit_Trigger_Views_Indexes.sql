USE BankCore;
GO

/* =========================================================
   PERFORMANCE INDEXES
   ========================================================= */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Accounts_CustomerID' AND object_id=OBJECT_ID('dbo.Accounts'))
    CREATE INDEX IX_Accounts_CustomerID ON dbo.Accounts(CustomerID);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Accounts_BranchID' AND object_id=OBJECT_ID('dbo.Accounts'))
    CREATE INDEX IX_Accounts_BranchID ON dbo.Accounts(BranchID);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Transactions_Status_Date' AND object_id=OBJECT_ID('dbo.Transactions'))
    CREATE INDEX IX_Transactions_Status_Date ON dbo.Transactions(TransactionStatus,TransactionDate) INCLUDE (TransactionType,Amount,ReferenceNumber);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Transactions_Type' AND object_id=OBJECT_ID('dbo.Transactions'))
    CREATE INDEX IX_Transactions_Type ON dbo.Transactions(TransactionType) INCLUDE (TransactionStatus,Amount,TransactionDate);

/* Cover the common account-history/balance access pattern. */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_TransactionEntries_AccountID_Covering' AND object_id=OBJECT_ID('dbo.TransactionEntries'))
    CREATE INDEX IX_TransactionEntries_AccountID_Covering
    ON dbo.TransactionEntries(AccountID,TransactionID) INCLUDE (EntryType,Amount);

/* Cover transaction-to-entry integrity and detail lookups. */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_TransactionEntries_TransactionID_Covering' AND object_id=OBJECT_ID('dbo.TransactionEntries'))
    CREATE INDEX IX_TransactionEntries_TransactionID_Covering
    ON dbo.TransactionEntries(TransactionID,EntryType) INCLUDE (AccountID,Amount);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Loans_Customer_Status' AND object_id=OBJECT_ID('dbo.Loans'))
    CREATE INDEX IX_Loans_Customer_Status ON dbo.Loans(CustomerID,LoanStatus) INCLUDE (PrincipalAmount,LoanType);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_LoanPayments_Status_DueDate' AND object_id=OBJECT_ID('dbo.LoanPayments'))
    CREATE INDEX IX_LoanPayments_Status_DueDate ON dbo.LoanPayments(PaymentStatus,DueDate) INCLUDE (LoanID,AmountDue,AmountPaid);
GO

/* =========================================================
   LEDGER POSTING INVARIANT
   A transaction may become SUCCESS only if it has exactly two
   entries and total debit equals total credit.
   ========================================================= */
CREATE OR ALTER TRIGGER dbo.trg_Transactions_ValidatePosting
ON dbo.Transactions
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT UPDATE(TransactionStatus) RETURN;

    IF EXISTS
    (
        SELECT 1
        FROM inserted I
        JOIN deleted D ON D.TransactionID=I.TransactionID
        WHERE I.TransactionStatus='SUCCESS'
          AND D.TransactionStatus<>'SUCCESS'
          AND
          (
              SELECT COUNT(*) FROM dbo.TransactionEntries E
              WHERE E.TransactionID=I.TransactionID
          ) <> 2
    )
    BEGIN
        THROW 50300,'A successful transaction must contain exactly two ledger entries.',1;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM inserted I
        JOIN deleted D ON D.TransactionID=I.TransactionID
        WHERE I.TransactionStatus='SUCCESS'
          AND D.TransactionStatus<>'SUCCESS'
          AND
          (
              SELECT COALESCE(SUM(CASE WHEN E.EntryType='DEBIT' THEN E.Amount ELSE -E.Amount END),0)
              FROM dbo.TransactionEntries E
              WHERE E.TransactionID=I.TransactionID
          ) <> 0
    )
    BEGIN
        THROW 50301,'A successful transaction must have equal total debit and credit.',1;
    END;
END;
GO

/* Entries cannot be posted against FAILED or REVERSED transactions. */
CREATE OR ALTER TRIGGER dbo.trg_TransactionEntries_ValidateParent
ON dbo.TransactionEntries
AFTER INSERT,UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM inserted E
        JOIN dbo.Transactions T ON T.TransactionID=E.TransactionID
        WHERE T.TransactionStatus IN ('FAILED','REVERSED')
    )
        THROW 50302,'FAILED or REVERSED transactions cannot contain ledger entries.',1;
END;
GO

/* =========================================================
   AUDIT TRIGGERS
   Separate INSERT/UPDATE/DELETE triggers make row-level action
   classification correct even for MERGE/multi-row statements.
   ========================================================= */
CREATE OR ALTER TRIGGER dbo.trg_Transactions_Audit_Insert
ON dbo.Transactions AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.AuditLog(TableName,ActionType,RecordID,Details)
    SELECT 'Transactions','INSERT',CAST(TransactionID AS VARCHAR(100)),
           CONCAT('Reference=',ReferenceNumber,'; Type=',TransactionType,
                  '; Status=',TransactionStatus,'; Amount=',CONVERT(VARCHAR(50),Amount))
    FROM inserted;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_Transactions_Audit_Update
ON dbo.Transactions AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.AuditLog(TableName,ActionType,RecordID,Details)
    SELECT 'Transactions','UPDATE',CAST(I.TransactionID AS VARCHAR(100)),
           CONCAT('Status ',D.TransactionStatus,' -> ',I.TransactionStatus,
                  '; Amount=',CONVERT(VARCHAR(50),I.Amount))
    FROM inserted I JOIN deleted D ON D.TransactionID=I.TransactionID;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_Transactions_Audit_Delete
ON dbo.Transactions AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.AuditLog(TableName,ActionType,RecordID,Details)
    SELECT 'Transactions','DELETE',CAST(TransactionID AS VARCHAR(100)),
           CONCAT('Reference=',ReferenceNumber,'; Amount=',CONVERT(VARCHAR(50),Amount))
    FROM deleted;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_Accounts_Audit
ON dbo.Accounts AFTER INSERT,UPDATE,DELETE
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.AuditLog(TableName,ActionType,RecordID,Details)
    SELECT 'Accounts',
           CASE WHEN I.AccountID IS NULL THEN 'DELETE'
                WHEN D.AccountID IS NULL THEN 'INSERT'
                ELSE 'UPDATE' END,
           CAST(COALESCE(I.AccountID,D.AccountID) AS VARCHAR(100)),
           CONCAT('Account=',COALESCE(I.AccountNumber,D.AccountNumber),
                  '; Status=',COALESCE(I.AccountStatus,D.AccountStatus),
                  '; Type=',COALESCE(I.AccountType,D.AccountType))
    FROM inserted I
    FULL OUTER JOIN deleted D ON D.AccountID=I.AccountID;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_Loans_Audit
ON dbo.Loans AFTER INSERT,UPDATE,DELETE
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.AuditLog(TableName,ActionType,RecordID,Details)
    SELECT 'Loans',
           CASE WHEN I.LoanID IS NULL THEN 'DELETE'
                WHEN D.LoanID IS NULL THEN 'INSERT'
                ELSE 'UPDATE' END,
           CAST(COALESCE(I.LoanID,D.LoanID) AS VARCHAR(100)),
           CONCAT('LoanType=',COALESCE(I.LoanType,D.LoanType),
                  '; Status=',COALESCE(I.LoanStatus,D.LoanStatus),
                  '; Principal=',CONVERT(VARCHAR(50),COALESCE(I.PrincipalAmount,D.PrincipalAmount)))
    FROM inserted I
    FULL OUTER JOIN deleted D ON D.LoanID=I.LoanID;
END;
GO

/* =========================================================
   ANALYTICAL VIEWS
   ========================================================= */
CREATE OR ALTER VIEW dbo.vw_MonthlyTransactionSummary
AS
SELECT DATEFROMPARTS(YEAR(TransactionDate),MONTH(TransactionDate),1) AS TransactionMonth,
       TransactionType,TransactionStatus,
       COUNT(*) AS TransactionCount,
       SUM(Amount) AS TotalAmount,
       AVG(Amount) AS AverageAmount
FROM dbo.Transactions
GROUP BY DATEFROMPARTS(YEAR(TransactionDate),MONTH(TransactionDate),1),
         TransactionType,TransactionStatus;
GO

CREATE OR ALTER VIEW dbo.vw_CustomerTransactionSummary
AS
SELECT C.CustomerID,C.FirstName,C.LastName,
       COUNT(DISTINCT T.TransactionID) AS TransactionCount,
       COALESCE(SUM(CASE WHEN E.EntryType='DEBIT' THEN E.Amount ELSE 0 END),0) AS TotalDebits,
       COALESCE(SUM(CASE WHEN E.EntryType='CREDIT' THEN E.Amount ELSE 0 END),0) AS TotalCredits
FROM dbo.Customers C
LEFT JOIN dbo.Accounts A ON C.CustomerID=A.CustomerID
LEFT JOIN dbo.TransactionEntries E ON A.AccountID=E.AccountID
LEFT JOIN dbo.Transactions T ON E.TransactionID=T.TransactionID AND T.TransactionStatus='SUCCESS'
GROUP BY C.CustomerID,C.FirstName,C.LastName;
GO

CREATE OR ALTER VIEW dbo.vw_BranchPerformance
AS
SELECT B.BranchID,B.BranchName,B.City,
       COUNT(DISTINCT A.AccountID) AS AccountCount,
       COUNT(DISTINCT T.TransactionID) AS RelatedTransactions,
       COALESCE(SUM(CASE WHEN E.EntryType='CREDIT' THEN E.Amount ELSE 0 END),0) AS Credits,
       COALESCE(SUM(CASE WHEN E.EntryType='DEBIT' THEN E.Amount ELSE 0 END),0) AS Debits
FROM dbo.Branches B
LEFT JOIN dbo.Accounts A ON B.BranchID=A.BranchID
LEFT JOIN dbo.TransactionEntries E ON A.AccountID=E.AccountID
LEFT JOIN dbo.Transactions T ON E.TransactionID=T.TransactionID AND T.TransactionStatus='SUCCESS'
GROUP BY B.BranchID,B.BranchName,B.City;
GO

CREATE OR ALTER VIEW dbo.vw_LoanPortfolio
AS
SELECT L.LoanType,L.LoanStatus,COUNT(*) AS LoanCount,
       SUM(L.PrincipalAmount) AS PrincipalValue,
       AVG(L.AnnualInterestRate) AS AverageInterestRate
FROM dbo.Loans L
GROUP BY L.LoanType,L.LoanStatus;
GO

EXEC dbo.usp_RefreshAccountBalanceSnapshot;
GO
