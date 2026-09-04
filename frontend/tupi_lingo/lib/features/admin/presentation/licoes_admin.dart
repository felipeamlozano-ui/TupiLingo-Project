import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class LicoesAdminTab extends StatefulWidget {
  final List<dynamic> variantes;
  final VoidCallback onRefresh;

  const LicoesAdminTab({
    super.key,
    required this.variantes,
    required this.onRefresh,
  });

  @override
  State<LicoesAdminTab> createState() => _LicoesAdminTabState();
}

class _LicoesAdminTabState extends State<LicoesAdminTab> {
  int? _selectedCapituloId;

  String get _baseUrl => dotenv.env['API_URL'] ?? 'http://127.0.0.1:8000';
  String? get _token => Supabase.instance.client.auth.currentSession?.accessToken;

  List<Map<String, dynamic>> get _allCapitulos {
    final List<Map<String, dynamic>> list = [];
    for (final v in widget.variantes) {
      final caps = v['capitulos'] as List<dynamic>? ?? [];
      for (final c in caps) {
        list.add(Map<String, dynamic>.from(c as Map));
      }
    }
    return list;
  }

  void _showLicaoDialog({Map<String, dynamic>? licao, required int capituloId}) {
    final isEditing = licao != null;
    final numeroController = TextEditingController(text: licao != null ? '${licao['numero']}' : '');
    final tituloController = TextEditingController(text: licao != null ? '${licao['titulo']}' : '');
    final descController = TextEditingController(text: licao != null ? '${licao['descricao']}' : '');
    final xpController = TextEditingController(text: licao != null ? '${licao['xp_base']}' : '25');
    bool publicada = licao != null ? (licao['publicada'] ?? true) : true;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            isEditing ? 'Editar Lição' : 'Nova Lição',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: numeroController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Número da Lição (Ordem)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: tituloController,
                  decoration: const InputDecoration(
                    labelText: 'Título da Lição',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Descrição Curta',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: xpController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'XP Base ao Concluir',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Publicada', style: TextStyle(fontWeight: FontWeight.bold)),
                  value: publicada,
                  activeThumbColor: const Color(0xFF0E5D4E),
                  onChanged: (val) => setDialogState(() => publicada = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final numVal = int.tryParse(numeroController.text.trim());
                final tituloVal = tituloController.text.trim();
                final xpVal = int.tryParse(xpController.text.trim()) ?? 25;

                if (numVal == null || tituloVal.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Preencha número e título.')),
                  );
                  return;
                }

                Navigator.pop(dialogCtx);

                try {
                  final uri = isEditing
                      ? Uri.parse('$_baseUrl/api/v1/admin/trilha/licoes/${licao['id']}/')
                      : Uri.parse('$_baseUrl/api/v1/admin/trilha/licoes/');

                  final body = {
                    'capitulo_id': capituloId,
                    'numero': numVal,
                    'titulo': tituloVal,
                    'descricao': descController.text.trim(),
                    'xp_base': xpVal,
                    'publicada': publicada,
                  };

                  final res = isEditing
                      ? await http.put(
                          uri,
                          headers: {
                            'Authorization': 'Bearer $_token',
                            'Content-Type': 'application/json',
                          },
                          body: jsonEncode(body),
                        )
                      : await http.post(
                          uri,
                          headers: {
                            'Authorization': 'Bearer $_token',
                            'Content-Type': 'application/json',
                          },
                          body: jsonEncode(body),
                        );

                  if (res.statusCode == 200 || res.statusCode == 201) {
                    widget.onRefresh();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: const Color(0xFF0E5D4E),
                          content: Text(isEditing ? 'Lição atualizada!' : 'Lição criada com sucesso!'),
                        ),
                      );
                    }
                  } else {
                    final err = jsonDecode(utf8.decode(res.bodyBytes))['error'] ?? 'Erro ao salvar';
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(backgroundColor: const Color(0xFFD32F2F), content: Text('$err')),
                      );
                    }
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(backgroundColor: const Color(0xFFD32F2F), content: Text('Erro: $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0E5D4E)),
              child: const Text('Salvar', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(int licaoId, String titulo) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Excluir Lição', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Tem certeza que deseja excluir "$titulo"? Todos os exercícios serão apagados.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final res = await http.delete(
                  Uri.parse('$_baseUrl/api/v1/admin/trilha/licoes/$licaoId/'),
                  headers: {'Authorization': 'Bearer $_token'},
                );
                if (res.statusCode == 200) {
                  widget.onRefresh();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(backgroundColor: Color(0xFF0E5D4E), content: Text('Lição excluída com sucesso.')),
                    );
                  }
                }
              } catch (_) {}
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD32F2F)),
            child: const Text('Excluir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final capitulos = _allCapitulos;

    if (capitulos.isEmpty) {
      return const Center(child: Text('Crie um capítulo primeiro para poder adicionar lições.'));
    }

    _selectedCapituloId ??= capitulos.first['id'] as int?;

    final currentCapitulo = capitulos.firstWhere(
      (c) => c['id'] == _selectedCapituloId,
      orElse: () => capitulos.first,
    );

    final licoes = (currentCapitulo['licoes'] as List<dynamic>? ?? []);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      children: [
        // Seletor de Capítulo
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFD0D0D0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              isExpanded: true,
              value: _selectedCapituloId,
              items: capitulos.map((cap) {
                return DropdownMenuItem<int>(
                  value: cap['id'],
                  child: Text(
                    'Cap. ${cap['numero']} • ${cap['titulo']}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                );
              }).toList(),
              onChanged: (newId) => setState(() => _selectedCapituloId = newId),
            ),
          ),
        ),
        const SizedBox(height: 16),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${licoes.length} ${licoes.length == 1 ? "Lição" : "Lições"} neste Capítulo',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Color(0xFF1F2937),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                if (_selectedCapituloId != null) {
                  _showLicaoDialog(capituloId: _selectedCapituloId!);
                }
              },
              icon: const Icon(Icons.add, size: 16, color: Colors.white),
              label: const Text('Nova Lição', style: TextStyle(color: Colors.white, fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0E5D4E),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (licoes.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: Text('Nenhuma lição cadastrada neste capítulo.', style: TextStyle(color: Colors.grey))),
          )
        else
          ...licoes.map((l) {
            final lMap = Map<String, dynamic>.from(l as Map);
            final isPub = lMap['publicada'] == true;

            return Card(
              color: Colors.white,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFD0D0D0)),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFD08A45).withValues(alpha: 0.15),
                  child: Text(
                    '${lMap['numero']}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD08A45)),
                  ),
                ),
                title: Text(
                  lMap['titulo'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                subtitle: Text(
                  '${lMap['xp_base']} XP • ${lMap['total_exercicios']} exercícios',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isPub ? Colors.green.shade50 : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isPub ? 'Ativa' : 'Oculta',
                        style: TextStyle(
                          color: isPub ? Colors.green.shade800 : Colors.orange.shade800,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 18, color: Color(0xFF565D6D)),
                      onPressed: () => _showLicaoDialog(licao: lMap, capituloId: _selectedCapituloId!),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFD32F2F)),
                      onPressed: () => _confirmDelete(lMap['id'], lMap['titulo'] ?? ''),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}
