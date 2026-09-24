import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/nota_lenha.dart';

/// Service responsible for generating PDF reports for Controle de Lenha TRBJ.
///
/// All methods return a [Uint8List] containing the raw PDF bytes, which can be
/// saved to disk, shared, or printed via the `printing` package.
class PdfService {
  PdfService._();
  static final PdfService instance = PdfService._();

  // ─── Formatters ───────────────────────────────────────────────────────────────

  static final NumberFormat _nf =
      NumberFormat('#,##0.000', 'pt_BR'); // e.g. 1.234,567
  static final DateFormat _df = DateFormat('dd/MM/yyyy', 'pt_BR');
  static final DateFormat _monthFmt = DateFormat('MMMM \'de\' yyyy', 'pt_BR');

  // ─── Colours / styles ─────────────────────────────────────────────────────────

  static const PdfColor _primary = PdfColor.fromInt(0xFF2E7D32); // dark green
  static const PdfColor _headerBg = PdfColor.fromInt(0xFF388E3C);
  static const PdfColor _rowAlt = PdfColor.fromInt(0xFFF1F8E9); // light green
  static const PdfColor _totalsRow = PdfColor.fromInt(0xFFDCEDC8);
  static const PdfColor _white = PdfColors.white;
  static const PdfColor _black = PdfColors.black;

  // ─── Public API ───────────────────────────────────────────────────────────────

