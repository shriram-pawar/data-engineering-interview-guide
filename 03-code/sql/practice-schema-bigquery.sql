-- ============================================================
-- FreshCart SQL Practice Set: schema and sample data (BigQuery)
-- FreshCart is a fictional online grocery delivery company.
-- All names, emails (reserved .test domain) and numbers are made up.
--
-- Creates a dataset named `freshcart` in your default project.
-- Run the whole script in the BigQuery console (multi-statement query).
-- Solutions: practice-solutions-bigquery.sql
-- ============================================================

CREATE SCHEMA IF NOT EXISTS freshcart;

CREATE OR REPLACE TABLE freshcart.customers (
  customer_id  INT64,
  name         STRING,
  email        STRING,
  region       STRING,
  signup_date  DATE,
  referred_by  INT64            -- customer_id of the referrer, NULL = organic signup
);
INSERT INTO freshcart.customers VALUES
  (1, 'Asha Rao',     'asha@mail.test',   'North', DATE '2026-01-02', NULL),
  (2, 'Ben Ortiz',    'ben@mail.test',    'South', DATE '2026-01-05', 1),
  (3, 'Chen Li',      'chen@mail.test',   'North', DATE '2026-01-10', 1),
  (4, 'Dara Okafor',  'dara@mail.test',   'West',  DATE '2026-01-20', NULL),
  (5, 'Eli Novak',    'eli@mail.test',    'East',  DATE '2026-02-01', 2),
  (6, 'Fatima Zahid', 'fatima@mail.test', 'South', DATE '2026-02-03', NULL),
  (7, 'Dara O.',      'Dara@Mail.test',   'West',  DATE '2026-02-10', NULL),
  (8, 'Gus Pereira',  'gus@mail.test',    'East',  DATE '2026-02-15', 3);

CREATE OR REPLACE TABLE freshcart.products (
  product_id  INT64,
  name        STRING,
  category    STRING,
  weight_kg   NUMERIC
);
INSERT INTO freshcart.products VALUES
  (1, 'Oat Milk 1L',      'Dairy-Free', 1.00),
  (2, 'Almond Milk 1L',   'Dairy-Free', 1.00),
  (3, 'Soy Yogurt',       'Dairy-Free', 0.50),
  (4, 'Sourdough Loaf',   'Bakery',     0.80),
  (5, 'Bagels 6-pack',    'Bakery',     0.60),
  (6, 'Bananas 1kg',      'Produce',    1.00),
  (7, 'Spinach 250g',     'Produce',    0.25),
  (8, 'Coffee Beans 1kg', 'Pantry',     1.00);

-- A price applies from valid_from until the next valid_from for the same product.
CREATE OR REPLACE TABLE freshcart.price_history (
  product_id  INT64,
  price       NUMERIC,
  valid_from  DATE
);
INSERT INTO freshcart.price_history VALUES
  (1, 2.50, DATE '2026-01-01'), (1, 2.80, DATE '2026-02-01'),
  (2, 3.00, DATE '2026-01-01'),
  (3, 1.50, DATE '2026-01-01'), (3, 1.20, DATE '2026-02-15'),
  (4, 4.00, DATE '2026-01-01'), (4, 4.50, DATE '2026-03-01'),
  (5, 3.50, DATE '2026-01-01'),
  (6, 1.80, DATE '2026-01-01'), (6, 2.00, DATE '2026-02-10'),
  (7, 2.20, DATE '2026-01-01'),
  (8, 12.00, DATE '2026-01-15');

CREATE OR REPLACE TABLE freshcart.orders (
  order_id     INT64,
  customer_id  INT64,
  order_date   DATE,
  status       STRING    -- 'delivered' or 'cancelled'
);
INSERT INTO freshcart.orders VALUES
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

CREATE OR REPLACE TABLE freshcart.order_items (
  order_id    INT64,
  product_id  INT64,
  quantity    INT64,
  unit_price  NUMERIC    -- price charged at checkout
);
INSERT INTO freshcart.order_items VALUES
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

CREATE OR REPLACE TABLE freshcart.deliveries (
  order_id        INT64,
  delivered_date  DATE
);
INSERT INTO freshcart.deliveries VALUES
  (101, DATE '2026-01-03'), (102, DATE '2026-01-05'), (103, DATE '2026-01-05'),
  (104, DATE '2026-01-06'), (105, DATE '2026-01-13'), (107, DATE '2026-02-05'),
  (108, DATE '2026-02-07'), (109, DATE '2026-02-07'), (110, DATE '2026-02-08'),
  (111, DATE '2026-02-08'), (112, DATE '2026-02-10'), (113, DATE '2026-02-16'),
  (114, DATE '2026-03-02'), (115, DATE '2026-03-15'), (116, DATE '2026-03-02');

CREATE OR REPLACE TABLE freshcart.employees (
  employee_id  INT64,
  name         STRING,
  manager_id   INT64,
  salary       INT64,
  team         STRING
);
INSERT INTO freshcart.employees VALUES
  (1, 'Maya',  NULL, 250000, 'Exec'),
  (2, 'Omar',  1,    160000, 'Data'),
  (3, 'Priya', 1,    150000, 'Ops'),
  (4, 'Leo',   2,    120000, 'Data'),
  (5, 'Sara',  2,    165000, 'Data'),
  (6, 'Tom',   2,    110000, 'Data'),
  (7, 'Uma',   3,     95000, 'Ops'),
  (8, 'Vik',   4,    100000, 'Data'),
  (9, 'Wen',   4,    105000, 'Data');

CREATE OR REPLACE TABLE freshcart.app_events (
  event_id     INT64,
  customer_id  INT64,
  event_time   TIMESTAMP,
  event_type   STRING    -- 'view', 'add_to_cart', 'purchase'
);
INSERT INTO freshcart.app_events VALUES
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

CREATE OR REPLACE TABLE freshcart.pipeline_runs (
  run_date  DATE,
  status    STRING       -- 'success' or 'failed'
);
INSERT INTO freshcart.pipeline_runs VALUES
  (DATE '2026-03-01', 'success'), (DATE '2026-03-02', 'success'), (DATE '2026-03-03', 'success'),
  (DATE '2026-03-04', 'failed'),  (DATE '2026-03-05', 'failed'),
  (DATE '2026-03-06', 'success'), (DATE '2026-03-07', 'success'), (DATE '2026-03-08', 'success'),
  (DATE '2026-03-09', 'success'), (DATE '2026-03-10', 'failed'),
  (DATE '2026-03-11', 'success'), (DATE '2026-03-12', 'success');

CREATE OR REPLACE TABLE freshcart.van_queue (
  package_id  INT64,
  load_order  INT64,
  weight_kg   INT64
);
INSERT INTO freshcart.van_queue VALUES
  (1, 1, 12), (2, 2, 8), (3, 3, 15), (4, 4, 10), (5, 5, 9), (6, 6, 7);
