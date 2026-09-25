import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:tupi_lingo/core/network/api_client.dart';
import 'package:tupi_lingo/core/security/secure_vault.dart';
import '../models/store_item.dart';

class StoreCatalogResult {
  final List<StoreItem> items;
  final int conchas;
  final int xpTotal;
  final Map<String, String> equippedItems;
  final String? signature;

  const StoreCatalogResult({
    required this.items,
    required this.conchas,
    required this.xpTotal,
    required this.equippedItems,
    this.signature,
  });
}

class StorePurchaseResult {
  final bool success;
  final String message;
  final int newBalance;
  final String? receiptSignature;
  final bool alreadyUnlocked;

  const StorePurchaseResult({
    required this.success,
    required this.message,
    required this.newBalance,
    this.receiptSignature,
    this.alreadyUnlocked = false,
  });
}

class StoreService {
  static final StoreService instance = StoreService._internal();
  StoreService._internal();

  static const String _keyLastStoreSignature = 'tupilingo_store_last_sig';
  static const String _keyEquippedTheme = 'tupilingo_cosmetic_equipped_theme';
  static const String _keyEquippedAvatar = 'tupilingo_cosmetic_equipped_avatar';
  static const String _keyEquippedFrame = 'tupilingo_cosmetic_equipped_frame';
  static const String _keyUnlockedItems = 'tupilingo_cosmetics_unlocked_set';
  static const String _keyUserBalanceConchas = 'tupilingo_user_balance_conchas';

  String get _baseUrl => dotenv.env['API_URL'] ?? 'http://127.0.0.1:8000';

