-- ============================================================
-- 01_create_raw_tables.sql
-- Purpose : Create raw (source) tables that simulate incoming
--           dirty data from the legacy EastWind Distributors
--           system. All columns are loosely typed (NVARCHAR/VARCHAR)
--           and fully NULLable to accept any incoming garbage.
--           Also creates audit/logging tables used throughout
--           the entire pipeline.
--
-- Run on  : Northwind database
-- Author  : ETL Project
-- Date    : 2026
-- ============================================================

USE Northwind;
GO

-- ------------------------------------------------------------
-- Drop tables if they already exist (safe re-run)
-- ------------------------------------------------------------
IF OBJECT_ID('dbo.DQ_IssueLog',   'U') IS NOT NULL DROP TABLE dbo.DQ_IssueLog;
IF OBJECT_ID('dbo.ETL_Log',       'U') IS NOT NULL DROP TABLE dbo.ETL_Log;
IF OBJECT_ID('dbo.RAW_Products',  'U') IS NOT NULL DROP TABLE dbo.RAW_Products;
IF OBJECT_ID('dbo.RAW_Orders',    'U') IS NOT NULL DROP TABLE dbo.RAW_Orders;
IF OBJECT_ID('dbo.RAW_Customers', 'U') IS NOT NULL DROP TABLE dbo.RAW_Customers;
GO

-- ------------------------------------------------------------
-- RAW_Customers
-- Represents a flat export of customer records from the
-- legacy system. No constraints, no referential integrity.
-- ------------------------------------------------------------
CREATE TABLE dbo.RAW_Customers
(
    CustomerID    NVARCHAR(10)   NULL,
    CompanyName   NVARCHAR(100)  NULL,
    ContactName   NVARCHAR(100)  NULL,
    ContactTitle  NVARCHAR(50)   NULL,
    Address       NVARCHAR(200)  NULL,
    City          NVARCHAR(50)   NULL,
    Region        NVARCHAR(50)   NULL,
    PostalCode    NVARCHAR(20)   NULL,
    Country       NVARCHAR(50)   NULL,
    Phone         NVARCHAR(50)   NULL,
    Fax           NVARCHAR(50)   NULL,
    LoadedAt      DATETIME       NOT NULL DEFAULT GETDATE()
);
GO

-- ------------------------------------------------------------
-- RAW_Orders
-- Flat order header export. Dates are stored as NVARCHAR
-- to allow invalid date strings to be loaded without error.
-- ------------------------------------------------------------
CREATE TABLE dbo.RAW_Orders
(
    OrderID        NVARCHAR(10)   NULL,
    CustomerID     NVARCHAR(10)   NULL,
    EmployeeID     NVARCHAR(10)   NULL,
    OrderDate      NVARCHAR(30)   NULL,   -- intentionally VARCHAR: may contain garbage
    RequiredDate   NVARCHAR(30)   NULL,
    ShippedDate    NVARCHAR(30)   NULL,
    ShipVia        NVARCHAR(10)   NULL,
    Freight        NVARCHAR(20)   NULL,   -- intentionally VARCHAR: may contain negative strings
    ShipName       NVARCHAR(100)  NULL,
    ShipAddress    NVARCHAR(200)  NULL,
    ShipCity       NVARCHAR(50)   NULL,
    ShipRegion     NVARCHAR(50)   NULL,
    ShipPostalCode NVARCHAR(20)   NULL,
    ShipCountry    NVARCHAR(50)   NULL,
    LoadedAt       DATETIME       NOT NULL DEFAULT GETDATE()
);
GO

-- ------------------------------------------------------------
-- RAW_Products
-- Flat product export. UnitPrice and stock are NVARCHAR to
-- allow corrupt numeric strings to be loaded.
-- ------------------------------------------------------------
CREATE TABLE dbo.RAW_Products
(
    ProductID       NVARCHAR(10)   NULL,
    ProductName     NVARCHAR(100)  NULL,
    SupplierID      NVARCHAR(10)   NULL,
    CategoryID      NVARCHAR(10)   NULL,
    QuantityPerUnit NVARCHAR(50)   NULL,
    UnitPrice       NVARCHAR(20)   NULL,   -- intentionally VARCHAR
    UnitsInStock    NVARCHAR(10)   NULL,   -- intentionally VARCHAR
    UnitsOnOrder    NVARCHAR(10)   NULL,
    ReorderLevel    NVARCHAR(10)   NULL,
    Discontinued    NVARCHAR(5)    NULL,
    LoadedAt        DATETIME       NOT NULL DEFAULT GETDATE()
);
GO

-- ------------------------------------------------------------
-- ETL_Log
-- One row inserted per entity per pipeline run.
-- Records how many rows were loaded vs rejected.
-- ------------------------------------------------------------
CREATE TABLE dbo.ETL_Log
(
    LogID        INT IDENTITY(1,1) PRIMARY KEY,
    RunAt        DATETIME      NOT NULL DEFAULT GETDATE(),
    EntityName   NVARCHAR(50)  NOT NULL,  -- 'Customers', 'Orders', 'Products'
    RowsInRaw    INT           NOT NULL DEFAULT 0,
    RowsLoaded   INT           NOT NULL DEFAULT 0,
    RowsRejected INT           NOT NULL DEFAULT 0,
    Notes        NVARCHAR(500) NULL
);
GO

-- ------------------------------------------------------------
-- DQ_IssueLog
-- Every data quality problem found during cleaning is logged
-- here with the affected table, column, row key, issue type,
-- and original bad value. This forms the DQ report.
-- ------------------------------------------------------------
CREATE TABLE dbo.DQ_IssueLog
(
    IssueID       INT IDENTITY(1,1) PRIMARY KEY,
    DetectedAt    DATETIME      NOT NULL DEFAULT GETDATE(),
    SourceTable   NVARCHAR(50)  NOT NULL,   -- e.g. 'STG_Customers'
    RowKey        NVARCHAR(50)  NULL,        -- CustomerID / OrderID / ProductID
    ColumnName    NVARCHAR(50)  NOT NULL,
    IssueType     NVARCHAR(50)  NOT NULL,   -- NULL_VALUE, DUPLICATE, FORMAT_ERROR, etc.
    OriginalValue NVARCHAR(500) NULL,
    ActionTaken   NVARCHAR(200) NULL        -- FILLED_DEFAULT, REJECTED, CORRECTED, etc.
);
GO

-- ------------------------------------------------------------
-- Ensure CategoryID=0 sentinel exists in Northwind Categories
-- (used for products with unknown/missing category)
-- ------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM dbo.Categories WHERE CategoryID = 0)
BEGIN
    SET IDENTITY_INSERT dbo.Categories ON;
    INSERT INTO dbo.Categories (CategoryID, CategoryName, Description)
    VALUES (0, 'Uncategorized', 'Products with missing or unknown category');
    SET IDENTITY_INSERT dbo.Categories OFF;
END
GO

PRINT '01_create_raw_tables.sql completed successfully.';
PRINT 'Tables created: RAW_Customers, RAW_Orders, RAW_Products, ETL_Log, DQ_IssueLog';
GO
