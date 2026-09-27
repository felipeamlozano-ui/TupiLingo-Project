import os
import sys
from dotenv import load_dotenv

load_dotenv('backend/.env')

sys.path.insert(0, os.path.abspath('backend'))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings.development')

try:
    from app.services.supabase_service import supabase_service
    print("Supabase service initialized.")

    variantes = ["tupi", "tupi_contemporaneo", "tupinamba", "kamaiurá", "kamaiura"]
    for v in variantes:
        try:
            items = supabase_service.obter_esqueleto_quiz(v, "geral", 5)
            print(f"Variante '{v}': {len(items)} items returned from RPC gerar_esqueleto_quiz")
            if items:
                print(f"  First item: {items[0].termo_tupi} -> {items[0].traducao_correta}")
        except Exception as e:
            print(f"Variante '{v}' error: {e}")

    try:
        chunks = supabase_service.obter_chunks_rag(["Vocabulário"], 3)
        print(f"\nRAG Chunks returned: {len(chunks)}")
        if chunks:
            print(f"  Chunk 0 sample: {str(chunks[0])[:150]}")
    except Exception as e:
        print(f"RAG Chunks error: {e}")

except Exception as e:
    print(f"General error: {e}")
