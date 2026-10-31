-- =====================================================================
-- 04_business_analysis.sql             (dialect: SQLite 3.35+, window functions)
-- Each query is exported to sql/results/<name>.csv by scripts/run_analysis.py
-- Conventions: "Gross" = Sale lines only, "Net" = Sales + Returns (returns are negative)
-- =====================================================================

-- name: q01_executive_kpis
SELECT
    ROUND(SUM(CASE WHEN transaction_type = 'Sale'   THEN revenue END), 0)             AS gross_revenue,
    ROUND(-SUM(CASE WHEN transaction_type = 'Return' THEN revenue END), 0)            AS returns_value,
    ROUND(SUM(revenue), 0)                                                            AS net_revenue,
    ROUND(100.0 * -SUM(CASE WHEN transaction_type = 'Return' THEN revenue END)
                 / SUM(CASE WHEN transaction_type = 'Sale' THEN revenue END), 2)      AS return_rate_pct,
    COUNT(DISTINCT CASE WHEN transaction_type = 'Sale' THEN invoice_no END)           AS orders,
    SUM(CASE WHEN transaction_type = 'Sale' THEN quantity END)                        AS units_sold,
    COUNT(DISTINCT CASE WHEN transaction_type = 'Sale' AND customer_key <> 0 THEN customer_key END) AS registered_customers,
    ROUND(SUM(CASE WHEN transaction_type = 'Sale' THEN revenue END)
          / COUNT(DISTINCT CASE WHEN transaction_type = 'Sale' THEN invoice_no END), 2) AS avg_order_value,
    ROUND(1.0 * SUM(CASE WHEN transaction_type = 'Sale' THEN quantity END)
          / COUNT(DISTINCT CASE WHEN transaction_type = 'Sale' THEN invoice_no END), 1) AS units_per_order
FROM fact_sales;

-- name: q02_monthly_trend
-- Monthly gross revenue, orders, AOV, month-over-month growth and cumulative net revenue
WITH m AS (
    SELECT d.year_month,
           d.is_complete_month,
           SUM(CASE WHEN f.transaction_type = 'Sale' THEN f.revenue END)                    AS gross_revenue,
           SUM(f.revenue)                                                                   AS net_revenue,
           COUNT(DISTINCT CASE WHEN f.transaction_type = 'Sale' THEN f.invoice_no END)      AS orders
    FROM fact_sales f JOIN dim_date d USING (date_key)
    GROUP BY d.year_month, d.is_complete_month
)
SELECT year_month,
       is_complete_month,
       ROUND(gross_revenue, 0)                                          AS gross_revenue,
       ROUND(net_revenue, 0)                                            AS net_revenue,
       orders,
       ROUND(gross_revenue / orders, 2)                                 AS avg_order_value,
       ROUND(100.0 * (net_revenue - LAG(net_revenue) OVER (ORDER BY year_month))
             / LAG(net_revenue) OVER (ORDER BY year_month), 1)          AS net_revenue_mom_pct,
       ROUND(SUM(net_revenue) OVER (ORDER BY year_month), 0)            AS cumulative_net_revenue
FROM m
ORDER BY year_month;

-- name: q03_quarterly_and_seasonality
SELECT d.year, d.quarter,
       ROUND(SUM(f.revenue), 0) AS net_revenue,
       COUNT(DISTINCT CASE WHEN f.transaction_type = 'Sale' THEN f.invoice_no END) AS orders
FROM fact_sales f JOIN dim_date d USING (date_key)
WHERE d.is_complete_month = 1
GROUP BY d.year, d.quarter
ORDER BY d.year, d.quarter;

-- name: q04_revenue_by_region_country
SELECT c.region, f.country,
       ROUND(SUM(f.revenue), 0)                                                    AS net_revenue,
       ROUND(100.0 * SUM(f.revenue) / SUM(SUM(f.revenue)) OVER (), 2)              AS pct_of_total,
       COUNT(DISTINCT CASE WHEN f.transaction_type = 'Sale' THEN f.invoice_no END) AS orders,
       ROUND(SUM(CASE WHEN f.transaction_type = 'Sale' THEN f.revenue END)
             / COUNT(DISTINCT CASE WHEN f.transaction_type = 'Sale' THEN f.invoice_no END), 2) AS avg_order_value,
       RANK() OVER (ORDER BY SUM(f.revenue) DESC)                                  AS revenue_rank
FROM fact_sales f JOIN dim_country c USING (country)
GROUP BY c.region, f.country
ORDER BY net_revenue DESC;

