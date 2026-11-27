# PySpark — Interview Question Bank

> Format: Question · Answer · Follow-ups · Difficulty

---

### Q1: RDD vs DataFrame vs Dataset — what's the difference?

**Answer:**
- **RDD**: low-level, distributed collection of objects, no schema, no built-in optimization — you write the execution plan yourself.
- **DataFrame**: distributed collection organized into named columns (like a table), schema-aware, optimized by Catalyst. This is what you use day-to-day in PySpark.
- **Dataset**: typed version of DataFrame (JVM-only, so not available in PySpark — Python DataFrames are effectively `Dataset[Row]`).
In practice: prefer DataFrames/Spark SQL; drop to RDDs only for fine-grained control Spark SQL can't express.

**Follow-ups:**
- Why is the Dataset API not available in PySpark?
- When would you still drop down to RDDs?

**Difficulty:** Easy

---

### Q2: What does "lazy evaluation" mean in Spark, and why does it matter?

**Answer:**
Transformations (`select`, `filter`, `join`, `withColumn`, ...) don't execute immediately — Spark just builds up a logical plan (a DAG). Nothing actually runs until an **action** (`show`, `count`, `collect`, `write`) triggers execution. This lets Catalyst optimize the *entire* chain of transformations together (predicate pushdown, column pruning, etc.) instead of executing each step naively.

**Follow-ups:**
- How does lazy evaluation let Catalyst optimize a query?
- What triggers execution of a DAG?

**Difficulty:** Easy

---

### Q3: Transformations vs actions — give examples of each.

**Answer:**
- **Transformations** (lazy, return a new DataFrame/RDD): `select`, `filter`/`where`, `groupBy`, `join`, `withColumn`, `orderBy`, `distinct`, `union`.
- **Actions** (trigger execution, return a value or write output): `show`, `count`, `collect`, `take`, `write.parquet(...)`, `foreach`.

**Follow-ups:**
- What's the difference between narrow and wide transformations?
- Is `count()` always expensive?

**Difficulty:** Easy

---

### Q4: What is a partition, and how do `repartition()` and `coalesce()` differ?

**Answer:**
A partition is a chunk of a DataFrame processed by a single task on a single executor core. Both change the number of partitions, but:
- **`repartition(n)`**: full shuffle, can increase or decrease partitions, produces roughly evenly-sized partitions. Use before a wide operation (join/aggregation) that benefits from even distribution.
- **`coalesce(n)`**: no full shuffle (merges adjacent partitions), can only *decrease* partitions, cheaper. Use just before writing output to reduce the number of small files.

```python
df.repartition(200, "customer_id")   # even shuffle by key, for a join
df.coalesce(10).write.parquet(path)  # cheaper reduction before writing
```

**Follow-ups:**
- Why can `coalesce(1)` make a job slow?
- How do you decide on the number of partitions?

**Difficulty:** Medium

---

### Q5: What's the difference between `cache()` and `persist()`?

**Answer:**
`cache()` is shorthand for `persist(StorageLevel.MEMORY_AND_DISK)`. `persist()` lets you choose the storage level explicitly — `MEMORY_ONLY`, `MEMORY_AND_DISK`, `DISK_ONLY`, with `_SER` (serialized, less memory, more CPU) and `_2` (replicated) variants. Use caching when a DataFrame is reused multiple times downstream (e.g., referenced in two branches of a pipeline) to avoid recomputing it from scratch each time.

**Follow-ups:**
- Which storage levels are there, and when would you use `MEMORY_AND_DISK`?
- When should you call `unpersist()`?

**Difficulty:** Easy

---

### Q6: What is a shuffle, and why is it expensive?

**Answer:**
A shuffle redistributes data across the cluster so that records with the same key end up on the same partition/executor — required by operations like `groupBy`, `join` (non-broadcast), `distinct`, `repartition`. It's expensive because it involves disk I/O, network transfer, and serialization across every executor. Minimizing unnecessary shuffles (via broadcast joins, partitioning early, avoiding repeated wide transformations) is one of the biggest levers for Spark job performance.

**Follow-ups:**
- Which operations trigger a shuffle?
- What does `spark.sql.shuffle.partitions` control?

