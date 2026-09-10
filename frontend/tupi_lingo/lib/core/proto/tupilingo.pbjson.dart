// This is a generated file - do not edit.
//
// Generated from tupilingo.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use userProfileMessageDescriptor instead')
const UserProfileMessage$json = {
  '1': 'UserProfileMessage',
  '2': [
    {'1': 'supabase_uid', '3': 1, '4': 1, '5': 9, '10': 'supabaseUid'},
    {'1': 'email', '3': 2, '4': 1, '5': 9, '10': 'email'},
    {'1': 'name', '3': 3, '4': 1, '5': 9, '10': 'name'},
    {'1': 'xp_total', '3': 4, '4': 1, '5': 5, '10': 'xpTotal'},
    {'1': 'streak_dias', '3': 5, '4': 1, '5': 5, '10': 'streakDias'},
    {'1': 'nivel_atual', '3': 6, '4': 1, '5': 5, '10': 'nivelAtual'},
    {'1': 'conchas', '3': 7, '4': 1, '5': 5, '10': 'conchas'},
    {
      '1': 'variante_ativa_codigo',
      '3': 8,
      '4': 1,
      '5': 9,
      '10': 'varianteAtivaCodigo'
    },
    {
      '1': 'variante_ativa_nome',
      '3': 9,
      '4': 1,
      '5': 9,
      '10': 'varianteAtivaNome'
    },
    {'1': 'ofensiva_ativa', '3': 10, '4': 1, '5': 8, '10': 'ofensivaAtiva'},
  ],
};

/// Descriptor for `UserProfileMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List userProfileMessageDescriptor = $convert.base64Decode(
    'ChJVc2VyUHJvZmlsZU1lc3NhZ2USIQoMc3VwYWJhc2VfdWlkGAEgASgJUgtzdXBhYmFzZVVpZB'
    'IUCgVlbWFpbBgCIAEoCVIFZW1haWwSEgoEbmFtZRgDIAEoCVIEbmFtZRIZCgh4cF90b3RhbBgE'
    'IAEoBVIHeHBUb3RhbBIfCgtzdHJlYWtfZGlhcxgFIAEoBVIKc3RyZWFrRGlhcxIfCgtuaXZlbF'
    '9hdHVhbBgGIAEoBVIKbml2ZWxBdHVhbBIYCgdjb25jaGFzGAcgASgFUgdjb25jaGFzEjIKFXZh'
    'cmlhbnRlX2F0aXZhX2NvZGlnbxgIIAEoCVITdmFyaWFudGVBdGl2YUNvZGlnbxIuChN2YXJpYW'
    '50ZV9hdGl2YV9ub21lGAkgASgJUhF2YXJpYW50ZUF0aXZhTm9tZRIlCg5vZmVuc2l2YV9hdGl2'
    'YRgKIAEoCFINb2ZlbnNpdmFBdGl2YQ==');

@$core.Deprecated('Use userLessonProgressMessageDescriptor instead')
const UserLessonProgressMessage$json = {
  '1': 'UserLessonProgressMessage',
  '2': [
    {'1': 'licao_id', '3': 1, '4': 1, '5': 5, '10': 'licaoId'},
    {'1': 'numero', '3': 2, '4': 1, '5': 5, '10': 'numero'},
    {'1': 'titulo', '3': 3, '4': 1, '5': 9, '10': 'titulo'},
    {'1': 'concluida', '3': 4, '4': 1, '5': 8, '10': 'concluida'},
    {'1': 'pontuacao_maxima', '3': 5, '4': 1, '5': 5, '10': 'pontuacaoMaxima'},
    {'1': 'tentativas', '3': 6, '4': 1, '5': 5, '10': 'tentativas'},
    {
      '1': 'data_conclusao_timestamp',
      '3': 7,
      '4': 1,
      '5': 3,
      '10': 'dataConclusaoTimestamp'
    },
  ],
};

/// Descriptor for `UserLessonProgressMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List userLessonProgressMessageDescriptor = $convert.base64Decode(
    'ChlVc2VyTGVzc29uUHJvZ3Jlc3NNZXNzYWdlEhkKCGxpY2FvX2lkGAEgASgFUgdsaWNhb0lkEh'
    'YKBm51bWVybxgCIAEoBVIGbnVtZXJvEhYKBnRpdHVsbxgDIAEoCVIGdGl0dWxvEhwKCWNvbmNs'
    'dWlkYRgEIAEoCFIJY29uY2x1aWRhEikKEHBvbnR1YWNhb19tYXhpbWEYBSABKAVSD3BvbnR1YW'
    'Nhb01heGltYRIeCgp0ZW50YXRpdmFzGAYgASgFUgp0ZW50YXRpdmFzEjgKGGRhdGFfY29uY2x1'
    'c2FvX3RpbWVzdGFtcBgHIAEoA1IWZGF0YUNvbmNsdXNhb1RpbWVzdGFtcA==');

