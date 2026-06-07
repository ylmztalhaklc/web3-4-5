-- ============================================================
-- 05_data_transformation.sql
-- Purpose : Apply business logic transformations to all rows
--           that survived cleaning (STG_Status = 'PENDING').
--           After all transformations are applied, rows are
--           promoted to STG_Status = 'CLEAN' and are ready
--           for the final load step.
--
-- Transformations applied:
--   T1 - Proper-case CompanyName
--   T2 - Proper-case City
--   T3 - Proper-case Country
--   T4 - Trim leading/trailing whitespace from all text columns
--   T5 - Normalize ProductName (LTRIM/RTRIM + proper-case first letter)
--   T6 - Ensure Discontinued in STG_Products is '0' or '1' only
--   T7 - Mark all remaining PENDING rows as CLEAN
-- ============================================================

USE Northwind;
GO

-- ============================================================
-- HELPER: Scalar function for simple proper-case conversion
-- (Capitalises first letter, lowercases the rest)
-- Only processes single words; multi-word strings get the
-- first word capitalised. Full title-case is handled inline.
-- ============================================================
IF OBJECT_ID('dbo.fn_ProperCase', 'FN') IS NOT NULL
    DROP FUNCTION dbo.fn_ProperCase;
GO

CREATE FUNCTION dbo.fn_ProperCase (@Input NVARCHAR(200))
RETURNS NVARCHAR(200)
AS
BEGIN
    IF @Input IS NULL RETURN NULL;
    RETURN UPPER(LEFT(LTRIM(@Input), 1))
         + LOWER(SUBSTRING(LTRIM(@Input), 2, LEN(LTRIM(@Input)) - 1));
END
GO

-- ============================================================
-- T1: Proper-case CompanyName in STG_Customers
--     e.g. "alfreds futterkiste" → "Alfreds futterkiste"
--     (First letter only — full title-case needs word splitting
--      which is out of scope for a student project)
-- ============================================================
UPDATE dbo.STG_Customers
SET    CompanyName = dbo.fn_ProperCase(LTRIM(RTRIM(CompanyName)))
WHERE  STG_Status = 'PENDING'
  AND  CompanyName IS NOT NULL;
GO

-- ============================================================
-- T2: Proper-case City in STG_Customers
--     e.g. "LONDON" → "London", "berlin" → "Berlin"
-- ============================================================
UPDATE dbo.STG_Customers
SET    City = dbo.fn_ProperCase(LTRIM(RTRIM(City)))
WHERE  STG_Status = 'PENDING'
  AND  City IS NOT NULL
  AND  City <> 'Unknown';
GO

-- ============================================================
-- T3: Proper-case Country in STG_Customers
--     Exceptions: 'USA' stays 'USA' (already an abbreviation)
-- ============================================================
UPDATE dbo.STG_Customers
SET    Country = CASE
                    WHEN UPPER(LTRIM(RTRIM(Country))) IN ('USA','UK','N/A','UNKNOWN') 
                        THEN UPPER(LTRIM(RTRIM(Country)))
                    ELSE dbo.fn_ProperCase(LTRIM(RTRIM(Country)))
                 END
WHERE  STG_Status = 'PENDING'
  AND  Country IS NOT NULL;
GO

-- ============================================================
-- T4: Trim whitespace from all NVARCHAR columns in all 3 STG tables
-- ============================================================

-- STG_Customers
UPDATE dbo.STG_Customers
SET    CustomerID   = LTRIM(RTRIM(CustomerID)),
       CompanyName  = LTRIM(RTRIM(CompanyName)),
       ContactName  = LTRIM(RTRIM(ContactName)),
       ContactTitle = LTRIM(RTRIM(ContactTitle)),
       Address      = LTRIM(RTRIM(Address)),
       City         = LTRIM(RTRIM(City)),
       PostalCode   = LTRIM(RTRIM(PostalCode)),
       Country      = LTRIM(RTRIM(Country)),
       Phone        = LTRIM(RTRIM(Phone))
WHERE  STG_Status = 'PENDING';

-- STG_Orders
UPDATE dbo.STG_Orders
SET    OrderID      = LTRIM(RTRIM(OrderID)),
       CustomerID   = LTRIM(RTRIM(CustomerID)),
       ShipName     = LTRIM(RTRIM(ShipName)),
       ShipAddress  = LTRIM(RTRIM(ShipAddress)),
       ShipCity     = LTRIM(RTRIM(ShipCity)),
       ShipCountry  = LTRIM(RTRIM(ShipCountry))
WHERE  STG_Status = 'PENDING';

-- STG_Products
UPDATE dbo.STG_Products
SET    ProductName     = LTRIM(RTRIM(ProductName)),
       QuantityPerUnit = LTRIM(RTRIM(QuantityPerUnit))
WHERE  STG_Status = 'PENDING';
GO

-- ============================================================
-- T5: Normalize ProductName — proper-case first letter
-- ============================================================
UPDATE dbo.STG_Products
SET    ProductName = dbo.fn_ProperCase(ProductName)
WHERE  STG_Status = 'PENDING'
  AND  ProductName IS NOT NULL;
GO

-- ============================================================
-- T6: Normalize Discontinued — only '0' or '1' allowed.
--     Any non-binary value is set to '0' (not discontinued).
-- ============================================================
UPDATE dbo.STG_Products
SET    Discontinued  = '0',
       STG_IssueNote = ISNULL(STG_IssueNote, '') + '[T6] Discontinued normalized to 0. '
WHERE  STG_Status = 'PENDING'
  AND  Discontinued NOT IN ('0', '1');
GO

-- ============================================================
-- T7: Mark all remaining PENDING rows as CLEAN
--     These rows passed all rejection checks and all
--     transformations have been applied.
-- ============================================================
UPDATE dbo.STG_Customers
SET    STG_Status = 'CLEAN'
WHERE  STG_Status = 'PENDING';

UPDATE dbo.STG_Orders
SET    STG_Status = 'CLEAN'
WHERE  STG_Status = 'PENDING';

UPDATE dbo.STG_Products
SET    STG_Status = 'CLEAN'
WHERE  STG_Status = 'PENDING';
GO

-- ============================================================
-- Summary: show final status distribution
-- ============================================================
SELECT 'STG_Customers' AS TableName, STG_Status, COUNT(*) AS [RowCount]
FROM dbo.STG_Customers GROUP BY STG_Status
UNION ALL
SELECT 'STG_Orders',   STG_Status, COUNT(*) FROM dbo.STG_Orders   GROUP BY STG_Status
UNION ALL
SELECT 'STG_Products', STG_Status, COUNT(*) FROM dbo.STG_Products  GROUP BY STG_Status
ORDER BY TableName, STG_Status;

-- Preview cleaned customer data
SELECT CustomerID, CompanyName, ContactName, City, Country, Phone, STG_Status
FROM dbo.STG_Customers
ORDER BY CustomerID;

PRINT '05_data_transformation.sql completed successfully.';
PRINT 'All PENDING rows promoted to CLEAN. Check result sets above.';
GO
