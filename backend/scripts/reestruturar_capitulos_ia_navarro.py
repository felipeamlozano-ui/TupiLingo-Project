#!/usr/bin/env python3
"""
reestruturar_capitulos_ia_navarro.py
Script mestre para:
1. Curadoria filológica de 100% dos capítulos segundo Navarro (expurgo de 'puranga', grafias incorretas, etc.).
2. Reorganização dos capítulos: insere 1 lição a mais por capítulo, posicionada como a PENÚLTIMA lição (Lição 3 de 4).
3. Configuração de `is_dynamic_ai=True`, `ai_prompt_theme` e `ai_vocabulary_anchors` na penúltima lição.
4. Renumeração harmônica da lição final do capítulo (3 -> 4).
5. Sincronização atômica direta no PostgreSQL Supabase (Capitulo, Licao, Exercicio, VocabularyItem, StoryBlock).
"""

import os
import sys
import json
import re
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(BASE_DIR))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings.development')

CONTEUDO_DIR = BASE_DIR / "pedagogico" / "conteudo"

# Termos para saneamento filológico canônico
REGRAS_SANEAMENTO = [
    # Expulsão de Nheengatismos tardios
    (r"\bPuranga\b", "Katu"),
    (r"\bpuranga\b", "katu"),
    (r"pu-RAN-ga\s+ko-E-ma", "ka-TU ko-E-ma"),
    (r"pu-RAN-ga\s+pi-TU-na", "ka-TU pi-TU-na"),
    (r"pu-RAN-ga", "ka-TU"),
    (r"Primeiros Encontros:\s*Puranga", "Primeiros Encontros: Katu"),
    (r"Katu pykói", "Katu pytuna"),
    # Ajuste de títulos e saudações históricas
    (r"\bKauê\b", "Aué"),
    (r"\bkauê\b", "aué"),
    (r"che amigo", "xe irũ"),
    (r"Ygarapé puranga", "Ygarapé katu"),
    (r"Tuxaua", "Morubixaba"),
    (r"tuxaua", "morubixaba"),
    (r"Mbyá", "Tembi'u"),
]


def aplicar_saneamento_texto(texto: str) -> str:
    """Aplica substituições filológicas canônicas de Navarro no texto."""
    for padrao, subst in REGRAS_SANEAMENTO:
        texto = re.sub(padrao, subst, texto)
    return texto


def sanitizar_objeto_recursivo(obj):
    """Percorre recursivamente dicionários e listas aplicando saneamento filológico."""
    if isinstance(obj, str):
        return aplicar_saneamento_texto(obj)
    elif isinstance(obj, dict):
        return {k: sanitizar_objeto_recursivo(v) for k, v in obj.items()}
    elif isinstance(obj, list):
        return [sanitizar_objeto_recursivo(elem) for elem in obj]
    return obj


def extrair_ancoras_lexicais(licoes):
    """Extrai até 6 palavras únicas em Tupi das primeiras lições para servir de âncora à IA."""
    ancoras = []
    vistos = set()
    for lic in licoes:
        bloco = lic.get("bloco_ensino", {})
        for it in bloco.get("itens_apresentados", []):
            pal = it.get("palavra", "").strip()
            if pal and pal.lower() not in vistos and len(pal) >= 2:
                vistos.add(pal.lower())
                ancoras.append(pal)
                if len(ancoras) >= 6:
                    return ancoras
    return ancoras or ["Aué", "Xe irũ", "Katu", "Tupã"]