@$core.Deprecated('Use quizItemMessageDescriptor instead')
const QuizItemMessage$json = {
  '1': 'QuizItemMessage',
  '2': [
    {'1': 'item_id', '3': 1, '4': 1, '5': 5, '10': 'itemId'},
    {'1': 'termo_tupi', '3': 2, '4': 1, '5': 9, '10': 'termoTupi'},
    {'1': 'traducao_correta', '3': 3, '4': 1, '5': 9, '10': 'traducaoCorreta'},
    {'1': 'distratores', '3': 4, '4': 3, '5': 9, '10': 'distratores'},
    {'1': 'regra_contexto', '3': 5, '4': 1, '5': 9, '10': 'regraContexto'},
    {'1': 'enunciado', '3': 6, '4': 1, '5': 9, '10': 'enunciado'},
    {'1': 'explicacao', '3': 7, '4': 1, '5': 9, '10': 'explicacao'},
    {'1': 'curiosidade', '3': 8, '4': 1, '5': 9, '10': 'curiosidade'},
  ],
};

/// Descriptor for `QuizItemMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List quizItemMessageDescriptor = $convert.base64Decode(
    'Cg9RdWl6SXRlbU1lc3NhZ2USFwoHaXRlbV9pZBgBIAEoBVIGaXRlbUlkEh0KCnRlcm1vX3R1cG'
    'kYAiABKAlSCXRlcm1vVHVwaRIpChB0cmFkdWNhb19jb3JyZXRhGAMgASgJUg90cmFkdWNhb0Nv'
    'cnJldGESIAoLZGlzdHJhdG9yZXMYBCADKAlSC2Rpc3RyYXRvcmVzEiUKDnJlZ3JhX2NvbnRleH'
    'RvGAUgASgJUg1yZWdyYUNvbnRleHRvEhwKCWVudW5jaWFkbxgGIAEoCVIJZW51bmNpYWRvEh4K'
    'CmV4cGxpY2FjYW8YByABKAlSCmV4cGxpY2FjYW8SIAoLY3VyaW9zaWRhZGUYCCABKAlSC2N1cm'
    'lvc2lkYWRl');

@$core.Deprecated('Use quizBlockMessageDescriptor instead')
const QuizBlockMessage$json = {
  '1': 'QuizBlockMessage',
  '2': [
    {'1': 'quiz_id', '3': 1, '4': 1, '5': 9, '10': 'quizId'},
    {'1': 'variante_codigo', '3': 2, '4': 1, '5': 9, '10': 'varianteCodigo'},
    {'1': 'nivel', '3': 3, '4': 1, '5': 5, '10': 'nivel'},
    {'1': 'tema', '3': 4, '4': 1, '5': 9, '10': 'tema'},
    {
      '1': 'questoes',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.tupilingo.QuizItemMessage',
      '10': 'questoes'
    },
    {
      '1': 'gerado_em_timestamp',
      '3': 6,
      '4': 1,
      '5': 3,
      '10': 'geradoEmTimestamp'
    },
  ],
};

/// Descriptor for `QuizBlockMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List quizBlockMessageDescriptor = $convert.base64Decode(
    'ChBRdWl6QmxvY2tNZXNzYWdlEhcKB3F1aXpfaWQYASABKAlSBnF1aXpJZBInCg92YXJpYW50ZV'
    '9jb2RpZ28YAiABKAlSDnZhcmlhbnRlQ29kaWdvEhQKBW5pdmVsGAMgASgFUgVuaXZlbBISCgR0'
    'ZW1hGAQgASgJUgR0ZW1hEjYKCHF1ZXN0b2VzGAUgAygLMhoudHVwaWxpbmdvLlF1aXpJdGVtTW'
    'Vzc2FnZVIIcXVlc3RvZXMSLgoTZ2VyYWRvX2VtX3RpbWVzdGFtcBgGIAEoA1IRZ2VyYWRvRW1U'
    'aW1lc3RhbXA=');
