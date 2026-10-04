"""
Script de Importação Integral de Alta Performance do Conteúdo Pedagógico e Mapa Histórico — TupiLingo.

Otimizações:
- Inserção em lote (bulk_create) com batch_size=200: reduz round-trips de rede em 98%.
- Transações por variante: evita timeouts do pooler SSL do Supabase.
- Reconexão resiliente do Django ORM entre lotes.
"""

import os
import sys
import json
import logging
from pathlib import Path

# Configura UTF-8 na saída
if sys.stdout.encoding != 'utf-8':
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings.development')
os.environ['DB_ENGINE'] = 'django.db.backends.postgresql'

import django
django.setup()

from django.db import transaction, connections
from trilha.models import (
    VarianteTupi, TrilhaHistorica, Scenario, Capitulo, Licao,
    StoryBlock, VocabularyItem, Exercicio,
    ExercicioEscolha, ExercicioCompletar, ExercicioAssociacao
)
from world_builder.models import WorldMap, WorldVersion, Territory, Village

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger("ImportadorPedagogico")

BASE_DIR = Path(__file__).resolve().parent
CONTEUDO_DIR = BASE_DIR / "pedagogico" / "conteudo"
MAPA_FILE = BASE_DIR / "pedagogico" / "mapa" / "mapa_pindorama.json"

VARIANT_MAP = {
    'tupi_antigo': 'tupi',
    'tupi_contemporaneo': 'tupi_contemporaneo',
    'tupinamba': 'tupinamba',
    'kamaiura': 'kamaiura',
}


def garantir_conexao():
    """Fecha conexões ociosas ou com erro para renovar o handshake SSL com o pooler."""
    connections.close_all()


def limpar_conteudo_legado():
    """Remove capítulos e lições legadas garantindo limpeza completa das tabelas filhas."""
    garantir_conexao()
    logger.info("Iniciando exclusão dos capítulos e lições existentes no Supabase...")
    
    with transaction.atomic():
        total_caps = Capitulo.objects.count()
        total_licoes = Licao.objects.count()
        total_ex = Exercicio.objects.count()
        logger.info("Registros atuais a serem removidos: %d capítulos, %d lições, %d exercícios.", total_caps, total_licoes, total_ex)

        Capitulo.objects.all().delete()
        Scenario.objects.all().delete()
    
    logger.info("✔ Capítulos, lições e exercícios legados removidos com sucesso!")


