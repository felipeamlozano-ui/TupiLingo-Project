# TupiLingo — Especificação do Mapa Histórico Progressivo de Pindorama
**Versão:** 3.0.0  
**Status:** Aprovado / Produção  
**Dataset de Referência:** [`mapa_pindorama.json`](file:///c:/Users/Felipe/Desktop/TupiLingo/backend/pedagogico/mapa/mapa_pindorama.json)  
**Regra Anti-Alucinação:** Proveniência Obrigatória no RAG (Seção 1.1)

---

## 1. Visão Geral e Filosofia Pedagógica

O **Mapa Histórico de Pindorama** é o sistema geográfico-narrativo de incentivo de progressão do TupiLingo. Ele transforma a jornada de aprendizado das quatro variantes Tupi (**Tupi Contemporâneo**, **Tupi Antigo**, **Kamaiurá** e **Tupinambá**) em uma viagem espaço-temporal pela geografia real indígena e colonial do Brasil.

### Princípios Norteadores:
1. **Toponímia e Geografia Real:** Aldeias, tabas, vilas históricas, baías, serras e rios correspondem a localidades geográficas reais com coordenadas de alta precisão (WGS-84 / latitude e longitude).
2. **Progressão Espaço-Temporal:** O usuário inicia no litoral sudeste/leste no século XVI pré-colonial (Confederação dos Tamoios, Baía de Guanabara, Iperoig), viaja pelas missões jesuíticas, migra para a Amazônia do Grão-Pará e Maranhão, penetra o Alto Xingu (Kamaiurá) e desemboca nas comunidades contemporâneas do Rio Negro e da Paraíba no século XXI.
3. **Desbloqueio Progressivo por Capítulo:** Cada capítulo concluído na Trilha Única (1 a 20) desbloqueia uma nova região no mapa com animação de névoa de guerra (*fog-of-war*), revelando marcos culturais, áudios e narrativas autênticas do RAG.
4. **Integração com o World Engine do Flutter:** Compatível com o motor de câmera e renderização isométrica/geográfica do app móvel ([`camera_state.dart`](file:///c:/Users/Felipe/Desktop/TupiLingo/frontend/tupi_lingo/lib/core/world_engine/camera/camera_state.dart)).

---

## 2. Tabela de Progressão dos 20 Estágios

| Cap. | ID Região | Nome da Localidade | Topônimo Indígena | Povo / Nação | Período Histórico | Lat / Long | Chunk RAG Ref. |
| :---: | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **01** | `REG_01_IPEROIG` | Praia de Iperoig (Ubatuba, SP) | *Iperoig* ("Água de tubarões") | Tupinambá | Séc. XVI (1563 - Tamoios) | `-23.4339, -45.0711` | `6059...chunk_4386` |
| **02** | `REG_02_URUCUMIRIM` | Taba de Uruçumirim (Glória, RJ) | *Uruçumirim* ("Onde vivem as pequenas abelhas") | Tupinambá | 1555–1567 (França Antártica) | `-22.9231, -43.1764` | `6d76...chunk_260` |
| **03** | `REG_03_SERRA_DO_MAR` | Trilha da Mata Atlântica Ancestral | *Paranapiacaba* ("De onde se avista o mar") | Tupiniquim / Tupinambá | Pré-colonização | `-23.7788, -46.3015` | `6d76...chunk_310` |
| **04** | `REG_04_SAO_VICENTE` | Estuário de São Vicente e Guaíbe | *Guaíbe* ("Lugar de água calma") | Tupiniquim | 1532 (Início da colonização) | `-23.9634, -46.3919` | `6d76...chunk_385` |
| **05** | `REG_05_PIRATININGA` | Planalto de Piratininga | *Piratininga* ("Peixe seco") | Tupiniquim | 1554 (Aldeamento jesuítico) | `-23.5489, -46.6388` | `6059...chunk_1204` |
| **06** | `REG_06_PARAIBA_SUL` | Vale do Rio Paraíba do Sul | *Paraíba* ("Rio ruim de navegar") | Puri / Tamoio | Séc. XVI–XVII | `-22.5211, -44.1042` | `6059...chunk_2150` |
| **07** | `REG_07_PORTO_SEGURO` | Aldeia de Cricaré e Porto Seguro | *Buranhém* ("Pau-doce") | Tupiniquim | 1500–1534 | `-16.4435, -39.0643` | `6059...chunk_1800` |
| **08** | `REG_08_ITAPARICA` | Ilha de Itaparica e Todos-os-Santos | *Itaparica* ("Cerca de pedras") | Tupinambá | Séc. XVI | `-12.9328, -38.6789` | `6059...chunk_3400` |
| **09** | `REG_09_SERGIPE_DEL_REI` | Território do Cacique Serigy | *Sergipe* ("Rio dos siris") | Tupinambá | 1575–1590 | `-10.9095, -37.0748` | `6059...chunk_5120` |
| **10** | `REG_10_POTIGUARA_PB` | Forte de Santa Catarina de Cabedelo | *Paraíba* ("Água de difícil travessia") | Potiguara | 1585–1599 | `-6.9812, -34.8335` | `6059...chunk_6210` |
| **11** | `REG_11_CUNHAU_RN` | Engenho de Cunhaú e Baía Formosa | *Cunhaú* ("Bebedouro de mulheres") | Potiguara | 1645 (Massacre de Cunhaú) | `-6.3142, -35.0833` | `b680...chunk_24` |
| **12** | `REG_12_MARANHAO_URUSSANGA`| Taba de Urussanga (Ilha de Upaon-Açu) | *Upaon-Açu* ("Ilha Grande") | Tupinambá | 1612 (França Equinocial) | `-2.5307, -44.3068` | `b680...chunk_78` |
| **13** | `REG_13_CAMETA_TOCANTINS` | Foz do Rio Tocantins e Cametá | *Cametá* ("Degrau / queda d'água") | Camutá / Tupinambá | Séc. XVII | `-2.2428, -49.4958` | `b680...chunk_142` |
| **14** | `REG_14_BELEM_GRAO_PARA` | Feliz Lusitânia e Baía do Guajará | *Guajará* ("Água dos guarás") | Tupinambá | 1616 (Fundação de Belém) | `-1.4558, -48.5039` | `b680...chunk_210` |
| **15** | `REG_15_TAPAJOS_SANTAREM` | Encontro das Águas do Tapajós | *Tapajós* ("Gente de cara pintada") | Tapajó / Tupinambá | Séc. XVII–XVIII | `-2.4431, -54.7083` | `c91d...chunk_312` |
| **16** | `REG_16_IPAVU_KAMAIURA` | Lagoa de Ipavu (Alto Xingu) | *Ipavu* ("Água grande / lago sagrado") | Kamaiurá | Tradição Imemorial | `-12.1842, -53.4211` | `1e95...chunk_88` |
| **17** | `REG_17_MORENA_XINGU` | Posto Leonardo Villas-Bôas | *Morena* (Confluência Formadores) | Kamaiurá, Yawalapiti | 1961 (Parque Indígena) | `-12.0125, -53.3856` | `1e95...chunk_142` |
| **18** | `REG_18_RIO_NEGRO_SAO_GABRIEL`| São Gabriel da Cachoeira (Rio Negro) | *Yauaretê* ("Cachoeira da Onça") | Povos do Rio Negro | Séc. XIX–XXI | `-0.1302, -67.0892` | `c91d...chunk_450` |
| **19** | `REG_19_BAIA_TRAICAO_PB` | Aldeias Potiguara de Baía da Traição | *Akajutibiró* ("Cajuzeiro azedo") | Potiguara | Contemporâneo (Séc. XXI) | `-6.6872, -34.9317` | `c91d...chunk_620` |
| **20** | `REG_20_ALDEIA_GLOBAL_PINDORAMA`| Encontro das Quatro Matrizes | *Pindorama* ("Terra das Palmeiras") | Todas as Nações Tupi | Contemporâneo & Futuro | `-15.7938, -47.8827` | `6059...chunk_8240` |

---

## 3. Estrutura de Metadados de Cada Estágio

O arquivo JSON [`mapa_pindorama.json`](file:///c:/Users/Felipe/Desktop/TupiLingo/backend/pedagogico/mapa/mapa_pindorama.json) implementa para cada nó geográfico o schema a seguir:

```json
{
  "chapter": 1,
  "id_regiao": "REG_01_IPEROIG",
  "nome": "Praia de Iperoig (Ubatuba)",
  "toponimo_indigena": "Iperoig ('Água de tubarões')",
  "nacao_indigena": "Tupinambá",
  "variantes_associadas": ["tupi_antigo", "tupinamba"],
  "periodo_historico": "Século XVI (Pré-colonização / 1563)",
  "coordenadas_reais": {
    "latitude": -23.4339,
    "longitude": -45.0711
  },
  "mapa_relativo": {
    "x": 0.72,
    "y": 0.68,
    "raio": 26.0
  },
  "narrativa_rag": "Coração da resistência dos Tamoios liderada por Cunhambebe...",
  "elementos_destaque": [
    "Paliçada de Iperoig",
    "Praia de desembarque das canoas",
    "Conselho dos Guerreiros"
  ],
  "rag_chunk_ref": "6059a27432d6fb84ebb446d48015b8f0cb1ea1bc79c39c7b6e6cc6122613fdfa_chunk_4386"
}
```

---

## 4. Integração Frontend (Flutter World Engine)

### 4.1 Coordenadas Relativas do Canvas Isométrico
- As coordenadas relativas `(x, y)` normalizam o mapa do Brasil e Pindorama em um plano cartesiano unitário `[0.0, 1.0] \times [0.0, 1.0]`.
- O parâmetro `raio` (em pixels lógicos) define a zona de desanuviamento da névoa de guerra ao desbloquear o capítulo.

### 4.2 Estados do Nó no App
1. **`LOCKED` (Bloqueado):** Nó coberto por névoa cinza com runas indígenas estilizadas.
2. **`UNLOCKED_NEW` (Recém-desbloqueado):** Dispara vinheta sonora tradicional (maracá/flauta uruá), transição suave de câmera com *pan* e *zoom*, e exibição do modal cultural com texto de contexto e pronúncia do topônimo.
3. **`EXPLORED` (Explorado):** Marcador ativo com ícone temático (canoa, maloca, peixe, onça, vitória-régia) permitindo revisitação livre a qualquer momento.
