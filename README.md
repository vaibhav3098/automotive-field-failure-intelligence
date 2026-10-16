# Automotive Field Failure Intelligence

**Analyzing automotive complaint patterns using SQL, Python, and Power BI**

## Project Overview

This project explores vehicle complaints reported to the U.S. National Highway Traffic Safety Administration (NHTSA) between 2020 and 2024.

The objective was to understand which automotive components appear most frequently in complaints, how complaint patterns vary across vehicle model years, and what the reported safety indicators reveal. The analysis combines SQL-based investigation, Python text exploration, and an interactive Power BI report.

## Business Objectives

- Identify the components most frequently mentioned in complaints.
- Analyze complaint trends over time and across vehicle model years.
- Examine reported crash, fire, injury, and death indicators.
- Explore complaint narratives to identify recurring keywords and potential patterns.
- Present the findings in a clear, interactive dashboard.

## Tools Used

- **SQL Server:** Data profiling, aggregation, trend analysis, and targeted investigations.
- **Python:** Exploratory analysis of complaint narratives and keyword patterns.
- **Power BI:** Interactive dashboards for complaint trends, component analysis, and model-year comparisons.

## Dataset

- **Source:** NHTSA vehicle complaint records.
- **Period:** 2020–2024, based on complaint received date.
- **Records analyzed:** 418,884.
- **Unique identifier:** `CMPLID`, verified during initial data profiling.

The analysis distinguishes between the complaint received year and the vehicle model year, as they answer different business questions.

## Dashboard

### 1. Executive Overview
Provides a high-level view of total complaints, reported safety indicators, complaint trends over time, and the most frequently reported components.

### 2. Component & Vehicle Investigation
Explores complaint distribution across components and vehicle model years, helping identify areas that may warrant further investigation.

## Key Findings

- The dataset contains **418,884 complaint records** in the profiled extract.
- Annual complaint counts declined in 2021 and increased from 2022 through 2024.
- Engine complaints were the largest among the component groups examined.
- Mileage was missing in approximately 64% of records, limiting mileage-based analysis.
- An exploratory review of Ford Escape engine complaint narratives for model years 2017–2019 found coolant-related keywords in approximately 71% of the selected records.

These findings describe patterns in reported complaints; they do not establish the actual failure rate or root cause.

## Approach

1. Profiled the dataset and reviewed record uniqueness, date coverage, and data completeness.
2. Used SQL to analyze complaint trends, component distribution, model-year patterns, and reported safety indicators.
3. Used Python to explore complaint narratives and investigate selected component/model combinations.
4. Built a two-page Power BI report to communicate the results through interactive visualizations.

## Limitations

- NHTSA complaints are reports and are not necessarily independently verified failures.
- Complaint counts are not failure rates because the dataset does not provide a reliable vehicle-population denominator.
- Missing and anomalous values can limit some comparisons.
- Narrative keyword matches are exploratory and do not confirm a common root cause.
- Model years have different exposure periods, which should be considered when comparing complaint counts.

## Repository Structure

```text
automotive-field-failure-intelligence/
├── README.md
├── powerbi/
├── python/
├── sql/
└── screenshots/
```

The folders contain the Power BI report, Python analysis, SQL queries, and dashboard screenshots, respectively.

## Conclusion

This project applies data analysis to an automotive problem area, connecting my mechanical engineering and R&D background with SQL, Python, and Power BI. The focus is on identifying useful patterns, checking data quality, and presenting findings with appropriate limitations.

**Author:** Vaibhav Sharma
