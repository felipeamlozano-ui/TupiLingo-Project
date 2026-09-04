import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class CapitulosAdminTab extends StatelessWidget {
  final List<dynamic> variantes;
  final VoidCallback onRefresh;

  const CapitulosAdminTab({
    super.key,
    required this.variantes,
    required this.onRefresh,
  });

  String get _baseUrl => dotenv.env['API_URL'] ?? 'http://127.0.0.1:8000';
  String? get _token => Supabase.instance.client.auth.currentSession?.accessToken;

  void _showCapituloDialog(BuildContext context, {Map<String, dynamic>? capitulo, required int trilhaId}) {
    final isEditing = capitulo != null;
    final numeroController = TextEditingController(text: capitulo != null ? '${capitulo['numero']}' : '');
    final tituloController = TextEditingController(text: capitulo != null ? '${capitulo['titulo']}' : '');
    final descController = TextEditingController(text: capitulo != null ? '${capitulo['descricao']}' : '');
    bool publicado = capitulo != null ? (capitulo['publicado'] ?? true) : true;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            isEditing ? 'Editar Capítulo' : 'Novo Capítulo',
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
                    labelText: 'Número do Capítulo',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: tituloController,
                  decoration: const InputDecoration(
                    labelText: 'Título do Capítulo',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Descrição Narrativa',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Publicado', style: TextStyle(fontWeight: FontWeight.bold)),
                  value: publicado,
                  activeThumbColor: const Color(0xFF0E5D4E),
                  onChanged: (val) => setDialogState(() => publicado = val),
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
                if (numVal == null || tituloVal.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Preencha número e título.')),
                  );
                  return;
                }

                Navigator.pop(dialogCtx);

                try {
                  final uri = isEditing
                      ? Uri.parse('$_baseUrl/api/v1/admin/trilha/capitulos/${capitulo['id']}/')
                      : Uri.parse('$_baseUrl/api/v1/admin/trilha/capitulos/');

                  final body = {
                    'trilha_id': trilhaId,
                    'numero': numVal,
                    'titulo': tituloVal,
                    'descricao': descController.text.trim(),
                    'publicado': publicado,
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
                    onRefresh();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: const Color(0xFF0E5D4E),
                          content: Text(isEditing ? 'Capítulo atualizado!' : 'Capítulo criado com sucesso!'),
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

  void _confirmDelete(BuildContext context, int capituloId, String titulo) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Excluir Capítulo', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Tem certeza que deseja excluir "$titulo"? Todas as lições e exercícios vinculados serão apagados.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final res = await http.delete(
                  Uri.parse('$_baseUrl/api/v1/admin/trilha/capitulos/$capituloId/'),
                  headers: {'Authorization': 'Bearer $_token'},
                );
                if (res.statusCode == 200) {
                  onRefresh();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(backgroundColor: Color(0xFF0E5D4E), content: Text('Capítulo excluído.')),
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
    if (variantes.isEmpty) {
      return const Center(child: Text('Nenhuma variante cadastrada.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      itemCount: variantes.length,
      itemBuilder: (context, vIndex) {
        final v = variantes[vIndex];
        final trilhaId = v['trilha_id'] as int?;
        final capitulos = (v['capitulos'] as List<dynamic>? ?? []);

        return Card(
          color: Colors.white,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFFD0D0D0)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${v['icone']} ${v['nome']}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0E5D4E),
                      ),
                    ),
                    if (trilhaId != null)
                      ElevatedButton.icon(
                        onPressed: () => _showCapituloDialog(context, trilhaId: trilhaId),
                        icon: const Icon(Icons.add, size: 16, color: Colors.white),
                        label: const Text('+ Capítulo', style: TextStyle(color: Colors.white, fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD08A45),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                  ],
                ),
                const Divider(height: 20),
                if (capitulos.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Nenhum capítulo cadastrado nesta variante.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  )
                else
                  ...capitulos.map((cap) {
                    final capMap = Map<String, dynamic>.from(cap as Map);
                    final isPub = capMap['publicado'] == true;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF9F5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFDCD8CB)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0E5D4E).withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${capMap['numero']}',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0E5D4E)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        capMap['titulo'] ?? '',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isPub ? Colors.green.shade50 : Colors.orange.shade50,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isPub ? 'Publicado' : 'Rascunho',
                                        style: TextStyle(
                                          color: isPub ? Colors.green.shade800 : Colors.orange.shade800,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${capMap['total_licoes']} lições',
                                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18, color: Color(0xFF565D6D)),
                            onPressed: () => _showCapituloDialog(context, capitulo: capMap, trilhaId: trilhaId ?? 1),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFD32F2F)),
                            onPressed: () => _confirmDelete(context, capMap['id'], capMap['titulo'] ?? ''),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }
}
