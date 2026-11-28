# Real-World Asked: SQL

SQL questions reported from real data engineering interviews. Answers were tested on DuckDB, with a BigQuery version wherever the syntax differs.

See [README.md](README.md) for the layout and contributor rules. Fields are left blank when unknown.

## Unspecified company

### Q1: Select every column except one

A table has 100 columns. How do you return 99 of them without typing all 99 column names?

**Answer:**
```sql
-- Standard SQL (tested on DuckDB)
SELECT * EXCLUDE (tax_id) FROM accounts;
```
BigQuery supports `SELECT * EXCEPT (col, ...)`; DuckDB and Snowflake call it `EXCLUDE`. ANSI SQL has no equivalent, so on PostgreSQL or MySQL you would generate the column list from `information_schema.columns`. In BigQuery, `EXCEPT` also cuts cost, because excluded columns aren't scanned.

**BigQuery version:**
```sql
SELECT * EXCEPT (tax_id) FROM `mydataset.accounts`;
```

**Follow-ups:**
- How would you replace one column's value while keeping the others (`SELECT * REPLACE`)?
- Why is `SELECT *` discouraged on wide BigQuery tables even with `EXCEPT`?

**Difficulty:** Easy

**Role:** 

**Round:** 

**Asked:** 

---

### Q2: Swap names between adjacent rows

Given rows with consecutive IDs 1–5 and a name per row, swap the names of each pair (1↔2, 3↔4). If the last row has no partner, it keeps its own name.

**Answer:**
```sql
-- Standard SQL (tested on DuckDB)
SELECT id, name,
       COALESCE(CASE WHEN id % 2 = 0 THEN LAG(name)  OVER (ORDER BY id)
                     ELSE                  LEAD(name) OVER (ORDER BY id) END,
                name) AS swapped_name
FROM seats
ORDER BY id;
```
Even IDs take the previous row's name and odd IDs take the next row's name. For the last odd row, `LEAD` returns NULL, and `COALESCE`/`IFNULL` falls back to the row's own name. BigQuery uses `MOD()` instead of `%`.

**BigQuery version:**
```sql
SELECT id, name,
       IFNULL(CASE WHEN MOD(id, 2) = 0 THEN LAG(name)  OVER (ORDER BY id)
                   ELSE                     LEAD(name) OVER (ORDER BY id) END,
              name) AS swapped_name
FROM `mydataset.seats`
ORDER BY id;
```

**Follow-ups:**
- How would you solve this with a self-join instead of window functions?
- What breaks if the IDs have gaps, and how would you fix it with `ROW_NUMBER()`?

**Difficulty:** Medium

**Role:** 

**Round:** 

**Asked:** 

---

### Q3: Top 3 scorers per season

A table holds each player's total points per season. Return the top 3 point scorers for every season.

**Answer:**
```sql
-- Standard SQL (tested on DuckDB)
SELECT season, player, points
FROM (
  SELECT season, player, points,
         ROW_NUMBER() OVER (PARTITION BY season ORDER BY points DESC) AS rn
  FROM season_points
) ranked
WHERE rn <= 3
ORDER BY season, rn;
```
Rank within each season and keep ranks 1–3. BigQuery's `QUALIFY` filters on the window result without a subquery; it needs a `WHERE`, `GROUP BY` or `HAVING` clause alongside it, hence `WHERE TRUE`.

**BigQuery version:**
```sql
SELECT season, player, points
FROM `mydataset.season_points`
WHERE TRUE
QUALIFY ROW_NUMBER() OVER (PARTITION BY season ORDER BY points DESC) <= 3
ORDER BY season, points DESC;
```

**Follow-ups:**
- How should ties at third place be handled: `ROW_NUMBER`, `RANK` or `DENSE_RANK`?
- How would you return the top scorer's margin over second place?

**Difficulty:** Easy

**Role:** 

**Round:** 

**Asked:** 

---

### Q4: Previous and next day's sales

For a daily sales table, show each day's amount next to the previous day's and the next day's amount.

**Answer:**
```sql
-- Standard SQL (tested on DuckDB)
SELECT sales_date, sales_amt,
       LAG(sales_amt)  OVER (ORDER BY sales_date) AS prev_amt,
       LEAD(sales_amt) OVER (ORDER BY sales_date) AS next_amt
FROM daily_sales
ORDER BY sales_date;
```
`LAG` reads the previous row and `LEAD` the next row in the window order. The first row has no previous value and the last row has no next value, so both return NULL there; pass a third argument (e.g. `LAG(sales_amt, 1, 0)`) for a default.

