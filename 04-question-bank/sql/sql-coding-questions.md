# SQL Coding Questions (FreshCart Practice Set)

Original practice problems on a single fictional schema. Load the data from
[`03-code/sql/practice-schema.sql`](../../03-code/sql/practice-schema.sql); runnable solutions are in
[`03-code/sql/practice-solutions.sql`](../../03-code/sql/practice-solutions.sql).

Delivered revenue for an order = `SUM(quantity * unit_price)` over its `order_items`, counting only orders with `status = 'delivered'`.

> Format: Question · Answer · Follow-ups · Difficulty

| # | Problem | Concepts | Difficulty |
|---|---|---|---|
| 1 | Customers who have never ordered | anti-join, NULL handling | Easy |
| 2 | Duplicate emails, ignoring case | GROUP BY, HAVING, normalization | Easy |
| 3 | Second-highest order value | CTE, DENSE_RANK | Easy |
| 4 | Employees who earn more than their manager | self-join | Easy |
| 5 | Managers with at least three direct reports | GROUP BY, HAVING, join | Easy |
| 6 | Everyone in a manager's organization | recursive CTE, hierarchy | Medium |
| 7 | Days where revenue went up | aggregation, LAG | Easy |
| 8 | Each customer's first order and its products | ROW_NUMBER, join | Medium |
| 9 | Product price on a given date | point-in-time lookup, LEFT JOIN | Medium |
| 10 | Data quality: checkout prices that don't match the price list | range join, LEAD, data validation | Medium |
| 11 | Customers who bought every Dairy-Free product | relational division | Hard |
| 12 | Running revenue total per region | window aggregate, running total | Medium |
| 13 | 7-day moving average of revenue | calendar spine, RANGE frame | Hard |
| 14 | Monthly revenue by category (pivot) | conditional aggregation, pivot | Medium |
| 15 | Same-day delivery rate | conditional aggregation, ratios | Medium |
| 16 | 30-day repeat purchase rate | first event, self-join / EXISTS | Medium |
| 17 | Top 2 products per category by revenue | DENSE_RANK per group, ties | Medium |
| 18 | Customers who ordered on 3+ consecutive days | gaps and islands | Hard |
| 19 | Contiguous ranges of pipeline success and failure | gaps and islands, LAG | Hard |
| 20 | Histogram of orders per customer, including zero | number spine, LEFT JOIN, counting | Hard |
| 21 | Last package that fits in the van | running total | Medium |
| 22 | Median order value per region | ordered-set aggregate | Hard |
| 23 | Remove duplicate events | ROW_NUMBER, deduplication | Medium |
| 24 | Sessionize app events (30-minute inactivity gap) | LAG, running sum, sessionization | Hard |
| 25 | Conversion funnel | conditional aggregation, ratios | Medium |
| 26 | Signups by referral source | COALESCE, self-join, NULL grouping | Easy |

---

### Q1: Customers who have never ordered

List the `customer_id` and `name` of customers who have never placed an order (of any status).

**Answer:**
```sql
SELECT c.customer_id, c.name
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
WHERE o.order_id IS NULL
ORDER BY c.customer_id;
```
A `LEFT JOIN` keeps every customer; rows with no matching order have NULL order columns. `NOT EXISTS` works just as well and is often the clearest way to write an anti-join.

Expected output:

| customer_id | name |
|---|---|
| 6 | Fatima Zahid |
| 7 | Dara O. |

**Follow-ups:**
- Why is `NOT IN (SELECT customer_id FROM orders)` dangerous if `orders.customer_id` can be NULL?
- How would you change this to find customers with no *delivered* orders?

**Difficulty:** Easy


---

### Q2: Duplicate emails, ignoring case

Emails should be unique regardless of letter case. Return each email (lower-cased) that belongs to more than one customer, with the number of accounts that use it.

**Answer:**
```sql
SELECT LOWER(email) AS email, COUNT(*) AS accounts
FROM customers
GROUP BY LOWER(email)
HAVING COUNT(*) > 1;
```
Normalize before grouping. In a real pipeline you would also `TRIM` whitespace and possibly strip `+tags` before checking for uniqueness.

