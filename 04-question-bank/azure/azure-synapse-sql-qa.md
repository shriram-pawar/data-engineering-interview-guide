# Azure Synapse & Azure SQL — Interview Question Bank

> Format: Question · Answer · Follow-ups · Difficulty

---

### Q1: What is Azure Synapse Analytics, and what are its main components?

**Answer:**
An integrated analytics workspace combining:
- **Dedicated SQL pools:** a provisioned **MPP data warehouse** (formerly SQL DW), billed by DWU, with distributed tables and columnstore indexes.
- **Serverless SQL pool:** on-demand T-SQL over files in the lake (Parquet, CSV, Delta), paid per TB processed; no infrastructure.
- **Apache Spark pools:** managed Spark for data engineering and ML notebooks.
- **Synapse pipelines:** ADF-style orchestration inside the workspace.
- **Data Explorer pools** (log and time-series analytics), plus integration with Power BI, Purview and Azure ML.
- **Synapse Studio** as the single UI.

It's used when an organization wants a SQL warehouse plus lake querying in one place; Microsoft Fabric is the newer evolution of the same ideas.

**Follow-ups:**
- When would you use the serverless SQL pool instead of a dedicated pool?
- How does Synapse relate to Microsoft Fabric?

**Difficulty:** Easy

---

### Q2: Dedicated SQL pool vs serverless SQL pool in Synapse: what's the difference?

**Answer:**
| | Dedicated SQL pool | Serverless SQL pool |
|---|---|---|
| Model | Provisioned MPP warehouse (DWUs); data **loaded into** managed storage | Query **files in the lake in place** (external tables, `OPENROWSET`) |
| Billing | Per hour of provisioned DWUs (pause to save) | Per TB of data processed |
| Performance | Predictable, tunable (distributions, indexes, materialized views, result cache) | Depends on file layout (Parquet, partitioning); good for ad-hoc work |
| Use for | Heavy, frequent BI workloads, a serving layer with strict SLAs | Exploration, lightweight reporting, logical data warehouse over the lake |

Many designs use serverless for exploration and the curated lake, and a dedicated pool only for high-concurrency, performance-critical gold data.

**Follow-ups:**
- How do you reduce cost on a serverless SQL pool?
- Why pause a dedicated pool?

**Difficulty:** Medium

---

### Q3: What are the Azure options for running SQL Server databases, and how do they differ?

**Answer:**
| Option | What it is | Use when |
|---|---|---|
| **Azure SQL Database** | Fully managed **PaaS** database (single DB or elastic pool); serverless and Hyperscale tiers | New cloud applications; no need for instance-level features |
| **Azure SQL Managed Instance** | Managed **instance** with near-100% SQL Server compatibility: SQL Agent, cross-database queries, CLR, Service Broker, VNet-native | Lift-and-shift of existing SQL Server apps that use instance features |
| **SQL Server on Azure VMs** | **IaaS**: full SQL Server on a VM you manage (OS, patching, HA) | Full control, unsupported features, specific versions, third-party software |

Moving down the table gives more control and compatibility, but more management work. For analytics at scale, use Synapse, Fabric or Databricks, not these OLTP engines.

**Follow-ups:**
- Which option supports SQL Server Agent jobs?
- What is the Hyperscale tier for?

**Difficulty:** Easy

---

### Q4: How does data distribution work in a Synapse dedicated SQL pool, and which distribution should you choose?

**Answer:**
A dedicated pool spreads every table across **60 distributions** processed in parallel by compute nodes. The distribution type decides where rows go:

| Type | How rows are placed | Use for |
|---|---|---|
| **Hash** | `HASH(column)` decides the distribution | Large fact tables (over about 2 GB); choose a high-cardinality, evenly spread column used in joins or GROUP BY (not a date, not mostly-NULL) |
| **Round robin** | Evenly, in turn, with no key | Staging tables and fast loads; tables with no good key |
| **Replicated** | A full copy cached on every compute node | Small dimension tables (under about 2 GB), joined often |

Good choices avoid **data movement** (shuffles) during joins: hash-distribute the fact and the large dimension on the same join key, and replicate small dimensions.

**Follow-ups:**
- What happens when you hash-distribute on a skewed column?
- Why is round robin bad for joins?

**Difficulty:** Medium

---

### Q5: What is PolyBase used for in Synapse and SQL Server?

**Answer:**
PolyBase lets the SQL engine **read external data with T-SQL** through external tables: files in ADLS or Blob (Parquet, CSV, ORC), and in SQL Server also other databases (Oracle, Teradata, MongoDB, other SQL Servers).

Uses:
- **Loading** a dedicated pool fast: `CREATE EXTERNAL TABLE` over lake files, then `INSERT ... SELECT` / CTAS. Parallel loading through all compute nodes is much faster than row-by-row inserts. (Today, `COPY INTO` is the simpler recommended load command.)
- **Querying** lake data without loading it (data virtualization).

