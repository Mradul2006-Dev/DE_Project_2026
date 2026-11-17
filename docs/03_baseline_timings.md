# Dream11 baseline timings

Measured on an Apple M4 MacBook Pro with 16 GB RAM and PostgreSQL 18.6. The database contains the ten seed CSVs, with statistics collected after the load. All indexes at this stage come from primary-key or unique constraints.

The supplied benchmark script ran each query three times with `EXPLAIN (ANALYZE, BUFFERS)`. The numbers are PostgreSQL execution times in milliseconds. Each write ran in a transaction that rolled back.

| Query | Type | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) |
| --- | --- | ---: | ---: | ---: | ---: |
| R01 | READ | 0.280 | 0.280 | 0.303 | 0.288 |
| R02 | READ | 31.645 | 30.892 | 31.167 | 31.235 |
| R03 | READ | 0.048 | 0.059 | 0.047 | 0.051 |
| R04 | READ | 0.257 | 0.248 | 0.277 | 0.261 |
| R05 | READ | 0.491 | 0.511 | 0.512 | 0.505 |
| R06 | READ | 66.171 | 66.267 | 66.933 | 66.457 |
| R07 | READ | 0.084 | 0.123 | 0.081 | 0.096 |
| R08 | READ | 1.324 | 1.461 | 1.253 | 1.346 |
| R09 | READ | 4.904 | 4.770 | 4.547 | 4.740 |
| R10 | READ | 5.180 | 5.146 | 5.322 | 5.216 |
| R11 | READ | 15.460 | 14.295 | 15.684 | 15.146 |
| R12 | READ | 1.031 | 1.023 | 1.032 | 1.029 |
| R13 | READ | 16.474 | 17.455 | 17.400 | 17.110 |
| R14 | READ | 10.766 | 10.384 | 10.656 | 10.602 |
| R15 | READ | 25.510 | 24.363 | 24.540 | 24.804 |
| R16 | READ | 0.102 | 0.106 | 0.103 | 0.104 |
| R17 | READ | 14.496 | 15.391 | 21.212 | 17.033 |
| R18 | READ | 11.923 | 12.575 | 10.962 | 11.820 |
| R19 | READ | 2225.860 | 2427.064 | 2313.932 | 2322.285 |
| R20 | READ | 7.704 | 6.349 | 6.983 | 7.012 |
| R21 | READ | 6.153 | 6.783 | 5.830 | 6.255 |
| R22 | READ | 29.341 | 29.397 | 28.622 | 29.120 |
| R23 | READ | 0.026 | 0.024 | 0.024 | 0.025 |
| R24 | READ | 0.562 | 0.502 | 0.549 | 0.538 |
| R25 | READ | 8.791 | 9.183 | 8.816 | 8.930 |
| W01 | WRITE | 0.607 | 0.613 | 0.729 | 0.650 |
| W02 | WRITE | 0.477 | 0.433 | 0.446 | 0.452 |
| W03 | WRITE | 0.463 | 0.382 | 0.394 | 0.413 |
| W04 | WRITE | 6.817 | 6.987 | 6.758 | 6.854 |
| W05 | WRITE | 5.748 | 5.909 | 5.443 | 5.700 |
| **Total** | | 2498.695 | 2698.975 | 2590.557 | 2596.077 |

The average column total sums the displayed query averages. The slowest query is R19. The plan repeats a scan of the 439,925-row selection table for each qualifying player.

## Reading the query plans

| Query | Scan type in last run | What the plan shows |
| --- | --- | --- |
| R01 | Seq Scan | The fixtures and contests are small, so scanning and grouping them is cheap. |
| R02 | Seq Scan, Index Only Scan | Counting picks requires joining lineups to their selections across all players available for the match. |
| R03 | Index Scan | The unique user, match and label index narrows the lookup before fetching the two player names. |
| R04 | Seq Scan, Index Scan | The query scans the small contest table and looks up entries using the contest ID prefix of the unique key. |
| R05 | Index Only Scan, Index Scan | The contest ID narrows the entries, then their teams are joined and ranked by points. |
| R06 | Seq Scan, Index Only Scan | The roster check repeatedly counts players from one side for the selected lineups. |
| R07 | Index Scan, Index Only Scan | The unique lineup key finds one user team. Primary-key lookups retrieve its selections and scores. |
| R08 | Seq Scan | The query scans saved lineups for the match, then groups them by captain. |
| R09 | Seq Scan | The wallet scan filters by user and status before calculating the running balance. |
| R10 | Seq Scan | The wallet scan filters all rows by withdrawal type, pending status and age. |
| R11 | Seq Scan | The report joins paid contests, entries, lineups and people before grouping by user. |
| R12 | Seq Scan | The match and stats tables are small enough to scan and aggregate by player. |
| R13 | Seq Scan | The subplan scans wallet references to build the NOT IN lookup. The plan returns zero qualifying entries. |
| R14 | Seq Scan, Index Scan | The fill-rate calculation visits the entries for many completed contests before averaging by type. |
| R15 | Seq Scan | Winnings across the year require a broad entry scan and joins to the owner of each lineup. |
| R16 | Seq Scan | A text search scans the small player table and sorts its matching names. |
| R17 | Seq Scan | The query reads many entries and their lineups, then groups by user and contest. |
| R18 | Seq Scan | The report filters the wallet ledger for successful winnings and groups by users with unverified KYC. |
| R19 | Seq Scan | The correlated count scans user_team_players again for each qualifying franchise player. |
| R20 | Seq Scan | The ledger scan filters deposit rows by status and date before building daily totals. |
| R21 | Seq Scan | The query filters to head-to-head contests, joins the registered lineups and aggregates win rates. |
| R22 | Seq Scan | The query sorts wallet transactions by time, then skips 50,000 rows to reach the requested page. |
| R23 | Index Scan | The unique phone index supports a single exact-match lookup. |
| R24 | Seq Scan | The query joins and sorts match scores for a small roster to find its last five fixtures per player. |
| R25 | Seq Scan | The audit joins abandoned matches and their entries and checks the wallet for refunds. |
| W01 | Seq Scan | A small match scan supplies the two captain IDs for one insert. |
| W02 | Index Scan, Seq Scan | The query finds the latest lineup ID and uses the contest-entry unique key to handle a collision. |
| W03 | Index Only Scan, Index Scan | Primary-key lookups find the latest entry, its contest and the paying user. |
| W04 | Seq Scan, Index Only Scan, Index Scan | The points update groups selections and match scores for the target fixture before writing the totals. |
| W05 | Seq Scan | The update scans the wallet for qualifying withdrawals before changing their status. |

The baseline results directory contains the summary CSV and the three raw execution plans for each query.