  /// Catálogo canônico da Loja Ancestral contendo os 16 itens oficiais
  /// (4 temas, 5 avatares, 4 molduras e 3 lições especiais).
  static const List<Map<String, dynamic>> canonicalCatalogJson = [
    // --- TEMAS ---
    {
      'id': 'theme_floresta_jade',
      'type': 'theme',
      'name': 'Floresta de Jade',
      'description': 'Paleta verde esmeralda clássica com raízes ancestrais da Mata Atlântica.',
      'price': 0,
      'is_default': true,
      'preview_colors': ['#0E5D4E', '#10B981', '#F59E0B'],
      'preview_color': '#0E5D4E',
      'icon': '🌿',
      'lore': 'Inspirado na sabedoria dos pajés e no coração da grande floresta.',
    },
    {
      'id': 'theme_areia_sagrada',
      'type': 'theme',
      'name': 'Areia Sagrada de Pindorama',
      'description': 'Dourado ocre caloroso inspirado nas dunas e praias intocadas da costa brasileira.',
      'price': 40,
      'is_default': false,
      'preview_colors': ['#D08A45', '#F59E0B', '#FFFBEB'],
      'preview_color': '#D08A45',
      'icon': '🏖️',
      'lore': 'As areias onde os ancestrais caminharam sob o sol de Tupã.',
    },
    {
      'id': 'theme_noite_tupa',
      'type': 'theme',
      'name': 'Noite Estrelada de Tupã',
      'description': 'Tema escuro profundo com constelações indígenas (Homem Velho, Ema) e ciano estelar.',
      'price': 80,
      'is_default': false,
      'preview_colors': ['#060B15', '#0284C7', '#38BDF8'],
      'preview_color': '#0284C7',
      'icon': '🌌',
      'lore': 'Sob o céu estrelado, os guardiões contam as histórias da criação.',
    },
    {
      'id': 'theme_fogo_caapora',
      'type': 'theme',
      'name': 'Chama Sagrada da Caapora',
      'description': 'Rubi e urucum flamejante com a energia protetora dos espíritos guardiões.',
      'price': 120,
      'is_default': false,
      'preview_colors': ['#7F1D1D', '#DC2626', '#F97316'],
      'preview_color': '#DC2626',
      'icon': '🔥',
      'lore': 'O fogo sagrado que purifica os caminhos e espanta as sombras.',
    },

    // --- AVATARES ---
    {
      'id': 'avatar_arara',
      'type': 'avatar',
      'name': 'Arara Canindé',
      'description': 'O mensageiro alado das altas copas da floresta.',
      'price': 0,
      'is_default': true,
      'icon': '🦜',
      'preview_color': '#0284C7',
      'lore': 'Suas penas de ouro e anil anunciam a aurora na aldeia.',
    },
    {
      'id': 'avatar_maraka',
      'type': 'avatar',
      'name': 'Guerreiro Maraká',
      'description': 'Marcado com pinturas de urucum e o chocalho cerimonial de guerra.',
      'price': 50,
      'is_default': false,
      'icon': '🏹',
      'preview_color': '#DC2626',
      'lore': 'A coragem inabalável de defender a terra e as tradições.',
    },
    {
      'id': 'avatar_xama',
      'type': 'avatar',
      'name': 'Xamã da Floresta',
      'description': 'Mestre dos cantos de cura e conexão com os espíritos da mata.',
      'price': 75,
      'is_default': false,
      'icon': '🧙‍♂️',
      'preview_color': '#10B981',
      'lore': 'A ponte viva entre os segredos da terra e os céus sagrados.',
    },
    {
      'id': 'avatar_onca',
      'type': 'avatar',
      'name': 'Onça Pintada Mística',
      'description': 'O predador supremo e guardião da sabedoria silenciosa.',
      'price': 100,
      'is_default': false,
      'icon': '🐆',
      'preview_color': '#F59E0B',
      'lore': 'A força veloz que espreita nas sombras da grande mata.',
    },
    {
      'id': 'avatar_tamandua',
      'type': 'avatar',
      'name': 'Tamanduá Guardião',
      'description': 'Símbolo de persistência e raízes na terra.',
      'price': 60,
      'is_default': false,
      'icon': '🦔',
      'preview_color': '#854D0E',
      'lore': 'A paciência dos antigos para construir e proteger o ninho.',
    },

    // --- MOLDURAS ---
    {
      'id': 'frame_madeira',
      'type': 'frame',
      'name': 'Madeira Rústica',
      'description': 'Borda clássica entalhada em madeira nobre da mata.',
      'price': 0,
      'is_default': true,
      'border_color': '#854D0E',
      'preview_color': '#854D0E',
      'icon': '🪵',
      'lore': 'A firmeza do tronco secular que resiste às tempestades.',
    },
    {
      'id': 'frame_penas',
      'type': 'frame',
      'name': 'Diadema de Penas Sagradas',
      'description': 'Ornamento cerimonial de penas coloridas de gavião e tucano.',
      'price': 60,
      'is_default': false,
      'border_color': '#EF4444',
      'preview_color': '#EF4444',
      'icon': '🪶',
      'lore': 'Usado nas grandes cerimônias de celebração e paz.',
    },
    {
      'id': 'frame_ouro_sol',
      'type': 'frame',
      'name': 'Aura Solar de Guaraci',
      'description': 'Brilho solar radiante e energia divina do meio-dia.',
      'price': 90,
      'is_default': false,
      'border_color': '#F59E0B',
      'preview_color': '#F59E0B',
      'icon': '☀️',
      'lore': 'A luz que alimenta as sementes e aquece os guerreiros.',
    },
    {
      'id': 'frame_grafismo',
      'type': 'frame',
      'name': 'Grafismo Kadiwéu',
      'description': 'Padrões geométricos simétricos de pintura corporal tradicional.',
      'price': 110,
      'is_default': false,
      'border_color': '#10B981',
      'preview_color': '#10B981',
      'icon': '💠',
      'lore': 'A geometria ancestral gravada na pele como memória viva.',
    },

    // --- LIÇÕES ESPECIAIS ---
    {
      'id': 'lesson_cantos_sagrados',
      'type': 'special_lesson',
      'name': 'Cantos Sagrados dos Pajés',
      'description': 'Lição especial: estude a métrica, ritmo e o vocabulário cerimonial das preces antigas.',
      'price': 120,
      'is_default': false,
      'icon': '🎶',
      'preview_color': '#8B5CF6',
      'lore': 'Entoado sob a luz do fogo para invocar as bênçãos dos ancestrais.',
    },
    {
      'id': 'lesson_taticas_caca',
      'type': 'special_lesson',
      'name': 'Táticas de Caça e Rastreamento',
      'description': 'Lição especial: termos de pegadas, ventos, animais da mata e sobrevivência.',
      'price': 150,
      'is_default': false,
      'icon': '🐾',
      'preview_color': '#D97706',
      'lore': 'A arte silenciosa de ler cada detalhe impresso no solo sagrado.',
    },
    {
      'id': 'lesson_ervas_medicinais',
      'type': 'special_lesson',
      'name': 'Farmacopeia e Ervas da Cura',
      'description': 'Lição especial: vocabulário botânico tradicional e as plantas mestras de Pindorama.',
      'price': 180,
      'is_default': false,
      'icon': '🌱',
      'preview_color': '#10B981',
      'lore': 'O conhecimento milenar de folhas, cascas e raízes curativas.',
    },
  ];

