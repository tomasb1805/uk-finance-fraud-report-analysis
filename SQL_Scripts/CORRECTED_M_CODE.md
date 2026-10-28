# Power Query M Code Corrections
## FinCrime.xlsx — All fixes for data integrity

> **How to apply:** Open each query in Power Query Advanced Editor
> (right-click query in Queries pane → Advanced Editor) and replace
> the ENTIRE code with the corrected version below.
>
> After applying ALL fixes, right-click `Combined_Fraud_Data_Table`
> → Refresh, then re-export the CSV.

---

### FIX 1: `fnRestructureCardTables` (the shared function)

**What changed:** Year filter `>= 2020` → `>= 2016` so card fraud
detail tables include the full 2016-2025 range from the PDF.

```
(tableId as text, fraudType as text, sourcePage as text) =>
let
    Source = Pdf.Tables(
        File.Contents("C:\path\to\fincrime-project\UK Finance Fraud Report 2026.pdf"),
        [Implementation="1.3"]
    ),
    RawTable = Source{[Id=tableId]}[Data],
    #"All Text" = Table.TransformColumnTypes(
        RawTable,
        List.Transform(Table.ColumnNames(RawTable), each {_, type text})
    ),
    #"Promoted" = Table.PromoteHeaders(#"All Text", [PromoteAllScalars=true]),
    changeCols = List.Select(
        Table.ColumnNames(#"Promoted"),
        each Text.Contains(_, "change", Comparer.OrdinalIgnoreCase)
    ),
    #"No Change" = if List.IsEmpty(changeCols)
        then #"Promoted"
        else Table.RemoveColumns(#"Promoted", changeCols),
    #"No Blanks" = Table.SelectRows(#"No Change",
        each not List.IsEmpty(
            List.RemoveMatchingItems(Record.FieldValues(_), {"", null})
        )
    ),
    firstCol = Table.ColumnNames(#"No Blanks"){0},
    #"Unpivoted" = Table.UnpivotOtherColumns(
        #"No Blanks", {firstCol}, "Year", "RawValue"
    ),
    #"Renamed" = Table.RenameColumns(#"Unpivoted", {{firstCol, "Measure"}}),
    #"C1" = Table.ReplaceValue(#"Renamed",  "£", "", Replacer.ReplaceText, {"RawValue"}),
    #"C2" = Table.ReplaceValue(#"C1",       "m", "", Replacer.ReplaceText, {"RawValue"}),
    #"C3" = Table.ReplaceValue(#"C2",       ",", "", Replacer.ReplaceText, {"RawValue"}),
    #"Trimmed" = Table.TransformColumns(#"C3", {{"RawValue", Text.Trim, type text}}),
    #"NA1" = Table.ReplaceValue(#"Trimmed", "N/A", null, Replacer.ReplaceValue, {"RawValue"}),
    #"NA2" = Table.ReplaceValue(#"NA1",     "",    null, Replacer.ReplaceValue, {"RawValue"}),
    #"Standardised" = Table.TransformColumns(#"NA2", {
        {"Measure", each
            if Text.Contains(_, "cases", Comparer.OrdinalIgnoreCase) then "Cases"
            else if Text.Contains(_, "prevented", Comparer.OrdinalIgnoreCase) then "Prevented"
            else "Value",
        type text}
    }),
    #"Typed" = Table.TransformColumnTypes(#"Standardised", {
        {"Year", Int64.Type}, {"RawValue", type number}
    }),
    // *** FIX: was >= 2020, now >= 2016 to capture full data range ***
    #"Filtered" = Table.SelectRows(#"Typed", each [Year] >= 2016),
    #"Pivoted" = Table.Pivot(
        #"Filtered",
        List.Distinct(#"Filtered"[Measure]),
        "Measure", "RawValue"
    ),
    #"E1" = if Table.HasColumns(#"Pivoted", "Cases")
            then #"Pivoted"
            else Table.AddColumn(#"Pivoted", "Cases", each null, type number),
    #"E2" = if Table.HasColumns(#"E1", "Value")
            then #"E1"
            else Table.AddColumn(#"E1", "Value", each null, type number),
    #"E3" = if Table.HasColumns(#"E2", "Prevented")
            then #"E2"
            else Table.AddColumn(#"E2", "Prevented", each null, type number),
    #"Renamed Cols" = Table.RenameColumns(#"E3", {
        {"Value", "Value_GBP_m"},
        {"Prevented", "Prevented_GBP_m"}
    }),
    #"Added Seg" = Table.AddColumn(#"Renamed Cols", "Segment",        each "All",       type text),
    #"Added FT"  = Table.AddColumn(#"Added Seg",    "Fraud_Type",     each fraudType,   type text),
    #"Added SP"  = Table.AddColumn(#"Added FT",     "Source_Page",    each sourcePage,  type text),
    #"Added P"   = Table.AddColumn(#"Added SP",     "Payments",       each null, type number),
    #"Added R"   = Table.AddColumn(#"Added P",      "Returned_GBP_m", each null, type number),
    #"Final" = Table.SelectColumns(#"Added R", {
        "Year", "Segment", "Fraud_Type", "Source_Page",
        "Cases", "Value_GBP_m", "Prevented_GBP_m",
        "Payments", "Returned_GBP_m"
    })
in
    #"Final"
```

