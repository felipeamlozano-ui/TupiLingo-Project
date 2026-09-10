// This is a generated file - do not edit.
//
// Generated from tupilingo.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

/// ─── Perfil do Usuário ────────────────────────────────────────────────────────
class UserProfileMessage extends $pb.GeneratedMessage {
  factory UserProfileMessage({
    $core.String? supabaseUid,
    $core.String? email,
    $core.String? name,
    $core.int? xpTotal,
    $core.int? streakDias,
    $core.int? nivelAtual,
    $core.int? conchas,
    $core.String? varianteAtivaCodigo,
    $core.String? varianteAtivaNome,
    $core.bool? ofensivaAtiva,
  }) {
    final result = create();
    if (supabaseUid != null) result.supabaseUid = supabaseUid;
    if (email != null) result.email = email;
    if (name != null) result.name = name;
    if (xpTotal != null) result.xpTotal = xpTotal;
    if (streakDias != null) result.streakDias = streakDias;
    if (nivelAtual != null) result.nivelAtual = nivelAtual;
    if (conchas != null) result.conchas = conchas;
    if (varianteAtivaCodigo != null)
      result.varianteAtivaCodigo = varianteAtivaCodigo;
    if (varianteAtivaNome != null) result.varianteAtivaNome = varianteAtivaNome;
    if (ofensivaAtiva != null) result.ofensivaAtiva = ofensivaAtiva;
    return result;
  }

  UserProfileMessage._();

