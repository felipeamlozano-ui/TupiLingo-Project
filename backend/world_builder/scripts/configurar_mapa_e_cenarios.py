"""
Script de Configuração e Enriquecimento Integral do Mapa Histórico de Pindorama
Configura:
1. Cenários Visuais e Atmosféricos (Scenario) vinculados aos 80 Capítulos
2. Épocas Históricas da Linha do Tempo (TimelineEpoch)
3. Cenários Históricos e Alianças Regionais (HistoricalOverlay)
4. Malha Hidrográfica Canônica de Rios em Bézier (River)
5. Rede de Trilhas Ancestrais e Peabiru (Trail)
6. Quests Épicas de Marco Histórico (Quest)
7. 20 Territórios e 20 Aldeias com coordenadas calibradas (4000x4000 e 10000x10000)
8. Permissões de Visualização, Desbloqueio e Progresso do Usuário
9. Snapshot Completo v3.1.0 publicado para o World Engine e World Builder
"""

import os
import sys
import json
import logging
from pathlib import Path

# Setup do ambiente Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings.development')
import django
django.setup()

from django.db import transaction, connection
from trilha.models import Scenario, Capitulo, Licao, TrilhaHistorica, VarianteTupi
from world_builder.models import (
    WorldMap, WorldVersion, Territory, Village, River, Trail,
    TimelineEpoch, HistoricalOverlay, Quest, WorldStatusChoices
)
from users.models import UserProfile, UserLesson

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)

BASE_DIR = Path(__file__).resolve().parent
MAPA_FILE = BASE_DIR / "pedagogico" / "mapa" / "mapa_pindorama.json"


def garantir_conexao():
    if connection.connection is None or connection.is_usable() is False:
        connection.connect()


def configurar_cenarios_e_capitulos():
    """Cria os Cenários atmosféricos e os vincula a todos os 80 capítulos."""
    garantir_conexao()
    logger.info("--- Configurando Cenários (Scenario) e vinculando aos Capítulos ---")

    cenarios_defs = [
        {
            "nome": "Mata Atlântica Ancestral",
            "palette": {"primary": "#0E5D4E", "secondary": "#2E7D32", "accent": "#F59E0B", "bg": "#0D1B14"},
        },
        {
            "nome": "Litoral dos Tamoios e Restingas",
            "palette": {"primary": "#0F766E", "secondary": "#0284C7", "accent": "#F97316", "bg": "#0A1B24"},
        },
        {
            "nome": "Planalto de Piratininga e Rios",
            "palette": {"primary": "#78350F", "secondary": "#B45309", "accent": "#EAB308", "bg": "#1C140D"},
        },
        {
            "nome": "Floresta Sagrada do Alto Xingu",
            "palette": {"primary": "#064E3B", "secondary": "#047857", "accent": "#10B981", "bg": "#0B1E16"},
        },
        {
            "nome": "Sertão dos Potiguaras e Caatinga",
            "palette": {"primary": "#C2410C", "secondary": "#EA580C", "accent": "#FACC15", "bg": "#231109"},
        },
        {
            "nome": "Bacia do Rio Negro e Amazônia",
            "palette": {"primary": "#1E1B4B", "secondary": "#312E81", "accent": "#8B5CF6", "bg": "#0A0D1E"},
        },
        {
            "nome": "Pindorama Vivo e Contemporâneo",
            "palette": {"primary": "#042F2E", "secondary": "#115E59", "accent": "#14B8A6", "bg": "#0B1519"},
        },
    ]

    cenarios_map = {}
    with transaction.atomic():
        for cdef in cenarios_defs:
            sc, _ = Scenario.objects.update_or_create(
                nome=cdef["nome"],
                defaults={"palette": cdef["palette"]}
            )
            cenarios_map[cdef["nome"]] = sc

        logger.info("✔ %d Cenários cadastrados/atualizados.", len(cenarios_map))

        # Vincula os 80 capítulos aos cenários temáticos
        capitulos = Capitulo.objects.all().order_by('trilha_id', 'numero')
        for cap in capitulos:
            num = cap.numero
            if num in (1, 2, 3):
                sc = cenarios_map["Litoral dos Tamoios e Restingas"]
            elif num in (4, 5):
                sc = cenarios_map["Mata Atlântica Ancestral"]
            elif num in (6, 7, 10):
                sc = cenarios_map["Planalto de Piratininga e Rios"]
            elif num in (8, 9, 11, 12):
                sc = cenarios_map["Litoral dos Tamoios e Restingas"]
            elif num in (13, 14, 15):
                sc = cenarios_map["Floresta Sagrada do Alto Xingu"]
            elif num in (16, 17, 18):
                sc = cenarios_map["Sertão dos Potiguaras e Caatinga"]
            elif num in (19, 20):
                sc = cenarios_map["Bacia do Rio Negro e Amazônia"]
            else:
                sc = cenarios_map["Pindorama Vivo e Contemporâneo"]

            cap.scenario = sc
            cap.save(update_fields=['scenario'])

        logger.info("✔ %d Capítulos associados aos Cenários visuais com sucesso.", capitulos.count())


