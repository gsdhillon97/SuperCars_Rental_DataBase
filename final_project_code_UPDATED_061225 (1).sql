--Final Project:  Hypercars Expo



-- Drop the database if it already exists to ensure a clean slate
DROP DATABASE IF EXISTS Hypercars
GO

-- Create the database if it does not already exist
CREATE DATABASE Hypercars
GO

-- Switch to the Hypercars database
USE Hypercars
GO



-- Drop tables in reverse dependency order to avoid foreign key errors
DROP TABLE IF EXISTS rentals
DROP TABLE IF EXISTS purchases
DROP TABLE IF EXISTS transactions
DROP TABLE IF EXISTS transaction_types
DROP TABLE IF EXISTS locations
DROP TABLE IF EXISTS states
DROP TABLE IF EXISTS customers
DROP TABLE IF EXISTS vehicles
GO


-- 1. Customers Table
CREATE TABLE customers
(
    customer_id INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    customer_firstname VARCHAR(50) NOT NULL,
    customer_lastname VARCHAR(50) NOT NULL,
    customer_phone CHAR(12) NOT NULL,
    customer_street_number VARCHAR(10) NOT NULL,
    customer_street_name VARCHAR(50) NOT NULL,
    customer_city VARCHAR(50) NOT NULL,
    customer_state CHAR(2) NOT NULL,
    customer_zip CHAR(5) NOT NULL,
    customer_license_number CHAR(9) NOT NULL, -- Adjusted length based on sample data (777111177)
    customer_email VARCHAR(100) NOT NULL
);
GO

-- 2. Vehicles Table (Hypercars)
CREATE TABLE vehicles
(
    vehicle_id INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    make VARCHAR(50) NOT NULL,
    model VARCHAR(50) NOT NULL,
    engine VARCHAR(3) NOT NULL, 
    top_speed_kmh CHAR(3) NOT NULL, 
    displacement_cc VARCHAR(10) NOT NULL,
    horse_power VARCHAR(10) NOT NULL
);
GO

-- 3. States Table (Lookup for Locations)
CREATE TABLE states
(
    state_code CHAR(2) PRIMARY KEY CHECK (state_code LIKE '[A-Z][A-Z]'),
    state_name VARCHAR(50) NOT NULL CONSTRAINT CHK_States_Name CHECK (LEN(state_name) >= 3)
);
GO

-- 4. Locations Table
CREATE TABLE locations
(
    location_id INT IDENTITY(101,1) PRIMARY KEY,
    location_name VARCHAR(100) NOT NULL,
    address_street_number VARCHAR(10) NOT NULL, -- Changed to VARCHAR as street numbers can be alphanumeric (e.g., '64')
    address_street_name VARCHAR(100) NOT NULL,
    city VARCHAR(50) NOT NULL,
    state_code CHAR(2) NOT NULL,
    zip_code CHAR(5) NOT NULL CHECK (zip_code LIKE '[0-9][0-9][0-9][0-9][0-9]'),
    CONSTRAINT FK_Locations_States FOREIGN KEY (state_code) REFERENCES states(state_code)
);
GO

-- 5. Transaction Types Table (Lookup)
CREATE TABLE transaction_types
(
    transaction_type_code VARCHAR(20) PRIMARY KEY CHECK (transaction_type_code IN ('Purchase', 'Rental'))
);
GO

-- 6. Transactions Table (Central Hub for all transactions)
CREATE TABLE transactions
(
    transaction_id INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    customer_id INT NOT NULL,
    vehicle_id INT NOT NULL,
    transaction_type_code VARCHAR(20) NOT NULL,
    transaction_date DATE NOT NULL,
    transaction_total_amount DECIMAL(18, 2) NOT NULL, -- Increased precision for large purchase amounts
    payment_method VARCHAR(50) NULL,
    duration_days INT NULL, -- Only used for rentals, so can be NULL
    notes TEXT NULL,

    CONSTRAINT FK_Transactions_Customers FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    CONSTRAINT FK_Transactions_Vehicles FOREIGN KEY (vehicle_id) REFERENCES vehicles(vehicle_id),
    CONSTRAINT FK_Transactions_TransactionType FOREIGN KEY (transaction_type_code) REFERENCES transaction_types(transaction_type_code)
);
GO

