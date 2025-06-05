/*
=============================
Creating Databases(MsSql)
=============================
Script Purpose:
  This script creates new databases(Schemas) for each layer(Bronze, Silver, Gold) after checking if they already exists.
  If the database already exists, it is dropped and recreated.
Warning:
  Running this script will drop the entire 'Bronze, Silver, Gold' Databases if it exists.
  All data in them will be lost, so go ahead with caution.
-----------------------------
Script:
*/
  
USE master;
GO

-- Drop and recreate the 'DataWarehouse' database
IF EXISTS (SELECT name FROM sys.databases WHERE name = 'DataWarehouse')
BEGIN
    ALTER DATABASE DataWarehouse SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE DataWarehouse;
END;
GO

-- Create the 'DataWarehouse' database
CREATE DATABASE DataWarehouse;
GO

USE DataWarehouse;
GO

-- Create Schemas
CREATE SCHEMA bronze;
GO

CREATE SCHEMA silver;
GO

CREATE SCHEMA gold;
GO