def configurar_epocas_e_overlays():
    """Cria as 5 épocas históricas e os cenários/alianças cartográficas."""
    garantir_conexao()
    logger.info("--- Configurando Épocas Históricas e Cenários/Overlays Cartográficos ---")

    epocas_defs = [
        {
            "slug": "pre1500",
            "label": "Pré-1500",
            "title": "Pindorama Ancestral",
            "description": "Soberania indígena milenar, rede sagrada do Peabiru e expansão dos povos Tupi-Guarani.",
            "order_index": 1,
        },
        {
            "slug": "epoch1554",
            "label": "1554",
            "title": "Aldeamento & Piratininga",
            "description": "Aliança de Tibiriçá, confluência dos rios Tietê e Tamanduateí e fundação de São Paulo.",
            "order_index": 2,
        },
        {
            "slug": "epoch1555",
            "label": "1555",
            "title": "França Antártica",
            "description": "Baía de Guanabara, Forte Coligny e aliança estratégica franco-tupinambá.",
            "order_index": 3,
        },
        {
            "slug": "epoch1567",
            "label": "1567",
            "title": "Confederação dos Tamoios",
            "description": "Resistência armada dos Tupinambás liderada por Cunhambebe e Aimberê contra a escravização.",
            "order_index": 4,
        },
        {
            "slug": "atual",
            "label": "Atualidade",
            "title": "Revitalização Linguística",
            "description": "Retomada cultural, literatura viva, Nheengatu cooficial e transmissão intergeracional.",
            "order_index": 5,
        },
    ]

    epocas_map = {}
    with transaction.atomic():
        for edef in epocas_defs:
            ep, _ = TimelineEpoch.objects.update_or_create(
                slug=edef["slug"],
                defaults={
                    "label": edef["label"],
                    "title": edef["title"],
                    "description": edef["description"],
                    "order_index": edef["order_index"],
                }
            )
            epocas_map[edef["slug"]] = ep

        logger.info("✔ %d Épocas da Linha do Tempo registradas.", len(epocas_map))

        overlays_defs = [
            {
                "slug": "overlay_tamoios",
                "title": "Confederação dos Tamoios",
                "description": "Pacto militar sagrado unindo os Tupinambás de Ubatuba, Guanabara e Cabo Frio.",
                "overlay_type": "confederacaoTamoios",
                "epoch": epocas_map["epoch1567"],
                "base_color_hex": "#E53935",
                "polygon_points": [
                    [2880.0, 2720.0], [2960.0, 2600.0], [3080.0, 2560.0],
                    [3000.0, 2480.0], [2800.0, 2600.0]
                ],
            },
            {
                "slug": "overlay_peabiru",
                "title": "Rede Ancestral do Peabiru",
                "description": "Caminho transcontinental milenar forrado de capim que ligava o Atlântico aos Andes.",
                "overlay_type": "caminhoPeabiru",
                "epoch": epocas_map["pre1500"],
                "base_color_hex": "#FFB300",
                "polygon_points": [
                    [2720.0, 2900.0], [2680.0, 2760.0], [2300.0, 2750.0],
                    [1900.0, 2850.0], [1900.0, 2950.0], [2700.0, 2950.0]
                ],
            },
            {
                "slug": "overlay_lingua_geral",
                "title": "Bacia da Língua Geral Paulista",
                "description": "Corredor hidrográfico do Tietê onde o Tupi se estabeleceu como língua geral do comércio.",
                "overlay_type": "linguaGeralPaulista",
                "epoch": epocas_map["epoch1554"],
                "base_color_hex": "#00897B",
                "polygon_points": [
                    [2560.0, 2680.0], [2680.0, 2760.0], [2800.0, 2800.0],
                    [2700.0, 2880.0], [2450.0, 2750.0]
                ],
            },
            {
                "slug": "overlay_franca_antartica",
                "title": "Baía de Guanabara & França Antártica",
                "description": "Enclave insular e costeiro da aliança diplomática franco-tupinambá.",
                "overlay_type": "alliance",
                "epoch": epocas_map["epoch1555"],
                "base_color_hex": "#1E88E5",
                "polygon_points": [
                    [2900.0, 2550.0], [3020.0, 2550.0], [3040.0, 2650.0], [2920.0, 2650.0]
                ],
            },
            {
                "slug": "overlay_alto_xingu",
                "title": "Território Sagrado do Alto Xingu",
                "description": "Santuário cultural dos Kamaiurá na lagoa Ipavu e confluência do Morená.",
                "overlay_type": "alliance",
                "epoch": epocas_map["pre1500"],
                "base_color_hex": "#43A047",
                "polygon_points": [
                    [2000.0, 1800.0], [2160.0, 1800.0], [2180.0, 2040.0], [2020.0, 2040.0]
                ],
            },
            {
                "slug": "overlay_potiguara",
                "title": "Território de Resistência Potiguara",
                "description": "Bastião dos Potiguaras na Baía da Traição e berço das célebres Cartas de 1645.",
                "overlay_type": "alliance",
                "epoch": epocas_map["epoch1567"],
                "base_color_hex": "#FB8C00",
                "polygon_points": [
                    [3500.0, 1150.0], [3620.0, 1150.0], [3640.0, 1350.0], [3520.0, 1350.0]
                ],
            },
            {
                "slug": "overlay_rio_negro",
                "title": "Bacia Cultural do Rio Negro & Nheengatu",
                "description": "Capital da Língua Geral Amazônica cooficializada em São Gabriel da Cachoeira.",
                "overlay_type": "alliance",
                "epoch": epocas_map["atual"],
                "base_color_hex": "#8E24AA",
                "polygon_points": [
                    [1100.0, 750.0], [1400.0, 750.0], [1500.0, 1050.0], [1200.0, 1050.0]
                ],
            },
        ]

        for odef in overlays_defs:
            HistoricalOverlay.objects.update_or_create(
                slug=odef["slug"],
                defaults={
                    "title": odef["title"],
                    "description": odef["description"],
                    "overlay_type": odef["overlay_type"],
                    "epoch": odef["epoch"],
                    "base_color_hex": odef["base_color_hex"],
                    "polygon_points": odef["polygon_points"],
                }
            )

        logger.info("✔ %d Cenários e Overlays Cartográficos registrados.", len(overlays_defs))


