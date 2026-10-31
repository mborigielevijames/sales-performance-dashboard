-- =====================================================================
-- 01_staging_and_cleaning.sql          (dialect: SQLite 3.35+)
-- Input : raw_online_retail  (loaded as-is from the UCI Online Retail CSV)
-- Output: stg_retail         (de-duplicated, typed, classified rows)
--         data_quality_log   (row counts + value at every cleaning step)
-- =====================================================================

DROP TABLE IF EXISTS stg_retail;

CREATE TABLE stg_retail AS
WITH deduped AS (
    -- Rule 1: drop exact duplicate rows (all 8 columns identical).
    SELECT DISTINCT
           InvoiceNo,
           StockCode,
           TRIM(Description)                                    AS description,
           Quantity,
           InvoiceDate,
           UnitPrice,
           NULLIF(TRIM(CustomerID), '')                         AS customer_raw,
           TRIM(Country)                                        AS country
    FROM raw_online_retail
)
SELECT
    ROW_NUMBER() OVER (ORDER BY InvoiceDate, InvoiceNo, StockCode) AS row_id,
    InvoiceNo                                                   AS invoice_no,
    UPPER(TRIM(StockCode))                                      AS stock_code,
    description,
    Quantity                                                    AS quantity,
    InvoiceDate                                                 AS line_datetime,
    -- one invoice can straddle a minute boundary; use its first timestamp
    MIN(InvoiceDate) OVER (PARTITION BY InvoiceNo)              AS invoice_datetime,
    UnitPrice                                                   AS unit_price,
    CAST(CAST(customer_raw AS REAL) AS INTEGER)                 AS customer_id,   -- '17850.0' -> 17850
    country,
    ROUND(Quantity * UnitPrice, 2)                              AS line_value,
    CASE WHEN InvoiceNo LIKE 'C%' THEN 'Cancellation'
         WHEN InvoiceNo LIKE 'A%' THEN 'Adjustment'
         ELSE 'Sale' END                                        AS invoice_type,
    -- real products have a 5-digit stock code (optionally + letter suffix);
    -- POST, DOT, M, D, S, B, BANK CHARGES, AMAZONFEE, CRUK, gift vouchers etc. are not products
    CASE WHEN UPPER(StockCode) GLOB '[0-9][0-9][0-9][0-9][0-9]*' THEN 1 ELSE 0 END AS is_product_code
FROM deduped;

CREATE INDEX idx_stg_invoice ON stg_retail(invoice_no);

-- Rule 2: classify every row as KEEP (NULL reason) or EXCLUDE (with a reason).
ALTER TABLE stg_retail ADD COLUMN exclusion_reason TEXT;

UPDATE stg_retail SET exclusion_reason =
    CASE
        WHEN invoice_type = 'Adjustment'                       THEN '1 Bad-debt accounting adjustment'
        WHEN is_product_code = 0                               THEN '2 Non-product code (postage, fees, manual, vouchers)'
        WHEN unit_price <= 0                                   THEN '3 Zero/negative unit price'
        WHEN invoice_type = 'Sale'         AND quantity <= 0   THEN '4 Negative quantity without cancellation invoice'
        WHEN invoice_type = 'Cancellation' AND quantity >= 0   THEN '5 Cancellation with non-negative quantity'
        ELSE NULL
    END;

-- Rule 3 (reason code 6): bulk orders (>= 10,000 units on one line) that the same customer fully
-- cancelled within 24h. Two such pairs exist (74,215 jars and 80,995 paper-craft
-- units, reversed 16 and 12 minutes later). They are almost certainly entry errors;
-- left in, they inflate both gross revenue and the return rate (Jan-11 and Dec-11).
UPDATE stg_retail SET exclusion_reason = '6 Fully reversed bulk order (entry error)'
WHERE exclusion_reason IS NULL
  AND row_id IN (
        SELECT s.row_id
        FROM stg_retail s
        JOIN stg_retail c
          ON c.customer_id = s.customer_id AND c.stock_code = s.stock_code
         AND c.quantity = -s.quantity
         AND s.invoice_type = 'Sale' AND c.invoice_type = 'Cancellation'
         AND JULIANDAY(c.invoice_datetime) - JULIANDAY(s.invoice_datetime) BETWEEN 0 AND 1
        WHERE s.quantity >= 10000 AND s.exclusion_reason IS NULL AND c.exclusion_reason IS NULL
        UNION
        SELECT c.row_id
        FROM stg_retail s
        JOIN stg_retail c
          ON c.customer_id = s.customer_id AND c.stock_code = s.stock_code
         AND c.quantity = -s.quantity
         AND s.invoice_type = 'Sale' AND c.invoice_type = 'Cancellation'
         AND JULIANDAY(c.invoice_datetime) - JULIANDAY(s.invoice_datetime) BETWEEN 0 AND 1
        WHERE s.quantity >= 10000 AND s.exclusion_reason IS NULL AND c.exclusion_reason IS NULL
  );

-- Audit trail ---------------------------------------------------------
DROP TABLE IF EXISTS data_quality_log;
CREATE TABLE data_quality_log (step TEXT, description TEXT, row_count INTEGER, value REAL);

INSERT INTO data_quality_log
SELECT '0 raw', 'Rows loaded from source file', COUNT(*), ROUND(SUM(Quantity * UnitPrice), 2)
FROM raw_online_retail;

INSERT INTO data_quality_log
SELECT '1 dedup', 'Rows after removing exact duplicates', COUNT(*), ROUND(SUM(line_value), 2)
FROM stg_retail;

INSERT INTO data_quality_log
SELECT 'x ' || exclusion_reason, 'Excluded: ' || SUBSTR(exclusion_reason, 3), COUNT(*), ROUND(SUM(line_value), 2)
FROM stg_retail WHERE exclusion_reason IS NOT NULL GROUP BY exclusion_reason;

INSERT INTO data_quality_log
SELECT '9 kept', 'Rows kept for the fact table (sales + returns)', COUNT(*), ROUND(SUM(line_value), 2)
FROM stg_retail WHERE exclusion_reason IS NULL;
