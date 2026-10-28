-- ============================================================
-- 03_VERIFY_DATA.sql
-- FinCrime Project — Data integrity verification
-- Database: fincrime_db  |  Server: <your-host>:5432
--
-- Run after 02_LOAD_DATA.sql to verify the load was clean.
-- Every query should return 0 problem rows if the pipeline
-- is working correctly.
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- CHECK 1: Orphan staging rows (fraud_type not in dimension)
-- Expected: 0 rows
-- If rows appear here, the CSV has a fraud_type value that
-- doesn't match dim_fraud_type — fix it in Power Query.
-- ────────────────────────────────────────────────────────────

SELECT 'CHECK 1: Orphan staging rows' AS check_name;

SELECT s.fraud_type, COUNT(*) AS orphan_rows
FROM staging_fraud s
LEFT JOIN dim_fraud_type d ON d.fraud_type = s.fraud_type
WHERE d.fraud_type_id IS NULL
  AND s.fraud_type IS NOT NULL
  AND TRIM(s.fraud_type) <> ''
GROUP BY s.fraud_type
ORDER BY s.fraud_type;

-- ────────────────────────────────────────────────────────────
-- CHECK 2: Fact rows with ALL numeric columns NULL
-- Expected: 0 rows
-- These are "empty" rows — a fraud_type+year exists in the
-- CSV but every measure (cases, value, prevented, payments,
-- returned) is blank.
-- ────────────────────────────────────────────────────────────

SELECT 'CHECK 2: Empty fact rows (all NULLs)' AS check_name;

SELECT
    d.fraud_type,
    f.year,
    f.segment
FROM fact_fraud f
JOIN dim_fraud_type d ON d.fraud_type_id = f.fraud_type_id
WHERE f.cases           IS NULL
  AND f.value_gbp_m     IS NULL
  AND f.prevented_gbp_m IS NULL
  AND f.payments        IS NULL
  AND f.returned_gbp_m  IS NULL
ORDER BY d.fraud_type, f.year;

-- ────────────────────────────────────────────────────────────
-- CHECK 3: Duplicate fraud_type names (near-matches)
-- Expected: 0 rows
-- Catches "_Fraud" suffix variants and typos.
-- ────────────────────────────────────────────────────────────

SELECT 'CHECK 3: Near-duplicate fraud_type names' AS check_name;

SELECT a.fraud_type AS type_a, b.fraud_type AS type_b
FROM dim_fraud_type a
JOIN dim_fraud_type b
  ON a.fraud_type_id < b.fraud_type_id
 AND (
       -- One is a suffix of the other
       a.fraud_type || '_Fraud' = b.fraud_type
    OR b.fraud_type || '_Fraud' = a.fraud_type
    OR REPLACE(a.fraud_type, '_', '') = REPLACE(b.fraud_type, '_', '')
 );

-- ────────────────────────────────────────────────────────────
-- CHECK 4: Year coverage per fraud domain
-- Expected: All years 2016-2025 for Unauthorised card types,
--           2020-2025 for APP scams (data availability).
-- ────────────────────────────────────────────────────────────

SELECT 'CHECK 4: Year coverage by domain' AS check_name;

SELECT
    d.fraud_domain,
    MIN(f.year) AS min_year,
    MAX(f.year) AS max_year,
    COUNT(DISTINCT f.year) AS year_count
FROM fact_fraud f
JOIN dim_fraud_type d ON d.fraud_type_id = f.fraud_type_id
GROUP BY d.fraud_domain
ORDER BY d.fraud_domain;

-- ────────────────────────────────────────────────────────────
-- CHECK 5: Segment distribution
-- Expected: "All" for card fraud (Group A), "Personal" and
-- "Non-Personal" for APP scams (Group B).
-- ────────────────────────────────────────────────────────────

SELECT 'CHECK 5: Segment distribution by domain' AS check_name;

SELECT
    d.fraud_domain,
    f.segment,
    COUNT(*) AS row_count
FROM fact_fraud f
JOIN dim_fraud_type d ON d.fraud_type_id = f.fraud_type_id
GROUP BY d.fraud_domain, f.segment
ORDER BY d.fraud_domain, f.segment;

-- ────────────────────────────────────────────────────────────
-- CHECK 6: Fraud types with prevented data but no value/cases
-- Expected: Only Remote_Banking_Total and Cheque_Fraud
-- (these come from prevented-only summary tables).
-- ────────────────────────────────────────────────────────────

SELECT 'CHECK 6: Prevented-only fraud types' AS check_name;

SELECT DISTINCT d.fraud_type
FROM fact_fraud f
JOIN dim_fraud_type d ON d.fraud_type_id = f.fraud_type_id
WHERE f.prevented_gbp_m IS NOT NULL
  AND f.cases IS NULL
  AND f.value_gbp_m IS NULL
ORDER BY d.fraud_type;

-- ────────────────────────────────────────────────────────────
-- CHECK 7: Fact row count by fraud type
-- Quick overview to spot missing or extra data.
-- ────────────────────────────────────────────────────────────

SELECT 'CHECK 7: Row counts per fraud type' AS check_name;

SELECT
    d.fraud_type,
    d.fraud_category,
    d.fraud_domain,
    COUNT(*) AS fact_rows,
    COUNT(f.cases) AS has_cases,
    COUNT(f.value_gbp_m) AS has_value,
    COUNT(f.prevented_gbp_m) AS has_prevented
FROM dim_fraud_type d
LEFT JOIN fact_fraud f ON f.fraud_type_id = d.fraud_type_id
GROUP BY d.fraud_type, d.fraud_category, d.fraud_domain
ORDER BY d.fraud_domain, d.fraud_category, d.fraud_type;

-- ────────────────────────────────────────────────────────────
-- CHECK 8: Grand totals for sanity check
-- Compare these against the PDF report's summary figures.
-- ────────────────────────────────────────────────────────────

SELECT 'CHECK 8: Grand totals by year (All segment)' AS check_name;

SELECT
    f.year,
    SUM(f.cases)            AS total_cases,
    SUM(f.value_gbp_m)      AS total_value_gbp_m,
    SUM(f.prevented_gbp_m)  AS total_prevented_gbp_m
FROM fact_fraud f
WHERE f.segment = 'All'
GROUP BY f.year
ORDER BY f.year;
