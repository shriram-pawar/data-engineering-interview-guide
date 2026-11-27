# Real-World Asked: GCP

Google Cloud (BigQuery, Cloud Storage, Composer, Dataflow, …) questions reported from real data engineering interviews.

See [README.md](README.md) for the layout and contributor rules. Fields are left blank when unknown.

## Unspecified company

### Q1: Cost of `SELECT *` vs `SELECT * ... LIMIT 10` in BigQuery

In BigQuery, what's the difference between `SELECT * FROM employee` and `SELECT * FROM employee LIMIT 10` in terms of computation, data scanned and cost?

**Answer:**
BigQuery bills on-demand queries by **bytes read from the columns referenced**, not by rows returned. `LIMIT` is applied after the data is read, so on a regular (non-clustered) table both queries read every column of every row and **cost the same**; the `LIMIT` version only returns less data to the client.

| | `SELECT *` | `SELECT * ... LIMIT 10` |
|---|---|---|
| Bytes read / billed | All columns, whole table | Same: all columns, whole table |
| Rows returned | All | 10 |
| Slot time | Full scan | Roughly the same scan |

To look at sample rows cheaply:
- Use the table **Preview** tab, `bq head`, or the `tabledata.list` API: these are free.
- Select only the columns you need: cost scales with the columns referenced.
- Filter on the **partition column** (and clustered columns) so BigQuery can prune data before reading it.
- Check the dry-run estimate ("This query will process X GB") before running.

**Follow-ups:**
- Why can a `WHERE` filter on a clustered column reduce cost, while `LIMIT` doesn't?
- How would you stop analysts from running accidental full scans (`require_partition_filter`, maximum bytes billed)?

**Difficulty:** Easy

**Role:** 

**Round:** 

**Asked:** 
