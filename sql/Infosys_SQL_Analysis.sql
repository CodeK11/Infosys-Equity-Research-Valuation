-- INFOSYS FINANCIAL ANALYSIS — SQLITE QUERY PACK
-- Run the Python notebook first. It creates Infosys_Analysis.db and these tables:
-- annual_financials, annual_ratios, annual_trend, quality_checks, source_register.
-- Open the database in DB Browser for SQLite and run these queries.
-- Historical basis: consolidated Ind AS FY2021-FY2026. Amounts INR crore except ratios/EPS.

-- 1. Revenue, PBT and PAT trend
SELECT fiscal_year,
       MAX(CASE WHEN metric = 'Revenue' THEN value END) AS revenue_inr_cr,
       MAX(CASE WHEN metric = 'Profit before tax' THEN value END) AS pbt_inr_cr,
       MAX(CASE WHEN metric = 'Profit after tax' THEN value END) AS pat_inr_cr
FROM annual_financials
GROUP BY fiscal_year, fiscal_year_end
ORDER BY fiscal_year_end;

-- 2. Revenue growth and profitability margins
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

-- 3. Operating cash flow and CFO-less-capex proxy reconciliation
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

-- 4. Liquidity and leverage indicators from the pre-calculated ratio schedule
SELECT fiscal_year, metric, value, unit
FROM annual_ratios
WHERE metric IN ('Current ratio', 'Total liabilities / equity')
ORDER BY metric, fiscal_year_end;

-- 5. Cash conversion indicators
SELECT fiscal_year, metric, ROUND(value, 4) AS ratio_value, unit
FROM annual_ratios
WHERE metric IN ('CFO margin', 'CFO less capex proxy margin')
ORDER BY fiscal_year_end, metric;

-- 6. Missing historical values (NULL is not treated as zero)
SELECT statement, metric, unit,
       SUM(CASE WHEN value IS NULL THEN 1 ELSE 0 END) AS missing_year_count,
       GROUP_CONCAT(CASE WHEN value IS NULL THEN fiscal_year END, ', ') AS missing_years
FROM annual_financials
GROUP BY statement, metric, unit
HAVING missing_year_count > 0
ORDER BY statement, metric;

-- 7. Review checks only
SELECT check_name, fiscal_year, status, detail
FROM quality_checks
WHERE status <> 'PASS'
ORDER BY fiscal_year, check_name;

-- 8. Source register
SELECT source_id, publisher, document, coverage, status, url
FROM source_register
ORDER BY source_id;
