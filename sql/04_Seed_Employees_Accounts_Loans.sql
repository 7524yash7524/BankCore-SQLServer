USE BankCore;
GO

;WITH Numbers AS
(
    SELECT TOP (100)
        ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS N
    FROM sys.all_objects A
    CROSS JOIN sys.all_objects B
)
INSERT INTO dbo.Employees (BranchID,EmployeeName,JobTitle,HireDate)
SELECT
    ((N-1)%10)+1,
    CONCAT(
        CASE N%10 WHEN 0 THEN 'Rahul' WHEN 1 THEN 'Ankit' WHEN 2 THEN 'Rohit'
        WHEN 3 THEN 'Amit' WHEN 4 THEN 'Neha' WHEN 5 THEN 'Priya'
        WHEN 6 THEN 'Sneha' WHEN 7 THEN 'Pooja' WHEN 8 THEN 'Vikas'
        ELSE 'Karan' END,
        ' ',
        CASE N%8 WHEN 0 THEN 'Sharma' WHEN 1 THEN 'Verma' WHEN 2 THEN 'Gupta'
        WHEN 3 THEN 'Patel' WHEN 4 THEN 'Singh' WHEN 5 THEN 'Kumar'
        WHEN 6 THEN 'Mehta' ELSE 'Reddy' END),
    CASE N%5 WHEN 0 THEN 'Branch Manager'
        WHEN 1 THEN 'Relationship Manager'
        WHEN 2 THEN 'Loan Officer'
        WHEN 3 THEN 'Cashier'
        ELSE 'Operations Officer' END,
    DATEADD(DAY,-(500+(N*37%3000)),CAST(GETDATE() AS DATE))
FROM Numbers;
GO

;WITH AccountNumbers AS
(
    SELECT CustomerID,1 AS AccountSequence
    FROM dbo.Customers
    WHERE CustomerID <= 2500
    UNION ALL
    SELECT CustomerID,1
    FROM dbo.Customers
    WHERE CustomerID > 2500
    UNION ALL
    SELECT CustomerID,2
    FROM dbo.Customers
    WHERE CustomerID > 2500
)
INSERT INTO dbo.Accounts
(
    CustomerID,BranchID,AccountNumber,AccountType,OpenDate,AccountStatus,CurrencyCode
)
SELECT
    CustomerID,
    ((CustomerID+AccountSequence-2)%10)+1,
    CONCAT('10',RIGHT('0000000000'+CAST(((CustomerID-1)*2)+AccountSequence AS VARCHAR(10)),10)),
    CASE
        WHEN AccountSequence=2 THEN 'CURRENT'
        WHEN CustomerID%4=0 THEN 'SALARY'
        WHEN CustomerID%5=0 THEN 'FIXED_DEPOSIT'
        ELSE 'SAVINGS'
    END,
    DATEADD(DAY,-(CustomerID%1500),CAST(GETDATE() AS DATE)),
    CASE WHEN CustomerID%100=0 THEN 'FROZEN' ELSE 'ACTIVE' END,
    'INR'
FROM AccountNumbers;
GO

;WITH Numbers AS
(
    SELECT TOP (1000)
        ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS N
    FROM sys.all_objects A
    CROSS JOIN sys.all_objects B
)
INSERT INTO dbo.Loans
(
    CustomerID,BranchID,LoanType,PrincipalAmount,AnnualInterestRate,
    TermMonths,DisbursementDate,LoanStatus
)
SELECT
    ((N*37-1)%5000)+1,
    ((N-1)%10)+1,
    CASE N%5 WHEN 0 THEN 'HOME' WHEN 1 THEN 'PERSONAL'
        WHEN 2 THEN 'EDUCATION' WHEN 3 THEN 'VEHICLE' ELSE 'BUSINESS' END,
    CAST(50000+(N*7919%1950000) AS DECIMAL(18,2)),
    CAST(6+(N*13%900)/100.0 AS DECIMAL(5,2)),
    CASE N%5 WHEN 0 THEN 120 WHEN 1 THEN 60 WHEN 2 THEN 36 WHEN 3 THEN 48 ELSE 84 END,
    DATEADD(DAY,-(N*23%1800),CAST(GETDATE() AS DATE)),
    CASE WHEN N%20=0 THEN 'DEFAULT'
         WHEN N%7=0 THEN 'CLOSED'
         ELSE 'ACTIVE' END
FROM Numbers;
GO

;WITH PaymentMonths AS
(
    SELECT N FROM (VALUES
        (1),(2),(3),(4),(5),(6),(7),(8),(9),(10),(11),(12)
    ) V(N)
)
INSERT INTO dbo.LoanPayments
(
    LoanID,DueDate,PaidDate,AmountDue,AmountPaid,PaymentStatus
)
SELECT
    L.LoanID,
    DATEADD(MONTH,P.N,L.DisbursementDate),
    CASE WHEN L.LoanID%10 IN (0,1,2,3,4,5,6)
         THEN DATEADD(DAY,CASE WHEN L.LoanID%20=0 THEN 15 ELSE 0 END,
                      DATEADD(MONTH,P.N,L.DisbursementDate))
         ELSE NULL END,
    CAST((L.PrincipalAmount*(1+L.AnnualInterestRate/100.0))/L.TermMonths AS DECIMAL(18,2)),
    CASE WHEN L.LoanID%10 IN (0,1,2,3,4,5,6)
         THEN CAST((L.PrincipalAmount*(1+L.AnnualInterestRate/100.0))/L.TermMonths AS DECIMAL(18,2))
         ELSE 0 END,
    CASE WHEN L.LoanID%20=0 THEN 'LATE'
         WHEN L.LoanID%10 IN (0,1,2,3,4,5,6) THEN 'PAID'
         ELSE 'DUE' END
FROM dbo.Loans L
CROSS JOIN PaymentMonths P;
GO

DECLARE @SystemCustomerID INT;

INSERT INTO dbo.Customers
(FirstName,LastName,DateOfBirth,Email,Phone,KYCStatus)
VALUES
('BankCore','System','2000-01-01','system@bankcore.internal','9000000000','VERIFIED');

SET @SystemCustomerID = CONVERT(INT,SCOPE_IDENTITY());

INSERT INTO dbo.Accounts
(CustomerID,BranchID,AccountNumber,AccountType,OpenDate,AccountStatus,CurrencyCode)
VALUES
(@SystemCustomerID,1,'999999999999','CURRENT','2020-01-01','ACTIVE','INR');
GO

SELECT COUNT(*) AS Employees FROM dbo.Employees;
SELECT COUNT(*) AS Accounts FROM dbo.Accounts;
SELECT COUNT(*) AS Loans FROM dbo.Loans;
SELECT COUNT(*) AS LoanPayments FROM dbo.LoanPayments;