---

### FIX 2: `Card_Not_Received_Fraud`

**What changed:** Converted to use `fnRestructureCardTables` instead
of standalone code. Fixes: segment "Unauthorised" → "All", adds
missing Prevented/Payments/Returned columns, gets full year range.

```
let
    Result = fnRestructureCardTables(
        "Table048",
        "Card_Not_Received",
        "UK Finance 2026, p.24")
in
    Result
```

---

### FIX 3: `Counterfeit_Card_Fraud`

**What changed:** `"Counterfeit_Card_Fraud"` → `"Counterfeit_Card"`

```
let
    Result = fnRestructureCardTables(
        "Table049",
        "Counterfeit_Card",
        "UK Finance 2026, p.24")
in
    Result
```

---

### FIX 4: `Card_ID_Theft`

**What changed:** `"Card_ID_Tefth_Fraud"` → `"Card_ID_Theft"`
(fixed typo AND removed _Fraud suffix)

```
let
    Result = fnRestructureCardTables(
        "Table053",
        "Card_ID_Theft",
        "UK Finance 2026, p.26")
in
    Result
```

---

### FIX 5: `UK_Retail_FaceToFace_Fraud`

**What changed:** `"UK_Retail_FaceToFace_Fraud"` → `"UK_Retail_FaceToFace"`

```
let
    Result = fnRestructureCardTables(
        "Table056",
        "UK_Retail_FaceToFace",
        "UK Finance 2026, p.27")
in
    Result
```

---

### FIX 6: `Account_Takeover_Fraud`

**What changed:** `"Account_Takeover_Fraud"` → `"Account_Takeover"`

```
let
    Result = fnRestructureCardTables(
        "Table055",
        "Account_Takeover",
        "UK Finance 2026, p.26")
in
    Result
```

---

### FIX 7: `Mobile_Banking_Fraud`

**What changed:** `"Mobile_Banking_Fraud"` → `"Mobile_Banking"`

```
let
    Result = fnRestructureCardTables(
        "Table067",
        "Mobile_Banking",
        "UK Finance 2026, p.32")
in
    Result
```

---

### FIX 8: `Internet_Banking_Fraud`

**What changed:** `"Internet_Banking_Fraud"` → `"Internet_Banking"`

```
let
    Result = fnRestructureCardTables(
        "Table064",
        "Internet_Banking",
        "UK Finance 2026, p.31")
in
    Result
```

---

### FIX 9: `Internet_eCommerce_Fraud`

**What changed:** `"Internet_eCommerce_Fraud"` → `"Internet_eCommerce"`

```
let
    Result = fnRestructureCardTables(
        "Table057",
        "Internet_eCommerce",
        "UK Finance 2026, p.28")
in
    Result
```

---

### FIX 10: `Telephone_Banking_Fraud`

**What changed:** `"Telephone_Banking_Fraud"` → `"Telephone_Banking"`

```
let
    Result = fnRestructureCardTables(
        "Table065",
        "Telephone_Banking",
        "UK Finance 2026, p.32")
in
    Result
```

---

### FIX 11: `Prevented_Card_Fraud_Clean`

**What changed:**
1. Added CNR → `Card_Not_Received` mapping
2. Added CNP → `Remote_Purchase` mapping
3. Added "Prevented" (total row) → `null` mapping + filter to exclude it
4. Year filter `>= 2020` → `>= 2016` for full range

