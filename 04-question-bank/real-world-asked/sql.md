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
