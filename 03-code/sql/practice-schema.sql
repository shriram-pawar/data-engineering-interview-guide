-- ============================================================
-- FreshCart SQL Practice Set: schema and sample data
-- FreshCart is a fictional online grocery delivery company.
-- All names, emails (reserved .test domain) and numbers are made up.
--
-- Verified on DuckDB 2.0. Most queries are standard SQL; the few DuckDB-specific
-- spots (INTERVAL n DAY, STRFTIME, generate_series over dates) are noted next to
-- each solution with the PostgreSQL / BigQuery equivalent.
-- Quick start:  duckdb freshcart.db < practice-schema.sql
-- ============================================================

DROP TABLE IF EXISTS customers;
CREATE TABLE customers (
  customer_id  INT PRIMARY KEY,
  name         VARCHAR(50),
  email        VARCHAR(100),
  region       VARCHAR(10),
  signup_date  DATE,
  referred_by  INT            -- customer_id of the referrer, NULL = organic signup
);
INSERT INTO customers VALUES
  (1, 'Asha Rao',     'asha@mail.test',   'North', DATE '2026-01-02', NULL),
  (2, 'Ben Ortiz',    'ben@mail.test',    'South', DATE '2026-01-05', 1),
  (3, 'Chen Li',      'chen@mail.test',   'North', DATE '2026-01-10', 1),
  (4, 'Dara Okafor',  'dara@mail.test',   'West',  DATE '2026-01-20', NULL),
  (5, 'Eli Novak',    'eli@mail.test',    'East',  DATE '2026-02-01', 2),
  (6, 'Fatima Zahid', 'fatima@mail.test', 'South', DATE '2026-02-03', NULL),
  (7, 'Dara O.',      'Dara@Mail.test',   'West',  DATE '2026-02-10', NULL),
  (8, 'Gus Pereira',  'gus@mail.test',    'East',  DATE '2026-02-15', 3);

DROP TABLE IF EXISTS products;
CREATE TABLE products (
  product_id  INT PRIMARY KEY,
  name        VARCHAR(50),
  category    VARCHAR(20),
  weight_kg   DECIMAL(5,2)
);
INSERT INTO products VALUES
  (1, 'Oat Milk 1L',      'Dairy-Free', 1.00),
  (2, 'Almond Milk 1L',   'Dairy-Free', 1.00),
  (3, 'Soy Yogurt',       'Dairy-Free', 0.50),
  (4, 'Sourdough Loaf',   'Bakery',     0.80),
  (5, 'Bagels 6-pack',    'Bakery',     0.60),
  (6, 'Bananas 1kg',      'Produce',    1.00),
  (7, 'Spinach 250g',     'Produce',    0.25),
  (8, 'Coffee Beans 1kg', 'Pantry',     1.00);

-- A price applies from valid_from until the next valid_from for the same product.
DROP TABLE IF EXISTS price_history;
CREATE TABLE price_history (
  product_id  INT,
  price       DECIMAL(6,2),
  valid_from  DATE
);
INSERT INTO price_history VALUES
  (1, 2.50, DATE '2026-01-01'), (1, 2.80, DATE '2026-02-01'),
  (2, 3.00, DATE '2026-01-01'),
  (3, 1.50, DATE '2026-01-01'), (3, 1.20, DATE '2026-02-15'),
  (4, 4.00, DATE '2026-01-01'), (4, 4.50, DATE '2026-03-01'),
  (5, 3.50, DATE '2026-01-01'),
  (6, 1.80, DATE '2026-01-01'), (6, 2.00, DATE '2026-02-10'),
  (7, 2.20, DATE '2026-01-01'),
  (8, 12.00, DATE '2026-01-15');

DROP TABLE IF EXISTS orders;
CREATE TABLE orders (
  order_id     INT PRIMARY KEY,
  customer_id  INT,
  order_date   DATE,
  status       VARCHAR(10)    -- 'delivered' or 'cancelled'
);
INSERT INTO orders VALUES
  (101, 1, DATE '2026-01-03', 'delivered'),
  (102, 1, DATE '2026-01-04', 'delivered'),
  (103, 1, DATE '2026-01-05', 'delivered'),
  (104, 2, DATE '2026-01-06', 'delivered'),
  (105, 3, DATE '2026-01-12', 'delivered'),
  (106, 2, DATE '2026-01-20', 'cancelled'),
  (107, 3, DATE '2026-02-05', 'delivered'),
  (108, 4, DATE '2026-02-06', 'delivered'),
  (109, 5, DATE '2026-02-07', 'delivered'),
  (110, 1, DATE '2026-02-07', 'delivered'),
  (111, 5, DATE '2026-02-08', 'delivered'),
  (112, 5, DATE '2026-02-09', 'delivered'),
  (113, 8, DATE '2026-02-16', 'delivered'),
  (114, 2, DATE '2026-03-01', 'delivered'),
  (115, 4, DATE '2026-03-15', 'delivered'),
  (116, 3, DATE '2026-03-02', 'delivered');

