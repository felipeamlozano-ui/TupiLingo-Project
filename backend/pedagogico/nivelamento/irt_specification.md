# Especificação do Novo Motor de Nivelamento Adaptativo TRI (IRT 3PL) — Tupilingo

**Versão da Especificação:** 3.0.0  
**Arquitetura:** Computerized Adaptive Testing (CAT) com Modelo Logístico de 3 Parâmetros (3PL)  
**Módulo Implementador:** `backend/pedagogico/nivelamento/irt_engine.py`  
**Integração no RAG:** Substituição contratual das antigas estruturas estáticas em `app/ai/rag_service.py`

---

## 1. Motivação e Descarte do Sistema Legado

### 1.1 Diagnóstico do Sistema Anterior
O sistema legado operava com um questionário fixo e artificial de 10 perguntas baseado nas estruturas estáticas:
- `_VARIANTE_NOME_MAP`
- `_NIVEL_TEMAS`
- `_NIVEL_CATEGORIA_MAP`
- `_NIVEL_RAG_CATEGORIAS`
- `_LETRAS`

Esse modelo apresentava graves limitações psicométricas:
1. **Incapacidade de Adaptação Dinâmica:** Todos os usuários respondiam exatamente à mesma sequência arbitrária de perguntas em dificuldade crescente, medindo apenas a posição em uma régua estática e não a verdadeira habilidade latente ($\theta$).
2. **Vulnerabilidade ao Acerto Casual ("Chute"):** O formato de 4 alternativas sem ponderação do parâmetro $c$ superestimava drasticamente a proficiência de usuários iniciantes que acertavam questões complexas por pura aleatoriedade estatística.
3. **Ausência de Paridade Real Entre as 4 Variantes:** A geração dependia de fallbacks genéricos de Tupi Antigo para cobrir lacunas no Kamaiurá ou Tupinambá.

---

## 2. Fundamentos Psicométricos do Novo Motor

### 2.1 O Modelo Logístico de 3 Parâmetros (3PL)
Para cada item $i$ administrado ao usuário com nível de habilidade $\theta$, a probabilidade de acerto é modelada por:

$$P_i(\theta) = c_i + \frac{1 - c_i}{1 + e^{-D \cdot a_i (\theta - b_i)}}$$

Onde:
- **$\theta \in [-3.0, +3.0]$**: Habilidade latente do estudante na variante selecionada.
- **$a_i > 0$ (Discriminação)**: Inclinação da Curva Característica do Item (CCI) no ponto $b_i$. Itens de vocabulário e morfologia possuem $a \in [1.2, 1.8]$.
- **$b_i \in [-2.5, +2.5]$ (Dificuldade)**: Ponto na escala $\theta$ onde a probabilidade de acerto é $(1 + c_i)/2$.
- **$c_i \in [0.20, 0.25]$ (Pseudo-chance / Chute)**: Probabilidade assintótica inferior de acerto casual em itens de 4 alternativas.
- **$D = 1.702$**: Fator de escalonamento para aproximação ótima à ogiva normal.

---

### 2.2 Seleção de Itens por Máxima Informação de Fisher
A Informação de Fisher $I_i(\theta)$ quantifica a precisão com que o item $i$ mensura a habilidade no ponto $\theta$:

$$I_i(\theta) = D^2 a_i^2 \cdot \frac{1 - P_i(\theta)}{P_i(\theta)} \cdot \left[ \frac{P_i(\theta) - c_i}{1 - c_i} \right]^2$$

A cada resposta fornecida pelo usuário:
1. Recalcula-se a estimativa pontual $\hat{\theta}$.
2. Seleciona-se, dentro do banco de itens não administrados daquela variante, o item que maximiza $I_i(\hat{\theta})$, ponderado pelo balanceamento de categorias (vocabulário, gramática e contexto histórico/cultural).

---

### 2.3 Estimação de Habilidade (Expected A Posteriori - EAP)
A habilidade latente é estimada via método Bayesiano EAP com quadratura de 41 nós no intervalo $[-4.0, +4.0]$:

$$\hat{\theta}_{EAP} = \frac{\int_{-\infty}^{\infty} \theta \cdot L(\mathbf{u}|\theta) \cdot f(\theta) \, d\theta}{\int_{-\infty}^{\infty} L(\mathbf{u}|\theta) \cdot f(\theta) \, d\theta}$$

O Erro Padrão da estimativa é derivado diretamente da variância a posteriori:

$$SE(\hat{\theta}) = \sqrt{\operatorname{Var}(\theta | \mathbf{u})}$$

---

