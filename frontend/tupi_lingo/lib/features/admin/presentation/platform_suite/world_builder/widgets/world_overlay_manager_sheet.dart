import 'package:flutter/material.dart';
import 'package:tupi_lingo/core/theme/app_theme.dart';

// Modal inferior para ligar e desligar camadas cartográficas e ajustar a simulação da névoa de guerra.
class WorldOverlayManagerSheet extends StatefulWidget {
  final bool layerTerritories;
  final ValueChanged<bool> onLayerTerritoriesChanged;
  final bool layerVillages;
  final ValueChanged<bool> onLayerVillagesChanged;
  final bool layerRivers;
  final ValueChanged<bool> onLayerRiversChanged;
  final bool layerTrails;
  final ValueChanged<bool> onLayerTrailsChanged;
  final bool layerQuests;
  final ValueChanged<bool> onLayerQuestsChanged;
  final bool layerGrid;
  final ValueChanged<bool> onLayerGridChanged;
  final bool layerLabels;
  final ValueChanged<bool> onLayerLabelsChanged;
  final bool showFogPreview;
  final ValueChanged<bool> onShowFogPreviewChanged;
  final double fogOpacity;
  final ValueChanged<double> onFogOpacityChanged;
  final Color fogColor;
  final ValueChanged<Color> onFogColorChanged;

  const WorldOverlayManagerSheet({
    super.key,
    required this.layerTerritories,
    required this.onLayerTerritoriesChanged,
    required this.layerVillages,
    required this.onLayerVillagesChanged,
    required this.layerRivers,
    required this.onLayerRiversChanged,
    required this.layerTrails,
    required this.onLayerTrailsChanged,
    required this.layerQuests,
    required this.onLayerQuestsChanged,
    required this.layerGrid,
    required this.onLayerGridChanged,
    required this.layerLabels,
    required this.onLayerLabelsChanged,
    required this.showFogPreview,
    required this.onShowFogPreviewChanged,
    required this.fogOpacity,
    required this.onFogOpacityChanged,
    required this.fogColor,
    required this.onFogColorChanged,
  });

  @override
  State<WorldOverlayManagerSheet> createState() => _WorldOverlayManagerSheetState();
}

class _WorldOverlayManagerSheetState extends State<WorldOverlayManagerSheet> {
  late bool _layerTerritories;
  late bool _layerVillages;
  late bool _layerRivers;
  late bool _layerTrails;
  late bool _layerQuests;
  late bool _layerGrid;
  late bool _layerLabels;
  late bool _showFogPreview;
  late double _fogOpacity;
  late Color _fogColor;

  @override
  void initState() {
    super.initState();
    _layerTerritories = widget.layerTerritories;
    _layerVillages = widget.layerVillages;
    _layerRivers = widget.layerRivers;
    _layerTrails = widget.layerTrails;
    _layerQuests = widget.layerQuests;
    _layerGrid = widget.layerGrid;
    _layerLabels = widget.layerLabels;
    _showFogPreview = widget.showFogPreview;
    _fogOpacity = widget.fogOpacity;
    _fogColor = widget.fogColor;
  }

