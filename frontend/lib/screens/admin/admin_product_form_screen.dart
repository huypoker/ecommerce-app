import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/product_provider.dart';
import '../../services/api_service.dart';
import 'package:file_picker/file_picker.dart';

class AdminProductFormScreen extends StatefulWidget {
  final int? productId;
  const AdminProductFormScreen({super.key, this.productId});
  @override
  State<AdminProductFormScreen> createState() => _AdminProductFormScreenState();
}

class _AdminProductFormScreenState extends State<AdminProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _importPriceCtrl = TextEditingController(text: '0');
  final _sellPriceCtrl = TextEditingController(text: '0');
  final _tiktokPriceCtrl = TextEditingController(text: '0');
  final _imageUrlCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _sizesCtrl = TextEditingController();
  final _sourceCtrl = TextEditingController();
  final _stockCtrl = TextEditingController(text: '0');

  List<_ColorEntry> _colors = [];
  bool _loading = false;
  bool _uploading = false;

  bool get _isEdit => widget.productId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _loadProduct();
    context.read<ProductProvider>().fetchSourceLabels();
  }

  Future<void> _loadProduct() async {
    setState(() => _loading = true);
    final p =
        await context.read<ProductProvider>().getProduct(widget.productId!);
    if (p != null && mounted) {
      _codeCtrl.text = p.code;
      _nameCtrl.text = p.name;
      _descCtrl.text = p.description;
      _importPriceCtrl.text = p.importPrice.toInt().toString();
      _sellPriceCtrl.text = p.sellPrice.toInt().toString();
      _tiktokPriceCtrl.text = p.tiktokPrice.toInt().toString();
      _imageUrlCtrl.text = p.imageUrl;
      _categoryCtrl.text = p.category;
      _sizesCtrl.text = p.sizes;
      _sourceCtrl.text = p.source;
      _stockCtrl.text = p.stock.toString();
      _colors = p.colors
          .map((c) => _ColorEntry(name: c.colorName, imageUrl: c.imageUrl))
          .toList();
    }
    setState(() => _loading = false);
  }

  Future<void> _pickMainImage() async {
    final token = context.read<AuthProvider>().token!;
    await _uploadImage(
        token, (url) => setState(() => _imageUrlCtrl.text = url));
  }

  Future<void> _pickColorImage(int index) async {
    final token = context.read<AuthProvider>().token!;
    await _uploadImage(
        token, (url) => setState(() => _colors[index].imageUrl = url));
  }

  Future<void> _uploadImage(String token, void Function(String) onUrl) async {
    try {
      final result = await FilePicker.platform
          .pickFiles(type: FileType.image, withData: true);
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.bytes == null) return;
      setState(() => _uploading = true);
      final url = await ApiService.uploadImage(token, file.bytes!, file.name);
      if (url.isNotEmpty) {
        onUrl(url);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('✅ Upload ảnh thành công!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Upload lỗi: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final token = context.read<AuthProvider>().token!;

    final data = {
      'code': _codeCtrl.text.trim(),
      'name': _nameCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'import_price': int.tryParse(_importPriceCtrl.text) ?? 0,
      'sell_price': int.tryParse(_sellPriceCtrl.text) ?? 0,
      'tiktok_price': int.tryParse(_tiktokPriceCtrl.text) ?? 0,
      'image_url': _imageUrlCtrl.text.trim(),
      'category': _categoryCtrl.text.trim(),
      'sizes': _sizesCtrl.text.trim(),
      'source': _sourceCtrl.text.trim(),
      'stock': int.tryParse(_stockCtrl.text) ?? 0,
      'colors': _colors
          .where((c) => c.name.isNotEmpty)
          .map((c) => {'color_name': c.name, 'image_url': c.imageUrl})
          .toList(),
    };

    try {
      if (_isEdit) {
        await ApiService.updateProduct(token, widget.productId!, data);
      } else {
        await ApiService.createProduct(token, data);
      }
      if (mounted) context.go('/admin/products');
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
    final pp = context.watch<ProductProvider>();
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/admin/products')),
        title: Text(_isEdit ? 'Sửa sản phẩm' : 'Thêm sản phẩm'),
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
                    _field(_codeCtrl, 'Mã sản phẩm'),
                    _field(_nameCtrl, 'Tên sản phẩm', required: true),
                    _field(_descCtrl, 'Mô tả', maxLines: 3),
                    Row(children: [
                      Expanded(
                          child: _field(_importPriceCtrl, 'Giá nhập',
                              number: true)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _field(_sellPriceCtrl, 'Giá bán',
                              number: true, required: true)),
                    ]),
                    Row(children: [
                      Expanded(
                          child: _field(_tiktokPriceCtrl, 'Giá TikTok',
                              number: true)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _field(_stockCtrl, 'Tồn kho', number: true)),
                    ]),
                    _field(_categoryCtrl, 'Danh mục'),
                    _field(_sizesCtrl, 'Sizes (cách nhau bởi dấu phẩy)'),
                    // Source dropdown or text
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: pp.sourceLabels.isNotEmpty
                          ? DropdownButtonFormField<String>(
                              value: _sourceCtrl.text.isNotEmpty &&
                                      pp.sourceLabels.contains(_sourceCtrl.text)
                                  ? _sourceCtrl.text
                                  : null,
                              decoration: const InputDecoration(
                                  labelText: 'Nguồn hàng',
                                  border: OutlineInputBorder()),
                              items: pp.sourceLabels
                                  .map((s) => DropdownMenuItem(
                                      value: s, child: Text(s)))
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _sourceCtrl.text = v ?? ''),
                            )
                          : TextFormField(
                              controller: _sourceCtrl,
                              decoration: const InputDecoration(
                                  labelText: 'Nguồn hàng',
                                  border: OutlineInputBorder()),
                            ),
                    ),
                    // Main image
                    const Text('Ảnh chính',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (_imageUrlCtrl.text.isEmpty) ...[
                      Row(children: [
                        Expanded(
                          child: TextFormField(
                            controller: _imageUrlCtrl,
                            decoration: const InputDecoration(
                                hintText: 'URL ảnh hoặc upload',
                                border: OutlineInputBorder()),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _uploading ? null : _pickMainImage,
                          icon: const Icon(Icons.upload),
                          label: Text(_uploading ? 'Đang tải...' : 'Upload'),
                        ),
                      ]),
                    ] else ...[
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              ApiService.resolveImageUrl(_imageUrlCtrl.text),
                              height: 150,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                height: 150,
                                color: Colors.grey[200],
                                child: const Center(child: Icon(Icons.broken_image, size: 40)),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Row(children: [
                              _imageAction(Icons.edit, 'Đổi ảnh', Colors.blue, () => _pickMainImage()),
                              const SizedBox(width: 4),
                              _imageAction(Icons.delete, 'Xóa', Colors.red, () {
                                setState(() => _imageUrlCtrl.text = '');
                              }),
                            ]),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),
                    // Colors section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Màu sắc',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        TextButton.icon(
                          onPressed: () => setState(() =>
                              _colors.add(_ColorEntry(name: '', imageUrl: ''))),
                          icon: const Icon(Icons.add),
                          label: const Text('Thêm màu'),
                        ),
                      ],
                    ),
                    ..._colors.asMap().entries.map((e) {
                      final idx = e.key;
                      final c = e.value;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              Row(children: [
                                Expanded(
                                  child: TextFormField(
                                    initialValue: c.name,
                                    decoration: const InputDecoration(
                                        labelText: 'Tên màu',
                                        border: OutlineInputBorder()),
                                    onChanged: (v) => c.name = v,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    onPressed: () =>
                                        setState(() => _colors.removeAt(idx))),
                              ]),
                              const SizedBox(height: 8),
                              if (c.imageUrl.isEmpty) ...[
                                Row(children: [
                                  const Expanded(
                                    child: Text('Chưa có ảnh',
                                        style: TextStyle(color: Colors.grey)),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: _uploading
                                        ? null
                                        : () => _pickColorImage(idx),
                                    icon: const Icon(Icons.upload, size: 16),
                                    label: const Text('Upload ảnh'),
                                  ),
                                ]),
                              ] else ...[
                                const SizedBox(height: 8),
                                Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        ApiService.resolveImageUrl(c.imageUrl),
                                        height: 100,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          height: 100,
                                          color: Colors.grey[200],
                                          child: const Center(child: Icon(Icons.broken_image)),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: Row(children: [
                                        _imageAction(Icons.edit, 'Đổi', Colors.blue,
                                            () => _pickColorImage(idx)),
                                        const SizedBox(width: 4),
                                        _imageAction(Icons.delete, 'Xóa', Colors.red, () {
                                          setState(() => _colors[idx].imageUrl = '');
                                        }),
                                      ]),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _save,
                        child: Text(_isEdit ? 'Cập nhật' : 'Tạo sản phẩm',
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

  Widget _imageAction(IconData icon, String tooltip, Color color, VoidCallback onTap) {
    return Material(
      color: color.withOpacity(0.9),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 4),
            Text(tooltip, style: const TextStyle(color: Colors.white, fontSize: 12)),
          ]),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label,
      {bool number = false, bool required = false, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        decoration: InputDecoration(
            labelText: label, border: const OutlineInputBorder()),
        keyboardType: number ? TextInputType.number : TextInputType.text,
        maxLines: maxLines,
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'Bắt buộc' : null
            : null,
      ),
    );
  }
}

class _ColorEntry {
  String name;
  String imageUrl;
  _ColorEntry({required this.name, required this.imageUrl});
}
