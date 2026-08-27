import math
import logging

logger = logging.getLogger(__name__)

def p_theta(theta: float, a: float, b: float, c: float) -> float:
    """Função 3PL da Teoria da Resposta ao Item (TRI)."""
    # Previne overflow no exp
    exponent = -a * (theta - b)
    if exponent > 50:
        return c
    if exponent < -50:
        return 1.0
    return c + (1 - c) / (1 + math.exp(exponent))

def evaluate_test(answers: list, current_level: int) -> dict:
    """
    Avalia o teste baseado na Teoria da Resposta ao Item.
    
    answers: lista de dicts com as seguintes chaves esperadas:
      - is_correct (bool)
      - time_taken_seconds (float)
      - param_a (float, default 1.2)
      - param_b (float, mapeado a partir do nível da questão)
      - param_c (float, default 0.25)
      - selected_letter (str)
    """
    if not answers:
        return {"level": current_level, "theta": 0.0, "cheating": False}
        
    total_time = sum(ans.get("time_taken_seconds", 0) for ans in answers)
    avg_time = total_time / len(answers)
    
    # 1. Heurística Anti-chute: Speedrun
    is_cheating = False
    if avg_time < 3.0:
        is_cheating = True
        logger.warning(f"Speedrun detectado. Média de tempo: {avg_time:.2f}s")
        
    # 2. Heurística Anti-chute: Padrões repetitivos
    selected_letters = [ans.get("selected_letter", "") for ans in answers if ans.get("selected_letter")]
    if len(selected_letters) >= 4:
        # Verifica se todas são a mesma letra
        if len(set(selected_letters)) == 1:
            is_cheating = True
            logger.warning(f"Padrão de chute detectado (mesma letra): {selected_letters}")
        # Verifica padrão A-B-A-B-A-B
        elif all(selected_letters[i] == selected_letters[i-2] for i in range(2, len(selected_letters))):
            is_cheating = True
            logger.warning(f"Padrão de chute alternado detectado: {selected_letters}")
            
    # 3. MLE Básico (Maximum Likelihood Estimation via Gradient Ascent)
    theta = 0.0 # inicial
    learning_rate = 0.5
    
    for _ in range(10): # Iterações do gradient ascent
        gradient = 0.0
        for ans in answers:
            a = float(ans.get("param_a", 1.2))
            b = float(ans.get("param_b", (current_level - 5) / 2.0)) # Normaliza nível 1-10 para -2 a +2.5
            c = float(ans.get("param_c", 0.25))
            u = 1 if ans.get("is_correct") else 0
            
            p = p_theta(theta, a, b, c)
            # Derivada da log-verossimilhança
            if 0 < p < 1:
                grad_item = a * (u - p) * (p - c) / (p * (1 - c))
                gradient += grad_item
                
        theta += learning_rate * gradient
        # Restringe theta entre -3.0 e +3.0
        theta = max(-3.0, min(3.0, theta))
        
    # Penalização máxima caso o sistema tenha detectado chute
    if is_cheating:
        theta = -3.0
        
    # 4. Converte theta (Traço Latente) de volta para Escala de Nível (1 a 10)
    # theta -3.0 -> 1
    # theta +3.0 -> 10
    new_level = int(round(((theta + 3.0) / 6.0) * 9 + 1))
    new_level = max(1, min(10, new_level))
    
    return {
        "level": new_level,
        "theta": theta,
        "cheating": is_cheating
    }
