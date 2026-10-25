#!/usr/bin/env python
"""
validar_questoes.py — Validador Estrito de Qualidade e Diversidade de Questões

Valida:
1. Pelo menos 3 versões diferentes por exercício (máximo 8).
2. Contexto de cena (lúdico/narrativo) presente e não vazio.
3. Não repetição de distratores absurdos/idênticos.
4. Mapeamentos de associação íntegros e não-lineares.
5. Parâmetros psicométricos 3PL válidos.
6. Independência filológica entre tupi_antigo e tupi_revitalizado.

Uso:
    python backend/scripts/validar_questoes.py --arquivo backend/pedagogico/conteudo/tupi_antigo/capitulo_01.json
    python backend/scripts/validar_questoes.py --todos
"""

import os
import sys
import json
import argparse
from typing import List, Dict, Any, Tuple

if sys.stdout.encoding != 'utf-8':
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def calcular_jaccard_trigramas(str1: str, str2: str) -> float:
    """Calcula similaridade de Jaccard baseada em trigramas de caracteres."""
    s1, s2 = str1.lower().strip(), str2.lower().strip()
    if not s1 or not s2:
        return 0.0
    if s1 == s2:
        return 1.0
    trigramas1 = set(s1[i:i+3] for i in range(len(s1) - 2)) if len(s1) >= 3 else {s1}
    trigramas2 = set(s2[i:i+3] for i in range(len(s2) - 2)) if len(s2) >= 3 else {s2}
    uniao = trigramas1.union(trigramas2)
    if not uniao:
        return 0.0
    return len(trigramas1.intersection(trigramas2)) / len(uniao)


def validar_versao(versao: Dict[str, Any], tipo_exercicio: str, v_idx: int) -> List[str]:
    erros = []
    prefixo = f"[Versão {versao.get('versao_numero', v_idx)}]"

    # 1. Contexto de cena
    ctx = versao.get('contexto_cena', '').strip()
    if not ctx:
        erros.append(f"{prefixo} 'contexto_cena' é obrigatório e não pode ser vazio.")
    elif len(ctx) < 15:
        erros.append(f"{prefixo} 'contexto_cena' muito curto ('{ctx}'). Espera-se ambientação rica.")

    # 2. Enunciado
    enunciado = versao.get('enunciado', '').strip()
    if not enunciado:
        erros.append(f"{prefixo} 'enunciado' não pode ser vazio.")

    # 3. Parâmetros IRT 3PL
    try:
        a = float(versao.get('param_a', 1.0))
        b = float(versao.get('param_b', 0.0))
        c = float(versao.get('param_c', 0.25))

        if not (0.3 <= a <= 3.0):
            erros.append(f"{prefixo} param_a={a} fora da faixa aceitável [0.3, 3.0].")
        if not (-3.5 <= b <= 3.5):
            erros.append(f"{prefixo} param_b={b} fora da faixa aceitável [-3.5, 3.5].")
        if not (0.0 <= c <= 0.40):
            erros.append(f"{prefixo} param_c={c} fora da faixa aceitável [0.0, 0.40].")
    except (ValueError, TypeError) as e:
        erros.append(f"{prefixo} Erro na conversão de parâmetros IRT: {e}")

    # 4. Validação por Tipo
    payload = versao.get('payload', {})
    if not isinstance(payload, dict):
        erros.append(f"{prefixo} 'payload' deve ser um dicionário.")
        return erros

    if tipo_exercicio == 'escolha_multipla':
        opcoes = payload.get('opcoes', [])
        if not isinstance(opcoes, list) or len(opcoes) < 3:
            erros.append(f"{prefixo} Múltipla escolha deve ter pelo menos 3 opções.")
        else:
            textos_opcoes = []
            for op in opcoes:
                txt = (op.get('texto') if isinstance(op, dict) else str(op)).strip()
                textos_opcoes.append(txt)

            # Verifica unicidade de opções
            if len(set(textos_opcoes)) != len(textos_opcoes):
                erros.append(f"{prefixo} Opções duplicadas detectadas: {textos_opcoes}")

            # Verifica distratores proibidos repetitivos
            proibidos = ["fogo sagrado", "onça veloz", "água pura"]
            presentes_proibidos = [p for p in proibidos if p in [t.lower() for t in textos_opcoes]]
            if len(presentes_proibidos) >= 2:
                erros.append(f"{prefixo} Uso redundante de distratores clichês ({presentes_proibidos}). Crie distratores contextuais.")

            # Verifica resposta correta
            resp_corr = payload.get('resposta_correta')
            if resp_corr is None:
                erros.append(f"{prefixo} 'resposta_correta' ausente no payload.")
            else:
                if isinstance(resp_corr, int):
                    if not (0 <= resp_corr < len(opcoes)):
                        erros.append(f"{prefixo} 'resposta_correta' índice {resp_corr} fora do limite [0, {len(opcoes)-1}].")
                elif isinstance(resp_corr, str):
                    letras_validas = [chr(65 + i) for i in range(len(opcoes))]
                    if resp_corr.upper() not in letras_validas:
                        erros.append(f"{prefixo} 'resposta_correta' letra '{resp_corr}' inválida para {len(opcoes)} opções.")

    elif tipo_exercicio == 'completar':
        lacunas = payload.get('respostas_lacunas') or payload.get('respostas_corretas') or []
        if not isinstance(lacunas, list) or len(lacunas) == 0:
            erros.append(f"{prefixo} Exercício de completar requer lista 'respostas_lacunas' não vazia.")
        texto_lacuna = payload.get('texto_com_lacunas', '')
        if not texto_lacuna or ('___' not in texto_lacuna and '{' not in texto_lacuna):
            erros.append(f"{prefixo} 'texto_com_lacunas' deve indicar o espaço da lacuna (ex: '___').")

    elif tipo_exercicio == 'associacao':
        esq = payload.get('coluna_esquerda', [])
        dir_ = payload.get('coluna_direita', [])
        pares = payload.get('pares_corretos', {})

        if not isinstance(esq, list) or not isinstance(dir_, list):
            erros.append(f"{prefixo} Associação requer listas 'coluna_esquerda' e 'coluna_direita'.")
        elif len(esq) < 3 or len(dir_) < 3:
            erros.append(f"{prefixo} Associação requer pelo menos 3 pares.")
        elif len(esq) != len(dir_):
            erros.append(f"{prefixo} Colunas esquerda ({len(esq)}) e direita ({len(dir_)}) devem ter o mesmo tamanho.")
        elif not isinstance(pares, dict) or len(pares) != len(esq):
            erros.append(f"{prefixo} 'pares_corretos' deve mapear todos os {len(esq)} itens.")

    return erros


