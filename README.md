# BankCore — Banking & Transaction Analytics System

**Author:** Yash Chitransh  
**Program:** MSc Mathematics and Scientific Computing  
**Database:** Microsoft SQL Server / SQL Server Express  
**Interface:** SQL only  
**Dataset:** Synthetic and reproducible  
**Target scale:** 100,000+ transactions

## Overview

BankCore is a SQL-only banking and transaction analytics DBMS project. It models customers, branches, employees, accounts, loans, loan payments, financial transactions, double-entry ledger entries, and audit logs.

The project demonstrates:

- Relational database design and normalization
- Primary/foreign/unique/check/default constraints
- Referential integrity
- Double-entry accounting
- ACID transaction processing with concurrency-safe locking
- Stored procedures with `UPDLOCK`/`HOLDLOCK` account-row serialization
- Posting-state ledger validation and audit logging across banking-critical tables
- Views
- CTEs and window functions
- Covering indexes, execution-plan analysis, and snapshot-vs-ledger performance comparison
- Synthetic data generation at 100K+ transaction scale
- Customer, branch, transaction and loan analytics
- Potential-anomaly screening

> **Academic/demo system only:** all data is synthetic. It is not production banking software and contains no real customer or banking data.

## Technology

| Component | Choice |
|---|---|
| Database | Microsoft SQL Server |
| Recommended client | SQL Server Management Studio (SSMS) |
| Language | T-SQL |
| Frontend | SQL only |
| Data | Synthetic |
| Scale | 100,000+ transactions |
| Compatible with | SQL Server 2017+ |

SQL Server Express is sufficient for the included dataset.

## Database Architecture

```text
CUSTOMERS ───────< ACCOUNTS >─────── BRANCHES
    │                 │                  │
    │                 │                  └──< EMPLOYEES
    │                 │
    │                 └────< TRANSACTION_ENTRIES >──── TRANSACTIONS
    │
    └──────────────< LOANS >──────────< LOAN_PAYMENTS
```

### Main relationships

- One customer → many accounts
- One branch → many accounts
- One branch → many employees
- One customer → many loans
- One loan → many loan payments
- One account → many transaction entries
- One transaction → multiple transaction entries

## Double-entry ledger

A transfer of ₹10,000 is represented as:

```text
Transaction #12345
    Account A  DEBIT   ₹10,000
    Account B  CREDIT  ₹10,000
```

The project validates the invariant:

```text
Total Debits = Total Credits
```

Balances are derived from successful ledger entries:

```text
Balance = SUM(CREDITS) - SUM(DEBITS)
```

## Folder structure

```text
BankCore_SQLServer_Yash_Chitransh/
│
├── README.md
├── sql/
│   ├── 01_Create_Database.sql
│   ├── 02_Create_Tables.sql
│   ├── 03_Seed_Branches_Customers.sql
│   ├── 04_Seed_Employees_Accounts_Loans.sql
│   ├── 05_Create_Ledger_And_Balance_View.sql
│   ├── 06_Create_Transaction_Procedure.sql
│   ├── 07_Create_Audit_Trigger_Views_Indexes.sql
│   ├── 08_Generate_Opening_Balances.sql
│   ├── 09_Generate_100K_Transactions.sql
│   ├── 10_Analytics.sql
│   ├── 11_Testing_And_Integrity.sql
│   └── 12_Performance_Analysis.sql
│
├── docs/
│   ├── ER_Diagram.md
│   ├── Relational_Schema.md
│   └── Project_Report_Outline.md
│
├── data/
│   └── Dataset_Generation_Notes.md
│
└── screenshots/
    └── README.md
```

## Execution order

Run these scripts in SSMS in this exact order:

1. `01_Create_Database.sql`
2. `02_Create_Tables.sql`
3. `03_Seed_Branches_Customers.sql`
4. `04_Seed_Employees_Accounts_Loans.sql`
5. `05_Create_Ledger_And_Balance_View.sql`
6. `06_Create_Transaction_Procedure.sql`
7. `07_Create_Audit_Trigger_Views_Indexes.sql`
8. `08_Generate_Opening_Balances.sql`
9. `09_Generate_100K_Transactions.sql`
10. `10_Analytics.sql`
11. `11_Testing_And_Integrity.sql`
12. `12_Performance_Analysis.sql`

**Important:** Script 01 intentionally recreates `BankCore`. Do not run it against a database containing data you want to keep.

## Expected dataset

| Entity | Target |
|---|---:|
| Branches | 10 |
| Regular customers | 5,000 |
| System customer | 1 |
| Regular accounts | 7,500 |
| System account | 1 |
| Employees | 100 |
| Loans | 1,000 |
| Loan payments | 12,000 |
| Opening transactions | 7,500 |
| Generated transactions | 100,000 |
| Total transactions | 107,500+ |
| Ledger entries | 200,000+ |

## Advanced SQL topics demonstrated

### DDL / integrity
- `CREATE DATABASE`
- `CREATE TABLE`
- `PRIMARY KEY`
- `FOREIGN KEY`
- `UNIQUE`
- `CHECK`
- `DEFAULT`

