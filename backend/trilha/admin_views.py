"""
Views administrativas para gerenciamento in-app da Trilha:
Capítulos, Lições e Exercícios.

Todas as rotas são protegidas por @staff_required (exclusivas para admin).
"""

import json
import logging

from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods
from users.decorators import staff_required

from .models import (
    Capitulo,
    DificuldadeChoices,
    Exercicio,
    Licao,
    TrilhaHistorica,
    VarianteTupi,
)

logger = logging.getLogger("trilha.admin")


def _parse_body(request):
    try:
        return json.loads(request.body), None
    except (json.JSONDecodeError, ValueError):
        return None, JsonResponse({"error": "JSON inválido."}, status=400)


# ─── Listagem Geral para o Painel Admin ───────────────────────────────────────

@csrf_exempt
@staff_required
@require_http_methods(["GET"])
def admin_listar_dados(request):
    """
    Retorna árvore completa de variantes, capítulos, lições e exercícios
    para que o painel do aplicativo possa listar e selecionar facilmente.
    """
    variantes_data = []
    for v in VarianteTupi.objects.all().order_by("ordem"):
        trilha = getattr(v, "trilha", None)
        capitulos_data = []
        if trilha:
            for cap in trilha.capitulos.all().order_by("numero"):
                licoes_data = []
                for lic in cap.licoes.all().order_by("numero"):
                    exs_data = []
                    for ex in lic.exercicios.all().order_by("ordem"):
                        exs_data.append({
                            "id": ex.id,
                            "tipo": ex.tipo,
                            "enunciado": ex.enunciado,
                            "explicacao": ex.explicacao,
                            "dificuldade": ex.dificuldade,
                            "pontos_base": ex.pontos_base,
                            "ordem": ex.ordem,
                            "opcoes": ex.opcoes,
                            "resposta_correta": ex.resposta_correta,
                            "texto_com_lacunas": ex.texto_com_lacunas,
                            "respostas_corretas": ex.respostas_corretas,
                            "coluna_esquerda": ex.coluna_esquerda,
                            "coluna_direita": ex.coluna_direita,
                            "associacao_correta": ex.associacao_correta,
                        })
                    licoes_data.append({
                        "id": lic.id,
                        "titulo": lic.titulo,
                        "descricao": lic.descricao,
                        "numero": lic.numero,
                        "xp_base": lic.xp_base,
                        "publicada": lic.publicada,
                        "total_exercicios": len(exs_data),
                        "exercicios": exs_data,
                    })
                capitulos_data.append({
                    "id": cap.id,
                    "titulo": cap.titulo,
                    "descricao": cap.descricao,
                    "numero": cap.numero,
                    "publicado": cap.publicado,
                    "total_licoes": len(licoes_data),
                    "licoes": licoes_data,
                })
        variantes_data.append({
            "id": v.id,
            "nome": v.nome,
            "codigo": v.codigo,
            "icone": v.icone,
            "trilha_id": trilha.id if trilha else None,
            "trilha_titulo": trilha.titulo if trilha else "",
            "capitulos": capitulos_data,
        })

    return JsonResponse({"success": True, "variantes": variantes_data})


# ─── CRUD de Capítulos ────────────────────────────────────────────────────────

@csrf_exempt
@staff_required
@require_http_methods(["POST"])
def admin_criar_capitulo(request):
    """
    Cria um novo Capítulo.
    Payload: { "trilha_id": int, "numero": int, "titulo": str, "descricao": str, "publicado": bool }
    """
    body, err = _parse_body(request)
    if err:
        return err

    trilha_id = body.get("trilha_id")
    numero = body.get("numero")
    titulo = (body.get("titulo") or "").strip()
    descricao = (body.get("descricao") or "").strip()
    publicado = bool(body.get("publicado", True))

    if not trilha_id or not numero or not titulo:
        return JsonResponse({"error": "trilha_id, numero e titulo são obrigatórios."}, status=400)

    trilha = TrilhaHistorica.objects.filter(id=trilha_id).first()
    if not trilha:
        return JsonResponse({"error": "Trilha não encontrada."}, status=404)

    if Capitulo.objects.filter(trilha=trilha, numero=numero).exists():
        return JsonResponse({"error": f"Já existe um capítulo com o número {numero} nesta trilha."}, status=400)

    capitulo = Capitulo.objects.create(
        trilha=trilha,
        numero=int(numero),
        titulo=titulo,
        descricao=descricao,
        publicado=publicado,
    )

    logger.info("Admin criou Capítulo: %s (id=%d)", capitulo.titulo, capitulo.id)
    return JsonResponse({
        "success": True,
        "capitulo": {
            "id": capitulo.id,
            "numero": capitulo.numero,
            "titulo": capitulo.titulo,
            "descricao": capitulo.descricao,
            "publicado": capitulo.publicado,
        },
        "message": "Capítulo criado com sucesso!",
    }, status=201)


