-- =====================================================================
-- 02_star_schema.sql                   (dialect: SQLite 3.35+)
-- Builds a star schema for Power BI from stg_retail (kept rows only):
--   fact_sales  <- dim_date, dim_product, dim_customer, dim_country
-- fact_sales holds BOTH sales and returns (signed values) so that
--   Net revenue = SUM(revenue) and Gross = SUM(revenue WHERE type='Sale').
-- =====================================================================

-- ---------- dim_date --------------------------------------------------
DROP TABLE IF EXISTS dim_date;
CREATE TABLE dim_date AS
WITH RECURSIVE cal(dt) AS (
    SELECT DATE('2010-12-01')
    UNION ALL
    SELECT DATE(dt, '+1 day') FROM cal WHERE dt < DATE('2011-12-31')
)
SELECT
    CAST(STRFTIME('%Y%m%d', dt) AS INTEGER)                      AS date_key,
    dt                                                           AS date,
    CAST(STRFTIME('%Y', dt) AS INTEGER)                          AS year,
    CAST(STRFTIME('%m', dt) AS INTEGER)                          AS month_number,
    CASE STRFTIME('%m', dt)
        WHEN '01' THEN 'Jan' WHEN '02' THEN 'Feb' WHEN '03' THEN 'Mar' WHEN '04' THEN 'Apr'
        WHEN '05' THEN 'May' WHEN '06' THEN 'Jun' WHEN '07' THEN 'Jul' WHEN '08' THEN 'Aug'
        WHEN '09' THEN 'Sep' WHEN '10' THEN 'Oct' WHEN '11' THEN 'Nov' ELSE 'Dec' END AS month_name,
    STRFTIME('%Y-%m', dt)                                        AS year_month,
    'Q' || ((CAST(STRFTIME('%m', dt) AS INTEGER) + 2) / 3)       AS quarter,
    CAST(STRFTIME('%Y', dt) AS INTEGER) * 10
        + ((CAST(STRFTIME('%m', dt) AS INTEGER) + 2) / 3)        AS year_quarter_sort,
    CAST(STRFTIME('%W', dt) AS INTEGER)                          AS week_of_year,
    CAST(STRFTIME('%w', dt) AS INTEGER)                          AS day_of_week_number,   -- 0 = Sunday
    CASE STRFTIME('%w', dt)
        WHEN '0' THEN 'Sun' WHEN '1' THEN 'Mon' WHEN '2' THEN 'Tue' WHEN '3' THEN 'Wed'
        WHEN '4' THEN 'Thu' WHEN '5' THEN 'Fri' ELSE 'Sat' END   AS day_name,
    CASE WHEN STRFTIME('%w', dt) IN ('0', '6') THEN 1 ELSE 0 END AS is_weekend,
    -- source data ends on 2011-12-09, so Dec 2011 is a partial month
    CASE WHEN STRFTIME('%Y-%m', dt) = '2011-12' THEN 0 ELSE 1 END AS is_complete_month
FROM cal;

-- ---------- dim_country -----------------------------------------------
DROP TABLE IF EXISTS dim_country;
CREATE TABLE dim_country AS
SELECT DISTINCT
    country,
    CASE
        WHEN country = 'United Kingdom' THEN 'United Kingdom'
        WHEN country IN ('Germany','France','EIRE','Spain','Netherlands','Belgium','Switzerland','Portugal',
                         'Norway','Italy','Channel Islands','Finland','Cyprus','Sweden','Austria','Denmark',
                         'Poland','Iceland','Greece','Malta','Lithuania','Czech Republic','European Community')
                                                                  THEN 'Europe (ex-UK)'
        WHEN country IN ('Israel','United Arab Emirates','Lebanon','Bahrain','Saudi Arabia') THEN 'Middle East'
        WHEN country IN ('Australia','Japan','Hong Kong','Singapore')                       THEN 'Asia-Pacific'
        WHEN country IN ('USA','Canada','Brazil','RSA')                                     THEN 'Americas & Africa'
        ELSE 'Unspecified'
    END AS region
