# Real-World Asked: Python & PySpark

Python and PySpark questions reported from real data engineering interviews.

See [README.md](README.md) for the layout and contributor rules. Fields are left blank when unknown.

## Unspecified company

### Q1: Explode an array column into rows

A DataFrame has a `name` column and an `array_of_str` column, e.g. `John → [mango, banana, apple]`. Produce one row per name and fruit.

**Answer:**
Use `explode` (or `explode_outer` to keep rows whose array is empty or NULL):

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import explode

spark = SparkSession.builder.appName("explode-demo").getOrCreate()
df = spark.createDataFrame(
    [("John", ["mango", "banana", "apple"]), ("Tom", ["mango", "orange"]), ("Min", ["apple"])],
    ["name", "array_of_str"],
)

df.select("name", explode("array_of_str").alias("fruit")).show()
```

The same thing in BigQuery SQL, where arrays are flattened with `UNNEST`:

```sql
SELECT name, fruit
FROM `mydataset.people`, UNNEST(array_of_str) AS fruit;
```

To keep the element position as well, use `posexplode` in PySpark or `UNNEST(...) WITH OFFSET` in BigQuery.

**Follow-ups:**
- What's the difference between `explode` and `explode_outer`?
- How would you go the other way and collect rows back into an array (`collect_list` / `ARRAY_AGG`)?

**Difficulty:** Easy

**Role:** 

**Round:** 

**Asked:**

## Deloitte

### Q2: How do you parse pipe-delimited strings into a DataFrame with PySpark?

**Answer:**
Read the file as text, split each line on the pipe, and select columns by position, or let the CSV reader do it with a custom separator:

```python
from pyspark.sql import functions as F

# Option 1: the CSV reader with sep="|" (simplest, handles quoting)
df = (spark.read.option("header", True).option("sep", "|")
           .schema("order_id STRING, region STRING, amount DECIMAL(10,2)")
           .csv("abfss://raw@mylake.dfs.core.windows.net/orders/"))

# Option 2: a column already holding pipe-delimited strings
parsed = (raw.withColumn("parts", F.split(F.col("value"), r"\|"))      # escape: split() takes a regex
             .select(F.col("parts")[0].alias("order_id"),
                     F.col("parts")[1].alias("region"),
                     F.col("parts")[2].cast("decimal(10,2)").alias("amount")))
