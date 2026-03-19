import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../database.dart';
import '../auth_middleware.dart';

void registerSourceLabelRoutes(Router router) {
  // Get all source labels (public)
  router.get('/api/source-labels', (Request request) async {
    try {
      final labels = queryAll('SELECT * FROM source_labels ORDER BY name ASC');
      return jsonResponse(labels);
    } catch (e) {
      return jsonResponse({'error': e.toString()}, statusCode: 500);
    }
  });

  // Create source label (admin only)
  router.post('/api/source-labels', (Request request) async {
    final authError = requireAdmin(request);
    if (authError != null) return authError;

    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final name = (body['name'] as String?)?.trim();
      if (name == null || name.isEmpty) {
        return jsonResponse({'error': 'Name is required'}, statusCode: 400);
      }

      execute('INSERT INTO source_labels (name) VALUES (?)', [name]);
      final label = queryOne('SELECT * FROM source_labels WHERE id = ?', [lastInsertRowId]);
      return jsonResponse(label, statusCode: 201);
    } catch (e) {
      if (e.toString().contains('UNIQUE')) {
        return jsonResponse({'error': 'Label already exists'}, statusCode: 409);
      }
      return jsonResponse({'error': e.toString()}, statusCode: 500);
    }
  });

  // Delete source label (admin only)
  router.delete('/api/source-labels/<id>', (Request request, String id) async {
    final authError = requireAdmin(request);
    if (authError != null) return authError;

    try {
      final labelId = int.parse(id);
      final existing = queryOne('SELECT * FROM source_labels WHERE id = ?', [labelId]);
      if (existing == null) {
        return jsonResponse({'error': 'Label not found'}, statusCode: 404);
      }
      execute('DELETE FROM source_labels WHERE id = ?', [labelId]);
      return jsonResponse({'message': 'Label deleted successfully'});
    } catch (e) {
      return jsonResponse({'error': e.toString()}, statusCode: 500);
    }
  });
}
