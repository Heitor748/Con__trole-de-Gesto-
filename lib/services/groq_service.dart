import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Singleton service that wraps Groq's vision API for firewood-note analysis.
///
/// Reads the manifest photo directly (no separate on-device OCR step) via a
/// vision-capable model on Groq's OpenAI-compatible chat completions endpoint.
class GroqService {
  GroqService._();
  static final GroqService instance = GroqService._();

  static const String _endpoint =
      'https://api.groq.com/openai/v1/chat/completions';
  static const String _model = 'meta-llama/llama-4-scout-17b-16e-instruct';

  // ─── Public API ───────────────────────────────────────────────────────────────

  /// Reads the firewood manifest (romaneio de lenha) photo from [imageBytes]
  /// and returns a [Map] with the extracted fields.
  ///
  /// [fileName] is only used to infer the image's MIME type from its
  /// extension.
  ///
  /// Expected keys in the returned map:
  /// `numero_nota`, `data`, `motorista`, `placa`, `cliente`, `projeto`,
  /// `s1`, `m2`, `total_m3`.
  ///
  /// Values may be `null` when Groq cannot identify a field.
  Future<Map<String, dynamic>> analyzeNotaImage(
    Uint8List imageBytes,
    String fileName,
  ) async {
    final String apiKey = dotenv.env['GROQ_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      throw StateError(
        'GroqService: GROQ_API_KEY not found in .env file. '
        'Make sure flutter_dotenv is loaded before using GroqService.',
      );
    }

    final String base64Image = base64Encode(imageBytes);
    final String mimeType = _mimeTypeFor(fileName);

    try {
      final http.Response response = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {
              'role': 'user',
              'content': [
                {'type': 'text', 'text': _buildPrompt()},
                {
                  'type': 'image_url',
                  'image_url': {
                    'url': 'data:$mimeType;base64,$base64Image',
                  },
                },
              ],
            },
          ],
          'temperature': 0.1,
          'response_format': {'type': 'json_object'},
        }),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'GroqService.analyzeNotaImage: Groq API error – '
          '${response.statusCode} ${response.body}',
        );
      }

      final Map<String, dynamic> decoded =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final String? text = (decoded['choices'] as List?)
          ?.cast<Map<String, dynamic>>()
          .firstOrNull?['message']?['content'] as String?;

      if (text == null || text.trim().isEmpty) {
        return _emptyResult();
      }

      return _parseResponse(text);
    } catch (e) {
      throw Exception('GroqService.analyzeNotaImage: unexpected error – $e');
    }
  }

  // ─── Private helpers ─────────────────────────────────────────────────────────

  String _mimeTypeFor(String path) {
    final String ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }

  String _buildPrompt() {
    return '''
Você é um assistente especializado em ler romaneios de lenha (notas fiscais de transporte de madeira/lenha) fotografados, preenchidos à mão ou digitados.

Observe a imagem em anexo e extraia os campos solicitados. O documento pode conter abreviações, letra manuscrita, grafia incorreta ou campos parcialmente ilegíveis — use seu melhor julgamento para interpretar os valores.

Extraia e retorne SOMENTE um objeto JSON válido com os seguintes campos:
- "numero_nota": número da nota ou romaneio (string ou null)
- "data": data no formato "YYYY-MM-DD" (string ou null)
- "motorista": nome completo do motorista (string ou null)
- "placa": placa do veículo no formato ABC-1234 ou ABC1D23 (string ou null)
- "cliente": nome do cliente/destinatário (string ou null)
- "projeto": nome do projeto ou fazenda (string ou null)
- "s1": valor de S1 / primeiro estéreo (número decimal ou null)
- "m2": valor de M2 / metros quadrados (número decimal ou null)
- "total_m3": total em metros cúbicos (m³) (número decimal ou null)

Regras:
1. Retorne SOMENTE o JSON, sem texto adicional, markdown ou explicações.
2. Use null para campos que não for possível identificar com razoável confiança.
3. Números decimais devem usar ponto (.) como separador decimal.
4. Datas devem estar no formato ISO 8601 (YYYY-MM-DD).
5. Placa deve estar em maiúsculas, sem espaços extras.
''';
  }

  Map<String, dynamic> _parseResponse(String text) {
    // Strip possible markdown code fences that the model may add despite the
    // response_format hint.
    String clean = text.trim();
    if (clean.startsWith('```')) {
      clean = clean
          .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
          .replaceFirst(RegExp(r'\s*```$'), '')
          .trim();
    }

    try {
      final dynamic decoded = jsonDecode(clean);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return _emptyResult();
    } on FormatException {
      // Try to locate a JSON object inside the text as a fallback.
      final Match? match = RegExp(r'\{[\s\S]*\}').firstMatch(clean);
      if (match != null) {
        try {
          final dynamic decoded = jsonDecode(match.group(0)!);
          if (decoded is Map<String, dynamic>) return decoded;
        } catch (_) {}
      }
      return _emptyResult();
    }
  }

  Map<String, dynamic> _emptyResult() => {
        'numero_nota': null,
        'data': null,
        'motorista': null,
        'placa': null,
        'cliente': null,
        'projeto': null,
        's1': null,
        'm2': null,
        'total_m3': null,
      };
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
