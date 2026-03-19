import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:path/path.dart' as p;

import 'package:ecommerce_server/database.dart';
import 'package:ecommerce_server/seed.dart';
import 'package:ecommerce_server/auth_middleware.dart';
import 'package:ecommerce_server/routes/auth.dart';
import 'package:ecommerce_server/routes/products.dart';
import 'package:ecommerce_server/routes/cart.dart';
import 'package:ecommerce_server/routes/orders.dart';
import 'package:ecommerce_server/routes/source_labels.dart';
import 'package:ecommerce_server/routes/upload.dart';
import 'package:ecommerce_server/routes/stats.dart';

void main() async {
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 3000;

  // Initialize database
  initDatabase();
  seedDatabase();

  // Create API router
  final router = Router();
  registerAuthRoutes(router);
  registerProductRoutes(router);
  registerCartRoutes(router);
  registerOrderRoutes(router);
  registerSourceLabelRoutes(router);
  registerUploadRoutes(router);
  registerStatsRoutes(router);

  // Health check
  router.get('/api/health', (Request request) {
    return jsonResponse({
      'status': 'ok',
      'timestamp': DateTime.now().toIso8601String(),
    });
  });

  // Static file handler
  final publicDir = p.join(Directory.current.path, 'public');
  Handler? staticHandler;
  if (Directory(publicDir).existsSync()) {
    staticHandler = createStaticHandler(publicDir, defaultDocument: 'index.html');
  }

  // Uploads directory
  final dataDir = Platform.environment['DATA_DIR'] ?? Directory.current.path;
  final uploadsDir = p.join(dataDir, 'uploads');
  Directory(uploadsDir).createSync(recursive: true);

  // Main handler
  Future<Response> appHandler(Request request) async {
    final path = request.url.path;

    // Serve uploaded files
    if (path.startsWith('uploads/')) {
      final fileName = path.substring('uploads/'.length);
      final file = File(p.join(uploadsDir, fileName));
      if (file.existsSync()) {
        return Response.ok(
          file.readAsBytesSync(),
          headers: {'content-type': _mimeType(fileName)},
        );
      }
      return Response.notFound('File not found');
    }

    // Handle DELETE /api/cart (clear cart) - special case since shelf_router
    // can't distinguish DELETE /api/cart from DELETE /api/cart/<id>
    if (path == 'api/cart' && request.method == 'DELETE') {
      return await handleClearCart(request);
    }

    // API routes
    if (path.startsWith('api/') || path == 'api') {
      return await router.call(request);
    }

    // Static files (Flutter web build)
    if (staticHandler != null) {
      try {
        final response = await staticHandler(request);
        if (response.statusCode != 404) {
          return response;
        }
      } catch (_) {}
    }

    // SPA fallback: serve index.html for all non-API, non-file routes
    final indexFile = File(p.join(publicDir, 'index.html'));
    if (indexFile.existsSync()) {
      return Response.ok(
        indexFile.readAsStringSync(),
        headers: {'content-type': 'text/html'},
      );
    }

    return Response.notFound('Not found');
  }

  // Apply CORS middleware
  final handler = Pipeline()
      .addMiddleware(_corsMiddleware())
      .addHandler(appHandler);

  final server = await io.serve(handler, '0.0.0.0', port);
  print('🚀 E-commerce server running at http://localhost:${server.port}');
}

Middleware _corsMiddleware() {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Origin, Content-Type, Authorization',
  };

  return createMiddleware(
    requestHandler: (Request request) {
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: corsHeaders);
      }
      return null;
    },
    responseHandler: (Response response) {
      return response.change(headers: corsHeaders);
    },
  );
}

String _mimeType(String filename) {
  final ext = p.extension(filename).toLowerCase();
  switch (ext) {
    case '.jpg':
    case '.jpeg':
      return 'image/jpeg';
    case '.png':
      return 'image/png';
    case '.gif':
      return 'image/gif';
    case '.webp':
      return 'image/webp';
    default:
      return 'application/octet-stream';
  }
}
