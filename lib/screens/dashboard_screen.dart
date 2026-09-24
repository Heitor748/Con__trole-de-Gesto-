import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

import '../models/nota_lenha.dart';
import '../services/supabase_service.dart';

// ─── Colour palette for pie chart slices ────────────────────────────────────
const List<Color> _kPieColors = [
  Color(0xFF2E7D32),
  Color(0xFF1565C0),
  Color(0xFF6A1B9A),
  Color(0xFFE65100),
  Color(0xFF00796B),
  Color(0xFFC62828),
  Color(0xFF4527A0),
  Color(0xFF37474F),
];

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<List<NotaLenha>> _notasFuture;
  int _pieTouchedIndex = -1;

  @override
  void initState() {
    super.initState();
    _notasFuture = SupabaseService.instance.listNotas();
  }

  Future<void> _refresh() async {
    setState(() {
      _notasFuture = SupabaseService.instance.listNotas();
    });
  }

  // ─── Aggregate helpers ───────────────────────────────────────────────────

  double _totalM3(List<NotaLenha> notas) =>
      notas.fold(0.0, (s, n) => s + (n.totalM3 ?? 0.0));

  int _motoristasUnicos(List<NotaLenha> notas) =>
      notas.map((n) => n.motorista.trim().toLowerCase()).toSet().length;

  /// Returns a map of {month-label: total_m3} for the last 6 calendar months.
  Map<String, double> _m3PorUltimosMeses(List<NotaLenha> notas) {
    final now = DateTime.now();
    final result = <String, double>{};
    for (int i = 5; i >= 0; i--) {
      int m = now.month - i;
      int y = now.year;
      while (m <= 0) {
        m += 12;
        y -= 1;
      }
      final key = DateFormat('MM/yy').format(DateTime(y, m));
      result[key] = 0.0;
    }
    for (final n in notas) {
      if (n.dataNota == null) continue;
      final key = DateFormat('MM/yy').format(n.dataNota!);
      if (result.containsKey(key)) {
        result[key] = result[key]! + (n.totalM3 ?? 0.0);
      }
    }
    return result;
  }

  /// Returns a map of {cliente: total_m3}, capped to top 7 + Others.
  Map<String, double> _m3PorCliente(List<NotaLenha> notas) {
    final raw = <String, double>{};
    for (final n in notas) {
      final c = n.cliente.trim().isEmpty ? '—' : n.cliente.trim();
      raw[c] = (raw[c] ?? 0.0) + (n.totalM3 ?? 0.0);
    }
    if (raw.length <= 7) return raw;
    final sorted = raw.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(7);
    final othersTotal =
        sorted.skip(7).fold(0.0, (s, e) => s + e.value);
    return {
      for (final e in top) e.key: e.value,
      if (othersTotal > 0) 'Outros': othersTotal,
    };
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: FutureBuilder<List<NotaLenha>>(
        future: _notasFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _ShimmerDashboard();
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 56, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      'Erro ao carregar dados',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString(),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            );
          }

          final notas = snapshot.data ?? [];
          return RefreshIndicator(
            onRefresh: _refresh,
            child: _DashboardContent(
              notas: notas,
              totalM3: _totalM3(notas),
              motoristasUnicos: _motoristasUnicos(notas),
              m3PorMes: _m3PorUltimosMeses(notas),
              m3PorCliente: _m3PorCliente(notas),
              pieTouchedIndex: _pieTouchedIndex,
              onPieTouched: (i) => setState(() => _pieTouchedIndex = i),
            ),
          );
        },
      ),
    );
  }
}

// ─── Dashboard body extracted as a stateless widget ─────────────────────────

class _DashboardContent extends StatelessWidget {
  final List<NotaLenha> notas;
  final double totalM3;
  final int motoristasUnicos;
  final Map<String, double> m3PorMes;
  final Map<String, double> m3PorCliente;
  final int pieTouchedIndex;
  final ValueChanged<int> onPieTouched;

