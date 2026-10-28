-- ============================================================
-- 05_ANALYSIS_VIEWS.sql
-- FinCrime Project — Analytical views for Excel ODBC
-- Database: fincrime_db  |  Server: <your-host>:5432
--
-- These views provide ready-made datasets for Excel pivot
-- tables and charts via ODBC. They JOIN fact + dimensions
-- so Excel sees friendly column names, not foreign keys.
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- VIEW 1: Full denormalised fact table
-- Use this as the main data source for Excel pivot tables.
-- ────────────────────────────────────────────────────────────

CREATE OR REPLACE VIEW v_fraud_analysis AS
SELECT
    f.year,
    f.segment,
    d.fraud_type,
    d.fraud_category,
    d.fraud_domain,
    f.cases,
    f.value_gbp_m,
    f.prevented_gbp_m,
    f.payments,
    f.returned_gbp_m,
    f.source_page,
    -- Derived columns for dashboard convenience
    CASE
        WHEN f.value_gbp_m IS NOT NULL AND f.prevented_gbp_m IS NOT NULL
        THEN f.value_gbp_m + f.prevented_gbp_m
    END AS total_attempted_gbp_m,
    CASE
        WHEN f.value_gbp_m IS NOT NULL AND f.prevented_gbp_m IS NOT NULL
             AND (f.value_gbp_m + f.prevented_gbp_m) > 0
        THEN ROUND(
            f.prevented_gbp_m / (f.value_gbp_m + f.prevented_gbp_m) * 100,
            1
        )
    END AS prevention_rate_pct
FROM fact_fraud f
JOIN dim_fraud_type d ON d.fraud_type_id = f.fraud_type_id
ORDER BY d.fraud_domain, d.fraud_category, d.fraud_type, f.year, f.segment;

-- ────────────────────────────────────────────────────────────
-- VIEW 2: Year-over-year changes (All segment only)
-- For trend analysis charts.
-- ────────────────────────────────────────────────────────────

CREATE OR REPLACE VIEW v_fraud_yoy AS
SELECT
    curr.year,
    d.fraud_type,
    d.fraud_category,
    d.fraud_domain,
    curr.cases                                          AS cases,
    prev.cases                                          AS cases_prev,
    CASE WHEN prev.cases > 0
         THEN ROUND((curr.cases - prev.cases)::NUMERIC / prev.cases * 100, 1)
    END                                                 AS cases_yoy_pct,
    curr.value_gbp_m                                    AS value_gbp_m,
    prev.value_gbp_m                                    AS value_prev,
    CASE WHEN prev.value_gbp_m > 0
         THEN ROUND((curr.value_gbp_m - prev.value_gbp_m) / prev.value_gbp_m * 100, 1)
    END                                                 AS value_yoy_pct,
    curr.prevented_gbp_m,
    prev.prevented_gbp_m                                AS prevented_prev
FROM fact_fraud curr
JOIN dim_fraud_type d ON d.fraud_type_id = curr.fraud_type_id
LEFT JOIN fact_fraud prev
    ON prev.fraud_type_id = curr.fraud_type_id
   AND prev.year = curr.year - 1
   AND prev.segment = curr.segment
WHERE curr.segment = 'All'
ORDER BY d.fraud_type, curr.year;

-- ────────────────────────────────────────────────────────────
-- VIEW 3: Prevention gap analysis
-- "Where is the gap between losses and prevention widening?"
-- ────────────────────────────────────────────────────────────

CREATE OR REPLACE VIEW v_prevention_gap AS
SELECT
    f.year,
    d.fraud_type,
    d.fraud_category,
    d.fraud_domain,
    f.value_gbp_m                                       AS losses_gbp_m,
    f.prevented_gbp_m,
    (f.value_gbp_m - f.prevented_gbp_m)                 AS gap_gbp_m,
    CASE WHEN f.value_gbp_m > 0
         THEN ROUND(f.prevented_gbp_m / f.value_gbp_m * 100, 1)
    END                                                 AS prevented_to_loss_ratio_pct
FROM fact_fraud f
JOIN dim_fraud_type d ON d.fraud_type_id = f.fraud_type_id
WHERE f.segment = 'All'
  AND f.value_gbp_m     IS NOT NULL
  AND f.prevented_gbp_m IS NOT NULL
ORDER BY gap_gbp_m DESC, f.year;

-- ────────────────────────────────────────────────────────────
-- VIEW 4: APP scam breakdown (Personal vs Non-Personal)
-- For segment comparison charts.
-- ────────────────────────────────────────────────────────────

CREATE OR REPLACE VIEW v_app_scam_segments AS
SELECT
    f.year,
    d.fraud_type,
    f.segment,
    f.cases,
    f.value_gbp_m,
    f.payments,
    f.returned_gbp_m,
    CASE WHEN f.value_gbp_m > 0 AND f.returned_gbp_m IS NOT NULL
         THEN ROUND(f.returned_gbp_m / f.value_gbp_m * 100, 1)
    END AS return_rate_pct
FROM fact_fraud f
JOIN dim_fraud_type d ON d.fraud_type_id = f.fraud_type_id
WHERE d.fraud_domain = 'Authorised (APP)'
  AND f.segment IN ('Personal', 'Non-Personal')
ORDER BY d.fraud_type, f.year, f.segment;
