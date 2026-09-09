-- =========================================================
-- DATA VALIDATION
-- Retail Sales & Inventory Performance Analysis
-- =========================================================
-- Purpose:
-- Validate source data structure, completeness, integrity,
-- value ranges, business rules, and inventory coverage
-- before preparing the analytical layer.
-- =========================================================
-- 1. ROW COUNTS
-- =========================================================

SELECT 'sales' AS table_name, COUNT(*) AS row_count
FROM sales
UNION ALL
SELECT 'products', COUNT(*)
FROM products
UNION ALL
SELECT 'stores', COUNT(*)
FROM stores
UNION ALL
SELECT 'inventory', COUNT(*)
FROM inventory
UNION ALL
SELECT 'calendar', COUNT(*)
FROM calendar;

-- =========================================================
-- 2. KEY UNIQUENESS AND GRANULARITY
-- =========================================================

-- Sales: expected key = sale_id
SELECT
    COUNT(*) AS row_count,
    COUNT(DISTINCT sale_id) AS unique_sale_ids
FROM sales;

-- Products: expected key = product_id
SELECT
    COUNT(*) AS row_count,
    COUNT(DISTINCT product_id) AS unique_product_ids
FROM products;

-- Stores: expected key = store_id
SELECT
    COUNT(*) AS row_count,
    COUNT(DISTINCT store_id) AS unique_store_ids
FROM stores;

-- Inventory: expected key = store_id + product_id
SELECT
    COUNT(*) AS row_count,
    COUNT(DISTINCT (store_id, product_id)) AS unique_store_product_pairs
FROM inventory;


-- Calendar: expected key = date
SELECT
    COUNT(*) AS row_count,
    COUNT(DISTINCT date) AS unique_dates
FROM calendar;


-- Check whether Store × Product × Date is unique in raw sales
SELECT 
    date,
    store_id,
    product_id,
    COUNT(*) AS record_count
FROM sales
GROUP BY
    date,
    store_id,
    product_id
HAVING COUNT(*) > 1
ORDER BY record_count DESC
LIMIT 20;

-- =========================================================
-- 3. MISSING VALUES
-- =========================================================

-- Sales
SELECT
    COUNT(*) FILTER (WHERE sale_id IS NULL) AS missing_sale_id,
    COUNT(*) FILTER (WHERE date IS NULL OR TRIM(date) = '') AS missing_date,
    COUNT(*) FILTER (WHERE store_id IS NULL) AS missing_store_id,
    COUNT(*) FILTER (WHERE product_id IS NULL) AS missing_product_id,
    COUNT(*) FILTER (WHERE units IS NULL) AS missing_units
FROM sales;

-- Products
SELECT
    COUNT(*) FILTER (WHERE product_id IS NULL) AS missing_product_id,
    COUNT(*) FILTER (WHERE product_name IS NULL OR TRIM(product_name) = '') AS missing_product_name,
    COUNT(*) FILTER (WHERE product_category IS NULL OR TRIM(product_category) = '') AS missing_product_category,
    COUNT(*) FILTER (WHERE product_cost IS NULL OR TRIM(product_cost) = '') AS missing_product_cost,
    COUNT(*) FILTER (WHERE product_price IS NULL OR TRIM(product_price) = '') AS missing_product_price
FROM products;

-- Stores
SELECT
    COUNT(*) FILTER (WHERE store_id IS NULL) AS missing_store_id,
    COUNT(*) FILTER (WHERE store_name IS NULL OR TRIM(store_name) = '') AS missing_store_name,
    COUNT(*) FILTER (WHERE store_city IS NULL OR TRIM(store_city) = '') AS missing_store_city,
    COUNT(*) FILTER (WHERE store_location IS NULL OR TRIM(store_location) = '') AS missing_store_location,
    COUNT(*) FILTER (WHERE store_open_date IS NULL OR TRIM(store_open_date) = '') AS missing_store_open_date
FROM stores;

-- Inventory
SELECT
    COUNT(*) FILTER (WHERE store_id IS NULL) AS missing_store_id,
    COUNT(*) FILTER (WHERE product_id IS NULL) AS missing_product_id,
    COUNT(*) FILTER (WHERE stock_on_hand IS NULL) AS missing_stock_on_hand
FROM inventory;

-- Calendar
SELECT
    COUNT(*) FILTER (WHERE date IS NULL OR TRIM(date) = '') AS missing_date
FROM calendar;

-- =========================================================
-- 4. REFERENTIAL INTEGRITY
-- =========================================================

-- Sales -> Stores
SELECT COUNT(*) AS unmatched_store_ids
FROM sales s
LEFT JOIN stores st
    ON s.store_id = st.store_id
WHERE st.store_id IS NULL;

-- Sales -> Products
SELECT COUNT(*) AS unmatched_product_ids
FROM sales s
LEFT JOIN products p
    ON s.product_id = p.product_id
WHERE p.product_id IS NULL;

-- Inventory -> Stores
SELECT COUNT(*) AS unmatched_store_ids
FROM inventory i
LEFT JOIN stores st
    ON i.store_id = st.store_id
WHERE st.store_id IS NULL;

