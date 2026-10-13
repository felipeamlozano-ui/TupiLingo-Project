import psycopg2

conn = psycopg2.connect(
    dbname="tupilingo_sec_audit",
    user="postgres",
    password="postgres_audit_pass",
    host="localhost",
    port=15432
)
cur = conn.cursor()
cur.execute("""
    SELECT table_name 
    FROM information_schema.tables 
    WHERE table_schema = 'public' 
    ORDER BY table_name;
""")
tables = [r[0] for r in cur.fetchall()]
print(f"Total tables: {len(tables)}")
cur.execute("""
    SELECT tablename, rowsecurity 
    FROM pg_tables 
    WHERE schemaname = 'public' 
    ORDER BY tablename;
""")
print("\n--- RLS Status on Public Tables ---")
for row in cur.fetchall():
    print(f"  {row[0]}: RLS={row[1]}")

cur.execute("""
    SELECT schemaname, tablename, policyname, roles, cmd, qual, with_check 
    FROM pg_policies 
    WHERE schemaname = 'public' 
    ORDER BY tablename, policyname;
""")
print("\n--- Active RLS Policies ---")
for row in cur.fetchall():
    print(f"  Table: {row[1]} | Policy: {row[2]} | Roles: {row[3]} | Cmd: {row[4]}")
conn.close()

