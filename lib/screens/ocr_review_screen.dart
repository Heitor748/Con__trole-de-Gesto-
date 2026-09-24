import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../models/nota_lenha.dart';
import '../services/supabase_service.dart';
import '../services/drive_service.dart';

class OcrReviewScreen extends StatefulWidget {
  /// Route arguments: {imagePath, ocrText, extractedData}
  final Map<String, dynamic>? arguments;

  const OcrReviewScreen({super.key, this.arguments});

  @override
  State<OcrReviewScreen> createState() => _OcrReviewScreenState();
}

class _OcrReviewScreenState extends State<OcrReviewScreen> {
  final _formKey = GlobalKey<FormState>();

  // ── Text controllers ──────────────────────────────────────────────────────────
  final _numeroNotaCtrl = TextEditingController();
  final _dataNotaCtrl = TextEditingController();
  final _motoristaCtrl = TextEditingController();
  final _placaCtrl = TextEditingController();
  final _clienteCtrl = TextEditingController();
  final _projetoCtrl = TextEditingController();
  final _s1Ctrl = TextEditingController();
  final _m2Ctrl = TextEditingController();
  final _totalM3Ctrl = TextEditingController();

  // ── State ─────────────────────────────────────────────────────────────────────
  String? _imagePath;
  String _ocrText = '';
  DateTime? _selectedDate;
  bool _saving = false;
  bool _ocrExpanded = false;

  @override
  void initState() {
    super.initState();

    _imagePath = widget.arguments?['imagePath'] as String?;
    _ocrText = (widget.arguments?['ocrText'] as String?) ?? '';

    final extractedData =
        widget.arguments?['extractedData'] as Map<String, dynamic>?;

    if (extractedData != null) {
      _prefillFromExtractedData(extractedData);
    }
  }

  @override
  void dispose() {
    _numeroNotaCtrl.dispose();
    _dataNotaCtrl.dispose();
    _motoristaCtrl.dispose();
    _placaCtrl.dispose();
    _clienteCtrl.dispose();
    _projetoCtrl.dispose();
    _s1Ctrl.dispose();
    _m2Ctrl.dispose();
    _totalM3Ctrl.dispose();
    super.dispose();
  }

  // ─── Pre-fill ────────────────────────────────────────────────────────────────

  void _prefillFromExtractedData(Map<String, dynamic> data) {
    _numeroNotaCtrl.text = (data['numero_nota'] as String?) ?? '';
    _motoristaCtrl.text = (data['motorista'] as String?) ?? '';
    _placaCtrl.text = (data['placa'] as String?) ?? '';
    _clienteCtrl.text = (data['cliente'] as String?) ?? '';
    _projetoCtrl.text = (data['projeto'] as String?) ?? '';

    // Numeric fields
    final s1 = _parseDouble(data['s1']);
    if (s1 != null) _s1Ctrl.text = s1.toString();

    final m2 = _parseDouble(data['m2']);
    if (m2 != null) _m2Ctrl.text = m2.toString();

    final totalM3 = _parseDouble(data['total_m3']);
    if (totalM3 != null) _totalM3Ctrl.text = totalM3.toString();

    // Date field
    final dateStr = data['data'] as String?;
    if (dateStr != null && dateStr.isNotEmpty) {
      final parsed = DateTime.tryParse(dateStr);
      if (parsed != null) {
        _selectedDate = parsed;
        _dataNotaCtrl.text = DateFormat('dd/MM/yyyy').format(parsed);
      }
    }
  }

  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  // ─── Date picker ─────────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final initial = _selectedDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
        _dataNotaCtrl.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  // ─── Save ────────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      // ── Resolve date ────────────────────────────────────────────────────────
      DateTime? dataNota = _selectedDate;
      if (dataNota == null && _dataNotaCtrl.text.isNotEmpty) {
        try {
          dataNota = DateFormat('dd/MM/yyyy').parse(_dataNotaCtrl.text);
        } catch (_) {}
      }

      // ── Upload image to Supabase Storage ────────────────────────────────────
      String? imagemUrl;
      if (_imagePath != null) {
        final ext = p.extension(_imagePath!);
        final fileName = '${const Uuid().v4()}$ext';
        imagemUrl = await SupabaseService.instance
            .uploadImagem(_imagePath!, fileName);
      }

