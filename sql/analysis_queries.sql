/*
Project: Automotive Field Failure Intelligence
Database: Automotive Field Failure Intelligence
Source table: dbo.nhtsa_complaints
Purpose: SQL analysis script for portfolio documentation.

IMPORTANT:
- Run in SQL Server Management Studio (SSMS) after selecting the database.
- NHTSA complaints are reports, not verified failures. Counts are not failure rates without exposure/sales denominators.
*/

USE [Automotive Field Failure Intelligence];
GO

/* =========================================================
   1. TABLE STRUCTURE
   Inspect imported column names and data types.
   ========================================================= */
SELECT
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'dbo'
  AND TABLE_NAME = 'nhtsa_complaints'
ORDER BY ORDINAL_POSITION;
GO

/* =========================================================
   2. DATASET SIZE AND COMPLAINT ID UNIQUENESS
   Expected from prior profiling: 418,884 rows and unique CMPLID
   ========================================================= */
SELECT
    COUNT_BIG(*) AS total_rows,
    COUNT(DISTINCT CMPLID) AS distinct_complaint_ids,
    COUNT_BIG(*) - COUNT(DISTINCT CMPLID) AS rows_minus_distinct_ids,
    MIN(TRY_CONVERT(date, LDATE)) AS earliest_received_date,
    MAX(TRY_CONVERT(date, LDATE)) AS latest_received_date
FROM dbo.nhtsa_complaints;
GO

/* Duplicate complaint IDs, if any */
SELECT CMPLID, COUNT_BIG(*) AS row_count
FROM dbo.nhtsa_complaints
GROUP BY CMPLID
HAVING COUNT_BIG(*) > 1
ORDER BY row_count DESC;
GO

--No duplicate complaint ID's present in dataset for given timeframe

/* =========================================================
   3. DATA COVERAGE / CATEGORY COUNTS
   ========================================================= */
SELECT
    COUNT(DISTINCT MAKETXT) AS distinct_makes,
    COUNT(DISTINCT MODELTXT) AS distinct_models,
    COUNT(DISTINCT COMPDESC) AS distinct_component_descriptions,
    MIN(TRY_CONVERT(int, MODEL_YEAR)) AS minimum_model_year,
    MAX(TRY_CONVERT(int, MODEL_YEAR)) AS maximum_model_year
FROM dbo.nhtsa_complaints;
GO

SELECT
    CRASH,
    COUNT_BIG(*) AS complaint_count
FROM dbo.nhtsa_complaints
GROUP BY CRASH
ORDER BY complaint_count DESC;
GO

SELECT
    FIRE,
    COUNT_BIG(*) AS complaint_count
FROM dbo.nhtsa_complaints
GROUP BY FIRE
ORDER BY complaint_count DESC;
GO

/* =========================================================
   4. COMPLAINTS BY RECEIVED YEAR
   LDATE is used as the complaint received/recorded date.
   ========================================================= */
WITH complaint_dates AS (
    SELECT TRY_CONVERT(date, LDATE) AS received_date
    FROM dbo.nhtsa_complaints
)
SELECT
    YEAR(received_date) AS received_year,
    COUNT_BIG(*) AS complaint_count
FROM complaint_dates
WHERE received_date >= '20200101'
  AND received_date <  '20250101'
GROUP BY YEAR(received_date)
ORDER BY received_year;
GO

/* Monthly complaint trend, 2020–2024 */
WITH complaint_dates AS (
    SELECT TRY_CONVERT(date, LDATE) AS received_date
    FROM dbo.nhtsa_complaints
)
SELECT
    DATEFROMPARTS(YEAR(received_date), MONTH(received_date), 1) AS received_month,
    COUNT_BIG(*) AS complaint_count
FROM complaint_dates
WHERE received_date >= '20200101'
  AND received_date <  '20250101'
GROUP BY DATEFROMPARTS(YEAR(received_date), MONTH(received_date), 1)
ORDER BY received_month;
GO

/* =========================================================
   5. TOP COMPONENTS BY COMPLAINT VOLUME
   ========================================================= */
SELECT TOP (10)
    COMPDESC,
    COUNT(DISTINCT CMPLID) AS complaint_count
FROM dbo.nhtsa_complaints
GROUP BY COMPDESC
ORDER BY complaint_count DESC;
GO

