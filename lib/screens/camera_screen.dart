import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app/routes.dart';
import '../services/ocr_service.dart';
import '../services/gemini_service.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final ImagePicker _picker = ImagePicker();

  String? _imagePath;
  bool _processing = false;
  String _statusText = '';

  // ─── Image selection ─────────────────────────────────────────────────────────

  Future<void> _takePicture() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (photo != null && mounted) {
        setState(() {
          _imagePath = photo.path;
        });
      }
    } catch (e) {
      _showError('Erro ao tirar foto: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (image != null && mounted) {
        setState(() {
          _imagePath = image.path;
        });
      }
    } catch (e) {
      _showError('Erro ao abrir galeria: $e');
    }
  }

  // ─── OCR + AI processing ─────────────────────────────────────────────────────

  Future<void> _processNota() async {
    if (_imagePath == null) return;

    setState(() {
      _processing = true;
      _statusText = 'Lendo texto...';
    });

    try {
      // Step 1 – OCR
      final String ocrText =
          await OcrService.instance.processImage(_imagePath!);

      if (!mounted) return;
      setState(() => _statusText = 'Analisando com IA...');

      // Step 2 – Gemini AI analysis
      final Map<String, dynamic> extractedData =
          await GeminiService.instance.analyzeNotaText(ocrText);

      if (!mounted) return;

      // Navigate to review screen with all results
      Navigator.pushNamed(
        context,
        AppRoutes.ocrReview,
        arguments: {
          'imagePath': _imagePath,
          'ocrText': ocrText,
          'extractedData': extractedData,
        },
      );
    } catch (e) {
      if (mounted) {
        _showError('Erro ao processar nota: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _processing = false;
          _statusText = '';
        });
      }
    }
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _clearImage() {
    setState(() => _imagePath = null);
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nova Nota'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _processing ? _buildProcessingView() : _buildMainView(),
    );
  }

  // ── Processing overlay ───────────────────────────────────────────────────────

  Widget _buildProcessingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: Color(0xFF2E7D32),
              strokeWidth: 3,
            ),
            const SizedBox(height: 24),
            Text(
              _statusText,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Por favor, aguarde…',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Main view ────────────────────────────────────────────────────────────────

  Widget _buildMainView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Image preview or selection area ──
          if (_imagePath == null)
            _buildImagePlaceholder()
          else
            _buildImagePreview(),

          const SizedBox(height: 24),

          // ── Selection buttons ──
          if (_imagePath == null) ...[
            _buildSelectionButton(
              icon: Icons.camera_alt,
              label: 'Tirar Foto',
              color: const Color(0xFF2E7D32),
              onPressed: _takePicture,
            ),
            const SizedBox(height: 12),
            _buildSelectionButton(
              icon: Icons.photo_library,
              label: 'Galeria',
              color: const Color(0xFF1565C0),
              onPressed: _pickFromGallery,
            ),
          ],

          // ── Process button (shown when image is selected) ──
          if (_imagePath != null) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _clearImage,
                    icon: const Icon(Icons.close),
                    label: const Text('Trocar Imagem'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _processNota,
                    icon: const Icon(Icons.auto_fix_high),
                    label: const Text(
                      'Processar Nota',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Secondary option to re-select
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: _takePicture,
                  icon: const Icon(Icons.camera_alt, size: 18),
                  label: const Text('Tirar Foto'),
                ),
                const SizedBox(width: 16),
                TextButton.icon(
                  onPressed: _pickFromGallery,
                  icon: const Icon(Icons.photo_library, size: 18),
                  label: const Text('Galeria'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      height: 260,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade300,
          width: 2,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_photo_alternate_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Selecione ou fotografe a nota',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.file(
        File(_imagePath!),
        height: 300,
        width: double.infinity,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildSelectionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(
        label,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 2,
      ),
    );
  }
}