@csrf_exempt
@staff_required
@require_http_methods(["PUT", "DELETE"])
def admin_gerenciar_capitulo(request, capitulo_id: int):
    """Atualiza ou exclui um Capítulo existente."""
    capitulo = Capitulo.objects.filter(id=capitulo_id).first()
    if not capitulo:
        return JsonResponse({"error": "Capítulo não encontrado."}, status=404)

    if request.method == "DELETE":
        titulo = capitulo.titulo
        capitulo.delete()
        logger.info("Admin excluiu Capítulo id=%d (%s)", capitulo_id, titulo)
        return JsonResponse({"success": True, "message": f"Capítulo '{titulo}' excluído com sucesso."})

    # PUT
    body, err = _parse_body(request)
    if err:
        return err

    titulo = body.get("titulo")
    descricao = body.get("descricao")
    numero = body.get("numero")
    publicado = body.get("publicado")

    if titulo is not None:
        capitulo.titulo = titulo.strip()
    if descricao is not None:
        capitulo.descricao = descricao.strip()
    if numero is not None:
        capitulo.numero = int(numero)
    if publicado is not None:
        capitulo.publicado = bool(publicado)

    capitulo.save()
    logger.info("Admin atualizou Capítulo id=%d", capitulo.id)
    return JsonResponse({
        "success": True,
        "capitulo": {
            "id": capitulo.id,
            "numero": capitulo.numero,
            "titulo": capitulo.titulo,
            "descricao": capitulo.descricao,
            "publicado": capitulo.publicado,
        },
        "message": "Capítulo atualizado com sucesso!",
    })


# ─── CRUD de Lições ───────────────────────────────────────────────────────────

@csrf_exempt
@staff_required
@require_http_methods(["POST"])
def admin_criar_licao(request):
    """
    Cria uma nova Lição em um Capítulo.
    Payload: { "capitulo_id": int, "numero": int, "titulo": str, "descricao": str, "xp_base": int, "publicada": bool }
    """
    body, err = _parse_body(request)
    if err:
        return err

    capitulo_id = body.get("capitulo_id")
    numero = body.get("numero")
    titulo = (body.get("titulo") or "").strip()
    descricao = (body.get("descricao") or "").strip()
    xp_base = int(body.get("xp_base", 20))
    publicada = bool(body.get("publicada", True))

    if not capitulo_id or not numero or not titulo:
        return JsonResponse({"error": "capitulo_id, numero e titulo são obrigatórios."}, status=400)

    capitulo = Capitulo.objects.filter(id=capitulo_id).first()
    if not capitulo:
        return JsonResponse({"error": "Capítulo não encontrado."}, status=404)

    if Licao.objects.filter(capitulo=capitulo, numero=numero).exists():
        return JsonResponse({"error": f"Já existe uma lição com o número {numero} neste capítulo."}, status=400)

    licao = Licao.objects.create(
        capitulo=capitulo,
        numero=int(numero),
        titulo=titulo,
        descricao=descricao,
        xp_base=xp_base,
        publicada=publicada,
    )

    logger.info("Admin criou Lição: %s (id=%d)", licao.titulo, licao.id)
    return JsonResponse({
        "success": True,
        "licao": {
            "id": licao.id,
            "capitulo_id": capitulo.id,
            "numero": licao.numero,
            "titulo": licao.titulo,
            "descricao": licao.descricao,
            "xp_base": licao.xp_base,
            "publicada": licao.publicada,
        },
        "message": "Lição criada com sucesso!",
    }, status=201)


