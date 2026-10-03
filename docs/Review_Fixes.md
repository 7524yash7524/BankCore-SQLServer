# BankCore — Review Fixes

This file documents the engineering improvements made after a code review.

## 1. Concurrency race condition — fixed

### Problem
The transfer procedure previously read the source balance without locking the account row. Two concurrent transfers could therefore both pass the balance check before either committed.

### Fix
`usp_TransferMoney` now:
- locks source and destination account rows with `UPDLOCK, HOLDLOCK`;
- acquires those locks in deterministic `AccountID` order;
- calculates the source balance while the locks are held;
- writes both ledger entries in one transaction;
- commits only after posting to `SUCCESS`.

### Interview explanation
"I serialize concurrent transfers involving the same account by locking the account rows before checking the balance. Deterministic lock ordering also reduces deadlock risk."

## 2. Database-level ledger invariant — fixed

### Problem
Bulk generation could bypass the stored procedure, so ledger balance depended on the calling code.

### Fix
Successful posting is now a database-enforced state transition:

`PENDING -> SUCCESS`

The trigger `trg_Transactions_ValidatePosting` rejects `SUCCESS` unless:
- exactly two ledger entries exist;
- total debit equals total credit.

`FAILED` and `REVERSED` transactions are prevented from having entries.

## 3. Audit coverage — improved

### Problem
Only loans were audited.

### Fix
Audit triggers now cover:
- `Transactions` INSERT/UPDATE/DELETE;
- `Accounts` INSERT/UPDATE/DELETE;
- `Loans` INSERT/UPDATE/DELETE.

Transaction status changes are explicitly recorded because posting/reversal state is important for financial traceability.

## 4. Performance evidence — improved

### Problem
The project had optimization queries but no controlled comparison.

### Fix
`12_Performance_Analysis.sql` now includes:
- forced-scan baseline for transaction search;
- indexed transaction search;
- forced-scan baseline for account history;
- covering-index account history;
- ledger-derived balance query;
- snapshot balance query;
- snapshot/ledger reconciliation;
- actual execution plan instructions;
- `STATISTICS IO` and `STATISTICS TIME`;
- index metadata and missing-index DMV output.

Actual benchmark values must be collected in SSMS and placed in the final report. No values are fabricated.

## 5. Indexing — improved

The transaction date/status index now uses `(TransactionStatus, TransactionDate)`, matching the common equality + date-range + ordering access pattern.

`TransactionEntries` has covering indexes for:
- account history / balance access;
- transaction-to-entry lookups.

## 6. Balance scalability — improved

The authoritative `vw_AccountBalances` still derives balances from the ledger.

For read-heavy workloads, `AccountBalanceSnapshot` can be refreshed and compared through `vw_AccountBalanceReconciliation`. This demonstrates a scalable pattern without changing the ledger source of truth.

## 7. Reproducibility and execution order — improved

The SQL files are numbered so the posting-validation triggers exist before opening balances and the 100K transaction load are generated. Index creation is idempotent with `IF NOT EXISTS` checks.
