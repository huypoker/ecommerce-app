const db = require('./db');
const { hashPassword } = require('./middleware/auth');

function seedDatabase() {
  console.log('🌱 Seeding database...');

  // Create users
  const existing = db.prepare('SELECT id FROM users WHERE email = ?').get('admin@shop.com');
  if (!existing) {
    const adminHash = hashPassword('admin123');
    const userHash = hashPassword('user123');
    db.prepare('INSERT INTO users (name, email, password, role) VALUES (?, ?, ?, ?)').run('Admin', 'admin@shop.com', adminHash, 'admin');
    db.prepare('INSERT INTO users (name, email, password, role) VALUES (?, ?, ?, ?)').run('User', 'user@shop.com', userHash, 'user');
    console.log('✅ Users created:');
    console.log('   Admin: admin@shop.com / admin123');
    console.log('   User:  user@shop.com / user123');
  }

  // Seed source labels
  const sourceLabels = ['TikTok Shop', 'Shopee', 'Facebook', 'Zalo', 'Trực tiếp'];
  const insertLabel = db.prepare('INSERT OR IGNORE INTO source_labels (name) VALUES (?)');
  for (const label of sourceLabels) insertLabel.run(label);
  console.log(`✅ ${sourceLabels.length} source labels seeded`);

  // Seed products
  const { cnt } = db.prepare('SELECT COUNT(*) as cnt FROM products').get();
  if (cnt === 0) {
    const products = [
      { code: 'SP001', name: 'Nike Air Max 270', description: 'Giày Nike Air Max 270 với đệm Air lớn nhất, êm ái và phong cách.', import_price: 2500000, sell_price: 3500000, tiktok_price: 3200000, image_url: 'https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=500', category: 'Giày', sizes: 'S,M,L,XL', source: 'TikTok Shop', rating: 4.5, review_count: 235, stock: 50 },
      { code: 'SP002', name: 'Apple Watch Series 9', description: 'Đồng hồ thông minh Apple Watch Series 9 với cảm biến sức khỏe tiên tiến.', import_price: 7000000, sell_price: 9500000, tiktok_price: 8900000, image_url: 'https://images.unsplash.com/photo-1546868871-af0de0ae72be?w=500', category: 'Điện tử', sizes: '', source: 'Shopee', rating: 4.8, review_count: 512, stock: 30 },
      { code: 'SP003', name: 'Túi đeo chéo da thật', description: 'Túi đeo chéo da bò thật, dây đeo điều chỉnh. Phù hợp sử dụng hàng ngày.', import_price: 800000, sell_price: 1500000, tiktok_price: 1350000, image_url: 'https://images.unsplash.com/photo-1548036328-c9fa89d128fa?w=500', category: 'Túi xách', sizes: '', source: 'Facebook', rating: 4.2, review_count: 89, stock: 25 },
      { code: 'SP004', name: 'Tai nghe Bluetooth không dây', description: 'Tai nghe chống ồn cao cấp, pin 30 giờ, chất âm vượt trội.', import_price: 3000000, sell_price: 4500000, tiktok_price: 4200000, image_url: 'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=500', category: 'Điện tử', sizes: '', source: 'TikTok Shop', rating: 4.6, review_count: 678, stock: 100 },
      { code: 'SP005', name: 'Áo khoác Denim cổ điển', description: 'Áo khoác denim cotton cao cấp, khóa cúc, túi ngực.', import_price: 500000, sell_price: 850000, tiktok_price: 799000, image_url: 'https://images.unsplash.com/photo-1576995853123-5a10305d93c0?w=500', category: 'Quần áo', sizes: 'S,M,L,XL,XXL', source: 'Shopee', rating: 4.3, review_count: 156, stock: 40 },
      { code: 'SP006', name: 'Đồng hồ Minimalist', description: 'Đồng hồ tối giản, dây da thật, máy Quartz Nhật Bản.', import_price: 1200000, sell_price: 2200000, tiktok_price: 1990000, image_url: 'https://images.unsplash.com/photo-1524592094714-0f0654e20314?w=500', category: 'Phụ kiện', sizes: '', source: 'Zalo', rating: 4.4, review_count: 203, stock: 35 },
      { code: 'SP007', name: 'Giày chạy bộ Pro', description: 'Giày chạy bộ nhẹ, đệm đàn hồi, thân lưới thoáng khí.', import_price: 1800000, sell_price: 2800000, tiktok_price: 2600000, image_url: 'https://images.unsplash.com/photo-1460353581641-37baddab0fa2?w=500', category: 'Giày', sizes: 'S,M,L,XL', source: 'Facebook', rating: 4.7, review_count: 445, stock: 60 },
      { code: 'SP008', name: 'Kính mát cao cấp', description: 'Kính phân cực UV400, gọng titan, thời trang và bền bỉ.', import_price: 1500000, sell_price: 2500000, tiktok_price: 2300000, image_url: 'https://images.unsplash.com/photo-1572635196237-14b3f281503f?w=500', category: 'Phụ kiện', sizes: '', source: 'Trực tiếp', rating: 4.1, review_count: 92, stock: 45 },
      { code: 'SP009', name: 'Đế sạc không dây', description: 'Đế sạc không dây tương thích mọi thiết bị Qi. Hỗ trợ sạc nhanh.', import_price: 300000, sell_price: 550000, tiktok_price: 499000, image_url: 'https://images.unsplash.com/photo-1586953208270-767889fa9b0e?w=500', category: 'Điện tử', sizes: '', source: 'TikTok Shop', rating: 4.0, review_count: 167, stock: 80 },
      { code: 'SP010', name: 'Túi tote vải canvas', description: 'Túi canvas thân thiện môi trường, có túi trong. Phù hợp đi chợ và sử dụng hàng ngày.', import_price: 200000, sell_price: 380000, tiktok_price: 350000, image_url: 'https://images.unsplash.com/photo-1544816155-12df9643f363?w=500', category: 'Túi xách', sizes: '', source: 'Shopee', rating: 4.3, review_count: 78, stock: 120 },
      { code: 'SP011', name: 'Vòng đeo tay thể thao', description: 'Vòng theo dõi sức khỏe, đo nhịp tim, theo dõi giấc ngủ, pin 7 ngày.', import_price: 600000, sell_price: 990000, tiktok_price: 890000, image_url: 'https://images.unsplash.com/photo-1575311373937-040b8e1fd5b6?w=500', category: 'Điện tử', sizes: '', source: 'Zalo', rating: 4.2, review_count: 334, stock: 75 },
      { code: 'SP012', name: 'Áo thun cổ tròn cotton', description: 'Áo thun 100% cotton hữu cơ, form rộng thoải mái. Nhiều màu sắc.', import_price: 150000, sell_price: 290000, tiktok_price: 260000, image_url: 'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=500', category: 'Quần áo', sizes: 'S,M,L,XL,XXL', source: 'Trực tiếp', rating: 4.5, review_count: 890, stock: 200 },
    ];

    const insert = db.prepare(`INSERT INTO products (code, name, description, import_price, sell_price, tiktok_price, image_url, category, sizes, source, rating, review_count, stock) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`);
    for (const p of products) {
      insert.run(p.code, p.name, p.description, p.import_price, p.sell_price, p.tiktok_price, p.image_url, p.category, p.sizes, p.source, p.rating, p.review_count, p.stock);
    }
    console.log(`✅ ${products.length} products seeded`);
  }

  console.log('🎉 Seeding complete!');
}

module.exports = seedDatabase;