def configurar_rios_e_trilhas():
    """Cria os Rios em Bézier e as Trilhas Históricas."""
    garantir_conexao()
    logger.info("--- Configurando Malha Hidrográfica (Rios) e Trilhas ---")

    rivers_defs = [
        {
            "slug": "river_tiete",
            "name": "Rio Tietê",
            "tupi_name": "Anhembi / Tietê",
            "spring_x": 2560.0,
            "spring_y": 2880.0,
            "estuary_x": 1200.0,
            "estuary_y": 3120.0,
            "max_width": 28.0,
            "control_points": [
                [2560.0, 2880.0], [2320.0, 2840.0], [2080.0, 2720.0],
                [1840.0, 2760.0], [1600.0, 2800.0], [1360.0, 2920.0], [1200.0, 3120.0]
            ],
            "water_color": "#2E9383",
            "flow_speed": 1.2,
        },
        {
            "slug": "river_paraiba",
            "name": "Rio Paraíba do Sul",
            "tupi_name": "Parahyba",
            "spring_x": 2720.0,
            "spring_y": 2760.0,
            "estuary_x": 3280.0,
            "estuary_y": 2600.0,
            "max_width": 24.0,
            "control_points": [
                [2720.0, 2760.0], [2920.0, 2680.0], [3120.0, 2640.0], [3280.0, 2600.0]
            ],
            "water_color": "#26A69A",
            "flow_speed": 1.1,
        },
        {
            "slug": "river_xingu",
            "name": "Rio Xingu e Formadores",
            "tupi_name": "Kuluene / Yngu",
            "spring_x": 2120.0,
            "spring_y": 2100.0,
            "estuary_x": 1960.0,
            "estuary_y": 1480.0,
            "max_width": 32.0,
            "control_points": [
                [2120.0, 2100.0], [2080.0, 1920.0], [2040.0, 1840.0],
                [2000.0, 1680.0], [1960.0, 1480.0]
            ],
            "water_color": "#38BDF8",
            "flow_speed": 1.4,
        },
        {
            "slug": "river_rio_negro",
            "name": "Rio Negro e Solimões",
            "tupi_name": "Y-Guasu / Pará-Guaçu",
            "spring_x": 1100.0,
            "spring_y": 750.0,
            "estuary_x": 2200.0,
            "estuary_y": 1250.0,
            "max_width": 38.0,
            "control_points": [
                [1100.0, 750.0], [1280.0, 880.0], [1500.0, 1020.0],
                [1800.0, 1150.0], [2200.0, 1250.0]
            ],
            "water_color": "#1E3A8A",
            "flow_speed": 1.0,
        },
        {
            "slug": "river_beberibe",
            "name": "Rio Beberibe",
            "tupi_name": "Beberibe",
            "spring_x": 3400.0,
            "spring_y": 1450.0,
            "estuary_x": 3580.0,
            "estuary_y": 1380.0,
            "max_width": 18.0,
            "control_points": [
                [3400.0, 1450.0], [3460.0, 1420.0], [3520.0, 1400.0], [3580.0, 1380.0]
            ],
            "water_color": "#0EA5E9",
            "flow_speed": 1.0,
        },
        {
            "slug": "river_sao_francisco",
            "name": "Rio São Francisco",
            "tupi_name": "Opará",
            "spring_x": 2900.0,
            "spring_y": 2400.0,
            "estuary_x": 3650.0,
            "estuary_y": 1550.0,
            "max_width": 30.0,
            "control_points": [
                [2900.0, 2400.0], [3100.0, 2100.0], [3300.0, 1800.0],
                [3500.0, 1600.0], [3650.0, 1550.0]
            ],
            "water_color": "#0284C7",
            "flow_speed": 1.3,
        },
        {
            "slug": "river_parana",
            "name": "Rio Paranapanema",
            "tupi_name": "Paranã-panema",
            "spring_x": 2300.0,
            "spring_y": 2600.0,
            "estuary_x": 1900.0,
            "estuary_y": 3400.0,
            "max_width": 26.0,
            "control_points": [
                [2300.0, 2600.0], [2150.0, 2800.0], [2000.0, 3100.0], [1900.0, 3400.0]
            ],
            "water_color": "#059669",
            "flow_speed": 1.2,
        },
    ]

    with transaction.atomic():
        for rdef in rivers_defs:
            River.objects.update_or_create(
                slug=rdef["slug"],
                defaults={
                    "name": rdef["name"],
                    "tupi_name": rdef["tupi_name"],
                    "spring_x": rdef["spring_x"],
                    "spring_y": rdef["spring_y"],
                    "estuary_x": rdef["estuary_x"],
                    "estuary_y": rdef["estuary_y"],
                    "max_width": rdef["max_width"],
                    "control_points": rdef["control_points"],
                    "flow_speed": rdef["flow_speed"],
                }
            )
        logger.info("✔ %d Rios históricos criados/atualizados.", len(rivers_defs))

        trails_defs = [
            {
                "slug": "peabiru_principal",
                "name": "Caminho do Peabiru",
                "description": "Trilha transcontinental ancestral conectando o litoral atlântico aos Andes.",
                "waypoints": [
                    [2720.0, 2880.0], [2680.0, 2760.0], [2560.0, 2680.0],
                    [2300.0, 2750.0], [1900.0, 2850.0], [1500.0, 2950.0]
                ],
                "color_hex": "#E5A93C",
                "stroke_width": 3.5,
                "historical_period": "Pré-1500",
            },
            {
                "slug": "rota_tamoios",
                "name": "Rota Costeira dos Tamoios",
                "description": "Conexão marítima e litorânea de canoagem entre Ubatuba, Guanabara e Cabo Frio.",
                "waypoints": [
                    [2880.0, 2720.0], [2920.0, 2680.0], [2960.0, 2600.0], [3080.0, 2560.0]
                ],
                "color_hex": "#EF4444",
                "stroke_width": 3.0,
                "historical_period": "1550–1567",
            },
            {
                "slug": "trilha_xingu",
                "name": "Trilha das Águas do Xingu",
                "description": "Rotas ancestrais entre as aldeias circulares Kamaiurá de Morená e Ipavu.",
                "waypoints": [
                    [2080.0, 1920.0], [2040.0, 1840.0], [2120.0, 2000.0]
                ],
                "color_hex": "#10B981",
                "stroke_width": 3.0,
                "historical_period": "Tradição Imemorial",
            },
            {
                "slug": "trilha_potiguaras",
                "name": "Caminho das Aldeias Potiguaras",
                "description": "Ligação territorial entre as tabas da Baía da Traição e o litoral paraibano/pernambucano.",
                "waypoints": [
                    [3560.0, 1200.0], [3540.0, 1300.0], [3520.0, 1400.0]
                ],
                "color_hex": "#F59E0B",
                "stroke_width": 3.0,
                "historical_period": "Século XVII",
            },
            {
                "slug": "rota_rio_negro",
                "name": "Rota Fluvial da Língua Geral",
                "description": "Navegação cotidiana e comércio comunitário em São Gabriel da Cachoeira.",
                "waypoints": [
                    [1100.0, 750.0], [1280.0, 880.0], [1500.0, 1020.0]
                ],
                "color_hex": "#8B5CF6",
                "stroke_width": 3.5,
                "historical_period": "Séculos XVIII–XXI",
            },
        ]

        for tdef in trails_defs:
            Trail.objects.update_or_create(
                slug=tdef["slug"],
                defaults={
                    "name": tdef["name"],
                    "description": tdef["description"],
                    "waypoints": tdef["waypoints"],
                    "color_hex": tdef["color_hex"],
                    "stroke_width": tdef["stroke_width"],
                    "historical_period": tdef["historical_period"],
                    "is_discovered": True,
                }
            )
        logger.info("✔ %d Trilhas ancestrais criadas/atualizadas.", len(trails_defs))


