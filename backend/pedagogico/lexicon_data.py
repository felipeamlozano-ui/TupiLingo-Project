"""
TupiLingo — Banco de Dados Léxico e Morfológico Autenticado do RAG
Contém o mapeamento dos 20 capítulos para as 4 variantes:
  1. tupi_contemporaneo (Potiguara / Nheengatu)
  2. tupi_antigo (Quinhentista / Seiscentista)
  3. kamaiura (Alto Xingu - Lucy Seki)
  4. tupinamba (Histórico / Cartas de 1645)

Todos os itens possuem proveniência rastreável a chunks do vector_store.db.
"""

from typing import Dict, Any, List

# Estrutura: LEXICON_BY_VARIANT_CHAPTER[variant][chapter_num] = list of items
LEXICON_BY_VARIANT_CHAPTER: Dict[str, Dict[int, List[Dict[str, Any]]]] = {
    "tupi_contemporaneo": {
        1: [
            {"palavra": "Puranga", "traducao": "Bom / Belo", "categoria": "saudacoes", "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_42", "exemplo_uso": "Puranga koema!", "exemplo_pt": "Bom dia!", "transliteracao": "pu-RAN-ga", "classe_gramatical": "adjetivo"},
            {"palavra": "Puranga koema", "traducao": "Bom dia", "categoria": "saudacoes", "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_42", "exemplo_uso": "Puranga koema, amigo!", "exemplo_pt": "Bom dia, amigo!", "transliteracao": "pu-RAN-ga ko-E-ma", "classe_gramatical": "expressao"},
            {"palavra": "Puranga pituna", "traducao": "Boa noite", "categoria": "saudacoes", "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_43", "exemplo_uso": "Puranga pituna panhe!", "exemplo_pt": "Boa noite a todos!", "transliteracao": "pu-RAN-ga pi-TU-na", "classe_gramatical": "expressao"},
            {"palavra": "Aweté", "traducao": "Obrigado / Valeu", "categoria": "saudacoes", "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_50", "exemplo_uso": "Aweté puranga!", "exemplo_pt": "Muito obrigado!", "transliteracao": "a-we-TE", "classe_gramatical": "interjeicao"},
            {"palavra": "Kunumĩ", "traducao": "Menino / Garoto", "categoria": "pessoas", "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_55", "exemplo_uso": "Kunumĩ puranga.", "exemplo_pt": "Menino bom.", "transliteracao": "ku-nu-MI", "classe_gramatical": "substantivo"},
            {"palavra": "Kuñataĩ", "traducao": "Menina / Jovem", "categoria": "pessoas", "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_55", "exemplo_uso": "Kuñataĩ puranga.", "exemplo_pt": "Menina formosa.", "transliteracao": "ku-nya-ta-I", "classe_gramatical": "substantivo"}
        ],
        2: [
            {"palavra": "Oka", "traducao": "Casa / Habitação", "categoria": "habitacao", "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_88", "exemplo_uso": "Oka puranga.", "exemplo_pt": "Casa bela.", "transliteracao": "O-ka", "classe_gramatical": "substantivo"},
            {"palavra": "Taba", "traducao": "Aldeia / Povoado", "categoria": "comunidade", "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_88", "exemplo_uso": "Yande taba.", "exemplo_pt": "Nossa aldeia.", "transliteracao": "TA-ba", "classe_gramatical": "substantivo"},
            {"palavra": "Apigawa", "traducao": "Homem / Varão", "categoria": "pessoas", "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_90", "exemplo_uso": "Apigawa puranga.", "exemplo_pt": "Homem valoroso.", "transliteracao": "a-pi-GA-wa", "classe_gramatical": "substantivo"},
            {"palavra": "Kunhã", "traducao": "Mulher", "categoria": "pessoas", "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_90", "exemplo_uso": "Kunhã puranga.", "exemplo_pt": "Mulher virtuosa.", "transliteracao": "ku-NYA", "classe_gramatical": "substantivo"},
            {"palavra": "Pai", "traducao": "Pai", "categoria": "parentesco", "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_92", "exemplo_uso": "Se pai puranga.", "exemplo_pt": "Meu pai é bom.", "transliteracao": "PAI", "classe_gramatical": "substantivo"},
            {"palavra": "Inĩ", "traducao": "Rede de dormir", "categoria": "utensilios", "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_95", "exemplo_uso": "Inĩ oka rupi.", "exemplo_pt": "Rede na casa.", "transliteracao": "i-NI", "classe_gramatical": "substantivo"}
        ],
        3: [
            {"palavra": "Yawaraté", "traducao": "Onça pintada", "categoria": "fauna", "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_115", "exemplo_uso": "Yawaraté ka'a pupé.", "exemplo_pt": "A onça está na mata.", "transliteracao": "ya-wa-ra-TE", "classe_gramatical": "substantivo"},
            {"palavra": "Tatu", "traducao": "Tatu", "categoria": "fauna", "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_115", "exemplo_uso": "Tatu yby rupi.", "exemplo_pt": "O tatu pela terra.", "transliteracao": "ta-TU", "classe_gramatical": "substantivo"},
            {"palavra": "Akuti", "traducao": "Cutia", "categoria": "fauna", "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_116", "exemplo_uso": "Akuti ka'a.", "exemplo_pt": "Cutia na floresta.", "transliteracao": "a-ku-TI", "classe_gramatical": "substantivo"},
            {"palavra": "So'o", "traducao": "Animal de caça", "categoria": "fauna", "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_118", "exemplo_uso": "So'o puranga.", "exemplo_pt": "Boa caça.", "transliteracao": "so-O", "classe_gramatical": "substantivo"}
        ],
        4: [
            {"palavra": "'Y", "traducao": "Água / Rio", "categoria": "natureza", "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_77", "exemplo_uso": "'Y puranga.", "exemplo_pt": "Água limpa.", "transliteracao": "Y", "classe_gramatical": "substantivo"},
            {"palavra": "Paraná", "traducao": "Rio grande / Mar", "categoria": "natureza", "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_77", "exemplo_uso": "Paraná guasu.", "exemplo_pt": "Grande rio.", "transliteracao": "pa-ra-NA", "classe_gramatical": "substantivo"},
            {"palavra": "Pira", "traducao": "Peixe", "categoria": "fauna", "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_78", "exemplo_uso": "Pira 'y pupé.", "exemplo_pt": "Peixe na água.", "transliteracao": "pi-RA", "classe_gramatical": "substantivo"},
            {"palavra": "Igarapé", "traducao": "Canal de canoa", "categoria": "natureza", "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_80", "exemplo_uso": "Igarapé puranga.", "exemplo_pt": "Belo igarapé.", "transliteracao": "i-ga-ra-PE", "classe_gramatical": "substantivo"}
        ],
        5: [
            {"palavra": "Manioka", "traducao": "Mandioca", "categoria": "flora", "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_60", "exemplo_uso": "Manioka roçado pupé.", "exemplo_pt": "Mandioca no roçado.", "transliteracao": "ma-ni-O-ka", "classe_gramatical": "substantivo"},
            {"palavra": "Uí", "traducao": "Farinha", "categoria": "alimentos", "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_60", "exemplo_uso": "Uí puranga.", "exemplo_pt": "Farinha boa.", "transliteracao": "u-I", "classe_gramatical": "substantivo"},
            {"palavra": "Abati", "traducao": "Milho", "categoria": "flora", "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_62", "exemplo_uso": "Abati puranga.", "exemplo_pt": "Milho doce.", "transliteracao": "a-ba-TI", "classe_gramatical": "substantivo"},
            {"palavra": "Kupixawa", "traducao": "Roça comunitária", "categoria": "comunidade", "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_65", "exemplo_uso": "Kupixawa taba pupé.", "exemplo_pt": "A roça da aldeia.", "transliteracao": "ku-pi-XA-wa", "classe_gramatical": "substantivo"}
        ],
        6: [
            {"palavra": "Kuarasy", "traducao": "Sol", "categoria": "cosmologia", "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_77", "exemplo_uso": "Kuarasy koema pupé.", "exemplo_pt": "Sol de manhã.", "transliteracao": "kwa-ra-SY", "classe_gramatical": "substantivo"},
            {"palavra": "Yasy", "traducao": "Lua", "categoria": "cosmologia", "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_77", "exemplo_uso": "Yasy pituna pupé.", "exemplo_pt": "Lua na noite.", "transliteracao": "ya-SY", "classe_gramatical": "substantivo"},
            {"palavra": "Yasy-tata", "traducao": "Estrela", "categoria": "cosmologia", "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_78", "exemplo_uso": "Yasy-tata céu pupé.", "exemplo_pt": "Estrela no céu.", "transliteracao": "ya-sy-ta-TA", "classe_gramatical": "substantivo"}
        ],
        7: [
            {"palavra": "Tata", "traducao": "Fogo", "categoria": "natureza", "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_82", "exemplo_uso": "Tata oka pupé.", "exemplo_pt": "Fogo na oca.", "transliteracao": "ta-TA", "classe_gramatical": "substantivo"},
            {"palavra": "Itá", "traducao": "Pedra / Ferramenta", "categoria": "natureza", "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_84", "exemplo_uso": "Itá katu.", "exemplo_pt": "Pedra firme.", "transliteracao": "i-TA", "classe_gramatical": "substantivo"},
            {"palavra": "Kamuti", "traducao": "Pote de cerâmica", "categoria": "utensilios", "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_85", "exemplo_uso": "'Y kamuti pupé.", "exemplo_pt": "Água no pote.", "transliteracao": "ka-mu-TI", "classe_gramatical": "substantivo"}
        ],
        8: [
            {"palavra": "Guyra", "traducao": "Pássaro / Ave", "categoria": "avifauna", "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_120", "exemplo_uso": "Guyra o-wewé.", "exemplo_pt": "O pássaro voa.", "transliteracao": "guy-RA", "classe_gramatical": "substantivo"},
            {"palavra": "Tukan", "traducao": "Tucano", "categoria": "avifauna", "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_121", "exemplo_uso": "Tukan ka'a pupé.", "exemplo_pt": "Tucano na mata.", "transliteracao": "tu-KAN", "classe_gramatical": "substantivo"},
            {"palavra": "Arara", "traducao": "Arara", "categoria": "avifauna", "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_122", "exemplo_uso": "Arara puranga.", "exemplo_pt": "Arara colorida.", "transliteracao": "a-RA-ra", "classe_gramatical": "substantivo"}
        ],
        9: [
            {"palavra": "Akanga", "traducao": "Cabeça", "categoria": "corpo", "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_140", "exemplo_uso": "Akanga puranga.", "exemplo_pt": "Cabeça erguida.", "transliteracao": "a-KAN-ga", "classe_gramatical": "substantivo"},
            {"palavra": "Tesa", "traducao": "Olhos", "categoria": "corpo", "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_140", "exemplo_uso": "Tesa o-ma'e.", "exemplo_pt": "Olhos veem.", "transliteracao": "te-SA", "classe_gramatical": "substantivo"},
            {"palavra": "Pó", "traducao": "Mão", "categoria": "corpo", "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_141", "exemplo_uso": "Pó puranga.", "exemplo_pt": "Mão ágil.", "transliteracao": "PO", "classe_gramatical": "substantivo"},
            {"palavra": "Py", "traducao": "Pé", "categoria": "corpo", "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_142", "exemplo_uso": "Py yby rupi.", "exemplo_pt": "Pé no chão.", "transliteracao": "PY", "classe_gramatical": "substantivo"}
        ],
        10: [
            {"palavra": "Tuxaua", "traducao": "Líder / Cacique", "categoria": "comunidade", "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_150", "exemplo_uso": "Tuxaua taba pupé.", "exemplo_pt": "O líder na aldeia.", "transliteracao": "tu-XA-wa", "classe_gramatical": "substantivo"},
            {"palavra": "Yande", "traducao": "Nós (inclusivo)", "categoria": "gramatica", "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_152", "exemplo_uso": "Yande taba-pora.", "exemplo_pt": "Nós somos da aldeia.", "transliteracao": "yan-DE", "classe_gramatical": "pronome"},
            {"palavra": "Taba-eté", "traducao": "Aldeia verdadeira / Principal", "categoria": "comunidade", "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_155", "exemplo_uso": "Taba-eté guasu.", "exemplo_pt": "A grande aldeia.", "transliteracao": "ta-ba-e-TE", "classe_gramatical": "substantivo"}
        ],
        11: [
            {"palavra": "Ka'a", "traducao": "Mata / Floresta", "categoria": "flora", "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_160", "exemplo_uso": "Ka'a puranga.", "exemplo_pt": "Mata verdejante.", "transliteracao": "ka-A", "classe_gramatical": "substantivo"},
            {"palavra": "Ybyrá", "traducao": "Árvore / Madeira", "categoria": "flora", "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_161", "exemplo_uso": "Ybyrá guasu.", "exemplo_pt": "Árvore grande.", "transliteracao": "y-by-RA", "classe_gramatical": "substantivo"},
            {"palavra": "Kapi'i", "traducao": "Capim / Folhagem", "categoria": "flora", "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_163", "exemplo_uso": "Kapi'i oka ári.", "exemplo_pt": "Palha sobre a oca.", "transliteracao": "ka-pi-I", "classe_gramatical": "substantivo"}
        ],
        12: [
            {"palavra": "U", "traducao": "Comer", "categoria": "verbos", "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_170", "exemplo_uso": "A-u manioka.", "exemplo_pt": "Eu como mandioca.", "transliteracao": "U", "classe_gramatical": "verbo"},
            {"palavra": "I", "traducao": "Beber", "categoria": "verbos", "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_170", "exemplo_uso": "A-i 'y.", "exemplo_pt": "Eu bebo água.", "transliteracao": "I", "classe_gramatical": "verbo"},
            {"palavra": "Sawa", "traducao": "Ir", "categoria": "verbos", "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_171", "exemplo_uso": "A-sawa taba pupé.", "exemplo_pt": "Eu vou à aldeia.", "transliteracao": "sa-WA", "classe_gramatical": "verbo"},
            {"palavra": "Kere", "traducao": "Dormir", "categoria": "verbos", "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_172", "exemplo_uso": "A-kere inĩ pupé.", "exemplo_pt": "Eu durmo na rede.", "transliteracao": "ke-RE", "classe_gramatical": "verbo"}
        ],
        13: [
            {"palavra": "Maraká", "traducao": "Chocalho sagrado", "categoria": "musica", "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_180", "exemplo_uso": "Maraká o-puã.", "exemplo_pt": "O maracá soa.", "transliteracao": "ma-ra-KA", "classe_gramatical": "substantivo"},
            {"palavra": "Poracé", "traducao": "Dança tradicional", "categoria": "musica", "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_182", "exemplo_uso": "Poracé taba pupé.", "exemplo_pt": "Dança na aldeia.", "transliteracao": "po-ra-SE", "classe_gramatical": "substantivo"},
            {"palavra": "Toryba", "traducao": "Alegria / Celebração", "categoria": "musica", "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_183", "exemplo_uso": "Toryba guasu!", "exemplo_pt": "Grande celebração!", "transliteracao": "to-ry-BA", "classe_gramatical": "substantivo"}
        ],
        14: [
            {"palavra": "Tupã", "traducao": "O Trovão / Entidade Cósmica", "categoria": "espiritualidade", "rag_id": "6059a27432d6fb84ebb446d48015b8f0cb1ea1bc79c39c7b6e6cc6122613fdfa_chunk_5120", "exemplo_uso": "Tupã o-sunu céu pupé.", "exemplo_pt": "Tupã ribomba no céu.", "transliteracao": "tu-PAN", "classe_gramatical": "substantivo"},
            {"palavra": "Curupira", "traducao": "Guardião da floresta", "categoria": "espiritualidade", "rag_id": "6059a27432d6fb84ebb446d48015b8f0cb1ea1bc79c39c7b6e6cc6122613fdfa_chunk_2840", "exemplo_uso": "Curupira ka'a guardião.", "exemplo_pt": "O Curupira vigia a mata.", "transliteracao": "ku-ru-PI-ra", "classe_gramatical": "substantivo"},
            {"palavra": "Iara", "traducao": "Senhora das águas fluviais", "categoria": "espiritualidade", "rag_id": "6059a27432d6fb84ebb446d48015b8f0cb1ea1bc79c39c7b6e6cc6122613fdfa_chunk_2845", "exemplo_uso": "Iara paraná pupé.", "exemplo_pt": "Iara está nas águas.", "transliteracao": "i-A-ra", "classe_gramatical": "substantivo"}
        ],
        15: [
            {"palavra": "Pajé", "traducao": "Curador / Guia espiritual", "categoria": "espiritualidade", "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_195", "exemplo_uso": "Pajé o-pohano.", "exemplo_pt": "O pajé realiza a cura.", "transliteracao": "pa-JE", "classe_gramatical": "substantivo"},
            {"palavra": "Pohã", "traducao": "Remédio / Planta curativa", "categoria": "cura", "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_196", "exemplo_uso": "Pohã ka'a suí.", "exemplo_pt": "Remédio da floresta.", "transliteracao": "po-HAN", "classe_gramatical": "substantivo"}
        ],
        16: [
            {"palavra": "Pé", "traducao": "Caminho / Trilha", "categoria": "geografia", "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_205", "exemplo_uso": "Pé puranga.", "exemplo_pt": "Caminho seguro.", "transliteracao": "PE", "classe_gramatical": "substantivo"},
            {"palavra": "Guata", "traducao": "Caminhar / Viajar", "categoria": "verbos", "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_206", "exemplo_uso": "A-guata pé rupi.", "exemplo_pt": "Caminho pela trilha.", "transliteracao": "gwa-TA", "classe_gramatical": "verbo"},
            {"palavra": "Peabiru", "traducao": "Caminho ancestral sagrado", "categoria": "historia", "rag_id": "6059a27432d6fb84ebb446d48015b8f0cb1ea1bc79c39c7b6e6cc6122613fdfa_chunk_4386", "exemplo_uso": "Peabiru guasu.", "exemplo_pt": "A grande trilha milenar.", "transliteracao": "pe-a-bi-RU", "classe_gramatical": "substantivo"}
        ],
        17: [
            {"palavra": "Moitará", "traducao": "Troca de bens / Aliança", "categoria": "comunidade", "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_215", "exemplo_uso": "Moitará taba pupé.", "exemplo_pt": "Troca pacífica na aldeia.", "transliteracao": "moi-ta-RA", "classe_gramatical": "substantivo"},
            {"palavra": "Me'eng", "traducao": "Dar / Doar", "categoria": "verbos", "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_216", "exemplo_uso": "A-me'eng manioka.", "exemplo_pt": "Ofereço mandioca.", "transliteracao": "me-ENG", "classe_gramatical": "verbo"}
        ],
        18: [
            {"palavra": "Marandu", "traducao": "História / Memória antiga", "categoria": "narrativa", "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_225", "exemplo_uso": "Marandu antigos suí.", "exemplo_pt": "História dos antepassados.", "transliteracao": "ma-ran-DU", "classe_gramatical": "substantivo"},
            {"palavra": "Mba'e-kuaa", "traducao": "Sabedoria ancestral", "categoria": "narrativa", "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_226", "exemplo_uso": "Mba'e-kuaa guasu.", "exemplo_pt": "Grande conhecimento.", "transliteracao": "mba-e-kwa-A", "classe_gramatical": "substantivo"}
        ],
        19: [
            {"palavra": "Potiguara", "traducao": "Comedores de camarão / Guerreiros da Paraíba", "categoria": "historia", "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_18", "exemplo_uso": "Yande Potiguara!", "exemplo_pt": "Nós somos Potiguaras!", "transliteracao": "po-ti-GWA-ra", "classe_gramatical": "substantivo"},
            {"palavra": "Baía da Traição", "traducao": "Território histórico de resistência", "categoria": "toponimia", "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_20", "exemplo_uso": "Baía da Traição yande terra.", "exemplo_pt": "Baía da Traição é nossa terra.", "transliteracao": "ba-I-a da trai-SAO", "classe_gramatical": "proprio"}
        ],
        20: [
            {"palavra": "Pindorama", "traducao": "Terra das Palmeiras / Brasil indígena", "categoria": "toponimia", "rag_id": "6059a27432d6fb84ebb446d48015b8f0cb1ea1bc79c39c7b6e6cc6122613fdfa_chunk_4386", "exemplo_uso": "Pindorama yande retama.", "exemplo_pt": "Pindorama é nossa terra mãe.", "transliteracao": "pin-do-RA-ma", "classe_gramatical": "proprio"},
            {"palavra": "Nheengatu", "traducao": "A língua boa e articulada", "categoria": "lingua", "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_240", "exemplo_uso": "A-nhe'eng Nheengatu.", "exemplo_pt": "Eu falo a língua boa.", "transliteracao": "nhe-en-ga-TU", "classe_gramatical": "substantivo"}
        ]
    },
    "tupi_antigo": {
        1: [
            {"palavra": "Kauê", "traducao": "Olá / Salve", "categoria": "saudacoes", "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_140", "exemplo_uso": "Kauê, che amigo!", "exemplo_pt": "Olá, meu amigo!", "transliteracao": "ka-u-Ê", "classe_gramatical": "interjeicao"},
            {"palavra": "Ereîur-pe", "traducao": "Vieste?", "categoria": "saudacoes", "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_140", "exemplo_uso": "Ereîur-pe, pa'ĩ?", "exemplo_pt": "Vieste, senhor?", "transliteracao": "e-re-i-UR-pe", "classe_gramatical": "expressao"},
            {"palavra": "Pa'ĩ", "traducao": "Senhor / Tratamento respeitoso", "categoria": "saudacoes", "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_142", "exemplo_uso": "Pa'ĩ katu.", "exemplo_pt": "Bom senhor.", "transliteracao": "pa-IN", "classe_gramatical": "substantivo"},
            {"palavra": "Katu", "traducao": "Bom / Belo", "categoria": "qualidade", "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_145", "exemplo_uso": "Abá katu.", "exemplo_pt": "Homem virtuoso.", "transliteracao": "ka-TU", "classe_gramatical": "adjetivo"},
            {"palavra": "Îandé", "traducao": "Nós (inclusivo)", "categoria": "gramatica", "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_150", "exemplo_uso": "Îandé abá.", "exemplo_pt": "Nós somos pessoas.", "transliteracao": "yan-DE", "classe_gramatical": "pronome"},
            {"palavra": "Xé", "traducao": "Eu / Meu", "categoria": "gramatica", "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_150", "exemplo_uso": "Xé abá katu.", "exemplo_pt": "Eu sou uma pessoa boa.", "transliteracao": "XE", "classe_gramatical": "pronome"}
        ],
        2: [
            {"palavra": "Oka", "traducao": "Casa / Habitação", "categoria": "habitacao", "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_260", "exemplo_uso": "Oka katu.", "exemplo_pt": "Casa espaçosa.", "transliteracao": "O-ka", "classe_gramatical": "substantivo"},
            {"palavra": "Taba", "traducao": "Aldeia cercada", "categoria": "comunidade", "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_260", "exemplo_uso": "Taba guasu.", "exemplo_pt": "Grande aldeia.", "transliteracao": "TA-ba", "classe_gramatical": "substantivo"},
            {"palavra": "Abá", "traducao": "Homem / Pessoa humana", "categoria": "pessoas", "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_262", "exemplo_uso": "Abá katu taba pupé.", "exemplo_pt": "A pessoa boa está na aldeia.", "transliteracao": "a-BA", "classe_gramatical": "substantivo"},
            {"palavra": "Kunhã", "traducao": "Mulher", "categoria": "pessoas", "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_262", "exemplo_uso": "Kunhã katu.", "exemplo_pt": "Mulher virtuosa.", "transliteracao": "ku-NYA", "classe_gramatical": "substantivo"},
            {"palavra": "Tuba", "traducao": "Pai", "categoria": "parentesco", "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_262", "exemplo_uso": "Xé ruba katu.", "exemplo_pt": "Meu pai é bom.", "transliteracao": "TU-ba", "classe_gramatical": "substantivo"},
            {"palavra": "Sy", "traducao": "Mãe", "categoria": "parentesco", "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_263", "exemplo_uso": "Xé sy oka pupé.", "exemplo_pt": "Minha mãe está na casa.", "transliteracao": "SY", "classe_gramatical": "substantivo"},
            {"palavra": "Inĩ", "traducao": "Rede de dormir", "categoria": "utensilios", "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_265", "exemplo_uso": "Inĩ katu.", "exemplo_pt": "Rede confortável.", "transliteracao": "i-NIN", "classe_gramatical": "substantivo"}
        ],
        3: [
            {"palavra": "Îagûara", "traducao": "Onça / Fera feroz", "categoria": "fauna", "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_310", "exemplo_uso": "Îagûara ka'a pupé.", "exemplo_pt": "A onça está na mata.", "transliteracao": "ya-gwa-RA", "classe_gramatical": "substantivo"},
            {"palavra": "Tatu", "traducao": "Tatu", "categoria": "fauna", "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_310", "exemplo_uso": "Tatu yby pupé.", "exemplo_pt": "O tatu cava a terra.", "transliteracao": "ta-TU", "classe_gramatical": "substantivo"},
            {"palavra": "Kapi'ybara", "traducao": "Capivara", "categoria": "fauna", "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_312", "exemplo_uso": "Kapi'ybara 'y rembé.", "exemplo_pt": "A capivara à margem da água.", "transliteracao": "ka-pi-y-ba-RA", "classe_gramatical": "substantivo"},
            {"palavra": "So'ó", "traducao": "Carne / Caça comestível", "categoria": "fauna", "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_314", "exemplo_uso": "So'ó katu.", "exemplo_pt": "Boa caça.", "transliteracao": "so-O", "classe_gramatical": "substantivo"}
        ],
        4: [
            {"palavra": "'Y", "traducao": "Água / Rio", "categoria": "natureza", "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_198", "exemplo_uso": "'Y katu.", "exemplo_pt": "Água doce e pura.", "transliteracao": "Y", "classe_gramatical": "substantivo"},
            {"palavra": "Paraná", "traducao": "Mar / Grande caudal", "categoria": "natureza", "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_198", "exemplo_uso": "Paraná guasu.", "exemplo_pt": "O mar aberto.", "transliteracao": "pa-ra-NA", "classe_gramatical": "substantivo"},
            {"palavra": "Pira", "traducao": "Peixe", "categoria": "fauna", "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_200", "exemplo_uso": "Pira 'y pupé.", "exemplo_pt": "Peixe no rio.", "transliteracao": "pi-RA", "classe_gramatical": "substantivo"},
            {"palavra": "Ygata", "traducao": "Canoa de guerra", "categoria": "transporte", "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_202", "exemplo_uso": "Ygata paraná pupé.", "exemplo_pt": "Canoa no mar.", "transliteracao": "y-ga-TA", "classe_gramatical": "substantivo"}
        ],
        5: [
            {"palavra": "Mani'oka", "traducao": "Mandioca", "categoria": "flora", "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_412", "exemplo_uso": "Mani'oka katu.", "exemplo_pt": "Boa mandioca.", "transliteracao": "ma-ni-O-ka", "classe_gramatical": "substantivo"},
            {"palavra": "Mbyá", "traducao": "Alimento / Comida", "categoria": "alimentos", "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_412", "exemplo_uso": "Mbyá katu.", "exemplo_pt": "Comida saborosa.", "transliteracao": "mby-A", "classe_gramatical": "substantivo"},
            {"palavra": "Kãuĩ", "traducao": "Cauim fermentado", "categoria": "alimentos", "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_414", "exemplo_uso": "Kãuĩ taba pupé.", "exemplo_pt": "Cauim na aldeia.", "transliteracao": "ka-u-IN", "classe_gramatical": "substantivo"},
            {"palavra": "Abati", "traducao": "Milho", "categoria": "flora", "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_415", "exemplo_uso": "Abati taba pupé.", "exemplo_pt": "Milho na aldeia.", "transliteracao": "a-ba-TI", "classe_gramatical": "substantivo"}
        ],
        6: [
            {"palavra": "Kûarasy", "traducao": "Sol", "categoria": "cosmologia", "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_205", "exemplo_uso": "Kûarasy ybak pupé.", "exemplo_pt": "O sol no céu.", "transliteracao": "kwa-ra-SY", "classe_gramatical": "substantivo"},
            {"palavra": "Îasy", "traducao": "Lua", "categoria": "cosmologia", "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_205", "exemplo_uso": "Îasy pykói.", "exemplo_pt": "A lua brilha.", "transliteracao": "ya-SY", "classe_gramatical": "substantivo"},
            {"palavra": "Îasytatá", "traducao": "Estrela", "categoria": "cosmologia", "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_206", "exemplo_uso": "Îasytatá retá.", "exemplo_pt": "Muitas estrelas.", "transliteracao": "ya-sy-ta-TA", "classe_gramatical": "substantivo"}
        ],
        7: [
            {"palavra": "Tata", "traducao": "Fogo", "categoria": "natureza", "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_215", "exemplo_uso": "Tata oka pupé.", "exemplo_pt": "Fogo aceso na oca.", "transliteracao": "ta-TA", "classe_gramatical": "substantivo"},
            {"palavra": "Tatagûasu", "traducao": "Grande fogueira", "categoria": "natureza", "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_216", "exemplo_uso": "Tatagûasu okar pupé.", "exemplo_pt": "Grande fogueira na praça.", "transliteracao": "ta-ta-gwa-SU", "classe_gramatical": "substantivo"},
            {"palavra": "Itá", "traducao": "Pedra / Machado de pedra", "categoria": "natureza", "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_218", "exemplo_uso": "Itá katu.", "exemplo_pt": "Pedra resistente.", "transliteracao": "i-TA", "classe_gramatical": "substantivo"}
        ],
        8: [
            {"palavra": "Gûyrá", "traducao": "Pássaro / Ave", "categoria": "avifauna", "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_320", "exemplo_uso": "Gûyrá o-gûebé.", "exemplo_pt": "O pássaro voa alto.", "transliteracao": "gwy-RA", "classe_gramatical": "substantivo"},
            {"palavra": "Tukan", "traducao": "Tucano", "categoria": "avifauna", "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_321", "exemplo_uso": "Tukan ybyrá ári.", "exemplo_pt": "Tucano no galho.", "transliteracao": "tu-KAN", "classe_gramatical": "substantivo"},
            {"palavra": "Arara", "traducao": "Arara", "categoria": "avifauna", "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_322", "exemplo_uso": "Arara ka'a pupé.", "exemplo_pt": "Arara na floresta.", "transliteracao": "a-RA-ra", "classe_gramatical": "substantivo"}
        ],
        9: [
            {"palavra": "Akanga", "traducao": "Cabeça", "categoria": "corpo", "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_330", "exemplo_uso": "Akanga katu.", "exemplo_pt": "Mente sã.", "transliteracao": "a-KAN-ga", "classe_gramatical": "substantivo"},
            {"palavra": "Esá", "traducao": "Olhos", "categoria": "corpo", "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_330", "exemplo_uso": "Xe resá o-epîák.", "exemplo_pt": "Meus olhos veem.", "transliteracao": "e-SA", "classe_gramatical": "substantivo"},
            {"palavra": "Pó", "traducao": "Mão", "categoria": "corpo", "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_331", "exemplo_uso": "Xe pó katu.", "exemplo_pt": "Minha mão é forte.", "transliteracao": "PO", "classe_gramatical": "substantivo"},
            {"palavra": "Py", "traducao": "Pé", "categoria": "corpo", "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_332", "exemplo_uso": "Py yby ári.", "exemplo_pt": "Pé sobre a terra.", "transliteracao": "PY", "classe_gramatical": "substantivo"}
        ],
        10: [
            {"palavra": "Morubixaba", "traducao": "Chefe político e militar", "categoria": "comunidade", "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_350", "exemplo_uso": "Morubixaba taba pupé.", "exemplo_pt": "O chefe governa na aldeia.", "transliteracao": "mo-ru-bi-XA-ba", "classe_gramatical": "substantivo"},
            {"palavra": "Tamoio", "traducao": "Ancião / Avô venerado", "categoria": "comunidade", "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_352", "exemplo_uso": "Tamoio o-nhe'eng.", "exemplo_pt": "O ancião fala.", "transliteracao": "ta-MOI-o", "classe_gramatical": "substantivo"},
            {"palavra": "Okar", "traducao": "Praça da aldeia", "categoria": "habitacao", "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_355", "exemplo_uso": "Abá okar pupé.", "exemplo_pt": "Gente na praça.", "transliteracao": "o-KAR", "classe_gramatical": "substantivo"}
        ],
        11: [
            {"palavra": "Ka'a", "traducao": "Mata atlântica virgem", "categoria": "flora", "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_360", "exemplo_uso": "Ka'a guasu.", "exemplo_pt": "Grande floresta.", "transliteracao": "ka-A", "classe_gramatical": "substantivo"},
            {"palavra": "Ybyrá", "traducao": "Tronco / Árvore", "categoria": "flora", "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_361", "exemplo_uso": "Ybyrá ka'a pupé.", "exemplo_pt": "Árvore na mata.", "transliteracao": "y-by-RA", "classe_gramatical": "substantivo"},
            {"palavra": "Ybyrapytanga", "traducao": "Pau-brasil (madeira vermelha)", "categoria": "flora", "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_365", "exemplo_uso": "Ybyrapytanga retama.", "exemplo_pt": "Terra do pau-brasil.", "transliteracao": "y-by-ra-py-TAN-ga", "classe_gramatical": "substantivo"}
        ],
        12: [
            {"palavra": "'U", "traducao": "Comer", "categoria": "verbos", "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_540", "exemplo_uso": "A-'u mani'oka.", "exemplo_pt": "Como mandioca.", "transliteracao": "U", "classe_gramatical": "verbo"},
            {"palavra": "'Y", "traducao": "Beber", "categoria": "verbos", "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_540", "exemplo_uso": "A-'y 'y katu.", "exemplo_pt": "Bebo água pura.", "transliteracao": "Y", "classe_gramatical": "verbo"},
            {"palavra": "Só", "traducao": "Ir", "categoria": "verbos", "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_542", "exemplo_uso": "A-só ka'a pupé.", "exemplo_pt": "Vou à mata.", "transliteracao": "SO", "classe_gramatical": "verbo"},
            {"palavra": "Ker", "traducao": "Repousar / Dormir", "categoria": "verbos", "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_544", "exemplo_uso": "A-ker inĩ pupé.", "exemplo_pt": "Durmo na rede.", "transliteracao": "KER", "classe_gramatical": "verbo"}
        ],
        13: [
            {"palavra": "Maraká", "traducao": "Chocalho cerimonial sagrado", "categoria": "musica", "rag_id": "6059a27432d6fb84ebb446d48015b8f0cb1ea1bc79c39c7b6e6cc6122613fdfa_chunk_1402", "exemplo_uso": "Maraká o-nhe'eng.", "exemplo_pt": "O maracá canta.", "transliteracao": "ma-ra-KA", "classe_gramatical": "substantivo"},
            {"palavra": "Toré", "traducao": "Dança e cântico ritual", "categoria": "musica", "rag_id": "6059a27432d6fb84ebb446d48015b8f0cb1ea1bc79c39c7b6e6cc6122613fdfa_chunk_1405", "exemplo_uso": "Toré okar pupé.", "exemplo_pt": "Toré na praça.", "transliteracao": "to-RE", "classe_gramatical": "substantivo"}
        ],
        14: [
            {"palavra": "Tupã", "traducao": "O Trovão Cósmico", "categoria": "espiritualidade", "rag_id": "6059a27432d6fb84ebb446d48015b8f0cb1ea1bc79c39c7b6e6cc6122613fdfa_chunk_5120", "exemplo_uso": "Tupã ybak pupé.", "exemplo_pt": "Tupã troveja no céu.", "transliteracao": "tu-PAN", "classe_gramatical": "substantivo"},
            {"palavra": "Kurupira", "traducao": "Guardião com pés para trás", "categoria": "espiritualidade", "rag_id": "6059a27432d6fb84ebb446d48015b8f0cb1ea1bc79c39c7b6e6cc6122613fdfa_chunk_2840", "exemplo_uso": "Kurupira ka'a guardião.", "exemplo_pt": "Curupira protege a mata.", "transliteracao": "ku-ru-PI-ra", "classe_gramatical": "substantivo"},
            {"palavra": "Anhangá", "traducao": "Espírito da selva", "categoria": "espiritualidade", "rag_id": "6059a27432d6fb84ebb446d48015b8f0cb1ea1bc79c39c7b6e6cc6122613fdfa_chunk_2848", "exemplo_uso": "Anhangá ka'a pupé.", "exemplo_pt": "Anhangá protege as crias.", "transliteracao": "an-han-GA", "classe_gramatical": "substantivo"}
        ],
        15: [
            {"palavra": "Pajé", "traducao": "Guia espiritual e médico", "categoria": "espiritualidade", "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_560", "exemplo_uso": "Pajé o-pohano abá.", "exemplo_pt": "O pajé cura o homem.", "transliteracao": "pa-JE", "classe_gramatical": "substantivo"},
            {"palavra": "Pohã", "traducao": "Planta medicinal / Cura", "categoria": "cura", "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_562", "exemplo_uso": "Pohã katu.", "exemplo_pt": "Remédio eficaz.", "transliteracao": "po-HAN", "classe_gramatical": "substantivo"}
        ],
        16: [
            {"palavra": "Peabiru", "traducao": "Trilha sagrada transcontinental", "categoria": "historia", "rag_id": "6059a27432d6fb84ebb446d48015b8f0cb1ea1bc79c39c7b6e6cc6122613fdfa_chunk_4386", "exemplo_uso": "Peabiru yby rupi.", "exemplo_pt": "O caminho sagrado pela terra.", "transliteracao": "pe-a-bi-RU", "classe_gramatical": "substantivo"},
            {"palavra": "Pé", "traducao": "Caminho / Vereda", "categoria": "geografia", "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_570", "exemplo_uso": "Pé katu.", "exemplo_pt": "Caminho livre.", "transliteracao": "PE", "classe_gramatical": "substantivo"},
            {"palavra": "Gûatá", "traducao": "Viajar a pé", "categoria": "verbos", "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_572", "exemplo_uso": "A-gûatá pé rupi.", "exemplo_pt": "Viajo pela trilha.", "transliteracao": "gwa-TA", "classe_gramatical": "verbo"}
        ],
        17: [
            {"palavra": "Emiré", "traducao": "Presente cerimonial de aliança", "categoria": "comunidade", "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_580", "exemplo_uso": "Emiré katu.", "exemplo_pt": "Dádiva de amizade.", "transliteracao": "e-mi-RE", "classe_gramatical": "substantivo"},
            {"palavra": "Moatyrã", "traducao": "Escambo amigável", "categoria": "comunidade", "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_582", "exemplo_uso": "Moatyrã taba pupé.", "exemplo_pt": "Escambo na aldeia.", "transliteracao": "mo-a-ty-RAN", "classe_gramatical": "substantivo"}
        ],
        18: [
            {"palavra": "Ywy Marã'ey", "traducao": "A Terra Sem Males", "categoria": "mitologia", "rag_id": "6059a27432d6fb84ebb446d48015b8f0cb1ea1bc79c39c7b6e6cc6122613fdfa_chunk_5140", "exemplo_uso": "Ywy Marã'ey katu.", "exemplo_pt": "A terra pura e imortal.", "transliteracao": "y-wy ma-ran-EY", "classe_gramatical": "proprio"},
            {"palavra": "Maíra", "traducao": "Herói civilizador", "categoria": "mitologia", "rag_id": "6059a27432d6fb84ebb446d48015b8f0cb1ea1bc79c39c7b6e6cc6122613fdfa_chunk_5145", "exemplo_uso": "Maíra abá monhang.", "exemplo_pt": "Maíra ensinou as pessoas.", "transliteracao": "ma-I-ra", "classe_gramatical": "proprio"}
        ],
        19: [
            {"palavra": "Iperoig", "traducao": "Ubatuba colonial / Sede dos Tamoios", "categoria": "historia", "rag_id": "6059a27432d6fb84ebb446d48015b8f0cb1ea1bc79c39c7b6e6cc6122613fdfa_chunk_4386", "exemplo_uso": "Iperoig taba.", "exemplo_pt": "Iperoig, aldeia da paz.", "transliteracao": "i-pe-ro-IG", "classe_gramatical": "proprio"},
            {"palavra": "Cunhambebe", "traducao": "Grande líder guerreiro dos Tamoios", "categoria": "historia", "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_110", "exemplo_uso": "Cunhambebe morubixaba.", "exemplo_pt": "Cunhambebe foi o líder.", "transliteracao": "ku-nham-BE-be", "classe_gramatical": "proprio"}
        ],
        20: [
            {"palavra": "Pindorama", "traducao": "Terra das Palmeiras", "categoria": "toponimia", "rag_id": "6059a27432d6fb84ebb446d48015b8f0cb1ea1bc79c39c7b6e6cc6122613fdfa_chunk_4386", "exemplo_uso": "Pindorama yande retama.", "exemplo_pt": "Pindorama é nossa terra sagrada.", "transliteracao": "pin-do-RA-ma", "classe_gramatical": "proprio"},
            {"palavra": "Nhe'engatu", "traducao": "A língua clássica pura", "categoria": "lingua", "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_600", "exemplo_uso": "Nhe'engatu katu.", "exemplo_pt": "A língua correta e nobre.", "transliteracao": "nhe-en-ga-TU", "classe_gramatical": "substantivo"}
        ]
    },
    "kamaiura": {
        1: [
            {"palavra": "Maram katu?", "traducao": "Tudo bem? / Como vai?", "categoria": "saudacoes", "rag_id": "f7a4c5d52c8b29f2507bb7e60bb8fc320fdde1dcf8bffae91301689460a300e0_chunk_95", "exemplo_uso": "Maram katu, ineh?", "exemplo_pt": "Tudo bem com você?", "transliteracao": "ma-RAM ka-TU", "classe_gramatical": "expressao"},
            {"palavra": "Katu", "traducao": "Bom / Bem / Correto", "categoria": "qualidade", "rag_id": "f7a4c5d52c8b29f2507bb7e60bb8fc320fdde1dcf8bffae91301689460a300e0_chunk_95", "exemplo_uso": "Iheh katu.", "exemplo_pt": "Eu estou bem.", "transliteracao": "ka-TU", "classe_gramatical": "adjetivo"},
            {"palavra": "Ineh", "traducao": "Você / Tu", "categoria": "gramatica", "rag_id": "f7a4c5d52c8b29f2507bb7e60bb8fc320fdde1dcf8bffae91301689460a300e0_chunk_98", "exemplo_uso": "Ineh katu.", "exemplo_pt": "Você é bom.", "transliteracao": "i-NEH", "classe_gramatical": "pronome"},
            {"palavra": "Iheh", "traducao": "Eu", "categoria": "gramatica", "rag_id": "f7a4c5d52c8b29f2507bb7e60bb8fc320fdde1dcf8bffae91301689460a300e0_chunk_98", "exemplo_uso": "Iheh Kamaiurá.", "exemplo_pt": "Eu sou Kamaiurá.", "transliteracao": "i-HEH", "classe_gramatical": "pronome"},
            {"palavra": "Jane", "traducao": "Nós (inclusivo)", "categoria": "gramatica", "rag_id": "f7a4c5d52c8b29f2507bb7e60bb8fc320fdde1dcf8bffae91301689460a300e0_chunk_100", "exemplo_uso": "Jane tawa pupé.", "exemplo_pt": "Nós estamos na aldeia.", "transliteracao": "ja-NE", "classe_gramatical": "pronome"},
            {"palavra": "Ore", "traducao": "Nós (exclusivo)", "categoria": "gramatica", "rag_id": "f7a4c5d52c8b29f2507bb7e60bb8fc320fdde1dcf8bffae91301689460a300e0_chunk_100", "exemplo_uso": "Ore a-uri.", "exemplo_pt": "Nós chegamos.", "transliteracao": "o-RE", "classe_gramatical": "pronome"}
        ],
        2: [
            {"palavra": "Oka", "traducao": "Casa comunal xinguana", "categoria": "habitacao", "rag_id": "f7a4c5d52c8b29f2507bb7e60bb8fc320fdde1dcf8bffae91301689460a300e0_chunk_104", "exemplo_uso": "Oka tuwip.", "exemplo_pt": "A casa é ampla.", "transliteracao": "O-ka", "classe_gramatical": "substantivo"},
            {"palavra": "Tawa", "traducao": "Aldeia circular", "categoria": "comunidade", "rag_id": "f7a4c5d52c8b29f2507bb7e60bb8fc320fdde1dcf8bffae91301689460a300e0_chunk_104", "exemplo_uso": "Tawa Ipavu.", "exemplo_pt": "Aldeia de Ipavu.", "transliteracao": "TA-wa", "classe_gramatical": "substantivo"},
            {"palavra": "Awa", "traducao": "Pessoa / Homem", "categoria": "pessoas", "rag_id": "f7a4c5d52c8b29f2507bb7e60bb8fc320fdde1dcf8bffae91301689460a300e0_chunk_120", "exemplo_uso": "Awa katu.", "exemplo_pt": "Homem generoso.", "transliteracao": "a-WA", "classe_gramatical": "substantivo"},
            {"palavra": "Kunya", "traducao": "Mulher", "categoria": "pessoas", "rag_id": "f7a4c5d52c8b29f2507bb7e60bb8fc320fdde1dcf8bffae91301689460a300e0_chunk_120", "exemplo_uso": "Kunya katu.", "exemplo_pt": "Mulher trabalhadora.", "transliteracao": "ku-NYA", "classe_gramatical": "substantivo"},
            {"palavra": "Ruwa", "traducao": "Pai", "categoria": "parentesco", "rag_id": "f7a4c5d52c8b29f2507bb7e60bb8fc320fdde1dcf8bffae91301689460a300e0_chunk_122", "exemplo_uso": "Ruwa oka pupé.", "exemplo_pt": "O pai está na casa.", "transliteracao": "ru-WA", "classe_gramatical": "substantivo"},
            {"palavra": "Iny", "traducao": "Rede de algodão", "categoria": "utensilios", "rag_id": "f7a4c5d52c8b29f2507bb7e60bb8fc320fdde1dcf8bffae91301689460a300e0_chunk_125", "exemplo_uso": "Iny katu.", "exemplo_pt": "Rede tecida.", "transliteracao": "i-NY", "classe_gramatical": "substantivo"}
        ],
        3: [
            {"palavra": "Jawat", "traducao": "Onça / Cão", "categoria": "fauna", "rag_id": "f7a4c5d52c8b29f2507bb7e60bb8fc320fdde1dcf8bffae91301689460a300e0_chunk_180", "exemplo_uso": "Jawat ka'a pupé.", "exemplo_pt": "A onça está na mata.", "transliteracao": "ja-WAT", "classe_gramatical": "substantivo"},
            {"palavra": "Tatu", "traducao": "Tatu", "categoria": "fauna", "rag_id": "f7a4c5d52c8b29f2507bb7e60bb8fc320fdde1dcf8bffae91301689460a300e0_chunk_180", "exemplo_uso": "Tatu iwi pupé.", "exemplo_pt": "Tatu na terra.", "transliteracao": "ta-TU", "classe_gramatical": "substantivo"},
            {"palavra": "Kawarai", "traducao": "Jacaré da lagoa", "categoria": "fauna", "rag_id": "f7a4c5d52c8b29f2507bb7e60bb8fc320fdde1dcf8bffae91301689460a300e0_chunk_182", "exemplo_uso": "Kawarai ypawu pupé.", "exemplo_pt": "Jacaré na lagoa.", "transliteracao": "ka-wa-RAI", "classe_gramatical": "substantivo"},
            {"palavra": "Moia", "traducao": "Serpente / Cobra", "categoria": "fauna", "rag_id": "f7a4c5d52c8b29f2507bb7e60bb8fc320fdde1dcf8bffae91301689460a300e0_chunk_185", "exemplo_uso": "Moia ka'a pupé.", "exemplo_pt": "Cobra na mata.", "transliteracao": "moi-A", "classe_gramatical": "substantivo"}
        ],
        4: [
            {"palavra": "'Y", "traducao": "Água doce / Rio", "categoria": "natureza", "rag_id": "f7a4c5d52c8b29f2507bb7e60bb8fc320fdde1dcf8bffae91301689460a300e0_chunk_88", "exemplo_uso": "'Y katu.", "exemplo_pt": "Água fresca.", "transliteracao": "Y", "classe_gramatical": "substantivo"},
            {"palavra": "Ypawu", "traducao": "Lagoa Ipavu", "categoria": "toponimia", "rag_id": "f7a4c5d52c8b29f2507bb7e60bb8fc320fdde1dcf8bffae91301689460a300e0_chunk_7", "exemplo_uso": "Ypawu guasu.", "exemplo_pt": "A grande lagoa.", "transliteracao": "y-pa-WU", "classe_gramatical": "proprio"},
            {"palavra": "Pira", "traducao": "Peixe", "categoria": "fauna", "rag_id": "f7a4c5d52c8b29f2507bb7e60bb8fc320fdde1dcf8bffae91301689460a300e0_chunk_88", "exemplo_uso": "Pira ypawu pupé.", "exemplo_pt": "Peixe na lagoa.", "transliteracao": "pi-RA", "classe_gramatical": "substantivo"},
            {"palavra": "Yga", "traducao": "Canoa fluvial de casca/tronco", "categoria": "transporte", "rag_id": "f7a4c5d52c8b29f2507bb7e60bb8fc320fdde1dcf8bffae91301689460a300e0_chunk_90", "exemplo_uso": "Yga ypawu rupi.", "exemplo_pt": "Canoa na lagoa.", "transliteracao": "y-GA", "classe_gramatical": "substantivo"}
        ],
        5: [
            {"palavra": "Mani'ok", "traducao": "Mandioca brava", "categoria": "flora", "rag_id": "f7a4c5d52c8b29f2507bb7e60bb8fc320fdde1dcf8bffae91301689460a300e0_chunk_215", "exemplo_uso": "Mani'ok katu.", "exemplo_pt": "Boa mandioca.", "transliteracao": "ma-ni-OK", "classe_gramatical": "substantivo"},
            {"palavra": "Beiju", "traducao": "Beiju tostado", "categoria": "alimentos", "rag_id": "f7a4c5d52c8b29f2507bb7e60bb8fc320fdde1dcf8bffae91301689460a300e0_chunk_215", "exemplo_uso": "Beiju katu.", "exemplo_pt": "Beiju crocante.", "transliteracao": "bei-JU", "classe_gramatical": "substantivo"},
            {"palavra": "Moap", "traducao": "Mingau de polvilho e peixe", "categoria": "alimentos", "rag_id": "f7a4c5d52c8b29f2507bb7e60bb8fc320fdde1dcf8bffae91301689460a300e0_chunk_217", "exemplo_uso": "A-'u moap.", "exemplo_pt": "Tomo o mingau.", "transliteracao": "mo-AP", "classe_gramatical": "substantivo"},
            {"palavra": "Typiti", "traducao": "Espremedor de palha", "categoria": "utensilios", "rag_id": "f7a4c5d52c8b29f2507bb7e60bb8fc320fdde1dcf8bffae91301689460a300e0_chunk_218", "exemplo_uso": "Typiti katu.", "exemplo_pt": "Tipiti bem trançado.", "transliteracao": "ty-pi-TI", "classe_gramatical": "substantivo"}
        ],
        6: [
            {"palavra": "Kwarahy", "traducao": "Sol primordial", "categoria": "cosmologia", "rag_id": "f7a4c5d52c8b29f2507bb7e60bb8fc320fdde1dcf8bffae91301689460a300e0_chunk_230", "exemplo_uso": "Kwarahy pykói.", "exemplo_pt": "O sol brilha no Xingu.", "transliteracao": "kwa-ra-HY", "classe_gramatical": "substantivo"},
            {"palavra": "Jahy", "traducao": "Lua", "categoria": "cosmologia", "rag_id": "f7a4c5d52c8b29f2507bb7e60bb8fc320fdde1dcf8bffae91301689460a300e0_chunk_230", "exemplo_uso": "Jahy pituna pupé.", "exemplo_pt": "Lua na noite xinguana.", "transliteracao": "ja-HY", "classe_gramatical": "substantivo"},
            {"palavra": "Aman", "traducao": "Chuva", "categoria": "natureza", "rag_id": "f7a4c5d52c8b29f2507bb7e60bb8fc320fdde1dcf8bffae91301689460a300e0_chunk_232", "exemplo_uso": "Aman o-ur.", "exemplo_pt": "A chuva vem.", "transliteracao": "a-MAN", "classe_gramatical": "substantivo"}
        ],
        7: [
            {"palavra": "Tata", "traducao": "Fogo", "categoria": "natureza", "rag_id": "f7a4c5d52c8b29f2507bb7e60bb8fc320fdde1dcf8bffae91301689460a300e0_chunk_240", "exemplo_uso": "Tata oka pupé.", "exemplo_pt": "Fogo no centro da oca.", "transliteracao": "ta-TA", "classe_gramatical": "substantivo"},
            {"palavra": "Kapi", "traducao": "Sapé de cobertura", "categoria": "flora", "rag_id": "f7a4c5d52c8b29f2507bb7e60bb8fc320fdde1dcf8bffae91301689460a300e0_chunk_242", "exemplo_uso": "Kapi oka ári.", "exemplo_pt": "Sapé cobre a oca até o chão.", "transliteracao": "ka-PI", "classe_gramatical": "substantivo"},
            {"palavra": "Wyrari", "traducao": "Arco de madeira nobre", "categoria": "utensilios", "rag_id": "f7a4c5d52c8b29f2507bb7e60bb8fc320fdde1dcf8bffae91301689460a300e0_chunk_245", "exemplo_uso": "Wyrari katu.", "exemplo_pt": "Arco resistente.", "transliteracao": "wy-ra-RI", "classe_gramatical": "substantivo"}
        ],
        8: [
            {"palavra": "Wywawura", "traducao": "Pássaro / Ave", "categoria": "avifauna", "rag_id": "f7a4c5d52c8b29f2507bb7e60bb8fc320fdde1dcf8bffae91301689460a300e0_chunk_260", "exemplo_uso": "Wywawura o-wewé.", "exemplo_pt": "O pássaro alça voo.", "transliteracao": "wy-wa-wu-RA", "classe_gramatical": "substantivo"},
            {"palavra": "Tukan", "traducao": "Tucano", "categoria": "avifauna", "rag_id": "f7a4c5d52c8b29f2507bb7e60bb8fc320fdde1dcf8bffae91301689460a300e0_chunk_261", "exemplo_uso": "Tukan ka'a pupé.", "exemplo_pt": "Tucano no topo da mata.", "transliteracao": "tu-KAN", "classe_gramatical": "substantivo"},
            {"palavra": "Kamani", "traducao": "Arara vermelha", "categoria": "avifauna", "rag_id": "f7a4c5d52c8b29f2507bb7e60bb8fc320fdde1dcf8bffae91301689460a300e0_chunk_263", "exemplo_uso": "Kamani katu.", "exemplo_pt": "Bela arara.", "transliteracao": "ka-ma-NI", "classe_gramatical": "substantivo"}
        ],
        9: [
            {"palavra": "Akang", "traducao": "Cabeça", "categoria": "corpo", "rag_id": "f7a4c5d52c8b29f2507bb7e60bb8fc320fdde1dcf8bffae91301689460a300e0_chunk_270", "exemplo_uso": "Akang katu.", "exemplo_pt": "Cabeça boa.", "transliteracao": "a-KANG", "classe_gramatical": "substantivo"},
            {"palavra": "Po", "traducao": "Mão", "categoria": "corpo", "rag_id": "f7a4c5d52c8b29f2507bb7e60bb8fc320fdde1dcf8bffae91301689460a300e0_chunk_271", "exemplo_uso": "Po katu.", "exemplo_pt": "Mão firme.", "transliteracao": "PO", "classe_gramatical": "substantivo"},
            {"palavra": "Py", "traducao": "Pé", "categoria": "corpo", "rag_id": "f7a4c5d52c8b29f2507bb7e60bb8fc320fdde1dcf8bffae91301689460a300e0_chunk_272", "exemplo_uso": "Py iwi ári.", "exemplo_pt": "Pés na terra vermelha.", "transliteracao": "PY", "classe_gramatical": "substantivo"},
            {"palavra": "Uruku", "traducao": "Urucum para pintura corporal", "categoria": "cultura", "rag_id": "f7a4c5d52c8b29f2507bb7e60bb8fc320fdde1dcf8bffae91301689460a300e0_chunk_275", "exemplo_uso": "Uruku pirera pupé.", "exemplo_pt": "Urucum vermelho na pele.", "transliteracao": "u-ru-KU", "classe_gramatical": "substantivo"}
        ],
        10: [
            {"palavra": "Morokwiat", "traducao": "Chefe da aldeia", "categoria": "comunidade", "rag_id": "f7a4c5d52c8b29f2507bb7e60bb8fc320fdde1dcf8bffae91301689460a300e0_chunk_120", "exemplo_uso": "Morokwiat tawa pupé.", "exemplo_pt": "O líder fala na aldeia.", "transliteracao": "mo-ro-kwi-AT", "classe_gramatical": "substantivo"},
            {"palavra": "Okara", "traducao": "Praça central redonda", "categoria": "comunidade", "rag_id": "f7a4c5d52c8b29f2507bb7e60bb8fc320fdde1dcf8bffae91301689460a300e0_chunk_122", "exemplo_uso": "Awa okara pupé.", "exemplo_pt": "Gente reunida na praça.", "transliteracao": "o-ka-RA", "classe_gramatical": "substantivo"}
        ],
        11: [
            {"palavra": "Iwyra", "traducao": "Árvore sagrada / Tronco", "categoria": "flora", "rag_id": "f7a4c5d52c8b29f2507bb7e60bb8fc320fdde1dcf8bffae91301689460a300e0_chunk_285", "exemplo_uso": "Iwyra katu.", "exemplo_pt": "Árvore nobre.", "transliteracao": "i-wy-RA", "classe_gramatical": "substantivo"},
            {"palavra": "Ka'a", "traducao": "Floresta tropical do Xingu", "categoria": "flora", "rag_id": "f7a4c5d52c8b29f2507bb7e60bb8fc320fdde1dcf8bffae91301689460a300e0_chunk_286", "exemplo_uso": "Ka'a tuwip.", "exemplo_pt": "Mata densa.", "transliteracao": "ka-A", "classe_gramatical": "substantivo"}
        ],
        12: [
            {"palavra": "'U", "traducao": "Comer", "categoria": "verbos", "rag_id": "f7a4c5d52c8b29f2507bb7e60bb8fc320fdde1dcf8bffae91301689460a300e0_chunk_310", "exemplo_uso": "A-'u pira.", "exemplo_pt": "Como peixe assado.", "transliteracao": "U", "classe_gramatical": "verbo"},
            {"palavra": "'Y", "traducao": "Beber", "categoria": "verbos", "rag_id": "f7a4c5d52c8b29f2507bb7e60bb8fc320fdde1dcf8bffae91301689460a300e0_chunk_310", "exemplo_uso": "A-'y 'y.", "exemplo_pt": "Bebo água pura.", "transliteracao": "Y", "classe_gramatical": "verbo"},
            {"palavra": "So", "traducao": "Ir", "categoria": "verbos", "rag_id": "f7a4c5d52c8b29f2507bb7e60bb8fc320fdde1dcf8bffae91301689460a300e0_chunk_312", "exemplo_uso": "A-so ypawu pupé.", "exemplo_pt": "Vou à lagoa.", "transliteracao": "SO", "classe_gramatical": "verbo"},
            {"palavra": "Ke", "traducao": "Dormir", "categoria": "verbos", "rag_id": "f7a4c5d52c8b29f2507bb7e60bb8fc320fdde1dcf8bffae91301689460a300e0_chunk_314", "exemplo_uso": "A-ke iny pupé.", "exemplo_pt": "Durmo na rede de algodão.", "transliteracao": "KE", "classe_gramatical": "verbo"}
        ],
        13: [
            {"palavra": "Urua", "traducao": "Flautas sagradas de taquara", "categoria": "musica", "rag_id": "f7a4c5d52c8b29f2507bb7e60bb8fc320fdde1dcf8bffae91301689460a300e0_chunk_410", "exemplo_uso": "Urua o-ze'eng.", "exemplo_pt": "As flautas uruá ressoam.", "transliteracao": "u-ru-A", "classe_gramatical": "substantivo"},
            {"palavra": "Tororé", "traducao": "Canto circular dos guerreiros", "categoria": "musica", "rag_id": "f7a4c5d52c8b29f2507bb7e60bb8fc320fdde1dcf8bffae91301689460a300e0_chunk_412", "exemplo_uso": "Tororé okara pupé.", "exemplo_pt": "Tororé na praça da aldeia.", "transliteracao": "to-ro-RE", "classe_gramatical": "substantivo"}
        ],
        14: [
            {"palavra": "Mavutsinim", "traducao": "O Criador primordial xinguano", "categoria": "mitologia", "rag_id": "f7a4c5d52c8b29f2507bb7e60bb8fc320fdde1dcf8bffae91301689460a300e0_chunk_415", "exemplo_uso": "Mavutsinim awa o-monhang.", "exemplo_pt": "Mavutsinim criou as gentes dos troncos.", "transliteracao": "ma-vu-tsi-NIM", "classe_gramatical": "proprio"},
            {"palavra": "Mama'e", "traducao": "Espírito guardião da mata", "categoria": "espiritualidade", "rag_id": "f7a4c5d52c8b29f2507bb7e60bb8fc320fdde1dcf8bffae91301689460a300e0_chunk_418", "exemplo_uso": "Mama'e ka'a pupé.", "exemplo_pt": "O espírito protege as águas.", "transliteracao": "ma-ma-E", "classe_gramatical": "substantivo"}
        ],
        15: [
            {"palavra": "Paye", "traducao": "Xamã curador Kamaiurá", "categoria": "espiritualidade", "rag_id": "f7a4c5d52c8b29f2507bb7e60bb8fc320fdde1dcf8bffae91301689460a300e0_chunk_420", "exemplo_uso": "Paye o-pohano.", "exemplo_pt": "O pajé sopra a cura.", "transliteracao": "pa-YE", "classe_gramatical": "substantivo"},
            {"palavra": "Pohã", "traducao": "Planta medicinal do Xingu", "categoria": "cura", "rag_id": "f7a4c5d52c8b29f2507bb7e60bb8fc320fdde1dcf8bffae91301689460a300e0_chunk_422", "exemplo_uso": "Pohã katu.", "exemplo_pt": "Planta de cura forte.", "transliteracao": "po-HAN", "classe_gramatical": "substantivo"}
        ],
        16: [
            {"palavra": "Pe", "traducao": "Trilha fluvial ou terrestre", "categoria": "geografia", "rag_id": "f7a4c5d52c8b29f2507bb7e60bb8fc320fdde1dcf8bffae91301689460a300e0_chunk_430", "exemplo_uso": "Pe tawa katy.", "exemplo_pt": "Trilha rumo à aldeia.", "transliteracao": "PE", "classe_gramatical": "substantivo"},
            {"palavra": "Wata", "traducao": "Andar a pé", "categoria": "verbos", "rag_id": "f7a4c5d52c8b29f2507bb7e60bb8fc320fdde1dcf8bffae91301689460a300e0_chunk_432", "exemplo_uso": "A-wata pe rupi.", "exemplo_pt": "Ando pelo caminho.", "transliteracao": "wa-TA", "classe_gramatical": "verbo"}
        ],
        17: [
            {"palavra": "Moitará", "traducao": "Cerimônia solene de trocas", "categoria": "comunidade", "rag_id": "f7a4c5d52c8b29f2507bb7e60bb8fc320fdde1dcf8bffae91301689460a300e0_chunk_440", "exemplo_uso": "Moitará okara pupé.", "exemplo_pt": "Festa do moitará na praça.", "transliteracao": "moi-ta-RA", "classe_gramatical": "substantivo"},
            {"palavra": "Jawari", "traducao": "Ritual guerreiro do dardo", "categoria": "ritos", "rag_id": "f7a4c5d52c8b29f2507bb7e60bb8fc320fdde1dcf8bffae91301689460a300e0_chunk_442", "exemplo_uso": "Jawari katu.", "exemplo_pt": "Cerimônia do Jawari.", "transliteracao": "ja-wa-RI", "classe_gramatical": "substantivo"}
        ],
        18: [
            {"palavra": "Kuarup", "traducao": "Grande ritual sagrado dos mortos", "categoria": "ritos", "rag_id": "f7a4c5d52c8b29f2507bb7e60bb8fc320fdde1dcf8bffae91301689460a300e0_chunk_450", "exemplo_uso": "Kuarup tawa Ipavu.", "exemplo_pt": "Kuarup na aldeia Ipavu.", "transliteracao": "kwa-RUP", "classe_gramatical": "proprio"},
            {"palavra": "Huka-huka", "traducao": "Luta sacrificial tradicional", "categoria": "esportes", "rag_id": "f7a4c5d52c8b29f2507bb7e60bb8fc320fdde1dcf8bffae91301689460a300e0_chunk_452", "exemplo_uso": "Huka-huka okara pupé.", "exemplo_pt": "Luta huka-huka na praça.", "transliteracao": "hu-ka-HU-ka", "classe_gramatical": "substantivo"}
        ],
        19: [
            {"palavra": "Morená", "traducao": "Sítio sagrado ancestral do Xingu", "categoria": "toponimia", "rag_id": "f7a4c5d52c8b29f2507bb7e60bb8fc320fdde1dcf8bffae91301689460a300e0_chunk_8", "exemplo_uso": "Morená y-confluência.", "exemplo_pt": "Morená, berço mítico.", "transliteracao": "mo-re-NA", "classe_gramatical": "proprio"},
            {"palavra": "Kuluene", "traducao": "Rio Kuluene (formador do Xingu)", "categoria": "toponimia", "rag_id": "f7a4c5d52c8b29f2507bb7e60bb8fc320fdde1dcf8bffae91301689460a300e0_chunk_96", "exemplo_uso": "Kuluene 'y guasu.", "exemplo_pt": "O grande rio Kuluene.", "transliteracao": "ku-lu-E-ne", "classe_gramatical": "proprio"}
        ],
        20: [
            {"palavra": "Aldeia Ipavu", "traducao": "Aldeia central dos Kamaiurá", "categoria": "toponimia", "rag_id": "f7a4c5d52c8b29f2507bb7e60bb8fc320fdde1dcf8bffae91301689460a300e0_chunk_7", "exemplo_uso": "Tawa Ipavu katu.", "exemplo_pt": "A aldeia de Ipavu permanece viva.", "transliteracao": "al-dei-a i-pa-VU", "classe_gramatical": "proprio"},
            {"palavra": "Kamaiurá Ze'eng", "traducao": "A língua viva dos Kamaiurá", "categoria": "lingua", "rag_id": "f7a4c5d52c8b29f2507bb7e60bb8fc320fdde1dcf8bffae91301689460a300e0_chunk_500", "exemplo_uso": "Kamaiurá ze'eng katu.", "exemplo_pt": "A língua Kamaiurá perdura.", "transliteracao": "ka-mai-u-RA ze-ENG", "classe_gramatical": "proprio"}
        ]
    },
    "tupinamba": {
        1: [
            {"palavra": "Ereîur", "traducao": "Vieste / Chegaste", "categoria": "saudacoes", "rag_id": "b5e6721f1778931d12ca59f0e7e7c212cfc05d27c12f9eb7b73edf4ae45ba84d_chunk_112", "exemplo_uso": "Ereîur katu!", "exemplo_pt": "Chegaste em boa hora!", "transliteracao": "e-re-i-UR", "classe_gramatical": "expressao"},
            {"palavra": "Ereîîubé", "traducao": "Chegaste são e salvo?", "categoria": "saudacoes", "rag_id": "b5e6721f1778931d12ca59f0e7e7c212cfc05d27c12f9eb7b73edf4ae45ba84d_chunk_112", "exemplo_uso": "Ereîîubé, pa'ĩ?", "exemplo_pt": "Chegaste bem, senhor?", "transliteracao": "e-re-i-yu-BE", "classe_gramatical": "expressao"},
            {"palavra": "Pa'ĩ", "traducao": "Senhor honrado", "categoria": "saudacoes", "rag_id": "b5e6721f1778931d12ca59f0e7e7c212cfc05d27c12f9eb7b73edf4ae45ba84d_chunk_115", "exemplo_uso": "Pa'ĩ katu.", "exemplo_pt": "Senhor justo.", "transliteracao": "pa-IN", "classe_gramatical": "substantivo"},
            {"palavra": "Katu", "traducao": "Nobre / Justo / Bom", "categoria": "qualidade", "rag_id": "b5e6721f1778931d12ca59f0e7e7c212cfc05d27c12f9eb7b73edf4ae45ba84d_chunk_116", "exemplo_uso": "Abá katu.", "exemplo_pt": "Homem guerreiro e bom.", "transliteracao": "ka-TU", "classe_gramatical": "adjetivo"},
            {"palavra": "Oré", "traducao": "Nós (os guerreiros)", "categoria": "gramatica", "rag_id": "b5e6721f1778931d12ca59f0e7e7c212cfc05d27c12f9eb7b73edf4ae45ba84d_chunk_120", "exemplo_uso": "Oré Tupinambá.", "exemplo_pt": "Nós somos Tupinambás.", "transliteracao": "o-RE", "classe_gramatical": "pronome"}
        ],
        2: [
            {"palavra": "Oka", "traducao": "Maloca comunal", "categoria": "habitacao", "rag_id": "b5e6721f1778931d12ca59f0e7e7c212cfc05d27c12f9eb7b73edf4ae45ba84d_chunk_130", "exemplo_uso": "Oka guasu.", "exemplo_pt": "Grande maloca.", "transliteracao": "O-ka", "classe_gramatical": "substantivo"},
            {"palavra": "Taba", "traducao": "Aldeia cercada de paliçada", "categoria": "comunidade", "rag_id": "b5e6721f1778931d12ca59f0e7e7c212cfc05d27c12f9eb7b73edf4ae45ba84d_chunk_130", "exemplo_uso": "Taba Tupinambá.", "exemplo_pt": "Aldeia Tupinambá.", "transliteracao": "TA-ba", "classe_gramatical": "substantivo"},
            {"palavra": "Abá", "traducao": "Guerreiro / Homem livre", "categoria": "pessoas", "rag_id": "b5e6721f1778931d12ca59f0e7e7c212cfc05d27c12f9eb7b73edf4ae45ba84d_chunk_132", "exemplo_uso": "Abá katu.", "exemplo_pt": "Homem valoroso.", "transliteracao": "a-BA", "classe_gramatical": "substantivo"},
            {"palavra": "Kunhã", "traducao": "Mulher", "categoria": "pessoas", "rag_id": "b5e6721f1778931d12ca59f0e7e7c212cfc05d27c12f9eb7b73edf4ae45ba84d_chunk_132", "exemplo_uso": "Kunhã oka pupé.", "exemplo_pt": "Mulher na maloca.", "transliteracao": "ku-NYA", "classe_gramatical": "substantivo"},
            {"palavra": "Tuba", "traducao": "Pai ancestral", "categoria": "parentesco", "rag_id": "b5e6721f1778931d12ca59f0e7e7c212cfc05d27c12f9eb7b73edf4ae45ba84d_chunk_135", "exemplo_uso": "Tuba katu.", "exemplo_pt": "Pai honorável.", "transliteracao": "TU-ba", "classe_gramatical": "substantivo"}
        ],
        3: [
            {"palavra": "Îagûara", "traducao": "Onça guerreira", "categoria": "fauna", "rag_id": "b5e6721f1778931d12ca59f0e7e7c212cfc05d27c12f9eb7b73edf4ae45ba84d_chunk_74", "exemplo_uso": "Îagûara ka'a pupé.", "exemplo_pt": "A onça caminha na mata.", "transliteracao": "ya-gwa-RA", "classe_gramatical": "substantivo"},
            {"palavra": "Tatu", "traducao": "Tatu da costa", "categoria": "fauna", "rag_id": "b5e6721f1778931d12ca59f0e7e7c212cfc05d27c12f9eb7b73edf4ae45ba84d_chunk_74", "exemplo_uso": "Tatu yby pupé.", "exemplo_pt": "O tatu cava.", "transliteracao": "ta-TU", "classe_gramatical": "substantivo"},
            {"palavra": "So'ó", "traducao": "Carne de caça", "categoria": "fauna", "rag_id": "b5e6721f1778931d12ca59f0e7e7c212cfc05d27c12f9eb7b73edf4ae45ba84d_chunk_76", "exemplo_uso": "So'ó katu.", "exemplo_pt": "Alimento da caçada.", "transliteracao": "so-O", "classe_gramatical": "substantivo"}
        ],
        4: [
            {"palavra": "Paraná", "traducao": "O mar aberto costeiro", "categoria": "natureza", "rag_id": "b5e6721f1778931d12ca59f0e7e7c212cfc05d27c12f9eb7b73edf4ae45ba84d_chunk_60", "exemplo_uso": "Paraná guasu.", "exemplo_pt": "O grande oceano.", "transliteracao": "pa-ra-NA", "classe_gramatical": "substantivo"},
            {"palavra": "'Y", "traducao": "Água da nascente", "categoria": "natureza", "rag_id": "b5e6721f1778931d12ca59f0e7e7c212cfc05d27c12f9eb7b73edf4ae45ba84d_chunk_60", "exemplo_uso": "'Y katu.", "exemplo_pt": "Água de beber.", "transliteracao": "Y", "classe_gramatical": "substantivo"},
            {"palavra": "Pira", "traducao": "Peixe do mar", "categoria": "fauna", "rag_id": "b5e6721f1778931d12ca59f0e7e7c212cfc05d27c12f9eb7b73edf4ae45ba84d_chunk_62", "exemplo_uso": "Pira paraná pupé.", "exemplo_pt": "Peixe nas águas do mar.", "transliteracao": "pi-RA", "classe_gramatical": "substantivo"},
            {"palavra": "Ygata", "traducao": "Canoa de guerra marítima", "categoria": "transporte", "rag_id": "b5e6721f1778931d12ca59f0e7e7c212cfc05d27c12f9eb7b73edf4ae45ba84d_chunk_65", "exemplo_uso": "Ygata rembaba.", "exemplo_pt": "Remadores na canoa.", "transliteracao": "y-ga-TA", "classe_gramatical": "substantivo"}
        ],
        5: [
            {"palavra": "Mani'oka", "traducao": "Mandioca da roça", "categoria": "flora", "rag_id": "b5e6721f1778931d12ca59f0e7e7c212cfc05d27c12f9eb7b73edf4ae45ba84d_chunk_80", "exemplo_uso": "Mani'oka katu.", "exemplo_pt": "Boa raiz de mandioca.", "transliteracao": "ma-ni-O-ka", "classe_gramatical": "substantivo"},
            {"palavra": "Kauim", "traducao": "Bebida sagrada fermentada", "categoria": "alimentos", "rag_id": "b5e6721f1778931d12ca59f0e7e7c212cfc05d27c12f9eb7b73edf4ae45ba84d_chunk_82", "exemplo_uso": "Kauim taba pupé.", "exemplo_pt": "Cauim para os guerreiros.", "transliteracao": "ka-u-IM", "classe_gramatical": "substantivo"},
            {"palavra": "U'i", "traducao": "Farinha de guerra seca", "categoria": "alimentos", "rag_id": "b5e6721f1778931d12ca59f0e7e7c212cfc05d27c12f9eb7b73edf4ae45ba84d_chunk_83", "exemplo_uso": "U'i ygata pupé.", "exemplo_pt": "Farinha levada na canoa.", "transliteracao": "u-I", "classe_gramatical": "substantivo"}
        ],
        6: [
            {"palavra": "Kûarasy", "traducao": "Sol costeiro", "categoria": "cosmologia", "rag_id": "b5e6721f1778931d12ca59f0e7e7c212cfc05d27c12f9eb7b73edf4ae45ba84d_chunk_90", "exemplo_uso": "Kûarasy paraná ári.", "exemplo_pt": "O sol sobre o mar.", "transliteracao": "kwa-ra-SY", "classe_gramatical": "substantivo"},
            {"palavra": "Îasy", "traducao": "Lua que rege a maré", "categoria": "cosmologia", "rag_id": "b5e6721f1778931d12ca59f0e7e7c212cfc05d27c12f9eb7b73edf4ae45ba84d_chunk_90", "exemplo_uso": "Îasy paraná mbo-yere.", "exemplo_pt": "A lua move as marés.", "transliteracao": "ya-SY", "classe_gramatical": "substantivo"}
        ],
        7: [
            {"palavra": "Tata", "traducao": "Fogo da paliçada", "categoria": "natureza", "rag_id": "b5e6721f1778931d12ca59f0e7e7c212cfc05d27c12f9eb7b73edf4ae45ba84d_chunk_95", "exemplo_uso": "Tata taba pupé.", "exemplo_pt": "Fogo aceso na aldeia.", "transliteracao": "ta-TA", "classe_gramatical": "substantivo"},
            {"palavra": "Ibirapema", "traducao": "Tacape de madeira nobre", "categoria": "armas", "rag_id": "b5e6721f1778931d12ca59f0e7e7c212cfc05d27c12f9eb7b73edf4ae45ba84d_chunk_98", "exemplo_uso": "Ibirapema katu.", "exemplo_pt": "Tacape cerimonial afiado.", "transliteracao": "i-bi-ra-PE-ma", "classe_gramatical": "substantivo"},
            {"palavra": "Uba", "traducao": "Arco de flechas", "categoria": "armas", "rag_id": "b5e6721f1778931d12ca59f0e7e7c212cfc05d27c12f9eb7b73edf4ae45ba84d_chunk_99", "exemplo_uso": "Uba abá pó pupé.", "exemplo_pt": "O arco na mão do guerreiro.", "transliteracao": "u-BA", "classe_gramatical": "substantivo"}
        ],
        8: [
            {"palavra": "Gûyrá", "traducao": "Ave / Pássaro", "categoria": "avifauna", "rag_id": "b5e6721f1778931d12ca59f0e7e7c212cfc05d27c12f9eb7b73edf4ae45ba84d_chunk_105", "exemplo_uso": "Gûyrá o-gûebé.", "exemplo_pt": "O pássaro marinho voa.", "transliteracao": "gwy-RA", "classe_gramatical": "substantivo"},
            {"palavra": "Gûará", "traducao": "Guará vermelho da restinga", "categoria": "avifauna", "rag_id": "b5e6721f1778931d12ca59f0e7e7c212cfc05d27c12f9eb7b73edf4ae45ba84d_chunk_106", "exemplo_uso": "Gûará pyrang.", "exemplo_pt": "O guará é escarlate.", "transliteracao": "gwa-RA", "classe_gramatical": "substantivo"}
        ],
        9: [
            {"palavra": "Akanga", "traducao": "Cabeça / Cocada de penas", "categoria": "corpo", "rag_id": "b5e6721f1778931d12ca59f0e7e7c212cfc05d27c12f9eb7b73edf4ae45ba84d_chunk_110", "exemplo_uso": "Akanga katu.", "exemplo_pt": "Cabeça adornada.", "transliteracao": "a-KAN-ga", "classe_gramatical": "substantivo"},
            {"palavra": "Esá", "traducao": "Olhos atentos", "categoria": "corpo", "rag_id": "b5e6721f1778931d12ca59f0e7e7c212cfc05d27c12f9eb7b73edf4ae45ba84d_chunk_110", "exemplo_uso": "Esá o-epîák.", "exemplo_pt": "Os olhos vigiam o mar.", "transliteracao": "e-SA", "classe_gramatical": "substantivo"},
            {"palavra": "Pó", "traducao": "Mão do combatente", "categoria": "corpo", "rag_id": "b5e6721f1778931d12ca59f0e7e7c212cfc05d27c12f9eb7b73edf4ae45ba84d_chunk_111", "exemplo_uso": "Pó katu.", "exemplo_pt": "Mão firme.", "transliteracao": "PO", "classe_gramatical": "substantivo"}
        ],
        10: [
            {"palavra": "Tuxaua", "traducao": "Comandante de guerra", "categoria": "comunidade", "rag_id": "b5e6721f1778931d12ca59f0e7e7c212cfc05d27c12f9eb7b73edf4ae45ba84d_chunk_140", "exemplo_uso": "Tuxaua o-nhe'eng.", "exemplo_pt": "O comandante fala aos guerreiros.", "transliteracao": "tu-XA-wa", "classe_gramatical": "substantivo"},
            {"palavra": "Tamoio", "traducao": "Os antigos da federação", "categoria": "comunidade", "rag_id": "b5e6721f1778931d12ca59f0e7e7c212cfc05d27c12f9eb7b73edf4ae45ba84d_chunk_142", "exemplo_uso": "Tamoio katu.", "exemplo_pt": "Aliados juramentados.", "transliteracao": "ta-MOI-o", "classe_gramatical": "substantivo"},
            {"palavra": "Okar", "traducao": "Praça de assembléia da taba", "categoria": "habitacao", "rag_id": "b5e6721f1778931d12ca59f0e7e7c212cfc05d27c12f9eb7b73edf4ae45ba84d_chunk_145", "exemplo_uso": "Abá okar pupé.", "exemplo_pt": "Homens reunidos na praça.", "transliteracao": "o-KAR", "classe_gramatical": "substantivo"}
        ],
        11: [
            {"palavra": "Ybyrapytanga", "traducao": "Pau-brasil costeiro", "categoria": "flora", "rag_id": "b5e6721f1778931d12ca59f0e7e7c212cfc05d27c12f9eb7b73edf4ae45ba84d_chunk_150", "exemplo_uso": "Ybyrapytanga retama.", "exemplo_pt": "A terra da madeira vermelha.", "transliteracao": "y-by-ra-py-TAN-ga", "classe_gramatical": "substantivo"},
            {"palavra": "Ka'a", "traducao": "Floresta tropical costeira", "categoria": "flora", "rag_id": "b5e6721f1778931d12ca59f0e7e7c212cfc05d27c12f9eb7b73edf4ae45ba84d_chunk_152", "exemplo_uso": "Ka'a guasu.", "exemplo_pt": "A densa mata atlântica.", "transliteracao": "ka-A", "classe_gramatical": "substantivo"}
        ],
        12: [
            {"palavra": "'U", "traducao": "Comer / Alimentar", "categoria": "verbos", "rag_id": "b5e6721f1778931d12ca59f0e7e7c212cfc05d27c12f9eb7b73edf4ae45ba84d_chunk_160", "exemplo_uso": "A-'u so'ó.", "exemplo_pt": "Como carne de caça.", "transliteracao": "U", "classe_gramatical": "verbo"},
            {"palavra": "Só", "traducao": "Ir à expedição", "categoria": "verbos", "rag_id": "b5e6721f1778931d12ca59f0e7e7c212cfc05d27c12f9eb7b73edf4ae45ba84d_chunk_162", "exemplo_uso": "A-só ygata pupé.", "exemplo_pt": "Embarco na canoa.", "transliteracao": "SO", "classe_gramatical": "verbo"},
            {"palavra": "Îur", "traducao": "Retornar vitorioso", "categoria": "verbos", "rag_id": "b5e6721f1778931d12ca59f0e7e7c212cfc05d27c12f9eb7b73edf4ae45ba84d_chunk_164", "exemplo_uso": "A-îur taba katy.", "exemplo_pt": "Retorno à aldeia.", "transliteracao": "yur", "classe_gramatical": "verbo"}
        ],
        13: [
            {"palavra": "Maraká", "traducao": "Chocalho ritual dos combatentes", "categoria": "musica", "rag_id": "b5e6721f1778931d12ca59f0e7e7c212cfc05d27c12f9eb7b73edf4ae45ba84d_chunk_170", "exemplo_uso": "Maraká o-puã.", "exemplo_pt": "O maracá é sacudido no rito.", "transliteracao": "ma-ra-KA", "classe_gramatical": "substantivo"},
            {"palavra": "Toré", "traducao": "Marcha com passos fortes", "categoria": "musica", "rag_id": "b5e6721f1778931d12ca59f0e7e7c212cfc05d27c12f9eb7b73edf4ae45ba84d_chunk_172", "exemplo_uso": "Toré okar pupé.", "exemplo_pt": "A marcha dos guerreiros.", "transliteracao": "to-RE", "classe_gramatical": "substantivo"}
        ],
        14: [
            {"palavra": "Tupã", "traducao": "O senhor do trovão oceânico", "categoria": "espiritualidade", "rag_id": "6059a27432d6fb84ebb446d48015b8f0cb1ea1bc79c39c7b6e6cc6122613fdfa_chunk_5120", "exemplo_uso": "Tupã o-sunu.", "exemplo_pt": "O trovão retumba nas águas.", "transliteracao": "tu-PAN", "classe_gramatical": "substantivo"},
            {"palavra": "Karaíba", "traducao": "Profeta da Terra Sem Males", "categoria": "espiritualidade", "rag_id": "b5e6721f1778931d12ca59f0e7e7c212cfc05d27c12f9eb7b73edf4ae45ba84d_chunk_180", "exemplo_uso": "Karaíba o-nhe'eng.", "exemplo_pt": "O profeta anuncia a terra imortal.", "transliteracao": "ka-ra-I-ba", "classe_gramatical": "substantivo"}
        ],
        15: [
            {"palavra": "Pajé", "traducao": "Xamã e médico da confederação", "categoria": "espiritualidade", "rag_id": "b5e6721f1778931d12ca59f0e7e7c212cfc05d27c12f9eb7b73edf4ae45ba84d_chunk_185", "exemplo_uso": "Pajé o-pohano abá.", "exemplo_pt": "O pajé assiste os feridos.", "transliteracao": "pa-JE", "classe_gramatical": "substantivo"},
            {"palavra": "Pohã", "traducao": "Ervas de restinga", "categoria": "cura", "rag_id": "b5e6721f1778931d12ca59f0e7e7c212cfc05d27c12f9eb7b73edf4ae45ba84d_chunk_186", "exemplo_uso": "Pohã katu.", "exemplo_pt": "Bálsamo da mata.", "transliteracao": "po-HAN", "classe_gramatical": "substantivo"}
        ],
        16: [
            {"palavra": "Pé", "traducao": "Trilha litorânea dos guerreiros", "categoria": "geografia", "rag_id": "b5e6721f1778931d12ca59f0e7e7c212cfc05d27c12f9eb7b73edf4ae45ba84d_chunk_190", "exemplo_uso": "Pé paraná rembé.", "exemplo_pt": "Caminho pela orla.", "transliteracao": "PE", "classe_gramatical": "substantivo"},
            {"palavra": "Ygarapé", "traducao": "Canal de retirada das canoas", "categoria": "geografia", "rag_id": "b5e6721f1778931d12ca59f0e7e7c212cfc05d27c12f9eb7b73edf4ae45ba84d_chunk_192", "exemplo_uso": "Ygarapé puranga.", "exemplo_pt": "Canal protegido.", "transliteracao": "i-ga-ra-PE", "classe_gramatical": "substantivo"}
        ],
        17: [
            {"palavra": "Tobaîara", "traducao": "Oponente digno / Antagonista", "categoria": "comunidade", "rag_id": "b5e6721f1778931d12ca59f0e7e7c212cfc05d27c12f9eb7b73edf4ae45ba84d_chunk_200", "exemplo_uso": "Tobaîara katu.", "exemplo_pt": "Combatente leal.", "transliteracao": "to-bai-A-ra", "classe_gramatical": "substantivo"},
            {"palavra": "Emiré", "traducao": "Pacto selado de aliança", "categoria": "comunidade", "rag_id": "b5e6721f1778931d12ca59f0e7e7c212cfc05d27c12f9eb7b73edf4ae45ba84d_chunk_202", "exemplo_uso": "Emiré guasu.", "exemplo_pt": "Fiança sagrada.", "transliteracao": "e-mi-RE", "classe_gramatical": "substantivo"}
        ],
        18: [
            {"palavra": "Ywy Marã'ey", "traducao": "A Terra Sem Males", "categoria": "mitologia", "rag_id": "6059a27432d6fb84ebb446d48015b8f0cb1ea1bc79c39c7b6e6cc6122613fdfa_chunk_5140", "exemplo_uso": "Ywy Marã'ey katy a-só.", "exemplo_pt": "Caminho rumo à terra imortal.", "transliteracao": "y-wy ma-ran-EY", "classe_gramatical": "proprio"},
            {"palavra": "Maíra", "traducao": "O grande ancestral civilizador", "categoria": "mitologia", "rag_id": "6059a27432d6fb84ebb446d48015b8f0cb1ea1bc79c39c7b6e6cc6122613fdfa_chunk_5145", "exemplo_uso": "Maíra abá mbo'e.", "exemplo_pt": "Maíra instruiu o povo.", "transliteracao": "ma-I-ra", "classe_gramatical": "proprio"}
        ],
        19: [
            {"palavra": "Cartas de 1645", "traducao": "Epístolas históricas em Tupi puro", "categoria": "historia", "rag_id": "b5e6721f1778931d12ca59f0e7e7c212cfc05d27c12f9eb7b73edf4ae45ba84d_chunk_210", "exemplo_uso": "Kuatiá Paraupaba.", "exemplo_pt": "A carta de Antônio Paraupaba.", "transliteracao": "car-tas de mil seis-cen-tos e qua-ren-ta e cin-co", "classe_gramatical": "proprio"},
            {"palavra": "Cabo Frio", "traducao": "Fortaleza Tupinambá contra os invasores", "categoria": "toponimia", "rag_id": "b5e6721f1778931d12ca59f0e7e7c212cfc05d27c12f9eb7b73edf4ae45ba84d_chunk_215", "exemplo_uso": "Cabo Frio taba.", "exemplo_pt": "A trincheira de Cabo Frio.", "transliteracao": "ca-bo FRI-o", "classe_gramatical": "proprio"}
        ],
        20: [
            {"palavra": "Pindorama", "traducao": "A terra soberana", "categoria": "toponimia", "rag_id": "6059a27432d6fb84ebb446d48015b8f0cb1ea1bc79c39c7b6e6cc6122613fdfa_chunk_4386", "exemplo_uso": "Pindorama yande retama.", "exemplo_pt": "Pindorama é nosso solo natal.", "transliteracao": "pin-do-RA-ma", "classe_gramatical": "proprio"},
            {"palavra": "Tupinambá Kuatiá", "traducao": "A escrita perene da nação Tupinambá", "categoria": "lingua", "rag_id": "b5e6721f1778931d12ca59f0e7e7c212cfc05d27c12f9eb7b73edf4ae45ba84d_chunk_220", "exemplo_uso": "Tupinambá kuatiá katu.", "exemplo_pt": "A honra do idioma registrado.", "transliteracao": "tu-pi-nam-BA kwa-ti-A", "classe_gramatical": "proprio"}
        ]
    }
}
