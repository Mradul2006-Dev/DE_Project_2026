-- @R19
-- Selection report. Count picks once per player, then keep every franchise player.
SELECT p.player_id, p.full_name, COALESCE(picks.times_picked, 0::bigint) AS times_picked
FROM players AS p
JOIN teams AS t ON t.team_id = p.team_id AND t.team_type = 'FRANCHISE'
LEFT JOIN (
    SELECT player_id, count(*) AS times_picked
    FROM user_team_players
    GROUP BY player_id
) AS picks ON picks.player_id = p.player_id
ORDER BY times_picked DESC;
