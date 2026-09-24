import 'package:intl/intl.dart';

/// Represents a single firewood delivery note (Nota de Lenha).
class NotaLenha {
  final String? id;
  final String numeroNota;
  final DateTime? dataNota;
  final String motorista;
  final String placa;
  final String cliente;
  final String projeto;

  /// Stere 1 (s1) – first stere measurement
  final double? s1;

  /// Square metres (m2) – area measurement
  final double? m2;

  /// Total cubic metres (m³)
  final double? totalM3;

  final String? imagemUrl;
  final DateTime? criadoEm;

  const NotaLenha({
    this.id,
    required this.numeroNota,
    this.dataNota,
    required this.motorista,
    required this.placa,
    required this.cliente,
    required this.projeto,
    this.s1,
    this.m2,
    this.totalM3,
    this.imagemUrl,
    this.criadoEm,
  });

  // ─── Factory constructors ────────────────────────────────────────────────────

  factory NotaLenha.empty() => NotaLenha(
        numeroNota: '',
        motorista: '',
        placa: '',
        cliente: '',
        projeto: '',
      );

  factory NotaLenha.fromJson(Map<String, dynamic> json) {
    return NotaLenha(
      id: json['id'] as String?,
      numeroNota: json['numero_nota'] as String? ?? '',
      dataNota: _parseDate(json['data_nota']),
      motorista: json['motorista'] as String? ?? '',
      placa: json['placa'] as String? ?? '',
      cliente: json['cliente'] as String? ?? '',
      projeto: json['projeto'] as String? ?? '',
      s1: _parseDouble(json['s1']),
      m2: _parseDouble(json['m2']),
      totalM3: _parseDouble(json['total_m3']),
      imagemUrl: json['imagem_url'] as String?,
      criadoEm: _parseDate(json['criado_em']),
    );
  }

  // ─── Serialisation ───────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'numero_nota': numeroNota,
      if (dataNota != null)
        'data_nota': DateFormat('yyyy-MM-dd').format(dataNota!),
      'motorista': motorista,
      'placa': placa,
      'cliente': cliente,
      'projeto': projeto,
      if (s1 != null) 's1': s1,
      if (m2 != null) 'm2': m2,
      if (totalM3 != null) 'total_m3': totalM3,
      if (imagemUrl != null) 'imagem_url': imagemUrl,
      if (criadoEm != null) 'criado_em': criadoEm!.toIso8601String(),
    };
  }

  // ─── CopyWith ────────────────────────────────────────────────────────────────

  NotaLenha copyWith({
    String? id,
    String? numeroNota,
    DateTime? dataNota,
    String? motorista,
    String? placa,
    String? cliente,
    String? projeto,
    double? s1,
    double? m2,
    double? totalM3,
    String? imagemUrl,
    DateTime? criadoEm,
  }) {
    return NotaLenha(
      id: id ?? this.id,
      numeroNota: numeroNota ?? this.numeroNota,
      dataNota: dataNota ?? this.dataNota,
      motorista: motorista ?? this.motorista,
      placa: placa ?? this.placa,
      cliente: cliente ?? this.cliente,
      projeto: projeto ?? this.projeto,
      s1: s1 ?? this.s1,
      m2: m2 ?? this.m2,
      totalM3: totalM3 ?? this.totalM3,
      imagemUrl: imagemUrl ?? this.imagemUrl,
      criadoEm: criadoEm ?? this.criadoEm,
    );
  }

  // ─── Computed helpers ────────────────────────────────────────────────────────

  /// Returns the data_nota formatted as dd/MM/yyyy, or empty string.
  String get dataNotaFormatada {
    if (dataNota == null) return '';
    return DateFormat('dd/MM/yyyy').format(dataNota!);
  }

  /// Returns total_m3 formatted with 3 decimal places.
  String get totalM3Formatado {
    if (totalM3 == null) return '0,000';
    return totalM3!.toStringAsFixed(3).replaceAll('.', ',');
  }

  String get placaFormatada => placa.toUpperCase();

  @override
  String toString() =>
      'NotaLenha(id: $id, numero_nota: $numeroNota, motorista: $motorista, '
      'placa: $placa, cliente: $cliente, projeto: $projeto, '
      'total_m3: $totalM3)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotaLenha &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          numeroNota == other.numeroNota;

  @override
  int get hashCode => Object.hash(id, numeroNota);

  // ─── Private helpers ─────────────────────────────────────────────────────────

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
