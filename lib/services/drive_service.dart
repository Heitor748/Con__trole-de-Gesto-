import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

/// Singleton service that uploads files to Google Drive via Service Account.
///
/// The service account JSON is bundled at assets/service_account.json.
/// The target Drive folder must be shared with the service account as Editor:
///   silvaheitor@controle-de-lenha.iam.gserviceaccount.com
class DriveService {
  DriveService._();
  static final DriveService instance = DriveService._();

  static const List<String> _scopes = [drive.DriveApi.driveFileScope];

  // ─── Public API ──────────────────────────────────────────────────────────────

  /// Uploads [filePath] to Google Drive.
  ///
  /// [folderId] overrides the DRIVE_FOLDER_ID from .env.
  /// Returns the webViewLink of the uploaded file, or null on error.
  Future<String?> uploadFile(
    String filePath,
    String fileName,
    String mimeType, {
    String? folderId,
  }) async {
    try {
      final String targetFolder =
          folderId ?? dotenv.env['DRIVE_FOLDER_ID'] ?? '';

      final http.Client authClient = await _buildAuthClient();

      try {
        final drive.DriveApi driveApi = drive.DriveApi(authClient);

        final drive.File fileMetadata = drive.File()
          ..name = fileName
          ..mimeType = mimeType
          ..parents = targetFolder.isNotEmpty ? [targetFolder] : null;

        final File localFile = File(filePath);
        if (!localFile.existsSync()) {
          throw FileSystemException('File not found', filePath);
        }

        final drive.File uploaded = await driveApi.files.create(
          fileMetadata,
          uploadMedia: drive.Media(
            localFile.openRead(),
            localFile.lengthSync(),
            contentType: mimeType,
          ),
          $fields: 'id,webViewLink',
        );

        if (uploaded.id == null) return null;

        // Make file readable by anyone with the link.
        await driveApi.permissions.create(
          drive.Permission()
            ..role = 'reader'
            ..type = 'anyone',
          uploaded.id!,
        );

        return uploaded.webViewLink;
      } finally {
        authClient.close();
      }
    } catch (e) {
      // Drive upload is non-critical — never block the main save flow.
      // ignore: avoid_print
      print('DriveService.uploadFile error: $e');
      return null;
    }
  }

  // ─── Private helpers ─────────────────────────────────────────────────────────

  Future<http.Client> _buildAuthClient() async {
    final String jsonStr =
        await rootBundle.loadString('assets/service_account.json');
    final Map<String, dynamic> json =
        jsonDecode(jsonStr) as Map<String, dynamic>;

    final ServiceAccountCredentials credentials =
        ServiceAccountCredentials.fromJson(json);

    return clientViaServiceAccount(credentials, _scopes);
  }
}
