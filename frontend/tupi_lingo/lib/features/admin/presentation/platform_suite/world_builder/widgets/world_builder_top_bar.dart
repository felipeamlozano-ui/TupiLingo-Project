import 'package:flutter/material.dart';
import 'package:tupi_lingo/core/theme/app_theme.dart';
import '../../shared/status_badge.dart';

// Barra superior do World Builder contendo título, época histórica, sincronização e ações globais de deploy.
class WorldBuilderTopBar extends StatelessWidget {
  final String selectedEpoch;
  final ValueChanged<String> onEpochChanged;
  final bool isLoading;
  final VoidCallback onSyncBackend;
  final VoidCallback onAddVillage;
  final VoidCallback onSaveAndApply;
  final VoidCallback onPublishSnapshot;

  const WorldBuilderTopBar({
    super.key,
    required this.selectedEpoch,
    required this.onEpochChanged,
    required this.isLoading,
    required this.onSyncBackend,
    required this.onAddVillage,
    required this.onSaveAndApply,
    required this.onPublishSnapshot,
  });

  // Renderiza a barra com seletores de linha do tempo e botões de persistência imediata e publicação.
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        border: Border(bottom: BorderSide(color: AppTheme.border(context))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Icon(Icons.public, color: AppTheme.accent(context), size: 26),
            const SizedBox(width: 12),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pindorama World Builder',
                  style: TextStyle(
                    color: AppTheme.textPrimary(context),
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'CMS Topológico & Curadoria Curricular',
                  style: TextStyle(
                    color: AppTheme.textSecondary(context),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            StatusBadge.draft(label: 'DRAFT v1.3.0'),
            const SizedBox(width: 24),

            // Seletor de Época na Timeline
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceSubtle(context),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.border(context)),
              ),
              child: DropdownButton<String>(
                value: selectedEpoch,
                dropdownColor: AppTheme.surface(context),
                underline: const SizedBox(),
                style: TextStyle(
                  color: AppTheme.textPrimary(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                items: const [
                  DropdownMenuItem(value: '1500: Primeiro Contato', child: Text('1500: Primeiro Contato')),
                  DropdownMenuItem(value: '1554: Confederação dos Tamoios', child: Text('1554: Confederação dos Tamoios')),
                  DropdownMenuItem(value: '1567: Fundação do Rio de Janeiro', child: Text('1567: Fundação do Rio de Janeiro')),
                ],
                onChanged: (val) {
                  if (val != null) onEpochChanged(val);
                },
              ),
            ),

            const SizedBox(width: 24),

            // Botões de Ação
            IconButton(
              icon: isLoading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent(context)),
                    )
                  : Icon(Icons.sync, color: AppTheme.textSecondary(context)),
              tooltip: 'Sincronizar do Backend',
              onPressed: isLoading ? null : onSyncBackend,
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.accent(context),
                side: BorderSide(color: AppTheme.accent(context)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.add_location_alt_rounded, size: 18),
              label: const Text(
                '+ Nova Aldeia',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: onAddVillage,
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.save_rounded, size: 18),
              label: const Text(
                'Salvar & Aplicar no Jogo',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: onSaveAndApply,
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent(context),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.cloud_upload, size: 18),
              label: const Text(
                'Publicar Snapshot',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: onPublishSnapshot,
            ),
          ],
        ),
      ),
    );
  }
}
