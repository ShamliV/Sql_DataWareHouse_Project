/*Built an end-to-end SQL analytics solution covering:

Change-over-time (trend analysis)
Cumulative and time-series analysis
Performance benchmarking using window functions
Contribution (part-to-whole) analysis
Customer and product segmentation
Advanced reporting layer using SQL views*/

--Change over time

use DATAWARESHOUSE;


SELECT year(order_date) as Order_year ,sum(SALES_AMOUNT)
FROM GOLD.FACT_SALES
WHERE ORDER_DATE IS NOT NULL
GROUP BY year(order_date)
ORDER BY year(order_date)

--Analysis -->The 2013 was the best year and 2010 was the not good as compared to others.

--Adding other measures as well.

SELECT year(order_date) as Order_year ,
sum(SALES_AMOUNT) as sales_amount,
count(distinct customer_key) as customers,
sum(quantity) as quantity
FROM GOLD.FACT_SALES
WHERE ORDER_DATE IS NOT NULL
GROUP BY year(order_date)
ORDER BY year(order_date)

--DATETRUNC 

SELECT
datetrunc(month,order_date) as Order_Month,
sum(SALES_AMOUNT) as sales_amount,
count(distinct customer_key) as customers,
sum(quantity) as quantity
FROM GOLD.FACT_SALES
WHERE ORDER_DATE IS NOT NULL
GROUP BY datetrunc(month,order_date) 
ORDER BY datetrunc(month,order_date) ;

--Cummalative analysis

--Total sales by month
--Running total by sales.

select order_date,
total_sales,
--Windows function
sum(total_sales) over(partition by year(order_date) order by order_date) as running_total
from (
select 
datetrunc(month,order_date) as Order_date,
sum(sales_amount) as total_sales
from gold.fact_sales
where order_date is NOT NULL
group by datetrunc(month,order_date))t


---Performance Analysis 

/* Analyze the yearly performance of products by comparing their sales
to both the average sales performance of the product and the previous year's sales */


select * from gold.dim_products;

With yearly_sales as(

select YEAR(s.order_date) as Order_year,p.product_name as product_name,sum(s.sales_amount) as Current_sales
from gold.fact_sales s
left join 
gold.dim_products p
on s.product_key=p.product_key
where s.order_date is NOT NULL
group by  year(s.order_date),p.product_name
)
select Order_year,product_name, Current_sales ,
avg(Current_sales) over(partition by product_name) as Avearge_sales,
Current_sales-avg(Current_sales) over(partition by product_name) as difference_sales,
case when Current_sales-avg(Current_sales) over(partition by product_name)<0 then 'Below Average'
 When Current_sales-avg(Current_sales) over(partition by product_name)>0 then 'Above Average'
 else 'Average'
 end Check_Average,
 Current_sales-LAG(Current_sales) over(partition by product_name order by Order_year) as difference_previous,
case when Current_sales-LAG(Current_sales) over(partition by product_name order by Order_year)<0 then 'Decrease'
 When Current_sales-LAG(Current_sales) over(partition by product_name order by Order_year)>0 then 'Increase'
 else 'NO change'
 end Check_PY_Change
from  yearly_sales;


--Part_To_whole_analysis

--Which categories contribute the most to overall sales?
With category_Analysis
as (select p.category as category ,sum(s.sales_amount) as total_sales
from gold.fact_sales s
left join gold.dim_products p
on s.product_key=p.product_key
group by p.category
)
select category,total_sales,
sum(total_sales) over() as Overall_sales,
concat(round(cast(total_sales as float)/sum(total_sales) over( )*100,2),'%') as percentage_of_Total
from category_Analysis
order by total_sales desc;

--Data segmentation

--Segregate the cost based on range


