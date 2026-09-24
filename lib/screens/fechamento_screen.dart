import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../services/supabase_service.dart';
import '../services/pdf_service.dart';

class FechamentoScreen extends StatefulWidget {
  const FechamentoScreen({super.key});

  @override
  State<FechamentoScreen> createState() => _FechamentoScreenState();
}

class _FechamentoScreenState extends State<FechamentoScreen> {
  // ─── Month / year selector state ─────────────────────────────────────────
  final int _currentYear = DateTime.now().year;

  late int _selectedMes;
  late int _selectedAno;

  // ─── Result state ─────────────────────────────────────────────────────────
  Map<String, dynamic>? _fechamento;
  bool _loading = false;
  bool _exporting = false;
  String? _error;

  static const List<String> _monthNames = [
    'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
    'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
  ];

  @override
  void initState() {
    super.initState();
    _selectedMes = DateTime.now().month;
    _selectedAno = _currentYear;
  }

  // ─── Actions ──────────────────────────────────────────────────────────────

  Future<void> _gerarFechamento() async {
    setState(() {
      _loading = true;
      _error = null;
      _fechamento = null;
    });

    try {
      final result = await SupabaseService.instance
          .getFechamentoMensal(_selectedAno, _selectedMes);
      if (mounted) {
        setState(() {
          _fechamento = result;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _exportarPdf() async {
    if (_fechamento == null) return;
    setState(() => _exporting = true);
    try {
      final bytes = await PdfService.instance.gerarFechamentoPDF(
        _fechamento!,
        _selectedMes,
        _selectedAno,
      );
      if (mounted) {
        await Printing.layoutPdf(
          onLayout: (_) async => bytes,
          name:
              'Fechamento_${_selectedAno}_${_selectedMes.toString().padLeft(2, '0')}.pdf',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao exportar PDF: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fechamento Mensal'),
        actions: [
          if (_fechamento != null)
            IconButton(
              icon: _exporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf),
              onPressed: _exporting ? null : _exportarPdf,
              tooltip: 'Exportar PDF',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Month / Year selector card ─────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selecionar Período',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        // Month dropdown
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<int>(
                            value: _selectedMes,
                            decoration: InputDecoration(
                              labelText: 'Mês',
                              prefixIcon: const Icon(Icons.calendar_month),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 14),
                            ),
                            items: List.generate(12, (i) {
                              return DropdownMenuItem(
                                value: i + 1,
                                child: Text(_monthNames[i]),
                              );
                            }),
                            onChanged: (v) {
                              if (v != null) {
                                setState(() {
                                  _selectedMes = v;
                                  _fechamento = null;
                                  _error = null;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Year dropdown
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<int>(
                            value: _selectedAno,
                            decoration: InputDecoration(
                              labelText: 'Ano',
                              prefixIcon: const Icon(Icons.today),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 14),
                            ),
                            items: List.generate(3, (i) {
                              final year = _currentYear - i;
                              return DropdownMenuItem(
                                value: year,
                                child: Text(year.toString()),
                              );
                            }),
                            onChanged: (v) {
                              if (v != null) {
                                setState(() {
                                  _selectedAno = v;
                                  _fechamento = null;
                                  _error = null;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _loading ? null : _gerarFechamento,
                        icon: _loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.assessment),
                        label: Text(
                          _loading ? 'Gerando…' : 'Gerar Fechamento',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Error ──────────────────────────────────────────────────────
            if (_error != null) ...[
              const SizedBox(height: 12),
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          color: Colors.red.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // ── Results ────────────────────────────────────────────────────
            if (_fechamento != null) ...[
              const SizedBox(height: 20),
              _buildResultHeader(theme),
              const SizedBox(height: 16),
              _buildSummaryCards(theme),
              const SizedBox(height: 20),
              _buildClienteTable(theme),
              const SizedBox(height: 20),
              _buildProjetoTable(theme),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _exporting ? null : _exportarPdf,
                  icon: _exporting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.picture_as_pdf),
                  label: Text(
                    _exporting ? 'Exportando…' : 'Exportar PDF',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Result widgets ───────────────────────────────────────────────────────

  Widget _buildResultHeader(ThemeData theme) {
    return Row(
      children: [
        const Icon(Icons.assessment, size: 18, color: Color(0xFF2E7D32)),
        const SizedBox(width: 8),
        Text(
          'Fechamento – ${_monthNames[_selectedMes - 1]} de $_selectedAno',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1B5E20),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCards(ThemeData theme) {
    final totalM3 = (_fechamento!['total_m3'] as num?)?.toDouble() ?? 0.0;
    final count = (_fechamento!['count'] as int?) ?? 0;

    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            label: 'Total Notas',
            value: count.toString(),
            icon: Icons.receipt_long,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            label: 'Total m³',
            value: totalM3.toStringAsFixed(3).replaceAll('.', ','),
            icon: Icons.inventory_2,
            color: theme.colorScheme.tertiary,
          ),
        ),
      ],
    );
  }

  Widget _buildClienteTable(ThemeData theme) {
    final rows = _castList(_fechamento!['por_cliente']);
    if (rows.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Por Cliente',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _tableHeader(['Cliente', 'Qtd', 'Volume (m³)']),
            const Divider(height: 8),
            ...rows.asMap().entries.map((entry) {
              final r = entry.value;
              final alt = entry.key.isOdd;
              return _tableRow(
                [
                  (r['cliente'] as String?) ?? '—',
                  '${(r['count'] as int?) ?? 0}',
                  _fmtM3(r['total_m3']),
                ],
                alternate: alt,
              );
            }),
            const Divider(height: 8),
            _tableTotalsRow(rows, 'cliente'),
          ],
        ),
      ),
    );
  }

  Widget _buildProjetoTable(ThemeData theme) {
    final rows = _castList(_fechamento!['por_projeto']);
    if (rows.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Por Projeto',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _tableHeader(['Projeto', 'Qtd', 'Volume (m³)']),
            const Divider(height: 8),
            ...rows.asMap().entries.map((entry) {
              final r = entry.value;
              final alt = entry.key.isOdd;
              return _tableRow(
                [
                  (r['projeto'] as String?) ?? '—',
                  '${(r['count'] as int?) ?? 0}',
                  _fmtM3(r['total_m3']),
                ],
                alternate: alt,
              );
            }),
            const Divider(height: 8),
            _tableTotalsRow(rows, 'projeto'),
          ],
        ),
      ),
    );
  }

  // ─── Table helpers ────────────────────────────────────────────────────────

  Widget _tableHeader(List<String> labels) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(labels[0],
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13)),
        ),
        SizedBox(
          width: 48,
          child: Text(labels[1],
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13)),
        ),
        Expanded(
          flex: 2,
          child: Text(labels[2],
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13)),
        ),
      ],
    );
  }

  Widget _tableRow(List<String> values, {bool alternate = false}) {
    return Container(
      color: alternate
          ? const Color(0xFFF1F8E9)
          : Colors.transparent,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(values[0],
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis),
          ),
          SizedBox(
            width: 48,
            child: Text(values[1],
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13)),
          ),
          Expanded(
            flex: 2,
            child: Text(values[2],
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _tableTotalsRow(
      List<Map<String, dynamic>> rows, String nameKey) {
    final totalM3 =
        rows.fold(0.0, (s, r) => s + _toDouble(r['total_m3']));
    final totalCount =
        rows.fold(0, (s, r) => s + ((r['count'] as int?) ?? 0));
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: const BoxDecoration(
        color: Color(0xFFDCEDC8),
        borderRadius: BorderRadius.all(Radius.circular(4)),
      ),
      child: Row(
        children: [
          const Expanded(
            flex: 3,
            child: Text('TOTAL',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          SizedBox(
            width: 48,
            child: Text(
              '$totalCount',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _fmtM3(totalM3),
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Utilities ────────────────────────────────────────────────────────────

  String _fmtM3(dynamic value) {
    final d = _toDouble(value);
    return NumberFormat('#,##0.000', 'pt_BR').format(d);
  }

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
}

// ─── Summary card (local) ─────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
