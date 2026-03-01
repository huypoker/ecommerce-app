const express = require('express');
const db = require('../database');
const { authenticateToken } = require('../middleware/auth');

const router = express.Router();

// Get cart items for current user
router.get('/', authenticateToken, (req, res) => {
  try {
    const items = db.prepare(`
      SELECT ci.id, ci.quantity, ci.product_id,
             p.name, p.sell_price, p.image_url, p.stock
      FROM cart_items ci
      JOIN products p ON ci.product_id = p.id
      WHERE ci.user_id = ?
      ORDER BY ci.created_at DESC
    `).all(req.user.id);

    // Calculate totals
    const subtotal = items.reduce((sum, item) => {
      return sum + (item.sell_price * item.quantity);
    }, 0);

    res.json({ items, subtotal, item_count: items.length });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Add item to cart
router.post('/', authenticateToken, (req, res) => {
  try {
    const { product_id, quantity } = req.body;

    if (!product_id) {
      return res.status(400).json({ error: 'product_id is required' });
    }

    // Check product exists
    const product = db.prepare('SELECT * FROM products WHERE id = ?').get(product_id);
    if (!product) {
      return res.status(404).json({ error: 'Product not found' });
    }

    const qty = quantity || 1;

    // Upsert: insert or update quantity
    const existing = db.prepare(
      'SELECT * FROM cart_items WHERE user_id = ? AND product_id = ?'
    ).get(req.user.id, product_id);

    if (existing) {
      db.prepare(
        'UPDATE cart_items SET quantity = quantity + ? WHERE id = ?'
      ).run(qty, existing.id);
    } else {
      db.prepare(
        'INSERT INTO cart_items (user_id, product_id, quantity) VALUES (?, ?, ?)'
      ).run(req.user.id, product_id, qty);
    }

    res.status(201).json({ message: 'Item added to cart' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Update cart item quantity
router.put('/:id', authenticateToken, (req, res) => {
  try {
    const { quantity } = req.body;
    if (!quantity || quantity < 1) {
      return res.status(400).json({ error: 'Valid quantity is required' });
    }

    const item = db.prepare(
      'SELECT * FROM cart_items WHERE id = ? AND user_id = ?'
    ).get(req.params.id, req.user.id);

    if (!item) {
      return res.status(404).json({ error: 'Cart item not found' });
    }

    db.prepare('UPDATE cart_items SET quantity = ? WHERE id = ?').run(quantity, req.params.id);
    res.json({ message: 'Cart updated' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Remove item from cart
router.delete('/:id', authenticateToken, (req, res) => {
  try {
    const item = db.prepare(
      'SELECT * FROM cart_items WHERE id = ? AND user_id = ?'
    ).get(req.params.id, req.user.id);

    if (!item) {
      return res.status(404).json({ error: 'Cart item not found' });
    }

    db.prepare('DELETE FROM cart_items WHERE id = ?').run(req.params.id);
    res.json({ message: 'Item removed from cart' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Clear cart
router.delete('/', authenticateToken, (req, res) => {
  try {
    db.prepare('DELETE FROM cart_items WHERE user_id = ?').run(req.user.id);
    res.json({ message: 'Cart cleared' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
