# Resiliency Test POC: Disaster Recovery and Cyber Recovery Validation in a Dockerized Environment

## Executive Summary
This project demonstrates a practical proof-of-concept for Disaster Recovery as a Service (DRaaS) and Cyber Recovery as a Service (CRaaS). It simulates a real operational scenario in which an application workload, database, and file set are backed up, intentionally impacted by a destructive event, and restored using a recovery workflow.

The environment is built using Docker Compose and includes PostgreSQL, a Flask API, MinIO object storage, Restic backup/restore, and OpenSearch with Dashboards. The purpose is to model a realistic resilience drill that can be executed locally and presented to technical and business stakeholders.

## Objective
The primary objective is to prove that a small but representative application environment can:

- generate workload data,
- create a point-in-time backup,
- simulate a destructive attack,
- restore the environment from backup,
- validate that application data and files are recovered.

This is a simple but valuable demonstration of resilience testing and operational recovery readiness.

## Business and Technical Value
This POC is useful for teams that want to demonstrate:

- data protection and backup coverage,
- database and file recovery validation,
- cyber recovery readiness after destructive events,
- application continuity in a controlled environment,
- DR drill execution for training and stakeholder review.

It provides a clear, low-cost way to explain resilience testing without requiring a full production environment.

## Solution Architecture
The platform is implemented as a small containerized stack.

### Components
- PostgreSQL 15: primary data store for application records
- Flask API: workload application that accepts writes and reads
- MinIO: object storage used as the backup repository
- Restic: backup and restore engine
- OpenSearch / Dashboards: monitoring and observability layer

### Runtime Topology
- The Flask application exposes endpoints for creating and listing records.
- The PostgreSQL database stores those records.
- Restic stores a database dump and file content in the MinIO repository.
- A script simulates a destructive event by deleting files and dropping the public schema.
- Restore scripts replay the database dump and recover the files from the snapshot.

## What the POC Demonstrates
The POC models the following lifecycle:

1. Workload generation
   - Records are added through the Flask API.
2. Backup creation
   - PostgreSQL is dumped to SQL.
   - The dump and application files are backed up with Restic.
3. Simulated attack
   - Files are removed.
   - The PostgreSQL public schema is dropped to simulate data loss.
4. Recovery
   - Restic restores the snapshot.
   - The SQL dump is replayed into PostgreSQL.
5. Validation
   - The application list endpoint shows recovered records.
   - The database query confirms the restored rows.

This demonstrates the full value chain of backup, recovery, and validation.

## Folder and File Breakdown

### docker-compose.yml
Defines the stack for the environment.

### flask/app.py
This is the Flask API that handles the workload and manages the database table.

### flask/Dockerfile
Builds the Flask container for the application service.

### flask/requirements.txt
Defines the Python dependencies:

```text
Flask==3.0.3
psycopg2-binary==2.9.9
```

### Scripts/backup.sh
Creates a database dump and runs a Restic backup.

### Scripts/ransom.sh
Simulates the destructive event by deleting files and dropping database objects.

### Scripts/restore.sh
Restores the snapshot and replays the SQL dump.

### generate_final_word.py
Generates a Word document summary for reporting and tracking.

## Verified Test Flow
The following workflow was executed and validated successfully.

### 1. Create workload record
The application was tested using PowerShell native HTTP calls.

```powershell
Invoke-WebRequest -Method Post -Uri 'http://localhost:8080/create' -Headers @{'Content-Type'='application/json'} -Body '{"content":"demo-record-101"}' -UseBasicParsing
```

Validated result:

```text
StatusCode : 200
Content    : {"content":"demo-record-101","status":"ok"}
```

### 2. Backup database and files
The project generated a database dump and backed it up with Restic.

```powershell
docker compose exec -T postgres pg_dump -U pocuser pocdb -f /tmp/pgdump.sql
docker compose run --rm restic backup /tmp/pgdump.sql /app_files
```

Validated result:

```text
snapshot 7cebcc71 saved
```

### 3. Simulate ransomware-style destruction
The files were removed and the PostgreSQL schema was dropped.

```powershell
Remove-Item -Recurse -Force .\app_files\*
docker compose exec -T postgres psql -U pocuser -d pocdb -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
```

Validated result:

```text
NOTICE:  drop cascades to table posts
DROP SCHEMA
CREATE SCHEMA
```

### 4. Restore from backup
The snapshot was restored and the SQL dump was replayed.

```powershell
docker compose run --rm restic restore latest --target /tmp/restore
docker compose exec -T postgres psql -U pocuser -d pocdb -f /tmp/restore/tmp/pgdump.sql
```

Validated result:

```text
CREATE TABLE
COPY 2
```

### 5. Validate recovery
The list endpoint was queried again and the recovered rows were confirmed.

```powershell
Invoke-WebRequest -Uri 'http://localhost:8080/list' -UseBasicParsing
```

Validated result:

```text
StatusCode : 200
Content    : [[1,"demo-record-001"],[2,"demo-record-101"]]
```

Database query confirmation:

```text
id |     content
----+-----------------
  1 | demo-record-001
  2 | demo-record-101
(2 rows)
```

This is the clearest proof that the POC works as designed.

## Important Technical Notes
Several implementation details were identified and corrected during testing:

- The Flask app must create the `posts` table if it is missing.
- If the schema is dropped during the attack simulation, the app must roll back the failed transaction before re-creating the table.
- Restic restores the dump file under a nested path, typically `/tmp/restore/tmp/pgdump.sql`, so the restore script must check the actual location before replaying the SQL.
- The Compose file includes an obsolete `version` field, but Docker Compose currently ignores it without breaking startup.

These findings are part of the real-world troubleshooting and validation that make the project publishable.

## Practical Usage
To run the environment locally:

```powershell
cd "C:\Users\preet\resiliency-testpoc"
docker compose up -d --build
```

Then create some load data and execute the backup, ransomware simulation, and restore steps as shown above.

## Conclusion
This project validates a compact and realistic disaster recovery workflow. It demonstrates that a small application environment can be intentionally disrupted and restored, proving the viability of backup and recovery planning in a controlled technical environment.

The most important point is that the project is not theoretical: it was executed, tested, and validated. The database was dropped, the files were removed, the snapshot was restored, and the application and database data were recovered successfully.

This makes the project suitable for technical documentation, stakeholder presentations, demo sessions, and recovery-readiness discussions.
