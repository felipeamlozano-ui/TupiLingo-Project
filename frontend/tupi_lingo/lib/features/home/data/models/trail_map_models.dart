import 'package:flutter/material.dart';

enum LicaoStatus { bloqueada, disponivel, emAndamento, concluida }

class LicaoMapData {
  final int id;
  final String titulo;
  final String descricao;
  final int numero;
  final int xpBase;
  final double posX;
  final double posY;
  final LicaoStatus status;
  final int earnedXp;

  const LicaoMapData({
    required this.id,
    required this.titulo,
    required this.descricao,
    required this.numero,
    required this.xpBase,
    required this.posX,
    required this.posY,
    required this.status,
    this.earnedXp = 0,
  });

  LicaoMapData copyWith({
    int? id,
    String? titulo,
    String? descricao,
    int? numero,
    int? xpBase,
    double? posX,
    double? posY,
    LicaoStatus? status,
    int? earnedXp,
  }) {
    return LicaoMapData(
      id: id ?? this.id,
      titulo: titulo ?? this.titulo,
      descricao: descricao ?? this.descricao,
      numero: numero ?? this.numero,
      xpBase: xpBase ?? this.xpBase,
      posX: posX ?? this.posX,
      posY: posY ?? this.posY,
      status: status ?? this.status,
      earnedXp: earnedXp ?? this.earnedXp,
    );
  }
}

class ChestRewardMapData {
  final int milestoneIndex;
  final String status; // 'bloqueado', 'disponivel', 'concluido'
  final bool unlocked;
  final bool collected;
  final int recompensaXp;
  final int recompensaConchas;
  final int afterLessonNumber;

  const ChestRewardMapData({
    required this.milestoneIndex,
    required this.status,
    required this.unlocked,
    required this.collected,
    required this.recompensaXp,
    required this.recompensaConchas,
    required this.afterLessonNumber,
  });
}

class CapituloMapData {
  final int id;
  final String titulo;
  final String descricao;
  final int numero;
  final Color paletteColor;
  final List<LicaoMapData> licoes;
  final ChestRewardMapData? chestReward;
  final double moduleProgressPercentage;

  const CapituloMapData({
    required this.id,
    required this.titulo,
    required this.descricao,
    required this.numero,
    required this.paletteColor,
    required this.licoes,
    this.chestReward,
    this.moduleProgressPercentage = 0.0,
  });

  CapituloMapData copyWith({
    int? id,
    String? titulo,
    String? descricao,
    int? numero,
    Color? paletteColor,
    List<LicaoMapData>? licoes,
    ChestRewardMapData? chestReward,
    double? moduleProgressPercentage,
  }) {
    return CapituloMapData(
      id: id ?? this.id,
      titulo: titulo ?? this.titulo,
      descricao: descricao ?? this.descricao,
      numero: numero ?? this.numero,
      paletteColor: paletteColor ?? this.paletteColor,
      licoes: licoes ?? this.licoes,
      chestReward: chestReward ?? this.chestReward,
      moduleProgressPercentage: moduleProgressPercentage ?? this.moduleProgressPercentage,
    );
  }
}
