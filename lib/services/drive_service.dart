import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Singleton service that uploads files to Google Drive through the
/// project's `backend/` proxy (see backend/README.md).
///
/// The Google service account credential lives only on the server side —
/// the app never handles it, which keeps it safe to run on the web.
class DriveService {
  DriveService._();
  static final DriveService instance = DriveService._();

  // ─── Public API ──────────────────────────────────────────────────────────────

  /// Uploads [bytes] to Google Drive as [fileName] via the backend proxy.
  ///
  /// Returns the webViewLink of the uploaded file, or null on error/if the
  /// proxy isn't configured.
  Future<String?> uploadFile(
    Uint8List bytes,
    String fileName,
    String mimeType,
  ) async {
    try {
      final String baseUrl = dotenv.env['DRIVE_PROXY_URL'] ?? '';
      final String apiKey = dotenv.env['DRIVE_PROXY_API_KEY'] ?? '';
      if (baseUrl.isEmpty || apiKey.isEmpty) return null;

      final Uri uri = Uri.parse('$baseUrl/api/upload');
      final http.MultipartRequest request = http.MultipartRequest('POST', uri)
        ..headers['x-api-key'] = apiKey
        ..fields['fileName'] = fileName
        ..files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: fileName,
          ),
        );

      final http.StreamedResponse streamed = await request.send();
      final http.Response response = await http.Response.fromStream(streamed);

      if (response.statusCode != 200) {
        // ignore: avoid_print
        print(
          'DriveService.uploadFile error: '
          '${response.statusCode} ${response.body}',
        );
        return null;
      }

      final Map<String, dynamic> decoded =
          jsonDecode(response.body) as Map<String, dynamic>;
      return decoded['webViewLink'] as String?;
    } catch (e) {
      // Drive upload is non-critical — never block the main save flow.
      // ignore: avoid_print
      print('DriveService.uploadFile error: $e');
      return null;
    }
  }
}