```
let
    Source = Pdf.Tables(
        File.Contents("C:\path\to\fincrime-project\UK Finance Fraud Report 2026.pdf"),
        [Implementation="1.3"]
    ),
    RawTable = Source{[Id="Table042"]}[Data],
    #"All Text" = Table.TransformColumnTypes(
        RawTable,
        List.Transform(Table.ColumnNames(RawTable), each {_, type text})
    ),
    #"Promoted" = Table.PromoteHeaders(#"All Text", [PromoteAllScalars=true]),

    // Remove Change / % column if present
    changeCols = List.Select(
        Table.ColumnNames(#"Promoted"),
        each Text.Contains(_, "change", Comparer.OrdinalIgnoreCase)
    ),
    #"No Change" = if List.IsEmpty(changeCols)
        then #"Promoted"
        else Table.RemoveColumns(#"Promoted", changeCols),

    // Remove blank rows
    #"No Blanks" = Table.SelectRows(#"No Change",
        each not List.IsEmpty(
            List.RemoveMatchingItems(Record.FieldValues(_), {"", null})
        )
    ),

    // First column = the card fraud category label
    firstCol = Table.ColumnNames(#"No Blanks"){0},

    // Unpivot year columns
    #"Unpivoted" = Table.UnpivotOtherColumns(
        #"No Blanks", {firstCol}, "Year", "RawValue"
    ),
    #"Renamed" = Table.RenameColumns(#"Unpivoted", {{firstCol, "Fraud_Type"}}),

    // Clean currency symbols
    #"C1" = Table.ReplaceValue(#"Renamed",  "£", "", Replacer.ReplaceText, {"RawValue"}),
    #"C2" = Table.ReplaceValue(#"C1",       "m", "", Replacer.ReplaceText, {"RawValue"}),
    #"C3" = Table.ReplaceValue(#"C2",       ",", "", Replacer.ReplaceText, {"RawValue"}),
    #"Trimmed" = Table.TransformColumns(#"C3", {{"RawValue", Text.Trim, type text}}),
    #"NA1" = Table.ReplaceValue(#"Trimmed", "N/A", null, Replacer.ReplaceValue, {"RawValue"}),
    #"NA2" = Table.ReplaceValue(#"NA1",     "",    null, Replacer.ReplaceValue, {"RawValue"}),

    // Type conversions
    #"Typed" = Table.TransformColumnTypes(#"NA2", {
        {"Year", Int64.Type}, {"RawValue", type number}
    }),

    // *** FIX: Filter 2016+ (was 2020+), exclude Total rows ***
    #"Filtered" = Table.SelectRows(#"Typed",
        each [Year] >= 2016
             and not Text.Contains([Fraud_Type], "total", Comparer.OrdinalIgnoreCase)
    ),

    // *** FIX: Complete mapping with CNR, CNP, and Prevented exclusion ***
    #"Mapped" = Table.TransformColumns(#"Filtered", {
        {"Fraud_Type", each
            if Text.Contains(_, "not received",  Comparer.OrdinalIgnoreCase)
                then "Card_Not_Received"
            else if Text.Contains(_, "mail",     Comparer.OrdinalIgnoreCase)
                then "Card_Not_Received"
            else if _ = "CNR"
                then "Card_Not_Received"
            else if Text.Contains(_, "counterfeit", Comparer.OrdinalIgnoreCase)
                then "Counterfeit_Card"
            else if Text.Contains(_, "lost",     Comparer.OrdinalIgnoreCase)
                then "Lost_Stolen_Card"
            else if Text.Contains(_, "stolen",   Comparer.OrdinalIgnoreCase)
                then "Lost_Stolen_Card"
            else if Text.Contains(_, "id theft", Comparer.OrdinalIgnoreCase)
                then "Card_ID_Theft"
            else if Text.Contains(_, "identity", Comparer.OrdinalIgnoreCase)
                then "Card_ID_Theft"
            else if Text.Contains(_, "remote",   Comparer.OrdinalIgnoreCase)
                then "Remote_Purchase"
            else if _ = "CNP"
                then "Remote_Purchase"
            else if Text.Contains(_, "prevented", Comparer.OrdinalIgnoreCase)
                then null
            else _,
        type text}
    }),

    // *** FIX: Remove rows where Fraud_Type mapped to null (the "Prevented" total) ***
    #"No Prevented Total" = Table.SelectRows(#"Mapped",
        each [Fraud_Type] <> null
    ),

    // Rename value column
    #"Renamed PV" = Table.RenameColumns(#"No Prevented Total", {{"RawValue", "Prevented_GBP_m"}}),

    // Add remaining schema columns
    #"Added Seg" = Table.AddColumn(#"Renamed PV", "Segment",        each "All",                      type text),
    #"Added SP"  = Table.AddColumn(#"Added Seg",  "Source_Page",    each "UK Finance 2026, Table042", type text),
    #"Added C"   = Table.AddColumn(#"Added SP",   "Cases",          each null, type number),
    #"Added V"   = Table.AddColumn(#"Added C",    "Value_GBP_m",    each null, type number),
    #"Added P"   = Table.AddColumn(#"Added V",    "Payments",       each null, type number),
    #"Added R"   = Table.AddColumn(#"Added P",    "Returned_GBP_m", each null, type number),

    #"Final" = Table.SelectColumns(#"Added R", {
        "Year", "Segment", "Fraud_Type", "Source_Page",
        "Cases", "Value_GBP_m", "Prevented_GBP_m",
        "Payments", "Returned_GBP_m"
    })
in
    #"Final"
```

