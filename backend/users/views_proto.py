"""
views_proto.py - Endpoints com suporte nativo a Protocol Buffers (Binary Serialization).
Permite negociação de conteúdo via header Accept / Content-Type:
- application/x-protobuf: serialização binária compacta ultra-rápida
- application/json: fallback padrão REST
"""
import logging
from django.http import HttpResponse, JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_GET
from django_ratelimit.decorators import ratelimit

from proto_gen import tupilingo_pb2
from users.decorators import supabase_auth_required
from users.models import UserProfile

logger = logging.getLogger("users.views_proto")


@csrf_exempt
@ratelimit(key="ip", rate="30/m", block=True)
@supabase_auth_required
@require_GET
def get_user_profile_proto(request):
    """
    Retorna o perfil do usuário em formato Protocol Buffers binário ou JSON.
    Negociação via header:
      Accept: application/x-protobuf
    """
    user_uid = request.user_data.get("sub")
    user = UserProfile.objects.select_related("variante_ativa").filter(supabase_uid=user_uid).first()

    if not user:
        return JsonResponse({"error": "Perfil não encontrado"}, status=404)

    accept_header = request.headers.get("Accept", "")
    wants_protobuf = "application/x-protobuf" in accept_header or "application/octet-stream" in accept_header

    variante_codigo = user.variante_ativa.codigo if user.variante_ativa else ""
    variante_nome = user.variante_ativa.nome if user.variante_ativa else ""

    if wants_protobuf:
        # Serialização nativa em Protobuf
        pb_profile = tupilingo_pb2.UserProfileMessage(
            supabase_uid=str(user.supabase_uid),
            email=user.email,
            name=user.name,
            xp_total=user.xp_total,
            streak_dias=user.streak_dias,
            nivel_atual=user.nivel_atual,
            conchas=user.conchas,
            variante_ativa_codigo=variante_codigo,
            variante_ativa_nome=variante_nome,
            ofensiva_ativa=user.ofensiva_ativa,
        )
        binary_payload = pb_profile.SerializeToString()
        response = HttpResponse(binary_payload, content_type="application/x-protobuf")
        response["X-Serialization-Format"] = "protobuf-v3"
        response["Content-Length"] = str(len(binary_payload))
        return response

    # Fallback JSON padrão
    return JsonResponse({
        "supabase_uid": str(user.supabase_uid),
        "email": user.email,
        "name": user.name,
        "xp_total": user.xp_total,
        "streak_dias": user.streak_dias,
        "nivel_atual": user.nivel_atual,
        "conchas": user.conchas,
        "variante_ativa_codigo": variante_codigo,
        "variante_ativa_nome": variante_nome,
        "ofensiva_ativa": user.ofensiva_ativa,
    })
