# Python Coding Practice — Data Engineer Interview Problems

Try each problem yourself before checking `coding-solutions.md`. Every solution has been executed and verified.

---

### P1. Deduplicate a list of records by key, keeping the most recently updated version
Given a list of dicts representing the same entities updated multiple times, return one record per key — the one with the highest timestamp.
```python
records = [
    {"id": 1, "val": "a", "ts": 10},
    {"id": 2, "val": "b", "ts": 12},
    {"id": 1, "val": "a-updated", "ts": 15},
]
# dedupe_latest(records, key="id", ts_field="ts")
# -> [{"id": 1, "val": "a-updated", "ts": 15}, {"id": 2, "val": "b", "ts": 12}]
```

---

### P2. Merge overlapping intervals
Given a list of `(start, end)` tuples, merge all overlapping/touching intervals.
```python
merge_intervals([(1,3),(2,6),(8,10),(15,18)])
# -> [(1,6),(8,10),(15,18)]
```

---

### P3. Find the longest streak of consecutive active days
Given a list of `date` objects (a user's activity log, possibly unordered with duplicates), find the length of the longest run of consecutive calendar days.

---

### P4. Chunk a large iterable into fixed-size batches
Useful for batching API calls or bulk-insert operations without loading everything into memory at once.
```python
list(chunk(range(10), 3))
# -> [[0,1,2],[3,4,5],[6,7,8],[9]]
```

---

### P5. Top-K frequent elements
Given a list of items, return the K most frequent ones.

---

### P6. Flatten a nested dictionary (e.g., parsed JSON)
```python
flatten_dict({"user": {"id": 1, "address": {"city": "NYC", "zip": "10001"}}, "active": True})
# -> {"user.id": 1, "user.address.city": "NYC", "user.address.zip": "10001", "active": True}
```

---

### P7. Write a retry decorator with exponential backoff
Wrap any function so that on failure, it retries up to N times with increasing delay between attempts, then re-raises if all attempts fail.

---

### P8. Detect a cycle in a task dependency graph (DAG validation)
Given a dict representing `{task: [downstream_tasks]}`, determine whether the graph contains a cycle (which would make it an invalid DAG for something like Airflow).
```python
has_cycle({"extract": ["transform"], "transform": ["load"], "load": []})       # -> False
has_cycle({"extract": ["transform"], "transform": ["load"], "load": ["extract"]})  # -> True
```

---

### P9. Parse structured fields out of a raw log line using regex
```python
line = '192.168.1.1 - - [10/Jan/2024:13:55:36] "GET /index.html HTTP/1.1" 200'
parse_log_line(line)
# -> {"ip": "192.168.1.1", "timestamp": "10/Jan/2024:13:55:36", "method": "GET", "path": "/index.html", "status": 200}
```

---

### P10. Implement an LRU (Least Recently Used) cache
Support `get(key)` and `put(key, value)`, evicting the least-recently-used entry when capacity is exceeded.

---

### P11. Compute a moving average over a stream of values
Implement a class with a `next(value)` method that returns the average of the last N values seen so far (fewer than N at the start).
```python
ma = MovingAverage(3)
[ma.next(x) for x in [1, 10, 3, 5]]
# -> [1.0, 5.5, 4.666..., 6.0]
```

---

### P12. Find gaps in a sequence of IDs
Given a list of integer IDs that should ideally be contiguous (e.g., auto-incrementing primary keys, or a sequence number in an event log), find the missing ranges.
```python
find_gaps([1,2,3,7,8,10])
# -> [(4,6),(9,9)]
```
