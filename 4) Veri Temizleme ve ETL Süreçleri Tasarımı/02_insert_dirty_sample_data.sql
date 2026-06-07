-- ============================================================
-- 02_insert_dirty_sample_data.sql
-- Purpose : Insert intentionally dirty rows into the three
--           RAW tables. Every data quality problem type used
--           in the cleaning script is represented here.
--           Do NOT fix anything in this file — the point is
--           to have visible, ugly data that the pipeline cleans.
--
-- Problems included:
--   Customers : NULL CustomerID, NULL ContactName, NULL Country,
--               4 different phone formats, city typos,
--               country name inconsistencies, exact duplicates,
--               near-duplicates (case/spacing)
--   Orders    : NULL OrderDate, future OrderDate, ShippedDate
--               before OrderDate, orphan CustomerID (no match),
--               negative Freight, NULL ShipCity/ShipCountry
--   Products  : NULL ProductName, zero/negative UnitPrice,
--               NULL CategoryID, NULL SupplierID, negative
--               UnitsInStock, near-duplicate product names
-- ============================================================

USE Northwind;
GO

-- Clear any previous test data (safe re-run)
DELETE FROM dbo.RAW_Customers;
DELETE FROM dbo.RAW_Orders;
DELETE FROM dbo.RAW_Products;
GO

-- ============================================================
-- RAW_Customers  (22 rows: 16 base + 3 exact dupes + 3 others)
-- ============================================================
INSERT INTO dbo.RAW_Customers
    (CustomerID, CompanyName, ContactName, ContactTitle, Address, City, Region, PostalCode, Country, Phone, Fax)
