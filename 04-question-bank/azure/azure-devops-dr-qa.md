# Azure DevOps & Disaster Recovery — Interview Question Bank

> Format: Question · Answer · Follow-ups · Difficulty

---

### Q1: What is Azure DevOps, and which of its services matter for data teams?

**Answer:**
Azure DevOps is Microsoft's suite of development services:
- **Azure Repos:** Git repositories with pull requests and branch policies.
- **Azure Pipelines:** CI/CD for building, testing and deploying (YAML or classic), with agents (Microsoft-hosted or self-hosted).
- **Azure Boards:** work items, backlogs, sprints.
- **Azure Artifacts:** package feeds (Python wheels, npm).
- **Azure Test Plans:** manual and exploratory testing.

For data teams: Repos hold ADF JSON, Databricks code and bundles, SQL and Terraform/Bicep; Pipelines run tests and deploy ADF ARM templates, Databricks Asset Bundles and database changes to dev → test → prod, with **environments and approvals**; Artifacts host shared Python libraries.

**Follow-ups:**
- How does Azure DevOps compare with GitHub plus GitHub Actions?
- What are branch policies?

**Difficulty:** Easy

---

### Q2: How is continuous delivery different from continuous deployment?

**Answer:**
Both build on **continuous integration** (every change is built and tested automatically):
- **Continuous delivery:** every change that passes the pipeline is **ready to release**, and is deployed automatically to test or staging, but **production deployment needs a manual approval**.
- **Continuous deployment:** every change that passes all checks goes **to production automatically**, with no human gate.

Data platforms usually practice continuous delivery (an approval gate before prod, because data changes and backfills can be costly to undo), and move towards continuous deployment for low-risk components with strong automated tests and easy rollback.

**Follow-ups:**
- What automated checks would you need before allowing continuous deployment of pipelines?
- How do feature flags help?

**Difficulty:** Easy

---

### Q3: How do YAML pipelines, build (CI) stages and release (CD) stages fit together in Azure DevOps?

**Answer:**
- **YAML pipelines** define CI/CD **as code** in the repository (`azure-pipelines.yml`), versioned and reviewed like other code. They're the recommended replacement for "classic" UI-built build and release pipelines.
- **Build / CI stage:** triggered by a pull request or commit; lint, unit tests, validate (e.g. ADF ARM template generation, `databricks bundle validate`, `terraform plan`), and **publish artifacts**.
- **Release / CD stages:** deploy the same artifact to **environments** (dev → test → prod). Environments carry **approvals and checks** (manual approval, business hours, required gates), and deployment history.

```yaml
stages:
- stage: Build
  jobs: [{ job: test, steps: [{ script: pytest }] }]
- stage: DeployProd
  dependsOn: Build
  jobs:
  - deployment: prod
    environment: data-prod        # approvals configured on this environment
    strategy: { runOnce: { deploy: { steps: [{ script: databricks bundle deploy -t prod }] } } }
```

**Follow-ups:**
- Why deploy the same build artifact to every environment?
- How do you add a manual approval before prod?

**Difficulty:** Medium

---

### Q4: What is a variable group in Azure DevOps?

**Answer:**
A variable group is a **shared, named set of variables** that several pipelines can use (e.g. `data-platform-prod` with workspace URLs, resource group names, environment settings).
- Mark sensitive values as **secret**, or **link the group to Azure Key Vault**, so secrets are fetched at runtime and never stored in the pipeline.
- Scope groups per environment and control who can use and edit them (pipeline permissions, approvals).

```yaml
variables:
- group: data-platform-prod
steps:
- script: echo "Deploying to $(workspace_url)"
```

**Follow-ups:**
- Why link a variable group to Key Vault instead of storing secrets in it?
- How do you avoid printing secrets in logs?

**Difficulty:** Easy

---

### Q5: Terraform vs ARM templates vs Bicep: how do they compare?

**Answer:**
| | ARM templates | Bicep | Terraform |
|---|---|---|---|
| Syntax | Verbose JSON | Concise DSL that **compiles to ARM** | HCL |
| Cloud support | Azure only | Azure only | **Multi-cloud** plus SaaS providers (Databricks, GitHub, …) |
| State | No state file (Azure is the source of truth) | No state file | **State file** (remote backend needed) |
| New Azure features | Day zero | Day zero | Via the AzureRM / AzAPI providers (sometimes later) |
| Preview | What-if | What-if | `plan` |

Choose **Bicep** for Azure-only teams that want first-party tooling and no state management; **Terraform** when you manage several clouds or non-Azure resources (Databricks workspaces and jobs, GitHub) with one tool. Avoid hand-writing raw ARM JSON for new work.

**Follow-ups:**
- What are the pros and cons of not having a state file?
- How would you manage Databricks resources with IaC?

**Difficulty:** Medium

---

### Q6: What are App Service deployment slots used for?

**Answer:**
A deployment slot is a **live, separate copy of an App Service app** (e.g. `staging`) with its own hostname. You deploy a new version to the staging slot, warm it up and test it, then **swap** it with production: the swap redirects traffic with near-zero downtime, and swapping back is an instant **rollback**.