-- name: q05_top_products_net
-- Ranked on NET revenue (returns deducted)
SELECT RANK() OVER (ORDER BY SUM(f.revenue) DESC)                                  AS rank,
       p.product_key, p.description, p.product_group,
       SUM(CASE WHEN f.transaction_type = 'Sale' THEN f.quantity END)              AS units_sold,
       ROUND(SUM(f.revenue), 0)                                                    AS net_revenue,
       ROUND(100.0 * SUM(f.revenue) / SUM(SUM(f.revenue)) OVER (), 2)              AS pct_of_total
FROM fact_sales f JOIN dim_product p USING (product_key)
GROUP BY p.product_key, p.description, p.product_group
ORDER BY net_revenue DESC
LIMIT 20;

-- name: q06_pareto_products
-- What share of net revenue comes from the top 20% of products?
WITH prod AS (
    SELECT product_key, SUM(revenue) AS rev FROM fact_sales GROUP BY product_key HAVING SUM(revenue) > 0
),
ranked AS (
    SELECT product_key, rev,
           ROW_NUMBER() OVER (ORDER BY rev DESC)               AS rn,
           COUNT(*) OVER ()                                    AS n,
           SUM(rev) OVER (ORDER BY rev DESC)                   AS running_rev,
           SUM(rev) OVER ()                                    AS total_rev
    FROM prod
)
SELECT n AS products_with_positive_net_revenue,
       CAST(n * 0.2 AS INTEGER)                                AS top_20pct_products,
       ROUND(100.0 * MAX(CASE WHEN rn = CAST(n * 0.2 AS INTEGER) THEN running_rev END) / MAX(total_rev), 1) AS revenue_share_of_top_20pct,
       ROUND(100.0 * MAX(CASE WHEN rn = CAST(n * 0.1 AS INTEGER) THEN running_rev END) / MAX(total_rev), 1) AS revenue_share_of_top_10pct
FROM ranked;

-- name: q07_product_group_performance
SELECT p.product_group,
       COUNT(DISTINCT p.product_key)                                               AS products,
       SUM(CASE WHEN f.transaction_type = 'Sale' THEN f.quantity END)              AS units_sold,
       ROUND(SUM(f.revenue), 0)                                                    AS net_revenue,
       ROUND(100.0 * SUM(f.revenue) / SUM(SUM(f.revenue)) OVER (), 1)              AS pct_of_total,
       ROUND(-100.0 * SUM(CASE WHEN f.transaction_type = 'Return' THEN f.revenue END)
             / SUM(CASE WHEN f.transaction_type = 'Sale' THEN f.revenue END), 2)   AS return_rate_pct
FROM fact_sales f JOIN dim_product p USING (product_key)
GROUP BY p.product_group
ORDER BY net_revenue DESC;

-- name: q08_customer_concentration
-- Registered customers only; share of revenue from top 10 / top 20% of customers
WITH cust AS (
    SELECT customer_key, SUM(revenue) AS rev
    FROM fact_sales WHERE customer_key <> 0
    GROUP BY customer_key HAVING SUM(revenue) > 0
),
ranked AS (
    SELECT rev, ROW_NUMBER() OVER (ORDER BY rev DESC) AS rn, COUNT(*) OVER () AS n,
           SUM(rev) OVER (ORDER BY rev DESC) AS running, SUM(rev) OVER () AS total
    FROM cust
)
SELECT MAX(n)                                                                              AS customers_with_revenue,
       ROUND(100.0 * MAX(CASE WHEN rn = 10 THEN running END) / MAX(total), 1)              AS top10_customers_share_pct,
       ROUND(100.0 * MAX(CASE WHEN rn = CAST(n * 0.2 AS INTEGER) THEN running END) / MAX(total), 1) AS top20pct_customers_share_pct
FROM ranked;

-- name: q09_guest_vs_registered
SELECT c.customer_type,
       COUNT(DISTINCT CASE WHEN f.transaction_type = 'Sale' THEN f.invoice_no END) AS orders,
       ROUND(SUM(f.revenue), 0)                                                    AS net_revenue,
       ROUND(100.0 * SUM(f.revenue) / SUM(SUM(f.revenue)) OVER (), 1)              AS pct_of_total,
       ROUND(SUM(CASE WHEN f.transaction_type = 'Sale' THEN f.revenue END)
             / COUNT(DISTINCT CASE WHEN f.transaction_type = 'Sale' THEN f.invoice_no END), 2) AS avg_order_value
FROM fact_sales f JOIN dim_customer c USING (customer_key)
GROUP BY c.customer_type;

