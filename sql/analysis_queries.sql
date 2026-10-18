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

/* =========================================================
   6. REPORTED SAFETY INDICATORS
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
   7. MODEL-YEAR × COMPONENT MATRIX
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
   8. COMPONENT COMPLAINT SHARE BY MODEL YEAR
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
   9. DATA COMPLETENESS CHECKS
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

/* =========================================================
   10. EXPLORATORY FORD ESCAPE ENGINE NARRATIVE CHECK
   ========================================================= */
SELECT
    COUNT(DISTINCT CMPLID) AS ford_escape_engine_complaints,
    COUNT(DISTINCT CASE
        WHEN LOWER(COALESCE(CDESCR, '')) LIKE '%coolant%'
          OR LOWER(COALESCE(CDESCR, '')) LIKE '%cooling fluid%'
          OR LOWER(COALESCE(CDESCR, '')) LIKE '%antifreeze%'
        THEN CMPLID END) AS complaints_mentioning_coolant_terms,
    CAST(
        100.0 * COUNT(DISTINCT CASE
            WHEN LOWER(COALESCE(CDESCR, '')) LIKE '%coolant%'
              OR LOWER(COALESCE(CDESCR, '')) LIKE '%cooling fluid%'
              OR LOWER(COALESCE(CDESCR, '')) LIKE '%antifreeze%'
            THEN CMPLID END)
        / NULLIF(COUNT(DISTINCT CMPLID), 0)
        AS decimal(6,2)
    ) AS coolant_term_share_pct
FROM dbo.nhtsa_complaints
WHERE LOWER(COALESCE(MAKETXT, '')) LIKE '%ford%'
  AND LOWER(COALESCE(MODELTXT, '')) LIKE '%escape%'
  AND LOWER(COALESCE(COMPDESC, '')) LIKE '%engine%';
GO

/* Same exploratory search for 2017–2019 Ford Escape engine complaints */
SELECT
    COUNT(DISTINCT CMPLID) AS ford_escape_engine_complaints_2017_2019,
    COUNT(DISTINCT CASE
        WHEN LOWER(COALESCE(CDESCR, '')) LIKE '%coolant%'
          OR LOWER(COALESCE(CDESCR, '')) LIKE '%cooling fluid%'
          OR LOWER(COALESCE(CDESCR, '')) LIKE '%antifreeze%'
        THEN CMPLID END) AS coolant_term_complaints,
    CAST(
        100.0 * COUNT(DISTINCT CASE
            WHEN LOWER(COALESCE(CDESCR, '')) LIKE '%coolant%'
              OR LOWER(COALESCE(CDESCR, '')) LIKE '%cooling fluid%'
              OR LOWER(COALESCE(CDESCR, '')) LIKE '%antifreeze%'
            THEN CMPLID END)
        / NULLIF(COUNT(DISTINCT CMPLID), 0)
        AS decimal(6,2)
    ) AS coolant_term_share_pct
FROM dbo.nhtsa_complaints
WHERE LOWER(COALESCE(MAKETXT, '')) LIKE '%ford%'
  AND LOWER(COALESCE(MODELTXT, '')) LIKE '%escape%'
  AND LOWER(COALESCE(COMPDESC, '')) LIKE '%engine%'
  AND TRY_CONVERT(int, MODEL_YEAR) BETWEEN 2017 AND 2019;
GO
