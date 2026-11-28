# Teradata to BigQuery Migration — Interview Question Bank

*(For a full worked example of a warehouse migration, see the case study in [`05-system-design/case-studies/`](../../05-system-design/case-studies/).)*

> Format: Question · Answer · Follow-ups · Difficulty

---

### Q1: Why do organizations migrate from Teradata to BigQuery?

**Answer:**
- **No infrastructure to manage:** no appliance refreshes, capacity planning or node expansion.
- **Elastic scale:** compute and storage are separated; pay per query or per slot, and scale for peaks.
- **Cost:** avoid large license and hardware renewals; cheap long-term storage.
- **Ecosystem:** native integration with Cloud Storage, Dataflow, Composer, Looker, BigQuery ML and Vertex AI.
- **New capabilities:** semi-structured data, streaming ingestion, sharing with authorized views and Analytics Hub.

In an interview, tie it to business outcomes: faster reports, lower total cost, and enabling ML.

**Follow-ups:**
- What are the risks of a Teradata migration?
- How would you build the cost case?

**Difficulty:** Easy

---

### Q2: What are the main phases of a Teradata to BigQuery migration?

**Moved:** this question was asked in real interviews, so its answer now lives in [`real-world-asked/gcp.md`](../real-world-asked/gcp.md).

---

### Q3: How do you move large volumes of data from Teradata to BigQuery?

**Answer:**
- **BigQuery Data Transfer Service for Teradata** (part of the BigQuery Migration Service): an agent extracts tables (via TPT or JDBC), stages them in Cloud Storage and loads them into BigQuery, with incremental options.
- **Custom extract:** export with **TPT (Teradata Parallel Transporter)** to compressed files (Avro or Parquet preferred over CSV), copy with `gcloud storage cp` / Storage Transfer Service, then `bq load`.
- **Very large one-time volumes** with limited bandwidth: **Transfer Appliance**.

Load in parallel by table and partition, migrate history first, then switch to incremental (watermark or CDC) loads until cutover.

**Follow-ups:**
- Why prefer Avro or Parquet over CSV for the export?
- How would you keep BigQuery in sync during a months-long parallel run?

**Difficulty:** Medium

---

### Q4: How do you convert Teradata SQL to BigQuery SQL?

**Answer:**
Start with the **BigQuery Migration Service SQL translator** (batch or interactive), which handles most syntax automatically, then fix the rest by hand. Common differences:

| Teradata | BigQuery |
|---|---|
| `SEL`, `INS`, `UPD` abbreviations | Full keywords |
| `QUALIFY` | Also supported (needs a `WHERE`, `GROUP BY` or `HAVING` clause) |
| `date + 1`, `ADD_MONTHS` | `DATE_ADD(date, INTERVAL 1 DAY)`, `DATE_ADD(..., INTERVAL n MONTH)` |
| `TOP n`, `SAMPLE n` | `LIMIT n`, `TABLESAMPLE SYSTEM (x PERCENT)` |
| Volatile / global temporary tables | Temporary tables in scripts, or CTEs |
| Case-insensitive comparisons by default | Case-sensitive: use `LOWER()` or collation |
| `CAST(... FORMAT '...')` | `FORMAT_DATE`, `PARSE_DATE` |

Then test translated queries against the same data and compare the results.

**Follow-ups:**
- How would you prioritize thousands of scripts for translation?
- What silent behavior differences can make translated queries return different results?

**Difficulty:** Hard

---

### Q5: How do you handle Teradata primary indexes and other indexes in BigQuery?

