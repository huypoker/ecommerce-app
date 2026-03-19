import 'dart:typed_data';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../auth_middleware.dart';
import '../multipart_parser.dart';
import '../cloudinary.dart';

void registerUploadRoutes(Router router) {
  router.post('/api/upload', (Request request) async {
    final authError = requireAdmin(request);
    if (authError != null) return authError;

    try {
      final files = await parseMultipartRequest(request);
      final imageFile = files.where((f) => f.fieldName == 'image').firstOrNull;

      if (imageFile == null) {
        return jsonResponse({'error': 'No image file provided'}, statusCode: 400);
      }

      // Validate file type
      final allowedTypes = ['image/jpeg', 'image/png', 'image/gif', 'image/webp'];
      if (imageFile.contentType != null && !allowedTypes.contains(imageFile.contentType)) {
        return jsonResponse(
          {'error': 'Only JPEG, PNG, GIF and WebP images are allowed'},
          statusCode: 400,
        );
      }

      // Check file size (10MB max)
      if (imageFile.bytes.length > 10 * 1024 * 1024) {
        return jsonResponse({'error': 'File size exceeds 10MB limit'}, statusCode: 400);
      }

      final url = await uploadToCloudinary(
        Uint8List.fromList(imageFile.bytes),
        imageFile.filename ?? 'upload.jpg',
      );

      return jsonResponse({'url': url}, statusCode: 201);
    } catch (e) {
      return jsonResponse({'error': 'Upload failed: ${e.toString()}'}, statusCode: 500);
    }
  });
}