Expected output:

| email | accounts |
|---|---|
| dara@mail.test | 2 |

**Follow-ups:**
- How would you return the full customer rows involved, not just the email?
- How would you enforce this rule at write time?

**Difficulty:** Easy


---

### Q3: Second-highest order value

Compute the revenue of each delivered order and return the **second-highest distinct** order revenue. Return NULL if it doesn't exist.

**Answer:**
```sql
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
```
Two orders tie for the highest value (16.50), so `DENSE_RANK` is needed; `ROW_NUMBER` would wrongly return 16.50. Wrapping the result in an aggregate guarantees a single row containing NULL when there's no rank 2.

Expected output:

| second_highest_revenue |
|---|
| 14 |

**Follow-ups:**
- Generalize this to the Nth highest value.
- How do `RANK`, `DENSE_RANK` and `ROW_NUMBER` differ on the tied values?

**Difficulty:** Easy


---

### Q4: Employees who earn more than their manager

Return the names of employees whose salary is higher than their direct manager's salary.

**Answer:**
```sql
SELECT e.name AS employee, e.salary, m.name AS manager, m.salary AS manager_salary
FROM employees e
JOIN employees m ON m.employee_id = e.manager_id
WHERE e.salary > m.salary;
```
Join the table to itself: one copy plays the employee, the other plays the manager.

Expected output:

| employee | salary | manager | manager_salary |
|---|---|---|---|
| Sara | 165000 | Omar | 160000 |

**Follow-ups:**
- How would you compare against the average salary of the employee's team instead?
- What happens to the CEO row, and why?

**Difficulty:** Easy


---

### Q5: Managers with at least three direct reports

Return the name of each manager who has three or more direct reports, along with the report count.

**Answer:**
```sql
SELECT m.name AS manager, COUNT(*) AS direct_reports
FROM employees e
JOIN employees m ON m.employee_id = e.manager_id
GROUP BY m.employee_id, m.name
HAVING COUNT(*) >= 3;
```
Group the employees by `manager_id`, then join back to get each manager's name. Group by the ID, not just the name, because names aren't unique.

Expected output:

| manager | direct_reports |
|---|---|
| Omar | 3 |

**Follow-ups:**
- How would you include managers with zero reports in a full count?
- How would you count *all* reports, not just direct ones? (See the next problem.)

**Difficulty:** Easy


---

### Q6: Everyone in a manager's organization

Return every employee who reports to Omar (`employee_id = 2`) directly or indirectly, with their depth below Omar (1 = direct report).

**Answer:**
```sql
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
```
The anchor member selects the direct reports. The recursive member repeatedly joins the employees who report to anyone already found, until no new rows appear.

Expected output:

| employee_id | name | depth |
|---|---|---|
| 4 | Leo | 1 |
| 5 | Sara | 1 |
| 6 | Tom | 1 |
| 8 | Vik | 2 |
| 9 | Wen | 2 |

**Follow-ups:**
- How would you guard against a cycle in bad data (A manages B, B manages A)?
- How would you build the full reporting path, e.g. `Omar > Leo > Vik`?

**Difficulty:** Medium


---

### Q7: Days where revenue went up

Calculate total delivered revenue per order date. Return the dates where revenue was higher than on the **previous date that had orders**, with both values.

**Answer:**
```sql
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
```
`LAG` looks at the previous row in date order. The first date has a NULL `prev_revenue`, and `NULL > x` is not true, so it is excluded automatically.

Expected output:

| order_date | prev_revenue | revenue |
|---|---|---|
| 2026-01-05 | 1.8 | 9 |
| 2026-01-06 | 9 | 11.5 |
| 2026-01-12 | 11.5 | 16.5 |
| 2026-02-06 | 5.8 | 9.8 |
| 2026-02-07 | 9.8 | 17.1 |
| 2026-02-09 | 6 | 12 |
| 2026-03-01 | 4.4 | 16.5 |
| 2026-03-15 | 8.4 | 14 |

