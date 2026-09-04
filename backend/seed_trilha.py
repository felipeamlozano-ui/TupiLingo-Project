import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings.development')
django.setup()

from django.db import connection
from trilha.models import (
    VarianteTupi, TrilhaHistorica, Capitulo, Licao, Scenario,
    StoryBlock, VocabularyItem, Exercicio,
    ExercicioEscolha, ExercicioCompletar, ExercicioAssociacao
)
from users.models import UserProfile, UserLesson, Achievement, UserAchievement


def criar_exercicio_escolha(licao, ordem, enunciado, opcoes, resposta_correta, explicacao, dificuldade='facil', pontos_base=10):
    """Cria o exercício tanto no modelo unificado Exercicio quanto na tabela legada ExercicioEscolha."""
    Exercicio.objects.create(
        licao=licao,
        tipo='escolha_multipla',
        enunciado=enunciado,
        opcoes=opcoes,
        resposta_correta=resposta_correta,
        explicacao=explicacao,
        dificuldade=dificuldade,
        pontos_base=pontos_base,
        ordem=ordem,
    )
    ExercicioEscolha.objects.create(
        licao=licao,
        enunciado=enunciado,
        opcoes=opcoes,
        resposta_correta=resposta_correta,
        explicacao=explicacao,
        dificuldade=dificuldade,
        pontos_base=pontos_base,
        ordem=ordem,
    )


def criar_exercicio_completar(licao, ordem, enunciado, texto_com_lacunas, respostas_corretas, explicacao, dificuldade='facil', pontos_base=10, tolerancia=2):
    """Cria o exercício tanto no modelo unificado Exercicio quanto na tabela legada ExercicioCompletar."""
    Exercicio.objects.create(
        licao=licao,
        tipo='completar',
        enunciado=enunciado,
        texto_com_lacunas=texto_com_lacunas,
        respostas_corretas=respostas_corretas,
        tolerancia_levenshtein=tolerancia,
        explicacao=explicacao,
        dificuldade=dificuldade,
        pontos_base=pontos_base,
        ordem=ordem,
    )
    ExercicioCompletar.objects.create(
        licao=licao,
        enunciado=enunciado,
        texto_com_lacunas=texto_com_lacunas,
        respostas_corretas=respostas_corretas,
        tolerancia_levenshtein=tolerancia,
        explicacao=explicacao,
        dificuldade=dificuldade,
        pontos_base=pontos_base,
        ordem=ordem,
    )


def criar_exercicio_associacao(licao, ordem, enunciado, coluna_esquerda, coluna_direita, associacao_correta, explicacao, dificuldade='facil', pontos_base=15):
    """Cria o exercício tanto no modelo unificado Exercicio quanto na tabela legada ExercicioAssociacao."""
    Exercicio.objects.create(
        licao=licao,
        tipo='associacao',
        enunciado=enunciado,
        coluna_esquerda=coluna_esquerda,
        coluna_direita=coluna_direita,
        associacao_correta=associacao_correta,
        explicacao=explicacao,
        dificuldade=dificuldade,
        pontos_base=pontos_base,
        ordem=ordem,
    )
    ExercicioAssociacao.objects.create(
        licao=licao,
        enunciado=enunciado,
        coluna_esquerda=coluna_esquerda,
        coluna_direita=coluna_direita,
        associacao_correta=associacao_correta,
        explicacao=explicacao,
        dificuldade=dificuldade,
        pontos_base=pontos_base,
        ordem=ordem,
    )


def criar_views_supabase():
    """Cria Views SQL no Supabase para facilitar a gestão de trilhas pelos desenvolvedores."""
    print("Criando Views SQL no Supabase Postgres...")
    with connection.cursor() as cursor:
        cursor.execute("""
        CREATE OR REPLACE VIEW view_trilha_gerenciamento AS
        SELECT 
            t.titulo AS trilha,
            c.numero AS cap_numero,
            c.titulo AS capitulo,
            l.id AS licao_id,
            l.numero AS licao_numero,
            l.titulo AS licao,
            e.id AS exercicio_id,
            e.ordem AS exercicio_ordem,
            e.tipo AS tipo_exercicio,
            e.enunciado,
            e.dificuldade,
            e.pontos_base
        FROM trilha_trilhahistorica t
        JOIN trilha_capitulo c ON c.trilha_id = t.id
        JOIN trilha_licao l ON l.capitulo_id = c.id
        LEFT JOIN trilha_exercicio e ON e.licao_id = l.id
        ORDER BY t.id, c.numero, l.numero, e.ordem;
        """)

        cursor.execute("""
        CREATE OR REPLACE VIEW view_trilha_resumo AS
        SELECT 
            c.numero AS cap_num,
            c.titulo AS capitulo,
            l.id AS licao_id,
            l.numero AS licao_num,
            l.titulo AS licao,
            COUNT(DISTINCT sb.id) AS total_storyblocks,
            COUNT(DISTINCT v.id) AS total_vocabulario,
            COUNT(DISTINCT e.id) AS total_exercicios
        FROM trilha_capitulo c
        JOIN trilha_licao l ON l.capitulo_id = c.id
        LEFT JOIN trilha_storyblock sb ON sb.licao_id = l.id
        LEFT JOIN trilha_vocabularyitem v ON v.licao_id = l.id
        LEFT JOIN trilha_exercicio e ON e.licao_id = l.id
        GROUP BY c.numero, c.titulo, l.id, l.numero, l.titulo
        ORDER BY c.numero, l.numero;
        """)
    print("Views view_trilha_gerenciamento e view_trilha_resumo criadas com sucesso!")


