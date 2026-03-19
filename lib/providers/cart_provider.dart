import 'package:flutter/material.dart';
import '../services/api_service.dart';

class CartProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _items = [];
  double _subtotal = 0;
  bool _loading = false;

  List<Map<String, dynamic>> get items => _items;
  double get subtotal => _subtotal;
  int get itemCount => _items.length;
  bool get loading => _loading;

  Future<void> fetchCart(String token) async {
    _loading = true;
    notifyListeners();
    try {
      final data = await ApiService.getCart(token);
      _items = List<Map<String, dynamic>>.from(data['items'] ?? []);
      _subtotal = (data['subtotal'] ?? 0).toDouble();
    } catch (_) {}
    _loading = false;
    notifyListeners();
  }

  Future<void> addToCart(String token, int productId) async {
    await ApiService.addToCart(token, productId);
    await fetchCart(token);
  }

  Future<void> updateQuantity(String token, int id, int qty) async {
    await ApiService.updateCartItem(token, id, qty);
    await fetchCart(token);
  }

  Future<void> removeItem(String token, int id) async {
    await ApiService.removeCartItem(token, id);
    await fetchCart(token);
  }

  Future<void> clearCart(String token) async {
    await ApiService.clearCart(token);
    _items = [];
    _subtotal = 0;
    notifyListeners();
  }
}
