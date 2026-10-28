-- ============================================================
-- 04_CLEANUP_LEGACY.sql
-- FinCrime Project — Remove stale dimension entries
-- Database: fincrime_db  |  Server: <your-host>:5432
--
-- Run ONCE after the first successful load with corrected
-- M code to remove any leftover dim_fraud_type entries from
-- earlier loads that used the wrong fraud_type names
-- (e.g. "Counterfeit_Card_Fraud" vs "Counterfeit_Card").
--
-- Safe to re-run: deletes nothing if the stale names are gone.
-- ============================================================

BEGIN;

-- Remove fact rows that reference stale fraud_type names
-- (these would be empty/orphan rows from the old load)
DELETE FROM fact_fraud
WHERE fraud_type_id IN (
    SELECT fraud_type_id
    FROM dim_fraud_type
    WHERE fraud_type IN (
        'Counterfeit_Card_Fraud',
        'Card_ID_Tefth_Fraud',
        'Card_ID_Theft_Fraud',
        'UK_Retail_FaceToFace_Fraud',
        'Account_Takeover_Fraud',
        'Mobile_Banking_Fraud',
        'Internet_Banking_Fraud',
        'Internet_eCommerce_Fraud',
        'Telephone_Banking_Fraud'
    )
);

-- Now remove the stale dimension entries themselves
DELETE FROM dim_fraud_type
WHERE fraud_type IN (
    'Counterfeit_Card_Fraud',
    'Card_ID_Tefth_Fraud',
    'Card_ID_Theft_Fraud',
    'UK_Retail_FaceToFace_Fraud',
    'Account_Takeover_Fraud',
    'Mobile_Banking_Fraud',
    'Internet_Banking_Fraud',
    'Internet_eCommerce_Fraud',
    'Telephone_Banking_Fraud'
);

COMMIT;

-- Verify: should show exactly 23 fraud types, no _Fraud suffixes
SELECT fraud_type_id, fraud_type, fraud_category, fraud_domain
FROM dim_fraud_type
ORDER BY fraud_domain, fraud_category, fraud_type;
