
/* 
EDA PROJECT OBJECTIVE:
Analyze sales, customers, and products to uncover:
- Revenue trends
- Customer behavior
- Product performance
- Business insights for decision making
*/
/* ============================================================
   STEP 1: DATABASE & METADATA EXPLORATION
   Understanding schema, tables, and column structure
   ============================================================ */

USE DATAWARESHOUSE;

-- List all tables in the database
SELECT * FROM INFORMATION_SCHEMA.TABLES;

-- Explore structure of a specific table (dim_products)
SELECT * 
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME = 'dim_products';

-- Check constraints applied in the database
SELECT * FROM INFORMATION_SCHEMA.CHECK_CONSTRAINTS;


/* ============================================================
   STEP 2: DIMENSION EXPLORATION
   Understanding categorical attributes (who, what, where)
   ============================================================ */

-- Customer dimension exploration
SELECT * FROM GOLD.dim_customer;

-- Identify unique values in key categorical columns
SELECT DISTINCT country FROM GOLD.dim_customer;
SELECT DISTINCT marital_status FROM GOLD.dim_customer;
SELECT DISTINCT gender FROM GOLD.dim_customer;

-- Product dimension exploration
SELECT * FROM GOLD.dim_products;

-- Unique product-related attributes
SELECT DISTINCT product_name FROM GOLD.dim_products;
SELECT DISTINCT category FROM GOLD.dim_products;
SELECT DISTINCT subcategory FROM GOLD.dim_products;
SELECT DISTINCT product_line FROM GOLD.dim_products;


/* ============================================================
   STEP 3: DATE EXPLORATION
   Understanding time coverage of dataset
   ============================================================ */

-- Find first and last order date + total duration
SELECT
    MIN(order_date) AS first_order_date,
    MAX(order_date) AS last_order_date,
    DATEDIFF(month, MIN(order_date), MAX(order_date)) AS order_range_months
FROM gold.fact_sales;

-- Find youngest and oldest customers
SELECT
    MIN(birthdate) AS oldest_birthdate,
    DATEDIFF(year, MIN(birthdate), GETDATE()) AS oldest_age,
    MAX(birthdate) AS youngest_birthdate,
    DATEDIFF(year, MAX(birthdate), GETDATE()) AS youngest_age
FROM gold.dim_customer;


/* ============================================================
   STEP 4: MEASURE EXPLORATION
   Analyzing key business metrics (KPIs)
   ============================================================ */

-- Total Sales Revenue
SELECT SUM(sales_amount) AS Total_sales FROM gold.fact_sales;

-- Total Quantity Sold
SELECT SUM(quantity) AS Total_quantity FROM gold.fact_sales;

-- Average Product Price
SELECT AVG(price) AS Average_price FROM gold.fact_sales;

-- Total Number of Orders
SELECT COUNT(order_number) AS Total_orders FROM gold.fact_sales;

-- Total Products Sold (row-level count)
SELECT COUNT(product_key) AS Total_products FROM gold.fact_sales;

-- Total Customers in dimension table
SELECT COUNT(DISTINCT customer_key) AS Total_customers FROM gold.dim_customer;

-- Customers who placed at least one order
SELECT COUNT(DISTINCT customer_key) AS Customers_with_orders FROM gold.fact_sales;


-- Combine all KPI metrics into one result
SELECT 'Total Sales' AS Measure_name, SUM(sales_amount) AS Measure_value FROM gold.fact_sales
UNION ALL
SELECT 'Total Quantity', SUM(quantity) FROM gold.fact_sales
UNION ALL
SELECT 'Average Price', AVG(price) FROM gold.fact_sales
UNION ALL
SELECT 'Total Orders', COUNT(order_number) FROM gold.fact_sales
UNION ALL
SELECT 'Total Products', COUNT(product_key) FROM gold.fact_sales
UNION ALL
SELECT 'Total Customers', COUNT(DISTINCT customer_key) FROM gold.dim_customer
UNION ALL
SELECT 'Customers with Orders', COUNT(DISTINCT customer_key) FROM gold.fact_sales;


/* ============================================================
   STEP 5: MAGNITUDE ANALYSIS
   Comparing distribution across categories
   ============================================================ */

