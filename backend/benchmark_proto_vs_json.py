"""
Benchmark Real: Protocol Buffers vs. JSON (TupiLingo)
Avalia:
1. Tamanho em bytes na rede (Payload size)
2. Tempo de Serialização (Encoding latency)
3. Tempo de Deserialização (Decoding latency)
4. Throughput (operações por segundo)
"""
import sys
import time
import json
import statistics
from pathlib import Path

# Adiciona o backend ao path para carregar o stub gerado
BACKEND_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(BACKEND_DIR))

from proto_gen import tupilingo_pb2


def create_sample_user():
    # Representação em Objeto Python / Dict
    user_dict = {
        "supabase_uid": "e7b36f1c-4b9a-4c2d-98e1-5832a819b4e7",
        "email": "curumim.potiguara@tupilingo.org",
        "name": "Kuarahy Potiguara",
        "xp_total": 4850,
        "streak_dias": 42,
        "nivel_atual": 6,
        "conchas": 320,
        "variante_ativa_codigo": "tupi_antigo",
        "variante_ativa_nome": "Tupi Antigo (Século XVI)",
        "ofensiva_ativa": True,
    }

    # Mensagem Protobuf equivalente
    user_pb = tupilingo_pb2.UserProfileMessage(
        supabase_uid=user_dict["supabase_uid"],
        email=user_dict["email"],
        name=user_dict["name"],
        xp_total=user_dict["xp_total"],
        streak_dias=user_dict["streak_dias"],
        nivel_atual=user_dict["nivel_atual"],
        conchas=user_dict["conchas"],
        variante_ativa_codigo=user_dict["variante_ativa_codigo"],
        variante_ativa_nome=user_dict["variante_ativa_nome"],
        ofensiva_ativa=user_dict["ofensiva_ativa"],
    )
    return user_dict, user_pb


def create_sample_quiz_block():
    # 10 questões realistas no formato do TupiLingo
    questoes_dict = []
    questoes_pb = []

    for i in range(1, 11):
        q_dict = {
            "item_id": i,
            "termo_tupi": f"Kûarasy_{i}",
            "traducao_correta": "Sol / Astro do dia",
            "distratores": ["Lua / Jaci", "Água / Y", "Fogo / Tatá"],
            "regra_contexto": "Substantivo referente a corpos celestes na mitologia Tupi.",
            "enunciado": f"Qual é a tradução correta da palavra 'Kûarasy_{i}' em Tupi Antigo?",
            "explicacao": f"'Kûarasy_{i}' designa o sol na cosmologia e vida cotidiana indígena.",
            "curiosidade": "Na cosmovisão Tupi, Guaraci é a divindade solar primordial.",
        }
        questoes_dict.append(q_dict)

        q_pb = tupilingo_pb2.QuizItemMessage(
            item_id=q_dict["item_id"],
            termo_tupi=q_dict["termo_tupi"],
            traducao_correta=q_dict["traducao_correta"],
            distratores=q_dict["distratores"],
            regra_contexto=q_dict["regra_contexto"],
            enunciado=q_dict["enunciado"],
            explicacao=q_dict["explicacao"],
            curiosidade=q_dict["curiosidade"],
        )
        questoes_pb.append(q_pb)

    quiz_dict = {
        "quiz_id": "quiz_block_sess_89412aef",
        "variante_codigo": "tupi_antigo",
        "nivel": 3,
        "tema": "Natureza e Cosmovisão",
        "questoes": questoes_dict,
        "gerado_em_timestamp": 1773070000,
    }

    quiz_pb = tupilingo_pb2.QuizBlockMessage(
        quiz_id=quiz_dict["quiz_id"],
        variante_codigo=quiz_dict["variante_codigo"],
        nivel=quiz_dict["nivel"],
        tema=quiz_dict["tema"],
        questoes=questoes_pb,
        gerado_em_timestamp=quiz_dict["gerado_em_timestamp"],
    )

    return quiz_dict, quiz_pb


def run_benchmark(iterations: int = 10000):
    print("=" * 72)
    print(f"  BENCHMARK REAL: PROTOCOL BUFFERS vs. JSON ({iterations:,} iterações)")
    print("=" * 72)

    user_dict, user_pb = create_sample_user()
    quiz_dict, quiz_pb = create_sample_quiz_block()

    test_cases = [
        ("Perfil do Usuário (Single Model)", user_dict, user_pb, tupilingo_pb2.UserProfileMessage),
        ("Bloco de 10 Questões de Quiz (Complex Graph)", quiz_dict, quiz_pb, tupilingo_pb2.QuizBlockMessage),
    ]

    for title, obj_dict, obj_pb, pb_class in test_cases:
        print(f"\n--- Cenário: {title} ---")

        # 1. Medição de Tamanho do Payload (Rede)
        json_bytes = json.dumps(obj_dict, ensure_ascii=False, separators=(',', ':')).encode('utf-8')
        proto_bytes = obj_pb.SerializeToString()

        json_size = len(json_bytes)
        proto_size = len(proto_bytes)
        reduction_pct = ((json_size - proto_size) / json_size) * 100

        print(f" • Payload JSON (minificado):  {json_size:,} bytes")
        print(f" • Payload Protobuf (binário): {proto_size:,} bytes")
        print(f" • Redução de Payload:         {reduction_pct:.2f}% de economia na rede")

        # 2. Benchmark de Serialização
        # JSON
        t0 = time.perf_counter()
        for _ in range(iterations):
            _ = json.dumps(obj_dict, ensure_ascii=False, separators=(',', ':')).encode('utf-8')
        json_ser_time = time.perf_counter() - t0

        # Protobuf
        t0 = time.perf_counter()
        for _ in range(iterations):
            _ = obj_pb.SerializeToString()
        proto_ser_time = time.perf_counter() - t0

        # 3. Benchmark de Deserialização
        # JSON
        t0 = time.perf_counter()
        for _ in range(iterations):
            _ = json.loads(json_bytes)
        json_deser_time = time.perf_counter() - t0

        # Protobuf
        t0 = time.perf_counter()
        for _ in range(iterations):
            parsed = pb_class()
            parsed.ParseFromString(proto_bytes)
        proto_deser_time = time.perf_counter() - t0

        # Resultados de Tempo e Velocidade
        print("\n Performance de Latência (tempo total para 10k execuções):")
        print(f"   [Serialização]")
        print(f"     JSON:     {json_ser_time * 1000:.2f} ms ({iterations / json_ser_time:,.0f} ops/sec) | Média: {(json_ser_time / iterations) * 1e6:.2f} µs/op")
        print(f"     Protobuf: {proto_ser_time * 1000:.2f} ms ({iterations / proto_ser_time:,.0f} ops/sec) | Média: {(proto_ser_time / iterations) * 1e6:.2f} µs/op")
        ser_speedup = json_ser_time / proto_ser_time
        print(f"     Speedup:  {ser_speedup:.2f}x mais rápido na serialização")

        print(f"   [Deserialização]")
        print(f"     JSON:     {json_deser_time * 1000:.2f} ms ({iterations / json_deser_time:,.0f} ops/sec) | Média: {(json_deser_time / iterations) * 1e6:.2f} µs/op")
        print(f"     Protobuf: {proto_deser_time * 1000:.2f} ms ({iterations / proto_deser_time:,.0f} ops/sec) | Média: {(proto_deser_time / iterations) * 1e6:.2f} µs/op")
        deser_speedup = json_deser_time / proto_deser_time
        print(f"     Speedup:  {deser_speedup:.2f}x mais rápido na deserialização")


if __name__ == "__main__":
    run_benchmark(iterations=10000)