def validar_arquivo_capitulo(caminho_arquivo: str) -> Tuple[bool, List[str]]:
    if not os.path.exists(caminho_arquivo):
        return False, [f"Arquivo não encontrado: {caminho_arquivo}"]

    with open(caminho_arquivo, 'r', encoding='utf-8') as f:
        try:
            data = json.load(f)
        except Exception as e:
            return False, [f"JSON malformado em {caminho_arquivo}: {e}"]

    erros_totais = []
    variante = data.get('variante', 'desconhecida')
    cap_num = data.get('capitulo_numero', 0)

    for licao in data.get('licoes', []):
        lic_num = licao.get('numero', 0)
        for ex in licao.get('exercicios', []):
            ordem = ex.get('ordem', 0)
            tipo = ex.get('tipo', 'desconhecido')
            tag = f"[{variante} Cap {cap_num} L{lic_num} Ex{ordem} ({tipo})]"

            versoes = ex.get('versoes')
            if versoes is None:
                erros_totais.append(f"{tag} Chave 'versoes' ausente! Cada exercício deve possuir pelo menos 3 versões.")
                continue

            if not isinstance(versoes, list):
                erros_totais.append(f"{tag} 'versoes' deve ser uma lista.")
                continue

            if len(versoes) < 3:
                erros_totais.append(f"{tag} Possui apenas {len(versoes)} versões. Mínimo exigido: 3 versões.")
            elif len(versoes) > 8:
                erros_totais.append(f"{tag} Possui {len(versoes)} versões. Limite máximo: 8 versões.")

            # Checar unicidade de enunciados entre as versões do mesmo exercício
            enunciados = [v.get('enunciado', '').strip().lower() for v in versoes if isinstance(v, dict)]
            if len(set(enunciados)) != len(enunciados):
                erros_totais.append(f"{tag} Versões possuem enunciados idênticos! As versões devem variar em perspectiva/formulação.")

            # Valida cada versão individualmente
            for idx, v in enumerate(versoes, 1):
                if not isinstance(v, dict):
                    erros_totais.append(f"{tag} Versão {idx} deve ser um objeto JSON.")
                    continue
                v_erros = validar_versao(v, tipo, idx)
                for err in v_erros:
                    erros_totais.append(f"{tag} {err}")

    return len(erros_totais) == 0, erros_totais


