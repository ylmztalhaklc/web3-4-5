-- ============================================================
-- 04_data_cleaning.sql
-- Purpose : Apply all data quality fixes to staging tables.
--           Every issue found is logged in DQ_IssueLog.
--           Rows that cannot be salvaged are marked REJECTED.
--           Rows that are fixed/acceptable are left as PENDING
--           (they will be marked CLEAN in 05_data_transformation.sql
--           after transformations are applied).
--
-- EXECUTION ORDER matters — run sections top to bottom.
-- Do not skip sections or run out of order.
--
-- Cleaning operations performed:
--   CUSTOMERS:
--     C1  - Log and reject rows with NULL CustomerID
--     C2  - Remove exact duplicate rows (keep lowest STG_ID)
--     C3  - Remove near-duplicate rows (same CustomerID, LTRIM/RTRIM/LOWER match)
--     C4  - Fill NULL ContactName with 'Unknown'
--     C5  - Fill NULL Country with 'Unknown'
--     C6  - Fill NULL City with 'Unknown'
--     C7  - Correct known city typos
--     C8  - Normalize Country values (US/United States → USA)
--     C9  - Standardize Phone to NNN-NNN-NNNN format
--     C10 - Fill NULL Phone with 'N/A'
--   ORDERS:
--     O1  - Log and reject rows with NULL OrderDate
--     O2  - Log and reject rows with future OrderDate (> today)
--     O3  - Log and reject rows where ShippedDate < OrderDate
--     O4  - Log and reject rows with orphan CustomerID
--     O5  - Set negative Freight to 0
--     O6  - Fill NULL Freight with '0'
--     O7  - Fill NULL ShipCity with 'Unknown'
--     O8  - Fill NULL ShipCountry with 'Unknown'
--     O9  - Fill NULL EmployeeID with '0'
--     O10 - Remove exact duplicate OrderID rows (keep lowest STG_ID)
--   PRODUCTS:
--     P1  - Log and reject rows with NULL ProductName
--     P2  - Remove near-duplicate products (same name after LTRIM/RTRIM/LOWER)
--     P3  - Assign CategoryID = '0' where NULL
--     P4  - Flag rows with NULL SupplierID (fill with '0', log issue)
--     P5  - Set negative UnitPrice to NULL and flag
--     P6  - Set zero UnitPrice to NULL and flag
--     P7  - Set negative UnitsInStock to '0' and log
-- ============================================================

USE Northwind;
GO

-- ============================================================
-- CUSTOMERS CLEANING
-- ============================================================

-- C1: Reject rows where CustomerID is NULL
-- These rows have no key and cannot be identified or merged.
-- --------------------------------------------------------
UPDATE dbo.STG_Customers
SET    STG_Status    = 'REJECTED',
       STG_IssueNote = ISNULL(STG_IssueNote, '') + '[C1] NULL CustomerID. '
WHERE  CustomerID IS NULL
  AND  STG_Status = 'PENDING';

INSERT INTO dbo.DQ_IssueLog
    (SourceTable, RowKey, ColumnName, IssueType, OriginalValue, ActionTaken)
SELECT
    'STG_Customers',
    CAST(STG_ID AS NVARCHAR),
    'CustomerID',
    'NULL_VALUE',
    NULL,
    'REJECTED'
FROM dbo.STG_Customers
WHERE CustomerID IS NULL;
GO

-- C2: Remove exact duplicate rows — keep the row with the lowest STG_ID
-- A duplicate is defined as identical values in all business columns.
-- --------------------------------------------------------
; WITH CTE_DupeCustomers AS
(
    SELECT STG_ID,
           ROW_NUMBER() OVER (
               PARTITION BY CustomerID, CompanyName, ContactName,
                            ContactTitle, Address, City, PostalCode,
                            Country, Phone
               ORDER BY STG_ID ASC
           ) AS RN
    FROM dbo.STG_Customers
    WHERE STG_Status = 'PENDING'
)
INSERT INTO dbo.DQ_IssueLog
    (SourceTable, RowKey, ColumnName, IssueType, OriginalValue, ActionTaken)
