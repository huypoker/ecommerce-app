const express = require('express');
const db = require('../db');
const { requireAdmin } = require('../middleware/auth');
const router = express.Router();

// Get all orders
router.get('/', requireAdmin, (req, res) => {
  try {
    const { status, search, sort } = req.query;
    let query = 'SELECT * FROM orders WHERE 1=1';
    const params = [];

    if (status) { query += ' AND status = ?'; params.push(status); }
    if (search) {
      query += ' AND (customer_name LIKE ? OR customer_phone LIKE ?)';
      params.push(`%${search}%`, `%${search}%`);
    }

    switch (sort) {
      case 'oldest': query += ' ORDER BY created_at ASC'; break;
      case 'total_desc': query += ' ORDER BY total DESC'; break;
      case 'total_asc': query += ' ORDER BY total ASC'; break;
      case 'name_asc': query += ' ORDER BY customer_name ASC'; break;
      default: query += ' ORDER BY created_at DESC';
    }

    const orders = db.prepare(query).all(...params);
    const getItems = db.prepare('SELECT * FROM order_items WHERE order_id = ?');
    for (const o of orders) o.items = getItems.all(o.id);

    res.json(orders);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Get single order
router.get('/:id', requireAdmin, (req, res) => {
  try {
    const order = db.prepare('SELECT * FROM orders WHERE id = ?').get(req.params.id);
    if (!order) return res.status(404).json({ error: 'Order not found' });
    order.items = db.prepare('SELECT * FROM order_items WHERE order_id = ?').all(order.id);
    res.json(order);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Create order
router.post('/', requireAdmin, (req, res) => {
  try {
    const { customer_name, customer_phone, customer_fb, status, note, items } = req.body;
    if (!customer_name) return res.status(400).json({ error: 'customer_name is required' });
    if (!items || !items.length) return res.status(400).json({ error: 'At least one item is required' });

    let total = 0;
    const processedItems = [];
    for (const item of items) {
      if (!item.product_id) return res.status(400).json({ error: 'Each item needs product_id and quantity' });
      const product = db.prepare('SELECT * FROM products WHERE id = ?').get(item.product_id);
      if (!product) return res.status(404).json({ error: `Product ID ${item.product_id} not found` });
      const price = product.sell_price;
      const qty = item.quantity || 1;
      total += price * qty;
      processedItems.push({ product_id: item.product_id, product_name: product.name, price, quantity: qty });
    }

    const orderStatus = status || 'chua_tao_don';
    const result = db.prepare('INSERT INTO orders (customer_name, customer_phone, customer_fb, status, total, note) VALUES (?, ?, ?, ?, ?, ?)').run(
      customer_name, customer_phone || '', customer_fb || '', orderStatus, total, note || ''
    );
    const orderId = result.lastInsertRowid;

    const insertItem = db.prepare('INSERT INTO order_items (order_id, product_id, product_name, price, quantity) VALUES (?, ?, ?, ?, ?)');
    for (const item of processedItems) {
      insertItem.run(orderId, item.product_id, item.product_name, item.price, item.quantity);
    }

    const order = db.prepare('SELECT * FROM orders WHERE id = ?').get(orderId);
    order.items = db.prepare('SELECT * FROM order_items WHERE order_id = ?').all(orderId);
    res.status(201).json(order);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Update order
router.put('/:id', requireAdmin, (req, res) => {
  try {
    const orderId = parseInt(req.params.id);
    const existing = db.prepare('SELECT * FROM orders WHERE id = ?').get(orderId);
    if (!existing) return res.status(404).json({ error: 'Order not found' });

    const { customer_name, customer_phone, customer_fb, status, note, items } = req.body;
    let total = existing.total;

    if (items && items.length) {
      total = 0;
      const processedItems = [];
      for (const item of items) {
        const product = db.prepare('SELECT * FROM products WHERE id = ?').get(item.product_id);
        if (!product) return res.status(404).json({ error: `Product ID ${item.product_id} not found` });
        const price = product.sell_price;
        const qty = item.quantity || 1;
        total += price * qty;
        processedItems.push({ product_id: item.product_id, product_name: product.name, price, quantity: qty });
      }

      db.prepare('DELETE FROM order_items WHERE order_id = ?').run(orderId);
      const insertItem = db.prepare('INSERT INTO order_items (order_id, product_id, product_name, price, quantity) VALUES (?, ?, ?, ?, ?)');
      for (const item of processedItems) {
        insertItem.run(orderId, item.product_id, item.product_name, item.price, item.quantity);
      }
    }

    db.prepare(`UPDATE orders SET customer_name = COALESCE(?, customer_name), customer_phone = COALESCE(?, customer_phone), customer_fb = COALESCE(?, customer_fb), status = COALESCE(?, status), total = ?, note = COALESCE(?, note), updated_at = CURRENT_TIMESTAMP WHERE id = ?`).run(
      customer_name || null,
      customer_phone !== undefined ? customer_phone : null,
      customer_fb !== undefined ? customer_fb : null,
      status || null, total,
      note !== undefined ? note : null,
      orderId
    );

    const order = db.prepare('SELECT * FROM orders WHERE id = ?').get(orderId);
    order.items = db.prepare('SELECT * FROM order_items WHERE order_id = ?').all(orderId);
    res.json(order);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Delete order
router.delete('/:id', requireAdmin, (req, res) => {
  try {
    const existing = db.prepare('SELECT * FROM orders WHERE id = ?').get(req.params.id);
    if (!existing) return res.status(404).json({ error: 'Order not found' });
    db.prepare('DELETE FROM orders WHERE id = ?').run(req.params.id);
    res.json({ message: 'Order deleted successfully' });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

module.exports = router;
