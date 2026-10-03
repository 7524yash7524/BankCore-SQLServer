# Synthetic Dataset

The SQL scripts generate the dataset inside SQL Server.

Target:
- 10 branches
- 5,000 regular customers + 1 system customer
- 7,500 regular accounts + 1 system account
- 100 employees
- 1,000 loans
- 12,000 loan payments
- 7,500 opening transactions
- 100,000 generated transactions
- 200,000+ ledger entries

All records are synthetic. No external or confidential banking data is used.


## Posting and integrity model

Generated successful transactions are created as `PENDING`, receive their two ledger entries, and are then posted to `SUCCESS`. A database trigger validates the two-entry/equal-debit-credit invariant at posting time. Failed transactions remain `FAILED` and receive no entries.
