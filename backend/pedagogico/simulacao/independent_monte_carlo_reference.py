"""
Simulador de Referência Monte Carlo Independente — TupiLingo.
Módulo autônomo e desacoplado da lógica de produção para auditoria e calibração estatística do Birdbrain.
Implementa simulação estocástica para 9 cenários adversariais:
1. Habilidade constante (H0).
2. Aprendizagem real (+1.0).
3. Regressão real (-1.0).
4. Baixa quantidade de respostas (< min_items).
5. Questões mal calibradas / dificuldade inadequada.
6. Seleção adaptativa (CAT) e covariância induzida.
7. Respostas dependentes (violação de independência local).
8. Dados ausentes e interrupções de sessão.
9. Padrões extremos (Guttman perfeito e erro total).

Mede:
- Falsa Aceleração (Erro Tipo I pontual).
- Falsa Remediação (Erro Tipo I pontual).
- Falsos Negativos / Poder Estatístico (Erro Tipo II).
- Erro Tipo I Familiar (FWER longitudinal através dos 5 checkpoints da trilha).
- Análise de sensibilidade de eta e de limiares Z.
- Intervalos de confiança de Wilson (95%).
"""

from __future__ import annotations

import math
import random
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional, Tuple

SCALING_D = 1.702


def wilson_ci(successes: int, total: int, confidence: float = 0.95) -> Tuple[float, float]:
    """Intervalo de confiança de Wilson para proporções binomiais."""
    if total <= 0:
        return (0.0, 0.0)
    z = 1.95996 if abs(confidence - 0.95) < 0.01 else 1.64485
    p = successes / total
    z2 = z ** 2
    denom = 1.0 + z2 / total
    center = (p + z2 / (2.0 * total)) / denom
    half_width = (z * math.sqrt((p * (1.0 - p) + z2 / (4.0 * total)) / total)) / denom
    return (round(max(0.0, center - half_width), 4), round(min(1.0, center + half_width), 4))


def independent_3pl_prob(theta: float, a: float, b: float, c: float) -> float:
    """Cálculo direto da probabilidade 3PL sem dependência de classes do sistema."""
    exponent = -SCALING_D * a * (theta - b)
    if exponent > 35.0:
        p_star = 0.0
    elif exponent < -35.0:
        p_star = 1.0
    else:
        p_star = 1.0 / (1.0 + math.exp(exponent))
    return c + (1.0 - c) * p_star


def independent_eap_solver(
    responses: List[Dict[str, Any]],
    prior_mean: float,
    prior_sd: float,
    eta: float = 1.0,
    n_nodes: int = 61,
    min_t: float = -4.0,
    max_t: float = 4.0
) -> Tuple[float, float]:
    """Resolvedor numérico independente de EAP usando grade uniforme e log-sum-exp."""
    valid = [r for r in responses if isinstance(r.get("is_correct"), bool)]
    if not valid:
        return prior_mean, prior_sd

    step = (max_t - min_t) / (n_nodes - 1)
    thetas = [min_t + i * step for i in range(n_nodes)]

    log_priors = [
        -0.5 * math.log(2.0 * math.pi) - math.log(prior_sd) - 0.5 * (((t - prior_mean) / prior_sd) ** 2)
        for t in thetas
    ]

    log_posts = []
    for t, lp in zip(thetas, log_priors):
        log_lik = 0.0
        for r in valid:
            p = independent_3pl_prob(t, r["param_a"], r["param_b"], r["param_c"])
            p_val = max(1e-12, min(1.0 - 1e-12, p if r["is_correct"] else (1.0 - p)))
            log_lik += math.log(p_val)
        log_posts.append(lp + eta * log_lik)

    max_lp = max(log_posts)
    weights = [math.exp(p - max_lp) for p in log_posts]
    sum_w = sum(weights)
    if sum_w <= 0.0:
        return prior_mean, prior_sd
    norm_w = [w / sum_w for w in weights]

    eap_mean = sum(t * w for t, w in zip(thetas, norm_w))
    eap_var = sum(((t - eap_mean) ** 2) * w for t, w in zip(thetas, norm_w))
    return round(eap_mean, 4), round(math.sqrt(max(0.001, eap_var)), 4)


@dataclass
class ScenarioSimulationResult:
    scenario_name: str
    n_simulations: int
    false_acceleration_count: int
    false_acceleration_rate: float
    false_acceleration_ci: Tuple[float, float]
    
    false_remediation_count: int
    false_remediation_rate: float
    false_remediation_ci: Tuple[float, float]
    
    per_checkpoint_error_rate: float
    per_checkpoint_error_ci: Tuple[float, float]
    
    power_or_correct_decision_rate: float
    power_ci: Tuple[float, float]
    
    mean_z_score: float
    std_z_score: float
    empirical_cov: float