@csrf_exempt
@staff_required
@require_http_methods(["PUT", "DELETE"])
def admin_gerenciar_licao(request, licao_id: int):
    """Atualiza ou exclui uma Lição existente."""
    licao = Licao.objects.filter(id=licao_id).first()
    if not licao:
        return JsonResponse({"error": "Lição não encontrada."}, status=404)

    if request.method == "DELETE":
        titulo = licao.titulo
        licao.delete()
        logger.info("Admin excluiu Lição id=%d (%s)", licao_id, titulo)
        return JsonResponse({"success": True, "message": f"Lição '{titulo}' excluída com sucesso."})

    body, err = _parse_body(request)
    if err:
        return err

    titulo = body.get("titulo")
    descricao = body.get("descricao")
    numero = body.get("numero")
    xp_base = body.get("xp_base")
    publicada = body.get("publicada")

    if titulo is not None:
        licao.titulo = titulo.strip()
    if descricao is not None:
        licao.descricao = descricao.strip()
    if numero is not None:
        licao.numero = int(numero)
    if xp_base is not None:
        licao.xp_base = int(xp_base)
    if publicada is not None:
        licao.publicada = bool(publicada)

    licao.save()
    logger.info("Admin atualizou Lição id=%d", licao.id)
    return JsonResponse({
        "success": True,
        "licao": {
            "id": licao.id,
            "numero": licao.numero,
            "titulo": licao.titulo,
            "descricao": licao.descricao,
            "xp_base": licao.xp_base,
            "publicada": licao.publicada,
        },
        "message": "Lição atualizada com sucesso!",
    })


# ─── CRUD de Exercícios ───────────────────────────────────────────────────────

@csrf_exempt
@staff_required
@require_http_methods(["POST"])
def admin_criar_exercicio(request):
    """
    Cria um Exercício Unificado.
    Suporta tipos: 'escolha_multipla', 'completar', 'associacao'.
    """
    body, err = _parse_body(request)
    if err:
        return err

    licao_id = body.get("licao_id")
    tipo = body.get("tipo")
    enunciado = (body.get("enunciado") or "").strip()
    explicacao = (body.get("explicacao") or "").strip()
    dificuldade = body.get("dificuldade", DificuldadeChoices.FACIL)
    pontos_base = int(body.get("pontos_base", 10))
    ordem = int(body.get("ordem", 0))

    if not licao_id or not tipo or not enunciado:
        return JsonResponse({"error": "licao_id, tipo e enunciado são obrigatórios."}, status=400)

    if tipo not in ["escolha_multipla", "completar", "associacao"]:
        return JsonResponse({"error": f"Tipo '{tipo}' inválido."}, status=400)

    licao = Licao.objects.filter(id=licao_id).first()
    if not licao:
        return JsonResponse({"error": "Lição não encontrada."}, status=404)

    # Se a ordem não foi fornecida, auto-incrementa
    if ordem == 0:
        maior_ordem = Exercicio.objects.filter(licao=licao).count()
        ordem = maior_ordem + 1

    exercicio = Exercicio(
        licao=licao,
        tipo=tipo,
        enunciado=enunciado,
        explicacao=explicacao,
        dificuldade=dificuldade,
        pontos_base=pontos_base,
        ordem=ordem,
    )

    if tipo == "escolha_multipla":
        opcoes = body.get("opcoes")
        resp_correta = body.get("resposta_correta")
        if not isinstance(opcoes, list) or len(opcoes) < 2:
            return JsonResponse({"error": "Múltipla escolha requer lista de ao menos 2 opções."}, status=400)
        if resp_correta is None or not (0 <= int(resp_correta) < len(opcoes)):
            return JsonResponse({"error": "Índice da resposta correta inválido."}, status=400)
        exercicio.opcoes = opcoes
        exercicio.resposta_correta = int(resp_correta)

    elif tipo == "completar":
        texto = body.get("texto_com_lacunas", "")
        respostas = body.get("respostas_corretas", [])
        if "___" not in texto:
            return JsonResponse({"error": "Texto com lacunas deve conter ao menos um '___'."}, status=400)
        if not isinstance(respostas, list) or len(respostas) == 0:
            return JsonResponse({"error": "Informe as respostas corretas das lacunas."}, status=400)
        exercicio.texto_com_lacunas = texto
        exercicio.respostas_corretas = respostas
        exercicio.tolerancia_levenshtein = int(body.get("tolerancia_levenshtein", 2))

    elif tipo == "associacao":
        col_esq = body.get("coluna_esquerda", [])
        col_dir = body.get("coluna_direita", [])
        assoc = body.get("associacao_correta", {})
        if not isinstance(col_esq, list) or not isinstance(col_dir, list) or len(col_esq) < 2:
            return JsonResponse({"error": "Associação requer ao menos 2 itens em cada coluna."}, status=400)
        exercicio.coluna_esquerda = col_esq
        exercicio.coluna_direita = col_dir
        exercicio.associacao_correta = assoc

    exercicio.save()
    logger.info("Admin criou Exercício: id=%d tipo=%s licao=%d", exercicio.id, exercicio.tipo, licao.id)

    return JsonResponse({
        "success": True,
        "exercicio": {
            "id": exercicio.id,
            "licao_id": licao.id,
            "tipo": exercicio.tipo,
            "enunciado": exercicio.enunciado,
            "ordem": exercicio.ordem,
        },
        "message": "Exercício cadastrado com sucesso!",
    }, status=201)


