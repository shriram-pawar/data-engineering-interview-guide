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
