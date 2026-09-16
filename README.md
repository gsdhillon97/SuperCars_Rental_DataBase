# Hypercars Expo — SQL Database Project

A Microsoft SQL Server project that models hypercar rentals and purchases across multiple locations. The database connects customers, vehicles, transactions, and location details to support transaction history, vehicle status reporting, and revenue analysis.

This academic project demonstrates relational database design, T-SQL development, integrity constraints, trigger-based validation, and business reporting using sample data.

## Project at a glance

| Database | `Hypercars` |
| Language | Transact-SQL (T-SQL) |
| Tables | 8 |
| Triggers | 2 insert triggers |
| Reports | 5 business reports and 1 date-filtered query |
| Sample data | 10 customers, 24 vehicles, 5 locations, and 5 transactions |

## Business purpose

Hypercars Expo brings rental and purchase records into one database so a business can answer questions such as:

- Which vehicles has each customer rented or purchased?
- Which vehicles are available, rented, or sold according to the reporting logic?
- Where are rental vehicles picked up and returned?
- What are the price, tax, and location details for each purchase?
- How much transaction value comes from rentals versus purchases?

## Repository contents

Place this README alongside the SQL file in the repository root:

```text
.
├── README.md
├── final_project_code_UPDATED_061225 (1).sql
└── assets/
    ├── conceptual-diagram.png
    └── conceptual-diagram.drawio
```

The SQL file contains database creation, table definitions, triggers, sample inserts, reporting queries, and intentional conflict tests.

## Database design

The `transactions` table stores the shared details of each customer–vehicle transaction. The `rentals` and `purchases` tables hold the details specific to each transaction type.

| Table | Purpose | Primary key |
| --- | --- | --- |
| `customers` | Customer names, contact details, addresses, and license numbers | `customer_id` |
| `vehicles` | Vehicle makes, models, and performance specifications | `vehicle_id` |
| `states` | State codes and names for location records | `state_code` |
| `locations` | Business locations and addresses | `location_id` |
| `transaction_types` | Allowed transaction types: `Rental` and `Purchase` | `transaction_type_code` |
| `transactions` | Customer, vehicle, type, date, amount, and payment details | `transaction_id` |
| `rentals` | Rental dates, duration, pricing, and pickup/drop-off locations | `rental_id` |
| `purchases` | Purchase date, pricing, tax, and purchase location | `purchase_id` |

## SQL features demonstrated

- **Relational modeling:** Primary keys, foreign keys, lookup tables, and separate rental/purchase detail tables.
- **Data validation:** `NOT NULL`, `UNIQUE`, and `CHECK` constraints, including location ZIP-code patterns and allowed transaction types.
- **Identity handling:** `IDENTITY` columns and `SCOPE_IDENTITY()` to connect new transactions to their detail records.
- **Trigger logic:** `AFTER INSERT` triggers using `inserted`, `ROLLBACK TRANSACTION`, and `THROW`.
- **Business reporting:** Multi-table joins, `CASE`, `EXISTS`, conditional aggregation, sorting, and date filtering.

### Implemented trigger rules

| Trigger | Behavior on insert |
| --- | --- |
| `trg_prevent_rental_overlap` | Rejects a rental if its date range overlaps another rental for the same vehicle. Date boundaries are inclusive, so a rental starting on another rental's end date conflicts. |
| `trg_prevent_duplicate_purchase` | Rejects a purchase if another purchase already references the same vehicle. |

These triggers check rental-to-rental and purchase-to-purchase conflicts. They do not check conflicts between rentals and purchases, and they do not validate updates.

## Getting started

### Requirements

