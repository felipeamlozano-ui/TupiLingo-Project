# RELATÓRIO DE AUDITORIA FORENSE E QA DE SEGURANÇA — TUPILINGO
**Data da Auditoria:** 25 de Setembro de 2026  
**Status do Auditor:** Agente de Auditoria Forense e QA de Segurança (Modo Estrito / Sem Justificativas Evasivas)  
**Escopo:** Verificação de 4 potenciais modos de falha e anomalias na execução anterior.

---

## 1. INVESTIGAÇÃO 1: Auditoria de Integridade dos Testes Unitários

### 1.1 Comando Executado
```bash
git diff app/tests/test_quiz_service.py
```

### 1.2 Diff Exato
```diff
diff --git a/backend/app/tests/test_quiz_service.py b/backend/app/tests/test_quiz_service.py
index dabd053..319e309 100644
--- a/backend/app/tests/test_quiz_service.py
+++ b/backend/app/tests/test_quiz_service.py
@@ -197,6 +197,7 @@ class TestRAGServiceHybrid:
         assert "explicacao" in primeira
         assert len(primeira["alternativas"]) == 4 
 
+    @patch("app.ai.rag_service.get_redis_client", return_value=None)
     @patch("app.ai.rag_service._USE_SUPABASE_ENGINE", True)
     @patch("app.ai.rag_service.supabase_service")
     @patch("app.ai.rag_service.FallbackOrchestrator.execute_with_fallback")
@@ -204,6 +205,7 @@ class TestRAGServiceHybrid:
         self,
         mock_fallback: MagicMock,
         mock_supabase: MagicMock,
+        mock_redis: MagicMock,
     ) -> None:
         """Garante que a cada chamada o Supabase é consultado para gerar questões inéditas (sem cache)."""
         from app.ai.rag_service import RAGService
```

### 1.3 Classificação Técnica Objetiva
- [x] **Refatoração de infraestrutura:** O patch adicionou `@patch("app.ai.rag_service.get_redis_client", return_value=None)` para isolar o teste unitário de resíduos de cache do daemon Redis local ativo na máquina do desenvolvedor.
- [ ] **Relaxamento de asserções:** NENHUMA asserção foi enfraquecida, modificada ou removida.

### 1.4 Análise Detalhada das Asserções
No teste em questão (`test_geracao_dinamica_sempre_consulta_supabase`):
- Linha 227: `assert "questoes" in result` (MANTIDO)
- Linha 228: `assert len(result["questoes"]) == 10` (MANTIDO)
- Linha 230: `mock_supabase.obter_esqueleto_quiz.assert_called_once()` (MANTIDO)

**Causa Raiz da Falha Prévia:** O método `RAGService.generate` possui um circuito O(1) que consome o Question Pool do Redis via `r.spop(pool_key)`. Como o Redis local continha chaves populadas em testes anteriores, o código retornava o pacote do pool antes de chamar o Supabase. Ao mockar `get_redis_client` para retornar `None`, forçou-se a execução síncrona através do Supabase.

**Veredito:** **LEGÍTIMO (Sem relaxamento).** Contudo, cabe ressaltar que `test_quiz_service.py` é um teste de integração de backend pré-existente para a rota Supabase/Redis, e **não** o validador pedagógico determinístico das 80 unidades pedagógicas, que reside isoladamente em `pedagogico/qa_validator.py`.

---

## 2. INVESTIGAÇÃO 2: Reconciliação Aritmética do RAG (25.016 vs. 12.448 chunks)

### 2.1 Saída Bruta do Script de Consulta
```
TOTAL BRUTO NO DB: 25016
BREAKDOWN REAL POR VARIANTE: {}
CHUNKS SEM VARIANTE/ORFÃOS: 25016
CHAVES DE METADADOS EXISTENTES: ['file_hash', 'page', 'chunk_index', 'filename']
```

### 2.2 Inventário Real por Arquivo Fonte (`filename`)
A consulta aos metadados revelou que o SQLite **não possui a coluna ou chave `variante`**. A classificação é derivada exclusivamente do campo `filename`. O agrupamento completo de todos os 25.016 chunks é:

