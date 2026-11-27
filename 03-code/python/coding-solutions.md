# Python Coding Practice — ANSWERS

*(Every solution below has been executed against the examples in `coding-problems.md` and passes.)*

---

### P1. Deduplicate by key, keeping latest
```python
def dedupe_latest(records, key, ts_field):
    latest = {}
    for r in records:
        k = r[key]
        if k not in latest or r[ts_field] > latest[k][ts_field]:
            latest[k] = r
    return list(latest.values())
```
**Complexity**: O(n) time, O(unique keys) space — single pass, no sorting needed.

---

### P2. Merge overlapping intervals
```python
def merge_intervals(intervals):
    intervals = sorted(intervals, key=lambda x: x[0])
    merged = []
    for start, end in intervals:
        if merged and start <= merged[-1][1]:
            merged[-1] = (merged[-1][0], max(merged[-1][1], end))
        else:
            merged.append((start, end))
    return merged
```
**Key idea**: sort by start time first, then a single pass — if the current interval starts before (or exactly when) the last merged interval ends, extend it; otherwise start a new merged interval.

---

### P3. Longest streak of consecutive active days
```python
from datetime import timedelta

def longest_streak(dates):
    dates = sorted(set(dates))
    if not dates:
        return 0
    longest = current = 1
    for i in range(1, len(dates)):
        if dates[i] - dates[i-1] == timedelta(days=1):
            current += 1
        else:
            current = 1
        longest = max(longest, current)
    return longest
```
This is the Python equivalent of the classic SQL "Consecutive Numbers" gaps-and-islands problem — sort, then track a running streak counter that resets on any gap.

---

### P4. Chunk an iterable into batches
```python
def chunk(iterable, size):
    batch = []
    for item in iterable:
        batch.append(item)
        if len(batch) == size:
            yield batch
            batch = []
    if batch:
        yield batch
```
Written as a generator so it works on arbitrarily large/streaming iterables without holding everything in memory at once.

---

### P5. Top-K frequent elements
```python
from collections import Counter
import heapq

def top_k_frequent(items, k):
    counts = Counter(items)
    return [item for item, _ in heapq.nlargest(k, counts.items(), key=lambda x: x[1])]
```
`heapq.nlargest` is O(n log k) — better than sorting the full frequency list (O(n log n)) when k is small relative to n.

---

### P6. Flatten a nested dictionary
```python
def flatten_dict(d, parent_key="", sep="."):
    items = {}
    for k, v in d.items():
        new_key = f"{parent_key}{sep}{k}" if parent_key else k
        if isinstance(v, dict):
            items.update(flatten_dict(v, new_key, sep))
        else:
            items[new_key] = v
    return items
```
Recursive approach; handles arbitrary nesting depth. (In practice, you'd also want a branch for lists of dicts depending on how you want array data represented.)

---

### P7. Retry decorator with exponential backoff
```python
import time, functools

def retry(max_attempts=3, base_delay=0.01):
    def decorator(func):
        @functools.wraps(func)
        def wrapper(*args, **kwargs):
            attempt = 0
            while True:
                try:
                    return func(*args, **kwargs)
                except Exception:
                    attempt += 1
                    if attempt >= max_attempts:
                        raise
                    time.sleep(base_delay * (2 ** (attempt - 1)))
        return wrapper
    return decorator

# Usage:
@retry(max_attempts=3, base_delay=0.5)
def call_flaky_api():
    ...
```
`functools.wraps` preserves the wrapped function's name/docstring — good practice for any decorator. Delay doubles each attempt (`base_delay * 2^(attempt-1)`).

---

### P8. Detect a cycle in a DAG (3-color DFS)
```python
def has_cycle(graph):
    WHITE, GRAY, BLACK = 0, 1, 2
    color = {node: WHITE for node in graph}

    def dfs(node):
        color[node] = GRAY  # currently being explored (on the DFS stack)
        for neighbor in graph.get(node, []):
            if color.get(neighbor, WHITE) == GRAY:
                return True  # back-edge to a node on the current path -> cycle
            if color.get(neighbor, WHITE) == WHITE and dfs(neighbor):
                return True
        color[node] = BLACK  # fully explored, safe
        return False

    return any(color[node] == WHITE and dfs(node) for node in graph)
```
This is exactly the algorithm Airflow itself effectively needs to validate a DAG has no cycles. GRAY = "on the current DFS path"; hitting a GRAY node again means a back-edge, i.e., a cycle.

---

### P9. Parse a log line with regex
```python
import re

def parse_log_line(line):
    pattern = r'(?P<ip>[\d\.]+) - - \[(?P<timestamp>[^\]]+)\] "(?P<method>\w+) (?P<path>\S+).*?" (?P<status>\d+)'
    m = re.match(pattern, line)
    if not m:
        return None
    d = m.groupdict()
    d["status"] = int(d["status"])
    return d
```
Named capture groups (`?P<name>...`) make the extracted dict self-documenting. Always return `None`/route-to-dead-letter on non-match rather than raising, for pipeline robustness.

---

### P10. LRU Cache
```python
from collections import OrderedDict

class LRUCache:
    def __init__(self, capacity):
        self.capacity = capacity
        self.cache = OrderedDict()

    def get(self, key):
        if key not in self.cache:
            return -1
        self.cache.move_to_end(key)  # mark as recently used
        return self.cache[key]

    def put(self, key, value):
        if key in self.cache:
            self.cache.move_to_end(key)
        self.cache[key] = value
        if len(self.cache) > self.capacity:
            self.cache.popitem(last=False)  # evict least recently used
```
`OrderedDict` gives O(1) `move_to_end` and O(1) pop-from-front, so both `get` and `put` are O(1) — this is the standard interview-expected implementation.

---

### P11. Moving average over a stream
```python
from collections import deque

class MovingAverage:
    def __init__(self, window_size):
        self.window = deque(maxlen=window_size)

    def next(self, value):
        self.window.append(value)
        return sum(self.window) / len(self.window)
```
`deque(maxlen=N)` automatically drops the oldest element once full — no manual bookkeeping needed. (For very high-frequency streams, you'd maintain a running sum incrementally rather than re-summing the deque each call, to avoid O(N) work per `next()`.)

---

### P12. Find gaps in a sequence of IDs
```python
def find_gaps(ids):
    ids = sorted(ids)
    gaps = []
    for i in range(1, len(ids)):
        if ids[i] - ids[i-1] > 1:
            gaps.append((ids[i-1] + 1, ids[i] - 1))
    return gaps
```
Sort, then look at consecutive pairs — any gap greater than 1 between neighbors means missing values in between.
