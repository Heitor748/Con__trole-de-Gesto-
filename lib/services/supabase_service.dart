import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/nota_lenha.dart';

/// Singleton service that wraps all Supabase interactions for Controle de Lenha TRBJ.
class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  SupabaseClient get _client => Supabase.instance.client;

  static const String _table = 'notas_lenha';
  static const String _bucket = 'notas-imagens';

  // ─── CRUD ─────────────────────────────────────────────────────────────────────

  /// Inserts [nota] into the database and returns the persisted record.
  Future<NotaLenha> insertNota(NotaLenha nota) async {
    final Map<String, dynamic> payload = nota.toJson()..remove('id');

    final List<dynamic> response =
        await _client.from(_table).insert(payload).select();

    if (response.isEmpty) {
      throw Exception('SupabaseService.insertNota: empty response from server.');
    }

    return NotaLenha.fromJson(response.first as Map<String, dynamic>);
  }

  /// Updates an existing record identified by [nota.id].
  Future<void> updateNota(NotaLenha nota) async {
    if (nota.id == null) {
      throw ArgumentError('updateNota: nota.id must not be null.');
    }

    await _client.from(_table).update(nota.toJson()).eq('id', nota.id!);
  }

  /// Returns a single [NotaLenha] by primary-key [id], or `null` if not found.
  Future<NotaLenha?> getNota(String id) async {
    final List<dynamic> response =
        await _client.from(_table).select().eq('id', id).limit(1);

    if (response.isEmpty) return null;
    return NotaLenha.fromJson(response.first as Map<String, dynamic>);
  }

  /// Lists notas with optional full-text [search] and date-range filters.
  ///
  /// [search] is matched (case-insensitive) against motorista, cliente, projeto
  /// and numero_nota.
  Future<List<NotaLenha>> listNotas({
    String? search,
    DateTime? dataInicio,
    DateTime? dataFim,
  }) async {
    var query = _client.from(_table).select();

    if (dataInicio != null) {
      query = query.gte('data_nota', dataInicio.toIso8601String());
    }
    if (dataFim != null) {
      // Include the entire end day.
      final endOfDay =
          DateTime(dataFim.year, dataFim.month, dataFim.day, 23, 59, 59);
      query = query.lte('data_nota', endOfDay.toIso8601String());
    }

    // Supabase supports ilike for case-insensitive pattern matching.
    if (search != null && search.trim().isNotEmpty) {
      final pattern = '%${search.trim()}%';
      query = query.or(
        'numero_nota.ilike.$pattern,'
        'motorista.ilike.$pattern,'
        'cliente.ilike.$pattern,'
        'projeto.ilike.$pattern',
      );
    }

    final List<dynamic> response =
        await query.order('data_nota', ascending: false);

    return response
        .map((e) => NotaLenha.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Permanently deletes the nota with the given [id].
  Future<void> deleteNota(String id) async {
    await _client.from(_table).delete().eq('id', id);
  }

  // ─── Storage ──────────────────────────────────────────────────────────────────

  /// Uploads the file at [filePath] to the [_bucket] storage bucket under
  /// [fileName] and returns its public URL.
  Future<String> uploadImagem(String filePath, String fileName) async {
    final File file = File(filePath);
    if (!file.existsSync()) {
      throw FileSystemException('File not found', filePath);
    }

    // Derive content-type from extension.
    final String ext = filePath.split('.').last.toLowerCase();
    final String contentType = switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'application/octet-stream',
    };

    await _client.storage.from(_bucket).upload(
          fileName,
          file,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );

    final String publicUrl =
        _client.storage.from(_bucket).getPublicUrl(fileName);
    return publicUrl;
  }

  // ─── Aggregations ─────────────────────────────────────────────────────────────

  /// Returns monthly closing data for [mes]/[ano].
  ///
  /// Result shape:
  /// ```json
  /// {
  ///   "total_m3": 123.456,
  ///   "count": 42,
  ///   "por_cliente": [
  ///     {"cliente": "X", "total_m3": 10.0, "count": 5},
  ///     ...
  ///   ],
  ///   "por_projeto": [
  ///     {"projeto": "Y", "total_m3": 20.0, "count": 7},
  ///     ...
  ///   ]
  /// }
  /// ```
  Future<Map<String, dynamic>> getFechamentoMensal(int ano, int mes) async {
    final DateTime inicio = DateTime(ano, mes, 1);
    final DateTime fim = DateTime(ano, mes + 1, 1)
        .subtract(const Duration(seconds: 1)); // last moment of the month

    final List<dynamic> rows = await _client
        .from(_table)
        .select('cliente, projeto, total_m3')
        .gte('data_nota', inicio.toIso8601String())
        .lte('data_nota', fim.toIso8601String());

    // ── aggregate in-memory ──────────────────────────────────────────────────
    double totalM3 = 0;
    final Map<String, _Agg> porCliente = {};
    final Map<String, _Agg> porProjeto = {};

    for (final dynamic raw in rows) {
      final Map<String, dynamic> row = raw as Map<String, dynamic>;
      final double m3 = _parseDouble(row['total_m3']);
      final String cliente = (row['cliente'] as String?) ?? '—';
      final String projeto = (row['projeto'] as String?) ?? '—';

      totalM3 += m3;

      porCliente.putIfAbsent(cliente, _Agg.new).add(m3);
      porProjeto.putIfAbsent(projeto, _Agg.new).add(m3);
    }

    return {
      'total_m3': totalM3,
      'count': rows.length,
      'por_cliente': porCliente.entries
          .map((e) => {
                'cliente': e.key,
                'total_m3': e.value.total,
                'count': e.value.count,
              })
          .toList(),
      'por_projeto': porProjeto.entries
          .map((e) => {
                'projeto': e.key,
                'total_m3': e.value.total,
                'count': e.value.count,
              })
          .toList(),
    };
  }

  // ─── Private helpers ─────────────────────────────────────────────────────────

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

// Small aggregation helper used only inside this file.
class _Agg {
  double total = 0;
  int count = 0;

  void add(double m3) {
    total += m3;
    count++;
  }
}
