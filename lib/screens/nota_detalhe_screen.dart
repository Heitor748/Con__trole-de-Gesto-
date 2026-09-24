import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../models/nota_lenha.dart';
import '../services/pdf_service.dart';
import '../services/supabase_service.dart';
import 'ocr_review_screen.dart';

class NotaDetalheScreen extends StatefulWidget {
  final Map<String, dynamic>? arguments;

  const NotaDetalheScreen({super.key, this.arguments});

  @override
  State<NotaDetalheScreen> createState() => _NotaDetalheScreenState();
}

class _NotaDetalheScreenState extends State<NotaDetalheScreen> {
  NotaLenha? _nota;
  bool _deleting = false;
  bool _exporting = false;

  static final DateFormat _dtFmt =
      DateFormat('dd/MM/yyyy HH:mm', 'pt_BR');

  @override
  void initState() {
    super.initState();
    _nota = widget.arguments?['nota'] as NotaLenha?;
  }

  // ─── Export PDF ───────────────────────────────────────────────────────────

  Future<void> _exportarPdf() async {
    if (_nota == null) return;
    setState(() => _exporting = true);
    try {
      final bytes = await PdfService.instance.gerarRelatorioPDF(
        [_nota!],
        'Nota ${_nota!.numeroNota}',
      );
      if (mounted) {
        await Printing.layoutPdf(
          onLayout: (_) async => bytes,
          name: 'Nota_${_nota!.numeroNota}.pdf',
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

  // ─── Delete ───────────────────────────────────────────────────────────────

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Nota'),
        content: Text(
          'Deseja excluir a nota ${_nota?.numeroNota}?\n'
          'Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _delete();
    }
  }

  Future<void> _delete() async {
    if (_nota?.id == null) return;
    setState(() => _deleting = true);
    try {
      await SupabaseService.instance.deleteNota(_nota!.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nota excluída com sucesso'),
            backgroundColor: Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true); // true signals deletion to caller
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao excluir: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _deleting = false);
      }
    }
  }

  // ─── Edit ─────────────────────────────────────────────────────────────────

  Future<void> _editNota() async {
    if (_nota == null) return;
    // Navigate to OcrReviewScreen pre-filled with current nota data
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => OcrReviewScreen(
          arguments: {
            'imagePath': null,
            'ocrText': '',
            'extractedData': {
              'numero_nota': _nota!.numeroNota,
              'motorista': _nota!.motorista,
              'placa': _nota!.placa,
              'cliente': _nota!.cliente,
              'projeto': _nota!.projeto,
              's1': _nota!.s1,
              'm2': _nota!.m2,
              'total_m3': _nota!.totalM3,
              'data': _nota!.dataNota?.toIso8601String(),
            },
            'editingId': _nota!.id,
          },
        ),
        settings: const RouteSettings(name: '/ocr-review'),
      ),
    );

    // Reload if edited
    if (result == true && _nota?.id != null && mounted) {
      final updated =
          await SupabaseService.instance.getNota(_nota!.id!);
      if (updated != null && mounted) {
        setState(() => _nota = updated);
      }
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_nota == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalhe da Nota')),
        body: const Center(child: Text('Nota não encontrada')),
      );
    }

    final nota = _nota!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Nota ${nota.numeroNota}'),
        actions: [
          // Edit action
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: _editNota,
            tooltip: 'Editar',
          ),
          // Delete action
          IconButton(
            icon: _deleting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.delete_outline),
            onPressed: _deleting ? null : _confirmDelete,
            tooltip: 'Excluir',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Hero image ─────────────────────────────────────────────
            _buildImage(nota),
            const SizedBox(height: 20),

            // ── Informações da Nota card ───────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Informações da Nota',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const Divider(height: 20),
                    _InfoRow(
                        icon: Icons.receipt,
                        label: 'Número',
                        value: nota.numeroNota),
                    _InfoRow(
                        icon: Icons.calendar_today,
                        label: 'Data',
                        value: nota.dataNotaFormatada),
                    _InfoRow(
                        icon: Icons.person,
                        label: 'Motorista',
                        value: nota.motorista),
                    _InfoRow(
                        icon: Icons.directions_car,
                        label: 'Placa',
                        value: nota.placaFormatada),
                    _InfoRow(
                        icon: Icons.business,
                        label: 'Cliente',
                        value: nota.cliente),
                    _InfoRow(
                        icon: Icons.folder_outlined,
                        label: 'Projeto',
                        value: nota.projeto),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Medições card ──────────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Medições',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const Divider(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _MeasurementTile(
                            label: 'S1 (st)',
                            value: nota.s1 != null
                                ? nota.s1!.toStringAsFixed(3)
                                : '—',
                            icon: Icons.straighten,
                            color: theme.colorScheme.secondary,
                          ),
                        ),
                        Expanded(
                          child: _MeasurementTile(
                            label: 'M² (área)',
                            value: nota.m2 != null
                                ? nota.m2!.toStringAsFixed(3)
                                : '—',
                            icon: Icons.square_foot,
                            color: theme.colorScheme.tertiary,
                          ),
                        ),
                        Expanded(
                          child: _MeasurementTile(
                            label: 'Total m³',
                            value: nota.totalM3Formatado,
                            icon: Icons.inventory,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Criado em ──────────────────────────────────────────────
            if (nota.criadoEm != null) ...[
              const SizedBox(height: 8),
              Text(
                'Cadastrado em: ${_dtFmt.format(nota.criadoEm!.toLocal())}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],

            const SizedBox(height: 24),

            // ── Exportar PDF button ────────────────────────────────────
            ElevatedButton.icon(
              onPressed: _exporting ? null : _exportarPdf,
              icon: _exporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.picture_as_pdf),
              label: Text(
                _exporting ? 'Exportando…' : 'Exportar PDF',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Image widget ─────────────────────────────────────────────────────────

  Widget _buildImage(NotaLenha nota) {
    if (nota.imagemUrl != null && nota.imagemUrl!.isNotEmpty) {
      return Hero(
        tag: 'nota-imagem-${nota.id ?? nota.numeroNota}',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: nota.imagemUrl!,
            height: 240,
            width: double.infinity,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              height: 240,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(child: CircularProgressIndicator()),
            ),
            errorWidget: (context, url, error) => Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Icon(Icons.broken_image,
                    size: 56, color: Colors.grey),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Icon(Icons.image_not_supported, size: 56, color: Colors.grey),
      ),
    );
  }
}

// ─── Info row ─────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Text(
            '$label: ',
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          Expanded(
            child: Text(
              value.trim().isNotEmpty ? value : '—',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Measurement tile ─────────────────────────────────────────────────────────

class _MeasurementTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MeasurementTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 30),
        const SizedBox(height: 6),
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: color, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Colors.grey),
        ),
      ],
    );
  }
}
