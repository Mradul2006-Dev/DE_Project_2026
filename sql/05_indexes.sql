BEGIN;
SET LOCAL search_path TO dream11;

-- R01, R04, W02. Seek contests by match first. For a join, contest type narrows the range.
CREATE INDEX contests_match_type_idx
    ON contests (match_id, contest_type) INCLUDE (contest_id, prize_pool);

-- R02, R06, R08, W02, W04. Find teams for one match and retain the team ID order.
-- Including captain_id covers R08's per-match captain counts.
CREATE INDEX user_teams_match_idx
    ON user_teams (match_id, user_team_id) INCLUDE (captain_id);

-- R09. Seek the successful rows for one user, then stream them in running-balance order.
CREATE INDEX wallet_success_user_time_idx
    ON wallet_transactions (user_id, created_at, txn_id) INCLUDE (txn_type, amount)
    WHERE status = 'SUCCESS';

-- R10, W05. Keep the small pending-withdrawal subset ordered by the cutoff timestamp.
CREATE INDEX wallet_pending_withdrawal_time_idx
    ON wallet_transactions (created_at) INCLUDE (txn_id, user_id, amount)
    WHERE txn_type = 'WITHDRAWAL' AND status = 'PENDING';

-- R13. Successful entry-fee references are the debit evidence used by the anti-join.
CREATE INDEX wallet_success_entry_ref_idx
    ON wallet_transactions (reference_entry_id)
    WHERE txn_type = 'ENTRY_FEE' AND status = 'SUCCESS';

-- R18. Read the successful winnings subset grouped by user.
CREATE INDEX wallet_success_winnings_user_idx
    ON wallet_transactions (user_id) INCLUDE (amount)
    WHERE txn_type = 'WINNINGS' AND status = 'SUCCESS';

-- R20. Seek the date range inside the successful-deposit subset.
CREATE INDEX wallet_success_deposit_time_idx
    ON wallet_transactions (created_at) INCLUDE (amount)
    WHERE txn_type = 'DEPOSIT' AND status = 'SUCCESS';

-- R22. The support page can read ordered entries instead of sorting the whole ledger.
-- Include the displayed columns so all-visible pages can be served from the index.
CREATE INDEX wallet_history_time_idx
    ON wallet_transactions (created_at DESC) INCLUDE (txn_id, user_id, txn_type, amount, status);

-- R25. Look up the refund reference rather than scanning unrelated ledger rows.
CREATE INDEX wallet_refund_entry_ref_idx
    ON wallet_transactions (reference_entry_id) WHERE txn_type = 'REFUND';

COMMIT;
ANALYZE;
