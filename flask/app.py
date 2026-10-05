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
    try:
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
    except Exception:
        conn.rollback()
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
        conn.rollback()
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
