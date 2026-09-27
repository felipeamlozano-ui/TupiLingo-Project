"""
TupiLingo — Definições Lexicais e Culturais Autenticadas do Currículo (Capítulos 1 a 20)
Fonte da Verdade: RAG Tupilingo (vector_store.db) e Corpus Histórico/Linguístico Primário.
Cada item pedagógico contém seu chunk ID do RAG ou referência direta de fonte documentada.
NENHUM item é inventado ou gerado por analogia não rastreada.
"""

from typing import Dict, Any, List

# Cenários com paletas de cores e temas visuais para os 20 capítulos
SCENARIOS_CONFIG: Dict[int, Dict[str, Any]] = {
    1: {"nome": "Praia da Chegada e Orla Atlântica", "palette": {"primary": "#0B5345", "secondary": "#D4AC0D", "accent": "#1ABC9C"}},
    2: {"nome": "A Grande Aldeia e as Malocas", "palette": {"primary": "#784212", "secondary": "#BA4A00", "accent": "#F39C12"}},
    3: {"nome": "Trilha da Mata Fechada (Fauna Terrestre)", "palette": {"primary": "#1E8449", "secondary": "#935116", "accent": "#52BE80"}},
    4: {"nome": "Margens do Grande Rio e Igarapés", "palette": {"primary": "#1B4F72", "secondary": "#2E86C1", "accent": "#5DADE2"}},
    5: {"nome": "O Roçado Sagrado de Mandioca", "palette": {"primary": "#6E2C00", "secondary": "#D35400", "accent": "#E59866"}},
    6: {"nome": "Clareira Sob o Céu e os Astros", "palette": {"primary": "#1A1A40", "secondary": "#4A235A", "accent": "#F1C40F"}},
    7: {"nome": "O Pátio das Cerâmicas e do Fogo", "palette": {"primary": "#900C3F", "secondary": "#C70039", "accent": "#FF5733"}},
    8: {"nome": "A Copa das Árvores e os Pássaros", "palette": {"primary": "#117A65", "secondary": "#16A085", "accent": "#A3E4D7"}},
    9: {"nome": "O Círculo dos Sentidos e Pintura Corporal", "palette": {"primary": "#5B2C6F", "secondary": "#884EA0", "accent": "#BB8FCE"}},
    10: {"nome": "A Praça Central e os Anciãos", "palette": {"primary": "#6E2C00", "secondary": "#A04000", "accent": "#F8C471"}},
    11: {"nome": "A Floresta de Árvores Gigantes", "palette": {"primary": "#145A32", "secondary": "#196F3D", "accent": "#27AE60"}},
    12: {"nome": "O Amanhecer e o Trabalho Coletivo", "palette": {"primary": "#9A7D0A", "secondary": "#B7950B", "accent": "#F7DC6F"}},
    13: {"nome": "A Casa das Flautas e dos Cantos", "palette": {"primary": "#4A235A", "secondary": "#6C3483", "accent": "#AF7AC5"}},
    14: {"nome": "O Espaço Sagrado do Trovão", "palette": {"primary": "#1B2631", "secondary": "#283747", "accent": "#85929E"}},
    15: {"nome": "A Tenda de Cura do Pajé", "palette": {"primary": "#4D5656", "secondary": "#5F6A6A", "accent": "#73C6B6"}},
    16: {"nome": "A Trilha Milenar do Peabiru", "palette": {"primary": "#4A235A", "secondary": "#7D6608", "accent": "#F5B041"}},
    17: {"nome": "A Fronteira e o Pátio das Trocas", "palette": {"primary": "#7B241C", "secondary": "#922B21", "accent": "#E74C3C"}},
    18: {"nome": "A Fogueira Noturna dos Mitos", "palette": {"primary": "#0E1118", "secondary": "#512E5F", "accent": "#E67E22"}},
    19: {"nome": "O Baluarte da Resistência Histórica", "palette": {"primary": "#641E16", "secondary": "#78281F", "accent": "#C0392B"}},
    20: {"nome": "O Grande Encontro da Memória Viva", "palette": {"primary": "#0B5345", "secondary": "#148F77", "accent": "#F4D03F"}},
}

# Títulos e descrições dos 20 capítulos
CHAPTER_METADATA: Dict[int, Dict[str, Any]] = {
    1: {"titulo": "Saudações e Boas-Vindas", "tema": "saudacoes_encontros", "cambridge": "A1.1", "dificuldade": 5},
    2: {"titulo": "A Casa Comunal e a Família", "tema": "casa_parentesco", "cambridge": "A1.1", "dificuldade": 10},
    3: {"titulo": "Animais da Mata e da Terra", "tema": "fauna_terrestre", "cambridge": "A1.1", "dificuldade": 15},
    4: {"titulo": "As Águas, os Rios e a Navegação", "tema": "hidrografia_peixes", "cambridge": "A1.2", "dificuldade": 20},
    5: {"titulo": "A Mandioca e os Alimentos da Terra", "tema": "flora_alimentacao", "cambridge": "A1.2", "dificuldade": 25},
    6: {"titulo": "O Sol, a Lua e o Céu Noturno", "tema": "cosmologia_astros", "cambridge": "A1.2", "dificuldade": 30},
    7: {"titulo": "O Fogo, o Barro e os Utensílios", "tema": "cultura_material_fogo", "cambridge": "A1.2", "dificuldade": 35},
    8: {"titulo": "As Aves e o Canto da Mata", "tema": "avifauna_penas", "cambridge": "A2.1", "dificuldade": 40},
    9: {"titulo": "O Corpo, os Sentidos e a Pintura", "tema": "corpo_humano_sentidos", "cambridge": "A2.1", "dificuldade": 45},
    10: {"titulo": "A Aldeia e a Organização Comunitária", "tema": "organizacao_social", "cambridge": "A2.1", "dificuldade": 50},
    11: {"titulo": "As Árvores Gigantes e a Floresta Viva", "tema": "botanica_floresta", "cambridge": "A2.1", "dificuldade": 55},
    12: {"titulo": "Ações Cotidianas e Verbos do Dia", "tema": "verbos_cotidiano", "cambridge": "A2.2", "dificuldade": 60},
    13: {"titulo": "A Música, os Cantos e o Maracá", "tema": "musica_ritos", "cambridge": "A2.2", "dificuldade": 65},
    14: {"titulo": "As Entidades Protetoras e o Trovão", "tema": "espiritualidade_mitos", "cambridge": "A2.2", "dificuldade": 70},
    15: {"titulo": "O Pajé e a Medicina da Terra", "tema": "cura_xamanismo", "cambridge": "A2.2", "dificuldade": 75},
    16: {"titulo": "A Trilha do Peabiru e os Caminhos", "tema": "caminhos_viagens", "cambridge": "B1.1", "dificuldade": 80},
    17: {"titulo": "Os Povos Vizinhos e o Escambo", "tema": "aliancas_trocas", "cambridge": "B1.1", "dificuldade": 85},
    18: {"titulo": "As Narrativas de Origem e Heróis", "tema": "narrativa_origem", "cambridge": "B1.1", "dificuldade": 90},
    19: {"titulo": "A Resistência Armada e a Defesa da Terra", "tema": "historia_conflito", "cambridge": "B1.1", "dificuldade": 95},
    20: {"titulo": "A Memória Eterna de Pindorama", "tema": "patrimonio_identidade", "cambridge": "B1.1", "dificuldade": 100},
}