SELECT
    'STG_Customers',
    CAST(c.CustomerID AS NVARCHAR),
    'ALL',
    'DUPLICATE_ROW',
    'Exact duplicate',
    'DELETED'
FROM CTE_DupeCustomers d
JOIN dbo.STG_Customers c ON c.STG_ID = d.STG_ID
WHERE d.RN > 1;

; WITH CTE_DupeCustomers AS
(
    SELECT STG_ID,
           ROW_NUMBER() OVER (
               PARTITION BY CustomerID, CompanyName, ContactName,
                            ContactTitle, Address, City, PostalCode,
                            Country, Phone
               ORDER BY STG_ID ASC
           ) AS RN
    FROM dbo.STG_Customers
    WHERE STG_Status = 'PENDING'
)
DELETE FROM dbo.STG_Customers
WHERE STG_ID IN (SELECT STG_ID FROM CTE_DupeCustomers WHERE RN > 1);
GO

-- C3: Remove near-duplicate rows — same CustomerID, same CompanyName
--     after LTRIM/RTRIM/LOWER normalization. Keep lowest STG_ID.
-- --------------------------------------------------------
; WITH CTE_NearDupe AS
(
    SELECT STG_ID,
           ROW_NUMBER() OVER (
               PARTITION BY CustomerID, LTRIM(RTRIM(LOWER(CompanyName)))
               ORDER BY STG_ID ASC
           ) AS RN
    FROM dbo.STG_Customers
    WHERE STG_Status = 'PENDING'
      AND CustomerID IS NOT NULL
)
INSERT INTO dbo.DQ_IssueLog
    (SourceTable, RowKey, ColumnName, IssueType, OriginalValue, ActionTaken)
SELECT
    'STG_Customers',
    CAST(c.CustomerID AS NVARCHAR),
    'CompanyName',
    'NEAR_DUPLICATE',
    c.CompanyName,
    'DELETED'
FROM CTE_NearDupe d
JOIN dbo.STG_Customers c ON c.STG_ID = d.STG_ID
WHERE d.RN > 1;

; WITH CTE_NearDupe AS
(
    SELECT STG_ID,
           ROW_NUMBER() OVER (
               PARTITION BY CustomerID, LTRIM(RTRIM(LOWER(CompanyName)))
               ORDER BY STG_ID ASC
           ) AS RN
    FROM dbo.STG_Customers
    WHERE STG_Status = 'PENDING'
      AND CustomerID IS NOT NULL
)
DELETE FROM dbo.STG_Customers
WHERE STG_ID IN (SELECT STG_ID FROM CTE_NearDupe WHERE RN > 1);
GO

-- C4: Fill NULL ContactName with 'Unknown'
-- --------------------------------------------------------
INSERT INTO dbo.DQ_IssueLog
    (SourceTable, RowKey, ColumnName, IssueType, OriginalValue, ActionTaken)
SELECT
    'STG_Customers', CustomerID, 'ContactName', 'NULL_VALUE', NULL, 'FILLED_DEFAULT:Unknown'
FROM dbo.STG_Customers
WHERE ContactName IS NULL AND STG_Status = 'PENDING';

UPDATE dbo.STG_Customers
SET    ContactName   = 'Unknown',
       STG_IssueNote = ISNULL(STG_IssueNote, '') + '[C4] NULL ContactName filled. '
WHERE  ContactName IS NULL
  AND  STG_Status = 'PENDING';
GO

-- C5: Fill NULL Country with 'Unknown'
-- --------------------------------------------------------
INSERT INTO dbo.DQ_IssueLog
    (SourceTable, RowKey, ColumnName, IssueType, OriginalValue, ActionTaken)
SELECT
    'STG_Customers', CustomerID, 'Country', 'NULL_VALUE', NULL, 'FILLED_DEFAULT:Unknown'
FROM dbo.STG_Customers
WHERE Country IS NULL AND STG_Status = 'PENDING';

