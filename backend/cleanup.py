import os
import psycopg2
from dotenv import load_dotenv

load_dotenv()

conn = psycopg2.connect(
    dbname=os.environ.get("DB_NAME", "postgres"),
    user=os.environ.get("DB_USER"),
    password=os.environ.get("DB_PASSWORD"),
    host=os.environ.get("DB_HOST"),
    port=os.environ.get("DB_PORT", "6543")
)
cursor = conn.cursor()

# Deleta todos os UserProfile duplicados por email, mantendo apenas o que tem o menor ID (primeiro criado)
sql = """
DELETE FROM users_userprofile
WHERE id IN (
    SELECT id
    FROM (
        SELECT id, ROW_NUMBER() OVER(PARTITION BY email ORDER BY id ASC) as row_num
        FROM users_userprofile
    ) t
    WHERE t.row_num > 1
);
"""

cursor.execute(sql)
conn.commit()
print(f"Deleted {cursor.rowcount} duplicate rows.")

conn.close()