**Follow-ups:**
- How would you compare with the previous *calendar* day instead, treating days without orders as 0?
- How would you calculate the percentage change?

**Difficulty:** Easy


---

### Q8: Each customer's first order and its products

For each customer, show the date of their first delivered order and the comma-separated names of the products in that order.

**Answer:**
```sql
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
```
`ROW_NUMBER` picks exactly one first order per customer; `order_id` breaks ties between two orders on the same day. `STRING_AGG` is the PostgreSQL/DuckDB name; MySQL uses `GROUP_CONCAT`.

Expected output:

| customer_id | first_order_date | products |
|---|---|---|
| 1 | 2026-01-03 | Oat Milk 1L, Sourdough Loaf |
| 2 | 2026-01-06 | Bagels 6-pack, Sourdough Loaf |
| 3 | 2026-01-12 | Almond Milk 1L, Oat Milk 1L, Soy Yogurt |
| 4 | 2026-02-06 | Bagels 6-pack, Oat Milk 1L |
| 5 | 2026-02-07 | Almond Milk 1L, Sourdough Loaf |
| 8 | 2026-02-16 | Bananas 1kg, Soy Yogurt |

**Follow-ups:**
- What changes if you want *all* orders placed on the first day?
- How would you find the most common first-order product category?

**Difficulty:** Medium


---

### Q9: Product price on a given date

Using `price_history`, return the price of **every** product as of `2026-01-10`. Show NULL for products that had no price yet.

**Answer:**
```sql
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
```
Keep only the price rows that started on or before the target date, take the latest one per product, then `LEFT JOIN` from products so that products with no price yet still appear. Coffee Beans only gets a price on 2026-01-15.

Expected output:

| product_id | name | price |
|---|---|---|
| 1 | Oat Milk 1L | 2.5 |
| 2 | Almond Milk 1L | 3 |
| 3 | Soy Yogurt | 1.5 |
| 4 | Sourdough Loaf | 4 |
| 5 | Bagels 6-pack | 3.5 |
| 6 | Bananas 1kg | 1.8 |
| 7 | Spinach 250g | 2.2 |
| 8 | Coffee Beans 1kg | NULL |

**Follow-ups:**
- How would you turn `price_history` into `valid_from` / `valid_to` ranges using `LEAD`?
- How does this relate to an SCD Type 2 dimension?

**Difficulty:** Medium


---

### Q10: Data quality: checkout prices that don't match the price list

Every `order_items.unit_price` should equal the price in effect on the order date. Find the order lines where it doesn't, showing the charged and expected prices.

**Answer:**
```sql
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
```
`LEAD` turns the start dates into half-open `[valid_from, valid_to)` ranges, so each order date matches exactly one price. Order 111 charged the new banana price two days before it took effect.

Expected output:

| order_id | order_date | product_id | charged | expected |
|---|---|---|---|---|
| 111 | 2026-02-08 | 6 | 2 | 1.8 |

**Follow-ups:**
- How would you also catch order lines with *no* matching price range?
- Where would a check like this run in a production pipeline, and what should happen when it fails?

**Difficulty:** Medium


---

### Q11: Customers who bought every Dairy-Free product

Return the customers who, across all their delivered orders, have bought **every** product in the `Dairy-Free` category.

**Answer:**
```sql
SELECT o.customer_id
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
JOIN products p ON p.product_id = oi.product_id
WHERE o.status = 'delivered' AND p.category = 'Dairy-Free'
GROUP BY o.customer_id
HAVING COUNT(DISTINCT oi.product_id) =
       (SELECT COUNT(*) FROM products WHERE category = 'Dairy-Free')
ORDER BY o.customer_id;
```
"Bought all of X" means the number of distinct X products a customer bought equals the total number of X products. Asha bought them across several orders; Chen bought them in one.

Expected output:

| customer_id |
|---|
| 1 |
| 3 |