-- 7. Rentals Table (Subtype of Transactions)
CREATE TABLE rentals
(
    -- The rental_id here will be its own PK and also an FK to the central transactions.transaction_id
    rental_id INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    transaction_id INT NOT NULL UNIQUE, -- Foreign Key to Transactions, ensures 1:1 relationship for rental types
    price_per_day DECIMAL(10, 2) NOT NULL,
    rental_days INT NOT NULL,
    tax_amount DECIMAL(10, 2) NOT NULL,
    total_rental_price DECIMAL(10, 2) NOT NULL,
    pickup_location_id INT NOT NULL,
    dropoff_location_id INT NOT NULL,
    rental_start_date DATE NOT NULL,
    rental_end_date DATE NOT NULL,

    CONSTRAINT FK_Rentals_Transactions FOREIGN KEY (transaction_id) REFERENCES transactions(transaction_id),
    CONSTRAINT FK_Rentals_PickupLocation FOREIGN KEY (pickup_location_id) REFERENCES locations(location_id),
    CONSTRAINT FK_Rentals_DropoffLocation FOREIGN KEY (dropoff_location_id) REFERENCES locations(location_id)
);
GO

--Creating Rental Trigger
--This trigger will prevent a customer from buyiong or renting a vehicle that's currently rented/purchased on or between rental start and rental end dates
CREATE TRIGGER trg_prevent_rental_overlap
ON rentals
AFTER INSERT
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM rentals r
        JOIN transactions t_existing ON r.transaction_id = t_existing.transaction_id
        JOIN inserted i ON 1 = 1
        JOIN transactions t_new ON i.transaction_id = t_new.transaction_id
        WHERE 
            t_existing.vehicle_id = t_new.vehicle_id
            AND r.transaction_id != i.transaction_id -- Exclude the row being inserted
            AND (
                i.rental_start_date BETWEEN r.rental_start_date AND r.rental_end_date
                OR i.rental_end_date BETWEEN r.rental_start_date AND r.rental_end_date
                OR r.rental_start_date BETWEEN i.rental_start_date AND i.rental_end_date
            )
    )
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50001, 'Rental conflict: Vehicle is already rented for the given date range.', 1;
    END
END;
GO
-- 8. Purchases Table (Subtype of Transactions)
CREATE TABLE purchases
(
    -- The purchase_id here will be its own PK and also an FK to the central transactions.transaction_id
    purchase_id INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    transaction_id INT NOT NULL UNIQUE, -- Foreign Key to Transactions, ensures 1:1 relationship for purchase types
    purchase_price DECIMAL(18, 2) NOT NULL, -- Increased precision for large purchase amounts
    tax_amount DECIMAL(10, 2) NOT NULL,
    total_purchase_amount DECIMAL(18, 2) NOT NULL,
    purchase_location_id INT NOT NULL,
    purchase_date DATE NOT NULL,

    CONSTRAINT FK_Purchases_Transactions FOREIGN KEY (transaction_id) REFERENCES transactions(transaction_id),
    CONSTRAINT FK_Purchases_Location FOREIGN KEY (purchase_location_id) REFERENCES locations(location_id)
);
GO

--Creating purchase trigger
--This trigger will prevent a customer from purchasing a vehicle that has already been sold
CREATE TRIGGER trg_prevent_duplicate_purchase
ON purchases
AFTER INSERT
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM purchases p
        JOIN transactions t_existing ON p.transaction_id = t_existing.transaction_id
        JOIN inserted i ON 1 = 1
        JOIN transactions t_new ON i.transaction_id = t_new.transaction_id
        WHERE 
            t_existing.vehicle_id = t_new.vehicle_id
            AND p.transaction_id != i.transaction_id -- Exclude current insert
    )
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50002, 'Purchase conflict: This vehicle has already been sold.', 1;
    END