/* Component complaint volume by received year */
WITH complaint_dates AS (
    SELECT
        COMPDESC,
        CMPLID,
        TRY_CONVERT(date, LDATE) AS received_date
    FROM dbo.nhtsa_complaints
)
SELECT
    YEAR(received_date) AS received_year,
    COMPDESC,
    COUNT(DISTINCT CMPLID) AS complaint_count
FROM complaint_dates
WHERE received_date >= '20200101'
  AND received_date <  '20250101'
GROUP BY YEAR(received_date), COMPDESC
ORDER BY received_year, complaint_count DESC;
GO
--Engine related complaints are maximum in given dataste for timeframe 2020-2024

/* =========================================================
   6. DIAGNOSTIC: ENGINE-RELATED COMPONENT CATEGORIES
   Purpose:
   Identify the exact component labels to include in the
   subsequent engine-related manufacturer/model analysis.
   ========================================================= */

SELECT
    COMPDESC,
    COUNT(DISTINCT CMPLID) AS complaint_count,
    COUNT(DISTINCT TRY_CONVERT(int, MODEL_YEAR)) AS model_years_available,
    MIN(TRY_CONVERT(int, MODEL_YEAR)) AS earliest_model_year,
    MAX(TRY_CONVERT(int, MODEL_YEAR)) AS latest_model_year
FROM dbo.nhtsa_complaints
WHERE UPPER(COALESCE(COMPDESC, '')) LIKE '%ENGINE%'
GROUP BY COMPDESC
ORDER BY complaint_count DESC;
GO

-- Step 6.1: Inspect engine-related complaint categories

SELECT
    COMPDESC,
    COUNT(DISTINCT CMPLID) AS complaint_count,
    COUNT(DISTINCT TRY_CONVERT(int, MODEL_YEAR))
        AS distinct_model_years,
    MIN(TRY_CONVERT(int, MODEL_YEAR)) AS first_model_year,
    MAX(TRY_CONVERT(int, MODEL_YEAR)) AS last_model_year
FROM dbo.nhtsa_complaints
WHERE COMPDESC LIKE '%ENGINE%'
   OR COMPDESC LIKE '%COOLING%'
   OR COMPDESC LIKE '%WATER PUMP%'
   OR COMPDESC LIKE '%RADIATOR%'
GROUP BY COMPDESC
ORDER BY
    COUNT(DISTINCT CMPLID) DESC,
    COMPDESC;

-- 6.2:Rank manufacturer-model combinations for engine/cooling investigation

WITH engine_complaints AS (
    SELECT
        CMPLID,
        MAKETXT,
        MODELTXT,
        COMPDESC,
        TRY_CONVERT(int, MODEL_YEAR) AS model_year,
        LDATE
    FROM dbo.nhtsa_complaints
    WHERE COMPDESC LIKE '%ENGINE%'
       OR COMPDESC LIKE '%COOLING%'
       OR COMPDESC LIKE '%WATER PUMP%'
       OR COMPDESC LIKE '%RADIATOR%'
)
SELECT TOP (30)
    MAKETXT AS manufacturer,
    MODELTXT AS vehicle_model,
    COUNT(DISTINCT CMPLID) AS complaint_count,
    COUNT(DISTINCT model_year) AS distinct_model_years,
    MIN(model_year) AS first_model_year,
    MAX(model_year) AS last_model_year,
    MAX(LDATE) AS latest_complaint_date
FROM engine_complaints
WHERE NULLIF(LTRIM(RTRIM(MAKETXT)), '') IS NOT NULL
  AND NULLIF(LTRIM(RTRIM(MODELTXT)), '') IS NOT NULL
GROUP BY
    MAKETXT,
    MODELTXT
ORDER BY
    complaint_count DESC,
    manufacturer,
    vehicle_model;
/*
Observation
- Ford Escape recorded the highest volume in our current engine/cooling-related vehicle-model screening, with 3,665 complaints 
across 22 model years (2001–2024). This makes it a strong candidate for deeper investigation, not necessarily the vehicle with the highest failure rate.
- The next objective is to move beyond aggregate counts and identify recurring component-level issues and model-year-specific 
complaint patterns that can be validated through complaint narratives.
*/


-- 6.3: Ford Escape component-level complaint breakdown

SELECT
    COMPDESC AS component_category,
    COUNT(DISTINCT CMPLID) AS complaint_count,
    COUNT(DISTINCT TRY_CONVERT(int, MODEL_YEAR))
        AS distinct_model_years,
    MIN(TRY_CONVERT(int, MODEL_YEAR)) AS first_model_year,
    MAX(TRY_CONVERT(int, MODEL_YEAR)) AS last_model_year