VALUES
-- 1  Normal row (reference)
('ALFKI',  'Alfreds Futterkiste',       'Maria Anders',    'Sales Rep',    'Obere Str. 57',     'Berlin',    NULL, '12209', 'Germany',       '030-0074321',      '030-0076545'),
-- 2  NULL ContactName
('ANATR',  'Ana Trujillo Emp.',         NULL,              'Owner',        'Avda. Constitución','Mexico City',NULL,'05021', 'Mexico',        '555-047-2900',     '(5) 555-3745'),
-- 3  City typo: Londn
('ANTON',  'Antonio Moreno Taquería',   'Antonio Moreno',  'Owner',        'Mataderos 2312',    'Londn',     NULL, '05023', 'UK',            '555-039-3200',     NULL),
-- 4  City typo: Berln
('AROUT',  'Around the Horn',           'Thomas Hardy',    'Sales Rep',    '120 Hanover Sq.',   'Berln',     NULL, 'WA1 1DP','Germany',      '(171) 555-7788',   '(171) 555-6750'),
-- 5  City ALL CAPS, Country inconsistency: USA
('BERGS',  'Berglunds snabbköp',        'Christina Berglund','Order Admin','Berguvsvägen 8',    'LONDON',    NULL, 'S-958 22','USA',          '0921-12 34 65',    '0921-12 34 67'),
-- 6  Country: United States (should normalize to USA)
('BLAUS',  'Blauer See Delikatessen',   'Hanna Moos',      'Sales Rep',    'Forsterstr. 57',    'Paris',     NULL, '68306', 'United States', '555-062-1084',     '0621-08924'),
-- 7  Country: US (should normalize to USA)
('BLONP',  'Blondesddsl père et fils',  'Frédérique Citeaux','Mktg Mgr',  '24, place Kléber',  'Strasbourg',NULL, '67000', 'US',            '556.015.3100',     '88.60.15.32'),
-- 8  NULL Country
('BOLID',  'Bólido Comidas preparadas', 'Martín Sommer',   'Owner',        'C/ Araquil, 67',    'Madrid',    NULL, '28023', NULL,            '555-091-5522',     '(91) 555 91 99'),
-- 9  Phone format: +1-555-555-555-0101 (international prefix style)
('BONAP',  'Bon app''',                 'Laurence Lebihan','Owner',        '12, rue des Bouchers','Marseille',NULL,'13008', 'France',        '+1-555-555-0101',  NULL),
-- 10 Phone format: (555) 012-3456
('BOTTM',  'Bottom-Dollar Markets',     'Elizabeth Lincoln','Acct Mgr',   '23 Tsawassen Blvd.','Tsawassen', 'BC','T2F 8M4','Canada',        '(555) 012-3456',   '(604) 555-3745'),
-- 11 Phone format: 555.012.3456
('BSBEV',  'B''s Beverages',            'Victoria Ashworth','Sales Rep',  'Fauntleroy Circus',  'London',   NULL, 'EC2 5NT','UK',            '555.012.3456',     NULL),
-- 12 Phone format: 5550123456 (no separators)
('CACTU',  'Cactus Comidas para llevar','Patricio Simpson','Sales Agent', 'Cerrito 333',        'Buenos Aires',NULL,'1010','Argentina',     '5550123456',       '(1) 135-4892'),
-- 13 NULL CustomerID (should be rejected)
(NULL,     'Ghost Company A',           'John Doe',        'Manager',      '1 Unknown St',      'Unknown',   NULL, '00000', 'USA',           '555-000-0000',     NULL),
-- 14 NULL CustomerID (should be rejected)
(NULL,     'Ghost Company B',           'Jane Doe',        'Director',     '2 Unknown Ave',     'Unknown',   NULL, '00001', 'USA',           '555-000-0001',     NULL),
-- 15 City typo: paris (all lowercase)
('CENTC',  'Centro comercial Moctezuma','Francisco Chang', 'Mktg Mgr',    'Sierras de Granada 9987','paris',NULL,'05022','Mexico',         '555-033-9200',     '(5) 555-7293'),
-- 16 City typo: new york (mixed case issue)
('CHOPS',  'Chop-suey Chinese',         'Yang Wang',       'Owner',        'Hauptstr. 29',      'new york',  NULL, '3012',  'Switzerland',   '0452-076545',      NULL),
-- 17 NULL ContactName + NULL Phone
('COMMI',  'Comércio Mineiro',          NULL,              'Sales Assoc.', 'Av. dos Lusíadas, 23','São Paulo',NULL,'05432-043','Brazil',    NULL,               NULL),
-- 18 NULL ContactName + NULL Country
('CONSH',  'Consolidated Holdings',     NULL,              'Sales Mgr',    'Berkeley Gardens 12','London',  NULL, 'WX1 6LT', NULL,           '(171) 555-2282',   '(171) 555-9199'),
-- 19 Normal row
('DRACD',  'Drachenblut Delikatessen',  'Sven Ottlieb',    'Order Admin',  'Walserweg 21',      'Aachen',   NULL, '52066', 'Germany',       '0241-039123',      '0241-059428'),
-- 20 EXACT DUPLICATE of row 1
('ALFKI',  'Alfreds Futterkiste',       'Maria Anders',    'Sales Rep',    'Obere Str. 57',     'Berlin',   NULL, '12209', 'Germany',       '030-0074321',      '030-0076545'),
-- 21 EXACT DUPLICATE of row 1
('ALFKI',  'Alfreds Futterkiste',       'Maria Anders',    'Sales Rep',    'Obere Str. 57',     'Berlin',   NULL, '12209', 'Germany',       '030-0074321',      '030-0076545'),
-- 22 NEAR-DUPLICATE of row 1 (CompanyName different case, trailing space)
('ALFKI',  'alfreds futterkiste ',      'Maria Anders',    'Sales Rep',    'Obere Str. 57',     'Berlin',   NULL, '12209', 'Germany',       '030-0074321',      '030-0076545');
GO