  // Título em caixa alta estilizado para separar blocos do gerenciador.
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        title,
        style: TextStyle(
          color: AppTheme.accent(context),
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  // Item com switch para alternar visibilidade de uma camada específica do mapa.
  Widget _buildLayerTile({
    required String title,
    required IconData icon,
    required Color color,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      secondary: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: AppTheme.textPrimary(context),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      value: value,
      activeThumbColor: AppTheme.accent(context),
      onChanged: onChanged,
    );
  }

  // Chip de seleção de tonalidade da atmosfera/névoa escura.
  Widget _buildFogColorChip(String label, Color color) {
    final isSelected = _fogColor == color;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: isSelected ? Colors.white : AppTheme.textPrimary(context),
        ),
      ),
      avatar: CircleAvatar(backgroundColor: color, radius: 7),
      selected: isSelected,
      selectedColor: AppTheme.accent(context),
      backgroundColor: AppTheme.surfaceSubtle(context),
      onSelected: (_) {
        setState(() => _fogColor = color);
        widget.onFogColorChanged(color);
      },
    );
  }

  // Renderiza a lista de camadas e as opções de densidade e cor do Fog of War.
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.layers, color: AppTheme.accent(context)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Gerenciador de Camadas & Fog of War',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppTheme.textPrimary(context),
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Ative ou desative as camadas cartográficas e personalize o Fog of War.',
                style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 11),
              ),
              const SizedBox(height: 14),

              // Seção de Camadas
              _buildSectionHeader('CAMADAS CARTOGRÁFICAS'),
              _buildLayerTile(
                title: 'Territórios e Fronteiras Tribais',
                icon: Icons.polyline,
                color: const Color(0xFF10B981),
                value: _layerTerritories,
                onChanged: (val) {
                  setState(() => _layerTerritories = val);
                  widget.onLayerTerritoriesChanged(val);
                },
              ),
              _buildLayerTile(
                title: 'Aldeias e Centros Populacionais',
                icon: Icons.holiday_village,
                color: const Color(0xFFF59E0B),
                value: _layerVillages,
                onChanged: (val) {
                  setState(() => _layerVillages = val);
                  widget.onLayerVillagesChanged(val);
                },
              ),
              _buildLayerTile(
                title: 'Rios e Bacias Hidrográficas',
                icon: Icons.water,
                color: const Color(0xFF0284C7),
                value: _layerRivers,
                onChanged: (val) {
                  setState(() => _layerRivers = val);
                  widget.onLayerRiversChanged(val);
                },
              ),
              _buildLayerTile(
                title: 'Trilhas & Conexões (Peabiru)',
                icon: Icons.route,
                color: const Color(0xFFD97706),
                value: _layerTrails,
                onChanged: (val) {
                  setState(() => _layerTrails = val);
                  widget.onLayerTrailsChanged(val);
                },
              ),
              _buildLayerTile(
                title: 'Missões e Pontos de Interesse (Quests)',
                icon: Icons.explore,
                color: const Color(0xFFEAB308),
                value: _layerQuests,
                onChanged: (val) {
                  setState(() => _layerQuests = val);
                  widget.onLayerQuestsChanged(val);
                },
              ),
              _buildLayerTile(
                title: 'Grid Cartográfico (100m / 500m)',
                icon: Icons.grid_4x4,
                color: const Color(0xFF64748B),
                value: _layerGrid,
                onChanged: (val) {
                  setState(() => _layerGrid = val);
                  widget.onLayerGridChanged(val);
                },
              ),
              _buildLayerTile(
                title: 'Rótulos e Nomes em Tupi',
                icon: Icons.label,
                color: const Color(0xFFA855F7),
                value: _layerLabels,
                onChanged: (val) {
                  setState(() => _layerLabels = val);
                  widget.onLayerLabelsChanged(val);
                },
              ),

              const SizedBox(height: 14),
              // Personalização do Fog of War
              _buildSectionHeader('PERSONALIZAÇÃO DO FOG OF WAR'),
              _buildLayerTile(
                title: 'Simulação do Fog of War',
                icon: Icons.cloud,
                color: const Color(0xFF38BDF8),
                value: _showFogPreview,
                onChanged: (val) {
                  setState(() => _showFogPreview = val);
                  widget.onShowFogPreviewChanged(val);
                },
              ),

              if (_showFogPreview) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Text(
                    'Densidade da Névoa: ${(_fogOpacity * 100).toInt()}%',
                    style: TextStyle(
                      color: AppTheme.textPrimary(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Slider(
                  value: _fogOpacity,
                  min: 0.20,
                  max: 0.98,
                  divisions: 15,
                  activeColor: const Color(0xFF38BDF8),
                  onChanged: (v) {
                    setState(() => _fogOpacity = v);
                    widget.onFogOpacityChanged(v);
                  },
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 6),
                  child: Text(
                    'Tom / Atmosfera da Névoa:',
                    style: TextStyle(
                      color: AppTheme.textPrimary(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildFogColorChip('Abismo Noturno', const Color(0xFF060B15)),
                    _buildFogColorChip('Neblina Selva', const Color(0xFF0A2118)),
                    _buildFogColorChip('Pergaminho', const Color(0xFF24180C)),
                    _buildFogColorChip('Crepúsculo Místico', const Color(0xFF151226)),
                  ],
                ),
              ],

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
