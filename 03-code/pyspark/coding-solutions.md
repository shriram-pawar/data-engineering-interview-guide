# PySpark Coding Practice — ANSWERS

*(Every solution below has been executed against real PySpark, local mode, and verified against the examples in `coding-problems.md`.)*

---

### PS1. Word count
```python
words = lines.select(F.explode(F.split(F.col("line"), " ")).alias("word"))
counts = words.groupBy("word").count().orderBy(F.desc("count"), "word")
counts.show()
```
`split` turns each line into an array of words; `explode` turns each array element into its own row; then a standard `groupBy().count()`.

---

### PS2. Running total per customer
```python
w = Window.partitionBy("customer_id").orderBy("order_date")
result = orders.withColumn("running_total", F.sum("amount").over(w))
result.orderBy("customer_id", "order_date").show()
```
By default, a window with `ORDER BY` and no explicit frame uses `RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` — exactly what a running total needs.

---

### PS3. Deduplicate, keeping latest per key
```python
w = Window.partitionBy("id").orderBy(F.desc("ts"))
deduped = (records
    .withColumn("rn", F.row_number().over(w))
    .filter(F.col("rn") == 1)
    .drop("rn"))
deduped.show()
```
Classic pattern: `ROW_NUMBER()` partitioned by the natural key, ordered so the "winner" is `rn == 1`, then filter.

---

### PS4. First and last event per user
```python
agg = events.groupBy("user_id").agg(
    F.min("event_ts").alias("first_event"),
    F.max("event_ts").alias("last_event"),
)
agg.show()
```
Works directly on string timestamps in `YYYY-MM-DD HH:MM:SS` format since lexicographic order matches chronological order for that format; for other formats, cast to `timestamp` first (`F.to_timestamp`).

---

### PS5. Data quality quarantine split
```python
good = raw.filter(F.col("email").isNotNull() & F.col("amount").isNotNull())
bad = raw.filter(F.col("email").isNull() | F.col("amount").isNull())

good.write.mode("append").parquet("gs://bucket/clean/orders")
bad.write.mode("append").parquet("gs://bucket/dead-letter/orders")
```
Two complementary filters (never just `.subtract()` the two — direct boolean conditions are cheaper and clearer). In a real pipeline, add a `reason` column to `bad` explaining *why* each row was quarantined.

---

### PS6. Flatten nested array with explode
```python
flat = orders_nested.select(
    "order_id",
    F.explode("items").alias("item")
).select("order_id", "item.sku", "item.qty")
flat.show()
```
`explode` duplicates the parent row's other columns (`order_id`) once per array element — this is the standard way to normalize a one-to-many nested structure into flat rows.

---

### PS7. Top-1 per group with a window function
```python
w = Window.partitionBy("category").orderBy(F.desc("sales"))
top1 = (sales
    .withColumn("rnk", F.rank().over(w))
    .filter(F.col("rnk") == 1)
    .drop("rnk"))
top1.show()
```
Use `rank()` (not `row_number()`) if you want **ties** included as co-winners; use `row_number()` if you strictly want exactly one row per group even on a tie.

---

### PS8. Sessionization by inactivity gap
```python
w = Window.partitionBy("user_id").orderBy("ts_seconds")

sessioned = (clicks
    .withColumn("prev_ts", F.lag("ts_seconds").over(w))
    .withColumn("gap", F.col("ts_seconds") - F.col("prev_ts"))
    .withColumn("new_session", F.when((F.col("gap") > 600) | F.col("gap").isNull(), 1).otherwise(0))
    .withColumn("session_id",
                F.sum("new_session").over(w.rowsBetween(Window.unboundedPreceding, Window.currentRow)))
    .drop("prev_ts", "gap"))
sessioned.orderBy("ts_seconds").show()
```
The classic sessionization pattern: `lag()` to see the previous event's timestamp, flag a "new session" whenever the gap exceeds the threshold (or it's the very first event), then a running `SUM` over that flag turns "is this a new session start" into an actual incrementing session ID.

---

### PS9. Pivot
```python
pivoted = dept_rev.groupBy("id").pivot("month", ["Jan", "Feb"]).sum("revenue")
pivoted.show()
```
Explicitly listing the pivot values (`["Jan", "Feb"]`) avoids an extra pass over the data to discover distinct values automatically — always do this in production if the possible values are known ahead of time, for performance.

---

### PS10. Broadcast join to avoid shuffling the large table
```python
joined = big.join(F.broadcast(small), "category_id")
joined.show(5)
```
Wrapping the small DataFrame in `F.broadcast(...)` tells Spark to ship a full copy of `small` to every executor and perform the join locally, with **no shuffle of `big`** — the standard fix whenever one side of a join is small enough to fit comfortably in executor memory (roughly under Spark's `autoBroadcastJoinThreshold`, or forced explicitly like here).
