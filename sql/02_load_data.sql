-- Run this with psql from the project root after extracting seed_data.zip.
BEGIN;
SET LOCAL search_path TO dream11;

\copy teams FROM 'seed_data/teams.csv' WITH (FORMAT csv, HEADER true)
\copy players FROM 'seed_data/players.csv' WITH (FORMAT csv, HEADER true)
\copy matches FROM 'seed_data/matches.csv' WITH (FORMAT csv, HEADER true)
\copy player_match_stats FROM 'seed_data/player_match_stats.csv' WITH (FORMAT csv, HEADER true)
\copy users FROM 'seed_data/users.csv' WITH (FORMAT csv, HEADER true)
\copy user_teams FROM 'seed_data/user_teams.csv' WITH (FORMAT csv, HEADER true)
\copy user_team_players FROM 'seed_data/user_team_players.csv' WITH (FORMAT csv, HEADER true)
\copy contests FROM 'seed_data/contests.csv' WITH (FORMAT csv, HEADER true)
\copy contest_entries FROM 'seed_data/contest_entries.csv' WITH (FORMAT csv, HEADER true)
\copy wallet_transactions FROM 'seed_data/wallet_transactions.csv' WITH (FORMAT csv, HEADER true)

-- COPY supplies explicit IDs, so advance the identity sequences for future inserts.
SELECT setval(pg_get_serial_sequence('teams', 'team_id'), max(team_id)) FROM teams;
SELECT setval(pg_get_serial_sequence('players', 'player_id'), max(player_id)) FROM players;
SELECT setval(pg_get_serial_sequence('matches', 'match_id'), max(match_id)) FROM matches;
SELECT setval(pg_get_serial_sequence('users', 'user_id'), max(user_id)) FROM users;
SELECT setval(pg_get_serial_sequence('user_teams', 'user_team_id'), max(user_team_id)) FROM user_teams;
SELECT setval(pg_get_serial_sequence('contests', 'contest_id'), max(contest_id)) FROM contests;
SELECT setval(pg_get_serial_sequence('contest_entries', 'entry_id'), max(entry_id)) FROM contest_entries;
SELECT setval(pg_get_serial_sequence('wallet_transactions', 'txn_id'), max(txn_id)) FROM wallet_transactions;

COMMIT;
ANALYZE;