FROM dbo.nhtsa_complaints
WHERE UPPER(LTRIM(RTRIM(MAKETXT))) = 'FORD'
  AND UPPER(LTRIM(RTRIM(MODELTXT))) = 'ESCAPE'
  AND (
      COMPDESC LIKE '%ENGINE%'
      OR COMPDESC LIKE '%COOLING%'
      OR COMPDESC LIKE '%WATER PUMP%'
      OR COMPDESC LIKE '%RADIATOR%'
  )
GROUP BY COMPDESC
ORDER BY
    COUNT(DISTINCT CMPLID) DESC,
    component_category;


-- 6.4: Ford Escape model-year symptom screening

WITH escape_complaints AS (
    SELECT DISTINCT
        CMPLID,
        TRY_CONVERT(int, MODEL_YEAR) AS model_year,
        UPPER(COALESCE(CDESCR, '')) AS narrative
    FROM dbo.nhtsa_complaints
    WHERE UPPER(LTRIM(RTRIM(MAKETXT))) = 'FORD'
      AND UPPER(LTRIM(RTRIM(MODELTXT))) = 'ESCAPE'
      AND TRY_CONVERT(int, MODEL_YEAR) BETWEEN 2001 AND 2024
)
SELECT
    model_year,
    COUNT(DISTINCT CMPLID) AS total_complaints,
    COUNT(DISTINCT CASE
        WHEN narrative LIKE '%OVERHEAT%'
          OR narrative LIKE '%OVER HEAT%'
        THEN CMPLID END) AS overheating_mentions,
    COUNT(DISTINCT CASE
        WHEN narrative LIKE '%COOLANT%'
          OR narrative LIKE '%ANTIFREEZE%'
        THEN CMPLID END) AS coolant_mentions,
    COUNT(DISTINCT CASE
        WHEN narrative LIKE '%WATER PUMP%'
        THEN CMPLID END) AS water_pump_mentions,
    COUNT(DISTINCT CASE
        WHEN narrative LIKE '%ENGINE FAIL%'
          OR narrative LIKE '%ENGINE STALL%'
          OR narrative LIKE '%ENGINE SHUT%'
        THEN CMPLID END) AS engine_failure_mentions
FROM escape_complaints
GROUP BY model_year
ORDER BY model_year;
/*
Observation — Ford Escape model-year symptom screening
- Model years 2013–2018 show substantial complaint volumes and recurring overheating, coolant-related and engine-failure mentions, 
with particularly high coolant mentions in 2013 (462), 2014 (379), 2017 (1,032) and 2018 (692).
- The 2017 model year has the highest total complaint count in this output (1,933) and the most coolant mentions (1,032). 
This is a promising cohort for deeper investigation, but these are raw counts and keyword matches—not verified failures or model-year failure rates.
*/


-- 6.5: Inspect raw Ford Escape 2017 complaints

SELECT TOP (50)
    CMPLID,
    MODEL_YEAR,
    COMPDESC,
    CDESCR AS complaint_narrative
FROM dbo.nhtsa_complaints
WHERE UPPER(LTRIM(RTRIM(MAKETXT))) = 'FORD'
  AND UPPER(LTRIM(RTRIM(MODELTXT))) = 'ESCAPE'
  AND TRY_CONVERT(int, MODEL_YEAR) = 2017
  AND (
      UPPER(COALESCE(CDESCR, '')) LIKE '%COOLANT%'
      OR UPPER(COALESCE(CDESCR, '')) LIKE '%ANTIFREEZE%'
      OR UPPER(COALESCE(CDESCR, '')) LIKE '%OVERHEAT%'
      OR UPPER(COALESCE(CDESCR, '')) LIKE '%WATER PUMP%'
  )
ORDER BY CMPLID;

/*
Observation:
- Manual review of 2017 Ford Escape complaints reveals a recurring pattern of coolant intrusion into engine cylinders, 
coolant loss without an obvious external leak, misfires, overheating and reported engine or short-block replacement.
- The narratives provide a credible engineering hypothesis to investigate. They are owner-reported complaints, however, 
and may include duplicate reports across component categories; they do not independently establish root cause or 
population-level failure risk.
*/

/* =========================================================
   7. REPORTED SAFETY INDICATORS
   Exclude 99 from INJURED/DEATHS because it is an anomalous
   or unverified value in this dataset profile.
   These are complaint-record counts, not event-rate estimates.
   ========================================================= */
