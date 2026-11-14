-- INFOSYS FINANCIAL ANALYSIS — MYSQL 8.0 QUERY PACK
-- Tested in MySQL Server 8.0.46 against schema: infosys_valuation
-- The database is a validated analytical copy migrated from Infosys_Analysis.db.
-- SQLite remains the canonical notebook-generated database.
-- Amounts are INR crore unless stated otherwise. Historical basis: consolidated Ind AS FY2021-FY2026.
-- Open this file in MySQL Workbench. Run one highlighted query at a time.

USE infosys_valuation;

-- QUERY 1 — Revenue, PBT and PAT trend
-- Expected: 6 rows, FY2021-FY2026; revenue, PBT and PAT columns.
SELECT fiscal_year,
       MAX(CASE WHEN metric = 'Revenue' THEN value END) AS revenue_inr_cr,
       MAX(CASE WHEN metric = 'Profit before tax' THEN value END) AS pbt_inr_cr,
       MAX(CASE WHEN metric = 'Profit after tax' THEN value END) AS pat_inr_cr
FROM annual_financials
GROUP BY fiscal_year, fiscal_year_end
ORDER BY fiscal_year_end;

-- QUERY 2 — Revenue growth and profitability margins
-- Expected: 6 rows; FY2021 revenue_growth_pct is NULL because no prior year is present.
WITH annual AS (
    SELECT fiscal_year, fiscal_year_end,
           MAX(CASE WHEN metric = 'Revenue' THEN value END) AS revenue,
           MAX(CASE WHEN metric = 'Profit before tax' THEN value END) AS pbt,
           MAX(CASE WHEN metric = 'Profit after tax' THEN value END) AS pat
    FROM annual_financials
    GROUP BY fiscal_year, fiscal_year_end
)
SELECT fiscal_year, revenue, pbt, pat,
       ROUND(100.0 * (revenue / NULLIF(LAG(revenue) OVER (ORDER BY fiscal_year_end), 0) - 1), 2) AS revenue_growth_pct,
       ROUND(100.0 * pbt / NULLIF(revenue, 0), 2) AS pbt_margin_pct,
       ROUND(100.0 * pat / NULLIF(revenue, 0), 2) AS pat_margin_pct
FROM annual
ORDER BY fiscal_year_end;

-- QUERY 3 — Operating cash flow and CFO-less-capex proxy reconciliation
-- Expected: 6 annual rows. PASS means the two proxy calculations differ by <= INR 1 crore.
-- REVIEW requires inspection; NULL inputs are not evidence of zero. This is an analyst proxy, not reported FCF/FCFF.
SELECT fiscal_year,
       MAX(CASE WHEN metric = 'Cash flow from operating activities' THEN value END) AS cfo,
       MAX(CASE WHEN metric = 'Capital expenditure' THEN value END) AS capex,
       MAX(CASE WHEN metric = 'CFO less capex proxy' THEN value END) AS workbook_proxy,
       MAX(CASE WHEN metric = 'Cash flow from operating activities' THEN value END)
         - MAX(CASE WHEN metric = 'Capital expenditure' THEN value END) AS recalculated_proxy,
       CASE WHEN ABS(
         (MAX(CASE WHEN metric = 'Cash flow from operating activities' THEN value END)
          - MAX(CASE WHEN metric = 'Capital expenditure' THEN value END))
         - MAX(CASE WHEN metric = 'CFO less capex proxy' THEN value END)
       ) <= 1 THEN 'PASS' ELSE 'REVIEW' END AS arithmetic_status
FROM annual_financials
GROUP BY fiscal_year, fiscal_year_end
ORDER BY fiscal_year_end;

-- QUERY 4 — Liquidity and leverage indicators
-- Expected: 12 rows if both ratios are populated for all six years (2 ratios x 6 years).
SELECT fiscal_year, metric, value, unit
FROM annual_ratios
WHERE metric IN ('Current ratio', 'Total liabilities / equity')
ORDER BY metric, fiscal_year_end;

-- QUERY 5 — Cash conversion indicators
-- Expected: rows for available annual CFO margin and CFO-less-capex proxy margin values.
SELECT fiscal_year, metric, ROUND(value, 4) AS ratio_value, unit
FROM annual_ratios
WHERE metric IN ('CFO margin', 'CFO less capex proxy margin')
ORDER BY fiscal_year_end, metric;

-- QUERY 6 — Missing historical values (MySQL GROUP_CONCAT syntax)
-- Expected: only metrics with at least one NULL year; zero rows means no missing values in these groups.
SELECT statement, metric, unit,
       SUM(CASE WHEN value IS NULL THEN 1 ELSE 0 END) AS missing_year_count,
       GROUP_CONCAT(CASE WHEN value IS NULL THEN fiscal_year END SEPARATOR ', ') AS missing_years
FROM annual_financials
GROUP BY statement, metric, unit
HAVING missing_year_count > 0
ORDER BY statement, metric;

-- QUERY 7 — Quality checks requiring review
-- Expected: only rows where status is not PASS; zero rows means no non-PASS checks.
SELECT check_name, fiscal_year, status, detail
FROM quality_checks
WHERE status <> 'PASS'
ORDER BY fiscal_year, check_name;

-- QUERY 8 — Source register
-- Expected: 24 rows, one per source-register record in the validated database.
SELECT source_id, publisher, document, coverage, status, url
FROM source_register
ORDER BY source_id;

-- FINAL VERIFICATION — Table row counts
-- Expected: 5 rows; 198 + 84 + 6 + 31 + 24 = 343 total records.
SELECT 'annual_financials' AS table_name, COUNT(*) AS row_count FROM annual_financials
UNION ALL
SELECT 'annual_ratios', COUNT(*) FROM annual_ratios
UNION ALL
SELECT 'annual_trend', COUNT(*) FROM annual_trend
UNION ALL
SELECT 'quality_checks', COUNT(*) FROM quality_checks
UNION ALL
SELECT 'source_register', COUNT(*) FROM source_register;