def run_seed():
    print("Iniciando seed de dados enriquecido da Trilha Histórica...")

    # 1. Variante Tupi Antigo
    variante, _ = VarianteTupi.objects.get_or_create(
        codigo='tupi',
        defaults={
            'nome': 'Tupi Antigo',
            'descricao': 'Língua falada pela nação Tupinambá na costa do Brasil no século XVI.',
            'icone': '🌿',
            'ativo': True,
            'ordem': 1,
        }
    )

    # 2. Trilha Principal
    trilha, _ = TrilhaHistorica.objects.get_or_create(
        variante=variante,
        defaults={
            'titulo': 'Jornada pelo Pindorama',
            'subtitulo': 'Descubra a língua, cultura e tradições dos povos Tupis.',
            'publicada': True,
        }
    )
    trilha.publicada = True
    trilha.save()

    # 3. Cenários
    scenario_floresta, _ = Scenario.objects.get_or_create(
        nome='Mata Atlântica Ancestral',
        defaults={
            'palette': {'primary': '#0E5D4E', 'secondary': '#D08A45', 'accent': '#27C98A'}
        }
    )
    scenario_aldeia, _ = Scenario.objects.get_or_create(
        nome='A Grande Aldeia (Taba)',
        defaults={
            'palette': {'primary': '#8B4513', 'secondary': '#E8742A', 'accent': '#FFD166'}
        }
    )

    # 4. Capítulos
    cap1, _ = Capitulo.objects.get_or_create(
        trilha=trilha,
        numero=1,
        defaults={
            'titulo': 'Capítulo 1: O Despertar na Aldeia',
            'descricao': 'Aprenda saudações essenciais, pessoas da comunidade e os animais sagrados da mata.',
            'scenario': scenario_floresta,
            'publicado': True,
        }
    )
    cap1.titulo = 'Capítulo 1: O Despertar na Aldeia'
    cap1.descricao = 'Aprenda saudações essenciais, pessoas da comunidade e os animais sagrados da mata.'
    cap1.scenario = scenario_floresta
    cap1.publicado = True
    cap1.save()

    cap2, _ = Capitulo.objects.get_or_create(
        trilha=trilha,
        numero=2,
        defaults={
            'titulo': 'Capítulo 2: A Vida Cotidiana e a Terra',
            'descricao': 'Conheça os alimentos tradicionais, a família e os rituais sagrados da taba.',
            'scenario': scenario_aldeia,
            'publicado': True,
        }
    )
    cap2.titulo = 'Capítulo 2: A Vida Cotidiana e a Terra'
    cap2.descricao = 'Conheça os alimentos tradicionais, a família e os rituais sagrados da taba.'
    cap2.scenario = scenario_aldeia
    cap2.publicado = True
    cap2.save()

    # Despublica capítulos de teste (ex: Capítulo 999 RAG) para não poluir a trilha do usuário
    Capitulo.objects.filter(numero__gte=900).update(publicado=False)

    # 5. Limpa lições antigas do cap 1 e 2 para reconstruir completas e sem duplicatas
    Licao.objects.filter(capitulo__in=[cap1, cap2]).delete()

    # ═════════════════════════════════════════════════════════════════════════════
    # ── CAPÍTULO 1: O DESPERTAR NA ALDEIA ────────────────────────────────────────
    # ═════════════════════════════════════════════════════════════════════════════

    # Lição 1: Saudações e Encontros
    l1 = Licao.objects.create(
        capitulo=cap1,
        numero=1,
        titulo='Saudações e Boas-Vindas',
        descricao='Aprenda a dizer olá, saudações de respeito e os primeiros cumprimentos em Tupi.',
        xp_base=25,
        pos_x=50.0,
        pos_y=15.0,
        publicada=True,
    )
    StoryBlock.objects.create(
        licao=l1, tipo='story', titulo='Chegada à Costa',
        conteudo='Você desembarca nas praias do Pindorama ao amanhecer. Entre a brisa do mar e o verde da Mata Atlântica, você é recebido com sorrisos pelos guardiões da aldeia.',
        ordem=1, xp_bonus=5,
    )
    StoryBlock.objects.create(
        licao=l1, tipo='dialogue', titulo='Encontro com o Pajé',
        conteudo='Kauê! (Olá!). Seja muito bem-vindo à nossa taba. Meu nome é Karaíba.',
        ordem=2, extra={'personagem': 'Pajé Karaíba', 'lado': 'esquerda'}, xp_bonus=5,
    )
    StoryBlock.objects.create(
        licao=l1, tipo='curiosity', titulo='Curiosidade Cultural',
        conteudo='A palavra "Kauê" era usada amplamente no Tupi Antigo como uma saudação de respeito e amizade, equivalente a "Salve!" ou "Olá!".',
        ordem=3, xp_bonus=5,
    )
    VocabularyItem.objects.create(
        licao=l1, palavra_tupi='Kauê', traducao_pt='Olá / Salve',
        transliteracao='ka-u-Ê', exemplo_tupi='Kauê, che amigo!', exemplo_pt='Olá, meu amigo!',
        categoria='geral', classe_gramatical='interjeicao', ordem=1
    )
    VocabularyItem.objects.create(
        licao=l1, palavra_tupi='Abá', traducao_pt='Homem / Pessoa',
        transliteracao='a-BÁ', exemplo_tupi='Abá katu.', exemplo_pt='Pessoa boa.',
        categoria='geral', classe_gramatical='substantivo', ordem=2
    )
    VocabularyItem.objects.create(
        licao=l1, palavra_tupi='Kunhã', traducao_pt='Mulher',
        transliteracao='ku-NHÃ', exemplo_tupi='Kunhã poranga.', exemplo_pt='Mulher bonita.',
        categoria='geral', classe_gramatical='substantivo', ordem=3
    )
    VocabularyItem.objects.create(
        licao=l1, palavra_tupi='Taba', traducao_pt='Aldeia',
        transliteracao='TA-ba', exemplo_tupi='Okarusu taba.', exemplo_pt='Praça da aldeia.',
        categoria='geral', classe_gramatical='substantivo', ordem=4
    )

    criar_exercicio_escolha(
        l1, ordem=1,
        enunciado='Qual é a saudação tradicional em Tupi que significa "Olá!" ou "Salve!"?',
        opcoes=['Kauê', 'Pirá', 'Tupã', 'Taba'], resposta_correta=0,
        explicacao='"Kauê" é a saudação cordial tupi usada ao encontrar alguém.',
    )
    criar_exercicio_completar(
        l1, ordem=2,
        enunciado='Complete com a saudação correta:',
        texto_com_lacunas='Ao avistar um amigo na aldeia, dizemos: "___!"',
        respostas_corretas=['Kauê'],
        explicacao='"Kauê" expressa alegria ao saudar alguém na taba.',
    )
    criar_exercicio_escolha(
        l1, ordem=3,
        enunciado='O que significa a palavra "Abá" na língua Tupi?',
        opcoes=['Água', 'Homem / Pessoa', 'Fogo', 'Lua'], resposta_correta=1,
        explicacao='"Abá" significa homem, pessoa ou ser humano.',
    )
    criar_exercicio_associacao(
        l1, ordem=4,
        enunciado='Associe cada palavra em Tupi à sua tradução:',
        coluna_esquerda=['Kauê', 'Kunhã', 'Taba'],
        coluna_direita=['Aldeia', 'Olá', 'Mulher'],
        associacao_correta={'0': '1', '1': '2', '2': '0'},
        explicacao='Kauê = Olá, Kunhã = Mulher, Taba = Aldeia.',
    )

    # Lição 2: Animais Sagrados da Mata
    l2 = Licao.objects.create(
        capitulo=cap1,
        numero=2,
        titulo='Animais da Floresta',
        descricao='Conheça os animais que habitam o Pindorama e sua importância mística.',
        xp_base=25,
        pos_x=35.0,
        pos_y=35.0,
        publicada=True,
    )
    StoryBlock.objects.create(
        licao=l2, tipo='story', titulo='Trilhas da Mata',
        conteudo='Adentrando a densa floresta sob a copa das árvores centenárias, os sons da fauna revelam a presença de seres admirados e temidos.',
        ordem=1, xp_bonus=5,
    )
    StoryBlock.objects.create(
        licao=l2, tipo='curiosity', titulo='O Senhor da Noite',
        conteudo='O "Jagûara" (onça-pintada) é o maior predador terrestre das Américas e era visto como símbolo de coragem pelos guerreiros Tupinambás.',
        ordem=2, xp_bonus=5,
    )
    VocabularyItem.objects.create(
        licao=l2, palavra_tupi='Jagûara', traducao_pt='Onça / Fera',
        transliteracao='ja-gwa-RA', exemplo_tupi='Jagûara ocaru.', exemplo_pt='A onça comeu.',
        categoria='fauna', classe_gramatical='substantivo', ordem=1
    )
    VocabularyItem.objects.create(
        licao=l2, palavra_tupi='Pirá', traducao_pt='Peixe',
        transliteracao='pi-RÁ', exemplo_tupi='Pirá ype.', exemplo_pt='Peixe na água.',
        categoria='fauna', classe_gramatical='substantivo', ordem=2
    )
    VocabularyItem.objects.create(
        licao=l2, palavra_tupi='Gûyrá', traducao_pt='Pássaro / Ave',
        transliteracao='gwi-RÁ', exemplo_tupi='Gûyrá oveve.', exemplo_pt='O pássaro voa.',
        categoria='fauna', classe_gramatical='substantivo', ordem=3
    )
    VocabularyItem.objects.create(
        licao=l2, palavra_tupi='Tatu', traducao_pt='Tatu',
        transliteracao='ta-TU', exemplo_tupi='Tatu ybykype.', exemplo_pt='O tatu na toca.',
        categoria='fauna', classe_gramatical='substantivo', ordem=4
    )

    criar_exercicio_escolha(
        l2, ordem=1,
        enunciado='Qual animal é chamado de "Jagûara" pelos Tupis?',
        opcoes=['Tatu', 'Onça', 'Peixe', 'Anta'], resposta_correta=1,
        explicacao='"Jagûara" se refere à onça ou a feras carnívoras ferozes.',
    )
    criar_exercicio_escolha(
        l2, ordem=2,
        enunciado='Como se diz "Peixe" em Tupi Antigo?',
        opcoes=['Gûyrá', 'Taba', 'Pirá', 'Kûarasy'], resposta_correta=2,
        explicacao='"Pirá" significa peixe. Daí a origem de nomes como Piranha e Pirarucu.',
    )
    criar_exercicio_completar(
        l2, ordem=3,
        enunciado='Complete o nome da ave em Tupi:',
        texto_com_lacunas='A ave que corta os céus da floresta é chamada de ___ pelos nativos.',
        respostas_corretas=['Gûyrá'],
        tolerancia=2,
        explicacao='"Gûyrá" é o termo geral para pássaros e aves.',
    )
    criar_exercicio_associacao(
        l2, ordem=4,
        enunciado='Ligue cada animal ao seu nome em Tupi:',
        coluna_esquerda=['Jagûara', 'Pirá', 'Gûyrá'],
        coluna_direita=['Pássaro', 'Onça', 'Peixe'],
        associacao_correta={'0': '1', '1': '2', '2': '0'},
        explicacao='Jagûara = Onça, Pirá = Peixe, Gûyrá = Pássaro.',
    )

    # Lição 3: Elementos e Forças da Natureza
    l3 = Licao.objects.create(
        capitulo=cap1,
        numero=3,
        titulo='As Forças da Natureza',
        descricao='Entenda os elementos primordiais: a água, o fogo e os espíritos celestes.',
        xp_base=30,
        pos_x=65.0,
        pos_y=55.0,
        publicada=True,
    )
    StoryBlock.objects.create(
        licao=l3, tipo='story', titulo='O Rio Sagrado',
        conteudo='À beira das águas claras do grande rio ("Y"), o reflexo do Sol ("Kûarasy") ilumina as canoas esculpidas em troncos únicos de peroba.',
        ordem=1, xp_bonus=5,
    )
    VocabularyItem.objects.create(
        licao=l3, palavra_tupi='Y', traducao_pt='Água / Rio',
        transliteracao='Y (som gutural)', exemplo_tupi='Y tyba.', exemplo_pt='Muita água.',
        categoria='natureza', classe_gramatical='substantivo', ordem=1
    )
    VocabularyItem.objects.create(
        licao=l3, palavra_tupi='Tatagûasu', traducao_pt='Fogueira grande / Fogo',
        transliteracao='ta-ta-gwa-SU', exemplo_tupi='Tata oendy.', exemplo_pt='O fogo queima.',
        categoria='natureza', classe_gramatical='substantivo', ordem=2
    )
    VocabularyItem.objects.create(
        licao=l3, palavra_tupi='Kûarasy', traducao_pt='Sol',
        transliteracao='kwa-ra-SY', exemplo_tupi='Kûarasy osem.', exemplo_pt='O Sol nasce.',
        categoria='natureza', classe_gramatical='substantivo', ordem=3
    )
    VocabularyItem.objects.create(
        licao=l3, palavra_tupi='Jasy', traducao_pt='Lua',
        transliteracao='ja-SY', exemplo_tupi='Jasy pytuna.', exemplo_pt='Lua na noite.',
        categoria='natureza', classe_gramatical='substantivo', ordem=4
    )

    criar_exercicio_escolha(
        l3, ordem=1,
        enunciado='Qual elemento fundamental é representado pela letra "Y" em Tupi?',
        opcoes=['Fogo', 'Terra', 'Água / Rio', 'Pedra'], resposta_correta=2,
        explicacao='"Y" representa a água ou rios. É a base de termos como Iguaçu (Y-gûasu = água grande).',
    )
    criar_exercicio_completar(
        l3, ordem=2,
        enunciado='Complete com o nome do astro rei em Tupi:',
        texto_com_lacunas='O astro que aquece e ilumina o dia é chamado de ___ pelos Tupis.',
        respostas_corretas=['Kûarasy', 'Kuarasy'],
        tolerancia=2,
        explicacao='"Kûarasy" é o Sol, a força que guia os ciclos da terra.',
    )
    criar_exercicio_escolha(
        l3, ordem=3,
        enunciado='Como se chama a Lua que ilumina as noites na aldeia?',
        opcoes=['Jasy', 'Y', 'Tata', 'Taba'], resposta_correta=0,
        explicacao='"Jasy" é a Lua no panteão e vocabulário tupi.',
    )
    criar_exercicio_associacao(
        l3, ordem=4,
        enunciado='Ligue os astros ao seu nome em Tupi:',
        coluna_esquerda=['Kûarasy', 'Jasy', 'Y'],
        coluna_direita=['Água', 'Sol', 'Lua'],
        associacao_correta={'0': '1', '1': '2', '2': '0'},
        explicacao='Kûarasy = Sol, Jasy = Lua, Y = Água.',
    )

    # Lição 4: Desafio do Guardião (Chefão do Capítulo 1)
    l4 = Licao.objects.create(
        capitulo=cap1,
        numero=4,
        titulo='O Teste do Guerreiro Morubixaba',
        descricao='Prove seus conhecimentos reunidos em uma revisão desafiadora diante do conselho da aldeia.',
        xp_base=40,
        pos_x=50.0,
        pos_y=80.0,
        publicada=True,
    )
    StoryBlock.objects.create(
        licao=l4, tipo='story', titulo='Diante do Conselho Ancestral',
        conteudo='O Morubixaba (chefe da aldeia) e os sábios anciãos convidam você para demonstrar sua comunhão com a língua dos ancestrais.',
        ordem=1, xp_bonus=10,
    )

    criar_exercicio_escolha(
        l4, ordem=1,
        enunciado='Como traduzir a expressão: "Kauê, kunhã!"?',
        opcoes=['Adeus, guerreiro!', 'Olá, mulher!', 'Boa noite, pajé!', 'Venha até aqui!'], resposta_correta=1,
        explicacao='"Kauê" é Olá e "kunhã" é mulher, logo: Olá, mulher!',
        dificuldade='media', pontos_base=15,
    )
    criar_exercicio_completar(
        l4, ordem=2,
        enunciado='Complete com a palavra que significa Homem / Pessoa:',
        texto_com_lacunas='Um membro valoroso da aldeia é chamado de ___ katu (pessoa boa).',
        respostas_corretas=['Abá', 'Aba'],
        tolerancia=1,
        explicacao='"Abá" é a palavra tupi para ser humano, pessoa ou homem.',
        dificuldade='media', pontos_base=15,
    )
    criar_exercicio_escolha(
        l4, ordem=3,
        enunciado='A palavra "Iguaçu" vem de "Y" (água) + "Gûasu" (grande). O que significa "Y"?',
        opcoes=['Terra', 'Árvore', 'Água / Rio', 'Pássaro'], resposta_correta=2,
        explicacao='"Y" significa água ou rio.',
    )
    criar_exercicio_associacao(
        l4, ordem=4,
        enunciado='Associe os conceitos sagrados aprendidos:',
        coluna_esquerda=['Jagûara', 'Abá', 'Jasy'],
        coluna_direita=['Lua', 'Onça', 'Pessoa'],
        associacao_correta={'0': '1', '1': '2', '2': '0'},
        explicacao='Jagûara = Onça, Abá = Pessoa, Jasy = Lua.',
        dificuldade='media', pontos_base=15,
    )

    # ═════════════════════════════════════════════════════════════════════════════
    # ── CAPÍTULO 2: A VIDA COTIDIANA E A TERRA ──────────────────────────────────
    # ═════════════════════════════════════════════════════════════════════════════

    # Lição 1: Alimentos da Terra e a Mandioca
    l5 = Licao.objects.create(
        capitulo=cap2,
        numero=1,
        titulo='Alimentos da Terra e a Mandioca',
        descricao='Descubra a culinária, as raízes e a agricultura ancestral dos Tupis.',
        xp_base=25,
        pos_x=50.0,
        pos_y=20.0,
        publicada=True,
    )
    StoryBlock.objects.create(
        licao=l5, tipo='story', titulo='A Dádiva de Mani',
        conteudo='Segundo a tradição tupi, a Mandioca ("Mani\'oka") nasceu do sono sagrado da doce menina Mani, tornando-se o alimento primordial que sustenta as aldeias.',
        ordem=1, xp_bonus=5,
    )
    StoryBlock.objects.create(
        licao=l5, tipo='curiosity', titulo='A Farinha e o Beiju',
        conteudo='Os Tupis dominavam técnicas sofisticadas para extrair o amido e produzir o tipiti, a farinha fina e o beiju crocante assado no fogo de chão.',
        ordem=2, xp_bonus=5,
    )
    VocabularyItem.objects.create(
        licao=l5, palavra_tupi="Mani'oka", traducao_pt='Mandioca',
        transliteracao='ma-ni-O-ka', exemplo_tupi="Mani'oka katu.", exemplo_pt='Mandioca boa.',
        categoria='flora', classe_gramatical='substantivo', ordem=1
    )
    VocabularyItem.objects.create(
        licao=l5, palavra_tupi='Mbiú', traducao_pt='Comida / Alimento',
        transliteracao='mbi-Ú', exemplo_tupi='Mbiú ete.', exemplo_pt='Comida de verdade.',
        categoria='geral', classe_gramatical='substantivo', ordem=2
    )
    VocabularyItem.objects.create(
        licao=l5, palavra_tupi='Kagûĩ', traducao_pt='Cauim (Bebida tradicional)',
        transliteracao='ka-gwI', exemplo_tupi='Kagûĩ syry.', exemplo_pt='Bebida fresca.',
        categoria='geral', classe_gramatical='substantivo', ordem=3
    )
    VocabularyItem.objects.create(
        licao=l5, palavra_tupi="U'u", traducao_pt='Comer / Mastigar',
        transliteracao='u-U', exemplo_tupi="A'u pirá.", exemplo_pt='Como peixe.',
        categoria='geral', classe_gramatical='verbo', ordem=4
    )

    criar_exercicio_escolha(
        l5, ordem=1,
        enunciado='Qual raiz sagrada cultivada pelos povos Tupis deu origem à farinha e à tapioca?',
        opcoes=['Batata', "Mani'oka (Mandioca)", 'Milho', 'Arroz'], resposta_correta=1,
        explicacao="Mani'oka é a raiz sagrada que deu origem à mandioca e aos seus derivados.",
    )
    criar_exercicio_completar(
        l5, ordem=2,
        enunciado='Complete com o nome da bebida cerimonial tradicional em Tupi:',
        texto_com_lacunas='Nas grandes festividades da aldeia, os sábios partilhavam o ___ fermentado de mandioca.',
        respostas_corretas=['Kagûĩ', 'Kagui', 'Cauim'],
        tolerancia=2,
        explicacao='"Kagûĩ" (Cauim) era a bebida cerimonial de celebração.',
    )
    criar_exercicio_escolha(
        l5, ordem=3,
        enunciado='O que significa o termo geral "Mbiú" em Tupi?',
        opcoes=['Canoa', 'Comida / Alimento', 'Guerra', 'Arco'], resposta_correta=1,
        explicacao='"Mbiú" é o termo geral para alimento ou refeição.',
    )
    criar_exercicio_associacao(
        l5, ordem=4,
        enunciado='Associe os termos gastronômicos Tupis:',
        coluna_esquerda=["Mani'oka", "Mbiú", "Kagûĩ"],
        coluna_direita=['Comida', 'Mandioca', 'Bebida festiva'],
        associacao_correta={'0': '1', '1': '0', '2': '2'},
        explicacao="Mani'oka = Mandioca, Mbiú = Comida, Kagûĩ = Bebida festiva.",
    )

    # Lição 2: A Família e o Cotidiano
    l6 = Licao.objects.create(
        capitulo=cap2,
        numero=2,
        titulo='A Família e o Cotidiano',
        descricao='Aprenda a falar sobre parentesco, irmãos, pais e a vida em comunidade.',
        xp_base=30,
        pos_x=30.0,
        pos_y=50.0,
        publicada=True,
    )
    StoryBlock.objects.create(
        licao=l6, tipo='story', titulo='A Grande Maloca Familiar',
        conteudo='Na aldeia, as famílias vivem sob o mesmo teto das grandes malocas ("Oca"), onde o respeito entre pais, mães e filhos mantém a harmonia da comunidade.',
        ordem=1, xp_bonus=5,
    )
    VocabularyItem.objects.create(
        licao=l6, palavra_tupi='Tuba', traducao_pt='Pai',
        transliteracao='TU-ba', exemplo_tupi='Tuba katu.', exemplo_pt='Pai bondoso.',
        categoria='familia', classe_gramatical='substantivo', ordem=1
    )
    VocabularyItem.objects.create(
        licao=l6, palavra_tupi='Sy', traducao_pt='Mãe',
        transliteracao='Sy', exemplo_tupi='Sy poranga.', exemplo_pt='Mãe carinhosa.',
        categoria='familia', classe_gramatical='substantivo', ordem=2
    )
    VocabularyItem.objects.create(
        licao=l6, palavra_tupi="Oka", traducao_pt='Casa / Habitação',
        transliteracao='O-ka', exemplo_tupi="Oka guasu.", exemplo_pt='Casa grande.',
        categoria='comunidade', classe_gramatical='substantivo', ordem=3
    )
    VocabularyItem.objects.create(
        licao=l6, palavra_tupi='Ta\'yra', traducao_pt='Filho / Filha',
        transliteracao='ta-Y-ra', exemplo_tupi="Che ta'yra.", exemplo_pt='Meu filho.',
        categoria='familia', classe_gramatical='substantivo', ordem=4
    )

    criar_exercicio_escolha(
        l6, ordem=1,
        enunciado='Como se diz "Mãe" na língua Tupi Antigo?',
        opcoes=['Sy', 'Tuba', 'Abá', 'Kunhã'], resposta_correta=0,
        explicacao='"Sy" é a palavra para mãe. Origina termos como "Iaci" e "Cipó".',
    )
    criar_exercicio_completar(
        l6, ordem=2,
        enunciado='Complete a palavra que designa o "Pai" da família:',
        texto_com_lacunas='Em Tupi Antigo, o respeito ao pai da família é expresso pela palavra ___ katu.',
        respostas_corretas=['Tuba'],
        tolerancia=1,
        explicacao='"Tuba" significa pai ou progenitor.',
    )
    criar_exercicio_escolha(
        l6, ordem=3,
        enunciado='Como é chamada a habitação tradicional ou casa da família indígena?',
        opcoes=['Oka', 'Y', 'Pirá', 'Kûarasy'], resposta_correta=0,
        explicacao='"Oka" (Oca) é a casa, moradia tradicional da família.',
    )
    criar_exercicio_associacao(
        l6, ordem=4,
        enunciado='Associe cada membro familiar ao seu nome em Tupi:',
        coluna_esquerda=['Tuba', 'Sy', 'Oka'],
        coluna_direita=['Casa', 'Pai', 'Mãe'],
        associacao_correta={'0': '1', '1': '2', '2': '0'},
        explicacao='Tuba = Pai, Sy = Mãe, Oka = Casa.',
    )

    # Lição 3: A Cerimônia das Flautas
    l7 = Licao.objects.create(
        capitulo=cap2,
        numero=3,
        titulo='A Cerimônia das Flautas',
        descricao='Canções, rituais musicais e expressões de alegria na taba.',
        xp_base=35,
        pos_x=65.0,
        pos_y=80.0,
        publicada=True,
    )
    StoryBlock.objects.create(
        licao=l7, tipo='story', titulo='O Canto das Flautas',
        conteudo='Ao cair da tarde, o som doce das flautas de taquara ecoa pelo pátio central, convidando todos para a celebração da colheita.',
        ordem=1, xp_bonus=5,
    )
    VocabularyItem.objects.create(
        licao=l7, palavra_tupi='Mimbŷ', traducao_pt='Flauta',
        transliteracao='mim-BỸ', exemplo_tupi='Mimbŷ oñe\'ẽ.', exemplo_pt='A flauta soa.',
        categoria='musica', classe_gramatical='substantivo', ordem=1
    )
    VocabularyItem.objects.create(
        licao=l7, palavra_tupi='Maraká', traducao_pt='Chocalho sagrado',
        transliteracao='ma-ra-KÁ', exemplo_tupi='Maraká pu.', exemplo_pt='Som do maracá.',
        categoria='musica', classe_gramatical='substantivo', ordem=2
    )
    VocabularyItem.objects.create(
        licao=l7, palavra_tupi='Poracei', traducao_pt='Dançar / Cantar',
        transliteracao='po-ra-SEI', exemplo_tupi='Abá oporacei.', exemplo_pt='A pessoa dança.',
        categoria='musica', classe_gramatical='verbo', ordem=3
    )
    VocabularyItem.objects.create(
        licao=l7, palavra_tupi='Toryba', traducao_pt='Alegria / Felicidade',
        transliteracao='to-RY-ba', exemplo_tupi='Toryba guasu.', exemplo_pt='Grande alegria.',
        categoria='geral', classe_gramatical='substantivo', ordem=4
    )

    criar_exercicio_escolha(
        l7, ordem=1,
        enunciado='Qual instrumento sagrado de sopro feito de bambu/taquara é chamado de "Mimbŷ"?',
        opcoes=['Tambor', 'Flauta', 'Arpa', 'Chocalho'], resposta_correta=1,
        explicacao='"Mimbŷ" é a flauta tradicional confeccionada com taquara.',
    )
    criar_exercicio_completar(
        l7, ordem=2,
        enunciado='Complete com o instrumento de percussão sagrado feito de cabaça:',
        texto_com_lacunas='Nas cerimônias ancestrais, o pajé utiliza o ___ para entoar canções espirituais.',
        respostas_corretas=['Maraká', 'Maraca'],
        tolerancia=1,
        explicacao='"Maraká" é o chocalho ritual sagrado usado pelos pajés.',
    )
    criar_exercicio_escolha(
        l7, ordem=3,
        enunciado='O verbo "Poracei" significa qual ação festiva?',
        opcoes=['Caçar', 'Dançar / Cantar', 'Navegar', 'Dormir'], resposta_correta=1,
        explicacao='"Poracei" reúne a arte de cantar e dançar coletivamente.',
    )
    criar_exercicio_associacao(
        l7, ordem=4,
        enunciado='Associe a arte e musicalidade Tupi:',
        coluna_esquerda=['Mimbŷ', 'Maraká', 'Toryba'],
        coluna_direita=['Chocalho', 'Alegria', 'Flauta'],
        associacao_correta={'0': '2', '1': '0', '2': '1'},
        explicacao='Mimbŷ = Flauta, Maraká = Chocalho, Toryba = Alegria.',
    )

    # 6. Atualiza o status do usuário logado para ter a lição 1 concluída e lição 2 disponível
    for user in UserProfile.objects.all():
        UserLesson.objects.update_or_create(
            usuario=user,
            licao=l1,
            defaults={'status': 'concluida', 'earned_xp': 25, 'completion_percentage': 100.0}
        )
        UserLesson.objects.update_or_create(
            usuario=user,
            licao=l2,
            defaults={'status': 'disponivel', 'earned_xp': 0, 'completion_percentage': 0.0}
        )
        UserLesson.objects.update_or_create(
            usuario=user,
            licao=l3,
            defaults={'status': 'bloqueada'}
        )
        UserLesson.objects.update_or_create(
            usuario=user,
            licao=l4,
            defaults={'status': 'bloqueada'}
        )
        UserLesson.objects.update_or_create(
            usuario=user,
            licao=l5,
            defaults={'status': 'bloqueada'}
        )
        UserLesson.objects.update_or_create(
            usuario=user,
            licao=l6,
            defaults={'status': 'bloqueada'}
        )
        UserLesson.objects.update_or_create(
            usuario=user,
            licao=l7,
            defaults={'status': 'bloqueada'}
        )
        if user.xp_total < 85:
            user.xp_total = 85
        user.variante_ativa = variante
        user.save()

    # 7. Conquistas padrão (Achievements)
    achievements_data = [
        ('Semente Curiosa', 'Deu seus primeiros passos na língua Tupi.', 'xp_tier', '🌱', 'xp_semente', 0),
        ('Folha da Floresta', 'Alcançou 500 XP de jornada.', 'xp_tier', '🍃', 'xp_folha', 500),
        ('Arco Certeiro', 'Dominou mais de 20 palavras e 1500 XP.', 'xp_tier', '🏹', 'xp_arco', 1500),
        ('Guerreiro Audaz', 'Alcançou 4000 XP e completou a primeira trilha.', 'xp_tier', '🪓', 'xp_guerreiro', 4000),
        ('Pajé Sábio', 'Alcançou 8000 XP e domina diálogos complexos.', 'xp_tier', '🦅', 'xp_paje', 8000),
        ('Guardião do Pindorama', 'Alcançou 15000 XP — fluência e maestria ancestral.', 'xp_tier', '☀️', 'xp_guardiao', 15000),
        ('Amigo da Mata', 'Completou a lição sobre os animais da floresta.', 'cultural', '🐆', 'amigo_mata', 20),
    ]

    for nome, desc, tipo, icone, codigo, xp_nec in achievements_data:
        ach, _ = Achievement.objects.update_or_create(
            codigo=codigo,
            defaults={
                'nome': nome,
                'descricao': desc,
                'tipo': tipo,
                'icone': icone,
                'xp_necessario': xp_nec,
            }
        )
        for u in UserProfile.objects.all():
            if u.xp_total >= xp_nec and tipo == 'xp_tier':
                UserAchievement.objects.get_or_create(user=u, achievement=ach)

    # 8. Criação das Views SQL no Supabase
    criar_views_supabase()

    total_ex = Exercicio.objects.count()
    print("Seed da Trilha concluído com sucesso!")
    print(f"Capítulos ativos: {Capitulo.objects.filter(publicado=True).count()}")
    print(f"Lições ativas: {Licao.objects.filter(publicada=True).count()}")
    print(f"StoryBlocks: {StoryBlock.objects.count()}")
    print(f"Vocabulário: {VocabularyItem.objects.count()}")
    print(f"Exercícios Unificados (trilha_exercicio): {total_ex}")


if __name__ == '__main__':
    run_seed()
