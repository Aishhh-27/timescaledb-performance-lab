-- TimescaleDB Performance Lab
-- 01 - Setup and TimescaleDB verification

-- Check TimescaleDB version
SELECT extname, extversion
FROM pg_extension
WHERE extname = 'timescaledb';

-- Check current database size
SELECT
    pg_size_pretty(
        pg_database_size(current_database())
    ) AS database_size;

-- Create standard PostgreSQL table
CREATE TABLE metrics_regular (
    time TIMESTAMPTZ NOT NULL,
    device_id INTEGER NOT NULL,
    cpu_usage DOUBLE PRECISION,
    memory_usage DOUBLE PRECISION,
    temperature DOUBLE PRECISION
);

-- Verify table creation
SELECT table_name
FROM information_schema.tables
WHERE table_name = 'metrics_regular';
