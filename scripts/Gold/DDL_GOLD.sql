
---DDL Script: Create Gold Views

-- Create Dimension: gold.dim_customers
IF OBJECT_ID('gold.dim_customers', 'V') IS NOT NULL
    DROP VIEW gold.dim_customers;
GO

Create view gold.dim_customer 
as
  SELECT ROW_NUMBER() OVER (ORDER BY ci.[CST_ID]) AS customer_key,
  ci.[CST_ID] as customer_id
      ,ci.[CST_KEY]  as customer_number
      ,ci.[CST_FIRSTNAME] as first_name
      ,ci.[CST_LASTNAME] as last_nam,
            EL.[CNTRY] as country
      ,ci.[CST_MARITAL_STATUS] as marital_status,
   case when  ci.[CST_GNDR]!='N/A' then ci.[CST_GNDR]
      else coalesce( EC.[GEN],'N/A')
      end as gender,
      EC.[BDATE] as birthdate,
      ci.[CST_CREATE_DATE] as create_date
  FROM [DATAWARESHOUSE].[SILVER].[CRM_CUST_INFO] ci
  left join [DATAWARESHOUSE].[SILVER].[ERP_CUST_AZ12] EC
  on ci.[CST_KEY]=EC.[CID]
  left join [DATAWARESHOUSE].[SILVER].[ERP_LOC_A101] EL
  on ci.[CST_KEY]=EL.[CID];
GO

-- Create Dimension: gold.dim_products

IF OBJECT_ID('gold.dim_products', 'V') IS NOT NULL
    DROP VIEW gold.dim_products;
GO
  Create view gold.dim_products
as
  SELECT ROW_NUMBER() OVER (ORDER BY PI.[PRD_ID]) AS product_key,
  PI.[PRD_ID] as product_ID
      ,PI.[PRD_KEY] as product_number
      ,PI.[PROD_NM] as product_name
       ,PI.[CAT_ID] as category_id,
        PC.[CAT] as category 
      ,PC.[SUBCAT] as subcategory
      ,PC.[MAINTENANCE] as maintenance
      ,[PROD_COST] as cost
      ,PI.[PROD_LINE] as product_line
      ,PI.[PRD_START_DT] as start_date
  FROM [DATAWARESHOUSE].[SILVER].[CRM_PROD_INFO] PI
  left join  [DATAWARESHOUSE].[SILVER].[ERP_PX_CAT_G1V2] PC
  on PI.CAT_ID=PC.ID
  where PI.[PRD_END_DT] is NULL--To remove the historical data;
GO

-- Create Fact Table: gold.fact_sales

IF OBJECT_ID('gold.fact_sales', 'V') IS NOT NULL
    DROP VIEW gold.fact_sales;
GO

Create view gold.fact_sales
as
  SELECT  [SLS_ORD_NUM] as order_number,
  p.product_key ,
  c.customer_key
      ,[SLS_ORDER_DT] as order_date
      ,[SLS_SHIP_DT] as ship_date
      ,[SLS_DUE_DT] as due_date
      ,[SLS_SALES] as sales_amount
      ,[SLS_QUANTITY] as quantity
      ,[SLS_PRICE] as price
       FROM [DATAWARESHOUSE].[BRONZE].[CRM_SALES_DETAILS] sd
      left Join gold.dim_products p
      on sd.[SLS_PRD_KEY]=p.product_number
      left join gold.dim_customer c
      on sd.SLS_CUST_ID=c.customer_id;

GO
