-- Dimension: fraud type with classification hierarchy
CREATE TABLE dim_fraud_type (
    fraud_type_id   SERIAL PRIMARY KEY,
    fraud_type      TEXT NOT NULL UNIQUE,     -- matches CSV Fraud_Type
    fraud_category  TEXT NOT NULL,            -- e.g. 'Card Fraud', 'APP Scam'
    fraud_domain    TEXT NOT NULL             -- e.g. 'Unauthorised', 'Authorised (APP)'
);

-- Dimension: year (natural key — no surrogate needed)
CREATE TABLE dim_year (
    year  INTEGER PRIMARY KEY
);

-- Fact: one row per (fraud type × year × segment)
CREATE TABLE fact_fraud (
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