**Follow-ups:**
- How would you solve this with a double `NOT EXISTS`?
- How would you list the products each customer is still missing?

**Difficulty:** Hard


---

### Q12: Running revenue total per region

For each region, show delivered revenue per order date and a running total within that region, ordered by date.

**Answer:**
```sql
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
```
`PARTITION BY region` restarts the total for each region. Spelling out the `ROWS` frame avoids surprises: the default `RANGE` frame treats rows with the same date as peers and adds them together.

Expected output:

| region | order_date | revenue | running_total |
|---|---|---|---|
| East | 2026-02-07 | 7 | 7 |
| East | 2026-02-08 | 6 | 13 |
| East | 2026-02-09 | 12 | 25 |
| East | 2026-02-16 | 4.4 | 29.4 |
| North | 2026-01-03 | 9 | 9 |
| North | 2026-01-04 | 1.8 | 10.8 |
| North | 2026-01-05 | 9 | 19.8 |
| North | 2026-01-12 | 16.5 | 36.3 |
| North | 2026-02-05 | 5.8 | 42.1 |
| North | 2026-02-07 | 10.1 | 52.2 |
| North | 2026-03-02 | 8.4 | 60.6 |
| South | 2026-01-06 | 11.5 | 11.5 |
| South | 2026-03-01 | 16.5 | 28 |
| West | 2026-02-06 | 9.8 | 9.8 |
| West | 2026-03-15 | 14 | 23.8 |

**Follow-ups:**
- What's the difference between `ROWS` and `RANGE` here?
- How would you show each day's share of the region's total?

**Difficulty:** Medium


---

### Q13: 7-day moving average of revenue

For every **calendar** day from 2026-02-01 to 2026-02-16, show delivered revenue (0 if there were no orders) and the average daily revenue over that day and the 6 days before it.

**Answer:**
```sql
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
```
A moving average over *rows* is only a 7-*day* average if every day has a row, so build a date spine first and fill missing days with 0. The spine starts 6 days early so the first output day has a full window. PostgreSQL: `generate_series(DATE '2026-01-26', DATE '2026-02-16', INTERVAL '1 day')`; BigQuery: `UNNEST(GENERATE_DATE_ARRAY('2026-01-26', '2026-02-16'))`.

Expected output:

| day | revenue | avg_7d |
|---|---|---|
| 2026-02-01 | 0 | 0 |
| 2026-02-02 | 0 | 0 |
| 2026-02-03 | 0 | 0 |
| 2026-02-04 | 0 | 0 |
| 2026-02-05 | 5.8 | 1.16 |
| 2026-02-06 | 9.8 | 2.6 |
| 2026-02-07 | 17.1 | 4.67 |
| 2026-02-08 | 6 | 5.53 |
| 2026-02-09 | 12 | 7.24 |
| 2026-02-10 | 0 | 7.24 |
| 2026-02-11 | 0 | 7.24 |
| 2026-02-12 | 0 | 6.41 |
| 2026-02-13 | 0 | 5.01 |
| 2026-02-14 | 0 | 2.57 |
| 2026-02-15 | 0 | 1.71 |
| 2026-02-16 | 4.4 | 0.63 |

**Follow-ups:**
- How would you do this with `RANGE BETWEEN INTERVAL '6 days' PRECEDING AND CURRENT ROW` instead?
- When is it wrong to fill missing days with 0?

**Difficulty:** Hard


---

### Q14: Monthly revenue by category (pivot)

Produce one row per month (`YYYY-MM`) with a delivered-revenue column for each category: Dairy-Free, Bakery, Produce and Pantry.

**Answer:**
```sql
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
```
Conditional aggregation (`SUM(CASE ...)`) pivots portably on any engine. The month format function differs by engine: `STRFTIME` (DuckDB), `TO_CHAR(order_date, 'YYYY-MM')` (PostgreSQL), `FORMAT_DATE('%Y-%m', order_date)` (BigQuery).

Expected output:

