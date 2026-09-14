import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Modular, versioned, hash-addressed prompt builder for LiteLLM (Chapters 42 & ADR-017).
class PromptBuilderV3 {
  static const String promptVersion = 'v3.2.0-entropy';

  /// Assembles a system and user prompt with KG grounding and morphological constraints.
  String buildPrompt({
    required String theme,
    required int variantId,
    required double targetTheta,
    String? kgContext,
    String? failedGateFeedback,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('### INSTRUÇÕES DO SISTEMA (TupiLingo AI Pipeline $promptVersion) ###');
    buffer.writeln('Você é um especialista em línguas Tupi-Guarani (Navarro 1998, Rodrigues 1953).');
    buffer.writeln('Variante ativa: ID $variantId (Isolamento estrito: PROIBIDO usar termos de outras variantes).');
    buffer.writeln('Dificuldade pedagógica visada (TRI θ): ${targetTheta.toStringAsFixed(2)}');
    buffer.writeln('Tema da prática: "$theme"');

    if (kgContext != null && kgContext.isNotEmpty) {
      buffer.writeln('\n[SUBGRAFO KNOWLEDGE GRAPH AUTORIZADO]');
      buffer.writeln(kgContext);
    }

    if (failedGateFeedback != null && failedGateFeedback.isNotEmpty) {
      buffer.writeln('\n[FEEDBACK DE CORREÇÃO DO TRUTH LAYER]');
      buffer.writeln('A geração anterior falhou pelo seguinte motivo: $failedGateFeedback');
      buffer.writeln('Ajuste sua geração para satisfazer estritamente essa restrição.');
    }

    buffer.writeln('\nGere uma questão em formato JSON estrito com os campos:');
    buffer.writeln('{"question": "...", "answer_key": "...", "distractors": ["...", "...", "..."], "explanation": "..."}');

    return buffer.toString();
  }

  /// Computes a SHA-256 hash of the composed prompt for deduplication and telemetry.
  String computePromptHash(String composedPrompt) {
    final bytes = utf8.encode(composedPrompt);
    return sha256.convert(bytes).toString();
  }
}
