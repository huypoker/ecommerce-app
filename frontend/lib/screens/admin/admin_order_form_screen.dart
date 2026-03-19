import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/product_provider.dart';
import '../../models/product.dart';
import '../../services/api_service.dart';

class AdminOrderFormScreen extends StatefulWidget {
  final int? orderId;
  const AdminOrderFormScreen({super.key, this.orderId});
  @override
  State<AdminOrderFormScreen> createState() => _AdminOrderFormScreenState();
}

class _AdminOrderFormScreenState extends State<AdminOrderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _fbCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String _status = 'chua_tao_don';

  List<_OrderItemEntry> _items = [];
  List<Product> _allProducts = [];
  bool _loading = false;

  bool get _isEdit => widget.orderId != null;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    if (_isEdit) _loadOrder();
  }

  Future<void> _loadProducts() async {
    await context.read<ProductProvider>().fetchProducts();
    if (mounted) {
      setState(() => _allProducts = context.read<ProductProvider>().products);
    }
  }

  Future<void> _loadOrder() async {
    setState(() => _loading = true);
    final token = context.read<AuthProvider>().token!;
    try {
      // Fetch the specific order via the orders list then find it
      await context.read<OrderProvider>().fetchOrders(token);
      if (!mounted) return;
      final orders = context.read<OrderProvider>().orders;
      final order = orders.where((o) => o.id == widget.orderId).firstOrNull;
      if (order != null) {
        _nameCtrl.text = order.customerName;
        _phoneCtrl.text = order.customerPhone;
        _fbCtrl.text = order.customerFb ?? '';
        _noteCtrl.text = order.note ?? '';
        _status = order.status;
        _items = order.items
            .map((i) => _OrderItemEntry(productId: i.productId, quantity: i.quantity))
            .toList();
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  void _addItem() {
    if (_allProducts.isEmpty) return;
    setState(() {
      _items.add(_OrderItemEntry(
          productId: _allProducts.first.id, quantity: 1));
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cần ít nhất 1 sản phẩm')));
      return;
    }
    setState(() => _loading = true);
    final token = context.read<AuthProvider>().token!;
    final op = context.read<OrderProvider>();

    final data = {
      'customer_name': _nameCtrl.text.trim(),
      'customer_phone': _phoneCtrl.text.trim(),
      'customer_fb': _fbCtrl.text.trim(),
      'status': _status,
      'note': _noteCtrl.text.trim(),
      'items': _items
          .map((i) => {'product_id': i.productId, 'quantity': i.quantity})
          .toList(),
    };

    try {
      bool success;
      if (_isEdit) {
        success = await op.updateOrder(token, widget.orderId!, data);
      } else {
        final result = await op.createOrder(token, data);
        success = result != null;
      }
      if (success && mounted) context.go('/admin/orders');
      if (!success && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Lỗi khi lưu đơn hàng')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/admin/orders')),
        title: Text(_isEdit ? 'Sửa đơn hàng' : 'Tạo đơn hàng'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Customer info
                    const Text('Thông tin khách hàng',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Tên khách hàng *',
                          border: OutlineInputBorder()),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Bắt buộc' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Số điện thoại',
                          border: OutlineInputBorder()),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _fbCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Facebook (link)',
                          border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _status,
                      decoration: const InputDecoration(
                          labelText: 'Trạng thái',
                          border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(
                            value: 'chua_tao_don',
                            child: Text('Chưa tạo đơn')),
                        DropdownMenuItem(
                            value: 'da_tao_don',
                            child: Text('Đã tạo đơn')),
                        DropdownMenuItem(
                            value: 'da_hoan_thanh',
                            child: Text('Đã hoàn thành')),
                      ],
                      onChanged: (v) => setState(() => _status = v!),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _noteCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Ghi chú',
                          border: OutlineInputBorder()),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 20),
                    // Items
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Sản phẩm',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        TextButton.icon(
                          onPressed: _addItem,
                          icon: const Icon(Icons.add),
                          label: const Text('Thêm SP'),
                        ),
                      ],
                    ),
                    if (_items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Chưa có sản phẩm nào',
                            style: TextStyle(color: Colors.grey),
                            textAlign: TextAlign.center),
                      ),
                    ..._items.asMap().entries.map((e) {
                      final idx = e.key;
                      final item = e.value;
                      final selectedProduct = _allProducts
                          .where((p) => p.id == item.productId)
                          .firstOrNull;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: DropdownButtonFormField<int>(
                                  value: selectedProduct != null
                                      ? item.productId
                                      : (_allProducts.isNotEmpty
                                          ? _allProducts.first.id
                                          : null),
                                  decoration: const InputDecoration(
                                      labelText: 'Sản phẩm',
                                      border: OutlineInputBorder(),
                                      isDense: true),
                                  isExpanded: true,
                                  items: _allProducts
                                      .map((p) => DropdownMenuItem(
                                          value: p.id,
                                          child: Text(p.name,
                                              overflow:
                                                  TextOverflow.ellipsis)))
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => item.productId = v!),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 70,
                                child: TextFormField(
                                  initialValue: item.quantity.toString(),
                                  decoration: const InputDecoration(
                                      labelText: 'SL',
                                      border: OutlineInputBorder(),
                                      isDense: true),
                                  keyboardType: TextInputType.number,
                                  onChanged: (v) => item.quantity =
                                      int.tryParse(v) ?? 1,
                                ),
                              ),
                              IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () =>
                                      setState(() => _items.removeAt(idx))),
                            ],
                          ),
                        ),
                      );
                    }),
                    // Total preview
                    if (_items.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Builder(builder: (_) {
                          double total = 0;
                          for (final item in _items) {
                            final p = _allProducts
                                .where((p) => p.id == item.productId)
                                .firstOrNull;
                            if (p != null) {
                              total += p.sellPrice * item.quantity;
                            }
                          }
                          return Text(
                              'Tổng dự kiến: ${formatVND(total)}',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).primaryColor));
                        }),
                      ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _save,
                        child: Text(_isEdit ? 'Cập nhật' : 'Tạo đơn hàng',
                            style: const TextStyle(fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }
}

class _OrderItemEntry {
  int productId;
  int quantity;
  _OrderItemEntry({required this.productId, required this.quantity});
}