  // Busca o catálogo da API ou recorre ao catálogo canônico offline se a API estiver fora do ar
  Future<StoreCatalogResult> fetchCatalog() async {
    try {
      final response = await ApiClient.get('$_baseUrl/api/v1/store/catalog/')
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

        // Trata catalog tanto como List<dynamic> quanto Map<String, dynamic>
        List<dynamic> rawCatalog = [];
        final catalogData = data['catalog'];
        if (catalogData is List) {
          rawCatalog = catalogData;
        } else if (catalogData is Map) {
          for (final list in catalogData.values) {
            if (list is List) {
              rawCatalog.addAll(list);
            }
          }
        }

        final balance = (data['user_balance'] as Map<String, dynamic>?) ?? {};
        final unlockedList = ((data['unlocked_items'] as List<dynamic>?) ?? [])
            .map((e) => e.toString())
            .toSet();
        final equippedMap = ((data['equipped_items'] as Map<String, dynamic>?) ?? {})
            .map((k, v) => MapEntry(k.toString(), v.toString()));

        final security = (data['security'] as Map<String, dynamic>?) ?? {};
        final signature = security['signature'] as String?;

        // Salva assinatura e equipados no cofre protegido por hardware
        if (signature != null && signature.isNotEmpty) {
          await SecureVault.writeSecret(_keyLastStoreSignature, signature);
        }
        if (equippedMap.containsKey('theme')) {
          await SecureVault.writeSecret(_keyEquippedTheme, equippedMap['theme']!);
        }
        if (equippedMap.containsKey('avatar')) {
          await SecureVault.writeSecret(_keyEquippedAvatar, equippedMap['avatar']!);
        }
        if (equippedMap.containsKey('frame')) {
          await SecureVault.writeSecret(_keyEquippedFrame, equippedMap['frame']!);
        }

        // Cache local de desbloqueios e saldo
        if (unlockedList.isNotEmpty) {
          await SecureVault.writeSecret(_keyUnlockedItems, jsonEncode(unlockedList.toList()));
        }
        final conchas = (balance['conchas'] as num?)?.toInt() ?? 0;
        await SecureVault.writeSecret(_keyUserBalanceConchas, conchas.toString());

        final sourceList = rawCatalog.isNotEmpty ? rawCatalog : canonicalCatalogJson;

        final items = sourceList.map((itemJson) {
          final map = itemJson as Map<String, dynamic>;
          final id = map['id']?.toString() ?? '';
          final type = map['type']?.toString() ?? '';
          final isUnlocked = unlockedList.contains(id) || map['is_default'] == true;
          final isEquipped = equippedMap[type] == id;

          return StoreItem.fromJson(
            map,
            isUnlocked: isUnlocked,
            isEquipped: isEquipped,
          );
        }).toList();

        return StoreCatalogResult(
          items: items,
          conchas: conchas,
          xpTotal: (balance['xp_total'] as num?)?.toInt() ?? 0,
          equippedItems: equippedMap,
          signature: signature,
        );
      }
    } catch (_) {
      // Recorre ao catálogo local caso offline ou erro de conexão
    }

