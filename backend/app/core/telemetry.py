import os

from app.core.config import settings
from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.django import DjangoInstrumentor
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor


def configure_telemetry():
    """
    Configura OpenTelemetry para enviar Traces ao Jaeger/Prometheus via OTLP.
    É habilitado apenas se ENABLE_OTEL for True.
    """
    if not settings.ENABLE_OTEL:
        return

    # Definir provedor de Tracing
    provider = TracerProvider()
    
    # Exportador OTLP (vai para o coletor ou direto para Grafana Tempo/Jaeger)
    otlp_endpoint = os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "http://localhost:4317")
    exporter = OTLPSpanExporter(endpoint=otlp_endpoint, insecure=True)
    
    processor = BatchSpanProcessor(exporter)
    provider.add_span_processor(processor)
    
    trace.set_tracer_provider(provider)
    
    # Instrumentação automática do Django
    DjangoInstrumentor().instrument()

    print("OpenTelemetry configurado e instrumentado para Django.")

# Opcional: Criar decorator para rastrear funções específicas (como geração de LLM)
def trace_llm_call(func):
    def wrapper(*args, **kwargs):
        if settings.ENABLE_OTEL:
            tracer = trace.get_tracer(__name__)
            with tracer.start_as_current_span(f"LLM_Call_{func.__name__}"):
                return func(*args, **kwargs)
        return func(*args, **kwargs)
    return wrapper