**Difficulty:** Medium

---

### Q7: Explain broadcast joins and when to use them.

**Answer:**
When joining a large DataFrame with a much smaller one, Spark can send ("broadcast") a full copy of the small DataFrame to every executor, so the join happens locally with no shuffle of the large table.
```python
from pyspark.sql.functions import broadcast

result = big_df.join(broadcast(small_df), "customer_id")
```
Spark auto-broadcasts tables under `spark.sql.autoBroadcastJoinThreshold` (default 10 MB), but you can force it explicitly. Good rule of thumb: use it when one side comfortably fits in executor memory (typically well under a few hundred MB–1GB).

**Follow-ups:**
- What's the default broadcast size threshold, and how do you change it?
- What happens if you broadcast a table that's too big?

**Difficulty:** Medium

---

### Q8: What causes data skew, and how do you fix it?

**Answer:**
Skew happens when one or a few keys have disproportionately more rows than others (e.g., a "NULL" or default customer_id holding half the data), so a handful of tasks take far longer than the rest and become the bottleneck.
Fixes:
- **Salting**: append a random suffix to the skewed key, join, then aggregate back.
- **Broadcast join** if the small side is genuinely small.
- **Adaptive Query Execution (AQE)** — Spark 3+ can auto-detect and split skewed partitions (`spark.sql.adaptive.skewJoin.enabled`).
- Isolate and handle the hot key(s) separately from the rest of the data.

**Follow-ups:**
- How does salting work, step by step?
- How does AQE's skew-join handling differ from manual salting?

**Difficulty:** Hard

---

### Q9: What is Adaptive Query Execution (AQE)?

**Answer:**
A Spark 3.x feature that re-optimizes the query plan at runtime using actual statistics collected between stages, rather than relying purely on static estimates. It can dynamically coalesce shuffle partitions, switch a sort-merge join to a broadcast join if a table turns out small, and split skewed partitions automatically. Enabled by default in Spark 3.2+.

**Follow-ups:**
- Which three main optimizations does AQE perform?
- Why does AQE need runtime statistics?

**Difficulty:** Medium

---

### Q10: Explain the Spark architecture: driver, executors, cluster manager.