UPDATE dbo.STG_Customers
SET    Country       = 'Unknown',
       STG_IssueNote = ISNULL(STG_IssueNote, '') + '[C5] NULL Country filled. '
WHERE  Country IS NULL
  AND  STG_Status = 'PENDING';
GO

-- C6: Fill NULL City with 'Unknown'
-- --------------------------------------------------------
INSERT INTO dbo.DQ_IssueLog
    (SourceTable, RowKey, ColumnName, IssueType, OriginalValue, ActionTaken)
SELECT
    'STG_Customers', CustomerID, 'City', 'NULL_VALUE', NULL, 'FILLED_DEFAULT:Unknown'
FROM dbo.STG_Customers
WHERE City IS NULL AND STG_Status = 'PENDING';

UPDATE dbo.STG_Customers
SET    City          = 'Unknown',
       STG_IssueNote = ISNULL(STG_IssueNote, '') + '[C6] NULL City filled. '
WHERE  City IS NULL
  AND  STG_Status = 'PENDING';
GO

-- C7: Correct known city name typos using a CASE lookup
-- --------------------------------------------------------
INSERT INTO dbo.DQ_IssueLog
    (SourceTable, RowKey, ColumnName, IssueType, OriginalValue, ActionTaken)
SELECT
    'STG_Customers',
    CustomerID,
    'City',
    'FORMAT_ERROR',
    City,
    'CORRECTED:' + CASE LTRIM(RTRIM(LOWER(City)))
        WHEN 'londn'    THEN 'London'
        WHEN 'berln'    THEN 'Berlin'
        WHEN 'paris'    THEN 'Paris'
        WHEN 'new york' THEN 'New York'
        WHEN 'london'   THEN 'London'
        ELSE City
    END
FROM dbo.STG_Customers
WHERE STG_Status = 'PENDING'
  AND LTRIM(RTRIM(LOWER(City))) IN ('londn','berln','paris','new york','london')
  AND City <> CASE LTRIM(RTRIM(LOWER(City)))
                  WHEN 'londn'    THEN 'London'
                  WHEN 'berln'    THEN 'Berlin'
                  WHEN 'paris'    THEN 'Paris'
                  WHEN 'new york' THEN 'New York'
                  WHEN 'london'   THEN 'London'
                  ELSE City
              END;

UPDATE dbo.STG_Customers
SET    City = CASE LTRIM(RTRIM(LOWER(City)))
                  WHEN 'londn'    THEN 'London'
                  WHEN 'berln'    THEN 'Berlin'
                  WHEN 'paris'    THEN 'Paris'
                  WHEN 'new york' THEN 'New York'
                  WHEN 'london'   THEN 'London'
                  ELSE City
              END,
       STG_IssueNote = ISNULL(STG_IssueNote, '') + '[C7] City typo corrected. '
WHERE  STG_Status = 'PENDING'
  AND  LTRIM(RTRIM(LOWER(City))) IN ('londn','berln','paris','new york','london');
GO

-- C8: Normalize Country — US / United States / USA → 'USA'
-- --------------------------------------------------------
INSERT INTO dbo.DQ_IssueLog
    (SourceTable, RowKey, ColumnName, IssueType, OriginalValue, ActionTaken)
SELECT
    'STG_Customers', CustomerID, 'Country', 'INCONSISTENT_VALUE', Country, 'NORMALIZED:USA'
FROM dbo.STG_Customers
WHERE STG_Status = 'PENDING'
  AND UPPER(LTRIM(RTRIM(Country))) IN ('US', 'UNITED STATES', 'UNITED STATES OF AMERICA')
  AND Country <> 'USA';

UPDATE dbo.STG_Customers
SET    Country       = 'USA',
       STG_IssueNote = ISNULL(STG_IssueNote, '') + '[C8] Country normalized to USA. '
WHERE  STG_Status = 'PENDING'
  AND  UPPER(LTRIM(RTRIM(Country))) IN ('US', 'UNITED STATES', 'UNITED STATES OF AMERICA');
GO

