"""
TupiLingo — Banco de Dados Léxico e Morfológico Autenticado do RAG
Contém o mapeamento dos 20 capítulos para as 2 variantes canônicas:
  1. tupi_antigo (Quinhentista / Clássico - Eduardo Navarro USP)
  2. tupi_revitalizado (Método Moderno / Revitalização - Eduardo Navarro USP)

Todos os itens possuem proveniência rastreável a chunks do vector_store.db.
"""

from typing import Dict, Any, List

# Estrutura: LEXICON_BY_VARIANT_CHAPTER[variant][chapter_num] = list of items
LEXICON_BY_VARIANT_CHAPTER: Dict[str, Dict[int, List[Dict[str, Any]]]] = {
    "tupi_antigo": {
        "1": [
            {
                "palavra": "Aué",
                "traducao": "Olá / Salve",
                "variante": "tupi_antigo",
                "categoria": "saudacoes",
                "capitulo_introduzido": 1,
                "licao_introduzida": 1,
                "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_140",
                "exemplo_uso": "Aué, xe irũ!",
                "transliteracao": "a-u-É",
                "status": "completo"
            },
            {
                "palavra": "Ereîur pe?",
                "traducao": "Vieste?",
                "variante": "tupi_antigo",
                "categoria": "saudacoes",
                "capitulo_introduzido": 1,
                "licao_introduzida": 1,
                "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_140",
                "exemplo_uso": "Ereîur pe?, pa'i?",
                "transliteracao": "e-re-i-UR pe",
                "status": "completo"
            },
            {
                "palavra": "Pa'i",
                "traducao": "Senhor / Tratamento respeitoso",
                "variante": "tupi_antigo",
                "categoria": "saudacoes",
                "capitulo_introduzido": 1,
                "licao_introduzida": 1,
                "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_142",
                "exemplo_uso": "Pa'i katu.",
                "transliteracao": "pa-I",
                "status": "completo"
            },
            {
                "palavra": "Katu",
                "traducao": "Bom / Belo",
                "variante": "tupi_antigo",
                "categoria": "qualidade",
                "capitulo_introduzido": 1,
                "licao_introduzida": 2,
                "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_145",
                "exemplo_uso": "Abá katu.",
                "transliteracao": "ka-TU",
                "status": "completo"
            },
            {
                "palavra": "Îandé",
                "traducao": "Nós (inclusivo)",
                "variante": "tupi_antigo",
                "categoria": "gramatica",
                "capitulo_introduzido": 1,
                "licao_introduzida": 2,
                "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_150",
                "exemplo_uso": "Îandé abá.",
                "transliteracao": "yan-DE",
                "status": "completo"
            },
            {
                "palavra": "Xé",
                "traducao": "Eu / Meu",
                "variante": "tupi_antigo",
                "categoria": "gramatica",
                "capitulo_introduzido": 1,
                "licao_introduzida": 2,
                "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_150",
                "exemplo_uso": "Xé abá katu.",
                "transliteracao": "XE",
                "status": "completo"
            }
        ],
        "2": [
            {
                "palavra": "Oka",
                "traducao": "Casa / Habitação",
                "variante": "tupi_antigo",
                "categoria": "habitacao",
                "capitulo_introduzido": 2,
                "licao_introduzida": 1,
                "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_260",
                "exemplo_uso": "Oka katu.",
                "transliteracao": "O-ka",
                "status": "completo"
            },
            {
                "palavra": "Taba",
                "traducao": "Aldeia cercada",
                "variante": "tupi_antigo",
                "categoria": "comunidade",
                "capitulo_introduzido": 2,
                "licao_introduzida": 1,
                "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_260",
                "exemplo_uso": "Taba guasu.",
                "transliteracao": "TA-ba",
                "status": "completo"
            },
            {
                "palavra": "Abá",
                "traducao": "Homem / Pessoa humana",
                "variante": "tupi_antigo",
                "categoria": "pessoas",
                "capitulo_introduzido": 2,
                "licao_introduzida": 1,
                "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_262",
                "exemplo_uso": "Abá katu taba pupé.",
                "transliteracao": "a-BA",
                "status": "completo"
            },
            {
                "palavra": "Kunhã",
                "traducao": "Mulher",
                "variante": "tupi_antigo",
                "categoria": "pessoas",
                "capitulo_introduzido": 2,
                "licao_introduzida": 2,
                "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_262",
                "exemplo_uso": "Kunhã katu.",
                "transliteracao": "ku-NYA",
                "status": "completo"
            },
            {
                "palavra": "Tuba",
                "traducao": "Pai",
                "variante": "tupi_antigo",
                "categoria": "parentesco",
                "capitulo_introduzido": 2,
                "licao_introduzida": 2,
                "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_262",
                "exemplo_uso": "Xé ruba katu.",
                "transliteracao": "TU-ba",
                "status": "completo"
            },
            {
                "palavra": "Sy",
                "traducao": "Mãe",
                "variante": "tupi_antigo",
                "categoria": "parentesco",
                "capitulo_introduzido": 2,
                "licao_introduzida": 2,
                "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_263",
                "exemplo_uso": "Xé sy oka pupé.",
                "transliteracao": "SY",
                "status": "completo"
            },
            {
                "palavra": "Inĩ",
                "traducao": "Rede de dormir",
                "variante": "tupi_antigo",
                "categoria": "utensilios",
                "capitulo_introduzido": 2,
                "licao_introduzida": 2,
                "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_265",
                "exemplo_uso": "Inĩ katu.",
                "transliteracao": "i-NIN",
                "status": "completo"
            }
        ],
        "3": [
            {
                "palavra": "Îagûara",
                "traducao": "Onça / Fera feroz",
                "variante": "tupi_antigo",
                "categoria": "fauna",
                "capitulo_introduzido": 3,
                "licao_introduzida": 1,
                "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_310",
                "exemplo_uso": "Îagûara ka'a pupé.",
                "transliteracao": "ya-gwa-RA",
                "status": "completo"
            },
            {
                "palavra": "Tatu",
                "traducao": "Tatu",
                "variante": "tupi_antigo",
                "categoria": "fauna",
                "capitulo_introduzido": 3,
                "licao_introduzida": 1,
                "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_310",
                "exemplo_uso": "Tatu yby pupé.",
                "transliteracao": "ta-TU",
                "status": "completo"
            },
            {
                "palavra": "Kapi'ybara",
                "traducao": "Capivara",
                "variante": "tupi_antigo",
                "categoria": "fauna",
                "capitulo_introduzido": 3,
                "licao_introduzida": 2,
                "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_312",
                "exemplo_uso": "Kapi'ybara 'y rembé.",
                "transliteracao": "ka-pi-y-ba-RA",
                "status": "completo"
            },
            {
                "palavra": "So'ó",
                "traducao": "Carne / Caça comestível",
                "variante": "tupi_antigo",
                "categoria": "fauna",
                "capitulo_introduzido": 3,
                "licao_introduzida": 2,
                "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_314",
                "exemplo_uso": "So'ó katu.",
                "transliteracao": "so-O",
                "status": "completo"
            }
        ],
        "4": [
            {
                "palavra": "'Y",
                "traducao": "Água / Rio",
                "variante": "tupi_antigo",
                "categoria": "natureza",
                "capitulo_introduzido": 4,
                "licao_introduzida": 1,
                "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_198",
                "exemplo_uso": "'Y katu.",
                "transliteracao": "Y",
                "status": "completo"
            },
            {
                "palavra": "Paraná",
                "traducao": "Mar / Grande caudal",
                "variante": "tupi_antigo",
                "categoria": "natureza",
                "capitulo_introduzido": 4,
                "licao_introduzida": 1,
                "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_198",
                "exemplo_uso": "Paraná guasu.",
                "transliteracao": "pa-ra-NA",
                "status": "completo"
            },
            {
                "palavra": "Pira",
                "traducao": "Peixe",
                "variante": "tupi_antigo",
                "categoria": "fauna",
                "capitulo_introduzido": 4,
                "licao_introduzida": 2,
                "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_200",
                "exemplo_uso": "Pira 'y pupé.",
                "transliteracao": "pi-RA",
                "status": "completo"
            },
            {
                "palavra": "Ygata",
                "traducao": "Canoa de guerra",
                "variante": "tupi_antigo",
                "categoria": "transporte",
                "capitulo_introduzido": 4,
                "licao_introduzida": 2,
                "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_202",
                "exemplo_uso": "Ygata paraná pupé.",
                "transliteracao": "y-ga-TA",
                "status": "completo"
            }
        ],
        "5": [
            {
                "palavra": "Mani'oka",
                "traducao": "Mandioca",
                "variante": "tupi_antigo",
                "categoria": "flora",
                "capitulo_introduzido": 5,
                "licao_introduzida": 1,
                "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_412",
                "exemplo_uso": "Mani'oka katu.",
                "transliteracao": "ma-ni-O-ka",
                "status": "completo"
            },
            {
                "palavra": "Tembi'u",
                "traducao": "Comida / O que se come",
                "variante": "tupi_antigo",
                "categoria": "alimentos",
                "capitulo_introduzido": 5,
                "licao_introduzida": 1,
                "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_412",
                "exemplo_uso": "Tembi'u katu.",
                "transliteracao": "mby-A",
                "status": "completo"
            },
            {
                "palavra": "Kãuĩ",
                "traducao": "Cauim fermentado",
                "variante": "tupi_antigo",
                "categoria": "alimentos",
                "capitulo_introduzido": 5,
                "licao_introduzida": 2,
                "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_414",
                "exemplo_uso": "Kãuĩ taba pupé.",
                "transliteracao": "ka-u-IN",
                "status": "completo"
            },
            {
                "palavra": "Abati",
                "traducao": "Milho",
                "variante": "tupi_antigo",
                "categoria": "flora",
                "capitulo_introduzido": 5,
                "licao_introduzida": 2,
                "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_415",
                "exemplo_uso": "Abati taba pupé.",
                "transliteracao": "a-ba-TI",
                "status": "completo"
            }
        ],
        "6": [
            {
                "palavra": "Kûarasy",
                "traducao": "Sol",
                "variante": "tupi_antigo",
                "categoria": "cosmologia",
                "capitulo_introduzido": 6,
                "licao_introduzida": 1,
                "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_205",
                "exemplo_uso": "Kûarasy ybak pupé.",
                "transliteracao": "kwa-ra-SY",
                "status": "completo"
            },
            {
                "palavra": "Îasy",
                "traducao": "Lua",
                "variante": "tupi_antigo",
                "categoria": "cosmologia",
                "capitulo_introduzido": 6,
                "licao_introduzida": 2,
                "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_205",
                "exemplo_uso": "Îasy pykói.",
                "transliteracao": "ya-SY",
                "status": "completo"
            },
            {
                "palavra": "Îasytatá",
                "traducao": "Estrela",
                "variante": "tupi_antigo",
                "categoria": "cosmologia",
                "capitulo_introduzido": 6,
                "licao_introduzida": 2,
                "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_206",
                "exemplo_uso": "Îasytatá retá.",
                "transliteracao": "ya-sy-ta-TA",
                "status": "completo"
            }
        ],
        "7": [
            {
                "palavra": "Tata",
                "traducao": "Fogo",
                "variante": "tupi_antigo",
                "categoria": "natureza",
                "capitulo_introduzido": 7,
                "licao_introduzida": 1,
                "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_215",
                "exemplo_uso": "Tata oka pupé.",
                "transliteracao": "ta-TA",
                "status": "completo"
            },
            {
                "palavra": "Tatagûasu",
                "traducao": "Grande fogueira",
                "variante": "tupi_antigo",
                "categoria": "natureza",
                "capitulo_introduzido": 7,
                "licao_introduzida": 2,
                "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_216",
                "exemplo_uso": "Tatagûasu okar pupé.",
                "transliteracao": "ta-ta-gwa-SU",
                "status": "completo"
            },
            {
                "palavra": "Itá",
                "traducao": "Pedra / Machado de pedra",
                "variante": "tupi_antigo",
                "categoria": "natureza",
                "capitulo_introduzido": 7,
                "licao_introduzida": 2,
                "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_218",
                "exemplo_uso": "Itá katu.",
                "transliteracao": "i-TA",
                "status": "completo"
            }
        ],
        "8": [
            {
                "palavra": "Gûyrá",
                "traducao": "Pássaro / Ave",
                "variante": "tupi_antigo",
                "categoria": "avifauna",
                "capitulo_introduzido": 8,
                "licao_introduzida": 1,
                "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_320",
                "exemplo_uso": "Gûyrá o-gûebé.",
                "transliteracao": "gwy-RA",
                "status": "completo"
            },
            {
                "palavra": "Tukan",
                "traducao": "Tucano",
                "variante": "tupi_antigo",
                "categoria": "avifauna",
                "capitulo_introduzido": 8,
                "licao_introduzida": 2,
                "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_321",
                "exemplo_uso": "Tukan ybyrá ári.",
                "transliteracao": "tu-KAN",
                "status": "completo"
            },
            {
                "palavra": "Arara",
                "traducao": "Arara",
                "variante": "tupi_antigo",
                "categoria": "avifauna",
                "capitulo_introduzido": 8,
                "licao_introduzida": 2,
                "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_322",
                "exemplo_uso": "Arara ka'a pupé.",
                "transliteracao": "a-RA-ra",
                "status": "completo"
            }
        ],
        "9": [
            {
                "palavra": "Akanga",
                "traducao": "Cabeça",
                "variante": "tupi_antigo",
                "categoria": "corpo",
                "capitulo_introduzido": 9,
                "licao_introduzida": 1,
                "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_330",
                "exemplo_uso": "Akanga katu.",
                "transliteracao": "a-KAN-ga",
                "status": "completo"
            },
            {
                "palavra": "Esá",
                "traducao": "Olhos",
                "variante": "tupi_antigo",
                "categoria": "corpo",
                "capitulo_introduzido": 9,
                "licao_introduzida": 1,
                "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_330",
                "exemplo_uso": "Xe resá o-epîák.",
                "transliteracao": "e-SA",
                "status": "completo"
            },
            {
                "palavra": "Pó",
                "traducao": "Mão",
                "variante": "tupi_antigo",
                "categoria": "corpo",
                "capitulo_introduzido": 9,
                "licao_introduzida": 2,
                "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_331",
                "exemplo_uso": "Xe pó katu.",
                "transliteracao": "PO",
                "status": "completo"
            },
            {
                "palavra": "Py",
                "traducao": "Pé",
                "variante": "tupi_antigo",
                "categoria": "corpo",
                "capitulo_introduzido": 9,
                "licao_introduzida": 2,
                "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_332",
                "exemplo_uso": "Py yby ári.",
                "transliteracao": "PY",
                "status": "completo"
            }
        ],
        "10": [
            {
                "palavra": "Morubixaba",
                "traducao": "Chefe político e militar",
                "variante": "tupi_antigo",
                "categoria": "comunidade",
                "capitulo_introduzido": 10,
                "licao_introduzida": 1,
                "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_350",
                "exemplo_uso": "Morubixaba taba pupé.",
                "transliteracao": "mo-ru-bi-XA-ba",
                "status": "completo"
            },
            {
                "palavra": "Tamuya",
                "traducao": "Ancião / Avô venerado",
                "variante": "tupi_antigo",
                "categoria": "comunidade",
                "capitulo_introduzido": 10,
                "licao_introduzida": 2,
                "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_352",
                "exemplo_uso": "Tamuya o-nhe'eng.",
                "transliteracao": "ta-MOI-o",
                "status": "completo"
            },
            {
                "palavra": "Okar",
                "traducao": "Praça da aldeia",
                "variante": "tupi_antigo",
                "categoria": "habitacao",
                "capitulo_introduzido": 10,
                "licao_introduzida": 2,
                "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_355",
                "exemplo_uso": "Abá okar pupé.",
                "transliteracao": "o-KAR",
                "status": "completo"
            }
        ],
        "11": [
            {
                "palavra": "Ka'a",
                "traducao": "Mata atlântica virgem",
                "variante": "tupi_antigo",
                "categoria": "flora",
                "capitulo_introduzido": 11,
                "licao_introduzida": 1,
                "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_360",
                "exemplo_uso": "Ka'a guasu.",
                "transliteracao": "ka-A",
                "status": "completo"
            },
            {
                "palavra": "Ybyrá",
                "traducao": "Tronco / Árvore",
                "variante": "tupi_antigo",
                "categoria": "flora",
                "capitulo_introduzido": 11,
                "licao_introduzida": 2,
                "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_361",
                "exemplo_uso": "Ybyrá ka'a pupé.",
                "transliteracao": "y-by-RA",
                "status": "completo"
            },
            {
                "palavra": "Ybyrapytanga",
                "traducao": "Pau-brasil (madeira vermelha)",
                "variante": "tupi_antigo",
                "categoria": "flora",
                "capitulo_introduzido": 11,
                "licao_introduzida": 2,
                "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_365",
                "exemplo_uso": "Ybyrapytanga retama.",
                "transliteracao": "y-by-ra-py-TAN-ga",
                "status": "completo"
            }
        ],
        "12": [
            {
                "palavra": "'U",
                "traducao": "Comer",
                "variante": "tupi_antigo",
                "categoria": "verbos",
                "capitulo_introduzido": 12,
                "licao_introduzida": 1,
                "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_540",
                "exemplo_uso": "A-'u mani'oka.",
                "transliteracao": "U",
                "status": "completo"
            },
            {
                "palavra": "'Y",
                "traducao": "Beber",
                "variante": "tupi_antigo",
                "categoria": "verbos",
                "capitulo_introduzido": 12,
                "licao_introduzida": 1,
                "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_540",
                "exemplo_uso": "A-'y 'y katu.",
                "transliteracao": "Y",
                "status": "completo"
            },
            {
                "palavra": "Só",
                "traducao": "Ir",
                "variante": "tupi_antigo",
                "categoria": "verbos",
                "capitulo_introduzido": 12,
                "licao_introduzida": 2,
                "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_542",
                "exemplo_uso": "A-só ka'a pupé.",
                "transliteracao": "SO",
                "status": "completo"
            },
            {
                "palavra": "Ker",
                "traducao": "Repousar / Dormir",
                "variante": "tupi_antigo",
                "categoria": "verbos",
                "capitulo_introduzido": 12,
                "licao_introduzida": 2,
                "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_544",
                "exemplo_uso": "A-ker inĩ pupé.",
                "transliteracao": "KER",
                "status": "completo"
            }
        ],
        "13": [
            {
                "palavra": "Maraká",
                "traducao": "Chocalho cerimonial sagrado",
                "variante": "tupi_antigo",
                "categoria": "musica",
                "capitulo_introduzido": 13,
                "licao_introduzida": 1,
                "rag_id": "6059a27432d6fb84ebb446d48015b8f0cb1ea1bc79c39c7b6e6cc6122613fdfa_chunk_1402",
                "exemplo_uso": "Maraká o-nhe'eng.",
                "transliteracao": "ma-ra-KA",
                "status": "completo"
            },
            {
                "palavra": "Toré",
                "traducao": "Dança e cântico ritual",
                "variante": "tupi_antigo",
                "categoria": "musica",
                "capitulo_introduzido": 13,
                "licao_introduzida": 2,
                "rag_id": "6059a27432d6fb84ebb446d48015b8f0cb1ea1bc79c39c7b6e6cc6122613fdfa_chunk_1405",
                "exemplo_uso": "Toré okar pupé.",
                "transliteracao": "to-RE",
                "status": "completo"
            }
        ],
        "14": [
            {
                "palavra": "Tupã",
                "traducao": "O Trovão Cósmico",
                "variante": "tupi_antigo",
                "categoria": "espiritualidade",
                "capitulo_introduzido": 14,
                "licao_introduzida": 1,
                "rag_id": "6059a27432d6fb84ebb446d48015b8f0cb1ea1bc79c39c7b6e6cc6122613fdfa_chunk_5120",
                "exemplo_uso": "Tupã ybak pupé.",
                "transliteracao": "tu-PAN",
                "status": "completo"
            },
            {
                "palavra": "Kurupira",
                "traducao": "Guardião com pés para trás",
                "variante": "tupi_antigo",
                "categoria": "espiritualidade",
                "capitulo_introduzido": 14,
                "licao_introduzida": 2,
                "rag_id": "6059a27432d6fb84ebb446d48015b8f0cb1ea1bc79c39c7b6e6cc6122613fdfa_chunk_2840",
                "exemplo_uso": "Kurupira ka'a guardião.",
                "transliteracao": "ku-ru-PI-ra",
                "status": "completo"
            },
            {
                "palavra": "Anhangá",
                "traducao": "Espírito da selva",
                "variante": "tupi_antigo",
                "categoria": "espiritualidade",
                "capitulo_introduzido": 14,
                "licao_introduzida": 2,
                "rag_id": "6059a27432d6fb84ebb446d48015b8f0cb1ea1bc79c39c7b6e6cc6122613fdfa_chunk_2848",
                "exemplo_uso": "Anhangá ka'a pupé.",
                "transliteracao": "an-han-GA",
                "status": "completo"
            }
        ],
        "15": [
            {
                "palavra": "Pajé",
                "traducao": "Guia espiritual e médico",
                "variante": "tupi_antigo",
                "categoria": "espiritualidade",
                "capitulo_introduzido": 15,
                "licao_introduzida": 1,
                "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_560",
                "exemplo_uso": "Pajé o-pohano abá.",
                "transliteracao": "pa-JE",
                "status": "completo"
            },
            {
                "palavra": "Pohã",
                "traducao": "Planta medicinal / Cura",
                "variante": "tupi_antigo",
                "categoria": "cura",
                "capitulo_introduzido": 15,
                "licao_introduzida": 2,
                "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_562",
                "exemplo_uso": "Pohã katu.",
                "transliteracao": "po-HAN",
                "status": "completo"
            }
        ],
        "16": [
            {
                "palavra": "Peabiru",
                "traducao": "Trilha sagrada transcontinental",
                "variante": "tupi_antigo",
                "categoria": "historia",
                "capitulo_introduzido": 16,
                "licao_introduzida": 1,
                "rag_id": "6059a27432d6fb84ebb446d48015b8f0cb1ea1bc79c39c7b6e6cc6122613fdfa_chunk_4386",
                "exemplo_uso": "Peabiru yby rupi.",
                "transliteracao": "pe-a-bi-RU",
                "status": "completo"
            },
            {
                "palavra": "Pé",
                "traducao": "Caminho / Vereda",
                "variante": "tupi_antigo",
                "categoria": "geografia",
                "capitulo_introduzido": 16,
                "licao_introduzida": 2,
                "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_570",
                "exemplo_uso": "Pé katu.",
                "transliteracao": "PE",
                "status": "completo"
            },
            {
                "palavra": "Gûatá",
                "traducao": "Viajar a pé",
                "variante": "tupi_antigo",
                "categoria": "verbos",
                "capitulo_introduzido": 16,
                "licao_introduzida": 2,
                "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_572",
                "exemplo_uso": "A-gûatá pé rupi.",
                "transliteracao": "gwa-TA",
                "status": "completo"
            }
        ],
        "17": [
            {
                "palavra": "Emiré",
                "traducao": "Presente cerimonial de aliança",
                "variante": "tupi_antigo",
                "categoria": "comunidade",
                "capitulo_introduzido": 17,
                "licao_introduzida": 1,
                "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_580",
                "exemplo_uso": "Emiré katu.",
                "transliteracao": "e-mi-RE",
                "status": "completo"
            },
            {
                "palavra": "Moatyrã",
                "traducao": "Escambo amigável",
                "variante": "tupi_antigo",
                "categoria": "comunidade",
                "capitulo_introduzido": 17,
                "licao_introduzida": 2,
                "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_582",
                "exemplo_uso": "Moatyrã taba pupé.",
                "transliteracao": "mo-a-ty-RAN",
                "status": "completo"
            }
        ],
        "18": [
            {
                "palavra": "Ywy Marã'ey",
                "traducao": "A Terra Sem Males",
                "variante": "tupi_antigo",
                "categoria": "mitologia",
                "capitulo_introduzido": 18,
                "licao_introduzida": 1,
                "rag_id": "6059a27432d6fb84ebb446d48015b8f0cb1ea1bc79c39c7b6e6cc6122613fdfa_chunk_5140",
                "exemplo_uso": "Ywy Marã'ey katu.",
                "transliteracao": "y-wy ma-ran-EY",
                "status": "completo"
            },
            {
                "palavra": "Maíra",
                "traducao": "Herói civilizador",
                "variante": "tupi_antigo",
                "categoria": "mitologia",
                "capitulo_introduzido": 18,
                "licao_introduzida": 2,
                "rag_id": "6059a27432d6fb84ebb446d48015b8f0cb1ea1bc79c39c7b6e6cc6122613fdfa_chunk_5145",
                "exemplo_uso": "Maíra abá monhang.",
                "transliteracao": "ma-I-ra",
                "status": "completo"
            }
        ],
        "19": [
            {
                "palavra": "Iperoig",
                "traducao": "Ubatuba colonial / Sede dos Tamuyas",
                "variante": "tupi_antigo",
                "categoria": "historia",
                "capitulo_introduzido": 19,
                "licao_introduzida": 1,
                "rag_id": "6059a27432d6fb84ebb446d48015b8f0cb1ea1bc79c39c7b6e6cc6122613fdfa_chunk_4386",
                "exemplo_uso": "Iperoig taba.",
                "transliteracao": "i-pe-ro-IG",
                "status": "completo"
            },
            {
                "palavra": "Cunhambebe",
                "traducao": "Grande líder guerreiro dos Tamuyas",
                "variante": "tupi_antigo",
                "categoria": "historia",
                "capitulo_introduzido": 19,
                "licao_introduzida": 2,
                "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_110",
                "exemplo_uso": "Cunhambebe morubixaba.",
                "transliteracao": "ku-nham-BE-be",
                "status": "completo"
            }
        ],
        "20": [
            {
                "palavra": "Pindorama",
                "traducao": "Terra das Palmeiras",
                "variante": "tupi_antigo",
                "categoria": "toponimia",
                "capitulo_introduzido": 20,
                "licao_introduzida": 1,
                "rag_id": "6059a27432d6fb84ebb446d48015b8f0cb1ea1bc79c39c7b6e6cc6122613fdfa_chunk_4386",
                "exemplo_uso": "Pindorama yande retama.",
                "transliteracao": "pin-do-RA-ma",
                "status": "completo"
            },
            {
                "palavra": "Nhe'engatu",
                "traducao": "A língua clássica pura",
                "variante": "tupi_antigo",
                "categoria": "lingua",
                "capitulo_introduzido": 20,
                "licao_introduzida": 2,
                "rag_id": "6d76a303c0b35f73a2ddcadb8b991ce238ae37340cc06afe9e01279806f6860f_chunk_600",
                "exemplo_uso": "Nhe'engatu katu.",
                "transliteracao": "nhe-en-ga-TU",
                "status": "completo"
            }
        ]
    },
    "tupi_revitalizado": {
        "1": [
            {
                "palavra": "Puranga",
                "traducao": "Bom / Belo",
                "variante": "tupi_revitalizado",
                "categoria": "saudacoes",
                "capitulo_introduzido": 1,
                "licao_introduzida": 1,
                "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_42",
                "exemplo_uso": "Katu koema!",
                "transliteracao": "pu-RAN-ga",
                "status": "completo"
            },
            {
                "palavra": "Katu koema",
                "traducao": "Bom dia",
                "variante": "tupi_revitalizado",
                "categoria": "saudacoes",
                "capitulo_introduzido": 1,
                "licao_introduzida": 1,
                "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_42",
                "exemplo_uso": "Katu koema, xe irũ!",
                "transliteracao": "pu-RAN-ga ko-E-ma",
                "status": "completo"
            },
            {
                "palavra": "Katu pykói",
                "traducao": "Boa noite",
                "variante": "tupi_revitalizado",
                "categoria": "saudacoes",
                "capitulo_introduzido": 1,
                "licao_introduzida": 1,
                "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_43",
                "exemplo_uso": "Katu pykói panhe!",
                "transliteracao": "pu-RAN-ga pi-TU-na",
                "status": "completo"
            },
            {
                "palavra": "Aweté",
                "traducao": "Obrigado / Valeu",
                "variante": "tupi_revitalizado",
                "categoria": "saudacoes",
                "capitulo_introduzido": 1,
                "licao_introduzida": 2,
                "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_50",
                "exemplo_uso": "Aweté puranga!",
                "transliteracao": "a-we-TE",
                "status": "completo"
            },
            {
                "palavra": "Kunumĩ",
                "traducao": "Menino / Garoto",
                "variante": "tupi_revitalizado",
                "categoria": "pessoas",
                "capitulo_introduzido": 1,
                "licao_introduzida": 2,
                "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_55",
                "exemplo_uso": "Kunumĩ puranga.",
                "transliteracao": "ku-nu-MI",
                "status": "completo"
            },
            {
                "palavra": "Kuñataĩ",
                "traducao": "Menina / Jovem",
                "variante": "tupi_revitalizado",
                "categoria": "pessoas",
                "capitulo_introduzido": 1,
                "licao_introduzida": 2,
                "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_55",
                "exemplo_uso": "Kuñataĩ puranga.",
                "transliteracao": "ku-nya-ta-I",
                "status": "completo"
            }
        ],
        "2": [
            {
                "palavra": "Oka",
                "traducao": "Casa / Habitação",
                "variante": "tupi_revitalizado",
                "categoria": "habitacao",
                "capitulo_introduzido": 2,
                "licao_introduzida": 1,
                "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_88",
                "exemplo_uso": "Oka puranga.",
                "transliteracao": "O-ka",
                "status": "completo"
            },
            {
                "palavra": "Taba",
                "traducao": "Aldeia / Povoado",
                "variante": "tupi_revitalizado",
                "categoria": "comunidade",
                "capitulo_introduzido": 2,
                "licao_introduzida": 1,
                "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_88",
                "exemplo_uso": "Yande taba.",
                "transliteracao": "TA-ba",
                "status": "completo"
            },
            {
                "palavra": "Abá",
                "traducao": "Homem / Varão",
                "variante": "tupi_revitalizado",
                "categoria": "pessoas",
                "capitulo_introduzido": 2,
                "licao_introduzida": 1,
                "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_90",
                "exemplo_uso": "Abá puranga.",
                "transliteracao": "a-pi-GA-wa",
                "status": "completo"
            },
            {
                "palavra": "Kunhã",
                "traducao": "Mulher",
                "variante": "tupi_revitalizado",
                "categoria": "pessoas",
                "capitulo_introduzido": 2,
                "licao_introduzida": 2,
                "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_90",
                "exemplo_uso": "Kunhã puranga.",
                "transliteracao": "ku-NYA",
                "status": "completo"
            },
            {
                "palavra": "Pai",
                "traducao": "Pai",
                "variante": "tupi_revitalizado",
                "categoria": "parentesco",
                "capitulo_introduzido": 2,
                "licao_introduzida": 2,
                "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_92",
                "exemplo_uso": "Se pai puranga.",
                "transliteracao": "PAI",
                "status": "completo"
            },
            {
                "palavra": "Inĩ",
                "traducao": "Rede de dormir",
                "variante": "tupi_revitalizado",
                "categoria": "utensilios",
                "capitulo_introduzido": 2,
                "licao_introduzida": 2,
                "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_95",
                "exemplo_uso": "Inĩ oka rupi.",
                "transliteracao": "i-NI",
                "status": "completo"
            }
        ],
        "3": [
            {
                "palavra": "Yawaraté",
                "traducao": "Onça pintada",
                "variante": "tupi_revitalizado",
                "categoria": "fauna",
                "capitulo_introduzido": 3,
                "licao_introduzida": 1,
                "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_115",
                "exemplo_uso": "Yawaraté ka'a pupé.",
                "transliteracao": "ya-wa-ra-TE",
                "status": "completo"
            },
            {
                "palavra": "Tatu",
                "traducao": "Tatu",
                "variante": "tupi_revitalizado",
                "categoria": "fauna",
                "capitulo_introduzido": 3,
                "licao_introduzida": 1,
                "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_115",
                "exemplo_uso": "Tatu yby rupi.",
                "transliteracao": "ta-TU",
                "status": "completo"
            },
            {
                "palavra": "Akuti",
                "traducao": "Cutia",
                "variante": "tupi_revitalizado",
                "categoria": "fauna",
                "capitulo_introduzido": 3,
                "licao_introduzida": 2,
                "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_116",
                "exemplo_uso": "Akuti ka'a.",
                "transliteracao": "a-ku-TI",
                "status": "completo"
            },
            {
                "palavra": "So'o",
                "traducao": "Animal de caça",
                "variante": "tupi_revitalizado",
                "categoria": "fauna",
                "capitulo_introduzido": 3,
                "licao_introduzida": 2,
                "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_118",
                "exemplo_uso": "So'o puranga.",
                "transliteracao": "so-O",
                "status": "completo"
            }
        ],
        "4": [
            {
                "palavra": "'Y",
                "traducao": "Água / Rio",
                "variante": "tupi_revitalizado",
                "categoria": "natureza",
                "capitulo_introduzido": 4,
                "licao_introduzida": 1,
                "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_77",
                "exemplo_uso": "'Y puranga.",
                "transliteracao": "Y",
                "status": "completo"
            },
            {
                "palavra": "Paraná",
                "traducao": "Rio grande / Mar",
                "variante": "tupi_revitalizado",
                "categoria": "natureza",
                "capitulo_introduzido": 4,
                "licao_introduzida": 1,
                "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_77",
                "exemplo_uso": "Paraná guasu.",
                "transliteracao": "pa-ra-NA",
                "status": "completo"
            },
            {
                "palavra": "Pira",
                "traducao": "Peixe",
                "variante": "tupi_revitalizado",
                "categoria": "fauna",
                "capitulo_introduzido": 4,
                "licao_introduzida": 2,
                "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_78",
                "exemplo_uso": "Pira 'y pupé.",
                "transliteracao": "pi-RA",
                "status": "completo"
            },
            {
                "palavra": "Igarapé",
                "traducao": "Canal de canoa",
                "variante": "tupi_revitalizado",
                "categoria": "natureza",
                "capitulo_introduzido": 4,
                "licao_introduzida": 2,
                "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_80",
                "exemplo_uso": "Igarapé puranga.",
                "transliteracao": "i-ga-ra-PE",
                "status": "completo"
            }
        ],
        "5": [
            {
                "palavra": "Manioka",
                "traducao": "Mandioca",
                "variante": "tupi_revitalizado",
                "categoria": "flora",
                "capitulo_introduzido": 5,
                "licao_introduzida": 1,
                "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_60",
                "exemplo_uso": "Mani'oka koo pupé.",
                "transliteracao": "ma-ni-O-ka",
                "status": "completo"
            },
            {
                "palavra": "Uí",
                "traducao": "Farinha",
                "variante": "tupi_revitalizado",
                "categoria": "alimentos",
                "capitulo_introduzido": 5,
                "licao_introduzida": 1,
                "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_60",
                "exemplo_uso": "Uí puranga.",
                "transliteracao": "u-I",
                "status": "completo"
            },
            {
                "palavra": "Abati",
                "traducao": "Milho",
                "variante": "tupi_revitalizado",
                "categoria": "flora",
                "capitulo_introduzido": 5,
                "licao_introduzida": 2,
                "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_62",
                "exemplo_uso": "Abati puranga.",
                "transliteracao": "a-ba-TI",
                "status": "completo"
            },
            {
                "palavra": "Koo",
                "traducao": "Roça comunitária",
                "variante": "tupi_revitalizado",
                "categoria": "comunidade",
                "capitulo_introduzido": 5,
                "licao_introduzida": 2,
                "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_65",
                "exemplo_uso": "Koo taba pupé.",
                "transliteracao": "ku-pi-XA-wa",
                "status": "completo"
            }
        ],
        "6": [
            {
                "palavra": "Kuarasy",
                "traducao": "Sol",
                "variante": "tupi_revitalizado",
                "categoria": "cosmologia",
                "capitulo_introduzido": 6,
                "licao_introduzida": 1,
                "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_77",
                "exemplo_uso": "Kuarasy koema pupé.",
                "transliteracao": "kwa-ra-SY",
                "status": "completo"
            },
            {
                "palavra": "Yasy",
                "traducao": "Lua",
                "variante": "tupi_revitalizado",
                "categoria": "cosmologia",
                "capitulo_introduzido": 6,
                "licao_introduzida": 2,
                "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_77",
                "exemplo_uso": "Yasy pituna pupé.",
                "transliteracao": "ya-SY",
                "status": "completo"
            },
            {
                "palavra": "Yasy-tata",
                "traducao": "Estrela",
                "variante": "tupi_revitalizado",
                "categoria": "cosmologia",
                "capitulo_introduzido": 6,
                "licao_introduzida": 2,
                "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_78",
                "exemplo_uso": "Îasytatá ybak pupé.",
                "transliteracao": "ya-sy-ta-TA",
                "status": "completo"
            }
        ],
        "7": [
            {
                "palavra": "Tata",
                "traducao": "Fogo",
                "variante": "tupi_revitalizado",
                "categoria": "natureza",
                "capitulo_introduzido": 7,
                "licao_introduzida": 1,
                "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_82",
                "exemplo_uso": "Tata oka pupé.",
                "transliteracao": "ta-TA",
                "status": "completo"
            },
            {
                "palavra": "Itá",
                "traducao": "Pedra / Ferramenta",
                "variante": "tupi_revitalizado",
                "categoria": "natureza",
                "capitulo_introduzido": 7,
                "licao_introduzida": 2,
                "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_84",
                "exemplo_uso": "Itá katu.",
                "transliteracao": "i-TA",
                "status": "completo"
            },
            {
                "palavra": "Iapé",
                "traducao": "Pote de cerâmica",
                "variante": "tupi_revitalizado",
                "categoria": "utensilios",
                "capitulo_introduzido": 7,
                "licao_introduzida": 2,
                "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_85",
                "exemplo_uso": "'Y kamuti pupé.",
                "transliteracao": "ka-mu-TI",
                "status": "completo"
            }
        ],
        "8": [
            {
                "palavra": "Guyra",
                "traducao": "Pássaro / Ave",
                "variante": "tupi_revitalizado",
                "categoria": "avifauna",
                "capitulo_introduzido": 8,
                "licao_introduzida": 1,
                "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_120",
                "exemplo_uso": "Guyra o-wewé.",
                "transliteracao": "guy-RA",
                "status": "completo"
            },
            {
                "palavra": "Tukan",
                "traducao": "Tucano",
                "variante": "tupi_revitalizado",
                "categoria": "avifauna",
                "capitulo_introduzido": 8,
                "licao_introduzida": 2,
                "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_121",
                "exemplo_uso": "Tukan ka'a pupé.",
                "transliteracao": "tu-KAN",
                "status": "completo"
            },
            {
                "palavra": "Arara",
                "traducao": "Arara",
                "variante": "tupi_revitalizado",
                "categoria": "avifauna",
                "capitulo_introduzido": 8,
                "licao_introduzida": 2,
                "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_122",
                "exemplo_uso": "Arara puranga.",
                "transliteracao": "a-RA-ra",
                "status": "completo"
            }
        ],
        "9": [
            {
                "palavra": "Akanga",
                "traducao": "Cabeça",
                "variante": "tupi_revitalizado",
                "categoria": "corpo",
                "capitulo_introduzido": 9,
                "licao_introduzida": 1,
                "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_140",
                "exemplo_uso": "Akanga puranga.",
                "transliteracao": "a-KAN-ga",
                "status": "completo"
            },
            {
                "palavra": "Tesa",
                "traducao": "Olhos",
                "variante": "tupi_revitalizado",
                "categoria": "corpo",
                "capitulo_introduzido": 9,
                "licao_introduzida": 1,
                "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_140",
                "exemplo_uso": "Tesa o-ma'e.",
                "transliteracao": "te-SA",
                "status": "completo"
            },
            {
                "palavra": "Pó",
                "traducao": "Mão",
                "variante": "tupi_revitalizado",
                "categoria": "corpo",
                "capitulo_introduzido": 9,
                "licao_introduzida": 2,
                "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_141",
                "exemplo_uso": "Pó puranga.",
                "transliteracao": "PO",
                "status": "completo"
            },
            {
                "palavra": "Py",
                "traducao": "Pé",
                "variante": "tupi_revitalizado",
                "categoria": "corpo",
                "capitulo_introduzido": 9,
                "licao_introduzida": 2,
                "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_142",
                "exemplo_uso": "Py yby rupi.",
                "transliteracao": "PY",
                "status": "completo"
            }
        ],
        "10": [
            {
                "palavra": "Morubixaba",
                "traducao": "Líder / Cacique",
                "variante": "tupi_revitalizado",
                "categoria": "comunidade",
                "capitulo_introduzido": 10,
                "licao_introduzida": 1,
                "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_150",
                "exemplo_uso": "Morubixaba taba pupé.",
                "transliteracao": "tu-XA-wa",
                "status": "completo"
            },
            {
                "palavra": "Yande",
                "traducao": "Nós (inclusivo)",
                "variante": "tupi_revitalizado",
                "categoria": "gramatica",
                "capitulo_introduzido": 10,
                "licao_introduzida": 2,
                "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_152",
                "exemplo_uso": "Yande taba-pora.",
                "transliteracao": "yan-DE",
                "status": "completo"
            },
            {
                "palavra": "Taba-eté",
                "traducao": "Aldeia verdadeira / Principal",
                "variante": "tupi_revitalizado",
                "categoria": "comunidade",
                "capitulo_introduzido": 10,
                "licao_introduzida": 2,
                "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_155",
                "exemplo_uso": "Taba-eté guasu.",
                "transliteracao": "ta-ba-e-TE",
                "status": "completo"
            }
        ],
        "11": [
            {
                "palavra": "Ka'a",
                "traducao": "Mata / Floresta",
                "variante": "tupi_revitalizado",
                "categoria": "flora",
                "capitulo_introduzido": 11,
                "licao_introduzida": 1,
                "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_160",
                "exemplo_uso": "Ka'a puranga.",
                "transliteracao": "ka-A",
                "status": "completo"
            },
            {
                "palavra": "Ybyrá",
                "traducao": "Árvore / Madeira",
                "variante": "tupi_revitalizado",
                "categoria": "flora",
                "capitulo_introduzido": 11,
                "licao_introduzida": 2,
                "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_161",
                "exemplo_uso": "Ybyrá guasu.",
                "transliteracao": "y-by-RA",
                "status": "completo"
            },
            {
                "palavra": "Kapi'i",
                "traducao": "Capim / Folhagem",
                "variante": "tupi_revitalizado",
                "categoria": "flora",
                "capitulo_introduzido": 11,
                "licao_introduzida": 2,
                "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_163",
                "exemplo_uso": "Kapi'i oka ári.",
                "transliteracao": "ka-pi-I",
                "status": "completo"
            }
        ],
        "12": [
            {
                "palavra": "U",
                "traducao": "Comer",
                "variante": "tupi_revitalizado",
                "categoria": "verbos",
                "capitulo_introduzido": 12,
                "licao_introduzida": 1,
                "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_170",
                "exemplo_uso": "A-u manioka.",
                "transliteracao": "U",
                "status": "completo"
            },
            {
                "palavra": "I",
                "traducao": "Beber",
                "variante": "tupi_revitalizado",
                "categoria": "verbos",
                "capitulo_introduzido": 12,
                "licao_introduzida": 1,
                "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_170",
                "exemplo_uso": "A-i 'y.",
                "transliteracao": "I",
                "status": "completo"
            },
            {
                "palavra": "Sawa",
                "traducao": "Ir",
                "variante": "tupi_revitalizado",
                "categoria": "verbos",
                "capitulo_introduzido": 12,
                "licao_introduzida": 2,
                "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_171",
                "exemplo_uso": "A-sawa taba pupé.",
                "transliteracao": "sa-WA",
                "status": "completo"
            },
            {
                "palavra": "Kere",
                "traducao": "Dormir",
                "variante": "tupi_revitalizado",
                "categoria": "verbos",
                "capitulo_introduzido": 12,
                "licao_introduzida": 2,
                "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_172",
                "exemplo_uso": "A-kere inĩ pupé.",
                "transliteracao": "ke-RE",
                "status": "completo"
            }
        ],
        "13": [
            {
                "palavra": "Maraká",
                "traducao": "Chocalho sagrado",
                "variante": "tupi_revitalizado",
                "categoria": "musica",
                "capitulo_introduzido": 13,
                "licao_introduzida": 1,
                "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_180",
                "exemplo_uso": "Maraká o-puã.",
                "transliteracao": "ma-ra-KA",
                "status": "completo"
            },
            {
                "palavra": "Poracé",
                "traducao": "Dança tradicional",
                "variante": "tupi_revitalizado",
                "categoria": "musica",
                "capitulo_introduzido": 13,
                "licao_introduzida": 2,
                "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_182",
                "exemplo_uso": "Poracé taba pupé.",
                "transliteracao": "po-ra-SE",
                "status": "completo"
            },
            {
                "palavra": "Toryba",
                "traducao": "Alegria / Celebração",
                "variante": "tupi_revitalizado",
                "categoria": "musica",
                "capitulo_introduzido": 13,
                "licao_introduzida": 2,
                "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_183",
                "exemplo_uso": "Toryba guasu!",
                "transliteracao": "to-ry-BA",
                "status": "completo"
            }
        ],
        "14": [
            {
                "palavra": "Tupã",
                "traducao": "O Trovão / Entidade Cósmica",
                "variante": "tupi_revitalizado",
                "categoria": "espiritualidade",
                "capitulo_introduzido": 14,
                "licao_introduzida": 1,
                "rag_id": "6059a27432d6fb84ebb446d48015b8f0cb1ea1bc79c39c7b6e6cc6122613fdfa_chunk_5120",
                "exemplo_uso": "Tupã o-sunu ybak pupé.",
                "transliteracao": "tu-PAN",
                "status": "completo"
            },
            {
                "palavra": "Curupira",
                "traducao": "Guardião da floresta",
                "variante": "tupi_revitalizado",
                "categoria": "espiritualidade",
                "capitulo_introduzido": 14,
                "licao_introduzida": 2,
                "rag_id": "6059a27432d6fb84ebb446d48015b8f0cb1ea1bc79c39c7b6e6cc6122613fdfa_chunk_2840",
                "exemplo_uso": "Kurupera ka'a rerekua.",
                "transliteracao": "ku-ru-PI-ra",
                "status": "completo"
            },
            {
                "palavra": "Iara",
                "traducao": "Senhora das águas fluviais",
                "variante": "tupi_revitalizado",
                "categoria": "espiritualidade",
                "capitulo_introduzido": 14,
                "licao_introduzida": 2,
                "rag_id": "6059a27432d6fb84ebb446d48015b8f0cb1ea1bc79c39c7b6e6cc6122613fdfa_chunk_2845",
                "exemplo_uso": "Iara paraná pupé.",
                "transliteracao": "i-A-ra",
                "status": "completo"
            }
        ],
        "15": [
            {
                "palavra": "Pajé",
                "traducao": "Curador / Guia espiritual",
                "variante": "tupi_revitalizado",
                "categoria": "espiritualidade",
                "capitulo_introduzido": 15,
                "licao_introduzida": 1,
                "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_195",
                "exemplo_uso": "Pajé o-pohano.",
                "transliteracao": "pa-JE",
                "status": "completo"
            },
            {
                "palavra": "Pohã",
                "traducao": "Remédio / Planta curativa",
                "variante": "tupi_revitalizado",
                "categoria": "cura",
                "capitulo_introduzido": 15,
                "licao_introduzida": 2,
                "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_196",
                "exemplo_uso": "Pohã ka'a suí.",
                "transliteracao": "po-HAN",
                "status": "completo"
            }
        ],
        "16": [
            {
                "palavra": "Pé",
                "traducao": "Caminho / Trilha",
                "variante": "tupi_revitalizado",
                "categoria": "geografia",
                "capitulo_introduzido": 16,
                "licao_introduzida": 1,
                "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_205",
                "exemplo_uso": "Pé puranga.",
                "transliteracao": "PE",
                "status": "completo"
            },
            {
                "palavra": "Guata",
                "traducao": "Caminhar / Viajar",
                "variante": "tupi_revitalizado",
                "categoria": "verbos",
                "capitulo_introduzido": 16,
                "licao_introduzida": 2,
                "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_206",
                "exemplo_uso": "A-guata pé rupi.",
                "transliteracao": "gwa-TA",
                "status": "completo"
            },
            {
                "palavra": "Peabiru",
                "traducao": "Caminho ancestral sagrado",
                "variante": "tupi_revitalizado",
                "categoria": "historia",
                "capitulo_introduzido": 16,
                "licao_introduzida": 2,
                "rag_id": "6059a27432d6fb84ebb446d48015b8f0cb1ea1bc79c39c7b6e6cc6122613fdfa_chunk_4386",
                "exemplo_uso": "Peabiru guasu.",
                "transliteracao": "pe-a-bi-RU",
                "status": "completo"
            }
        ],
        "17": [
            {
                "palavra": "Moitará",
                "traducao": "Troca de bens / Aliança",
                "variante": "tupi_revitalizado",
                "categoria": "comunidade",
                "capitulo_introduzido": 17,
                "licao_introduzida": 1,
                "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_215",
                "exemplo_uso": "Moitará taba pupé.",
                "transliteracao": "moi-ta-RA",
                "status": "completo"
            },
            {
                "palavra": "Me'eng",
                "traducao": "Dar / Doar",
                "variante": "tupi_revitalizado",
                "categoria": "verbos",
                "capitulo_introduzido": 17,
                "licao_introduzida": 2,
                "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_216",
                "exemplo_uso": "A-me'eng manioka.",
                "transliteracao": "me-ENG",
                "status": "completo"
            }
        ],
        "18": [
            {
                "palavra": "Marandu",
                "traducao": "História / Memória antiga",
                "variante": "tupi_revitalizado",
                "categoria": "narrativa",
                "capitulo_introduzido": 18,
                "licao_introduzida": 1,
                "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_225",
                "exemplo_uso": "Marandu antigos suí.",
                "transliteracao": "ma-ran-DU",
                "status": "completo"
            },
            {
                "palavra": "Mba'e-kuaa",
                "traducao": "Sabedoria ancestral",
                "variante": "tupi_revitalizado",
                "categoria": "narrativa",
                "capitulo_introduzido": 18,
                "licao_introduzida": 2,
                "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_226",
                "exemplo_uso": "Mba'e-kuaa guasu.",
                "transliteracao": "mba-e-kwa-A",
                "status": "completo"
            }
        ],
        "19": [
            {
                "palavra": "Potiguara",
                "traducao": "Comedores de camarão / Guerreiros da Paraíba",
                "variante": "tupi_revitalizado",
                "categoria": "historia",
                "capitulo_introduzido": 19,
                "licao_introduzida": 1,
                "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_18",
                "exemplo_uso": "Yande Potiguara!",
                "transliteracao": "po-ti-GWA-ra",
                "status": "completo"
            },
            {
                "palavra": "Baía da Traição",
                "traducao": "Território histórico de resistência",
                "variante": "tupi_revitalizado",
                "categoria": "toponimia",
                "capitulo_introduzido": 19,
                "licao_introduzida": 2,
                "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_20",
                "exemplo_uso": "Baía da Traição yande terra.",
                "transliteracao": "ba-I-a da trai-SAO",
                "status": "completo"
            }
        ],
        "20": [
            {
                "palavra": "Pindorama",
                "traducao": "Terra das Palmeiras / Brasil indígena",
                "variante": "tupi_revitalizado",
                "categoria": "toponimia",
                "capitulo_introduzido": 20,
                "licao_introduzida": 1,
                "rag_id": "6059a27432d6fb84ebb446d48015b8f0cb1ea1bc79c39c7b6e6cc6122613fdfa_chunk_4386",
                "exemplo_uso": "Pindorama yande retama.",
                "transliteracao": "pin-do-RA-ma",
                "status": "completo"
            },
            {
                "palavra": "Nheengatu",
                "traducao": "A língua boa e articulada",
                "variante": "tupi_revitalizado",
                "categoria": "lingua",
                "capitulo_introduzido": 20,
                "licao_introduzida": 2,
                "rag_id": "c91d78e766850e39a5e3270cedfd79fdcb99c37bbff45ac46fa3bd22e4b60da8_chunk_240",
                "exemplo_uso": "A-nhe'eng Nheengatu.",
                "transliteracao": "nhe-en-ga-TU",
                "status": "completo"
            }
        ]
    }
}
