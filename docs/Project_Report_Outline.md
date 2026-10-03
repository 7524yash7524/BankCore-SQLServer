# Project Report Outline

1. Title Page
2. Abstract
3. Introduction
4. Problem Statement
5. Objectives
6. Technology Used
7. Requirements
8. ER Diagram
9. Relational Schema
10. Normalization
11. Constraints and Referential Integrity
12. Double-Entry Ledger Design
13. Transaction Processing and ACID
14. Stored Procedure
15. Trigger and Audit Logging
16. Views
17. Synthetic Dataset Generation
18. Concurrency Control and Race-Condition Prevention
19. Indexing and Query Optimization
20. Transaction Analytics
21. Customer Analytics
22. Branch Analytics
23. Loan Analytics
24. Anomaly Screening
25. Testing
26. Results
27. Limitations
28. Future Scope
29. Conclusion


## Evidence to capture for the performance section
- Actual Execution Plan for the transaction date/status query
- `STATISTICS IO` logical reads and `STATISTICS TIME` CPU/elapsed time
- Account-history query using the covering index
- Ledger-derived balance query versus `AccountBalanceSnapshot` query
- Index metadata output
- Any missing-index DMV recommendation that is actually validated before adoption


## Recommended technical discussion points

### Concurrency control
Explain the lost-update/overspending race: two transfers can otherwise read the same balance before either commits. BankCore serializes the source/destination account rows using `UPDLOCK, HOLDLOCK` in deterministic order.

### Ledger integrity
Explain why `PENDING` is used: the transaction header exists before the two ledger entries, but the transaction is not marked `SUCCESS` until the entries are present and balanced. The posting trigger enforces this invariant inside the database.

### Audit design
Explain that separate DML triggers preserve correct action labels for INSERT, UPDATE, and DELETE, and that transaction status changes are especially important for financial traceability.

### Performance evidence
Use actual SSMS execution plans and `STATISTICS IO/TIME`. Compare forced-scan baselines with indexed queries. Discuss the trade-off between a ledger-derived balance and a reconciled balance snapshot.