**Follow-ups:**
- How would you compute the day-over-day change and percentage change?
- What happens when a date is missing from the table, and how would you fill it?

**Difficulty:** Easy

**Role:** 

**Round:** 

**Asked:** 

---

### Q5: Cumulative sales

For the same daily sales table, add a column with the cumulative sales up to and including each day.

**Answer:**
```sql
-- Standard SQL (tested on DuckDB)
SELECT sales_date, sales_amt,
       SUM(sales_amt) OVER (ORDER BY sales_date
                            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cumulative_sales
FROM daily_sales2
ORDER BY sales_date;
```
A windowed `SUM` with a running frame. Prefer this to adding `LAG` values: `SUM` simply skips NULL amounts, whereas arithmetic with NULLs from `LAG` turns the whole result NULL.

**Follow-ups:**
- How would you restart the running total every month?
- What's the difference between the `ROWS` and the default `RANGE` frame when two rows share a date?

**Difficulty:** Easy

**Role:** 

**Round:** 

**Asked:** 

---

### Q6: Count skill hashtags in free text

A profile text contains hashtags such as `#Spark`, `#Glue` and `#Scala`. Count how many times each hashtag appears.

**Answer:**
```sql
-- Standard SQL (tested on DuckDB)
SELECT tag, COUNT(*) AS occurrences
FROM (
  SELECT UNNEST(regexp_extract_all(details, '#(\w+)', 1)) AS tag
  FROM profiles
) t
GROUP BY tag
ORDER BY occurrences DESC, tag;
```
Extract every hashtag into an array with a regular expression, flatten the array into rows, and group. This finds any hashtag, so you don't have to hard-code one expression per skill (the other common approach is `ARRAY_LENGTH(REGEXP_EXTRACT_ALL(details, r'#Spark'))` per column).

**BigQuery version:**
```sql
SELECT tag, COUNT(*) AS occurrences
FROM `mydataset.profiles`,
     UNNEST(REGEXP_EXTRACT_ALL(details, r'#(\w+)')) AS tag
GROUP BY tag
ORDER BY occurrences DESC, tag;
```

**Follow-ups:**
- How would you make the count case-insensitive?
- How would you return one row per profile with a column per skill?

**Difficulty:** Medium

**Role:** 

**Round:** 

**Asked:** 

---

### Q7: Net profit per stock from buy and sell trades

A trades table has the stock name (with inconsistent letter case), trade type (`BUY`/`SELL`), share price and quantity. Return the net profit per stock, i.e. total sell value minus total buy value.

**Answer:**
```sql
-- Standard SQL (tested on DuckDB)
SELECT UPPER(name) AS stock,
       SUM(CASE WHEN t_type = 'SELL' THEN share_price * quantity
                ELSE -share_price * quantity END) AS net_profit
FROM trades
GROUP BY UPPER(name)
ORDER BY stock;
```
Sign each trade (sells positive, buys negative) and sum per normalized name; grouping on `UPPER(name)` merges `crux` and `CRUX`. The original note's expected output mixed per-share and total values; this version uses total value (price × quantity) consistently.

**Follow-ups:**
- How would you compute realized profit when buys and sells happen in several lots (FIFO matching)?
- How would you flag stocks that were sold without a matching buy?

**Difficulty:** Medium

**Role:** 

**Round:** 

**Asked:** 

---

### Q8: Pivot student marks by subject

A table has one row per student per subject with the marks. Produce one row per student with a column per subject (ML, DL, DS), without using a `PIVOT` operator.

**Answer:**
```sql
-- Standard SQL (tested on DuckDB)
SELECT student_id,
       MAX(CASE WHEN subject = 'ML' THEN marks END) AS ml,
       MAX(CASE WHEN subject = 'DL' THEN marks END) AS dl,
       MAX(CASE WHEN subject = 'DS' THEN marks END) AS ds
FROM marks
GROUP BY student_id
ORDER BY student_id;
```
Conditional aggregation: each `CASE` keeps only one subject's marks and `MAX` collapses the student's rows into one. It works on every engine; BigQuery also has a `PIVOT` operator.

**BigQuery version:**
```sql
-- With BigQuery's PIVOT operator
SELECT *
FROM `mydataset.marks`
PIVOT (MAX(marks) FOR subject IN ('ML' AS ml, 'DL' AS dl, 'DS' AS ds))
ORDER BY student_id;
```

