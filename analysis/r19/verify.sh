#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  printf '%s\n' 'Usage: bash analysis/r19/verify.sh <local-seed-database>' >&2
  exit 2
fi

root=$(cd -- "$(dirname -- "$0")/../.." && pwd)
extract_r19() {
  awk '
    /^-- @R19[[:space:]]*$/ { found=1; next }
    found && /^-- @/ { exit }
    found { print }
  ' "$1"
}

original=$(extract_r19 "$root/queries/workload_30.sql")
candidate=$(extract_r19 "$root/sql/06_optimized_queries.sql")
if [[ -z "$original" || -z "$candidate" ]]; then
  printf '%s\n' 'R19 must exist in both the faculty workload and the submitted optimized workload.' >&2
  exit 1
fi

{
  cat <<'SQL'
BEGIN;
SET LOCAL search_path TO dream11;
INSERT INTO players (full_name, team_id, role, credits, is_active)
SELECT '__r19_fixture_' || lower(team_type), team_id, 'BAT', 8.0, true
FROM (
    SELECT DISTINCT ON (team_type) team_type, team_id
    FROM teams
    WHERE team_type IN ('FRANCHISE', 'INTERNATIONAL')
    ORDER BY team_type, team_id
) fixture_teams;
SQL
  printf 'CREATE TEMP TABLE r19_original AS\n%s\n' "$original"
  printf 'CREATE TEMP TABLE r19_optimized AS\n%s\n' "$candidate"
  cat <<'SQL'
DO $$
BEGIN
    IF EXISTS (
        (TABLE r19_original EXCEPT ALL TABLE r19_optimized)
        UNION ALL
        (TABLE r19_optimized EXCEPT ALL TABLE r19_original)
    ) THEN
        RAISE EXCEPTION 'Optimized R19 changed the result rows';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM r19_optimized
        WHERE full_name = '__r19_fixture_franchise' AND times_picked = 0
    ) THEN
        RAISE EXCEPTION 'A franchise player with zero picks must still appear';
    END IF;

    IF EXISTS (
        SELECT 1 FROM r19_optimized WHERE full_name = '__r19_fixture_international'
    ) THEN
        RAISE EXCEPTION 'International players must stay out of the report';
    END IF;
END;
$$;
SELECT count(*) FILTER (WHERE full_name <> '__r19_fixture_franchise') AS seed_players_compared
FROM r19_original;
ROLLBACK;
SQL
} | psql -X -v ON_ERROR_STOP=1 -d "$1"

printf '%s\n' 'PASS identical R19 results, zero picks and franchise filter.'
