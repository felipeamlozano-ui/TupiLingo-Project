import logging

from celery import shared_task

logger = logging.getLogger("users.tasks")


@shared_task(bind=True, max_retries=3, default_retry_delay=60)
def processar_pos_licao(self, user_id: int, licao_id: int, accuracy: float):
    """Processa achievements e recalibração de nível de forma assíncrona (SCALE-001)."""
    try:
        from trilha.models import Licao
        from trilha.views import _recalibrar_nivel

        from users.models import UserProfile
        from users.services.achievement_service import (
            check_and_grant_lesson_achievements,
            check_and_grant_xp_achievements,
        )

        user = UserProfile.objects.get(pk=user_id)
        licao = Licao.objects.select_related("capitulo__trilha__variante").get(
            pk=licao_id
        )

        _recalibrar_nivel(user, licao.capitulo.trilha.variante)
        check_and_grant_xp_achievements(user)
        check_and_grant_lesson_achievements(user, licao, accuracy)
        logger.info(
            f"Pós-lição processada com sucesso para usuário {user_id} e lição {licao_id}"
        )
    except Exception as exc:  # noqa: BLE001
        logger.error(
            f"Erro no processamento pós-lição (user: {user_id}, licao: {licao_id}): {exc}"
        )
        raise self.retry(exc=exc)
