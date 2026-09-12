import glob, os, re

def check_migrations():
    migration_files = sorted(glob.glob(r'c:\Users\Felipe\Desktop\TupiLingo\supabase\migrations\*.sql'))
    for f in migration_files:
        with open(f, 'r', encoding='utf-8') as fp:
            content = fp.read()
        tables = re.findall(r'CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?([a-zA-Z0-9_\.\"]+)', content, re.IGNORECASE)
        print(f"File: {os.path.basename(f)}")
        for t in tables:
            print(f"  - Table: {t}")

if __name__ == '__main__':
    check_migrations()
