# Azure Monitoring, Governance & Security — Interview Question Bank

> Format: Question · Answer · Follow-ups · Difficulty

---

### Q1: What is KQL, and how would you use it for pipeline monitoring?

**Answer:**
**KQL (Kusto Query Language)** is the read-only query language used by Log Analytics, Azure Data Explorer, Microsoft Sentinel and Fabric Real-Time Intelligence. Queries pipe a table through operators:

```kusto
ADFActivityRun
| where TimeGenerated > ago(24h) and Status == "Failed"
| summarize failures = count() by PipelineName, ActivityName, bin(TimeGenerated, 1h)
| order by failures desc
```

Common operators: `where`, `project`, `summarize ... by`, `extend`, `join`, `render timechart`. Use it to find failing pipelines, slow activities (`DurationMs`), trends over time, and as the query behind **log alerts** and workbook charts.

**Follow-ups:**
- How would you find the 10 slowest activities this week?
- How do you turn a KQL query into an alert?

**Difficulty:** Easy

---

### Q2: What is Application Insights, and is it useful for data pipelines?

**Answer:**
Application Insights is Azure Monitor's **application performance monitoring (APM)** feature: it collects requests, dependencies (calls to databases and APIs), exceptions, traces, custom events and metrics from applications, with distributed tracing and an application map. Data lands in a Log Analytics workspace.

For data engineering it's useful in the **code-based parts** of a pipeline: Azure Functions, custom APIs, or Python and Spark jobs instrumented with OpenTelemetry. There you can track custom metrics (rows processed, latency) and exceptions, and correlate a failure across services. ADF itself is monitored through Azure Monitor diagnostics rather than Application Insights.

**Follow-ups:**
- How would you send custom metrics from a Python job?
- What is distributed tracing?

**Difficulty:** Easy

---

### Q3: What is a diagnostic setting in Azure?

**Answer:**
A diagnostic setting tells an Azure resource **which logs and metrics to export, and where**:
- **Destinations:** a **Log Analytics workspace** (query and alert), a **storage account** (cheap long-term archive), **Event Hubs** (stream to a SIEM or other tools), or partner solutions.
- **Categories:** e.g. for ADF, `PipelineRuns`, `ActivityRuns`, `TriggerRuns`; for storage, read, write and delete logs; for Key Vault, audit events.

Without diagnostic settings, many resource logs aren't kept at all. Best practice: enable them through **Azure Policy** (deployIfNotExists) so every new resource sends logs to the central workspace automatically, using resource-specific tables.

**Follow-ups:**
- Why use Azure Policy to configure diagnostic settings?
- When would you send logs to Event Hubs instead of Log Analytics?

**Difficulty:** Easy

---

### Q4: What does Azure Service Health tell you, and why should data teams use it?

**Answer:**
Azure Service Health tells you about **Azure platform issues that affect your resources**:
- **Service issues:** current outages or degradations in your regions and services.
- **Planned maintenance:** upcoming work that may affect availability.
- **Health advisories and security advisories:** deprecations, required actions.
- **Resource Health:** the health of an individual resource (e.g. "your SQL database is unavailable due to a platform issue").

Set up **Service Health alerts** (with action groups) for the regions and services your pipelines depend on. During an incident, it tells you whether a failure is your code or Azure, which saves debugging time and supports RCA.

**Follow-ups:**
- How would you check whether a pipeline failure was caused by an Azure outage?
- What's the difference between Service Health and Resource Health?

**Difficulty:** Easy

---

### Q5: What is Azure Monitor, and how does it relate to Log Analytics?

**Answer:**
**Azure Monitor** is the umbrella monitoring platform. It collects two kinds of data:
- **Metrics:** numeric time series (CPU, failed pipeline runs, throughput), lightweight and near real time, kept for 93 days.
- **Logs:** detailed records (activity runs, resource logs, application traces), stored in a **Log Analytics workspace** and queried with **KQL**.

**Log Analytics** is the part of Azure Monitor that stores and queries logs. Diagnostic settings route each resource's logs (ADF, Databricks, Synapse, storage) into a workspace. On top sit **alerts** (metric and log), **action groups**, **workbooks and dashboards**, and **Application Insights** for application telemetry.