-- C9: Standardize Phone numbers to NNN-NNN-NNNN format
--     Handles: +1-NNN-NNN-NNNN, (NNN) NNN-NNNN, NNN.NNN.NNNN, NNNNNNNNNN
--     Phones that do not yield exactly 10 digits are left unchanged and logged.
--     Single-pass CROSS APPLY: original value is never permanently overwritten.
-- --------------------------------------------------------
UPDATE c
SET    c.Phone        = CASE
                            WHEN LEN(x.D) = 10 AND x.D NOT LIKE '%[^0-9]%'
                            THEN SUBSTRING(x.D,1,3)+'-'+SUBSTRING(x.D,4,3)+'-'+SUBSTRING(x.D,7,4)
                            ELSE c.Phone
                        END,
       c.STG_IssueNote = CASE
                            WHEN LEN(x.D) = 10 AND x.D NOT LIKE '%[^0-9]%'
                            THEN ISNULL(c.STG_IssueNote,'') + '[C9] Phone reformatted. '
                            ELSE c.STG_IssueNote
                        END
FROM   dbo.STG_Customers c
CROSS APPLY (
    SELECT REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
               CASE WHEN LEFT(c.Phone,3) = '+1-' THEN STUFF(c.Phone,1,3,'') ELSE c.Phone END,
           '+',''),'-',''),'.',''),'(',''),')',''),' ','') AS D
) x
WHERE  c.STG_Status = 'PENDING'
  AND  c.Phone IS NOT NULL;

-- Log phones that could not be standardized to NNN-NNN-NNNN
INSERT INTO dbo.DQ_IssueLog
    (SourceTable, RowKey, ColumnName, IssueType, OriginalValue, ActionTaken)
SELECT
    'STG_Customers', CustomerID, 'Phone', 'FORMAT_ERROR',
    Phone, 'LEFT_AS_IS:non_standard_format'
FROM dbo.STG_Customers
WHERE STG_Status = 'PENDING'
  AND Phone IS NOT NULL
  AND Phone <> 'N/A'
  AND Phone NOT LIKE '[0-9][0-9][0-9]-[0-9][0-9][0-9]-[0-9][0-9][0-9][0-9]';
GO

-- C10: Fill NULL Phone with 'N/A'
-- --------------------------------------------------------
INSERT INTO dbo.DQ_IssueLog
    (SourceTable, RowKey, ColumnName, IssueType, OriginalValue, ActionTaken)
SELECT
    'STG_Customers', CustomerID, 'Phone', 'NULL_VALUE', NULL, 'FILLED_DEFAULT:N/A'
FROM dbo.STG_Customers
WHERE Phone IS NULL AND STG_Status = 'PENDING';

UPDATE dbo.STG_Customers
SET    Phone         = 'N/A',
       STG_IssueNote = ISNULL(STG_IssueNote, '') + '[C10] NULL Phone filled. '
WHERE  Phone IS NULL
  AND  STG_Status = 'PENDING';
GO

-- ============================================================
-- ORDERS CLEANING
-- ============================================================

-- O1: Reject rows where OrderDate is NULL
-- --------------------------------------------------------
UPDATE dbo.STG_Orders
SET    STG_Status    = 'REJECTED',
       STG_IssueNote = ISNULL(STG_IssueNote, '') + '[O1] NULL OrderDate. '
WHERE  OrderDate IS NULL
  AND  STG_Status = 'PENDING';

INSERT INTO dbo.DQ_IssueLog
    (SourceTable, RowKey, ColumnName, IssueType, OriginalValue, ActionTaken)
SELECT
    'STG_Orders', OrderID, 'OrderDate', 'NULL_VALUE', NULL, 'REJECTED'
FROM dbo.STG_Orders
WHERE OrderDate IS NULL;
GO

-- O2: Reject rows where OrderDate is a future date (> today)
-- ISDATE() ensures we only compare valid date strings
-- --------------------------------------------------------
UPDATE dbo.STG_Orders
SET    STG_Status    = 'REJECTED',
       STG_IssueNote = ISNULL(STG_IssueNote, '') + '[O2] Future OrderDate. '
