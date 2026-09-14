import 'package:flutter/material.dart';

enum WorldBuilderTool {
  select,
  territory,
  village,
  river,
  trail,
  quest,
  overlay,
}

/// Floating Toolbar com ferramentas de edição visual para o World Builder CMS (RFC-013 Capítulo 19).
class FloatingWorldToolbar extends StatelessWidget {
  final WorldBuilderTool activeTool;
  final ValueChanged<WorldBuilderTool> onToolSelected;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onResetView;
  final bool showFogPreview;
  final ValueChanged<bool> onToggleFogPreview;

  const FloatingWorldToolbar({
    super.key,
    required this.activeTool,
    required this.onToolSelected,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onResetView,
    required this.showFogPreview,
    required this.onToggleFogPreview,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF334155), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToolButton(
            tool: WorldBuilderTool.select,
            icon: Icons.near_me,
            tooltip: 'Seleção & Inspeção (V)',
          ),
          _buildToolButton(
            tool: WorldBuilderTool.territory,
            icon: Icons.polyline,
            tooltip: 'Polígono de Território (T)',
          ),
          _buildToolButton(
            tool: WorldBuilderTool.village,
            icon: Icons.holiday_village,
            tooltip: 'Inserir Aldeia / Oca (A)',
          ),
          _buildToolButton(
            tool: WorldBuilderTool.river,
            icon: Icons.water,
            tooltip: 'Curva Bézier de Rio (R)',
          ),
          _buildToolButton(
            tool: WorldBuilderTool.trail,
            icon: Icons.route,
            tooltip: 'Trilha Histórica (P)',
          ),
          _buildToolButton(
            tool: WorldBuilderTool.quest,
            icon: Icons.explore,
            tooltip: 'Ponto de Interesse / Quest (Q)',
          ),
          _buildToolButton(
            tool: WorldBuilderTool.overlay,
            icon: Icons.layers,
            tooltip: 'Camadas Históricas (L)',
          ),
          const SizedBox(width: 8),
          Container(width: 1, height: 28, color: const Color(0xFF334155)),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.zoom_in, color: Colors.white70, size: 20),
            tooltip: 'Zoom +',
            onPressed: onZoomIn,
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out, color: Colors.white70, size: 20),
            tooltip: 'Zoom -',
            onPressed: onZoomOut,
          ),
          IconButton(
            icon: const Icon(Icons.center_focus_strong, color: Colors.white70, size: 20),
            tooltip: 'Centralizar Câmera',
            onPressed: onResetView,
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(
              showFogPreview ? Icons.cloud : Icons.cloud_off,
              color: showFogPreview ? const Color(0xFF38BDF8) : Colors.white38,
              size: 20,
            ),
            tooltip: showFogPreview ? 'Desativar Fog of War' : 'Simular Fog of War',
            onPressed: () => onToggleFogPreview(!showFogPreview),
          ),
        ],
      ),
    );
  }

  Widget _buildToolButton({
    required WorldBuilderTool tool,
    required IconData icon,
    required String tooltip,
  }) {
    final isActive = activeTool == tool;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () => onToolSelected(tool),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(8),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF10B981) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: isActive ? Colors.white : const Color(0xFF94A3B8),
            size: 20,
          ),
        ),
      ),
    );
  }
}
