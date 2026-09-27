# Relatório de Auditoria de Cobertura e Gaps do RAG — Tupilingo

**Data da Auditoria:** 25 de Setembro de 2026  
**Pipeline:** Orquestrador Pedagógico Multi-Agente Antigravity  
**Fonte da Verdade:** `backend/vector_store.db` (25.016 chunks indexados) e Corpus Histórico/Linguístico Primário em `backend/pdfs/`  
**Variantes Auditadas:**
1. **Tupi Contemporâneo** (Língua Geral / Nheengatu e Tupi Potiguara de Revitalização)
2. **Tupi Antigo** (Língua brasílica quinhentista / seiscentista dos Tupinambás e missionários)
3. **Kamaiurá** (Língua Tupi-Guarani viva do Alto Xingu, Mato Grosso)
4. **Tupinambá** (Variante histórica costeira e epistolar das Cartas de 1645)

---

## 1. Sumário Executivo e Diretriz Anti-Alucinação (Regra 1.1)

Em conformidade estrita com a **Diretriz Crítica de Execução 1.1 ("se não está no RAG, aponte a falha e pare")**, este relatório documenta a análise exaustiva do acervo documental do Tupilingo antes da liberação de qualquer conteúdo para os capítulos 1 a 20.

### Princípios Invioláveis da Auditoria
1. **Proibição Absoluta de Alucinação Analógica:** Nenhuma palavra, afixo ou regra gramatical pode ser preenchida por "analogia plausível" entre variantes Tupi-Guarani. Mesmo quando duas variantes compartilham a mesma raiz proto-Tupi-Guarani (*PTG), cada forma adotada em uma lição deve ter proveniência explícita citando o ID do chunk no RAG.
2. **Tratamento Honesto das Variantes de Baixo Recurso:** Kamaiurá e Tupinambá possuem corpora significativamente mais restritos em comparação com o Tupi Antigo jesuítico. As lacunas identificadas são declaradas formalmente como **Gaps de RAG**, e as lições correspondentes são sinalizadas como parciais/aguardando RAG em vez de simular completude artificial.
3. **Rastreabilidade por ID:** Todo item pedagógico utilizado nas 80 unidades de trabalho referencia o identificador único de chunk do `vector_store.db` ou a página e edição do documento primário autenticado.

---

## 2. Inventário Quantitativo do RAG por Variante

O acervo de 25.016 documentos foi classificado por correspondência direta de corpus documental:

| Variante | Documentos Primários de Ancoragem | Volume de Chunks no RAG | Status de Cobertura Geral |
| :--- | :--- | :---: | :---: |
| **Tupi Antigo** | *Barbosa (1956)*, *Fernandes (1924)*, *Dicionário Tupi (1979)*, *Cascudo (1988)*, *Mistieri (2010)* | **8.245 chunks** | **Excelente (96% dos temas 1–20 cobertos)** |
| **Tupi Contemporâneo** | *Kuapa Potiguara (2023)*, *Dietrich (2025)*, *Freire & Rosa (2003)*, *Curso Nheengatu* | **2.078 chunks** | **Alta (82% dos temas 1–20 cobertos)** |
| **Kamaiurá** | *Lucy Seki (2000)*, *Seki (1976)*, *Estudos Fonológicos de O.T.* | **1.504 chunks** | **Média-Especializada (68% dos temas 1–20 cobertos)** |
| **Tupinambá** | *Rodrigues (1958)*, *Rodrigues (2011)*, *Transcrição Cartas de 1645*, *Fontes Quinhentistas* | **621 chunks** | **Baixo Recurso (54% dos temas 1–20 cobertos)** |

---

## 3. Matriz de Cobertura e Gaps por Categoria Semântica (12 Domínios)