-- Inventory -> Products
SELECT COUNT(*) AS unmatched_product_ids
FROM inventory i
LEFT JOIN products p
    ON i.product_id = p.product_id
WHERE p.product_id IS NULL;

-- =========================================================
-- 5. VALUE AND RANGE VALIDATION
-- =========================================================
-- 5.1 Date validation
-- ---------------------------------------------------------

-- Sales date range
SELECT
    MIN(date::date) AS min_sales_date,
    MAX(date::date) AS max_sales_date,
    COUNT(DISTINCT date::date) AS sales_days
FROM sales;

-- Calendar date range
-- Calendar dates are stored in M/D/YYYY format
SELECT
    MIN(TO_DATE(date, 'MM/DD/YYYY')) AS min_calendar_date,
    MAX(TO_DATE(date, 'MM/DD/YYYY')) AS max_calendar_date,
    COUNT(DISTINCT TO_DATE(date, 'MM/DD/YYYY')) AS calendar_days
FROM calendar;

-- Store opening date range
SELECT
    MIN(store_open_date::date) AS earliest_store_open_date,
    MAX(store_open_date::date) AS latest_store_open_date
FROM stores;

-- Check that all sales dates are covered by the calendar table
SELECT DISTINCT
    s.date::date AS missing_calendar_date
FROM sales s
LEFT JOIN calendar c
    ON s.date::date = TO_DATE(c.date, 'MM/DD/YYYY')
WHERE c.date IS NULL
ORDER BY missing_calendar_date;

-- Check for sales occurring before the corresponding store opened
SELECT
    s.store_id,
    st.store_name,
    st.store_open_date::date AS store_open_date,
    MIN(s.date::date) AS first_sales_date
FROM sales s
JOIN stores st
    ON s.store_id = st.store_id
GROUP BY
    s.store_id,
    st.store_name,
    st.store_open_date
HAVING MIN(s.date::date) < st.store_open_date::date
ORDER BY s.store_id;

-- ---------------------------------------------------------
-- 5.2 Sales units validation
-- ---------------------------------------------------------

-- Units range and invalid quantities
SELECT
    MIN(units) AS min_units,
    MAX(units) AS max_units,
    COUNT(*) FILTER (WHERE units <= 0) AS non_positive_units
FROM sales;

-- ---------------------------------------------------------
-- 5.3 Inventory validation
-- ---------------------------------------------------------

-- Stock range and invalid stock levels
SELECT
    MIN(stock_on_hand) AS min_stock,
    MAX(stock_on_hand) AS max_stock,
    COUNT(*) FILTER (WHERE stock_on_hand < 0) AS negative_stock,
    COUNT(*) FILTER (WHERE stock_on_hand = 0) AS zero_stock
FROM inventory;

-- ---------------------------------------------------------
-- 5.4 Product cost and price validation
-- ---------------------------------------------------------

-- Cost and price ranges
SELECT
    MIN(REPLACE(product_cost, '$', '')::numeric) AS min_cost,
    MAX(REPLACE(product_cost, '$', '')::numeric) AS max_cost,
    MIN(REPLACE(product_price, '$', '')::numeric) AS min_price,
    MAX(REPLACE(product_price, '$', '')::numeric) AS max_price
FROM products;

-- Check for invalid prices and products priced at or below cost
SELECT
    COUNT(*) FILTER (
        WHERE REPLACE(product_cost, '$', '')::numeric <= 0
    ) AS non_positive_cost,
    COUNT(*) FILTER (
        WHERE REPLACE(product_price, '$', '')::numeric <= 0
    ) AS non_positive_price,
    COUNT(*) FILTER (
        WHERE REPLACE(product_price, '$', '')::numeric
           <= REPLACE(product_cost, '$', '')::numeric
    ) AS price_not_above_cost
FROM products;

-- =========================================================
-- 6. INVENTORY COVERAGE AND DATA LIMITATIONS
-- =========================================================

-- Inventory coverage across all possible Store × Product combinations
SELECT
    COUNT(*) AS possible_store_product_pairs,
    COUNT(i.product_id) AS inventory_pairs,
    COUNT(*) - COUNT(i.product_id) AS missing_inventory_pairs
FROM stores st
CROSS JOIN products p
LEFT JOIN inventory i
    ON st.store_id = i.store_id
   AND p.product_id = i.product_id;

-- Check whether missing inventory combinations have historical sales
WITH missing_inventory AS (
    SELECT
        st.store_id,
        p.product_id
    FROM stores st
    CROSS JOIN products p
    LEFT JOIN inventory i
        ON st.store_id = i.store_id
       AND p.product_id = i.product_id
    WHERE i.product_id IS NULL
)
SELECT
    COUNT(*) AS missing_inventory_pairs,
    COUNT(*) FILTER (
        WHERE s.store_id IS NOT NULL
    ) AS pairs_with_sales,
    COUNT(*) FILTER (
        WHERE s.store_id IS NULL
    ) AS pairs_without_sales
FROM missing_inventory m
LEFT JOIN (
    SELECT DISTINCT
        store_id,
        product_id
    FROM sales
) s
    ON m.store_id = s.store_id
   AND m.product_id = s.product_id;
