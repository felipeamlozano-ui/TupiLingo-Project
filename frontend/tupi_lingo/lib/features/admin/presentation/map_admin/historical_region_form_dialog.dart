import 'package:flutter/material.dart';
import 'package:tupi_lingo/features/historical_map/domain/entities/historical_region.dart';

class HistoricalRegionFormDialog extends StatefulWidget {
  final HistoricalRegion? regionToEdit;
  final Function(HistoricalRegion region) onSave;

  const HistoricalRegionFormDialog({
    super.key,
    this.regionToEdit,
    required this.onSave,
  });

  static Future<void> show(
    BuildContext context, {
    HistoricalRegion? regionToEdit,
    required Function(HistoricalRegion region) onSave,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => HistoricalRegionFormDialog(
        regionToEdit: regionToEdit,
        onSave: onSave,
      ),
    );
  }

  @override
  State<HistoricalRegionFormDialog> createState() => _HistoricalRegionFormDialogState();
}

class _HistoricalRegionFormDialogState extends State<HistoricalRegionFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _nationController;
  late final TextEditingController _periodController;
  late final TextEditingController _culturalSummaryController;
  late final TextEditingController _vocabController;

  double _relativeX = 0.5;
  double _relativeY = 0.5;
  bool _isUnlocked = false;
  int _requiredLevel = 1;

  @override
  void initState() {
    super.initState();
    final r = widget.regionToEdit;
    _nameController = TextEditingController(text: r?.name ?? '');
    _nationController = TextEditingController(text: r?.indigenousNation ?? '');
    _periodController = TextEditingController(text: r?.historicalPeriod ?? 'Século XVI');
    _culturalSummaryController = TextEditingController(text: r?.culturalSummary ?? '');
    _vocabController = TextEditingController(
      text: r?.vocabularyHighlights.join(', ') ?? '',
    );
    _relativeX = r?.relativeX ?? 0.5;
    _relativeY = r?.relativeY ?? 0.5;
    _isUnlocked = r?.isUnlocked ?? false;
    _requiredLevel = r?.requiredLevel ?? 1;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nationController.dispose();
    _periodController.dispose();
    _culturalSummaryController.dispose();
    _vocabController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      final vocab = _vocabController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      final region = HistoricalRegion(
        id: widget.regionToEdit?.id ?? DateTime.now().millisecondsSinceEpoch,
        name: _nameController.text.trim(),
        indigenousNation: _nationController.text.trim(),
        historicalPeriod: _periodController.text.trim(),
        relativeX: _relativeX,
        relativeY: _relativeY,
        culturalSummary: _culturalSummaryController.text.trim(),
        vocabularyHighlights: vocab,
        isUnlocked: _isUnlocked,
        requiredLevel: _requiredLevel,
        lessonsCount: widget.regionToEdit?.lessonsCount ?? 5,
        completedLessonsCount: widget.regionToEdit?.completedLessonsCount ?? 0,
      );

      widget.onSave(region);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.regionToEdit != null;

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 550, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Bar do Dialog
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEditing ? '✏️ Editar Aldeia / Região' : '🌿 Nova Aldeia / Região',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF565D6D)),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),

                        // Nome da Região
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Nome da Aldeia / Região Histórica',
                            hintText: 'Ex: Costa dos Tupinambás - Ubatuba',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Campo obrigatório'
                              : null,
                        ),
                        const SizedBox(height: 14),

                        // Nação Indígena & Período
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _nationController,
                                decoration: const InputDecoration(
                                  labelText: 'Nação Indígena',
                                  hintText: 'Ex: Tupinambá, Guarani',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (v) => (v == null || v.trim().isEmpty)
                                    ? 'Campo obrigatório'
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _periodController,
                                decoration: const InputDecoration(
                                  labelText: 'Período Histórico',
                                  hintText: 'Ex: Século XVI',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Seletor Interativo de Coordenadas no Mapa
                        const Text(
                          '📍 Posição no Mapa (Toque para definir as coordenadas):',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        _buildCoordinatePickerMap(),
                        const SizedBox(height: 14),

                        // Resumo Cultural
                        TextFormField(
                          controller: _culturalSummaryController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Resumo Histórico & Lore Cultural',
                            hintText: 'Contexto das tradições, líderes e território...',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Campo obrigatório'
                              : null,
                        ),
                        const SizedBox(height: 14),

                        // Destaques de Vocabulário
                        TextFormField(
                          controller: _vocabController,
                          decoration: const InputDecoration(
                            labelText: 'Destaques de Vocabulário (separados por vírgula)',
                            hintText: 'Ex: Taba, Karai, Tupã, Maracá',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Status Desbloqueado e Nível Mínimo
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Switch(
                                  value: _isUnlocked,
                                  activeThumbColor: const Color(0xFF0E5D4E),
                                  onChanged: (val) => setState(() => _isUnlocked = val),
                                ),
                                Text(
                                  _isUnlocked ? 'Desbloqueada' : 'Bloqueada por Padrão',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                const Text('Nível Requerido: ', style: TextStyle(fontSize: 12)),
                                DropdownButton<int>(
                                  value: _requiredLevel,
                                  items: List.generate(10, (i) => i + 1).map((lvl) {
                                    return DropdownMenuItem(value: lvl, child: Text('$lvl'));
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) setState(() => _requiredLevel = val);
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancelar', style: TextStyle(color: Color(0xFF565D6D))),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0E5D4E),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                      label: Text(
                        isEditing ? 'Atualizar Aldeia' : 'Salvar Aldeia',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCoordinatePickerMap() {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F2E8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD0D0D0)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;

          return GestureDetector(
            onTapDown: (details) {
              final localPos = details.localPosition;
              setState(() {
                _relativeX = (localPos.dx / w).clamp(0.05, 0.95);
                _relativeY = (localPos.dy / h).clamp(0.05, 0.95);
              });
            },
            child: Stack(
              children: [
                const Center(
                  child: Text(
                    'Toque no mapa para posicionar o pino\n[ X: 0.0 - 1.0  |  Y: 0.0 - 1.0 ]',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF8C867A), fontSize: 11),
                  ),
                ),
                // Pino posicionado
                Positioned(
                  left: (_relativeX * w) - 12,
                  top: (_relativeY * h) - 24,
                  child: const Icon(
                    Icons.location_on_rounded,
                    color: Color(0xFFD08A45),
                    size: 26,
                  ),
                ),
                Positioned(
                  right: 8,
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'X: ${(_relativeX * 100).toInt()}%  Y: ${(_relativeY * 100).toInt()}%',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
