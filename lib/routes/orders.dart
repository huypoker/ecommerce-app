import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../database.dart';
import '../auth_middleware.dart';

void registerOrderRoutes(Router router) {
  // Get all orders (admin only)
  router.get('/api/orders', (Request request) async {
    final authError = requireAdmin(request);
    if (authError != null) return authError;

    try {
      final params = request.url.queryParameters;
      final status = params['status'];
      final search = params['search'];
      final sort = params['sort'];

      var query = 'SELECT * FROM orders WHERE 1=1';
      final queryParams = <Object?>[];

      if (status != null) {
        query += ' AND status = ?';
        queryParams.add(status);
      }
      if (search != null) {
        query += ' AND (customer_name LIKE ? OR customer_phone LIKE ?)';
        queryParams.addAll(['%$search%', '%$search%']);
      }

      switch (sort) {
        case 'oldest':
          query += ' ORDER BY created_at ASC';
          break;
        case 'total_desc':
          query += ' ORDER BY total DESC';
          break;
        case 'total_asc':
          query += ' ORDER BY total ASC';
          break;
        case 'name_asc':
          query += ' ORDER BY customer_name ASC';
          break;
        case 'newest':
        default:
          query += ' ORDER BY created_at DESC';
      }

      final orders = queryAll(query, queryParams);
      for (final order in orders) {
        order['items'] = queryAll(
            'SELECT * FROM order_items WHERE order_id = ?', [order['id']]);
      }

      return jsonResponse(orders);
    } catch (e) {
      return jsonResponse({'error': e.toString()}, statusCode: 500);
    }
  });

  // Get single order (admin only)
  router.get('/api/orders/<id>', (Request request, String id) async {
    final authError = requireAdmin(request);
    if (authError != null) return authError;

    try {
      final order = queryOne('SELECT * FROM orders WHERE id = ?', [int.parse(id)]);
      if (order == null) {
        return jsonResponse({'error': 'Order not found'}, statusCode: 404);
      }
      order['items'] = queryAll(
          'SELECT * FROM order_items WHERE order_id = ?', [order['id']]);
      return jsonResponse(order);
    } catch (e) {
      return jsonResponse({'error': e.toString()}, statusCode: 500);
    }
  });

  // Create order (admin only)
  router.post('/api/orders', (Request request) async {
    final authError = requireAdmin(request);
    if (authError != null) return authError;

    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final customerName = body['customer_name'] as String?;
      final items = body['items'] as List?;

      if (customerName == null) {
        return jsonResponse({'error': 'customer_name is required'}, statusCode: 400);
      }
      if (items == null || items.isEmpty) {
        return jsonResponse({'error': 'At least one item is required'}, statusCode: 400);
      }

      double total = 0;
      final processedItems = <Map<String, dynamic>>[];
      for (final item in items) {
        final productId = item['product_id'];
        final quantity = item['quantity'] ?? 1;
        if (productId == null) {
          return jsonResponse({'error': 'Each item needs product_id and quantity'}, statusCode: 400);
        }
        final product = queryOne('SELECT * FROM products WHERE id = ?', [productId]);
        if (product == null) {
          return jsonResponse({'error': 'Product ID $productId not found'}, statusCode: 404);
        }
        final price = (product['sell_price'] as num).toDouble();
        total += price * quantity;
        processedItems.add({
          'product_id': productId,
          'product_name': product['name'],
          'price': price,
          'quantity': quantity,
        });
      }

      final orderStatus = body['status'] ?? 'chua_tao_don';
      execute(
        'INSERT INTO orders (customer_name, customer_phone, customer_fb, status, total, note) VALUES (?, ?, ?, ?, ?, ?)',
        [customerName, body['customer_phone'] ?? '', body['customer_fb'] ?? '', orderStatus, total, body['note'] ?? ''],
      );
      final orderId = lastInsertRowId;

      for (final item in processedItems) {
        execute(
          'INSERT INTO order_items (order_id, product_id, product_name, price, quantity) VALUES (?, ?, ?, ?, ?)',
          [orderId, item['product_id'], item['product_name'], item['price'], item['quantity']],
        );
      }

      final order = queryOne('SELECT * FROM orders WHERE id = ?', [orderId])!;
      order['items'] = queryAll('SELECT * FROM order_items WHERE order_id = ?', [orderId]);
      return jsonResponse(order, statusCode: 201);
    } catch (e) {
      return jsonResponse({'error': e.toString()}, statusCode: 500);
    }
  });

  // Update order (admin only)
  router.put('/api/orders/<id>', (Request request, String id) async {
    final authError = requireAdmin(request);
    if (authError != null) return authError;

    try {
      final orderId = int.parse(id);
      final existing = queryOne('SELECT * FROM orders WHERE id = ?', [orderId]);
      if (existing == null) {
        return jsonResponse({'error': 'Order not found'}, statusCode: 404);
      }

      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final items = body['items'] as List?;

      var total = (existing['total'] as num).toDouble();
      if (items != null && items.isNotEmpty) {
        total = 0;
        final processedItems = <Map<String, dynamic>>[];
        for (final item in items) {
          final product = queryOne('SELECT * FROM products WHERE id = ?', [item['product_id']]);
          if (product == null) {
            return jsonResponse({'error': 'Product ID ${item['product_id']} not found'}, statusCode: 404);
          }
          final price = (product['sell_price'] as num).toDouble();
          total += price * (item['quantity'] ?? 1);
          processedItems.add({
            'product_id': item['product_id'],
            'product_name': product['name'],
            'price': price,
            'quantity': item['quantity'] ?? 1,
          });
        }

        execute('DELETE FROM order_items WHERE order_id = ?', [orderId]);
        for (final item in processedItems) {
          execute(
            'INSERT INTO order_items (order_id, product_id, product_name, price, quantity) VALUES (?, ?, ?, ?, ?)',
            [orderId, item['product_id'], item['product_name'], item['price'], item['quantity']],
          );
        }
      }

      execute('''
        UPDATE orders SET
          customer_name = COALESCE(?, customer_name),
          customer_phone = COALESCE(?, customer_phone),
          customer_fb = COALESCE(?, customer_fb),
          status = COALESCE(?, status),
          total = ?,
          note = COALESCE(?, note),
          updated_at = CURRENT_TIMESTAMP
        WHERE id = ?
      ''', [
        body['customer_name'],
        body.containsKey('customer_phone') ? body['customer_phone'] : null,
        body.containsKey('customer_fb') ? body['customer_fb'] : null,
        body['status'],
        total,
        body.containsKey('note') ? body['note'] : null,
        orderId,
      ]);

      final order = queryOne('SELECT * FROM orders WHERE id = ?', [orderId])!;
      order['items'] = queryAll('SELECT * FROM order_items WHERE order_id = ?', [orderId]);
      return jsonResponse(order);
    } catch (e) {
      return jsonResponse({'error': e.toString()}, statusCode: 500);
    }
  });

  // Delete order (admin only)
  router.delete('/api/orders/<id>', (Request request, String id) async {
    final authError = requireAdmin(request);
    if (authError != null) return authError;

    try {
      final orderId = int.parse(id);
      final existing = queryOne('SELECT * FROM orders WHERE id = ?', [orderId]);
      if (existing == null) {
        return jsonResponse({'error': 'Order not found'}, statusCode: 404);
      }
      execute('DELETE FROM orders WHERE id = ?', [orderId]);
      return jsonResponse({'message': 'Order deleted successfully'});
    } catch (e) {
      return jsonResponse({'error': e.toString()}, statusCode: 500);
    }
  });
}
