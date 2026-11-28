# Real-World Asked: Behavioral & Managerial

Behavioral, managerial and HR questions reported from real interviews. Answers give a structure; fill them with your own real examples.

See [README.md](README.md) for the layout and contributor rules. Fields are left blank when unknown.

## Deloitte

### Q1: How do you work with clients to gather and confirm requirements?

**Answer:**
- **Prepare:** read existing documents and systems first, so meetings focus on gaps.
- **Ask about outcomes, not just tables:** what decision will this data support, who uses it, how fresh it must be, and what "correct" means (metric definitions).
- **Capture non-functional requirements:** volume, latency or SLA, retention, security and PII, cost limits.
- **Confirm in writing:** a short requirements document or user stories with acceptance criteria and examples (sample input and output), signed off by the client.
- **Iterate:** show a prototype or sample output early; manage changes through a backlog, with impact on timeline made explicit.
- **Communicate regularly:** status updates, risks raised early, and no surprises.

**Follow-ups:**
- How do you handle requirements that keep changing mid-sprint?
- How do you deal with conflicting requirements from two stakeholders?

**Difficulty:** Easy


**Role:** Azure Data Engineer

**Round:** Round 2 – Technical + Managerial

**Asked:** 

---

### Q2: What's the difference between being a team lead and an individual contributor?

**Answer:**
- **Individual contributor:** success is measured by **your own output**: designing and building pipelines, solving hard technical problems, code quality, and depth of expertise.
- **Team lead:** success is measured by **the team's output**: planning and breaking down work, unblocking people, code reviews and standards, mentoring, stakeholder communication, estimates, and risk management. You still contribute technically, but less hands-on time.

In an interview, show you understand both and give examples: "As an IC I designed the CDC pipeline; as an acting lead for the migration I split work across four engineers, ran reviews, and owned the client status calls." Then say honestly which you're aiming for and why.

**Follow-ups:**
- How do you balance hands-on work with leading?
- How do you handle an underperforming team member?

**Difficulty:** Easy


**Role:** Azure Data Engineer

**Round:** Round 2 – Technical + Managerial

**Asked:** 

---

### Q3: A client escalates an issue to you. How do you respond?

**Answer:**
1. **Acknowledge quickly and calmly:** confirm you understand the issue and its impact; don't argue in the moment.
2. **Contain:** restore service or provide a workaround first (rerun, backfill, a manual report).
3. **Communicate on a schedule:** who's working on it, the next update time, and an expected resolution. Over-communicate during the incident.
4. **Fix the root cause**, then share an RCA with a timeline, the cause, the fix and prevention steps.
5. **Rebuild trust:** follow up on the preventive actions and show they're done.

Give a short real example using STAR, ideally one where the escalation led to a lasting improvement (e.g. adding SLA monitoring).

**Follow-ups:**
- How do you respond when the escalation is caused by the client's own upstream data?
- When do you involve your manager?

**Difficulty:** Medium


**Role:** Azure Data Engineer

**Round:** Round 2 – Technical + Managerial

**Asked:** 

---

### Q4: What is your notice period, and what compensation do you expect?

**Answer:**
These are HR questions, but answer them clearly:
- **Notice period:** state it accurately (e.g. "60 days; buyout is possible" or "negotiable to 30 days"), and mention if you're already serving notice. Don't promise a date you can't meet.
- **Compensation:** research the market range for the role, level and location first. Give a **range** based on that and your current package, focused on total compensation, and stay open to discussing the overall offer (role, growth, benefits). It's fine to ask for their budgeted range first.

Be consistent: what you say here usually goes straight into the offer process.

**Follow-ups:**
- How would you respond if the offer is below your range?
- What matters to you besides salary?

**Difficulty:** Easy


**Role:** Azure Data Engineer

**Round:** Round 2 – Technical + Managerial

**Asked:** 

---

### Q5: Describe a typical working day in your current project.

