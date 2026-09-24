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

  String get _baseUrl => dotenv.env['API_URL'] ?? 'http://127.0.0.1:8000';

  /// Busca o catálogo completo protegido, saldo de conchas e cosméticos equipados
  Future<StoreCatalogResult> fetchCatalog() async {
    final response = await ApiClient.get('$_baseUrl/api/v1/store/catalog/');

    if (response.statusCode != 200) {
      throw Exception('Falha ao carregar catálogo da Loja: ${response.statusCode}');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final rawCatalog = (data['catalog'] as List<dynamic>?) ?? [];
    final balance = (data['user_balance'] as Map<String, dynamic>?) ?? {};
    final unlockedList = ((data['unlocked_items'] as List<dynamic>?) ?? [])
        .map((e) => e.toString())
        .toSet();
    final equippedMap = ((data['equipped_items'] as Map<String, dynamic>?) ?? {})
        .map((k, v) => MapEntry(k.toString(), v.toString()));

    final security = (data['security'] as Map<String, dynamic>?) ?? {};
    final signature = security['signature'] as String?;

    // Salva assinatura de integridade no cofre protegido por hardware
    if (signature != null && signature.isNotEmpty) {
      await SecureVault.writeSecret(_keyLastStoreSignature, signature);
    }

    // Cache local dos equipados
    if (equippedMap.containsKey('theme')) {
      await SecureVault.writeSecret(_keyEquippedTheme, equippedMap['theme']!);
    }
    if (equippedMap.containsKey('avatar')) {
      await SecureVault.writeSecret(_keyEquippedAvatar, equippedMap['avatar']!);
    }
    if (equippedMap.containsKey('frame')) {
      await SecureVault.writeSecret(_keyEquippedFrame, equippedMap['frame']!);
    }

    final items = rawCatalog.map((itemJson) {
      final map = itemJson as Map<String, dynamic>;
      final id = map['id']?.toString() ?? '';
      final type = map['type']?.toString() ?? '';
      final isUnlocked = unlockedList.contains(id);
      final isEquipped = equippedMap[type] == id;

      return StoreItem.fromJson(
        map,
        isUnlocked: isUnlocked,
        isEquipped: isEquipped,
      );
    }).toList();

    return StoreCatalogResult(
      items: items,
      conchas: (balance['conchas'] as num?)?.toInt() ?? 0,
      xpTotal: (balance['xp_total'] as num?)?.toInt() ?? 0,
      equippedItems: equippedMap,
      signature: signature,
    );
  }

  /// Executa compra atômica com trava de saldo no banco de dados e recibo HMAC-SHA256
  Future<StorePurchaseResult> purchaseCosmetic(String itemId) async {
    final response = await ApiClient.post(
      '$_baseUrl/api/v1/store/purchase/',
      body: {'item_id': itemId},
    );

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

    // Salva o recibo criptográfico no cofre seguro
    if (receiptSig != null) {
      await SecureVault.writeSecret('tupilingo_receipt_$itemId', receiptSig);
    }

    return StorePurchaseResult(
      success: true,
      message: data['message'] as String? ?? 'Item desbloqueado com sucesso!',
      newBalance: newBalance,
      receiptSignature: receiptSig,
      alreadyUnlocked: data['already_unlocked'] == true,
    );
  }

  /// Equipa um cosmético desbloqueado
  Future<bool> equipCosmetic(String itemId) async {
    final response = await ApiClient.post(
      '$_baseUrl/api/v1/store/equip/',
      body: {'item_id': itemId},
    );

    if (response.statusCode >= 400) {
      return false;
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final itemType = data['item_type'] as String?;

    if (itemType != null) {
      if (itemType == 'theme') {
        await SecureVault.writeSecret(_keyEquippedTheme, itemId);
      } else if (itemType == 'avatar') {
        await SecureVault.writeSecret(_keyEquippedAvatar, itemId);
      } else if (itemType == 'frame') {
        await SecureVault.writeSecret(_keyEquippedFrame, itemId);
      }
    }

    return true;
  }

  /// Obtém o item equipado salvo em cache
  Future<String?> getEquippedCosmetic(String type) async {
    if (type == 'theme') return await SecureVault.readSecret(_keyEquippedTheme);
    if (type == 'avatar') return await SecureVault.readSecret(_keyEquippedAvatar);
    if (type == 'frame') return await SecureVault.readSecret(_keyEquippedFrame);
    return null;
  }
}
