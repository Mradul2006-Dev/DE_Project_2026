# R19 franchise player selection counts

The original query counts picks with a correlated subquery. On the faculty seed data, PostgreSQL scanned `user_team_players` 250 times, once for each franchise player in the report. [The rewrite](r19-optimized.sql) aggregates picks by player and left joins the counts. This keeps players with zero picks in the report. The recorded plan used a parallel sequential scan and grouped the 439,925 pick rows once across the workers.

## Result check

Compared all rows in both directions with `EXCEPT ALL`. The 250 seed franchise players matched. A temporary zero-pick franchise player appeared with a count of zero, and a temporary international player was excluded. The check rolled back its fixture rows. Both queries sort by descending pick count. Ordering within ties is unspecified.

## Timing

Three `EXPLAIN (ANALYZE, BUFFERS)` runs per version on the same PostgreSQL 18.6 database loaded with the official seed data on 17 Nov 2026. The original was measured before the rewrite.

| Version | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) |
| --- | ---: | ---: | ---: | ---: |
| [Original](before.txt) | 2261.358 | 2214.660 | 2231.297 | 2235.772 |
| [Rewrite](after.txt) | 20.409 | 20.052 | 22.201 | 20.887 |

The rewrite was about 107× faster for this query on this fixture.

## Run locally

Apply the repository schema and loader to a fresh Dream11 test database. From the repo root, pass its name to the verification script.

```bash
bash analysis/r19/verify.sh dream11_r19
r19_original=$(mktemp)
awk '/^-- @R19[[:space:]]*$/ { found=1; print; next } found && /^-- @/ { exit } found { print }' \
  queries/workload_30.sql > "$r19_original"
bash benchmarks/run_benchmark.sh dream11_r19 r19-before 3 "$r19_original"
bash benchmarks/run_benchmark.sh dream11_r19 r19-after 3 analysis/r19/r19-optimized.sql
rm "$r19_original"
```

Use this R19 section in `sql/06_optimized_queries.sql` when assembling the team workload. Run the full optimized benchmark again after combining the other changes.