**Answer:**
Describe a typical day concretely, in the order it happens:
- **Morning:** check overnight pipeline runs and data freshness dashboards, triage failures, and rerun or backfill if needed.
- **Stand-up:** progress, blockers, priorities.
- **Development:** building or changing pipelines (e.g. new source ingestion, SQL and PySpark transformations, DAGs), code reviews, and tests.
- **Collaboration:** clarifying requirements with analysts or the business, coordinating with source-system teams on schema changes.
- **Operations and improvement:** performance tuning, cost reviews, documentation and runbooks.

Mention the proportion (e.g. "about 60% development, 25% support, 15% design and meetings"), and give one recent example of each part.

**Follow-ups:**
- What did you deliver in your last sprint?
- How much of your time goes to production support?

**Difficulty:** Easy


**Role:** Data Engineer

**Round:** L1

**Asked:** 

---

### Q6: What issues do you face day to day in your project, and how do you deal with them?

**Answer:**
Pick 2–3 recurring, realistic issues and show how you **reduced** them, not just fixed them:
- **Late or missing source files** → sensors with timeouts, SLA alerts, and agreed delivery times with the source team.
- **Schema changes without notice** → schema validation before load, quarantine of bad records, and a contract with the source.
- **Data quality problems** (duplicates, NULL keys) → automated checks between layers, with alerts.
- **Performance regressions as data grows** → monitoring of runtime and bytes processed, then partitioning, clustering or job tuning.
- **Unclear requirements** → written acceptance criteria and sample outputs.

End with impact: "failures needing manual work dropped from several a week to about one a month."

**Follow-ups:**
- Which issue took the most of your time, and why?
- How do you prevent the same failure from repeating?

**Difficulty:** Easy


**Role:** Data Engineer

**Round:** L1

**Asked:** 

---

### Q7: How do you explain a technical problem, like a data delay, to a non-technical client?

**Also asked at:** Persistent Systems

**Answer:**
- **Lead with impact, not cause:** "Today's sales dashboard is about 2 hours behind; yesterday's numbers are correct and complete."
- **Plain language and an analogy:** "One of the systems sending us data was late, like a delivery truck arriving late, so the next steps had to wait."
- **What you're doing and when it'll be fixed:** a clear time for the next update.
- **What they should do:** e.g. "use yesterday's report for this morning's meeting."
- **Afterwards:** a short summary of the cause and what changes so it's less likely to happen again (alerts, buffer time, an agreement with the source team).

Avoid jargon (DAGs, partitions, retries) unless they ask; offer details for technical stakeholders separately.

**Follow-ups:**
- How do you handle a client who wants technical details you're not sure about yet?
- How do you set expectations when you don't know the fix time?

**Difficulty:** Easy


**Role:** Data Engineer (3+ years)

**Round:** 

**Asked:** 

## HCLTech

### Q8: As a lead, how do you decide who on the team works on what?

**Answer:**
- **Break work down** into clearly scoped tasks with acceptance criteria and estimates (backlog grooming).
- **Match tasks to skills and growth:** critical, risky items go to experienced engineers; stretch tasks go to people who want to grow, paired with someone senior.
- **Balance load and avoid single points of failure:** rotate areas so knowledge spreads, and don't overload one person.
- **Make dependencies visible:** sequence work so blockers are resolved early.
- **Track and adjust** in stand-ups and the board; re-allocate when priorities change.

Give a concrete example (e.g. how you split a migration across a team by subject area, with one person owning reconciliation tooling).

**Follow-ups:**
- How do you handle a task nobody wants?
- What do you do when an estimate turns out badly wrong?

**Difficulty:** Easy


**Role:** Lead Data Engineer

**Round:** Round 3 – Managerial & HR

**Asked:** 

---

### Q9: If you had to rebuild a data pipeline you built two years ago, what would you change?

**Answer:**
This tests reflection. Pick real, specific improvements with reasons:
- **Idempotency and recovery:** partition overwrite or `MERGE` instead of appends, so reruns are safe.
- **Incremental processing:** CDC or watermarks instead of full reloads, to cut runtime and cost.
- **Testing and data quality:** unit tests for transformations, and data quality checks (dbt tests or expectations) between layers.
- **Observability:** structured logging, freshness and volume monitoring, alerting on SLAs.
- **Simpler architecture:** fewer custom scripts, more managed services; configuration- or metadata-driven instead of copy-pasted jobs.
- **Infrastructure as code and CI/CD** from day one.

