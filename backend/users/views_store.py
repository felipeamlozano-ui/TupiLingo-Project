"""
Views de API da Loja de Conchas (Demanda 2).
Oferece endpoints protegidos com autenticação JWT e assinaturas HMAC-SHA256
para catálogo, compra atômica com trava select_for_update() e equipagem de cosméticos.
"""

import json
import logging
import time
from django.db import transaction
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_GET, require_POST
from django_ratelimit.decorators import ratelimit

from .decorators import supabase_auth_required
from .models import UserProfile, UserCosmetic, CosmeticPurchaseAudit
from .store_catalog import STORE_CATALOG, get_item_by_id
from .store_crypto import sign_store_state, sign_purchase_receipt

logger = logging.getLogger('users.store')

# Padrões gratuitos que todo usuário possui desbloqueado
DEFAULT_UNLOCKED_ITEMS = {
    'theme_floresta_jade': 'theme',
    'avatar_arara': 'avatar',
    'frame_madeira': 'frame',
}


@csrf_exempt
@require_GET
@ratelimit(key='ip', rate='60/m', block=True)
@supabase_auth_required
def get_store_catalog(request):
    """
    Retorna o catálogo completo da Loja de Conchas, o saldo atual do usuário,
    os itens já desbloqueados, os itens equipados e a assinatura digital do estado.
    """
    user_id = request.user_data.get('sub')
    user = UserProfile.objects.filter(supabase_uid=user_id).first()
    if not user:
        return JsonResponse({'error': 'Perfil de usuário não encontrado'}, status=404)

    # Coleta cosméticos já desbloqueados
    user_cosmetics = UserCosmetic.objects.filter(user=user)
    unlocked_ids = set(user_cosmetics.values_list('item_id', flat=True))
    unlocked_ids.update(DEFAULT_UNLOCKED_ITEMS.keys())

    # Identifica itens atualmente equipados
    equipped_map = {}
    for uc in user_cosmetics.filter(is_equipped=True):
        equipped_map[uc.item_type] = uc.item_id

    # Se não houver nada equipado em alguma categoria, aplica o padrão
    if 'theme' not in equipped_map:
        equipped_map['theme'] = 'theme_floresta_jade'
    if 'avatar' not in equipped_map:
        equipped_map['avatar'] = 'avatar_arara'
    if 'frame' not in equipped_map:
        equipped_map['frame'] = 'frame_madeira'

    now_ts = int(time.time())
    conchas_val = getattr(user, 'conchas', 0)
    signature = sign_store_state(user.id, conchas_val, now_ts)

    return JsonResponse({
        'success': True,
        'catalog': STORE_CATALOG,
        'user_balance': {
            'conchas': conchas_val,
            'xp_total': user.xp_total,
        },
        'unlocked_items': list(unlocked_ids),
        'equipped_items': equipped_map,
        'security': {
            'timestamp': now_ts,
            'signature': signature,
        }
    })


