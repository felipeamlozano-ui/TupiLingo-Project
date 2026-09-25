// Fábrica com os dados e nós iniciais padrão da cartografia histórica de Pindorama.
class PindoramaWorldDefaults {
  // Retorna os territórios demarcados padrão (Tupinambá, Tupiniquim) com seus polígonos.
  static List<Map<String, dynamic>> defaultTerritories() {
    return [
      {
        'id': 1,
        'name_tupi': 'Tupinambá',
        'name_portuguese': 'Costa da Guanabara e Ubatuba',
        'biome': 'Mata Atlântica',
        'center_x': 2000.0,
        'center_y': 2000.0,
        'is_unlocked_default': true,
        'fog_reveal_radius': 240.0,
        'polygon_coordinates': [
          [1700.0, 1800.0],
          [2300.0, 1750.0],
          [2400.0, 2200.0],
          [2100.0, 2400.0],
          [1650.0, 2250.0],
        ],
      },
      {
        'id': 2,
        'name_tupi': 'Tupiniquim',
        'name_portuguese': 'Planalto de Piratininga',
        'biome': 'Mata Atlântica',
        'center_x': 2600.0,
        'center_y': 2000.0,
        'is_unlocked_default': false,
        'fog_reveal_radius': 240.0,
        'polygon_coordinates': [
          [2450.0, 1800.0],
          [2850.0, 1750.0],
          [2900.0, 2300.0],
          [2500.0, 2250.0],
        ],
      },
    ];
  }

  // Retorna as aldeias históricas da costa e planalto (Ubatuba, Karióka, Piratininga).
  static List<Map<String, dynamic>> defaultVillages() {
    return [
      {
        'id': 1,
        'name_tupi': 'Ubatuba',
        'name_portuguese': 'Lugar de Muitas Canoas',
        'biome': 'Mata Atlântica',
        'village_style': 'canoas',
        'village_color': '#F59E0B',
        'x': 1950.0,
        'y': 1950.0,
        'is_unlocked_default': true,
        'fog_reveal_radius': 190.0,
        'description': 'Principal centro da Confederação dos Tamoios sob liderança de Cunhambebe.',
      },
      {
        'id': 2,
        'name_tupi': 'Karióka',
        'name_portuguese': 'Casa do Homem Branco',
        'biome': 'Mata Atlântica',
        'village_style': 'taba_fort',
        'village_color': '#10B981',
        'x': 2250.0,
        'y': 2100.0,
        'is_unlocked_default': true,
        'fog_reveal_radius': 180.0,
        'description': 'Aldeia histórica na foz do rio Carioca na baía de Guanabara.',
      },
      {
        'id': 3,
        'name_tupi': 'Piratininga',
        'name_portuguese': 'Peixe Seco ao Sol',
        'biome': 'Mata Atlântica',
        'village_style': 'maloca',
        'village_color': '#DC2626',
        'x': 2650.0,
        'y': 1980.0,
        'is_unlocked_default': false,
        'fog_reveal_radius': 170.0,
        'description': 'Aldeia liderada por Tibiriçá no planalto paulista.',
      },
    ];
  }

  // Fornece a hidrografia inicial com curvas de rio em Bézier e correntes visuais.
  static List<Map<String, dynamic>> defaultRivers() {
    return [
      {
        'id': 1,
        'name_tupi': 'Paranapanema',
        'name_portuguese': 'Rio da Água Ruim / Larga',
        'river_width': 6.0,
        'water_color': '#38BDF8',
        'flow_style': 'currents',
        'bezier_points': [
          [1600.0, 1700.0],
          [1850.0, 1900.0],
          [2200.0, 2050.0],
          [2600.0, 2150.0],
          [2850.0, 2400.0],
        ],
      },
    ];
  }

  // Gera as rotas e conexões pré-estabelecidas entre aldeias como o Peabiru.
  static List<Map<String, dynamic>> defaultTrails() {
    return [
      {
        'id': 1,
        'name_tupi': 'Peabiru Histórico',
        'name_portuguese': 'Caminho Ancestral Transcontinental',
        'connection_type': 'terrestre',
        'trail_color': '#F59E0B',
        'trail_style': 'dotted',
        'trail_width': 3.0,
        'from_id': 1,
        'from_type': 'Aldeia',
        'from_name': 'Ubatuba',
        'to_id': 2,
        'to_type': 'Aldeia',
        'to_name': 'Karióka',
        'waypoints': [
          [1950.0, 1950.0],
          [2100.0, 2020.0],
          [2250.0, 2100.0],
        ],
      },
    ];
  }

  // Registra as missões e relíquias etnográficas espalhadas inicialmente no mapa.
  static List<Map<String, dynamic>> defaultQuests() {
    return [
      {
        'id': 1,
        'name_tupi': 'Sambaqui de Guaratiba',
        'name_portuguese': 'Sítio Concheiro Arqueológico',
        'biome': 'Mata Atlântica',
        'quest_icon': 'relic',
        'marker_color': '#EAB308',
        'x': 2100.0,
        'y': 2250.0,
        'type': 'ancient_relic',
        'xp_reward': 75,
        'is_unlocked_default': true,
        'fog_reveal_radius': 130.0,
        'description': 'Montículo de conchas e vestígios pré-colombianos de extrema importância arqueológica.',
      },
      {
        'id': 2,
        'name_tupi': 'Itacoatiara do Peabiru',
        'name_portuguese': 'Inscrições Rupestres Sagradas',
        'biome': 'Mata Atlântica',
        'quest_icon': 'scroll',
        'marker_color': '#8B5CF6',
        'x': 2450.0,
        'y': 2040.0,
        'type': 'curiosity',
        'xp_reward': 50,
        'is_unlocked_default': false,
        'fog_reveal_radius': 110.0,
        'description': 'Petroglifos entalhados na rocha ao longo da antiga rota milenar indígena.',
      },
    ];
  }
}
