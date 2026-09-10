#ifndef TUPI_TRIE_H
#define TUPI_TRIE_H

#ifdef __cplusplus
extern "C" {
#endif

#if defined(_WIN32)
  #define TUPI_EXPORT __declspec(dllexport)
#else
  #define TUPI_EXPORT __attribute__((visibility("default")))
#endif

typedef struct {
    char** words;
    char** translations;
    int count;
} TrieSearchResultNative;

TUPI_EXPORT void* tupi_trie_create();

TUPI_EXPORT void tupi_trie_insert(void* handle, const char* word, const char* translation);

TUPI_EXPORT TrieSearchResultNative* tupi_trie_search_prefix(void* handle, const char* prefix, int max_results);

TUPI_EXPORT void tupi_trie_free_result(TrieSearchResultNative* result);

TUPI_EXPORT void tupi_trie_destroy(void* handle);

#ifdef __cplusplus
}
#endif

#endif // TUPI_TRIE_H
