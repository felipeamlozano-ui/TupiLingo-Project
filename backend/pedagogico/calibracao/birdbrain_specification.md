# Especificação da Calibração Contínua de Habilidade e Checkpoints ("Birdbrain") — Tupilingo

**Versão da Especificação:** 3.0.0  
**Inspiração Metodológica:** Sistema *Birdbrain* (Duolingo) adaptado a modelos de Resposta ao Item (TRI 3PL)  
**Módulo Implementador:** `backend/pedagogico/calibracao/birdbrain_service.py`  
**Configuração de Checkpoints:** `backend/pedagogico/calibracao/checkpoints_config.json`

---

## 1. Visão Geral da Arquitetura

O sistema **Birdbrain** do Tupilingo opera como um motor contínuo de rastreamento de proficiência psicométrica. Ele supera a limitação de avaliar o estudante apenas no teste inicial de entrada:

1. **Rastreamento Contínuo por Lição:** Toda resposta em qualquer exercício da trilha possui parâmetros de calibração IRT ($a, b, c$). Conforme o usuário conclui lições, o parâmetro $\theta_{atual}$ é atualizado suavemente.
2. **Checkpoints Estruturados de Revisão:** A cada 4 capítulos (Capítulos 4, 8, 12, 16 e 20), o pipeline insere marcos adaptativos de revisão com itens ensinados nos capítulos anteriores selecionados por Máxima Informação de Fisher.
3. **Mecanismo Dinâmico de Bifurcação:**
   - **Remediação Obrigatória:** Se o desempenho cair abaixo do limiar $\Delta\theta < -0.45$, o sistema bloqueia o avanço para o próximo capítulo e gera uma sessão de reforço customizada focando estritamente nos conceitos errados.
   - **Aceleração Adaptativa:** Se o desempenho for consistentemente superior ($\Delta\theta > +0.45$), o estudante ganha a opção de saltar lições de revisão redundantes (sendo terminantemente proibido saltar lições de ensino de itens novos).

---

## 2. Modelo Matemático de Atualização Incremental (Filtro Bayesiano)

A cada lição concluída composta por $K$ respostas $\{u_1, u_2, \dots, u_K\}$, a proficiência demonstrada na lição $\hat{\theta}_{licao}$ e seu erro padrão $SE_{licao}$ são calculados via EAP (Expected A Posteriori).

A fusão de $\theta_{atual}$ com a nova observação é realizada via ponderação pelo inverso da variância com taxa de aprendizagem $\alpha = 0.15$:

$$w_{anterior} = \frac{1}{\sigma_{\theta}^2}, \quad w_{licao} = \frac{\alpha}{\sigma_{licao}^2}$$

$$\theta_{novo} = \frac{w_{anterior} \cdot \theta_{atual} + w_{licao} \cdot \hat{\theta}_{licao}}{w_{anterior} + w_{licao}}$$

$$\sigma_{novo} = \sqrt{\frac{1}{w_{anterior} + w_{licao}}}$$

Essa formulação garante que:
- O nível de habilidade não oscila violentamente por causa de um único erro casual ou descuido momentâneo.
- O histórico acumulado estabiliza o Erro Padrão ($SE$), tornando a curva de proficiência auditável ao longo de semanas de estudo.

---

## 3. Matriz de Checkpoints de Revisão Periódica

| Checkpoint | Posição na Trilha | Capítulos Revisitados | Domínios em Foco | Limiar de Divergência | Aceleração Permitida? |
| :---: | :---: | :---: | :--- | :---: | :---: |
| **CP_01** | Após Capítulo 4 | Capítulos 1, 2, 3, 4 | Saudações, maloca, fauna terrestre, hidrografia | $|\Delta\theta| > 0.50$ | Sim (pula revisão cap. 5) |
| **CP_02** | Após Capítulo 8 | Capítulos 1 a 8 | Cultivo de mandioca, astros, cerâmica, aves | $|\Delta\theta| > 0.50$ | Sim (pula revisão cap. 9) |
| **CP_03** | Após Capítulo 12 | Capítulos 5 a 12 | Sentidos, liderança da aldeia, árvores, verbos | $|\Delta\theta| > 0.45$ | Sim (pula revisão cap. 13) |
| **CP_04** | Após Capítulo 16 | Capítulos 9 a 16 | Música ritual, espiritualidade, pajé, Peabiru | $|\Delta\theta| > 0.40$ | Sim (pula revisão cap. 17) |
| **CP_05** | Após Capítulo 20 | Capítulos 1 a 20 | Alianças, mitos de origem, guerras, memória viva | $|\Delta\theta| > 0.35$ | **Não** (Marco de Certificação A2/B1) |

---

## 4. Auditoria e Persistência Determinística

- Todo evento de atualização emite um registro em log legível e JSON com timestamp UTC, $\theta_{anterior}$, $\theta_{novo}$, $\Delta\theta$, acurácia percentual e ação executada.
- Garante total conformidade com a Diretriz 1.3: auditoria do progresso é 100% determinística em código Python, sem intervenção de auto-julgamento de LLM.
