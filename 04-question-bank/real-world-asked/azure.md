# Real-World Asked: Azure

Azure data platform questions (ADF, ADLS, Synapse, Key Vault) reported from real interviews.

See [README.md](README.md) for the layout and contributor rules. Fields are left blank when unknown.

## Deloitte

### Q1: How do you troubleshoot failed Azure Data Factory pipelines?

**Answer:**
1. **Monitor tab:** open the failed run, find the failing activity, and read its **error code and message** plus the input and output JSON.
2. **Classify the error:**
   - *Connectivity or auth*: linked service credentials, Key Vault access, firewall or private endpoint, Self-hosted IR offline.
   - *Source or sink data*: schema mismatch, type conversion, file not found, permissions on the folder.
   - *Throttling or timeouts*: database DTU limits, too much parallelism, activity timeout.
   - *Expression errors*: dynamic content evaluating to NULL or the wrong type.
3. **Reproduce in Debug** with the same parameters; check the IR's logs for Self-hosted IR issues.
4. **Fix and rerun safely:** "Rerun from failed activity" only if the earlier activities are idempotent.
5. **Prevent:** retries on transient activities, timeouts, failure alerts (Azure Monitor alerts or a Logic App/Web activity), and send diagnostic logs to Log Analytics for trend analysis.

**Follow-ups:**
- When is "rerun from failed activity" unsafe?
- How do you alert on ADF failures?

**Difficulty:** Medium


**Role:** Azure Data Engineer

**Round:** Round 2 – Technical + Managerial

**Asked:** 

---

### Q2: How did you handle schema drift in Azure Data Factory?

**Answer:**
- **Copy activity:** with no explicit mapping it maps columns by name; to tolerate new columns, either keep the mapping dynamic (parameterized mapping JSON from a metadata table) or land the files unchanged in the raw zone and handle schema later.
- **Mapping Data Flows:** enable **"Allow schema drift"** on source and sink, so unexpected columns flow through. Use **rule-based mapping** (e.g. map all columns matching a pattern) and `byName()` / derived columns for drifted fields; optionally **auto-map** in the sink.
- **Validate and alert:** compare the incoming header with the expected schema (Get Metadata `structure` vs a stored contract) and route breaking changes to a quarantine path.
- **Downstream:** with Delta, use `mergeSchema` for additive changes and keep bronze raw for replay.

**Follow-ups:**
- What's the difference between schema drift and a breaking schema change?
- How would you detect a new column before the load runs?

**Difficulty:** Medium


**Role:** Data Engineer

**Round:** L1

**Asked:** 

---

### Q3: How would you implement CDC from source tables to target tables?

**Answer:**
Pick the capture method based on what the source supports:
1. **Log-based CDC** (best): SQL Server CDC or change tracking, or Debezium for MySQL/PostgreSQL, reading inserts, updates and deletes with ordering information. In Azure, ADF has a **CDC resource** / native SQL CDC support, and Databricks can consume Debezium events from Event Hubs or Kafka.
2. **Watermark-based** (no CDC available): load rows where `last_modified > last watermark`, store the new watermark in a control table. This misses hard deletes.
3. **Snapshot diff** (no timestamps): compare full extracts with hashes to detect changes.

**Applying the changes:** land them in a staging or bronze table, deduplicate to the latest change per key, then `MERGE` into the target (update, insert, and delete for `op = 'D'`), or SCD2 if history is needed. Make every step **idempotent** and reconcile counts.

**Follow-ups:**
- How do you capture hard deletes without log-based CDC?
- What ordering field would you use to apply changes correctly?

**Difficulty:** Medium


**Role:** Data Engineer

**Round:** L1

**Asked:** 

---

### Q4: What's the difference between the Azure Integration Runtime and a Self-hosted Integration Runtime?

**Answer:**
The **Integration Runtime (IR)** is the compute ADF uses to move and transform data.

| | Azure IR | Self-hosted IR |
|---|---|---|
| Runs on | Microsoft-managed compute in Azure | Your own VM or on-premises machine (installed agent) |
| Reaches | Public endpoints and Azure services (or private ones through a managed VNet) | **On-premises or private-network** sources (SQL Server on-prem, file shares) |
| Management | Fully managed, auto-scaled | You install, patch, scale (multiple nodes for HA) |
| Data flows | Runs Mapping Data Flows | Copy activity and dispatch only |

A third type, the **Azure-SSIS IR**, runs SSIS packages. Use a Self-hosted IR when the source is behind a firewall or on-prem; install at least two nodes for high availability.

**Follow-ups:**
- How do you make a Self-hosted IR highly available?
- When would you use a managed virtual network IR instead?

**Difficulty:** Easy


**Role:** Data Engineer (3+ years)

**Round:** 

**Asked:** 

---

### Q5: Runs of an ADF pipeline sit in the Queued state and don't start. What do you check?

