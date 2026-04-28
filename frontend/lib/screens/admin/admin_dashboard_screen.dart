import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/')),
        title: const Text('Quản trị'),
        actions: [
          IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () {
                auth.logout();
                context.go('/');
              }),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Xin chào, ${auth.user?.name ?? 'Admin'}!',
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold)),
                ),
                if (auth.isSuperAdmin)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.purple.withOpacity(0.4)),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.shield, size: 14, color: Colors.purple),
                      SizedBox(width: 4),
                      Text('Super Admin',
                          style: TextStyle(
                              color: Colors.purple,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ]),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF40BFFF).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Admin',
                        style: TextStyle(
                            color: Color(0xFF40BFFF),
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.3,
                children: [
                  _tile(context, Icons.inventory_2, 'Sản phẩm',
                      'Quản lý sản phẩm', '/admin/products'),
                  _tile(context, Icons.receipt_long, 'Đơn hàng',
                      'Quản lý đơn hàng', '/admin/orders'),
                  _tile(context, Icons.bar_chart, 'Doanh thu',
                      'Thống kê doanh thu', '/admin/revenue'),
                  _tile(context, Icons.storefront, 'Cửa hàng',
                      'Xem trang chủ', '/'),
                  if (auth.isSuperAdmin)
                    _tile(context, Icons.manage_accounts, 'Tài khoản',
                        'Quản lý tài khoản', '/admin/users',
                        color: Colors.purple),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String title,
      String subtitle, String route, {Color? color}) {
    final tileColor = color ?? Theme.of(context).primaryColor;
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () => context.go(route),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: tileColor),
              const SizedBox(height: 12),
              Text(title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
