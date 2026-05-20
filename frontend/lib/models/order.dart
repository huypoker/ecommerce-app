class OrderItem {
  final int? id;
  final int productId;
  final String productName;
  final String productCode;
  final String imageUrl;
  final String colorName;
  final String brand;
  final double price;
  final double importPrice;
  final int quantity;
  final String itemStatus;

  OrderItem({
    this.id,
    required this.productId,
    required this.productName,
    this.productCode = '',
    this.imageUrl = '',
    this.colorName = '',
    this.brand = '',
    required this.price,
    this.importPrice = 0,
    required this.quantity,
    this.itemStatus = 'cho_hang',
  });

  double get profit => (price - importPrice) * quantity;

  String get itemStatusLabel {
    switch (itemStatus) {
      case 'da_ve_kho': return 'Đã về kho';
      case 'da_giao': return 'Đã giao';
      case 'huy': return 'Đã hủy';
      default: return 'Chờ hàng';
    }
  }

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
        id: json['id'],
        productId: json['product_id'],
        productName: json['product_name'] ?? '',
        productCode: json['product_code'] ?? '',
        imageUrl: json['image_url'] ?? '',
        colorName: json['color_name'] ?? '',
        brand: json['brand'] ?? '',
        price: (json['price'] ?? 0).toDouble(),
        importPrice: (json['import_price'] ?? 0).toDouble(),
        quantity: json['quantity'] ?? 1,
        itemStatus: json['item_status'] ?? 'cho_hang',
      );
}

class Order {
  final int id;
  final String? orderCode;
  final String customerName;
  final String customerPhone;
  final String? customerFb;
  final String status;
  final String? source;
  final double total;
  final String? note;
  final List<OrderItem> items;
  final String? createdAt;
  final String? updatedAt;

  double get totalProfit => items.fold(0, (s, i) => s + i.profit);

  Order({
    required this.id,
    this.orderCode,
    required this.customerName,
    required this.customerPhone,
    this.customerFb,
    required this.status,
    this.source,
    required this.total,
    this.note,
    required this.items,
    this.createdAt,
    this.updatedAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        id: json['id'],
        orderCode: json['order_code'],
        customerName: json['customer_name'] ?? '',
        customerPhone: json['customer_phone'] ?? '',
        customerFb: json['customer_fb'],
        status: json['status'] ?? 'chua_tao_don',
        source: json['source'],
        total: (json['total'] ?? 0).toDouble(),
        note: json['note'],
        items: (json['items'] as List?)
                ?.map((i) => OrderItem.fromJson(i))
                .toList() ??
            [],
        createdAt: json['created_at'],
        updatedAt: json['updated_at'],
      );

  String get statusLabel {
    switch (status) {
      case 'chua_tao_don':
        return 'Chưa tạo đơn';
      case 'da_tao_don':
        return 'Đã tạo đơn';
      case 'da_hoan_thanh':
        return 'Đã hoàn thành';
      default:
        return status;
    }
  }
}
