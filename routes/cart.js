const express = require('express');
const db = require('../db');
const { requireAuth } = require('../middleware/auth');
const router = express.Router();

// Get cart
router.get('/', requireAuth, (req, res) => {
  try {
    const items = db.prepare(`
      SELECT ci.id, ci.quantity, ci.product_id,
             p.name, p.sell_price, p.image_url, p.stock
      FROM cart_items ci
      JOIN products p ON ci.product_id = p.id
      WHERE ci.user_id = ?
      ORDER BY ci.created_at DESC
    `).all(req.user.id);

    let subtotal = 0;
    for (const item of items) subtotal += item.sell_price * item.quantity;

    res.json({ items, subtotal, item_count: items.length });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Add to cart
router.post('/', requireAuth, (req, res) => {
  try {
    const { product_id, quantity = 1 } = req.body;
    if (!product_id) return res.status(400).json({ error: 'product_id is required' });

    const product = db.prepare('SELECT * FROM products WHERE id = ?').get(product_id);
    if (!product) return res.status(404).json({ error: 'Product not found' });

    const existing = db.prepare('SELECT * FROM cart_items WHERE user_id = ? AND product_id = ?').get(req.user.id, product_id);
    if (existing) {
      db.prepare('UPDATE cart_items SET quantity = quantity + ? WHERE id = ?').run(quantity, existing.id);
    } else {
      db.prepare('INSERT INTO cart_items (user_id, product_id, quantity) VALUES (?, ?, ?)').run(req.user.id, product_id, quantity);
    }

    res.status(201).json({ message: 'Item added to cart' });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Update cart item
router.put('/:id', requireAuth, (req, res) => {
  try {
    const { quantity } = req.body;
    if (!quantity || quantity < 1) return res.status(400).json({ error: 'Valid quantity is required' });

    const item = db.prepare('SELECT * FROM cart_items WHERE id = ? AND user_id = ?').get(req.params.id, req.user.id);
    if (!item) return res.status(404).json({ error: 'Cart item not found' });

    db.prepare('UPDATE cart_items SET quantity = ? WHERE id = ?').run(quantity, req.params.id);
    res.json({ message: 'Cart updated' });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Clear cart (DELETE /api/cart with no id)
router.delete('/', requireAuth, (req, res) => {
  try {
    db.prepare('DELETE FROM cart_items WHERE user_id = ?').run(req.user.id);
    res.json({ message: 'Cart cleared' });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Remove item from cart
router.delete('/:id', requireAuth, (req, res) => {
  try {
    const item = db.prepare('SELECT * FROM cart_items WHERE id = ? AND user_id = ?').get(req.params.id, req.user.id);
    if (!item) return res.status(404).json({ error: 'Cart item not found' });

    db.prepare('DELETE FROM cart_items WHERE id = ?').run(req.params.id);
    res.json({ message: 'Item removed from cart' });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

module.exports = router;
