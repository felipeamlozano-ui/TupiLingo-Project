import sys
sys.path.insert(0, ".")

from app.ai.ping_race import (
    get_redis_client,
    PingRaceRouter,
    REDIS_KEY_COOLDOWN_PREFIX,
    REDIS_KEY_FATAL_PREFIX,
    REDIS_KEY_METRICS_PREFIX
)

r = get_redis_client()
print("=" * 70)
print("TESTE DE CORREÇÃO DO CIRCUIT BREAKER DA SAMBANOVA")
print("=" * 70)

target = "sambanova/Meta-Llama-3.3-70B-Instruct"

# 1. Limpa resíduos anteriores do Redis para a SambaNova
if r:
    keys = list(r.keys("pingrace:*sambanova*"))
    if keys:
        r.delete(*keys)
        print(f"Chaves antigas limpas no Redis: {list(keys)}")
    else:
        print("Nenhuma chave antiga encontrada no Redis.")

# 2. Executa _ping_single_model
print(f"\nDisparando ping ao vivo contra: {target}...")
try:
    PingRaceRouter._ping_single_model(target)
    print("Sucesso inesperado")
except Exception as e:
    print(f"Falha capturada no ping: {type(e).__name__}: {str(e)[:120]}")

# 3. Verifica status no PingRaceRouter e Redis
is_fatal = PingRaceRouter.is_fatal_disabled(target)
is_cooldown = PingRaceRouter.is_in_cooldown(target)
metrics = PingRaceRouter.get_circuit_metrics().get(target, {})

print("\n--- STATUS APÓS PING ---")
print(f"is_fatal_disabled: {is_fatal}")
print(f"is_in_cooldown: {is_cooldown}")
print(f"Metrics: {metrics}")

if is_fatal and not is_cooldown:
    print("\n✓ SUCESSO: Erro 402 da SambaNova classificado com exatidão como FATAL (24h), sem cooldown transitório!")
else:
    print(f"\n✗ FALHA: Classificação incorreta: fatal={is_fatal}, cooldown={is_cooldown}")
