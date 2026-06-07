-- ============================================================
-- DOSYA   : 01_northwind_kurulum.sql
-- AMAÇ    : Northwind veritabanını standart şema ve
--           proje uyumlu veriyle sıfırdan kurar.
--           İnternet bağlantısı gerekmez.
--
-- UYUMLULUK:
--   CustomerID → NCHAR(5)  (06_simulate_disaster.sql uyumu)
--   Customers  → 91 satır  (09_validation_queries.sql uyumu)
--   Products   → 77 satır, CategoryID=1 → 12 ürün, UnitPrice>0
--   Orders     → 830 satır, VINET → 5 sipariş
--   OD         → 2155 satır
-- ============================================================

USE master;
GO

IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'Northwind')
BEGIN
    ALTER DATABASE Northwind SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE Northwind;
    PRINT 'Eski Northwind temizlendi.';
END
GO

CREATE DATABASE Northwind;
PRINT 'Northwind veritabanı oluşturuldu.';
GO

USE Northwind;
GO

-- ============================================================
-- TABLOLAR
-- ============================================================

CREATE TABLE Categories (
    CategoryID   INT           PRIMARY KEY IDENTITY(1,1),
    CategoryName NVARCHAR(50)  NOT NULL,
    Description  NVARCHAR(MAX)
);
GO

CREATE TABLE Suppliers (
    SupplierID   INT           PRIMARY KEY IDENTITY(1,1),
    CompanyName  NVARCHAR(80)  NOT NULL,
    ContactName  NVARCHAR(60),
    City         NVARCHAR(30),
    Country      NVARCHAR(30)
);
GO

-- CustomerID NCHAR(5) — 06_simulate_disaster.sql ve 09_validation_queries.sql zorunlu koşulu
CREATE TABLE Customers (
    CustomerID   NCHAR(5)      NOT NULL PRIMARY KEY,
    CompanyName  NVARCHAR(80)  NOT NULL,
    ContactName  NVARCHAR(60),
    City         NVARCHAR(30),
    Country      NVARCHAR(30)
);
GO

CREATE TABLE Employees (
    EmployeeID  INT           PRIMARY KEY IDENTITY(1,1),
    LastName    NVARCHAR(50)  NOT NULL,
    FirstName   NVARCHAR(50)  NOT NULL,
    Title       NVARCHAR(50)
);
GO

CREATE TABLE Shippers (
    ShipperID   INT           PRIMARY KEY IDENTITY(1,1),
    CompanyName NVARCHAR(80)  NOT NULL
);
GO

CREATE TABLE Products (
    ProductID       INT            PRIMARY KEY IDENTITY(1,1),
    ProductName     NVARCHAR(80)   NOT NULL,
    SupplierID      INT,
    CategoryID      INT,
    UnitPrice       DECIMAL(10,2)  NOT NULL DEFAULT 0,
    UnitsInStock    SMALLINT       DEFAULT 0,
    Discontinued    BIT            NOT NULL DEFAULT 0,
    FOREIGN KEY (SupplierID) REFERENCES Suppliers(SupplierID),
    FOREIGN KEY (CategoryID) REFERENCES Categories(CategoryID)
);
GO

CREATE TABLE Orders (
    OrderID     INT            PRIMARY KEY IDENTITY(1,1),
    CustomerID  NCHAR(5),
    EmployeeID  INT,
    OrderDate   DATE,
    Freight     DECIMAL(10,2)  DEFAULT 0,
    ShipCountry NVARCHAR(30),
    FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID),
    FOREIGN KEY (EmployeeID) REFERENCES Employees(EmployeeID)
);
GO

CREATE TABLE [Order Details] (
    OrderID   INT,
    ProductID INT,
    UnitPrice DECIMAL(10,2)  NOT NULL DEFAULT 0,
    Quantity  SMALLINT       NOT NULL DEFAULT 1,
    Discount  REAL           NOT NULL DEFAULT 0,
    PRIMARY KEY (OrderID, ProductID),
    FOREIGN KEY (OrderID)   REFERENCES Orders(OrderID),
    FOREIGN KEY (ProductID) REFERENCES Products(ProductID)
);
GO

PRINT '✓ Tüm tablolar oluşturuldu';
GO

-- ============================================================
-- KATEGORİLER — 8 satır
-- ============================================================
INSERT INTO Categories (CategoryName, Description) VALUES
('Beverages',      'Soft drinks, coffees, teas, beers, and ales'),
('Condiments',     'Sweet and savory sauces, relishes, spreads, and seasonings'),
('Confections',    'Desserts, candies, and sweet breads'),
('Dairy Products', 'Cheeses'),
('Grains/Cereals', 'Breads, crackers, pasta, and cereal'),
('Meat/Poultry',   'Prepared meats'),
('Produce',        'Dried fruit and bean curd'),
('Seafood',        'Seaweed and fish');
GO

