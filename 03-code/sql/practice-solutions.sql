-- ============================================================
-- FreshCart SQL Practice Set: solutions
-- Run practice-schema.sql first. Problem statements are in
-- 04-question-bank/sql/sql-coding-questions.md
-- Verified on DuckDB; engine-specific syntax is called out in the notes.
-- ============================================================

-- ----- Q1. Customers who have never ordered (Easy) -----
SELECT c.customer_id, c.name
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
WHERE o.order_id IS NULL
ORDER BY c.customer_id;

-- ----- Q2. Duplicate emails, ignoring case (Easy) -----
SELECT LOWER(email) AS email, COUNT(*) AS accounts
FROM customers
GROUP BY LOWER(email)
HAVING COUNT(*) > 1;

-- ----- Q3. Second-highest order value (Easy) -----
WITH order_revenue AS (
  SELECT o.order_id, SUM(oi.quantity * oi.unit_price) AS revenue
  FROM orders o
  JOIN order_items oi ON oi.order_id = o.order_id
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
FROM employees e
JOIN employees m ON m.employee_id = e.manager_id
WHERE e.salary > m.salary;

-- ----- Q5. Managers with at least three direct reports (Easy) -----
SELECT m.name AS manager, COUNT(*) AS direct_reports
FROM employees e
JOIN employees m ON m.employee_id = e.manager_id
GROUP BY m.employee_id, m.name
HAVING COUNT(*) >= 3;

-- ----- Q6. Everyone in a manager's organization (Medium) -----
WITH RECURSIVE org AS (
  SELECT employee_id, name, 1 AS depth
  FROM employees
  WHERE manager_id = 2
  UNION ALL
  SELECT e.employee_id, e.name, org.depth + 1
  FROM employees e
  JOIN org ON e.manager_id = org.employee_id
)
SELECT * FROM org ORDER BY depth, employee_id;

-- ----- Q7. Days where revenue went up (Easy) -----
WITH daily AS (
  SELECT o.order_date, SUM(oi.quantity * oi.unit_price) AS revenue
  FROM orders o
  JOIN order_items oi ON oi.order_id = o.order_id
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
  FROM orders
  WHERE status = 'delivered'
)
SELECT f.customer_id, f.order_date AS first_order_date,
       STRING_AGG(p.name, ', ' ORDER BY p.name) AS products
FROM first_orders f
JOIN order_items oi ON oi.order_id = f.order_id
JOIN products p ON p.product_id = oi.product_id
WHERE f.rn = 1
GROUP BY f.customer_id, f.order_date
ORDER BY f.customer_id;

-- ----- Q9. Product price on a given date (Medium) -----
WITH effective AS (
  SELECT product_id, price,
         ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY valid_from DESC) AS rn
  FROM price_history
  WHERE valid_from <= DATE '2026-01-10'
)
SELECT p.product_id, p.name, e.price
FROM products p
LEFT JOIN effective e ON e.product_id = p.product_id AND e.rn = 1
ORDER BY p.product_id;

-- ----- Q10. Data quality: checkout prices that don't match the price list (Medium) -----
WITH ranges AS (
  SELECT product_id, price, valid_from,
         LEAD(valid_from) OVER (PARTITION BY product_id ORDER BY valid_from) AS valid_to
  FROM price_history
)
SELECT oi.order_id, o.order_date, oi.product_id,
       oi.unit_price AS charged, r.price AS expected
FROM order_items oi
JOIN orders o ON o.order_id = oi.order_id
JOIN ranges r
  ON r.product_id = oi.product_id
 AND o.order_date >= r.valid_from
 AND (r.valid_to IS NULL OR o.order_date < r.valid_to)
WHERE oi.unit_price <> r.price;

-- ----- Q11. Customers who bought every Dairy-Free product (Hard) -----
SELECT o.customer_id
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
JOIN products p ON p.product_id = oi.product_id
WHERE o.status = 'delivered' AND p.category = 'Dairy-Free'
GROUP BY o.customer_id
HAVING COUNT(DISTINCT oi.product_id) =
       (SELECT COUNT(*) FROM products WHERE category = 'Dairy-Free')
ORDER BY o.customer_id;

