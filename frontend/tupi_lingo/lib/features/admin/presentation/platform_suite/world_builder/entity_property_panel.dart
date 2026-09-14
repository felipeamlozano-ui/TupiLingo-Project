import 'package:flutter/material.dart';

/// Painel lateral de propriedades e inspeção de entidade do World Builder CMS (RFC-013 Capítulo 19).
class EntityPropertyPanel extends StatelessWidget {
  final Map<String, dynamic>? selectedEntity;
  final String entityType;
  final ValueChanged<Map<String, dynamic>> onEntityChanged;
  final VoidCallback onDelete;
  final VoidCallback onClose;

  const EntityPropertyPanel({
    super.key,
    required this.selectedEntity,
    required this.entityType,
    required this.onEntityChanged,
    required this.onDelete,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedEntity == null) {
      return Container(
        width: 320,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withValues(alpha: 0.95),
          border: const Border(left: BorderSide(color: Color(0xFF334155))),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.touch_app, color: Color(0xFF64748B), size: 40),
              SizedBox(height: 12),
              Text(
                'Nenhuma entidade selecionada',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 4),
              Text(
                'Clique em um território, aldeia, rio ou trilha para inspecionar',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF475569), fontSize: 11),
              ),
            ],
          ),
        ),
      );
    }

    final entity = selectedEntity!;
    final nameTupi = entity['name_tupi'] ?? entity['name'] ?? '';
    final namePt = entity['name_portuguese'] ?? '';
    final biome = entity['biome'] ?? 'Mata Atlântica';
    final isVisibleInFog = entity['is_unlocked_default'] ?? false;

    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.95),
        border: const Border(left: BorderSide(color: Color(0xFF334155))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header do Painel
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.tune, color: Color(0xFF10B981), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'PROPRIEDADES: $entityType',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                  onPressed: onClose,
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF334155), height: 1),

          // Formulário de Edição
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildFieldLabel('Nome em Tupi Antigo'),
                TextFormField(
                  initialValue: nameTupi,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: _inputDecoration('Ex: Tupinambá, Piraquara'),
                  onChanged: (val) {
                    entity['name_tupi'] = val;
                    entity['name'] = val;
                    onEntityChanged(entity);
                  },
                ),
                const SizedBox(height: 16),

                _buildFieldLabel('Nome em Português / Tradução'),
                TextFormField(
                  initialValue: namePt,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: _inputDecoration('Ex: Rio dos Peixes'),
                  onChanged: (val) {
                    entity['name_portuguese'] = val;
                    onEntityChanged(entity);
                  },
                ),
                const SizedBox(height: 16),

                _buildFieldLabel('Bioma & Atmosfera'),
                DropdownButtonFormField<String>(
                  initialValue: biome,
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: _inputDecoration(''),
                  items: const [
                    DropdownMenuItem(value: 'Mata Atlântica', child: Text('Mata Atlântica (Costa)')),
                    DropdownMenuItem(value: 'Cerrado', child: Text('Cerrado (Planalto Central)')),
                    DropdownMenuItem(value: 'Amazônia', child: Text('Floresta Amazônica')),
                    DropdownMenuItem(value: 'Caatinga', child: Text('Caatinga (Sertão)')),
                    DropdownMenuItem(value: 'Pantanal', child: Text('Pantanal')),
                    DropdownMenuItem(value: 'Pampa', child: Text('Pampa Sulista')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      entity['biome'] = val;
                      onEntityChanged(entity);
                    }
                  },
                ),
                const SizedBox(height: 16),

                _buildFieldLabel('Visibilidade Inicial (Fog of War)'),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Desbloqueado por Padrão', style: TextStyle(color: Colors.white, fontSize: 13)),
                  subtitle: const Text('Visível sem exploração prévia', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                  value: isVisibleInFog,
                  activeThumbColor: const Color(0xFF10B981),
                  onChanged: (val) {
                    entity['is_unlocked_default'] = val;
                    onEntityChanged(entity);
                  },
                ),
                const SizedBox(height: 16),

                _buildFieldLabel('Descrição Histórica & Contexto'),
                TextFormField(
                  initialValue: entity['description'] ?? '',
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: _inputDecoration('Contexto etnográfico e arqueológico'),
                  onChanged: (val) {
                    entity['description'] = val;
                    onEntityChanged(entity);
                  },
                ),
                const SizedBox(height: 24),

                // Botão de Excluir
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                    side: const BorderSide(color: Color(0xFFEF4444)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Excluir Entidade'),
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF94A3B8),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF475569), fontSize: 12),
      filled: true,
      fillColor: const Color(0xFF1E293B),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF334155)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF334155)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF10B981)),
      ),
    );
  }
}