| month | dairy_free | bakery | produce | pantry |
|---|---|---|---|---|
| 2026-01 | 30.5 | 15.5 | 1.8 | 0 |
| 2026-02 | 18.3 | 11 | 13.8 | 12 |
| 2026-03 | 0 | 18.5 | 8.4 | 12 |

**Follow-ups:**
- How would you do this with BigQuery's `PIVOT` operator?
- How would you handle categories that aren't known in advance?

**Difficulty:** Medium


---

### Q15: Same-day delivery rate

Return two percentages, rounded to 1 decimal place: the share of **all** delivered orders that were delivered on the order date, and the same share for customers' **first** delivered orders only.

**Answer:**
```sql
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
```
The average of a 0/1 flag is a rate. `CASE WHEN rn = 1 THEN same_day END` yields NULL for other rows, and `AVG` ignores NULLs, which neatly restricts the second rate to first orders.

Expected output:

| same_day_pct_all | same_day_pct_first_orders |
|---|---|
| 60 | 66.7 |

**Follow-ups:**
- Why multiply by `100.0` rather than `100`?
- How would you break this down by region and month?

**Difficulty:** Medium


---

### Q16: 30-day repeat purchase rate

What percentage of customers who placed a delivered order went on to place **another** delivered order within 30 days of their first one?

**Answer:**
```sql
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
```
Find each customer's first order date, then check whether a later order falls inside the 30-day window. Ben's cancelled order doesn't count, so Ben isn't a 30-day repeater. In PostgreSQL write `INTERVAL '30 days'`.

Expected output:

| repeat_30d_pct |
|---|
| 50 |

**Follow-ups:**
- How would you turn this into a monthly cohort retention table?
- Should same-day second orders count as repeats?

**Difficulty:** Medium


---

### Q17: Top 2 products per category by revenue

For each category, return the top 2 products by delivered revenue. If products tie, include all tied products.

**Answer:**
```sql
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
```
A ranking function partitioned by category is the standard "top N per group" pattern. Engines that support `QUALIFY` (BigQuery, Snowflake, DuckDB) let you filter on the rank without the extra CTE.

Expected output:

| category | name | revenue | rnk |
|---|---|---|---|
| Bakery | Bagels 6-pack | 24.5 | 1 |
| Bakery | Sourdough Loaf | 20.5 | 2 |
| Dairy-Free | Oat Milk 1L | 20.9 | 1 |
| Dairy-Free | Almond Milk 1L | 15 | 2 |
| Pantry | Coffee Beans 1kg | 24 | 1 |
| Produce | Bananas 1kg | 17.4 | 1 |
| Produce | Spinach 250g | 6.6 | 2 |

**Follow-ups:**
- Rewrite this using `QUALIFY`.
- How would you return exactly 2 rows per category even when there are ties?

**Difficulty:** Medium


---

### Q18: Customers who ordered on 3+ consecutive days

Find customers who placed delivered orders on at least 3 consecutive calendar days. Return the customer and the start and end of each such streak.

**Answer:**
```sql
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
```
This is the classic islands trick: on consecutive days the date and the row number both go up by 1, so `date - row_number` stays constant within a streak and can be used as a group key. Deduplicate dates first, or two orders on the same day would break the pattern.

Expected output:

| customer_id | streak_start | streak_end | days |
|---|---|---|---|
| 1 | 2026-01-03 | 2026-01-05 | 3 |
| 5 | 2026-02-07 | 2026-02-09 | 3 |

**Follow-ups:**
- How would you find the longest streak per customer?
- How would you adapt this to allow a gap of at most one day?

**Difficulty:** Hard


---

### Q19: Contiguous ranges of pipeline success and failure

`pipeline_runs` has one row per day. Collapse it into contiguous ranges of the same status, showing `status`, `start_date`, `end_date` and the number of days.

**Answer:**
```sql
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
```
Flag each row whose status differs from the previous row, then a running sum of the flags gives every island its own ID. This version doesn't depend on the dates being consecutive, so it is more general than the `date - row_number` trick.

Expected output:

