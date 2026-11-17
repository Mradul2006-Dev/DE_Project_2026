-- R13: paid entries without a successful entry-fee debit.
-- Confirm with the team whether SUCCESS is the intended definition of a debit.
SELECT ce.entry_id, ce.contest_id, ce.joined_at
FROM contest_entries AS ce
JOIN contests AS c ON c.contest_id = ce.contest_id
WHERE c.entry_fee > 0
  AND NOT EXISTS (
    SELECT 1
    FROM wallet_transactions AS w
    WHERE w.reference_entry_id = ce.entry_id
      AND w.txn_type = 'ENTRY_FEE'
      AND w.status = 'SUCCESS'
  );

-- Candidate for CP3; benchmark against the real dataset before adopting.
-- CREATE INDEX idx_wallet_successful_entry_fee ON wallet_transactions (reference_entry_id)
-- WHERE txn_type = 'ENTRY_FEE' AND status = 'SUCCESS';