def configurar_quests():
    """Configura Quests de marco narrativo."""
    garantir_conexao()
    logger.info("--- Configurando Quests Históricas ---")

    quests_defs = [
        {
            "slug": "quest_iperoig",
            "title": "A Paz de Iperoig",
            "description": "Visite Ubatuba e entenda a diplomacia de Cunhambebe durante a Confederação dos Tamoios.",
            "is_main": True,
            "target_x": 2880.0,
            "target_y": 2720.0,
            "reward_xp": 200,
        },
        {
            "slug": "quest_piratininga",
            "title": "O Pacto do Planalto",
            "description": "Aprenda os termos de acolhimento e aliança com o Cacique Tibiriçá em Piratininga.",
            "is_main": True,
            "target_x": 2680.0,
            "target_y": 2760.0,
            "reward_xp": 250,
        },
        {
            "slug": "quest_morena",
            "title": "As Flautas Sagradas de Morená",
            "description": "Penetre o Alto Xingu e conheça o mito primordial de Mavutsinim.",
            "is_main": True,
            "target_x": 2080.0,
            "target_y": 1920.0,
            "reward_xp": 300,
        },
        {
            "slug": "quest_potiguara",
            "title": "As Cartas de 1645",
            "description": "Descubra os manuscritos originais em Tupi redigidos pelos guerreiros Potiguaras.",
            "is_main": True,
            "target_x": 3560.0,
            "target_y": 1200.0,
            "reward_xp": 350,
        },
        {
            "slug": "quest_rio_negro",
            "title": "A Voz Viva do Nheengatu",
            "description": "Conecte-se com a comunidade de São Gabriel da Cachoeira onde a língua permanece oficial.",
            "is_main": True,
            "target_x": 1280.0,
            "target_y": 880.0,
            "reward_xp": 400,
        },
    ]

    with transaction.atomic():
        for qdef in quests_defs:
            Quest.objects.update_or_create(
                slug=qdef["slug"],
                defaults={
                    "title": qdef["title"],
                    "description": qdef["description"],
                    "is_main": qdef["is_main"],
                    "target_x": qdef["target_x"],
                    "target_y": qdef["target_y"],
                    "reward_xp": qdef["reward_xp"],
                }
            )
        logger.info("✔ %d Quests cadastradas com sucesso.", len(quests_defs))


