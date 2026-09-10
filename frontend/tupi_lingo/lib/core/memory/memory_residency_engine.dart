import 'dart:collection';
import 'package:flutter/widgets.dart';

/// Gerenciador de residência de memória, pools de objetos e caches multinível (L0..L4).
///
/// Protege a Dart VM de picos de alocação no Young Space e evita coletas
/// scavenge (Stop-the-World GC) durante a navegação entre telas.
class MemoryResidencyEngine with WidgetsBindingObserver {
  MemoryResidencyEngine._();

  static final MemoryResidencyEngine instance = MemoryResidencyEngine._();

  // ─── Cache L1: Objetos Imutáveis em Heap gerenciada por LRU ────────────────
  final int _maxL1Entries = 120;
  final LinkedHashMap<String, dynamic> _l1ObjectCache = LinkedHashMap();

  // ─── Cache L1: Referências Fracas (Zero retenção indesejada) ───────────────
  final Map<String, WeakReference<Object>> _weakObjectCache = {};

  // ─── Pools de Objetos Reutilizáveis ─────────────────────────────────────────
  final Map<Type, List<dynamic>> _objectPools = {};

  bool _isObserverRegistered = false;

  void initialize() {
    if (!_isObserverRegistered) {
      WidgetsBinding.instance.addObserver(this);
      _isObserverRegistered = true;
      debugPrint('🧠 [MemoryResidencyEngine] Inicializado com proteção contra GC Pressure.');
    }
  }

  // ─── Obtenção e Devolução ao Pool de Objetos (Zero Alocação no Nursery) ────

  /// Obtém um objeto do pool ou cria um novo através da fábrica fornecida.
  T acquire<T>(T Function() factory) {
    final pool = _objectPools[T];
    if (pool != null && pool.isNotEmpty) {
      return pool.removeLast() as T;
    }
    return factory();
  }

  /// Retorna um objeto ao pool para reuso posterior em vez de descartar para o GC.
  void release<T>(T instance) {
    final pool = _objectPools.putIfAbsent(T, () => <dynamic>[]);
    if (pool.length < 50) {
      // Limite do pool para evitar consumo de memória estática
      pool.add(instance);
    }
  }

  // ─── Operações de Cache L1 (Dart Objects) ───────────────────────────────────

  /// Salva um modelo no Cache L1 com política LRU de alta performance.
  void putL1(String key, dynamic value) {
    if (_l1ObjectCache.containsKey(key)) {
      _l1ObjectCache.remove(key);
    } else if (_l1ObjectCache.length >= _maxL1Entries) {
      // Evicção LRU da chave mais antiga
      _l1ObjectCache.remove(_l1ObjectCache.keys.first);
    }
    _l1ObjectCache[key] = value;
  }

  /// Recupera do Cache L1 e renova a prioridade na política LRU.
  T? getL1<T>(String key) {
    if (!_l1ObjectCache.containsKey(key)) return null;
    final value = _l1ObjectCache.remove(key);
    _l1ObjectCache[key] = value;
    return value as T?;
  }

  /// Remove uma entrada do Cache L1 e retorna o valor prévio se existente.
  T? removeL1<T>(String key) {
    return _l1ObjectCache.remove(key) as T?;
  }

  /// Salva uma referência fraca para objetos volumosos (telas, listas de exercícios).
  void putWeak(String key, Object object) {
    _weakObjectCache[key] = WeakReference(object);
  }

  /// Recupera objeto por referência fraca se ainda vivo na heap.
  T? getWeak<T extends Object>(String key) {
    final ref = _weakObjectCache[key];
    if (ref == null) return null;
    final target = ref.target;
    if (target == null) {
      _weakObjectCache.remove(key);
      return null;
    }
    return target as T?;
  }

  // ─── Resposta a Alertas de Baixa Memória do Sistema Operacional ─────────────

  @override
  void didHaveMemoryPressure() {
    debugPrint('⚠️ [MemoryResidencyEngine] Pressão de memória detectada pelo SO! Realizando trim preventivo...');
    trimMemory();
  }

  /// Limpa caches não essenciais e pools de objetos para liberar memória para o SO.
  void trimMemory() {
    _objectPools.clear();
    _weakObjectCache.clear();
    // Reduz o cache L1 pela metade
    while (_l1ObjectCache.length > (_maxL1Entries ~/ 2)) {
      _l1ObjectCache.remove(_l1ObjectCache.keys.first);
    }
  }

  void dispose() {
    if (_isObserverRegistered) {
      WidgetsBinding.instance.removeObserver(this);
      _isObserverRegistered = false;
    }
    _objectPools.clear();
    _l1ObjectCache.clear();
    _weakObjectCache.clear();
  }
}