END;
GO
-- Inserting into Customers Table
INSERT INTO customers (customer_firstname, customer_lastname, customer_phone, customer_street_number, customer_street_name, customer_city, customer_state, customer_zip, customer_license_number, customer_email)
VALUES
('Goku', 'Kakarot', '777-777-7777', '500', 'Mountain Area Earth', 'Paradise', 'NV', '11111', '777111177', 'Gokudbz@yahoo.com'),
('Vegeta', 'Saiyan', '787-900-0087', '35', 'Grand Highway', 'West City', 'CA', '77777', '937820381', 'planetprince@yahoo.com'),
('Monkey', 'Luffy', '699-888-0102', '40', 'Blue bay street', 'Grand Line', 'SC', '12345', '294592044', 'Mdluffy@grandline.com'),
('Jason', 'Duval', '919-898-7463', '789', 'Keys Bay', 'Vice City', 'FL', '91947', '465738656', 'JDuvalvice@yahoo.com'),
('Jon', 'Smith', '111-777-0382', '777', 'Great coast bay', 'Hilo', 'HI', '96720', '568432881', 'jonAloha@gmail.com'),
('Kat', 'Zhurun', '778-930-3004', '637', 'Palm Drive', 'Jersey Shore', 'NJ', '17740', '8297777', 'katbrownkitty@gmail.com'),
('Gary', 'Dhillon', '219-456-9000', '23', 'Stonewall Drive', 'Seattle', 'WA', '98102', '1346722', 'Gdhillon@yahoo.com'),
('Alaa', 'Alawaad', '314-877-8787', '215', 'Claystone Street', 'Las Vegas', 'NV', '88909', '3456777','Alalaa@yahoo.com'),
('Lance','Vance', '555-078-8000', '234', 'Vice Point', 'Miami', 'FL', '91948', '8974411', 'LanceV@yahoo.com'),
('Cloud', 'Strife', '722-876-7676', '111', 'Nibelheim', 'Atlanta', 'GA', '30033','9776137','LanceV@yahoo.com');
GO

-- Inserting into Vehicles Table
INSERT INTO vehicles (make, model, engine, top_speed_kmh, displacement_cc, horse_power)
VALUES
('Ferrari', 'Aperta', 'V12', '350', '6262', '800'),
('Lamborghini', 'SIAN FKP 37', 'V12', '350', '6498', '770'),
('Lamborghini', 'Temerario', 'V12', '350', '6498', '770'),
('Lamborghini', 'Revuelto', 'V12', '350', '6498', '770'),
('Lamborghini', 'Huracan Evo Spyder', 'V12', '350', '6498', '770'),
('Lamborghini', 'SIAN Roadster', 'V12', '350', '6498', '770'),
('McLaren', 'W1', 'V8', '380', '3994', '800'),
('McLaren', 'P1', 'V8', '380', '3994', '800'),
('McLaren', 'Speedtail', 'V8', '402', '3994', '1050'),
('McLaren', 'F1', 'V8', '380', '3994', '800'),
('McLaren', 'Artura Spider', 'V8', '380', '3994', '800'),
('McLaren', '750S Spider', 'V8', '380', '3994', '800'),
('Bugatti', 'Centodieci EB110', 'W16', '420', '7993', '1500'),
('Bugatti', 'W16 Mistral', 'W16', '420', '7993', '1500'),
('Bugatti', 'Tourbillon', 'W16', '420', '7993', '1500'),
('Bugatti', 'La Voiture Noire', 'W16', '420', '7993', '1500'),
('Bugatti', 'Chiron Super Sport 300', 'W16', '490', '7993', '1600'),
('Koenigsegg', 'Jesko Absolut', 'V8', '500', '5000', '1600'),
('Koenigsegg', 'Jesko Absolut', 'V8', '460', '5000', '1360'),
('Koenigsegg', 'Regera', 'V8', '460', '5000', '1360'),
('Koenigsegg', 'ONE:1', 'V8', '460', '5000', '1360'),
('Koenigsegg', 'Agera', 'V8', '460', '5000', '1360'),
('Pagani', 'Huayra R', 'V12', '355', '5980', '850'),
('Aston Martin', 'Valkyrie', 'V12', '350', '6498', '1160');
GO

