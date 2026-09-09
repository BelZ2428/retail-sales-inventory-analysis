-- =========================================================
-- DATA PREPARATION
-- Retail Sales & Inventory Performance Analysis
-- =========================================================
-- Purpose:
-- Create a standardized analytical layer for Power BI
-- while preserving the original source tables unchanged.
-- =========================================================

CREATE SCHEMA IF NOT EXISTS analytics;
CREATE SCHEMA IF NOT EXISTS analytics;

-- =========================================================
-- 1. PRODUCT DIMENSION
-- =========================================================

CREATE OR REPLACE VIEW analytics.dim_products AS
SELECT
    product_id,
    product_name,
    product_category,
    REPLACE(product_cost, '$', '')::numeric(10,2) AS product_cost,
    REPLACE(product_price, '$', '')::numeric(10,2) AS product_price
FROM products;

-- =========================================================
-- 2. STORE DIMENSION
-- =========================================================

CREATE OR REPLACE VIEW analytics.dim_stores AS
SELECT
    store_id,
    store_name,
    store_city,
    store_location,
    store_open_date::date AS store_open_date
FROM stores;

-- =========================================================
-- 3. SALES FACT
-- =========================================================

CREATE OR REPLACE VIEW analytics.fact_sales AS
SELECT
    sale_id,
    date::date AS sale_date,
    store_id,
    product_id,
    units
FROM sales;

-- =========================================================
-- 4. INVENTORY FACT
-- =========================================================

CREATE OR REPLACE VIEW analytics.fact_inventory AS
SELECT
    store_id,
    product_id,
    stock_on_hand
FROM inventory;