| Chunks | Arquivo Fonte (`filename`) | Domínio / Conteúdo |
| :---: | :--- | :--- |
| **6.184** | `Cascudo_1988_DicionarioDoFolcloreBrasileiro_OCR.pdf` | **Folclore Geral em Português** (não-variante direta) |
| **3.096** | `Dicionário Tupi.pdf` | Tupi Antigo (Léxico Clássico) |
| **1.584** | `bookpart.pdf` | Tupi Antigo / Estudos Coloniais |
| **1.448** | `Ribeiro_1988_DicionarioDoArtesanatoIndigena.pdf` | **Etnografia Material em Português** |
| **1.426** | `sek00kamaiura.pdf` | Kamaiurá (Gramática Seki 2000) |
| **1.238** | `Barbosa_1956_CursoDeTupiAntigo_BDCN_CNic.pdf` | Tupi Antigo |
| **1.146** | `Gerardi_A Role and Reference_OA.pdf` | **Linguística Geral / Tupari / Macro-Tupi** |
| **949** | `Ayrosa_1943_ApontBibliogrLingTupiGuarani1ed.pdf` | **Bibliografia Histórica em Português** |
| **921** | `EstudoContrastivoLínguas.pdf` | **Estudo Acadêmico Contrastivo** |
| **841** | `Freire&Rosa_2003_LinguasGerais_PoliticaLingECatequese.pdf`| Língua Geral / História |
| **765** | `PagliaroETC_2005_DemografiaDosPovosIndigenasNoBrasil.pdf`| **Demografia Geral em Português** |
| **684** | `Dietrich_2025_GramaticaDaLinguaGeralDoBrazil.pdf` | Tupi Contemporâneo / Nheengatu |
| **539** | `tupi-potiguara-kuapa-2023_compress.pdf` | Tupi Contemporâneo / Potiguara |
| **457** | `Fernandes_1924_GrammaticaTupy.pdf` | Tupi Antigo |
| **455** | `Rodrigues_1958_Phonologie_der_Tupinamba.pdf` | Tupinambá |
| **390** | `Dissertação - Clara Carolina Souza Santos.pdf` | Linguística Contemporânea |
| **348** | `CURSO DE LÍNGUA GERAL (NHEENGATU).pdf` | Tupi Contemporâneo |
| **331** | `Pereira_1954_OsIndiosMaues.pdf` | **Sateré-Mawé (Não-variante TupiLingo)** |
| **237** | `Simpson_1955_GramaticaLinguaBrasileira.pdf` | Língua Geral |
| **225** | `Veiga_org_2015_EscolaKariamaContaUmbuesa_Baniwa.pdf` | **Baniwa - Família Aruak (Não-Tupi)** |
| **218** | `Masucci_1979_DicionarioTupiPortugues.pdf` | Tupi Antigo |
| **208** | `Transcrição e Tradução Carta 1645.pdf` | Tupinambá |
| **201** | `LIVRO_MYB_EBOOK-1.pdf` | **Guarani Mbyá (Não-variante TupiLingo)** |
| **191** | `4-33-3-2025-Siva-Politicas.pdf` | Políticas Linguísticas |
| **148** | `Mistieri_2010_Acento_Tupi_Antigo.pdf` | Tupi Antigo |
| **133** | `04_Wilmar da Rocha D'Angelis.pdf` | Artigo Acadêmico |
| **129** | `Leacock_1964_EconomicLifeOfTheMaueIndians.pdf` | **Mawé (Não-variante)** |
| **78** | `Rodrigues_2011_AnaliseMorfologicaDeUmTextoTupi.pdf` | Tupinambá |
| **46** | `seki_1976_kamaiura.pdf` | Kamaiurá |
| **32** | `LenitionandnasalizationinKamaiura-anOTperspective.pdf` | Kamaiurá |
| **112** | Outros 8 PDFs menores (01.pdf, 05.pdf, apostilas, etc.) | Miscelânea |