So: Azure Monitor is the service; Log Analytics workspaces hold the log data that Azure Monitor queries and alerts on.

**Follow-ups:**
- What do you send to Log Analytics from a data platform?
- How long are metrics and logs retained?

**Difficulty:** Easy

---

### Q6: What's the difference between the Activity Log and resource logs?

**Answer:**
| | Activity Log | Resource logs |
|---|---|---|
| Records | **Control-plane** operations on resources: who created, changed, deleted or restarted what, and when (subscription level) | **Data-plane** activity inside a resource: pipeline runs, queries, storage reads and writes, Key Vault secret access |
| Collected | Automatically, retained 90 days | Only when you configure a **diagnostic setting** |
| Example | "User X deleted the linked service" | "Activity Copy_orders failed with error …" |

Send both to Log Analytics: the Activity Log for auditing changes, and resource logs for operational monitoring and troubleshooting.

**Follow-ups:**
- Where would you look to find who deleted a storage container?
- How long is the Activity Log kept by default?

**Difficulty:** Easy

---

### Q7: How would you monitor jobs running in Azure Databricks?

**Answer:**
- **Jobs UI:** run history, task durations, failures, repair runs; **job notifications** (email, Teams, webhooks) on failure, success or duration thresholds.
- **Spark UI and logs:** driver and executor logs, stages, spills, and the Structured Streaming tab (input rate, processing time, batch duration).
- **System tables** (Unity Catalog): `system.lakeflow.job_run_timeline`, billing usage and audit tables, queried with SQL for dashboards (failures, duration trends, cost per job).
- **Azure integration:** diagnostic logs to Log Analytics; cluster metrics; alerts through Azure Monitor.
- **Data quality monitoring:** Lakehouse Monitoring or expectations in Lakeflow Declarative Pipelines.

Alert on failures, on runtime well above normal, and on streaming lag.

**Follow-ups:**
- How would you build a dashboard of job cost per team?
- What would you watch for in a streaming job?

**Difficulty:** Medium

---

### Q8: Metric alerts vs log alerts in Azure Monitor: what's the difference?

**Answer:**
| | Metric alert | Log (search) alert |
|---|---|---|
| Based on | Numeric **platform metrics** (e.g. `PipelineFailedRuns`, CPU) | A **KQL query** over Log Analytics data |
| Latency | Near real time (about a minute) | Runs on a schedule (e.g. every 5–15 minutes) |
| Flexibility | Thresholds and dynamic thresholds on one metric (with dimensions) | Any logic: joins, text matching, custom conditions |
| Cost | Cheaper | Per query evaluation |

Both trigger **action groups** (email, SMS, webhooks, Logic Apps, ITSM). Use metric alerts for simple, fast signals (any pipeline failure), and log alerts for richer conditions (the same pipeline failed 3 times in an hour, or an error message contains "throttled").

**Follow-ups:**
- What are dynamic thresholds?
- What is an action group?

**Difficulty:** Easy

---

### Q9: What's the difference between an SLA, an SLO and an SLI?

**Answer:**
- **SLI (Service Level Indicator):** the **measured** value, e.g. "percentage of days the sales table was ready by 6 AM", or "p95 end-to-end latency".
- **SLO (Service Level Objective):** the internal **target** for an SLI, e.g. "ready by 6 AM on 99% of days".
- **SLA (Service Level Agreement):** an external **commitment** with consequences if missed (credits, penalties), usually looser than the SLO, e.g. Azure's 99.9% availability for a service, or a contract with the business.

For data platforms, define SLIs for **freshness, completeness, correctness and latency**, set SLOs per critical dataset, and alert before the SLO is breached.

**Follow-ups:**
- What SLIs would you define for a daily reporting pipeline?
- Why should an SLO be stricter than the SLA?

**Difficulty:** Easy

---

### Q10: What does Azure Advisor do?

**Answer:**
Azure Advisor is a free service that analyzes your resources and gives **personalized recommendations** in five categories: **cost** (idle or oversized resources, reservation purchase suggestions), **security** (from Defender for Cloud), **reliability** (redundancy, backups), **operational excellence**, and **performance**.

For a data platform: it suggests resizing underused VMs and SQL databases, buying reservations for steady workloads, and enabling soft delete or geo-redundancy. Review it regularly (or set up Advisor alerts and digests), and treat the recommendations as input, not automatic actions.

