#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#ifdef __cplusplus
extern "C" {
#endif

// Exportação para Android / Linux / Windows FFI
#if defined(_WIN32)
#define TUPI_EXPORT __declspec(dllexport)
#else
#define TUPI_EXPORT __attribute__((visibility("default"))) __attribute__((used))
#endif

/**
 * Ofusca/Cifra um buffer binário do Protocol Buffers usando stream XOR com salt dinâmico
 * e permutação de bytes para impedir análise estática e engenharia reversa.
 */
TUPI_EXPORT void tupi_obfuscate_buffer(const uint8_t* input, uint8_t* output, int32_t length, uint32_t salt) {
    if (!input || !output || length <= 0) return;

    uint8_t key_byte = (uint8_t)(salt & 0xFF);
    uint8_t shift = (uint8_t)((salt >> 8) & 0x07);

    for (int32_t i = 0; i < length; ++i) {
        uint8_t b = input[i];
        // Rotação de bits + XOR com chave baseada em posição e salt
        uint8_t rotated = (uint8_t)((b << shift) | (b >> (8 - shift)));
        uint8_t masked = rotated ^ (uint8_t)(key_byte + (i * 31));
        output[i] = masked;
    }
}

/**
 * Reverte a ofuscação/cifra nativa restaurando o payload binário original do Protobuf.
 */
TUPI_EXPORT void tupi_deobfuscate_buffer(const uint8_t* input, uint8_t* output, int32_t length, uint32_t salt) {
    if (!input || !output || length <= 0) return;

    uint8_t key_byte = (uint8_t)(salt & 0xFF);
    uint8_t shift = (uint8_t)((salt >> 8) & 0x07);

    for (int32_t i = 0; i < length; ++i) {
        uint8_t masked = input[i];
        uint8_t rotated = masked ^ (uint8_t)(key_byte + (i * 31));
        // Desfaz a rotação de bits
        uint8_t b = (uint8_t)((rotated >> shift) | (rotated << (8 - shift)));
        output[i] = b;
    }
}

/**
 * Calcula uma assinatura de integridade rápida de 32-bit (FNV-1a adaptado)
 * para verificação instantânea no receptor.
 */
TUPI_EXPORT uint32_t tupi_calculate_checksum(const uint8_t* data, int32_t length) {
    if (!data || length <= 0) return 0;

    uint32_t hash = 2166136261u;
    for (int32_t i = 0; i < length; ++i) {
        hash ^= data[i];
        hash *= 16777619u;
    }
    return hash;
}

#ifdef __cplusplus
}
#endif