```

The key detail is that `split()` takes a **regular expression**, so `|` must be escaped. Supplying an explicit schema avoids an extra pass for type inference.

**Follow-ups:**
- What happens if you call `split(col, '|')` without escaping?
- How would you handle rows with the wrong number of fields?

**Difficulty:** Easy


**Role:** Azure Data Engineer

**Round:** Round 1 – Technical

**Asked:** 

---

### Q3: How do you troubleshoot an out-of-memory error on the Spark driver?

**Answer:**
The driver runs out of memory when **too much data is brought to it** or its own planning work is huge:
1. **Find the cause** in the driver log and Spark UI: `collect()`, `toPandas()`, large `broadcast` variables, `show()` on huge rows, or a query plan with thousands of files and partitions.
2. **Common fixes:**
   - Don't `collect()` large DataFrames; write results to storage, or use `take(n)` or `limit`.
   - Lower or disable automatic broadcast when a "small" side is actually large (`spark.sql.autoBroadcastJoinThreshold`).
   - Reduce the number of small files and partitions; the driver tracks metadata for each.
   - Avoid huge local Python objects and accumulators.
3. **Only then add memory:** `spark.driver.memory` and `spark.driver.maxResultSize`, or a larger driver node type in Databricks.

**Follow-ups:**
- Why can a broadcast join cause a driver OOM?
- What does `spark.driver.maxResultSize` protect against?

**Difficulty:** Medium


**Role:** Azure Data Engineer

**Round:** Round 1 – Technical

**Asked:** 

---

### Q4: Explain Spark's architecture and what happens when you run spark-submit.

**Also asked at:** JPMorgan, Wipro

**Answer:**
**Components:**
- **Driver:** runs your `main` program, creates the `SparkSession`, builds the logical plan, optimizes it (Catalyst), splits it into **jobs → stages → tasks**, and schedules tasks.
- **Cluster manager** (YARN, Kubernetes, standalone, or Databricks' own): allocates resources.
- **Executors** (on worker nodes): JVM processes that run tasks on partitions, cache data, and report back.

**`spark-submit` flow:**
1. `spark-submit --master yarn --deploy-mode cluster app.py` sends the application to the cluster manager.
2. The cluster manager starts the **driver** (on a cluster node in *cluster* mode, or locally in *client* mode).
3. The driver requests **executors**; the cluster manager launches them on workers.
4. When an **action** runs, the driver builds the DAG, splits it into stages at shuffle boundaries, and sends tasks (one per partition) to executors.
5. Executors run the tasks, exchange shuffle data, and return results or write output.
6. At the end the driver stops and executors are released.

**Follow-ups:**
- What's the difference between client and cluster deploy mode?
- What happens to the application if an executor dies? And if the driver dies?

**Difficulty:** Medium


**Role:** Azure Data Engineer

**Round:** Round 2 – Technical + Managerial

**Asked:** 

---

### Q5: Can Spark's inferSchema be relied on to map source data to the right column types?

**Answer:**
Partly. `inferSchema=true` makes Spark sample the data and guess types (int, double, timestamp), which saves typing a schema, but:
- It needs an **extra pass** over the data (slow on large files).
- Guesses can be **wrong or unstable**: IDs with leading zeros become integers, sparse columns become strings, and types can change from one day's file to the next.
- It doesn't map source columns to target columns; it only guesses types.

For production pipelines, define an **explicit schema** (or a schema from a contract or registry) and handle mismatches on purpose. Use `inferSchema` or `schema_of_json` for exploration, then freeze the result. In ADF, the equivalent is explicit column mapping rather than relying on automatic mapping.

**Follow-ups:**
- How would a changing inferred type break a downstream table?
- How do you capture records that don't fit the expected schema (`badRecordsPath`, `_rescued_data`)?

**Difficulty:** Easy


**Role:** Data Engineer

**Round:** L1

**Asked:** 

---

### Q6: How do you handle data skew in PySpark, for example with salting?

**Also asked at:** JPMorgan

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


**Role:** Data Engineer (3+ years)

**Round:** 

**Asked:** 

---

### Q7: What's the difference between transform() and a udf() in PySpark, and which is more efficient?

**Answer:**
- **`udf()`** wraps a Python function that runs **row by row** outside the JVM. Data is serialized between the JVM and Python workers, and Catalyst can't optimize inside it. It's slow.
- **`DataFrame.transform(func)`** isn't a UDF at all: it's a way to **chain your own functions** that take and return a DataFrame (`df.transform(clean).transform(enrich)`). Inside, you use built-in column expressions, so everything stays in the JVM and is optimized.
- There's also the higher-order SQL function **`transform(array_col, x -> ...)`**, which applies an expression to each array element, natively.

So `transform` is more efficient, because it composes native expressions. When custom Python logic is unavoidable, prefer a **pandas (vectorized) UDF** over a plain `udf`.

**Follow-ups:**
- Why are Python UDFs slower than built-in functions?
- When would you use a pandas UDF?

**Difficulty:** Medium


**Role:** Data Engineer (3+ years)

**Round:** 

**Asked:** 

---

### Q8: Write a Python function that removes duplicates from a list while keeping the original order.

**Answer:**
```python
def dedupe(items):
    seen = set()
    result = []
    for item in items:
        if item not in seen:
            seen.add(item)
            result.append(item)
    return result