-- ----- Q12. Running revenue total per region (Medium) -----
WITH region_daily AS (
  SELECT c.region, o.order_date, SUM(oi.quantity * oi.unit_price) AS revenue
  FROM orders o
  JOIN customers c ON c.customer_id = o.customer_id
  JOIN order_items oi ON oi.order_id = o.order_id
  WHERE o.status = 'delivered'
  GROUP BY c.region, o.order_date
)
SELECT region, order_date, revenue,
       SUM(revenue) OVER (PARTITION BY region ORDER BY order_date
                          ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_total
FROM region_daily
ORDER BY region, order_date;

-- ----- Q13. 7-day moving average of revenue (Hard) -----
WITH days AS (
  SELECT CAST(d AS DATE) AS day
  FROM generate_series(DATE '2026-01-26', DATE '2026-02-16', INTERVAL 1 DAY) AS t(d)
),
daily AS (
  SELECT o.order_date AS day, SUM(oi.quantity * oi.unit_price) AS revenue
  FROM orders o
  JOIN order_items oi ON oi.order_id = o.order_id
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

-- ----- Q14. Monthly revenue by category (pivot) (Medium) -----
SELECT STRFTIME(o.order_date, '%Y-%m') AS month,
       SUM(CASE WHEN p.category = 'Dairy-Free' THEN oi.quantity * oi.unit_price ELSE 0 END) AS dairy_free,
       SUM(CASE WHEN p.category = 'Bakery'     THEN oi.quantity * oi.unit_price ELSE 0 END) AS bakery,
       SUM(CASE WHEN p.category = 'Produce'    THEN oi.quantity * oi.unit_price ELSE 0 END) AS produce,
       SUM(CASE WHEN p.category = 'Pantry'     THEN oi.quantity * oi.unit_price ELSE 0 END) AS pantry
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
JOIN products p ON p.product_id = oi.product_id
WHERE o.status = 'delivered'
GROUP BY 1
ORDER BY 1;

-- ----- Q15. Same-day delivery rate (Medium) -----
WITH d AS (
  SELECT o.order_id, o.customer_id, o.order_date,
         CASE WHEN dl.delivered_date = o.order_date THEN 1 ELSE 0 END AS same_day,
         ROW_NUMBER() OVER (PARTITION BY o.customer_id ORDER BY o.order_date, o.order_id) AS rn
  FROM orders o
  JOIN deliveries dl ON dl.order_id = o.order_id
  WHERE o.status = 'delivered'
)
SELECT ROUND(100.0 * AVG(same_day), 1) AS same_day_pct_all,
       ROUND(100.0 * AVG(CASE WHEN rn = 1 THEN same_day END), 1) AS same_day_pct_first_orders
FROM d;

-- ----- Q16. 30-day repeat purchase rate (Medium) -----
WITH firsts AS (
  SELECT customer_id, MIN(order_date) AS first_date
  FROM orders
  WHERE status = 'delivered'
  GROUP BY customer_id
)
SELECT ROUND(100.0 * AVG(CASE WHEN EXISTS (
         SELECT 1 FROM orders o
         WHERE o.customer_id = f.customer_id
           AND o.status = 'delivered'
           AND o.order_date >  f.first_date
           AND o.order_date <= f.first_date + INTERVAL 30 DAY
       ) THEN 1 ELSE 0 END), 1) AS repeat_30d_pct
FROM firsts f;

-- ----- Q17. Top 2 products per category by revenue (Medium) -----
WITH product_rev AS (
  SELECT p.category, p.name, SUM(oi.quantity * oi.unit_price) AS revenue
  FROM orders o
  JOIN order_items oi ON oi.order_id = o.order_id
  JOIN products p ON p.product_id = oi.product_id
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

-- ----- Q18. Customers who ordered on 3+ consecutive days (Hard) -----
WITH days AS (
  SELECT DISTINCT customer_id, order_date
  FROM orders
  WHERE status = 'delivered'
),
grouped AS (
  SELECT customer_id, order_date,
         order_date - CAST(ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date) AS INT) AS grp
  FROM days
)
SELECT customer_id, MIN(order_date) AS streak_start, MAX(order_date) AS streak_end, COUNT(*) AS days
FROM grouped
GROUP BY customer_id, grp
HAVING COUNT(*) >= 3
ORDER BY customer_id;

-- ----- Q19. Contiguous ranges of pipeline success and failure (Hard) -----
WITH flagged AS (
  SELECT run_date, status,
         CASE WHEN status = LAG(status) OVER (ORDER BY run_date) THEN 0 ELSE 1 END AS new_island
  FROM pipeline_runs
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

-- ----- Q20. Histogram of orders per customer, including zero (Hard) -----
WITH per_customer AS (
  SELECT c.customer_id, COUNT(o.order_id) AS n_orders
  FROM customers c
  LEFT JOIN orders o ON o.customer_id = c.customer_id AND o.status = 'delivered'
  GROUP BY c.customer_id
),
buckets AS (
  SELECT CAST(n AS INT) AS n_orders
  FROM generate_series(0, (SELECT MAX(n_orders) FROM per_customer)) AS t(n)
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
  FROM van_queue
)
SELECT package_id
FROM loaded
WHERE cumulative_kg <= 50
ORDER BY load_order DESC
LIMIT 1;

-- ----- Q22. Median order value per region (Hard) -----
WITH order_revenue AS (
  SELECT c.region, o.order_id, SUM(oi.quantity * oi.unit_price) AS revenue
  FROM orders o
  JOIN customers c ON c.customer_id = o.customer_id
  JOIN order_items oi ON oi.order_id = o.order_id
  WHERE o.status = 'delivered'
  GROUP BY c.region, o.order_id
)
SELECT region,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY revenue) AS median_revenue
FROM order_revenue
GROUP BY region
ORDER BY region;

-- ----- Q23. Remove duplicate events (Medium) -----
SELECT event_id, customer_id, event_time, event_type
FROM (
  SELECT *,
         ROW_NUMBER() OVER (PARTITION BY customer_id, event_time, event_type ORDER BY event_id) AS rn
  FROM app_events
) t
WHERE rn = 1
ORDER BY event_id;

-- ----- Q24. Sessionize app events (30-minute inactivity gap) (Hard) -----
WITH dedup AS (
  SELECT DISTINCT customer_id, event_time, event_type FROM app_events
),
flagged AS (
  SELECT *,
         CASE WHEN event_time - LAG(event_time) OVER (PARTITION BY customer_id ORDER BY event_time)
                   <= INTERVAL 30 MINUTE THEN 0 ELSE 1 END AS new_session
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
FROM app_events;

-- ----- Q26. Signups by referral source (Easy) -----
SELECT COALESCE(r.name, 'organic') AS referral_source, COUNT(*) AS signups
FROM customers c
LEFT JOIN customers r ON r.customer_id = c.referred_by
GROUP BY COALESCE(r.name, 'organic')
ORDER BY signups DESC, referral_source;
