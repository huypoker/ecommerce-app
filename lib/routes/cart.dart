import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../database.dart';
import '../auth_middleware.dart';

void registerCartRoutes(Router router) {
  // Get cart
  router.get('/api/cart', (Request request) async {
    final authError = requireAuth(request);
    if (authError != null) return authError;
    final user = getUser(request)!;

    try {
      final items = queryAll('''
        SELECT ci.id, ci.quantity, ci.product_id,
               p.name, p.sell_price, p.image_url, p.stock
        FROM cart_items ci
        JOIN products p ON ci.product_id = p.id
        WHERE ci.user_id = ?
        ORDER BY ci.created_at DESC
      ''', [user['id']]);

      double subtotal = 0;
      for (final item in items) {
        subtotal += (item['sell_price'] as num).toDouble() * (item['quantity'] as int);
      }

      return jsonResponse({
        'items': items,
        'subtotal': subtotal,
        'item_count': items.length,
      });
    } catch (e) {
      return jsonResponse({'error': e.toString()}, statusCode: 500);
    }
  });

  // Add to cart
  router.post('/api/cart', (Request request) async {
    final authError = requireAuth(request);
    if (authError != null) return authError;
    final user = getUser(request)!;

    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final productId = body['product_id'];

      if (productId == null) {
        return jsonResponse({'error': 'product_id is required'}, statusCode: 400);
      }

      final product = queryOne('SELECT * FROM products WHERE id = ?', [productId]);
      if (product == null) {
        return jsonResponse({'error': 'Product not found'}, statusCode: 404);
      }

      final qty = body['quantity'] ?? 1;
      final existing = queryOne(
        'SELECT * FROM cart_items WHERE user_id = ? AND product_id = ?',
        [user['id'], productId],
      );

      if (existing != null) {
        execute('UPDATE cart_items SET quantity = quantity + ? WHERE id = ?',
            [qty, existing['id']]);
      } else {
        execute('INSERT INTO cart_items (user_id, product_id, quantity) VALUES (?, ?, ?)',
            [user['id'], productId, qty]);
      }

      return jsonResponse({'message': 'Item added to cart'}, statusCode: 201);
    } catch (e) {
      return jsonResponse({'error': e.toString()}, statusCode: 500);
    }
  });

  // Update cart item
  router.put('/api/cart/<id>', (Request request, String id) async {
    final authError = requireAuth(request);
    if (authError != null) return authError;
    final user = getUser(request)!;

    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final quantity = body['quantity'] as int?;

      if (quantity == null || quantity < 1) {
        return jsonResponse({'error': 'Valid quantity is required'}, statusCode: 400);
      }

      final item = queryOne(
        'SELECT * FROM cart_items WHERE id = ? AND user_id = ?',
        [int.parse(id), user['id']],
      );
      if (item == null) {
        return jsonResponse({'error': 'Cart item not found'}, statusCode: 404);
      }

      execute('UPDATE cart_items SET quantity = ? WHERE id = ?', [quantity, int.parse(id)]);
      return jsonResponse({'message': 'Cart updated'});
    } catch (e) {
      return jsonResponse({'error': e.toString()}, statusCode: 500);
    }
  });

  // Remove item from cart (must be before clear to have specific path matched first)
  router.delete('/api/cart/<id>', (Request request, String id) async {
    final authError = requireAuth(request);
    if (authError != null) return authError;
    final user = getUser(request)!;

    try {
      final item = queryOne(
        'SELECT * FROM cart_items WHERE id = ? AND user_id = ?',
        [int.parse(id), user['id']],
      );
      if (item == null) {
        return jsonResponse({'error': 'Cart item not found'}, statusCode: 404);
      }

      execute('DELETE FROM cart_items WHERE id = ?', [int.parse(id)]);
      return jsonResponse({'message': 'Item removed from cart'});
    } catch (e) {
      return jsonResponse({'error': e.toString()}, statusCode: 500);
    }
  });
}

/// Handle DELETE /api/cart (clear cart) - registered separately in server.dart
Future<Response> handleClearCart(Request request) async {
  final authError = requireAuth(request);
  if (authError != null) return authError;
  final user = getUser(request)!;

  try {
    execute('DELETE FROM cart_items WHERE user_id = ?', [user['id']]);
    return jsonResponse({'message': 'Cart cleared'});
  } catch (e) {
    return jsonResponse({'error': e.toString()}, statusCode: 500);
  }
}