FROM stg_retail WHERE exclusion_reason IS NULL;

-- ---------- product group rules (reference table) ---------------------
-- The source has no category field, so product_group is a transparent keyword
-- heuristic. A rule matches when the keyword starts a word in the description
-- (leading space enforced; add a trailing space for whole-word matches).
-- The lowest priority number that matches wins.
DROP TABLE IF EXISTS ref_product_group_rules;
CREATE TABLE ref_product_group_rules (priority INTEGER, product_group TEXT, keyword TEXT);
INSERT INTO ref_product_group_rules VALUES
 (1,'Christmas & Seasonal','CHRISTMAS'),(1,'Christmas & Seasonal','XMAS'),(1,'Christmas & Seasonal','SANTA'),
 (1,'Christmas & Seasonal','ADVENT'),(1,'Christmas & Seasonal','REINDEER'),(1,'Christmas & Seasonal','SNOW'),
 (1,'Christmas & Seasonal','STOCKING'),
 (2,'Bags & Accessories','BAG'),(2,'Bags & Accessories','SHOPPER'),(2,'Bags & Accessories','PURSE'),
 (2,'Bags & Accessories','UMBRELLA'),(2,'Bags & Accessories','WALLET'),
 (3,'Lighting & Candles','LIGHT'),(3,'Lighting & Candles','T-LIGHT'),(3,'Lighting & Candles','LAMP'),
 (3,'Lighting & Candles','CANDLE'),(3,'Lighting & Candles','LANTERN'),(3,'Lighting & Candles','LED '),
 (4,'Kitchen & Dining','CAKE'),(4,'Kitchen & Dining','TEA '),(4,'Kitchen & Dining','TEAPOT'),
 (4,'Kitchen & Dining','TEACUP'),(4,'Kitchen & Dining','TEASPOON'),(4,'Kitchen & Dining','MUG'),
 (4,'Kitchen & Dining','CUP'),(4,'Kitchen & Dining','JAR'),(4,'Kitchen & Dining','TIN '),
 (4,'Kitchen & Dining','TINS '),(4,'Kitchen & Dining','JAM'),(4,'Kitchen & Dining','BAKING'),
 (4,'Kitchen & Dining','LUNCH'),(4,'Kitchen & Dining','SNACK'),(4,'Kitchen & Dining','PANTRY'),
 (4,'Kitchen & Dining','SPICE'),(4,'Kitchen & Dining','PLATE'),(4,'Kitchen & Dining','BOWL'),
 (4,'Kitchen & Dining','PICNIC'),(4,'Kitchen & Dining','KITCHEN'),(4,'Kitchen & Dining','COOK'),
 (4,'Kitchen & Dining','CUTLERY'),(4,'Kitchen & Dining','APRON'),(4,'Kitchen & Dining','NAPKIN'),
 (4,'Kitchen & Dining','TRAY'),(4,'Kitchen & Dining','COFFEE'),(4,'Kitchen & Dining','SUGAR'),
 (4,'Kitchen & Dining','WINE GLASS'),(4,'Kitchen & Dining','TUMBLER'),(4,'Kitchen & Dining','EGG '),
 (5,'Party & Gifting','BUNTING'),(5,'Party & Gifting','PARTY'),(5,'Party & Gifting','BALLOON'),
 (5,'Party & Gifting','WRAP'),(5,'Party & Gifting','RIBBON'),(5,'Party & Gifting','CARDS'),
 (5,'Party & Gifting','GREETING'),(5,'Party & Gifting','PAPER CHAIN'),(5,'Party & Gifting','GARLAND'),
 (5,'Party & Gifting','GIFT'),(5,'Party & Gifting','BIRTHDAY'),(5,'Party & Gifting','THANK YOU'),
 (6,'Stationery & Crafts','PEN '),(6,'Stationery & Crafts','PENS '),(6,'Stationery & Crafts','PENCIL'),
 (6,'Stationery & Crafts','NOTEBOOK'),(6,'Stationery & Crafts','STICKER'),(6,'Stationery & Crafts','CRAFT'),
 (6,'Stationery & Crafts','PAPER'),(6,'Stationery & Crafts','ERASER'),(6,'Stationery & Crafts','RULER'),
 (6,'Stationery & Crafts','STAMP'),(6,'Stationery & Crafts','NOTE '),(6,'Stationery & Crafts','JOURNAL'),
 (6,'Stationery & Crafts','DIARY'),(6,'Stationery & Crafts','BOOK'),
 (7,'Toys & Games','TOY'),(7,'Toys & Games','GAME'),(7,'Toys & Games','PUZZLE'),(7,'Toys & Games','DOLL'),
 (7,'Toys & Games','PLAY'),(7,'Toys & Games','HARMONICA'),(7,'Toys & Games','SPACEBOY'),
 (7,'Toys & Games','CHILDREN'),(7,'Toys & Games','KIDS'),(7,'Toys & Games','CHILD'),
 (7,'Toys & Games','SKIPPING'),(7,'Toys & Games','TEDDY'),
 (8,'Jewellery','NECKLACE'),(8,'Jewellery','BRACELET'),(8,'Jewellery','EARRING'),(8,'Jewellery','JEWEL'),
 (8,'Jewellery','RING '),(8,'Jewellery','PENDANT'),
 (9,'Home Decor','FRAME'),(9,'Home Decor','SIGN'),(9,'Home Decor','CLOCK'),(9,'Home Decor','DOORMAT'),
 (9,'Home Decor','CUSHION'),(9,'Home Decor','HEART'),(9,'Home Decor','MIRROR'),(9,'Home Decor','VASE'),
 (9,'Home Decor','WICKER'),(9,'Home Decor','BIRD'),(9,'Home Decor','ORNAMENT'),(9,'Home Decor','DECORATION'),
 (9,'Home Decor','HANGING'),(9,'Home Decor','BLACKBOARD'),(9,'Home Decor','CHALKBOARD'),
 (0,'Home Decor','HOT WATER'),(9,'Home Decor','BOX'),(9,'Home Decor','BASKET'),(9,'Home Decor','HOLDER'),
 (9,'Home Decor','CANDELABRA'),(9,'Home Decor','SHELF'),(9,'Home Decor','HOOK'),(9,'Home Decor','DOOR'),
 (9,'Home Decor','CURTAIN'),(9,'Home Decor','TOWEL'),(9,'Home Decor','SOAP'),(9,'Home Decor','WALL'),
 (9,'Home Decor','MEMOBOARD'),(9,'Home Decor','STORAGE'),(9,'Home Decor','CABINET'),(9,'Home Decor','DRAWER'),
 (9,'Home Decor','KNOB'),(9,'Home Decor','FLOWER'),(9,'Home Decor','FLORAL'),(9,'Home Decor','GARDEN'),
 (9,'Home Decor','PLANT'),(9,'Home Decor','PARASOL'),(9,'Home Decor','BUTTERFLY');

