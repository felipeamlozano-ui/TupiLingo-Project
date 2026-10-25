#!/usr/bin/env python
"""
briefing_licao.py — Dossiê Pedagógico e Filológico para Autoria 1 a 1 de Questões

Uso:
    python backend/scripts/briefing_licao.py --variante tupi_antigo --capitulo 1 --licao 1
    python backend/scripts/briefing_licao.py --variante tupi_revitalizado --capitulo 1 --licao 1
"""

import os
import sys
import json
import argparse

if sys.stdout.encoding != 'utf-8':
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass
import django

# Setup Django
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.append(BASE_DIR)
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings.development')
django.setup()

from trilha.models import VarianteTupi, Capitulo, Licao, Exercicio, ExercicioVersao
from pedagogico.filologia.lexicon_repository import get_philological_repository


def obter_briefing(variante_slug: str, capitulo_num: int, licao_num: int):
    caminho_json = os.path.join(
        BASE_DIR, 'pedagogico', 'conteudo', variante_slug, f'capitulo_{capitulo_num:02d}.json'
    )
    if not os.path.exists(caminho_json):
        print(f"[-] Arquivo não encontrado: {caminho_json}")
        return None

    with open(caminho_json, 'r', encoding='utf-8') as f:
        data_capitulo = json.load(f)

    licao_data = None
    for lic in data_capitulo.get('licoes', []):
        if lic.get('numero') == licao_num:
            licao_data = lic
            break

    if not licao_data:
        print(f"[-] Lição {licao_num} não encontrada no capítulo {capitulo_num} de {variante_slug}.")
        return None

    # Tenta obter do banco de dados para checar IDs existentes
    variante_cods = ['tupi', 'tupi_antigo'] if variante_slug in ['tupi', 'tupi_antigo'] else [variante_slug]
    licao_db = Licao.objects.filter(
        capitulo__trilha__variante__codigo__in=variante_cods,
        capitulo__numero=capitulo_num,
        numero=licao_num
    ).first()

    repo = get_philological_repository()

    briefing = {
        'variante': variante_slug,
        'capitulo_numero': capitulo_num,
        'capitulo_titulo': data_capitulo.get('titulo'),
        'capitulo_descricao': data_capitulo.get('descricao'),
        'scenario': data_capitulo.get('scenario'),
        'licao_numero': licao_num,
        'licao_titulo': licao_data.get('titulo'),
        'licao_descricao': licao_data.get('descricao'),
        'licao_db_id': licao_db.id if licao_db else None,
        'itens_apresentados': licao_data.get('bloco_ensino', {}).get('itens_apresentados', []),
        'dica_cultural': licao_data.get('bloco_ensino', {}).get('dica_cultural', ''),
        'exercicios': []
    }

    exercicios_json = licao_data.get('exercicios', [])
    for ex in exercicios_json:
        ordem = ex.get('ordem')
        ex_db = None
        versoes_count = 0
        if licao_db:
            ex_db = Exercicio.objects.filter(licao=licao_db, ordem=ordem).first()
            if ex_db:
                versoes_count = ex_db.versoes.count()

        ex_info = {
            'ordem': ordem,
            'db_id': ex_db.id if ex_db else None,
            'tipo': ex.get('tipo'),
            'enunciado_atual': ex.get('enunciado'),
            'dificuldade': ex.get('dificuldade', 'medio'),
            'itens_alvo': ex.get('itens_alvo', []),
            'versoes_existentes_no_banco': versoes_count,
            'tem_versoes_no_json': 'versoes' in ex,
            'qtd_versoes_json': len(ex.get('versoes', [])),
            'payload_atual': {k: v for k, v in ex.items() if k not in ['ordem', 'tipo', 'dificuldade', 'enunciado', 'versoes']}
        }
        briefing['exercicios'].append(ex_info)

    # Validar termos no repositório filológico
    for item in briefing['itens_apresentados']:
        palavra = item.get('palavra', '')
        entry = repo.lookup_exact(palavra)
        if not entry:
            normalized_list = repo.lookup_normalized(palavra)
            if normalized_list:
                entry = normalized_list[0]

        if entry:
            briefing_sources = []
            if hasattr(entry, 'sources') and entry.sources:
                briefing_sources = [f"{getattr(s, 'author', '')} ({getattr(s, 'year', '')})" for s in entry.sources]
            briefing_etym = getattr(entry, 'etymology', '') or getattr(entry, 'lema_original', '')

            item['filologia'] = {
                'status': getattr(entry.status_publicacao, 'value', str(entry.status_publicacao)),
                'tier': getattr(entry.tier, 'value', str(entry.tier)),
                'etimologia': briefing_etym,
                'fontes': briefing_sources
            }
        else:
            item['filologia'] = {'status': 'lexico_geral_ou_revitalizado'}

    return briefing


def main():
    parser = argparse.ArgumentParser(description="Gera dossiê de lição para redação de exercícios.")
    parser.add_argument('--variante', required=True, choices=['tupi_antigo', 'tupi_revitalizado'])
    parser.add_argument('--capitulo', type=int, required=True)
    parser.add_argument('--licao', type=int, required=True)
    parser.add_argument('--json-only', action='store_true', help="Imprime saída apenas em formato JSON")

    args = parser.parse_args()
    briefing = obter_briefing(args.variante, args.capitulo, args.licao)
    if not briefing:
        sys.exit(1)

    if args.json_only:
        print(json.dumps(briefing, ensure_ascii=False, indent=2))
        return

    print("=" * 70)
    print(f"DOSSIÊ PEDAGÓGICO: {briefing['variante'].upper()} | Cap {briefing['capitulo_numero']} - Lição {briefing['licao_numero']}")
    print(f"Capítulo: {briefing['capitulo_titulo']}")
    print(f"Cenário/Bioma: {briefing['scenario'].get('nome') if briefing['scenario'] else 'Padrão'}")
    print(f"Lição: {briefing['licao_titulo']} (DB ID: {briefing['licao_db_id']})")
    print(f"Descrição: {briefing['licao_descricao']}")
    print("-" * 70)
    print("VOCABULÁRIO INTRODUZIDO:")
    for v in briefing['itens_apresentados']:
        filo = v.get('filologia', {})
        print(f"  * {v.get('palavra')} ({v.get('classe_gramatical')}) -> {v.get('traducao')}")
        print(f"    Ex: {v.get('exemplo_uso')} | {v.get('exemplo_pt')}")
        print(f"    Filologia: {filo.get('status')} | Fontes: {filo.get('fontes', [])}")
    print("-" * 70)
    print(f"Dica Cultural: {briefing['dica_cultural']}")
    print("-" * 70)
    print(f"EXERCÍCIOS ({len(briefing['exercicios'])} no total):")
    for ex in briefing['exercicios']:
        print(f"  [{ex['ordem']}] Tipo: {ex['tipo']} | DB ID: {ex['db_id']} | Versões no Banco: {ex['versoes_existentes_no_banco']} | Versões no JSON: {ex['qtd_versoes_json']}")
        print(f"      Enunciado: {ex['enunciado_atual']}")
    print("=" * 70)


if __name__ == '__main__':
    main()