```
(For Python 3.7+, `list(dict.fromkeys(items))` also works and preserves order.)

**Follow-ups:**
- Why does `dict.fromkeys` preserve order?
- How would you dedupe by one field of a dict rather than the whole record?

**Difficulty:** Easy


**Role:** Data Engineer (3+ years)

**Round:** 

**Asked:** 

## HCLTech

### Q9: Which Spark optimization techniques have you used, and what other techniques do you know?

**Also asked at:** JPMorgan, Persistent Systems, Wipro

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


**Role:** Lead Data Engineer

**Round:** Round 1 – Technical

**Asked:** 

---

### Q10: How do you use the Spark UI (spills and shuffle sizes) to debug a slow job?

**Answer:**
Open the slow stage in the **Spark UI → Stages** tab and read:
- **Task duration distribution** (min / median / max): a max far above the median means **skew**; look at the input size per task.
- **Shuffle Read / Shuffle Write** sizes: huge shuffles point at wide joins or aggregations. Reduce them by filtering early, broadcasting small tables, or pre-aggregating.
- **Spill (Memory / Disk):** spill means partitions don't fit in execution memory. Increase the number of partitions (`spark.sql.shuffle.partitions`, or let AQE coalesce and split), fix skew, or give executors more memory.
- **GC time:** high GC means memory pressure.
- **SQL tab:** the physical plan shows join strategies (SortMergeJoin vs BroadcastHashJoin) and where rows explode.

Then change one thing at a time and compare the stage metrics again.

**Follow-ups:**
- What's the difference between memory spill and disk spill?
- How does AQE's skew join handling show up in the plan?

**Difficulty:** Hard


**Role:** Lead Data Engineer

**Round:** Round 1 – Technical

**Asked:** 

---

### Q11: Walk through what Spark does internally when you call df.groupBy("city").count().show().

**Answer:**
`df.groupBy("city").count().show()`:
1. **Lazy plan:** `groupBy().count()` builds a logical plan; `show()` is the **action** that triggers a job.
2. **Catalyst** optimizes the plan (column pruning: only `city` is read; filters are pushed down).
3. **Physical plan:** a `HashAggregate` (partial) → `Exchange hashpartitioning(city)` (**shuffle**) → `HashAggregate` (final).
4. **Stage 1:** each task reads its input partition and computes **partial counts per city** (map-side combine), then writes shuffle files.
5. **Stage 2:** tasks read the shuffle data for their cities, sum the partial counts, and produce final counts (`spark.sql.shuffle.partitions` tasks, adjusted by AQE).
6. `show()` only needs 20 rows, so Spark may run a limited job and send those rows to the driver to print.

You can see all of this with `df.groupBy("city").count().explain()`.

**Follow-ups:**
- Why is the partial aggregation before the shuffle important?
- How would skew in `city` affect stage 2?

**Difficulty:** Medium


**Role:** Lead Data Engineer

**Round:** Round 1 – Technical

**Asked:** 

## JPMorgan

### Q12: What's the difference between repartition() and coalesce() in Spark?

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


**Role:** Senior / Lead Data Engineer

**Round:** Technical Round 1

**Asked:** 

---

### Q13: Why is Spark lazily evaluated, and what are the benefits in practice?

**Also asked at:** Wipro

**Answer:**
Transformations (`select`, `filter`, `join`, `withColumn`, ...) don't execute immediately — Spark just builds up a logical plan (a DAG). Nothing actually runs until an **action** (`show`, `count`, `collect`, `write`) triggers execution. This lets Catalyst optimize the *entire* chain of transformations together (predicate pushdown, column pruning, etc.) instead of executing each step naively.

**Follow-ups:**
- How does lazy evaluation let Catalyst optimize a query?
- What triggers execution of a DAG?

**Difficulty:** Easy


**Role:** Senior / Lead Data Engineer

**Round:** Technical Round 1

**Asked:** 

## Persistent Systems

### Q14: How do you parse and flatten a nested JSON file in PySpark?

**Answer:**
Read with the JSON reader (`multiLine` for pretty-printed files), then **flatten structs** with dot notation and **explode arrays**:

```python
from pyspark.sql import functions as F

orders = spark.read.option("multiLine", True).json("abfss://raw@mylake.dfs.core.windows.net/orders/")
# {"order_id": 1, "customer": {"id": 7, "address": {"city": "Pune"}}, "items": [{"sku": "A", "qty": 2}]}

flat = (orders
        .withColumn("item", F.explode_outer("items"))                    # one row per array element
        .select("order_id",
                F.col("customer.id").alias("customer_id"),
                F.col("customer.address.city").alias("city"),
                F.col("item.sku").alias("sku"),
                F.col("item.qty").alias("qty")))
```

For deep or changing structures, write a small recursive helper that walks `df.schema` and flattens every `StructType` (and explodes `ArrayType`) automatically. Supply an explicit schema in production, so new or malformed fields don't silently change types.

**Follow-ups:**
- What's the difference between `explode` and `explode_outer` here?
- How would you flatten a schema whose nesting depth isn't known in advance?

**Difficulty:** Medium


**Role:** Data Engineer

**Round:** Round 1 – Technical

**Asked:** 

---

### Q15: Narrow vs wide transformations in Spark: what's the difference? Give examples of each.

**Answer:**
- **Narrow:** each output partition depends on **one** input partition, so there's no data movement. Examples: `select`, `filter`, `withColumn`, `map`, `union`. Spark pipelines consecutive narrow transformations into one stage.
- **Wide:** an output partition needs data from **many** input partitions, so Spark must **shuffle** data across the network. Examples: `groupBy`, `join` (non-broadcast), `distinct`, `orderBy`, `repartition`.

Wide transformations create **stage boundaries** and are usually the most expensive part of a job, so tuning focuses on reducing or optimizing them.

**Follow-ups:**
- Why is a broadcast join narrow on the large side?
- Is `coalesce` narrow or wide?

**Difficulty:** Easy


**Role:** Data Engineer

**Round:** Round 2 – Technical

**Asked:** 

## TEKsystems

### Q16: Write a Python snippet to read a CSV file and load it into BigQuery.

**Answer:**
Use the BigQuery client's **load job** (not row-by-row inserts). It reads the file directly, is free, and handles large files:

```python
from google.cloud import bigquery

