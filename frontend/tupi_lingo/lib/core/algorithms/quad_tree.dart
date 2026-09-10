import 'dart:ui';

/// Elemento espacial indexável na QuadTree com Bounding Box (Rect) e payload [T].
class SpatialItem<T> {
  final Rect bounds;
  final T data;

  const SpatialItem({required this.bounds, required this.data});
}

/// Estrutura de dados espacial QuadTree em 2D.
/// Permite inserção e consulta de intersecção/ponto em tempo O(log n),
/// eliminando a necessidade de iterar sobre centenas de polígonos na UI a cada toque.
class SpatialQuadTree<T> {
  final Rect boundary;
  final int capacity;
  final int maxDepth;
  final int depth;

  final List<SpatialItem<T>> _items = [];
  bool _divided = false;

  SpatialQuadTree<T>? _northWest;
  SpatialQuadTree<T>? _northEast;
  SpatialQuadTree<T>? _southWest;
  SpatialQuadTree<T>? _southEast;

  SpatialQuadTree({
    required this.boundary,
    this.capacity = 4,
    this.maxDepth = 8,
    this.depth = 0,
  });

  /// Insere um item espacial na árvore.
  bool insert(SpatialItem<T> item) {
    if (!boundary.overlaps(item.bounds)) {
      return false;
    }

    if (_items.length < capacity || depth >= maxDepth) {
      _items.add(item);
      return true;
    }

    if (!_divided) {
      _subdivide();
    }

    bool inserted = false;
    if (_northWest!.insert(item)) inserted = true;
    if (_northEast!.insert(item)) inserted = true;
    if (_southWest!.insert(item)) inserted = true;
    if (_southEast!.insert(item)) inserted = true;

    return inserted;
  }

  void _subdivide() {
    final double x = boundary.left;
    final double y = boundary.top;
    final double halfW = boundary.width / 2.0;
    final double halfH = boundary.height / 2.0;

    _northWest = SpatialQuadTree<T>(
      boundary: Rect.fromLTWH(x, y, halfW, halfH),
      capacity: capacity,
      maxDepth: maxDepth,
      depth: depth + 1,
    );
    _northEast = SpatialQuadTree<T>(
      boundary: Rect.fromLTWH(x + halfW, y, halfW, halfH),
      capacity: capacity,
      maxDepth: maxDepth,
      depth: depth + 1,
    );
    _southWest = SpatialQuadTree<T>(
      boundary: Rect.fromLTWH(x, y + halfH, halfW, halfH),
      capacity: capacity,
      maxDepth: maxDepth,
      depth: depth + 1,
    );
    _southEast = SpatialQuadTree<T>(
      boundary: Rect.fromLTWH(x + halfW, y + halfH, halfW, halfH),
      capacity: capacity,
      maxDepth: maxDepth,
      depth: depth + 1,
    );

    _divided = true;

    // Redistribui itens existentes se aplicável
    final oldItems = List<SpatialItem<T>>.from(_items);
    _items.clear();
    for (final it in oldItems) {
      bool pushed = false;
      if (_northWest!.insert(it)) pushed = true;
      if (_northEast!.insert(it)) pushed = true;
      if (_southWest!.insert(it)) pushed = true;
      if (_southEast!.insert(it)) pushed = true;
      if (!pushed) {
        _items.add(it);
      }
    }
  }

  /// Busca os itens cujos bounds contêm o ponto especificado em tempo O(log n).
  List<T> queryPoint(Offset point) {
    final List<T> found = [];
    if (!boundary.contains(point)) {
      return found;
    }

    for (final item in _items) {
      if (item.bounds.contains(point)) {
        found.add(item.data);
      }
    }

    if (_divided) {
      found.addAll(_northWest!.queryPoint(point));
      found.addAll(_northEast!.queryPoint(point));
      found.addAll(_southWest!.queryPoint(point));
      found.addAll(_southEast!.queryPoint(point));
    }

    return found;
  }

  /// Limpa toda a árvore espacial para reconstrução.
  void clear() {
    _items.clear();
    _divided = false;
    _northWest = null;
    _northEast = null;
    _southWest = null;
    _southEast = null;
  }
}