---

### FIX 12: `Prevented_Remote_Banking_Clean`

**What changed:** Year filter `>= 2020` → `>= 2016`

```
let
    Source = Pdf.Tables(
        File.Contents("C:\path\to\fincrime-project\UK Finance Fraud Report 2026.pdf"),
        [Implementation="1.3"]
    ),
    RawTable = Source{[Id="Table062"]}[Data],
    #"All Text" = Table.TransformColumnTypes(
        RawTable,
        List.Transform(Table.ColumnNames(RawTable), each {_, type text})
    ),
    #"Promoted" = Table.PromoteHeaders(#"All Text", [PromoteAllScalars=true]),

    // Remove Change column
    changeCols = List.Select(
        Table.ColumnNames(#"Promoted"),
        each Text.Contains(_, "change", Comparer.OrdinalIgnoreCase)
    ),
    #"No Change" = if List.IsEmpty(changeCols)
        then #"Promoted"
        else Table.RemoveColumns(#"Promoted", changeCols),

    // Remove blank rows
    #"No Blanks" = Table.SelectRows(#"No Change",
        each not List.IsEmpty(
            List.RemoveMatchingItems(Record.FieldValues(_), {"", null})
        )
    ),

    // First column has the measure label
    firstCol = Table.ColumnNames(#"No Blanks"){0},
    #"Renamed FC" = Table.RenameColumns(#"No Blanks", {{firstCol, "Measure"}}),

    // Unpivot year columns
    #"Unpivoted" = Table.UnpivotOtherColumns(
        #"Renamed FC", {"Measure"}, "Year", "RawValue"
    ),

    // Clean currency
    #"C1" = Table.ReplaceValue(#"Unpivoted", "£", "", Replacer.ReplaceText, {"RawValue"}),
    #"C2" = Table.ReplaceValue(#"C1",        "m", "", Replacer.ReplaceText, {"RawValue"}),
    #"C3" = Table.ReplaceValue(#"C2",        ",", "", Replacer.ReplaceText, {"RawValue"}),
    #"Trimmed" = Table.TransformColumns(#"C3", {{"RawValue", Text.Trim, type text}}),
    #"NA1" = Table.ReplaceValue(#"Trimmed", "N/A", null, Replacer.ReplaceValue, {"RawValue"}),
    #"NA2" = Table.ReplaceValue(#"NA1",     "",    null, Replacer.ReplaceValue, {"RawValue"}),

    // Standardise measure labels
    #"Std" = Table.TransformColumns(#"NA2", {
        {"Measure", each
            if Text.Contains(_, "prevented", Comparer.OrdinalIgnoreCase)
                then "Prevented_GBP_m"
            else "Value_GBP_m",
        type text}
    }),

    #"Typed" = Table.TransformColumnTypes(#"Std", {
        {"Year", Int64.Type}, {"RawValue", type number}
    }),
    // *** FIX: was >= 2020, now >= 2016 ***
    #"Filtered" = Table.SelectRows(#"Typed", each [Year] >= 2016),

    // Pivot
    #"Pivoted" = Table.Pivot(
        #"Filtered",
        List.Distinct(#"Filtered"[Measure]),
        "Measure", "RawValue"
    ),

    // Ensure both measure columns exist
    #"E1" = if Table.HasColumns(#"Pivoted", "Value_GBP_m")
            then #"Pivoted"
            else Table.AddColumn(#"Pivoted", "Value_GBP_m", each null, type number),
    #"E2" = if Table.HasColumns(#"E1", "Prevented_GBP_m")
            then #"E1"
            else Table.AddColumn(#"E1", "Prevented_GBP_m", each null, type number),

    // Add remaining schema columns
    #"Added Seg" = Table.AddColumn(#"E2",        "Segment",        each "All",                      type text),
    #"Added FT"  = Table.AddColumn(#"Added Seg", "Fraud_Type",     each "Remote_Banking_Total",     type text),
    #"Added SP"  = Table.AddColumn(#"Added FT",  "Source_Page",    each "UK Finance 2026, Table062", type text),
    #"Added C"   = Table.AddColumn(#"Added SP",  "Cases",          each null, type number),
    #"Added P"   = Table.AddColumn(#"Added C",   "Payments",       each null, type number),
    #"Added R"   = Table.AddColumn(#"Added P",   "Returned_GBP_m", each null, type number),

    #"Final" = Table.SelectColumns(#"Added R", {
        "Year", "Segment", "Fraud_Type", "Source_Page",
        "Cases", "Value_GBP_m", "Prevented_GBP_m",
        "Payments", "Returned_GBP_m"
    })
in
    #"Final"
```