-- ---------- dim_product -----------------------------------------------
DROP TABLE IF EXISTS dim_product;
CREATE TABLE dim_product AS
WITH desc_rank AS (   -- a stock code can carry several descriptions: keep the most frequent
    SELECT stock_code, description,
           ROW_NUMBER() OVER (PARTITION BY stock_code ORDER BY COUNT(*) DESC, description) AS rn
    FROM stg_retail
    WHERE exclusion_reason IS NULL AND description <> ''
    GROUP BY stock_code, description
),
prod AS (
    SELECT s.stock_code,
           COALESCE(d.description, 'UNKNOWN') AS description,
           MIN(CASE WHEN s.invoice_type = 'Sale' THEN DATE(s.invoice_datetime) END) AS first_sold_date,
           ROUND(AVG(CASE WHEN s.invoice_type = 'Sale' THEN s.unit_price END), 2)   AS avg_unit_price
    FROM stg_retail s
    LEFT JOIN desc_rank d ON d.stock_code = s.stock_code AND d.rn = 1
    WHERE s.exclusion_reason IS NULL
    GROUP BY s.stock_code, d.description
)
SELECT
    p.stock_code AS product_key,
    p.description,
    COALESCE((SELECT r.product_group
              FROM ref_product_group_rules r
              WHERE (' ' || p.description || ' ') LIKE '% ' || r.keyword || '%'
              ORDER BY r.priority, LENGTH(r.keyword) DESC
              LIMIT 1), 'Other')                                       AS product_group,
    p.first_sold_date,
    p.avg_unit_price