| status | start_date | end_date | days |
|---|---|---|---|
| success | 2026-03-01 | 2026-03-03 | 3 |
| failed | 2026-03-04 | 2026-03-05 | 2 |
| success | 2026-03-06 | 2026-03-09 | 4 |
| failed | 2026-03-10 | 2026-03-10 | 1 |
| success | 2026-03-11 | 2026-03-12 | 2 |

**Follow-ups:**
- What's the longest failure streak, and when did it start?
- How would you treat a missing day (no run at all)?

**Difficulty:** Hard


---

### Q20: Histogram of orders per customer, including zero

Show how many customers have 0, 1, 2, … delivered orders, up to the highest count. Every bucket from 0 to the maximum must appear, even if it is empty.

**Answer:**
```sql
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
```
Two traps here: the status filter must go in the `ON` clause (in `WHERE` it would drop customers with no orders), and empty buckets only appear if you generate them with a number spine and `LEFT JOIN` the counts onto it.

Expected output:

| n_orders | customers |
|---|---|
| 0 | 2 |
| 1 | 1 |
| 2 | 2 |
| 3 | 2 |
| 4 | 1 |

**Follow-ups:**
- What goes wrong if you write `COUNT(*)` instead of `COUNT(o.order_id)`?
- How would you generate the spine on an engine without `generate_series`?

**Difficulty:** Hard


---

### Q21: Last package that fits in the van

Packages are loaded in `load_order`. The van holds at most 50 kg. Return the `package_id` of the last package that fits.

**Answer:**
```sql
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
```
A running sum in loading order gives the cumulative weight; the last row still within capacity is the answer (12 + 8 + 15 + 10 = 45 kg).

Expected output:

| package_id |
|---|
| 4 |

**Follow-ups:**
- How would you split all packages across as many vans as needed (a van number per package)?
- What if packages could be skipped when they don't fit?

**Difficulty:** Medium


---

### Q22: Median order value per region

Return the median delivered-order revenue for each region.

**Answer:**
```sql
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
```
`PERCENTILE_CONT(0.5)` interpolates between the two middle values when the count is even; `PERCENTILE_DISC` returns an actual value from the data. BigQuery offers `PERCENTILE_CONT` as an analytic function, or `APPROX_QUANTILES` for large data.

Expected output:

| region | median_revenue |
|---|---|
| East | 6.5 |
| North | 9 |
| South | 14 |
| West | 11.9 |

**Follow-ups:**
- How would you compute the median without any percentile function?
- Why might you prefer the median to the mean for order values?

**Difficulty:** Hard


---

### Q23: Remove duplicate events

Event 13 is a duplicate of event 8: same customer, timestamp and type, ingested twice. Write a query that returns the deduplicated events, keeping the lowest `event_id` from each duplicate group.

**Answer:**
```sql
SELECT event_id, customer_id, event_time, event_type
FROM (
  SELECT *,
         ROW_NUMBER() OVER (PARTITION BY customer_id, event_time, event_type ORDER BY event_id) AS rn
  FROM app_events
) t
WHERE rn = 1
ORDER BY event_id;
```
Partition by the columns that define a duplicate (the business key) and keep `rn = 1`. To delete the duplicates in place, run `DELETE FROM app_events WHERE event_id IN (...the rn > 1 ids...)`.

Expected output:

| event_id | customer_id | event_time | event_type |
|---|---|---|---|
| 1 | 1 | 2026-02-07 09:00 | view |
| 2 | 1 | 2026-02-07 09:05 | add_to_cart |
| 3 | 1 | 2026-02-07 09:20 | purchase |
| 4 | 1 | 2026-02-07 11:00 | view |
| 5 | 1 | 2026-02-07 11:10 | view |
| 6 | 2 | 2026-02-07 10:00 | view |
| 7 | 2 | 2026-02-07 10:40 | view |
| 8 | 2 | 2026-02-07 10:45 | add_to_cart |
| 9 | 5 | 2026-02-07 08:00 | view |
| 10 | 5 | 2026-02-07 08:10 | add_to_cart |
| 11 | 5 | 2026-02-07 08:15 | purchase |
| 12 | 8 | 2026-02-07 12:00 | view |

