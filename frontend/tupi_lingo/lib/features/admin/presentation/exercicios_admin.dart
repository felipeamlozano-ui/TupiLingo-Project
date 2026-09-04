import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class ExerciciosAdminTab extends StatefulWidget {
  final List<dynamic> variantes;
  final VoidCallback onRefresh;

  const ExerciciosAdminTab({
    super.key,
    required this.variantes,
    required this.onRefresh,
  });

  @override
  State<ExerciciosAdminTab> createState() => _ExerciciosAdminTabState();
}

class _ExerciciosAdminTabState extends State<ExerciciosAdminTab> {
  int? _selectedLicaoId;

  String get _baseUrl => dotenv.env['API_URL'] ?? 'http://127.0.0.1:8000';
  String? get _token => Supabase.instance.client.auth.currentSession?.accessToken;

  List<Map<String, dynamic>> get _allLicoes {
    final List<Map<String, dynamic>> list = [];
    for (final v in widget.variantes) {
      final caps = v['capitulos'] as List<dynamic>? ?? [];
      for (final c in caps) {
        final licoes = c['licoes'] as List<dynamic>? ?? [];
        for (final l in licoes) {
          final lMap = Map<String, dynamic>.from(l as Map);
          lMap['capitulo_numero'] = c['numero'];
          lMap['capitulo_titulo'] = c['titulo'];
          list.add(lMap);
        }
      }
    }
    return list;
  }

