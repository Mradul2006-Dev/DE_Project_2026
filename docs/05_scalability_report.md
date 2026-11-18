# Dream11 scalability report

The faculty project expects a separate approximately 20× archive and asks for the optimized workload on that archive. The seed run and partition experiment below use the released faculty seed data.

<!-- large-results:start -->
## Official large-data measurements

Awaiting the faculty large_data.zip. Run the large-data command in the README when it is available to populate the 30-query table, storage comparison and partition plans here.
<!-- large-results:end -->

## Seed measurements

| Measurement | Bytes |
| --- | ---: |
| Database | 101,619,391 |
| Dream11 table storage | 43,114,496 |
| Dream11 index storage | 49,864,704 |

The [seed timings](../benchmarks/results/optimized/summary.csv) are the reference for growth. The database size includes catalogs. Table storage includes TOAST and auxiliary forks. Index storage is reported separately.

## Wallet partitioning

[The DDL](../sql/08_partitioning.sql) makes a test copy partitioned by UTC month on created_at. It keeps the amount and transaction constraints and the two foreign keys. PostgreSQL requires a partitioned primary key to include the partition column. The test copy uses (created_at, txn_id) with a shared ID sequence. A production migration that needs globally constrained txn_id references would also need a global ID registry or references that include the date.

On the seed fixture, both copies had 118,343 wallet rows and the same total amount and ID range. The June UTC successful-deposit query returned 2,068 rows totalling 1,612,400.00 in both copies. The [partitioned plan](../analysis/partitioning/wallet_transactions_partitioned-seed.txt) reads only wallet_tx_2026_06. The [unpartitioned plan](../analysis/partitioning/wallet_transactions-seed.txt) uses the successful-deposit index over the original table.

R20 has a bounded date range and can prune monthly partitions. R09 is scoped by user and has an all-time running balance, so date partitions alone cannot prune it. Keep the user/time access path for that workload. For the support console, keep global newest-first paging available and offer cursor navigation when the product supports it.

## Architecture at 100× growth

A linear extrapolation from the seed database size is about 10.2 GB at 100×. This is a planning estimate. Validate it against the official run and reserve working space for WAL, indexes, maintenance and temporary files.

- **Shard the wallet by user.** Keep debits, disputes and R09 on the user's shard. Entry and match reports such as R05 and R17 span users. Maintain match-scoped leaderboard and audit projections so the live leaderboard can be read by contest without fan-out on each request.
- **Protect fresh reads.** Keep W01–W05, the immediately updated team or wallet view and R13 on the primary when current state matters. Replay analytics such as R12, R14, R19 and R24 on replicas once acceptable lag is defined. Cache the upcoming lobby and player pool with a short TTL and invalidate on contest publication or roster changes.
- **Maintain hot partitions.** Review dead tuples and analyze lag after payout batches, tune autovacuum thresholds per active monthly partition from measured churn, and keep statistics current. Create future partitions before month rollover. Detach and archive closed months after retention and financial reconciliation checks.
- **Measure the failure cases.** Check deadlines for live queries first, then inspect buffer reads, sort spills and join cardinality for any missed target. Compare plans on the same dataset after making a change and rerun the result checks.

The seed workload runs correctly and the date-range probe prunes the wallet. The large archive is the next verification of target latency and storage growth before a readiness decision.