def validar_independencia_variantes(caminho_antigo: str, caminho_revitalizado: str) -> List[str]:
    """Garante que as duas variantes não são clones uma da outra."""
    erros = []
    if not os.path.exists(caminho_antigo) or not os.path.exists(caminho_revitalizado):
        return erros

    with open(caminho_antigo, 'r', encoding='utf-8') as f:
        data_a = json.load(f)
    with open(caminho_revitalizado, 'r', encoding='utf-8') as f:
        data_r = json.load(f)

    enunciados_a = []
    for licao in data_a.get('licoes', []):
        for ex in licao.get('exercicios', []):
            for v in ex.get('versoes', []):
                enunciados_a.append(v.get('enunciado', ''))

    enunciados_r = []
    for licao in data_r.get('licoes', []):
        for ex in licao.get('exercicios', []):
            for v in ex.get('versoes', []):
                enunciados_r.append(v.get('enunciado', ''))

    if enunciados_a and enunciados_r:
        # Testa sobreposição média
        pares_quase_identicos = 0
        total_compara = 0
        for ea in enunciados_a[:30]:
            for er in enunciados_r[:30]:
                total_compara += 1
                sim = calcular_jaccard_trigramas(ea, er)
                if sim > 0.85:
                    pares_quase_identicos += 1

        taxa = pares_quase_identicos / max(1, total_compara)
        if taxa > 0.20:
            erros.append(f"Alta sobreposição de enunciados ({taxa*100:.1f}%) entre Tupi Antigo e Tupi Revitalizado! As duas variantes devem ser independentes e autênticas.")

    return erros


def main():
    parser = argparse.ArgumentParser(description="Validador Estrito de Questões e Versões.")
    parser.add_argument('--arquivo', help="Caminho de um arquivo capitulo_XX.json específico.")
    parser.add_argument('--todos', action='store_true', help="Valida todos os capítulos existentes.")
    args = parser.parse_args()

    arquivos = []
    if args.arquivo:
        arquivos.append(args.arquivo)
    elif args.todos:
        for var in ['tupi_antigo', 'tupi_revitalizado']:
            dir_var = os.path.join(BASE_DIR, 'pedagogico', 'conteudo', var)
            if os.path.exists(dir_var):
                for f in sorted(os.listdir(dir_var)):
                    if f.endswith('.json') and f.startswith('capitulo_'):
                        arquivos.append(os.path.join(dir_var, f))

    if not arquivos:
        print("[-] Nenhum arquivo especificado para validação. Use --arquivo ou --todos.")
        sys.exit(1)

    todos_erros = []
    for arq in arquivos:
        ok, erros = validar_arquivo_capitulo(arq)
        if not ok:
            todos_erros.extend(erros)

    # Verificar independência para capítulo 1 se presente
    f_antigo = os.path.join(BASE_DIR, 'pedagogico', 'conteudo', 'tupi_antigo', 'capitulo_01.json')
    f_revit = os.path.join(BASE_DIR, 'pedagogico', 'conteudo', 'tupi_revitalizado', 'capitulo_01.json')
    if (f_antigo in arquivos or args.todos) and (f_revit in arquivos or args.todos):
        erros_indep = validar_independencia_variantes(f_antigo, f_revit)
        todos_erros.extend(erros_indep)

    if todos_erros:
        print(f"❌ ENCONTRADOS {len(todos_erros)} ERROS NA VALIDAÇÃO:")
        for err in todos_erros[:50]:
            print(f"  * {err}")
        if len(todos_erros) > 50:
            print(f"  ... e mais {len(todos_erros) - 50} erros omitidos.")
        sys.exit(1)
    else:
        print(f"✅ SUCESSO: Todos os {len(arquivos)} arquivos validados com 100% de conformidade com as regras pedagógicas!")


if __name__ == '__main__':
    main()
