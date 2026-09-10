#!/usr/bin/env python
"""
Script de Limpeza de Usuários de Teste — TupiLingo

Exclui usuários de teste da base de dados PostgreSQL e cascadeia a exclusão
de todas as tabelas de progresso associadas:
  - UserLesson (progresso nas lições)
  - DailyStudyLog (histórico diário de ofensiva/XP)
  - UserChestReward (baús culturais coletados)
  - UserAchievement (medalhas e conquistas)
  - VocabularyProgress (revisão espaçada SM-2)
  - UserVarianteLevel (nível calibrado por variante)
  - TestAttempt (tentativas de teste de nivelamento)
  - FilaExercicioUsuario (fila offline de exercícios)

Opcionalmente, remove também os usuários correspondentes no Supabase Auth via Admin API.

Uso:
  python clean_test_users.py --dry-run
  python clean_test_users.py
  python clean_test_users.py --include-supabase
  python clean_test_users.py --all
"""

import os
import sys
import argparse
import logging
from typing import List, Set

# Configura o ambiente Django antes de qualquer import de models
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings.development')

import django
django.setup()

from django.db import transaction
from django.contrib.auth.models import User
from decouple import config

from users.models import (
    UserProfile,
    UserLesson,
    DailyStudyLog,
    UserAchievement,
    VocabularyProgress,
    FilaExercicioUsuario,
)
from trilha.models import UserChestReward
from nivelamento.models import UserVarianteLevel, TestAttempt

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("clean_test_users")

DEFAULT_PROTECTED_EMAILS = {
    'felipe.a.m.lozano@gmail.com',
}


def get_protected_emails(extra_keep: List[str] = None, keep_staff: bool = False) -> Set[str]:
    """Retorna o conjunto de emails que NÃO devem ser excluídos."""
    protected = set(email.lower().strip() for email in DEFAULT_PROTECTED_EMAILS)

    if extra_keep:
        for em in extra_keep:
            if em:
                protected.add(em.lower().strip())

    if keep_staff:
        # Protege superusuários e staff cadastrados no Django User
        staff_emails = User.objects.filter(
            is_staff=True
        ).values_list('email', flat=True)
        for em in staff_emails:
            if em:
                protected.add(em.lower().strip())

    return protected


def delete_from_supabase_auth(supabase_uids: List[str]) -> int:
    """Remove usuários do Supabase Auth usando o Service Role Key."""
    supabase_url = config('SUPABASE_URL', default=None)
    service_role_key = config('SUPABASE_SERVICE_ROLE_KEY', default=None)

    if not supabase_url or not service_role_key:
        logger.warning("[Supabase Auth] SUPABASE_URL ou SUPABASE_SERVICE_ROLE_KEY ausente. Ignorando remoção no Supabase Auth.")
        return 0

    try:
        from supabase import create_client
        supabase = create_client(supabase_url, service_role_key)
    except Exception as exc:
        logger.error("[Supabase Auth] Falha ao inicializar client Supabase Admin: %s", exc)
        return 0

    deleted_count = 0
    for uid_str in supabase_uids:
        try:
            supabase.auth.admin.delete_user(uid_str)
            logger.info("  [Supabase Auth] Usuário %s removido com sucesso.", uid_str)
            deleted_count += 1
        except Exception as exc:
            logger.warning("  [Supabase Auth] Falha ao deletar uid %s: %s", uid_str, exc)

    return deleted_count