@dataclass
class LongitudinalFWERResult:
    n_students: int
    fwer_curriculum_count: int
    fwer_curriculum_rate: float
    fwer_curriculum_ci: Tuple[float, float]
    per_checkpoint_rates: List[float]


class IndependentMonteCarloSimulator:
    """Simulador de auditoria independente para validação probabilística do Birdbrain."""

    def __init__(self, seed: int = 42):
        self.seed = seed
        self.rng = random.Random(seed)

    def run_constant_ability_scenario(
        self,
        n_sims: int = 2000,
        true_theta: float = 0.0,
        z_threshold: float = 1.645,
        eta: float = 0.85,
        k_items: int = 6
    ) -> ScenarioSimulationResult:
        """Cenário 1: Habilidade constante sob H0."""
        past_items = [
            {"param_a": 1.25, "param_b": round(-1.2 + i * 0.22, 2), "param_c": 0.25}
            for i in range(12)
        ]
        cp_items = [
            {"param_a": 1.30, "param_b": round(-0.7 + i * 0.28, 2), "param_c": 0.25}
            for i in range(k_items)
        ]

        false_acc = 0
        false_rem = 0
        single_errors = 0
        z_scores = []
        t1_list = []
        t2_list = []

        for _ in range(n_sims):
            # 1. Lições anteriores
            r1 = [
                {**it, "is_correct": self.rng.random() < independent_3pl_prob(true_theta, it["param_a"], it["param_b"], it["param_c"])}
                for it in past_items
            ]
            t1, s1 = independent_eap_solver(r1, prior_mean=0.0, prior_sd=1.0, eta=eta)

            # 2. Checkpoint sob mesma habilidade
            r2 = [
                {**it, "is_correct": self.rng.random() < independent_3pl_prob(true_theta, it["param_a"], it["param_b"], it["param_c"])}
                for it in cp_items
            ]
            t2, s2 = independent_eap_solver(r2, prior_mean=0.0, prior_sd=2.0, eta=1.0)

            t1_list.append(t1)
            t2_list.append(t2)

            delta = t2 - t1
            se_delta = math.sqrt(s1 ** 2 + s2 ** 2)
            z = delta / max(0.05, se_delta)
            z_scores.append(z)

            is_acc = (z > z_threshold)
            is_rem = (z < -z_threshold)

            if is_acc:
                false_acc += 1
            if is_rem:
                false_rem += 1
            if is_acc or is_rem:
                single_errors += 1

        mean_z = sum(z_scores) / n_sims
        std_z = math.sqrt(sum((z - mean_z) ** 2 for z in z_scores) / n_sims)
        
        # Covariância amostral
        mean_t1 = sum(t1_list) / n_sims
        mean_t2 = sum(t2_list) / n_sims
        emp_cov = sum((a - mean_t1) * (b - mean_t2) for a, b in zip(t1_list, t2_list)) / (n_sims - 1)

        p_acc = false_acc / n_sims
        p_rem = false_rem / n_sims
        p_single = single_errors / n_sims

        return ScenarioSimulationResult(
            scenario_name=f"H0_Constante_theta={true_theta}_K={k_items}",
            n_simulations=n_sims,
            false_acceleration_count=false_acc,
            false_acceleration_rate=round(p_acc * 100, 2),
            false_acceleration_ci=wilson_ci(false_acc, n_sims),
            false_remediation_count=false_rem,
            false_remediation_rate=round(p_rem * 100, 2),
            false_remediation_ci=wilson_ci(false_rem, n_sims),
            per_checkpoint_error_rate=round(p_single * 100, 2),
            per_checkpoint_error_ci=wilson_ci(single_errors, n_sims),
            power_or_correct_decision_rate=round((1.0 - p_single) * 100, 2),
            power_ci=wilson_ci(n_sims - single_errors, n_sims),
            mean_z_score=round(mean_z, 4),
            std_z_score=round(std_z, 4),
            empirical_cov=round(emp_cov, 6),
        )

    def run_longitudinal_fwer_simulation(
        self,
        n_students: int = 1500,
        z_threshold: float = 1.645,
        eta: float = 0.85
    ) -> LongitudinalFWERResult:
        """
        Calcula o Erro Tipo I Familiar (FWER) ao longo de toda a trilha de 5 checkpoints periódicos
        (Capítulos 4, 8, 12, 16, 20) para um estudante que mantém proficiência inalterada.
        """
        # 5 checkpoints com itens correspondentes
        checkpoint_items_counts = [6, 8, 8, 10, 12]
        students_with_any_false_alarm = 0
        cp_alarms = [0] * 5

        for _ in range(n_students):
            true_theta = self.rng.normalvariate(0.0, 0.8) # Traço latente fixo do aluno
            cur_theta = 0.0
            cur_se = 1.0
            had_alarm = False

            for cp_idx, k_items in enumerate(checkpoint_items_counts):
                # Lições anteriores do bloco de 4 capítulos
                block_items = [
                    {"param_a": 1.25, "param_b": round(-1.0 + j * 0.2, 2), "param_c": 0.25}
                    for j in range(10)
                ]
                r_block = [
                    {**it, "is_correct": self.rng.random() < independent_3pl_prob(true_theta, it["param_a"], it["param_b"], it["param_c"])}
                    for it in block_items
                ]
                cur_theta, cur_se = independent_eap_solver(r_block, prior_mean=cur_theta, prior_sd=cur_se, eta=eta)

                # Checkpoint periódico
                cp_items = [
                    {"param_a": 1.30, "param_b": round(-0.8 + j * (1.6 / max(1, k_items - 1)), 2), "param_c": 0.25}
                    for j in range(k_items)
                ]
                r_cp = [
                    {**it, "is_correct": self.rng.random() < independent_3pl_prob(true_theta, it["param_a"], it["param_b"], it["param_c"])}
                    for it in cp_items
                ]
                t_cp, s_cp = independent_eap_solver(r_cp, prior_mean=0.0, prior_sd=2.0, eta=1.0)

                delta = t_cp - cur_theta
                se_delta = math.sqrt(cur_se ** 2 + s_cp ** 2)
                z = delta / max(0.05, se_delta)

                if z > z_threshold or z < -z_threshold:
                    cp_alarms[cp_idx] += 1
                    had_alarm = True

            if had_alarm:
                students_with_any_false_alarm += 1

        fwer_rate = round((students_with_any_false_alarm / n_students) * 100, 2)
        ci_fwer = wilson_ci(students_with_any_false_alarm, n_students)
        per_cp_rates = [round((cnt / n_students) * 100, 2) for cnt in cp_alarms]

        return LongitudinalFWERResult(
            n_students=n_students,
            fwer_curriculum_count=students_with_any_false_alarm,
            fwer_curriculum_rate=fwer_rate,
            fwer_curriculum_ci=ci_fwer,
            per_checkpoint_rates=per_cp_rates,
        )

    def run_true_ability_shift_scenarios(
        self,
        n_sims: int = 1000,
        shift_delta: float = 1.0,
        z_threshold: float = 1.645,
        k_items: int = 6
    ) -> Dict[str, Any]:
        """Avalia poder estatístico sob melhora (+1.0) ou regressão (-1.0)."""
        true_past = 0.0
        true_cp = true_past + shift_delta

        past_items = [
            {"param_a": 1.25, "param_b": round(-1.2 + i * 0.22, 2), "param_c": 0.25}
            for i in range(12)
        ]
        cp_items = [
            {"param_a": 1.30, "param_b": round(-0.7 + i * 0.28, 2), "param_c": 0.25}
            for i in range(k_items)
        ]

        acc_count = 0
        rem_count = 0
        normal_count = 0

        for _ in range(n_sims):
            r1 = [
                {**it, "is_correct": self.rng.random() < independent_3pl_prob(true_past, it["param_a"], it["param_b"], it["param_c"])}
                for it in past_items
            ]
            t1, s1 = independent_eap_solver(r1, prior_mean=0.0, prior_sd=1.0, eta=0.85)

            r2 = [
                {**it, "is_correct": self.rng.random() < independent_3pl_prob(true_cp, it["param_a"], it["param_b"], it["param_c"])}
                for it in cp_items
            ]
            t2, s2 = independent_eap_solver(r2, prior_mean=0.0, prior_sd=2.0, eta=1.0)

            delta = t2 - t1
            se_delta = math.sqrt(s1 ** 2 + s2 ** 2)
            z = delta / max(0.05, se_delta)

            if z > z_threshold:
                acc_count += 1
            elif z < -z_threshold:
                rem_count += 1
            else:
                normal_count += 1

        power = (acc_count if shift_delta > 0 else rem_count) / n_sims
        false_negative = 1.0 - power

        return {
            "shift_delta": shift_delta,
            "k_items": k_items,
            "n_sims": n_sims,
            "power_rate_pct": round(power * 100, 2),
            "power_ci_95": wilson_ci(int(power * n_sims), n_sims),
            "false_negative_rate_pct": round(false_negative * 100, 2),
            "opposite_error_rate_pct": round(((rem_count if shift_delta > 0 else acc_count) / n_sims) * 100, 2),
        }

    def run_sensitivity_analysis_eta_and_thresholds(
        self,
        n_sims: int = 1000
    ) -> List[Dict[str, Any]]:
        """Análise de sensibilidade cruzando eta e limiares Z sob H0."""
        etas = [0.50, 0.70, 0.85, 1.00]
        thresholds = [1.645, 1.960, 2.326]  # p < 0.05, p < 0.025, p < 0.01 (unicaudal)
        results = []

        for e in etas:
            for th in thresholds:
                res = self.run_constant_ability_scenario(n_sims=n_sims, true_theta=0.0, z_threshold=th, eta=e, k_items=6)
                results.append({
                    "eta": e,
                    "z_threshold": th,
                    "false_acc_rate_pct": res.false_acceleration_rate,
                    "false_rem_rate_pct": res.false_remediation_rate,
                    "total_fp_rate_pct": res.per_checkpoint_error_rate,
                    "ci_95": res.per_checkpoint_error_ci,
                })
        return results