def configurar_territorios_e_aldeias_com_snapshot():
    """Configura os 20 Territórios e Aldeias, gera e publica o Snapshot v3.1.0."""
    garantir_conexao()
    logger.info("--- Configurando Territórios, Aldeias e Snapshot Global v3.1.0 ---")

    if not MAPA_FILE.exists():
        logger.error("Arquivo %s não encontrado!", MAPA_FILE)
        return

    with open(MAPA_FILE, 'r', encoding='utf-8') as f:
        mapa_data = json.load(f)

    stages = mapa_data.get('stages', [])

    with transaction.atomic():
        world_map, _ = WorldMap.objects.get_or_create(
            name="Mapa Histórico Progressivo de Pindorama",
            defaults={
                'version': '3.1.0',
                'status': WorldStatusChoices.PUBLISHED,
                'width': 10000.0,
                'height': 10000.0,
                'is_active': True,
            }
        )
        world_map.version = '3.1.0'
        world_map.status = WorldStatusChoices.PUBLISHED
        world_map.is_active = True
        world_map.save()

        # Limpa territórios anteriores do mapa para reconstrução perfeita
        Territory.objects.filter(world_map=world_map).delete()

        territories_batch = []
        villages_batch = []
        territories_payload = []
        villages_payload = []

        all_epochs_list = ['pre1500', 'epoch1554', 'epoch1555', 'epoch1567', 'atual']

        # Carrega lições dos capítulos da variante tupi_antigo ou tupi para anexar aos nós
        licoes_por_cap = {}
        for lic in Licao.objects.select_related('capitulo').order_by('numero'):
            cnum = lic.capitulo.numero
            if cnum not in licoes_por_cap:
                licoes_por_cap[cnum] = []
            licoes_por_cap[cnum].append(lic)

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

            # Coordenadas:
            # Em canvas 4000x4000 (World Builder):
            cx_4000 = rel_pos.get("x", 0.5) * 4000.0
            cy_4000 = rel_pos.get("y", 0.5) * 4000.0
            # Em canvas 10000x10000 (World Engine):
            cx_10000 = rel_pos.get("x", 0.5) * 10000.0
            cy_10000 = rel_pos.get("y", 0.5) * 10000.0

            raio_mundo_4000 = rel_pos.get("raio", 25.0) * 8.0
            polygon_4000 = [
                [cx_4000 - raio_mundo_4000, cy_4000 - raio_mundo_4000],
                [cx_4000 + raio_mundo_4000, cy_4000 - raio_mundo_4000],
                [cx_4000 + raio_mundo_4000, cy_4000 + raio_mundo_4000],
                [cx_4000 - raio_mundo_4000, cy_4000 + raio_mundo_4000],
            ]

            biome_name = "mataAtlantica"
            if ch in (1, 2, 4, 8, 11, 12):
                biome_name = "litoral"
            elif ch in (3, 5, 7, 10):
                biome_name = "mataAtlantica"
            elif ch in (6, 16):
                biome_name = "mataAtlantica"
            elif ch in (9, 17, 18, 19):
                biome_name = "caatinga"
            elif ch in (13, 14, 15):
                biome_name = "cerrado"
            elif ch == 20:
                biome_name = "amazonia"

            territory = Territory(
                world_map=world_map,
                slug=f"reg_{ch:02d}_{reg_id}",
                name=nome,
                tupi_name=toponimo,
                historical_period=periodo,
                primary_dialect=nacao,
                biome=biome_name,
                completion_xp=250 + (ch * 25),
                center_x=cx_4000,
                center_y=cy_4000,
                polygon_points=polygon_4000,
                is_unlocked=True,
                order_index=ch,
            )
            territories_batch.append(territory)

        Territory.objects.bulk_create(territories_batch)

        saved_territories = list(Territory.objects.filter(world_map=world_map).order_by('order_index'))

        style_cycle = ['canoas', 'taba_fort', 'maloca', 'circular']
        color_palette = ['#F59E0B', '#10B981', '#06B6D4', '#EF4444', '#8B5CF6', '#EC4899', '#3B82F6']

        for territory, stage in zip(saved_territories, stages):
            ch = stage["chapter"]
            reg_id = stage["id_regiao"].lower()
            nome = stage["nome"]
            toponimo = stage["toponimo_indigena"]
            nacao = stage["nacao_indigena"]
            rel_pos = stage["mapa_relativo"]
            narrativa = stage.get("narrativa_rag", "")
            destaques = stage.get("elementos_destaque", [])

            cx_4000 = rel_pos.get("x", 0.5) * 4000.0
            cy_4000 = rel_pos.get("y", 0.5) * 4000.0
            cx_10000 = rel_pos.get("x", 0.5) * 10000.0
            cy_10000 = rel_pos.get("y", 0.5) * 10000.0

            style = style_cycle[(ch - 1) % len(style_cycle)]
            vcolor = color_palette[(ch - 1) % len(color_palette)]

            # Lições vinculadas
            licoes_cap = licoes_por_cap.get(ch, [])
            lessons_payload = []
            for lic_idx, lic in enumerate(licoes_cap):
                lessons_payload.append({
                    "id": f"lic_{lic.id}",
                    "licao_id": lic.id,
                    "title": lic.titulo,
                    "tupi_title": f"{lic.titulo.split('—')[0].strip() if '—' in lic.titulo else lic.titulo}",
                    "description": lic.descricao or f"Lição de {lic.titulo}",
                    "difficulty": "iniciante" if ch <= 6 else ("intermediario" if ch <= 14 else "avancado"),
                    "type": "vocabulario" if lic_idx == 0 else ("gramatica" if lic_idx == 1 else "historia"),
                    "status": "available" if (ch == 1 or lic_idx == 0) else "locked",
                    "xp_reward": 40 + (ch * 5),
                    "duration_minutes": 5,
                    "practice_theme": lic.titulo.split(':')[-1].strip(),
                })

            village = Village(
                territory=territory,
                slug=f"vila_{ch:02d}_{reg_id}",
                name=nome,
                tupi_name=toponimo,
                x=cx_4000,
                y=cy_4000,
                evolution_stage=2,  # Explorada (visível no mapa sem névoa)
                resident_count=200 + (ch * 15),
                dialect_variant=nacao,
                leader_name=f"Cacique Ancestral de {toponimo.split()[0]}",
                historical_context=narrativa,
                has_boss_challenge=(ch % 5 == 0),
                is_unlocked=True,
                active_epochs=all_epochs_list,
            )
            villages_batch.append(village)

            territories_payload.append({
                'id': territory.id,
                'slug': territory.slug,
                'name': territory.name,
                'name_portuguese': territory.name,
                'name_tupi': territory.tupi_name,
                'tupi_name': territory.tupi_name,
                'historical_period': territory.historical_period,
                'primary_dialect': territory.primary_dialect,
                'biome': territory.biome,
                'center_x': cx_4000,
                'center_y': cy_4000,
                'cx': cx_4000,
                'cy': cy_4000,
                'is_unlocked': True,
                'is_unlocked_default': True,
                'fog_reveal_radius': 240.0,
                'order_index': ch,
                'village_ids': [f"vila_{ch:02d}_{reg_id}"],
            })

            villages_payload.append({
                'id': f"vila_{ch:02d}_{reg_id}",
                'slug': f"vila_{ch:02d}_{reg_id}",
                'name': nome,
                'name_portuguese': nome,
                'tupi_name': toponimo,
                'name_tupi': toponimo,
                'x': cx_4000,
                'y': cy_4000,
                'cx': cx_4000,
                'cy': cy_4000,
                'wx_10000': cx_10000,
                'wy_10000': cy_10000,
                'is_unlocked': True,
                'is_unlocked_default': True,
                'stage': 'explorada',
                'evolution_stage': 2,
                'fog_reveal_radius': 240.0,
                'biome': territory.biome,
                'village_style': style,
                'village_color': vcolor,
                'resident_count': 200 + (ch * 15),
                'dialect_variant': nacao,
                'leader_name': f"Liderança {nacao}",
                'description': narrativa,
                'historical_context': narrativa,
                'destaques': destaques,
                'active_epochs': all_epochs_list,
                'chapter': ch,
                'chapter_id': f"cap_{ch:02d}",
                'lessons': lessons_payload,
            })

        Village.objects.bulk_create(villages_batch)
        logger.info("✔ %d Territórios e Aldeias cadastrados no PostgreSQL.", len(villages_batch))

        # Serializa todas as entidades para o Snapshot v3.1.0
        rivers_payload = []
        for r in River.objects.all():
            rivers_payload.append({
                'id': r.id,
                'slug': r.slug,
                'name': r.name,
                'name_portuguese': r.name,
                'name_tupi': r.tupi_name,
                'tupi_name': r.tupi_name,
                'river_width': 8.0,
                'water_color': '#2E9383' if 'tiete' in r.slug else ('#38BDF8' if 'xingu' in r.slug else '#1E3A8A'),
                'flow_style': 'currents',
                'bezier_points': r.control_points,
            })

        trails_payload = []
        for t in Trail.objects.all():
            trails_payload.append({
                'id': t.id,
                'slug': t.slug,
                'name': t.name,
                'name_portuguese': t.name,
                'name_tupi': t.name,
                'waypoints': t.waypoints,
                'trail_color': t.color_hex,
                'stroke_width': t.stroke_width,
                'historical_period': t.historical_period,
                'is_discovered': True,
            })

        epochs_payload = []
        for ep in TimelineEpoch.objects.all().order_by('order_index'):
            epochs_payload.append({
                'id': ep.slug,
                'slug': ep.slug,
                'label': ep.label,
                'title': ep.title,
                'description': ep.description,
                'order_index': ep.order_index,
            })

        overlays_payload = []
        for ov in HistoricalOverlay.objects.all():
            overlays_payload.append({
                'id': ov.slug,
                'slug': ov.slug,
                'title': ov.title,
                'description': ov.description,
                'overlay_type': ov.overlay_type,
                'epoch': ov.epoch.slug if ov.epoch else 'epoch1554',
                'epoch_id': ov.epoch.slug if ov.epoch else 'epoch1554',
                'base_color_hex': ov.base_color_hex,
                'polygon_points': ov.polygon_points,
            })

        quests_payload = []
        for q in Quest.objects.all():
            quests_payload.append({
                'id': q.id,
                'slug': q.slug,
                'title': q.title,
                'description': q.description,
                'is_main': q.is_main,
                'target_x': q.target_x,
                'target_y': q.target_y,
                'reward_xp': q.reward_xp,
            })

        snapshot = {
            'version': '3.1.0',
            'dataset_name': mapa_data.get('dataset_name'),
            'total_stages': len(stages),
            'territories': territories_payload,
            'villages': villages_payload,
            'rivers': rivers_payload,
            'trails': trails_payload,
            'epochs': epochs_payload,
            'overlays': overlays_payload,
            'quests': quests_payload,
            'stages': stages,
        }

        world_ver = WorldVersion.objects.create(
            world_map=world_map,
            version_tag='3.1.0',
            commit_message='Publicação oficial completa do Pindorama: 20 Aldeias, Territórios, Rios, Cenários e Trilhas',
            author_role='Chief System Architect',
            snapshot_data=snapshot,
        )

        logger.info("✔ WorldVersion v3.1.0 publicada com sucesso! Diff hash: %s", world_ver.diff_hash[:8])
        logger.info("  - %d Aldeias configuradas e desbloqueadas", len(villages_payload))
        logger.info("  - %d Rios em Bézier", len(rivers_payload))
        logger.info("  - %d Cenários e Overlays", len(overlays_payload))
        logger.info("  - %d Trilhas Ancestrais", len(trails_payload))
        logger.info("  - %d Quests Históricas", len(quests_payload))