def clean_users(
    dry_run: bool = False,
    include_supabase: bool = False,
    all_users: bool = False,
    extra_keep: List[str] = None,
    keep_staff: bool = False,
):
    protected_emails = set() if all_users else get_protected_emails(extra_keep, keep_staff=keep_staff)

    print("=" * 75)
    print("           TUPILINGO — LIMPEZA DE BASE DE TESTES")
    print("=" * 75)
    if dry_run:
        print(" [MODO SIMULACAO] Nenhuma alteracao sera gravada no banco de dados.")
    if all_users:
        print(" [AVISO] Modo --all ativado: TODOS os usuarios serao deletados!")
    else:
        print(f" [*] Emails protegidos (nao serao excluidos): {sorted(list(protected_emails))}")
    print("-" * 75)

    all_profiles = UserProfile.objects.all()
    to_delete: List[UserProfile] = []
    to_keep: List[UserProfile] = []

    for prof in all_profiles:
        prof_email = (prof.email or "").strip().lower()
        if not all_users and prof_email in protected_emails:
            to_keep.append(prof)
        else:
            to_delete.append(prof)

    print(f" [*] Total de perfis na base: {all_profiles.count()}")
    print(f" [*] Perfis preservados: {len(to_keep)}")
    for k in to_keep:
        print(f"     - ID {k.id}: {k.email} ({k.name})")

    print(f" [*] Perfis marcados para exclusao: {len(to_delete)}")
    for d in to_delete:
        print(f"     - ID {d.id}: {d.email} ({d.name}) [UID: {d.supabase_uid}]")

    if not to_delete:
        print("\n [!] Nenhum usuario de teste encontrado para exclusao.")
        return

    delete_ids = [u.id for u in to_delete]
    supabase_uids = [str(u.supabase_uid) for u in to_delete if u.supabase_uid]

    # Contabilidade de registros filhos que serao removidos em cascata
    total_lessons = UserLesson.objects.filter(usuario_id__in=delete_ids).count()
    total_logs = DailyStudyLog.objects.filter(user_id__in=delete_ids).count()
    total_chests = UserChestReward.objects.filter(user_id__in=delete_ids).count()
    total_achievements = UserAchievement.objects.filter(user_id__in=delete_ids).count()
    total_vocab = VocabularyProgress.objects.filter(usuario_id__in=delete_ids).count()
    total_levels = UserVarianteLevel.objects.filter(user_id__in=delete_ids).count()
    total_attempts = TestAttempt.objects.filter(user_id__in=delete_ids).count()
    total_offline = FilaExercicioUsuario.objects.filter(usuario_id__in=delete_ids).count()

    print("\n [*] Registros dependentes que serao removidos em cascata:")
    print(f"     - Lições de Usuário (UserLesson): {total_lessons}")
    print(f"     - Logs de Ofensiva (DailyStudyLog): {total_logs}")
    print(f"     - Baús Coletados (UserChestReward): {total_chests}")
    print(f"     - Medalhas (UserAchievement): {total_achievements}")
    print(f"     - Vocabulário SM-2 (VocabularyProgress): {total_vocab}")
    print(f"     - Níveis por Variante (UserVarianteLevel): {total_levels}")
    print(f"     - Testes de Nivelamento (TestAttempt): {total_attempts}")
    print(f"     - Buffer Offline (FilaExercicioUsuario): {total_offline}")

    if dry_run:
        print("\n [OK] Simulacao concluida com sucesso. Nenhum registro foi alterado.")
        return

    # Execucao real da exclusao transacional
    print("\n [*] Executando exclusao transacional no PostgreSQL...")
    with transaction.atomic():
        # Limpa caches em memoria/redis para os IDs deletados
        from django.core.cache import cache
        for uid in delete_ids:
            for vid in range(1, 10):
                cache.delete(f"user_trail_{uid}_{vid}")

        # Cascade delete via ORM Django
        deleted_count, details = UserProfile.objects.filter(id__in=delete_ids).delete()

    print(f" [OK] {deleted_count} registros removidos com sucesso do PostgreSQL!")
    print(f"      Detalhes: {details}")

    # Remocao opcional do Supabase Auth
    if include_supabase and supabase_uids:
        print("\n [*] Removendo contas correspondentes no Supabase Auth...")
        sb_count = delete_from_supabase_auth(supabase_uids)
        print(f" [OK] {sb_count} usuario(s) removido(s) do Supabase Auth.")

    print("\n" + "=" * 75)
    print(" BASE DE TESTES LIMPA COM SUCESSO! VOCE PODE TESTAR DO ZERO AGORA.")
    print("=" * 75)


def main():
    parser = argparse.ArgumentParser(
        description="Script para deletar usuários de teste e zerar o progresso na base do TupiLingo."
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Simula a execução e lista os usuários e registros sem deletar nada.",
    )
    parser.add_argument(
        "--include-supabase",
        action="store_true",
        help="Deleta os usuários também do auth.users do Supabase.",
    )
    parser.add_argument(
        "--all",
        action="store_true",
        help="Remove TODOS os usuários da base sem exceções (use com cautela).",
    )
    parser.add_argument(
        "--keep-staff",
        action="store_true",
        help="Preserva também quaisquer contas com is_staff=True no Django User.",
    )
    parser.add_argument(
        "--keep-email",
        action="append",
        default=[],
        help="Especifica email adicional a ser preservado da exclusão (pode ser repetido).",
    )

    args = parser.parse_args()
    clean_users(
        dry_run=args.dry_run,
        include_supabase=args.include_supabase,
        all_users=args.all,
        extra_keep=args.keep_email,
        keep_staff=args.keep_staff,
    )


if __name__ == '__main__':
    main()
