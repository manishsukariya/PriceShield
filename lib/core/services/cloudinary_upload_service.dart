import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class CloudinaryUpload {
  const CloudinaryUpload({
    required this.secureUrl,
    required this.publicId,
    required this.resourceType,
  });

  final String secureUrl;
  final String publicId;
  final String resourceType;
}

/// Uploads client-selected files using restricted unsigned Cloudinary presets.
/// Cloudinary API secrets must never be placed in this Flutter app.
class CloudinaryUploadService {
  CloudinaryUploadService._();

  static const _cloudName =
      String.fromEnvironment(
        'CLOUDINARY_CLOUD_NAME',
        defaultValue: 'mpz1wxhc',
      );
  static const _imagePreset =
      String.fromEnvironment(
        'CLOUDINARY_IMAGE_UPLOAD_PRESET',
        defaultValue: 'priceshield_images',
      );
  static const _videoPreset =
      String.fromEnvironment(
        'CLOUDINARY_VIDEO_UPLOAD_PRESET',
        defaultValue: 'priceshield_images',
      );

  static Future<CloudinaryUpload> uploadFile({
    required File file,
    required bool isVideo,
  }) async {
    final cloudName = _cloudName.trim();
    final preset = (isVideo ? _videoPreset : _imagePreset).trim();
    if (cloudName.isEmpty || preset.isEmpty) {
      throw StateError(
        'Cloudinary setup is incomplete. Configure the cloud name and '
        '${isVideo ? 'video' : 'image'} upload preset.',
      );
    }

    final fileSize = await file.length();
    final maxBytes = isVideo ? 25 * 1024 * 1024 : 10 * 1024 * 1024;
    if (fileSize > maxBytes) {
      final limitMb = isVideo ? 25 : 10;
      throw StateError('Choose a file smaller than $limitMb MB.');
    }

    final resourceType = isVideo ? 'video' : 'image';
    final uri = Uri.https(
      'api.cloudinary.com',
      '/v1_1/$cloudName/$resourceType/upload',
    );
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = preset
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamedResponse = await request.send().timeout(
          const Duration(minutes: 2),
          onTimeout: () => throw StateError(
            'Cloudinary upload timed out. Check your internet and retry.',
          ),
        );
    final response = await http.Response.fromStream(streamedResponse);

    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException {
      throw StateError('Cloudinary returned an unreadable response.');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = payload['error'];
      final message = error is Map<String, dynamic>
          ? error['message']?.toString()
          : null;
      throw StateError(message ?? 'Cloudinary upload failed. Please retry.');
    }

    final secureUrl = payload['secure_url']?.toString();
    final publicId = payload['public_id']?.toString();
    if (secureUrl == null || publicId == null) {
      throw StateError('Cloudinary upload response is missing file details.');
    }

    return CloudinaryUpload(
      secureUrl: secureUrl,
      publicId: publicId,
      resourceType: payload['resource_type']?.toString() ?? resourceType,
    );
  }
}
