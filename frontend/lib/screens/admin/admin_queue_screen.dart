import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class AdminQueueScreen extends StatefulWidget {
  const AdminQueueScreen({super.key});
  @override
  State<AdminQueueScreen> createState() => _AdminQueueScreenState();
}

class _AdminQueueScreenState extends State<AdminQueueScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  // Track which items are being updated
  final Set<int> _updating = {};

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final token = context.read<AuthProvider>().token!;
      final data = await ApiService.getPendingQueue(token);
      setState(() => _items = data.cast<Map<String, dynamic>>());
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _markStatus(Map<String, dynamic> item, String newStatus) async {
    final id = item['id'] as int;
    setState(() => _updating.add(id));
    try {
      final token = context.read<AuthProvider>().token!;
      await ApiService.updateItemStatus(token, id, newStatus);
      await _fetch();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    } finally {
      if (mounted) setState(() => _updating.remove(id));
    }
  }

  Future<void> _openFb(String? fb) async {
    if (fb == null || fb.isEmpty) return;
    final uri = fb.startsWith('http') ? Uri.parse(fb) : Uri.parse('https://$fb');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  // Group items by product_name
  Map<String, List<Map<String, dynamic>>> get _grouped {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final item in _items) {
      final pName = item['product_name'] ?? 'Không rõ';
      final cName = item['color_name']?.toString() ?? '';
      final key = cName.isNotEmpty ? '$pName · $cName' : '$pName';
      map.putIfAbsent(key, () => []).add(item);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _grouped;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/admin')),
        title: Text('Hàng chờ về (${_items.length})'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetch),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.check_circle_outline, size: 64, color: Colors.green[300]),
                    const SizedBox(height: 16),
                    const Text('Không có sản phẩm nào đang chờ về!',
                        style: TextStyle(fontSize: 16, color: Colors.grey)),
                  ]),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: grouped.length,
                  itemBuilder: (_, i) {
                    final productKey = grouped.keys.elementAt(i);
                    final productItems = grouped[productKey]!;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Product header
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor.withOpacity(0.1),
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(12)),
                            ),
                            child: Row(children: [
                              const Icon(Icons.inventory_2_outlined, size: 18),
                              const SizedBox(width: 8),
                              Expanded(child: Text(productKey,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 14))),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text('${productItems.length} người chờ',
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.orange,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ]),
                          ),
                          // Customer queue — sorted by order date (FIFO, already sorted by backend)
                          ...productItems.asMap().entries.map((e) {
                            final rank = e.key + 1;
                            final item = e.value;
                            final itemId = item['id'] as int;
                            final isUpdating = _updating.contains(itemId);
                            final orderDate = item['order_date']?.toString() ?? '';
                            final fb = item['customer_fb']?.toString() ?? '';

                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                border: e.key < productItems.length - 1
                                    ? Border(bottom: BorderSide(
                                        color: Colors.grey.shade200))
                                    : null,
                              ),
                              child: Row(children: [
                                // Rank badge
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: rank == 1
                                        ? Colors.orange
                                        : Colors.grey[200],
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(child: Text('$rank',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: rank == 1
                                              ? Colors.white
                                              : Colors.grey[700]))),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(children: [
                                        Text(item['customer_name'] ?? '',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600)),
                                        if (item['order_code'] != null) ...[
                                          const SizedBox(width: 6),
                                          Text('(${item['order_code']})',
                                              style: TextStyle(fontSize: 11,
                                                  color: Colors.grey[500])),
                                        ],
                                      ]),
                                      if (item['customer_phone']?.isNotEmpty == true)
                                        Text(item['customer_phone'],
                                            style: const TextStyle(
                                                fontSize: 12, color: Colors.grey)),
                                      if (fb.isNotEmpty)
                                        InkWell(
                                          onTap: () => _openFb(fb),
                                          child: Row(children: [
                                            const Icon(Icons.facebook,
                                                size: 13, color: Colors.blue),
                                            const SizedBox(width: 3),
                                            Flexible(child: Text('Facebook',
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.blue,
                                                    decoration:
                                                        TextDecoration.underline))),
                                          ]),
                                        ),
                                      if (item['source']?.isNotEmpty == true)
                                        Text('Nguồn: ${item['source']}',
                                            style: const TextStyle(
                                                fontSize: 11, color: Colors.teal)),
                                      Text('Đặt: ${orderDate.split('T').first}',
                                          style: const TextStyle(
                                              fontSize: 11, color: Colors.grey)),
                                      Text('SL: ${item['quantity']}',
                                          style: const TextStyle(fontSize: 12)),
                                    ],
                                  ),
                                ),
                                // Action buttons
                                if (isUpdating)
                                  const SizedBox(width: 36, height: 36,
                                      child: Padding(padding: EdgeInsets.all(8),
                                          child: CircularProgressIndicator(strokeWidth: 2)))
                                else
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert),
                                    onSelected: (v) => _markStatus(item, v),
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(value: 'da_ve_kho',
                                          child: Row(children: [
                                            Icon(Icons.inventory, size: 16, color: Colors.blue),
                                            SizedBox(width: 8),
                                            Text('Đã về kho'),
                                          ])),
                                      PopupMenuItem(value: 'da_giao',
                                          child: Row(children: [
                                            Icon(Icons.check_circle, size: 16, color: Colors.green),
                                            SizedBox(width: 8),
                                            Text('Đã giao khách'),
                                          ])),
                                      PopupMenuItem(value: 'huy',
                                          child: Row(children: [
                                            Icon(Icons.cancel, size: 16, color: Colors.red),
                                            SizedBox(width: 8),
                                            Text('Hủy'),
                                          ])),
                                    ],
                                  ),
                              ]),
                            );
                          }),
                          const SizedBox(height: 4),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
