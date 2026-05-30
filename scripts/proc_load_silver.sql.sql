CREATE OR ALTER PROCEDURE SILVER.LOAD_SILVER
AS
BEGIN

    SET NOCOUNT ON;

    -- Prevent recursion
    IF @@NESTLEVEL > 1
    BEGIN
        PRINT 'Recursive call detected. Stopping execution.';
        RETURN;
    END;

    DECLARE @start_time DATETIME,
            @end_time DATETIME,
            @batch_start_time DATETIME,
            @batch_end_time DATETIME;

    SET @batch_start_time = GETDATE();

    BEGIN TRY

    PRINT '=====================================================';
    PRINT 'LOADING SILVER LAYER';
    PRINT '=====================================================';

    -----------------------------------------------------
    -- CRM
    -----------------------------------------------------
    PRINT '-----------------------------------------------------';
    PRINT 'LOADING CRM TABLES';
    PRINT '-----------------------------------------------------';

    ------------------ CRM_CUST_INFO ------------------
    SET @start_time = GETDATE();

    PRINT '>> TRUNCATING: SILVER.CRM_CUST_INFO';
    TRUNCATE TABLE SILVER.CRM_CUST_INFO;

    PRINT '>> LOADING: SILVER.CRM_CUST_INFO';

    INSERT INTO SILVER.CRM_CUST_INFO (
        CST_ID, CST_KEY, CST_FIRSTNAME, CST_LASTNAME,
        CST_MARITAL_STATUS, CST_GNDR, CST_CREATE_DATE
    )
    SELECT 
        CST_ID,
        CST_KEY,
        TRIM(CST_FIRSTNAME),
        TRIM(CST_LASTNAME),
        CASE 
            WHEN UPPER(TRIM(CST_MARITAL_STATUS)) = 'S' THEN 'Single'
            WHEN UPPER(TRIM(CST_MARITAL_STATUS)) = 'M' THEN 'Married'
            ELSE 'N/A'
        END,
        CASE 
            WHEN UPPER(TRIM(CST_GNDR)) = 'M' THEN 'Male'
            WHEN UPPER(TRIM(CST_GNDR)) = 'F' THEN 'Female'
            ELSE 'N/A'
        END,
        CST_CREATE_DATE
    FROM (
        SELECT *,
               ROW_NUMBER() OVER (
                   PARTITION BY CST_ID 
                   ORDER BY CST_CREATE_DATE DESC
               ) AS rn
        FROM BRONZE.CRM_CUST_INFO
        WHERE CST_ID IS NOT NULL
    ) t
    WHERE rn = 1;

    SET @end_time = GETDATE();
    PRINT '>> Duration: ' + CAST(DATEDIFF(SECOND,@start_time,@end_time) AS NVARCHAR) + ' sec';


    ------------------ CRM_PROD_INFO ------------------
    SET @start_time = GETDATE();

    PRINT '>> TRUNCATING: SILVER.CRM_PROD_INFO';
    TRUNCATE TABLE SILVER.CRM_PROD_INFO;

    PRINT '>> LOADING: SILVER.CRM_PROD_INFO';

    INSERT INTO SILVER.CRM_PROD_INFO (
        PRD_ID, CAT_ID, PRD_KEY, PROD_NM,
        PROD_COST, PROD_LINE, PRD_START_DT, PRD_END_DT
    )
    SELECT
        PRD_ID,
        REPLACE(SUBSTRING(PROD_KEY,1,5),'-','_'),
        SUBSTRING(PROD_KEY,7,LEN(PROD_KEY)),
        PROD_NM,
        ISNULL(PROD_COST,0),
        CASE
            WHEN UPPER(TRIM(PROD_LINE))='M' THEN 'Mountain'
            WHEN UPPER(TRIM(PROD_LINE))='R' THEN 'Road'
            WHEN UPPER(TRIM(PROD_LINE))='S' THEN 'Other Sales'
            WHEN UPPER(TRIM(PROD_LINE))='T' THEN 'Touring'
            ELSE 'N/A'
        END,
        PRD_START_DT,
        DATEADD(DAY,-1,
            LEAD(PRD_START_DT) OVER(
                PARTITION BY PROD_KEY
                ORDER BY PRD_START_DT
            )
        )
    FROM BRONZE.CRM_PROD_INFO;

    SET @end_time = GETDATE();
    PRINT '>> Duration: ' + CAST(DATEDIFF(SECOND,@start_time,@end_time) AS NVARCHAR) + ' sec';


    ------------------ CRM_SALES_DETAILS ------------------
    SET @start_time = GETDATE();

    PRINT '>> TRUNCATING: SILVER.CRM_SALES_DETAILS';
    TRUNCATE TABLE SILVER.CRM_SALES_DETAILS;

    PRINT '>> LOADING: SILVER.CRM_SALES_DETAILS';

    INSERT INTO SILVER.CRM_SALES_DETAILS (
        SLS_ORD_NUM, SLS_PRD_KEY, SLS_CUST_ID,
        SLS_ORDER_DT, SLS_SHIP_DT, SLS_DUE_DT,
        SLS_SALES, SLS_QUANTITY, SLS_PRICE
    )
    SELECT
        SLS_ORD_NUM,
        SLS_PRD_KEY,
        SLS_CUST_ID,
        SLS_ORDER_DT,
        SLS_SHIP_DT,
        SLS_DUE_DT,
        CASE 
            WHEN SLS_SALES IS NULL OR SLS_SALES<=0 
                 OR SLS_SALES <> SLS_QUANTITY*ABS(SLS_PRICE)
            THEN SLS_QUANTITY*ABS(SLS_PRICE)
            ELSE SLS_SALES
        END,
        SLS_QUANTITY,
        CASE 
            WHEN SLS_PRICE IS NULL OR SLS_PRICE<=0
            THEN SLS_SALES/NULLIF(SLS_QUANTITY,0)
            ELSE SLS_PRICE
        END
    FROM BRONZE.CRM_SALES_DETAILS;

    SET @end_time = GETDATE();
    PRINT '>> Duration: ' + CAST(DATEDIFF(SECOND,@start_time,@end_time) AS NVARCHAR) + ' sec';


    -----------------------------------------------------
    -- ERP
    -----------------------------------------------------
    PRINT '-----------------------------------------------------';
    PRINT 'LOADING ERP TABLES';
    PRINT '-----------------------------------------------------';

    ------------------ ERP_CUST_AZ12 ------------------
    SET @start_time = GETDATE();

    PRINT '>> TRUNCATING: SILVER.ERP_CUST_AZ12';
    TRUNCATE TABLE SILVER.ERP_CUST_AZ12;

    PRINT '>> LOADING: SILVER.ERP_CUST_AZ12';

    INSERT INTO SILVER.ERP_CUST_AZ12 (CID,BDATE,GEN)
    SELECT
        CASE WHEN CID LIKE 'NAS%' THEN SUBSTRING(CID,4,LEN(CID)) ELSE CID END,
        CASE WHEN BDATE>GETDATE() THEN NULL ELSE BDATE END,
        CASE
            WHEN Upper(TRIM(GEN)) IN ('M','MALE') THEN 'Male'
            WHEN upper(TRIM(GEN)) IN ('F','FEMALE') THEN 'Female'
            ELSE 'N/A'
        END
    FROM BRONZE.ERP_CUST_AZ12;

    SET @end_time = GETDATE();
    PRINT '>> Duration: ' + CAST(DATEDIFF(SECOND,@start_time,@end_time) AS NVARCHAR) + ' sec';


    ------------------ ERP_LOC_A101 ------------------
    SET @start_time = GETDATE();

    PRINT '>> TRUNCATING: SILVER.ERP_LOC_A101';
    TRUNCATE TABLE SILVER.ERP_LOC_A101;

    PRINT '>> LOADING: SILVER.ERP_LOC_A101';

    INSERT INTO SILVER.ERP_LOC_A101 (CID,CNTRY)
    SELECT
        REPLACE(CID,'-',''),
        CASE
            WHEN TRIM(CNTRY)='DE' THEN 'Germany'
            WHEN TRIM(CNTRY) IN ('USA','US') THEN 'United States'
            WHEN CNTRY IS NULL OR TRIM(CNTRY)='' THEN 'N/A'
            ELSE TRIM(CNTRY)
        END
    FROM BRONZE.ERP_LOC_A101;

    SET @end_time = GETDATE();
    PRINT '>> Duration: ' + CAST(DATEDIFF(SECOND,@start_time,@end_time) AS NVARCHAR) + ' sec';


    ------------------ ERP_PX_CAT_G1V2 ------------------
    SET @start_time = GETDATE();

    PRINT '>> TRUNCATING: SILVER.ERP_PX_CAT_G1V2';
    TRUNCATE TABLE SILVER.ERP_PX_CAT_G1V2;

    PRINT '>> LOADING: SILVER.ERP_PX_CAT_G1V2';

    INSERT INTO SILVER.ERP_PX_CAT_G1V2 (ID,CAT,SUBCAT,MAINTENANCE)
    SELECT ID,CAT,SUBCAT,MAINTENANCE
    FROM BRONZE.ERP_PX_CAT_G1V2;

    SET @end_time = GETDATE();
    PRINT '>> Duration: ' + CAST(DATEDIFF(SECOND,@start_time,@end_time) AS NVARCHAR) + ' sec';


    -----------------------------------------------------
    -- TOTAL
    -----------------------------------------------------
    SET @batch_end_time = GETDATE();

    PRINT '=====================================================';
    PRINT 'TOTAL SILVER LOAD DURATION: '
        + CAST(DATEDIFF(SECOND,@batch_start_time,@batch_end_time) AS NVARCHAR)
        + ' sec';
    PRINT '=====================================================';

    END TRY

    BEGIN CATCH
        PRINT '================================================';
        PRINT 'ERROR IN SILVER LOAD';
        PRINT ERROR_MESSAGE();
        PRINT '================================================';
    END CATCH

END;
GO

-- Execute
EXEC SILVER.LOAD_SILVER;