-- name: q10_new_vs_returning_customers_by_month
-- A customer is "new" in the month of their first purchase and "returning" afterwards
WITH monthly AS (
    SELECT DISTINCT d.year_month, f.customer_key, c.cohort_month
    FROM fact_sales f
    JOIN dim_date d USING (date_key)
    JOIN dim_customer c USING (customer_key)
    WHERE f.transaction_type = 'Sale' AND f.customer_key <> 0
)
SELECT year_month,
       COUNT(*)                                                         AS active_customers,
       SUM(CASE WHEN cohort_month = year_month THEN 1 ELSE 0 END)       AS new_customers,
       SUM(CASE WHEN cohort_month < year_month THEN 1 ELSE 0 END)       AS returning_customers,
       ROUND(100.0 * SUM(CASE WHEN cohort_month < year_month THEN 1 ELSE 0 END) / COUNT(*), 1) AS returning_pct
FROM monthly
GROUP BY year_month
ORDER BY year_month;

-- name: q11_largest_returns
-- Largest single return lines (after removing the two reversed bulk-order entry errors)
SELECT p.description, ABS(MIN(f.quantity)) AS largest_return_qty,
       ROUND(-MIN(f.revenue), 0)           AS returned_value,
       f.customer_key
FROM fact_sales f JOIN dim_product p USING (product_key)
WHERE f.transaction_type = 'Return'
GROUP BY f.invoice_no, p.description, f.customer_key
ORDER BY returned_value DESC
LIMIT 5;

-- name: q12_returns_by_month
SELECT d.year_month,
       ROUND(SUM(CASE WHEN f.transaction_type = 'Sale' THEN f.revenue END), 0)      AS gross_revenue,
       ROUND(-SUM(CASE WHEN f.transaction_type = 'Return' THEN f.revenue END), 0)   AS returns_value,
       ROUND(-100.0 * SUM(CASE WHEN f.transaction_type = 'Return' THEN f.revenue END)
             / SUM(CASE WHEN f.transaction_type = 'Sale' THEN f.revenue END), 2)    AS return_rate_pct
FROM fact_sales f JOIN dim_date d USING (date_key)
GROUP BY d.year_month ORDER BY d.year_month;

-- name: q13_day_of_week_and_hour
SELECT d.day_name,
       d.day_of_week_number,
       COUNT(DISTINCT CASE WHEN f.transaction_type = 'Sale' THEN f.invoice_no END) AS orders,
       ROUND(SUM(CASE WHEN f.transaction_type = 'Sale' THEN f.revenue END), 0)     AS gross_revenue
FROM fact_sales f JOIN dim_date d USING (date_key)
GROUP BY d.day_name, d.day_of_week_number
ORDER BY d.day_of_week_number;

-- name: q14_hourly_orders
SELECT invoice_hour,
       COUNT(DISTINCT CASE WHEN transaction_type = 'Sale' THEN invoice_no END) AS orders,
       ROUND(SUM(CASE WHEN transaction_type = 'Sale' THEN revenue END), 0)     AS gross_revenue
FROM fact_sales GROUP BY invoice_hour ORDER BY invoice_hour;

-- name: q15_order_size_distribution
WITH orders AS (
    SELECT invoice_no, SUM(revenue) AS order_value, SUM(quantity) AS units
    FROM fact_sales WHERE transaction_type = 'Sale' GROUP BY invoice_no
)
SELECT CASE WHEN order_value < 50   THEN '1. under 50'
            WHEN order_value < 150  THEN '2. 50 - 149'
            WHEN order_value < 300  THEN '3. 150 - 299'
            WHEN order_value < 600  THEN '4. 300 - 599'
            WHEN order_value < 1500 THEN '5. 600 - 1,499'
            ELSE '6. 1,500 +' END                                                AS order_value_band,
       COUNT(*)                                                                  AS orders,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)                        AS pct_of_orders,
       ROUND(SUM(order_value), 0)                                                AS revenue,
       ROUND(100.0 * SUM(order_value) / SUM(SUM(order_value)) OVER (), 1)        AS pct_of_revenue
FROM orders GROUP BY 1 ORDER BY 1;

-- name: q16_product_group_by_quarter
SELECT d.year_quarter_sort, d.year || ' ' || d.quarter AS quarter, p.product_group,
       ROUND(SUM(f.revenue), 0) AS net_revenue
FROM fact_sales f JOIN dim_date d USING (date_key) JOIN dim_product p USING (product_key)
WHERE d.is_complete_month = 1
GROUP BY 1, 2, 3 ORDER BY 1, net_revenue DESC;
