\set ON_ERROR_STOP on
CREATE TEMP TABLE contests (contest_id bigint PRIMARY KEY, entry_fee numeric NOT NULL);
CREATE TEMP TABLE contest_entries (entry_id bigint PRIMARY KEY, contest_id bigint NOT NULL, joined_at timestamptz NOT NULL);
CREATE TEMP TABLE wallet_transactions (txn_id bigint PRIMARY KEY, txn_type text NOT NULL, reference_entry_id bigint, status text NOT NULL);
INSERT INTO contests VALUES (1, 10), (2, 0);
INSERT INTO contest_entries VALUES (1,1,now()), (2,1,now()), (3,1,now()), (4,1,now()), (5,2,now());
INSERT INTO wallet_transactions VALUES (1,'DEPOSIT',NULL,'SUCCESS'), (2,'ENTRY_FEE',1,'SUCCESS'), (3,'REFUND',2,'SUCCESS'), (4,'ENTRY_FEE',3,'FAILED'), (5,'ENTRY_FEE',4,'PENDING');
SELECT 'original_with_null' AS test, coalesce(string_agg(ce.entry_id::text, ',' ORDER BY ce.entry_id), '(none)') AS ids FROM contest_entries ce JOIN contests c USING (contest_id) WHERE c.entry_fee > 0 AND ce.entry_id NOT IN (SELECT w.reference_entry_id FROM wallet_transactions w);
SELECT 'original_without_null' AS test, coalesce(string_agg(ce.entry_id::text, ',' ORDER BY ce.entry_id), '(none)') AS ids FROM contest_entries ce JOIN contests c USING (contest_id) WHERE c.entry_fee > 0 AND ce.entry_id NOT IN (SELECT w.reference_entry_id FROM wallet_transactions w WHERE w.reference_entry_id IS NOT NULL);
SELECT 'corrected_successful_debit' AS test, coalesce(string_agg(ce.entry_id::text, ',' ORDER BY ce.entry_id), '(none)') AS ids FROM contest_entries ce JOIN contests c USING (contest_id) WHERE c.entry_fee > 0 AND NOT EXISTS (SELECT 1 FROM wallet_transactions w WHERE w.reference_entry_id = ce.entry_id AND w.txn_type = 'ENTRY_FEE' AND w.status = 'SUCCESS');
DO $$ DECLARE actual bigint[]; BEGIN SELECT array_agg(ce.entry_id ORDER BY ce.entry_id) INTO actual FROM contest_entries ce JOIN contests c USING (contest_id) WHERE c.entry_fee > 0 AND NOT EXISTS (SELECT 1 FROM wallet_transactions w WHERE w.reference_entry_id = ce.entry_id AND w.txn_type = 'ENTRY_FEE' AND w.status = 'SUCCESS'); IF actual IS DISTINCT FROM ARRAY[2,3,4]::bigint[] THEN RAISE EXCEPTION 'Unexpected result: %', actual; END IF; END $$;