**Answer:**
1. **Integration Runtime capacity:** the Self-hosted IR is offline or overloaded (CPU or memory, concurrent job limit reached), or the Azure IR region has limits. Check IR monitoring and node status.
2. **Concurrency limits:** pipeline `concurrency` setting, activity limits, or a **ForEach with high parallelism** saturating resources, so new runs wait in the queue. A Tumbling Window trigger also waits for dependencies.
3. **Source or sink waits:** a long-running upstream run holding locks, or a throttled database.

Also check for platform incidents (Azure Service Health) and whether a data flow cluster is still spinning up (TTL settings).

**Follow-ups:**
- How does the pipeline concurrency setting cause queuing?
- How would you scale a Self-hosted IR?

**Difficulty:** Medium


**Role:** Data Engineer (3+ years)

**Round:** 

**Asked:** 

---

### Q6: Where and how should a production data pipeline keep its secrets?

**Answer:**
- **Store secrets in a vault:** **Azure Key Vault** (or GCP Secret Manager / AWS Secrets Manager), never in code, notebooks, pipeline JSON or Git.
- **Avoid secrets entirely where possible:** use **managed identities** (ADF, Databricks Unity Catalog storage credentials, Azure Functions) or workload identity, so there's no password to store.
- **Reference, don't copy:** ADF linked services reference Key Vault secrets; Databricks uses **Key Vault-backed secret scopes** (`dbutils.secrets.get`), whose values are redacted in notebook output; CI/CD pulls from variable groups linked to Key Vault.
- **Least privilege and rotation:** RBAC on Key Vault (get/list only for the pipeline identity), separate vaults per environment, and automatic rotation with expiry alerts.
- **Audit:** Key Vault diagnostic logs, plus secret-scanning in repositories.

**Follow-ups:**
- Why is a managed identity better than a stored service-principal secret?
- How do you rotate a database password without downtime?

**Difficulty:** Easy


**Role:** Data Engineer (3+ years)

**Round:** 

**Asked:** 

## HCLTech

### Q7: A job has to run every night at 2 AM. How do you schedule it?

**Answer:**
Use the orchestrator's scheduler with an explicit **time zone**:
- **ADF:** a **Schedule trigger** (daily at 02:00 in the right time zone), or a **Tumbling Window trigger** if each run must process a specific window with backfill and dependency support.
- **Databricks:** a job schedule with the cron expression `0 0 2 * * ?` (Quartz syntax) and time zone.
- **Airflow:** `schedule="0 2 * * *"` with a timezone-aware `start_date`. Remember that the run for a day's interval starts at the end of that interval.

Also add: retries and timeouts, an alert on failure or SLA miss, and idempotent logic so a delayed or rerun job doesn't double-process. Watch for daylight-saving changes when using local time.

**Follow-ups:**
- What's the difference between a Schedule trigger and a Tumbling Window trigger in ADF?
- How do daylight-saving changes affect a 2 AM schedule?

**Difficulty:** Easy


**Role:** Lead Data Engineer

**Round:** Round 1 – Technical

**Asked:** 

## Persistent Systems

### Q8: How would you design a cost-efficient Azure pipeline using ADF, Databricks and ADLS?

**Answer:**
- **Storage (ADLS Gen2):** Delta and Parquet with compression, **lifecycle management** to move old raw data to cool or archive tiers, and no unnecessary copies.
- **Orchestration (ADF):** use ADF for copying and orchestration only; keep data integration units (DIUs) and parallelism sized to the data; avoid Mapping Data Flows for heavy transforms when Databricks already runs; use event or tumbling triggers instead of frequent polling.
- **Compute (Databricks):** **job clusters or serverless** (not all-purpose), autoscaling with a sensible maximum, **spot instances** for workers, Photon where it pays off, auto-termination, and **cluster policies** to cap sizes.
- **Process less data:** incremental loads (Auto Loader, watermarks, CDC) instead of full reloads; partition pruning and file compaction (`OPTIMIZE`).
- **Governance:** tags per project, **budgets and cost alerts**, reserved capacity (Databricks commit, reserved storage) for steady workloads, and regular reviews of the most expensive jobs.

**Follow-ups:**
- Where does most of the cost usually come from in this stack?
- How do you attribute cost to individual pipelines?

**Difficulty:** Medium


**Role:** Data Engineer

**Round:** Round 1 – Technical

**Asked:** 

## Wipro

### Q9: With ADF, how would you pull one folder or file out of a GitHub repository into ADLS Gen2?