@csrf_exempt
@staff_required
@require_http_methods(["PUT", "DELETE"])
def admin_gerenciar_exercicio(request, exercicio_id: int):
    """Atualiza ou exclui um Exercício existente."""
    exercicio = Exercicio.objects.filter(id=exercicio_id).first()
    if not exercicio:
        return JsonResponse({"error": "Exercício não encontrado."}, status=404)

    if request.method == "DELETE":
        exercicio.delete()
        logger.info("Admin excluiu Exercício id=%d", exercicio_id)
        return JsonResponse({"success": True, "message": "Exercício excluído com sucesso."})

    body, err = _parse_body(request)
    if err:
        return err

    if "enunciado" in body:
        exercicio.enunciado = body["enunciado"].strip()
    if "explicacao" in body:
        exercicio.explicacao = body["explicacao"].strip()
    if "dificuldade" in body:
        exercicio.dificuldade = body["dificuldade"]
    if "pontos_base" in body:
        exercicio.pontos_base = int(body["pontos_base"])
    if "ordem" in body:
        exercicio.ordem = int(body["ordem"])

    if exercicio.tipo == "escolha_multipla":
        if "opcoes" in body:
            exercicio.opcoes = body["opcoes"]
        if "resposta_correta" in body:
            exercicio.resposta_correta = int(body["resposta_correta"])
    elif exercicio.tipo == "completar":
        if "texto_com_lacunas" in body:
            exercicio.texto_com_lacunas = body["texto_com_lacunas"]
        if "respostas_corretas" in body:
            exercicio.respostas_corretas = body["respostas_corretas"]
        if "tolerancia_levenshtein" in body:
            exercicio.tolerancia_levenshtein = int(body["tolerancia_levenshtein"])
    elif exercicio.tipo == "associacao":
        if "coluna_esquerda" in body:
            exercicio.coluna_esquerda = body["coluna_esquerda"]
        if "coluna_direita" in body:
            exercicio.coluna_direita = body["coluna_direita"]
        if "associacao_correta" in body:
            exercicio.associacao_correta = body["associacao_correta"]

    exercicio.save()
    logger.info("Admin atualizou Exercício id=%d", exercicio.id)
    return JsonResponse({
        "success": True,
        "exercicio": {
            "id": exercicio.id,
            "tipo": exercicio.tipo,
            "enunciado": exercicio.enunciado,
            "ordem": exercicio.ordem,
        },
        "message": "Exercício atualizado com sucesso!",
    })