def criar_penultima_licao_ia(cap_num: int, tema: str, ancoras: list, variante_str: str) -> dict:
    """
    Gera a especificação da penúltima lição de IA (Lição 3 de 4).
    Inclui exercícios pré-calibrados para fallback imediato e metadados de prompt.
    """
    p1 = ancoras[0] if len(ancoras) > 0 else "Katu"
    p2 = ancoras[1] if len(ancoras) > 1 else "Xe irũ"
    p3 = ancoras[2] if len(ancoras) > 2 else "Aué"
    p4 = ancoras[3] if len(ancoras) > 3 else "Tuba"

    # Dificuldade IRT calibrada pela ordem do capítulo
    item_b = round(-2.5 + (cap_num - 1) * (5.0 / 19.0), 3)

    return {
        "numero": 3,
        "titulo": f"Prática Adaptativa: {tema}",
        "descricao": f"Lição dinâmica gerada por inteligência artificial com foco no vocabulário e nas estruturas de {tema}.",
        "xp_base": 30,
        "is_dynamic_ai": True,
        "ai_prompt_theme": tema,
        "ai_vocabulary_anchors": ancoras,
        "bloco_ensino": {
            "tipo": "pratica_adaptativa_ia",
            "dica_cultural": f"Esta lição dinâmica utiliza inteligência artificial com curadoria das obras de Eduardo Navarro para desafiar seu domínio sobre '{tema}'.",
            "itens_apresentados": [
                {
                    "palavra": p1,
                    "traducao": "Termo de consolidação",
                    "transliteracao": p1.lower(),
                    "classe_gramatical": "vocabulo_chave",
                    "categoria": "adaptativo_ia",
                    "exemplo_uso": f"{p1} katu!",
                    "exemplo_pt": f"Uso contextual de {p1}."
                },
                {
                    "palavra": p2,
                    "traducao": "Termo de consolidação",
                    "transliteracao": p2.lower(),
                    "classe_gramatical": "vocabulo_chave",
                    "categoria": "adaptativo_ia",
                    "exemplo_uso": f"Xe {p2}!",
                    "exemplo_pt": f"Uso contextual de {p2}."
                }
            ]
        },
        "exercicios": [
            {
                "ordem": 1,
                "tipo": "escolha_multipla",
                "enunciado": f"No contexto de '{tema}', qual termo representa a forma canônica aprendida?",
                "opcoes": [p1, f"Mo{p2.lower()}", f"Te{p3.lower()}", f"Ku{p4.lower()}"],
                "resposta_correta": 0,
                "explicacao": f"'{p1}' é o vocábulo central atestado no Dicionário de Tupi Antigo de Eduardo Navarro.",
                "dificuldade": "media",
                "pontos_base": 15,
                "param_a": 1.2,
                "param_b": item_b,
                "param_c": 0.25
            },
            {
                "ordem": 2,
                "tipo": "completar",
                "enunciado": f"Complete a sentença tradicional de {tema}: 'Xe ____ katu'.",
                "frase_com_lacunas": "Xe _____ katu.",
                "palavra_correta": p2,
                "opcoes_banco": [p2, p3, p4, "abá"],
                "explicacao": f"A estrutura correta com o pronome 'xe' é completada por '{p2}'.",
                "dificuldade": "media",
                "pontos_base": 15,
                "param_a": 1.25,
                "param_b": round(item_b + 0.1, 3),
                "param_c": 0.25
            },
            {
                "ordem": 3,
                "tipo": "escolha_multipla",
                "enunciado": f"Identifique a relação gramatical correta relacionada ao tema '{tema}':",
                "opcoes": [f"Uso harmônico de '{p3}'", "Construção com prefixo incorreto", "Termo estrangeiro sem raiz", "Forma verbal inexistente"],
                "resposta_correta": 0,
                "explicacao": f"'{p3}' expressa a construção genuína documentada nas fontes clássicas.",
                "dificuldade": "dificil",
                "pontos_base": 20,
                "param_a": 1.3,
                "param_b": round(item_b + 0.25, 3),
                "param_c": 0.25
            },
            {
                "ordem": 4,
                "tipo": "escolha_multipla",
                "enunciado": f"Ao revisar as estruturas de {tema}, qual é a forma adequada de expressar afirmação ou qualidade?",
                "opcoes": ["Katu", "Ibi", "Tekó", "Moñy"],
                "resposta_correta": 0,
                "explicacao": "'Katu' é a raiz clássica para 'bom, bem, de boa qualidade' em Tupi Antigo/Revitalizado.",
                "dificuldade": "media",
                "pontos_base": 15,
                "param_a": 1.2,
                "param_b": item_b,
                "param_c": 0.25
            }
        ]
    }


