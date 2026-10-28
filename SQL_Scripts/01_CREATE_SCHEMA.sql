-- ============================================================
-- 01_CREATE_SCHEMA.sql
-- FinCrime Project — PostgreSQL 16 Star Schema DDL
-- Database: fincrime_db  |  Server: <your-host>:5432
-- ============================================================

-- Run once to create the schema. If re-running, the IF NOT EXISTS
-- and DROP-then-CREATE on staging make this safe to re-execute.

BEGIN;

-- ── Staging table (all TEXT, mirrors CSV columns exactly) ────
DROP TABLE IF EXISTS staging_fraud CASCADE;

CREATE TABLE staging_fraud (
    year            TEXT,
    segment         TEXT,
    fraud_type      TEXT,
    source_page     TEXT,
    cases           TEXT,
    value_gbp_m     TEXT,
    prevented_gbp_m TEXT,
    payments        TEXT,
    returned_gbp_m  TEXT
);

COMMENT ON TABLE staging_fraud IS
    'Temporary landing zone for combined_fraud_data.csv. All TEXT to avoid COPY type errors.';

-- ── Dimension: fraud type with classification hierarchy ─────
CREATE TABLE IF NOT EXISTS dim_fraud_type (
    fraud_type_id   SERIAL PRIMARY KEY,
    fraud_type      TEXT NOT NULL UNIQUE,
    fraud_category  TEXT NOT NULL,
    fraud_domain    TEXT NOT NULL
);

COMMENT ON TABLE dim_fraud_type IS
    'Lookup dimension mapping each fraud_type to its category and domain.';

-- ── Dimension: year ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS dim_year (
    year  INTEGER PRIMARY KEY
);

COMMENT ON TABLE dim_year IS
    'Year dimension — natural key, no surrogate needed.';

-- ── Fact table ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS fact_fraud (
    fact_id         SERIAL PRIMARY KEY,
    fraud_type_id   INTEGER NOT NULL REFERENCES dim_fraud_type(fraud_type_id),
    year            INTEGER NOT NULL REFERENCES dim_year(year),
    segment         TEXT NOT NULL DEFAULT 'All',
    cases           NUMERIC,
    value_gbp_m     NUMERIC,
    prevented_gbp_m NUMERIC,
    payments        NUMERIC,
    returned_gbp_m  NUMERIC,
    source_page     TEXT,
    UNIQUE (fraud_type_id, year, segment)
);

COMMENT ON TABLE fact_fraud IS
    'One row per (fraud_type × year × segment). Numeric columns are NULL when the source PDF has no data.';

COMMIT;