-- Inserting into States Table (using StateCodes from Locations and Customers)
INSERT INTO states(state_code, state_name)
VALUES
('NV', 'Nevada'), ('CA', 'California'), ('SC', 'South Carolina'), ('FL', 'Florida'),
('NY', 'New York'), ('TX', 'Texas'), ('IL', 'Illinois'), ('HI', 'Hawaii');
GO

-- Inserting into Locations Table
INSERT INTO locations (location_name, address_street_number, address_street_name, city, state_code, zip_code)
VALUES
('New York Supercar Center', '245', 'Maple Ave', 'New York', 'NY', '10001'),
('Los Angeles Elite Motors', '800', 'Broadway', 'Los Angeles', 'CA', '90012'),
('Austin Exotic Garage', '37', 'Pine St', 'Austin', 'TX', '73301'),
('Chicago Luxe Rentals', '1201', 'Chestnut Rd', 'Chicago', 'IL', '60614'),
('Miami Dream Drives', '64', 'Hillcrest Dr', 'Miami', 'FL', '33101');
GO

-- Inserting into Transaction Types Table
INSERT INTO transaction_types (transaction_type_code)
VALUES ('Rental'), ('Purchase');
GO

-- Inserting into Transactions, then Rentals/Purchases based on the new schema design.
-- This requires careful coordination of IDs and linking.

-- Transaction 1: Rental (Customer 3, Vehicle 2)
INSERT INTO transactions(customer_id, vehicle_id, transaction_type_code, transaction_date, transaction_total_amount, payment_method, duration_days, notes)
VALUES (3, 2, 'Rental', '2025-06-10', 3038.00, 'Credit Card', 2, 'Rental of Lamborghini SIAN FKP 37');
DECLARE @tx_id_rental1 INT = SCOPE_IDENTITY();
INSERT INTO rentals(transaction_id, price_per_day, rental_days, tax_amount, total_rental_price, pickup_location_id, dropoff_location_id, rental_start_date, rental_end_date)
VALUES (@tx_id_rental1, 1400.00, 2, 238.00, 3038.00, 101, 101, '2025-06-10', '2025-06-12');

-- Transaction 2: Rental (Customer 1, Vehicle 3)
INSERT INTO transactions(customer_id, vehicle_id, transaction_type_code, transaction_date, transaction_total_amount, payment_method, duration_days, notes)
VALUES (1, 3, 'Rental', '2025-06-15', 5208.00, 'Debit Card', 4, 'Rental of Lamborghini Temerario');
DECLARE @tx_id_rental2 INT = SCOPE_IDENTITY();
INSERT INTO rentals (transaction_id, price_per_day, rental_days, tax_amount, total_rental_price, pickup_location_id, dropoff_location_id, rental_start_date, rental_end_date)
VALUES (@tx_id_rental2, 1200.00, 4, 408.00, 5208.00, 102, 102, '2025-06-15', '2025-06-19');

-- Transaction 3: Rental (Customer 4, Vehicle 7)
INSERT INTO transactions(customer_id, vehicle_id, transaction_type_code, transaction_date, transaction_total_amount, payment_method, duration_days, notes)
VALUES (4, 7, 'Rental', '2025-06-20', 1627.50, 'Credit Card', 1, 'Rental of McLaren W1');
DECLARE @tx_id_rental3 INT = SCOPE_IDENTITY();
INSERT INTO rentals(transaction_id, price_per_day, rental_days, tax_amount, total_rental_price, pickup_location_id, dropoff_location_id, rental_start_date, rental_end_date)
VALUES (@tx_id_rental3, 1500.00, 1, 127.50, 1627.50, 103, 103, '2025-06-20', '2025-06-21');

