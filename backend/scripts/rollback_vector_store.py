#!/usr/bin/env python3
"""
Script de Rollback do vector_store.db do TupiLingo.
Restaura o banco a partir do backup pontual de segurança pré-remigração.
"""
import os
import shutil
import sqlite3
import sys

DEFAULT_BACKUP = r"C:\Users\Felipe\Desktop\TupiLingo_backups\vector_store_backup_2026-09-25_221112.db"
LOCAL_FALLBACK = os.path.join(os.path.dirname(__file__), "..", "backups", "vector_store_backup_2026-09-25_221112.db")
TARGET_DB = os.path.join(os.path.dirname(__file__), "..", "vector_store.db")

def rollback(backup_path: str = DEFAULT_BACKUP):
    if not os.path.exists(backup_path):
        if os.path.exists(LOCAL_FALLBACK):
            backup_path = LOCAL_FALLBACK
        else:
            print(f"ERRO: Arquivo de backup não encontrado em {backup_path} nem em {LOCAL_FALLBACK}")
            sys.exit(1)

    print(f"Iniciando rollback a partir de: {backup_path}")
    print(f"Destino: {TARGET_DB}")

    # Valida integridade do backup antes de sobrescrever
    try:
        conn = sqlite3.connect(backup_path)
        cur = conn.cursor()
        cur.execute("SELECT count(*) FROM documents")
        count = cur.fetchone()[0]
        conn.close()
        print(f"Validação do backup: OK ({count} documentos íntegros)")
    except Exception as exc:
        print(f"ERRO: Backup corrompido ou ilegível: {exc}")
        sys.exit(1)

    # Cria cópia de segurança do banco corrompido/falho antes de sobrescrever
    if os.path.exists(TARGET_DB):
        failed_save = TARGET_DB + ".failed_run"
        shutil.copy2(TARGET_DB, failed_save)
        print(f"Estado falho arquivado temporariamente em: {failed_save}")

    # Restaura
    shutil.copy2(backup_path, TARGET_DB)
    print(f"Rollback concluído com sucesso! {TARGET_DB} restaurado.")

if __name__ == "__main__":
    path = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_BACKUP
    rollback(path)