WHERE  STG_Status = 'PENDING'
  AND  ISDATE(OrderDate) = 1
  AND  CAST(OrderDate AS DATE) > CAST(GETDATE() AS DATE);

INSERT INTO dbo.DQ_IssueLog
    (SourceTable, RowKey, ColumnName, IssueType, OriginalValue, ActionTaken)
SELECT
    'STG_Orders', OrderID, 'OrderDate', 'FUTURE_DATE', OrderDate, 'REJECTED'
FROM dbo.STG_Orders
WHERE ISDATE(OrderDate) = 1
  AND CAST(OrderDate AS DATE) > CAST(GETDATE() AS DATE);
GO

-- O3: Reject rows where ShippedDate is earlier than OrderDate
-- --------------------------------------------------------
UPDATE dbo.STG_Orders
SET    STG_Status    = 'REJECTED',
       STG_IssueNote = ISNULL(STG_IssueNote, '') + '[O3] ShippedDate before OrderDate. '
WHERE  STG_Status = 'PENDING'
  AND  ShippedDate IS NOT NULL
  AND  ISDATE(OrderDate)   = 1
  AND  ISDATE(ShippedDate) = 1
  AND  CAST(ShippedDate AS DATE) < CAST(OrderDate AS DATE);

INSERT INTO dbo.DQ_IssueLog
    (SourceTable, RowKey, ColumnName, IssueType, OriginalValue, ActionTaken)
SELECT
    'STG_Orders', OrderID, 'ShippedDate',
    'DATE_LOGIC_ERROR',
    'ShippedDate=' + ShippedDate + ' < OrderDate=' + OrderDate,
    'REJECTED'
FROM dbo.STG_Orders
WHERE ShippedDate IS NOT NULL
  AND ISDATE(OrderDate)   = 1
  AND ISDATE(ShippedDate) = 1
  AND CAST(ShippedDate AS DATE) < CAST(OrderDate AS DATE);
GO

-- O4: Reject rows where CustomerID does not exist in STG_Customers
--     (only check against PENDING/valid customers, not REJECTED ones)
-- --------------------------------------------------------
UPDATE o
SET    o.STG_Status    = 'REJECTED',
       o.STG_IssueNote = ISNULL(o.STG_IssueNote, '') + '[O4] Orphan CustomerID. '
FROM   dbo.STG_Orders o
LEFT JOIN dbo.STG_Customers c
    ON  o.CustomerID = c.CustomerID
    AND c.STG_Status <> 'REJECTED'
WHERE  o.STG_Status = 'PENDING'
  AND  c.CustomerID IS NULL;

INSERT INTO dbo.DQ_IssueLog
    (SourceTable, RowKey, ColumnName, IssueType, OriginalValue, ActionTaken)
SELECT
    'STG_Orders', o.OrderID, 'CustomerID', 'ORPHAN_FK', o.CustomerID, 'REJECTED'
FROM dbo.STG_Orders o
LEFT JOIN dbo.STG_Customers c
    ON  o.CustomerID = c.CustomerID
    AND c.STG_Status <> 'REJECTED'
WHERE o.STG_Status = 'REJECTED'
  AND c.CustomerID IS NULL
  AND o.STG_IssueNote LIKE '%[O4]%';
GO

-- O5: Set negative Freight to 0
-- --------------------------------------------------------
INSERT INTO dbo.DQ_IssueLog
    (SourceTable, RowKey, ColumnName, IssueType, OriginalValue, ActionTaken)
SELECT
    'STG_Orders', OrderID, 'Freight', 'INVALID_VALUE', Freight, 'SET_TO_0'
FROM dbo.STG_Orders
WHERE STG_Status = 'PENDING'
  AND ISNUMERIC(Freight) = 1
  AND CAST(Freight AS DECIMAL(10,2)) < 0;

UPDATE dbo.STG_Orders
SET    Freight       = '0',
       STG_IssueNote = ISNULL(STG_IssueNote, '') + '[O5] Negative Freight set to 0. '