---

### FIX 13: `Prevented_Cheque_Clean`

**What changed:** Year filter `>= 2020` → `>= 2016`

```
let
    Source = Pdf.Tables(
        File.Contents("C:\path\to\fincrime-project\UK Finance Fraud Report 2026.pdf"),
        [Implementation="1.3"]
    ),
    RawTable = Source{[Id="Table060"]}[Data],
    #"All Text" = Table.TransformColumnTypes(
        RawTable,
        List.Transform(Table.ColumnNames(RawTable), each {_, type text})
    ),
    #"Promoted" = Table.PromoteHeaders(#"All Text", [PromoteAllScalars=true]),

    // Remove Change column
    changeCols = List.Select(
        Table.ColumnNames(#"Promoted"),
        each Text.Contains(_, "change", Comparer.OrdinalIgnoreCase)
    ),
    #"No Change" = if List.IsEmpty(changeCols)
        then #"Promoted"
        else Table.RemoveColumns(#"Promoted", changeCols),

    // Remove blank rows
    #"No Blanks" = Table.SelectRows(#"No Change",
        each not List.IsEmpty(
            List.RemoveMatchingItems(Record.FieldValues(_), {"", null})
        )
    ),

    // First column has "Value" / "Prevented"
    firstCol = Table.ColumnNames(#"No Blanks"){0},
    #"Renamed FC" = Table.RenameColumns(#"No Blanks", {{firstCol, "Measure"}}),

    // Unpivot year columns
    #"Unpivoted" = Table.UnpivotOtherColumns(
        #"Renamed FC", {"Measure"}, "Year", "RawValue"
    ),

    // Clean currency
    #"C1" = Table.ReplaceValue(#"Unpivoted", "£", "", Replacer.ReplaceText, {"RawValue"}),
    #"C2" = Table.ReplaceValue(#"C1",        "m", "", Replacer.ReplaceText, {"RawValue"}),
    #"C3" = Table.ReplaceValue(#"C2",        ",", "", Replacer.ReplaceText, {"RawValue"}),
    #"Trimmed" = Table.TransformColumns(#"C3", {{"RawValue", Text.Trim, type text}}),
    #"NA1" = Table.ReplaceValue(#"Trimmed", "N/A", null, Replacer.ReplaceValue, {"RawValue"}),
    #"NA2" = Table.ReplaceValue(#"NA1",     "",    null, Replacer.ReplaceValue, {"RawValue"}),

    // Standardise measure labels
    #"Std" = Table.TransformColumns(#"NA2", {
        {"Measure", each
            if Text.Contains(_, "prevented", Comparer.OrdinalIgnoreCase)
                then "Prevented_GBP_m"
            else "Value_GBP_m",
        type text}
    }),

    #"Typed" = Table.TransformColumnTypes(#"Std", {
        {"Year", Int64.Type}, {"RawValue", type number}
    }),
    // *** FIX: was >= 2020, now >= 2016 ***
    #"Filtered" = Table.SelectRows(#"Typed", each [Year] >= 2016),

    // Pivot
    #"Pivoted" = Table.Pivot(
        #"Filtered",
        List.Distinct(#"Filtered"[Measure]),
        "Measure", "RawValue"
    ),

    #"E1" = if Table.HasColumns(#"Pivoted", "Value_GBP_m")
            then #"Pivoted"
            else Table.AddColumn(#"Pivoted", "Value_GBP_m", each null, type number),
    #"E2" = if Table.HasColumns(#"E1", "Prevented_GBP_m")
            then #"E1"
            else Table.AddColumn(#"E1", "Prevented_GBP_m", each null, type number),

    // Add remaining schema columns
    #"Added Seg" = Table.AddColumn(#"E2",        "Segment",        each "All",                      type text),
    #"Added FT"  = Table.AddColumn(#"Added Seg", "Fraud_Type",     each "Cheque_Fraud",             type text),
    #"Added SP"  = Table.AddColumn(#"Added FT",  "Source_Page",    each "UK Finance 2026, Table060", type text),
    #"Added C"   = Table.AddColumn(#"Added SP",  "Cases",          each null, type number),
    #"Added P"   = Table.AddColumn(#"Added C",   "Payments",       each null, type number),
    #"Added R"   = Table.AddColumn(#"Added P",   "Returned_GBP_m", each null, type number),

    #"Final" = Table.SelectColumns(#"Added R", {
        "Year", "Segment", "Fraud_Type", "Source_Page",
        "Cases", "Value_GBP_m", "Prevented_GBP_m",
        "Payments", "Returned_GBP_m"
    })
in
    #"Final"
```

