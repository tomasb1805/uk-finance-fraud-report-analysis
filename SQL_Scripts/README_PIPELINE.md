# FinCrime Data Pipeline — Quick Reference

## Execution Order

```
Excel (Power Query)  →  CSV  →  PostgreSQL  →  Excel (ODBC)
```

### Step 1: Apply M Code Fixes (in Excel/Power Query)

Open `FinCrime.xlsx` in Excel. For each query listed in
`CORRECTED_M_CODE.md`, right-click the query → Advanced Editor,
replace the entire code, and click Done.

**Apply order:** `fnRestructureCardTables` first (the function),
then the 10 calling queries, then `Prevented_Card_Fraud_Clean`,
then the two other Prevented queries.

After all 13 fixes: right-click `Combined_Fraud_Data_Table` →
Refresh. Then File → Export to CSV as `combined_fraud_data.csv`
into the project folder.

### Step 2: Run SQL Scripts (in DBeaver or psql)

Connect to your `fincrime_db` PostgreSQL database, then run in order:

| Script | Purpose |
|--------|---------|
| `01_CREATE_SCHEMA.sql` | Creates/resets staging + star schema tables |
| `02_LOAD_DATA.sql` | Loads CSV → staging → dimensions → fact (idempotent) |
| `03_VERIFY_DATA.sql` | 8 data quality checks — all should return 0 problems |
| `04_CLEANUP_LEGACY.sql` | Removes stale `_Fraud` suffix entries from old loads (run once) |
| `05_ANALYSIS_VIEWS.sql` | Creates 4 analytical views for Excel ODBC dashboards |

### Step 3: Connect Excel to PostgreSQL

Set up an ODBC data source on the machine running Excel pointing to
your `fincrime_db` database, then use Data → Get Data →
From ODBC to pull the `v_fraud_analysis` view as the main
data source for pivot tables and charts.

## File Inventory

```
fincrime-project/
├── FinCrime.xlsx                  ← Power Query workbook
├── combined_fraud_data.csv        ← CSV export (refreshed after fixes)
├── CORRECTED_M_CODE.md            ← All 13 Power Query fixes with code
├── 01_CREATE_SCHEMA.sql           ← DDL: staging + star schema
├── 02_LOAD_DATA.sql               ← ETL: CSV → staging → fact
├── 03_VERIFY_DATA.sql             ← 8 verification queries
├── 04_CLEANUP_LEGACY.sql          ← One-time stale data cleanup
├── 05_ANALYSIS_VIEWS.sql          ← 4 analytical views for ODBC
└── README_PIPELINE.md             ← This file
```
