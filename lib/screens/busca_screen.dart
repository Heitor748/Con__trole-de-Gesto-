import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app/routes.dart';
import '../models/nota_lenha.dart';
import '../services/supabase_service.dart';

class BuscaScreen extends StatefulWidget {
  const BuscaScreen({super.key});

  @override
  State<BuscaScreen> createState() => _BuscaScreenState();
}

class _BuscaScreenState extends State<BuscaScreen> {
  final _searchCtrl = TextEditingController();

  // ─── Debounce ─────────────────────────────────────────────────────────────
  Timer? _debounce;

  // ─── Date range ───────────────────────────────────────────────────────────
  DateTime? _dataInicio;
  DateTime? _dataFim;

  // ─── Filter chips: placa / motorista ─────────────────────────────────────
  // We collect distinct values from loaded results to offer as quick filters.
  List<String> _placasDisponiveis = [];
  List<String> _motoristasDisponiveis = [];
  String? _placaSelecionada;
  String? _motoristaSelecionada;

  // ─── Results state ────────────────────────────────────────────────────────
  List<NotaLenha> _allResults = [];
  bool _loading = false;
  bool _searched = false;
  String? _error;

  static final DateFormat _dateFmt = DateFormat('dd/MM/yyyy', 'pt_BR');

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  // ─── Debounced search ─────────────────────────────────────────────────────

