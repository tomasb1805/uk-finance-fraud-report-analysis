-- ============================================================
-- 02_LOAD_DATA.sql
-- FinCrime Project — Full data load pipeline
-- Database: fincrime_db  |  Server: <your-host>:5432
--
-- CSV path (server-side): /path/to/fincrime-project/combined_fraud_data.csv
--
-- USAGE:
--   psql -h <your-host> -d fincrime_db -f 02_LOAD_DATA.sql
--
-- Or from DBeaver: run each section in order.
--
-- This script is IDEMPOTENT: safe to re-run after a new CSV export.
-- It truncates staging and fact tables, then reloads everything.
-- ============================================================

BEGIN;

-- ════════════════════════════════════════════════════════════
-- STEP 1: Clear existing data for clean reload
-- ════════════════════════════════════════════════════════════

TRUNCATE staging_fraud;
TRUNCATE fact_fraud CASCADE;
-- dim tables are not truncated; they accumulate and the
-- INSERT ... ON CONFLICT below handles existing rows.

-- ════════════════════════════════════════════════════════════
-- STEP 2: Load CSV into staging (all TEXT)
-- ════════════════════════════════════════════════════════════
-- NOTE: COPY reads from a server-side path.
--       If running psql from a client machine, use
--       \COPY instead (same syntax, no backslash-escaping needed).

COPY staging_fraud (
    year, segment, fraud_type, source_page,
    cases, value_gbp_m, prevented_gbp_m,
    payments, returned_gbp_m
)
FROM '/path/to/fincrime-project/combined_fraud_data.csv'
WITH (
    FORMAT csv,
    HEADER true,
    DELIMITER ',',
    NULL ''
);

-- ════════════════════════════════════════════════════════════
-- STEP 3: Staging data quality check
-- ════════════════════════════════════════════════════════════

-- Quick count — should match CSV row count (expect ~219 rows
-- after M code fixes, potentially more with 2016-2019 data)
DO $$
DECLARE
    row_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO row_count FROM staging_fraud;
    RAISE NOTICE 'Staging loaded: % rows', row_count;
END $$;

-- Show distinct fraud_type values for visual inspection
-- (all should match dim_fraud_type entries below)
DO $$
DECLARE
    rec RECORD;
BEGIN
    RAISE NOTICE '── Distinct fraud_type values in staging ──';
    FOR rec IN
        SELECT DISTINCT fraud_type
        FROM staging_fraud
        ORDER BY fraud_type
    LOOP
        RAISE NOTICE '  %', rec.fraud_type;
    END LOOP;
END $$;

-- ════════════════════════════════════════════════════════════
-- STEP 4: Populate dim_year
-- ════════════════════════════════════════════════════════════

INSERT INTO dim_year (year)
SELECT DISTINCT year::INTEGER
FROM staging_fraud
WHERE year IS NOT NULL
  AND year ~ '^\d{4}$'
ON CONFLICT (year) DO NOTHING;

-- ════════════════════════════════════════════════════════════
-- STEP 5: Populate dim_fraud_type
-- ════════════════════════════════════════════════════════════
-- These are the 23 canonical fraud_type values.
-- The category and domain classify each for dashboard grouping.

INSERT INTO dim_fraud_type (fraud_type, fraud_category, fraud_domain)
VALUES
    -- ── Unauthorised card fraud ─────────────────────────────
    ('Card_Not_Received',       'Card Fraud',           'Unauthorised'),
    ('Counterfeit_Card',        'Card Fraud',           'Unauthorised'),
    ('Lost_Stolen_Card',        'Card Fraud',           'Unauthorised'),
    ('Card_ID_Theft',           'Card Fraud',           'Unauthorised'),

    -- ── Unauthorised remote purchase fraud ──────────────────
    ('Remote_Purchase',         'Remote Purchase',      'Unauthorised'),
    ('Internet_eCommerce',      'Remote Purchase',      'Unauthorised'),

    -- ── Unauthorised in-person / ATM ────────────────────────
    ('UK_Retail_FaceToFace',    'In-Person Fraud',      'Unauthorised'),
    ('ATM_Fraud',               'In-Person Fraud',      'Unauthorised'),
    ('Third_Party_Apps',        'Third-Party Apps',     'Unauthorised'),

    -- ── Unauthorised account / banking fraud ────────────────
    ('Account_Takeover',        'Account Fraud',        'Unauthorised'),
    ('Internet_Banking',        'Banking Channel',      'Unauthorised'),
    ('Telephone_Banking',       'Banking Channel',      'Unauthorised'),
    ('Mobile_Banking',          'Banking Channel',      'Unauthorised'),

    -- ── Prevented totals (unauthorised) ─────────────────────
    ('Remote_Banking_Total',    'Banking Channel',      'Unauthorised'),
    ('Cheque_Fraud',            'Cheque',               'Unauthorised'),

    -- ── APP Scams (Authorised Push Payment) ─────────────────
    ('Purchase_Scam',           'APP Scam',             'Authorised (APP)'),
    ('Investment_Scam',         'APP Scam',             'Authorised (APP)'),
    ('Romance_Scam',            'APP Scam',             'Authorised (APP)'),
    ('Advance_Fee_Scam',        'APP Scam',             'Authorised (APP)'),
    ('Invoice_Scam',            'APP Scam',             'Authorised (APP)'),
    ('CEO_Scam',                'APP Scam',             'Authorised (APP)'),
    ('Police_Bank_Impersonation', 'APP Scam',           'Authorised (APP)'),
    ('Other_Impersonation',     'APP Scam',             'Authorised (APP)')