    return await getLocalCatalogFallback();
  }

  /// Retorna o catálogo canônico local com estado de cosméticos e conchas salvos em cache
  Future<StoreCatalogResult> getLocalCatalogFallback() async {
    final equippedTheme = await SecureVault.readSecret(_keyEquippedTheme) ?? 'theme_floresta_jade';
    final equippedAvatar = await SecureVault.readSecret(_keyEquippedAvatar) ?? 'avatar_arara';
    final equippedFrame = await SecureVault.readSecret(_keyEquippedFrame) ?? 'frame_madeira';

    final equippedMap = {
      'theme': equippedTheme,
      'avatar': equippedAvatar,
      'frame': equippedFrame,
    };

    final Set<String> unlockedSet = {'theme_floresta_jade', 'avatar_arara', 'frame_madeira'};
    try {
      final savedUnlockedStr = await SecureVault.readSecret(_keyUnlockedItems);
      if (savedUnlockedStr != null && savedUnlockedStr.isNotEmpty) {
        final decoded = jsonDecode(savedUnlockedStr);
        if (decoded is List) {
          unlockedSet.addAll(decoded.map((e) => e.toString()));
        }
      }
    } catch (_) {}

    int savedConchas = 0;
    try {
      final savedConchasStr = await SecureVault.readSecret(_keyUserBalanceConchas);
      if (savedConchasStr != null) {
        savedConchas = int.tryParse(savedConchasStr) ?? 0;
      }
    } catch (_) {}

    final items = canonicalCatalogJson.map((map) {
      final id = map['id']?.toString() ?? '';
      final type = map['type']?.toString() ?? '';
      final isUnlocked = unlockedSet.contains(id) || map['is_default'] == true;
      final isEquipped = equippedMap[type] == id;

      return StoreItem.fromJson(
        map,
        isUnlocked: isUnlocked,
        isEquipped: isEquipped,
      );
    }).toList();

    return StoreCatalogResult(
      items: items,
      conchas: savedConchas,
      xpTotal: 0,
      equippedItems: equippedMap,
    );
  }

  // Executa compra atômica com trava de saldo no backend ou simulação segura local se offline
  Future<StorePurchaseResult> purchaseCosmetic(String itemId) async {
    try {
      final response = await ApiClient.post(
        '$_baseUrl/api/v1/store/purchase/',
        body: {'item_id': itemId},
      ).timeout(const Duration(seconds: 4));

      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

      if (response.statusCode >= 400) {
        final errorMsg = data['error'] as String? ?? 'Erro na compra do item.';
        return StorePurchaseResult(
          success: false,
          message: errorMsg,
          newBalance: (data['current_conchas'] as num?)?.toInt() ?? 0,
        );
      }

      final newBalance = (data['new_balance'] as num?)?.toInt() ?? 0;
      final receipt = (data['receipt'] as Map<String, dynamic>?) ?? {};
      final receiptSig = receipt['receipt_signature'] as String?;

      if (receiptSig != null) {
        await SecureVault.writeSecret('tupilingo_receipt_$itemId', receiptSig);
      }
      await _recordLocalUnlock(itemId, newBalance);

      return StorePurchaseResult(
        success: true,
        message: data['message'] as String? ?? 'Item desbloqueado com sucesso!',
        newBalance: newBalance,
        receiptSignature: receiptSig,
        alreadyUnlocked: data['already_unlocked'] == true,
      );
    } catch (_) {
      // Fallback gracioso offline: deduz saldo localmente e grava desbloqueio
      final item = canonicalCatalogJson.firstWhere(
        (i) => i['id'] == itemId,
        orElse: () => <String, dynamic>{},
      );
      if (item.isEmpty) {
        return const StorePurchaseResult(
          success: false,
          message: 'Item não encontrado no catálogo.',
          newBalance: 0,
        );
      }

      final price = (item['price'] as num?)?.toInt() ?? 0;
      int currentConchas = 0;
      try {
        final savedStr = await SecureVault.readSecret(_keyUserBalanceConchas);
        if (savedStr != null) currentConchas = int.tryParse(savedStr) ?? 0;
      } catch (_) {}

      final newBalance = currentConchas >= price ? currentConchas - price : 0;
      await _recordLocalUnlock(itemId, newBalance);

      return StorePurchaseResult(
        success: true,
        message: 'Item "${item['name']}" desbloqueado com sucesso!',
        newBalance: newBalance,
      );
    }
  }

  Future<void> _recordLocalUnlock(String itemId, int newBalance) async {
    await SecureVault.writeSecret(_keyUserBalanceConchas, newBalance.toString());
    final Set<String> unlockedSet = {'theme_floresta_jade', 'avatar_arara', 'frame_madeira'};
    try {
      final savedUnlockedStr = await SecureVault.readSecret(_keyUnlockedItems);
      if (savedUnlockedStr != null && savedUnlockedStr.isNotEmpty) {
        final decoded = jsonDecode(savedUnlockedStr);
        if (decoded is List) {
          unlockedSet.addAll(decoded.map((e) => e.toString()));
        }
      }
    } catch (_) {}
    unlockedSet.add(itemId);
    await SecureVault.writeSecret(_keyUnlockedItems, jsonEncode(unlockedSet.toList()));
  }

  // Envia requisição para equipar o cosmético e salva a escolha no cofre seguro local
  Future<bool> equipCosmetic(String itemId) async {
    // Identifica o tipo do cosmético no catálogo canônico
    String? itemType;
    final item = canonicalCatalogJson.firstWhere(
      (i) => i['id'] == itemId,
      orElse: () => <String, dynamic>{},
    );
    if (item.isNotEmpty) {
      itemType = item['type']?.toString();
    }

    if (itemType != null) {
      if (itemType == 'theme') {
        await SecureVault.writeSecret(_keyEquippedTheme, itemId);
      } else if (itemType == 'avatar') {
        await SecureVault.writeSecret(_keyEquippedAvatar, itemId);
      } else if (itemType == 'frame') {
        await SecureVault.writeSecret(_keyEquippedFrame, itemId);
      }
    }

    try {
      final response = await ApiClient.post(
        '$_baseUrl/api/v1/store/equip/',
        body: {'item_id': itemId},
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode < 400) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final returnedType = data['item_type'] as String?;
        if (returnedType != null) {
          if (returnedType == 'theme') {
            await SecureVault.writeSecret(_keyEquippedTheme, itemId);
          } else if (returnedType == 'avatar') {
            await SecureVault.writeSecret(_keyEquippedAvatar, itemId);
          } else if (returnedType == 'frame') {
            await SecureVault.writeSecret(_keyEquippedFrame, itemId);
          }
        }
      }
    } catch (_) {}

    return true;
  }

  // Lê do cofre seguro o identificador do cosmético que está ativo
  Future<String?> getEquippedCosmetic(String type) async {
    if (type == 'theme') return await SecureVault.readSecret(_keyEquippedTheme);
    if (type == 'avatar') return await SecureVault.readSecret(_keyEquippedAvatar);
    if (type == 'frame') return await SecureVault.readSecret(_keyEquippedFrame);
    return null;
  }

  static const Map<String, String> defaultEquippedMap = {
    'theme': 'theme_floresta_jade',
    'avatar': 'avatar_arara',
    'frame': 'frame_madeira',
  };

  /// Constrói a lista canônica inicial em memória com os 16 itens oficiais
  static List<StoreItem> getInitialCanonicalItems() {
    return canonicalCatalogJson.map((map) {
      final id = map['id']?.toString() ?? '';
      final type = map['type']?.toString() ?? '';
      final isDefault = map['is_default'] == true;
      final isEquipped = defaultEquippedMap[type] == id;

      return StoreItem.fromJson(
        map,
        isUnlocked: isDefault,
        isEquipped: isEquipped,
      );
    }).toList();
  }
}
