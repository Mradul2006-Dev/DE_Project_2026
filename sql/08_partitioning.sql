-- Create a partitioned wallet copy in a test database after loading the data.
BEGIN;
SET LOCAL search_path TO dream11;

CREATE TABLE wallet_transactions_partitioned (
    LIKE wallet_transactions INCLUDING DEFAULTS INCLUDING IDENTITY INCLUDING CONSTRAINTS,
    PRIMARY KEY (created_at, txn_id),
    FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE RESTRICT,
    FOREIGN KEY (reference_entry_id) REFERENCES contest_entries (entry_id) ON DELETE RESTRICT
) PARTITION BY RANGE (created_at);

DO $$
DECLARE
    month_start timestamp;
    last_month timestamp;
    next_month timestamp;
BEGIN
    SELECT date_trunc('month', min(created_at) AT TIME ZONE 'UTC'),
           date_trunc('month', max(created_at) AT TIME ZONE 'UTC')
    INTO month_start, last_month
    FROM wallet_transactions;

    WHILE month_start <= last_month LOOP
        next_month := month_start + interval '1 month';
        EXECUTE format(
            'CREATE TABLE %I PARTITION OF wallet_transactions_partitioned FOR VALUES FROM (%L) TO (%L)',
            'wallet_tx_' || to_char(month_start, 'YYYY_MM'),
            to_char(month_start, 'YYYY-MM-DD') || ' 00:00:00+00',
            to_char(next_month, 'YYYY-MM-DD') || ' 00:00:00+00'
        );
        month_start := next_month;
    END LOOP;
END;
$$;

CREATE TABLE wallet_tx_default PARTITION OF wallet_transactions_partitioned DEFAULT;
INSERT INTO wallet_transactions_partitioned
SELECT txn_id, user_id, txn_type, amount, reference_entry_id, status, created_at
FROM wallet_transactions;

SELECT setval(pg_get_serial_sequence('dream11.wallet_transactions_partitioned', 'txn_id'),
              coalesce(max(txn_id), 1), max(txn_id) IS NOT NULL)
FROM wallet_transactions_partitioned;

-- Keep the successful-deposit access path comparable with the CP3 ledger.
CREATE INDEX wallet_partition_deposit_time_idx
    ON wallet_transactions_partitioned (created_at) INCLUDE (amount)
    WHERE txn_type = 'DEPOSIT' AND status = 'SUCCESS';

COMMIT;
ANALYZE dream11.wallet_transactions_partitioned;