  void _showExercicioDialog({Map<String, dynamic>? exercicio, required int licaoId}) {
    final isEditing = exercicio != null;
    String tipo = exercicio != null ? (exercicio['tipo'] ?? 'escolha_multipla') : 'escolha_multipla';
    final enunciadoController = TextEditingController(text: exercicio != null ? (exercicio['enunciado'] ?? '') : '');
    final explicacaoController = TextEditingController(text: exercicio != null ? (exercicio['explicacao'] ?? '') : '');
    final xpController = TextEditingController(text: exercicio != null ? '${exercicio['pontos_base']}' : '10');
    String dificuldade = exercicio != null ? (exercicio['dificuldade'] ?? 'facil') : 'facil';

    // Múltipla Escolha
    final opcoesController = TextEditingController(
      text: exercicio != null && exercicio['opcoes'] is List
          ? (exercicio['opcoes'] as List).join(', ')
          : 'Opção A, Opção B, Opção C, Opção D',
    );
    int respostaCorretaIndice = exercicio != null && exercicio['resposta_correta'] != null
        ? (exercicio['resposta_correta'] as int)
        : 0;

    // Completar Lacunas
    final lacunasController = TextEditingController(
      text: exercicio != null ? (exercicio['texto_com_lacunas'] ?? '') : 'Ao ver o pajé, o guerreiro disse: "___!"',
    );
    final respostasLacunasController = TextEditingController(
      text: exercicio != null && exercicio['respostas_corretas'] is List
          ? (exercicio['respostas_corretas'] as List).join(', ')
          : 'Kauê',
    );

    // Associação
    final colEsqController = TextEditingController(
      text: exercicio != null && exercicio['coluna_esquerda'] is List
          ? (exercicio['coluna_esquerda'] as List).join(', ')
          : 'Tupã, Taba, Kunhã',
    );
    final colDirController = TextEditingController(
      text: exercicio != null && exercicio['coluna_direita'] is List
          ? (exercicio['coluna_direita'] as List).join(', ')
          : 'Deus do Trovão, Aldeia, Mulher',
    );

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Text(
            isEditing ? 'Editar Exercício' : 'Novo Exercício',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Seletor de Tipo
                  const Text('Tipo de Exercício', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: tipo,
                    decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    items: const [
                      DropdownMenuItem(value: 'escolha_multipla', child: Text('Múltipla Escolha')),
                      DropdownMenuItem(value: 'completar', child: Text('Completar Lacunas (___)')),
                      DropdownMenuItem(value: 'associacao', child: Text('Associação de Pares')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => tipo = val);
                    },
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: enunciadoController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Enunciado da Questão',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Campos Específicos por Tipo
                  if (tipo == 'escolha_multipla') ...[
                    TextField(
                      controller: opcoesController,
                      decoration: const InputDecoration(
                        labelText: 'Opções (separadas por vírgula)',
                        hintText: 'Ex: Kauê, Pirá, Tupã, Taba',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      initialValue: respostaCorretaIndice,
                      decoration: const InputDecoration(
                        labelText: 'Opção Correta (0 = primeira)',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('1ª Opção (Índice 0)')),
                        DropdownMenuItem(value: 1, child: Text('2ª Opção (Índice 1)')),
                        DropdownMenuItem(value: 2, child: Text('3ª Opção (Índice 2)')),
                        DropdownMenuItem(value: 3, child: Text('4ª Opção (Índice 3)')),
                      ],
                      onChanged: (val) => setDialogState(() => respostaCorretaIndice = val ?? 0),
                    ),
                  ] else if (tipo == 'completar') ...[
                    TextField(
                      controller: lacunasController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Texto com Lacunas (use ___ para marcar)',
                        hintText: 'Ex: O sol em tupi é ___',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: respostasLacunasController,
                      decoration: const InputDecoration(
                        labelText: 'Respostas aceitas (separadas por vírgula)',
                        hintText: 'Ex: Kûarasy, Kuarasu',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ] else if (tipo == 'associacao') ...[
                    TextField(
                      controller: colEsqController,
                      decoration: const InputDecoration(
                        labelText: 'Coluna Esquerda (separada por vírgula)',
                        hintText: 'Ex: Kauê, Kunhã, Taba',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: colDirController,
                      decoration: const InputDecoration(
                        labelText: 'Coluna Direita (pares na mesma ordem)',
                        hintText: 'Ex: Olá, Mulher, Aldeia',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),
                  TextField(
                    controller: explicacaoController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Explicação Cultural (pós-resposta)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: dificuldade,
                          decoration: const InputDecoration(labelText: 'Dificuldade', border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: 'facil', child: Text('Fácil')),
                            DropdownMenuItem(value: 'media', child: Text('Média')),
                            DropdownMenuItem(value: 'dificil', child: Text('Difícil')),
                          ],
                          onChanged: (val) => setDialogState(() => dificuldade = val ?? 'facil'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: xpController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'XP Base', border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                final enunciado = enunciadoController.text.trim();
                final xp = int.tryParse(xpController.text.trim()) ?? 10;
                if (enunciado.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe o enunciado.')));
                  return;
                }

                final Map<String, dynamic> payload = {
                  'licao_id': licaoId,
                  'tipo': tipo,
                  'enunciado': enunciado,
                  'explicacao': explicacaoController.text.trim(),
                  'dificuldade': dificuldade,
                  'pontos_base': xp,
                };

                if (tipo == 'escolha_multipla') {
                  final opts = opcoesController.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
                  if (opts.length < 2) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe ao menos 2 opções.')));
                    return;
                  }
                  payload['opcoes'] = opts;
                  payload['resposta_correta'] = respostaCorretaIndice.clamp(0, opts.length - 1);
                } else if (tipo == 'completar') {
                  final texto = lacunasController.text.trim();
                  final resps = respostasLacunasController.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
                  if (!texto.contains('___') || resps.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Texto deve ter ___ e ao menos uma resposta.')));
                    return;
                  }
                  payload['texto_com_lacunas'] = texto;
                  payload['respostas_corretas'] = resps;
                  payload['tolerancia_levenshtein'] = 2;
                } else if (tipo == 'associacao') {
                  final esq = colEsqController.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
                  final dir = colDirController.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
                  if (esq.length < 2 || dir.length < 2 || esq.length != dir.length) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('As duas colunas devem ter a mesma quantidade (mín 2).')));
                    return;
                  }
                  final Map<String, String> assoc = {};
                  for (int i = 0; i < esq.length; i++) {
                    assoc['$i'] = '$i';
                  }
                  payload['coluna_esquerda'] = esq;
                  payload['coluna_direita'] = dir;
                  payload['associacao_correta'] = assoc;
                }

                Navigator.pop(dialogCtx);

                try {
                  final uri = isEditing
                      ? Uri.parse('$_baseUrl/api/v1/admin/trilha/exercicios/${exercicio['id']}/')
                      : Uri.parse('$_baseUrl/api/v1/admin/trilha/exercicios/');

                  final res = isEditing
                      ? await http.put(
                          uri,
                          headers: {
                            'Authorization': 'Bearer $_token',
                            'Content-Type': 'application/json',
                          },
                          body: jsonEncode(payload),
                        )
                      : await http.post(
                          uri,
                          headers: {
                            'Authorization': 'Bearer $_token',
                            'Content-Type': 'application/json',
                          },
                          body: jsonEncode(payload),
                        );

                  if (res.statusCode == 200 || res.statusCode == 201) {
                    widget.onRefresh();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: const Color(0xFF0E5D4E),
                          content: Text(isEditing ? 'Exercício atualizado!' : 'Exercício criado com sucesso!'),
                        ),
                      );
                    }
                  } else {
                    final err = jsonDecode(utf8.decode(res.bodyBytes))['error'] ?? 'Erro ao salvar';
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: const Color(0xFFD32F2F), content: Text('$err')));
                    }
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: const Color(0xFFD32F2F), content: Text('Erro: $e')));
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

  void _confirmDelete(int exId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Excluir Exercício', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Tem certeza que deseja excluir este exercício?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final res = await http.delete(
                  Uri.parse('$_baseUrl/api/v1/admin/trilha/exercicios/$exId/'),
                  headers: {'Authorization': 'Bearer $_token'},
                );
                if (res.statusCode == 200) {
                  widget.onRefresh();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(backgroundColor: Color(0xFF0E5D4E), content: Text('Exercício excluído com sucesso.')),
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

  String _tipoFormatado(String tipo) {
    switch (tipo) {
      case 'escolha_multipla': return 'Múltipla Escolha';
      case 'completar': return 'Completar Lacunas';
      case 'associacao': return 'Associação';
      default: return tipo;
    }
  }

  @override
  Widget build(BuildContext context) {
    final licoes = _allLicoes;

    if (licoes.isEmpty) {
      return const Center(child: Text('Cadastre lições primeiro para poder criar exercícios.'));
    }

    _selectedLicaoId ??= licoes.first['id'] as int?;

    final currentLicao = licoes.firstWhere(
      (l) => l['id'] == _selectedLicaoId,
      orElse: () => licoes.first,
    );

    final exercicios = (currentLicao['exercicios'] as List<dynamic>? ?? []);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      children: [
        // Seletor de Lição
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
              value: _selectedLicaoId,
              items: licoes.map((lic) {
                return DropdownMenuItem<int>(
                  value: lic['id'],
                  child: Text(
                    'Cap. ${lic['capitulo_numero']} > Lição ${lic['numero']}: ${lic['titulo']}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (newId) => setState(() => _selectedLicaoId = newId),
            ),
          ),
        ),
        const SizedBox(height: 16),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${exercicios.length} ${exercicios.length == 1 ? "Exercício" : "Exercícios"}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1F2937)),
            ),
            ElevatedButton.icon(
              onPressed: () {
                if (_selectedLicaoId != null) {
                  _showExercicioDialog(licaoId: _selectedLicaoId!);
                }
              },
              icon: const Icon(Icons.add, size: 16, color: Colors.white),
              label: const Text('Novo Exercício', style: TextStyle(color: Colors.white, fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD08A45),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (exercicios.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: Text('Nenhum exercício cadastrado nesta lição.', style: TextStyle(color: Colors.grey))),
          )
        else
          ...exercicios.map((ex) {
            final exMap = Map<String, dynamic>.from(ex as Map);

            return Card(
              color: Colors.white,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFD0D0D0)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0E5D4E).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _tipoFormatado(exMap['tipo'] ?? ''),
                            style: const TextStyle(
                              color: Color(0xFF0E5D4E),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              '+${exMap['pontos_base']} XP',
                              style: const TextStyle(color: Color(0xFFD08A45), fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18, color: Color(0xFF565D6D)),
                              onPressed: () => _showExercicioDialog(exercicio: exMap, licaoId: _selectedLicaoId!),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFD32F2F)),
                              onPressed: () => _confirmDelete(exMap['id']),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      exMap['enunciado'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1F2937)),
                    ),
                    if ((exMap['explicacao'] ?? '').toString().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Explicação: ${exMap['explicacao']}',
                        style: const TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}
