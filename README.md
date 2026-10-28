# FinCrime: UK Fraud Analysis Pipeline

An end-to-end data pipeline and analysis of UK fraud losses, prevention and
reimbursement from 2016 to 2025, built from the **UK Finance Annual Fraud
Report 2026**.

```
UK Finance PDF  →  Excel (Power Query)  →  CSV  →  PostgreSQL (star schema)  →  Excel (ODBC dashboards)
```

## What's covered

- **Unauthorised fraud**: card fraud (CNP, counterfeit, lost/stolen, card ID
  theft, CNR), remote banking (internet, telephone, mobile), cheque fraud and
  account takeover
- **Authorised push payment (APP) scams**: purchase, investment, romance,
  advance fee, invoice, CEO, police/bank impersonation and other impersonation
- **Metrics**: cases, losses (£m), prevented fraud (£m), payments, and amounts
  returned to victims, split by personal and non-personal segments

## Repository structure

```
fincrime-project/
├── FinCrime.xlsx               Power Query workbook that extracts tables from the PDF
├── combined_fraud_data.csv     Cleaned, combined dataset exported from Power Query
├── SQL_Scripts/
│   ├── 01_CREATE_SCHEMA.sql    Staging tables and star schema DDL
│   ├── 02_LOAD_DATA.sql        CSV → staging → dimensions → fact (idempotent)
│   ├── 03_VERIFY_DATA.sql      8 data quality checks
│   ├── 04_CLEANUP_LEGACY.sql   One-time cleanup of stale entries
│   ├── 05_ANALYSIS_VIEWS.sql   4 analytical views for dashboards
│   ├── CREATE_DB_TABLE.sql
│   ├── CORRECTED_M_CODE.md     Power Query M code fixes
│   └── README_PIPELINE.md      Detailed run instructions
└── analytics_view_csv/         Exports of the analytical views
    ├── fraud_analysis.csv      Main fact view with categories and prevention rate
    ├── fraud_status_yoy.csv    Year-on-year change in cases, losses and prevention
    ├── prevention_gap.csv      Losses vs prevented amounts by fraud type
    └── app_scams_cohorts.csv   APP scam reimbursement (return) rates
```

## How to run

1. **Extract**: open `FinCrime.xlsx`, apply the fixes in
   `SQL_Scripts/CORRECTED_M_CODE.md`, refresh `Combined_Fraud_Data_Table`, and
   export it as `combined_fraud_data.csv`.
2. **Load**: run the SQL scripts `01` → `05` in order against a PostgreSQL
   database. `03_VERIFY_DATA.sql` should report zero problems.
3. **Analyse**: connect Excel (or any BI tool) to the database over ODBC and
   use the `v_fraud_analysis` view as the main data source.

See [`SQL_Scripts/README_PIPELINE.md`](SQL_Scripts/README_PIPELINE.md) for
full details.

## Tools

Excel Power Query (M), PostgreSQL, DBeaver/psql, ODBC

## Data source

UK Finance, *Annual Fraud Report 2026*. Each row in `combined_fraud_data.csv`
cites the page it was taken from in its `Source_Page` column. All figures are
published aggregates; the dataset contains no personal data.
