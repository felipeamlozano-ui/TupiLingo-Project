import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tupi_lingo/core/theme/app_theme.dart';
import 'package:tupi_lingo/features/dashboard/data/repositories/dashboard_repository_impl.dart';
import 'package:tupi_lingo/features/historical_map/data/datasources/historical_map_remote_data_source.dart';

class LanguageSwitcherBottomSheet extends StatefulWidget {
  final int varianteIdAtiva;
  final Function(Map<String, dynamic> variante, bool precisaNivelar) onVarianteSelected;

  static List<Map<String, dynamic>>? cachedVariantes;

  static Future<void> preloadVariantes() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      final baseUrl = dotenv.env['API_URL'] ?? 'http://127.0.0.1:8000';
      final res = await http.get(
        Uri.parse('$baseUrl/api/v1/trilha/variantes/'),
        headers: {
          'Content-Type': 'application/json',
          if (session != null) 'Authorization': 'Bearer ${session.accessToken}',
        },
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        if (data['success'] == true && data['variantes'] is List) {
          cachedVariantes = List<Map<String, dynamic>>.from(data['variantes']);
        }
      }
    } catch (_) {}
  }

  const LanguageSwitcherBottomSheet({
    super.key,
    required this.varianteIdAtiva,
    required this.onVarianteSelected,
  });

  @override
  State<LanguageSwitcherBottomSheet> createState() => _LanguageSwitcherBottomSheetState();
}

class _LanguageSwitcherBottomSheetState extends State<LanguageSwitcherBottomSheet> {
  bool _isLoading = true;
  int? _updatingVarianteId;
  String? _error;
  List<Map<String, dynamic>> _variantes = [];

  static const Color _primary = Color(0xFF0E5D4E);

  @override
  void initState() {
    super.initState();
    if (LanguageSwitcherBottomSheet.cachedVariantes != null &&
        LanguageSwitcherBottomSheet.cachedVariantes!.isNotEmpty) {
      _variantes = List.from(LanguageSwitcherBottomSheet.cachedVariantes!);
      _isLoading = false;
    }
    _fetchVariantes();
  }

  Future<void> _fetchVariantes() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      final baseUrl = dotenv.env['API_URL'] ?? 'http://127.0.0.1:8000';
      final res = await http.get(
        Uri.parse('$baseUrl/api/v1/trilha/variantes/'),
        headers: {
          'Content-Type': 'application/json',
          if (session != null) 'Authorization': 'Bearer ${session.accessToken}',
        },
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        if (data['success'] == true && data['variantes'] is List) {
          final loaded = List<Map<String, dynamic>>.from(data['variantes']);
          LanguageSwitcherBottomSheet.cachedVariantes = loaded;
          if (mounted) {
            setState(() {
              _variantes = loaded;
              _isLoading = false;
            });
            return;
          }
        }
      }
      throw Exception('Não foi possível carregar as variantes.');
    } catch (e) {
      if (mounted) {
        setState(() {
          if (_variantes.isEmpty) {
            _error = e.toString();
          }
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectVariante(Map<String, dynamic> v) async {
    final int vId = (v['id'] as num).toInt();
    if (vId == widget.varianteIdAtiva) {
      Navigator.pop(context);
      return;
    }

    setState(() => _updatingVarianteId = vId);

    try {
      final session = Supabase.instance.client.auth.currentSession;
      final baseUrl = dotenv.env['API_URL'] ?? 'http://127.0.0.1:8000';

      final res = await http.post(
        Uri.parse('$baseUrl/api/v1/auth/update-variante'),
        headers: {
          'Content-Type': 'application/json',
          if (session != null) 'Authorization': 'Bearer ${session.accessToken}',
        },
        body: jsonEncode({'variante_id': vId}),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        final bool precisaNivelar = data['precisa_nivelar'] == true;

        HistoricalMapRemoteDataSourceImpl.invalidateCache();
        DashboardRepositoryImpl.invalidateCache();

        if (mounted) {
          Navigator.pop(context);
          widget.onVarianteSelected(v, precisaNivelar);
        }
      } else {
        throw Exception('Erro ao atualizar variante ativa');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _updatingVarianteId = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        24 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.border(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('🌿', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Text(
                    'Selecione o Idioma',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary(context),
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, color: AppTheme.textSecondary(context)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Explore diferentes troncos e variações históricas das línguas Tupi.',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary(context)),
          ),
          const SizedBox(height: 18),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: CircularProgressIndicator(color: _primary),
              ),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _isLoading = true;
                        _error = null;
                      });
                      _fetchVariantes();
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: _primary),
                    child: const Text('Tentar Novamente'),
                  ),
                ],
              ),
            )
          else ...[
            ..._variantes.map((v) {
              final int vId = (v['id'] as num).toInt();
              final bool isSelected = vId == widget.varianteIdAtiva;
              final bool isUpdating = _updatingVarianteId == vId;
              final String nome = v['nome']?.toString() ?? 'Tupi';
              final String icone = v['icone']?.toString() ?? '🌿';
              final String desc = v['descricao']?.toString() ?? '';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: isUpdating ? null : () => _selectVariante(v),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _primary.withValues(alpha: 0.12)
                          : AppTheme.surfaceSubtle(context),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isSelected ? _primary : AppTheme.border(context),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? _primary.withValues(alpha: 0.18)
                                : AppTheme.surface(context),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppTheme.border(context)),
                          ),
                          child: Center(
                            child: Text(icone, style: const TextStyle(fontSize: 24)),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    nome,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? _primary : AppTheme.textPrimary(context),
                                    ),
                                  ),
                                  if (isSelected) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _primary,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Text(
                                        'ATIVO',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (desc.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  desc,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary(context),
                                    height: 1.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (isUpdating)
                          const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2, color: _primary),
                          )
                        else if (isSelected)
                          const Icon(Icons.check_circle_rounded, color: _primary, size: 22)
                        else
                          Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary(context), size: 22),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
