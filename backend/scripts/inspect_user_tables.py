import psycopg2

conn = psycopg2.connect(
    dbname="tupilingo_sec_audit",
    user="postgres",
    password="postgres_audit_pass",
    host="localhost",
    port=15432
)
cur = conn.cursor()

user_tables = [
    'users_userprofile',
    'users_daily_study_log',
    'users_historicoresposta',
    'users_userlesson',
    'trilha_userchestreward',
    'nivelamento_uservariantelevel',
    'nivelamento_testattempt',
    'users_userachievement',
    'users_vocabularyprogress',
    'users_cosmetics',
    'users_cosmetic_purchases',
    'users_filaexerciciousuario',
]

for t in user_tables:
    cur.execute(f"""
        SELECT column_name, data_type 
        FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = '{t}';
    """)
    cols = [f"{c[0]}:{c[1]}" for c in cur.fetchall()]
    print(f"{t}: {', '.join(cols)}")

conn.close()
