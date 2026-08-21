import jwt
from jwt import PyJWKClient
from django.http import JsonResponse
from functools import wraps
from decouple import config

# 1. URL real do seu projeto TupiLingo
URL_SUPABASE = config('SUPABASE_URL') 

# 2. Endpoint correto com a extensão .well-known
jwks_url = f"{URL_SUPABASE}/auth/v1/.well-known/jwks.json"
jwks_client = PyJWKClient(jwks_url, cache_keys=True)

def supabase_auth_required(view_func):
    @wraps(view_func)
    def wrapper(request, *args, **kwargs):
        auth_header = request.headers.get('Authorization')
        if not auth_header or not auth_header.startswith('Bearer '):
            return JsonResponse({'error': 'Token ausente'}, status=401)
        
        token = auth_header.split(' ')[1]
        try:
            # Pega a chave correta diretamente do Supabase
            signing_key = jwks_client.get_signing_key_from_jwt(token)
            
            # Decodifica usando a chave pública
            # 3. MUDANÇA: Adicionado o audience e issuer
            payload = jwt.decode(
                token, 
                signing_key.key, 
                algorithms=["RS256", "ES256"],
                audience="authenticated",
                issuer=f"{URL_SUPABASE}/auth/v1",
                leeway=60
            )
            
            request.user_data = payload
        except Exception as e:
            # Isso vai imprimir o erro real no terminal do Django
            print(f"DEBUG ERRO JWT: {str(e)}") 
            return JsonResponse({'error': 'Token inválido ou expirado'}, status=401)
            
        return view_func(request, *args, **kwargs)
    return wrapper