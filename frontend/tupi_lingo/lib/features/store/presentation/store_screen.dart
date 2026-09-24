import 'package:flutter/material.dart';
import 'package:tupi_lingo/core/theme/app_theme.dart';
import '../models/store_item.dart';
import '../services/store_service.dart';

class StoreScreen extends StatefulWidget {
  final int? initialConchas;

  const StoreScreen({super.key, this.initialConchas});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final StoreService _storeService = StoreService.instance;

  bool _isLoading = true;
  String? _errorMessage;
  int _conchas = 0;
  List<StoreItem> _allItems = [];
  Map<String, String> _equippedItems = {};

  @override
  void initState() {
    super.initState();
    _conchas = widget.initialConchas ?? 0;
    _tabController = TabController(length: 3, vsync: this);
    _loadStoreData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStoreData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _storeService.fetchCatalog();
      if (mounted) {
        setState(() {
          _allItems = result.items;
          _conchas = result.conchas;
          _equippedItems = result.equippedItems;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Não foi possível carregar a Loja Ancestral. Verifique sua conexão.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handlePurchase(StoreItem item) async {
    if (_conchas < item.price) {
      _showInsufficientFundsDialog(item);
      return;
    }

    final confirmed = await _showPurchaseConfirmationDialog(item);
    if (confirmed != true) return;

    // Loading overlay
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.surface(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border(context)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Color(0xFFD08A45)),
              const SizedBox(height: 16),
              Text(
                'Autenticando transação segura...',
                style: TextStyle(
                  color: AppTheme.textPrimary(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Assinatura HMAC-SHA256 em andamento',
                style: TextStyle(
                  color: AppTheme.textSecondary(context),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final result = await _storeService.purchaseCosmetic(item.id);

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // fecha loading

    if (result.success) {
      setState(() {
        _conchas = result.newBalance;
        _allItems = _allItems.map((i) {
          if (i.id == item.id) {
            return i.copyWith(isUnlocked: true);
          }
          return i;
        }).toList();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF0E5D4E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Row(
            children: [
              const Text('✨', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${item.name} desbloqueado com sucesso!',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFE05638),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text(result.message, style: const TextStyle(color: Colors.white)),
        ),
      );
    }
  }

  Future<void> _handleEquip(StoreItem item) async {
    final success = await _storeService.equipCosmetic(item.id);

    if (!mounted) return;

    if (success) {
      setState(() {
        final itemTypeKey = item.type.toServerString();
        _equippedItems[itemTypeKey] = item.id;
        _allItems = _allItems.map((i) {
          if (i.type == item.type) {
            return i.copyWith(isEquipped: i.id == item.id);
          }
          return i;
        }).toList();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF0E5D4E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text(
            '${item.name} agora está ativo no seu aplicativo!',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFE05638),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: const Text('Falha ao equipar item.', style: TextStyle(color: Colors.white)),
        ),
      );
    }
  }

  Future<bool?> _showPurchaseConfirmationDialog(StoreItem item) {
    final isDark = AppTheme.isDark(context);
    final remainingConchas = _conchas - item.price;

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppTheme.border(context)),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: item.previewColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(item.icon, style: const TextStyle(fontSize: 28)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Desbloquear Item',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary(context),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.name,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? const Color(0xFFE69A56) : const Color(0xFFD08A45),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.description,
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary(context)),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C2723) : const Color(0xFFFAF9F5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border(context)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Preço do Item:', style: TextStyle(color: AppTheme.textSecondary(context))),
                      Text('🐚 ${item.price} Conchas', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Saldo Atual:', style: TextStyle(color: AppTheme.textSecondary(context))),
                      Text('🐚 $_conchas', style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Saldo Após Compra:', style: TextStyle(color: AppTheme.textPrimary(context), fontWeight: FontWeight.bold)),
                      Text(
                        '🐚 $remainingConchas',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1EC9A5)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.shield_outlined, size: 14, color: Color(0xFF0E5D4E)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Transação assinada e gravada com integridade criptográfica no cofre.',
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary(context)),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancelar', style: TextStyle(color: AppTheme.textSecondary(context))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD08A45),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Confirmar Troca', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showInsufficientFundsDialog(StoreItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppTheme.border(context)),
        ),
        title: Row(
          children: const [
            Text('🐚', style: TextStyle(fontSize: 24)),
            SizedBox(width: 8),
            Text('Conchas Insuficientes'),
          ],
        ),
        content: Text(
          'Você precisa de mais ${item.price - _conchas} Conchas Sagradas para desbloquear "${item.name}".\n\nPratique lições, complete trilhas ancestrais e colete baús milenares para ganhar mais conchas!',
          style: TextStyle(color: AppTheme.textSecondary(context)),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0E5D4E),
              foregroundColor: Colors.white,
            ),
            child: const Text('Entendido!'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        backgroundColor: AppTheme.bg(context),
        foregroundColor: AppTheme.textPrimary(context),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(_conchas),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Oca das Trocas & Conchas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary(context),
              ),
            ),
            Text(
              'Loja Ancestral de Cosméticos',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary(context),
              ),
            ),
          ],
        ),
        actions: [
          // Conchas badge no topo direito da AppBar
          Container(
            margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF15332B), const Color(0xFF0C241E)]
                    : [const Color(0xFFE4F7F2), const Color(0xFFD0F0E8)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? const Color(0xFF1EC9A5) : const Color(0xFF2E7D5E),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1EC9A5).withValues(alpha: 0.15),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🐚', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(
                  '$_conchas',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isDark ? const Color(0xFF1EC9A5) : const Color(0xFF0E5D4E),
                  ),
                ),
              ],
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: isDark ? const Color(0xFFE69A56) : const Color(0xFFD08A45),
          unselectedLabelColor: AppTheme.textSecondary(context),
          indicatorColor: isDark ? const Color(0xFFE69A56) : const Color(0xFFD08A45),
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.palette_outlined, size: 20), text: 'Temas'),
            Tab(icon: Icon(Icons.face_outlined, size: 20), text: 'Avatares & Molduras'),
            Tab(icon: Icon(Icons.menu_book_outlined, size: 20), text: 'Lições'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFD08A45)),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('⚠️', style: TextStyle(fontSize: 40)),
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textSecondary(context)),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadStoreData,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Tentar Novamente'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD08A45),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildThemesTab(),
                    _buildAvatarsAndFramesTab(),
                    _buildSpecialLessonsTab(),
                  ],
                ),
    );
  }

  Widget _buildThemesTab() {
    final themes = _allItems.where((i) => i.type == CosmeticType.theme).toList();
    return _buildItemList(
      items: themes,
      emptyMessage: 'Nenhum tema disponível no momento.',
      headerNote: 'Temas alteram as cores das trilhas, botões e elementos da floresta.',
    );
  }

  Widget _buildAvatarsAndFramesTab() {
    final cosmetics = _allItems
        .where((i) => i.type == CosmeticType.avatar || i.type == CosmeticType.frame)
        .toList();
    return _buildItemList(
      items: cosmetics,
      emptyMessage: 'Nenhum avatar ou moldura disponível no momento.',
      headerNote: 'Avatares e molduras sagradas personalizam sua presença nas aldeias e no perfil.',
    );
  }

  Widget _buildSpecialLessonsTab() {
    final lessons = _allItems.where((i) => i.type == CosmeticType.specialLesson).toList();
    return _buildItemList(
      items: lessons,
      emptyMessage: 'Nenhuma lição especial disponível no momento.',
      headerNote: 'Lições com sabedoria ancestral profunda, cantos rituais e botânica sagrada.',
    );
  }

  Widget _buildItemList({
    required List<StoreItem> items,
    required String emptyMessage,
    required String headerNote,
  }) {
    if (items.isEmpty) {
      return Center(
        child: Text(emptyMessage, style: TextStyle(color: AppTheme.textSecondary(context))),
      );
    }

    final isDark = AppTheme.isDark(context);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // Security & Lore Header banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF151E1B) : const Color(0xFFFAF9F5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border(context)),
          ),
          child: Row(
            children: [
              const Icon(Icons.lock_clock_outlined, size: 16, color: Color(0xFF0E5D4E)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  headerNote,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary(context),
                  ),
                ),
              ),
            ],
          ),
        ),

        // List of items
        ...items.map((item) => _buildStoreCard(item)),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildStoreCard(StoreItem item) {
    final isDark = AppTheme.isDark(context);
    final canAfford = _conchas >= item.price;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.isEquipped
              ? const Color(0xFF1EC9A5)
              : (item.isUnlocked
                  ? AppTheme.border(context)
                  : AppTheme.border(context).withValues(alpha: 0.6)),
          width: item.isEquipped ? 2.0 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Preview Icon & Badge
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: item.previewColor.withValues(alpha: isDark ? 0.25 : 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: item.previewColor.withValues(alpha: 0.4)),
              ),
              child: Center(
                child: Text(
                  item.icon,
                  style: const TextStyle(fontSize: 30),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary(context),
                          ),
                        ),
                      ),
                      if (item.isEquipped)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0E5D4E),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'EM USO',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary(context),
                    ),
                  ),
                  if (item.lore.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      '“${item.lore}”',
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: isDark ? const Color(0xFFE69A56) : const Color(0xFFA56627),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),

                  // Bottom Action & Price row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Price display
                      if (!item.isUnlocked)
                        Row(
                          children: [
                            const Text('🐚', style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 4),
                            Text(
                              '${item.price} conchas',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: canAfford
                                    ? (isDark ? const Color(0xFF1EC9A5) : const Color(0xFF0E5D4E))
                                    : const Color(0xFFE05638),
                              ),
                            ),
                          ],
                        )
                      else
                        Row(
                          children: const [
                            Icon(Icons.check_circle, size: 16, color: Color(0xFF1EC9A5)),
                            SizedBox(width: 4),
                            Text(
                              'Desbloqueado',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1EC9A5),
                              ),
                            ),
                          ],
                        ),

                      // Button
                      if (!item.isUnlocked)
                        ElevatedButton(
                          onPressed: () => _handlePurchase(item),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: canAfford
                                ? const Color(0xFFD08A45)
                                : (isDark ? const Color(0xFF263833) : const Color(0xFFE2DFD4)),
                            foregroundColor: canAfford ? Colors.white : Colors.grey,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Desbloquear', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        )
                      else if (item.type != CosmeticType.specialLesson)
                        item.isEquipped
                            ? OutlinedButton(
                                onPressed: null,
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text('Equipado', style: TextStyle(fontSize: 12)),
                              )
                            : OutlinedButton(
                                onPressed: () => _handleEquip(item),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Color(0xFFD08A45)),
                                  foregroundColor: const Color(0xFFD08A45),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text('Equipar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              )
                      else
                        ElevatedButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Acessando lição sagrada: ${item.name}'),
                                backgroundColor: const Color(0xFF0E5D4E),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0E5D4E),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Acessar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