### 2.4 Critério de Parada Adaptativo
Diferente da prova fixa de 10 perguntas, o teste adaptativo encerra dinamicamente quando:
1. **Convergência de Precisão:** $SE(\hat{\theta}) < 0.30$ após um mínimo de 5 itens administrados; **OU**
2. **Teto de Itens:** Atingimento do limite máximo de 15 itens.

---

## 3. Mapeamento Contínuo: Theta ($\theta$) $\to$ Capítulo de Entrada

O aplicativo mantém uma **trilha única** por variante. O nível obtido no teste de nivelamento posiciona o estudante diretamente no capítulo correspondente da trilha iniciante (Capítulos 1 a 20) ou o direciona para a fila de espera avançada:

| Faixa de $\theta$ | Capítulo de Entrada | Nível Pedagógico | Descrição e Foco Temático |
| :---: | :---: | :---: | :--- |
| $\theta < -2.00$ | **Capítulo 1** | Iniciante Absoluto (A1.1) | Saudações, cumprimentos e primeiras pessoas |
| $-2.00 \le \theta < -1.75$ | **Capítulo 2** | Iniciante (A1.1) | A Casa comunal e a família nuclear |
| $-1.75 \le \theta < -1.50$ | **Capítulo 3** | Iniciante (A1.1) | Animais da mata e fauna terrestre |
| $-1.50 \le \theta < -1.25$ | **Capítulo 4** | Iniciante (A1.2) | As águas, rios e navegação |
| $-1.25 \le \theta < -1.00$ | **Capítulo 5** | Iniciante (A1.2) | O roçado sagrado de mandioca e alimentos |
| $-1.00 \le \theta < -0.75$ | **Capítulo 6** | Iniciante (A1.2) | O sol, a lua e os astros celestes |
| $-0.75 \le \theta < -0.50$ | **Capítulo 7** | Iniciante (A1.2) | O fogo, cerâmica e instrumentos |
| $-0.50 \le \theta < -0.25$ | **Capítulo 8** | Iniciante Superior (A2.1) | As aves e plumas rituais |
| $-0.25 \le \theta < 0.00$ | **Capítulo 9** | Iniciante Superior (A2.1) | O corpo humano, sentidos e pintura |
| $0.00 \le \theta < +0.25$ | **Capítulo 10** | Iniciante Superior (A2.1) | A aldeia, praça e lideranças |
| $+0.25 \le \theta < +0.50$ | **Capítulo 11** | Iniciante Superior (A2.1) | As árvores e a floresta viva |
| $+0.50 \le \theta < +0.75$ | **Capítulo 12** | Iniciante Consolidado (A2.2) | Ações cotidianas e verbos do dia |
| $+0.75 \le \theta < +1.00$ | **Capítulo 13** | Iniciante Consolidado (A2.2) | A música, danças e maracá |
| $+1.00 \le \theta < +1.25$ | **Capítulo 14** | Iniciante Consolidado (A2.2) | Tupã e os espíritos guardiões |
| $+1.25 \le \theta < +1.50$ | **Capítulo 15** | Iniciante Consolidado (A2.2) | O pajé e a sabedoria da cura |
| $+1.50 \le \theta < +1.75$ | **Capítulo 16** | Transição Intermediário (B1.1) | A trilha do Peabiru e os caminhos |
| $+1.75 \le \theta < +2.00$ | **Capítulo 17** | Transição Intermediário (B1.1) | Povos vizinhos e escambo ritual |
| $+2.00 \le \theta < +2.25$ | **Capítulo 18** | Transição Intermediário (B1.1) | Narrativas de origem e mitos heroicos |
| $+2.25 \le \theta < +2.50$ | **Capítulo 19** | Transição Intermediário (B1.1) | Resistência histórica e defesa da terra |
| $+2.50 \le \theta < +2.75$ | **Capítulo 20** | Conclusão do Nível Iniciante | A memória viva de Pindorama |
| $\theta \ge +2.75$ | **Após Cap. 20** | Intermediário / Avançado | Direcionamento para fila de espera / conteúdo futuro |

---

## 4. Persistência de Dados e Recalibração Periódica

1. **Tabelas de Registro:** Todas as respostas dos testes são persistidas deterministicamente em `AnswerItem` e `TestAttempt` com os metadados:
   - `selected_letter`, `is_correct`, `time_taken_seconds`, `param_a`, `param_b`, `param_c`.
2. **Rotina de Recalibração de Itens:** Script em lote que re-estima periodicamente os parâmetros $b$ e $a$ de cada item do banco conforme o histórico empírico de milhares de usuários converge, garantindo calibração psicométrica contínua sem intervenção manual.
