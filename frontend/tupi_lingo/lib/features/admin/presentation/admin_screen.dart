import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'capitulos_admin.dart';
import 'licoes_admin.dart';
import 'exercicios_admin.dart';
import 'map_admin/historical_regions_admin_tab.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _variantes = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAdminData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAdminData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Sessão não encontrada.';
        });
        return;
      }

      final baseUrl = dotenv.env['API_URL'] ?? 'http://127.0.0.1:8000';
      final res = await http.get(
        Uri.parse('$baseUrl/api/v1/admin/trilha/dados/'),
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final dynamic data = jsonDecode(utf8.decode(res.bodyBytes));
        if (data is Map<String, dynamic> && data['success'] == true) {
          if (mounted) {
            setState(() {
              _variantes = data['variantes'] as List<dynamic>? ?? [];
              _isLoading = false;
            });
          }
          return;
        }
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Falha ao carregar dados administrativos (Status ${res.statusCode})';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Erro ao conectar com o servidor: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F2E8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Row(
          children: [
            Text('⚙️', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text(
              'Gerenciador de Conteúdo',
              style: TextStyle(
                color: Color(0xFF1F2937),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0E5D4E)),
            tooltip: 'Atualizar Dados',
            onPressed: _loadAdminData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF0E5D4E),
          unselectedLabelColor: const Color(0xFF565D6D),
          indicatorColor: const Color(0xFF0E5D4E),
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'Capítulos', icon: Icon(Icons.menu_book_rounded, size: 20)),
            Tab(text: 'Lições', icon: Icon(Icons.bookmark_added_rounded, size: 20)),
            Tab(text: 'Exercícios', icon: Icon(Icons.quiz_rounded, size: 20)),
            Tab(text: 'Mapa & Aldeias', icon: Icon(Icons.explore_rounded, size: 20)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0E5D4E)))
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.lock_outline_rounded, color: Color(0xFFD32F2F), size: 48),
                      const SizedBox(height: 12),
                      Text(_errorMessage!, style: const TextStyle(color: Color(0xFF565D6D))),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadAdminData,
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0E5D4E)),
                        child: const Text('Tentar Novamente', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    CapitulosAdminTab(variantes: _variantes, onRefresh: _loadAdminData),
                    LicoesAdminTab(variantes: _variantes, onRefresh: _loadAdminData),
                    ExerciciosAdminTab(variantes: _variantes, onRefresh: _loadAdminData),
                    HistoricalRegionsAdminTab(onRefresh: _loadAdminData),
                  ],
                ),
    );
  }
}