### 2.3 Reconciliação Factual dos Chunks Faltantes
- **Chunks de Fontes Diretas das 4 Variantes:** ~12.448 chunks.
- **Chunks "Evaporados" (12.568 chunks):** São documentos que constam no `vector_store.db` mas **não são gramáticas ou dicionários diretos das 4 variantes**:
  1. **Obras Etnográficas e Folclóricas em Português:** Luís da Câmara Cascudo (6.184 chunks) + Berta Ribeiro (1.448 chunks) + Demografia Pagliaro (765 chunks) + Apontamentos Ayrosa (949 chunks) = **9.346 chunks**.
  2. **Outras Famílias/Línguas Indígenas não cobertas pelo app:** Baniwa/Aruak (225 chunks), Sateré-Mawé (460 chunks), Guarani Mbyá (201 chunks), Tupari/Macro-Tupi (1.146 chunks) = **2.032 chunks**.
  3. **Estudos Históricos e Contrastivos em Prosa:** 1.190 chunks.

**Veredito:** Os 12.568 chunks "faltantes" não evaporaram por erro de banco; eles correspondem a compêndios em português de folclore, etnografia e línguas de outras famílias que foram indexados no banco vetorial mas não pertencem ao corpus estrito das 4 variantes.

---

## 3. INVESTIGAÇÃO 3: Riqueza Lexical Real e Falsa Paridade

### 3.1 Saída Bruta da Contagem de Vocabulário Inédito
```
================ VARIANTE: TUPI_CONTEMPORANEO ================
Vocabulário Único Total Ensinado nos 20 capítulos: 66
Palavras inéditas introduzidas por capítulo (1 a 20):
[6, 6, 4, 4, 4, 3, 3, 3, 4, 3, 3, 4, 3, 3, 2, 3, 2, 2, 2, 2]

================ VARIANTE: TUPI_ANTIGO ================
Vocabulário Único Total Ensinado nos 20 capítulos: 65
Palavras inéditas introduzidas por capítulo (1 a 20):
[6, 7, 4, 4, 4, 3, 3, 3, 4, 3, 3, 3, 2, 3, 2, 3, 2, 2, 2, 2]

================ VARIANTE: KAMAIURA ================
Vocabulário Único Total Ensinado nos 20 capítulos: 60
Palavras inéditas introduzidas por capítulo (1 a 20):
[6, 6, 4, 4, 4, 3, 3, 3, 4, 2, 2, 3, 2, 2, 2, 2, 2, 2, 2, 2]

================ VARIANTE: TUPINAMBA ================
Vocabulário Único Total Ensinado nos 20 capítulos: 54
Palavras inéditas introduzidas por capítulo (1 a 20):
[5, 5, 3, 4, 3, 2, 3, 2, 3, 3, 2, 3, 2, 2, 2, 2, 2, 2, 2, 2]
```

### 3.2 Análise de Densidade: A Síndrome dos "Capítulos Magros"
A análise revela uma queda acentuada na introdução de novas palavras na segunda metade dos cursos:

| Variante | Total Vocábulos Únicos | Capítulos com $\le 2$ Palavras Novas | Proporção de Capítulos com Baixa Densidade |
| :--- | :---: | :---: | :---: |
| **Tupi Contemporâneo** | 66 | 5 (Caps 15, 17, 18, 19, 20) | 25% |
| **Tupi Antigo** | 65 | 6 (Caps 13, 15, 17, 18, 19, 20) | 30% |
| **Kamaiurá** | 60 | **10** (Caps 10, 11, 13, 14, 15, 16, 17, 18, 19, 20) | **50%** |
| **Tupinambá** | 54 | **11** (Caps 6, 8, 11, 13, 14, 15, 16, 17, 18, 19, 20) | **55%** |

### 3.3 Verificação de Proveniência dos Chunks Citados
O script executado no SQLite confirmou:
- **Kamaiurá:** 48 chunks distintos citados em 61 itens ensinados. **48 de 48 existem fisicamente no SQLite (0 faltantes).**
- **Tupinambá:** 47 chunks distintos citados em 54 itens ensinados. **47 de 47 existem fisicamente no SQLite (0 faltantes).**
- **Tupi Antigo:** 53 chunks distintos citados em 66 itens ensinados. **53 de 53 existem (0 faltantes).**
- **Tupi Contemporâneo:** 53 chunks distintos citados em 66 itens ensinados. **53 de 53 existem (0 faltantes).**