-- ============================================================
-- RAW_Orders  (27 rows)
-- ============================================================
INSERT INTO dbo.RAW_Orders
    (OrderID, CustomerID, EmployeeID, OrderDate, RequiredDate, ShippedDate, ShipVia, Freight, ShipName, ShipAddress, ShipCity, ShipRegion, ShipPostalCode, ShipCountry)
VALUES
-- 1  Normal order
('10001', 'ALFKI', '5', '2024-01-15', '2024-02-15', '2024-01-22', '1', '32.50',  'Alfreds Futterkiste', 'Obere Str. 57',     'Berlin',      NULL, '12209', 'Germany'),
-- 2  Normal order
('10002', 'ANATR', '3', '2024-01-18', '2024-02-18', '2024-01-25', '2', '11.61',  'Ana Trujillo Emp.',   'Avda. Constitución','Mexico City', NULL, '05021', 'Mexico'),
-- 3  NULL OrderDate (should be rejected)
('10003', 'ANTON', '1', NULL,          '2024-02-20', '2024-01-30', '1', '65.83',  'Antonio Moreno',      'Mataderos 2312',    'London',      NULL, '05023', 'UK'),
-- 4  NULL OrderDate (should be rejected)
('10004', 'AROUT', '4', NULL,          '2024-03-01', NULL,         '3', '41.34',  'Around the Horn',     '120 Hanover Sq.',   'London',      NULL, 'WA1 1DP','UK'),
-- 5  Future OrderDate 2099 (should be rejected)
('10005', 'BERGS', '2', '2099-06-15', '2099-07-15', NULL,         '2', '51.30',  'Berglunds snabbköp',  'Berguvsvägen 8',   'Luleå',       NULL, 'S-958 22','Sweden'),
-- 6  Future OrderDate 2099 (should be rejected)
('10006', 'BLAUS', '6', '2099-12-31', '2100-01-31', NULL,         '1', '8.74',   'Blauer See Delikat.', 'Forsterstr. 57',    'Mannheim',    NULL, '68306', 'Germany'),
-- 7  ShippedDate BEFORE OrderDate (should be rejected)
('10007', 'BLONP', '5', '2024-03-10', '2024-04-10', '2024-03-01', '2', '22.98',  'Blondesddsl père',    '24, place Kléber',  'Strasbourg',  NULL, '67000', 'France'),
-- 8  ShippedDate BEFORE OrderDate (should be rejected)
('10008', 'BOLID', '3', '2024-04-05', '2024-05-05', '2024-03-20', '3', '148.33', 'Bólido Comidas',      'C/ Araquil, 67',    'Madrid',      NULL, '28023', 'Spain'),
-- 9  Orphan CustomerID (XXXXX does not exist)
('10009', 'XXXXX', '1', '2024-02-14', '2024-03-14', '2024-02-20', '1', '13.97',  'Nonexistent Corp',    '1 Fake Street',     'Nowhere',     NULL, '00000', 'Unknown'),
-- 10 Orphan CustomerID (ZZZZZ does not exist)
('10010', 'ZZZZZ', '2', '2024-03-01', '2024-04-01', NULL,         '2', '81.91',  'Another Fake Co',     '2 Imaginary Blvd',  'Nowhere',     NULL, '00001', 'Unknown'),
-- 11 Negative Freight
('10011', 'BONAP', '4', '2024-01-20', '2024-02-20', '2024-01-28', '1', '-15.50', 'Bon app''',           '12, rue des Bouchers','Marseille', NULL, '13008', 'France'),
-- 12 NULL ShipCity
('10012', 'BOTTM', '5', '2024-02-01', '2024-03-01', '2024-02-10', '3', '4.56',   'Bottom-Dollar Mkt',  '23 Tsawassen Blvd.',NULL,          'BC', 'T2F 8M4','Canada'),
-- 13 NULL ShipCountry
('10013', 'BSBEV', '2', '2024-02-15', '2024-03-15', '2024-02-22', '2', '36.71',  'B''s Beverages',      'Fauntleroy Circus', 'London',      NULL, 'EC2 5NT', NULL),
-- 14 NULL ShipCity + NULL ShipCountry
('10014', 'CACTU', '6', '2024-03-05', '2024-04-05', '2024-03-12', '1', '19.42',  'Cactus Comidas',      'Cerrito 333',       NULL,          NULL, '1010',    NULL),
-- 15 Normal order
('10015', 'CENTC', '3', '2024-03-20', '2024-04-20', '2024-03-27', '2', '55.09',  'Centro comercial',    'Sierras de Granada','Mexico City', NULL, '05022', 'Mexico'),
-- 16 Normal order
('10016', 'CHOPS', '1', '2024-04-01', '2024-05-01', '2024-04-08', '3', '26.18',  'Chop-suey Chinese',   'Hauptstr. 29',      'Bern',        NULL, '3012',  'Switzerland'),
-- 17 Normal order
('10017', 'COMMI', '5', '2024-04-15', '2024-05-15', NULL,         '1', '17.55',  'Comércio Mineiro',    'Av. dos Lusíadas',  'São Paulo',   NULL, '05432', 'Brazil'),
-- 18 Normal order
('10018', 'DRACD', '4', '2024-05-01', '2024-06-01', '2024-05-09', '2', '88.40',  'Drachenblut Delikat.','Walserweg 21',     'Aachen',      NULL, '52066', 'Germany'),
-- 19 Freight = 0 (edge case, not an error but flagged)
('10019', 'ALFKI', '2', '2024-05-10', '2024-06-10', '2024-05-17', '1', '0',      'Alfreds Futterkiste', 'Obere Str. 57',     'Berlin',      NULL, '12209', 'Germany'),
-- 20 Normal order
('10020', 'BERGS', '3', '2024-05-20', '2024-06-20', '2024-05-27', '3', '12.75',  'Berglunds snabbköp',  'Berguvsvägen 8',   'Luleå',       NULL, 'S-958 22','Sweden'),
-- 21 NULL EmployeeID (fill with default 0)
('10021', 'BLAUS', NULL,'2024-06-01', '2024-07-01', NULL,         '2', '44.20',  'Blauer See Delikat.', 'Forsterstr. 57',    'Mannheim',    NULL, '68306', 'Germany'),
-- 22 Normal order
('10022', 'ANTON', '1', '2024-06-10', '2024-07-10', '2024-06-18', '1', '72.96',  'Antonio Moreno',      'Mataderos 2312',    'Mexico City', NULL, '05023', 'Mexico'),
-- 23 Normal order
('10023', 'ANATR', '6', '2024-07-01', '2024-08-01', '2024-07-09', '3', '9.01',   'Ana Trujillo Emp.',   'Avda. Constitución','Mexico City', NULL, '05021', 'Mexico'),
-- 24 NULL Freight (fill with 0)
('10024', 'AROUT', '5', '2024-07-15', '2024-08-15', NULL,         '2', NULL,     'Around the Horn',     '120 Hanover Sq.',   'London',      NULL, 'WA1 1DP','UK'),
-- 25 Normal order
('10025', 'BONAP', '4', '2024-08-01', '2024-09-01', '2024-08-09', '1', '33.60',  'Bon app''',           '12, rue des Bouchers','Marseille', NULL, '13008', 'France'),
-- 26 DUPLICATE of row 1
('10001', 'ALFKI', '5', '2024-01-15', '2024-02-15', '2024-01-22', '1', '32.50',  'Alfreds Futterkiste', 'Obere Str. 57',     'Berlin',      NULL, '12209', 'Germany'),
-- 27 DUPLICATE of row 2
('10002', 'ANATR', '3', '2024-01-18', '2024-02-18', '2024-01-25', '2', '11.61',  'Ana Trujillo Emp.',   'Avda. Constitución','Mexico City', NULL, '05021', 'Mexico');
GO