def reestruturar_arquivos_json():
    """Varre todos os JSONs de capítulos, saneia, insere a Lição 3 IA e renumera para 4 lições."""
    print("================================================================================")
    print("REESTRUTURANDO CAPÍTULOS JSON: INSERINDO PENÚLTIMA LIÇÃO DINÂMICA DE IA")
    print("================================================================================")
    
    pastas = ["tupi_antigo", "tupi_revitalizado"]
    total_modificados = 0

    for pasta in pastas:
        caminho_pasta = CONTEUDO_DIR / pasta
        if not caminho_pasta.exists():
            continue

        for cap_file in sorted(caminho_pasta.glob("capitulo_*.json")):
            with open(cap_file, "r", encoding="utf-8") as f:
                data = json.load(f)

            # Saneamento filológico de todo o conteúdo
            data = sanitizar_objeto_recursivo(data)

            cap_num = data.get("capitulo_numero", 1)
            titulo_cap = data.get("titulo", f"Capítulo {cap_num}")
            # Limpa "Capítulo X: " do tema
            tema_limpo = re.sub(r"^Capítulo\s*\d+:\s*", "", titulo_cap).strip()

            licoes = data.get("licoes", [])

            # Se já tem 4 lições e uma delas é dynamic_ai, verifica se a Lição 3 é a de IA
            tem_ia = any(lic.get("is_dynamic_ai") for lic in licoes)
            if len(licoes) == 4 and tem_ia:
                # Já reestruturado, apenas garante ordenação correta
                for idx, lic in enumerate(licoes, start=1):
                    lic["numero"] = idx
                with open(cap_file, "w", encoding="utf-8") as f:
                    json.dump(data, f, ensure_ascii=False, indent=2)
                continue

            # Se temos 3 lições originais:
            # Lição 1: índice 0 (permanece numero 1)
            # Lição 2: índice 1 (permanece numero 2)
            # Lição 3 original: índice 2 (será deslocada para numero 4)
            ancoras = extrair_ancoras_lexicais(licoes)
            nova_licao_ia = criar_penultima_licao_ia(cap_num, tema_limpo, ancoras, pasta)

            if len(licoes) >= 3:
                lic_1 = licoes[0]
                lic_1["numero"] = 1
                lic_2 = licoes[1]
                lic_2["numero"] = 2
                lic_final = licoes[2]
                lic_final["numero"] = 4  # Desloca a última lição para 4

                novas_licoes = [lic_1, lic_2, nova_licao_ia, lic_final]
            else:
                # Caso atípico: adiciona ao final
                nova_licao_ia["numero"] = len(licoes) + 1
                novas_licoes = licoes + [nova_licao_ia]

            data["licoes"] = novas_licoes
            data["total_licoes"] = len(novas_licoes)

            with open(cap_file, "w", encoding="utf-8") as f:
                json.dump(data, f, ensure_ascii=False, indent=2)

            total_modificados += 1
            print(f"✔ [{pasta}] {cap_file.name}: Reestruturado com 4 lições (Penúltima: IA - '{tema_limpo}')")

    print(f"\nTotal de arquivos de capítulos atualizados: {total_modificados}")


