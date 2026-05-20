import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import '../../models/order.dart';
import '../../services/api_service.dart';

const _sourceTabs = [
  (null, 'Tất cả', Icons.list_alt),
  ('Hàn', 'Hàn', Icons.flag),
  ('QCCC', 'QCCC', Icons.flag),
  ('VNTK', 'VNTK', Icons.flag),
];

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});
  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  String? _status;
  String? _sort;
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _sourceTabs.length, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) _refresh();
    });
    _refresh();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  String? get _currentSource => _sourceTabs[_tabCtrl.index].$1;

  void _refresh() {
    final token = context.read<AuthProvider>().token!;
    context.read<OrderProvider>().fetchOrders(token,
        status: _status,
        search: _search.isEmpty ? null : _search,
        sort: _sort,
        source: _currentSource);
  }

  Future<void> _delete(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xác nhận'),
        content: const Text('Bạn có chắc muốn xóa đơn hàng này?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(context, true),
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
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _showDetail(Order o) {
    showDialog(context: context,
        builder: (_) => _OrderDetailDialog(order: o, openFb: _openFb));
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'da_hoan_thanh': return Colors.green;
      case 'da_tao_don': return Colors.orange;
      default: return Colors.grey;
    }
  }

  Color _sourceColor(String? source) {
    switch (source) {
      case 'Hàn': return Colors.purple;
      case 'QCCC': return Colors.blue;
      case 'VNTK': return Colors.teal;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final op = context.watch<OrderProvider>();
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/admin')),
        title: const Text('Quản lý đơn hàng'),
        actions: [
          IconButton(icon: const Icon(Icons.add),
              onPressed: () => context.go('/admin/orders/new')),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: _sourceTabs.map((t) => Tab(text: t.$2)).toList(),
        ),
      ),
      body: Column(children: [
        // Search + filters
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Tìm tên, SĐT, mã đơn...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              suffixIcon: _search.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear), onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _search = '');
                      _refresh();
                    }) : null,
            ),
            onSubmitted: (v) { setState(() => _search = v); _refresh(); },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            Expanded(child: DropdownButton<String?>(
              value: _status, isExpanded: true,
              underline: const SizedBox(), hint: const Text('Trạng thái'),
              items: const [
                DropdownMenuItem(value: null, child: Text('Tất cả')),
                DropdownMenuItem(value: 'chua_tao_don', child: Text('Chưa tạo đơn')),
                DropdownMenuItem(value: 'da_tao_don', child: Text('Đã tạo đơn')),
                DropdownMenuItem(value: 'da_hoan_thanh', child: Text('Đã hoàn thành')),
              ],
              onChanged: (v) { setState(() => _status = v); _refresh(); },
            )),
            const SizedBox(width: 12),
            Expanded(child: DropdownButton<String?>(
              value: _sort, isExpanded: true,
              underline: const SizedBox(), hint: const Text('Sắp xếp'),
              items: const [
                DropdownMenuItem(value: null, child: Text('Mới nhất')),
                DropdownMenuItem(value: 'oldest', child: Text('Cũ nhất')),
                DropdownMenuItem(value: 'total_desc', child: Text('Tổng giảm')),
                DropdownMenuItem(value: 'name_asc', child: Text('Tên A-Z')),
              ],
              onChanged: (v) { setState(() => _sort = v); _refresh(); },
            )),
          ]),
        ),
        const Divider(),
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
                        final pendingCount = o.items.where((it) => it.itemStatus == 'cho_hang').length;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            onTap: () => _showDetail(o),
                            leading: CircleAvatar(
                              backgroundColor: _statusColor(o.status).withOpacity(0.2),
                              child: Icon(Icons.receipt, color: _statusColor(o.status)),
                            ),
                            title: Row(children: [
                              Expanded(child: Text(o.customerName,
                                  style: const TextStyle(fontWeight: FontWeight.w600))),
                              if (o.source?.isNotEmpty == true)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: _sourceColor(o.source).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8)),
                                  child: Text(o.source!,
                                      style: TextStyle(fontSize: 11,
                                          color: _sourceColor(o.source),
                                          fontWeight: FontWeight.bold)),
                                ),
                            ]),
                            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              if (o.orderCode != null)
                                Text(o.orderCode!,
                                    style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                              Text('${o.customerPhone} · ${formatVND(o.total)}'
                                  '${o.totalProfit > 0 ? " · Lời: ${formatVND(o.totalProfit)}" : ""}'),
                              Row(children: [
                                Container(
                                  margin: const EdgeInsets.only(top: 3),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _statusColor(o.status).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12)),
                                  child: Text(o.statusLabel,
                                      style: TextStyle(fontSize: 11, color: _statusColor(o.status),
                                          fontWeight: FontWeight.w500)),
                                ),
                                if (pendingCount > 0) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    margin: const EdgeInsets.only(top: 3),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(12)),
                                    child: Text('⏳ $pendingCount chờ hàng',
                                        style: const TextStyle(fontSize: 11,
                                            color: Colors.orange, fontWeight: FontWeight.w500)),
                                  ),
                                ]
                              ]),
                            ]),
                            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                              IconButton(icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                                  onPressed: () => context.go('/admin/orders/${o.id}/edit')),
                              IconButton(icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                                  onPressed: () => _delete(o.id)),
                            ]),
                          ),
                        );
                      }),
        ),
      ]),
    );
  }
}

