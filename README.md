# TimescaleDB Performance Lab

Hands-on time-series database performance lab using **Tiger Cloud, TimescaleDB, and PostgreSQL**.

## Overview

This project explores how TimescaleDB extends PostgreSQL for time-series workloads. I built equivalent PostgreSQL and TimescaleDB datasets on a managed Tiger Cloud instance and compared query performance, storage usage, chunking, compression, retention, and continuous aggregates.

## Environment

- Cloud: Tiger Cloud
- Cloud Provider: AWS
- Region: us-east-1
- PostgreSQL: 18.4
- TimescaleDB: 2.29.1
- Dataset: 200,000 time-series records
- Devices: 100

## What I Built

### 1. PostgreSQL Baseline

Created a standard PostgreSQL table containing:

- Timestamp
- Device ID
- CPU usage
- Memory usage
- Temperature

The dataset contained 200,000 records.

### 2. TimescaleDB Hypertable

Created an equivalent TimescaleDB table and converted it into a hypertable using the timestamp column.

The hypertable was automatically divided into 11 time-based chunks.

### 3. Query Performance

Used `EXPLAIN (ANALYZE, BUFFERS)` to compare PostgreSQL and TimescaleDB queries.

A 24-hour time-range query produced:

| Configuration | Execution Time |
|---|---:|
| PostgreSQL without time index | 49.581 ms |
| PostgreSQL with time index | 1.099 ms |
| TimescaleDB hypertable | 1.186 ms |

This demonstrated that proper PostgreSQL indexing can significantly improve time-series queries, while TimescaleDB provides additional time-series-specific functionality.

### 4. Time-Series Aggregation

Compared aggregation workloads using:

- PostgreSQL `date_trunc()`
- TimescaleDB `time_bucket()`

For the hourly aggregation workload:

| Approach | Execution Time |
|---|---:|
| PostgreSQL | 16.314 ms |
| TimescaleDB | 22.950 ms |

The results showed that TimescaleDB does not automatically outperform PostgreSQL for every workload, particularly on a relatively small dataset.

### 5. Compression

Configured TimescaleDB compression and compressed all 11 chunks.

Storage usage:

- Before compression: ~20 MB
- After compression: ~8.2 MB
- Approximate reduction: ~59%

### 6. Retention Policy

Configured a TimescaleDB retention policy with a 1-year retention period.

The policy runs automatically every day while preserving the current benchmark dataset.

### 7. Continuous Aggregate

Created a continuous aggregate containing hourly metrics per device.

The aggregate contained approximately 110,000 summarized rows.

Performance comparison:

| Query | Execution Time |
|---|---:|
| Raw hourly aggregation | 14.242 ms |
| Continuous aggregate | 7.077 ms |

The pre-aggregated query was approximately 2× faster in this workload.

## Key Learnings

- TimescaleDB hypertables organize time-series data into time-based chunks.
- Query performance depends heavily on indexing and workload characteristics.
- PostgreSQL with an appropriate time index can perform very well on smaller datasets.
- TimescaleDB provides specialized time-series capabilities beyond standard PostgreSQL tables.
- Compression can significantly reduce storage requirements.
- Retention policies automate lifecycle management of historical data.
- Continuous aggregates can reduce the cost of repeatedly calculating time-series aggregations.
- `EXPLAIN ANALYZE` and buffer statistics are useful for understanding database performance.

## Technologies

- PostgreSQL
- TimescaleDB
- Tiger Cloud
- SQL
- `EXPLAIN ANALYZE`
- Time-series data modeling
- Hypertables
- Compression
- Continuous aggregates
- Retention policies
