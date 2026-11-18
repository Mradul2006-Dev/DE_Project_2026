#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  printf '%s\n' 'Usage: bash benchmarks/verify_workload.sh <baseline-db> <optimized-db>' >&2
  exit 2
fi

root=$(cd -- "$(dirname -- "$0")/.." && pwd)
baseline="$root/queries/workload_30.sql"
optimized="$root/sql/06_optimized_queries.sql"
if [[ ! -s "$optimized" ]]; then
  printf '%s\n' 'Missing sql/06_optimized_queries.sql.' >&2
  exit 1
fi

scratch=$(mktemp -d)
trap 'rm -rf -- "$scratch"' EXIT
export LC_ALL=C

workload_query() {
  awk -v marker="@$2" '
    /^-- @/ { if (found) exit; found = ($2 == marker); next }
    found && !/^--/ { print }
  ' "$1"
}

capture_rows() {
  local database="$1" statement="$2"
  statement=$(printf '%s\n' "$statement" | sed '$s/;[[:space:]]*$//')
  printf 'SET search_path TO dream11;\nCOPY (\n%s\n) TO STDOUT;\n' "$statement" |
    psql -X -qAt -v ON_ERROR_STOP=1 -d "$database" | sort
}

for ((index = 1; index <= 25; index++)); do
  id=$(printf 'R%02d' "$index")
  before=$(workload_query "$baseline" "$id")
  after=$(workload_query "$optimized" "$id")
  capture_rows "$1" "$before" > "$scratch/before"
  capture_rows "$2" "$after" > "$scratch/after"
  before_count=$(wc -l < "$scratch/before" | awk '{print $1}')
  after_count=$(wc -l < "$scratch/after" | awk '{print $1}')

  if [[ "$id" == R13 ]]; then
    # Independent oracle. Group successful entry-fee references before the left join.
    oracle=$(cat <<'SQL'
SELECT ce.entry_id, ce.contest_id, ce.joined_at
FROM contest_entries ce
JOIN contests c ON c.contest_id = ce.contest_id
LEFT JOIN (
    SELECT DISTINCT reference_entry_id
    FROM wallet_transactions
    WHERE status = 'SUCCESS' AND txn_type = 'ENTRY_FEE'
) AS debit ON debit.reference_entry_id = ce.entry_id
WHERE c.entry_fee > 0 AND debit.reference_entry_id IS NULL
SQL
)
    capture_rows "$2" "$oracle" > "$scratch/oracle"
    cmp -s "$scratch/oracle" "$scratch/after" || { echo 'R13 audit differs from the independent oracle.' >&2; exit 1; }
    printf 'R13 corrected: original %s rows, independent oracle and rewrite %s rows\n' "$before_count" "$after_count"
  else
    cmp -s "$scratch/before" "$scratch/after" ||
      { printf '%s result mismatch (%s vs %s rows)\n' "$id" "$before_count" "$after_count" >&2; exit 1; }
    printf '%s exact row match: %s rows\n' "$id" "$after_count"
  fi
done

capture_points_updates() {
  local database="$1" statement="$2"
  statement=$(printf '%s\n' "$statement" | sed '$s/;[[:space:]]*$//')
  printf 'SET search_path TO dream11;\nBEGIN;\n%s\nRETURNING ut.user_team_id, ut.total_points;\nROLLBACK;\n' "$statement" |
    psql -X -qAt -v ON_ERROR_STOP=1 -d "$database" | sort
}

capture_points_updates "$1" "$(workload_query "$baseline" W04)" > "$scratch/before"
capture_points_updates "$2" "$(workload_query "$optimized" W04)" > "$scratch/after"
if [[ ! -s "$scratch/after" ]] || ! cmp -s "$scratch/before" "$scratch/after"; then
  printf '%s\n' 'W04 updated a different set of teams or points.' >&2
  exit 1
fi
printf 'W04 exact updated team and points match: %s rows (rolled back)\n' "$(wc -l < "$scratch/after" | awk '{print $1}')"
