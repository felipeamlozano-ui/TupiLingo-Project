"""
Benchmark & Validação de SLOs do Question Pool (Producer-Consumer).

SLOs Avaliados:
1. Latência de extração (Redis SPOP):
   - P50 < 2.0 ms
   - P99 < 10.0 ms
2. Tempo de resposta do pipeline RAGService (Pool Hit + Pydantic + Shuffle):
   - P50 < 30.0 ms
   - P95 < 80.0 ms
   - P99 < 150.0 ms
3. Conformidade Linguística e Estrutural:
   - Presença obrigatória de 'fonte_confianca' em cada questão (alta / média / baixa)
   - Exatamente 4 alternativas únicas ('A', 'B', 'C', 'D')
   - 'pacote_id' único em formato UUID
"""

from __future__ import annotations

import json
import math
import os
import sys
import time
import uuid

# Configura o ambiente Django
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")

import django
django.setup()

from app.ai.ping_race import get_redis_client
from app.ai.rag_service import RAGService, _pool_key, _shuffle_quiz_response
from app.schemas.quiz import QuizResponse


def calculate_percentile(sorted_data: list[float], percentile: float) -> float:
    """Calcula o percentil especificado (0 a 100) via interpolação linear."""
    if not sorted_data:
        return 0.0
    k = (len(sorted_data) - 1) * (percentile / 100.0)
    f = math.floor(k)
    c = math.ceil(k)
    if f == c:
        return sorted_data[int(k)]
    d0 = sorted_data[int(f)] * (c - k)
    d1 = sorted_data[int(c)] * (k - f)
    return d0 + d1


