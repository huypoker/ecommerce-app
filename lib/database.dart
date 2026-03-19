import 'dart:io';
import 'package:sqlite3/sqlite3.dart';
import 'package:path/path.dart' as p;

late Database db;

Map<String, dynamic> _rowToMap(Row row, List<String> columns) {
  return {for (final col in columns) col: row[col]};
}

Map<String, dynamic>? queryOne(String sql, [List<Object?> params = const []]) {
  final result = db.select(sql, params);
  if (result.isEmpty) return null;
  return _rowToMap(result.first, result.columnNames);
}

List<Map<String, dynamic>> queryAll(String sql, [List<Object?> params = const []]) {
  final result = db.select(sql, params);
  return result.map((row) => _rowToMap(row, result.columnNames)).toList();
}

void execute(String sql, [List<Object?> params = const []]) {
  db.execute(sql, params);
}

int get lastInsertRowId => db.lastInsertRowId;

void initDatabase() {
  final dataDir = Platform.environment['DATA_DIR'] ?? Directory.current.path;
  final dir = Directory(dataDir);
  if (!dir.existsSync()) dir.createSync(recursive: true);

  db = sqlite3.open(p.join(dataDir, 'ecommerce.db'));
  db.execute('PRAGMA journal_mode = WAL');
  db.execute('PRAGMA foreign_keys = ON');

  db.execute('''
    CREATE TABLE IF NOT EXISTS users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      email TEXT UNIQUE NOT NULL,
      password TEXT NOT NULL,
      role TEXT NOT NULL DEFAULT 'user' CHECK(role IN ('admin', 'user')),
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )
  ''');

  db.execute('''
    CREATE TABLE IF NOT EXISTS products (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      code TEXT,
      name TEXT NOT NULL,
      description TEXT,
      import_price REAL DEFAULT 0,
      sell_price REAL NOT NULL DEFAULT 0,
      tiktok_price REAL DEFAULT 0,
      image_url TEXT,
      category TEXT,
      sizes TEXT DEFAULT '',
      source TEXT DEFAULT '',
      rating REAL DEFAULT 0,
      review_count INTEGER DEFAULT 0,
      stock INTEGER DEFAULT 0,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )
  ''');

  db.execute('''
    CREATE TABLE IF NOT EXISTS source_labels (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT UNIQUE NOT NULL,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )
  ''');

  db.execute('''
    CREATE TABLE IF NOT EXISTS orders (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      customer_name TEXT NOT NULL,
      customer_phone TEXT DEFAULT '',
      customer_fb TEXT,
      status TEXT NOT NULL DEFAULT 'chua_tao_don' CHECK(status IN ('chua_tao_don', 'da_tao_don', 'da_hoan_thanh')),
      total REAL NOT NULL DEFAULT 0,
      note TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )
  ''');

  db.execute('''
    CREATE TABLE IF NOT EXISTS order_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      order_id INTEGER NOT NULL,
      product_id INTEGER NOT NULL,
      product_name TEXT NOT NULL,
      price REAL NOT NULL,
      quantity INTEGER NOT NULL DEFAULT 1,
      FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
      FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE SET NULL
    )
  ''');

  db.execute('''
    CREATE TABLE IF NOT EXISTS product_colors (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      product_id INTEGER NOT NULL,
      color_name TEXT NOT NULL,
      image_url TEXT DEFAULT '',
      FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
    )
  ''');

  db.execute('''
    CREATE TABLE IF NOT EXISTS cart_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      product_id INTEGER NOT NULL,
      quantity INTEGER NOT NULL DEFAULT 1,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
      FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
      UNIQUE(user_id, product_id)
    )
  ''');
}
