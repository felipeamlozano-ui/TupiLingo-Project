"""
Comando Django para Simulação Sintética (Synthetic Bootstrapping) e Calibração MCMC/EM para TRI.
Role: Staff Machine Learning Engineer & Performance Architect.

Uso:
    python manage.py synthetic_bootstrapping --agents 5000 --iterations 20 --dry-run
"""

from __future__ import annotations

import logging

import numpy as np
from django.core.management.base import BaseCommand
from django.db import transaction
from trilha.models import Exercicio

from nivelamento.models import AnswerItem
from nivelamento.services.nlp_item_calibrator import NLPItemCalibrator
from nivelamento.services.tri_engine_vectorized import D_FACTOR, VectorizedTRIEngine

logger = logging.getLogger("nivelamento.bootstrapping")


class Command(BaseCommand):
    help = (
        "Gera milhares de agentes virtuais (Monte Carlo) para simular respostas e "
        "pré-calibrar as curvas de informação (ICC) dos itens via Expectation-Maximization."
    )

    def add_arguments(self, parser):
        parser.add_argument(
            "--agents",
            type=int,
            default=3000,
            help="Número de agentes sintéticos a simular (default: 3000)",
        )
        parser.add_argument(
            "--iterations",
            type=int,
            default=15,
            help="Iterações do algoritmo Expectation-Maximization (default: 15)",
        )
        parser.add_argument(
            "--dry-run",
            action="store_true",
            help="Executa a simulação e exibe métricas sem persistir no banco de dados.",
        )

    def handle(self, *args, **options):
        n_agents: int = options["agents"]
        n_iterations: int = options["iterations"]
        dry_run: bool = options["dry_run"]

        self.stdout.write(self.style.NOTICE(
            f"[TRI] Iniciando Synthetic Bootstrapping: {n_agents} agentes, {n_iterations} iteracoes EM..."
        ))

        # 1. Carregar itens do banco (Exercicio)
        exercicios = list(Exercicio.objects.select_related("licao").all().order_by("id"))
        if not exercicios:
            self.stdout.write(self.style.WARNING("Nenhum exercício encontrado na base de dados para calibrar."))
            return

        m_items = len(exercicios)
        self.stdout.write(f"[ITENS] Total de itens encontrados no banco: {m_items}")

        # 2. Inicialização Zero-Shot (NLP & Heurísticas)
        calibrator = NLPItemCalibrator()
        init_a = np.zeros(m_items, dtype=np.float64)
        init_b = np.zeros(m_items, dtype=np.float64)
        init_c = np.zeros(m_items, dtype=np.float64)

        for i, ex in enumerate(exercicios):
            opcoes = ex.opcoes or []
            resp_idx = ex.resposta_correta if ex.resposta_correta is not None else 0
            correta = str(opcoes[resp_idx]) if (0 <= resp_idx < len(opcoes)) else (ex.respostas_corretas or [""])[0]
            distratores = [str(opt) for idx, opt in enumerate(opcoes) if idx != resp_idx]

            # Parâmetros a frio via NLP
            b_val = calibrator.infer_difficulty_b(
                enunciado=ex.enunciado,
                resposta_correta=correta,
                categoria=getattr(ex, "categoria", "geral"),
            )
            c_val = calibrator.infer_guessing_c(
                resposta_correta=correta,
                distratores=distratores,
            )
            a_val = calibrator.infer_discrimination_a(
                enunciado=ex.enunciado,
                resposta_correta=correta,
                distratores=distratores,
            )

            init_a[i] = a_val
            init_b[i] = b_val
            init_c[i] = c_val

        self.stdout.write(self.style.SUCCESS(
            f"[NLP] Parametros Zero-Shot inicializados com sucesso! (b_medio={init_b.mean():.2f}, c_medio={init_c.mean():.2f})"
        ))

        # 3. Geração de Agentes Virtuais: theta ~ N(0, 1)
        np.random.seed(42)  # Reprodutibilidade
        theta_agents = np.random.normal(loc=0.0, scale=1.0, size=n_agents)

        # 4. Monte Carlo Simulation: Geração da Matriz de Respostas Sintéticas U in {0, 1}^(N x M)
        # Probabilidade 3PL para cada par (agente j, item i)
        # Broadcasting: theta_agents[:, None] (N, 1) vs init_b[None, :] (1, M)
        linear = -D_FACTOR * init_a[None, :] * (theta_agents[:, None] - init_b[None, :])
        linear = np.clip(linear, -35.0, 35.0)
        p_matrix = init_c[None, :] + (1.0 - init_c[None, :]) / (1.0 + np.exp(linear))

        # Sorteio de Bernoulli
        uniform_random = np.random.uniform(0.0, 1.0, size=(n_agents, m_items))
        response_matrix = (uniform_random < p_matrix).astype(np.int32)

        taxa_acerto_media = float(response_matrix.mean())
        self.stdout.write(f"[SIMULACAO] Simulacao Monte Carlo concluida: taxa global de acerto = {taxa_acerto_media*100:.1f}%")

        # 5. Algoritmo de Calibração EM (Expectation-Maximization)
        # E-step: Estima a proficiência latente de cada agente dado os parâmetros atuais dos itens
        # M-step: Ajusta os parâmetros dos itens (a, b) maximizando a verossimilhança marginal
        calib_a = np.copy(init_a)
        calib_b = np.copy(init_b)
        calib_c = np.copy(init_c)
        tri_engine = VectorizedTRIEngine()

        self.stdout.write("[EM] Executando iteracoes EM...")
        for it in range(1, n_iterations + 1):
            # E-step: Estimação de thetas com Newton-Raphson
            estimated_thetas = np.zeros(n_agents, dtype=np.float64)
            for j in range(n_agents):
                res = tri_engine.estimate_theta_map(
                    responses=response_matrix[j, :],
                    params_a=calib_a,
                    params_b=calib_b,
                    params_c=calib_c,
                    initial_theta=theta_agents[j],
                )
                estimated_thetas[j] = res.theta

            # M-step: Gradiente estocástico com regularização bayesiana para cada item
            for i in range(m_items):
                u_col = response_matrix[:, i]
                p_col = tri_engine.p_3pl(estimated_thetas, calib_a[i], calib_b[i], calib_c[i])
                p_safe = np.clip(p_col, 1e-6, 1.0 - 1e-6)
                c_val = calib_c[i]

                # Gradiente para b (dificuldade)
                # dL/db = - sum [ D * a * (P - c)/(1 - c) * (u - P)/P ]
                weight_b = (D_FACTOR * calib_a[i] * (p_safe - c_val)) / (1.0 - c_val)
                grad_b = -np.sum(weight_b * ((u_col - p_safe) / p_safe)) / n_agents
                # Regularizador L2 em direção à prior Zero-Shot
                grad_b += 0.05 * (calib_b[i] - init_b[i])

                # Gradiente para a (discriminação)
                weight_a = (D_FACTOR * (estimated_thetas - calib_b[i]) * (p_safe - c_val)) / (1.0 - c_val)
                grad_a = np.sum(weight_a * ((u_col - p_safe) / p_safe)) / n_agents
                grad_a -= 0.05 * (calib_a[i] - init_a[i])

                # Atualização com taxa de aprendizado adaptativa
                lr = 0.2 / (1.0 + 0.1 * it)
                calib_b[i] = float(np.clip(calib_b[i] - lr * grad_b, -3.0, 3.0))
                calib_a[i] = float(np.clip(calib_a[i] + lr * grad_a, 0.6, 2.5))

            if it % 5 == 0 or it == n_iterations:
                self.stdout.write(f"   [Iteracao {it}/{n_iterations}] Parametros ajustados. Delta_b={abs(calib_b - init_b).mean():.3f}")

        # 6. Exibir Resultados e Persistir
        self.stdout.write(self.style.SUCCESS("[OK] Calibracao sintetica finalizada!"))
        self.stdout.write("---------------------------------------------------------")
        self.stdout.write(f"Item 1: b_inicial={init_b[0]:.2f} -> b_calibrado={calib_b[0]:.2f} | a={calib_a[0]:.2f} | c={calib_c[0]:.2f}")
        if m_items > 1:
            self.stdout.write(f"Item {m_items}: b_inicial={init_b[-1]:.2f} -> b_calibrado={calib_b[-1]:.2f} | a={calib_a[-1]:.2f} | c={calib_c[-1]:.2f}")
        self.stdout.write("---------------------------------------------------------")

        if dry_run:
            self.stdout.write(self.style.WARNING("Modo --dry-run ativado. Nenhuma alteração foi salva no banco."))
            return

        # 7. Persistência transacional via Django ORM
        with transaction.atomic():
            for i, ex in enumerate(exercicios):
                # Se existir suporte para param_a, param_b, param_c no Exercicio ou AnswerItem
                # Salva os parâmetros refinados
                ex.pontos_base = int(round(10 + max(0.0, calib_b[i] + 1.5) * 5))
                ex.save(update_fields=["pontos_base"])

                # Atualiza amostras correspondentes em AnswerItem se houver
                AnswerItem.objects.filter(question_text=ex.enunciado).update(
                    param_a=float(np.round(calib_a[i], 3)),
                    param_b=float(np.round(calib_b[i], 3)),
                    param_c=float(np.round(calib_c[i], 3)),
                )

        self.stdout.write(self.style.SUCCESS(
            f"[SUCESSO] {m_items} itens pre-calibrados e sincronizados no banco de dados Supabase/Postgres!"
        ))