**Follow-ups:**
- How would you unpivot the result back to rows (`UNPIVOT` or `UNION ALL`)?
- How would you handle subjects that aren't known in advance?

**Difficulty:** Easy

**Role:** 

**Round:** 

**Asked:** 

---

### Q9: Expand rows into consecutive dates

Each row has a key `c1`, a count `c2` and a start date `c3`. Produce `c2` rows per key, numbered 1..`c2`, with dates starting at `c3` and increasing by one day.

**Answer:**
```sql
-- Standard SQL (tested on DuckDB)
SELECT r.c1, g.n AS c2, CAST(r.c3 + (g.n - 1) * INTERVAL 1 DAY AS DATE) AS c3
FROM ranges r,
     LATERAL (SELECT UNNEST(generate_series(1, r.c2)) AS n) g
ORDER BY r.c1, g.n;
```
Generate a number series 1..`c2` per row (a correlated `UNNEST`/`LATERAL`), then add `n - 1` days to the start date. In BigQuery, `GENERATE_ARRAY` plus `UNNEST` does this in one step.

**BigQuery version:**
```sql
SELECT r.c1, n AS c2, DATE_ADD(r.c3, INTERVAL n - 1 DAY) AS c3
FROM `mydataset.ranges` r,
     UNNEST(GENERATE_ARRAY(1, r.c2)) AS n
ORDER BY r.c1, n;
```

**Follow-ups:**
- How would you do this on an engine without series functions (recursive CTE)?
- How would you skip weekends when generating the dates?

**Difficulty:** Medium

**Role:** 

**Round:** 

**Asked:** 

---

### Q10: First vs repeat purchases per month

An invoices table has `cust_id`, `invoice_date`, `invoice_no` and `purchase_amount`. For each month, return the number and total amount of customers' **first-ever** purchases, and the number and total of all other purchases.

**Answer:**
```sql
-- Standard SQL (tested on DuckDB)
WITH ranked AS (
  SELECT cust_id, invoice_date, purchase_amount,
         ROW_NUMBER() OVER (PARTITION BY cust_id ORDER BY invoice_date, invoice_no) AS rn
  FROM invoices
)
SELECT strftime(invoice_date, '%Y-%m') AS month_year,
       COUNT(CASE WHEN rn = 1 THEN 1 END)                    AS first_purchase_count,
       COALESCE(SUM(CASE WHEN rn = 1 THEN purchase_amount END), 0) AS first_purchase_amount,
       COUNT(CASE WHEN rn > 1 THEN 1 END)                    AS repeat_purchase_count,
       COALESCE(SUM(CASE WHEN rn > 1 THEN purchase_amount END), 0) AS repeat_purchase_amount
FROM ranked
GROUP BY 1
ORDER BY 1;
```
Number each customer's purchases by date (the invoice number breaks same-day ties); `rn = 1` is the first-ever purchase. Then aggregate per month with conditional counts and sums. BigQuery has `COUNTIF` and `IF` shortcuts.

**BigQuery version:**
```sql
WITH ranked AS (
  SELECT cust_id, invoice_date, purchase_amount,
         ROW_NUMBER() OVER (PARTITION BY cust_id ORDER BY invoice_date, invoice_no) AS rn
  FROM `mydataset.invoices`
)
SELECT FORMAT_DATE('%Y-%m', invoice_date) AS month_year,
       COUNTIF(rn = 1)                         AS first_purchase_count,
       IFNULL(SUM(IF(rn = 1, purchase_amount, NULL)), 0) AS first_purchase_amount,
       COUNTIF(rn > 1)                         AS repeat_purchase_count,
       IFNULL(SUM(IF(rn > 1, purchase_amount, NULL)), 0) AS repeat_purchase_amount
FROM ranked
GROUP BY month_year
ORDER BY month_year;
```

**Follow-ups:**
- How would you compute the share of revenue from new customers per month?
- How would you count a customer as new only in their first month, even if they bought twice that month?

**Difficulty:** Medium

**Role:** 

**Round:** 

**Asked:**

## Deloitte

### Q11: Calculate each movie's average rating.

**Answer:**
Join ratings to movies, aggregate per movie, and use a `LEFT JOIN` if movies without ratings must still appear:

