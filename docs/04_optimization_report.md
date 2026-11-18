# Dream11 optimization report

Measured on the same Apple M4 MacBook Pro with 16 GB RAM and PostgreSQL 18.6. Both databases came from one load of the ten faculty seed CSVs. The baseline copy had constraint indexes. The optimized copy applied the nine indexes in [05_indexes.sql](../sql/05_indexes.sql) and collected statistics. Each query used three EXPLAIN (ANALYZE, BUFFERS) runs. All write runs rolled back.

The paired [baseline](../benchmarks/results/optimized/paired_baseline/summary.csv) and [optimized results](../benchmarks/results/optimized/summary.csv) support this table. The original CP2 archive remains available in [baseline](../benchmarks/results/baseline/summary.csv).

The sum of the 30 average execution times went from **2950.536 ms** to **200.795 ms** on this fixture.

| Query | Before (ms) | Problem found in original plan | Optimization applied | After (ms) | Improvement | Same result? |
| --- | ---: | --- | --- | ---: | ---: | --- |
| R01 | 1.488 | Seq Scan on contests / Seq Scan on matches | Match/type index available. The seed plan scans the small contest table. | 0.376 | +74.7% | Exact rows |
| R02 | 69.120 | Candidate players multiplied by the match teams before aggregation. | Count picks once per match and use the match-team index. | 1.683 | +97.6% | Exact rows |
| R03 | 0.055 | Index Scan using user_teams_user_id_match_id_team_label_key on user_teams / Index Scan using players_pkey on players | Keep the faculty query and its existing access paths. | 0.046 | +16.4% | Exact rows |
| R04 | 0.251 | Seq Scan on contests / Index Scan using contest_entries_contest_id_user_team_id_key on contest_entries | Match/type index and existing contest-entry key. | 0.129 | +48.6% | Exact rows |
| R05 | 0.466 | Index Only Scan using contest_entries_contest_id_user_team_id_key on contest_entries / Index Scan using user_teams_pkey on user_teams | Keep the faculty query and its existing access paths. | 0.450 | +3.4% | Exact rows |
| R06 | 68.208 | Side counts repeated for each selected player. | Aggregate once per team and side. Use the match-team index. | 2.374 | +96.5% | Exact rows |
| R07 | 0.083 | Index Scan using user_teams_user_id_match_id_team_label_key on user_teams / Index Only Scan using user_team_players_pkey on user_team_players | Keep the faculty query and its existing access paths. | 0.082 | +1.2% | Exact rows |
| R08 | 1.550 | Seq Scan on user_teams / Seq Scan on players | Read the match teams through the match-team index. | 0.338 | +78.2% | Exact rows |
| R09 | 5.191 | Wallet scan filters unrelated users before sorting. | Successful-wallet partial index starts with user, then time and transaction ID. | 0.069 | +98.7% | Exact rows |
| R10 | 6.011 | Wallet scan reads rows that are not pending withdrawals. | Pending-withdrawal partial index seeks by time. | 0.043 | +99.3% | Exact rows |
| R11 | 14.537 | Seq Scan on contest_entries / Seq Scan on user_teams | Keep the faculty query and its existing access paths. | 14.913 | -2.6% | Exact rows |
| R12 | 1.088 | Seq Scan on player_match_stats / Seq Scan on matches | Keep the faculty query and its existing access paths. | 1.352 | -24.3% | Exact rows |
| R13 | 18.945 | NULL wallet references turn the NOT IN test unknown. | Correct the NULL bug with NOT EXISTS and a successful-debit partial index. | 8.538 | +54.9% | Corrected, oracle matches |
| R14 | 10.436 | Year extracted for every matching timestamp. | Use a half-open timestamp range for 2026. | 18.315 | -75.5% | Exact rows |
| R15 | 22.174 | Seq Scan on contest_entries / Seq Scan on user_teams | Keep the faculty query and its existing access paths. | 48.236 | -117.5% | Exact rows |
| R16 | 0.115 | Seq Scan on players / Seq Scan on teams | Keep the faculty query and its existing access paths. | 0.113 | +1.7% | Exact rows |
| R17 | 13.055 | Seq Scan on contest_entries / Seq Scan on user_teams | Keep the faculty query and its existing access paths. | 17.531 | -34.3% | Exact rows |
| R18 | 11.300 | Seq Scan on wallet_transactions / Seq Scan on users | Winning transactions use a partial index. Keep the original grouping. | 7.894 | +30.1% | Exact rows |
| R19 | 2641.598 | Wallet-independent pick table scanned repeatedly by the correlated count. | Count picks once per player and left join the totals. | 54.371 | +97.9% | Exact rows |
| R20 | 6.774 | Date cast prevents using the raw timestamp range. | Use a half-open June range and the successful-deposit partial index. | 0.535 | +92.1% | Exact rows |
| R21 | 5.956 | Seq Scan on user_teams / Seq Scan on contest_entries | Keep the faculty query and its existing access paths. | 6.327 | -6.2% | Exact rows |
| R22 | 27.422 | Sort before skipping 50,000 rows. | Use the covering time index while preserving the exact requested page. | 5.944 | +78.3% | Exact rows |
| R23 | 0.027 | Index Scan using users_phone_key on users | Keep the faculty query and its existing access paths. | 0.025 | +7.4% | Exact rows |
| R24 | 0.540 | Seq Scan on player_match_stats / Seq Scan on players | Keep the faculty query and its existing access paths. | 0.586 | -8.5% | Exact rows |
| R25 | 9.486 | Seq Scan on wallet_transactions / Seq Scan on contest_entries | Probe refund references using the partial refund index. | 3.445 | +63.7% | Exact rows |
| W01 | 0.484 | Seq Scan on matches | Maintain the new match-team index on insert. | 1.131 | -133.7% | Same write statement |
| W02 | 0.368 | Index Scan using user_teams_pkey on user_teams / Seq Scan on contests | Use the match/team and contest match/type indexes. | 0.475 | -29.1% | Same write statement |
| W03 | 0.454 | Index Only Scan using contest_entries_pkey on contest_entries / Index Scan using contest_entries_pkey on contest_entries | Maintain wallet history and the matching partial indexes on insert. | 0.634 | -39.6% | Same write statement |
| W04 | 7.493 | Seq Scan on user_teams / Index Only Scan using user_team_players_pkey on user_team_players | Limit update candidates to match 183 using the match-team index. | 4.136 | +44.8% | Same team IDs and points |
| W05 | 5.861 | Seq Scan on wallet_transactions | Locate pending withdrawals with the cutoff index before changing status. | 0.704 | +88.0% | Same write statement |
| **Total** | **2950.536** | | | **200.795** | **+93.2%** | |