ON CONFLICT (fraud_type) DO UPDATE SET
    fraud_category = EXCLUDED.fraud_category,
    fraud_domain   = EXCLUDED.fraud_domain;

-- ════════════════════════════════════════════════════════════
-- STEP 6: Load fact table from staging + dimension JOINs
-- ════════════════════════════════════════════════════════════
-- Uses GROUP BY with MAX to collapse any duplicate staging rows
-- (e.g. same fraud_type+year+segment from overlapping queries).
-- NULLIF converts empty strings to NULL before casting to NUMERIC.
-- ON CONFLICT upserts with COALESCE so a second load merges
-- rather than failing.

INSERT INTO fact_fraud (
    fraud_type_id, year, segment,
    cases, value_gbp_m, prevented_gbp_m,
    payments, returned_gbp_m, source_page
)
SELECT
    d.fraud_type_id,
    s.year::INTEGER,
    COALESCE(NULLIF(TRIM(s.segment), ''), 'All'),
    MAX(NULLIF(TRIM(s.cases),           '')::NUMERIC),
    MAX(NULLIF(TRIM(s.value_gbp_m),     '')::NUMERIC),
    MAX(NULLIF(TRIM(s.prevented_gbp_m), '')::NUMERIC),
    MAX(NULLIF(TRIM(s.payments),        '')::NUMERIC),
    MAX(NULLIF(TRIM(s.returned_gbp_m),  '')::NUMERIC),
    MAX(s.source_page)
FROM staging_fraud s
JOIN dim_fraud_type d ON d.fraud_type = s.fraud_type
WHERE s.year IS NOT NULL
  AND s.year ~ '^\d{4}$'
  AND s.fraud_type IS NOT NULL
  AND TRIM(s.fraud_type) <> ''
GROUP BY
    d.fraud_type_id,
    s.year::INTEGER,
    COALESCE(NULLIF(TRIM(s.segment), ''), 'All')
ON CONFLICT (fraud_type_id, year, segment)
DO UPDATE SET
    cases           = COALESCE(EXCLUDED.cases,           fact_fraud.cases),
    value_gbp_m     = COALESCE(EXCLUDED.value_gbp_m,     fact_fraud.value_gbp_m),
    prevented_gbp_m = COALESCE(EXCLUDED.prevented_gbp_m, fact_fraud.prevented_gbp_m),
    payments        = COALESCE(EXCLUDED.payments,         fact_fraud.payments),
    returned_gbp_m  = COALESCE(EXCLUDED.returned_gbp_m,  fact_fraud.returned_gbp_m),
    source_page     = COALESCE(EXCLUDED.source_page,     fact_fraud.source_page);

COMMIT;

-- ════════════════════════════════════════════════════════════
-- Post-load summary
-- ════════════════════════════════════════════════════════════

DO $$
DECLARE
    staging_ct  INTEGER;
    fact_ct     INTEGER;
    dim_ft_ct   INTEGER;
    dim_yr_ct   INTEGER;
BEGIN
    SELECT COUNT(*) INTO staging_ct  FROM staging_fraud;
    SELECT COUNT(*) INTO fact_ct     FROM fact_fraud;
    SELECT COUNT(*) INTO dim_ft_ct   FROM dim_fraud_type;
    SELECT COUNT(*) INTO dim_yr_ct   FROM dim_year;

    RAISE NOTICE '';
    RAISE NOTICE '══════ LOAD COMPLETE ══════';
    RAISE NOTICE 'Staging rows:    %', staging_ct;
    RAISE NOTICE 'Fact rows:       %', fact_ct;
    RAISE NOTICE 'Fraud types:     %', dim_ft_ct;
    RAISE NOTICE 'Year range:      %', dim_yr_ct;
    RAISE NOTICE '═══════════════════════════';
END $$;