-- Transaction 4: Purchase (Customer 2, Vehicle 1)
INSERT INTO transactions(customer_id, vehicle_id, transaction_type_code, transaction_date, transaction_total_amount, payment_method, duration_days, notes)
VALUES (2, 1, 'Purchase', '2025-05-10', 2950000.00, 'Bank Transfer', NULL, 'Purchase of Ferrari Aperta');
DECLARE @tx_id_purchase1 INT = SCOPE_IDENTITY();
INSERT INTO purchases(transaction_id, purchase_price, tax_amount, total_purchase_amount, purchase_location_id, purchase_date)
VALUES (@tx_id_purchase1, 2500000.00, 450000.00, 2950000.00, 103, '2025-05-10');

-- Transaction 5: Purchase (Customer 5, Vehicle 13)
INSERT INTO transactions (customer_id, vehicle_id, transaction_type_code, transaction_date, transaction_total_amount, payment_method, duration_days, notes)
VALUES (5, 13, 'Purchase', '2025-05-12', 10350000.00, 'Wire Transfer', NULL, 'Purchase of Bugatti Centodieci EB110');
DECLARE @tx_id_purchase2 INT = SCOPE_IDENTITY();
INSERT INTO purchases (transaction_id, purchase_price, tax_amount, total_purchase_amount, purchase_location_id, purchase_date)
VALUES (@tx_id_purchase2, 9000000.00, 1350000.00, 10350000.00, 104, '2025-05-12');
GO




-- Business Question 1: Customers and their Transacted Hypercars 
-- 1. List all customers and the hypercars they have ever rented or purchased.
-- Business Rule Applied: "A customer may rent or purchase one or more vehicles."
SELECT
    c.customer_firstname + ' ' + c.customer_lastname AS customer_name,
    v.make + ' ' + v.model AS vehicle_name,
    tt.transaction_type_code AS transaction_type,
    t.transaction_date AS transaction_date
FROM
    customers c
    JOIN
        transactions t ON c.customer_id = t.customer_id
    JOIN
        vehicles v ON t.vehicle_id = v.vehicle_id
    JOIN
        transaction_types tt ON t.transaction_type_code = tt.transaction_type_code
    ORDER BY
        customer_name, transaction_type, transaction_date;
GO

-- Business Question 2: Vehicle Current Status 
-- 2. For each vehicle, show its current status (e.g., 'Available', 'Rented', 'Sold').
-- Business Rule Applied: "A vehicle can only be involved in one transaction type (rental or purchase) at any given time."
-- Assumption: 'Sold' if it has any purchase record. 'Rented' if it has an *active* rental (end date >= today). 'Available' otherwise.
SELECT
    v.make + ' ' + v.model AS vehicle_name,
    CASE
        WHEN EXISTS (
            SELECT 1
            FROM purchases p
            JOIN transactions t ON p.transaction_id = t.transaction_id
            WHERE t.vehicle_id = v.vehicle_id
        ) THEN 'Sold'
        WHEN EXISTS (
            SELECT 1
            FROM rentals r
            JOIN transactions t ON r.transaction_id = t.transaction_id
            WHERE t.vehicle_id = v.vehicle_id
              AND r.rental_end_date >= CONVERT(DATE, GETDATE()) -- Check for active rentals
        ) THEN 'Rented'
        ELSE 'Available'
    END AS current_status
FROM
    vehicles v
ORDER BY
    vehicle_name
GO

-- Business Question 3: All Rental Details with Locations 
-- 3. Show all details for rentals, including customer and vehicle information, and pickup/drop-off locations.
-- Business Rule Applied: "Rentals include duration, pickup, and drop-off location details." ; "Each transaction links to a specific customer and vehicle."
SELECT
    c.customer_firstname + ' ' + c.customer_lastname AS customer_name,
    v.make + ' ' + v.model AS VehicleName,
    r.rental_start_date,
    r.rental_end_date,
    r.rental_days,
    r.price_per_day,
    r.tax_amount AS rental_tax_amount,
    r.total_rental_price,
    pickup_loc.location_name AS pickup_location,
    dropoff_loc.location_name AS dropoff_location
FROM
    rentals r
    JOIN
        transactions t ON r.transaction_id = t.transaction_id
    JOIN
        customers c ON t.customer_id = c.customer_id
    JOIN
        vehicles v ON t.vehicle_id = v.vehicle_id
    JOIN
        locations pickup_loc ON r.pickup_location_id = pickup_loc.location_id
    JOIN
        locations dropoff_loc ON r.dropoff_location_id = dropoff_loc.location_id
    ORDER BY
        r.rental_start_date DESC
