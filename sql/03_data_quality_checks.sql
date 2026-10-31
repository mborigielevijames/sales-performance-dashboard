-- =====================================================================
-- 03_data_quality_checks.sql   Every query should return check_passed = 1
-- =====================================================================
-- name: fact_has_rows
SELECT 'fact_sales has rows' AS check_name, CASE WHEN COUNT(*) > 0 THEN 1 ELSE 0 END AS check_passed FROM fact_sales;

-- name: no_null_keys
SELECT 'no NULL keys in fact_sales' AS check_name,
       CASE WHEN SUM(date_key IS NULL OR product_key IS NULL OR customer_key IS NULL OR country IS NULL) = 0 THEN 1 ELSE 0 END
FROM fact_sales;

-- name: orphan_dates
SELECT 'every fact date_key exists in dim_date', CASE WHEN COUNT(*) = 0 THEN 1 ELSE 0 END
FROM fact_sales f LEFT JOIN dim_date d ON d.date_key = f.date_key WHERE d.date_key IS NULL;

-- name: orphan_products
SELECT 'every fact product_key exists in dim_product', CASE WHEN COUNT(*) = 0 THEN 1 ELSE 0 END
FROM fact_sales f LEFT JOIN dim_product p ON p.product_key = f.product_key WHERE p.product_key IS NULL;

-- name: orphan_customers
SELECT 'every fact customer_key exists in dim_customer', CASE WHEN COUNT(*) = 0 THEN 1 ELSE 0 END
FROM fact_sales f LEFT JOIN dim_customer c ON c.customer_key = f.customer_key WHERE c.customer_key IS NULL;

-- name: orphan_countries
SELECT 'every fact country exists in dim_country', CASE WHEN COUNT(*) = 0 THEN 1 ELSE 0 END
FROM fact_sales f LEFT JOIN dim_country c ON c.country = f.country WHERE c.country IS NULL;

-- name: unique_dim_keys
SELECT 'dimension keys are unique',
       CASE WHEN (SELECT COUNT(*) - COUNT(DISTINCT product_key)  FROM dim_product)  = 0
             AND (SELECT COUNT(*) - COUNT(DISTINCT customer_key) FROM dim_customer) = 0
             AND (SELECT COUNT(*) - COUNT(DISTINCT country)      FROM dim_country)  = 0
             AND (SELECT COUNT(*) - COUNT(DISTINCT date_key)     FROM dim_date)     = 0 THEN 1 ELSE 0 END;

-- name: sign_rules
SELECT 'sales have qty>0 & revenue>0; returns qty<0 & revenue<0',
       CASE WHEN SUM(CASE WHEN transaction_type = 'Sale'   AND (quantity <= 0 OR revenue <= 0) THEN 1 ELSE 0 END) = 0
             AND SUM(CASE WHEN transaction_type = 'Return' AND (quantity >= 0 OR revenue >= 0) THEN 1 ELSE 0 END) = 0 THEN 1 ELSE 0 END
FROM fact_sales;

-- name: revenue_reconciles
SELECT 'fact revenue equals kept staging value',
       CASE WHEN ABS((SELECT SUM(revenue) FROM fact_sales) - (SELECT SUM(line_value) FROM stg_retail WHERE exclusion_reason IS NULL)) < 0.5 THEN 1 ELSE 0 END;

-- name: row_reconciliation
SELECT 'raw rows = duplicates + excluded + kept',
       CASE WHEN (SELECT row_count FROM data_quality_log WHERE step = '0 raw')
               = (SELECT row_count FROM data_quality_log WHERE step = '0 raw') - (SELECT row_count FROM data_quality_log WHERE step = '1 dedup')
               + (SELECT SUM(row_count) FROM data_quality_log WHERE step LIKE 'x %')
               + (SELECT row_count FROM data_quality_log WHERE step = '9 kept') THEN 1 ELSE 0 END;

-- name: date_range
SELECT 'dates within dim_date range (Dec-2010 .. Dec-2011)',
       CASE WHEN MIN(invoice_date) >= '2010-12-01' AND MAX(invoice_date) <= '2011-12-31' THEN 1 ELSE 0 END FROM fact_sales;
