# Contributing

Thanks for helping improve the Data Engineering Interview Guide!

## Workflow

> **Direct pushes to `main` are not allowed.** All changes go through a pull request.

1. **Sync `main`**
   ```bash
   git checkout main
   git pull origin main
   ```
2. **Create a branch** using one of these naming patterns:
   - `feature/<topic>`: new content (e.g. `feature/spark-optimization-questions`)
   - `fix/<topic>`: corrections (e.g. `fix/scd-type2-typo`)
   ```bash
   git checkout -b feature/<topic>
   ```
3. **Make your changes** and commit with clear messages.
   ```bash
   git add .
   git commit -m "Add questions on Spark partitioning"
   ```
4. **Push and open a pull request** against `main`.
   ```bash
   git push -u origin feature/<topic>
   gh pr create --base main
   ```
5. **Review**: at least one approval from a code owner is required. New commits dismiss earlier approvals.

## Content Guidelines

- Put content in the right folder (see the main [README](README.md)).
- Question-bank files must follow the format in [`04-question-bank/README.md`](04-question-bank/README.md): **Question, Answer, Follow-ups, Difficulty**.
- System design case studies must include `README.md`, `architecture.md` (with a Mermaid diagram), and a `diagrams/` folder.
- Use lowercase, hyphen-separated file names (e.g. `window-functions.md`).
- Make sure code samples run, and say which versions you used (Python, Spark, Airflow, etc.).
- Don't commit credentials, keys, or proprietary/confidential data.
