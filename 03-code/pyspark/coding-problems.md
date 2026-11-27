# PySpark Coding Practice — Data Engineer Interview Problems

Try each problem yourself before checking `coding-solutions.md`. Every solution has been executed against real PySpark (local mode) and verified.

**Setup used across problems** (create once at the top of your practice session):
```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.window import Window

spark = SparkSession.builder.master("local[2]").appName("practice").getOrCreate()
```

---

### PS1. Word count
Given a DataFrame of text lines, compute the frequency of each word, ordered most-to-least frequent.
```python
lines = spark.createDataFrame([("the quick brown fox",), ("the fox jumps",)], ["line"])
# expected: "the" -> 2, "fox" -> 2, "quick" -> 1, "brown" -> 1, "jumps" -> 1
```

---

### PS2. Running total of order amounts per customer
```python
orders = spark.createDataFrame([
    (1, "2024-01-01", 100), (1, "2024-01-02", 50), (1, "2024-01-03", 25),
    (2, "2024-01-01", 200),
], ["customer_id", "order_date", "amount"])
# For customer 1 ordered by date: running_total should be 100, 150, 175
```

---

### PS3. Deduplicate records, keeping the latest version per key
```python
records = spark.createDataFrame([
    (1, "a", 10), (1, "a-updated", 15), (2, "b", 12),
], ["id", "val", "ts"])
# Keep only the row with the max ts per id
```

---

### PS4. Find each user's first and last event timestamp
```python
events = spark.createDataFrame([
    (1, "2024-01-01 10:00:00", "login"), (1, "2024-01-01 12:00:00", "logout"),
    (2, "2024-01-01 09:00:00", "login"),
], ["user_id", "event_ts", "event_type"])
```

---

### PS5. Data quality: split good vs bad records (quarantine pattern)
Given raw data with required fields `email` and `amount`, split into a "good" DataFrame (all required fields present) and a "bad" DataFrame (missing something) — don't just drop the bad rows silently.
```python
raw = spark.createDataFrame([
    (1, "a@x.com", 100), (2, None, 200), (3, "c@x.com", None),
], ["id", "email", "amount"])
```

---

### PS6. Flatten a nested array column (`explode`)
Given an `orders` DataFrame where each row has an array of `(sku, qty)` line items, produce one row per line item.

---

### PS7. Top-1 product by sales within each category (window function)
```python
sales = spark.createDataFrame([
    ("electronics", "phone", 500), ("electronics", "laptop", 1000),
    ("electronics", "cable", 20), ("clothing", "shirt", 50), ("clothing", "shoes", 80),
], ["category", "product", "sales"])
# expected: electronics -> laptop, clothing -> shoes
```

---

### PS8. Sessionize a clickstream — assign a session ID based on a 10-minute (600s) inactivity gap
```python
clicks = spark.createDataFrame([
    (1, 0), (1, 100), (1, 200), (1, 2000), (1, 2050),
], ["user_id", "ts_seconds"])
# Gap between ts=200 and ts=2000 is 1800s (> 600s) -> new session starts there
# expected session_ids in order: 1, 1, 1, 2, 2
```

---

### PS9. Pivot monthly revenue into columns
```python
dept_rev = spark.createDataFrame([
    (1, 8000, "Jan"), (2, 9000, "Jan"), (1, 7000, "Feb"),
], ["id", "revenue", "month"])
# expected columns: id, Jan, Feb  (department 2 has null for Feb)
```

---

### PS10. Join a large fact table with a small dimension table efficiently
Given a large `big` DataFrame (1000+ rows) and a tiny `small` lookup DataFrame (a handful of category mappings), join them in a way that avoids an unnecessary shuffle of the large table.
```python
big = spark.createDataFrame([(i, i % 5) for i in range(1000)], ["id", "category_id"])
small = spark.createDataFrame([(0,"a"),(1,"b"),(2,"c"),(3,"d"),(4,"e")], ["category_id", "category_name"])
```