DROP TABLE IF EXISTS order_items;
CREATE TABLE order_items (
  order_id    INT,
  product_id  INT,
  quantity    INT,
  unit_price  DECIMAL(6,2)    -- price charged at checkout
);
INSERT INTO order_items VALUES
  (101, 1, 2, 2.50), (101, 4, 1, 4.00),
  (102, 6, 1, 1.80),
  (103, 2, 1, 3.00), (103, 3, 4, 1.50),
  (104, 4, 2, 4.00), (104, 5, 1, 3.50),
  (105, 1, 3, 2.50), (105, 2, 2, 3.00), (105, 3, 2, 1.50),
  (106, 7, 5, 2.20),
  (107, 6, 2, 1.80), (107, 7, 1, 2.20),
  (108, 1, 1, 2.80), (108, 5, 2, 3.50),
  (109, 2, 1, 3.00), (109, 4, 1, 4.00),
  (110, 1, 2, 2.80), (110, 2, 1, 3.00), (110, 3, 1, 1.50),
  (111, 6, 3, 2.00),
  (112, 8, 1, 12.00),
  (113, 3, 2, 1.20), (113, 6, 1, 2.00),
  (114, 4, 1, 4.50), (114, 8, 1, 12.00),
  (115, 5, 4, 3.50),
  (116, 6, 2, 2.00), (116, 7, 2, 2.20);

DROP TABLE IF EXISTS deliveries;
CREATE TABLE deliveries (
  order_id        INT,
  delivered_date  DATE
);
INSERT INTO deliveries VALUES
  (101, DATE '2026-01-03'), (102, DATE '2026-01-05'), (103, DATE '2026-01-05'),
  (104, DATE '2026-01-06'), (105, DATE '2026-01-13'), (107, DATE '2026-02-05'),
  (108, DATE '2026-02-07'), (109, DATE '2026-02-07'), (110, DATE '2026-02-08'),
  (111, DATE '2026-02-08'), (112, DATE '2026-02-10'), (113, DATE '2026-02-16'),
  (114, DATE '2026-03-02'), (115, DATE '2026-03-15'), (116, DATE '2026-03-02');

DROP TABLE IF EXISTS employees;
CREATE TABLE employees (
  employee_id  INT PRIMARY KEY,
  name         VARCHAR(50),
  manager_id   INT,
  salary       INT,
  team         VARCHAR(10)
);
INSERT INTO employees VALUES
  (1, 'Maya',  NULL, 250000, 'Exec'),
  (2, 'Omar',  1,    160000, 'Data'),
  (3, 'Priya', 1,    150000, 'Ops'),
  (4, 'Leo',   2,    120000, 'Data'),
  (5, 'Sara',  2,    165000, 'Data'),
  (6, 'Tom',   2,    110000, 'Data'),
  (7, 'Uma',   3,     95000, 'Ops'),
  (8, 'Vik',   4,    100000, 'Data'),
  (9, 'Wen',   4,    105000, 'Data');

DROP TABLE IF EXISTS app_events;
CREATE TABLE app_events (
  event_id     INT,
  customer_id  INT,
  event_time   TIMESTAMP,
  event_type   VARCHAR(20)    -- 'view', 'add_to_cart', 'purchase'
);
INSERT INTO app_events VALUES
  (1,  1, TIMESTAMP '2026-02-07 09:00:00', 'view'),
  (2,  1, TIMESTAMP '2026-02-07 09:05:00', 'add_to_cart'),
  (3,  1, TIMESTAMP '2026-02-07 09:20:00', 'purchase'),
  (4,  1, TIMESTAMP '2026-02-07 11:00:00', 'view'),
  (5,  1, TIMESTAMP '2026-02-07 11:10:00', 'view'),
  (6,  2, TIMESTAMP '2026-02-07 10:00:00', 'view'),
  (7,  2, TIMESTAMP '2026-02-07 10:40:00', 'view'),
  (8,  2, TIMESTAMP '2026-02-07 10:45:00', 'add_to_cart'),
  (9,  5, TIMESTAMP '2026-02-07 08:00:00', 'view'),
  (10, 5, TIMESTAMP '2026-02-07 08:10:00', 'add_to_cart'),
  (11, 5, TIMESTAMP '2026-02-07 08:15:00', 'purchase'),
  (12, 8, TIMESTAMP '2026-02-07 12:00:00', 'view'),
  (13, 2, TIMESTAMP '2026-02-07 10:45:00', 'add_to_cart');  -- duplicate of event 8 (ingested twice)

DROP TABLE IF EXISTS pipeline_runs;
CREATE TABLE pipeline_runs (
  run_date  DATE,
  status    VARCHAR(10)       -- 'success' or 'failed'
);
INSERT INTO pipeline_runs VALUES
  (DATE '2026-03-01', 'success'), (DATE '2026-03-02', 'success'), (DATE '2026-03-03', 'success'),
  (DATE '2026-03-04', 'failed'),  (DATE '2026-03-05', 'failed'),
  (DATE '2026-03-06', 'success'), (DATE '2026-03-07', 'success'), (DATE '2026-03-08', 'success'),
  (DATE '2026-03-09', 'success'), (DATE '2026-03-10', 'failed'),
  (DATE '2026-03-11', 'success'), (DATE '2026-03-12', 'success');

DROP TABLE IF EXISTS van_queue;
CREATE TABLE van_queue (
  package_id  INT,
  load_order  INT,
  weight_kg   INT
);
INSERT INTO van_queue VALUES
  (1, 1, 12), (2, 2, 8), (3, 3, 15), (4, 4, 10), (5, 5, 9), (6, 6, 7);
