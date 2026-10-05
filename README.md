# Resiliency Test POC

## Overview
This project is a practical proof-of-concept for Disaster Recovery as a Service (DRaaS) and Cyber Recovery as a Service (CRaaS). It demonstrates how an application workload, file set, and database can be backed up, intentionally impacted by a ransomware-style attack, and then restored using a recovery workflow built from Docker, PostgreSQL, Flask, MinIO, and Restic.

The goal is to show a realistic recovery test in a lightweight lab environment that can be run locally on a developer machine or in a small demo setup.

## What this POC does
This POC simulates a real-world resilience scenario:

1. A workload is running normally.
2. Application data is inserted into a PostgreSQL database.
3. Files are created in an application directory.
4. A backup is taken with Restic and a database dump is created.
5. A simulated attack removes files and drops the public schema in PostgreSQL.
6. The environment is restored from the backup snapshot.
7. The application and database are validated to confirm the workload is recovered.

This is useful for demonstrating:
- backup coverage for database and files
- restore validation
- cyber recovery testing
- operational readiness for DR drills
- a simple visual demo for stakeholders

## Architecture

The environment is defined in Docker Compose and includes:

- PostgreSQL: primary database workload
- Flask API: application layer that accepts record writes and reads
- MinIO: object storage used as the backup target for Restic
- Restic: backup and restore engine
- OpenSearch + Dashboards: monitoring and observability layer

## Project structure

```text
resiliency-testpoc/
├── app_files/
│   ├── customers.csv
│   └── report.txt
├── flask/
│   ├── app.py
│   ├── Dockerfile
│   └── requirements.txt
├── Scripts/
│   ├── backup.sh
│   ├── ransom.sh
│   └── restore.sh
├── tmp/
│   ├── pgdump.sql
│   └── restore/
├── docker-compose.yml
├── generate_final_word.py
├── README.md
├── Resiliency_Test_POC_Document.docx
├── Resiliency_Test_POC_Track_Copy.docx
└── .git/
```

## File-by-file explanation

### docker-compose.yml
This file defines the infrastructure stack.

```yaml
version: "3.9"

services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_USER: pocuser
      POSTGRES_PASSWORD: pocpass
      POSTGRES_DB: pocdb
    volumes:
      - ./tmp:/tmp
      - pgdata:/var/lib/postgresql/data
    ports:
      - "5432:5432"

  flask:
    build: ./flask
    environment:
      DATABASE_URL: postgres://pocuser:pocpass@postgres:5432/pocdb
    ports:
      - "8080:8080"
    depends_on:
      - postgres

  minio:
    image: minio/minio:latest
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: minioadmin
      MINIO_ROOT_PASSWORD: minioadmin
    volumes:
      - minio_data:/data
    ports:
      - "9000:9000"
      - "9001:9001"

  restic:
    image: restic/restic:latest
    environment:
      AWS_ACCESS_KEY_ID: minioadmin
      AWS_SECRET_ACCESS_KEY: minioadmin
      RESTIC_PASSWORD: MyStrongPass123
      RESTIC_REPOSITORY: s3:http://minio:9000/resticrepo
    volumes:
      - ./app_files:/app_files
      - ./tmp:/tmp
    entrypoint: ["restic"]

  opensearch:
    image: opensearchproject/opensearch:2.9.0
    environment:
      - discovery.type=single-node
    ports:
      - "9200:9200"

  opensearch-dashboards:
    image: opensearchproject/opensearch-dashboards:2.9.0
    ports:
      - "5601:5601"
    environment:
      OPENSEARCH_HOSTS: '["http://opensearch:9200"]'
    depends_on:
      - opensearch

volumes:
  pgdata:
  minio_data:
```

Why this matters:
- PostgreSQL is the primary data store for the workload.
- Flask exposes a simple API for writing and reading records.
- MinIO is configured as the backup repository target for Restic.
- Restic stores database dumps and file content safely.
- OpenSearch and Dashboards provide observability for such a lab environment.

### flask/app.py
This is the application layer. It creates the database table if missing and exposes a minimal API.

