const express = require('express');
const db = require('../db');
const { requireAdmin } = require('../middleware/auth');
const router = express.Router();

// Get categories
router.get('/meta/categories', (req, res) => {
  try {
    const rows = db.prepare('SELECT DISTINCT category FROM products WHERE category IS NOT NULL AND category != ""').all();
    res.json(rows.map(r => r.category));
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Get all products
router.get('/', (req, res) => {
  try {
    const { category, search, sort, source } = req.query;
    let query = 'SELECT * FROM products WHERE 1=1';
    const params = [];

    if (category) { query += ' AND category = ?'; params.push(category); }
    if (source) { query += ' AND source = ?'; params.push(source); }
    if (search) {
      query += ' AND (name LIKE ? OR description LIKE ? OR code LIKE ?)';
      params.push(`%${search}%`, `%${search}%`, `%${search}%`);
    }

    switch (sort) {
      case 'price_asc': query += ' ORDER BY sell_price ASC'; break;
      case 'price_desc': query += ' ORDER BY sell_price DESC'; break;
      case 'rating': query += ' ORDER BY rating DESC'; break;
      default: query += ' ORDER BY created_at DESC';
    }

    const products = db.prepare(query).all(...params);
    const getColors = db.prepare('SELECT id, color_name, image_url FROM product_colors WHERE product_id = ?');
    for (const p of products) {
      p.colors = getColors.all(p.id);
    }
    res.json(products);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Get single product
router.get('/:id', (req, res) => {
  try {
    const product = db.prepare('SELECT * FROM products WHERE id = ?').get(req.params.id);
    if (!product) return res.status(404).json({ error: 'Product not found' });
    product.colors = db.prepare('SELECT id, color_name, image_url FROM product_colors WHERE product_id = ?').all(product.id);
    res.json(product);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Create product
router.post('/', requireAdmin, (req, res) => {
  try {
    const { code, name, description, import_price, sell_price, tiktok_price, image_url, category, sizes, source, stock, colors } = req.body;
    if (!name || sell_price == null) return res.status(400).json({ error: 'Name and sell_price are required' });

    const sizesStr = Array.isArray(sizes) ? sizes.join(',') : (sizes || '');
    const result = db.prepare(`INSERT INTO products (code, name, description, import_price, sell_price, tiktok_price, image_url, category, sizes, source, stock) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`).run(
      code || '', name, description || '', import_price || 0, sell_price, tiktok_price || 0, image_url || '', category || '', sizesStr, source || '', stock || 0
    );
    const productId = result.lastInsertRowid;

    if (Array.isArray(colors)) {
      const insertColor = db.prepare('INSERT INTO product_colors (product_id, color_name, image_url) VALUES (?, ?, ?)');
      for (const c of colors) {
        if (c && c.color_name) insertColor.run(productId, c.color_name, c.image_url || '');
      }
    }

    const product = db.prepare('SELECT * FROM products WHERE id = ?').get(productId);
    product.colors = db.prepare('SELECT id, color_name, image_url FROM product_colors WHERE product_id = ?').all(productId);
    res.status(201).json(product);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Update product
router.put('/:id', requireAdmin, (req, res) => {
  try {
    const productId = parseInt(req.params.id);
    const existing = db.prepare('SELECT * FROM products WHERE id = ?').get(productId);
    if (!existing) return res.status(404).json({ error: 'Product not found' });

    const body = req.body;
    const sizes = body.sizes != null ? (Array.isArray(body.sizes) ? body.sizes.join(',') : body.sizes.toString()) : existing.sizes;

    db.prepare(`UPDATE products SET code = COALESCE(?, code), name = COALESCE(?, name), description = COALESCE(?, description), import_price = COALESCE(?, import_price), sell_price = COALESCE(?, sell_price), tiktok_price = COALESCE(?, tiktok_price), image_url = COALESCE(?, image_url), category = COALESCE(?, category), sizes = ?, source = COALESCE(?, source), stock = COALESCE(?, stock), updated_at = CURRENT_TIMESTAMP WHERE id = ?`).run(
      body.code !== undefined ? body.code : null, body.name || null, body.description !== undefined ? body.description : null,
      body.import_price !== undefined ? body.import_price : null, body.sell_price !== undefined ? body.sell_price : null,
      body.tiktok_price !== undefined ? body.tiktok_price : null, body.image_url !== undefined ? body.image_url : null,
      body.category !== undefined ? body.category : null, sizes, body.source !== undefined ? body.source : null,
      body.stock !== undefined ? body.stock : null, productId
    );

    if (Array.isArray(body.colors)) {
      db.prepare('DELETE FROM product_colors WHERE product_id = ?').run(productId);
      const insertColor = db.prepare('INSERT INTO product_colors (product_id, color_name, image_url) VALUES (?, ?, ?)');
      for (const c of body.colors) {
        if (c && c.color_name) insertColor.run(productId, c.color_name, c.image_url || '');
      }
    }

    const product = db.prepare('SELECT * FROM products WHERE id = ?').get(productId);
    product.colors = db.prepare('SELECT id, color_name, image_url FROM product_colors WHERE product_id = ?').all(productId);
    res.json(product);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Delete product
router.delete('/:id', requireAdmin, (req, res) => {
  try {
    const product = db.prepare('SELECT * FROM products WHERE id = ?').get(req.params.id);
    if (!product) return res.status(404).json({ error: 'Product not found' });
    db.prepare('DELETE FROM products WHERE id = ?').run(req.params.id);
    res.json({ message: 'Product deleted successfully' });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

module.exports = router;
