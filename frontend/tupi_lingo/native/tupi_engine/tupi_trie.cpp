#include "tupi_trie.h"
#include <string>
#include <vector>
#include <unordered_map>
#include <cstring>
#include <cstdlib>

struct TrieNode {
    std::unordered_map<char, TrieNode*> children;
    bool is_end_of_word = false;
    std::string translation;
    std::string original_word;

    ~TrieNode() {
        for (auto& pair : children) {
            delete pair.second;
        }
    }
};

class TupiTrieEngine {
public:
    TrieNode* root;

    TupiTrieEngine() {
        root = new TrieNode();
    }

    ~TupiTrieEngine() {
        delete root;
    }

    void insert(const std::string& word, const std::string& translation) {
        TrieNode* curr = root;
        for (char c : word) {
            if (curr->children.find(c) == curr->children.end()) {
                curr->children[c] = new TrieNode();
            }
            curr = curr->children[c];
        }
        curr->is_end_of_word = true;
        curr->original_word = word;
        curr->translation = translation;
    }

    void collect(TrieNode* node, std::vector<std::pair<std::string, std::string>>& results, int max_results) {
        if (!node || results.size() >= static_cast<size_t>(max_results)) return;

        if (node->is_end_of_word) {
            results.push_back({node->original_word, node->translation});
        }

        for (auto& pair : node->children) {
            collect(pair.second, results, max_results);
            if (results.size() >= static_cast<size_t>(max_results)) break;
        }
    }

    std::vector<std::pair<std::string, std::string>> search_prefix(const std::string& prefix, int max_results) {
        std::vector<std::pair<std::string, std::string>> results;
        TrieNode* curr = root;

        for (char c : prefix) {
            if (curr->children.find(c) == curr->children.end()) {
                return results; // Prefixo não encontrado
            }
            curr = curr->children[c];
        }

        collect(curr, results, max_results);
        return results;
    }
};

extern "C" {

void* tupi_trie_create() {
    return static_cast<void*>(new TupiTrieEngine());
}

void tupi_trie_insert(void* handle, const char* word, const char* translation) {
    if (!handle || !word) return;
    auto* trie = static_cast<TupiTrieEngine*>(handle);
    trie->insert(word, translation ? translation : "");
}

TrieSearchResultNative* tupi_trie_search_prefix(void* handle, const char* prefix, int max_results) {
    if (!handle || !prefix) return nullptr;
    auto* trie = static_cast<TupiTrieEngine*>(handle);

    auto matches = trie->search_prefix(prefix, max_results);
    int count = static_cast<int>(matches.size());

    auto* res = static_cast<TrieSearchResultNative*>(malloc(sizeof(TrieSearchResultNative)));
    res->count = count;
    res->words = static_cast<char**>(malloc(sizeof(char*) * count));
    res->translations = static_cast<char**>(malloc(sizeof(char*) * count));

    for (int i = 0; i < count; i++) {
        res->words[i] = strdup(matches[i].first.c_str());
        res->translations[i] = strdup(matches[i].second.c_str());
    }

    return res;
}

void tupi_trie_free_result(TrieSearchResultNative* result) {
    if (!result) return;
    for (int i = 0; i < result->count; i++) {
        free(result->words[i]);
        free(result->translations[i]);
    }
    free(result->words);
    free(result->translations);
    free(result);
}

void tupi_trie_destroy(void* handle) {
    if (!handle) return;
    delete static_cast<TupiTrieEngine*>(handle);
}

}