```python
from flask import Flask, request, jsonify
import json
import os
import psycopg2

app = Flask(__name__)

conn = psycopg2.connect(
    dbname=os.getenv("POSTGRES_DB", "pocdb"),
    user=os.getenv("POSTGRES_USER", "pocuser"),
    password=os.getenv("POSTGRES_PASSWORD", "pocpass"),
    host=os.getenv("POSTGRES_HOST", "postgres"),
    port=int(os.getenv("POSTGRES_PORT", "5432")),
)


def init_db():
    with conn.cursor() as cur:
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS posts (
                id SERIAL PRIMARY KEY,
                content TEXT NOT NULL
            );
            """
        )
    conn.commit()


def ensure_table():
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT 1 FROM posts LIMIT 1;")
    except Exception:
        init_db()


init_db()


@app.route("/", methods=["GET"])
def index():
    return jsonify(
        {
            "status": "ok",
            "message": "Resiliency POC API",
            "endpoints": {
                "GET /": "This endpoint",
                "GET /list": "List all posts",
                "POST /create": "Create a post with JSON {\"content\": \"text\"}",
            },
        }
    )


@app.route("/create", methods=["POST"])
def create_post():
    ensure_table()
    data = request.get_json(silent=True)
    if data is None:
        data = request.form.to_dict()
    if not data and request.data:
        try:
            data = json.loads(request.data.decode("utf-8"))
        except (TypeError, ValueError):
            data = {}

    content = data.get("content") or request.args.get("content")
    if not content:
        return jsonify({"error": "content is required"}), 400

    with conn.cursor() as cur:
        cur.execute("INSERT INTO posts(content) VALUES (%s)", (content,))
    conn.commit()
    return jsonify({"status": "ok", "content": content})


@app.route("/list", methods=["GET"])
def list_posts():
    ensure_table()
    with conn.cursor() as cur:
        cur.execute("SELECT * FROM posts;")
        rows = cur.fetchall()
    return jsonify(rows)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
```

This route set is intentionally minimal. It allows the demo to show:
- HTTP-based application workload
- persistence into PostgreSQL
- recovery validation after database loss

### flask/Dockerfile
```dockerfile
FROM python:3.11-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py .

EXPOSE 8080
CMD ["python", "app.py"]
```

This builds the Flask service container. The app runs on port 8080 and depends on the database service on the Docker network.

### flask/requirements.txt
```text
Flask==3.0.3
psycopg2-binary==2.9.9
```

These are the only application dependencies required for the API.

### Scripts/backup.sh
```bash
#!/bin/bash
set -e

docker compose exec -T postgres pg_dump -U pocuser pocdb -f /tmp/pgdump.sql
docker compose run --rm restic backup /tmp/pgdump.sql /app_files
```

This script creates a database dump and backs up both the dump file and the app file set.

### Scripts/ransom.sh
```bash
#!/bin/bash
set -e

rm -rf app_files/*
docker compose exec -T postgres psql -U pocuser -d pocdb -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
```

This simulates a ransomware or destructive attack by:
- removing application files from the app directory
- dropping the PostgreSQL schema to simulate data destruction

### Scripts/restore.sh
```bash
#!/bin/bash
set -e

SNAPSHOT=${1:-latest}
docker compose run --rm restic restore "$SNAPSHOT" --target /tmp/restore
RESTORE_SQL="/tmp/restore/tmp/pgdump.sql"
if [ ! -f "$RESTORE_SQL" ]; then
  RESTORE_SQL="/tmp/restore/pgdump.sql"
fi
if [ ! -f "$RESTORE_SQL" ]; then
  echo "Database dump not found in restored snapshot" >&2
  exit 1
fi
docker compose exec -T postgres psql -U pocuser -d pocdb -f "$RESTORE_SQL"
```

Important note: Restic restores the snapshot contents under a nested structure. The SQL dump is commonly located at /tmp/restore/tmp/pgdump.sql, not directly at /tmp/restore/pgdump.sql. This path handling is the key fix that makes restore reliable.

### generate_final_word.py
This Python file creates a Word document summarizing the project.

