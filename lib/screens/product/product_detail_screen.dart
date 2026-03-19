import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/product.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/product_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/app_footer.dart';

class ProductDetailScreen extends StatefulWidget {
  final int id;
  const ProductDetailScreen({super.key, required this.id});
  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  Product? _product;
  bool _loading = true;
  int _selectedColor = -1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await context.read<ProductProvider>().getProduct(widget.id);
    if (mounted) setState(() { _product = p; _loading = false; });
  }

  String get _displayImage {
    if (_product == null) return '';
    if (_selectedColor >= 0 && _selectedColor < _product!.colors.length) {
      final colorImg = _product!.colors[_selectedColor].imageUrl;
      if (colorImg.isNotEmpty) return ApiService.resolveImageUrl(colorImg);
    }
    return ApiService.resolveImageUrl(_product!.imageUrl);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/')),
        title: Text(_product?.name ?? 'Chi tiết sản phẩm'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _product == null
              ? const Center(child: Text('Không tìm thấy sản phẩm'))
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image
                      Container(
                        width: double.infinity,
                        height: 350,
                        color: Colors.grey[100],
                        child: _displayImage.isNotEmpty
                            ? Image.network(_displayImage, fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 100))
                            : const Icon(Icons.image, size: 100),
                      ),
                      // Color swatches
                      if (_product!.colors.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Màu sắc:', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: List.generate(_product!.colors.length, (i) {
                                  final c = _product!.colors[i];
                                  final sel = _selectedColor == i;
                                  return GestureDetector(
                                    onTap: () => setState(() => _selectedColor = sel ? -1 : i),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                            color: sel ? Theme.of(context).primaryColor : Colors.grey,
                                            width: sel ? 2 : 1),
                                        borderRadius: BorderRadius.circular(20),
                                        color: sel ? Theme.of(context).primaryColor.withOpacity(0.1) : null,
                                      ),
                                      child: Text(c.colorName),
                                    ),
                                  );
                                }),
                              ),
                            ],
                          ),
                        ),
                      // Info
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_product!.code.isNotEmpty)
                              Text('Mã: ${_product!.code}', style: TextStyle(color: Colors.grey[600])),
                            const SizedBox(height: 8),
                            Text(_product!.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text(formatVND(_product!.sellPrice),
                                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold,
                                    color: Theme.of(context).primaryColor)),
                            if (_product!.tiktokPrice > 0) ...[
                              const SizedBox(height: 4),
                              Text('Giá TikTok: ${formatVND(_product!.tiktokPrice)}',
                                  style: TextStyle(color: Colors.grey[600])),
                            ],
                            const SizedBox(height: 12),
                            if (_product!.sizeList.isNotEmpty)
                              Wrap(
                                spacing: 8,
                                children: _product!.sizeList.map((s) => Chip(label: Text(s))).toList(),
                              ),
                            if (_product!.source.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text('Nguồn: ${_product!.source}', style: TextStyle(color: Colors.grey[600])),
                            ],
                            if (_product!.rating > 0) ...[
                              const SizedBox(height: 8),
                              Row(children: [
                                Icon(Icons.star, color: Colors.amber[700]),
                                Text(' ${_product!.rating} (${_product!.reviewCount} đánh giá)'),
                              ]),
                            ],
                            const SizedBox(height: 8),
                            Text('Tồn kho: ${_product!.stock}', style: TextStyle(color: Colors.grey[600])),
                            const SizedBox(height: 16),
                            if (_product!.description.isNotEmpty)
                              Text(_product!.description, style: const TextStyle(fontSize: 15, height: 1.5)),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.add_shopping_cart),
                                label: const Text('Thêm vào giỏ hàng', style: TextStyle(fontSize: 16)),
                                onPressed: auth.isLoggedIn
                                    ? () async {
                                        await context.read<CartProvider>().addToCart(auth.token!, _product!.id);
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Đã thêm vào giỏ hàng')));
                                        }
                                      }
                                    : () => context.go('/login'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const AppFooter(),
                    ],
                  ),
                ),
    );
  }
}