```sql
-- Standard SQL (tested on DuckDB)
SELECT m.movie_id, m.title,
       ROUND(AVG(r.rating), 2) AS avg_rating,
       COUNT(r.rating)         AS num_ratings
FROM movies m
LEFT JOIN ratings r ON r.movie_id = m.movie_id
GROUP BY m.movie_id, m.title
ORDER BY avg_rating DESC NULLS LAST;
```
`AVG` ignores NULLs, so unrated movies get a NULL average rather than 0. If ratings are integers, some engines (e.g. SQL Server) do integer division, so cast first (`AVG(CAST(rating AS DECIMAL))`). For a fair ranking, filter with `HAVING COUNT(*) >= n` so a movie with a single 5-star rating doesn't top the list.

**Follow-ups:**
- How would you return only movies with at least 2 ratings?
- How would you compute a Bayesian (weighted) average rating?

**Difficulty:** Easy


**Role:** Azure Data Engineer

**Round:** Round 1 – Technical

**Asked:** 

---

### Q12: Find the most active user, breaking ties alphabetically by name.

**Answer:**
Count activity per user, then order by count descending and name ascending, so ties resolve to the lexicographically smallest name:

```sql
-- Standard SQL (tested on DuckDB)
SELECT u.name, COUNT(*) AS activity_count
FROM activity a
JOIN users u ON u.user_id = a.user_id
GROUP BY u.user_id, u.name
ORDER BY activity_count DESC, u.name ASC
LIMIT 1;
```
Ravi and Anita both have 2 activities; `ORDER BY ..., name ASC` returns Anita. To return **all** tied users, use `RANK() OVER (ORDER BY COUNT(*) DESC)` and keep rank 1 instead of `LIMIT 1`.

**Follow-ups:**
- How would you return the most active user per month?
- How would you handle case differences in names when tie-breaking?

**Difficulty:** Easy


**Role:** Azure Data Engineer

**Round:** Round 1 – Technical

**Asked:** 

---

### Q13: Split comma-separated values in a column into separate rows.

**Answer:**
Split the string into an array, then unnest the array into rows. Trim spaces, and skip empty items:

```sql
-- Standard SQL (tested on DuckDB)
SELECT emp_id, TRIM(skill) AS skill
FROM (SELECT emp_id, UNNEST(string_split(skill_list, ',')) AS skill FROM skills) t
WHERE TRIM(skill) <> ''
ORDER BY emp_id, skill;
```
Each engine has its own split function: `SPLIT` + `UNNEST` in BigQuery, `string_split` / `STRING_SPLIT` in DuckDB and SQL Server, `regexp_split_to_table` in PostgreSQL, and `explode(split(col, ','))` in Spark SQL. Rows with NULL lists disappear after a cross join with `UNNEST`; use `LEFT JOIN UNNEST(...)` to keep them.

**BigQuery version:**
```sql
SELECT emp_id, TRIM(skill) AS skill
FROM `mydataset.skills`,
     UNNEST(SPLIT(skill_list, ',')) AS skill
WHERE TRIM(skill) != ''
ORDER BY emp_id, skill;
```

**Follow-ups:**
- How would you keep each value's position in the list?
- How would you go the other way and aggregate rows back into a comma-separated string?

**Difficulty:** Easy


**Role:** Azure Data Engineer

**Round:** Round 1 – Technical

**Asked:** 

---

### Q14: Turn pipe-delimited values into a proper table (unpivot them into rows).

**Answer:**
Each row holds `key|value` pairs packed into one string. Split the pairs, then split each pair into its key and value:

```sql
-- Standard SQL (tested on DuckDB)
SELECT id,
       split_part(pair, '=', 1) AS attribute,
       split_part(pair, '=', 2) AS value
FROM (SELECT id, UNNEST(string_split(attrs, '|')) AS pair FROM raw_attrs) t
ORDER BY id, attribute;
```
If instead each pipe-separated position is a fixed column (`2024-01-01|North|120`), split once and pick positions (`SPLIT(line, '|')[SAFE_OFFSET(1)] AS region`), which gives a wide table. Unpivoting turns wide columns into rows; in BigQuery, `UNPIVOT` does that for real columns.

**BigQuery version:**
```sql
SELECT id,
       SPLIT(pair, '=')[SAFE_OFFSET(0)] AS attribute,
       SPLIT(pair, '=')[SAFE_OFFSET(1)] AS value
FROM `mydataset.raw_attrs`,
     UNNEST(SPLIT(attrs, '|')) AS pair
ORDER BY id, attribute;
```

**Follow-ups:**
- How would you pivot the result back to one column per attribute?
- How do you handle a value that itself contains a pipe character?

**Difficulty:** Medium


**Role:** Azure Data Engineer

**Round:** Round 1 – Technical

**Asked:** 

---

### Q15: Given `customers` and `orders` tables, find customers who have never placed an order.

