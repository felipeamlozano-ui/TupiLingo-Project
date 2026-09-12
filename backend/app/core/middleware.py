"""
Middleware de Segurança e Blindagem de Interface do TupiLingo.

Garante que nenhuma exceção técnica, erro interno do banco de dados,
rastros de SQL ou nomes de infraestrutura (Supabase, pg_trgm, psycopg2, etc.)
vazem para as telas do aplicativo móvel ou respostas da API.
Todas as falhas técnicas são registradas detalhadamente nos logs do servidor
e convertidas em mensagens lúdicas e acolhedoras para o aluno da aldeia.
"""

import json
import logging
from django.http import JsonResponse
from django.utils.deprecation import MiddlewareMixin

logger = logging.getLogger("app.core.middleware")

# Palavras e termos técnicos proibidos na UI
TECHNICAL_TERMS_BLACKLIST = [
    "supabase",
    "pg_trgm",
    "postgresql",
    "psycopg2",
    "postgres",
    "sql",
    "operationalerror",
    "programmingerror",
    "integrityerror",
    "traceback",
    "syntax error",
    "exception",
]

FRIENDLY_VILLAGE_ERROR = "Nossa aldeia perdeu a conexão com os espíritos da floresta temporariamente. Suas respostas continuam salvas! Tente novamente em instantes."


class FriendlyExceptionMiddleware(MiddlewareMixin):
    """
    Intercepta exceções não tratadas e respostas com status de erro para
    sanitizar mensagens técnicas e garantir uma experiência lúdica e imersiva.
    """

    def process_exception(self, request, exception):
        """Captura exceções lançadas durante o processamento de uma view."""
        # Registra o erro técnico detalhado internamente para diagnóstico dos desenvolvedores
        logger.error(
            "[BlindagemUI] Exceção técnica interceptada em %s: %s",
            request.path,
            exception,
            exc_info=True,
        )

        # Retorna JSON lúdico e limpo para rotas de API
        if request.path.startswith("/api/"):
            return JsonResponse(
                {
                    "success": False,
                    "error": FRIENDLY_VILLAGE_ERROR,
                    "code": "ALDEIA_OFFLINE",
                },
                status=500,
            )

        return None

    def process_response(self, request, response):
        """Sanitiza respostas HTTP 400/500 JSON que possam conter mensagens técnicas."""
        if request.path.startswith("/api/") and response.status_code >= 400:
            try:
                # Se for JSON, verifica se contém jargão técnico
                content_type = response.get("Content-Type", "")
                if "application/json" in content_type:
                    data = json.loads(response.content.decode("utf-8", errors="ignore"))
                    
                    if isinstance(data, dict):
                        error_msg = str(data.get("error", "") or data.get("detail", "") or data.get("message", ""))
                        lower_msg = error_msg.lower()
                        
                        # Se contiver qualquer termo da blacklist ou for um 500 genérico
                        if any(term in lower_msg for term in TECHNICAL_TERMS_BLACKLIST) or response.status_code >= 500:
                            data["error"] = FRIENDLY_VILLAGE_ERROR
                            if "message" in data:
                                data["message"] = FRIENDLY_VILLAGE_ERROR
                            if "detail" in data:
                                data["detail"] = FRIENDLY_VILLAGE_ERROR
                            data["code"] = "ALDEIA_OFFLINE"
                            response.content = json.dumps(data).encode("utf-8")
            except Exception as e:
                logger.warning("[BlindagemUI] Falha ao sanitizar response: %s", e)

        return response