with cost_category as (select
product_key,product_name,cost,
case when cost<100 then 'Below 100'
when cost between 100 and 500 then '100-500'
when cost between 500 and 1000 then '500-1000'
else 'above 1000'
end cost_range
from gold.dim_products)
select cost_range, count(product_key) as total_products
from cost_category
group by cost_range
order by total_products


--- Change Over Time Analysis


-- Analyse sales performance over time
-- Quick Date Functions
SELECT
    YEAR(order_date) AS order_year,
    MONTH(order_date) AS order_month,
    SUM(sales_amount) AS total_sales,
    COUNT(DISTINCT customer_key) AS total_customers,
    SUM(quantity) AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY YEAR(order_date), MONTH(order_date)
ORDER BY YEAR(order_date), MONTH(order_date);

-- DATETRUNC()
SELECT
    DATETRUNC(month, order_date) AS order_date,
    SUM(sales_amount) AS total_sales,
    COUNT(DISTINCT customer_key) AS total_customers,
    SUM(quantity) AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(month, order_date)
ORDER BY DATETRUNC(month, order_date);

-- FORMAT()
SELECT
    FORMAT(order_date, 'yyyy-MMM') AS order_date,
    SUM(sales_amount) AS total_sales,
    COUNT(DISTINCT customer_key) AS total_customers,
    SUM(quantity) AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY FORMAT(order_date, 'yyyy-MMM')
ORDER BY FORMAT(order_date, 'yyyy-MMM');


/*Group customers into three segments based on their spending behavior:
- VIP: Customers with at least 12 months of history and spending more than €5,000.
- Regular: Customers with at least 12 months of history but spending €5,000 or less.
- New: Customers with a lifespan less than 12 months.
And find the total number of customers by each group
*/

Use DATAWARESHOUSE;


with customer_spending as (
select c.customer_key as customer_key,
SUM(f.sales_amount) AS total_spending,
MIN(order_date) AS first_order,
MAX(order_date) AS last_order,
DATEDIFF (month, MIN(order_date), MAX(order_date)) AS lifespan
FROM gold.fact_sales f
LEFT JOIN gold.dim_customer c
ON f.customer_key = c.customer_key
GROUP BY c.customer_key
)
SELECT
customer_segment,
COUNT(customer_key) AS total_customers
FROM (
SELECT
customer_key,
CASE WHEN lifespan >= 12 AND total_spending > 5000 THEN 'VIP'
WHEN lifespan >= 12 AND total_spending <= 5000 THEN 'Regular'
ELSE 'New'
END customer_segment
FROM customer_spending ) t
GROUP BY customer_segment
ORDER BY total_customers desc;



/*Customer Report

Purpose:
- This report consolidates key customer metrics and behaviors

Highlights:
1. Gathers essential fields such as names, ages, and transaction details.
2. Segments customers into categories (VIP, Regular, New) and age groups.
3. Aggregates customer-level metrics:
- total orders
- total sales
- total quantity purchased
- total products
- lifespan (in months)
4. Calculates valuable KPIs:
- recency (months since last order)
- average order value
- average monthly spend

*/