## Verify the results

[The comparison log](../benchmarks/results/optimized/equivalence.txt) records exact result multisets for 24 original reads, with sort keys preserved for ordered queries. It also compares the team IDs and assigned points for all 278 updates in W04. Both W04 transactions roll back.

R13 originally returned 0 rows. A wallet transaction such as a deposit can have a NULL reference. NOT IN returns unknown when there is no positive match and a NULL remains in the set. The rewrite looks for a successful ENTRY_FEE debit with NOT EXISTS. An independent left anti-join over successful entry-fee references agrees on all 192 candidates.

## Five largest time reductions with matching results

| Query | Saved (ms) | Evidence |
| --- | ---: | --- |
| R19 | 2587.227 | [Before](../benchmarks/results/optimized/paired_baseline/R19.txt) · [After](../benchmarks/results/optimized/R19.txt) |
| R02 | 67.437 | [Before](../benchmarks/results/optimized/paired_baseline/R02.txt) · [After](../benchmarks/results/optimized/R02.txt) |
| R06 | 65.834 | [Before](../benchmarks/results/optimized/paired_baseline/R06.txt) · [After](../benchmarks/results/optimized/R06.txt) |
| R22 | 21.478 | [Before](../benchmarks/results/optimized/paired_baseline/R22.txt) · [After](../benchmarks/results/optimized/R22.txt) |
| R20 | 6.239 | [Before](../benchmarks/results/optimized/paired_baseline/R20.txt) · [After](../benchmarks/results/optimized/R20.txt) |

## Write overhead

| Query | Before (ms) | After (ms) | Added time (ms) |
| --- | ---: | ---: | ---: |
| W01 | 0.484 | 1.131 | +0.647 |
| W02 | 0.368 | 0.475 | +0.107 |
| W03 | 0.454 | 0.634 | +0.180 |
| W04 | 7.493 | 4.136 | -3.357 |
| W05 | 5.861 | 0.704 | -5.157 |

W01 adds a match-team index entry. W03 adds history and successful-debit index entries alongside the wallet row. The measured insert means stay under 5 ms on seed. Millisecond differences include cache and run-to-run noise. W04 seeks the match's teams for its update. W05 finds the pending rows with a partial index before removing those entries from the pending subset.

## Index storage

The recorded sizes use pg_relation_size for each index and its table heap.

| Index | Table | Index bytes | Table heap bytes | Index / heap |
| --- | --- | ---: | ---: | ---: |
| contests_match_type_idx | contests | 155,648 | 425,984 | 36.5% |
| user_teams_match_idx | user_teams | 1,654,784 | 3,932,160 | 42.1% |
| wallet_history_time_idx | wallet_transactions | 8,060,928 | 9,568,256 | 84.2% |
| wallet_pending_withdrawal_time_idx | wallet_transactions | 16,384 | 9,568,256 | 0.2% |
| wallet_refund_entry_ref_idx | wallet_transactions | 32,768 | 9,568,256 | 0.3% |
| wallet_success_deposit_time_idx | wallet_transactions | 1,400,832 | 9,568,256 | 14.6% |
| wallet_success_entry_ref_idx | wallet_transactions | 974,848 | 9,568,256 | 10.2% |
| wallet_success_user_time_idx | wallet_transactions | 6,881,280 | 9,568,256 | 71.9% |
| wallet_success_winnings_user_idx | wallet_transactions | 409,600 | 9,568,256 | 4.3% |

The wallet history index buys an ordered scan for R22 at the cost of storing the visible support fields. The exact page still skips 50,000 entries. A cursor would help sequential browsing when the product can carry the last seen key.

## Remaining expensive plans

R11, R15 and R17 touch a broad share of the entry or team tables. Their plans still use sequential scans and joins. R14 and R18 are sensitive to how many contests and winning transactions qualify. R16 searches a small player dimension, and R23 already uses its unique phone index. The large run will show where these choices need revisiting.