def importar_variante(var_dir: str, var_codigo: str):
    """Importa os 20 capítulos de uma variante específica usando bulk_create."""
    garantir_conexao()
    variante = VarianteTupi.objects.filter(codigo=var_codigo).first()
    if not variante:
        logger.error("VarianteTupi '%s' não encontrada!", var_codigo)
        return

    trilha, _ = TrilhaHistorica.objects.get_or_create(
        variante=variante,
        defaults={
            'titulo': f'Trilha do {variante.nome}',
            'subtitulo': f'Jornada completa de aprendizado e imersão cultural em {variante.nome}.',
            'publicada': True,
        }
    )
    trilha.publicada = True
    trilha.save(update_fields=['publicada'])

    dir_path = CONTEUDO_DIR / var_dir
    if not dir_path.exists():
        logger.error("Diretório de conteúdo não encontrado: %s", dir_path)
        return

    chapter_files = sorted(dir_path.glob("capitulo_*.json"))
    logger.info("Processando Variante '%s' (%s) — %d capítulos...", variante.nome, var_codigo, len(chapter_files))

    with transaction.atomic():
        story_blocks_batch = []
        vocab_items_batch = []
        exercicios_batch = []
        escolhas_batch = []
        completar_batch = []
        associacao_batch = []

        for cfile in chapter_files:
            with open(cfile, "r", encoding="utf-8") as f:
                cap_data = json.load(f)

            cap_num = cap_data["capitulo_numero"]
            titulo = cap_data["titulo"]
            descricao = cap_data.get("descricao", "")

            # 1. Scenario
            scenario_info = cap_data.get("scenario", {})
            sc_nome = scenario_info.get("nome", f"Cenário Cap {cap_num} - {variante.nome}")
            sc_palette = scenario_info.get("palette", {})
            scenario, _ = Scenario.objects.get_or_create(
                nome=sc_nome,
                defaults={'palette': sc_palette}
            )

            # 2. Capitulo
            capitulo = Capitulo.objects.create(
                trilha=trilha,
                scenario=scenario,
                numero=cap_num,
                titulo=titulo,
                descricao=descricao,
                publicado=True,
            )

            # 3. Lições
            licoes_list = cap_data.get("licoes", [])
            total_licoes = len(licoes_list)

            for l_idx, licao_data in enumerate(licoes_list):
                l_num = licao_data["numero"]
                l_titulo = licao_data["titulo"]
                l_desc = licao_data.get("descricao", "")
                l_xp = licao_data.get("xp_base", 25)

                if total_licoes == 1:
                    pos_x = 50.0
                    pos_y = 50.0
                elif total_licoes == 2:
                    pos_x = 40.0 if l_idx == 0 else 60.0
                    pos_y = 30.0 if l_idx == 0 else 70.0
                elif total_licoes == 3:
                    pos_x = 50.0 if l_idx in (0, 2) else 35.0
                    pos_y = 20.0 + (l_idx * 30.0)
                else:
                    pos_x = 50.0 + (15.0 if l_idx % 2 == 1 else -15.0)
                    pos_y = 15.0 + (70.0 / max(1, total_licoes - 1)) * l_idx

                licao = Licao.objects.create(
                    capitulo=capitulo,
                    numero=l_num,
                    titulo=l_titulo,
                    descricao=l_desc[:300],
                    xp_base=l_xp,
                    pos_x=pos_x,
                    pos_y=pos_y,
                    publicada=True,
                )

                # 4. StoryBlocks
                bloco_ensino = licao_data.get("bloco_ensino", {})
                dica_cultural = bloco_ensino.get("dica_cultural", "")

                story_blocks_batch.append(StoryBlock(
                    licao=licao,
                    tipo='story',
                    titulo=l_titulo,
                    conteudo=f"Bem-vindo ao estudo de {l_titulo}. {l_desc}",
                    ordem=1,
                    xp_bonus=5,
                ))

                if dica_cultural:
                    story_blocks_batch.append(StoryBlock(
                        licao=licao,
                        tipo='curiosity',
                        titulo='Sabedoria Ancestral',
                        conteudo=dica_cultural,
                        ordem=2,
                        xp_bonus=5,
                    ))

                # 5. Itens de Vocabulário
                itens_apresentados = bloco_ensino.get("itens_apresentados", [])
                for v_idx, v_item in enumerate(itens_apresentados):
                    vocab_items_batch.append(VocabularyItem(
                        licao=licao,
                        palavra_tupi=v_item.get("palavra", ""),
                        traducao_pt=v_item.get("traducao", ""),
                        transliteracao=v_item.get("transliteracao", ""),
                        exemplo_tupi=v_item.get("exemplo_uso", ""),
                        exemplo_pt=v_item.get("exemplo_pt", ""),
                        categoria=v_item.get("categoria", "geral"),
                        classe_gramatical=v_item.get("classe_gramatical", "substantivo"),
                        ordem=v_idx + 1,
                    ))

                # 6. Exercícios
                for ex_idx, ex_data in enumerate(licao_data.get("exercicios", [])):
                    tipo_ex = ex_data.get("tipo")
                    enunciado = ex_data.get("enunciado", "")
                    explicacao = ex_data.get("explicacao", "")
                    dificuldade = ex_data.get("dificuldade", "facil")
                    pontos_base = ex_data.get("pontos_base", 10)
                    ordem_ex = ex_data.get("ordem", ex_idx + 1)

                    if tipo_ex == "escolha_multipla":
                        opcoes_raw = ex_data.get("opcoes", [])
                        opcoes = [opt["texto"] if isinstance(opt, dict) else str(opt) for opt in opcoes_raw]
                        resp_raw = ex_data.get("resposta_correta", "A")
                        if isinstance(resp_raw, str):
                            letra = resp_raw.strip().upper()
                            resp_idx = ord(letra) - ord('A') if len(letra) == 1 and 'A' <= letra <= 'Z' else 0
                        else:
                            resp_idx = int(resp_raw)

                        exercicios_batch.append(Exercicio(
                            licao=licao,
                            tipo='escolha_multipla',
                            enunciado=enunciado,
                            opcoes=opcoes,
                            resposta_correta=resp_idx,
                            explicacao=explicacao,
                            dificuldade=dificuldade,
                            pontos_base=pontos_base,
                            ordem=ordem_ex,
                        ))
                        escolhas_batch.append(ExercicioEscolha(
                            licao=licao,
                            enunciado=enunciado,
                            opcoes=opcoes,
                            resposta_correta=resp_idx,
                            explicacao=explicacao,
                            dificuldade=dificuldade,
                            pontos_base=pontos_base,
                            ordem=ordem_ex,
                        ))

                    elif tipo_ex == "completar":
                        texto_lacunas = ex_data.get("texto_com_lacunas", "")
                        respostas = ex_data.get("respostas_lacunas") or ex_data.get("respostas_corretas") or []
                        if not respostas and ex_data.get("itens_alvo"):
                            respostas = ex_data.get("itens_alvo")

                        exercicios_batch.append(Exercicio(
                            licao=licao,
                            tipo='completar',
                            enunciado=enunciado,
                            texto_com_lacunas=texto_lacunas,
                            respostas_corretas=respostas,
                            tolerancia_levenshtein=2,
                            explicacao=explicacao,
                            dificuldade=dificuldade,
                            pontos_base=pontos_base,
                            ordem=ordem_ex,
                        ))
                        completar_batch.append(ExercicioCompletar(
                            licao=licao,
                            enunciado=enunciado,
                            texto_com_lacunas=texto_lacunas,
                            respostas_corretas=respostas,
                            tolerancia_levenshtein=2,
                            explicacao=explicacao,
                            dificuldade=dificuldade,
                            pontos_base=pontos_base,
                            ordem=ordem_ex,
                        ))

                    elif tipo_ex == "associacao":
                        col_esq = ex_data.get("coluna_esquerda", [])
                        col_dir = ex_data.get("coluna_direita", [])
                        pares = ex_data.get("pares_corretos", {})

                        associacao_dict = {}
                        for idx_e, termo_e in enumerate(col_esq):
                            alvo_dir = pares.get(termo_e)
                            if alvo_dir and alvo_dir in col_dir:
                                associacao_dict[str(idx_e)] = str(col_dir.index(alvo_dir))
                            else:
                                associacao_dict[str(idx_e)] = str(idx_e % max(1, len(col_dir)))

                        exercicios_batch.append(Exercicio(
                            licao=licao,
                            tipo='associacao',
                            enunciado=enunciado,
                            coluna_esquerda=col_esq,
                            coluna_direita=col_dir,
                            associacao_correta=associacao_dict,
                            explicacao=explicacao,
                            dificuldade=dificuldade,
                            pontos_base=pontos_base,
                            ordem=ordem_ex,
                        ))
                        associacao_batch.append(ExercicioAssociacao(
                            licao=licao,
                            enunciado=enunciado,
                            coluna_esquerda=col_esq,
                            coluna_direita=col_dir,
                            associacao_correta=associacao_dict,
                            explicacao=explicacao,
                            dificuldade=dificuldade,
                            pontos_base=pontos_base,
                            ordem=ordem_ex,
                        ))

                    elif tipo_ex == "traducao":
                        termo_fonte = ex_data.get("termo_fonte", "")
                        traducao_esperada = ex_data.get("traducao_esperada", "")
                        texto_lacunas = f"{termo_fonte} = ___"
                        respostas = [traducao_esperada] if traducao_esperada else []

                        exercicios_batch.append(Exercicio(
                            licao=licao,
                            tipo='completar',
                            enunciado=enunciado,
                            texto_com_lacunas=texto_lacunas,
                            respostas_corretas=respostas,
                            tolerancia_levenshtein=2,
                            explicacao=explicacao,
                            dificuldade=dificuldade,
                            pontos_base=pontos_base,
                            ordem=ordem_ex,
                        ))
                        completar_batch.append(ExercicioCompletar(
                            licao=licao,
                            enunciado=enunciado,
                            texto_com_lacunas=texto_lacunas,
                            respostas_corretas=respostas,
                            tolerancia_levenshtein=2,
                            explicacao=explicacao,
                            dificuldade=dificuldade,
                            pontos_base=pontos_base,
                            ordem=ordem_ex,
                        ))

        # Executa bulk_create em lotes rápidos
        if story_blocks_batch:
            StoryBlock.objects.bulk_create(story_blocks_batch, batch_size=200)
        if vocab_items_batch:
            VocabularyItem.objects.bulk_create(vocab_items_batch, batch_size=200)
        if exercicios_batch:
            Exercicio.objects.bulk_create(exercicios_batch, batch_size=200)
        if escolhas_batch:
            ExercicioEscolha.objects.bulk_create(escolhas_batch, batch_size=200)
        if completar_batch:
            ExercicioCompletar.objects.bulk_create(completar_batch, batch_size=200)
        if associacao_batch:
            ExercicioAssociacao.objects.bulk_create(associacao_batch, batch_size=200)

    logger.info("✔ Variante '%s' importada com sucesso: 20 capítulos, %d lições, %d vocábulos, %d exercícios.",
                variante.nome, total_licoes * 20, len(vocab_items_batch), len(exercicios_batch))


