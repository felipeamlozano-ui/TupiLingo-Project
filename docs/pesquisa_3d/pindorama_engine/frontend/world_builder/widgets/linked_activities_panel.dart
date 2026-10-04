import 'package:flutter/material.dart';
import 'package:tupi_lingo/core/theme/app_theme.dart';
import 'entity_property_helpers.dart';

// Gerencia as lições, quizzes e desafios pedagógicos atrelados a uma aldeia no mapa.
class LinkedActivitiesPanel extends StatelessWidget {
  final Map<String, dynamic> entity;
  final ValueChanged<Map<String, dynamic>> onEntityChanged;

  const LinkedActivitiesPanel({
    super.key,
    required this.entity,
    required this.onEntityChanged,
  });

  // Abre modal com templates rápidos para associar novas atividades didáticas a este ponto do mapa.
  void _showAddActivityDialog(
    BuildContext context,
    List<Map<String, dynamic>> activities,
  ) {
    String selectedType = 'quiz';
    String activityTitle = 'Desafio de Gramática e Vocabulário';
    int exerciseCount = 5;
    int xpReward = 25;

    final templates = [
      {'title': '1. Saudações e Boas-Vindas da Taba', 'type': 'dialogue', 'count': 4, 'xp': 20},
      {'title': '2. Vocabulário: Fauna da Mata Sagrada', 'type': 'vocab', 'count': 6, 'xp': 25},
      {'title': '3. Quiz: Formação de Palavras em Tupi', 'type': 'quiz', 'count': 5, 'xp': 30},
      {'title': '4. Tradução e Transcrição Rupestre', 'type': 'writing', 'count': 3, 'xp': 20},
      {'title': '5. Desafio Cerimonial do Cacique', 'type': 'quiz', 'count': 8, 'xp': 40},
    ];

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surface(dialogCtx),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: AppTheme.border(dialogCtx)),
              ),
              title: Row(
                children: [
                  Icon(Icons.add_task_rounded, color: AppTheme.accent(dialogCtx)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Vincular Atividade à Aldeia',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.textPrimary(dialogCtx),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Modelos Rápidos Pré-configurados:',
                      style: TextStyle(color: AppTheme.textSecondary(dialogCtx), fontSize: 11),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: templates.map((tmpl) {
                        return ActionChip(
                          backgroundColor: AppTheme.surfaceSubtle(dialogCtx),
                          label: Text(
                            tmpl['title'] as String,
                            style: TextStyle(fontSize: 10, color: AppTheme.textPrimary(dialogCtx)),
                          ),
                          onPressed: () {
                            setDialogState(() {
                              activityTitle = tmpl['title'] as String;
                              selectedType = tmpl['type'] as String;
                              exerciseCount = tmpl['count'] as int;
                              xpReward = tmpl['xp'] as int;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    buildFieldLabel(dialogCtx, 'Título da Atividade'),
                    TextFormField(
                      key: ValueKey('act_title_${DateTime.now().millisecondsSinceEpoch}'),
                      initialValue: activityTitle,
                      style: TextStyle(color: AppTheme.textPrimary(dialogCtx), fontSize: 13),
                      decoration: entityInputDecoration(dialogCtx, 'Nome da lição'),
                      onChanged: (val) => activityTitle = val,
                    ),
                    const SizedBox(height: 12),

                    buildFieldLabel(dialogCtx, 'Tipo Pedagógico'),
                    DropdownButtonFormField<String>(
                      initialValue: selectedType,
                      dropdownColor: AppTheme.surface(dialogCtx),
                      style: TextStyle(color: AppTheme.textPrimary(dialogCtx), fontSize: 13),
                      decoration: entityInputDecoration(dialogCtx, ''),
                      items: const [
                        DropdownMenuItem(value: 'quiz', child: Text('❓ Quiz Interativo')),
                        DropdownMenuItem(value: 'vocab', child: Text('📚 Vocabulário Mnemônico')),
                        DropdownMenuItem(value: 'dialogue', child: Text('🗣️ Diálogo com Cacique/NPC')),
                        DropdownMenuItem(value: 'writing', child: Text('✍️ Tradução e Escrita')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedType = val);
                      },
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              buildFieldLabel(dialogCtx, 'Exercícios: $exerciseCount'),
                              Slider(
                                value: exerciseCount.toDouble(),
                                min: 1,
                                max: 15,
                                divisions: 14,
                                activeColor: AppTheme.accent(dialogCtx),
                                label: '$exerciseCount',
                                onChanged: (val) => setDialogState(() => exerciseCount = val.toInt()),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              buildFieldLabel(dialogCtx, 'XP: $xpReward'),
                              Slider(
                                value: xpReward.toDouble(),
                                min: 10,
                                max: 100,
                                divisions: 18,
                                activeColor: const Color(0xFFF59E0B),
                                label: '$xpReward XP',
                                onChanged: (val) => setDialogState(() => xpReward = val.toInt()),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text('Cancelar', style: TextStyle(color: AppTheme.textSecondary(dialogCtx))),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent(dialogCtx),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    final newActivity = {
                      'id': 'act_${DateTime.now().millisecondsSinceEpoch}',
                      'title': activityTitle,
                      'type': selectedType,
                      'exercises_count': exerciseCount,
                      'xp': xpReward,
                    };
                    activities.add(newActivity);
                    entity['linked_activities'] = activities;
                    onEntityChanged(entity);
                    Navigator.pop(dialogCtx);
                  },
                  child: const Text('Vincular'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Monta o item visual de cada atividade na lista com seu respectivo ícone temático e botão de remoção.
  Widget _buildActivityCard(
    BuildContext context,
    Map<String, dynamic> act,
    int idx,
    List<Map<String, dynamic>> activities,
  ) {
    final type = act['type'] ?? 'quiz';
    final title = act['title'] ?? 'Atividade';
    final xp = act['xp'] ?? 20;
    final count = act['exercises_count'] ?? 5;

    IconData icon = Icons.quiz_outlined;
    Color badgeColor = const Color(0xFF10B981);
    String typeName = 'Quiz';
    if (type == 'vocab') {
      icon = Icons.translate_rounded;
      badgeColor = const Color(0xFF38BDF8);
      typeName = 'Vocabulário';
    } else if (type == 'dialogue') {
      icon = Icons.chat_bubble_outline_rounded;
      badgeColor = const Color(0xFFA855F7);
      typeName = 'Diálogo';
    } else if (type == 'writing') {
      icon = Icons.edit_note_rounded;
      badgeColor = const Color(0xFFF59E0B);
      typeName = 'Escrita';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceSubtle(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Row(
        children: [
          Icon(icon, color: badgeColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.textPrimary(context),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        typeName,
                        style: TextStyle(color: badgeColor, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$count exercícios • +$xp XP',
                      style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFEF4444)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Desvincular Atividade',
            onPressed: () {
              activities.removeAt(idx);
              entity['linked_activities'] = activities;
              onEntityChanged(entity);
            },
          ),
        ],
      ),
    );
  }

  // Renderiza a lista de atividades ativas ou o estado vazio informativo.
  @override
  Widget build(BuildContext context) {
    final rawList = (entity['linked_activities'] as List<dynamic>?) ?? [];
    final activities = rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (activities.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceSubtle(context),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border(context)),
            ),
            child: Row(
              children: [
                const Icon(Icons.menu_book_outlined, color: Color(0xFFF59E0B), size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Nenhuma atividade vinculada. Vincule lições e quizzes a este ponto do mapa.',
                    style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 11),
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: activities.length,
            separatorBuilder: (_, _) => const SizedBox(height: 6),
            itemBuilder: (ctx, idx) => _buildActivityCard(context, activities[idx], idx, activities),
          ),
        const SizedBox(height: 10),

        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accent(context),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: const Icon(Icons.add_task_rounded, size: 16),
          label: const Text(
            'Vincular Atividade / Exercício',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          onPressed: () => _showAddActivityDialog(context, activities),
        ),
      ],
    );
  }
}
