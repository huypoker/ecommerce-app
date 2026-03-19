import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class AdminRevenueScreen extends StatefulWidget {
  const AdminRevenueScreen({super.key});
  @override
  State<AdminRevenueScreen> createState() => _AdminRevenueScreenState();
}

class _AdminRevenueScreenState extends State<AdminRevenueScreen> {
  String _period = 'day';
  Map<String, dynamic>? _data;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final token = context.read<AuthProvider>().token!;
      final res = await ApiService.getRevenue(token, period: _period);
      if (mounted) setState(() => _data = res);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  String _periodLabel(String p) {
    switch (p) {
      case 'day':
        return 'Theo ngày';
      case 'month':
        return 'Theo tháng';
      case 'year':
        return 'Theo năm';
      default:
        return p;
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _data?['summary'] as Map<String, dynamic>?;
    final rows = (_data?['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/admin')),
        title: const Text('Thống kê doanh thu'),
      ),
      body: Column(
        children: [
          // Period selector
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'day', label: Text('Ngày')),
                ButtonSegment(value: 'month', label: Text('Tháng')),
                ButtonSegment(value: 'year', label: Text('Năm')),
              ],
              selected: {_period},
              onSelectionChanged: (v) {
                setState(() => _period = v.first);
                _fetch();
              },
            ),
          ),
          // Summary cards
          if (summary != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Card(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(children: [
                          const Text('Tổng doanh thu',
                              style: TextStyle(color: Colors.grey)),
                          const SizedBox(height: 8),
                          Text(
                              formatVND(
                                  (summary['total_revenue'] ?? 0).toDouble()),
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).primaryColor)),
                        ]),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Card(
                      color: Colors.green.withOpacity(0.1),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(children: [
                          const Text('Tổng đơn hoàn thành',
                              style: TextStyle(color: Colors.grey)),
                          const SizedBox(height: 8),
                          Text('${summary['total_orders'] ?? 0}',
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green)),
                        ]),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          // Data table
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : rows.isEmpty
                    ? const Center(child: Text('Chưa có dữ liệu'))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(12),
                        child: SizedBox(
                          width: double.infinity,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(
                                Theme.of(context)
                                    .primaryColor
                                    .withOpacity(0.1)),
                            columns: [
                              DataColumn(
                                  label: Text(_periodLabel(_period),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold))),
                              const DataColumn(
                                  label: Text('Doanh thu',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold))),
                              const DataColumn(
                                  label: Text('Số đơn',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold))),
                            ],
                            rows: rows.map((r) {
                              return DataRow(cells: [
                                DataCell(Text(r['period']?.toString() ?? '')),
                                DataCell(Text(formatVND(
                                    (r['revenue'] ?? 0).toDouble()))),
                                DataCell(
                                    Text('${r['order_count'] ?? 0}')),
                              ]);
                            }).toList(),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