Settings can be **slot-specific** ("sticky", e.g. connection strings per environment) or swap with the code. In data platforms this applies to APIs or web apps that serve data, and Azure Functions on Premium or Dedicated plans also support slots, for example for ingestion functions.

**Follow-ups:**
- What's a slot-sticky setting?
- How does slot swapping support blue-green deployment?

**Difficulty:** Easy

---

### Q7: How do you roll back a bad deployment in a CI/CD pipeline?

**Answer:**
- **Redeploy the last known-good artifact:** since every release is a versioned artifact (ARM template, bundle, wheel, image), roll back by deploying the previous version through the same pipeline. Avoid manual fixes in production.
- **Revert in Git** (a revert commit) and let CI/CD deploy it, which keeps history clean and auditable.
- **Swap back** for App Service slots or blue-green setups.
- **Data-specific rollback:** code rollback doesn't undo data changes. Use Delta `RESTORE` or BigQuery time travel for bad writes, keep backfills idempotent, and use expand-then-contract schema migrations so old code still works with the new schema.

Prepare for it: automated smoke tests after deploy, deployment history per environment, and a documented rollback runbook.

**Follow-ups:**
- Why doesn't rolling back code fix data written by the bad version?
- What is an expand-and-contract migration?

**Difficulty:** Medium

---

### Q8: What's the difference between failover and failback?

**Answer:**
- **Failover:** switching workloads from the primary site or region to the **secondary** when the primary fails (or for a planned test). It can be automatic (e.g. SQL auto-failover groups) or manual (e.g. storage account customer-initiated failover).
- **Failback:** returning workloads to the **original primary** once it's healthy again, after re-synchronizing data changed during the outage.

Both need planning: DNS or connection string switching, replication direction, data loss within the RPO, and regular **DR drills** so the steps are tested, not theoretical.

**Follow-ups:**
- Why is failback often harder than failover?
- How do you test a failover without affecting production?

**Difficulty:** Easy

---

### Q9: Backup vs replication: what's the difference, and do you need both?

**Answer:**
| | Backup | Replication |
|---|---|---|
| What | **Point-in-time copies** kept for a retention period (Azure Backup, SQL automated backups, snapshots) | A **continuously synchronized copy** in another zone or region (geo-redundant storage, geo-replication, failover groups) |
| Protects against | Deletion, corruption, ransomware, bad deployments: you can go back in time | Infrastructure or regional outages: fast failover |
| Recovery speed | Slower (restore) | Fast (fail over) |
| Weakness | RPO = time since last backup | **Corruption and deletes replicate too** |

You need **both**: replication for availability, backups (with soft delete, immutability, retention, ideally stored in a separate vault) for recovery from logical errors. Recovery Services vaults and Backup vaults manage backups in Azure.

**Follow-ups:**
- Why doesn't geo-redundant storage protect against an accidental delete?
- What are immutable backups?

**Difficulty:** Medium

---

### Q10: Active-active vs active-passive architecture: what's the difference?

**Answer:**
- **Active-active:** two or more regions **serve traffic at the same time**, with load balancing (Front Door, Traffic Manager). Near-zero downtime when one fails and better performance for distributed users, but the most complex (data consistency, conflict handling, double cost).
- **Active-passive:** one region serves traffic; the secondary is on **standby** (hot, warm or cold) and takes over on failover. Simpler and cheaper, but with some downtime (RTO) and potential data loss (RPO).

For most data platforms, **active-passive** is enough: replicated storage, IaC to recreate compute, a tested failover runbook. Active-active is reserved for customer-facing, always-on serving layers.

**Follow-ups:**
- What makes active-active hard for databases?
- What's the difference between hot, warm and cold standby?

**Difficulty:** Medium

---

### Q11: What would a disaster recovery plan for an Azure data platform look like?

**Answer:**
1. **Set targets:** **RTO and RPO** per data product (e.g. finance reporting RTO 4 h, RPO 1 h; sandbox best effort).
2. **Storage:** ADLS on **GRS/RA-GRS** (or replicate to a paired region), soft delete and versioning, Delta tables (time travel, but geo-replicate the underlying storage too).
3. **Compute and pipelines as code:** ADF, Databricks (bundles, jobs), Synapse and networking all defined in Git and IaC (Terraform or Bicep), so you can **redeploy** in the secondary region quickly; the secondary workspace is pre-provisioned or deployable.
4. **Databases:** auto-failover groups or geo-replication (Azure SQL), geo-backups for Synapse.
5. **Secrets and identity:** Key Vault replicated or recreated, managed identities in both regions.
6. **Metadata:** Unity Catalog / Hive metastore and control tables replicated or rebuildable.
7. **Runbook and drills:** step-by-step failover and failback, DNS and connection switching, and regular tests.
8. **Rebuildability:** keep raw data, so curated layers can be recomputed.

**Follow-ups:**
- How would you decide RTO and RPO with the business?
- Halfway through a nightly load, the primary region goes down. What happens next?

**Difficulty:** Hard
