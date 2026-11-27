-- ============================================================
-- FreshCart SQL Practice Set: solutions (BigQuery)
-- Run practice-schema-bigquery.sql first. Problem statements are in
-- 04-question-bank/sql/sql-coding-questions.md
-- Problems marked [BigQuery-specific] use syntax that differs from the
-- standard version; the rest only add the `freshcart.` dataset prefix.
-- ============================================================

-- ----- Q1. Customers who have never ordered (Easy) -----
SELECT c.customer_id, c.name
FROM freshcart.customers c
LEFT JOIN freshcart.orders o ON o.customer_id = c.customer_id
WHERE o.order_id IS NULL
ORDER BY c.customer_id;

-- ----- Q2. Duplicate emails, ignoring case (Easy) -----
SELECT LOWER(email) AS email, COUNT(*) AS accounts
FROM freshcart.customers
GROUP BY LOWER(email)
HAVING COUNT(*) > 1;

-- ----- Q3. Second-highest order value (Easy) -----
WITH order_revenue AS (
  SELECT o.order_id, SUM(oi.quantity * oi.unit_price) AS revenue
  FROM freshcart.orders o
  JOIN freshcart.order_items oi ON oi.order_id = o.order_id
  WHERE o.status = 'delivered'
  GROUP BY o.order_id
),
ranked AS (
  SELECT revenue, DENSE_RANK() OVER (ORDER BY revenue DESC) AS rnk
  FROM order_revenue
)
SELECT MAX(revenue) AS second_highest_revenue   -- MAX() turns "no rows" into NULL
FROM ranked
WHERE rnk = 2;

-- ----- Q4. Employees who earn more than their manager (Easy) -----
SELECT e.name AS employee, e.salary, m.name AS manager, m.salary AS manager_salary
FROM freshcart.employees e
JOIN freshcart.employees m ON m.employee_id = e.manager_id
WHERE e.salary > m.salary;

-- ----- Q5. Managers with at least three direct reports (Easy) -----
SELECT m.name AS manager, COUNT(*) AS direct_reports
FROM freshcart.employees e
JOIN freshcart.employees m ON m.employee_id = e.manager_id
GROUP BY m.employee_id, m.name
HAVING COUNT(*) >= 3;

-- ----- Q6. Everyone in a manager's organization (Medium) -----
WITH RECURSIVE org AS (
  SELECT employee_id, name, 1 AS depth
  FROM freshcart.employees
  WHERE manager_id = 2
  UNION ALL
  SELECT e.employee_id, e.name, org.depth + 1
  FROM freshcart.employees e
  JOIN org ON e.manager_id = org.employee_id
)
SELECT * FROM org ORDER BY depth, employee_id;

-- ----- Q7. Days where revenue went up (Easy) -----
WITH daily AS (
  SELECT o.order_date, SUM(oi.quantity * oi.unit_price) AS revenue
  FROM freshcart.orders o
  JOIN freshcart.order_items oi ON oi.order_id = o.order_id
  WHERE o.status = 'delivered'
  GROUP BY o.order_date
),
with_prev AS (
  SELECT order_date, revenue,
         LAG(revenue) OVER (ORDER BY order_date) AS prev_revenue
  FROM daily
)
SELECT order_date, prev_revenue, revenue
FROM with_prev
WHERE revenue > prev_revenue
ORDER BY order_date;

-- ----- Q8. Each customer's first order and its products (Medium) -----
WITH first_orders AS (
  SELECT order_id, customer_id, order_date,
         ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date, order_id) AS rn
  FROM freshcart.orders
  WHERE status = 'delivered'
)
SELECT f.customer_id, f.order_date AS first_order_date,
       STRING_AGG(p.name, ', ' ORDER BY p.name) AS products
FROM first_orders f
JOIN freshcart.order_items oi ON oi.order_id = f.order_id
JOIN freshcart.products p ON p.product_id = oi.product_id
WHERE f.rn = 1
GROUP BY f.customer_id, f.order_date
ORDER BY f.customer_id;

-- ----- Q9. Product price on a given date (Medium) -----
WITH effective AS (
  SELECT product_id, price,
         ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY valid_from DESC) AS rn
  FROM freshcart.price_history
  WHERE valid_from <= DATE '2026-01-10'
)
SELECT p.product_id, p.name, e.price
FROM freshcart.products p
LEFT JOIN effective e ON e.product_id = p.product_id AND e.rn = 1
ORDER BY p.product_id;

