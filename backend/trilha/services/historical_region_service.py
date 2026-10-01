"""
Serviço de Domínio para Regiões Históricas (Aldeias) do Mapa Interativo.
"""

import json
from pathlib import Path
from typing import Any, Dict, List, Optional

_MAPA_PINDORAMA_PATH = Path(__file__).resolve().parent.parent.parent / "pedagogico" / "mapa" / "mapa_pindorama.json"


def _build_pindorama_stages() -> List[Dict[str, Any]]:
    if _MAPA_PINDORAMA_PATH.exists():
        try:
            with open(_MAPA_PINDORAMA_PATH, 'r', encoding='utf-8') as f:
                data = json.load(f)
            stages = data.get('stages', [])
            loaded = []
            for st in stages:
                ch = st.get('chapter', 1)
                nome = st.get('nome', '')
                toponimo = st.get('toponimo_indigena', '')
                nacao = st.get('nacao_indigena', 'Tupi')
                rel = st.get('mapa_relativo', {})
                loaded.append({
                    'id': ch,
                    'name': f"{nome} ({nacao})",
                    'toponimo': toponimo,
                    'indigenous_nation': nacao,
                    'historical_period': st.get('periodo_historico', 'Século XVI'),
                    'relative_x': rel.get('x', 0.5),
                    'relative_y': rel.get('y', 0.5),
                    'radius': rel.get('raio', 24.0),
                    'cultural_summary': st.get('narrativa_rag', ''),
                    'vocabulary_highlights': st.get('elementos_destaque', []),
                    'required_level': min(5, (ch + 3) // 4),
                })
            if loaded:
                return loaded
        except Exception:
            pass

    return [
        {
            'id': 1,
            'name': 'Costa dos Tupinambás (Ubatuba / Guanabara)',
            'indigenous_nation': 'Tupinambá',
            'historical_period': 'Século XVI - Confederação dos Tamoios',
            'relative_x': 0.72,
            'relative_y': 0.68,
            'radius': 26.0,
            'cultural_summary': 'Coração da Confederação dos Tamoios.',
            'vocabulary_highlights': ['Iperoig', 'Tamoio', 'Karai', 'Tupã', 'Maracá'],
            'required_level': 1,
        },
    ]


class HistoricalRegionService:
    REGIOES_TEMPLATE: List[Dict[str, Any]] = _build_pindorama_stages()

    @classmethod
    def build_user_regions(
        cls,
        capitulos: List[Dict[str, Any]],
        user_nivel: int = 1
    ) -> List[Dict[str, Any]]:
        """
        Combina o template histórico com o progresso real dos capítulos da trilha
        e o nível atual do usuário.
        """
        regioes_finais: List[Dict[str, Any]] = []

        for idx, reg in enumerate(cls.REGIOES_TEMPLATE):
            reg_data = dict(reg)
            if idx < len(capitulos):
                cap = capitulos[idx]
                licoes = cap.get('licoes', [])
                total_licoes = len(licoes) if licoes else 4
                completadas = sum(1 for l in licoes if l.get('status') == 'concluida')

                # Desbloqueio autêntico alinhado com lições
                has_active_lesson = any(l.get('status') in ('concluida', 'em_andamento', 'disponivel') for l in licoes)
                prev_cap_finished = False
                if idx > 0 and idx - 1 < len(capitulos):
                    prev_licoes = capitulos[idx - 1].get('licoes', [])
                    prev_cap_finished = len(prev_licoes) > 0 and all(l.get('status') == 'concluida' for l in prev_licoes)

                is_unlocked = (idx == 0) or has_active_lesson or prev_cap_finished or (user_nivel >= reg['required_level'])

                # Alinha o título e a narrativa da aldeia com os capítulos e lições reais da variante
                cap_titulo = cap.get('titulo')
                if cap_titulo:
                    reg_data['name'] = f"{cap_titulo} ({reg['indigenous_nation']})"
                cap_desc = cap.get('descricao')
                if cap_desc:
                    reg_data['cultural_summary'] = cap_desc

                # Destaca vocabulário expressado nas lições do capítulo
                lesson_terms = []
                for lic in licoes:
                    t = lic.get('titulo', '')
                    if t and '-' in t:
                        parts = t.split('-')
                        if len(parts) > 1:
                            lesson_terms.append(parts[1].strip())
                if lesson_terms:
                    reg_data['vocabulary_highlights'] = lesson_terms[:5]
            else:
                total_licoes = 4
                completadas = 0
                is_unlocked = user_nivel >= reg['required_level']

            reg_data['lessons_count'] = total_licoes
            reg_data['completed_lessons_count'] = completadas
            reg_data['is_unlocked'] = is_unlocked
            regioes_finais.append(reg_data)

        return regioes_finais