```python
from docx import Document
from docx.shared import Pt


def add_list(doc, items):
    for item in items:
        doc.add_paragraph(f'- {item}')


doc = Document()
doc.styles['Normal'].font.name = 'Calibri'
doc.styles['Normal'].font.size = Pt(11)

p = doc.add_paragraph()
r = p.add_run('Resiliency Test POC')
r.bold = True
r.font.size = Pt(22)

doc.add_paragraph('Project Summary and Tracking Document')
doc.add_paragraph('Prepared for print and project tracking.')

doc.add_heading('1. Project Overview', level=1)
doc.add_paragraph('This project demonstrates a sandbox environment for Disaster Recovery (DRaaS) and Cyber Recovery (CRaaS) using containerized open-source services.')
doc.add_paragraph('It simulates normal workload activity, backup creation, attack simulation, restore operations, and validation checks.')

doc.add_heading('2. Project Components', level=1)
add_list(doc, [
    'PostgreSQL - database layer',
    'Flask - application layer',
    'MinIO - object storage',
    'Restic - backup and restore',
    'OpenSearch + Dashboards - monitoring and visibility'
])

doc.add_heading('3. Demo Workflow', level=1)
for step in [
    '1. Workload alive: insert rows and add files.',
    '2. Backup: run pg_dump and Restic backup.',
    '3. Attack simulation: drop schema and delete files.',
    '4. Restore: recover the snapshot and replay the SQL file.',
    '5. Validate: confirm database rows and files are restored.'
]:
    doc.add_paragraph(step)

doc.add_heading('4. Code Copy', level=1)
doc.add_paragraph('Flask application code:')
app_code = '''from flask import Flask, request, jsonify
import psycopg2

app = Flask(__name__)
conn = psycopg2.connect(
    dbname="pocdb",
    user="pocuser",
    password="pocpass",
    host="postgres",
    port=5432
)

@app.route("/create", methods=["POST"])
def create_post():
    content = request.json.get("content")
    cur = conn.cursor()
    cur.execute("INSERT INTO posts(content) VALUES (%s)", (content,))
    conn.commit()
    cur.close()
    return jsonify({"status": "ok", "content": content})

@app.route("/list", methods=["GET"])
def list_posts():
    cur = conn.cursor()
    cur.execute("SELECT * FROM posts;")
    rows = cur.fetchall()
    cur.close()
    return jsonify(rows)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)'''
for line in app_code.splitlines():
    doc.add_paragraph(line)

doc.add_heading('5. Future Options', level=1)
add_list(doc, [
    'Improve the app workload with customer and order datasets.',
    'Add automated restore validation checks.',
    'Add stronger ransomware and corruption simulations.',
    'Store secrets in .env files or a secret manager.',
    'Add monitoring dashboards and alert rules.',
    'Turn this into a full disaster recovery drill for demos and training.'
])

doc.add_paragraph('This document is intended as a print-ready project tracking file for review, testing, and future improvements.')

doc.save('Resiliency_Test_POC_Document.docx')
print('Created: Resiliency_Test_POC_Document.docx')
```

This script turns the project into a printable tracking document for review and publication.

## Demo workflow

### 1. Start the environment
```powershell
cd "C:\Users\preet\resiliency-testpoc"
docker compose up -d --build
```

### 2. Create workload data
```powershell
curl.exe -s -X POST http://localhost:8080/create -H "Content-Type: application/json" -d '{"content":"demo-record-001"}'
curl.exe -s -X POST http://localhost:8080/create -H "Content-Type: application/json" -d '{"content":"demo-record-002"}'
```

### 3. Run backup
```powershell
docker compose exec -T postgres pg_dump -U pocuser pocdb -f /tmp/pgdump.sql
docker compose run --rm restic backup /tmp/pgdump.sql /app_files
```

### 4. Simulate ransomware or destructive attack
```powershell
Remove-Item -Recurse -Force .\app_files\*
docker compose exec -T postgres psql -U pocuser -d pocdb -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
```

### 5. Restore from snapshot
```powershell
docker compose run --rm restic restore latest --target /tmp/restore
docker compose exec -T postgres psql -U pocuser -d pocdb -f /tmp/restore/tmp/pgdump.sql
```

### 6. Validate recovery
```powershell
curl.exe -s http://localhost:8080/list
```

Successful recovery means:
- the record list includes the original content again
- files exist in the application folder again
- the schema and data are no longer destroyed

## Verified runtime behavior
The following were validated during setup and testing:

- Flask app responds successfully on http://localhost:8080/
- MinIO console responds on http://localhost:9001/
- PostgreSQL service is running on port 5432
- Restic snapshot creation works
- SQL restore works when the path is corrected to the nested restore directory

## Known notes and considerations
- Docker Compose shows an obsolete version warning; the version field is ignored by modern Docker Compose, but it does not block the stack.
- OpenSearch Dashboards may take longer to become fully ready than the rest of the services.
- When restoring from Restic, the dump file may be under /tmp/restore/tmp/pgdump.sql instead of /tmp/restore/pgdump.sql.
- This is a demo lab and not production hardened; secrets and configuration should be moved to secure management in a real environment.

## Business value
This POC is useful for:
- demonstrating resilience engineering to business stakeholders
- explaining DR and cyber recovery scenarios in a simple environment
- showing that backup and restoration are operationally testable
- creating a lab for training and stakeholder presentations

## Conclusion
This project is a compact disaster-recovery sandbox that demonstrates how a workload, its files, and its database can be backed up and restored after a destructive event. It provides both technical depth and demo-friendly simplicity, making it suitable for project documentation, stakeholder reviews, and recovery readiness discussions.