FROM prod p;

-- ---------- dim_customer ----------------------------------------------
-- customer_key 0 = guest checkout (CustomerID missing in the source)
DROP TABLE IF EXISTS dim_customer;
CREATE TABLE dim_customer AS
WITH k AS (
    SELECT COALESCE(customer_id, 0) AS customer_key, invoice_no, invoice_type, country,
           invoice_datetime, line_value
    FROM stg_retail WHERE exclusion_reason IS NULL
),
last_country AS (   -- country of the customer's most recent invoice
    SELECT customer_key, country,
           ROW_NUMBER() OVER (PARTITION BY customer_key ORDER BY invoice_datetime DESC) AS rn
    FROM k
),
agg AS (
    SELECT customer_key,
           MIN(CASE WHEN invoice_type = 'Sale' THEN DATE(invoice_datetime) END)  AS first_order_date,
           MAX(CASE WHEN invoice_type = 'Sale' THEN DATE(invoice_datetime) END)  AS last_order_date,
           COUNT(DISTINCT CASE WHEN invoice_type = 'Sale' THEN invoice_no END)   AS total_orders,
           ROUND(SUM(line_value), 2)                                             AS lifetime_net_revenue
    FROM k GROUP BY customer_key
)
SELECT a.customer_key,
       CASE WHEN a.customer_key = 0 THEN 'Guest (no customer ID)'
            ELSE 'Customer ' || a.customer_key END               AS customer_name,
       CASE WHEN a.customer_key = 0 THEN 'Guest' ELSE 'Registered' END AS customer_type,
       lc.country                                                AS primary_country,
       a.first_order_date,
       STRFTIME('%Y-%m', a.first_order_date)                     AS cohort_month,
       a.last_order_date,
       a.total_orders,
       a.lifetime_net_revenue
FROM agg a
JOIN last_country lc ON lc.customer_key = a.customer_key AND lc.rn = 1;

-- ---------- fact_sales ------------------------------------------------
DROP TABLE IF EXISTS fact_sales;
CREATE TABLE fact_sales AS
SELECT
    row_id                                         AS sales_key,
    invoice_no,
    DATE(invoice_datetime)                         AS invoice_date,
    invoice_datetime,
    CAST(STRFTIME('%Y%m%d', invoice_datetime) AS INTEGER) AS date_key,
    CAST(STRFTIME('%H', invoice_datetime) AS INTEGER)     AS invoice_hour,
    stock_code                                     AS product_key,
    COALESCE(customer_id, 0)                       AS customer_key,
    country,
    CASE invoice_type WHEN 'Cancellation' THEN 'Return' ELSE 'Sale' END AS transaction_type,
    quantity,
    unit_price,
    line_value                                     AS revenue          -- signed: returns are negative
FROM stg_retail
WHERE exclusion_reason IS NULL;

CREATE INDEX idx_fact_date     ON fact_sales(date_key);
CREATE INDEX idx_fact_product  ON fact_sales(product_key);
CREATE INDEX idx_fact_customer ON fact_sales(customer_key);
CREATE INDEX idx_fact_invoice  ON fact_sales(invoice_no);
