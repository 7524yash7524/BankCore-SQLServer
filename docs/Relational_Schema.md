# BankCore Relational Schema

- `Branches(BranchID PK, BranchCode UQ, BranchName, City, State, IFSCCode UQ, CreatedAt)`
- `Customers(CustomerID PK, FirstName, LastName, DateOfBirth, Email UQ, Phone UQ, KYCStatus, CreatedAt)`
- `Employees(EmployeeID PK, BranchID FK→Branches, EmployeeName, JobTitle, HireDate, CreatedAt)`
- `Accounts(AccountID PK, CustomerID FK→Customers, BranchID FK→Branches, AccountNumber UQ, AccountType, OpenDate, AccountStatus, CurrencyCode, CreatedAt)`
- `Transactions(TransactionID PK, ReferenceNumber UQ, TransactionType, TransactionStatus, Amount, CurrencyCode, TransactionDate, Description, CreatedAt)`
- `TransactionEntries(EntryID PK, TransactionID FK→Transactions, AccountID FK→Accounts, EntryType, Amount, CreatedAt)`
- `Loans(LoanID PK, CustomerID FK→Customers, BranchID FK→Branches, LoanType, PrincipalAmount, AnnualInterestRate, TermMonths, DisbursementDate, LoanStatus, CreatedAt)`
- `LoanPayments(PaymentID PK, LoanID FK→Loans, DueDate, PaidDate, AmountDue, AmountPaid, PaymentStatus)`
- `AuditLog(AuditID PK, TableName, ActionType, RecordID, ChangedAt, Details)`

The design separates independent business facts to reduce update anomalies and supports a double-entry ledger without storing a separate mutable account balance.