SELECT
    COUNT(DISTINCT CMPLID) AS total_complaints,
    COUNT(DISTINCT CASE WHEN UPPER(LTRIM(RTRIM(CRASH))) = 'Y'
                        THEN CMPLID END) AS crash_reports,
    COUNT(DISTINCT CASE WHEN UPPER(LTRIM(RTRIM(FIRE))) = 'Y'
                        THEN CMPLID END) AS fire_reports,
    COUNT(DISTINCT CASE WHEN TRY_CONVERT(int, INJURED) > 0
                              AND TRY_CONVERT(int, INJURED) <> 99
                        THEN CMPLID END) AS injury_reports_excluding_99,
    COUNT(DISTINCT CASE WHEN TRY_CONVERT(int, DEATHS) > 0
                              AND TRY_CONVERT(int, DEATHS) <> 99
                        THEN CMPLID END) AS death_reports_excluding_99
FROM dbo.nhtsa_complaints;
GO

/* =========================================================
   8. MODEL-YEAR × COMPONENT MATRIX
   Model year is different from complaint received year (LDATE).
   ========================================================= */
SELECT
    TRY_CONVERT(int, MODEL_YEAR) AS model_year,
    COMPDESC,
    COUNT(DISTINCT CMPLID) AS complaint_count
FROM dbo.nhtsa_complaints
WHERE TRY_CONVERT(int, MODEL_YEAR) BETWEEN 2020 AND 2025
GROUP BY TRY_CONVERT(int, MODEL_YEAR), COMPDESC
ORDER BY COMPDESC, model_year;
GO

/* =========================================================
   9. COMPONENT COMPLAINT SHARE BY MODEL YEAR
   For each component, selected model-year complaints divided
   by that component's complaints across all model years.
   ========================================================= */
DECLARE @SelectedModelYear int = 2022;

WITH component_year_counts AS (
    SELECT
        COMPDESC,
        TRY_CONVERT(int, MODEL_YEAR) AS model_year,
        COUNT(DISTINCT CMPLID) AS complaint_count
    FROM dbo.nhtsa_complaints
    WHERE TRY_CONVERT(int, MODEL_YEAR) IS NOT NULL
    GROUP BY COMPDESC, TRY_CONVERT(int, MODEL_YEAR)
),
component_totals AS (
    SELECT
        COMPDESC,
        SUM(complaint_count) AS all_model_year_complaints
    FROM component_year_counts
    GROUP BY COMPDESC
)
SELECT
    y.COMPDESC,
    y.model_year,
    y.complaint_count AS selected_year_complaints,
    t.all_model_year_complaints,
    CAST(100.0 * y.complaint_count /NULLIF(t.all_model_year_complaints, 0) AS decimal(6,2))
         AS component_complaint_share_pct
FROM component_year_counts AS y
INNER JOIN component_totals AS t
    ON t.COMPDESC = y.COMPDESC
WHERE y.model_year = @SelectedModelYear
ORDER BY component_complaint_share_pct DESC;
GO

/* =========================================================
   10. DATA COMPLETENESS CHECKS
   ========================================================= */
SELECT
    COUNT_BIG(*) AS total_rows,
    SUM(CASE WHEN MILES IS NULL THEN 1 ELSE 0 END) AS miles_null_rows,
    SUM(CASE WHEN TRY_CONVERT(float, MILES) = 0 THEN 1 ELSE 0 END) AS miles_zero_rows,
    SUM(CASE WHEN TRY_CONVERT(float, MILES) > 0 THEN 1 ELSE 0 END) AS miles_positive_rows,
    SUM(CASE WHEN FUEL_SYS IS NULL OR LTRIM(RTRIM(CONVERT(varchar(255), FUEL_SYS))) = ''
             THEN 1 ELSE 0 END) AS fuel_system_missing_rows,
    SUM(CASE WHEN TIRE_SIZE IS NULL OR LTRIM(RTRIM(CONVERT(varchar(255), TIRE_SIZE))) = ''
             THEN 1 ELSE 0 END) AS tire_size_missing_rows,
    SUM(CASE WHEN MANUF_DT IS NULL OR LTRIM(RTRIM(CONVERT(varchar(255), MANUF_DT))) = ''
             THEN 1 ELSE 0 END) AS manufacturer_date_missing_rows
FROM dbo.nhtsa_complaints;
GO