- Microsoft SQL Server 2016 or later, which supports the script's `DROP DATABASE IF EXISTS` syntax. See [Microsoft's DROP DATABASE documentation](https://learn.microsoft.com/en-us/sql/t-sql/statements/drop-database-transact-sql).
- SQL Server Management Studio (SSMS), or another SQL Server client that handles `GO` batch separators. See [Microsoft's GO documentation](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/sql-server-utilities-statements-go).
- Permissions to create and drop the `Hypercars` database and create its tables and triggers.

### Run the setup and reports

> **Database reset:** The script starts with `DROP DATABASE IF EXISTS Hypercars`. Running it deletes an existing database with that name before recreating it. Use a development instance where that reset is intended.

1. Download or clone the repository and open `final_project_code_UPDATED_061225 (1).sql` in SSMS.
2. Connect to your SQL Server instance and select `master` as the initial database context. Close other connections to an existing `Hypercars` database before rerunning the setup.
3. Select the script from the beginning through the `GO` immediately before `--Testing the Rental Trigger`.
4. Execute that selection to create the database, load the sample data, and display the reports.
5. Run the two conflict tests separately using the instructions below.

### Verify the sample data

Before running the conflict tests, execute:

```sql
USE Hypercars;
GO

SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM dbo.customers
UNION ALL SELECT 'vehicles', COUNT(*) FROM dbo.vehicles
UNION ALL SELECT 'states', COUNT(*) FROM dbo.states
UNION ALL SELECT 'locations', COUNT(*) FROM dbo.locations
UNION ALL SELECT 'transaction_types', COUNT(*) FROM dbo.transaction_types
UNION ALL SELECT 'transactions', COUNT(*) FROM dbo.transactions
UNION ALL SELECT 'rentals', COUNT(*) FROM dbo.rentals
UNION ALL SELECT 'purchases', COUNT(*) FROM dbo.purchases;
```

| Table | Expected rows |
| --- | ---: |
| `customers` | 10 |
| `vehicles` | 24 |
| `states` | 8 |
| `locations` | 5 |
| `transaction_types` | 2 |
| `transactions` | 5 |
| `rentals` | 3 |
| `purchases` | 2 |

## Business reports

| Report | What it returns |
| --- | --- |
| Customer transaction history | Customers with transactions, their vehicles, transaction types, and dates. Customers without transactions are excluded by the inner joins. |
| Vehicle status | A `Sold`, `Rented`, or `Available` label for each vehicle. Purchases take priority over rentals. |
| Rental details | Customer and vehicle information, rental dates, duration, pricing, tax, and pickup/drop-off locations. |
| Purchase details | Customer and vehicle information, purchase date, pricing, tax, and purchase location. |
| Revenue by transaction type | Rental, purchase, and combined transaction totals. |
| Transactions on a selected date | Transaction details for the example date `2025-06-10`. |

### Expected totals from the seed data

| Measure | Amount |
| --- | ---: |
| Rental transaction total | 9,873.50 |
| Purchase transaction total | 13,300,000.00 |
| Combined transaction total | 13,309,873.50 |

The query named “Total Revenue” sums stored transaction amounts, which include tax in the sample data. These figures are tax-inclusive transaction totals, not net revenue or profit. They are calculated from the five seed transactions before conflict tests are run.

## Trigger demonstrations

The last two sections intentionally attempt invalid inserts:

| Test | Conflict | Expected custom error |
| --- | --- | --- |
| Rental overlap | Attempts to rent vehicle `3` for June 17–19, 2025, overlapping its existing June 15–19 rental | `50001`: `Rental conflict: Vehicle is already rented for the given date range.` |
| Duplicate purchase | Attempts to purchase vehicle `1`, which already has a purchase record | `50002`: `Purchase conflict: This vehicle has already been sold.` |

Run the complete rental test block as one selection, then the complete purchase test block as a separate selection. Keep each block's transaction insert, variable declaration, and detail insert together so `SCOPE_IDENTITY()` refers to the intended row.

There is no `GO` between the two test blocks in the supplied file. Running both as one batch stops at the rental conflict, so the purchase test is not reached. SQL Server documents this behavior for a [rollback inside a trigger](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/rollback-transaction-transact-sql).

Under normal autocommit execution, the parent transaction insert commits before the detail insert fails. A failed test can therefore leave a transaction without rental or purchase details and change later report totals. Recreate the demonstration database with the setup section to restore the original seed data, or run each test inside its own explicit transaction so the parent and detail inserts roll back together.

## Current limitations and future improvements

- **Vehicle status:** The rental status query checks only whether `rental_end_date` is on or after the server's current date. It also labels future reservations as `Rented`. Add a start-date check to identify rentals active today. All seeded rentals end in June 2025, so running the query after those dates yields 2 sold and 22 available vehicles on clean seed data.
- **Transaction consistency:** Enforce that each transaction has exactly one detail record matching its declared type. Wrap parent and detail inserts in an explicit transaction.
- **Availability enforcement:** Extend validation to updates and rental/purchase conflicts, and address simultaneous bookings before using the design in a multi-user application.
- **Pricing and dates:** Add checks for positive durations, valid date ranges, nonnegative amounts, and agreement between stored totals and detail calculations. Rental duration and totals are currently stored in multiple places without consistency checks.
- **Data types and reference data:** Use numeric types for vehicle specifications, modernize the `TEXT` notes column, and consider a state foreign key for customers. The current state lookup is enforced only for business locations.
- **Sample data quality:** Treat the supplied vehicle specifications and customer records as demonstration data. Validate specifications and replace any personal contact information before publishing or reusing the dataset.

## Validation status

The schema, report descriptions, row counts, and expected totals in this README were reviewed against the supplied SQL source. The script was not executed against a SQL Server instance during this documentation review; runtime behavior and error outputs should be verified using the steps above.