-- ============================================================
-- RAW_Products  (18 rows)
-- ============================================================
INSERT INTO dbo.RAW_Products
    (ProductID, ProductName, SupplierID, CategoryID, QuantityPerUnit, UnitPrice, UnitsInStock, UnitsOnOrder, ReorderLevel, Discontinued)
VALUES
-- 1  Normal product
('1',  'Chai',              '1', '1', '10 boxes x 20 bags', '18.00',  '39',  '0',  '10', '0'),
-- 2  Near-duplicate: CHAI (all caps)
('2',  'CHAI',              '1', '1', '10 boxes x 20 bags', '18.00',  '39',  '0',  '10', '0'),
-- 3  Near-duplicate: chai with trailing space
('3',  'chai ',             '1', '1', '10 boxes x 20 bags', '18.00',  '39',  '0',  '10', '0'),
-- 4  Normal product
('4',  'Chang',             '1', '1', '24 - 12 oz bottles', '19.00', '17',  '40', '25', '0'),
-- 5  NULL ProductName (should be rejected)
('5',  NULL,                '2', '2', '12 - 550 ml bottles','21.35', '13',  '70', '25', '0'),
-- 6  NULL ProductName (should be rejected)
('6',  NULL,                '3', '2', '48 - 6 oz jars',     '25.00', '53',  '0',  '0',  '0'),
-- 7  NULL CategoryID (assign default 0)
('7',  'Pavlova',           '2', NULL,'32 - 500 g boxes',   '17.45', '29',  '0',  '10', '0'),
-- 8  NULL CategoryID (assign default 0)
('8',  'Meat Spread',       '3', NULL,'24 - 150 g jars',    '31.23', '42',  '0',  '0',  '1'),
-- 9  NULL CategoryID (assign default 0)
('9',  'Tunnbröd',          '4', NULL,'12 - 250 g pkgs.',   '9.00',  '61',  '0',  '25', '0'),
-- 10 NULL CategoryID (assign default 0)
('10', 'Singaporean Noodles','5',NULL,'32 - 1 kg pkgs.',    '14.00', '26',  '0',  '0',  '1'),
-- 11 NULL SupplierID
('11', 'Genen Shouyu',      NULL,'2', '24 - 250 ml bottles','13.00', '39',  '0',  '5',  '0'),
-- 12 NULL SupplierID
('12', 'Sir Rodney''s Scones',NULL,'3','24 pkgs. x 4 pieces','10.00','3',  '40', '5',  '0'),
-- 13 Negative UnitPrice (should be flagged)
('13', 'Ikura',             '4', '8', '12 - 200 ml jars',   '-31.00','31',  '0',  '0',  '0'),
-- 14 Zero UnitPrice (should be flagged)
('14', 'Queso Cabrales',    '5', '4', '1 kg pkg.',          '0',     '22',  '30', '30', '0'),
-- 15 Negative UnitsInStock
('15', 'Queso Manchego',    '5', '4', '10 - 500 g pkgs.',   '38.00', '-5',  '0',  '0',  '0'),
-- 16 Normal product
('16', 'Konbu',             '6', '8', '2 kg box',           '6.00',  '24',  '0',  '5',  '0'),
-- 17 NULL SupplierID + NULL CategoryID
('17', 'Tofu',              NULL, NULL,'40 - 100 g pkgs.',  '23.25', '35',  '0',  '0',  '0'),
-- 18 Normal product
('18', 'Geitost',           '15','4', '500 g',              '2.50',  '112', '0',  '20', '0');
GO

PRINT '02_insert_dirty_sample_data.sql completed successfully.';
PRINT 'Rows inserted — Customers: 22, Orders: 27, Products: 18';
PRINT 'Dirty data patterns embedded: NULL IDs, city typos, 4 phone formats,';
PRINT 'future dates, ShipDate violations, orphan FKs, negative values,';
PRINT 'NULL ProductNames, NULL CategoryIDs, near-duplicate products.';
GO