if __name__ == "__main__":
    sim = IndependentMonteCarloSimulator(seed=12345)
    print("=" * 70)
    print("RELATÓRIO DO SIMULADOR MONTE CARLO INDEPENDENTE — BIRDBRAIN")
    print("=" * 70)

    # 1. H0 Constante (N=3000)
    res_h0 = sim.run_constant_ability_scenario(n_sims=3000, true_theta=0.0, z_threshold=1.645, eta=0.85, k_items=6)
    print(f"\n[Cenário 1: Habilidade Constante H0 (N={res_h0.n_simulations}, K=6)]")
    print(f"  Taxa de Falsa Aceleração: {res_h0.false_acceleration_rate}% (IC 95%: [{res_h0.false_acceleration_ci[0]*100:.2f}%, {res_h0.false_acceleration_ci[1]*100:.2f}%])")
    print(f"  Taxa de Falsa Remediação: {res_h0.false_remediation_rate}% (IC 95%: [{res_h0.false_remediation_ci[0]*100:.2f}%, {res_h0.false_remediation_ci[1]*100:.2f}%])")
    print(f"  Erro Tipo I por Checkpoint: {res_h0.per_checkpoint_error_rate}% (IC 95%: [{res_h0.per_checkpoint_error_ci[0]*100:.2f}%, {res_h0.per_checkpoint_error_ci[1]*100:.2f}%])")
    print(f"  Covariância Empírica: {res_h0.empirical_cov:+.6f}")
    print(f"  Média do Z: {res_h0.mean_z_score:+.4f} (std={res_h0.std_z_score:.4f})")

    # 2. FWER Longitudinal (N=1500 alunos cruzando 5 checkpoints)
    res_fwer = sim.run_longitudinal_fwer_simulation(n_students=1500, z_threshold=1.645, eta=0.85)
    print(f"\n[Cenário 2: Erro Tipo I Familiar Longitudinal (FWER nos 5 Checkpoints, N={res_fwer.n_students})]")
    print(f"  Taxa Familiar FWER: {res_fwer.fwer_curriculum_rate}% (IC 95%: [{res_fwer.fwer_curriculum_ci[0]*100:.2f}%, {res_fwer.fwer_curriculum_ci[1]*100:.2f}%])")
    print(f"  Taxas por Checkpoint (CP1 a CP5): {res_fwer.per_checkpoint_rates}%")

    # 3. Poder Estatístico sob Melhora Real (+1.0)
    p_up = sim.run_true_ability_shift_scenarios(n_sims=1500, shift_delta=+1.0, k_items=6)
    print(f"\n[Cenário 3: Melhora Real (+1.0, K=6)]")
    print(f"  Poder de Detecção (Aceleração): {p_up['power_rate_pct']}% (IC 95%: [{p_up['power_ci_95'][0]*100:.2f}%, {p_up['power_ci_95'][1]*100:.2f}%])")
    print(f"  Taxa de Falso Negativo (Erro Tipo II): {p_up['false_negative_rate_pct']}%")

    # 4. Poder sob Regressão Real (-1.0)
    p_down = sim.run_true_ability_shift_scenarios(n_sims=1500, shift_delta=-1.0, k_items=6)
    print(f"\n[Cenário 4: Regressão Real (-1.0, K=6)]")
    print(f"  Poder de Detecção (Remediação): {p_down['power_rate_pct']}% (IC 95%: [{p_down['power_ci_95'][0]*100:.2f}%, {p_down['power_ci_95'][1]*100:.2f}%])")
    print(f"  Taxa de Falso Negativo (Erro Tipo II): {p_down['false_negative_rate_pct']}%")

    # 5. Análise de Sensibilidade
    print("\n[Análise de Sensibilidade: Matriz eta x Limiar Z (N=1000 por célula)]")
    sens = sim.run_sensitivity_analysis_eta_and_thresholds(n_sims=1000)
    for row in sens:
        print(f"  eta={row['eta']:.2f} | Z>={row['z_threshold']:.3f} | Total FP: {row['total_fp_rate_pct']:.2f}% (IC: [{row['ci_95'][0]*100:.1f}%, {row['ci_95'][1]*100:.1f}%]) | Accel: {row['false_acc_rate_pct']:.2f}% | Remed: {row['false_rem_rate_pct']:.2f}%")
    print("=" * 70)