GO

-- Business Question 4: All Purchase Details with Location
-- 4. Provide a report of all purchases, including customer, vehicle, and all pricing details, along with the purchase location.
-- Business Rule Applied: "Purchases include pricing details, tax, total cost, and purchase location." ; "Each transaction links to a specific customer and vehicle."
SELECT
    c.customer_firstname + ' ' + c.customer_lastname AS customer_name,
    v.make + ' ' + v.model AS vehicle_name,
    p.purchase_date AS purchasedate,
    p.purchase_price,
    p.tax_amount AS purchase_tax_amount,
    p.total_purchase_amount,
    purchase_loc.location_name AS purchase_location
    FROM
        purchases p
    JOIN
        transactions t ON p.transaction_id = t.transaction_id
    JOIN
        customers c ON t.customer_id = c.customer_id
    JOIN
        vehicles v ON t.vehicle_id = v.vehicle_id
    JOIN
        locations purchase_loc ON p.purchase_location_id = purchase_loc.location_id
        ORDER BY
            purchase_date DESC
GO

-- Business Question 5: Total Revenue by Transaction Type
-- 5. Get the total revenue generated from all rentals and all purchases, separately.
SELECT
    SUM(CASE WHEN t.transaction_type_code = 'Rental' THEN t.transaction_total_amount ELSE 0 END) AS total_rental_revenue,
    SUM(CASE WHEN t.transaction_type_code = 'Purchase' THEN t.transaction_total_amount ELSE 0 END) AS total_purchase_revenue,
    SUM(t.transaction_total_amount) AS overall_total_revenue
FROM
    transactions t
GO



-- example of one date

SELECT
    t.transaction_id,
    c.customer_firstname + ' ' + c.customer_lastname AS customer_name,
    v.make + ' ' + v.model AS vehicle_name,
    tt.transaction_type_code AS transaction_type,
    t.transaction_date,
    t.transaction_total_amount,
    t.notes
FROM
    transactions t
JOIN
    customers c ON t.customer_id = c.customer_id
JOIN
    vehicles v ON t.vehicle_id = v.vehicle_id
JOIN
    transaction_types tt ON t.transaction_type_code = tt.transaction_type_code
WHERE
    t.transaction_date = '2025-06-10'
GO

--Testing the Rental Trigger
-- Step 1: Insert into transactions
INSERT INTO transactions(customer_id, vehicle_id, transaction_type_code, transaction_date, transaction_total_amount, payment_method, duration_days, notes)
VALUES (2, 3, 'Rental', '2025-06-17', 2400.00, 'Credit Card', 2, 'Overlapping Rental Test');

-- Step 2: Get the transaction_id
DECLARE @test_rental_tx INT = SCOPE_IDENTITY();

-- Step 3: Try to insert into rentals (this will trigger the conflict)
INSERT INTO rentals (transaction_id, price_per_day, rental_days, tax_amount, total_rental_price, pickup_location_id, dropoff_location_id, rental_start_date, rental_end_date)
VALUES (@test_rental_tx, 1000.00, 2, 400.00, 2400.00, 101, 101, '2025-06-17', '2025-06-19');

--Testing the Purchase Trigger
-- Step 1: Insert into transactions
INSERT INTO transactions(customer_id, vehicle_id, transaction_type_code, transaction_date, transaction_total_amount, payment_method, duration_days, notes)
VALUES (1, 1, 'Purchase', '2025-06-01', 2950000.00, 'Cash', NULL, 'Duplicate Purchase Test');

-- Step 2: Get the transaction_id
DECLARE @test_purchase_tx INT = SCOPE_IDENTITY();

-- Step 3: Try to insert into purchases
INSERT INTO purchases(transaction_id, purchase_price, tax_amount, total_purchase_amount, purchase_location_id, purchase_date)
VALUES (@test_purchase_tx, 2500000.00, 450000.00, 2950000.00, 101, '2025-06-01');