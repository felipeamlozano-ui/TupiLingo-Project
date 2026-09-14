import 'package:flutter/foundation.dart';

/// Representation of an AI-generated question candidate submitted to the Truth Layer.
@immutable
class TruthQuestionCandidate {
  final String id;
  final String questionText;
  final String answerKey;
  final List<String> distractors;
  final String explanation;
  final int? variantId;
  final String? groundingSourceType; // 'rag_chunk', 'kg_node', 'morphology_rule'
  final String? groundingSourceId;
  final String questionHash;

  const TruthQuestionCandidate({
    required this.id,
    required this.questionText,
    required this.answerKey,
    required this.distractors,
    required this.explanation,
    this.variantId,
    this.groundingSourceType,
    this.groundingSourceId,
    required this.questionHash,
  });

  factory TruthQuestionCandidate.fromJson(Map<String, dynamic> json) {
    return TruthQuestionCandidate(
      id: json['id'] as String? ?? '',
      questionText: json['question'] as String? ?? json['question_text'] as String? ?? '',
      answerKey: json['answer_key'] as String? ?? json['correct_answer'] as String? ?? '',
      distractors: (json['distractors'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      explanation: json['explanation'] as String? ?? '',
      variantId: (json['variante_id'] as num?)?.toInt() ?? (json['variant_id'] as num?)?.toInt(),
      groundingSourceType: json['grounding_source_type'] as String?,
      groundingSourceId: json['grounding_source_id'] as String?,
      questionHash: json['question_hash'] as String? ?? json['hash'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question_text': questionText,
      'answer_key': answerKey,
      'distractors': distractors,
      'explanation': explanation,
      'variante_id': variantId,
      'grounding_source_type': groundingSourceType,
      'grounding_source_id': groundingSourceId,
      'question_hash': questionHash,
    };
  }
}
