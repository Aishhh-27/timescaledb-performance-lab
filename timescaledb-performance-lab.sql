-- ============================================================
-- TimescaleDB Performance Lab
-- Tiger Cloud / TimescaleDB / PostgreSQL
-- ============================================================
--
-- Purpose:
-- Compare standard PostgreSQL with TimescaleDB for a
-- time-series workload and demonstrate:
--
--   1. Hypertables
--   2. Time-based chunking
--   3. Query performance
--   4. Compression
--   5. Retention policies
--   6. Continuous aggregates
--
-- Dataset:
--   200,000 time-series records
--   100 devices
--
-- Environment:
--   PostgreSQL 18.4
--   TimescaleDB 2.29.1
--   Tiger Cloud / AWS
--
-- IMPORTANT:
-- Run this script section-by-section when reproducing
-- the experiment.
-- ============================================================


-- ============================================================
-- 1. VERIFY TIMESCALEDB
-- ============================================================

SELECT
    extname,
    extversion
FROM pg_extension
WHERE extname = 'timescaledb';


-- Check current database size

SELECT
    pg_size_pretty(
        pg_database_size(current_database())
    ) AS database_size;


-- ============================================================
-- 2. CREATE STANDARD POSTGRESQL TABLE
-- ============================================================

CREATE TABLE metrics_regular (
    time TIMESTAMPTZ NOT NULL,
    device_id INTEGER NOT NULL,
    cpu_usage DOUBLE PRECISION,
    memory_usage DOUBLE PRECISION,
    temperature DOUBLE PRECISION
);


-- Verify table

SELECT table_name
FROM information_schema.tables
WHERE table_name = 'metrics_regular';


-- ============================================================
-- 3. GENERATE 200,000 TIME-SERIES RECORDS
-- ============================================================

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

SELECT COUNT(*) AS regular_rows
FROM metrics_regular;


-- Measure PostgreSQL table size

SELECT
    pg_size_pretty(
        pg_total_relation_size('metrics_regular')
    ) AS regular_table_size;


-- ============================================================
-- 4. CREATE TIMESCALEDB HYPERTABLE
-- ============================================================

CREATE TABLE metrics_timescale (
    time TIMESTAMPTZ NOT NULL,
    device_id INTEGER NOT NULL,
    cpu_usage DOUBLE PRECISION,
    memory_usage DOUBLE PRECISION,
    temperature DOUBLE PRECISION
);


-- Convert standard PostgreSQL table into a hypertable

SELECT create_hypertable(
    'metrics_timescale',
    'time'
);


-- ============================================================
-- 5. LOAD THE SAME DATA INTO TIMESCALEDB
-- ============================================================

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


-- ============================================================
-- 6. CHECK TIMESCALEDB CHUNKS
-- ============================================================

SELECT
    chunk_name,
    range_start,
    range_end,
    is_compressed
FROM timescaledb_information.chunks
WHERE hypertable_name = 'metrics_timescale'
ORDER BY range_start;


-- ============================================================
-- 7. BASELINE QUERY - POSTGRESQL
-- ============================================================

EXPLAIN (ANALYZE, BUFFERS)
SELECT
    time,
    device_id,
    cpu_usage
FROM metrics_regular
WHERE time >= NOW() - INTERVAL '1 day'
ORDER BY time DESC;


-- ============================================================
-- 8. ADD TIME INDEX TO POSTGRESQL
-- ============================================================

CREATE INDEX metrics_regular_time_idx
ON metrics_regular (time DESC);


-- Run the same query again

EXPLAIN (ANALYZE, BUFFERS)
SELECT
    time,
    device_id,
    cpu_usage
FROM metrics_regular
WHERE time >= NOW() - INTERVAL '1 day'
ORDER BY time DESC;


-- ============================================================
-- 9. TIMESCALEDB TIME-RANGE QUERY
-- ============================================================

EXPLAIN (ANALYZE, BUFFERS)
SELECT
    time,
    device_id,
    cpu_usage
FROM metrics_timescale
WHERE time >= NOW() - INTERVAL '1 day'
ORDER BY time DESC;


-- ============================================================
-- 10. 7-DAY CPU AGGREGATION - POSTGRESQL
-- ============================================================

EXPLAIN (ANALYZE, BUFFERS)
SELECT
    device_id,
    AVG(cpu_usage) AS avg_cpu
FROM metrics_regular
WHERE time >= NOW() - INTERVAL '7 days'
GROUP BY device_id;


-- ============================================================
-- 11. 7-DAY CPU AGGREGATION - TIMESCALEDB
-- ============================================================

EXPLAIN (ANALYZE, BUFFERS)
SELECT
    device_id,
    AVG(cpu_usage) AS avg_cpu
FROM metrics_timescale
WHERE time >= NOW() - INTERVAL '7 days'
GROUP BY device_id;


-- ============================================================
-- 12. HOURLY AGGREGATION - POSTGRESQL
-- ============================================================