**Answer:**
This is an **anti-join**. It's worked through with sample data and expected output in the FreshCart practice set: [`sql-coding-questions.md` Q1](../sql/sql-coding-questions.md). The two standard forms:

```sql
-- Standard SQL (tested on DuckDB)
-- LEFT JOIN ... IS NULL
SELECT c.customer_id, c.name
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
WHERE o.order_id IS NULL;
```
Avoid `NOT IN (SELECT customer_id FROM orders)`: one NULL `customer_id` in `orders` (like order 13 here) makes it return no rows at all.

**BigQuery version:**
```sql
-- NOT EXISTS (same in BigQuery)
SELECT c.customer_id, c.name
FROM `mydataset.customers` c
WHERE NOT EXISTS (SELECT 1 FROM `mydataset.orders` o WHERE o.customer_id = c.customer_id);
```

**Follow-ups:**
- Why does `NOT IN` break when the subquery contains NULL?
- How would you find customers with no orders in the last 90 days?

**Difficulty:** Easy


**Role:** Data Engineer

**Round:** L1

**Asked:** 

---

### Q16: Calculate a running total of order amounts for each customer.

**Answer:**
Use a windowed `SUM` partitioned by customer and ordered by date, with an explicit row frame:

```sql
-- Standard SQL (tested on DuckDB)
SELECT customer_id, order_date, amount,
       SUM(amount) OVER (PARTITION BY customer_id ORDER BY order_date
                         ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_total
FROM cust_orders
ORDER BY customer_id, order_date;
```
Without the `ROWS` frame, the default `RANGE` frame adds together rows that share the same date. If a customer can have two orders on the same day, add a tie-breaker (`ORDER BY order_date, order_id`). The FreshCart set has a per-region variant ([Q12](../sql/sql-coding-questions.md)).

**Follow-ups:**
- How would you restart the running total each month?
- How would you compute it without window functions?

**Difficulty:** Easy


**Role:** Data Engineer

**Round:** L1

**Asked:** 

---

### Q17: Given website login data, find users who logged in on 3 consecutive days.

**Answer:**
A **gaps-and-islands** problem: deduplicate to one row per user per day, then `date - ROW_NUMBER()` is constant within a run of consecutive days. Full worked example with data: [FreshCart Q18](../sql/sql-coding-questions.md).

```sql
-- Standard SQL (tested on DuckDB)
WITH days AS (
  SELECT DISTINCT user_id, CAST(login_ts AS DATE) AS d FROM logins
),
grp AS (
  SELECT user_id, d,
         d - CAST(ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY d) AS INT) AS island
  FROM days
)
SELECT user_id, MIN(d) AS streak_start, MAX(d) AS streak_end
FROM grp
GROUP BY user_id, island
HAVING COUNT(*) >= 3;
```
An alternative for exactly 3 days: `LAG(d, 1)` and `LAG(d, 2)` and check they're 1 and 2 days earlier. The islands version generalizes to any streak length.

**BigQuery version:**
```sql
WITH days AS (
  SELECT DISTINCT user_id, DATE(login_ts) AS d FROM `mydataset.logins`
),
numbered AS (
  SELECT user_id, d, ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY d) AS rn FROM days
)
SELECT user_id, MIN(d) AS streak_start, MAX(d) AS streak_end
FROM numbered
GROUP BY user_id, DATE_SUB(d, INTERVAL rn DAY)
HAVING COUNT(*) >= 3;
```

**Follow-ups:**
- How would you find each user's longest streak?
- How would you allow one missed day inside a streak?

**Difficulty:** Medium


**Role:** Data Engineer

**Round:** L1

**Asked:** 

---

### Q18: Using window functions, find each user's second most recent login.

**Answer:**
Rank logins per user by time descending and keep rank 2. Use `DENSE_RANK` or deduplicate if a user can log in twice at the same timestamp:

```sql
-- Standard SQL (tested on DuckDB)
SELECT user_id, login_ts AS second_latest_login
FROM (
  SELECT user_id, login_ts,
         ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY login_ts DESC) AS rn
  FROM user_logins
) t
WHERE rn = 2;
```
User 2 has only one login, so they don't appear. To show them with NULL, compute `NTH_VALUE(login_ts, 2) OVER (...)` or left-join this result back to the user list.

**BigQuery version:**
```sql
SELECT user_id, login_ts AS second_latest_login
FROM `mydataset.user_logins`
WHERE TRUE
QUALIFY ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY login_ts DESC) = 2;
```

