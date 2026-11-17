# Wallet baseline review: R09 and R10

Sujay Barui | Team T0120 | 17 November 2026

This review uses the team’s existing CP2 baseline plans and summary. These are recorded measurements, not a new benchmark.

| Query | Purpose | Three execution times (ms) | Average (ms) | Recorded scan |
| --- | --- | --- | --- | --- |
| R09 | Successful wallet transactions and running balance for user 1006 | 4.904, 4.770, 4.547 | 4.740 | Sequential scan on wallet_transactions |
| R10 | Pending withdrawals older than 24 hours at the query’s fixed cutoff | 5.180, 5.146, 5.322 | 5.216 | Sequential scan on wallet_transactions |

The 30-query summary was checked against all three execution-time lines in each of the 30 raw plans: 90 timings matched. The report’s R09 and R10 values match those plans. See benchmarks/results/baseline/R09.txt, R10.txt, and summary.csv.

R09 filters user 1006 and successful transactions, then orders by created_at and txn_id for a running balance. Deposits, winnings, bonuses and refunds count as credits; other transaction types count as debits. R10 filters pending withdrawals before a fixed timestamp and orders by creation time.

Potential CP3 experiments are an index on (user_id, created_at, txn_id) restricted to successful transactions for R09 and a partial index on created_at restricted to pending withdrawals for R10. These are candidates, not measured improvements. Before adopting them, compare results and run the full before/after benchmark on the same data; also measure write overhead and index sizes. Keep the CP2 baseline unchanged.