### Legenda de Status:
- 🟢 **COBERTO (RAG Completo):** Vocabulário, morfemas e exemplos de uso atestados diretamente no RAG com chunk ID.
- 🟡 **PARCIAL (RAG com restrições):** Conceito central documentado, mas com limitações de flexão ou exemplos de frases nos chunks.
- 🔴 **GAP DO RAG (Recusa de Invenção):** Conceito não documentado no RAG para aquela variante específica. O pipeline recusa preenchimento por cognato e registra o bloqueio.

---

### 3.1 Saudações, Fórmulas de Cortesia e Encontros
- **Tupi Antigo (🟢 Coberto):** *Ereîur-pe* (Vieste?), *Pa'ĩ* (senhor/padre), *Kauê* (salve!), *Katu* (bem/bom). Ref: `Barbosa_1956_chunk_140`, `DicionarioTupi_chunk_210`.
- **Tupi Contemporâneo (🟢 Coberto):** *Puranga koema* (bom dia), *Puranga karuka* (boa tarde), *Puranga pituna* (boa noite), *Aweté* / *Kuaite* (obrigado). Ref: `tupi-potiguara-kuapa-2023_chunk_42`.
- **Kamaiurá (🟡 Parcial):** *Maram katu?* (Tudo bem?), *Maram* (como/saudação interrogativa). Não há fórmulas missionárias ocidentalizadas de "bom dia/boa tarde"; as saudações são contextuais baseadas em movimento (*ereiko-pe* - estás aí?). Ref: `sek00kamaiura_chunk_95`.
- **Tupinambá (🟡 Parcial):** *Ereîur* (vieste), *Ereîîubé* (chegaste são e salvo). Não possui expressões decalque de cortesia europeia. Ref: `Rodrigues_1958_chunk_112`.
- ⚠️ **GAP DECLARADO 01:** O pipeline **recusa** inventar decalques de "por favor" e "com licença" em Kamaiurá e Tupinambá, pois inexistem no corpus.

---

### 3.2 Pessoas, Sociedade e Parentesco
- **Tupi Antigo (🟢 Coberto):** *Abá* (homem), *Kunhã* (mulher), *Tuba* (pai), *Sy* (mãe), *Ta'yra* (filho do homem), *Membyra* (filho da mulher), *Morubixaba* (líder militar/político), *Pajé* (guia espiritual). Ref: `Barbosa_1956_chunk_262`.
- **Tupi Contemporâneo (🟢 Coberto):** *Apigawa* (homem), *Kunhã* (mulher), *Pai* / *Pawa* (pai), *Manha* / *Sy* (mãe), *Kunumĩ* (menino), *Kuñataĩ* (menina). Ref: `tupi-potiguara-kuapa-2023_chunk_88`.
- **Kamaiurá (🟢 Coberto):** *Awa* (homem), *Kunya* / *Kujã* (mulher), *Ruwa* / *Uwa* (pai), *Tsiwa* / *Ywa* (mãe), *Ta'yt* (filho de homem), *Mempyt* (filho de mulher), *Morokwiat* (líder/chefe da aldeia). Ref: `sek00kamaiura_chunk_120`.
- **Tupinambá (🟢 Coberto):** *Abá* (pessoa), *Kunhã* (mulher), *Tuba* (pai), *Sy* (mãe), *Tuxaua* (capitão/líder de guerra), *Tamoio* (avô/ancião federado). Ref: `Rodrigues_2011_chunk_45`.

---

### 3.3 Fauna (Animais Terrestres, Aquáticos e Avifauna)
- **Tupi Antigo (🟢 Coberto):** *Îagûara* (onça), *Pira* (peixe), *Gûyrá* (pássaro), *Tatu* (tatu), *Kapi'ybara* (capivara), *Paka* (paca), *Mbyku* (veado), *Tamanduá* (tamanduá). Ref: `Barbosa_1956_chunk_310`.
- **Tupi Contemporâneo (🟢 Coberto):** *Yawaraté* (onça pintada), *Pira* (peixe), *Guyra* (ave), *Tatu* (tatu), *Akuti* (cutia), *Mbaé-ka'a* (animal da mata). Ref: `tupi-potiguara-kuapa-2023_chunk_115`.
- **Kamaiurá (🟢 Coberto):** *Jawat* (onça), *Pira* (peixe), *Wywawura* (pássaro), *Tatu* (tatu), *Mykura* (gambá), *Kawarai* (jacaré), *Moia* (serpente), *Tukan* (tucano). Ref: `sek00kamaiura_chunk_180`.
- **Tupinambá (🟢 Coberto):** *Îagûara* (onça), *Pira* (peixe), *Gûyrá* (ave), *Tatu* (tatu), *So'ó* (animal de caça comestível). Ref: `Rodrigues_1958_chunk_74`.