-- Total customers by country
SELECT COUNT(customer_key) AS Total_customers, country
FROM gold.dim_customer
GROUP BY country
ORDER BY Total_customers DESC;

-- Total customers by gender
SELECT COUNT(customer_key) AS Total_customers, gender
FROM gold.dim_customer
GROUP BY gender
ORDER BY Total_customers DESC;

-- Total products by category
SELECT COUNT(product_key) AS Total_products, category
FROM gold.dim_products
GROUP BY category
ORDER BY Total_products DESC;

-- Average product cost by category
SELECT AVG(cost) AS Average_cost, category
FROM gold.dim_products
GROUP BY category
ORDER BY Average_cost DESC;

-- Total revenue by category
SELECT SUM(s.sales_amount) AS Revenue, p.category
FROM gold.fact_sales s
LEFT JOIN gold.dim_products p
    ON s.product_key = p.product_key
GROUP BY p.category
ORDER BY Revenue DESC;

-- Total revenue by customer
SELECT SUM(s.sales_amount) AS Revenue, c.first_name, c.last_nam
FROM gold.fact_sales s
LEFT JOIN gold.dim_customer c
    ON s.customer_key = c.customer_key
GROUP BY c.first_name, c.last_nam
ORDER BY Revenue DESC;

-- Total quantity sold by country
SELECT SUM(quantity) AS Total_quantity, c.country
FROM gold.fact_sales s
LEFT JOIN gold.dim_customer c
    ON s.customer_key = c.customer_key
GROUP BY c.country
ORDER BY Total_quantity DESC;


/* ============================================================
   STEP 6: RANKING ANALYSIS
   Identifying top and bottom performers
   ============================================================ */

-- Top 5 subcategories by revenue
SELECT TOP 5 p.subcategory, SUM(s.sales_amount) AS Revenue
FROM gold.fact_sales s
LEFT JOIN gold.dim_products p
    ON s.product_key = p.product_key
GROUP BY p.subcategory
ORDER BY Revenue DESC;

-- Bottom 5 subcategories
SELECT TOP 5 p.subcategory, SUM(s.sales_amount) AS Revenue
FROM gold.fact_sales s
LEFT JOIN gold.dim_products p
    ON s.product_key = p.product_key
GROUP BY p.subcategory
ORDER BY Revenue ASC;

-- Top 5 products
SELECT TOP 5 p.product_name, SUM(s.sales_amount) AS Revenue
FROM gold.fact_sales s
LEFT JOIN gold.dim_products p
    ON s.product_key = p.product_key
GROUP BY p.product_name
ORDER BY Revenue DESC;

-- Bottom 5 products
SELECT TOP 5 p.product_name, SUM(s.sales_amount) AS Revenue
FROM gold.fact_sales s
LEFT JOIN gold.dim_products p
    ON s.product_key = p.product_key
GROUP BY p.product_name
ORDER BY Revenue ASC;

-- Top 5 products using window function
SELECT *
FROM (
    SELECT 
        p.product_name,
        SUM(s.sales_amount) AS Revenue,
        ROW_NUMBER() OVER (ORDER BY SUM(s.sales_amount) DESC) AS rank_p
    FROM gold.fact_sales s
    LEFT JOIN gold.dim_products p
        ON s.product_key = p.product_key
    GROUP BY p.product_name
) t
WHERE rank_p <= 5;

-- Top 10 customers by revenue
SELECT *
FROM (
    SELECT 
        c.first_name,
        c.last_nam,
        SUM(s.sales_amount) AS Revenue,
        ROW_NUMBER() OVER (ORDER BY SUM(s.sales_amount) DESC) AS rank_c
    FROM gold.fact_sales s
    LEFT JOIN gold.dim_customer c
        ON s.customer_key = c.customer_key
    GROUP BY c.first_name, c.last_nam
) t
WHERE rank_c <= 10;

-- Bottom 3 customers
SELECT *
FROM (
    SELECT 
        c.first_name,
        c.last_nam,
        SUM(s.sales_amount) AS Revenue,
        ROW_NUMBER() OVER (ORDER BY SUM(s.sales_amount)) AS rank_c
    FROM gold.fact_sales s
    LEFT JOIN gold.dim_customer c
        ON s.customer_key = c.customer_key
    GROUP BY c.first_name, c.last_nam
) t
WHERE rank_c <= 3;
