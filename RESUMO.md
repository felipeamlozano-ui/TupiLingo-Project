# Resumo da Arquitetura do Sistema: TupiLingo

A plataforma TupiLingo representa um ecossistema complexo voltado à preservação e ao ensino das línguas Tupi Antigo, Tupinambá e Tupi Contemporâneo. Destaca-se não apenas por seu objetivo cultural, mas sobretudo pela forte aplicação de padrões de **Engenharia de Software Avançada** (*Enterprise-Ready*).

Abaixo está o detalhamento completo de como o sistema funciona e suas respectivas práticas de engenharia:

## 1. Arquitetura Geral Distribuída

O projeto baseia-se numa arquitetura modular onde responsabilidades estão firmemente divididas para escalar e isolar falhas.

*   **Frontend Mobile/Web (Flutter):** Adota a metodologia **Clean Architecture**. Separa claramente a interface (UI), o domínio (regras de negócio) e os repositórios (acesso a dados), tornando o aplicativo totalmente coeso, testável e desacoplado.
*   **Backend Híbrido (Django / REST):** A API orquestra as requisições principais de validação e roteamento lógico. Escrito em Python utilizando Django REST Framework, opera como ponto de controle centralizado de autenticação, throttling/rate-limiting (proteção contra abuso) e gerenciamento dos pacotes da aplicação.
*   **Filas e Background Workers:** As atividades mais custosas e lentas - como, por exemplo, extrair textos de PDFs escaneados via OCR ou processar vetores em larga escala - **não travam o usuário final**. O sistema joga essas tarefas numa fila no **Redis**, e robôs assíncronos (Workers) via **Celery** as processam paralelamente em background.

## 2. Persistência de Dados (Três Camadas)

Para garantir máxima eficiência financeira e de tráfego, a TupiLingo adota um banco de dados multicamada com focos específicos:

*   **PostgreSQL via Supabase:** O banco unificado em nuvem atua como fonte da verdade (*Source of Truth*). Contém os dados de usuários e estado consolidado. Utiliza RPCs altamente focadas.
*   **SQLite Local (Para GraphRAG):** Uma decisão notável de arquitetura foi manter a criação de vetores (para inteligência artificial) em um store relacional e leve (SQLite) instalado **localmente**. Isso elimina custos massivos com infraestruturas de nuvem especializadas em Vetores (VectorDBs na fase de ingestão).
*   **Redis:** Um armazém em memória de extrema velocidade, encarregado de funcionar como broker das tarefas (mensageria para o Celery) e cacheamento de rotas requisitadas frequentemente, eliminando a dependência do banco principal para leitura quente.

## 3. Inteligência Artificial Resiliente e Pipeline RAG

A integração de LLMs e Recuperação Aumentada (RAG) é feita sob a perspectiva de confiabilidade máxima:

*   **AI Router (LiteLLM) & Failover:** O roteador funciona sob um padrão de *Ping Race*. Quando uma IA é requisitada (seja para contexto histórico ou para as questões), pings simultâneos são enviados para provedores como DashScope, Groq, Gemini e Cerebras. O provedor que apresentar a menor latência responde à requisição do usuário.
*   **Tolerância a Falhas Estrutural (29 Modelos):** Se houver uma limitação na API (*Rate-Limit* 429) ou um provedor cair, um mecanismo de resiliência tenta sucessivamente 29 modelos distintos (inclusive instâncias sem custo de Nuvem ou Ollama localmente), de forma totalmente imperceptível ao aluno final.
*   **Embeddings com FastEmbed:** O ecossistema gera *embeddings* sem custos utilizando processamento estritamente interno e local sem necessidade de *vendors* caros.

## 4. Teoria de Resposta ao Item (IRT/TRI) e Ensino Adaptativo

Indo contra a maré dos cursos tradicionais (que servem currículos estáticos e idênticos para todos), o módulo de aprendizado age adaptativamente:

*   **Motor TRI Constante:** A cada pergunta respondida, o TupiLingo reavalia matematicamente o conhecimento do usuário ($\theta$). A dificuldade das lições subseqüentes é modelada e provisionada estritamente com base nisso (as questões trazem uma calibragem de nível e discriminação). O motor procura entregar uma pergunta que produza a *maior quantidade de informação* útil para avaliar o progresso, evitando exercícios irrelevantes, chatos ou difíceis demais.
*   **Modo Estrito (Heurística Fallback):** Caso ocorra o evento raríssimo da indisponibilidade simultânea de todas as IAs em nuvem, não acontece downtime. Uma heurística autônoma determinística entra em cena montando a questão com componentes sintáticos diretos do banco de dados relacional.

## 5. Práticas Notáveis da Engenharia de Software

As abordagens do projeto confirmam um foco total em sistemas confiáveis:

*   **Idempotência Obrigatória:** Processamentos paralelos gravam o estado no banco sob semânticas de contingência, ou seja, se um servidor de processamento desligar e ligar, tarefas repetidas não corrompem o banco devido a um padrão forte de `ON CONFLICT DO UPDATE`.
*   **Observabilidade Universal (OpenTelemetry):** Rotas HTTP e ações lógicas complexas produzem traços e monitoramentos nativos pelo ecossistema de dados, permitindo depuração fácil com Prometheus e sistemas de notificação no caso de comportamentos suspeitos.
*   **CI/CD e Containerização:** Tudo é acoplado dentro de imagens imutáveis através de *Docker* (e *Docker Compose*). Toda alteração estrutural necessita ser aprovada por pipelines restritas (de lint, segurança, de arquitetura Flutter e do Backend com pytest) validando o artefato de *build* perfeitamente blindado e reproduzível.

Esse compilado reflete a genialidade de juntar os objetivos humanísticos de preservação cultural a um patamar altamente técnico com padrões industriais na construção de software.