// ── Order detail dialog ──
class _OrderDetailDialog extends StatelessWidget {
  final Order order;
  final Future<void> Function(String?) openFb;
  const _OrderDetailDialog({required this.order, required this.openFb});

  Color _statusColor(String s) {
    switch (s) {
      case 'da_hoan_thanh': return Colors.green;
      case 'da_tao_don': return Colors.orange;
      default: return Colors.grey;
    }
  }

  Color _itemStatusColor(String s) {
    switch (s) {
      case 'da_ve_kho': return Colors.blue;
      case 'da_giao': return Colors.green;
      case 'huy': return Colors.red;
      default: return Colors.orange;
    }
  }

  String _itemStatusLabel(String s) {
    switch (s) {
      case 'da_ve_kho': return '📦 Đã về kho';
      case 'da_giao': return '✅ Đã giao';
      case 'huy': return '❌ Đã hủy';
      default: return '⏳ Chờ hàng';
    }
  }

  @override
  Widget build(BuildContext context) {
    final profit = order.totalProfit;
    return AlertDialog(
      title: Row(children: [
        const Icon(Icons.receipt_long, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(
          order.orderCode != null ? 'Đơn ${order.orderCode}' : 'Chi tiết đơn hàng',
          style: const TextStyle(fontSize: 16))),
      ]),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor(order.status).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20)),
                child: Text(order.statusLabel,
                    style: TextStyle(color: _statusColor(order.status), fontWeight: FontWeight.bold))),
              if (order.source?.isNotEmpty == true) ...[
                const SizedBox(width: 8),
                Chip(label: Text(order.source!), padding: EdgeInsets.zero,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 8)),
              ],
            ]),
            const SizedBox(height: 10),
            _row(Icons.person, order.customerName),
            if (order.customerPhone.isNotEmpty) _row(Icons.phone, order.customerPhone),
            if (order.customerFb?.isNotEmpty == true)
              InkWell(onTap: () => openFb(order.customerFb),
                  child: _row(Icons.facebook, order.customerFb!, color: Colors.blue)),
            if (order.note?.isNotEmpty == true)
              _row(Icons.notes, order.note!, italic: true),
            if (order.createdAt != null)
              _row(Icons.calendar_today, 'Ngày tạo: ${order.createdAt}', small: true),
            const Divider(height: 20),
            const Text('Sản phẩm', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            ...order.items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ClipRRect(borderRadius: BorderRadius.circular(8),
                    child: item.imageUrl.isNotEmpty
                        ? Image.network(ApiService.resolveImageUrl(item.imageUrl),
                            width: 56, height: 56, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _imgPlaceholder())
                        : _imgPlaceholder()),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.productName,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (item.productCode.isNotEmpty)
                    Text('Mã: ${item.productCode}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                  if (item.brand.isNotEmpty)
                    Text('Hãng: ${item.brand}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                  if (item.colorName.isNotEmpty)
                    Text('Màu: ${item.colorName}', style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 2),
                  Text('${formatVND(item.price)} × ${item.quantity} = ${formatVND(item.price * item.quantity)}',
                      style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.w500)),
                  if (item.importPrice > 0)
                    Text('Lời: ${formatVND(item.profit)}',
                        style: const TextStyle(color: Colors.green, fontSize: 12)),
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _itemStatusColor(item.itemStatus).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8)),
                    child: Text(_itemStatusLabel(item.itemStatus),
                        style: TextStyle(fontSize: 11, color: _itemStatusColor(item.itemStatus))),
                  ),
                ])),
              ]),
            )),
            const Divider(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Tổng cộng', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(formatVND(order.total), style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor)),
                ]),
                if (profit > 0) Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Tổng lời', style: TextStyle(color: Colors.grey)),
                  Text(formatVND(profit),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                ]),
              ]),
            ),
          ],
        )),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng')),
      ],
    );
  }

  Widget _row(IconData icon, String text,
      {Color? color, bool italic = false, bool small = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(children: [
        Icon(icon, size: 15, color: color ?? Colors.grey[600]),
        const SizedBox(width: 6),
        Flexible(child: Text(text,
            style: TextStyle(color: color,
                fontStyle: italic ? FontStyle.italic : FontStyle.normal,
                fontSize: small ? 12 : 14))),
      ]),
    );
  }

  Widget _imgPlaceholder() => Container(
    width: 56, height: 56, color: Colors.grey[200],
    child: const Icon(Icons.image, color: Colors.grey, size: 28));
}
