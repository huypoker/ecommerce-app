const express = require('express');
const db = require('../db');
const { requireAdmin } = require('../middleware/auth');
const router = express.Router();

// Search / get all customers
router.get('/', requireAdmin, (req, res) => {
  try {
    const { q } = req.query;
    let customers;
    if (q) {
      customers = db.prepare(
        'SELECT * FROM customers WHERE name LIKE ? OR phone LIKE ? ORDER BY updated_at DESC LIMIT 20'
      ).all(`%${q}%`, `%${q}%`);
    } else {
      customers = db.prepare(
        'SELECT * FROM customers ORDER BY updated_at DESC'
      ).all();
    }
    res.json(customers);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Create customer
router.post('/', requireAdmin, (req, res) => {
  try {
    const { name, phone, facebook_link, note } = req.body;
    if (!name) return res.status(400).json({ error: 'Name is required' });
    const result = db.prepare(
      'INSERT INTO customers (name, phone, facebook_link, note) VALUES (?, ?, ?, ?)'
    ).run(name, phone || '', facebook_link || '', note || '');
    const customer = db.prepare('SELECT * FROM customers WHERE id = ?').get(result.lastInsertRowid);
    res.status(201).json(customer);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Update customer
router.put('/:id', requireAdmin, (req, res) => {
  try {
    const { name, phone, facebook_link, note } = req.body;
    db.prepare(
      'UPDATE customers SET name = COALESCE(?, name), phone = COALESCE(?, phone), facebook_link = COALESCE(?, facebook_link), note = COALESCE(?, note), updated_at = CURRENT_TIMESTAMP WHERE id = ?'
    ).run(name || null, phone !== undefined ? phone : null, facebook_link !== undefined ? facebook_link : null, note !== undefined ? note : null, req.params.id);
    const customer = db.prepare('SELECT * FROM customers WHERE id = ?').get(req.params.id);
    if (!customer) return res.status(404).json({ error: 'Customer not found' });
    res.json(customer);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Delete customer
router.delete('/:id', requireAdmin, (req, res) => {
  try {
    db.prepare('DELETE FROM customers WHERE id = ?').run(req.params.id);
    res.json({ message: 'Customer deleted' });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Update item status (PATCH /api/customers/item-status/:itemId)
router.patch('/item-status/:itemId', requireAdmin, (req, res) => {
  try {
    const { item_status } = req.body;
    const validStatuses = ['cho_hang', 'da_ve_kho', 'da_giao', 'huy'];
    if (!validStatuses.includes(item_status)) {
      return res.status(400).json({ error: 'Invalid item_status' });
    }
    const item = db.prepare('SELECT * FROM order_items WHERE id = ?').get(req.params.itemId);
    if (!item) return res.status(404).json({ error: 'Item not found' });
    db.prepare('UPDATE order_items SET item_status = ? WHERE id = ?').run(item_status, req.params.itemId);
    res.json({ id: item.id, item_status });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Get pending items queue (cho_hang) grouped by product
router.get('/queue/pending', requireAdmin, (req, res) => {
  try {
    const items = db.prepare(`
      SELECT oi.*, o.customer_name, o.customer_fb, o.customer_phone, o.order_code, o.source,
             o.created_at as order_date, o.id as order_id
      FROM order_items oi
      JOIN orders o ON oi.order_id = o.id
      WHERE oi.item_status = 'cho_hang'
      ORDER BY o.created_at ASC
    `).all();
    res.json(items);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

module.exports = router;