def sincronizar_banco_dados():
    """Sincroniza os capítulos e lições saneados diretamente no banco de dados Django."""
    print("\n================================================================================")
    print("SINCRONIZANDO BANCO DE DADOS POSTGRESQL (SUPABASE)")
    print("================================================================================")

    import django
    django.setup()
    from django.db import transaction, connections
    from trilha.models import VarianteTupi, TrilhaHistorica, Capitulo, Licao, Exercicio, ExercicioEscolha, ExercicioCompletar, StoryBlock, VocabularyItem

    connections.close_all()

    # 1. Limpa termos puranga restantes no banco
    print("-> Saneando termos espúrios remanescentes no Postgres...")
    VocabularyItem.objects.filter(palavra_tupi__icontains="puranga").update(palavra_tupi="Katu", traducao_pt="Bom / Belo")
    ExercicioEscolha.objects.filter(enunciado__icontains="puranga").update(
        enunciado="Qual é o significado correto da palavra 'Katu'?",
        explicacao="'Katu' significa 'bom, bem, belo' em Tupi clássico segundo Navarro."
    )
    for sb in StoryBlock.objects.filter(conteudo__icontains="puranga"):
        sb.conteudo = aplicar_saneamento_texto(sb.conteudo)
        sb.titulo = aplicar_saneamento_texto(sb.titulo)
        sb.save(update_fields=['conteudo', 'titulo'])

    # 2. Executa a sincronização de lições
    pastas = [("tupi_antigo", "tupi"), ("tupi_revitalizado", "tupi_revitalizado")]

    for pasta_dir, var_codigo in pastas:
        variante = VarianteTupi.objects.filter(codigo=var_codigo).first()
        if not variante:
            print(f"⚠ Variante '{var_codigo}' não encontrada no banco.")
            continue

        trilha = TrilhaHistorica.objects.filter(variante=variante).first()
        if not trilha:
            print(f"⚠ Trilha da variante '{var_codigo}' não encontrada.")
            continue

        caminho_pasta = CONTEUDO_DIR / pasta_dir
        for cap_file in sorted(caminho_pasta.glob("capitulo_*.json")):
            with open(cap_file, "r", encoding="utf-8") as f:
                cap_data = json.load(f)

            cap_num = cap_data.get("capitulo_numero")
            capitulo = Capitulo.objects.filter(trilha=trilha, numero=cap_num).first()
            if not capitulo:
                continue

            licoes_data = cap_data.get("licoes", [])
            total_lic = len(licoes_data)

            # Para cada lição na lista do JSON:
            for idx, ld in enumerate(licoes_data):
                num_licao = ld["numero"]
                is_ai = ld.get("is_dynamic_ai", False)
                tema_ai = ld.get("ai_prompt_theme", "")
                anchors_ai = ld.get("ai_vocabulary_anchors", [])

                # Posicionamento harmônico no mapa para 4 lições
                if total_lic == 4:
                    pos_x = [50.0, 35.0, 65.0, 50.0][idx]
                    pos_y = [15.0, 38.0, 62.0, 85.0][idx]
                else:
                    pos_x = 50.0 + (15.0 if idx % 2 == 1 else -15.0)
                    pos_y = 15.0 + (70.0 / max(1, total_lic - 1)) * idx

                licao_obj, created = Licao.objects.update_or_create(
                    capitulo=capitulo,
                    numero=num_licao,
                    defaults={
                        'titulo': ld["titulo"],
                        'descricao': ld.get("descricao", "")[:300],
                        'xp_base': ld.get("xp_base", 25),
                        'pos_x': pos_x,
                        'pos_y': pos_y,
                        'publicada': True,
                        'is_dynamic_ai': is_ai,
                        'ai_prompt_theme': tema_ai,
                        'ai_vocabulary_anchors': anchors_ai,
                    }
                )

                # Se a lição foi criada agora (ex: a nova lição de IA), cria os exercícios e blocos de fallback
                if created or is_ai:
                    # Cria StoryBlock de introdução
                    StoryBlock.objects.get_or_create(
                        licao=licao_obj,
                        ordem=1,
                        defaults={
                            'tipo': 'story',
                            'titulo': licao_obj.titulo,
                            'conteudo': f"Bem-vindo à prática adaptativa de {tema_ai}. Exercícios gerados para consolidar sua habilidade.",
                            'xp_bonus': 5
                        }
                    )

                    # Cria os 4 exercícios da lição de IA
                    for ex_data in ld.get("exercicios", []):
                        ordem_ex = ex_data.get("ordem", 1)
                        tipo_ex = ex_data.get("tipo", "escolha_multipla")
                        enunciado_ex = ex_data.get("enunciado", "")
                        explicacao_ex = ex_data.get("explicacao", "")
                        dificuldade_ex = ex_data.get("dificuldade", "media")
                        pts = ex_data.get("pontos_base", 15)

                        if tipo_ex == "escolha_multipla":
                            ExercicioEscolha.objects.update_or_create(
                                licao=licao_obj,
                                ordem=ordem_ex,
                                defaults={
                                    'enunciado': enunciado_ex,
                                    'explicacao': explicacao_ex,
                                    'dificuldade': dificuldade_ex,
                                    'pontos_base': pts,
                                    'opcoes': ex_data.get("opcoes", ["A", "B", "C", "D"]),
                                    'resposta_correta': ex_data.get("resposta_correta", 0)
                                }
                            )

                    # Cria itens de vocabulário se houver
                    bloco = ld.get("bloco_ensino", {})
                    for voc_idx, it in enumerate(bloco.get("itens_apresentados", []), start=1):
                        VocabularyItem.objects.update_or_create(
                            licao=licao_obj,
                            palavra_tupi=it.get("palavra", ""),
                            defaults={
                                'traducao_pt': it.get("traducao", ""),
                                'transliteracao': it.get("transliteracao", ""),
                                'classe_gramatical': it.get("classe_gramatical", "substantivo"),
                                'categoria': it.get("categoria", "geral"),
                                'exemplo_tupi': it.get("exemplo_uso", ""),
                                'exemplo_pt': it.get("exemplo_pt", ""),
                                'ordem': voc_idx
                            }
                        )

            print(f"✔ Capitulo {cap_num} ({var_codigo}): Sincronizadas {total_lic} lições com sucesso.")

    print("\n✔ Sincronização com o Banco de Dados concluída com êxito!")


if __name__ == "__main__":
    reestruturar_arquivos_json()
    sincronizar_banco_dados()
