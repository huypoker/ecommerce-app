const express = require('express');
const db = require('../database');
const { authenticateToken, requireAdmin } = require('../middleware/auth');

const router = express.Router();

// Get all products (public)
router.get('/', (req, res) => {
  try {
    const { category, search, sort, source } = req.query;
    let query = 'SELECT * FROM products WHERE 1=1';
    const params = [];

    if (category) {
      query += ' AND category = ?';
      params.push(category);
    }

    if (source) {
      query += ' AND source = ?';
      params.push(source);
    }

    if (search) {
      query += ' AND (name LIKE ? OR description LIKE ? OR code LIKE ?)';
      params.push(`%${search}%`, `%${search}%`, `%${search}%`);
    }

    if (sort === 'price_asc') {
      query += ' ORDER BY sell_price ASC';
    } else if (sort === 'price_desc') {
      query += ' ORDER BY sell_price DESC';
    } else if (sort === 'newest') {
      query += ' ORDER BY created_at DESC';
    } else if (sort === 'rating') {
      query += ' ORDER BY rating DESC';
    } else {
      query += ' ORDER BY created_at DESC';
    }

    const products = db.prepare(query).all(...params);
    const getColors = db.prepare('SELECT id, color_name, image_url FROM product_colors WHERE product_id = ?');
    const result = products.map(p => ({ ...p, colors: getColors.all(p.id) }));
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get single product (public)
router.get('/:id', (req, res) => {
  try {
    const product = db.prepare('SELECT * FROM products WHERE id = ?').get(req.params.id);
    if (!product) {
      return res.status(404).json({ error: 'Product not found' });
    }
    const colors = db.prepare('SELECT id, color_name, image_url FROM product_colors WHERE product_id = ?').all(product.id);
    res.json({ ...product, colors });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Create product (admin only)
router.post('/', authenticateToken, requireAdmin, (req, res) => {
  try {
    const { code, name, description, import_price, sell_price, tiktok_price, image_url, category, sizes, source, stock } = req.body;

    if (!name || sell_price == null) {
      return res.status(400).json({ error: 'Name and sell_price are required' });
    }

    const result = db.prepare(
      `INSERT INTO products (code, name, description, import_price, sell_price, tiktok_price, image_url, category, sizes, source, stock)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
    ).run(
      code || '', name, description || '',
      import_price || 0, sell_price, tiktok_price || 0,
      image_url || '', category || '',
      Array.isArray(sizes) ? sizes.join(',') : (sizes || ''),
      source || '', stock || 0
    );

    // Save colors
    const { colors } = req.body;
    const insertColor = db.prepare('INSERT INTO product_colors (product_id, color_name, image_url) VALUES (?, ?, ?)');
    if (colors && Array.isArray(colors)) {
      for (const c of colors) {
        if (c.color_name) insertColor.run(result.lastInsertRowid, c.color_name, c.image_url || '');
      }
    }

    const product = db.prepare('SELECT * FROM products WHERE id = ?').get(result.lastInsertRowid);
    const savedColors = db.prepare('SELECT id, color_name, image_url FROM product_colors WHERE product_id = ?').all(product.id);
    res.status(201).json({ ...product, colors: savedColors });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Update product (admin only)
router.put('/:id', authenticateToken, requireAdmin, (req, res) => {
  try {
    const existing = db.prepare('SELECT * FROM products WHERE id = ?').get(req.params.id);
    if (!existing) {
      return res.status(404).json({ error: 'Product not found' });
    }

    const { code, name, description, import_price, sell_price, tiktok_price, image_url, category, sizes, source, stock } = req.body;

    const sizesStr = sizes !== undefined
      ? (Array.isArray(sizes) ? sizes.join(',') : sizes)
      : existing.sizes;

    db.prepare(
      `UPDATE products SET
        code = COALESCE(?, code),
        name = COALESCE(?, name),
        description = COALESCE(?, description),
        import_price = COALESCE(?, import_price),
        sell_price = COALESCE(?, sell_price),
        tiktok_price = COALESCE(?, tiktok_price),
        image_url = COALESCE(?, image_url),
        category = COALESCE(?, category),
        sizes = ?,
        source = COALESCE(?, source),
        stock = COALESCE(?, stock),
        updated_at = CURRENT_TIMESTAMP
       WHERE id = ?`
    ).run(
      code !== undefined ? code : null,
      name || null, description !== undefined ? description : null,
      import_price !== undefined ? import_price : null,
      sell_price !== undefined ? sell_price : null,
      tiktok_price !== undefined ? tiktok_price : null,
      image_url !== undefined ? image_url : null,
      category !== undefined ? category : null,
      sizesStr,
      source !== undefined ? source : null,
      stock !== undefined ? stock : null,
      req.params.id
    );

    // Update colors if provided
    const { colors } = req.body;
    if (colors && Array.isArray(colors)) {
      db.prepare('DELETE FROM product_colors WHERE product_id = ?').run(req.params.id);
      const insertColor = db.prepare('INSERT INTO product_colors (product_id, color_name, image_url) VALUES (?, ?, ?)');
      for (const c of colors) {
        if (c.color_name) insertColor.run(req.params.id, c.color_name, c.image_url || '');
      }
    }

    const product = db.prepare('SELECT * FROM products WHERE id = ?').get(req.params.id);
    const savedColors = db.prepare('SELECT id, color_name, image_url FROM product_colors WHERE product_id = ?').all(product.id);
    res.json({ ...product, colors: savedColors });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Delete product
router.delete('/:id', authenticateToken, requireAdmin, (req, res) => {
  try {
    const existing = db.prepare('SELECT * FROM products WHERE id = ?').get(req.params.id);
    if (!existing) {
      return res.status(404).json({ error: 'Product not found' });
    }

    db.prepare('DELETE FROM products WHERE id = ?').run(req.params.id);
    res.json({ message: 'Product deleted successfully' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get categories
router.get('/meta/categories', (req, res) => {
  try {
    const categories = db.prepare('SELECT DISTINCT category FROM products WHERE category IS NOT NULL AND category != ""').all();
    res.json(categories.map(c => c.category));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
