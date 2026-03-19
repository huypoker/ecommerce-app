import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import '../../services/api_service.dart';

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});
  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  String? _status;
  String? _sort;
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    final token = context.read<AuthProvider>().token!;
    context.read<OrderProvider>().fetchOrders(token,
        status: _status,
        search: _search.isEmpty ? null : _search,
        sort: _sort);
  }

  Future<void> _delete(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xác nhận'),
        content: const Text('Bạn có chắc muốn xóa đơn hàng này?'),
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
      await context.read<OrderProvider>().deleteOrder(token, id);
    }
  }

  Future<void> _openFb(String? fb) async {
    if (fb == null || fb.isEmpty) return;
    final uri = fb.startsWith('http') ? Uri.parse(fb) : Uri.parse('https://$fb');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'da_hoan_thanh':
        return Colors.green;
      case 'da_tao_don':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final op = context.watch<OrderProvider>();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/admin')),
        title: const Text('Quản lý đơn hàng'),
        actions: [
          IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => context.go('/admin/orders/new')),
        ],
      ),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Tìm theo tên, SĐT...',
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
          // Filters row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                // Status filter
                Expanded(
                  child: DropdownButton<String?>(
                    value: _status,
                    isExpanded: true,
                    underline: const SizedBox(),
                    hint: const Text('Trạng thái'),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('Tất cả')),
                      DropdownMenuItem(
                          value: 'chua_tao_don',
                          child: Text('Chưa tạo đơn')),
                      DropdownMenuItem(
                          value: 'da_tao_don', child: Text('Đã tạo đơn')),
                      DropdownMenuItem(
                          value: 'da_hoan_thanh',
                          child: Text('Đã hoàn thành')),
                    ],
                    onChanged: (v) {
                      setState(() => _status = v);
                      _refresh();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // Sort
                Expanded(
                  child: DropdownButton<String?>(
                    value: _sort,
                    isExpanded: true,
                    underline: const SizedBox(),
                    hint: const Text('Sắp xếp'),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('Mới nhất')),
                      DropdownMenuItem(
                          value: 'oldest', child: Text('Cũ nhất')),
                      DropdownMenuItem(
                          value: 'total_desc', child: Text('Tổng giảm')),
                      DropdownMenuItem(
                          value: 'total_asc', child: Text('Tổng tăng')),
                      DropdownMenuItem(
                          value: 'name_asc', child: Text('Tên A-Z')),
                    ],
                    onChanged: (v) {
                      setState(() => _sort = v);
                      _refresh();
                    },
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          // Order list
          Expanded(
            child: op.loading
                ? const Center(child: CircularProgressIndicator())
                : op.orders.isEmpty
                    ? const Center(child: Text('Không có đơn hàng nào'))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: op.orders.length,
                        itemBuilder: (_, i) {
                          final o = op.orders[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ExpansionTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    _statusColor(o.status).withOpacity(0.2),
                                child: Icon(Icons.receipt,
                                    color: _statusColor(o.status)),
                              ),
                              title: Text(o.customerName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      '${o.customerPhone} · ${formatVND(o.total)}'),
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _statusColor(o.status)
                                          .withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(o.statusLabel,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: _statusColor(o.status),
                                            fontWeight: FontWeight.w500)),
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                      icon: const Icon(Icons.edit,
                                          size: 20, color: Colors.blue),
                                      onPressed: () => context.go(
                                          '/admin/orders/${o.id}/edit')),
                                  IconButton(
                                      icon: const Icon(Icons.delete,
                                          size: 20, color: Colors.red),
                                      onPressed: () => _delete(o.id)),
                                ],
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                      16, 0, 16, 12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (o.customerFb != null &&
                                          o.customerFb!.isNotEmpty)
                                        InkWell(
                                          onTap: () => _openFb(o.customerFb),
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 8),
                                            child: Row(children: [
                                              const Icon(Icons.facebook,
                                                  size: 16,
                                                  color: Colors.blue),
                                              const SizedBox(width: 4),
                                              Flexible(
                                                child: Text(o.customerFb!,
                                                    style: const TextStyle(
                                                        color: Colors.blue,
                                                        decoration:
                                                            TextDecoration
                                                                .underline)),
                                              ),
                                            ]),
                                          ),
                                        ),
                                      if (o.note != null &&
                                          o.note!.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              bottom: 8),
                                          child: Text('Ghi chú: ${o.note}',
                                              style: const TextStyle(
                                                  fontStyle:
                                                      FontStyle.italic)),
                                        ),
                                      const Text('Sản phẩm:',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w600)),
                                      ...o.items.map((item) => Padding(
                                            padding:
                                                const EdgeInsets.only(top: 4),
                                            child: Text(
                                                '  • ${item.productName} x${item.quantity} — ${formatVND(item.price * item.quantity)}'),
                                          )),
                                      if (o.createdAt != null)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 8),
                                          child: Text(
                                              'Tạo: ${o.createdAt}',
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey)),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
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
