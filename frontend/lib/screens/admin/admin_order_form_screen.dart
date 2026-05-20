import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/product_provider.dart';
import '../../models/product.dart';
import '../../models/customer.dart';
import '../../services/api_service.dart';

const _sourceOptions = ['Hàn', 'QCCC', 'VNTK'];
const _quickSourceOptions = ['Hàn', 'VNTK', 'QCCC'];
const _quickSizeGroups = [
  ('Size số', ['66', '73', '80', '90', '100', '110', '120', '130', '140', '150']),
  ('Size chữ', ['XXS', 'XS', 'S', 'M', 'L', 'XL', 'JS', 'JM', 'JL']),
  ('Size tháng', ['6m', '12m', '18m']),
];

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
  String? _source;
  int? _selectedCustomerId;

  List<Customer> _customerSuggestions = [];
  bool _showSuggestions = false;

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
    if (mounted) setState(() => _allProducts = context.read<ProductProvider>().products);
  }

  Future<void> _searchCustomers(String q) async {
    if (q.isEmpty) { setState(() { _customerSuggestions = []; _showSuggestions = false; }); return; }
    try {
      final token = context.read<AuthProvider>().token!;
      final data = await ApiService.getCustomers(token, q: q);
      if (mounted) setState(() {
        _customerSuggestions = data.map((j) => Customer.fromJson(j)).toList();
        _showSuggestions = _customerSuggestions.isNotEmpty;
      });
    } catch (_) {}
  }

  void _selectCustomer(Customer c) {
    setState(() {
      _nameCtrl.text = c.name;
      _phoneCtrl.text = c.phone;
      _fbCtrl.text = c.facebookLink;
      _selectedCustomerId = c.id;
      _showSuggestions = false;
      _customerSuggestions = [];
    });
  }

  Future<void> _loadOrder() async {
    setState(() => _loading = true);
    final token = context.read<AuthProvider>().token!;
    try {
      await context.read<OrderProvider>().fetchOrders(token);
      if (!mounted) return;
      final order = context.read<OrderProvider>().orders
          .where((o) => o.id == widget.orderId).firstOrNull;
      if (order != null) {
        _nameCtrl.text = order.customerName;
        _phoneCtrl.text = order.customerPhone;
        _fbCtrl.text = order.customerFb ?? '';
        _noteCtrl.text = order.note ?? '';
        _status = order.status;
        _source = (order.source?.isNotEmpty == true) ? order.source : null;
        _items = order.items.map((i) => _OrderItemEntry(
          productId: i.productId, quantity: i.quantity,
          colorName: i.colorName.isEmpty ? null : i.colorName,
          brand: i.brand, itemStatus: i.itemStatus,
        )).toList();
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  void _addItem() {
    if (_allProducts.isEmpty) return;
    setState(() => _items.add(_OrderItemEntry(productId: _allProducts.first.id, quantity: 1)));
  }

  Future<void> _quickCreateProduct() async {
    final token = context.read<AuthProvider>().token!;
    final result = await showDialog<Map<String, dynamic>>(
      context: context, builder: (_) => const _QuickProductDialog());
    if (result == null || !mounted) return;
    try {
      final created = await ApiService.createProduct(token, result);
      if (created['id'] != null && mounted) {
        await context.read<ProductProvider>().fetchProducts();
        if (!mounted) return;
        setState(() {
          _allProducts = context.read<ProductProvider>().products;
          _items.add(_OrderItemEntry(productId: created['id'], quantity: 1));
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ Đã tạo sản phẩm: ${created["name"]}'),
          backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  Future<void> _upsertCustomer(String token) async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    try {
      final data = {'name': name, 'phone': _phoneCtrl.text.trim(),
          'facebook_link': _fbCtrl.text.trim()};
      if (_selectedCustomerId != null) {
        await ApiService.updateCustomer(token, _selectedCustomerId!, data);
      } else {
        final c = await ApiService.createCustomer(token, data);
        _selectedCustomerId = c['id'];
      }
    } catch (_) {}
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
    await _upsertCustomer(token);

    final data = {
      'customer_name': _nameCtrl.text.trim(),
      'customer_phone': _phoneCtrl.text.trim(),
      'customer_fb': _fbCtrl.text.trim(),
      'customer_id': _selectedCustomerId,
      'source': _source ?? '',
      'status': _status,
      'note': _noteCtrl.text.trim(),
      'items': _items.map((i) => {
        'product_id': i.productId, 'quantity': i.quantity,
        'color_name': i.colorName ?? '', 'brand': i.brand,
        'item_status': i.itemStatus,
      }).toList(),
    };

    try {
      bool success;
      if (_isEdit) {
        success = await op.updateOrder(token, widget.orderId!, data);
      } else {
        success = (await op.createOrder(token, data)) != null;
      }
      if (success && mounted) context.go('/admin/orders');
      if (!success && mounted) ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Lỗi khi lưu đơn hàng')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/admin/orders')),
        title: Text(_isEdit ? 'Sửa đơn hàng' : 'Tạo đơn hàng'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : GestureDetector(
              onTap: () => setState(() => _showSuggestions = false),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Source chips
                      Row(children: [
                        const Text('Nguồn: ',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        ..._sourceOptions.map((s) {
                          final sel = _source == s;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(s, style: TextStyle(
                                  color: sel ? Colors.white : Colors.black87,
                                  fontSize: 13)),
                              selected: sel,
                              selectedColor: Theme.of(context).primaryColor,
                              onSelected: (_) =>
                                  setState(() => _source = sel ? null : s),
                            ),
                          );
                        }),
                      ]),
                      const SizedBox(height: 16),
                      // Customer name + autocomplete
                      const Text('Thông tin khách hàng',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Stack(clipBehavior: Clip.none, children: [
                        TextFormField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Tên khách hàng *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.person)),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Bắt buộc' : null,
                          onChanged: (v) { _selectedCustomerId = null; _searchCustomers(v); },
                        ),
                        if (_showSuggestions)
                          Positioned(
                            top: 58, left: 0, right: 0,
                            child: Material(
                              elevation: 6, borderRadius: BorderRadius.circular(8),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxHeight: 200),
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: _customerSuggestions.length,
                                  itemBuilder: (_, i) {
                                    final c = _customerSuggestions[i];
                                    return ListTile(
                                      dense: true,
                                      leading: const Icon(Icons.person_outline, size: 18),
                                      title: Text(c.name),
                                      subtitle: Text('${c.phone}',
                                          style: const TextStyle(fontSize: 11)),
                                      onTap: () => _selectCustomer(c),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: TextFormField(
                          controller: _phoneCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Số điện thoại', border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.phone)),
                          keyboardType: TextInputType.phone)),
                        const SizedBox(width: 12),
                        Expanded(child: DropdownButtonFormField<String>(
                          value: _status,
                          decoration: const InputDecoration(
                              labelText: 'Trạng thái đơn', border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: 'chua_tao_don', child: Text('Chưa tạo đơn')),
                            DropdownMenuItem(value: 'da_tao_don', child: Text('Đã tạo đơn')),
                            DropdownMenuItem(value: 'da_hoan_thanh', child: Text('Đã hoàn thành')),
                          ],
                          onChanged: (v) => setState(() => _status = v!))),
                      ]),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _fbCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Facebook (link)', border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.link))),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _noteCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Ghi chú', border: OutlineInputBorder()),
                        maxLines: 2),
                      const SizedBox(height: 20),
                      // Items header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Sản phẩm',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                          Row(children: [
                            TextButton.icon(onPressed: _quickCreateProduct,
                                icon: const Icon(Icons.add_box, size: 18),
                                label: const Text('Tạo SP mới')),
                            TextButton.icon(onPressed: _addItem,
                                icon: const Icon(Icons.add),
                                label: const Text('Chọn SP')),
                          ]),
                        ],
                      ),
                      if (_items.isEmpty)
                        const Padding(padding: EdgeInsets.all(16),
                            child: Text('Chưa có sản phẩm nào',
                                style: TextStyle(color: Colors.grey),
                                textAlign: TextAlign.center)),
                      ..._items.asMap().entries.map((e) {
                        final idx = e.key;
                        final item = e.value;
                        final prod = _allProducts.where((p) => p.id == item.productId).firstOrNull;
                        final colors = prod?.colors ?? [];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Expanded(flex: 3, child: DropdownButtonFormField<int>(
                                  value: prod != null ? item.productId : (_allProducts.isNotEmpty ? _allProducts.first.id : null),
                                  decoration: const InputDecoration(labelText: 'Sản phẩm',
                                      border: OutlineInputBorder(), isDense: true),
                                  isExpanded: true,
                                  items: _allProducts.map((p) => DropdownMenuItem(
                                      value: p.id,
                                      child: Text(p.name, overflow: TextOverflow.ellipsis))).toList(),
                                  onChanged: (v) => setState(() { item.productId = v!; item.colorName = null; }),
                                )),
                                const SizedBox(width: 8),
                                SizedBox(width: 58, child: TextFormField(
                                  initialValue: item.quantity.toString(),
                                  decoration: const InputDecoration(labelText: 'SL',
                                      border: OutlineInputBorder(), isDense: true),
                                  keyboardType: TextInputType.number,
                                  onChanged: (v) => item.quantity = int.tryParse(v) ?? 1)),
                                IconButton(icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => setState(() => _items.removeAt(idx))),
                              ]),
                              const SizedBox(height: 8),
                              Row(children: [
                                Expanded(child: TextFormField(
                                  initialValue: item.brand,
                                  decoration: const InputDecoration(labelText: 'Hãng',
                                      border: OutlineInputBorder(), isDense: true),
                                  onChanged: (v) => item.brand = v)),
                                const SizedBox(width: 8),
                                Expanded(child: DropdownButtonFormField<String>(
                                  value: item.itemStatus,
                                  decoration: const InputDecoration(labelText: 'Trạng thái',
                                      border: OutlineInputBorder(), isDense: true),
                                  items: const [
                                    DropdownMenuItem(value: 'cho_hang',
                                        child: Text('⏳ Chờ hàng', style: TextStyle(fontSize: 13))),
                                    DropdownMenuItem(value: 'da_ve_kho',
                                        child: Text('📦 Đã về kho', style: TextStyle(fontSize: 13))),
                                    DropdownMenuItem(value: 'da_giao',
                                        child: Text('✅ Đã giao', style: TextStyle(fontSize: 13))),
                                    DropdownMenuItem(value: 'huy',
                                        child: Text('❌ Đã hủy', style: TextStyle(fontSize: 13))),
                                  ],
                                  onChanged: (v) => setState(() => item.itemStatus = v!))),
                              ]),
                              if (colors.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                DropdownButtonFormField<String?>(
                                  value: item.colorName,
                                  decoration: const InputDecoration(labelText: 'Màu sắc',
                                      border: OutlineInputBorder(), isDense: true),
                                  isExpanded: true,
                                  items: [
                                    const DropdownMenuItem(value: null, child: Text('-- Không chọn --')),
                                    ...colors.map((c) => DropdownMenuItem(
                                        value: c.colorName,
                                        child: Row(children: [
                                          if (c.imageUrl.isNotEmpty)
                                            Padding(padding: const EdgeInsets.only(right: 6),
                                                child: ClipRRect(borderRadius: BorderRadius.circular(4),
                                                    child: Image.network(c.imageUrl, width: 24, height: 24,
                                                        fit: BoxFit.cover,
                                                        errorBuilder: (_, __, ___) =>
                                                            const SizedBox(width: 24, height: 24)))),
                                          Text(c.colorName),
                                        ]))),
                                  ],
                                  onChanged: (v) => setState(() => item.colorName = v)),
                              ],
                            ]),
                          ),
                        );
                      }),
                      // Profit preview
                      if (_items.isNotEmpty) ...[
                        const Divider(),
                        Builder(builder: (_) {
                          double total = 0, profit = 0;
                          for (final item in _items) {
                            final p = _allProducts.where((p) => p.id == item.productId).firstOrNull;
                            if (p != null) {
                              total += p.sellPrice * item.quantity;
                              profit += (p.sellPrice - p.importPrice) * item.quantity;
                            }
                          }
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                const Text('Tổng dự kiến:', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                Text('Lời dự kiến:', style: TextStyle(color: Colors.green[700], fontSize: 12)),
                              ]),
                              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                Text(formatVND(total), style: TextStyle(
                                    fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
                                Text(formatVND(profit), style: const TextStyle(
                                    fontWeight: FontWeight.bold, color: Colors.green)),
                              ]),
                            ]),
                          );
                        }),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(height: 48,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _save,
                            child: Text(_isEdit ? 'Cập nhật' : 'Tạo đơn hàng',
                                style: const TextStyle(fontSize: 16)))),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _OrderItemEntry {
  int productId;
  int quantity;
  String? colorName;
  String brand;
  String itemStatus;
  _OrderItemEntry({required this.productId, required this.quantity,
      this.colorName, this.brand = '', this.itemStatus = 'cho_hang'});
}

