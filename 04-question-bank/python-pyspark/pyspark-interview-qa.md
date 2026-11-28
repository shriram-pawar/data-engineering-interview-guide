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

**Moved:** this question was asked in real interviews, so its answer now lives in [`real-world-asked/python-pyspark.md`](../real-world-asked/python-pyspark.md).

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

**Moved:** this question was asked in real interviews, so its answer now lives in [`real-world-asked/python-pyspark.md`](../real-world-asked/python-pyspark.md).

---

### Q5: What's the difference between `cache()` and `persist()`?

**Moved:** this question was asked in real interviews, so its answer now lives in [`real-world-asked/python-pyspark.md`](../real-world-asked/python-pyspark.md).

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

**Moved:** this question was asked in real interviews, so its answer now lives in [`real-world-asked/python-pyspark.md`](../real-world-asked/python-pyspark.md).

---

### Q8: What causes data skew, and how do you fix it?

**Moved:** this question was asked in real interviews, so its answer now lives in [`real-world-asked/python-pyspark.md`](../real-world-asked/python-pyspark.md).

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

**Moved:** this question was asked in real interviews, so its answer now lives in [`real-world-asked/python-pyspark.md`](../real-world-asked/python-pyspark.md).

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

**Moved:** this question was asked in real interviews, so its answer now lives in [`real-world-asked/python-pyspark.md`](../real-world-asked/python-pyspark.md).

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

---

### Q25: What's the difference between narrow and wide transformations?

**Moved:** this question was asked in real interviews, so its answer now lives in [`real-world-asked/python-pyspark.md`](../real-world-asked/python-pyspark.md).

---

### Q26: Explain jobs, stages and tasks in Spark.

**Answer:**
- **Job:** created by each **action** (`count`, `write`, `collect`).
- **Stage:** a job is split into stages at **shuffle boundaries** (wide transformations). Each stage runs a pipelined set of narrow transformations.
- **Task:** one unit of work per **partition** per stage, executed by an executor core.

Example: `spark.read.parquet(...).filter(...).groupBy("country").count().write...` gives one job with two stages: read and filter, then a shuffle, then aggregate and write. The number of tasks in the first stage equals the number of input partitions; in the second it equals the shuffle partitions.

**Follow-ups:**
- Where do you see stages and tasks in the Spark UI, and what does a long-tail task mean?
- How does AQE change the number of tasks after a shuffle?

**Difficulty:** Easy

---

### Q27: What is bucketing, and how does it differ from partitioning?

**Answer:**
| | `partitionBy` (on write) | `bucketBy` |
|---|---|---|
| Layout | One **directory** per column value (`country=IN/`) | A fixed number of **files** per partition, rows assigned by `hash(col) % n` |
| Best for | Low-cardinality filter columns (date, country) | High-cardinality join or aggregation keys (`customer_id`) |
| Benefit | **Partition pruning**: skip directories when filtering | **No shuffle** when joining or aggregating tables bucketed the same way on the same key |
| Requirement | Any file write | Only with `saveAsTable` (metastore tables) |

```python
(orders.write.partitionBy("order_date")
       .bucketBy(32, "customer_id").sortBy("customer_id")
       .saveAsTable("sales.orders"))
```

Partitioning on a high-cardinality column creates millions of tiny files; bucketing exists to handle those keys.

**Follow-ups:**
- What must match for two bucketed tables to join without a shuffle?
- How do Delta Lake's liquid clustering and Z-ordering relate to this?

**Difficulty:** Medium

---

### Q28: What's the difference between `groupByKey` and `reduceByKey`?

**Answer:**
Both group an RDD of `(key, value)` pairs, but:
- **`reduceByKey(func)`** combines values **on each partition first** (map-side combine), then shuffles only the partial results. Less data moves, so it's faster and safer for memory.
- **`groupByKey()`** shuffles **every value** across the network and builds the full list per key on one executor, which risks OOM for large keys.

```python
pairs = sc.parallelize([("a", 1), ("b", 1), ("a", 1)])
pairs.reduceByKey(lambda x, y: x + y).collect()           # [('a', 2), ('b', 1)]
pairs.groupByKey().mapValues(sum).collect()               # same result, more shuffle
```

With DataFrames, `df.groupBy("key").agg(sum("v"))` already does partial aggregation, so this is mainly an RDD-API question.

**Follow-ups:**
- When is `groupByKey` acceptable?
- What do `aggregateByKey` and `combineByKey` add?

**Difficulty:** Medium

---

### Q29: What are predicate pushdown and column pruning?

**Answer:**
- **Predicate pushdown:** Spark pushes filters down to the data source, so less data is read. With Parquet or ORC, row groups whose min/max statistics can't match are skipped; with JDBC or BigQuery, the filter runs in the source system.
- **Column pruning:** only the selected columns are read. Columnar formats make this very effective.

```python
df = spark.read.parquet("gs://bucket/orders/").filter("order_date = '2024-01-01'").select("order_id", "amount")
df.explain()   # look for PushedFilters: [EqualTo(order_date, ...)] and a narrow ReadSchema
```