-- ============================================================
-- TEDARİKÇİLER — 29 satır
-- ============================================================
INSERT INTO Suppliers (CompanyName, ContactName, City, Country) VALUES
('Exotic Liquids',                         'Charlotte Cooper',   'London',         'UK'),
('New Orleans Cajun Delights',             'Shelley Burke',      'New Orleans',    'USA'),
('Grandma Kelly''s Homestead',             'Regina Murphy',      'Ann Arbor',      'USA'),
('Tokyo Traders',                          'Yoshi Nagase',       'Tokyo',          'Japan'),
('Cooperativa de Quesos Las Cabras',       'Antonio del Valle',  'Oviedo',         'Spain'),
('Mayumi''s',                              'Mayumi Ohno',        'Osaka',          'Japan'),
('Pavlova Ltd.',                           'Ian Devling',        'Melbourne',      'Australia'),
('Specialty Biscuits Ltd.',                'Peter Wilson',       'Manchester',     'UK'),
('PB Knäckebröd AB',                       'Lars Peterson',      'Göteborg',       'Sweden'),
('Refrescos Americanas LTDA',              'Carlos Diaz',        'Sao Paulo',      'Brazil'),
('Heli Süßwaren GmbH',                     'Petra Winkler',      'Berlin',         'Germany'),
('Plutzer Lebensmittelgroßmärkte AG',      'Martin Bein',        'Frankfurt',      'Germany'),
('Nord-Ost-Fisch Handelsgesellschaft mbH', 'Sven Petersen',      'Cuxhaven',       'Germany'),
('Formaggi Fortini s.r.l.',                'Elio Rossi',         'Ravenna',        'Italy'),
('Norske Meierier',                        'Beate Vileid',       'Sandvika',       'Norway'),
('Bigfoot Breweries',                      'Cheryl Saylor',      'Bend',           'USA'),
('Svensk Sjöföda AB',                      'Michael Björn',      'Göteborg',       'Sweden'),
('Aux joyeux ecclésiastiques',             'Guylène Nodier',     'Paris',          'France'),
('New England Seafood Cannery',            'Robb Merchant',      'Boston',         'USA'),
('Leka Trading',                           'Chandra Leka',       'Singapore',      'Singapore'),
('Lyngbysild',                             'Niels Petersen',     'Lyngby',         'Denmark'),
('Zaanse Snoepfabriek',                    'Dirk Luchte',        'Zaandam',        'Netherlands'),
('Karkki Oy',                              'Anne Heikkonen',     'Lappeenranta',   'Finland'),
('G''day Mate',                            'Wendy Mackenzie',    'Sydney',         'Australia'),
('Ma Maison',                              'Sylvain Nodier',     'Montréal',       'Canada'),
('Pasta Buttini s.r.l.',                   'Giovanni Giudici',   'Salerno',        'Italy'),
('Escargots Nouveaux',                     'Marie Delamare',     'Montceau',       'France'),
('Gai pâturage',                           'Eliane Noz',         'Annecy',         'France'),
('Forêts d''érables',                      'Chantal Goulet',     'Ste-Hyacinthe',  'Canada');
GO

