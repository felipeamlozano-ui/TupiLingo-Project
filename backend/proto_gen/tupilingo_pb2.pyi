from google.protobuf.internal import containers as _containers
from google.protobuf import descriptor as _descriptor
from google.protobuf import message as _message
from collections.abc import Iterable as _Iterable, Mapping as _Mapping
from typing import ClassVar as _ClassVar, Optional as _Optional, Union as _Union

DESCRIPTOR: _descriptor.FileDescriptor

class UserProfileMessage(_message.Message):
    __slots__ = ("supabase_uid", "email", "name", "xp_total", "streak_dias", "nivel_atual", "conchas", "variante_ativa_codigo", "variante_ativa_nome", "ofensiva_ativa")
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
    def __init__(self, supabase_uid: _Optional[str] = ..., email: _Optional[str] = ..., name: _Optional[str] = ..., xp_total: _Optional[int] = ..., streak_dias: _Optional[int] = ..., nivel_atual: _Optional[int] = ..., conchas: _Optional[int] = ..., variante_ativa_codigo: _Optional[str] = ..., variante_ativa_nome: _Optional[str] = ..., ofensiva_ativa: _Optional[bool] = ...) -> None: ...

class UserLessonProgressMessage(_message.Message):
    __slots__ = ("licao_id", "numero", "titulo", "concluida", "pontuacao_maxima", "tentativas", "data_conclusao_timestamp")
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
    def __init__(self, licao_id: _Optional[int] = ..., numero: _Optional[int] = ..., titulo: _Optional[str] = ..., concluida: _Optional[bool] = ..., pontuacao_maxima: _Optional[int] = ..., tentativas: _Optional[int] = ..., data_conclusao_timestamp: _Optional[int] = ...) -> None: ...

class QuizItemMessage(_message.Message):
    __slots__ = ("item_id", "termo_tupi", "traducao_correta", "distratores", "regra_contexto", "enunciado", "explicacao", "curiosidade")
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
    def __init__(self, item_id: _Optional[int] = ..., termo_tupi: _Optional[str] = ..., traducao_correta: _Optional[str] = ..., distratores: _Optional[_Iterable[str]] = ..., regra_contexto: _Optional[str] = ..., enunciado: _Optional[str] = ..., explicacao: _Optional[str] = ..., curiosidade: _Optional[str] = ...) -> None: ...

class QuizBlockMessage(_message.Message):
    __slots__ = ("quiz_id", "variante_codigo", "nivel", "tema", "questoes", "gerado_em_timestamp")
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
    def __init__(self, quiz_id: _Optional[str] = ..., variante_codigo: _Optional[str] = ..., nivel: _Optional[int] = ..., tema: _Optional[str] = ..., questoes: _Optional[_Iterable[_Union[QuizItemMessage, _Mapping]]] = ..., gerado_em_timestamp: _Optional[int] = ...) -> None: ...