### 3.4 Diagnóstico Forense da "Falsa Paridade"
Não houve alucinação ou falsificação de chunks (100% dos chunks citados são reais e conferem com Seki 2000 e Rodrigues 1958). Porém, ocorreu uma **paridade superficial de estrutura com assimetria de densidade**:
- Para não violar a Regra 1.1 ("se não está no RAG, aponte a falha e pare"), o gerador manteve os capítulos de Kamaiurá e Tupinambá abertos com apenas **2 palavras novas**, preenchendo os exercícios restantes com reciclagem do banco cumulativo (revisão contínua).
- **Conclusão:** Os capítulos 13 a 20 de Kamaiurá e Tupinambá são formalmente válidos (passam no QA determinístico porque não cobram órfãos), mas são **pedagogicamente magros** (apenas 2 termos novos por capítulo).

---

## 4. INVESTIGAÇÃO 4: O Paradoxo Lógico do Nivelamento

### 4.1 Por que a regra original foi bifurcada em 10 faixas?
Na Seção 3 do prompt original constava:
> *"Usuário nivelado como iniciante → entra no capítulo 1."*  
> *"Usuário nivelado como intermediário/avançado → entra depois do capítulo 20."*

No entanto, o módulo psicométrico em `theta_chapter_mapping.json` dividiu a escala $\theta \in [-3.0, +3.0]$ em degraus de 0.25, gerando entradas nos capítulos 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20 e 21.  
**Motivo:** Sobre-engenharia matemática do motor IRT, assumindo que maior granularidade de $\theta$ exigiria múltiplos pontos de entrada na mesma trilha iniciante.

### 4.2 Como o sistema lida com o vocabulário acumulado?
**Fato brutal:** **NÃO existe nenhum mecanismo de aclimação ou dossiê prévio.**
Se um usuário obtém $\theta = 0.35$ e o app o joga diretamente no Capítulo 11:
1. O Capítulo 11 possui exercícios que cobram itens de fauna (Cap 3), pesca (Cap 4) e família (Cap 6), pois a regra determinística permite cobrar $\bigcup_{k=1}^{11} \text{itens}$.
2. O usuário é submetido a exercícios contendo de 20 a 30 palavras que **o aplicativo nunca apresentou a ele**.
3. Isso **VIOLA** diretamente o princípio inegociável "ensinar antes de cobrar" (Seção 2).

### 4.3 Proposta de Correção Imediata

#### Opção A (Corte Estrito / Fiel à Seção 3 - Recomendada):
Substituir a tabela de 20 degraus em `theta_chapter_mapping.json` por um corte binário com aceleração interna:
1. **$\theta < 2.0$ (Iniciante / Todo usuário do conteúdo atual):** Entra SEMPRE no **Capítulo 1**. A estimativa $\theta$ é repassada ao serviço Birdbrain para dispensar revisões redundantes nos checkpoints adaptativos, mas o usuário visualiza e aprende 100% das palavras na ordem pedagógica correta.
2. **$\theta \ge 2.0$ (Intermediário/Avançado):** Encaminhado para a **Fila de Espera / Prática Temática (Pós-Capítulo 20)**.

#### Opção B (Dossiê de Aclimação de Vocabulário):
Se for mantida a entrada em capítulos intermediários (ex.: Cap 6), criar uma rota mandatória de Onboarding:
- Antes da Lição 1 do Cap 6, apresentar uma tela de "Dossiê de Vocabulário Pré-adquirido" com os termos dos capítulos 1 a 5, exigindo que o usuário confirme antes de prosseguir.

---

## 5. PLANO DE CORREÇÃO IMEDIATO

1. **Patch no Mapeamento do Nivelamento (`theta_chapter_mapping.json` & `irt_engine.py`):**
   - Eliminar os saltos cegos para capítulos intermediários (restringir entrada a Cap 1 para iniciantes e > Cap 20 para fila avançada).
2. **Transparência na Densidade dos Manifestos (`rag_gaps_report.md`):**
   - Declarar explicitamente que os capítulos 10 a 20 de Kamaiurá e Tupinambá operam em modo de "alta consolidação / baixa densidade lexical" (2 itens/capítulo) devido à exaustão de chunks primários específicos nessas variantes.
3. **Reversão do Patch de Teste vs. Fix na Configuração:**
   - Adicionar uma fixture explícita de mock do Redis em `conftest.py` para todos os testes de unidade, em vez de depender de patches ad-hoc em funções individuais de teste.
