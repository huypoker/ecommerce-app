import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../services/api_service.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});
  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  @override
  void initState() {
    super.initState();
    final token = context.read<AuthProvider>().token;
    if (token != null) context.read<CartProvider>().fetchCart(token);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final cart = context.watch<CartProvider>();
    final token = auth.token!;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/')),
        title: Text('Giỏ hàng (${cart.itemCount})'),
        actions: [
          if (cart.items.isNotEmpty)
            IconButton(icon: const Icon(Icons.delete_sweep), tooltip: 'Xóa tất cả',
                onPressed: () => cart.clearCart(token)),
        ],
      ),
      body: cart.loading
          ? const Center(child: CircularProgressIndicator())
          : cart.items.isEmpty
              ? Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    const Text('Giỏ hàng trống', style: TextStyle(fontSize: 18, color: Colors.grey)),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: () => context.go('/'), child: const Text('Tiếp tục mua sắm')),
                  ]),
                )
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: cart.items.length,
                        itemBuilder: (_, i) {
                          final item = cart.items[i];
                          final imgUrl = ApiService.resolveImageUrl(item['image_url'] ?? '');
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: imgUrl.isNotEmpty
                                        ? Image.network(imgUrl, width: 70, height: 70, fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => const SizedBox(width: 70, height: 70, child: Icon(Icons.image)))
                                        : const SizedBox(width: 70, height: 70, child: Icon(Icons.image)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 4),
                                        Text(formatVND(item['sell_price'] ?? 0),
                                            style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle_outline),
                                        onPressed: item['quantity'] > 1
                                            ? () => cart.updateQuantity(token, item['id'], item['quantity'] - 1)
                                            : null,
                                      ),
                                      Text('${item['quantity']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                      IconButton(
                                        icon: const Icon(Icons.add_circle_outline),
                                        onPressed: () => cart.updateQuantity(token, item['id'], item['quantity'] + 1),
                                      ),
                                    ],
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => cart.removeItem(token, item['id']),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, -2))],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('Tổng cộng:', style: TextStyle(color: Colors.grey)),
                            Text(formatVND(cart.subtotal),
                                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
                          ]),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}