**Follow-ups:**
- What kinds of cost recommendations does Advisor give?
- How would you track whether recommendations are acted on?

**Difficulty:** Easy

---

### Q11: What is Microsoft Purview, and what does it do for data governance?

**Answer:**
Microsoft Purview is Microsoft's **data governance, risk and compliance** platform. For data engineering, the key parts are:
- **Data Map and catalog:** automated **scanning** of sources (ADLS, SQL, Synapse, Databricks/Unity Catalog, Power BI, on-prem) to discover assets and schemas.
- **Classification and sensitivity labels:** automatic detection of PII and sensitive data (built-in and custom classifiers).
- **Lineage:** from ADF, Synapse and other pipelines through to Power BI reports.
- **Business glossary and data products** (Unified Catalog): ownership, definitions, data quality.
- **Access policies** and integration with Information Protection and DLP.

It answers "what data do we have, where is the sensitive data, who owns it, and where does it come from?"

**Follow-ups:**
- How does Purview get lineage from ADF?
- How would you find every column containing email addresses?

**Difficulty:** Medium

---

### Q12: Azure Policy vs Azure RBAC: what's the difference?

**Answer:**
| | Azure RBAC | Azure Policy |
|---|---|---|
| Controls | **Who** can do **what** on which scope (users, groups, managed identities) | **What resources and settings are allowed**, whoever creates them |
| Example | "The data engineering group is Contributor on rg-data-dev" | "Storage accounts must disable public access", "only West Europe", "tags required" |
| Effect | Allow (role assignments; deny assignments are rare) | Deny, Audit, Modify, DeployIfNotExists, Append |

They work together: RBAC decides whether a user may create a storage account; Policy decides whether **that** storage account's configuration is compliant. Group policies into **initiatives** and assign them at management-group or subscription level.

**Follow-ups:**
- How would you enforce encryption and private endpoints on every storage account?
- What does the DeployIfNotExists effect do?

**Difficulty:** Medium

---

### Q13: What are Azure Reservations and Savings Plans, and how do they differ?

**Answer:**
Both trade a **1- or 3-year commitment** for lower prices than pay-as-you-go:
- **Reservations:** commit to a **specific resource type** (VM family and region, SQL Database vCores, Synapse DWUs, Databricks DBCU pre-purchase, storage capacity). The biggest discounts (up to about 72%), but less flexibility.
- **Savings Plan for compute:** commit to a **fixed hourly spend** on compute (VMs, App Service, Functions Premium, containers) across regions and families. Slightly smaller discounts, much more flexible.

Use reservations for stable, predictable resources (an always-on dedicated SQL pool, baseline VMs); a savings plan when the compute mix changes over time; and pay-as-you-go or spot for spiky or batch workloads.

**Follow-ups:**
- How would you decide how much to reserve?
- What happens to unused reservation hours?

**Difficulty:** Medium

---

### Q14: What are resource quotas and limits in Azure, and why do they matter for data workloads?

**Answer:**
Every subscription has **quotas** (soft limits you can raise through a support request) and **hard limits** per service and region: e.g. total vCPUs per VM family, public IPs, storage accounts per region, Event Hubs throughput units, Databricks cluster cores.

They matter because a pipeline can fail or stall when, for example, a Databricks autoscale or ADF Data Flow cluster needs more cores than the family quota allows ("quota exceeded"). Good practice: check quotas when planning capacity, raise them **before** big launches or migrations, monitor usage in the portal (Usage + quotas), and spread very large workloads across VM families or regions where appropriate.

**Follow-ups:**
- How would you diagnose a Databricks cluster stuck because of quota?
- What's the difference between a quota and a hard limit?

**Difficulty:** Easy

---

### Q15: What is Microsoft Purview Compliance Manager?

**Answer:**
Compliance Manager (part of Microsoft Purview) helps organizations **measure and manage compliance** with regulations and standards (GDPR, ISO 27001, HIPAA, SOC 2, and others):
- **Assessments** based on regulatory templates, mapped to controls.
- A **compliance score** showing progress.
- **Improvement actions** with guidance; some are tested automatically, others are assigned to owners with evidence.
- A clear split between controls Microsoft manages and controls the customer owns (shared responsibility).