client = bigquery.Client()                      # uses Application Default Credentials
table_id = "my-project.staging.orders"

job_config = bigquery.LoadJobConfig(
    source_format=bigquery.SourceFormat.CSV,
    skip_leading_rows=1,
    autodetect=False,
    schema=[
        bigquery.SchemaField("order_id", "STRING", mode="REQUIRED"),
        bigquery.SchemaField("order_date", "DATE"),
        bigquery.SchemaField("amount", "NUMERIC"),
    ],
    write_disposition=bigquery.WriteDisposition.WRITE_APPEND,
    max_bad_records=0,
)

with open("orders.csv", "rb") as f:             # for files in GCS use client.load_table_from_uri("gs://...", ...)
    job = client.load_table_from_file(f, table_id, job_config=job_config)
job.result()                                    # wait; raises on error
print(f"Loaded {job.output_rows} rows into {table_id}")
```

Explicit schemas avoid wrong type guesses; for files already in Cloud Storage, `load_table_from_uri` avoids downloading them.

**Follow-ups:**
- Why prefer a load job over `insert_rows_json` for files?
- How would you load into a specific date partition and make reruns idempotent?

**Difficulty:** Easy


**Role:** GCP Data Engineer

**Round:** Technical evaluation

**Asked:** 

---

### Q17: Why is loading a large CSV directly through Pandas not recommended?

**Answer:**
- **Memory:** pandas loads the whole file into RAM, often 5–10× the file size once parsed, so a multi-GB CSV can crash the worker (e.g. a Composer worker).
- **Speed:** it's single-threaded and adds an unnecessary parse step: CSV → DataFrame → serialization → BigQuery.
- **Types:** pandas infers types (leading zeros lost, mixed columns become `object`, NaN turns integers into floats), which can corrupt data.
- **Cost and reliability:** BigQuery **load jobs from Cloud Storage** are free, parallel and retry-safe.

Better: upload the file to Cloud Storage and run a load job (or `bq load`). If transformation is needed, use BigQuery SQL after loading (ELT), Dataflow or Spark. If pandas is unavoidable, read in chunks (`chunksize=`) with explicit `dtype`s.

**Follow-ups:**
- How much memory would a 5 GB CSV need in pandas?
- When is pandas still a reasonable choice?

**Difficulty:** Easy


**Role:** GCP Data Engineer

**Round:** Technical evaluation

**Asked:** 

---

### Q18: How would you identify and remove duplicate records in PySpark?

**Also asked at:** JPMorgan

**Answer:**
Exact duplicates use `dropDuplicates()`; duplicates by business key keep one row per key with a window:

```python
from pyspark.sql import functions as F, Window

# 1. Exact duplicate rows
deduped = df.dropDuplicates()

# 2. Duplicates by key: keep any one row per key
deduped_by_key = df.dropDuplicates(["customer_id", "order_id"])

# 3. Find which keys are duplicated (for reporting)
dupes = df.groupBy("customer_id", "order_id").count().filter("count > 1")
```

`dropDuplicates(subset)` keeps an **arbitrary** row per key. When you need a specific one (the latest), use the window approach in the next question. In streaming, combine `dropDuplicates` with a watermark to bound state.

**Follow-ups:**
- Why is the row kept by `dropDuplicates(subset)` not deterministic?
- How would you deduplicate a streaming DataFrame?

**Difficulty:** Easy


**Role:** GCP Data Engineer

**Round:** Technical evaluation

**Asked:** 

---

### Q19: How would you use window functions to retain the latest record?

**Answer:**
Rank rows per key by recency and keep rank 1:

```python
from pyspark.sql import functions as F, Window

w = Window.partitionBy("customer_id").orderBy(F.col("updated_at").desc(), F.col("ingest_ts").desc())

latest = (df.withColumn("rn", F.row_number().over(w))
            .filter(F.col("rn") == 1)
            .drop("rn"))
