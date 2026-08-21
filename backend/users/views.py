import json

from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_POST
from django_ratelimit.decorators import ratelimit

from .decorators import supabase_auth_required
from .models import UserProfile


@csrf_exempt
@ratelimit(key='ip', rate='10/m', block=True)
@supabase_auth_required
def check_user(request):
    """
    Verifica se o usuario autenticado via Supabase ja possui
    um perfil completo na base do Django.

    Fluxo:
    1. O decorator @supabase_auth_required ja validou o JWT.
    2. Extraimos o 'sub' (supabase_uid) do payload do token.
    3. Consultamos UserProfile para verificar se existe cadastro.
    4. Retornamos {"exists": true/false} para o frontend decidir
       se redireciona para /home ou /register.
    """
    email = request.user_data.get('email')
    user_id = request.user_data.get('sub')  # UUID do Supabase Auth

    # Consulta real ao banco de dados
    user = UserProfile.objects.filter(supabase_uid=user_id).first()
    exists = user is not None
    tupi_level = user.tupi_level if user else ""

    return JsonResponse({
        "status": "Autenticado com sucesso",
        "email": email,
        "exists": exists,
        "tupi_level": tupi_level,
    })


@csrf_exempt
@require_POST
@ratelimit(key='ip', rate='10/m', block=True)
@supabase_auth_required
def register_user(request):
    """
    Cria o perfil do usuario no banco Django apos o onboarding.

    Fluxo:
    1. O usuario fez login via Google (Supabase Auth) e foi
       redirecionado para o RegisterScreen (porque check_user
       retornou exists=false).
    2. Apos preencher nome, source e nivel, o Flutter envia
       esses dados para ca.
    3. Criamos o UserProfile vinculando ao supabase_uid.
    4. Retornamos sucesso para o frontend navegar para /home.
    """
    user_id = request.user_data.get('sub')
    email = request.user_data.get('email', '')

    # Verifica se ja existe (protecao contra dupla submissao)
    if UserProfile.objects.filter(supabase_uid=user_id).exists():
        return JsonResponse({
            "status": "Usuario ja registrado",
            "created": False,
        })

    # Parseia o body JSON enviado pelo Flutter
    try:
        body = json.loads(request.body)
    except (json.JSONDecodeError, ValueError):
        return JsonResponse({'error': 'Corpo da requisicao invalido'}, status=400)

    name = body.get('name', '').strip()
    source = body.get('source', '').strip()
    tupi_level = body.get('tupi_level', '').strip()

    # Validacao: nome e obrigatorio
    if not name:
        return JsonResponse({'error': 'O campo "name" e obrigatorio'}, status=400)

    # Cria o perfil no banco
    UserProfile.objects.create(
        supabase_uid=user_id,
        email=email,
        name=name,
        source=source,
        tupi_level=tupi_level,
    )

    return JsonResponse({
        "status": "Cadastro realizado com sucesso",
        "created": True,
    }, status=201)

@csrf_exempt
@require_POST
@supabase_auth_required
def update_level(request):
    user_id = request.user_data.get('sub')
    try:
        body = json.loads(request.body)
        new_level = str(body.get('level', ''))
        if not new_level:
            return JsonResponse({'error': 'Level is required'}, status=400)
            
        user = UserProfile.objects.filter(supabase_uid=user_id).first()
        if user:
            user.tupi_level = new_level
            user.save()
            return JsonResponse({"status": "Nível atualizado com sucesso"})
        return JsonResponse({'error': 'Usuário não encontrado'}, status=404)
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)