-- ----- Q10. Data quality: checkout prices that don't match the price list (Medium) -----
WITH ranges AS (
  SELECT product_id, price, valid_from,
         LEAD(valid_from) OVER (PARTITION BY product_id ORDER BY valid_from) AS valid_to
  FROM freshcart.price_history
)
SELECT oi.order_id, o.order_date, oi.product_id,
       oi.unit_price AS charged, r.price AS expected
FROM freshcart.order_items oi
JOIN freshcart.orders o ON o.order_id = oi.order_id
JOIN ranges r
  ON r.product_id = oi.product_id
 AND o.order_date >= r.valid_from
 AND (r.valid_to IS NULL OR o.order_date < r.valid_to)
WHERE oi.unit_price <> r.price;

-- ----- Q11. Customers who bought every Dairy-Free product (Hard) -----
SELECT o.customer_id
FROM freshcart.orders o
JOIN freshcart.order_items oi ON oi.order_id = o.order_id
JOIN freshcart.products p ON p.product_id = oi.product_id
WHERE o.status = 'delivered' AND p.category = 'Dairy-Free'
GROUP BY o.customer_id
HAVING COUNT(DISTINCT oi.product_id) =
       (SELECT COUNT(*) FROM freshcart.products WHERE category = 'Dairy-Free')
ORDER BY o.customer_id;