@csrf_exempt
@require_POST
@ratelimit(key='ip', rate='30/m', block=True)
@supabase_auth_required
def purchase_cosmetic(request):
    """
    Executa a compra de um item da loja utilizando conchas com garantia de atomicidade,
    trava de linha no banco (select_for_update) e emissão de recibo criptográfico HMAC.
    """
    user_id = request.user_data.get('sub')
    try:
        data = json.loads(request.body.decode('utf-8'))
    except Exception:
        return JsonResponse({'error': 'JSON inválido'}, status=400)

    item_id = data.get('item_id')
    if not item_id:
        return JsonResponse({'error': 'item_id é obrigatório'}, status=400)

    item = get_item_by_id(item_id)
    if not item:
        return JsonResponse({'error': 'Item não encontrado no catálogo'}, status=404)

    price = item.get('price', 0)

    with transaction.atomic():
        user = UserProfile.objects.select_for_update().filter(supabase_uid=user_id).first()
        if not user:
            return JsonResponse({'error': 'Usuário não encontrado'}, status=404)

        # Checa se já possui o item
        if item_id in DEFAULT_UNLOCKED_ITEMS or UserCosmetic.objects.filter(user=user, item_id=item_id).exists():
            return JsonResponse({
                'success': True,
                'message': 'Você já possui este item desbloqueado!',
                'already_unlocked': True,
                'item_id': item_id,
                'conchas': user.conchas,
            })

        # Verifica saldo
        if user.conchas < price:
            return JsonResponse({
                'error': f'Saldo insuficiente de conchas! Você tem {user.conchas}, mas o item custa {price}.',
                'current_conchas': user.conchas,
                'required_conchas': price,
            }, status=400)

        # Deduz saldo atomicamente
        balance_before = user.conchas
        user.conchas -= price
        user.save(update_fields=['conchas', 'updated_at'])
        balance_after = user.conchas

        # Registra desbloqueio
        user_cosmetic = UserCosmetic.objects.create(
            user=user,
            item_id=item_id,
            item_type=item['type'],
            is_equipped=False,
        )

        now_ts = int(time.time())
        receipt_sig = sign_purchase_receipt(user.id, item_id, price, balance_after, now_ts)

        # Registra auditoria
        CosmeticPurchaseAudit.objects.create(
            user=user,
            item_id=item_id,
            item_price=price,
            balance_before=balance_before,
            balance_after=balance_after,
            hmac_receipt=receipt_sig,
        )

        logger.info(
            "Compra confirmada: User %s (ID %s) comprou %s por %s conchas. Novo saldo: %s",
            user.name, user.id, item_id, price, balance_after
        )

        new_state_sig = sign_store_state(user.id, balance_after, now_ts)

        return JsonResponse({
            'success': True,
            'message': f'"{item["name"]}" desbloqueado com sucesso!',
            'item_id': item_id,
            'price_paid': price,
            'new_balance': balance_after,
            'receipt': {
                'timestamp': now_ts,
                'receipt_signature': receipt_sig,
                'state_signature': new_state_sig,
            }
        })


@csrf_exempt
@require_POST
@ratelimit(key='ip', rate='40/m', block=True)
@supabase_auth_required
def equip_cosmetic(request):
    """
    Equipa um tema, avatar ou moldura desbloqueado pelo usuário.
    """
    user_id = request.user_data.get('sub')
    try:
        data = json.loads(request.body.decode('utf-8'))
    except Exception:
        return JsonResponse({'error': 'JSON inválido'}, status=400)

    item_id = data.get('item_id')
    if not item_id:
        return JsonResponse({'error': 'item_id é obrigatório'}, status=400)

    item = get_item_by_id(item_id)
    if not item:
        return JsonResponse({'error': 'Item não encontrado no catálogo'}, status=404)

    item_type = item['type']
    if item_type == 'special_lesson':
        return JsonResponse({'error': 'Lições especiais não são equipáveis (são acessadas diretamente)'}, status=400)

    user = UserProfile.objects.filter(supabase_uid=user_id).first()
    if not user:
        return JsonResponse({'error': 'Usuário não encontrado'}, status=404)

    # Verifica se o item está desbloqueado
    is_unlocked = (item_id in DEFAULT_UNLOCKED_ITEMS) or UserCosmetic.objects.filter(user=user, item_id=item_id).exists()
    if not is_unlocked:
        return JsonResponse({'error': 'Você precisa desbloquear este item antes de equipá-lo!'}, status=403)

    with transaction.atomic():
        # Desequipa item anterior do mesmo tipo
        UserCosmetic.objects.filter(user=user, item_type=item_type).update(is_equipped=False)

        # Equipa o novo item
        UserCosmetic.objects.update_or_create(
            user=user,
            item_id=item_id,
            defaults={'item_type': item_type, 'is_equipped': True}
        )

    logger.info("User %s equipou %s (%s)", user.name, item_id, item_type)

    return JsonResponse({
        'success': True,
        'message': f'"{item["name"]}" equipado com sucesso!',
        'equipped_item_id': item_id,
        'item_type': item_type,
    })