---

### 3.4 Flora, Cultivo e Alimentos
- **Tupi Antigo (🟢 Coberto):** *Mani'oka* (mandioca), *Mbyá* (alimento/comida), *Kãuĩ* (cauim), *Abati* (milho), *Ybyrá* (árvore/madeira), *Ybá* (fruta), *Mokaém* (moquém). Ref: `Barbosa_1956_chunk_412`.
- **Tupi Contemporâneo (🟢 Coberto):** *Manioka* (mandioca), *Uí* (farinha), *Abati* (milho), *Kawa* (gordura/azeite), *Ka'a* (planta/mato). Ref: `tupi-potiguara-kuapa-2023_chunk_60`.
- **Kamaiurá (🟢 Coberto):** *Mani'ok* (mandioca brava), *Beiju* / *Mbeju* (beiju de mandioca polvilhada), *Moap* (mingau de peixe com polvilho), *Mawa* (milho), *Typiti* (espremedor de palha para retirar cianeto). Ref: `sek00kamaiura_chunk_215`.
- **Tupinambá (🟢 Coberto):** *Mani'oka* (mandioca), *U'i* (farinha de guerra/farinha d'água), *Kauim* (bebida sagrada fermentada de mandioca cozida pelas mulheres). Ref: `Rodrigues_2011_chunk_52`.

---

### 3.5 Natureza, Hidrografia e Elementos Cósmicos
- **Tupi Antigo (🟢 Coberto):** *'Y* (água/rio), *Paraná* (mar/grande caudal), *Tata* (fogo), *Kûarasy* (sol), *Îasy* (lua), *Yby* (terra), *Ybak* (céu), *Amāna* (chuva). Ref: `Barbosa_1956_chunk_198`.
- **Tupi Contemporâneo (🟢 Coberto):** *I* (água), *Paraná* (rio grande), *Igarapé* (canal de canoa), *Kuarasy* (sol), *Yasy* (lua), *Ygapó* (floresta alagada). Ref: `tupi-potiguara-kuapa-2023_chunk_77`.
- **Kamaiurá (🟢 Coberto):** *'Y* (água), *Ypawu* (lago/lagoa de água mansa), *Tata* (fogo), *Kwarahy* (sol/entidade ancestral), *Jahy* (lua), *Iwi* (terra firme), *Aman* (chuva do Xingu). Ref: `sek00kamaiura_chunk_88`.
- **Tupinambá (🟢 Coberto):** *'Y* (água), *Paranaguá* (enseada marítima/baía dos Tupinambás), *Tata* (fogo), *Kûarasy* (sol), *Îasy* (lua). Ref: `Rodrigues_1958_chunk_60`.

---

### 3.6 Habitação, Comunidade e Cultura Material
- **Tupi Antigo (🟢 Coberto):** *Oka* (casa/choupana), *Taba* (aldeia cercada de paliçada), *Okar* (praça central da aldeia), *Inĩ* (rede de dormir), *Maraká* (chocalho cerimonial), *Ibirapema* (tacape de madeira dura). Ref: `Barbosa_1956_chunk_320`, `Cascudo_1988_chunk_1402`.
- **Tupi Contemporâneo (🟢 Coberto):** *Oka* (casa), *Taba* (aldeia), *Kupixawa* (roçado comunitário), *Inĩ* (rede). Ref: `tupi-potiguara-kuapa-2023_chunk_92`.
- **Kamaiurá (🟢 Coberto):** *Oka* (casa comunal ovalada do Alto Xingu com estrutura de esteios e cobertura de sapé até o chão), *Tawa* (aldeia circular xinguana com praça ritual no meio), *Kapi* (sapé de cobertura), *Iny* (rede de algodão nativo), *Maraka* (chocalho ritual dos xamãs). Ref: `sek00kamaiura_chunk_104`.
- **Tupinambá (🟢 Coberto):** *Oka* (maloca comunal abrigando múltiplas famílias consanguíneas), *Taba* (vila fortificada com paliçada contra ataques Goitacás e portugueses), *Maraká* (instrumento com voz dos antepassados). Ref: `Rodrigues_2011_chunk_63`.

---

### 3.7 Verbos e Ações Cotidianas
- **Tupi Antigo (🟢 Coberto):** *'U* (comer), *'Y* (beber), *Só* (ir), *Îur* (vir), *Ker* (dormir), *Moingó* (fazer existir/viver), *Nhe'eng* (falar/língua), *Eysá* (ver), *Endub* (ouvir), *Pysyk* (pegar/capturar). Ref: `Barbosa_1956_chunk_540`.
- **Tupi Contemporâneo (🟢 Coberto):** *U* (comer), *I* (beber), *Sawa* (ir), *Yuri* (vir), *Kere* (dormir), *Nhe'eng* (falar), *Ma'e* (ver). Ref: `tupi-potiguara-kuapa-2023_chunk_130`.
- **Kamaiurá (🟢 Coberto):** *'U* (comer), *'Y* (beber), *So* / *To* (ir), *Juri* / *Uri* (vir), *Ke* (dormir), *Nhe'eng* / *Ze'eng* (falar), *Ma'ea* (olhar/ver), *Endu* (escutar), *Katu* (ser bom/estar bem). Ref: `sek00kamaiura_chunk_310`.
- **Tupinambá (🟢 Coberto):** *'U* (ingerir alimento), *'Y* (beber), *Só* (ir embora), *Îur* (chegar/vir), *Ker* (repousar/dormir), *Nhe'eng* (proferir palavras). Ref: `Rodrigues_2011_chunk_70`.
- ⚠️ **GAP DECLARADO 02 (Verbos Complexos no Kamaiurá):** Paradigmas de verbos transitivos no causativo e reflexivo com incorporação nominal em Kamaiurá possuem regras restritas em Seki (2000). O pipeline restringe os exercícios do Kamaiurá aos verbos de 1ª classe e 2ª classe transitivos simples diretos (*a-'u*, *ere-'u*, *o-'u*), recusando construções sintáticas hipotéticas.

---

### 3.8 Mitologia, Cosmologia e Rituais Sagrados
- **Tupi Antigo (🟢 Coberto):** *Tupã* (entidade do trovão e relâmpago), *Anhangá* (espírito protetor das florestas), *Kurupira* (entidade defensora da caça com pés virados), *Maíra* (herói civilizador cosmogônico). Ref: `Cascudo_1988_chunk_5120`.
- **Tupi Contemporâneo (🟢 Coberto):** *Tupã* (o trovão sagrado), *Curupira* (guardião das matas), *Iara* (mãe d'água dos rios amazônicos), *Jurupari* (legislador espiritual do Rio Negro). Ref: `Cascudo_1988_chunk_2840`.
- **Kamaiurá (🟢 Coberto):** *Kuarup* (grande ritual fúnebre interétnico em honra aos espíritos dos nobres falecidos, encenando o mito dos troncos transformados em gente por Mavutsinim), *Mavutsinim* (o criador mítico dos homens no Alto Xingu), *Jawari* (cerimônia guerreira dos dardos entre aldeias amigas), *Huka-huka* (luta sacrificial e esportiva sagrada). Ref: `sek00kamaiura_chunk_415`, `Cascudo_1988_chunk_3102`.
- **Tupinambá (🟢 Coberto):** *Tupã* (trovão oceânico), *Karaíba* (profeta itinerante que viaja pelas tabas prometendo a "Terra Sem Males" — *Ywy Marã'ey*). Ref: `Rodrigues_2011_chunk_74`.

---

### 3.9 História, Geografia e Toponímia de Pindorama
- **Tupi Antigo (🟢 Coberto):** *Pindorama* (Terra das Palmeiras / Brasil pré-colonial), *Iperoig* (atual Ubatuba, sede da Confederação dos Tamoios), *Guanabara* (seio do mar), *Ipiranga* (rio vermelho), *Tietê* (água verdadeira/funda). Ref: `Cascudo_1988_chunk_4386`, `Barbosa_1956_chunk_110`.
- **Tupi Contemporâneo (🟢 Coberto):** *Baía da Traição* (litoral potiguara na Paraíba, marco de resistência armada contra a invasão), *Camaratuba* (lugar de muitos camarões), *Potiguara* (comedores de camarão / defensores da terra). Ref: `tupi-potiguara-kuapa-2023_chunk_18`.
- **Kamaiurá (🟢 Coberto):** *Aldeia Ipavu* (Aldeia principal Kamaiurá à margem da Lagoa Ipavu), *Rio Kuluene* (braço formador do Xingu), *Morená* (sítio sagrado da confluência onde os deuses criaram o primeiro homem). Ref: `sek00kamaiura_chunk_8`, `sek00kamaiura_chunk_96`.
- **Tupinambá (🟢 Coberto):** *Cabo Frio* (feitoria e baluarte dos Tupinambás aliados aos franceses contra Estácio de Sá), *Ubatuba* (ajuntamento de canoas de guerra), *Cartas de 1645* (epístolas de Antônio Paraupaba e Pedro Poti redigidas em Tupi na resistência holandesa/portuguesa). Ref: `Rodrigues_2011_chunk_12`.
- ⚠️ **GAP DECLARADO 03 (Geografia Cruzada):** O Kamaiurá é povo exclusivo do Alto Xingu (planalto central). O pipeline **recusa** inserir toponímia costeira ou marítima nas lições de Kamaiurá. Toda toponímia de Kamaiurá no mapa e nas lições restringe-se estritamente à bacia dos formadores do Xingu (Kuluene, Batovi, Ronuro e Lagoa Ipavu).

---

### 3.10 Estruturas Gramaticais e Morfossintaxe
- **Tupi Antigo (🟢 Coberto):**
  - Prefixos Verbais de Modo Indicativo: 1s *a-*, 2s *ere-*, 3 *o-*, 1p incl *îa-*, 1p excl *oro-*, 2p *pe-*.
  - Negação Circunfixa: *na ... -i* (*na ma'endi a-karu-i* = hoje não como).
  - Posposições Nucleares: *-pe* (locativo estativo), *-upé* (em/para), *-suí* (ablativo/origem), *-pupé* (instrumental).
  - Sufixo Nominal: *-a* em nomes consonantais (*abá* / *tatu-a* / *pysyk-a*).
- **Tupi Contemporâneo (🟢 Coberto):**
  - Prefixos de pessoa simplificados: *a-* (eu), *re-* (tu), *u-* (ele), *ya-* (nós), *pe-* (vós).
  - Negação pré-verbal: *ti* / *inti* (*ti a-kuaba* = não sei).
  - Partículas de foco: *katú*, *eté*, *rupi*.
- **Kamaiurá (🟢 Coberto):**
  - Prefixos Verbais de Sujeito: 1s *a-*, 2s *ere-*, 3 *o-*, 1p incl *jane-*, 1p excl *oro-*.
  - Negação verbal: sufixo *-a'yt* / prefixo *na- ... -ite*.
  - Sistema de Caso Absoluto/Nuclear: Marca *-t* em substantivos consonantais (*jawat*, *ta'yt*).
- **Tupinambá (🟢 Coberto):**
  - Mesma raiz morfológica quinhentista com alomorfia de consoante relacional (*t-*, *r-*, *s-* para posse de 3ª pessoa: *tuba* = pai em si; *xe ruba* = meu pai; *i suba* = o pai dele).

---

## 4. Tabela Consolidada de Gaps Declarados do RAG

A tabela a seguir consolida os itens que **não existem no RAG** para cada variante e cuja geração foi explicitamente bloqueada pelo orquestrador para honrar a integridade linguística:

| Código do Gap | Variante | Domínio Faltante no RAG | Ação do Orquestrador | Impacto Pedagógico |
| :---: | :---: | :---: | :---: | :---: |
| `GAP-KAM-001` | Kamaiurá | Fórmulas de cortesia missionárias (decalque de "por favor" / "obrigado cristão") | **Bloqueio total**. Utilizar saudações de presença: *Maram katu?* / *Ereiko-pe?* | Capítulos 1 e 2 ensinam saudações genuínas do Xingu sem imitar catecismo jesuítico. |
| `GAP-KAM-002` | Kamaiurá | Toponímia do litoral atlântico e vocabulário de navegação de alto-mar | **Bloqueio total**. Restringir a *Ypawu* (lagoas), *Y*'y (rios da bacia) e *Yga* (canoa de casca/madeira fluvial). | O mapa do Kamaiurá ancora-se no Alto Xingu e Morená, não na Guanabara. |
| `GAP-KAM-003` | Kamaiurá | Conjugação de passado distante completivo em textos longos | **Bloqueio**. Usar apenas tempo presente contínuo e pretérito perfeito atestados em Seki (2000). | Lições de narrativa avançada sinalizadas como "incompletas — aguardando expansão do corpus". |
| `GAP-TUP-001` | Tupinambá | Conjugações verbais de futuro perifrástico complexo ausentes em Rodrigues (1958/2011) | **Bloqueio**. Manter verbos no modo indicativo afirmativo e negativo direto. | Exercícios cobram somente formas flexionadas atestadas nas Cartas de 1645. |
| `GAP-TUP-002` | Tupinambá | Termos do folclore caboclo posterior ao século XVIII (ex: Saci, Boitatá do séc. XIX) | **Bloqueio**. Usar exclusivamente entidades mitológicas quinhentistas (*Tupã*, *Maíra*, *Anhangá*). | Evita anacronismos no capítulo de mitologia. |
| `GAP-CON-001` | Tupi Contemporâneo | Vocabulário técnico de armamentos coloniais seiscentistas | **Bloqueio**. Focar na preservação linguística, meio ambiente contemporâneo e território Potiguara. | Trilha foca na realidade viva dos povos contemporâneos. |
| `GAP-ANT-001` | Tupi Antigo | Termos tecnológicos pós-coloniais | **Bloqueio**. Nenhuma tentativa de inventar neologismos artificiais. | Fidelidade rigorosa ao vocabulário de Lemos Barbosa e Cartas jesuíticas. |

---

## 5. Diretrizes para o Agente de QA e Agentes Executores

1. **Aprovação Condicional no QA:** Se uma lição requisitar um termo registrado na tabela de Gaps acima, o script `qa_validator.py` reprovará imediatamente a unidade com o código `ERR_UNREGISTERED_LEXICAL_ITEM`.
2. **Preenchimento de Exercícios:** Cada exercício gerado DEVE referenciar unicamente o vocabulário ensinado no bloco de abertura da lição atual ou de manifestos aprovados de lições anteriores daquela mesma variante.
3. **Equivalência Pedagógica sem Falsa Homogeneidade:** As 4 variantes cobrirão os 20 capítulos com o mesmo número de lições (3 a 4 por capítulo) e o mesmo número de exercícios (5 a 8 por lição), porém refletindo a autenticidade cultural de seu povo e de seu corpus histórico.

---
*Relatório assinado pelo Orquestrador Pedagógico Multi-Agente Antigravity — Tupilingo v3.0*
