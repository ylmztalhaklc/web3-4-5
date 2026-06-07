-- ============================================================
-- 03_create_staging_tables.sql
-- Purpose : Create staging tables that mirror the RAW tables
--           but add three audit columns:
--             STG_LoadedAt  - when the row was copied from RAW
--             STG_Status    - PENDING / CLEAN / REJECTED
--             STG_IssueNote - human-readable summary of issues
--           Then bulk-copy all RAW rows into staging so that
--           RAW data is never modified during cleaning.
--
-- After this script runs:
--   - STG tables exist and are fully populated
--   - All rows have STG_Status = 'PENDING'
--   - RAW tables remain untouched
-- ============================================================

USE Northwind;
GO

-- ------------------------------------------------------------
-- Drop staging tables if they already exist (safe re-run)
-- ------------------------------------------------------------
IF OBJECT_ID('dbo.STG_Products',  'U') IS NOT NULL DROP TABLE dbo.STG_Products;
IF OBJECT_ID('dbo.STG_Orders',    'U') IS NOT NULL DROP TABLE dbo.STG_Orders;
IF OBJECT_ID('dbo.STG_Customers', 'U') IS NOT NULL DROP TABLE dbo.STG_Customers;
GO

-- ------------------------------------------------------------
-- STG_Customers
-- ------------------------------------------------------------
CREATE TABLE dbo.STG_Customers
(
    STG_ID        INT IDENTITY(1,1) PRIMARY KEY,  -- surrogate key for staging
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
    -- Audit columns
    STG_LoadedAt  DATETIME       NOT NULL DEFAULT GETDATE(),
    STG_Status    NVARCHAR(20)   NOT NULL DEFAULT 'PENDING',  -- PENDING | CLEAN | REJECTED
    STG_IssueNote NVARCHAR(500)  NULL
);
GO

-- ------------------------------------------------------------
-- STG_Orders
-- ------------------------------------------------------------
CREATE TABLE dbo.STG_Orders
(
    STG_ID         INT IDENTITY(1,1) PRIMARY KEY,
    OrderID        NVARCHAR(10)   NULL,
    CustomerID     NVARCHAR(10)   NULL,
    EmployeeID     NVARCHAR(10)   NULL,
    OrderDate      NVARCHAR(30)   NULL,
    RequiredDate   NVARCHAR(30)   NULL,
    ShippedDate    NVARCHAR(30)   NULL,
    ShipVia        NVARCHAR(10)   NULL,
    Freight        NVARCHAR(20)   NULL,
    ShipName       NVARCHAR(100)  NULL,
    ShipAddress    NVARCHAR(200)  NULL,
    ShipCity       NVARCHAR(50)   NULL,
    ShipRegion     NVARCHAR(50)   NULL,
    ShipPostalCode NVARCHAR(20)   NULL,
    ShipCountry    NVARCHAR(50)   NULL,
    -- Audit columns
    STG_LoadedAt   DATETIME       NOT NULL DEFAULT GETDATE(),
    STG_Status     NVARCHAR(20)   NOT NULL DEFAULT 'PENDING',
    STG_IssueNote  NVARCHAR(500)  NULL
);
GO

-- ------------------------------------------------------------
-- STG_Products
-- ------------------------------------------------------------
CREATE TABLE dbo.STG_Products
(
    STG_ID          INT IDENTITY(1,1) PRIMARY KEY,
    ProductID       NVARCHAR(10)   NULL,
    ProductName     NVARCHAR(100)  NULL,
    SupplierID      NVARCHAR(10)   NULL,
    CategoryID      NVARCHAR(10)   NULL,
    QuantityPerUnit NVARCHAR(50)   NULL,
    UnitPrice       NVARCHAR(20)   NULL,
    UnitsInStock    NVARCHAR(10)   NULL,
    UnitsOnOrder    NVARCHAR(10)   NULL,
    ReorderLevel    NVARCHAR(10)   NULL,
    Discontinued    NVARCHAR(5)    NULL,
    -- Audit columns
    STG_LoadedAt    DATETIME       NOT NULL DEFAULT GETDATE(),
    STG_Status      NVARCHAR(20)   NOT NULL DEFAULT 'PENDING',
    STG_IssueNote   NVARCHAR(500)  NULL
);
GO

-- ------------------------------------------------------------
-- Load RAW → Staging  (snapshot copy, RAW untouched)
-- ------------------------------------------------------------
INSERT INTO dbo.STG_Customers
    (CustomerID, CompanyName, ContactName, ContactTitle,
     Address, City, Region, PostalCode, Country, Phone, Fax)
SELECT
    CustomerID, CompanyName, ContactName, ContactTitle,
    Address, City, Region, PostalCode, Country, Phone, Fax
FROM dbo.RAW_Customers;

INSERT INTO dbo.STG_Orders
    (OrderID, CustomerID, EmployeeID, OrderDate, RequiredDate,
     ShippedDate, ShipVia, Freight, ShipName, ShipAddress,
     ShipCity, ShipRegion, ShipPostalCode, ShipCountry)
SELECT
    OrderID, CustomerID, EmployeeID, OrderDate, RequiredDate,
    ShippedDate, ShipVia, Freight, ShipName, ShipAddress,
    ShipCity, ShipRegion, ShipPostalCode, ShipCountry
FROM dbo.RAW_Orders;

INSERT INTO dbo.STG_Products
    (ProductID, ProductName, SupplierID, CategoryID,
     QuantityPerUnit, UnitPrice, UnitsInStock, UnitsOnOrder,
     ReorderLevel, Discontinued)
SELECT
    ProductID, ProductName, SupplierID, CategoryID,
    QuantityPerUnit, UnitPrice, UnitsInStock, UnitsOnOrder,
    ReorderLevel, Discontinued
FROM dbo.RAW_Products;
GO

-- ------------------------------------------------------------
-- Confirm row counts
-- ------------------------------------------------------------
SELECT 'STG_Customers' AS TableName, COUNT(*) AS [RowCount] FROM dbo.STG_Customers
UNION ALL
SELECT 'STG_Orders',   COUNT(*) FROM dbo.STG_Orders
UNION ALL
SELECT 'STG_Products', COUNT(*) FROM dbo.STG_Products;

PRINT '03_create_staging_tables.sql completed successfully.';
PRINT 'All RAW rows copied to staging with STG_Status = PENDING.';
GO
