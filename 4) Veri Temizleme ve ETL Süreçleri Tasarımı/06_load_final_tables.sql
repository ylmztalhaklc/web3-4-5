-- ============================================================
-- 06_load_final_tables.sql
-- Purpose : Create final production-ready CLEAN tables with
--           proper data types, NOT NULL constraints, and
--           primary keys. Then load all CLEAN-status rows from
--           staging into these tables.
--           Finally, write a summary row to ETL_Log for each
--           entity.
--
-- After this script:
--   CLEAN_Customers, CLEAN_Orders, CLEAN_Products exist
--   and contain only validated, transformed data.
--   ETL_Log has 3 new rows showing load statistics.
-- ============================================================

USE Northwind;
GO

-- ------------------------------------------------------------
-- Drop final tables if they exist (safe re-run)
-- ------------------------------------------------------------
IF OBJECT_ID('dbo.CLEAN_Products',  'U') IS NOT NULL DROP TABLE dbo.CLEAN_Products;
IF OBJECT_ID('dbo.CLEAN_Orders',    'U') IS NOT NULL DROP TABLE dbo.CLEAN_Orders;
IF OBJECT_ID('dbo.CLEAN_Customers', 'U') IS NOT NULL DROP TABLE dbo.CLEAN_Customers;
GO

-- ------------------------------------------------------------
-- CLEAN_Customers
-- Proper data types enforced; CustomerID is the PK.
-- ContactName / City / Country guaranteed NOT NULL (cleaned).
-- ------------------------------------------------------------
CREATE TABLE dbo.CLEAN_Customers
(
    CustomerID    NCHAR(5)       NOT NULL,
    CompanyName   NVARCHAR(100)  NOT NULL,
    ContactName   NVARCHAR(100)  NOT NULL,   -- 'Unknown' if was NULL
    ContactTitle  NVARCHAR(50)   NULL,
    Address       NVARCHAR(200)  NULL,
    City          NVARCHAR(50)   NOT NULL,   -- 'Unknown' if was NULL
    Region        NVARCHAR(50)   NULL,
    PostalCode    NVARCHAR(20)   NULL,
    Country       NVARCHAR(50)   NOT NULL,   -- 'Unknown' if was NULL
    Phone         NVARCHAR(30)   NOT NULL,   -- 'N/A' if was NULL
    Fax           NVARCHAR(30)   NULL,
    ETL_LoadedAt  DATETIME       NOT NULL DEFAULT GETDATE(),
    CONSTRAINT PK_CLEAN_Customers PRIMARY KEY (CustomerID)
);
GO

-- ------------------------------------------------------------
-- CLEAN_Orders
-- Dates stored as DATE (not NVARCHAR).
-- Freight stored as MONEY.
-- ------------------------------------------------------------
CREATE TABLE dbo.CLEAN_Orders
(
    OrderID        INT            NOT NULL,
    CustomerID     NCHAR(5)       NOT NULL,
    EmployeeID     INT            NOT NULL DEFAULT 0,
    OrderDate      DATE           NOT NULL,
    RequiredDate   DATE           NULL,
    ShippedDate    DATE           NULL,
    ShipVia        INT            NULL,
    Freight        MONEY          NOT NULL DEFAULT 0,
    ShipName       NVARCHAR(100)  NULL,
    ShipAddress    NVARCHAR(200)  NULL,
    ShipCity       NVARCHAR(50)   NOT NULL,   -- 'Unknown' if was NULL
    ShipRegion     NVARCHAR(50)   NULL,
    ShipPostalCode NVARCHAR(20)   NULL,
    ShipCountry    NVARCHAR(50)   NOT NULL,   -- 'Unknown' if was NULL
    ETL_LoadedAt   DATETIME       NOT NULL DEFAULT GETDATE(),
    CONSTRAINT PK_CLEAN_Orders PRIMARY KEY (OrderID)
);
GO

-- ------------------------------------------------------------
-- CLEAN_Products
-- UnitPrice stored as MONEY (NULL allowed — flagged in DQ).
-- UnitsInStock as SMALLINT (guaranteed >= 0 after cleaning).
-- ------------------------------------------------------------
CREATE TABLE dbo.CLEAN_Products
(
    ProductID       INT            NOT NULL,
    ProductName     NVARCHAR(100)  NOT NULL,
    SupplierID      INT            NOT NULL DEFAULT 0,
    CategoryID      INT            NOT NULL DEFAULT 0,
    QuantityPerUnit NVARCHAR(50)   NULL,
    UnitPrice       MONEY          NULL,   -- NULL = price unknown (was negative/zero)
    UnitsInStock    SMALLINT       NOT NULL DEFAULT 0,
    UnitsOnOrder    SMALLINT       NOT NULL DEFAULT 0,
    ReorderLevel    SMALLINT       NOT NULL DEFAULT 0,
    Discontinued    BIT            NOT NULL DEFAULT 0,
    ETL_LoadedAt    DATETIME       NOT NULL DEFAULT GETDATE(),
    CONSTRAINT PK_CLEAN_Products PRIMARY KEY (ProductID)
);
GO

-- ------------------------------------------------------------
-- Load CLEAN_Customers from STG_Customers (CLEAN rows only)
-- NCHAR(5) cast: CustomerID may be shorter; RTRIM pads safely.
-- ------------------------------------------------------------
DECLARE @CustLoaded   INT = 0;
DECLARE @CustRejected INT = 0;
DECLARE @CustRaw      INT = 0;

SELECT @CustRaw      = COUNT(*) FROM dbo.RAW_Customers;
SELECT @CustRejected = COUNT(*) FROM dbo.STG_Customers WHERE STG_Status = 'REJECTED';