Components: `CREATE EXTERNAL DATA SOURCE` (location plus credential), `CREATE EXTERNAL FILE FORMAT`, `CREATE EXTERNAL TABLE`.

**Follow-ups:**
- How does `COPY INTO` compare with PolyBase for loading?
- What credentials does an external data source use?

**Difficulty:** Medium

---

### Q6: What is CETAS, and when would you use it?

**Answer:**
**CETAS = CREATE EXTERNAL TABLE AS SELECT.** It runs a query and **writes the result to files in the lake** (Parquet or CSV) while creating an external table over them:

```sql
CREATE EXTERNAL TABLE gold.daily_sales
WITH (LOCATION = 'gold/daily_sales/', DATA_SOURCE = lake, FILE_FORMAT = parquet_ff)
AS
SELECT order_date, region, SUM(amount) AS revenue
FROM silver.orders
GROUP BY order_date, region;
```

Uses: materializing transformed or aggregated results from a **serverless SQL pool** (which can't store regular tables), exporting warehouse data to the lake for other engines, and creating reusable intermediate datasets. Rerunning needs the target folder to be empty (drop the table and delete the files first).

**Follow-ups:**
- How is CETAS different from CTAS?
- How would you refresh a CETAS result daily?

**Difficulty:** Medium

---

### Q7: What's the difference between rowstore and columnstore storage, and what is a clustered columnstore index?

**Answer:**
- **Rowstore** keeps all columns of a row together: fast for OLTP lookups and updates of single rows.
- **Columnstore** keeps each column together in compressed segments (about 1 million rows per rowgroup): much smaller and much faster for analytics that scan a few columns over many rows, with segment elimination (skipping) and batch-mode execution.

A **clustered columnstore index (CCI)** stores the whole table in columnstore format. It's the **default and recommended** for large tables in Synapse dedicated pools. Tips: load in large batches (at least about 100k rows per distribution) so rowgroups are compressed well, and rebuild or reorganize indexes after heavy trickle loads or deletes. Use heap or rowstore for small staging tables.

**Follow-ups:**
- Why do small trickle inserts hurt columnstore quality?
- When would you use a heap table?

**Difficulty:** Medium

---

### Q8: How does workload management work in a Synapse dedicated SQL pool?

**Answer:**
It controls how concurrent queries share resources:
- **Workload groups** reserve and cap a percentage of resources (`MIN_PERCENTAGE_RESOURCE`, `CAP_PERCENTAGE_RESOURCE`) and set per-request resources and timeouts.
- **Workload classifiers** route requests to groups by user, role, label or session context, with an **importance** (low → high) that decides who goes first when resources are scarce.
- Older **resource classes** (`smallrc`, `largerc`, …) do the same in a simpler way.

Typical setup: a group for ETL loads with guaranteed resources, a group for BI dashboards with high importance and short queries, and a capped group for ad-hoc analysts, so one heavy query can't starve the others.

**Follow-ups:**
- What's the trade-off between giving a query more resources and concurrency?
- How do you label queries for classification?

**Difficulty:** Hard

---

### Q9: What causes data skew in a Synapse dedicated pool, and how do you fix it?

**Answer:**
**Cause:** a hash-distributed table whose distribution column has uneven values (a few hot values, many NULLs or defaults), so some of the 60 distributions hold far more rows. Queries wait for the slowest distribution.

**Detect:**
```sql
DBCC PDW_SHOWSPACEUSED('dbo.fact_sales');   -- rows per distribution
```
Or use the `sys.dm_pdw_nodes_db_partition_stats` DMVs; look for distributions with much more data than average (over about 10% skew is worth fixing).

**Fix:** re-create the table (CTAS) hash-distributed on a **higher-cardinality, evenly distributed** column (or a combination via a computed key); use round robin if no good key exists; handle NULL or default keys separately. Then check query plans for reduced data movement.

**Follow-ups:**
- Why is a date column usually a poor distribution key?
- How do you change a table's distribution?

**Difficulty:** Hard

---

### Q10: How do you optimize a slow query in a Synapse dedicated SQL pool?

**Answer:**
1. **Look at the plan and DMVs** (`sys.dm_pdw_exec_requests`, `sys.dm_pdw_request_steps`): which step is slow; is there a lot of **data movement** (ShuffleMove, BroadcastMove)?
2. **Distribution:** align hash distributions on join keys and replicate small dimensions to avoid shuffles; fix skew.
3. **Statistics:** create or update statistics on join, filter and group-by columns (stale stats lead to bad plans).
4. **Columnstore health:** well-compressed rowgroups; rebuild after trickle loads.
5. **Partitioning:** partition large facts by date for elimination, without over-partitioning (60 distributions × partitions).
6. **Materialized views and result set caching** for repeated aggregations.
7. **Resources and concurrency:** the right workload group or resource class; scale DWUs if needed.
8. **Query shape:** select only needed columns; avoid functions on filter columns.

**Follow-ups:**
- What does a BroadcastMove in the plan tell you?
- Why do stale statistics hurt in an MPP system?

**Difficulty:** Hard
