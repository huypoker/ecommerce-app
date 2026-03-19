import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../database.dart';
import '../auth_middleware.dart';

void registerProductRoutes(Router router) {
  // Get categories (must be before /<id>)
  router.get('/api/products/meta/categories', (Request request) async {
    try {
      final categories = queryAll(
        'SELECT DISTINCT category FROM products WHERE category IS NOT NULL AND category != ""',
      );
      return jsonResponse(categories.map((c) => c['category']).toList());
    } catch (e) {
      return jsonResponse({'error': e.toString()}, statusCode: 500);
    }
  });

  // Get all products
  router.get('/api/products', (Request request) async {
    try {
      final params = request.url.queryParameters;
      final category = params['category'];
      final search = params['search'];
      final sort = params['sort'];
      final source = params['source'];

      var query = 'SELECT * FROM products WHERE 1=1';
      final queryParams = <Object?>[];

      if (category != null) {
        query += ' AND category = ?';
        queryParams.add(category);
      }
      if (source != null) {
        query += ' AND source = ?';
        queryParams.add(source);
      }
      if (search != null) {
        query += ' AND (name LIKE ? OR description LIKE ? OR code LIKE ?)';
        queryParams.addAll(['%$search%', '%$search%', '%$search%']);
      }

      switch (sort) {
        case 'price_asc':
          query += ' ORDER BY sell_price ASC';
          break;
        case 'price_desc':
          query += ' ORDER BY sell_price DESC';
          break;
        case 'rating':
          query += ' ORDER BY rating DESC';
          break;
        case 'newest':
        default:
          query += ' ORDER BY created_at DESC';
      }

      final products = queryAll(query, queryParams);
      for (final p in products) {
        p['colors'] = queryAll(
          'SELECT id, color_name, image_url FROM product_colors WHERE product_id = ?',
          [p['id']],
        );
      }

      return jsonResponse(products);
    } catch (e) {
      return jsonResponse({'error': e.toString()}, statusCode: 500);
    }
  });

  // Get single product
  router.get('/api/products/<id>', (Request request, String id) async {
    try {
      final product = queryOne('SELECT * FROM products WHERE id = ?', [int.parse(id)]);
      if (product == null) {
        return jsonResponse({'error': 'Product not found'}, statusCode: 404);
      }
      product['colors'] = queryAll(
        'SELECT id, color_name, image_url FROM product_colors WHERE product_id = ?',
        [product['id']],
      );
      return jsonResponse(product);
    } catch (e) {
      return jsonResponse({'error': e.toString()}, statusCode: 500);
    }
  });

  // Create product (admin only)
  router.post('/api/products', (Request request) async {
    final authError = requireAdmin(request);
    if (authError != null) return authError;

    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final name = body['name'] as String?;
      final sellPrice = body['sell_price'];

      if (name == null || sellPrice == null) {
        return jsonResponse({'error': 'Name and sell_price are required'}, statusCode: 400);
      }

      final sizes = body['sizes'];
      final sizesStr = sizes is List ? sizes.join(',') : (sizes?.toString() ?? '');

      execute('''
        INSERT INTO products (code, name, description, import_price, sell_price, tiktok_price, image_url, category, sizes, source, stock)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''', [
        body['code'] ?? '', name, body['description'] ?? '',
        body['import_price'] ?? 0, sellPrice, body['tiktok_price'] ?? 0,
        body['image_url'] ?? '', body['category'] ?? '',
        sizesStr, body['source'] ?? '', body['stock'] ?? 0,
      ]);
      final productId = lastInsertRowId;

      final colors = body['colors'];
      if (colors is List) {
        for (final c in colors) {
          if (c is Map && c['color_name'] != null) {
            execute('INSERT INTO product_colors (product_id, color_name, image_url) VALUES (?, ?, ?)',
                [productId, c['color_name'], c['image_url'] ?? '']);
          }
        }
      }

      final product = queryOne('SELECT * FROM products WHERE id = ?', [productId])!;
      product['colors'] = queryAll(
          'SELECT id, color_name, image_url FROM product_colors WHERE product_id = ?', [productId]);
      return jsonResponse(product, statusCode: 201);
    } catch (e) {
      return jsonResponse({'error': e.toString()}, statusCode: 500);
    }
  });

  // Update product (admin only)
  router.put('/api/products/<id>', (Request request, String id) async {
    final authError = requireAdmin(request);
    if (authError != null) return authError;

    try {
      final productId = int.parse(id);
      final existing = queryOne('SELECT * FROM products WHERE id = ?', [productId]);
      if (existing == null) {
        return jsonResponse({'error': 'Product not found'}, statusCode: 404);
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;

      final sizes = body['sizes'];
      final sizesStr = sizes != null
          ? (sizes is List ? sizes.join(',') : sizes.toString())
          : existing['sizes'];

      execute('''
        UPDATE products SET
          code = COALESCE(?, code),
          name = COALESCE(?, name),
          description = COALESCE(?, description),
          import_price = COALESCE(?, import_price),
          sell_price = COALESCE(?, sell_price),
          tiktok_price = COALESCE(?, tiktok_price),
          image_url = COALESCE(?, image_url),
          category = COALESCE(?, category),
          sizes = ?,
          source = COALESCE(?, source),
          stock = COALESCE(?, stock),
          updated_at = CURRENT_TIMESTAMP
        WHERE id = ?
      ''', [
        body.containsKey('code') ? body['code'] : null,
        body['name'],
        body.containsKey('description') ? body['description'] : null,
        body.containsKey('import_price') ? body['import_price'] : null,
        body.containsKey('sell_price') ? body['sell_price'] : null,
        body.containsKey('tiktok_price') ? body['tiktok_price'] : null,
        body.containsKey('image_url') ? body['image_url'] : null,
        body.containsKey('category') ? body['category'] : null,
        sizesStr,
        body.containsKey('source') ? body['source'] : null,
        body.containsKey('stock') ? body['stock'] : null,
        productId,
      ]);

      final colors = body['colors'];
      if (colors is List) {
        execute('DELETE FROM product_colors WHERE product_id = ?', [productId]);
        for (final c in colors) {
          if (c is Map && c['color_name'] != null) {
            execute('INSERT INTO product_colors (product_id, color_name, image_url) VALUES (?, ?, ?)',
                [productId, c['color_name'], c['image_url'] ?? '']);
          }
        }
      }

      final product = queryOne('SELECT * FROM products WHERE id = ?', [productId])!;
      product['colors'] = queryAll(
          'SELECT id, color_name, image_url FROM product_colors WHERE product_id = ?', [productId]);
      return jsonResponse(product);
    } catch (e) {
      return jsonResponse({'error': e.toString()}, statusCode: 500);
    }
  });

  // Delete product (admin only)
  router.delete('/api/products/<id>', (Request request, String id) async {
    final authError = requireAdmin(request);
    if (authError != null) return authError;

    try {
      final productId = int.parse(id);
      final existing = queryOne('SELECT * FROM products WHERE id = ?', [productId]);
      if (existing == null) {
        return jsonResponse({'error': 'Product not found'}, statusCode: 404);
      }
      execute('DELETE FROM products WHERE id = ?', [productId]);
      return jsonResponse({'message': 'Product deleted successfully'});
    } catch (e) {
      return jsonResponse({'error': e.toString()}, statusCode: 500);
    }
  });
}
