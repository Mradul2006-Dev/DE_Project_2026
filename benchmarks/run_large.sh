#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

if [[ $# -lt 1 || $# -gt 2 ]] || { [[ $# -eq 2 ]] && [[ "$2" != --rehearsal ]]; }; then
  echo 'Usage: bash benchmarks/run_large.sh <faculty-archive.zip> [--rehearsal]' >&2
  exit 2
fi
mode=official
if [[ $# -eq 2 ]]; then mode=rehearsal; fi
if [[ ! -f "$1" ]]; then
  echo 'Place the faculty archive on your computer and pass its ZIP path.' >&2
  exit 1
fi

root=$(cd -- "$(dirname -- "$0")/.." && pwd)
archive=$(cd -- "$(dirname -- "$1")" && pwd)/$(basename -- "$1")
scratch=$(mktemp -d)
database="dream11_cp4_$(date +%s)_$$"
created=0
lock=''
cleanup() {
  if [[ "$created" == 1 ]]; then dropdb --if-exists "$database" || true; fi
  if [[ -n "$lock" ]]; then rmdir -- "$lock" || true; fi
  rm -rf -- "$scratch"
}
trap cleanup EXIT

if [[ "$mode" == official ]]; then
  candidate_lock="$root/benchmarks/results/.large-run-lock"
  if ! mkdir "$candidate_lock"; then
    echo 'Another large-data run is active in this checkout.' >&2
    exit 1
  fi
  lock="$candidate_lock"
fi

mkdir "$scratch/seed_data"
unzip -Z1 "$archive" > "$scratch/archive-entries"
for table in teams players matches player_match_stats users user_teams user_team_players contests contest_entries wallet_transactions; do
  member=$(awk -v csv="$table.csv" -F/ '$NF == csv { path=$0; count++ }
      END { if (count != 1) exit 1; print path }' "$scratch/archive-entries") ||
    { printf 'Expected one %s.csv in the archive.\n' "$table" >&2; exit 1; }
  unzip -p "$archive" "$member" > "$scratch/seed_data/$table.csv"
  test -s "$scratch/seed_data/$table.csv"
done

createdb "$database"
created=1
(
  cd "$scratch"
  psql -X -q -v ON_ERROR_STOP=1 -d "$database" -f "$root/sql/01_schema.sql" -f "$root/sql/02_load_data.sql" > "$scratch/load.log"
)
picks=$(psql -X -qAt -v ON_ERROR_STOP=1 -d "$database" -c 'SELECT count(*) FROM dream11.user_team_players')
wallet=$(psql -X -qAt -v ON_ERROR_STOP=1 -d "$database" -c 'SELECT count(*) FROM dream11.wallet_transactions')
if [[ "$mode" == official ]] && { [[ "$picks" -le 439925 ]] || [[ "$wallet" -le 118343 ]]; }; then
  echo 'The loaded archive has seed-sized tables. Supply the faculty large archive or use --rehearsal.' >&2
  exit 1
fi

psql -X -q -v ON_ERROR_STOP=1 -d "$database" -f "$root/sql/05_indexes.sql" > "$scratch/indexes.log"
mkdir -p "$scratch/benchmark/benchmarks"
cp "$root/benchmarks/run_benchmark.sh" "$scratch/benchmark/benchmarks/"
bash "$scratch/benchmark/benchmarks/run_benchmark.sh" "$database" large 3 "$root/sql/06_optimized_queries.sql"
results="$scratch/benchmark/benchmarks/results/large"
for id in $(printf 'R%02d\n' {1..25}) $(printf 'W%02d\n' {1..5}); do
  test "$(grep -c '^Execution Time:' "$results/$id.txt")" = 3
done

psql -X -qAt -F , -v ON_ERROR_STOP=1 -d "$database" <<'SQL' > "$results/storage.csv"
SELECT 'measurement', 'bytes'
UNION ALL SELECT 'database', pg_database_size(current_database())::text
UNION ALL SELECT 'tables', sum(pg_table_size(c.oid))::text
    FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'dream11' AND c.relkind = 'r'
UNION ALL SELECT 'indexes', sum(pg_indexes_size(c.oid))::text
    FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'dream11' AND c.relkind = 'r';
SQL

psql -X -q -v ON_ERROR_STOP=1 -d "$database" -f "$root/sql/08_partitioning.sql" > "$scratch/partition-load.log"
month=$(psql -X -qAt -v ON_ERROR_STOP=1 -d "$database" <<'SQL'
SELECT to_char(month_start, 'YYYY-MM-DD') || '|' || to_char(month_start + interval '1 month', 'YYYY-MM-DD')
FROM (
    SELECT date_trunc('month', max(created_at) AT TIME ZONE 'UTC') AS month_start
    FROM dream11.wallet_transactions
    WHERE txn_type = 'DEPOSIT' AND status = 'SUCCESS'
) dates;
SQL
)
IFS='|' read -r first next <<< "$month"
[[ "$first" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ && "$next" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]
for table in wallet_transactions wallet_transactions_partitioned; do
  select_sql="SELECT count(*), sum(amount) FROM dream11.$table
    WHERE txn_type = 'DEPOSIT' AND status = 'SUCCESS'
      AND created_at >= TIMESTAMPTZ '$first 00:00:00+00'
      AND created_at < TIMESTAMPTZ '$next 00:00:00+00'"
  psql -X -qAt -v ON_ERROR_STOP=1 -d "$database" -c "$select_sql" > "$scratch/$table-result"
  psql -X -qAt -v ON_ERROR_STOP=1 -d "$database" -c "EXPLAIN (ANALYZE, BUFFERS) $select_sql" \
    > "$results/$table-plan.txt"
done
cmp "$scratch/wallet_transactions-result" "$scratch/wallet_transactions_partitioned-result"
child=$(printf '%s\n' "$first" | cut -c1-7 | tr '-' '_')
grep -q "wallet_tx_$child" "$results/wallet_transactions_partitioned-plan.txt"
test "$(grep -Eo 'wallet_tx_[0-9]{4}_[0-9]{2}' "$results/wallet_transactions_partitioned-plan.txt" | sort -u | wc -l | awk '{print $1}')" = 1
printf '%s UTC month; matching rows and total: %s\n' "$first" "$(cat "$scratch/wallet_transactions-result")" > "$results/partition-check.txt"

version=$(psql -X -qAt -v ON_ERROR_STOP=1 -d "$database" -c 'SHOW server_version')
report="$scratch/measurements.md"
if [[ "$mode" == official ]]; then
  heading='Official large-data measurements'
  links='../benchmarks/results/large/'
else
  heading='Seed rehearsal of the large-data run'
  links='./'
fi
{
  printf '## %s\n\n' "$heading"
  printf 'PostgreSQL %s ran the optimized workload three times per query. The loaded archive contains %s player picks and %s wallet transactions. All five writes rolled back.\n\n' "$version" "$picks" "$wallet"
  printf '| Query | Seed (ms) | Archive (ms) | Growth (×) | Target (ms) | Meets target? |\n'
  printf '| --- | ---: | ---: | ---: | ---: | --- |\n'
  awk -F, -v links="$links" '
    BEGIN {
      n=split("R01 R02 R03 R04 R05 R07 R08 R09 R23 W01 W02 W03", a, " ")
      for(i=1;i<=n;i++) budget[a[i]]=5
      n=split("R06 R10 R13 R16 R22 R25 W04 W05", a, " ")
      for(i=1;i<=n;i++) budget[a[i]]=250
    }
    FNR==NR { if (FNR>1) seed[$1]=$3; next }
    FNR==1 { next }
    {
      q=$1
      if (!(q in seed) || seed[q]<=0 || seen[q]++) exit 1
      target=(q in budget) ? budget[q] : 5000
      growth=$3/seed[q]
      pass=$3<target
      if(!pass) {
        misses++
        scan=$7
        gsub(/ \| /, ", ", scan)
        notes=notes sprintf("- [%s](%s%s.txt) took %.3f ms. Target < %d ms. Observed scans: %s.\n",q,links,q,$3,target,scan)
      }
      if(growth<=3) stable++; else if(growth<=30) scaled++; else steep++
      printf "| [%s](%s%s.txt) | %.3f | %.3f | %.2f | %d | %s |\n",q,links,q,seed[q],$3,growth,target,pass?"Yes":"Miss"
      count++
    }
    END {
      if(count!=30) exit 1
      printf "\nGrowth groups use ≤3×, >3× to 30×, and >30×. The counts are %d, %d and %d.\n\n",stable,scaled,steep
      if(misses) printf "### Targets to investigate\n\n%s\nCompare the linked plans with the seed plans, then record and retest any changes.\n",notes
      else print "All 30 query averages met their assigned target on this run."
    }
  ' "$root/benchmarks/results/optimized/summary.csv" "$results/summary.csv"
  printf '\n### Storage and partitioning\n\n'
  printf '| Scope | Bytes |\n| --- | ---: |\n'
  awk -F, 'NR>1 { printf "| %s | %s |\n",$1,$2 }' "$results/storage.csv"
  printf '\n[%s](%s) and [%s](%s) compared matching monthly deposit totals. %s\n' \
    'Original wallet plan' "$links""wallet_transactions-plan.txt" \
    'Partitioned wallet plan' "$links""wallet_transactions_partitioned-plan.txt" \
    "$(cat "$results/partition-check.txt")"
} > "$report"

if [[ "$mode" == rehearsal ]]; then
  saved=$(mktemp -d "$(dirname -- "$scratch")/dream11-large-rehearsal.XXXXXX")
  cp -R "$results/." "$saved/"
  cp "$report" "$saved/report.md"
  printf 'Rehearsal saved to %s\n' "$saved"
  exit 0
fi

target="$root/benchmarks/results/large"
updated="$scratch/scalability-report.md"
awk -v measured="$report" '
  /^<!-- large-results:start -->$/ {
    print
    while ((getline line < measured) > 0) print line
    close(measured)
    replaced++
    inside=1
    next
  }
  /^<!-- large-results:end -->$/ { inside=0 }
  !inside { print }
  END { if (replaced != 1 || inside) exit 1 }
' "$root/docs/05_scalability_report.md" > "$updated"

if [[ -e "$target" ]]; then mv "$target" "$scratch/prior-large"; fi
if ! mv "$results" "$target" || ! mv "$updated" "$root/docs/05_scalability_report.md"; then
  if [[ -d "$target" ]]; then mv "$target" "$scratch/failed-large"; fi
  if [[ -d "$scratch/prior-large" ]]; then mv "$scratch/prior-large" "$target"; fi
  exit 1
fi
echo 'Wrote benchmarks/results/large and docs/05_scalability_report.md. Review any missed targets before committing.'
