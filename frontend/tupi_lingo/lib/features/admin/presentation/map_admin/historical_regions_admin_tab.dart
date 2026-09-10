import 'package:flutter/material.dart';
import 'package:tupi_lingo/features/historical_map/data/repositories/historical_map_repository_impl.dart';
import 'package:tupi_lingo/features/historical_map/domain/entities/historical_region.dart';
import 'package:tupi_lingo/features/historical_map/domain/repositories/historical_map_repository.dart';
import 'historical_region_form_dialog.dart';

class HistoricalRegionsAdminTab extends StatefulWidget {
  final VoidCallback? onRefresh;

  const HistoricalRegionsAdminTab({super.key, this.onRefresh});

  @override
  State<HistoricalRegionsAdminTab> createState() => _HistoricalRegionsAdminTabState();
}

class _HistoricalRegionsAdminTabState extends State<HistoricalRegionsAdminTab> {
  final HistoricalMapRepository _repository = HistoricalMapRepositoryImpl();
  List<HistoricalRegion> _regions = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadRegions();
  }

  Future<void> _loadRegions() async {
    setState(() => _isLoading = true);
    final list = await _repository.getHistoricalRegions();
    if (mounted) {
      setState(() {
        _regions = list;
        _isLoading = false;
      });
    }
  }

  void _openCreateDialog() {
    HistoricalRegionFormDialog.show(
      context,
      onSave: (newRegion) async {
        await _repository.createRegion(newRegion);
        _loadRegions();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF0E5D4E),
            content: Text('Aldeia cadastrada com sucesso!'),
          ),
        );
      },
    );
  }

  void _openEditDialog(HistoricalRegion region) {
    HistoricalRegionFormDialog.show(
      context,
      regionToEdit: region,
      onSave: (updated) async {
        await _repository.updateRegion(updated);
        _loadRegions();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF0E5D4E),
            content: Text('Aldeia atualizada com sucesso!'),
          ),
        );
      },
    );
  }

  void _confirmDelete(HistoricalRegion region) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Aldeia'),
        content: Text('Tem certeza que deseja remover "${region.name}" do mapa?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD32F2F)),
            onPressed: () async {
              Navigator.pop(ctx);
              await _repository.deleteRegion(region.id);
              _loadRegions();
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _regions.where((r) {
      final q = _searchQuery.toLowerCase();
      return r.name.toLowerCase().contains(q) ||
          r.indigenousNation.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF3F2E8),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0E5D4E),
        icon: const Icon(Icons.add_location_alt_rounded, color: Colors.white),
        label: const Text('Nova Aldeia', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: _openCreateDialog,
      ),
      body: Column(
        children: [
          // Campo de Busca
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                hintText: 'Buscar por aldeia ou povo indígena...',
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF0E5D4E)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF0E5D4E)))
                : filtered.isEmpty
                    ? const Center(
                        child: Text(
                          'Nenhuma aldeia histórica encontrada.',
                          style: TextStyle(color: Color(0xFF565D6D)),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final r = filtered[index];
                          return Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                            elevation: 1.5,
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: r.isUnlocked
                                          ? const Color(0xFF0E5D4E).withValues(alpha: 0.12)
                                          : Colors.grey.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Text(
                                      r.isUnlocked ? '🏹' : '🔒',
                                      style: const TextStyle(fontSize: 22),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          r.name,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1F2937),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Text(
                                              r.indigenousNation,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFFD08A45),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '• (${(r.relativeX * 100).toInt()}%, ${(r.relativeY * 100).toInt()}%)',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF565D6D),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          r.culturalSummary,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF565D6D)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_rounded, color: Color(0xFF0E5D4E), size: 20),
                                        tooltip: 'Editar Aldeia',
                                        onPressed: () => _openEditDialog(r),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFD32F2F), size: 20),
                                        tooltip: 'Excluir Aldeia',
                                        onPressed: () => _confirmDelete(r),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