Create view gold.report_customer as 
With Base_query as (
SELECT
f.order_number,
f.product_key,
f.order_date,
f. sales_amount,
f.quantity,
c.customer_key,
c.customer_number,
CONCAT(c.first_name,' ', c.last_name)AS customer_name,
DATEDIFF(year, c.birthdate, GETDATE()) age
FROM gold.fact_sales f
LEFT JOIN gold.dim_customer c
ON f.customer_key = c.customer_key
WHERE order_date IS NOT NULL),
Customer_Aggregation as(
select customer_key,customer_number,customer_name,age,
count(distinct order_number) as total_orders,
sum(sales_amount) as total_sales,
sum(quantity) as total_quantity,
count(distinct product_key) as total_products,
MAX(order_date) as Last_Order_Date,
DATEDIFF(month,min(order_date),max(order_date)) as lifespan
from Base_query
group by customer_key,customer_number,customer_name,age)
select 
customer_key,
customer_number,
customer_name,
age,
CASE WHEN age<20 then 'Under 20'
WHEN AGE between 20 AND 29 then '20-29'
WHEN AGE BETWEEN 30 AND 39 THEN '30-39'
WHEN AGE BETWEEN 40 AND 49 THEN '40-49'
ELSE '50 AND Above'
end age_group,
CASE WHEN lifespan >= 12 AND  total_sales> 5000 THEN 'VIP'
WHEN lifespan >= 12 AND  total_sales<= 5000 THEN 'Regular'
ELSE 'New'
END customer_segment,
Last_Order_Date,
datediff(month,last_order_date,getdate()) as recency,
total_orders,
total_sales,
total_quantity,
total_products,
CASE WHEN total_Orders>0 then 0
else total_sales/total_orders
end as'Average_Order_Value',
-- average monthly spend
case when lifespan=0 then total_sales
else total_sales/lifespan
end as 'average monthly spend'
from Customer_Aggregation 

/*
Product Report

Purpose:
- This report consolidates key product metrics and behaviors.

Highlights:
1. Gathers essential fields such as product name, category, subcategory, and cost.
2. Segments products by revenue to identify High-Performers, Mid-Range, or Low-Performers.
3. Aggregates product-level metrics:
- total orders
- total sales
- total quantity sold
- total customers (unique)
- lifespan (in months)
4. Calculates valuable KPIs:
- recency (months since last sale)
- average order revenue (AOR)
- average monthly revenue
*/
select * from gold.dim_products;

CREATE VIEW gold.report_products AS
--Gathers essential fields such as product name, category, subcategory, and cost.
WITH base_query AS (
    SELECT 
        f.order_number,
        f.order_date,
        f.customer_key,
        f.sales_amount,
        f.quantity,
        p.product_key,
        p.product_name,
        p.category,
        p.subcategory,
        p.cost
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_products p
        ON f.product_key = p.product_key
    WHERE f.order_date IS NOT NULL
),

product_aggregation AS (
    SELECT
        product_key,
        product_name,
        category,
        subcategory,
        cost,
        DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) AS lifespan,
        MAX(order_date) AS last_sale_date,
        COUNT(DISTINCT order_number) AS total_orders,
        COUNT(DISTINCT customer_key) AS total_customers,
        SUM(sales_amount) AS total_sales,
        SUM(quantity) AS total_quantity,
        ROUND(AVG(CAST(sales_amount AS FLOAT) / NULLIF(quantity, 0)), 1) AS avg_selling_price
    FROM base_query
    GROUP BY 
        product_key, product_name, category, subcategory, cost
)

SELECT 
    product_key,
    product_name,
    category,
    subcategory,
    cost,
    last_sale_date,

    DATEDIFF(MONTH, last_sale_date, GETDATE()) AS recency_in_months,
    --Segments products by revenue to identify High-Performers, Mid-Range, or Low-Performers.
    CASE
        WHEN total_sales > 50000 THEN 'High-Performer'
        WHEN total_sales >= 10000 THEN 'Mid-Range'
        ELSE 'Low-Performer'
    END AS product_segment,
    /* Aggregates product-level metrics:
- total orders
- total sales
- total quantity sold
- total customers (unique)
- lifespan (in months),

Calculates valuable KPIs:
- recency (months since last sale)
- average order revenue (AOR)
- average monthly revenue*/
    lifespan,
    total_orders,
    total_sales,
    total_quantity,
    total_customers,
    avg_selling_price,
    -
    -- Average Order Revenue (AOR)
    CASE 
        WHEN total_orders = 0 THEN 0
        ELSE total_sales / total_orders
    END AS avg_order_revenue,

    -- Average Monthly Revenue
    CASE 
        WHEN lifespan = 0 THEN total_sales
        ELSE total_sales / lifespan
    END AS avg_monthly_revenue

FROM product_aggregation;