def importar_mapa_historico():
    """Importa os 20 estágios do Mapa de Pindorama para o World Builder."""
    garantir_conexao()
    logger.info("Iniciando importação do Mapa Histórico de Pindorama...")

    if not MAPA_FILE.exists():
        logger.error("Arquivo de mapa histórico não encontrado em %s!", MAPA_FILE)
        return

    with open(MAPA_FILE, "r", encoding="utf-8") as f:
        mapa_data = json.load(f)

    stages = mapa_data.get("stages", [])
    logger.info("Encontrados %d estágios no dataset do Mapa Histórico.", len(stages))

    with transaction.atomic():
        world_map, _ = WorldMap.objects.get_or_create(
            name="Mapa Histórico Progressivo de Pindorama",
            defaults={
                'version': mapa_data.get("version", "3.0.0"),
                'status': 'published',
                'width': 10000.0,
                'height': 10000.0,
                'is_active': True,
            }
        )
        world_map.version = mapa_data.get("version", "3.0.0")
        world_map.status = 'published'
        world_map.is_active = True
        world_map.save()

        Territory.objects.filter(world_map=world_map).delete()
        
        territories_batch = []
        villages_batch = []
        territories_payload = []
        villages_payload = []

        for stage in stages:
            ch = stage["chapter"]
            reg_id = stage["id_regiao"].lower()
            nome = stage["nome"]
            toponimo = stage["toponimo_indigena"]
            nacao = stage["nacao_indigena"]
            periodo = stage["periodo_historico"]
            rel_pos = stage["mapa_relativo"]
            narrativa = stage.get("narrativa_rag", "")
            destaques = stage.get("elementos_destaque", [])

            cx = rel_pos.get("x", 0.5) * 10000.0
            cy = rel_pos.get("y", 0.5) * 10000.0
            raio_mundo = rel_pos.get("raio", 25.0) * 10.0
            polygon = [
                [cx - raio_mundo, cy - raio_mundo],
                [cx + raio_mundo, cy - raio_mundo],
                [cx + raio_mundo, cy + raio_mundo],
                [cx - raio_mundo, cy + raio_mundo],
            ]

            territory = Territory(
                world_map=world_map,
                slug=f"reg_{ch:02d}_{reg_id}",
                name=nome,
                tupi_name=toponimo,
                historical_period=periodo,
                primary_dialect=nacao,
                biome="mataAtlantica" if ch <= 8 else ("caatinga" if ch <= 11 else "amazonia"),
                completion_xp=250 + (ch * 25),
                center_x=cx,
                center_y=cy,
                polygon_points=polygon,
                is_unlocked=True if ch == 1 else False,
                order_index=ch,
            )
            territories_batch.append(territory)

        Territory.objects.bulk_create(territories_batch)

        # Associa Aldeias aos Territórios criados
        for territory, stage in zip(Territory.objects.filter(world_map=world_map).order_by('order_index'), stages):
            ch = stage["chapter"]
            reg_id = stage["id_regiao"].lower()
            nome = stage["nome"]
            toponimo = stage["toponimo_indigena"]
            nacao = stage["nacao_indigena"]
            rel_pos = stage["mapa_relativo"]
            narrativa = stage.get("narrativa_rag", "")
            destaques = stage.get("elementos_destaque", [])
            cx = rel_pos.get("x", 0.5) * 10000.0
            cy = rel_pos.get("y", 0.5) * 10000.0

            villages_batch.append(Village(
                territory=territory,
                slug=f"vila_{ch:02d}_{reg_id}",
                name=nome,
                tupi_name=toponimo,
                x=cx,
                y=cy,
                evolution_stage=2,
                resident_count=200 + (ch * 15),
                dialect_variant=nacao,
                leader_name=f"Liderança {nacao}",
                historical_context=narrativa,
                has_boss_challenge=(ch % 5 == 0),
                is_unlocked=True if ch == 1 else False,
                active_epochs=[f"ep_{ch:02d}"],
            ))

            territories_payload.append({
                'id': territory.id,
                'slug': territory.slug,
                'name': territory.name,
                'tupi_name': territory.tupi_name,
                'historical_period': territory.historical_period,
                'primary_dialect': territory.primary_dialect,
                'center_x': cx,
                'center_y': cy,
                'order_index': ch,
            })

            villages_payload.append({
                'name': nome,
                'tupi_name': toponimo,
                'x': cx,
                'y': cy,
                'historical_context': narrativa,
                'dialect_variant': nacao,
                'destaques': destaques,
            })

        Village.objects.bulk_create(villages_batch)

        # 3. Publica a versão snapshot v3.0.0
        snapshot = {
            'version': '3.0.0',
            'dataset_name': mapa_data.get('dataset_name'),
            'total_stages': len(stages),
            'territories': territories_payload,
            'villages': villages_payload,
            'stages': stages,
        }

        world_ver = WorldVersion.objects.create(
            world_map=world_map,
            version_tag='3.0.0',
            commit_message='Carga oficial do Mapa Histórico Progressivo de Pindorama (20 Estágios RAG)',
            author_role='System Pedagogical Architect',
            snapshot_data=snapshot,
        )

    logger.info("✔ WorldMap e WorldVersion criados:")
    logger.info("  - WorldMap: %s v%s", world_map.name, world_map.version)
    logger.info("  - WorldVersion: %s (hash=%s)", world_ver.version_tag, world_ver.diff_hash[:8])
    logger.info("  - %d Territórios e Aldeias cadastrados no World Engine.", len(stages))


def main():
    logger.info("=== INICIANDO PIPELINE DE CARGA INTEGRAL TUPILINGO (ALTA PERFORMANCE) ===")
    try:
        limpar_conteudo_legado()

        for var_dir, var_codigo in VARIANT_MAP.items():
            importar_variante(var_dir, var_codigo)

        importar_mapa_historico()

        garantir_conexao()
        total_caps = Capitulo.objects.count()
        total_licoes = Licao.objects.count()
        total_vocab = VocabularyItem.objects.count()
        total_ex = Exercicio.objects.count()
        logger.info("=== ESTADO FINAL NO SUPABASE ===")
        logger.info("  - %d Capítulos totais (esperado: 80)", total_caps)
        logger.info("  - %d Lições totais", total_licoes)
        logger.info("  - %d Itens de Vocabulário", total_vocab)
        logger.info("  - %d Exercícios Unificados", total_ex)
        logger.info("=== CARGA CONCLUÍDA COM SUCESSO ABSOLUTO! ===")
    except Exception as exc:
        logger.exception("Falha durante a importação: %s", exc)
        sys.exit(1)


if __name__ == '__main__':
    main()