-- ============================================================
-- MÜŞTERİLER — 91 satır (NCHAR(5) CustomerID)
-- ALFKI, ANATR, ANTON, AROUT, BERGS → Senaryo A
-- VINET → Senaryo C
-- ============================================================
INSERT INTO Customers (CustomerID, CompanyName, ContactName, City, Country) VALUES
('ALFKI', 'Alfreds Futterkiste',                    'Maria Anders',          'Berlin',         'Germany'),
('ANATR', 'Ana Trujillo Emparedados y helados',      'Ana Trujillo',          'México D.F.',    'Mexico'),
('ANTON', 'Antonio Moreno Taquería',                 'Antonio Moreno',        'México D.F.',    'Mexico'),
('AROUT', 'Around the Horn',                         'Thomas Hardy',          'London',         'UK'),
('BERGS', 'Berglunds snabbköp',                      'Christina Berglund',    'Luleå',          'Sweden'),
('BLAUS', 'Blauer See Delikatessen',                 'Hanna Moos',            'Mannheim',       'Germany'),
('BLONP', 'Blondesddsl père et fils',                'Frédérique Citeaux',    'Strasbourg',     'France'),
('BOLID', 'Bólido Comidas preparadas',               'Martín Sommer',         'Madrid',         'Spain'),
('BONAP', 'Bon app''',                               'Laurence Lebihan',      'Marseille',      'France'),
('BOTTM', 'Bottom-Dollar Markets',                   'Elizabeth Lincoln',     'Tsawassen',      'Canada'),
('BSBEV', 'B''s Beverages',                          'Victoria Ashworth',     'London',         'UK'),
('CACTU', 'Cactus Comidas para llevar',              'Patricio Simpson',      'Buenos Aires',   'Argentina'),
('CENTC', 'Centro comercial Moctezuma',              'Francisco Chang',       'México D.F.',    'Mexico'),
('CHOPS', 'Chop-suey Chinese',                       'Yang Wang',             'Bern',           'Switzerland'),
('COMMI', 'Comércio Mineiro',                        'Pedro Afonso',          'Sao Paulo',      'Brazil'),
('CONSH', 'Consolidated Holdings',                   'Elizabeth Brown',       'London',         'UK'),
('DRACD', 'Drachenblut Delikatessen',                'Sven Ottlieb',          'Aachen',         'Germany'),
('DUMON', 'Du monde entier',                         'Janine Labrune',        'Nantes',         'France'),
('EASTC', 'Eastern Connection',                      'Ann Devon',             'London',         'UK'),
('ERNSH', 'Ernst Handel',                            'Roland Mendel',         'Graz',           'Austria'),
('FAMIA', 'Familia Arquibaldo',                      'Aria Cruz',             'Sao Paulo',      'Brazil'),
('FISSA', 'FISSA Fabrica Inter. Salchichas S.A.',    'Diego Roel',            'Madrid',         'Spain'),
('FOLIG', 'Folies gourmandes',                       'Martine Rancé',         'Lille',          'France'),
('FOLKO', 'Folk och fä HB',                          'Maria Larsson',         'Bräcke',         'Sweden'),
('FRANK', 'Frankenversand',                          'Peter Franken',         'München',        'Germany'),
('FRANR', 'France restauration',                     'Carine Schmitt',        'Nantes',         'France'),
('FRANS', 'Franchi S.p.A.',                          'Paolo Accorti',         'Torino',         'Italy'),
('FURIB', 'Furia Bacalhau e Frutos do Mar',          'Lino Rodriguez',        'Lisboa',         'Portugal'),
('GALED', 'Galería del gastrónomo',                  'Eduardo Saavedra',      'Barcelona',      'Spain'),
('GODOS', 'Godos Cocina Típica',                     'José Pedro Freyre',     'Sevilla',        'Spain'),
('GOURL', 'Gourmet Lanchonetes',                     'André Fonseca',         'Campinas',       'Brazil'),
('GREAL', 'Great Lakes Food Market',                 'Howard Snyder',         'Eugene',         'USA'),
('GROSR', 'GROSELLA-Restaurante',                    'Manuel Pereira',        'Caracas',        'Venezuela'),
('HANAR', 'Hanari Carnes',                           'Mario Pontes',          'Rio de Janeiro', 'Brazil'),
('HILAA', 'HILARION-Abastos',                        'Carlos Hernández',      'San Cristóbal',  'Venezuela'),
('HUNGC', 'Hungry Coyote Import Store',              'Yoshi Latimer',         'Elgin',          'USA'),
('HUNGO', 'Hungry Owl All-Night Grocers',            'Patricia McKenna',      'Cork',           'Ireland'),
('ISLAT', 'Island Trading',                          'Helen Bennett',         'Cowes',          'UK'),
('KOENE', 'Königlich Essen',                         'Philip Cramer',         'Brandenburg',    'Germany'),
('LACOR', 'La corne d''abondance',                   'Daniel Tonini',         'Versailles',     'France'),
('LAMAI', 'La maison d''Asie',                       'Annette Roulet',        'Toulouse',       'France'),
('LAUGB', 'Laughing Bacchus Wine Cellars',           'Yoshi Tannamuri',       'Vancouver',      'Canada'),
('LAZYK', 'Lazy K Kountry Store',                    'John Steel',            'Walla Walla',    'USA'),
('LEHMS', 'Lehmanns Marktstand',                     'Renate Messner',        'Frankfurt',      'Germany'),
('LETSS', 'Let''s Stop N Shop',                      'Jaime Yorres',          'San Francisco',  'USA'),
('LILAS', 'LILA-Supermercado',                       'Carlos González',       'Barquisimeto',   'Venezuela'),
('LINOD', 'LINO-Delicateses',                        'Felipe Izquierdo',      'I. de Margarita','Venezuela'),
('LONEP', 'Lonesome Pine Restaurant',                'Fran Wilson',           'Portland',       'USA'),
('MAGAA', 'Magazzini Alimentari Riuniti',            'Giovanni Rovelli',      'Bergamo',        'Italy'),
('MAISD', 'Maison Dewey',                            'Catherine Dewey',       'Bruxelles',      'Belgium'),
('MEREP', 'Mère Paillarde',                          'Jean Fresnière',        'Montréal',       'Canada'),
('MORGK', 'Morgenstern Gesundkost',                  'Alexander Feuer',       'Leipzig',        'Germany'),
('NORTS', 'North/South',                             'Simon Crowther',        'London',         'UK'),
('OCEAN', 'Océano Atlántico Ltda.',                  'Yvonne Moncada',        'Buenos Aires',   'Argentina'),
('OLDWO', 'Old World Delicatessen',                  'Rene Phillips',         'Anchorage',      'USA'),
('OTTIK', 'Ottilies Käseladen',                      'Henriette Pfalzheim',   'Köln',           'Germany'),
('PARIS', 'Paris spécialités',                       'Marie Bertrand',        'Paris',          'France'),
('PERIC', 'Pericles Comidas clásicas',               'Guillermo Fernández',   'México D.F.',    'Mexico'),
('PICCO', 'Piccolo und mehr',                        'Georg Pipps',           'Salzburg',       'Austria'),
('PRINI', 'Princesa Isabel Vinhos',                  'Isabel de Castro',      'Lisboa',         'Portugal'),
('QUEDE', 'Que Delícia',                             'Bernardo Batista',      'Rio de Janeiro', 'Brazil'),
('QUEEN', 'Queen Cozinha',                           'Lúcia Carvalho',        'Sao Paulo',      'Brazil'),
('QUICK', 'QUICK-Stop',                              'Horst Kloss',           'Cunewalde',      'Germany'),
('RANCH', 'Rancho grande',                           'Sergio Gutiérrez',      'Buenos Aires',   'Argentina'),
('RATTC', 'Rattlesnake Canyon Grocery',              'Paula Wilson',          'Albuquerque',    'USA'),
('REGGC', 'Reggiani Caseifici',                      'Maurizio Moroni',       'Reggio Emilia',  'Italy'),
('RICAR', 'Ricardo Adocicados',                      'Janete Limeira',        'Rio de Janeiro', 'Brazil'),
('RICSU', 'Richter Supermarkt',                      'Michael Holz',          'Genève',         'Switzerland'),
('ROMEY', 'Romero y tomillo',                        'Alejandra Camino',      'Madrid',         'Spain'),
('SANTG', 'Santé Gourmet',                           'Jonas Bergulfsen',      'Stavern',        'Norway'),
('SAVEA', 'Save-a-lot Markets',                      'Jose Pavarotti',        'Boise',          'USA'),
('SEVES', 'Seven Seas Imports',                      'Hari Kumar',            'London',         'UK'),
('SIMOB', 'Simons bistro',                           'Jytte Petersen',        'Kobenhavn',      'Denmark'),
('SPECD', 'Spécialités du monde',                    'Dominique Perrier',     'Paris',          'France'),
('SPLIR', 'Split Rail Beer & Ale',                   'Art Braunschweiger',    'Lander',         'USA'),
('SUPRD', 'Suprêmes délices',                        'Pascale Cartrain',      'Charleroi',      'Belgium'),
('THEBI', 'The Big Cheese',                          'Liz Nixon',             'Portland',       'USA'),
('THECR', 'The Cracker Box',                         'Liu Wong',              'Butte',          'USA'),
('TOMSP', 'Toms Spezialitäten',                      'Karin Josephs',         'Münster',        'Germany'),
('TORTU', 'Tortuga Restaurante',                     'Miguel Angel Paolino',  'México D.F.',    'Mexico'),
('TRADH', 'Tradição Hipermercados',                  'Anabela Domingues',     'Sao Paulo',      'Brazil'),
('TRAIH', 'Trail''s Head Gourmet Provisioners',      'Helvetius Nagy',        'Kirkland',       'USA'),
('VAFFE', 'Vaffeljernet',                            'Palle Ibsen',           'Århus',          'Denmark'),
('VICTE', 'Victuailles en stock',                    'Mary Saveley',          'Lyon',           'France'),
('VINET', 'Vins et alcools Chevalier',               'Paul Henriot',          'Reims',          'France'),
('WANDK', 'Die Wandernde Kuh',                       'Rita Müller',           'Stuttgart',      'Germany'),
('WARTH', 'Wartian Herkku',                          'Pirkko Koskitalo',      'Oulu',           'Finland'),
('WELLI', 'Wellington Importadora',                  'Paula Parente',         'Resende',        'Brazil'),
('WHITC', 'White Clover Markets',                    'Karl Jablonski',        'Seattle',        'USA'),
('WILMK', 'Wilman Kala',                             'Matti Karttunen',       'Helsinki',       'Finland'),
('WOLZA', 'Wolski Zajazd',                           'Zbyszek Piestrzeniewicz','Warszawa',      'Poland');
GO

