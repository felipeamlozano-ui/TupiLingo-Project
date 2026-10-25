#!/usr/bin/env python
"""
importar_versoes_exercicios.py — Importador In-Place de Versões de Exercícios

Atualiza o banco de dados PostgreSQL preservando 100% das Chaves Primárias
de Licao e Exercicio para não afetar o progresso dos usuários (UserLesson).

Uso:
    python backend/scripts/importar_versoes_exercicios.py --arquivo backend/pedagogico/conteudo/tupi_antigo/capitulo_01.json
    python backend/scripts/importar_versoes_exercicios.py --variante tupi_antigo --capitulo 1
"""

import os
import sys
import json
import hashlib
import argparse

if sys.stdout.encoding != 'utf-8':
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass
import django

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.append(BASE_DIR)
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings.development')
django.setup()

from django.db import transaction
from trilha.models import VarianteTupi, Capitulo, Licao, Exercicio, ExercicioVersao


def calcular_hash_superficie(payload: dict) -> str:
    serialized = json.dumps(payload, sort_keys=True, ensure_ascii=False)
    return hashlib.sha256(serialized.encode('utf-8')).hexdigest()[:32]


def importar_arquivo_capitulo(caminho_json: str) -> bool:
    if not os.path.exists(caminho_json):
        print(f"[-] Arquivo não encontrado: {caminho_json}")
        return False

    with open(caminho_json, 'r', encoding='utf-8') as f:
        data = json.load(f)

    variante_cod = data.get('variante')
    cap_num = data.get('capitulo_numero')

    variante_cods = ['tupi', 'tupi_antigo'] if variante_cod in ['tupi', 'tupi_antigo'] else [variante_cod]
    variante = VarianteTupi.objects.filter(codigo__in=variante_cods).first()
    if not variante:
        print(f"[-] Variante '{variante_cod}' não encontrada no banco.")
        return False

    capitulo = Capitulo.objects.filter(trilha__variante=variante, numero=cap_num).first()
    if not capitulo:
        print(f"[-] Capítulo {cap_num} da variante '{variante_cod}' não encontrado no banco.")
        return False

    total_exercicios_atualizados = 0
    total_versoes_criadas = 0

    with transaction.atomic():
        for licao_data in data.get('licoes', []):
            lic_num = licao_data.get('numero')
            licao = Licao.objects.filter(capitulo=capitulo, numero=lic_num).first()
            if not licao:
                print(f"[-] Lição {lic_num} não encontrada para cap {cap_num}.")
                continue

            for ex_data in licao_data.get('exercicios', []):
                ordem = ex_data.get('ordem')
                tipo = ex_data.get('tipo')
                enunciado = ex_data.get('enunciado')
                dificuldade = ex_data.get('dificuldade', 'medio')
                pontos_base = ex_data.get('pontos_base', 10)
                explicacao = ex_data.get('explicacao', '')

                # 1. Encontra ou cria Exercicio preservando PK
                ex_obj = Exercicio.objects.filter(licao=licao, ordem=ordem).first()
                if not ex_obj:
                    ex_obj = Exercicio(licao=licao, ordem=ordem)

                ex_obj.tipo = tipo
                ex_obj.enunciado = enunciado
                ex_obj.dificuldade = dificuldade
                ex_obj.pontos_base = pontos_base
                ex_obj.explicacao = explicacao

                # Atributos específicos do tipo base
                if tipo == 'escolha_multipla':
                    opcoes_raw = ex_data.get('opcoes', [])
                    opcoes_limpas = [
                        op.get('texto') if isinstance(op, dict) else str(op)
                        for op in opcoes_raw
                    ]
                    ex_obj.opcoes = opcoes_limpas
                    resp = ex_data.get('resposta_correta')
                    if isinstance(resp, str) and len(resp) == 1 and resp.upper() in 'ABCD':
                        ex_obj.resposta_correta = ord(resp.upper()) - 65
                    elif isinstance(resp, int):
                        ex_obj.resposta_correta = resp
                    else:
                        ex_obj.resposta_correta = 0

                elif tipo == 'completar':
                    ex_obj.texto_com_lacunas = ex_data.get('texto_com_lacunas', '')
                    ex_obj.respostas_corretas = ex_data.get('respostas_lacunas') or ex_data.get('respostas_corretas') or []

                elif tipo == 'associacao':
                    ex_obj.coluna_esquerda = ex_data.get('coluna_esquerda', [])
                    ex_obj.coluna_direita = ex_data.get('coluna_direita', [])
                    ex_obj.pares_corretos = ex_data.get('pares_corretos', {})

                ex_obj.save()
                total_exercicios_atualizados += 1

                # 2. Popula ExercicioVersao
                versoes = ex_data.get('versoes', [])
                for v in versoes:
                    v_num = v.get('versao_numero')
                    ctx = v.get('contexto_cena', '')
                    v_enunciado = v.get('enunciado', '')
                    v_payload = v.get('payload', {})
                    v_explicacao = v.get('explicacao', explicacao)
                    v_a = float(v.get('param_a', 1.0))
                    v_b = float(v.get('param_b', 0.0))
                    v_c = float(v.get('param_c', 0.25))

                    h_sup = hashlib.sha256(
                        f"{ex_obj.id}_{v_num}_{json.dumps(v_payload, sort_keys=True, ensure_ascii=False)}".encode('utf-8')
                    ).hexdigest()[:32]

                    versao_obj, created = ExercicioVersao.objects.update_or_create(
                        exercicio=ex_obj,
                        versao_numero=v_num,
                        defaults={
                            'tipo': tipo,
                            'contexto_cena': ctx,
                            'enunciado': v_enunciado,
                            'payload': v_payload,
                            'explicacao': v_explicacao,
                            'hash_superficie': h_sup,
                            'param_a': v_a,
                            'param_b': v_b,
                            'param_c': v_c,
                        }
                    )
                    total_versoes_criadas += 1

    print(f"✅ Sucesso: {total_exercicios_atualizados} exercícios e {total_versoes_criadas} versões importados para {variante_cod} Cap {cap_num}!")
    return True


def main():
    parser = argparse.ArgumentParser(description="Importa versões de exercícios para o banco de dados.")
    parser.add_argument('--arquivo', help="Caminho do arquivo JSON do capítulo.")
    parser.add_argument('--variante', choices=['tupi_antigo', 'tupi_revitalizado'])
    parser.add_argument('--capitulo', type=int)

    args = parser.parse_args()

    if args.arquivo:
        importar_arquivo_capitulo(args.arquivo)
    elif args.variante and args.capitulo:
        caminho = os.path.join(BASE_DIR, 'pedagogico', 'conteudo', args.variante, f'capitulo_{args.capitulo:02d}.json')
        importar_arquivo_capitulo(caminho)
    else:
        print("[-] Especifique --arquivo ou (--variante e --capitulo).")
        sys.exit(1)


if __name__ == '__main__':
    main()
