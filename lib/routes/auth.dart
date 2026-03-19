import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../database.dart';
import '../password_helper.dart';
import '../auth_middleware.dart';

void registerAuthRoutes(Router router) {
  router.post('/api/auth/login', (Request request) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final email = body['email'] as String?;
      final password = body['password'] as String?;

      if (email == null || password == null) {
        return jsonResponse({'error': 'Email and password are required'}, statusCode: 400);
      }

      final user = queryOne('SELECT * FROM users WHERE email = ?', [email]);
      if (user == null) {
        return jsonResponse({'error': 'Invalid email or password'}, statusCode: 401);
      }

      if (!verifyPassword(password, user['password'] as String)) {
        return jsonResponse({'error': 'Invalid email or password'}, statusCode: 401);
      }

      final token = generateToken({
        'id': user['id'],
        'email': user['email'],
        'role': user['role'],
        'name': user['name'],
      });

      return jsonResponse({
        'token': token,
        'user': {
          'id': user['id'],
          'name': user['name'],
          'email': user['email'],
          'role': user['role'],
        },
      });
    } catch (e) {
      return jsonResponse({'error': e.toString()}, statusCode: 500);
    }
  });

  router.post('/api/auth/register', (Request request) async {
    try {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final name = body['name'] as String?;
      final email = body['email'] as String?;
      final password = body['password'] as String?;
      final role = body['role'] as String?;

      if (name == null || email == null || password == null) {
        return jsonResponse({'error': 'Name, email and password are required'}, statusCode: 400);
      }

      final existing = queryOne('SELECT id FROM users WHERE email = ?', [email]);
      if (existing != null) {
        return jsonResponse({'error': 'Email already registered'}, statusCode: 409);
      }

      final hashedPassword = hashPassword(password);
      final userRole = role == 'admin' ? 'admin' : 'user';

      execute('INSERT INTO users (name, email, password, role) VALUES (?, ?, ?, ?)',
          [name, email, hashedPassword, userRole]);
      final userId = lastInsertRowId;

      final token = generateToken({
        'id': userId,
        'email': email,
        'role': userRole,
        'name': name,
      });

      return jsonResponse({
        'token': token,
        'user': {'id': userId, 'name': name, 'email': email, 'role': userRole},
      }, statusCode: 201);
    } catch (e) {
      return jsonResponse({'error': e.toString()}, statusCode: 500);
    }
  });
}
