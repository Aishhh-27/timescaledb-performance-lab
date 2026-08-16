-- TimescaleDB Performance Lab
-- 02 - Generate test data

INSERT INTO metrics_regular (
    time,
    device_id,
    cpu_usage,
    memory_usage,
    temperature
)
SELECT
    NOW() - (s * INTERVAL '1 minute'),
    (s % 100) + 1,
    20 + random() * 70,
    30 + random() * 60,
    30 + random() * 40
FROM generate_series(1, 200000) AS s;

-- Verify row count
SELECT COUNT(*) AS total_rows
FROM metrics_regular;

-- Check table size
SELECT
    pg_size_pretty(
        pg_total_relation_size('metrics_regular')
    ) AS table_size;

-- Create TimescaleDB table
CREATE TABLE metrics_timescale (
    time TIMESTAMPTZ NOT NULL,
    device_id INTEGER NOT NULL,
    cpu_usage DOUBLE PRECISION,
    memory_usage DOUBLE PRECISION,
    temperature DOUBLE PRECISION
);

-- Convert table into a hypertable
SELECT create_hypertable(
    'metrics_timescale',
    'time'
);

-- Copy the same dataset into the hypertable
INSERT INTO metrics_timescale (
    time,
    device_id,
    cpu_usage,
    memory_usage,
    temperature
)
SELECT
    time,
    device_id,
    cpu_usage,
    memory_usage,
    temperature
FROM metrics_regular;

-- Verify both datasets
SELECT
    (SELECT COUNT(*) FROM metrics_regular) AS regular_rows,
    (SELECT COUNT(*) FROM metrics_timescale) AS timescale_rows;