  /// Generates a full listing report containing [notas] under [titulo].
  ///
  /// Layout:
  /// - Header with app title, report title and generation date
  /// - Table with one row per nota (all fields)
  /// - Totals row at the bottom (sum of total_m3, row count)
  Future<Uint8List> gerarRelatorioPDF(
    List<NotaLenha> notas,
    String titulo,
  ) async {
    final pw.Document doc = pw.Document(
      title: titulo,
      author: 'Controle de Lenha TRBJ',
    );

    final String geradoEm =
        'Gerado em: ${DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(DateTime.now())}';

    // Pre-compute totals
    final double totalM3 =
        notas.fold(0.0, (sum, n) => sum + (n.totalM3 ?? 0.0));

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        header: (pw.Context ctx) =>
            _buildPageHeader(titulo, geradoEm, ctx.pageNumber, ctx.pagesCount),
        footer: (pw.Context ctx) => _buildPageFooter(),
        build: (pw.Context ctx) => [
          pw.SizedBox(height: 12),
          _buildNotasTable(notas, totalM3),
          pw.SizedBox(height: 16),
          _buildSummaryRow(notas.length, totalM3),
        ],
      ),
    );

    return doc.save();
  }

  /// Generates a monthly closing (fechamento) PDF for [mes]/[ano].
  ///
  /// [fechamento] is the map returned by
  /// [SupabaseService.getFechamentoMensal], expected shape:
  /// ```json
  /// {
  ///   "total_m3": 123.456,
  ///   "count": 42,
  ///   "por_cliente": [{"cliente": "X", "total_m3": 10.0, "count": 5}, ...],
  ///   "por_projeto":  [{"projeto":  "Y", "total_m3": 20.0, "count": 7}, ...]
  /// }
  /// ```
  Future<Uint8List> gerarFechamentoPDF(
    Map<String, dynamic> fechamento,
    int mes,
    int ano,
  ) async {
    final DateTime refDate = DateTime(ano, mes, 1);
    final String mesAnoLabel =
        _capitalize(_monthFmt.format(refDate)); // e.g. "Maio de 2025"
    final String titulo = 'Fechamento Mensal – $mesAnoLabel';

    final double totalM3 = _toDouble(fechamento['total_m3']);
    final int count = (fechamento['count'] as int?) ?? 0;

    final List<Map<String, dynamic>> porCliente =
        _castList(fechamento['por_cliente']);
    final List<Map<String, dynamic>> porProjeto =
        _castList(fechamento['por_projeto']);

    final pw.Document doc = pw.Document(
      title: titulo,
      author: 'Controle de Lenha TRBJ',
    );

    final String geradoEm =
        'Gerado em: ${DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(DateTime.now())}';

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (pw.Context ctx) =>
            _buildPageHeader(titulo, geradoEm, ctx.pageNumber, ctx.pagesCount),
        footer: (pw.Context ctx) => _buildPageFooter(),
        build: (pw.Context ctx) => [
          pw.SizedBox(height: 12),
          // ── global summary card ──────────────────────────────────────────
          _buildSummaryCard(count, totalM3),
          pw.SizedBox(height: 20),
          // ── por cliente ──────────────────────────────────────────────────
          if (porCliente.isNotEmpty) ...[
            _sectionTitle('Resumo por Cliente'),
            pw.SizedBox(height: 6),
            _buildClienteTable(porCliente),
            pw.SizedBox(height: 20),
          ],
          // ── por projeto ──────────────────────────────────────────────────
          if (porProjeto.isNotEmpty) ...[
            _sectionTitle('Resumo por Projeto'),
            pw.SizedBox(height: 6),
            _buildProjetoTable(porProjeto),
          ],
        ],
      ),
    );

    return doc.save();
  }

  // ─── Page-level helpers ───────────────────────────────────────────────────────

  pw.Widget _buildPageHeader(
    String titulo,
    String geradoEm,
    int page,
    int pages,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Controle de Lenha TRBJ',
              style: pw.TextStyle(
                fontSize: 10,
                color: _primary,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Text(
              'Pág. $page / $pages',
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          titulo,
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: _primary,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          geradoEm,
          style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
        pw.Divider(color: _primary, thickness: 1.5),
      ],
    );
  }

  pw.Widget _buildPageFooter() {
    return pw.Column(
      children: [
        pw.Divider(color: PdfColors.grey400, thickness: 0.5),
        pw.Text(
          'Controle de Lenha TRBJ – Documento gerado automaticamente.',
          style: pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
          textAlign: pw.TextAlign.center,
        ),
      ],
    );
  }

  // ─── Notas table ─────────────────────────────────────────────────────────────

  pw.Widget _buildNotasTable(List<NotaLenha> notas, double totalM3) {
    const headers = [
      'Nota',
      'Data',
      'Motorista',
      'Placa',
      'Cliente',
      'Projeto',
      'S1',
      'M²',
      'Total m³',
    ];

    // Column flex weights (landscape A4 ~ 792pt usable width after margins)
    const widths = <pw.TableColumnWidth>[
      pw.FixedColumnWidth(52),  // Nota
      pw.FixedColumnWidth(58),  // Data
      pw.FlexColumnWidth(2.0),  // Motorista
      pw.FixedColumnWidth(56),  // Placa
      pw.FlexColumnWidth(2.0),  // Cliente
      pw.FlexColumnWidth(2.0),  // Projeto
      pw.FixedColumnWidth(46),  // S1
      pw.FixedColumnWidth(46),  // M²
      pw.FixedColumnWidth(62),  // Total m³
    ];

    final headerRow = _tableHeaderRow(headers);
    final dataRows = notas.asMap().entries.map((entry) {
      final int idx = entry.key;
      final NotaLenha n = entry.value;
      return _tableDataRow(
        [
          n.numeroNota,
          n.dataNota != null ? _df.format(n.dataNota!) : '',
          n.motorista,
          n.placaFormatada,
          n.cliente,
          n.projeto,
          n.s1 != null ? _nf.format(n.s1) : '',
          n.m2 != null ? _nf.format(n.m2) : '',
          n.totalM3 != null ? _nf.format(n.totalM3) : '',
        ],
        alternate: idx.isOdd,
      );
    }).toList();

    // Totals row
    final totalsRow = pw.TableRow(
      decoration: const pw.BoxDecoration(color: _totalsRow),
      children: [
        _cell('TOTAL', bold: true, span: 8),
        ...[for (int i = 1; i < 8; i++) _cell('')],
        _cell(_nf.format(totalM3), bold: true, align: pw.TextAlign.right),
      ],
    );

    return pw.Table(
      columnWidths: {
        for (int i = 0; i < widths.length; i++) i: widths[i],
      },
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      children: [headerRow, ...dataRows, totalsRow],
    );
  }

  pw.Widget _buildSummaryRow(int count, double totalM3) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: pw.BoxDecoration(
        color: _rowAlt,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: _primary, width: 0.8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Total de notas: $count',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
          ),
          pw.Text(
            'Volume total: ${_nf.format(totalM3)} m³',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
              color: _primary,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Fechamento widgets ───────────────────────────────────────────────────────

  pw.Widget _buildSummaryCard(int count, double totalM3) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: _rowAlt,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _primary, width: 1),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _summaryItem('Total de Notas', count.toString()),
          _vDivider(),
          _summaryItem('Volume Total (m³)', _nf.format(totalM3)),
        ],
      ),
    );
  }

  pw.Widget _summaryItem(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
            color: _primary,
          ),
        ),
      ],
    );
  }

  pw.Widget _vDivider() {
    return pw.Container(
      width: 1,
      height: 40,
      color: PdfColors.grey400,
    );
  }

  pw.Widget _sectionTitle(String title) {
    return pw.Text(
      title,
      style: pw.TextStyle(
        fontSize: 12,
        fontWeight: pw.FontWeight.bold,
        color: _primary,
      ),
    );
  }

  pw.Widget _buildClienteTable(List<Map<String, dynamic>> rows) {
    const headers = ['Cliente', 'Qtd. Notas', 'Volume (m³)'];
    final headerRow = _tableHeaderRow(headers);
    final dataRows = rows.asMap().entries.map((entry) {
      final Map<String, dynamic> r = entry.value;
      return _tableDataRow(
        [
          (r['cliente'] as String?) ?? '—',
          '${(r['count'] as int?) ?? 0}',
          _nf.format(_toDouble(r['total_m3'])),
        ],
        alternate: entry.key.isOdd,
        lastRight: true,
      );
    }).toList();

    // totals
    final double total =
        rows.fold(0.0, (s, r) => s + _toDouble(r['total_m3']));
    final int totalCount =
        rows.fold(0, (s, r) => s + ((r['count'] as int?) ?? 0));
    final totalsRow = pw.TableRow(
      decoration: const pw.BoxDecoration(color: _totalsRow),
      children: [
        _cell('TOTAL', bold: true),
        _cell('$totalCount', bold: true, align: pw.TextAlign.center),
        _cell(_nf.format(total), bold: true, align: pw.TextAlign.right),
      ],
    );

    return pw.Table(
      columnWidths: const {
        0: pw.FlexColumnWidth(3),
        1: pw.FixedColumnWidth(72),
        2: pw.FixedColumnWidth(90),
      },
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      children: [headerRow, ...dataRows, totalsRow],
    );
  }

  pw.Widget _buildProjetoTable(List<Map<String, dynamic>> rows) {
    const headers = ['Projeto', 'Qtd. Notas', 'Volume (m³)'];
    final headerRow = _tableHeaderRow(headers);
    final dataRows = rows.asMap().entries.map((entry) {
      final Map<String, dynamic> r = entry.value;
      return _tableDataRow(
        [
          (r['projeto'] as String?) ?? '—',
          '${(r['count'] as int?) ?? 0}',
          _nf.format(_toDouble(r['total_m3'])),
        ],
        alternate: entry.key.isOdd,
        lastRight: true,
      );
    }).toList();

    final double total =
        rows.fold(0.0, (s, r) => s + _toDouble(r['total_m3']));
    final int totalCount =
        rows.fold(0, (s, r) => s + ((r['count'] as int?) ?? 0));
    final totalsRow = pw.TableRow(
      decoration: const pw.BoxDecoration(color: _totalsRow),
      children: [
        _cell('TOTAL', bold: true),
        _cell('$totalCount', bold: true, align: pw.TextAlign.center),
        _cell(_nf.format(total), bold: true, align: pw.TextAlign.right),
      ],
    );

    return pw.Table(
      columnWidths: const {
        0: pw.FlexColumnWidth(3),
        1: pw.FixedColumnWidth(72),
        2: pw.FixedColumnWidth(90),
      },
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      children: [headerRow, ...dataRows, totalsRow],
    );
  }

  // ─── Low-level table helpers ──────────────────────────────────────────────────

  pw.TableRow _tableHeaderRow(List<String> labels) {
    return pw.TableRow(
      decoration: const pw.BoxDecoration(color: _headerBg),
      children: labels
          .map(
            (label) => pw.Padding(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              child: pw.Text(
                label,
                style: pw.TextStyle(
                  color: _white,
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ),
          )
          .toList(),
    );
  }

  pw.TableRow _tableDataRow(
    List<String> values, {
    bool alternate = false,
    bool lastRight = false,
  }) {
    final PdfColor? bg = alternate ? _rowAlt : null;
    return pw.TableRow(
      decoration: bg != null ? pw.BoxDecoration(color: bg) : null,
      children: values.asMap().entries.map((e) {
        final bool isLast = e.key == values.length - 1;
        return _cell(
          e.value,
          align: isLast && lastRight ? pw.TextAlign.right : pw.TextAlign.left,
        );
      }).toList(),
    );
  }

  pw.Widget _cell(
    String text, {
    bool bold = false,
    pw.TextAlign align = pw.TextAlign.left,
    // ignore: unused_element
    int span = 1,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: _black,
        ),
        textAlign: align,
      ),
    );
  }

  // ─── Utilities ────────────────────────────────────────────────────────────────

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static List<Map<String, dynamic>> _castList(dynamic value) {
    if (value is List) {
      return value.whereType<Map<String, dynamic>>().toList();
    }
    return [];
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}