      // ── Build NotaLenha ─────────────────────────────────────────────────────
      final nota = NotaLenha(
        numeroNota: _numeroNotaCtrl.text.trim(),
        dataNota: dataNota,
        motorista: _motoristaCtrl.text.trim(),
        placa: _placaCtrl.text.trim().toUpperCase(),
        cliente: _clienteCtrl.text.trim(),
        projeto: _projetoCtrl.text.trim(),
        s1: double.tryParse(_s1Ctrl.text.replaceAll(',', '.')),
        m2: double.tryParse(_m2Ctrl.text.replaceAll(',', '.')),
        totalM3: double.tryParse(_totalM3Ctrl.text.replaceAll(',', '.')),
        imagemUrl: imagemUrl,
      );

      // ── Insert into Supabase ────────────────────────────────────────────────
      await SupabaseService.instance.insertNota(nota);

      // ── Optionally upload to Drive ──────────────────────────────────────────
      if (_imagePath != null) {
        final ext = p.extension(_imagePath!).toLowerCase();
        final mimeType = (ext == '.png') ? 'image/png' : 'image/jpeg';
        final driveName =
            'nota_${nota.numeroNota}_${DateFormat('yyyyMMdd').format(dataNota ?? DateTime.now())}$ext';

        // Fire-and-forget; failure is non-critical
        DriveService.instance
            .uploadFile(_imagePath!, driveName, mimeType)
            .catchError((_) => null);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nota salva com sucesso!'),
          backgroundColor: Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Return to home
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar nota: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Revisar Nota'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (!_saving)
            TextButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save, color: Colors.white),
              label: const Text(
                'Salvar',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Image preview ────────────────────────────────────────────────
            if (_imagePath != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(_imagePath!),
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ── Form ─────────────────────────────────────────────────────────
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildField(
                    controller: _numeroNotaCtrl,
                    label: 'Número da Nota',
                    icon: Icons.receipt,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty)
                            ? 'Informe o número da nota'
                            : null,
                  ),
                  _buildDateField(),
                  _buildField(
                    controller: _motoristaCtrl,
                    label: 'Motorista',
                    icon: Icons.person,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty)
                            ? 'Informe o motorista'
                            : null,
                  ),
                  _buildField(
                    controller: _placaCtrl,
                    label: 'Placa',
                    icon: Icons.directions_car,
                    textCapitalization: TextCapitalization.characters,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty)
                            ? 'Informe a placa'
                            : null,
                  ),
                  _buildField(
                    controller: _clienteCtrl,
                    label: 'Cliente',
                    icon: Icons.business,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty)
                            ? 'Informe o cliente'
                            : null,
                  ),
                  _buildField(
                    controller: _projetoCtrl,
                    label: 'Projeto',
                    icon: Icons.folder,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _buildField(
                          controller: _s1Ctrl,
                          label: 'S1 (st)',
                          icon: Icons.straighten,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildField(
                          controller: _m2Ctrl,
                          label: 'M² (área)',
                          icon: Icons.square_foot,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                        ),
                      ),
                    ],
                  ),
                  _buildField(
                    controller: _totalM3Ctrl,
                    label: 'Total M³',
                    icon: Icons.inventory,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── Raw OCR expandable section ────────────────────────────────────
            if (_ocrText.isNotEmpty) ...[
              Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                child: ExpansionTile(
                  title: const Row(
                    children: [
                      Icon(Icons.text_snippet_outlined, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Texto OCR original',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                  initiallyExpanded: _ocrExpanded,
                  onExpansionChanged: (v) =>
                      setState(() => _ocrExpanded = v),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SelectableText(
                          _ocrText,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Save button ───────────────────────────────────────────────────
            ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save),
              label: Text(
                _saving ? 'Salvando…' : 'Salvar Nota',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ─── Form field helpers ───────────────────────────────────────────────────────

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildDateField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: _dataNotaCtrl,
        readOnly: true,
        onTap: _pickDate,
        decoration: InputDecoration(
          labelText: 'Data da Nota',
          prefixIcon: const Icon(Icons.calendar_today),
          suffixIcon: const Icon(Icons.arrow_drop_down),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );
  }
}