**Follow-ups:**
- Write the `DELETE` version.
- How would you prevent duplicates at ingestion time (idempotency keys, `MERGE`)?

**Difficulty:** Medium


---

### Q24: Sessionize app events (30-minute inactivity gap)

A new session starts when a customer has been inactive for more than 30 minutes. Assign a session number per customer to each (deduplicated) event, then report each session's start, end and number of events.

**Answer:**
```sql
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
```
This uses the same flag-and-running-sum pattern as the pipeline-runs problem. The first event per customer has a NULL `LAG`, so the comparison isn't true and it falls into the `ELSE 1` branch, correctly starting session 1. In PostgreSQL write `INTERVAL '30 minutes'`.

Expected output:

| customer_id | session_no | session_start | session_end | events |
|---|---|---|---|---|
| 1 | 1 | 2026-02-07 09:00 | 2026-02-07 09:20 | 3 |
| 1 | 2 | 2026-02-07 11:00 | 2026-02-07 11:10 | 2 |
| 2 | 1 | 2026-02-07 10:00 | 2026-02-07 10:00 | 1 |
| 2 | 2 | 2026-02-07 10:40 | 2026-02-07 10:45 | 2 |
| 5 | 1 | 2026-02-07 08:00 | 2026-02-07 08:15 | 3 |
| 8 | 1 | 2026-02-07 12:00 | 2026-02-07 12:00 | 1 |

**Follow-ups:**
- How would you compute the average session length?
- How would you do this incrementally in a streaming pipeline (session windows)?

**Difficulty:** Hard


---

### Q25: Conversion funnel

Using the app events, count the distinct customers who reached each step (view → add_to_cart → purchase) and the conversion rate from view to purchase.

**Answer:**
```sql
SELECT COUNT(DISTINCT CASE WHEN event_type = 'view'        THEN customer_id END) AS viewed,
       COUNT(DISTINCT CASE WHEN event_type = 'add_to_cart' THEN customer_id END) AS added_to_cart,
       COUNT(DISTINCT CASE WHEN event_type = 'purchase'    THEN customer_id END) AS purchased,
       ROUND(100.0 * COUNT(DISTINCT CASE WHEN event_type = 'purchase' THEN customer_id END)
                   / COUNT(DISTINCT CASE WHEN event_type = 'view'     THEN customer_id END), 1) AS view_to_purchase_pct
FROM app_events;
```
`COUNT(DISTINCT CASE ...)` counts each customer once per step, which also makes the result immune to the duplicate event.

Expected output:

| viewed | added_to_cart | purchased | view_to_purchase_pct |
|---|---|---|---|
| 4 | 3 | 2 | 50 |

**Follow-ups:**
- How would you require the steps to happen *in order* within the same session?
- How would you show drop-off between each pair of steps?

**Difficulty:** Medium


---

### Q26: Signups by referral source

Count signups by referrer name, labelling customers without a referrer as `organic`.

**Answer:**
```sql
SELECT COALESCE(r.name, 'organic') AS referral_source, COUNT(*) AS signups
FROM customers c
LEFT JOIN customers r ON r.customer_id = c.referred_by
GROUP BY COALESCE(r.name, 'organic')
ORDER BY signups DESC, referral_source;
```
A self-join resolves the referrer's name, and `COALESCE` labels the NULLs. A common bug is filtering with `WHERE referred_by <> 1` to mean "not referred by Asha": that silently drops every organic customer, because `NULL <> 1` is not true.

Expected output:

| referral_source | signups |
|---|---|
| organic | 4 |
| Asha Rao | 2 |
| Ben Ortiz | 1 |
| Chen Li | 1 |

**Follow-ups:**
- How would you correctly list customers **not** referred by customer 1?
- Which referrers brought in customers who went on to order?

**Difficulty:** Easy

