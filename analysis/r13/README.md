# Himank: R13 finance audit handoff

GitHub username: **Onlyhimank**. The account accepted the team repository invitation and contributed this analysis.

## Findings

The original query uses `NOT IN` against every `reference_entry_id`. The schema allows NULL for deposits, bonuses and withdrawals. If any NULL appears in that list, an unmatched entry evaluates to UNKNOWN and is filtered out. The baseline plan records zero rows and an average of 17.110 ms over three recorded executions (16.474, 17.455, 17.400 ms). This is the original query's result and timing, not proof that there are no missing debits.

Filtering NULL alone is insufficient: a refund, failed entry-fee transaction or pending entry-fee transaction can suppress an entry even if no successful debit exists. `r13-correction.sql` uses `NOT EXISTS` and looks specifically for `ENTRY_FEE` with `SUCCESS`. The status condition assumes only a successful debit counts; confirm this business rule with the team.

## Tests and limitations

`test.sql` was executed in PostgreSQL against temporary synthetic tables. It tests a NULL reference, a successful debit, a refund, failed and pending debits, and a free contest. The original query returned no entries both with and without the NULL; the corrected query returned entries 2, 3 and 4 as expected. See `test-output.txt`. This validates the example, not the real dataset or performance.

The original handoff ZIP did not contain `seed_data.zip`; the faculty starter supplied it during the subsequent team setup. The corrected query was later tested on the seed data as described below. Before CP3, run it against the team's actual database, verify the business rule, and benchmark three `EXPLAIN (ANALYZE, BUFFERS)` runs with and without the candidate partial index. Do not claim an optimized speedup until measured. Mradul combines the final SQL and timings.

For CP5, be prepared to explain SQL three-valued logic, why `NOT EXISTS` handles NULL safely, why the transaction type and status matter, and the measured plan and timing once available.

## Real seed data follow-up

The faculty starter fetched during Mradul's setup includes `seed_data.zip`. On 17 November 2026, the schema and all ten seed CSVs were loaded into an isolated PostgreSQL instance. The data contains 63,000 NULL references. The original R13 returned zero rows; the corrected query returned 192 paid entries without a successful entry-fee transaction. This remains subject to confirming that SUCCESS is the intended business rule. One exploratory corrected-query run took 11.921 ms; this is not a three-run benchmark and should not be compared as a reliable speedup. See `real-data-results.txt` for the plan.
