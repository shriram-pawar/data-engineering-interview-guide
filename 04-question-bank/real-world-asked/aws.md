# Real-World Asked: AWS

AWS data engineering questions reported from real interviews.

See [README.md](README.md) for the layout and contributor rules. Fields are left blank when unknown.

## JPMorgan

### Q1: AWS Glue vs Amazon EMR: what's the difference, and when would you choose each?

**Answer:**
| | AWS Glue | Amazon EMR |
|---|---|---|
| Model | **Serverless** Spark (and Python shell) ETL | **Managed clusters** (EC2, EKS) or EMR Serverless |
| Operations | No cluster management; pay per DPU-hour | You choose instance types, sizes, configs |
| Ecosystem | Glue Data Catalog, crawlers, job bookmarks (incremental), visual ETL | Spark, Hive, Presto/Trino, HBase, Flink, custom libraries |
| Control and tuning | Limited | Full control (configs, spot fleets, bootstrap actions) |
| Cost at scale | Simple but can be expensive for big, long, steady jobs | Cheaper for large, long-running or steady workloads, especially with Spot |

**Choose Glue** for standard, moderate ETL jobs with little ops effort and tight catalog integration. **Choose EMR** for very large or long-running workloads, non-Spark engines, heavy tuning, or cost optimization at scale.

**Follow-ups:**
- How do Glue job bookmarks work?
- When would EMR Serverless be a good middle ground?

**Difficulty:** Medium


**Role:** Senior / Lead Data Engineer

**Round:** Technical Round 2

**Asked:** 

---

### Q2: How do you carry out a migration from on-premises to AWS?

**Answer:**
1. **Assess:** inventory sources, data volumes, dependencies, SLAs and compliance; choose a strategy per workload (rehost, replatform, refactor).
2. **Landing zone:** accounts, VPCs and networking (Direct Connect or VPN), IAM, encryption (KMS), logging.
3. **Move the data:**
   - Bulk history: **AWS DataSync**, **Snowball** for very large volumes, or exports to S3.
   - Databases: **AWS DMS** for full load plus **ongoing CDC**, with the Schema Conversion Tool for heterogeneous engines.
4. **Rebuild pipelines:** S3 as the data lake (raw, curated), Glue or EMR for processing, Redshift or Athena for analytics, Step Functions or MWAA (Airflow) for orchestration.
5. **Validate:** row counts, checksums, report reconciliation; then a parallel run.
6. **Cut over** with a rollback plan, then decommission on-prem.
7. **Optimize:** cost (storage classes, Spot, reserved capacity), performance, governance (Lake Formation).

**Follow-ups:**
- How do you keep data in sync during a long parallel run?
- When would you use Snowball instead of network transfer?

**Difficulty:** Medium


**Role:** Senior / Lead Data Engineer

**Round:** Technical Round 2

**Asked:** 

---

### Q3: Can you load a 1 TB file daily from S3 into Redshift, and how would you upsert it into the destination table without duplicates?

**Answer:**
Yes, with **`COPY`** (parallel bulk load) plus a staged **`MERGE`**:
1. **Prepare the file:** a single huge file loads slowly, because `COPY` parallelizes per file. Split it into many compressed parts (ideally a multiple of the number of slices, about 100 MB–1 GB each), or use columnar **Parquet**.
2. **Load into a staging table:**
   ```sql
   COPY stage_txn FROM 's3://my-bucket/txn/2024-06-01/'
   IAM_ROLE 'arn:aws:iam::123456789012:role/redshift-load'
   FORMAT AS PARQUET;
   ```
3. **Deduplicate staging** (latest record per key) and **upsert in one transaction:**
   ```sql
   MERGE INTO txn USING (SELECT * FROM stage_txn_dedup) s
   ON txn.txn_id = s.txn_id
   WHEN MATCHED THEN UPDATE SET amount = s.amount, updated_at = s.updated_at
   WHEN NOT MATCHED THEN INSERT VALUES (s.txn_id, s.amount, s.updated_at);
   ```
   (Before `MERGE` was available: `DELETE` matching keys, then `INSERT`, in one transaction.)
4. **Table design:** a distribution key on the join key (`txn_id`) and a sort key on the date, to make the merge efficient; `ANALYZE` and `VACUUM` as needed.
5. **Idempotency:** truncate staging per run, so a rerun of the same day produces the same result.

**Follow-ups:**
- Why does splitting the file speed up `COPY`?
- How do distribution and sort keys affect the merge?

**Difficulty:** Hard


**Role:** Senior / Lead Data Engineer

**Round:** Technical Round 2

**Asked:** 