-- ----- Q12. Running revenue total per region (Medium) -----
WITH region_daily AS (
  SELECT c.region, o.order_date, SUM(oi.quantity * oi.unit_price) AS revenue
  FROM freshcart.orders o
  JOIN freshcart.customers c ON c.customer_id = o.customer_id
  JOIN freshcart.order_items oi ON oi.order_id = o.order_id
  WHERE o.status = 'delivered'
  GROUP BY c.region, o.order_date
)
SELECT region, order_date, revenue,
       SUM(revenue) OVER (PARTITION BY region ORDER BY order_date
                          ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_total
FROM region_daily
ORDER BY region, order_date;

-- ----- Q13. 7-day moving average of revenue (Hard) [BigQuery-specific] -----
WITH days AS (
  SELECT day
  FROM UNNEST(GENERATE_DATE_ARRAY('2026-01-26', '2026-02-16')) AS day
),
daily AS (
  SELECT o.order_date AS day, SUM(oi.quantity * oi.unit_price) AS revenue
  FROM freshcart.orders o
  JOIN freshcart.order_items oi ON oi.order_id = o.order_id
  WHERE o.status = 'delivered'
  GROUP BY o.order_date
),
filled AS (
  SELECT d.day, COALESCE(daily.revenue, 0) AS revenue
  FROM days d
  LEFT JOIN daily ON daily.day = d.day
)
SELECT day, revenue,
       ROUND(AVG(revenue) OVER (ORDER BY day ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 2) AS avg_7d
FROM filled
WHERE day >= DATE '2026-02-01'
ORDER BY day;

-- ----- Q14. Monthly revenue by category (pivot) (Medium) [BigQuery-specific] -----
-- Option 1: conditional aggregation with FORMAT_DATE
SELECT FORMAT_DATE('%Y-%m', o.order_date) AS month,
       SUM(IF(p.category = 'Dairy-Free', oi.quantity * oi.unit_price, 0)) AS dairy_free,
       SUM(IF(p.category = 'Bakery',     oi.quantity * oi.unit_price, 0)) AS bakery,
       SUM(IF(p.category = 'Produce',    oi.quantity * oi.unit_price, 0)) AS produce,
       SUM(IF(p.category = 'Pantry',     oi.quantity * oi.unit_price, 0)) AS pantry
FROM freshcart.orders o
JOIN freshcart.order_items oi ON oi.order_id = o.order_id
JOIN freshcart.products p ON p.product_id = oi.product_id
WHERE o.status = 'delivered'
GROUP BY month
ORDER BY month;

-- Option 2: the PIVOT operator (missing combinations come back as NULL, not 0)
SELECT *
FROM (
  SELECT FORMAT_DATE('%Y-%m', o.order_date) AS month, p.category,
         oi.quantity * oi.unit_price AS amount
  FROM freshcart.orders o
  JOIN freshcart.order_items oi ON oi.order_id = o.order_id
  JOIN freshcart.products p ON p.product_id = oi.product_id
  WHERE o.status = 'delivered'
)
PIVOT (SUM(amount) FOR category IN ('Dairy-Free' AS dairy_free, 'Bakery' AS bakery,
                                    'Produce' AS produce, 'Pantry' AS pantry))
ORDER BY month;

-- ----- Q15. Same-day delivery rate (Medium) -----
WITH d AS (
  SELECT o.order_id, o.customer_id, o.order_date,
         CASE WHEN dl.delivered_date = o.order_date THEN 1 ELSE 0 END AS same_day,
         ROW_NUMBER() OVER (PARTITION BY o.customer_id ORDER BY o.order_date, o.order_id) AS rn
  FROM freshcart.orders o
  JOIN freshcart.deliveries dl ON dl.order_id = o.order_id
  WHERE o.status = 'delivered'
)
SELECT ROUND(100.0 * AVG(same_day), 1) AS same_day_pct_all,
       ROUND(100.0 * AVG(CASE WHEN rn = 1 THEN same_day END), 1) AS same_day_pct_first_orders
FROM d;

-- ----- Q16. 30-day repeat purchase rate (Medium) [BigQuery-specific] -----
WITH delivered AS (
  SELECT customer_id, order_date
  FROM freshcart.orders
  WHERE status = 'delivered'
),
firsts AS (
  SELECT customer_id, MIN(order_date) AS first_date
  FROM delivered
  GROUP BY customer_id
),
flags AS (
  SELECT f.customer_id,
         LOGICAL_OR(d.order_date > f.first_date
                    AND d.order_date <= DATE_ADD(f.first_date, INTERVAL 30 DAY)) AS repeated
  FROM firsts f
  JOIN delivered d USING (customer_id)
  GROUP BY f.customer_id
)
SELECT ROUND(100 * AVG(IF(repeated, 1, 0)), 1) AS repeat_30d_pct
FROM flags;

-- ----- Q17. Top 2 products per category by revenue (Medium) -----
WITH product_rev AS (
  SELECT p.category, p.name, SUM(oi.quantity * oi.unit_price) AS revenue
  FROM freshcart.orders o
  JOIN freshcart.order_items oi ON oi.order_id = o.order_id
  JOIN freshcart.products p ON p.product_id = oi.product_id
  WHERE o.status = 'delivered'
  GROUP BY p.category, p.name
),
ranked AS (
  SELECT *, DENSE_RANK() OVER (PARTITION BY category ORDER BY revenue DESC) AS rnk
  FROM product_rev
)
SELECT category, name, revenue, rnk
FROM ranked
WHERE rnk <= 2
ORDER BY category, rnk, name;

-- ----- Q18. Customers who ordered on 3+ consecutive days (Hard) [BigQuery-specific] -----
WITH days AS (
  SELECT DISTINCT customer_id, order_date
  FROM freshcart.orders
  WHERE status = 'delivered'
),
numbered AS (
  SELECT customer_id, order_date,
         ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date) AS rn
  FROM days
)
SELECT customer_id, MIN(order_date) AS streak_start, MAX(order_date) AS streak_end, COUNT(*) AS days
FROM numbered
GROUP BY customer_id, DATE_SUB(order_date, INTERVAL rn DAY)
HAVING COUNT(*) >= 3
ORDER BY customer_id;

-- ----- Q19. Contiguous ranges of pipeline success and failure (Hard) -----
WITH flagged AS (
  SELECT run_date, status,
         CASE WHEN status = LAG(status) OVER (ORDER BY run_date) THEN 0 ELSE 1 END AS new_island
  FROM freshcart.pipeline_runs
),
islands AS (
  SELECT run_date, status,
         SUM(new_island) OVER (ORDER BY run_date ROWS UNBOUNDED PRECEDING) AS island_id
  FROM flagged
)
SELECT status, MIN(run_date) AS start_date, MAX(run_date) AS end_date, COUNT(*) AS days
FROM islands
GROUP BY island_id, status
ORDER BY start_date;

-- ----- Q20. Histogram of orders per customer, including zero (Hard) [BigQuery-specific] -----
WITH per_customer AS (
  SELECT c.customer_id, COUNT(o.order_id) AS n_orders
  FROM freshcart.customers c
  LEFT JOIN freshcart.orders o ON o.customer_id = c.customer_id AND o.status = 'delivered'
  GROUP BY c.customer_id
),
buckets AS (
  SELECT n AS n_orders
  FROM (SELECT MAX(n_orders) AS max_orders FROM per_customer),
       UNNEST(GENERATE_ARRAY(0, max_orders)) AS n
)
SELECT b.n_orders, COUNT(pc.customer_id) AS customers
FROM buckets b
LEFT JOIN per_customer pc ON pc.n_orders = b.n_orders
GROUP BY b.n_orders
ORDER BY b.n_orders;

-- ----- Q21. Last package that fits in the van (Medium) -----
WITH loaded AS (
  SELECT package_id, load_order,
         SUM(weight_kg) OVER (ORDER BY load_order) AS cumulative_kg
  FROM freshcart.van_queue
)
SELECT package_id
FROM loaded
WHERE cumulative_kg <= 50
ORDER BY load_order DESC
LIMIT 1;

-- ----- Q22. Median order value per region (Hard) [BigQuery-specific] -----
-- In BigQuery, PERCENTILE_CONT is an analytic (window) function, not an aggregate
WITH order_revenue AS (
  SELECT c.region, o.order_id, SUM(oi.quantity * oi.unit_price) AS revenue
  FROM freshcart.orders o
  JOIN freshcart.customers c ON c.customer_id = o.customer_id
  JOIN freshcart.order_items oi ON oi.order_id = o.order_id
  WHERE o.status = 'delivered'
  GROUP BY c.region, o.order_id
)
SELECT DISTINCT region,
       PERCENTILE_CONT(revenue, 0.5) OVER (PARTITION BY region) AS median_revenue
FROM order_revenue
ORDER BY region;

-- For very large tables, an approximate aggregate is much cheaper:
-- SELECT region, APPROX_QUANTILES(revenue, 2)[OFFSET(1)] AS approx_median
-- FROM order_revenue GROUP BY region;

-- ----- Q23. Remove duplicate events (Medium) -----
SELECT event_id, customer_id, event_time, event_type
FROM (
  SELECT *,
         ROW_NUMBER() OVER (PARTITION BY customer_id, event_time, event_type ORDER BY event_id) AS rn
  FROM freshcart.app_events
) t
WHERE rn = 1
ORDER BY event_id;

-- ----- Q24. Sessionize app events (30-minute inactivity gap) (Hard) [BigQuery-specific] -----
WITH dedup AS (
  SELECT DISTINCT customer_id, event_time, event_type FROM freshcart.app_events
),
flagged AS (
  SELECT *,
         CASE WHEN TIMESTAMP_DIFF(event_time,
                                  LAG(event_time) OVER (PARTITION BY customer_id ORDER BY event_time),
                                  MINUTE) <= 30
              THEN 0 ELSE 1 END AS new_session
  FROM dedup
),
sessions AS (
  SELECT *,
         SUM(new_session) OVER (PARTITION BY customer_id ORDER BY event_time
                                ROWS UNBOUNDED PRECEDING) AS session_no
  FROM flagged
)
SELECT customer_id, session_no,
       MIN(event_time) AS session_start, MAX(event_time) AS session_end, COUNT(*) AS events
FROM sessions
GROUP BY customer_id, session_no
ORDER BY customer_id, session_no;

-- ----- Q25. Conversion funnel (Medium) -----
SELECT COUNT(DISTINCT CASE WHEN event_type = 'view'        THEN customer_id END) AS viewed,
       COUNT(DISTINCT CASE WHEN event_type = 'add_to_cart' THEN customer_id END) AS added_to_cart,
       COUNT(DISTINCT CASE WHEN event_type = 'purchase'    THEN customer_id END) AS purchased,
       ROUND(100.0 * COUNT(DISTINCT CASE WHEN event_type = 'purchase' THEN customer_id END)
                   / COUNT(DISTINCT CASE WHEN event_type = 'view'     THEN customer_id END), 1) AS view_to_purchase_pct
FROM freshcart.app_events;

-- ----- Q26. Signups by referral source (Easy) -----
SELECT COALESCE(r.name, 'organic') AS referral_source, COUNT(*) AS signups
FROM freshcart.customers c
LEFT JOIN freshcart.customers r ON r.customer_id = c.referred_by
GROUP BY COALESCE(r.name, 'organic')
ORDER BY signups DESC, referral_source;
