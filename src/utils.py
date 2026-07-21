import os
from pathlib import Path

import psycopg2


DB_CONFIG = {
    "host": os.getenv("POSTGRES_HOST", "postgres"),
    "port": int(os.getenv("POSTGRES_PORT", 5432)),
    "dbname": os.getenv("POSTGRES_DB", "bootcamp"),
    "user": os.getenv("POSTGRES_USER", "bootcamp"),
    "password": os.getenv("POSTGRES_PASSWORD", "bootcamp"),
}

BASE_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = BASE_DIR / "data"
SQL_DIR = BASE_DIR / "sql"


def get_connection():
    return psycopg2.connect(**DB_CONFIG)


def run_sql_file(cursor, filepath):
    with open(filepath, "r", encoding="utf-8") as f:
        sql = f.read()
    cursor.execute(sql)