For data teams it's the place where requirements like encryption, retention, access reviews and data classification are tracked as auditable controls.

**Follow-ups:**
- Which controls would a data platform team typically own?
- How does Compliance Manager relate to Azure Policy?

**Difficulty:** Easy

---

### Q16: What is data lineage, and why is it important?

**Answer:**
Data lineage shows **where data comes from, how it's transformed, and where it goes**: source tables → pipelines and jobs → intermediate tables → reports and models, ideally down to column level.

Why it matters:
- **Impact analysis:** before changing a column, see every downstream table and dashboard affected.
- **Root-cause analysis:** trace a wrong number back to the transformation or source that caused it.
- **Compliance:** prove where PII flows (GDPR, audits).
- **Trust and discovery:** users understand what a dataset is built from.

Tools capture it automatically from execution: **Unity Catalog** (Databricks), **Microsoft Purview** (ADF, Synapse, Power BI), Dataplex (GCP), dbt docs, and OpenLineage.

**Follow-ups:**
- What's the difference between table-level and column-level lineage?
- How would lineage help during a production incident?

**Difficulty:** Easy

---

### Q17: How do you implement data governance on Azure?

**Answer:**
Combine **people and process** with the platform features:
- **Ownership:** data owners and stewards per domain, and a business glossary with agreed definitions.
- **Catalog and classification:** Microsoft Purview scans sources, classifies sensitive data and shows lineage; Unity Catalog governs the Databricks lakehouse.
- **Access control:** Entra ID groups, RBAC and ADLS ACLs, Unity Catalog grants, row filters and column masks, and least privilege with access reviews.
- **Data protection:** encryption (customer-managed keys if required), masking, private endpoints, Key Vault.
- **Quality:** data quality rules and monitoring between layers, with owners alerted.
- **Policy and compliance:** Azure Policy guardrails, retention policies, audit logs, Compliance Manager.
- **Lifecycle:** retention and deletion processes (e.g. GDPR erasure).

Start with the most critical or sensitive data domains instead of trying to govern everything at once.

**Follow-ups:**
- Who should own data quality: the platform team or the domain teams?
- How would you implement GDPR deletion in a lakehouse?

**Difficulty:** Medium

---

### Q18: What is data masking, and how is it done in Azure data services?

**Answer:**
Data masking hides sensitive values from users who don't need to see them, while keeping data usable:
- **Dynamic data masking** (Azure SQL, Synapse): masking rules on columns (`email()`, `partial()`, `default()`) change query results for non-privileged users; the stored data is unchanged:
  ```sql
  ALTER TABLE dbo.customers ALTER COLUMN email ADD MASKED WITH (FUNCTION = 'email()');
  GRANT UNMASK TO pii_readers;
  ```
- **Databricks Unity Catalog column masks:** a SQL function applied to the column, returning the real or masked value depending on group membership.
- **Static masking or tokenization:** permanently replace values in copies (non-production environments) with masked or tokenized data.

Dynamic masking is a convenience layer, not encryption: combine it with access control, and don't rely on it against determined users with ad-hoc query access.

**Follow-ups:**
- Why isn't dynamic data masking a replacement for access control?
- How would you provide realistic but safe data to a test environment?

**Difficulty:** Medium

---

### Q19: How is data encrypted in Azure, at rest and in transit?

**Answer:**
- **At rest:** Azure Storage, SQL, Synapse, Databricks and the rest encrypt data by default with **platform-managed keys** (AES-256). For more control use **customer-managed keys (CMK)** in **Key Vault** or Managed HSM: you control rotation and revocation. Some services add **double encryption** (infrastructure encryption). Azure SQL has **TDE** (Transparent Data Encryption).
- **In transit:** TLS 1.2+ for all service endpoints (enforce a minimum TLS version and "secure transfer required" on storage); private endpoints keep traffic on the Microsoft backbone.
- **In use and application level:** Always Encrypted (SQL) for highly sensitive columns, and confidential computing.

Key management is the critical part: least-privilege access to Key Vault, soft delete and purge protection, rotation, and audit logs.

**Follow-ups:**
- What happens to your data if a customer-managed key is deleted?
- What's the difference between TDE and Always Encrypted?

**Difficulty:** Medium
