import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/product_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/app_footer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _category;
  String? _sort;
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final pp = context.read<ProductProvider>();
    pp.fetchProducts();
    pp.fetchCategories();
  }

  void _refresh() {
    context.read<ProductProvider>().fetchProducts(
        category: _category, search: _search.isEmpty ? null : _search, sort: _sort);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final pp = context.watch<ProductProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cửa hàng'),
        actions: [
          if (auth.isAdmin)
            IconButton(icon: const Icon(Icons.admin_panel_settings), onPressed: () => context.go('/admin')),
          if (auth.isLoggedIn)
            IconButton(icon: const Icon(Icons.shopping_cart), onPressed: () => context.go('/cart')),
          if (auth.isLoggedIn)
            IconButton(icon: const Icon(Icons.logout), onPressed: () => auth.logout())
          else
            TextButton(onPressed: () => context.go('/login'),
                child: const Text('Đăng nhập', style: TextStyle(color: Colors.white))),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm sản phẩm...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear), onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _search = '');
                        _refresh();
                      })
                    : null,
              ),
              onSubmitted: (v) { setState(() => _search = v); _refresh(); },
            ),
          ),
          // Category chips
          if (pp.categories.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _chip('Tất cả', null),
                  ...pp.categories.map((c) => _chip(c, c)),
                ],
              ),
            ),
          // Sort
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                const Text('Sắp xếp: ', style: TextStyle(fontWeight: FontWeight.w500)),
                DropdownButton<String?>(
                  value: _sort,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Mới nhất')),
                    DropdownMenuItem(value: 'price_asc', child: Text('Giá tăng')),
                    DropdownMenuItem(value: 'price_desc', child: Text('Giá giảm')),
                    DropdownMenuItem(value: 'rating', child: Text('Đánh giá')),
                  ],
                  onChanged: (v) { setState(() => _sort = v); _refresh(); },
                ),
              ],
            ),
          ),
          // Products grid
          Expanded(
            child: pp.loading
                ? const Center(child: CircularProgressIndicator())
                : pp.products.isEmpty
                    ? const Center(child: Text('Không có sản phẩm nào'))
                    : GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 250,
                          childAspectRatio: 0.65,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: pp.products.length,
                        itemBuilder: (_, i) {
                          final p = pp.products[i];
                          final imgUrl = ApiService.resolveImageUrl(p.imageUrl);
                          return GestureDetector(
                            onTap: () => context.go('/product/${p.id}'),
                            child: Card(
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: imgUrl.isNotEmpty
                                        ? Image.network(imgUrl, width: double.infinity, fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 60))
                                        : const Center(child: Icon(Icons.image, size: 60)),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 4),
                                        Text(formatVND(p.sellPrice),
                                            style: TextStyle(color: Theme.of(context).primaryColor,
                                                fontWeight: FontWeight.bold, fontSize: 15)),
                                        if (p.rating > 0)
                                          Row(children: [
                                            Icon(Icons.star, size: 14, color: Colors.amber[700]),
                                            Text(' ${p.rating}', style: const TextStyle(fontSize: 12)),
                                          ]),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          const AppFooter(),
        ],
      ),
    );
  }

  Widget _chip(String label, String? value) {
    final sel = _category == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: sel,
        selectedColor: Theme.of(context).primaryColor,
        labelStyle: TextStyle(color: sel ? Colors.white : null),
        onSelected: (_) { setState(() => _category = value); _refresh(); },
      ),
    );
  }
}