Pushdown can be blocked by UDFs in the filter, by casting the column (`CAST(col AS STRING) = ...`), or by formats such as CSV that have no statistics.

**Follow-ups:**
- How do partition pruning and predicate pushdown differ?
- Why might a filter on a timestamp column not be pushed down?

**Difficulty:** Medium

---

### Q30: What is Project Tungsten in Spark?

**Answer:**
Tungsten is a set of Spark **execution-engine optimizations** focused on CPU and memory efficiency:
- **Off-heap, binary memory management** (`UnsafeRow`): data stored in compact binary form instead of Java objects, so less garbage collection and smaller memory use.
- **Cache-aware computation:** algorithms and data structures (e.g. sort, hash aggregation) designed for CPU caches.
- **Whole-stage code generation:** chains of operators are compiled into a single optimized JVM function, avoiding virtual function calls per row.

Catalyst decides **what** plan to run; Tungsten makes executing it fast. You get it automatically with DataFrames and SQL (not with RDDs of Python objects), which is one reason DataFrames outperform RDDs.

**Follow-ups:**
- Why don't RDD-based jobs benefit from Tungsten?
- How can you see whole-stage codegen in a query plan?

**Difficulty:** Medium

---

### Q31: What's the difference between caching and checkpointing in Spark?

**Answer:**
| | `cache()` / `persist()` | `checkpoint()` |
|---|---|---|
| Stores data in | Executor memory and/or local disk | **Reliable storage** (HDFS, DBFS, cloud storage via `setCheckpointDir`) |
| Lineage | **Kept**: lost partitions are recomputed | **Truncated**: the plan restarts from the saved data |
| Survives | Only while the application and executors live | Beyond executor loss (and, for streaming, application restarts) |
| Cost | Fast, cheap | Writes the full data out (slower); compute twice unless cached first |
| Use for | Reusing a DataFrame several times in one job | Very long lineage (iterative algorithms, many joins) causing slow planning or stack overflows; streaming state and offsets |

`localCheckpoint()` truncates lineage using executor storage (faster, not fault-tolerant). In Structured Streaming, the **checkpoint location** stores offsets and state, which is different but related.

**Follow-ups:**
- Why might a very long lineage slow down a job?
- Why cache a DataFrame before checkpointing it?

**Difficulty:** Medium

---

### Q32: What is a broadcast variable in Spark?

**Answer:**
A broadcast variable sends a **read-only value to every executor once**, instead of shipping it with every task:

```python
country_names = {"IN": "India", "US": "United States"}
bc = spark.sparkContext.broadcast(country_names)

rdd.map(lambda r: (r.id, bc.value.get(r.country_code, "Unknown")))
```

Use it for small lookup data (maps, sets, small models) used inside RDD operations or UDFs. With DataFrames, the equivalent is usually a **broadcast join** (`F.broadcast(small_df)`), which Spark can plan and optimize. Keep broadcast data small (it has to fit in the driver and every executor), and call `unpersist()` / `destroy()` when done.

**Follow-ups:**
- How is a broadcast variable different from a broadcast join?
- What happens if the broadcast value is too large?

**Difficulty:** Easy

---

### Q33: How do Spark driver memory and executor memory differ, and what is each used for?

**Answer:**
- **Driver memory** (`spark.driver.memory`): used by the driver process for the SparkSession, query planning, task scheduling, broadcast variables built on the driver, and **results returned to it** (`collect`, `toPandas`). Too little causes driver OOMs on large collects or huge plans.
- **Executor memory** (`spark.executor.memory`): used by each executor for **execution** (shuffles, joins, sorts, aggregations) and **storage** (cached data), managed by the unified memory model (`spark.memory.fraction`), plus **overhead memory** (`spark.executor.memoryOverhead`) for off-heap and native use (Python workers, Photon, network buffers).

Sizing: executors need enough memory per core for the largest partitions (otherwise spills or OOM); the driver usually needs less, unless you collect or broadcast large data.

**Follow-ups:**
- What is memory overhead, and why do PySpark jobs often need more of it?
- How does `spark.memory.fraction` split execution and storage memory?

**Difficulty:** Medium

---

### Q34: What happens if the driver node fails in a Spark application?

**Answer:**
The driver holds the application's state (DAG, scheduling, task tracking, results), so **if it fails, the whole application fails**: executors are released and running work is lost. Unlike executors, a driver failure isn't recovered automatically within the same run.

How to cope:
- **Batch jobs:** let the orchestrator retry the whole job (Databricks job retries, Airflow retries), so jobs must be **idempotent** (partition overwrite, `MERGE`).
- **Streaming:** restart from the **checkpoint**: offsets and state are restored and processing continues exactly-once into Delta sinks. Cluster-mode supervision (`--supervise` on standalone, YARN application attempts, Databricks job retries) can restart the driver automatically.
- **Prevent:** avoid driver OOMs (no big `collect`), and size the driver node for large plans.

**Follow-ups:**
- Why does a streaming job need a checkpoint location to survive driver restarts?
- How is executor failure handled differently?

**Difficulty:** Medium