EXPLAIN (ANALYZE, BUFFERS)
SELECT
    date_trunc('hour', time) AS hour,
    device_id,
    AVG(cpu_usage) AS avg_cpu
FROM metrics_regular
WHERE time >= NOW() - INTERVAL '7 days'
GROUP BY hour, device_id
ORDER BY hour DESC, device_id;


-- ============================================================
-- 13. HOURLY AGGREGATION - TIMESCALEDB
-- ============================================================

EXPLAIN (ANALYZE, BUFFERS)
SELECT
    time_bucket('1 hour', time) AS hour,
    device_id,
    AVG(cpu_usage) AS avg_cpu
FROM metrics_timescale
WHERE time >= NOW() - INTERVAL '7 days'
GROUP BY hour, device_id
ORDER BY hour DESC, device_id;


-- ============================================================
-- 14. CHECK HYPERTABLE SIZE BEFORE COMPRESSION
-- ============================================================

SELECT
    pg_size_pretty(
        hypertable_size('metrics_timescale')
    ) AS hypertable_size_before_compression;


-- ============================================================
-- 15. CONFIGURE COMPRESSION
-- ============================================================

ALTER TABLE metrics_timescale
SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'device_id',
    timescaledb.compress_orderby = 'time DESC'
);


-- Verify compression configuration

SELECT
    hypertable_name,
    compression_enabled
FROM timescaledb_information.hypertables
WHERE hypertable_name = 'metrics_timescale';


-- ============================================================
-- 16. COMPRESS EXISTING CHUNKS
-- ============================================================

SELECT compress_chunk(chunk)
FROM show_chunks('metrics_timescale') AS chunk;


-- Verify compression

SELECT
    chunk_name,
    is_compressed
FROM timescaledb_information.chunks
WHERE hypertable_name = 'metrics_timescale'
ORDER BY range_start;


-- ============================================================
-- 17. MEASURE COMPRESSED STORAGE
-- ============================================================

SELECT
    pg_size_pretty(
        hypertable_size('metrics_timescale')
    ) AS compressed_size;


-- ============================================================
-- 18. CHECK DATA RANGE
-- ============================================================

SELECT
    MIN(time) AS oldest_data,
    MAX(time) AS newest_data,
    COUNT(*) AS total_rows
FROM metrics_timescale;


-- ============================================================
-- 19. RETENTION POLICY
-- ============================================================
--
-- A 1-year policy is intentionally used so the current
-- benchmark dataset is not deleted.
-- ============================================================

SELECT add_retention_policy(
    'metrics_timescale',
    INTERVAL '1 year'
);


-- Verify retention policy

SELECT
    job_id,
    application_name,
    schedule_interval,
    config
FROM timescaledb_information.jobs
WHERE hypertable_name = 'metrics_timescale';


-- ============================================================
-- 20. CREATE CONTINUOUS AGGREGATE
-- ============================================================

CREATE MATERIALIZED VIEW metrics_hourly
WITH (timescaledb.continuous) AS
SELECT
    time_bucket('1 hour', time) AS hour,
    device_id,
    AVG(cpu_usage) AS avg_cpu,
    AVG(memory_usage) AS avg_memory,
    AVG(temperature) AS avg_temperature
FROM metrics_timescale
GROUP BY hour, device_id
WITH NO DATA;


-- ============================================================
-- 21. REFRESH CONTINUOUS AGGREGATE
-- ============================================================

CALL refresh_continuous_aggregate(
    'metrics_hourly',
    '2026-06-07 00:00:00+00',
    '2026-08-16 00:00:00+00'
);


-- ============================================================
-- 22. CHECK CONTINUOUS AGGREGATE
-- ============================================================

SELECT
    COUNT(*) AS aggregate_rows
FROM metrics_hourly;


-- ============================================================
-- 23. QUERY CONTINUOUS AGGREGATE
-- ============================================================

EXPLAIN (ANALYZE, BUFFERS)
SELECT
    hour,
    device_id,
    avg_cpu
FROM metrics_hourly
WHERE hour >= NOW() - INTERVAL '7 days'
ORDER BY hour DESC, device_id;


-- ============================================================
-- 24. COMPARE AGAINST RAW TIMESCALEDB DATA
-- ============================================================

EXPLAIN (ANALYZE, BUFFERS)
SELECT
    time_bucket('1 hour', time) AS hour,
    device_id,
    AVG(cpu_usage) AS avg_cpu
FROM metrics_timescale
WHERE time >= NOW() - INTERVAL '7 days'
GROUP BY hour, device_id
ORDER BY hour DESC, device_id;


-- ============================================================
-- 25. FINAL DATA VERIFICATION
-- ============================================================

SELECT
    (SELECT COUNT(*) FROM metrics_regular) AS regular_rows,
    (SELECT COUNT(*) FROM metrics_timescale) AS timescale_rows,
    (SELECT COUNT(*) FROM metrics_hourly) AS aggregate_rows;


-- ============================================================
-- END OF LAB
-- ============================================================