**Answer:**
- **Driver**: runs the `main()` program, builds the DAG, schedules tasks, and collects results. One per application.
- **Executors**: JVM processes on worker nodes that actually run tasks and hold cached data; each has its own CPU cores and memory.
- **Cluster manager** (YARN, Kubernetes, Standalone, or Dataproc's manager): allocates resources (executors) to the application across the cluster.
Client vs cluster deploy mode determines *where* the driver runs — on the machine that submitted the job (client) or inside the cluster (cluster mode, typical for production).

**Follow-ups:**
- What happens when an executor dies mid-job?
- What are jobs, stages and tasks?

**Difficulty:** Easy

---

### Q11: What's the difference between `SparkContext` and `SparkSession`?

**Answer:**
`SparkContext` is the original entry point (RDD API, cluster connection). `SparkSession` (Spark 2.0+) unifies `SparkContext`, `SQLContext`, and `HiveContext` into a single entry point for the DataFrame/SQL API — it's what you use today (`spark.read`, `spark.sql`, etc.), and it wraps a `SparkContext` internally (`spark.sparkContext`).

**Follow-ups:**
- Why was `SparkSession` introduced in Spark 2.0?
- How do you get the `SparkContext` from a session?

**Difficulty:** Easy

---

### Q12: When would you write a UDF, and why should you avoid them if possible?

**Answer:**
A UDF (`pyspark.sql.functions.udf`) lets you run arbitrary Python logic per row when there's no built-in Spark SQL function for it. Downsides: Python UDFs serialize data between the JVM and a Python process row-by-row, breaking Catalyst's ability to optimize and killing performance versus native/Spark SQL functions. Prefer, in order: built-in `pyspark.sql.functions`, then **Pandas UDFs** (vectorized, Arrow-based — much faster than row-at-a-time UDFs), then plain UDFs as a last resort.
```python
from pyspark.sql.functions import pandas_udf
import pandas as pd

@pandas_udf("double")
def add_tax(price: pd.Series) -> pd.Series:
    return price * 1.08
```

**Follow-ups:**
- Why are Python UDFs slow?
- How do pandas UDFs (vectorized UDFs) improve on them?

**Difficulty:** Medium

---

### Q13: How do window functions work in PySpark? Give an example computing a running total.

**Answer:**
```python
from pyspark.sql import Window
from pyspark.sql.functions import sum as _sum, row_number, col

w = Window.partitionBy("customer_id").orderBy("order_date")

df = df.withColumn("running_total", _sum("amount").over(w))
df = df.withColumn("rn", row_number().over(w))
```
`Window.partitionBy(...)` groups rows (like `GROUP BY` but keeps all rows), `.orderBy(...)` defines row order within each partition, and you can bound the frame (`.rowsBetween(Window.unboundedPreceding, Window.currentRow)`) for running/moving calculations.

**Follow-ups:**
- What's the difference between `rowsBetween` and `rangeBetween`?
- What happens when a window has no `partitionBy`?

**Difficulty:** Medium

---

### Q14: What file formats does Spark work with, and why is Parquet usually preferred for pipelines?

**Answer:**
Spark reads/writes CSV, JSON, Parquet, ORC, Avro, Delta/Iceberg/Hudi, plain text, and JDBC sources. **Parquet** is generally preferred because it's:
- Columnar (fast for analytical queries that touch a subset of columns),
- Compressed (smaller storage/network footprint),
- Schema-embedded (no need to infer/redeclare types),
- Supports predicate/column pushdown for faster reads.

**Follow-ups:**
- What is predicate pushdown?
- How does column pruning work with Parquet?

**Difficulty:** Easy

---

### Q15: How would you avoid the "small files problem" when writing output?

**Answer:**
Writing too many small partitions (common after heavy filtering or over-partitioning) creates thousands of tiny files, which slows down downstream reads (metadata overhead) and storage listing. Mitigations:
- `coalesce(n)` before writing to control output file count.
- Set a target partition count based on data volume (rule of thumb: aim for ~128MB–1GB per output file).
- Use `maxRecordsPerFile` write option.
- Periodically compact small files in the target table/location.

**Follow-ups:**
- How does `maxRecordsPerFile` help?
- How do Delta's OPTIMIZE and auto-compaction address this?

**Difficulty:** Medium

---

### Q16: Explain `explode()` and give a use case.

**Answer:**
`explode()` turns each element of an array (or map) column into its own row, duplicating the other columns. Common when flattening nested/JSON data.
```python
from pyspark.sql.functions import explode

# orders_df has an `items` column that's an array of structs
flat = orders_df.select("order_id", explode("items").alias("item"))
flat = flat.select("order_id", "item.sku", "item.qty")
```

**Follow-ups:**
- What's the difference between `explode` and `explode_outer`?
- How do you explode a map column?

**Difficulty:** Easy

---

### Q17: What's the difference between `groupBy().agg()` and a window function for "top N per group" style problems?

**Answer:**
`groupBy().agg()` collapses each group into a single summary row — you lose the individual rows. A window function keeps every row but attaches a per-group computed value (like a rank), so you can then filter for "top N per group" without losing row-level detail.
```python
from pyspark.sql import Window
from pyspark.sql.functions import rank, col

w = Window.partitionBy("category").orderBy(col("sales").desc())
top3 = (df.withColumn("rnk", rank().over(w))
          .filter(col("rnk") <= 3))
```

**Follow-ups:**
- Why can `groupBy` alone not return the full row for the top N?
- How would you handle ties?

**Difficulty:** Medium

---

### Q18: How does Spark handle fault tolerance?

**Answer:**
Through **RDD lineage** — Spark tracks the sequence of transformations that produced each partition. If an executor/partition is lost, Spark recomputes just that partition by replaying the lineage from the last available data (or checkpoint), rather than restarting the whole job. Checkpointing (`df.checkpoint()`) can truncate very long lineages by persisting an intermediate result to reliable storage.

**Follow-ups:**
- What is lineage, and how does it enable recomputation?
- When would you use checkpointing?

**Difficulty:** Medium

---

### Q19: What's the difference between `spark-submit` client mode and cluster mode?

**Answer:**
- **Client mode**: the driver runs on the machine you launched the job from (e.g., your local box, an edge node) — good for interactive/debugging use, but if that machine disconnects, the job dies.
- **Cluster mode**: the driver runs inside the cluster, managed like any other application — the standard choice for production/scheduled jobs since it isn't tied to the submitting machine staying alive.

**Follow-ups:**
- Which mode does Dataproc or Databricks use for scheduled jobs?
- Where do driver logs end up in each mode?

**Difficulty:** Easy

---

### Q20: What is Spark Structured Streaming, and how does it differ from Spark's classic batch DataFrame API?

**Answer:**
Structured Streaming lets you write the *same* DataFrame API against an unbounded, continuously-arriving data source (Kafka, files, Pub/Sub via connectors), treating the stream as an ever-growing table. Spark incrementally processes new data in **micro-batches** (or continuous mode) and supports **watermarking** to bound how long it waits for late-arriving data, plus stateful aggregations across triggers.
```python
stream_df = (spark.readStream.format("kafka")
             .option("subscribe", "orders").load())

query = (stream_df.groupBy("customer_id").count()
         .writeStream.outputMode("update")
         .format("console").start())
```

**Follow-ups:**
- What are output modes (append, complete, update)?
- How do watermarks bound state in a streaming aggregation?

**Difficulty:** Hard

---

### Q21: How would you tune a slow Spark job — what's your general checklist?

**Answer:**
1. Check the Spark UI for skewed/straggler tasks and excessive spill to disk.
2. Reduce shuffles: broadcast small joins, filter/select early ("push down" work before wide operations).
3. Right-size partitions (`spark.sql.shuffle.partitions`, `repartition`/`coalesce`) — too few = underutilized cluster, too many = scheduling overhead.
4. Cache DataFrames that are reused multiple times, and unpersist when done.
5. Avoid Python UDFs where a built-in/Pandas UDF exists.
6. Check executor memory config and GC pressure; watch for OOM/spill in the UI.
7. Enable AQE and dynamic allocation if not already on.

**Follow-ups:**
- How do you read the Spark UI to find the bottleneck?
- How would you size executors (cores and memory)?

**Difficulty:** Hard

---

### Q22: Coding: given a DataFrame of orders, find the second-highest order amount per customer.

**Answer:**
```python
from pyspark.sql import Window
from pyspark.sql.functions import dense_rank, col

w = Window.partitionBy("customer_id").orderBy(col("amount").desc())

result = (orders_df
    .withColumn("rnk", dense_rank().over(w))
    .filter(col("rnk") == 2)
    .select("customer_id", "amount"))
```

**Follow-ups:**
- How would you return customers who have only one order?
- Should you use `dense_rank` or `row_number` here?

**Difficulty:** Medium

---

### Q23: What are accumulators, and what are they typically used for?

**Answer:**
Accumulators are write-only (from executors' perspective) shared variables the driver can read, used for aggregating simple metrics across tasks — e.g., counting malformed records encountered during a `foreach`/UDF pass. They're for monitoring/side-effects, **not** for computing values that feed back into the main transformation logic (updates inside transformations aren't guaranteed to apply exactly once if tasks are retried).
```python
bad_records = spark.sparkContext.accumulator(0)

def validate(row):
    if row.amount is None:
        bad_records.add(1)
    return row

df.foreach(validate)
print(bad_records.value)
```

**Follow-ups:**
- Why can accumulator values be wrong when updated inside transformations?
- What would you use instead for data quality counters?

**Difficulty:** Medium

---

### Q24: Explain the difference between `.select()` and `.withColumn()`.

**Answer:**
`.select()` returns exactly the columns you list (a projection — drops everything else). `.withColumn(name, expr)` returns *all* existing columns plus one new/replaced column — convenient for incrementally building up transformations without re-listing every column each time. Chaining many `.withColumn()` calls is fine but can be slower than a single `.select()` with all expressions listed, since Spark builds a new plan node each time (usually negligible unless done hundreds of times).

**Follow-ups:**
- Why is calling `withColumn` in a loop a performance problem?
- How would you add 50 columns efficiently?

**Difficulty:** Easy
