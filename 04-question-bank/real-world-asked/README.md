# Real-World Asked Questions

Questions that people were **actually asked** in data engineering interviews. The other `04-question-bank/` folders hold general preparation questions; this folder records what interviewers really ask.

## Layout

- **One file per skill**, e.g. `sql.md`, `gcp.md`, `python-pyspark.md`. A file is created only when it has at least one question. If a question doesn't fit an existing skill, add a new skill file.
- **One `##` section per company** inside each file. Use `## Unspecified company` when the company isn't known or can't be shared.
- **Each question uses this format** (leave a field blank when it's unknown):

```markdown
### Q<n>: <short title>

<question, in clean wording>

**Answer:**
<answer, with code if relevant; add a BigQuery version where SQL differs>

**Follow-ups:**
- <follow-up>

**Difficulty:** Easy | Medium | Hard

**Role:** <e.g. Data Engineer, Senior Data Engineer>

**Round:** <e.g. Online assessment, Technical 1, Managerial>

**Asked:** <Month YYYY>
```

## Current Files

| File | Skill |
|---|---|
| [sql.md](sql.md) | SQL |
| [gcp.md](gcp.md) | GCP |
| [python-pyspark.md](python-pyspark.md) | Python & PySpark |

## Contributor Rules

- **Only questions you were asked yourself.** Don't add questions you heard about second-hand or found in a list.
- **No copied posts.** Don't paste from LinkedIn posts, blogs, course material, LeetCode, DataLemur or other sites. Write the question and answer in your own words.
- **Nothing under NDA.** Skip any question, take-home task or detail you agreed to keep confidential.
- **No personal details:** no interviewer names, candidate names, emails or phone numbers.
- **No confidential details:** no internal project names, client names, real GCP project IDs, dataset names or hostnames. Replace real data with generic data.
- **Company names are optional.** Use `## Unspecified company` if you'd rather not say.
- **Remove duplicates:** if a question is already in the repo, improve the existing entry instead of adding a copy.
