import 'dart:collection';

class _TrieNode {
  final Map<String, _TrieNode> children = HashMap();
  bool isTerminal = false;
  String? fullWord;
  String? translation;

  _TrieNode();
}

/// In-memory Trie prefix tree for ultra-fast (< 2ms) autocomplete suggestions.
class AutocompleteEngine {
  final _TrieNode _root = _TrieNode();

  /// Inserts a word and its Portuguese translation into the Trie.
  void insert(String word, {String? translation}) {
    final clean = word.trim().toLowerCase();
    if (clean.isEmpty) return;

    _TrieNode current = _root;
    for (int i = 0; i < clean.length; i++) {
      final char = clean[i];
      current = current.children.putIfAbsent(char, () => _TrieNode());
    }
    current.isTerminal = true;
    current.fullWord = word;
    current.translation = translation;
  }

  /// Batch inserts words into the prefix tree.
  void insertAll(Map<String, String> vocabulary) {
    vocabulary.forEach((word, translation) {
      insert(word, translation: translation);
    });
  }

  /// Returns up to [limit] autocomplete suggestions starting with [prefix].
  List<MapEntry<String, String>> suggest(String prefix, {int limit = 8}) {
    final clean = prefix.trim().toLowerCase();
    if (clean.isEmpty) return const [];

    _TrieNode? current = _root;
    for (int i = 0; i < clean.length; i++) {
      final char = clean[i];
      current = current?.children[char];
      if (current == null) return const [];
    }

    final node = current;
    if (node == null) return const [];

    final List<MapEntry<String, String>> results = [];
    _collectWords(node, results, limit);
    return results;
  }

  void _collectWords(_TrieNode node, List<MapEntry<String, String>> results, int limit) {
    if (results.length >= limit) return;

    if (node.isTerminal && node.fullWord != null) {
      results.add(MapEntry(node.fullWord!, node.translation ?? ''));
    }

    for (final child in node.children.values) {
      if (results.length >= limit) break;
      _collectWords(child, results, limit);
    }
  }

  /// Clears the Trie.
  void clear() {
    _root.children.clear();
  }
}