**Follow-ups:**
- How would you return the time gap between the latest and second-latest login?
- What changes if logins can share the exact same timestamp?

**Difficulty:** Easy


**Role:** Data Engineer (3+ years)

**Round:** 

**Asked:** 

---

### Q19: What does the `MERGE` statement do, and how is it different from an "upsert"?

**Answer:**
`MERGE` compares a **source** with a **target** on a join condition and, in one atomic statement, can:
- `WHEN MATCHED [AND ...] THEN UPDATE` or `DELETE`
- `WHEN NOT MATCHED [BY TARGET] THEN INSERT`
- `WHEN NOT MATCHED BY SOURCE THEN DELETE` / `UPDATE` (BigQuery, SQL Server), for rows that disappeared from the source

**Upsert** is the general idea of "update if it exists, otherwise insert". `MERGE` is the standard SQL statement that implements it and goes further (conditional updates, deletes, handling missing source rows). Other engines provide upsert-only syntax, e.g. PostgreSQL `INSERT ... ON CONFLICT DO UPDATE` and MySQL `INSERT ... ON DUPLICATE KEY UPDATE`.

```sql
-- Standard SQL (tested on DuckDB)
MERGE INTO tgt t
USING src s ON t.id = s.id
WHEN MATCHED AND t.v <> s.v THEN UPDATE SET v = s.v
WHEN NOT MATCHED THEN INSERT (id, v) VALUES (s.id, s.v);
SELECT * FROM tgt ORDER BY id;
```
The source must have **at most one row per key**, or `MERGE` fails ("multiple source rows matched"), so deduplicate the source first. In BigQuery, a partition filter in the `ON` clause limits how much of the target is scanned.

**BigQuery version:**
```sql
MERGE `mydataset.tgt` t
USING `mydataset.src` s ON t.id = s.id
WHEN MATCHED AND t.v != s.v THEN UPDATE SET v = s.v
WHEN NOT MATCHED THEN INSERT (id, v) VALUES (s.id, s.v)
WHEN NOT MATCHED BY SOURCE THEN DELETE;
```

**Follow-ups:**
- How do you use `MERGE` for an SCD Type 2 load?
- What happens if two source rows match the same target row?

**Difficulty:** Medium


**Role:** Data Engineer (3+ years)

**Round:** 

**Asked:** 

## HCLTech

### Q20: How do you delete duplicate records while keeping the latest version of each?

**Also asked at:** Deloitte

**Answer:**
Rank the rows within each business key by recency and remove everything except rank 1. The standard pattern deletes by a unique row identifier:

```sql
-- Standard SQL (tested on DuckDB)
DELETE FROM customer_stage
WHERE row_id IN (
  SELECT row_id FROM (
    SELECT row_id,
           ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY updated_at DESC, row_id DESC) AS rn
    FROM customer_stage
  ) t
  WHERE rn > 1
);
SELECT * FROM customer_stage ORDER BY customer_id;
```
The tie-breaker (`row_id DESC`) makes the result deterministic when two rows share the same `updated_at`. If there's no unique row ID at all (exact duplicate rows), rebuild the table with `SELECT DISTINCT` or the `QUALIFY` pattern instead. For a recurring load, dedupe in staging before the `MERGE` rather than cleaning the target afterwards.

**BigQuery version:**
```sql
-- BigQuery: rebuild instead of row-by-row DELETE (one scan, no DML on huge tables)
CREATE OR REPLACE TABLE `mydataset.customer_stage` AS
SELECT *
FROM `mydataset.customer_stage`
WHERE TRUE
QUALIFY ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY updated_at DESC) = 1;
```

**Follow-ups:**
- How do you dedupe when rows are exact duplicates with no unique column?
- How would you keep the earliest record instead of the latest?

**Difficulty:** Medium


**Role:** Lead Data Engineer

**Round:** Round 1 – Technical

**Asked:** 

## JPMorgan

### Q21: What's the difference between an inner join, a left join and an anti join?

**Answer:**
- **Inner join:** only rows with a match on both sides.
- **Left (outer) join:** every row from the left table, with matching right-side columns or NULLs when there's no match.
- **Anti join:** left rows that have **no** match on the right. SQL has no `ANTI JOIN` keyword in most engines; write it as `LEFT JOIN ... WHERE right.key IS NULL` or `NOT EXISTS`. Spark has `how="left_anti"` (and `left_semi` for the opposite).