  const _DashboardContent({
    required this.notas,
    required this.totalM3,
    required this.motoristasUnicos,
    required this.m3PorMes,
    required this.m3PorCliente,
    required this.pieTouchedIndex,
    required this.onPieTouched,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final last10 =
        notas.length > 10 ? notas.sublist(0, 10) : List<NotaLenha>.from(notas);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // ── Summary cards ─────────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                label: 'Total Notas',
                value: notas.length.toString(),
                icon: Icons.receipt_long,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SummaryCard(
                label: 'Total m³',
                value: totalM3.toStringAsFixed(2),
                icon: Icons.inventory_2,
                color: theme.colorScheme.tertiary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SummaryCard(
                label: 'Motoristas',
                value: motoristasUnicos.toString(),
                icon: Icons.badge,
                color: const Color(0xFF6A1B9A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // ── Bar chart: m³ by month ────────────────────────────────────────
        if (m3PorMes.isNotEmpty) ...[
          _SectionHeader(
            icon: Icons.bar_chart,
            title: 'm³ por Mês (últimos 6 meses)',
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 20, 20, 12),
              child: SizedBox(
                height: 220,
                child: _MonthBarChart(data: m3PorMes),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],

        // ── Pie chart: distribution by cliente ───────────────────────────
        if (m3PorCliente.isNotEmpty) ...[
          _SectionHeader(
            icon: Icons.pie_chart,
            title: 'Distribuição por Cliente',
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                height: 260,
                child: _ClientePieChart(
                  data: m3PorCliente,
                  touchedIndex: pieTouchedIndex,
                  onTouched: onPieTouched,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],

        // ── Last 10 notas ─────────────────────────────────────────────────
        _SectionHeader(
          icon: Icons.history,
          title: 'Últimas 10 Notas',
        ),
        const SizedBox(height: 8),
        if (last10.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inbox,
                      size: 56, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text(
                    'Nenhuma nota cadastrada',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
            ),
          )
        else
          ...last10.map(
            (n) => _NotaListItem(nota: n),
          ),
      ],
    );
  }
}

// ─── Month BarChart ──────────────────────────────────────────────────────────

class _MonthBarChart extends StatelessWidget {
  final Map<String, double> data;

  const _MonthBarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final keys = data.keys.toList();
    final values = data.values.toList();
    final maxY = values.isEmpty
        ? 10.0
        : values.reduce(math.max) * 1.25;

    return BarChart(
      BarChartData(
        maxY: maxY == 0 ? 10 : maxY,
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) => FlLine(
            color: Colors.grey.shade200,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 46,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox();
                return Text(
                  value.toStringAsFixed(0),
                  style:
                      const TextStyle(fontSize: 10, color: Colors.grey),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= keys.length) {
                  return const SizedBox();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    keys[idx],
                    style: const TextStyle(
                        fontSize: 10, color: Colors.grey),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: List.generate(keys.length, (i) {
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: values[i],
                color: color,
                width: 22,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4)),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: maxY == 0 ? 10 : maxY,
                  color: Colors.grey.shade100,
                ),
              ),
            ],
          );
        }),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${keys[group.x]}\n${rod.toY.toStringAsFixed(3)} m³',
                const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─── Cliente PieChart ────────────────────────────────────────────────────────

class _ClientePieChart extends StatelessWidget {
  final Map<String, double> data;
  final int touchedIndex;
  final ValueChanged<int> onTouched;

  const _ClientePieChart({
    required this.data,
    required this.touchedIndex,
    required this.onTouched,
  });

  @override
  Widget build(BuildContext context) {
    final entries = data.entries.toList();
    final total = entries.fold(0.0, (s, e) => s + e.value);

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  if (response?.touchedSection != null &&
                      event is FlTapUpEvent) {
                    onTouched(
                        response!.touchedSection!.touchedSectionIndex);
                  } else if (event is FlTapUpEvent) {
                    onTouched(-1);
                  }
                },
              ),
              sectionsSpace: 2,
              centerSpaceRadius: 36,
              sections: List.generate(entries.length, (i) {
                final isTouched = i == touchedIndex;
                final pct =
                    total > 0 ? (entries[i].value / total * 100) : 0.0;
                return PieChartSectionData(
                  value: entries[i].value,
                  title: '${pct.toStringAsFixed(1)}%',
                  titleStyle: TextStyle(
                    fontSize: isTouched ? 13 : 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  color: _kPieColors[i % _kPieColors.length],
                  radius: isTouched ? 72 : 60,
                );
              }),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(entries.length, (i) {
                final pct =
                    total > 0 ? (entries[i].value / total * 100) : 0.0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _kPieColors[i % _kPieColors.length],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${entries[i].key} (${pct.toStringAsFixed(0)}%)',
                          style: const TextStyle(fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Nota list item ──────────────────────────────────────────────────────────

class _NotaListItem extends StatelessWidget {
  final NotaLenha nota;

  const _NotaListItem({required this.nota});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.pushNamed(
          context,
          '/nota-detalhe',
          arguments: {'nota': nota},
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor:
                    theme.colorScheme.primary.withOpacity(0.12),
                child: Icon(Icons.receipt_long,
                    color: theme.colorScheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nota.numeroNota.isNotEmpty
                          ? 'Nota ${nota.numeroNota}'
                          : 'Sem número',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${nota.dataNotaFormatada.isNotEmpty ? nota.dataNotaFormatada : "—"}'
                      ' · ${nota.motorista.isNotEmpty ? nota.motorista : "—"}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Chip(
                label: Text(
                  '${nota.totalM3Formatado} m³',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                backgroundColor:
                    theme.colorScheme.primary.withOpacity(0.08),
                side: BorderSide.none,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Summary card ────────────────────────────────────────────────────────────

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
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
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
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Section header ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF2E7D32)),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1B5E20),
              ),
        ),
      ],
    );
  }
}

// ─── Shimmer placeholder ─────────────────────────────────────────────────────

class _ShimmerDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Summary row
          Row(
            children: List.generate(
              3,
              (_) => Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 90,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Bar chart placeholder
          Container(
            height: 240,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 24),
          // Pie chart placeholder
          Container(
            height: 280,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 24),
          // List items
          ...List.generate(
            5,
            (_) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
