import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/product_provider.dart';
import '../../services/api_service.dart';

class AdminProductsScreen extends StatefulWidget {
  const AdminProductsScreen({super.key});
  @override
  State<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends State<AdminProductsScreen> {
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<ProductProvider>().fetchProducts();
  }

  void _refresh() {
    context
        .read<ProductProvider>()
        .fetchProducts(search: _search.isEmpty ? null : _search);
  }

  Future<void> _delete(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xác nhận'),
        content: const Text('Bạn có chắc muốn xóa sản phẩm này?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Xóa', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true && mounted) {
      final token = context.read<AuthProvider>().token!;
      await ApiService.deleteProduct(token, id);
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pp = context.watch<ProductProvider>();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/admin')),
        title: const Text('Quản lý sản phẩm'),
        actions: [
          IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => context.go('/admin/products/new')),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm sản phẩm...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _search = '');
                          _refresh();
                        })
                    : null,
              ),
              onSubmitted: (v) {
                setState(() => _search = v);
                _refresh();
              },
            ),
          ),
          Expanded(
            child: pp.loading
                ? const Center(child: CircularProgressIndicator())
                : pp.products.isEmpty
                    ? const Center(child: Text('Không có sản phẩm nào'))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: pp.products.length,
                        itemBuilder: (_, i) {
                          final p = pp.products[i];
                          final imgUrl =
                              ApiService.resolveImageUrl(p.imageUrl);
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: imgUrl.isNotEmpty
                                    ? Image.network(imgUrl,
                                        width: 50,
                                        height: 50,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const SizedBox(
                                                width: 50,
                                                height: 50,
                                                child: Icon(Icons.image)))
                                    : const SizedBox(
                                        width: 50,
                                        height: 50,
                                        child: Icon(Icons.image)),
                              ),
                              title: Text(p.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                  '${p.code} · ${formatVND(p.sellPrice)} · Kho: ${p.stock}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                      icon: const Icon(Icons.edit,
                                          color: Colors.blue),
                                      onPressed: () => context.go(
                                          '/admin/products/${p.id}/edit')),
                                  IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: Colors.red),
                                      onPressed: () => _delete(p.id)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