class _QuickProductDialog extends StatefulWidget {
  const _QuickProductDialog();
  @override
  State<_QuickProductDialog> createState() => _QuickProductDialogState();
}

class _QuickProductDialogState extends State<_QuickProductDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _sellPriceCtrl = TextEditingController(text: '0');
  final _importPriceCtrl = TextEditingController(text: '0');
  final _tiktokPriceCtrl = TextEditingController(text: '0');
  final _categoryCtrl = TextEditingController();
  String? _source;
  final Set<String> _selectedSizes = {};
  final List<TextEditingController> _colorCtrls = [];
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tạo sản phẩm mới'),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(width: 480, child: SingleChildScrollView(child: Form(
        key: _formKey,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextFormField(controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Tên sản phẩm *', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Bắt buộc' : null),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextFormField(controller: _importPriceCtrl,
                decoration: const InputDecoration(labelText: 'Giá nhập', border: OutlineInputBorder()),
                keyboardType: TextInputType.number)),
            const SizedBox(width: 8),
            Expanded(child: TextFormField(controller: _sellPriceCtrl,
                decoration: const InputDecoration(labelText: 'Giá bán *', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Bắt buộc' : null)),
            const SizedBox(width: 8),
            Expanded(child: TextFormField(controller: _tiktokPriceCtrl,
                decoration: const InputDecoration(labelText: 'Giá TikTok', border: OutlineInputBorder()),
                keyboardType: TextInputType.number)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextFormField(controller: _categoryCtrl,
                decoration: const InputDecoration(labelText: 'Danh mục', border: OutlineInputBorder()))),
            const SizedBox(width: 8),
            Expanded(child: DropdownButtonFormField<String>(
                value: _source,
                decoration: const InputDecoration(labelText: 'Nguồn hàng', border: OutlineInputBorder()),
                items: _quickSourceOptions.map((s) =>
                    DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => setState(() => _source = v))),
          ]),
          const SizedBox(height: 10),
          const Text('Chọn Size', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 4),
          ..._quickSizeGroups.map((group) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(group.$1, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 2),
              Wrap(spacing: 4, runSpacing: 2, children: group.$2.map((size) {
                final sel = _selectedSizes.contains(size);
                return FilterChip(
                  label: Text(size, style: TextStyle(fontSize: 11,
                      color: sel ? Colors.white : Colors.black87)),
                  selected: sel,
                  selectedColor: Theme.of(context).primaryColor,
                  checkmarkColor: Colors.white,
                  backgroundColor: Colors.grey[100],
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                  onSelected: (v) => setState(() {
                    if (v) _selectedSizes.add(size); else _selectedSizes.remove(size);
                  }));
              }).toList()),
            ]),
          )),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Màu sắc', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            TextButton.icon(
                onPressed: () => setState(() => _colorCtrls.add(TextEditingController())),
                icon: const Icon(Icons.add, size: 16), label: const Text('Thêm màu')),
          ]),
          ..._colorCtrls.asMap().entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Expanded(child: TextFormField(controller: e.value,
                  decoration: InputDecoration(labelText: 'Tên màu ${e.key + 1}',
                      border: const OutlineInputBorder(), isDense: true))),
              IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                  onPressed: () => setState(() => _colorCtrls.removeAt(e.key))),
            ]),
          )),
          const SizedBox(height: 8),
        ]),
      ))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        ElevatedButton(
          onPressed: _saving ? null : () {
            if (!_formKey.currentState!.validate()) return;
            setState(() => _saving = true);
            Navigator.pop(context, {
              'name': _nameCtrl.text.trim(),
              'import_price': int.tryParse(_importPriceCtrl.text) ?? 0,
              'sell_price': int.tryParse(_sellPriceCtrl.text) ?? 0,
              'tiktok_price': int.tryParse(_tiktokPriceCtrl.text) ?? 0,
              'category': _categoryCtrl.text.trim(), 'source': _source ?? '',
              'sizes': _selectedSizes.join(','), 'description': '', 'image_url': '', 'stock': 0,
              'colors': _colorCtrls.where((c) => c.text.trim().isNotEmpty)
                  .map((c) => {'color_name': c.text.trim(), 'image_url': ''}).toList(),
            });
          },
          child: const Text('Tạo')),
      ],
    );
  }
}
