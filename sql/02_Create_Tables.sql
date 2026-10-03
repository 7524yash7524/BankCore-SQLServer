USE BankCore;
GO

CREATE TABLE dbo.Branches
(
    BranchID INT IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_Branches PRIMARY KEY,
    BranchCode VARCHAR(10) NOT NULL
        CONSTRAINT UQ_Branches_BranchCode UNIQUE,
    BranchName VARCHAR(100) NOT NULL,
    City VARCHAR(50) NOT NULL,
    State VARCHAR(50) NOT NULL,
    IFSCCode VARCHAR(20) NOT NULL
        CONSTRAINT UQ_Branches_IFSCCode UNIQUE,
    CreatedAt DATETIME2 NOT NULL
        CONSTRAINT DF_Branches_CreatedAt DEFAULT SYSDATETIME()
);
GO

CREATE TABLE dbo.Customers
(
    CustomerID INT IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_Customers PRIMARY KEY,
    FirstName VARCHAR(50) NOT NULL,
    LastName VARCHAR(50) NOT NULL,
    DateOfBirth DATE NOT NULL,
    Email VARCHAR(100) NOT NULL
        CONSTRAINT UQ_Customers_Email UNIQUE,
    Phone VARCHAR(15) NOT NULL
        CONSTRAINT UQ_Customers_Phone UNIQUE,
    KYCStatus VARCHAR(20) NOT NULL
        CONSTRAINT DF_Customers_KYCStatus DEFAULT 'PENDING',
    CreatedAt DATETIME2 NOT NULL
        CONSTRAINT DF_Customers_CreatedAt DEFAULT SYSDATETIME(),
    CONSTRAINT CK_Customers_KYCStatus
        CHECK (KYCStatus IN ('PENDING','VERIFIED','REJECTED'))
);
GO

CREATE TABLE dbo.Employees
(
    EmployeeID INT IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_Employees PRIMARY KEY,
    BranchID INT NOT NULL,
    EmployeeName VARCHAR(100) NOT NULL,
    JobTitle VARCHAR(50) NOT NULL,
    HireDate DATE NOT NULL,
    CreatedAt DATETIME2 NOT NULL
        CONSTRAINT DF_Employees_CreatedAt DEFAULT SYSDATETIME(),
    CONSTRAINT FK_Employees_Branches
        FOREIGN KEY (BranchID) REFERENCES dbo.Branches(BranchID)
);
GO

CREATE TABLE dbo.Accounts
(
    AccountID BIGINT IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_Accounts PRIMARY KEY,
    CustomerID INT NOT NULL,
    BranchID INT NOT NULL,
    AccountNumber VARCHAR(20) NOT NULL
        CONSTRAINT UQ_Accounts_AccountNumber UNIQUE,
    AccountType VARCHAR(20) NOT NULL,
    OpenDate DATE NOT NULL,
    AccountStatus VARCHAR(20) NOT NULL
        CONSTRAINT DF_Accounts_Status DEFAULT 'ACTIVE',
    CurrencyCode CHAR(3) NOT NULL
        CONSTRAINT DF_Accounts_Currency DEFAULT 'INR',
    CreatedAt DATETIME2 NOT NULL
        CONSTRAINT DF_Accounts_CreatedAt DEFAULT SYSDATETIME(),
    CONSTRAINT CK_Accounts_AccountType
        CHECK (AccountType IN ('SAVINGS','CURRENT','SALARY','FIXED_DEPOSIT')),
    CONSTRAINT CK_Accounts_Status
        CHECK (AccountStatus IN ('ACTIVE','FROZEN','CLOSED')),
    CONSTRAINT CK_Accounts_Currency
        CHECK (CurrencyCode = 'INR'),
    CONSTRAINT FK_Accounts_Customers
        FOREIGN KEY (CustomerID) REFERENCES dbo.Customers(CustomerID),
    CONSTRAINT FK_Accounts_Branches
        FOREIGN KEY (BranchID) REFERENCES dbo.Branches(BranchID)
);
GO

CREATE TABLE dbo.Transactions
(
    TransactionID BIGINT IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_Transactions PRIMARY KEY,
    ReferenceNumber VARCHAR(30) NOT NULL
        CONSTRAINT UQ_Transactions_ReferenceNumber UNIQUE,
    TransactionType VARCHAR(20) NOT NULL,
    TransactionStatus VARCHAR(20) NOT NULL
        CONSTRAINT DF_Transactions_Status DEFAULT 'PENDING',
    Amount DECIMAL(18,2) NOT NULL,
    CurrencyCode CHAR(3) NOT NULL
        CONSTRAINT DF_Transactions_Currency DEFAULT 'INR',
    TransactionDate DATETIME2 NOT NULL
        CONSTRAINT DF_Transactions_Date DEFAULT SYSDATETIME(),
    Description VARCHAR(255) NULL,
    CreatedAt DATETIME2 NOT NULL
        CONSTRAINT DF_Transactions_CreatedAt DEFAULT SYSDATETIME(),
    CONSTRAINT CK_Transactions_Type
        CHECK (TransactionType IN ('TRANSFER','DEPOSIT','WITHDRAWAL','FEE','INTEREST')),
    CONSTRAINT CK_Transactions_Status
        CHECK (TransactionStatus IN ('PENDING','SUCCESS','FAILED','REVERSED')),
    CONSTRAINT CK_Transactions_Amount CHECK (Amount > 0),
    CONSTRAINT CK_Transactions_Currency CHECK (CurrencyCode = 'INR')
);
GO