**Answer:**
BigQuery has **no indexes**: no primary index, secondary index or join index. Their purposes map to:
- **Data distribution (primary index):** not needed. BigQuery distributes storage and compute automatically.
- **Access paths (secondary and join indexes):** use **partitioning** (usually on a date) and **clustering** (up to 4 columns, often the old primary index or frequent filter and join keys).
- **Pre-joined or aggregated structures (join indexes, aggregate tables):** **materialized views** or scheduled summary tables.
- **Uniqueness:** BigQuery primary and foreign keys are `NOT ENFORCED` (they're optimizer hints), so enforce uniqueness in pipelines, e.g. with a `MERGE` on the key and dedupe checks.

**Follow-ups:**
- How would you guarantee no duplicate keys without enforced constraints?
- What do unenforced primary keys still buy you in BigQuery?

**Difficulty:** Medium

---

### Q6: How do you choose partitioning and clustering columns for migrated tables?

**Answer:**
- **Partition** on the column most queries filter by with a range, typically a **date or timestamp** (`order_date`, `event_ts`), at daily or monthly granularity. Keep partitions reasonably sized (not millions of tiny ones; there's a 10,000-partition limit per table), and set `require_partition_filter` on large tables.
- **Cluster** on columns used in **filters, joins and GROUP BY**, ordered by how often they're used (e.g. `customer_id`, `store_id`). High-cardinality columns work well.
- **Use the evidence:** Teradata query logs (DBQL) for the old filters and joins, and BigQuery `INFORMATION_SCHEMA.JOBS` after go-live to check bytes scanned.

Small tables (under about 1 GB) often need neither.

**Follow-ups:**
- What happens if most queries don't filter on the partition column?
- When would integer-range partitioning make sense?

**Difficulty:** Medium

---

### Q7: How do you migrate Teradata stored procedures, macros and BTEQ scripts?

**Answer:**
- **Stored procedures and macros** → BigQuery **stored procedures** (GoogleSQL scripting) or plain SQL. Rewrite row-by-row logic (cursors, loops) as set-based `MERGE` and window functions.
- **BTEQ scripts** (SQL plus control flow, error codes) → BigQuery scripts, or SQL tasks in **Cloud Composer** / **dbt** models, with retries and error handling there.
- **Control flow and scheduling** that lived in shell scripts or an enterprise scheduler → Composer DAGs.

The SQL translator helps with syntax, but business logic needs review and unit tests. Document every rule you discover.

**Follow-ups:**
- When would you move procedure logic into dbt instead of BigQuery procedures?
- How would you test a converted procedure?

**Difficulty:** Hard

---

### Q8: What data type and table-type mismatches do you watch for?

**Answer:**
| Teradata | BigQuery | Watch out for |
|---|---|---|
| `DECIMAL(p,s)` up to 38 digits | `NUMERIC` (38,9) / `BIGNUMERIC` | Scale above 9 needs `BIGNUMERIC` |
| `CHAR(n)` (space-padded) | `STRING` | Trailing spaces change comparisons: trim them |
| `VARCHAR(n)` | `STRING` | Length limits no longer enforced |
| `BYTEINT`, `SMALLINT`, `INTEGER`, `BIGINT` | `INT64` | Fine |
| `TIMESTAMP(n)` | `DATETIME` or `TIMESTAMP` | Time zones: Teradata timestamps are often local |
| `PERIOD`, `INTERVAL` types | Two columns, or `INTERVAL` | Need redesign |
| **SET** tables (reject duplicate rows) | No equivalent | Dedupe in the pipeline, otherwise duplicates appear |

**Follow-ups:**
- How would you detect precision loss after migration?
- Why do SET tables matter during validation?

**Difficulty:** Medium

---

### Q9: How do you validate that migrated data matches the source?

**Answer:**
Validate at increasing depth, and automate it so it runs every day of the parallel run:
1. **Row counts** per table and per partition (date).
2. **Aggregates:** sums, min/max and distinct counts of key numeric and date columns per partition.
3. **Hash comparisons:** row-level or column-level hashes on keys, either on all rows or on samples for huge tables.
4. **Schema checks:** column names, types and nullability.
5. **Report-level reconciliation** with business users.

Google's open-source **Data Validation Tool (DVT)** automates count, aggregate and row-hash comparisons between Teradata and BigQuery. When counts don't match, drill down by partition, then by key with an anti-join, to find missing or extra rows, and record each difference with its root cause (load issue, duplicates from SET tables, time-zone shift…).

**Follow-ups:**
- How would you compare hashes when string padding and time zones differ between systems?
- What tolerance, if any, would you accept for floating-point totals?

**Difficulty:** Medium

---

### Q10: How do you optimize queries after migrating them to BigQuery?

**Answer:**
- Check **bytes processed** and slot time in the query plan and `INFORMATION_SCHEMA.JOBS`.
- Add **partition filters** and clustering-friendly predicates; avoid functions on partition columns.
- **Select only the needed columns** (no `SELECT *`).
- Replace repeated heavy joins with **denormalized tables** or nested `ARRAY` / `STRUCT` fields.
- Use **materialized views** or summary tables for repeated aggregations.
- Rewrite procedural patterns (loops, temp-table chains) as set-based SQL.
- Fix **join skew** and order joins sensibly, so large tables aren't exploded early.

Teradata-tuned patterns (e.g. collecting statistics, PI-based joins) don't carry over, so re-tune on the BigQuery side.

**Follow-ups:**
- How would you find the most expensive queries after go-live?
- When are reservations (slots) cheaper than on-demand pricing?

**Difficulty:** Medium

---

### Q11: What challenges come up in a Teradata to BigQuery migration, and how do you address them?

**Answer:**
- **Hidden business logic** in BTEQ scripts, macros and ETL tools. Address it with automated inventory and lineage, and document rules as you go.
- **Behavior differences:** case sensitivity, CHAR padding, NULL handling, date arithmetic, SET-table deduplication. Address them with reconciliation and targeted tests.
- **Data volume and network limits:** parallel extracts, compressed columnar files, Transfer Appliance.
- **Keeping both systems in sync** during the parallel run: incremental loads (watermark or CDC) and daily automated validation.
- **Cost surprises** from unpartitioned queries: `require_partition_filter`, quotas and monitoring.
- **Downstream consumers** (reports, extracts): an inventory and communication plan.

Answer with a STAR-style example: the problem, what you did, and the measurable result.

**Follow-ups:**
- Which of these would you de-risk first?
- How would you handle a consumer that can't move off Teradata by the cutover date?

**Difficulty:** Medium
