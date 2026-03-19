import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/api_service.dart';

class ProductProvider extends ChangeNotifier {
  List<Product> _products = [];
  List<String> _categories = [];
  List<String> _sourceLabels = [];
  bool _loading = false;

  List<Product> get products => _products;
  List<String> get categories => _categories;
  List<String> get sourceLabels => _sourceLabels;
  bool get loading => _loading;

  Future<void> fetchProducts({String? category, String? search, String? sort, String? source}) async {
    _loading = true;
    notifyListeners();
    try {
      final data = await ApiService.getProducts(
          category: category, search: search, sort: sort, source: source);
      _products = data.map((j) => Product.fromJson(j)).toList();
    } catch (_) {}
    _loading = false;
    notifyListeners();
  }

  Future<void> fetchCategories() async {
    try {
      _categories = await ApiService.getCategories();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> fetchSourceLabels() async {
    try {
      final data = await ApiService.getSourceLabels();
      _sourceLabels = data.map((l) => l['name'].toString()).toList();
      notifyListeners();
    } catch (_) {}
  }

  Future<Product?> getProduct(int id) async {
    try {
      final data = await ApiService.getProduct(id);
      return Product.fromJson(data);
    } catch (_) {
      return null;
    }
  }
}
