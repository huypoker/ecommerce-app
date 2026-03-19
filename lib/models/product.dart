class ProductColor {
  final int id;
  final String colorName;
  final String imageUrl;

  ProductColor({required this.id, required this.colorName, required this.imageUrl});

  factory ProductColor.fromJson(Map<String, dynamic> json) => ProductColor(
        id: json['id'] ?? 0,
        colorName: json['color_name'] ?? '',
        imageUrl: json['image_url'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'color_name': colorName,
        'image_url': imageUrl,
      };
}

class Product {
  final int id;
  final String code;
  final String name;
  final String description;
  final double importPrice;
  final double sellPrice;
  final double tiktokPrice;
  final String imageUrl;
  final String category;
  final String sizes;
  final String source;
  final double rating;
  final int reviewCount;
  final int stock;
  final List<ProductColor> colors;

  Product({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.importPrice,
    required this.sellPrice,
    required this.tiktokPrice,
    required this.imageUrl,
    required this.category,
    required this.sizes,
    required this.source,
    required this.rating,
    required this.reviewCount,
    required this.stock,
    required this.colors,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'],
        code: json['code'] ?? '',
        name: json['name'] ?? '',
        description: json['description'] ?? '',
        importPrice: (json['import_price'] ?? 0).toDouble(),
        sellPrice: (json['sell_price'] ?? 0).toDouble(),
        tiktokPrice: (json['tiktok_price'] ?? 0).toDouble(),
        imageUrl: json['image_url'] ?? '',
        category: json['category'] ?? '',
        sizes: json['sizes'] ?? '',
        source: json['source'] ?? '',
        rating: (json['rating'] ?? 0).toDouble(),
        reviewCount: json['review_count'] ?? 0,
        stock: json['stock'] ?? 0,
        colors: (json['colors'] as List?)
                ?.map((c) => ProductColor.fromJson(c))
                .toList() ??
            [],
      );

  List<String> get sizeList =>
      sizes.split(',').where((s) => s.trim().isNotEmpty).toList();
}