Frame it as "what I learned since then", and mention which of these you've already applied in newer work.

**Follow-ups:**
- Which of these changes would give the biggest benefit, and why?
- How would you convince the team to invest in the rebuild?

**Difficulty:** Medium


**Role:** Lead Data Engineer

**Round:** Round 3 – Managerial & HR

**Asked:** 

---

### Q10: Can you share facts about work that saved your project cost or time?

**Answer:**
Prepare 2–3 **quantified** examples, and explain how you measured them:
- **Runtime:** "Rewrote the nightly Spark job (broadcast joins, skew fix, AQE): 3 h → 45 min, which met the 6 AM SLA."
- **Cost:** "Partitioned and clustered the largest BigQuery tables and added `require_partition_filter`: scanned bytes down about 70%, saving a measurable amount per month."
- **Effort:** "Built a metadata-driven ingestion framework: onboarding a new table went from 2 days to 1 hour."
- **Reliability:** "Added retries, idempotent loads and alerts: manual reruns dropped from about 10 a month to 1."

Use real numbers from your own work, with before and after values and the baseline; interviewers often ask how you measured them.

**Follow-ups:**
- How did you measure the before and after?
- What trade-offs did the optimization introduce?

**Difficulty:** Medium


**Role:** Lead Data Engineer

**Round:** Round 3 – Managerial & HR

**Asked:** 

---

### Q11: What was your team size, and what were your individual responsibilities?

**Answer:**
Be precise and separate team results from your own contribution:
- **Team:** size and composition (e.g. "6 people: 4 data engineers, 1 QA, 1 lead"), plus who you worked with (analysts, source-system teams, the client).
- **Your ownership:** the components you designed or built end to end (e.g. "the CDC ingestion pipelines and the reconciliation framework"), decisions you made, and any leadership (code reviews, mentoring, on-call rotation, client calls).
- **Scale:** number of pipelines and tables, data volume, SLAs.

Use "I" for your work and "we" for team outcomes; interviewers notice when candidates can't say what they personally did.

**Follow-ups:**
- What decision did you make that changed the design?
- Who did you go to when you were blocked?

**Difficulty:** Easy


**Role:** Lead Data Engineer

**Round:** Round 3 – Managerial & HR

**Asked:** 

## JPMorgan

### Q12: How long did your pipeline take to run in your last project?

**Answer:**
Give a precise, honest answer **with context**:
- The runtime and its range (e.g. "about 40 minutes daily, 70 at month-end").
- What drives it: data volume (rows or GB per run), number of tables and steps, and the slowest stage.
- The SLA it had to meet (e.g. "data ready by 6 AM").
- Whether it's batch or streaming (for streaming, give end-to-end latency instead).

Then be ready for the natural follow-up, "could it be faster?": name the bottleneck and what you did or would do (incremental loads, parallelism, partition pruning, Spark tuning).

**Follow-ups:**
- What was the slowest step, and why?
- How would the runtime change if the data volume doubled?

**Difficulty:** Easy


**Role:** Senior / Lead Data Engineer

**Round:** Managerial

**Asked:** 

## Persistent Systems

### Q13: Describe a production incident you resolved under time pressure, and how you handled it.

**Answer:**
Use **STAR**, focusing on calm, structured action:
- **Situation:** the issue and the stakes (e.g. "month-end finance load failed at 4 AM; reports were due to leadership at 9 AM").
- **Task:** your responsibility (on-call owner).
- **Action:** triage first (impact, scope), communicate early ("ETA in 30 minutes"), contain or work around it (rerun the healthy part, a manual backfill), find and fix the root cause, and verify the data before releasing it.
- **Result:** delivered on time or with a short, communicated delay; then the RCA and prevention (alert, test, runbook).

Show prioritization and communication as much as technical skill.

**Follow-ups:**
- How did you decide what to fix first?
- What changed afterwards so it didn't happen again?

**Difficulty:** Medium


**Role:** Data Engineer