  void _onSearchChanged() {
    setState(() {}); // rebuild to show/hide clear button
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _runSearch();
    });
  }

  Future<void> _runSearch() async {
    final query = _searchCtrl.text.trim();
    // Allow search with only date filters (no text required)
    setState(() {
      _loading = true;
      _error = null;
      _searched = true;
    });

    try {
      final results = await SupabaseService.instance.listNotas(
        search: query.isNotEmpty ? query : null,
        dataInicio: _dataInicio,
        dataFim: _dataFim != null
            ? DateTime(
                _dataFim!.year, _dataFim!.month, _dataFim!.day, 23, 59, 59)
            : null,
      );

      // Collect distinct placas and motoristas for filter chips
      final placas = results
          .map((n) => n.placa.trim().toUpperCase())
          .where((p) => p.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      final motoristas = results
          .map((n) => n.motorista.trim())
          .where((m) => m.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

      if (mounted) {
        setState(() {
          _allResults = results;
          _placasDisponiveis = placas;
          _motoristasDisponiveis = motoristas;
          // Reset chip selections if they no longer exist in new results
          if (_placaSelecionada != null &&
              !placas.contains(_placaSelecionada)) {
            _placaSelecionada = null;
          }
          if (_motoristaSelecionada != null &&
              !motoristas.contains(_motoristaSelecionada)) {
            _motoristaSelecionada = null;
          }
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

  void _clearSearch() {
    _searchCtrl.clear();
    setState(() {
      _allResults = [];
      _searched = false;
      _error = null;
      _placaSelecionada = null;
      _motoristaSelecionada = null;
      _placasDisponiveis = [];
      _motoristasDisponiveis = [];
    });
  }

  // ─── Date pickers ─────────────────────────────────────────────────────────

  Future<void> _pickDataInicio() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dataInicio ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null && mounted) {
      setState(() => _dataInicio = picked);
      _runSearch();
    }
  }

  Future<void> _pickDataFim() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dataFim ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null && mounted) {
      setState(() => _dataFim = picked);
      _runSearch();
    }
  }

  void _clearDates() {
    setState(() {
      _dataInicio = null;
      _dataFim = null;
    });
    _runSearch();
  }

  // ─── Filtered results (applying chip filters client-side) ─────────────────

  List<NotaLenha> get _filteredResults {
    return _allResults.where((n) {
      if (_placaSelecionada != null &&
          n.placa.trim().toUpperCase() != _placaSelecionada) {
        return false;
      }
      if (_motoristaSelecionada != null &&
          n.motorista.trim() != _motoristaSelecionada) {
        return false;
      }
      return true;
    }).toList();
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _filteredResults;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar Notas'),
      ),
      body: Column(
        children: [
          // ── Search text field ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              autofocus: false,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _runSearch(),
              decoration: InputDecoration(
                hintText: 'Nota, motorista, placa, cliente, projeto…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _clearSearch,
                        tooltip: 'Limpar',
                      )
                    : null,
              ),
            ),
          ),

          // ── Date range row ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(
                      _dataInicio != null
                          ? 'De: ${_dateFmt.format(_dataInicio!)}'
                          : 'De: (qualquer)',
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: _pickDataInicio,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(
                      _dataFim != null
                          ? 'Até: ${_dateFmt.format(_dataFim!)}'
                          : 'Até: (qualquer)',
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: _pickDataFim,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                    ),
                  ),
                ),
                if (_dataInicio != null || _dataFim != null)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: _clearDates,
                    tooltip: 'Limpar datas',
                  ),
              ],
            ),
          ),

          // ── Filter chips: Placa ───────────────────────────────────────
          if (_placasDisponiveis.isNotEmpty)
            _ChipFilterRow(
              label: 'Placa:',
              options: _placasDisponiveis,
              selected: _placaSelecionada,
              onSelected: (v) => setState(() {
                _placaSelecionada = _placaSelecionada == v ? null : v;
              }),
            ),

          // ── Filter chips: Motorista ───────────────────────────────────
          if (_motoristasDisponiveis.isNotEmpty)
            _ChipFilterRow(
              label: 'Motorista:',
              options: _motoristasDisponiveis,
              selected: _motoristaSelecionada,
              onSelected: (v) => setState(() {
                _motoristaSelecionada =
                    _motoristaSelecionada == v ? null : v;
              }),
            ),

          const SizedBox(height: 4),

          // ── Body: loading / error / empty / results ───────────────────
          Expanded(
            child: _buildBody(theme, filtered),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme, List<NotaLenha> filtered) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text('Erro ao buscar notas',
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(_error!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: Colors.grey),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _runSearch,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_searched) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Digite para buscar notas',
              style:
                  theme.textTheme.bodyLarge?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              'ou use os filtros de data acima',
              style:
                  theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox, size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Nenhuma nota encontrada',
              style:
                  theme.textTheme.bodyLarge?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              'Tente outros termos ou ajuste os filtros',
              style:
                  theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(
            '${filtered.length} resultado${filtered.length != 1 ? "s" : ""}',
            style:
                theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final n = filtered[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        theme.colorScheme.primaryContainer,
                    child: Icon(
                      Icons.receipt_long,
                      color: theme.colorScheme.onPrimaryContainer,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Nota: ${n.numeroNota.isNotEmpty ? n.numeroNota : "—"}',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 2),
                      Text(
                        '${n.dataNotaFormatada.isNotEmpty ? n.dataNotaFormatada : "—"}'
                        ' · ${n.motorista.isNotEmpty ? n.motorista : "—"}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.grey.shade600),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${n.placaFormatada.isNotEmpty ? n.placaFormatada : "—"}'
                        ' · ${n.cliente.isNotEmpty ? n.cliente : "—"}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  trailing: Chip(
                    label: Text(
                      '${n.totalM3Formatado} m³',
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
                  onTap: () => Navigator.pushNamed(
                    context,
                    AppRoutes.notaDetalhe,
                    arguments: {'nota': n},
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── Chip filter row ─────────────────────────────────────────────────────────

class _ChipFilterRow extends StatelessWidget {
  final String label;
  final List<String> options;
  final String? selected;
  final ValueChanged<String> onSelected;

  const _ChipFilterRow({
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 6, right: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: options.map((opt) {
                  final isSelected = selected == opt;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(opt, style: const TextStyle(fontSize: 12)),
                      selected: isSelected,
                      onSelected: (_) => onSelected(opt),
                      visualDensity: VisualDensity.compact,
                      selectedColor: const Color(0xFF4CAF50).withOpacity(0.2),
                      checkmarkColor: const Color(0xFF2E7D32),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
