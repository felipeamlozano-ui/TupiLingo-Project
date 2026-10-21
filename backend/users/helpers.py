"""
Helpers utilitários para resolução e provisionamento resiliente de usuários.
Garante que usuários com tokens válidos do Supabase nunca recebam 404 falso
por conta de condições de corrida, latência de rede ou reconciliação de contas.
"""

import json
import logging
from django.conf import settings
from django.http import JsonResponse
from users.models import UserProfile

logger = logging.getLogger(__name__)


def extract_user_email(user_data: dict) -> str:
    """Extrai o e-mail do payload do JWT ou metadados de forma abrangente."""
    if not user_data:
        return ""
    email = user_data.get("email") or ""
    if not email and isinstance(user_data.get("user_metadata"), dict):
        email = user_data["user_metadata"].get("email", "")
    if not email and isinstance(user_data.get("app_metadata"), dict):
        email = user_data["app_metadata"].get("email", "")
    return str(email).strip().lower()


def get_or_provision_user(request) -> tuple[UserProfile | None, JsonResponse | None]:
    """
    Resolve o UserProfile autenticado a partir do JWT do Supabase.
    Ordem de resolução:
      1. Busca por supabase_uid
      2. Reconciliação por e-mail (caso o usuário tenha recriado conta no Supabase)
      3. Auto-provisionamento resiliente garantindo que requisições autenticadas
         nunca sofram com 404 falso por latência de cadastro.
    Retorna (user, error_response).
    """
    if not hasattr(request, "user_data") or not request.user_data:
        return None, JsonResponse({"error": "UNAUTHORIZED"}, status=401)

    supabase_uid = request.user_data.get("sub")
    if not supabase_uid:
        return None, JsonResponse(
            {"error": "UNAUTHORIZED", "message": "Identificador do usuário ausente no token."},
            status=401,
        )

    # 1. Busca direta por supabase_uid
    user = UserProfile.objects.select_related("variante_ativa").filter(supabase_uid=supabase_uid).first()
    if user:
        return user, None

    # 2. Busca e reconciliação por e-mail
    email = extract_user_email(request.user_data)
    if email and not email.endswith("@anon.tupilingo.internal"):
        existing = UserProfile.objects.select_related("variante_ativa").filter(email__iexact=email).first()
        if existing:
            logger.info(
                "Reconciliando UserProfile por e-mail: %s (antigo_uid=%s, novo_uid=%s)",
                email,
                existing.supabase_uid,
                supabase_uid,
            )
            existing.supabase_uid = supabase_uid
            existing.save(update_fields=["supabase_uid", "updated_at"])
            return existing, None

    # 3. Auto-provisionamento imediato
    try:
        from trilha.models import VarianteTupi

        user_metadata = request.user_data.get("user_metadata") or {}
        name = (
            user_metadata.get("name")
            or user_metadata.get("full_name")
            or (email.split("@")[0] if email else "Aluno")
        )
        final_email = email or f"{supabase_uid}@anon.tupilingo.internal"
        default_var = VarianteTupi.objects.filter(ativo=True).order_by("ordem").first()

        user, created = UserProfile.objects.get_or_create(
            supabase_uid=supabase_uid,
            defaults={
                "email": final_email,
                "name": str(name)[:150],
                "source": "outro",
                "variante_ativa": default_var,
            },
        )
        logger.info(
            "Auto-provisionamento de UserProfile executado para uid=%s (email=%s, created=%s)",
            supabase_uid,
            final_email,
            created,
        )
        return user, None
    except Exception as exc:
        logger.warning("Falha ao auto-provisionar UserProfile para uid=%s: %s", supabase_uid, exc)
        # Se houve conflito no get_or_create (ex: race condition), tenta buscar novamente
        user = UserProfile.objects.filter(supabase_uid=supabase_uid).first()
        if user:
            return user, None
        if email and not email.endswith("@anon.tupilingo.internal"):
            user = UserProfile.objects.filter(email__iexact=email).first()
            if user:
                user.supabase_uid = supabase_uid
                user.save(update_fields=["supabase_uid", "updated_at"])
                return user, None

        return None, JsonResponse({"error": "Usuário não encontrado."}, status=404)