def configurar_progresso_e_permissoes_usuario():
    """Configura o progresso inicial e permissões de administrador do usuário."""
    garantir_conexao()
    logger.info("--- Configurando Permissões e Progresso do Usuário ---")

    admin_email = "felipe.a.m.lozano@gmail.com"
    from django.contrib.auth.models import User

    # 1. Garante privilégios administrativos no Django User
    d_user, _ = User.objects.get_or_create(username=admin_email, defaults={'email': admin_email})
    d_user.email = admin_email
    d_user.is_staff = True
    d_user.is_superuser = True
    d_user.save()
    logger.info("✔ Django User %s verificado com permissões de Administrador (is_staff=True, is_superuser=True).", admin_email)

    # 2. Configura perfil e progresso de lições
    try:
        user_profile = UserProfile.objects.get(email=admin_email)
        # Configura registros de UserLesson para o usuário nas lições iniciais de cada variante
        with transaction.atomic():
            for trilha in TrilhaHistorica.objects.all():
                primeiro_cap = Capitulo.objects.filter(trilha=trilha).order_by('numero').first()
                if not primeiro_cap:
                    continue
                licoes = list(Licao.objects.filter(capitulo=primeiro_cap).order_by('numero'))
                if licoes:
                    # Lição 1: Concluída com 100% de precisão e XP
                    UserLesson.objects.update_or_create(
                        usuario=user_profile,
                        licao=licoes[0],
                        defaults={
                            'status': 'concluida',
                            'completion_percentage': 100.0,
                            'accuracy': 1.0,
                            'earned_xp': 60,
                        }
                    )
                    # Lição 2: Disponível para jogar imediatamente
                    if len(licoes) > 1:
                        UserLesson.objects.update_or_create(
                            usuario=user_profile,
                            licao=licoes[1],
                            defaults={
                                'status': 'disponivel',
                                'completion_percentage': 0.0,
                                'accuracy': 0.0,
                                'earned_xp': 0,
                            }
                        )

            logger.info("✔ Registros de progresso inicial configurados para %s em todas as 4 variantes.", admin_email)
    except UserProfile.DoesNotExist:
        logger.warning("UserProfile %s não encontrado no banco.", admin_email)


def main():
    logger.info("=== INICIANDO CONFIGURAÇÃO COMPLETA DO MAPA, CENÁRIOS E PROGRESSO ===")
    configurar_cenarios_e_capitulos()
    configurar_epocas_e_overlays()
    configurar_rios_e_trilhas()
    configurar_quests()
    configurar_territorios_e_aldeias_com_snapshot()
    configurar_progresso_e_permissoes_usuario()
    logger.info("=== CONFIGURAÇÃO CONCLUÍDA COM SUCESSO TOTAL! ===")


if __name__ == '__main__':
    main()