**Round:** Round 3 – Managerial / Behavioral

**Asked:** 

---

### Q14: A client has unrealistic delivery expectations. How would you handle it?

**Answer:**
1. **Understand the driver:** what's behind the date (an event, a regulatory deadline, a demo)? Sometimes only part of the scope is needed by then.
2. **Make the estimate transparent:** break the work down, show effort and risks, and what's already committed.
3. **Offer options instead of "no":** a reduced scope (MVP) by the date, more resources, a phased delivery, or a later date for the full scope, with the trade-offs of each.
4. **Agree in writing** and track progress visibly, raising risks early if they appear.
5. **Escalate through the right channel** (your manager or delivery lead) if needed, without surprises.

Give a real example where a phased plan met the critical need on time.

**Follow-ups:**
- What would you do if the client insists on the full scope by the original date?
- How do you avoid over-committing in the first place?

**Difficulty:** Medium


**Role:** Data Engineer

**Round:** Round 3 – Managerial / Behavioral

**Asked:** 

---

### Q15: Describe a time you worked with several teams that had conflicting priorities. How did you manage the deadlines?

**Answer:**
- **Make the conflict visible:** list each team's needs, deadlines and dependencies.
- **Align on priority with the right people:** product owner, managers, or business sponsor, based on business impact, not who shouts loudest.
- **Find overlaps and sequence the work:** shared components first, interim solutions where possible.
- **Communicate the plan** with dates and owners, and re-plan openly when something changes.
- **Protect commitments:** say no or "later" explicitly, rather than silently slipping.

Answer with a concrete STAR example (e.g. analytics wanted a new source while finance needed a migration fix in the same sprint), including the outcome.

**Follow-ups:**
- How do you say no to a senior stakeholder?
- What would you do if two managers gave you opposite instructions?

**Difficulty:** Medium


**Role:** Data Engineer

**Round:** Round 3 – Managerial / Behavioral

**Asked:** 

## TEKsystems

### Q16: Explain your overall experience as a Data Engineer, core skills, and current project.

**Also asked at:** Deloitte, Wipro

**Answer:**
Keep it to about 90 seconds and use a clear structure:
1. **Summary:** years of experience, role, and main platforms (e.g. "5 years as a data engineer, mainly on GCP: BigQuery, Dataflow, Composer, plus PySpark and SQL").
2. **Core skills:** 3–4 strengths tied to the job description (pipeline design, migrations, CDC and streaming, performance tuning).
3. **Current project:** the business goal, your architecture in one sentence (sources → processing → BigQuery → consumers), data volume and frequency, and **your** responsibilities.
4. **One measurable result:** e.g. "cut the nightly load from 3 hours to 40 minutes" or "migrated 200 tables with automated reconciliation".
5. **Why this role:** one line linking your experience to what they need.

Avoid listing every tool; interviewers ask follow-ups on whatever you mention, so only mention what you can go deep on.

**Follow-ups:**
- What was the hardest technical problem in your current project?
- What exactly did you own versus the team?

**Difficulty:** Easy


**Role:** GCP Data Engineer

**Round:** Technical evaluation

**Asked:** 

---

### Q17: Explain a real production issue you debugged using Python or PySpark.

**Answer:**
Pick one real incident and tell it as **situation → investigation → fix → prevention**:
- **Situation:** what broke and the business impact (e.g. "the daily PySpark job started failing with executor OOM after volume doubled; reports were late").
- **Investigation:** how you narrowed it down: logs, Spark UI (one task processing far more data), and the data itself (a NULL key holding 30% of rows).
- **Fix:** the specific change, e.g. filtering or salting the skewed key, enabling AQE skew join, and repartitioning before the join, with before and after runtime.
- **Prevention:** an alert on task skew or runtime, a data quality check on NULL keys, and a runbook entry.

Interviewers look for structured debugging, evidence-based decisions and a lasting fix, not just "I restarted the job".

**Follow-ups:**
- How did you confirm the root cause rather than a symptom?
- What would you do differently next time?

**Difficulty:** Medium


**Role:** GCP Data Engineer

**Round:** Technical evaluation

**Asked:** 