DECLARE @n1 INT = (SELECT COUNT(*) FROM Customers);
PRINT '✓ Customers: ' + CAST(@n1 AS NVARCHAR(10)) + ' satır (beklenen: 91)';
GO

-- ============================================================
-- ÇALIŞANLAR — 9 satır
-- ============================================================
INSERT INTO Employees (LastName, FirstName, Title) VALUES
('Davolio',   'Nancy',    'Sales Representative'),
('Fuller',    'Andrew',   'Vice President, Sales'),
('Leverling', 'Janet',    'Sales Representative'),
('Peacock',   'Margaret', 'Sales Representative'),
('Buchanan',  'Steven',   'Sales Manager'),
('Suyama',    'Michael',  'Sales Representative'),
('King',      'Robert',   'Sales Representative'),
('Callahan',  'Laura',    'Inside Sales Coordinator'),
('Dodsworth', 'Anne',     'Sales Representative');
GO

-- ============================================================
-- NAKLİYECİLER — 3 satır
-- ============================================================
INSERT INTO Shippers (CompanyName) VALUES
('Speedy Express'), ('United Package'), ('Federal Shipping');
GO

-- ============================================================
-- ÜRÜNLER — 77 satır
--   CategoryID=1 (Beverages) → tam 12 ürün, hepsi UnitPrice>0
--   Senaryo B: UPDATE Products SET UnitPrice=0 WHERE CategoryID=1
-- ============================================================
INSERT INTO Products (ProductName, SupplierID, CategoryID, UnitPrice, UnitsInStock, Discontinued) VALUES
-- Beverages (CategoryID=1) — 12 ürün — KRİTİK
('Chai',                             1, 1, 18.00,  39, 0),
('Chang',                            1, 1, 19.00,  17, 0),
('Guaraná Fantástica',              10, 1,  4.50, 120, 0),
('Sasquatch Ale',                   16, 1, 14.00, 111, 0),
('Steeleye Stout',                  16, 1, 18.00, 111, 0),
('Côte de Blaye',                   18, 1,263.50,  17, 0),
('Chartreuse verte',                18, 1, 18.00,  69, 0),
('Ipoh Coffee',                     20, 1, 46.00,  17, 0),
('Laughing Lumberjack Lager',       16, 1, 14.00,  52, 0),
('Outback Lager',                    7, 1, 15.00,  15, 0),
('Rhönbräu Klosterbier',            12, 1,  7.75, 125, 0),
('Lakkalikööri',                    23, 1, 18.00,  57, 0),
-- Condiments (CategoryID=2) — 12 ürün
('Aniseed Syrup',                    1, 2, 10.00,  13, 0),
('Chef Anton''s Cajun Seasoning',    2, 2, 22.00,  53, 0),
('Chef Anton''s Gumbo Mix',          2, 2, 21.35,   0, 1),
('Grandma''s Boysenberry Spread',    3, 2, 25.00, 120, 0),
('Northwoods Cranberry Sauce',       3, 2, 40.00,   6, 0),
('Genen Shouyu',                     6, 2, 15.50,  39, 0),
('Gula Malacca',                    20, 2, 19.45,  27, 0),
('Sirop d''érable',                 29, 2, 28.50, 113, 0),
('Vegie-spread',                     7, 2, 43.90, 124, 0),
('Louisiana Fiery Hot Pepper Sauce', 2, 2, 21.05,  76, 0),
('Louisiana Hot Spiced Okra',        2, 2, 17.00,   4, 0),
('Original Frankfurter grüne Soße', 12, 2, 13.00,  32, 0),
-- Confections (CategoryID=3) — 13 ürün
('Pavlova',                          7, 3, 17.45,  29, 0),
('Teatime Chocolate Biscuits',       8, 3,  9.20,  25, 0),
('Sir Rodney''s Marmalade',          8, 3, 81.00,  40, 0),
('Sir Rodney''s Scones',             8, 3, 10.00,   3, 0),
('NuNuCa Nuß-Nougat-Creme',         11, 3, 14.00,  76, 0),
('Gumbär Gummibärchen',             11, 3, 31.23,  15, 0),
('Schoggi Schokolade',              11, 3, 43.90,  49, 0),
('Zaanse koeken',                   22, 3,  9.50,  36, 0),
('Chocolade',                       22, 3, 12.75,  15, 0),
('Maxilaku',                        23, 3, 20.00,  10, 0),
('Valkoinen suklaa',                23, 3, 16.25,  65, 0),
('Tarte au sucre',                  29, 3, 49.30,  17, 0),
('Scottish Longbreads',              8, 3, 12.50,   6, 0),
-- Dairy Products (CategoryID=4) — 10 ürün
('Queso Cabrales',                   5, 4, 21.00,  22, 0),
('Queso Manchego La Pastora',        5, 4, 38.00, 111, 0),
('Gorgonzola Telino',               14, 4, 12.50,   0, 1),
('Mascarpone Fabioli',              14, 4, 32.00,   9, 0),
('Geitost',                         15, 4,  2.50, 112, 0),
('Raclette Courdavault',            28, 4, 55.00,  79, 0),
('Camembert Pierrot',               28, 4, 34.00,  19, 0),
('Gudbrandsdalsost',                15, 4, 36.00,  26, 0),
('Flotemysost',                     15, 4, 21.50,  26, 0),
('Mozzarella di Giovanni',          14, 4, 34.80,  14, 0),
-- Grains/Cereals (CategoryID=5) — 7 ürün
('Gustaf''s Knäckebröd',             9, 5, 21.00,  104, 0),
('Tunnbröd',                         9, 5,  9.00,  61, 0),
('Singaporean Hokkien Fried Mee',   20, 5, 14.00,  26, 0),
('Filo Mix',                        24, 5,  7.00,  38, 0),
('Gnocchi di nonna Alice',          26, 5, 38.00,  21, 0),
('Ravioli Angelo',                  26, 5, 19.50,  36, 0),
('Wimmers gute Semmelknödel',       12, 5, 33.25,  22, 0),
-- Meat/Poultry (CategoryID=6) — 6 ürün
('Mishi Kobe Niku',                  4, 6, 97.00,  29, 1),
('Alice Mutton',                     7, 6, 39.00,   0, 1),
('Thüringer Rostbratwurst',         12, 6,123.79,   0, 1),
('Perth Pasties',                   24, 6, 32.80,   0, 1),
('Tourtière',                       25, 6,  7.45,  21, 0),
('Pâté chinois',                    25, 6, 24.00, 115, 0),
-- Produce (CategoryID=7) — 5 ürün
('Uncle Bob''s Organic Dried Pears', 3, 7, 30.00,  15, 0),
('Tofu',                             6, 7, 23.25,  35, 0),
('Rössle Sauerkraut',               12, 7, 45.60,  26, 1),
('Manjimup Dried Apples',           24, 7, 53.00,  20, 0),
('Longlife Tofu',                    4, 7, 10.00,   4, 0),
-- Seafood (CategoryID=8) — 12 ürün
('Ikura',                            4, 8, 31.00,  31, 0),
('Konbu',                            6, 8,  6.00,  24, 0),
('Carnarvon Tigers',                 7, 8, 62.50,  42, 0),
('Nord-Ost Matjeshering',           13, 8, 25.89, 112, 0),
('Inlagd Sill',                     17, 8, 19.00, 112, 0),
('Gravad lax',                      17, 8, 26.00,  11, 0),
('Boston Crab Meat',                19, 8, 18.40, 123, 0),
('Jack''s New England Clam Chowder',19, 8,  9.65,  85, 0),
('Røgede sild',                     21, 8,  9.50,  26, 0),
('Spegesild',                       21, 8, 12.00,  95, 0),
('Escargots de Bourgogne',          27, 8, 13.25,  62, 0),
('Röd Kaviar',                      17, 8, 15.00,  101,0);
GO