WHERE  STG_Status = 'PENDING'
  AND  ISNUMERIC(Freight) = 1
  AND  CAST(Freight AS DECIMAL(10,2)) < 0;
GO

-- O6: Fill NULL Freight with '0'
-- --------------------------------------------------------
UPDATE dbo.STG_Orders
SET    Freight       = '0',
       STG_IssueNote = ISNULL(STG_IssueNote, '') + '[O6] NULL Freight set to 0. '
WHERE  Freight IS NULL
  AND  STG_Status = 'PENDING';
GO

-- O7: Fill NULL ShipCity with 'Unknown'
-- --------------------------------------------------------
INSERT INTO dbo.DQ_IssueLog
    (SourceTable, RowKey, ColumnName, IssueType, OriginalValue, ActionTaken)
SELECT
    'STG_Orders', OrderID, 'ShipCity', 'NULL_VALUE', NULL, 'FILLED_DEFAULT:Unknown'
FROM dbo.STG_Orders
WHERE ShipCity IS NULL AND STG_Status = 'PENDING';

UPDATE dbo.STG_Orders
SET    ShipCity      = 'Unknown',
       STG_IssueNote = ISNULL(STG_IssueNote, '') + '[O7] NULL ShipCity filled. '
WHERE  ShipCity IS NULL AND STG_Status = 'PENDING';
GO

-- O8: Fill NULL ShipCountry with 'Unknown'
-- --------------------------------------------------------
INSERT INTO dbo.DQ_IssueLog
    (SourceTable, RowKey, ColumnName, IssueType, OriginalValue, ActionTaken)
SELECT
    'STG_Orders', OrderID, 'ShipCountry', 'NULL_VALUE', NULL, 'FILLED_DEFAULT:Unknown'
FROM dbo.STG_Orders
WHERE ShipCountry IS NULL AND STG_Status = 'PENDING';

UPDATE dbo.STG_Orders
SET    ShipCountry   = 'Unknown',
       STG_IssueNote = ISNULL(STG_IssueNote, '') + '[O8] NULL ShipCountry filled. '
WHERE  ShipCountry IS NULL AND STG_Status = 'PENDING';
GO

-- O9: Fill NULL EmployeeID with '0' (unknown employee)
-- --------------------------------------------------------
UPDATE dbo.STG_Orders
SET    EmployeeID    = '0',
       STG_IssueNote = ISNULL(STG_IssueNote, '') + '[O9] NULL EmployeeID set to 0. '
WHERE  EmployeeID IS NULL AND STG_Status = 'PENDING';
GO

-- O10: Remove exact duplicate OrderID rows (keep lowest STG_ID)
-- --------------------------------------------------------
; WITH CTE_DupeOrders AS
(
    SELECT STG_ID,
           ROW_NUMBER() OVER (
               PARTITION BY OrderID, CustomerID, OrderDate, Freight
               ORDER BY STG_ID ASC
           ) AS RN
    FROM dbo.STG_Orders
    WHERE STG_Status = 'PENDING'
)
INSERT INTO dbo.DQ_IssueLog
    (SourceTable, RowKey, ColumnName, IssueType, OriginalValue, ActionTaken)
SELECT
    'STG_Orders',
    CAST(o.OrderID AS NVARCHAR),
    'ALL',
    'DUPLICATE_ROW',
    'Exact duplicate',
    'DELETED'
FROM CTE_DupeOrders d
JOIN dbo.STG_Orders o ON o.STG_ID = d.STG_ID
WHERE d.RN > 1;

; WITH CTE_DupeOrders AS
(
    SELECT STG_ID,
           ROW_NUMBER() OVER (
               PARTITION BY OrderID, CustomerID, OrderDate, Freight
               ORDER BY STG_ID ASC
           ) AS RN
    FROM dbo.STG_Orders
    WHERE STG_Status = 'PENDING'
)
DELETE FROM dbo.STG_Orders
WHERE STG_ID IN (SELECT STG_ID FROM CTE_DupeOrders WHERE RN > 1);
GO