```sql
-- Standard SQL (tested on DuckDB)
SELECT 'inner' AS kind, e.emp_id FROM emp e JOIN dept d ON d.dept_id = e.dept_id
UNION ALL
SELECT 'left', e.emp_id FROM emp e LEFT JOIN dept d ON d.dept_id = e.dept_id
UNION ALL
SELECT 'anti', e.emp_id FROM emp e WHERE NOT EXISTS (SELECT 1 FROM dept d WHERE d.dept_id = e.dept_id)
ORDER BY kind, emp_id;
```
In PySpark: `emp.join(dept, 'dept_id', 'left_anti')`. Anti joins are the standard way to find orphans, e.g. employees whose department doesn't exist or customers with no orders.

**Follow-ups:**
- What's a semi join, and when is it better than an inner join?
- How do NULL join keys behave in each join type?

**Difficulty:** Easy


**Role:** Senior / Lead Data Engineer

**Round:** Technical Round 1

**Asked:** 

## Persistent Systems

### Q22: Using SQL, list the employees whose salary is higher than their direct manager's.

**Answer:**
Self-join the employees table: one copy as the employee, one as the manager. A worked example with data and expected output is in the FreshCart set: [Q4](../sql/sql-coding-questions.md).

```sql
-- Standard SQL (tested on DuckDB)
SELECT e.name AS employee, e.salary, m.name AS manager, m.salary AS manager_salary
FROM employees e
JOIN employees m ON m.employee_id = e.manager_id
WHERE e.salary > m.salary;
```
The inner self-join naturally excludes the top-level employee (no manager). Group by the ID, not the name, in variants that aggregate, because names can repeat.

**Follow-ups:**
- How would you compare against the manager's manager?
- How would you list managers with at least one report earning more than them?

**Difficulty:** Easy


**Role:** Data Engineer

**Round:** Round 1 – Technical

**Asked:** 

---

### Q23: Which users had over 20 critical orders in each week, for at least a month in a row?

**Answer:**
Count critical orders per user per week, keep the weeks above 20, then look for runs of **consecutive** qualifying weeks (gaps and islands on week numbers). "At least a month" is treated here as 4 consecutive weeks:

```sql
-- Standard SQL (tested on DuckDB)
WITH weekly AS (
  SELECT user_id, date_trunc('week', order_ts) AS wk, COUNT(*) AS critical_orders
  FROM txns
  WHERE priority = 'critical'
  GROUP BY user_id, date_trunc('week', order_ts)
  HAVING COUNT(*) > 20
),
islands AS (
  SELECT user_id, wk,
         wk - (ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY wk)) * INTERVAL 7 DAY AS grp
  FROM weekly
)
SELECT user_id, MIN(wk) AS first_week, MAX(wk) AS last_week, COUNT(*) AS consecutive_weeks
FROM islands
GROUP BY user_id, grp
HAVING COUNT(*) >= 4;
```
User 1 qualifies (5 consecutive weeks with 21 critical orders). User 2 misses week 3, so neither run reaches 4 weeks. Clarify in the interview whether "a month" means 4 consecutive weeks or a calendar month, and whether "more than 20" means > 20 or ≥ 20.

**BigQuery version:**
```sql
WITH weekly AS (
  SELECT user_id, DATE_TRUNC(DATE(order_ts), WEEK(MONDAY)) AS wk
  FROM `mydataset.txns`
  WHERE priority = 'critical'
  GROUP BY user_id, wk
  HAVING COUNT(*) > 20
),
numbered AS (
  SELECT user_id, wk, ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY wk) AS rn FROM weekly
)
SELECT user_id, MIN(wk) AS first_week, MAX(wk) AS last_week, COUNT(*) AS consecutive_weeks
FROM numbered
GROUP BY user_id, DATE_SUB(wk, INTERVAL rn WEEK)
HAVING COUNT(*) >= 4;
```

**Follow-ups:**
- How would you change this for a calendar month instead of 4 weeks?
- How would you make the week start on Sunday?

**Difficulty:** Hard


**Role:** Data Engineer

**Round:** Round 1 – Technical

**Asked:** 

## TEKsystems

### Q24: How do you implement Slowly Changing Dimension (SCD) Type 2 in BigQuery?

**Also asked at:** Deloitte, HCLTech, Wipro

**Answer:**
SCD Type 2 keeps history: when a tracked attribute changes, **close** the current row and **insert** a new current row. Standard two-step version (tested on DuckDB):