INSERT INTO dbo.CLEAN_Customers
    (CustomerID, CompanyName, ContactName, ContactTitle,
     Address, City, Region, PostalCode, Country, Phone, Fax)
SELECT
    CAST(CustomerID   AS NCHAR(5)),
    CompanyName,
    ContactName,
    ContactTitle,
    Address,
    City,
    Region,
    PostalCode,
    Country,
    Phone,
    Fax
FROM dbo.STG_Customers
WHERE STG_Status = 'CLEAN';

SET @CustLoaded = @@ROWCOUNT;

INSERT INTO dbo.ETL_Log (EntityName, RowsInRaw, RowsLoaded, RowsRejected, Notes)
VALUES ('Customers', @CustRaw, @CustLoaded, @CustRejected,
        'Loaded from STG_Customers WHERE STG_Status=CLEAN');
GO

-- ------------------------------------------------------------
-- Load CLEAN_Orders from STG_Orders (CLEAN rows only)
-- Dates are cast from NVARCHAR to DATE using CONVERT.
-- Freight is cast from NVARCHAR to MONEY.
-- ------------------------------------------------------------
DECLARE @OrdLoaded   INT = 0;
DECLARE @OrdRejected INT = 0;
DECLARE @OrdRaw      INT = 0;

SELECT @OrdRaw      = COUNT(*) FROM dbo.RAW_Orders;
SELECT @OrdRejected = COUNT(*) FROM dbo.STG_Orders WHERE STG_Status = 'REJECTED';

INSERT INTO dbo.CLEAN_Orders
    (OrderID, CustomerID, EmployeeID, OrderDate, RequiredDate,
     ShippedDate, ShipVia, Freight, ShipName, ShipAddress,
     ShipCity, ShipRegion, ShipPostalCode, ShipCountry)
SELECT
    CAST(OrderID     AS INT),
    CAST(CustomerID  AS NCHAR(5)),
    CAST(EmployeeID  AS INT),
    CAST(OrderDate   AS DATE),
    CASE WHEN ISDATE(RequiredDate) = 1 THEN CAST(RequiredDate AS DATE) ELSE NULL END,
    CASE WHEN ISDATE(ShippedDate)  = 1 THEN CAST(ShippedDate  AS DATE) ELSE NULL END,
    CASE WHEN ISNUMERIC(ShipVia)   = 1 THEN CAST(ShipVia AS INT)       ELSE NULL END,
    CAST(Freight AS MONEY),
    ShipName,
    ShipAddress,
    ShipCity,
    ShipRegion,
    ShipPostalCode,
    ShipCountry
FROM dbo.STG_Orders
WHERE STG_Status = 'CLEAN';

SET @OrdLoaded = @@ROWCOUNT;

INSERT INTO dbo.ETL_Log (EntityName, RowsInRaw, RowsLoaded, RowsRejected, Notes)
VALUES ('Orders', @OrdRaw, @OrdLoaded, @OrdRejected,
        'Loaded from STG_Orders WHERE STG_Status=CLEAN');
GO

-- ------------------------------------------------------------
-- Load CLEAN_Products from STG_Products (CLEAN rows only)
-- UnitPrice left NULL where it was set to NULL during cleaning.
-- ------------------------------------------------------------
DECLARE @ProdLoaded   INT = 0;
DECLARE @ProdRejected INT = 0;
DECLARE @ProdRaw      INT = 0;

SELECT @ProdRaw      = COUNT(*) FROM dbo.RAW_Products;
SELECT @ProdRejected = COUNT(*) FROM dbo.STG_Products WHERE STG_Status = 'REJECTED';

INSERT INTO dbo.CLEAN_Products
    (ProductID, ProductName, SupplierID, CategoryID, QuantityPerUnit,
     UnitPrice, UnitsInStock, UnitsOnOrder, ReorderLevel, Discontinued)
SELECT
    CAST(ProductID    AS INT),
    ProductName,
    CAST(SupplierID   AS INT),
    CAST(CategoryID   AS INT),
    QuantityPerUnit,
    CASE WHEN UnitPrice IS NOT NULL AND ISNUMERIC(UnitPrice) = 1
         THEN CAST(UnitPrice AS MONEY) ELSE NULL END,
    CAST(UnitsInStock AS SMALLINT),
    CAST(UnitsOnOrder AS SMALLINT),
    CAST(ReorderLevel AS SMALLINT),
    CAST(Discontinued AS BIT)
FROM dbo.STG_Products
WHERE STG_Status = 'CLEAN';

SET @ProdLoaded = @@ROWCOUNT;

INSERT INTO dbo.ETL_Log (EntityName, RowsInRaw, RowsLoaded, RowsRejected, Notes)
VALUES ('Products', @ProdRaw, @ProdLoaded, @ProdRejected,
        'Loaded from STG_Products WHERE STG_Status=CLEAN');
GO

-- ------------------------------------------------------------
-- Final summary
-- ------------------------------------------------------------
SELECT 'CLEAN_Customers' AS FinalTable, COUNT(*) AS RowsLoaded FROM dbo.CLEAN_Customers
UNION ALL
SELECT 'CLEAN_Orders',   COUNT(*) FROM dbo.CLEAN_Orders
UNION ALL
SELECT 'CLEAN_Products', COUNT(*) FROM dbo.CLEAN_Products;

SELECT * FROM dbo.ETL_Log ORDER BY LogID;

PRINT '06_load_final_tables.sql completed successfully.';
PRINT 'Final CLEAN tables populated. ETL_Log updated.';
GO