-- ============================================================
-- PRODUCTS CLEANING
-- ============================================================

-- P1: Reject rows where ProductName is NULL
-- --------------------------------------------------------
UPDATE dbo.STG_Products
SET    STG_Status    = 'REJECTED',
       STG_IssueNote = ISNULL(STG_IssueNote, '') + '[P1] NULL ProductName. '
WHERE  ProductName IS NULL
  AND  STG_Status = 'PENDING';

INSERT INTO dbo.DQ_IssueLog
    (SourceTable, RowKey, ColumnName, IssueType, OriginalValue, ActionTaken)
SELECT
    'STG_Products', ProductID, 'ProductName', 'NULL_VALUE', NULL, 'REJECTED'
FROM dbo.STG_Products
WHERE ProductName IS NULL;
GO

-- P2: Remove near-duplicate products (same name after LOWER + LTRIM/RTRIM)
--     Keep the row with the lowest STG_ID.
-- --------------------------------------------------------
; WITH CTE_NearDupeProd AS
(
    SELECT STG_ID,
           ROW_NUMBER() OVER (
               PARTITION BY LTRIM(RTRIM(LOWER(ProductName)))
               ORDER BY STG_ID ASC
           ) AS RN
    FROM dbo.STG_Products
    WHERE STG_Status = 'PENDING'
      AND ProductName IS NOT NULL
)
INSERT INTO dbo.DQ_IssueLog
    (SourceTable, RowKey, ColumnName, IssueType, OriginalValue, ActionTaken)
SELECT
    'STG_Products',
    p.ProductID,
    'ProductName',
    'NEAR_DUPLICATE',
    p.ProductName,
    'DELETED'
FROM CTE_NearDupeProd d
JOIN dbo.STG_Products p ON p.STG_ID = d.STG_ID
WHERE d.RN > 1;

; WITH CTE_NearDupeProd AS
(
    SELECT STG_ID,
           ROW_NUMBER() OVER (
               PARTITION BY LTRIM(RTRIM(LOWER(ProductName)))
               ORDER BY STG_ID ASC
           ) AS RN
    FROM dbo.STG_Products
    WHERE STG_Status = 'PENDING'
      AND ProductName IS NOT NULL
)
DELETE FROM dbo.STG_Products
WHERE STG_ID IN (SELECT STG_ID FROM CTE_NearDupeProd WHERE RN > 1);
GO

-- P3: Assign CategoryID = '0' for NULL CategoryID (sentinel = Uncategorized)
-- --------------------------------------------------------
INSERT INTO dbo.DQ_IssueLog
    (SourceTable, RowKey, ColumnName, IssueType, OriginalValue, ActionTaken)
SELECT
    'STG_Products', ProductID, 'CategoryID', 'NULL_VALUE', NULL, 'FILLED_DEFAULT:0_Uncategorized'
FROM dbo.STG_Products
WHERE CategoryID IS NULL AND STG_Status = 'PENDING';

UPDATE dbo.STG_Products
SET    CategoryID    = '0',
       STG_IssueNote = ISNULL(STG_IssueNote, '') + '[P3] NULL CategoryID set to 0. '
WHERE  CategoryID IS NULL AND STG_Status = 'PENDING';
GO

-- P4: Fill NULL SupplierID with '0' (unknown supplier) and log
-- --------------------------------------------------------
INSERT INTO dbo.DQ_IssueLog
    (SourceTable, RowKey, ColumnName, IssueType, OriginalValue, ActionTaken)
SELECT
    'STG_Products', ProductID, 'SupplierID', 'NULL_VALUE', NULL, 'FILLED_DEFAULT:0'
FROM dbo.STG_Products
WHERE SupplierID IS NULL AND STG_Status = 'PENDING';

UPDATE dbo.STG_Products
SET    SupplierID    = '0',
       STG_IssueNote = ISNULL(STG_IssueNote, '') + '[P4] NULL SupplierID set to 0. '