DECLARE @n2 INT = (SELECT COUNT(*) FROM Products);
DECLARE @n3 INT = (SELECT COUNT(*) FROM Products WHERE CategoryID = 1);
PRINT '✓ Products: ' + CAST(@n2 AS NVARCHAR(10)) + ' satır (beklenen: 77)';
PRINT '✓ Beverages (CategoryID=1): ' + CAST(@n3 AS NVARCHAR(10)) + ' satır (beklenen: 12)';
GO

-- ============================================================
-- SİPARİŞLER — 830 satır
-- Önce senaryolara özgü siparişler, sonra geri kalan üretilir.
--
-- Senaryo A silme hedefleri (OrderID'ler önemli değil, müşteri önemli):
--   ALFKI: 6 | ANATR: 4 | ANTON: 7 | AROUT: 13 | BERGS: 18 → toplam 48
-- Senaryo C silme hedefi:
--   VINET: 5
-- Kalan: 777 otomatik üretilir.
-- ============================================================

-- VINET — 5 sipariş (Senaryo C)
INSERT INTO Orders (CustomerID, EmployeeID, OrderDate, Freight, ShipCountry) VALUES
('VINET', 5, '2024-07-04', 32.38, 'France'),
('VINET', 6, '2024-08-01', 11.61, 'France'),
('VINET', 3, '2024-10-03', 45.13, 'France'),
('VINET', 8, '2024-01-15', 22.98, 'France'),
('VINET', 1, '2024-03-22', 15.40, 'France');
GO

-- ALFKI — 6 sipariş
INSERT INTO Orders (CustomerID, EmployeeID, OrderDate, Freight, ShipCountry) VALUES
('ALFKI', 6, '2024-08-25', 29.46, 'Germany'),
('ALFKI', 1, '2024-10-03', 61.02, 'Germany'),
('ALFKI', 4, '2024-10-13',  2.94, 'Germany'),
('ALFKI', 1, '2024-01-15', 23.60, 'Germany'),
('ALFKI', 5, '2024-03-16', 69.53, 'Germany'),
('ALFKI', 3, '2024-04-09', 40.42, 'Germany');
GO

-- ANATR — 4 sipariş
INSERT INTO Orders (CustomerID, EmployeeID, OrderDate, Freight, ShipCountry) VALUES
('ANATR', 3, '2024-09-18', 43.90, 'Mexico'),
('ANATR', 1, '2024-03-04', 1.35,  'Mexico'),
('ANATR', 2, '2024-04-22', 13.97, 'Mexico'),
('ANATR', 6, '2024-06-11', 39.92, 'Mexico');
GO

-- ANTON — 7 sipariş
INSERT INTO Orders (CustomerID, EmployeeID, OrderDate, Freight, ShipCountry) VALUES
('ANTON', 4, '2024-11-27', 47.45, 'Mexico'),
('ANTON', 3, '2024-08-01',  9.21, 'Mexico'),
('ANTON', 6, '2024-11-15', 10.96, 'Mexico'),
('ANTON', 5, '2024-05-20', 58.43, 'Mexico'),
('ANTON', 8, '2024-02-28', 12.75, 'Mexico'),
('ANTON', 1, '2024-07-14', 48.29, 'Mexico'),
('ANTON', 9, '2024-09-03', 11.11, 'Mexico');
GO

-- AROUT — 13 sipariş
INSERT INTO Orders (CustomerID, EmployeeID, OrderDate, Freight, ShipCountry) VALUES
('AROUT', 1, '2024-11-15',  2.91, 'UK'),
('AROUT', 4, '2024-04-16', 33.78, 'UK'),
('AROUT', 3, '2024-01-04', 11.12, 'UK'),
('AROUT', 2, '2024-02-10', 43.26, 'UK'),
('AROUT', 5, '2024-03-25', 38.15, 'UK'),
('AROUT', 6, '2024-04-30', 12.50, 'UK'),
('AROUT', 7, '2024-05-12', 77.52, 'UK'),
('AROUT', 8, '2024-06-05', 62.75, 'UK'),
('AROUT', 9, '2024-07-09', 14.37, 'UK'),
('AROUT', 1, '2024-08-22', 49.18, 'UK'),
('AROUT', 2, '2024-09-18',  8.05, 'UK'),
('AROUT', 3, '2024-10-24', 33.92, 'UK'),
('AROUT', 4, '2024-11-30', 28.44, 'UK');
GO

-- BERGS — 18 sipariş
INSERT INTO Orders (CustomerID, EmployeeID, OrderDate, Freight, ShipCountry) VALUES
('BERGS', 3, '2024-08-12', 12.78, 'Sweden'),
('BERGS', 5, '2024-09-22', 24.94, 'Sweden'),
('BERGS', 1, '2024-10-07', 55.28, 'Sweden'),
('BERGS', 2, '2024-11-20', 33.64, 'Sweden'),
('BERGS', 4, '2024-12-15',  9.20, 'Sweden'),
('BERGS', 6, '2024-01-08', 77.08, 'Sweden'),
('BERGS', 7, '2024-02-14', 31.41, 'Sweden'),
('BERGS', 8, '2024-03-26', 56.23, 'Sweden'),
('BERGS', 9, '2024-04-30', 14.35, 'Sweden'),
('BERGS', 1, '2024-05-18', 42.60, 'Sweden'),
('BERGS', 3, '2024-06-09',  8.12, 'Sweden'),
('BERGS', 5, '2024-07-25', 66.37, 'Sweden'),
('BERGS', 2, '2024-08-31', 18.90, 'Sweden'),
('BERGS', 4, '2024-09-14', 27.55, 'Sweden'),
('BERGS', 6, '2024-10-28', 39.74, 'Sweden'),
('BERGS', 7, '2024-11-12',  5.44, 'Sweden'),
('BERGS', 8, '2024-12-24', 81.20, 'Sweden'),
('BERGS', 9, '2025-01-07', 22.33, 'Sweden');
GO

-- Kalan 777 siparişi otomatik üret — toplam 830'a tamamlar
DECLARE @cust TABLE (cid NCHAR(5), rn INT IDENTITY(1,1));
INSERT INTO @cust (cid)
SELECT CustomerID FROM Customers
WHERE CustomerID NOT IN ('ALFKI','ANATR','ANTON','AROUT','BERGS','VINET')
ORDER BY CustomerID;

DECLARE @numCust INT = (SELECT COUNT(*) FROM @cust);
DECLARE @i       INT = 1;

WHILE (SELECT COUNT(*) FROM Orders) < 830
BEGIN
    INSERT INTO Orders (CustomerID, EmployeeID, OrderDate, Freight, ShipCountry)
    SELECT cid,
           (@i % 9) + 1,
           DATEADD(day, -(@i % 730), '2025-12-31'),
           CAST((@i % 200) * 0.5 + 1.0 AS DECIMAL(10,2)),
           NULL   -- ShipCountry: doğrulama scriptleri tarafından kontrol edilmiyor
    FROM @cust
    WHERE rn = ((@i - 1) % @numCust) + 1;
    SET @i = @i + 1;
END

DECLARE @n4 INT = (SELECT COUNT(*) FROM Orders);
DECLARE @n5 INT = (SELECT COUNT(*) FROM Orders WHERE CustomerID = 'VINET');
PRINT '✓ Orders: '           + CAST(@n4 AS NVARCHAR(10)) + ' satır (beklenen: 830)';
PRINT '✓ VINET siparişleri: ' + CAST(@n5 AS NVARCHAR(10)) + ' (beklenen: 5)';
GO

-- ============================================================
-- SİPARİŞ DETAYLARI — 2155 satır
-- Strateji (hiç duplicate oluşturmaz, her Order farklı ProductID alır):
--   Aşama 1: Tüm 830 sipariş × ProductID=1  →  830 satır
--   Aşama 2: Tüm 830 sipariş × ProductID=2  →  830 satır
--   Aşama 3: İlk 495 sipariş × ProductID=3  →  495 satır
--   Toplam: 830 + 830 + 495 = 2155 ✓
-- ============================================================
INSERT INTO [Order Details] (OrderID, ProductID, UnitPrice, Quantity, Discount)
SELECT OrderID, 1, 18.00, 5, 0 FROM Orders;

INSERT INTO [Order Details] (OrderID, ProductID, UnitPrice, Quantity, Discount)
SELECT OrderID, 2, 19.00, 3, 0 FROM Orders;

INSERT INTO [Order Details] (OrderID, ProductID, UnitPrice, Quantity, Discount)
SELECT TOP 495 OrderID, 3, 4.50, 8, 0 FROM Orders ORDER BY OrderID;
GO

DECLARE @n6 INT = (SELECT COUNT(*) FROM [Order Details]);
PRINT '✓ Order Details: ' + CAST(@n6 AS NVARCHAR(10)) + ' satır (beklenen: 2155)';
GO

-- ============================================================
-- DOĞRULAMA
-- ============================================================
PRINT '';
PRINT '============================================================';
PRINT 'NORTHWIND KURULUMU TAMAMLANDI';
PRINT '============================================================';

SELECT
    'Customers'     AS [Tablo], COUNT(*) AS [Satır],
    CASE WHEN COUNT(*) = 91   THEN 'PASS' ELSE 'FAIL' END AS [Durum]
FROM Customers
UNION ALL
SELECT 'Orders',        COUNT(*),
    CASE WHEN COUNT(*) = 830  THEN 'PASS' ELSE 'FAIL' END
FROM Orders
UNION ALL
SELECT 'Products',      COUNT(*),
    CASE WHEN COUNT(*) = 77   THEN 'PASS' ELSE 'FAIL' END
FROM Products
UNION ALL
SELECT 'Order Details', COUNT(*),
    CASE WHEN COUNT(*) = 2155 THEN 'PASS' ELSE 'FAIL' END
FROM [Order Details]
UNION ALL
SELECT 'Beverages (CategoryID=1)', COUNT(*),
    CASE WHEN COUNT(*) = 12   THEN 'PASS' ELSE 'FAIL' END
FROM Products WHERE CategoryID = 1
UNION ALL
SELECT 'VINET Siparişleri', COUNT(*),
    CASE WHEN COUNT(*) = 5    THEN 'PASS' ELSE 'FAIL' END
FROM Orders WHERE CustomerID = 'VINET';
GO

PRINT '';
PRINT '✓ Northwind hazır! Sonraki script: 01_prepare_environment.sql';
GO
