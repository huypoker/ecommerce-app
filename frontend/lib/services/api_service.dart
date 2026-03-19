import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class ApiService {
  static String get baseUrl {
    final origin = Uri.base.origin;
    if (origin.contains('localhost') || origin.contains('127.0.0.1')) {
      return 'http://localhost:3000';
    }
    return origin;
  }

  static String resolveImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    return '$baseUrl/$url';
  }

  static Map<String, String> _h(String? token, {bool json = true}) => {
        if (json) 'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  // ── Auth ──
  static Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await http.post(Uri.parse('$baseUrl/api/auth/login'),
        headers: _h(null), body: jsonEncode({'email': email, 'password': password}));
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> register(
      String name, String email, String password) async {
    final res = await http.post(Uri.parse('$baseUrl/api/auth/register'),
        headers: _h(null),
        body: jsonEncode({'name': name, 'email': email, 'password': password}));
    return jsonDecode(res.body);
  }

  // ── Products ──
  static Future<List<dynamic>> getProducts(
      {String? category, String? search, String? sort, String? source}) async {
    final params = <String, String>{};
    if (category != null) params['category'] = category;
    if (search != null) params['search'] = search;
    if (sort != null) params['sort'] = sort;
    if (source != null) params['source'] = source;
    final uri = Uri.parse('$baseUrl/api/products').replace(queryParameters: params.isEmpty ? null : params);
    final res = await http.get(uri);
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getProduct(int id) async {
    final res = await http.get(Uri.parse('$baseUrl/api/products/$id'));
    return jsonDecode(res.body);
  }

  static Future<List<String>> getCategories() async {
    final res = await http.get(Uri.parse('$baseUrl/api/products/meta/categories'));
    return List<String>.from(jsonDecode(res.body));
  }

  static Future<Map<String, dynamic>> createProduct(
      String token, Map<String, dynamic> data) async {
    final res = await http.post(Uri.parse('$baseUrl/api/products'),
        headers: _h(token), body: jsonEncode(data));
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> updateProduct(
      String token, int id, Map<String, dynamic> data) async {
    final res = await http.put(Uri.parse('$baseUrl/api/products/$id'),
        headers: _h(token), body: jsonEncode(data));
    return jsonDecode(res.body);
  }

  static Future<void> deleteProduct(String token, int id) async {
    await http.delete(Uri.parse('$baseUrl/api/products/$id'), headers: _h(token));
  }

  // ── Cart ──
  static Future<Map<String, dynamic>> getCart(String token) async {
    final res =
        await http.get(Uri.parse('$baseUrl/api/cart'), headers: _h(token));
    return jsonDecode(res.body);
  }

  static Future<void> addToCart(String token, int productId, {int qty = 1}) async {
    await http.post(Uri.parse('$baseUrl/api/cart'),
        headers: _h(token),
        body: jsonEncode({'product_id': productId, 'quantity': qty}));
  }

  static Future<void> updateCartItem(String token, int id, int quantity) async {
    await http.put(Uri.parse('$baseUrl/api/cart/$id'),
        headers: _h(token), body: jsonEncode({'quantity': quantity}));
  }

  static Future<void> removeCartItem(String token, int id) async {
    await http.delete(Uri.parse('$baseUrl/api/cart/$id'), headers: _h(token));
  }

  static Future<void> clearCart(String token) async {
    await http.delete(Uri.parse('$baseUrl/api/cart'), headers: _h(token));
  }

  // ── Orders ──
  static Future<List<dynamic>> getOrders(String token,
      {String? status, String? search, String? sort}) async {
    final params = <String, String>{};
    if (status != null) params['status'] = status;
    if (search != null) params['search'] = search;
    if (sort != null) params['sort'] = sort;
    final uri = Uri.parse('$baseUrl/api/orders').replace(queryParameters: params.isEmpty ? null : params);
    final res = await http.get(uri, headers: _h(token));
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> createOrder(
      String token, Map<String, dynamic> data) async {
    final res = await http.post(Uri.parse('$baseUrl/api/orders'),
        headers: _h(token), body: jsonEncode(data));
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> updateOrder(
      String token, int id, Map<String, dynamic> data) async {
    final res = await http.put(Uri.parse('$baseUrl/api/orders/$id'),
        headers: _h(token), body: jsonEncode(data));
    return jsonDecode(res.body);
  }

  static Future<void> deleteOrder(String token, int id) async {
    await http.delete(Uri.parse('$baseUrl/api/orders/$id'), headers: _h(token));
  }

  // ── Source Labels ──
  static Future<List<dynamic>> getSourceLabels() async {
    final res = await http.get(Uri.parse('$baseUrl/api/source-labels'));
    return jsonDecode(res.body);
  }

  // ── Stats ──
  static Future<Map<String, dynamic>> getRevenue(String token,
      {String period = 'day'}) async {
    final res = await http.get(
        Uri.parse('$baseUrl/api/stats/revenue?period=$period'),
        headers: _h(token));
    return jsonDecode(res.body);
  }

  // ── Upload ──
  static Future<String> uploadImage(String token, Uint8List bytes, String filename) async {
    final req = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/upload'));
    req.headers['Authorization'] = 'Bearer $token';
    final ext = filename.split('.').last.toLowerCase();
    final mimeTypes = {'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png', 'gif': 'image/gif', 'webp': 'image/webp'};
    final contentType = mimeTypes[ext] ?? 'image/jpeg';
    req.files.add(http.MultipartFile.fromBytes('image', bytes,
        filename: filename,
        contentType: MediaType.parse(contentType)));
    final res = await req.send();
    final body = await res.stream.bytesToString();
    final json = jsonDecode(body);
    return json['url'] ?? '';
  }
}

String formatVND(num price) {
  final str = price.toInt().toString();
  final buf = StringBuffer();
  for (var i = 0; i < str.length; i++) {
    if (i > 0 && (str.length - i) % 3 == 0) buf.write('.');
    buf.write(str[i]);
  }
  return '${buf}đ';
}