### T-SQL
- Stored procedures
- `TRY...CATCH`
- `THROW`
- `BEGIN TRANSACTION`
- `COMMIT`
- `ROLLBACK`
- Triggers
- Views
- Temporary tables

### Analytics
- CTEs
- `GROUP BY`
- `HAVING`
- `CASE`
- Subqueries
- `RANK`
- `DENSE_RANK`
- `ROW_NUMBER`
- `LAG`
- `LEAD`
- Running totals
- Month-over-month analysis

### Performance
- Nonclustered indexes
- `SET STATISTICS IO ON`
- `SET STATISTICS TIME ON`
- Actual Execution Plan
- Scan vs seek discussion

## Suggested resume entry

> **BankCore — Banking & Transaction Analytics System:** Designed and implemented a SQL Server banking database with 100K+ synthetic transactions, double-entry ledger accounting, ACID transaction processing, stored procedures, audit logging, indexing, and advanced SQL analytics using CTEs and window functions.

## Viva topics

Be ready to explain:

1. Why transaction headers and ledger entries are separate.
2. How double-entry accounting is represented.
3. How ACID properties are enforced.
4. Stored procedure vs trigger.
5. View vs table.
6. Primary key vs foreign key.
7. `RANK()` vs `DENSE_RANK()` vs `ROW_NUMBER()`.
8. CTE vs subquery.
9. Clustered vs nonclustered indexes.
10. How a rollback works.
11. How account balance is calculated.
12. How query performance was measured.

## Author

**Yash Chitransh**  
**MSc Mathematics and Scientific Computing**

## Disclaimer

All customer names, account numbers, transaction values, branches, loans, and other banking information are synthetic and created only for academic demonstration.


## Improvements added after design review

### 1. Concurrency-safe money transfers
`usp_TransferMoney` locks the source and destination account rows with `UPDLOCK, HOLDLOCK` in deterministic `AccountID` order. This prevents two concurrent transfers from both reading the same stale balance and overspending the source account. The procedure calculates the source balance from successful ledger entries while those account-row locks are held.

### 2. Database-level ledger invariant
Transactions use a posting lifecycle: `PENDING` → `SUCCESS`. Ledger entries are inserted while the transaction is pending, and `trg_Transactions_ValidatePosting` allows the transition to `SUCCESS` only when there are exactly two entries and total debits equal total credits. `FAILED` and `REVERSED` transactions cannot have ledger entries.

The bulk generator follows the same lifecycle instead of bypassing the invariant. This is stronger than relying only on application/procedure logic.

### 3. Stronger banking audit coverage
Audit triggers now cover `Transactions`, `Accounts`, and `Loans`, including INSERT/UPDATE/DELETE actions. Transaction status changes are recorded, and separate triggers avoid ambiguous action labels for mixed DML statements.

### 4. Real performance evidence
`12_Performance_Analysis.sql` contains controlled scan baselines and indexed versions for transaction search and account-history queries. Run with Actual Execution Plan (`Ctrl+M`) plus `STATISTICS IO/TIME`, then record the actual logical reads, CPU time, elapsed time, and seek/scan operators in the report. No benchmark numbers are fabricated in this repository.

### 5. Covering indexes
`TransactionEntries` has covering indexes for both account-history/balance access and transaction-entry lookup. The transaction date/status index uses `(TransactionStatus, TransactionDate)` so the common equality + date-range + ordering pattern has an appropriate access path.

### 6. Balance snapshot architecture
`vw_AccountBalances` remains the authoritative ledger-derived balance. `AccountBalanceSnapshot` is an optional read-optimized snapshot refreshed by `usp_RefreshAccountBalanceSnapshot`, with `vw_AccountBalanceReconciliation` comparing snapshot and ledger balances. This demonstrates how a larger system can avoid aggregating the entire ledger on every balance read without making the snapshot the source of truth.

## Important execution note
Run all SQL files in numeric order. In particular, `07_Create_Audit_Trigger_Views_Indexes.sql` must run **before** `08_Generate_Opening_Balances.sql` and `09_Generate_100K_Transactions.sql`, because the posting-validation trigger is part of the database integrity layer used by those scripts.

## Performance-report template
After running `12_Performance_Analysis.sql`, add a small table to your report with your actual SSMS results:

| Test | Plan | Logical Reads | CPU ms | Elapsed ms |
|---|---|---:|---:|---:|
| Transaction search — scan baseline | Scan | record from SSMS | record | record |
| Transaction search — indexed | Seek/Scan | record from SSMS | record | record |
| Account history — scan baseline | Scan | record | record | record |
| Account history — covering index | Seek | record | record | record |
| Ledger balance — authoritative | Aggregate | record | record | record |
| Snapshot balance — read optimized | Seek/scan | record | record | record |

Do not fill this table with invented values.

## Known academic/demo limitations
- The database uses synthetic data and is not a production core-banking platform.
- SQL Server Express resource limits may affect very large workloads.
- The ledger is authoritative; the balance snapshot must be refreshed/reconciled after bulk data loads.
- The transaction anomaly queries identify patterns for review; they do not prove fraud.