---

## Summary of all fixes

| # | Query | Bug | Fix |
|---|-------|-----|-----|
| 1 | `fnRestructureCardTables` | `[Year] >= 2020` | `[Year] >= 2016` |
| 2 | `Card_Not_Received_Fraud` | Standalone code, segment="Unauthorised", missing columns | Converted to `fnRestructureCardTables("Table048", "Card_Not_Received", ...)` |
| 3 | `Counterfeit_Card_Fraud` | `"Counterfeit_Card_Fraud"` | `"Counterfeit_Card"` |
| 4 | `Card_ID_Theft` | `"Card_ID_Tefth_Fraud"` (typo + suffix) | `"Card_ID_Theft"` |
| 5 | `UK_Retail_FaceToFace_Fraud` | `"UK_Retail_FaceToFace_Fraud"` | `"UK_Retail_FaceToFace"` |
| 6 | `Account_Takeover_Fraud` | `"Account_Takeover_Fraud"` | `"Account_Takeover"` |
| 7 | `Mobile_Banking_Fraud` | `"Mobile_Banking_Fraud"` | `"Mobile_Banking"` |
| 8 | `Internet_Banking_Fraud` | `"Internet_Banking_Fraud"` | `"Internet_Banking"` |
| 9 | `Internet_eCommerce_Fraud` | `"Internet_eCommerce_Fraud"` | `"Internet_eCommerce"` |
| 10 | `Telephone_Banking_Fraud` | `"Telephone_Banking_Fraud"` | `"Telephone_Banking"` |
| 11 | `Prevented_Card_Fraud_Clean` | Missing CNR/CNP mappings, "Prevented" total not excluded, Year >= 2020 | Added all mappings, null+filter for total, Year >= 2016 |
| 12 | `Prevented_Remote_Banking_Clean` | `[Year] >= 2020` | `[Year] >= 2016` |
| 13 | `Prevented_Cheque_Clean` | `[Year] >= 2020` | `[Year] >= 2016` |

### Queries that need NO changes (confirmed correct):
- `ATM_Fraud` — already uses `"ATM_Fraud"` (matches dim_fraud_type)
- `Third_Party_App_Fraud` — uses `"Third_Party_Apps"` (correct)
- `Remote_Purchase_Fraud` — uses `"Remote_Purchase"` (correct)
- All `_Scam_Clean` queries — correct fraud_type values
- `Combined_Fraud_Data_Table` — union only, no logic to fix
- `fnTransformFraudTable` — correct function
- `fnTransformFraudTable_CEO` — correct function