**Answer:**
GitHub content is served over HTTPS, so use the **HTTP or REST connector**:
1. **Linked service:** HTTP (anonymous for public repos, or a personal access token or GitHub App token stored in **Key Vault** for private ones) pointing to `https://raw.githubusercontent.com/` for single files, or the **GitHub REST API** (`/repos/{owner}/{repo}/contents/{path}`) to list a folder.
2. **For a folder:** a **Web activity** or REST dataset calls the contents API, which returns the file list; a **ForEach** loops over the items and a **Copy activity** downloads each `download_url` into ADLS (binary dataset, preserving names).
3. **For a single file:** one Copy activity from the HTTP dataset (relative URL parameterized with owner, repo, branch and path) to an ADLS sink.
4. **Parameterize** the repo, branch, path and target folder; add retries for API rate limits (HTTP 403/429).

(For large repos, cloning with an Azure Function or a DevOps pipeline and pushing to ADLS can be simpler.)

**Follow-ups:**
- How do you handle GitHub API rate limits?
- How would you copy only files that changed since the last run?

**Difficulty:** Hard


**Role:** Azure Data Engineer (5+ years)

**Round:** Round 1 – Technical

**Asked:** 

---

### Q10: How would you change that pipeline so it only processes `.csv` files modified in the last 30 days in an ADLS Gen2 folder?

**Answer:**
Filter by **last modified time** at the source:
- **Copy activity:** on the ADLS source, set the wildcard file name `*.csv` and **Filter by last modified** with
  - start: `@addDays(utcNow(), -30)`
  - end: `@utcNow()`
- **More control:** use **Get Metadata** (`childItems`) → **Filter** activity on `endsWith(item().name, '.csv')` → **ForEach** with a Get Metadata on each file to read `lastModified` → If Condition → Copy. That's slower, but lets you log each file.
- **Incremental pattern:** instead of a fixed 30 days, store the last successful run time in a control table and use it as the start time on each run, so files aren't reprocessed. Or use a **storage event trigger** to process files as they arrive.

**Follow-ups:**
- Why is a stored watermark better than a fixed 30-day window?
- What are the limits of Get Metadata on very large folders?

**Difficulty:** Medium


**Role:** Azure Data Engineer (5+ years)

**Round:** Round 1 – Technical

**Asked:** 

---

### Q11: Describe real-world ADF pipeline use cases. When would you use the different activities and connectors?

**Answer:**
| Activity | Use it for |
|---|---|
| **Copy** | Moving data between 100+ connectors (on-prem SQL → ADLS, REST API → Blob, ADLS → Synapse) |
| **Lookup** | Reading a small control or config table (watermarks, list of tables) |
| **Get Metadata** | Listing files, checking existence, reading size or last-modified time |
| **ForEach / Until / If / Switch** | Looping over tables or files; conditional branching |
| **Execute Pipeline** | Calling child pipelines (modular, metadata-driven designs) |
| **Stored Procedure / Script** | Running SQL in the target (merge, logging, watermark update) |
| **Databricks Notebook / Job, Synapse Notebook** | Heavy transformations in Spark |
| **Mapping Data Flow** | Visual, Spark-based transformations without code |
| **Web / Azure Function** | Calling APIs, sending notifications, custom logic |
| **Wait / Validation** | Waiting for files or a delay |

**Typical end-to-end use case:** a metadata-driven ingestion where Lookup reads the table list, ForEach runs a parameterized Copy from on-prem SQL (through a Self-hosted IR) to ADLS bronze, then a Databricks job builds silver and gold, a Stored Procedure updates the watermarks, and a Web activity posts success or failure to Teams or email.

**Follow-ups:**
- When would you choose a Mapping Data Flow over a Databricks notebook?
- How do you pass outputs from one activity to the next?

**Difficulty:** Medium


**Role:** Azure Data Engineer (5+ years)

**Round:** Round 2 – Technical

**Asked:** 

---

### Q12: How does ADLS Gen2 differ from plain Azure Blob Storage?

**Answer:**
ADLS Gen2 **is** Blob Storage with the **hierarchical namespace (HNS)** enabled, which adds:

| | Blob Storage (flat) | ADLS Gen2 (hierarchical namespace) |
|---|---|---|
| Namespace | Flat; "folders" are just name prefixes | Real directories |
| Rename / move a folder | Copy and delete every object (slow, not atomic) | **Atomic** metadata operation |
| Security | Container-level RBAC, SAS | RBAC **plus POSIX-style ACLs** on folders and files |
| Analytics | Works, but slower for big data engines | Optimized for Spark, Synapse, Databricks (`abfss://` driver) |
| Use for | General object storage, media, backups, static content | **Data lakes** and analytics workloads |

Both share tiers (hot, cool, cold, archive), redundancy options and lifecycle management. For a data lake, enable HNS when you create the account.

**Follow-ups:**
- Why do atomic directory renames matter for Spark jobs?
- How do ACLs and RBAC combine in ADLS Gen2?

**Difficulty:** Easy


**Role:** Azure Data Engineer (5+ years)

**Round:** Round 2 – Technical

**Asked:** 
