import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

final jwtSecret = Platform.environment['JWT_SECRET'] ?? 'ecommerce_secret_key_2026';

Response jsonResponse(dynamic data, {int statusCode = 200}) {
  return Response(statusCode,
    body: jsonEncode(data),
    headers: {'content-type': 'application/json'},
  );
}

Map<String, dynamic>? getUser(Request request) {
  final authHeader = request.headers['authorization'];
  if (authHeader == null || !authHeader.startsWith('Bearer ')) return null;
  final token = authHeader.substring(7);
  try {
    final jwt = JWT.verify(token, SecretKey(jwtSecret));
    return jwt.payload as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}

Response? requireAuth(Request request) {
  final user = getUser(request);
  if (user == null) {
    return jsonResponse({'error': 'Access token required'}, statusCode: 401);
  }
  return null;
}

Response? requireAdmin(Request request) {
  final user = getUser(request);
  if (user == null) {
    return jsonResponse({'error': 'Access token required'}, statusCode: 401);
  }
  if (user['role'] != 'admin') {
    return jsonResponse({'error': 'Admin access required'}, statusCode: 403);
  }
  return null;
}

String generateToken(Map<String, dynamic> payload) {
  final jwt = JWT(payload);
  return jwt.sign(SecretKey(jwtSecret), expiresIn: Duration(days: 7));
}