  factory UserProfileMessage.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UserProfileMessage.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UserProfileMessage',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tupilingo'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'supabaseUid')
    ..aOS(2, _omitFieldNames ? '' : 'email')
    ..aOS(3, _omitFieldNames ? '' : 'name')
    ..aI(4, _omitFieldNames ? '' : 'xpTotal')
    ..aI(5, _omitFieldNames ? '' : 'streakDias')
    ..aI(6, _omitFieldNames ? '' : 'nivelAtual')
    ..aI(7, _omitFieldNames ? '' : 'conchas')
    ..aOS(8, _omitFieldNames ? '' : 'varianteAtivaCodigo')
    ..aOS(9, _omitFieldNames ? '' : 'varianteAtivaNome')
    ..aOB(10, _omitFieldNames ? '' : 'ofensivaAtiva')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UserProfileMessage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UserProfileMessage copyWith(void Function(UserProfileMessage) updates) =>
      super.copyWith((message) => updates(message as UserProfileMessage))
          as UserProfileMessage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UserProfileMessage create() => UserProfileMessage._();
  @$core.override
  UserProfileMessage createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UserProfileMessage getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UserProfileMessage>(create);
  static UserProfileMessage? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get supabaseUid => $_getSZ(0);
  @$pb.TagNumber(1)
  set supabaseUid($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSupabaseUid() => $_has(0);
  @$pb.TagNumber(1)
  void clearSupabaseUid() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get email => $_getSZ(1);
  @$pb.TagNumber(2)
  set email($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasEmail() => $_has(1);
  @$pb.TagNumber(2)
  void clearEmail() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get name => $_getSZ(2);
  @$pb.TagNumber(3)
  set name($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasName() => $_has(2);
  @$pb.TagNumber(3)
  void clearName() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get xpTotal => $_getIZ(3);
  @$pb.TagNumber(4)
  set xpTotal($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasXpTotal() => $_has(3);
  @$pb.TagNumber(4)
  void clearXpTotal() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get streakDias => $_getIZ(4);
  @$pb.TagNumber(5)
  set streakDias($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasStreakDias() => $_has(4);
  @$pb.TagNumber(5)
  void clearStreakDias() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get nivelAtual => $_getIZ(5);
  @$pb.TagNumber(6)
  set nivelAtual($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasNivelAtual() => $_has(5);
  @$pb.TagNumber(6)
  void clearNivelAtual() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get conchas => $_getIZ(6);
  @$pb.TagNumber(7)
  set conchas($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasConchas() => $_has(6);
  @$pb.TagNumber(7)
  void clearConchas() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get varianteAtivaCodigo => $_getSZ(7);
  @$pb.TagNumber(8)
  set varianteAtivaCodigo($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasVarianteAtivaCodigo() => $_has(7);
  @$pb.TagNumber(8)
  void clearVarianteAtivaCodigo() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get varianteAtivaNome => $_getSZ(8);
  @$pb.TagNumber(9)
  set varianteAtivaNome($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasVarianteAtivaNome() => $_has(8);
  @$pb.TagNumber(9)
  void clearVarianteAtivaNome() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.bool get ofensivaAtiva => $_getBF(9);
  @$pb.TagNumber(10)
  set ofensivaAtiva($core.bool value) => $_setBool(9, value);
  @$pb.TagNumber(10)
  $core.bool hasOfensivaAtiva() => $_has(9);
  @$pb.TagNumber(10)
  void clearOfensivaAtiva() => $_clearField(10);
}

/// ─── Progresso de Lições do Usuário ──────────────────────────────────────────
class UserLessonProgressMessage extends $pb.GeneratedMessage {
  factory UserLessonProgressMessage({
    $core.int? licaoId,
    $core.int? numero,
    $core.String? titulo,
    $core.bool? concluida,
    $core.int? pontuacaoMaxima,
    $core.int? tentativas,
    $fixnum.Int64? dataConclusaoTimestamp,
  }) {
    final result = create();
    if (licaoId != null) result.licaoId = licaoId;
    if (numero != null) result.numero = numero;
    if (titulo != null) result.titulo = titulo;
    if (concluida != null) result.concluida = concluida;
    if (pontuacaoMaxima != null) result.pontuacaoMaxima = pontuacaoMaxima;
    if (tentativas != null) result.tentativas = tentativas;
    if (dataConclusaoTimestamp != null)
      result.dataConclusaoTimestamp = dataConclusaoTimestamp;
    return result;
  }

  UserLessonProgressMessage._();

  factory UserLessonProgressMessage.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UserLessonProgressMessage.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UserLessonProgressMessage',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tupilingo'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'licaoId')
    ..aI(2, _omitFieldNames ? '' : 'numero')
    ..aOS(3, _omitFieldNames ? '' : 'titulo')
    ..aOB(4, _omitFieldNames ? '' : 'concluida')
    ..aI(5, _omitFieldNames ? '' : 'pontuacaoMaxima')
    ..aI(6, _omitFieldNames ? '' : 'tentativas')
    ..aInt64(7, _omitFieldNames ? '' : 'dataConclusaoTimestamp')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UserLessonProgressMessage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UserLessonProgressMessage copyWith(
          void Function(UserLessonProgressMessage) updates) =>
      super.copyWith((message) => updates(message as UserLessonProgressMessage))
          as UserLessonProgressMessage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UserLessonProgressMessage create() => UserLessonProgressMessage._();
  @$core.override
  UserLessonProgressMessage createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UserLessonProgressMessage getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UserLessonProgressMessage>(create);
  static UserLessonProgressMessage? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get licaoId => $_getIZ(0);
  @$pb.TagNumber(1)
  set licaoId($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasLicaoId() => $_has(0);
  @$pb.TagNumber(1)
  void clearLicaoId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get numero => $_getIZ(1);
  @$pb.TagNumber(2)
  set numero($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasNumero() => $_has(1);
  @$pb.TagNumber(2)
  void clearNumero() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get titulo => $_getSZ(2);
  @$pb.TagNumber(3)
  set titulo($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTitulo() => $_has(2);
  @$pb.TagNumber(3)
  void clearTitulo() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get concluida => $_getBF(3);
  @$pb.TagNumber(4)
  set concluida($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasConcluida() => $_has(3);
  @$pb.TagNumber(4)
  void clearConcluida() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get pontuacaoMaxima => $_getIZ(4);
  @$pb.TagNumber(5)
  set pontuacaoMaxima($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasPontuacaoMaxima() => $_has(4);
  @$pb.TagNumber(5)
  void clearPontuacaoMaxima() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get tentativas => $_getIZ(5);
  @$pb.TagNumber(6)
  set tentativas($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasTentativas() => $_has(5);
  @$pb.TagNumber(6)
  void clearTentativas() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get dataConclusaoTimestamp => $_getI64(6);
  @$pb.TagNumber(7)
  set dataConclusaoTimestamp($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasDataConclusaoTimestamp() => $_has(6);
  @$pb.TagNumber(7)
  void clearDataConclusaoTimestamp() => $_clearField(7);
}

/// ─── Questão / Item de Quiz (Nivelamento / Prática) ──────────────────────────
class QuizItemMessage extends $pb.GeneratedMessage {
  factory QuizItemMessage({
    $core.int? itemId,
    $core.String? termoTupi,
    $core.String? traducaoCorreta,
    $core.Iterable<$core.String>? distratores,
    $core.String? regraContexto,
    $core.String? enunciado,
    $core.String? explicacao,
    $core.String? curiosidade,
  }) {
    final result = create();
    if (itemId != null) result.itemId = itemId;
    if (termoTupi != null) result.termoTupi = termoTupi;
    if (traducaoCorreta != null) result.traducaoCorreta = traducaoCorreta;
    if (distratores != null) result.distratores.addAll(distratores);
    if (regraContexto != null) result.regraContexto = regraContexto;
    if (enunciado != null) result.enunciado = enunciado;
    if (explicacao != null) result.explicacao = explicacao;
    if (curiosidade != null) result.curiosidade = curiosidade;
    return result;
  }

  QuizItemMessage._();

  factory QuizItemMessage.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory QuizItemMessage.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'QuizItemMessage',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tupilingo'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'itemId')
    ..aOS(2, _omitFieldNames ? '' : 'termoTupi')
    ..aOS(3, _omitFieldNames ? '' : 'traducaoCorreta')
    ..pPS(4, _omitFieldNames ? '' : 'distratores')
    ..aOS(5, _omitFieldNames ? '' : 'regraContexto')
    ..aOS(6, _omitFieldNames ? '' : 'enunciado')
    ..aOS(7, _omitFieldNames ? '' : 'explicacao')
    ..aOS(8, _omitFieldNames ? '' : 'curiosidade')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  QuizItemMessage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  QuizItemMessage copyWith(void Function(QuizItemMessage) updates) =>
      super.copyWith((message) => updates(message as QuizItemMessage))
          as QuizItemMessage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static QuizItemMessage create() => QuizItemMessage._();
  @$core.override
  QuizItemMessage createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static QuizItemMessage getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<QuizItemMessage>(create);
  static QuizItemMessage? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get itemId => $_getIZ(0);
  @$pb.TagNumber(1)
  set itemId($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasItemId() => $_has(0);
  @$pb.TagNumber(1)
  void clearItemId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get termoTupi => $_getSZ(1);
  @$pb.TagNumber(2)
  set termoTupi($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTermoTupi() => $_has(1);
  @$pb.TagNumber(2)
  void clearTermoTupi() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get traducaoCorreta => $_getSZ(2);
  @$pb.TagNumber(3)
  set traducaoCorreta($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTraducaoCorreta() => $_has(2);
  @$pb.TagNumber(3)
  void clearTraducaoCorreta() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbList<$core.String> get distratores => $_getList(3);

  @$pb.TagNumber(5)
  $core.String get regraContexto => $_getSZ(4);
  @$pb.TagNumber(5)
  set regraContexto($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasRegraContexto() => $_has(4);
  @$pb.TagNumber(5)
  void clearRegraContexto() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get enunciado => $_getSZ(5);
  @$pb.TagNumber(6)
  set enunciado($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasEnunciado() => $_has(5);
  @$pb.TagNumber(6)
  void clearEnunciado() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get explicacao => $_getSZ(6);
  @$pb.TagNumber(7)
  set explicacao($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasExplicacao() => $_has(6);
  @$pb.TagNumber(7)
  void clearExplicacao() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get curiosidade => $_getSZ(7);
  @$pb.TagNumber(8)
  set curiosidade($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasCuriosidade() => $_has(7);
  @$pb.TagNumber(8)
  void clearCuriosidade() => $_clearField(8);
}

/// ─── Bloco de Exercícios / Prova de Nivelamento ──────────────────────────────
class QuizBlockMessage extends $pb.GeneratedMessage {
  factory QuizBlockMessage({
    $core.String? quizId,
    $core.String? varianteCodigo,
    $core.int? nivel,
    $core.String? tema,
    $core.Iterable<QuizItemMessage>? questoes,
    $fixnum.Int64? geradoEmTimestamp,
  }) {
    final result = create();
    if (quizId != null) result.quizId = quizId;
    if (varianteCodigo != null) result.varianteCodigo = varianteCodigo;
    if (nivel != null) result.nivel = nivel;
    if (tema != null) result.tema = tema;
    if (questoes != null) result.questoes.addAll(questoes);
    if (geradoEmTimestamp != null) result.geradoEmTimestamp = geradoEmTimestamp;
    return result;
  }

  QuizBlockMessage._();

  factory QuizBlockMessage.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory QuizBlockMessage.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'QuizBlockMessage',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tupilingo'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'quizId')
    ..aOS(2, _omitFieldNames ? '' : 'varianteCodigo')
    ..aI(3, _omitFieldNames ? '' : 'nivel')
    ..aOS(4, _omitFieldNames ? '' : 'tema')
    ..pPM<QuizItemMessage>(5, _omitFieldNames ? '' : 'questoes',
        subBuilder: QuizItemMessage.create)
    ..aInt64(6, _omitFieldNames ? '' : 'geradoEmTimestamp')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  QuizBlockMessage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  QuizBlockMessage copyWith(void Function(QuizBlockMessage) updates) =>
      super.copyWith((message) => updates(message as QuizBlockMessage))
          as QuizBlockMessage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static QuizBlockMessage create() => QuizBlockMessage._();
  @$core.override
  QuizBlockMessage createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static QuizBlockMessage getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<QuizBlockMessage>(create);
  static QuizBlockMessage? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get quizId => $_getSZ(0);
  @$pb.TagNumber(1)
  set quizId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasQuizId() => $_has(0);
  @$pb.TagNumber(1)
  void clearQuizId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get varianteCodigo => $_getSZ(1);
  @$pb.TagNumber(2)
  set varianteCodigo($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasVarianteCodigo() => $_has(1);
  @$pb.TagNumber(2)
  void clearVarianteCodigo() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get nivel => $_getIZ(2);
  @$pb.TagNumber(3)
  set nivel($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasNivel() => $_has(2);
  @$pb.TagNumber(3)
  void clearNivel() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get tema => $_getSZ(3);
  @$pb.TagNumber(4)
  set tema($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTema() => $_has(3);
  @$pb.TagNumber(4)
  void clearTema() => $_clearField(4);

  @$pb.TagNumber(5)
  $pb.PbList<QuizItemMessage> get questoes => $_getList(4);

  @$pb.TagNumber(6)
  $fixnum.Int64 get geradoEmTimestamp => $_getI64(5);
  @$pb.TagNumber(6)
  set geradoEmTimestamp($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasGeradoEmTimestamp() => $_has(5);
  @$pb.TagNumber(6)
  void clearGeradoEmTimestamp() => $_clearField(6);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
