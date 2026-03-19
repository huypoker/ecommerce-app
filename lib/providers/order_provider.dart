import 'package:flutter/material.dart';
import '../models/order.dart';
import '../services/api_service.dart';

class OrderProvider extends ChangeNotifier {
  List<Order> _orders = [];
  bool _loading = false;

  List<Order> get orders => _orders;
  bool get loading => _loading;

  Future<void> fetchOrders(String token,
      {String? status, String? search, String? sort}) async {
    _loading = true;
    notifyListeners();
    try {
      final data = await ApiService.getOrders(token,
          status: status, search: search, sort: sort);
      _orders = data.map((j) => Order.fromJson(j)).toList();
    } catch (_) {}
    _loading = false;
    notifyListeners();
  }

  Future<Order?> createOrder(String token, Map<String, dynamic> data) async {
    try {
      final res = await ApiService.createOrder(token, data);
      if (res['error'] != null) return null;
      return Order.fromJson(res);
    } catch (_) {
      return null;
    }
  }

  Future<bool> updateOrder(String token, int id, Map<String, dynamic> data) async {
    try {
      final res = await ApiService.updateOrder(token, id, data);
      return res['error'] == null;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteOrder(String token, int id) async {
    try {
      await ApiService.deleteOrder(token, id);
      _orders.removeWhere((o) => o.id == id);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }
}