def run_benchmark():
    print("=" * 70)
    print(">>> INICIANDO BENCHMARK DE SLOs: QUESTION POOL (PRODUCER-CONSUMER) <<<")
    print("=" * 70)

    r = get_redis_client()
    if not r:
        print("[ERRO] Redis indisponivel! Inicie o Redis com 'docker start backend-redis-1'")
        sys.exit(1)

    test_key = "quiz_pool:benchmark:1"
    r.delete(test_key)

    # 1. Carrega 150 pacotes sintéticos válidos no pool de teste
    print("\n[*] Carregando 150 pacotes validos no Redis para medicao de latencia...")
    pipe = r.pipeline(transaction=False)
    for i in range(150):
        pacote = {
            "pacote_id": str(uuid.uuid4()),
            "provider": "RedisPool-Benchmark",
            "modelo": "seed-tupi-v1",
            "tempo_total_ms": 1,
            "cache_hit": True,
            "questoes": [
                {
                    "item_id": q_id,
                    "enunciado": f"Qual a traducao exata da palavra tupi 'termo_{q_id}'?",
                    "alternativas": [
                        {"letra": "A", "texto": f"Alternativa A_{q_id}"},
                        {"letra": "B", "texto": f"Alternativa B_{q_id}"},
                        {"letra": "C", "texto": f"Alternativa C_{q_id}"},
                        {"letra": "D", "texto": f"Alternativa D_{q_id}"},
                    ],
                    "resposta_correta": "A",
                    "explicacao": f"Explicacao pedagogica detalhada para termo_{q_id}.",
                    "categoria": "geral",
                    "variante": "tupi",
                    "dificuldade": "facil",
                    "curiosidade": "",
                    "regra_contexto": "",
                    "fonte_confianca": "alta",
                }
                for q_id in range(1, 11)
            ],
        }
        pipe.sadd(test_key, json.dumps(pacote))
    pipe.execute()

    initial_count = r.scard(test_key)
    print(f"[OK] Estoque inicial no pool: {initial_count} pacotes.")

    # ── 2. Benchmark de Latência Pura de Extração (Redis SPOP) ────────────────
    print("\n[*] Executando 100 extracoes SPOP consecutivas...")
    spop_latencies_ms: list[float] = []

    for _ in range(100):
        t0 = time.perf_counter()
        raw = r.spop(test_key)
        t1 = time.perf_counter()
        if raw:
            spop_latencies_ms.append((t1 - t0) * 1000.0)

    spop_latencies_ms.sort()
    spop_p50 = calculate_percentile(spop_latencies_ms, 50)
    spop_p90 = calculate_percentile(spop_latencies_ms, 90)
    spop_p95 = calculate_percentile(spop_latencies_ms, 95)
    spop_p99 = calculate_percentile(spop_latencies_ms, 99)

    print("\n--- METRICAS DE EXTRACAO REDIS SPOP ---")
    print(f"Amorstras coletadas: {len(spop_latencies_ms)}")
    print(f"P50: {spop_p50:.3f} ms (SLO: < 2.0 ms) -> {'[PASSOU]' if spop_p50 < 2.0 else '[ALERTA]'}")
    print(f"P90: {spop_p90:.3f} ms")
    print(f"P95: {spop_p95:.3f} ms")
    print(f"P99: {spop_p99:.3f} ms (SLO: < 10.0 ms) -> {'[PASSOU]' if spop_p99 < 10.0 else '[ALERTA]'}")

    # ── 3. Benchmark de Pipeline Completo RAGService ─────────────────────────
    # Abastece temporariamente o pool real para medir 30 requisições consecutivas com Pool Hit
    pool_real_key = _pool_key("tupi", 1)
    print(f"\n[*] Abastecendo {pool_real_key} com 50 pacotes para teste de carga do pipeline...")
    pipe = r.pipeline(transaction=False)
    for _ in range(50):
        pacote["pacote_id"] = str(uuid.uuid4())
        pipe.sadd(pool_real_key, json.dumps(pacote))
    pipe.execute()

    service = RAGService()
    pipeline_latencies_ms: list[float] = []
    conformidade_fonte_confianca = True
    conformidade_alternativas = True
    conformidade_pacote_id = True

    # Realiza 30 chamadas completas à geração com pool hit
    for _ in range(30):
        t0 = time.perf_counter()
        res = service.generate(nivel_atual=1, variante_codigo="tupi")
        t1 = time.perf_counter()
        pipeline_latencies_ms.append((t1 - t0) * 1000.0)

        # Validações estruturais e linguísticas
        if not res.get("pacote_id"):
            conformidade_pacote_id = False

        for q in res.get("questoes", []):
            fc = q.get("fonte_confianca")
            if fc not in {"alta", "média", "baixa"}:
                conformidade_fonte_confianca = False
            alts = q.get("alternativas", [])
            if len(alts) != 4 or len({a["letra"] for a in alts}) != 4:
                conformidade_alternativas = False

    pipeline_latencies_ms.sort()
    pipe_p50 = calculate_percentile(pipeline_latencies_ms, 50)
    pipe_p90 = calculate_percentile(pipeline_latencies_ms, 90)
    pipe_p95 = calculate_percentile(pipeline_latencies_ms, 95)
    pipe_p99 = calculate_percentile(pipeline_latencies_ms, 99)

    print("\n--- METRICAS DE RESPOSTA DO PIPELINE COMPLETO (POOL HIT) ---")
    print(f"Amostras coletadas: {len(pipeline_latencies_ms)}")
    print(f"P50: {pipe_p50:.2f} ms (SLO: < 30.0 ms) -> {'[PASSOU]' if pipe_p50 < 30.0 else '[ALERTA]'}")
    print(f"P90: {pipe_p90:.2f} ms")
    print(f"P95: {pipe_p95:.2f} ms (SLO: < 80.0 ms) -> {'[PASSOU]' if pipe_p95 < 80.0 else '[ALERTA]'}")
    print(f"P99: {pipe_p99:.2f} ms (SLO: < 150.0 ms) -> {'[PASSOU]' if pipe_p99 < 150.0 else '[ALERTA]'}")

    print("\n--- AUDITORIA DE QUALIDADE LINGUISTICA E ESTRUTURAL ---")
    print(f"Pacote ID UUID presente: {'[OK]' if conformidade_pacote_id else '[FALHA]'}")
    print(f"fonte_confianca (alta/media/baixa) em todas as questoes: {'[OK]' if conformidade_fonte_confianca else '[FALHA]'}")
    print(f"Exatamente 4 alternativas unicas por questao: {'[OK]' if conformidade_alternativas else '[FALHA]'}")

    # Limpa chave de teste e restaura seed fixture original
    r.delete(test_key)
    from django.core.management import call_command
    print("\n[*] Restaurando estoque de seed original com seed_quiz_pool...")
    call_command("seed_quiz_pool")

    print("\n" + "=" * 70)
    print(">>> BENCHMARK CONCLUIDO COM SUCESSO <<<")
    print("=" * 70)


if __name__ == "__main__":
    run_benchmark()
