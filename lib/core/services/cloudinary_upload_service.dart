import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

class CloudinaryUpload {
  const CloudinaryUpload({
    required this.secureUrl,
    required this.publicId,
    required this.resourceType,
    required this.sha256Hash,
  });

  final String secureUrl;
  final String publicId;
  final String resourceType;
  final String sha256Hash;
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

  static Future<String> computeSha256(File file) async {
    final digest = await file.openRead().transform(sha256).first;
    return digest.toString().toLowerCase();
  }

  static Future<CloudinaryUpload> uploadFile({
    required File file,
    required bool isVideo,
  }) async {
    final cloudName = _cloudName.trim();
    final preset = (isVideo ? _videoPreset : _imagePreset).trim();
    if (cloudName.isEmpty || preset.isEmpty) {
      throw StateError(
        'Photo upload service is temporarily unavailable. Please try again later.',
      );
    }

    final fileSize = await file.length();
    final maxBytes = isVideo ? 25 * 1024 * 1024 : 10 * 1024 * 1024;
    if (fileSize > maxBytes) {
      final limitMb = isVideo ? 25 : 10;
      throw StateError('Please choose a file smaller than $limitMb MB.');
    }

    final sha256Hash = await computeSha256(file);

    final resourceType = isVideo ? 'video' : 'image';
    final uri = Uri.https(
      'api.cloudinary.com',
      '/v1_1/$cloudName/$resourceType/upload',
    );

    int attempts = 0;
    const maxAttempts = 2;
    http.Response? response;

    while (attempts < maxAttempts) {
      attempts++;
      try {
        final request = http.MultipartRequest('POST', uri)
          ..fields['upload_preset'] = preset
          ..files.add(await http.MultipartFile.fromPath('file', file.path));

        final streamedResponse = await request.send().timeout(
              Duration(minutes: isVideo ? 3 : 1),
              onTimeout: () => throw StateError(
                'Upload timed out. Please check your internet connection and try again.',
              ),
            );
        response = await http.Response.fromStream(streamedResponse);
        break;
      } on SocketException {
        if (attempts >= maxAttempts) {
          throw StateError(
            isVideo
                ? 'Video upload connection was interrupted. Please ensure stable internet or proceed with photo proofs.'
                : 'Upload connection was interrupted. Please check your internet connection and try again.',
          );
        }
        await Future.delayed(const Duration(milliseconds: 600));
      } on http.ClientException {
        if (attempts >= maxAttempts) {
          throw StateError(
            isVideo
                ? 'Video upload was disconnected by network. Please retry or proceed with photo proofs.'
                : 'Upload was disconnected. Please check your internet connection and try again.',
          );
        }
        await Future.delayed(const Duration(milliseconds: 600));
      }
    }

    if (response == null) {
      throw StateError(
        isVideo
            ? 'Video upload failed. Please ensure a stable network or proceed with photo proofs.'
            : 'Proof upload failed. Please check your network and try again.',
      );
    }

    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException {
      throw StateError('Could not process the uploaded file. Please try again.');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = payload['error'];
      final message = error is Map<String, dynamic>
          ? error['message']?.toString()
          : null;
      throw StateError(message ?? 'Proof upload failed. Please try again.');
    }

    final secureUrl = payload['secure_url']?.toString();
    final publicId = payload['public_id']?.toString();
    if (secureUrl == null || publicId == null) {
      throw StateError('Could not save uploaded proof. Please try again.');
    }

    return CloudinaryUpload(
      secureUrl: secureUrl,
      publicId: publicId,
      resourceType: payload['resource_type']?.toString() ?? resourceType,
      sha256Hash: sha256Hash,
    );
  }
}
