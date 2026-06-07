-- ============================================================
-- FILE    : 06_simulate_disaster.sql
-- PURPOSE : Simulate three realistic data loss scenarios in the
--           Northwind database to demonstrate why backups are
--           critical and to test the restore procedures.
--
-- WARNING : This script intentionally corrupts and deletes data.
--           Run ONLY after backups exist:
--             04_full_backup.sql     (required)
--             05_differential_backup.sql (required for Scenario B)
--
-- RECOVERY:
--   Scenarios A and C -> 07_restore_full.sql
--   Scenario B        -> 08_restore_diff.sql
--
-- NOTE: All three scenarios are run together in this script.
--   In a classroom demo, you may highlight and execute each
--   section individually using F5 on the selected text.
-- ============================================================

USE Northwind;
GO

-- ============================================================
-- PRE-DISASTER BASELINE
-- Save these numbers to compare with the post-restore state.
-- ============================================================

PRINT '=== PRE-DISASTER BASELINE ===';

SELECT
    'Customers'   AS [Table], COUNT(*) AS [Row Count] FROM Customers
UNION ALL
SELECT 'Orders',                COUNT(*) FROM Orders
UNION ALL
SELECT 'Products',              COUNT(*) FROM Products
UNION ALL
SELECT 'Order Details',         COUNT(*) FROM [Order Details];
GO

-- ============================================================
-- SCENARIO A: Accidental DELETE from Customers
-- -------------------------------------------------------
-- Situation : An employee mistakenly deletes five customer
--             records while cleaning up test data.
-- Affected  : Customers ALFKI, ANATR, ANTON, AROUT, BERGS
-- Cascade   : Their Orders and Order Details are removed first
--             to satisfy foreign key constraints.
-- Recovery  : 07_restore_full.sql
-- ============================================================

PRINT '=== SCENARIO A: Deleting 5 customer records ===';

-- Show the customers that will be deleted
SELECT CustomerID, CompanyName, ContactName, Country
FROM Customers
WHERE CustomerID IN ('ALFKI','ANATR','ANTON','AROUT','BERGS');
GO

-- Step 1: Remove Order Details rows linked to these customers' orders
DELETE od
FROM [Order Details] od
INNER JOIN Orders o ON od.OrderID = o.OrderID
WHERE o.CustomerID IN ('ALFKI','ANATR','ANTON','AROUT','BERGS');

-- Step 2: Remove the Orders themselves
DELETE FROM Orders
WHERE CustomerID IN ('ALFKI','ANATR','ANTON','AROUT','BERGS');

-- Step 3: Now remove the customer records
DELETE FROM Customers
WHERE CustomerID IN ('ALFKI','ANATR','ANTON','AROUT','BERGS');
GO

-- Confirm damage (expected: 86, was 91)
PRINT 'Customer count after delete (expected 86):';
SELECT COUNT(*) AS [Customers Remaining] FROM Customers;
GO

-- ============================================================
-- SCENARIO B: Wrong UPDATE on Products (Beverages zeroed out)
-- -------------------------------------------------------
-- Situation : A pricing migration script runs with a bug and
--             sets all Beverage category products to $0.00.
-- Affected  : Products WHERE CategoryID = 1 (Beverages, 12 rows)
-- Recovery  : 08_restore_diff.sql (full + differential)
-- ============================================================

PRINT '=== SCENARIO B: Setting all Beverage prices to 0.00 ===';

-- Show original prices before the wrong update
SELECT ProductID, ProductName, UnitPrice AS [Original Price]
FROM Products
WHERE CategoryID = 1
ORDER BY ProductID;
GO

-- The buggy update
UPDATE Products
SET UnitPrice = 0.00
WHERE CategoryID = 1;
GO

-- Confirm damage (all should show 0.00)
PRINT 'Beverage prices after wrong update (all should be 0.00):';
SELECT ProductID, ProductName, UnitPrice AS [Corrupted Price]
FROM Products
WHERE CategoryID = 1
ORDER BY ProductID;
GO

-- ============================================================
-- SCENARIO C: Accidental DELETE of Orders for customer VINET
-- -------------------------------------------------------
-- Situation : A developer runs a filtered DELETE without
--             properly testing the WHERE clause, removing an
--             entire customer's order history.
-- Affected  : All Orders and Order Details for CustomerID = VINET
-- Recovery  : 07_restore_full.sql
-- ============================================================

PRINT '=== SCENARIO C: Deleting all orders for customer VINET ===';

-- Show orders that will be deleted
SELECT o.OrderID, o.OrderDate, o.ShipName, o.ShipCity
FROM Orders o
WHERE o.CustomerID = 'VINET'
ORDER BY o.OrderDate;
GO

-- Step 1: Remove Order Details for VINET's orders
DELETE od
FROM [Order Details] od
INNER JOIN Orders o ON od.OrderID = o.OrderID
WHERE o.CustomerID = 'VINET';

-- Step 2: Remove the orders
DELETE FROM Orders
WHERE CustomerID = 'VINET';
GO

-- Confirm damage (expected: 0, was 5)
PRINT 'VINET order count after delete (expected 0):';
SELECT COUNT(*) AS [VINET Orders Remaining]
FROM Orders
WHERE CustomerID = 'VINET';
GO

-- ============================================================
-- POST-DISASTER SUMMARY
-- ============================================================

PRINT '=== POST-DISASTER SUMMARY ===';

SELECT
    'Customers'   AS [Table], COUNT(*) AS [Damaged Count] FROM Customers
UNION ALL
SELECT 'Orders',                COUNT(*) FROM Orders
UNION ALL
SELECT 'Products',              COUNT(*) FROM Products
UNION ALL
SELECT 'Order Details',         COUNT(*) FROM [Order Details];
GO

PRINT '======================================================';
PRINT 'All three disaster scenarios have been applied.';
PRINT 'The database is now in a corrupted/incomplete state.';
PRINT '';
PRINT 'To recover, run:';
PRINT '  07_restore_full.sql    (Scenarios A and C)';
PRINT '  08_restore_diff.sql    (Scenario B)';
PRINT '';
PRINT 'Run 09_validation_queries.sql after restore to verify.';
PRINT '======================================================';
GO