```sql
-- 1. Close the current row for customers whose tracked attribute changed
UPDATE dim_customer d
SET valid_to = CURRENT_DATE, is_current = FALSE
FROM stg_customer s
WHERE d.customer_id = s.customer_id AND d.is_current AND d.city <> s.city;

-- 2. Insert a new current row for changed and brand-new customers
INSERT INTO dim_customer (customer_id, city, valid_from, valid_to, is_current)
SELECT s.customer_id, s.city, CURRENT_DATE, NULL, TRUE
FROM stg_customer s
LEFT JOIN dim_customer d ON d.customer_id = s.customer_id AND d.is_current
WHERE d.customer_id IS NULL;
```

**BigQuery version** (a single `MERGE`; changed rows appear twice in the source, once with a NULL join key, so the new version gets inserted):
```sql
MERGE `mydataset.dim_customer` d
USING (
  SELECT customer_id AS join_key, customer_id, city FROM `mydataset.stg_customer`
  UNION ALL
  SELECT NULL AS join_key, s.customer_id, s.city
  FROM `mydataset.stg_customer` s
  JOIN `mydataset.dim_customer` d ON d.customer_id = s.customer_id AND d.is_current
  WHERE d.city <> s.city
) s
ON d.customer_id = s.join_key AND d.is_current
WHEN MATCHED AND d.city <> s.city THEN
  UPDATE SET valid_to = CURRENT_DATE(), is_current = FALSE
WHEN NOT MATCHED THEN
  INSERT (customer_id, city, valid_from, valid_to, is_current)
  VALUES (s.customer_id, s.city, CURRENT_DATE(), NULL, TRUE);
```

With many tracked columns, compare a hash of them (`FARM_FINGERPRINT(...)`) instead of listing every column. In dbt, **snapshots** implement this pattern for you.

**Follow-ups:**
- How would you handle a customer whose record changes twice in the same batch?
- How do you query "which city was this customer in on 1 March"?

**Difficulty:** Hard


**Role:** GCP Data Engineer

**Round:** Technical evaluation

**Asked:** 

## Wipro

### Q25: Rank employees using a CTE and `RANK()`, then join the result to the department table.

**Answer:**
Rank inside a CTE, then join for department names and filter on the rank:

```sql
-- Standard SQL (tested on DuckDB)
WITH ranked AS (
  SELECT emp_id, name, dept_id, salary,
         RANK() OVER (PARTITION BY dept_id ORDER BY salary DESC) AS salary_rank
  FROM staff
)
SELECT d.dept_name, r.name, r.salary, r.salary_rank
FROM ranked r
JOIN departments d ON d.dept_id = r.dept_id
WHERE r.salary_rank <= 2
ORDER BY d.dept_name, r.salary_rank, r.name;
```
`RANK()` gives B and C both rank 1 in Data, and the next rank is 3 (a gap). `DENSE_RANK()` would give the next one rank 2. Ranking before the join keeps the window small and avoids ranking duplicated rows if the join ever fans out.

**Follow-ups:**
- What changes with `DENSE_RANK()` and `ROW_NUMBER()` here?
- How would you show each employee's salary as a percentage of the department maximum?

**Difficulty:** Easy


**Role:** Azure Data Engineer (5+ years)

**Round:** Round 1 – Technical

**Asked:** 

---

### Q26: How would you use joins to reconcile row counts between two tables and spot mismatches?

**Answer:**
Count rows on each side and use joins to classify rows: matched (inner), only in A (left join with no match), only in B (right join with no match):

```sql
-- Standard SQL (tested on DuckDB)
SELECT
  (SELECT COUNT(*) FROM a)                                   AS rows_in_a,
  (SELECT COUNT(*) FROM b)                                   AS rows_in_b,
  (SELECT COUNT(*) FROM a JOIN b ON a.id = b.id)             AS matched,
  (SELECT COUNT(*) FROM a LEFT JOIN b ON a.id = b.id WHERE b.id IS NULL)  AS only_in_a,
  (SELECT COUNT(*) FROM a RIGHT JOIN b ON a.id = b.id WHERE a.id IS NULL) AS only_in_b;
```
Check the arithmetic: `rows_in_a = matched + only_in_a` only holds if the key is unique, so duplicates show up as a mismatch, which is useful in itself. A `FULL OUTER JOIN` gives the same classification in one pass and lists the actual mismatched keys. For value differences on matched keys, also compare the columns (or row hashes).

**Follow-ups:**
- How would duplicate keys distort these counts?
- How would you list the mismatched IDs rather than just count them?

**Difficulty:** Medium


**Role:** Azure Data Engineer (5+ years)

**Round:** Round 1 – Technical

**Asked:** 
