import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Singleton service that performs on-device OCR via Google ML Kit.
class OcrService {
  OcrService._();
  static final OcrService instance = OcrService._();

  // ─── Public API ───────────────────────────────────────────────────────────────

  /// Runs text recognition on the image located at [imagePath] and returns
  /// the full recognised text as a single string.
  ///
  /// Lines are separated by newline characters (`\n`).
  /// Returns an empty string if no text is detected.
  ///
  /// Throws an [Exception] if ML Kit cannot process the image.
  Future<String> processImage(String imagePath) async {
    final InputImage inputImage = InputImage.fromFilePath(imagePath);

    // Latin script covers Portuguese text used on Brazilian romaneios.
    final TextRecognizer recognizer = TextRecognizer(
      script: TextRecognitionScript.latin,
    );

    try {
      final RecognizedText recognizedText =
          await recognizer.processImage(inputImage);

      if (recognizedText.blocks.isEmpty) return '';

      // Concatenate all blocks → lines → elements preserving natural reading
      // order (ML Kit already returns them sorted top-to-bottom, left-to-right).
      final StringBuffer buffer = StringBuffer();

      for (final TextBlock block in recognizedText.blocks) {
        for (final TextLine line in block.lines) {
          buffer.writeln(line.text);
        }
        // Blank line between separate blocks to aid downstream parsing.
        buffer.writeln();
      }

      return buffer.toString().trim();
    } catch (e) {
      throw Exception('OcrService.processImage: failed to recognise text – $e');
    } finally {
      // Always close the recognizer to release native resources.
      await recognizer.close();
    }
  }
}