WHERE  SupplierID IS NULL AND STG_Status = 'PENDING';
GO

-- P5: Flag negative UnitPrice — set to NULL (price unknown, not invalid)
-- --------------------------------------------------------
INSERT INTO dbo.DQ_IssueLog
    (SourceTable, RowKey, ColumnName, IssueType, OriginalValue, ActionTaken)
SELECT
    'STG_Products', ProductID, 'UnitPrice', 'INVALID_VALUE', UnitPrice, 'SET_TO_NULL'
FROM dbo.STG_Products
WHERE STG_Status = 'PENDING'
  AND ISNUMERIC(UnitPrice) = 1
  AND CAST(UnitPrice AS DECIMAL(10,2)) < 0;

UPDATE dbo.STG_Products
SET    UnitPrice     = NULL,
       STG_IssueNote = ISNULL(STG_IssueNote, '') + '[P5] Negative UnitPrice set to NULL. '
WHERE  STG_Status = 'PENDING'
  AND  ISNUMERIC(UnitPrice) = 1
  AND  CAST(UnitPrice AS DECIMAL(10,2)) < 0;
GO

-- P6: Flag zero UnitPrice — set to NULL
-- --------------------------------------------------------
INSERT INTO dbo.DQ_IssueLog
    (SourceTable, RowKey, ColumnName, IssueType, OriginalValue, ActionTaken)
SELECT
    'STG_Products', ProductID, 'UnitPrice', 'ZERO_VALUE', UnitPrice, 'SET_TO_NULL'
FROM dbo.STG_Products
WHERE STG_Status = 'PENDING'
  AND ISNUMERIC(UnitPrice) = 1
  AND CAST(UnitPrice AS DECIMAL(10,2)) = 0;

UPDATE dbo.STG_Products
SET    UnitPrice     = NULL,
       STG_IssueNote = ISNULL(STG_IssueNote, '') + '[P6] Zero UnitPrice set to NULL. '
WHERE  STG_Status = 'PENDING'
  AND  ISNUMERIC(UnitPrice) = 1
  AND  CAST(UnitPrice AS DECIMAL(10,2)) = 0;
GO

-- P7: Set negative UnitsInStock to '0'
-- --------------------------------------------------------
INSERT INTO dbo.DQ_IssueLog
    (SourceTable, RowKey, ColumnName, IssueType, OriginalValue, ActionTaken)
SELECT
    'STG_Products', ProductID, 'UnitsInStock', 'INVALID_VALUE', UnitsInStock, 'SET_TO_0'
FROM dbo.STG_Products
WHERE STG_Status = 'PENDING'
  AND ISNUMERIC(UnitsInStock) = 1
  AND CAST(UnitsInStock AS INT) < 0;

UPDATE dbo.STG_Products
SET    UnitsInStock  = '0',
       STG_IssueNote = ISNULL(STG_IssueNote, '') + '[P7] Negative UnitsInStock set to 0. '
WHERE  STG_Status = 'PENDING'
  AND  ISNUMERIC(UnitsInStock) = 1
  AND  CAST(UnitsInStock AS INT) < 0;
GO

-- ============================================================
-- Summary report after cleaning
-- ============================================================
SELECT 'STG_Customers' AS TableName, STG_Status, COUNT(*) AS [RowCount]
FROM dbo.STG_Customers GROUP BY STG_Status
UNION ALL
SELECT 'STG_Orders',   STG_Status, COUNT(*) FROM dbo.STG_Orders   GROUP BY STG_Status
UNION ALL
SELECT 'STG_Products', STG_Status, COUNT(*) FROM dbo.STG_Products  GROUP BY STG_Status
ORDER BY TableName, STG_Status;

SELECT IssueType, SourceTable, COUNT(*) AS IssueCount
FROM dbo.DQ_IssueLog
GROUP BY IssueType, SourceTable
ORDER BY SourceTable, IssueType;

PRINT '04_data_cleaning.sql completed successfully.';
PRINT 'Check the result sets above for PENDING/REJECTED counts and DQ_IssueLog summary.';
GO
