/*
======================================================================
Stored Procedure: Loads the Silver Layer(Bronze --> Bronze)
======================================================================
Script Purpose:
  This Stored Procedure performs the ETL process to populate the 'silver'
  schema tables from the 'Bronze' tables.
Actions:
  It truncate the Silver tables before loading data.
  Inserts transformed and clean data from Bronze to Silver tables.
  Uses BULK INSERT to load the data.

  Parameter:
    This Procedure Accepts and Return NONE.
  Usage:
    EXEC Silver.load_silver;
======================================================================
*/
CREATE OR ALTER PROCEDURE Silver.load_silver AS
BEGIN    
    DECLARE @start_time DATETIME, @end_time DATETIME, @batch_start_time DATETIME, @batch_end_time DATETIME;
    BEGIN TRY
        SET @batch_start_time = GETDATE();
        PRINT '================================================';
		PRINT 'Loading Bronze Layer';
		PRINT '================================================';

		PRINT '------------------------------------------------';
		PRINT 'Loading CRM Tables';
		PRINT '------------------------------------------------';

        SET @start_time = GETDATE();
        PRINT '--> Truncating Table: Silver.crm_cust_info'
        TRUNCATE TABLE Silver.crm_cust_info;
        PRINT '--> Inserting Data Into: Silver.crm_cust_info'
        INSERT INTO Silver.crm_cust_info (
            cst_id,
            cst_key,
            cst_firstname,
            cst_lastname,
            cst_marital_status,
            cst_gndr,
            cst_create_date
        )
        SELECT
            cst_id,
            cst_key,
            TRIM(cst_firstname) AS cst_firstname,
            TRIM(cst_lastname) AS cst_lastname,
            CASE WHEN TRIM(UPPER(cst_marital_status)) = 'S' THEN 'Single'
                WHEN TRIM(UPPER(cst_marital_status)) = 'M' THEN 'Married'
                ELSE 'N/A'
            END AS cst_marital_status,
            CASE WHEN TRIM(UPPER(cst_gndr)) = 'F' THEN 'Female'
                WHEN TRIM(UPPER(cst_gndr)) = 'M' THEN 'Male'
                ELSE 'N/A'
            END AS cst_gndr,
            cst_create_date
        FROM (
            SELECT *, ROW_NUMBER() OVER(PARTITION BY cst_id ORDER BY cst_create_date DESC) as flag_last FROM Bronze.crm_cust_info
        )t 
        WHERE flag_last=1;
        SET @end_time = GETDATE()
        PRINT '--> Load Duration: ' +CAST(DATEDIFF(second, @start_time, @end_time)AS NVARCHAR) + 'seconds.';
        PRINT '--> -------------';

        SET @start_time = GETDATE();        
        PRINT '--> Truncating Table: Silver.crm_prd_info'
        TRUNCATE TABLE Silver.crm_prd_info;
        PRINT '--> Inserting Data Into: Silver.crm_prd_info'
        INSERT INTO Silver.crm_prd_info(
            prd_id,
            cat_id,
            prd_key,
            prd_nm,
            prd_cost,
            prd_line,
            prd_start_dt,
            prd_end_dt
        )
        SELECT 
            prd_id,
            -- prd_key,
            REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id, -- Extract Category ID
            SUBSTRING(prd_key, 7, LEN(prd_key)) AS prd_key,        -- Extract Product Key
            prd_nm,
            ISNULL(prd_cost, 0) AS prd_cost,
            CASE TRIM(UPPER(prd_line))
                WHEN 'M' THEN 'Mountain'
                WHEN 'R' THEN 'Road'
                WHEN 'S' THEN 'Other Sales'
                WHEN 'T' THEN 'Touring'
                ELSE 'N/A'
            END prd_line,
            CAST (prd_start_dt AS DATE) prd_start_dt,
            CAST(LEAD(prd_start_dt) OVER(PARTITION BY prd_key ORDER BY prd_start_dt) -1 AS DATE)AS prd_end_dt
            -- prd_end_dt
        FROM Bronze.crm_prd_info
        SET @end_time = GETDATE();
		PRINT '--> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '--> -------------';

        SET @start_time = GETDATE();
        PRINT '--> Truncating Table: Silver.crm_sales_details'
        TRUNCATE TABLE Silver.crm_sales_details;
        PRINT '--> Inserting Data Into: Silver.crm_sales_details'
        INSERT INTO Silver.crm_sales_details(
            sls_ord_num,
            sls_prd_key,
            sls_cust_id,
            sls_order_dt,
            sls_ship_dt,
            sls_due_dt,
            sls_sales,
            sls_quantity,
            sls_price
        )
        SELECT 
            sls_ord_num,
            sls_prd_key,
            sls_cust_id,
            CASE 
                WHEN sls_order_dt = 0 OR LEN(sls_order_dt) != 8 THEN NULL
                ELSE CAST(CAST(sls_order_dt AS NVARCHAR)AS DATE)
            END AS sls_order_dt,
            CASE 
                WHEN sls_ship_dt = 0 OR LEN(sls_ship_dt) != 8 THEN NULL
                ELSE CAST(CAST(sls_ship_dt AS NVARCHAR)AS DATE)
            END AS sls_ship_dt,
            CASE 
                WHEN sls_due_dt = 0 OR LEN(sls_due_dt) != 8 THEN NULL
                ELSE CAST(CAST(sls_due_dt AS NVARCHAR)AS DATE)
            END AS sls_due_dt,
            CASE 
                WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales != sls_quantity * ABS(sls_price)
                THEN sls_quantity * ABS(sls_price) -- Recalculate if original is missing or invalid
                ELSE sls_sales
            END AS sls_sales,
            sls_quantity,
            CASE 
                WHEN sls_price IS NULL OR sls_price <= 0 -- OR sls_price != sls_sales / sls_quantity
                THEN sls_sales / NULLIF(sls_quantity, 0) -- Recalculate if original is missing or invalid
                ELSE sls_price
            END AS sls_price
        FROM Bronze.crm_sales_details;
        SET @end_time = GETDATE();
		PRINT '--> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '--> -------------';

        SET @start_time = GETDATE();
        PRINT '--> Truncating Table: Silver.erp_cust_az12'
        TRUNCATE TABLE Silver.erp_cust_az12;
        PRINT '--> Inserting Data Into: Silver.erp_cust_az12'
        INSERT INTO Silver.erp_cust_az12(
            cid,
            bdate,
            gen
        )
        SELECT
            CASE 
                WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid))
                ELSE cid
            END AS cid,
            -- RIGHT(cid, 6) AS cid_t, -- Other possibility in Joining tables
            -- bdate,
            CASE 
                WHEN bdate > GETDATE() THEN NULL -- Setting future birthdays to NULL
                ELSE bdate
            END AS bdate,
            CASE
                WHEN UPPER(TRIM(gen)) IN ('F','FEMALE') THEN 'Female'
                WHEN UPPER(TRIM(gen)) IN ('M','MALE') THEN 'Male'
                ELSE 'N/A'
            END AS gen
        FROM Bronze.erp_cust_az12;
        SET @end_time = GETDATE();
		PRINT '--> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '--> -------------';

        SET @start_time = GETDATE();
        PRINT '--> Truncating Table: Silver.erp_loc_a101'
        TRUNCATE TABLE Silver.erp_loc_a101;
        PRINT '--> Inserting Data Into: Silver.erp_loc_a101'
        INSERT INTO Silver.erp_loc_a101(
            cid,
            cntry
        )
        SELECT 
            REPLACE(cid, '-', '') AS cid,
            CASE
                WHEN UPPER(TRIM(cntry)) IN ('USA', 'US', 'UNITED STATES') THEN 'United States'
                WHEN UPPER(TRIM(cntry)) IN ('UK', 'UNITED KINGDOM', 'ENGLAND', 'SCOTLAND', 'WALES') THEN 'United Kingdom'
                WHEN TRIM(cntry) = 'DE' THEN 'Germany'
                WHEN TRIM(cntry) = ''  OR cntry IS NULL THEN 'N/A'
                ELSE TRIM(cntry)
            END AS cntry
        FROM Bronze.erp_loc_a101;
        SET @end_time = GETDATE();
		PRINT '--> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '--> -------------';

        SET @start_time = GETDATE();
        PRINT '--> Truncating Table: Silver.erp_px_cat_g1v2'
        TRUNCATE TABLE Silver.erp_px_cat_g1v2;
        PRINT '--> Inserting Data Into: Silver.erp_px_cat_g1v2'
        INSERT INTO Silver.erp_px_cat_g1v2(
            id,
            cat,
            subcat,
            maintenance
        )
        SELECT
            id,
            cat,
            subcat,
            maintenance
        FROM Bronze.erp_px_cat_g1v2;
        SET @end_time = GETDATE();
		PRINT '--> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '--> -------------';

        SET @batch_end_time = GETDATE();
		PRINT '=========================================='
		PRINT 'Loading Silver Layer is Completed';
        PRINT 'Total Load Duration: ' + CAST(DATEDIFF(SECOND, @batch_start_time, @batch_end_time) AS NVARCHAR) + ' seconds';
		PRINT '=========================================='
    END TRY
    BEGIN CATCH
        PRINT '=========================================='
		PRINT 'ERROR OCCURED DURING LOADING BRONZE LAYER'
		PRINT 'Error Message' + ERROR_MESSAGE();
		PRINT 'Error Message' + CAST (ERROR_NUMBER() AS NVARCHAR);
		PRINT 'Error Message' + CAST (ERROR_STATE() AS NVARCHAR);
		PRINT '=========================================='
	END CATCH
END