CREATE TABLE dbo.TransactionEntries
(
    EntryID BIGINT IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_TransactionEntries PRIMARY KEY,
    TransactionID BIGINT NOT NULL,
    AccountID BIGINT NOT NULL,
    EntryType VARCHAR(10) NOT NULL,
    Amount DECIMAL(18,2) NOT NULL,
    CreatedAt DATETIME2 NOT NULL
        CONSTRAINT DF_TransactionEntries_CreatedAt DEFAULT SYSDATETIME(),
    CONSTRAINT CK_TransactionEntries_Type
        CHECK (EntryType IN ('DEBIT','CREDIT')),
    CONSTRAINT CK_TransactionEntries_Amount CHECK (Amount > 0),
    CONSTRAINT FK_TransactionEntries_Transactions
        FOREIGN KEY (TransactionID) REFERENCES dbo.Transactions(TransactionID),
    CONSTRAINT FK_TransactionEntries_Accounts
        FOREIGN KEY (AccountID) REFERENCES dbo.Accounts(AccountID)
);
GO

CREATE TABLE dbo.Loans
(
    LoanID BIGINT IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_Loans PRIMARY KEY,
    CustomerID INT NOT NULL,
    BranchID INT NOT NULL,
    LoanType VARCHAR(20) NOT NULL,
    PrincipalAmount DECIMAL(18,2) NOT NULL,
    AnnualInterestRate DECIMAL(5,2) NOT NULL,
    TermMonths INT NOT NULL,
    DisbursementDate DATE NOT NULL,
    LoanStatus VARCHAR(20) NOT NULL
        CONSTRAINT DF_Loans_Status DEFAULT 'ACTIVE',
    CreatedAt DATETIME2 NOT NULL
        CONSTRAINT DF_Loans_CreatedAt DEFAULT SYSDATETIME(),
    CONSTRAINT CK_Loans_Type
        CHECK (LoanType IN ('HOME','PERSONAL','EDUCATION','VEHICLE','BUSINESS')),
    CONSTRAINT CK_Loans_Principal CHECK (PrincipalAmount > 0),
    CONSTRAINT CK_Loans_Interest CHECK (AnnualInterestRate BETWEEN 0 AND 100),
    CONSTRAINT CK_Loans_Term CHECK (TermMonths > 0),
    CONSTRAINT CK_Loans_Status CHECK (LoanStatus IN ('ACTIVE','CLOSED','DEFAULT')),
    CONSTRAINT FK_Loans_Customers
        FOREIGN KEY (CustomerID) REFERENCES dbo.Customers(CustomerID),
    CONSTRAINT FK_Loans_Branches
        FOREIGN KEY (BranchID) REFERENCES dbo.Branches(BranchID)
);
GO

CREATE TABLE dbo.LoanPayments
(
    PaymentID BIGINT IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_LoanPayments PRIMARY KEY,
    LoanID BIGINT NOT NULL,
    DueDate DATE NOT NULL,
    PaidDate DATE NULL,
    AmountDue DECIMAL(18,2) NOT NULL,
    AmountPaid DECIMAL(18,2) NOT NULL
        CONSTRAINT DF_LoanPayments_AmountPaid DEFAULT 0,
    PaymentStatus VARCHAR(20) NOT NULL
        CONSTRAINT DF_LoanPayments_Status DEFAULT 'DUE',
    CONSTRAINT CK_LoanPayments_AmountDue CHECK (AmountDue > 0),
    CONSTRAINT CK_LoanPayments_AmountPaid CHECK (AmountPaid >= 0),
    CONSTRAINT CK_LoanPayments_Status
        CHECK (PaymentStatus IN ('DUE','PAID','LATE','PARTIAL')),
    CONSTRAINT FK_LoanPayments_Loans
        FOREIGN KEY (LoanID) REFERENCES dbo.Loans(LoanID)
);
GO

CREATE TABLE dbo.AuditLog
(
    AuditID BIGINT IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_AuditLog PRIMARY KEY,
    TableName VARCHAR(100) NOT NULL,
    ActionType VARCHAR(20) NOT NULL,
    RecordID VARCHAR(100) NOT NULL,
    ChangedAt DATETIME2 NOT NULL
        CONSTRAINT DF_AuditLog_ChangedAt DEFAULT SYSDATETIME(),
    Details VARCHAR(MAX) NULL
);
GO
