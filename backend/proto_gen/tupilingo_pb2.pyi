from collections.abc import Iterable as _Iterable
from collections.abc import Mapping as _Mapping
from typing import ClassVar as _ClassVar

from google.protobuf import descriptor as _descriptor
from google.protobuf import message as _message
from google.protobuf.internal import containers as _containers

DESCRIPTOR: _descriptor.FileDescriptor

class UserProfileMessage(_message.Message):
    __slots__ = ("conchas", "email", "name", "nivel_atual", "ofensiva_ativa", "streak_dias", "supabase_uid", "variante_ativa_codigo", "variante_ativa_nome", "xp_total")
    SUPABASE_UID_FIELD_NUMBER: _ClassVar[int]
    EMAIL_FIELD_NUMBER: _ClassVar[int]
    NAME_FIELD_NUMBER: _ClassVar[int]
    XP_TOTAL_FIELD_NUMBER: _ClassVar[int]
    STREAK_DIAS_FIELD_NUMBER: _ClassVar[int]
    NIVEL_ATUAL_FIELD_NUMBER: _ClassVar[int]
    CONCHAS_FIELD_NUMBER: _ClassVar[int]
    VARIANTE_ATIVA_CODIGO_FIELD_NUMBER: _ClassVar[int]
    VARIANTE_ATIVA_NOME_FIELD_NUMBER: _ClassVar[int]
    OFENSIVA_ATIVA_FIELD_NUMBER: _ClassVar[int]
    supabase_uid: str
    email: str
    name: str
    xp_total: int
    streak_dias: int
    nivel_atual: int
    conchas: int
    variante_ativa_codigo: str
    variante_ativa_nome: str
    ofensiva_ativa: bool
    def __init__(self, supabase_uid: str | None = ..., email: str | None = ..., name: str | None = ..., xp_total: int | None = ..., streak_dias: int | None = ..., nivel_atual: int | None = ..., conchas: int | None = ..., variante_ativa_codigo: str | None = ..., variante_ativa_nome: str | None = ..., ofensiva_ativa: bool | None = ...) -> None: ...

class UserLessonProgressMessage(_message.Message):
    __slots__ = ("concluida", "data_conclusao_timestamp", "licao_id", "numero", "pontuacao_maxima", "tentativas", "titulo")
    LICAO_ID_FIELD_NUMBER: _ClassVar[int]
    NUMERO_FIELD_NUMBER: _ClassVar[int]
    TITULO_FIELD_NUMBER: _ClassVar[int]
    CONCLUIDA_FIELD_NUMBER: _ClassVar[int]
    PONTUACAO_MAXIMA_FIELD_NUMBER: _ClassVar[int]
    TENTATIVAS_FIELD_NUMBER: _ClassVar[int]
    DATA_CONCLUSAO_TIMESTAMP_FIELD_NUMBER: _ClassVar[int]
    licao_id: int
    numero: int
    titulo: str
    concluida: bool
    pontuacao_maxima: int
    tentativas: int
    data_conclusao_timestamp: int
    def __init__(self, licao_id: int | None = ..., numero: int | None = ..., titulo: str | None = ..., concluida: bool | None = ..., pontuacao_maxima: int | None = ..., tentativas: int | None = ..., data_conclusao_timestamp: int | None = ...) -> None: ...

class QuizItemMessage(_message.Message):
    __slots__ = ("curiosidade", "distratores", "enunciado", "explicacao", "item_id", "regra_contexto", "termo_tupi", "traducao_correta")
    ITEM_ID_FIELD_NUMBER: _ClassVar[int]
    TERMO_TUPI_FIELD_NUMBER: _ClassVar[int]
    TRADUCAO_CORRETA_FIELD_NUMBER: _ClassVar[int]
    DISTRATORES_FIELD_NUMBER: _ClassVar[int]
    REGRA_CONTEXTO_FIELD_NUMBER: _ClassVar[int]
    ENUNCIADO_FIELD_NUMBER: _ClassVar[int]
    EXPLICACAO_FIELD_NUMBER: _ClassVar[int]
    CURIOSIDADE_FIELD_NUMBER: _ClassVar[int]
    item_id: int
    termo_tupi: str
    traducao_correta: str
    distratores: _containers.RepeatedScalarFieldContainer[str]
    regra_contexto: str
    enunciado: str
    explicacao: str
    curiosidade: str
    def __init__(self, item_id: int | None = ..., termo_tupi: str | None = ..., traducao_correta: str | None = ..., distratores: _Iterable[str] | None = ..., regra_contexto: str | None = ..., enunciado: str | None = ..., explicacao: str | None = ..., curiosidade: str | None = ...) -> None: ...

class QuizBlockMessage(_message.Message):
    __slots__ = ("gerado_em_timestamp", "nivel", "questoes", "quiz_id", "tema", "variante_codigo")
    QUIZ_ID_FIELD_NUMBER: _ClassVar[int]
    VARIANTE_CODIGO_FIELD_NUMBER: _ClassVar[int]
    NIVEL_FIELD_NUMBER: _ClassVar[int]
    TEMA_FIELD_NUMBER: _ClassVar[int]
    QUESTOES_FIELD_NUMBER: _ClassVar[int]
    GERADO_EM_TIMESTAMP_FIELD_NUMBER: _ClassVar[int]
    quiz_id: str
    variante_codigo: str
    nivel: int
    tema: str
    questoes: _containers.RepeatedCompositeFieldContainer[QuizItemMessage]
    gerado_em_timestamp: int
    def __init__(self, quiz_id: str | None = ..., variante_codigo: str | None = ..., nivel: int | None = ..., tema: str | None = ..., questoes: _Iterable[QuizItemMessage | _Mapping] | None = ..., gerado_em_timestamp: int | None = ...) -> None: ...