```

Use `row_number` (not `rank`) to guarantee exactly one row per key, and add a tie-breaker column so the result is deterministic. For very large data, an alternative that avoids sorting whole partitions is `groupBy(key).agg(F.max_by("struct_col", "updated_at"))` (Spark 3.3+).

**Follow-ups:**
- Why `row_number` rather than `rank` here?
- How would you apply this to a Delta table incrementally?

**Difficulty:** Medium


**Role:** GCP Data Engineer

**Round:** Technical evaluation

**Asked:** 

## Wipro

### Q20: What are the persistence (storage) levels in Spark, and when would you use each?

**Answer:**
Storage levels control **where** cached partitions live and whether they're **serialized** or **replicated**:

| Level | Stored | Use when |
|---|---|---|
| `MEMORY_ONLY` | Memory (deserialized); partitions that don't fit are recomputed | Data fits in memory and recompute is cheap |
| `MEMORY_AND_DISK` | Memory, spilling the rest to disk | Default for DataFrame `cache()`; data may not fit |
| `MEMORY_ONLY_SER` / `MEMORY_AND_DISK_SER` (JVM/RDD API) | Serialized: smaller, more CPU to read | Memory is tight |
| `DISK_ONLY` | Disk only | Very large, expensive-to-recompute data reused rarely |
| `*_2` (e.g. `MEMORY_AND_DISK_2`) | Replicated on two nodes | Recompute is very expensive and executors are unstable |
| `OFF_HEAP` | Off-heap memory | Reducing GC pressure (needs configuration) |

```python
from pyspark import StorageLevel
df.persist(StorageLevel.DISK_ONLY)
df.unpersist()          # release it when you're done
```

Only cache data that's **reused** several times, and check the Storage tab in the Spark UI to confirm it fits.

**Follow-ups:**
- What's the difference between `cache()` and `persist()`?
- When does caching make a job slower?

**Difficulty:** Medium


**Role:** Azure Data Engineer (5+ years)

**Round:** Round 1 – Technical

**Asked:** 

---

### Q21: What is the Catalyst optimizer, and how does Spark SQL process a query from parsing to execution?

**Answer:**
**Spark SQL's path from query to execution** (for both SQL and DataFrame code):
1. **Parsing:** SQL text, or the DataFrame API, becomes an **unresolved logical plan**.
2. **Analysis:** the analyzer resolves table and column names and types against the catalog → **resolved logical plan**.
3. **Logical optimization (Catalyst):** rule-based rewrites such as predicate pushdown, column pruning, constant folding, and join reordering (with cost-based optimization when statistics exist).
4. **Physical planning:** Catalyst generates candidate physical plans (e.g. broadcast vs sort-merge join) and picks one using cost estimates.
5. **Code generation (Tungsten):** whole-stage codegen compiles chains of operators into JVM bytecode, with efficient off-heap memory and binary row formats.
6. **Execution:** the plan runs as stages and tasks. **AQE** can re-optimize at runtime using real shuffle statistics (coalescing partitions, switching join strategy, splitting skewed partitions).

`df.explain(mode="extended")` shows each plan. This is why built-in functions beat UDFs: Catalyst can't see inside a UDF.

**Follow-ups:**
- What's the difference between rule-based and cost-based optimization?
- How does AQE change a plan at runtime?

**Difficulty:** Hard


**Role:** Azure Data Engineer (5+ years)

**Round:** Round 2 – Technical

**Asked:** 

---

### Q22: What are the different join strategies in Spark, and what happens under the hood for each?

**Answer:**
| Strategy | How it works | When Spark chooses it |
|---|---|---|
| **Broadcast hash join** | The small table is sent to every executor; each task joins its partition of the big table locally. **No shuffle** of the big side | One side is under `spark.sql.autoBroadcastJoinThreshold` (10 MB by default), or a `broadcast()` hint |
| **Shuffle hash join** | Both sides are shuffled by key; for each partition, a hash table is built on the smaller side | One side is much smaller per partition, and sort-merge isn't preferred (`spark.sql.join.preferSortMergeJoin=false`, or AQE decides) |
| **Sort-merge join** | Both sides are shuffled by key, **sorted**, then merged | The default for large-to-large equi-joins; scales well and can spill to disk |
| **Broadcast nested loop / Cartesian** | Every row compared with every row | Non-equi joins or cross joins: expensive |

Under the hood, shuffle-based joins write map outputs partitioned by join key and read them in the next stage. Skewed keys create long-running tasks, which AQE can split. Check the chosen strategy with `explain()`.

**Follow-ups:**
- How do you force or prevent a broadcast join?
- Why can a broadcast join fail with an OOM?

**Difficulty:** Hard


**Role:** Azure Data Engineer (5+ years)

**Round:** Round 2 – Technical

**Asked:** 
