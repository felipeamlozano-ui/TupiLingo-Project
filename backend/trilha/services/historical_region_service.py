"""
Serviço de Domínio para Regiões Históricas (Aldeias) do Mapa Interativo.
"""

from typing import Any, Dict, List, Optional


class HistoricalRegionService:
    REGIOES_TEMPLATE: List[Dict[str, Any]] = [
        {
            'id': 1,
            'name': 'Costa dos Tupinambás (Ubatuba / Guanabara)',
            'indigenous_nation': 'Tupinambá',
            'historical_period': 'Século XVI - Confederação dos Tamoios',
            'relative_x': 0.72,
            'relative_y': 0.68,
            'radius': 26.0,
            'cultural_summary': (
                'Coração da Confederação dos Tamoios liderada por Cunhambebe. Famosos navegadores de canoas '
                'e guerreiros da floresta atlântica, falantes do Tupi clássico registrado por Jean de Léry e Hans Staden.'
            ),
            'vocabulary_highlights': ['Iperoig', 'Tamoio', 'Karai', 'Tupã', 'Maracá'],
            'required_level': 1,
        },
        {
            'id': 2,
            'name': 'Território Carijó (Litoral Sul / Ilha de SC)',
            'indigenous_nation': 'Carijó (Guarani)',
            'historical_period': 'Século XVI - Trilha do Peabiru',
            'relative_x': 0.60,
            'relative_y': 0.84,
            'radius': 24.0,
            'cultural_summary': (
                'Povo pacífico de navegadores e guardiões do mítico caminho sagrado do Peabiru, que ligava o Atlântico aos Andes. '
                'Grandes ceramistas e agricultores de mandioca e milho.'
            ),
            'vocabulary_highlights': ['Peabiru', 'Meiembipe', 'Mandi\'oka', 'Avaxi'],
            'required_level': 2,
        },
        {
            'id': 3,
            'name': 'Alto Xingu & Florestas Centrais',
            'indigenous_nation': 'Kamaiurá / Aweti (Tupi)',
            'historical_period': 'Tradição Milenar das Aldeias Circulares',
            'relative_x': 0.52,
            'relative_y': 0.48,
            'radius': 25.0,
            'cultural_summary': (
                'Complexo cultural do Xingu com aldeias circulares monumentais, rituais sagrados do Kuarup e luta Huka-Huka. '
                'Preservam a língua de tronco Tupi viva em sua forma mais rica e expressiva.'
            ),
            'vocabulary_highlights': ['Kuarup', 'Huka-huka', 'Jawari', 'Moitará'],
            'required_level': 3,
        },
        {
            'id': 4,
            'name': 'Amazônia Nheengatu (Bacia do Rio Negro)',
            'indigenous_nation': 'Povos do Rio Negro (Nheengatu)',
            'historical_period': 'Século XVII aos dias atuais',
            'relative_x': 0.32,
            'relative_y': 0.22,
            'radius': 26.0,
            'cultural_summary': (
                'Berço da Língua Geral Amazônica (Nheengatu), derivada do Tupinambá e reconhecida como patrimônio linguístico vivo. '
                'Riquíssima cosmologia sobre Jurupari e os rios de água preta.'
            ),
            'vocabulary_highlights': ['Yande', 'Paranã', 'Yara', 'Jurupari', 'Puraque'],
            'required_level': 4,
        },
        {
            'id': 5,
            'name': 'Costa dos Tupiniquins (Porto Seguro)',
            'indigenous_nation': 'Tupiniquim',
            'historical_period': '1500 - Primeiro Contato',
            'relative_x': 0.84,
            'relative_y': 0.56,
            'radius': 23.0,
            'cultural_summary': (
                'Habitantes da costa sul da Bahia, foram os primeiros anfitriões dos navegadores portugueses em 1500. '
                'Exímios coletores de moluscos e conhecedores dos segredos das marés.'
            ),
            'vocabulary_highlights': ['Pindorama', 'Mbya', 'Itaparica', 'Pirá'],
            'required_level': 5,
        },
    ]

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
