import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

/// Singleton service that wraps Google Gemini AI for firewood-note OCR analysis.
class GeminiService {
  GeminiService._();
  static final GeminiService instance = GeminiService._();

  // Lazily initialised so dotenv is read only after it has been loaded.
  GenerativeModel? _model;

  GenerativeModel get _gemini {
    if (_model != null) return _model!;

    final String apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      throw StateError(
        'GeminiService: GEMINI_API_KEY not found in .env file. '
        'Make sure flutter_dotenv is loaded before using GeminiService.',
      );
    }

    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        temperature: 0.1, // low temperature for structured extraction
      ),
    );
    return _model!;
  }

  // ─── Public API ───────────────────────────────────────────────────────────────

  /// Analyses raw OCR text from a firewood manifest (romaneio de lenha) and
  /// returns a [Map] with the extracted fields.
  ///
  /// Expected keys in the returned map:
  /// `numero_nota`, `data`, `motorista`, `placa`, `cliente`, `projeto`,
  /// `s1`, `m2`, `total_m3`.
  ///
  /// Values may be `null` when Gemini cannot identify a field.
  Future<Map<String, dynamic>> analyzeNotaText(String ocrText) async {
    if (ocrText.trim().isEmpty) {
      return _emptyResult();
    }

    final String prompt = _buildPrompt(ocrText);

    try {
      final GenerateContentResponse response = await _gemini.generateContent(
        [Content.text(prompt)],
      );

      final String? text = response.text;
      if (text == null || text.trim().isEmpty) {
        return _emptyResult();
      }

      return _parseResponse(text);
    } on GenerativeAIException catch (e) {
      throw Exception('GeminiService.analyzeNotaText: Gemini API error – $e');
    } catch (e) {
      throw Exception('GeminiService.analyzeNotaText: unexpected error – $e');
    }
  }

  // ─── Private helpers ─────────────────────────────────────────────────────────

  String _buildPrompt(String ocrText) {
    return '''
Você é um assistente especializado em extrair dados de romaneios de lenha (notas fiscais de transporte de madeira/lenha) preenchidos à mão ou digitados.

Analise o texto OCR abaixo, proveniente de um romaneio de lenha, e extraia os campos solicitados. O documento pode conter abreviações, grafia incorreta ou campos parcialmente ilegíveis — use seu melhor julgamento para interpretar os valores.

TEXTO OCR:
"""
$ocrText
"""

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
    // responseMimeType hint.
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
      final Match? match =
          RegExp(r'\{[\s\S]*\}').firstMatch(clean);
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
