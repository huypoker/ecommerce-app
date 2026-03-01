const express = require('express');
const db = require('../database');
const { authenticateToken, requireAdmin } = require('../middleware/auth');

const router = express.Router();

// All order routes require admin
router.use(authenticateToken, requireAdmin);

// Get all orders
router.get('/', (req, res) => {
  try {
    const { status, search, sort } = req.query;
    let query = 'SELECT * FROM orders WHERE 1=1';
    const params = [];

    if (status) {
      query += ' AND status = ?';
      params.push(status);
    }

    if (search) {
      query += ' AND (customer_name LIKE ? OR customer_phone LIKE ?)';
      params.push(`%${search}%`, `%${search}%`);
    }

    if (sort === 'newest') {
      query += ' ORDER BY created_at DESC';
    } else if (sort === 'oldest') {
      query += ' ORDER BY created_at ASC';
    } else if (sort === 'total_desc') {
      query += ' ORDER BY total DESC';
    } else if (sort === 'total_asc') {
      query += ' ORDER BY total ASC';
    } else if (sort === 'name_asc') {
      query += ' ORDER BY customer_name ASC';
    } else {
      query += ' ORDER BY created_at DESC';
    }

    const orders = db.prepare(query).all(...params);

    // Attach items to each order
    const getItems = db.prepare('SELECT * FROM order_items WHERE order_id = ?');
    const result = orders.map(order => ({
      ...order,
      items: getItems.all(order.id)
    }));

    res.json(result);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get single order
router.get('/:id', (req, res) => {
  try {
    const order = db.prepare('SELECT * FROM orders WHERE id = ?').get(req.params.id);
    if (!order) {
      return res.status(404).json({ error: 'Order not found' });
    }

    const items = db.prepare('SELECT * FROM order_items WHERE order_id = ?').all(order.id);
    res.json({ ...order, items });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Create order
router.post('/', (req, res) => {
  try {
    const { customer_name, customer_phone, customer_fb, status, note, items } = req.body;

    if (!customer_name) {
      return res.status(400).json({ error: 'customer_name is required' });
    }
    if (!items || !Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ error: 'At least one item is required' });
    }

    // Calculate total from items
    let total = 0;
    for (const item of items) {
      if (!item.product_id || !item.quantity) {
        return res.status(400).json({ error: 'Each item needs product_id and quantity' });
      }
      const product = db.prepare('SELECT * FROM products WHERE id = ?').get(item.product_id);
      if (!product) {
        return res.status(404).json({ error: `Product ID ${item.product_id} not found` });
      }
      const price = product.sell_price;
      item.product_name = product.name;
      item.price = price;
      total += price * item.quantity;
    }

    const orderStatus = status || 'chua_tao_don';

    const result = db.prepare(
      'INSERT INTO orders (customer_name, customer_phone, customer_fb, status, total, note) VALUES (?, ?, ?, ?, ?, ?)'
    ).run(customer_name, customer_phone || '', customer_fb || '', orderStatus, total, note || '');

    const orderId = result.lastInsertRowid;

    // Insert order items
    const insertItem = db.prepare(
      'INSERT INTO order_items (order_id, product_id, product_name, price, quantity) VALUES (?, ?, ?, ?, ?)'
    );

    const insertAll = db.transaction((items) => {
      for (const item of items) {
        insertItem.run(orderId, item.product_id, item.product_name, item.price, item.quantity);
      }
    });

    insertAll(items);

    // Return created order
    const order = db.prepare('SELECT * FROM orders WHERE id = ?').get(orderId);
    const orderItems = db.prepare('SELECT * FROM order_items WHERE order_id = ?').all(orderId);

    res.status(201).json({ ...order, items: orderItems });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Update order
router.put('/:id', (req, res) => {
  try {
    const existing = db.prepare('SELECT * FROM orders WHERE id = ?').get(req.params.id);
    if (!existing) {
      return res.status(404).json({ error: 'Order not found' });
    }

    const { customer_name, customer_phone, customer_fb, status, note, items } = req.body;

    // If items are provided, recalculate total and replace items
    let total = existing.total;
    if (items && Array.isArray(items) && items.length > 0) {
      total = 0;
      for (const item of items) {
        const product = db.prepare('SELECT * FROM products WHERE id = ?').get(item.product_id);
        if (!product) {
          return res.status(404).json({ error: `Product ID ${item.product_id} not found` });
        }
        const price = product.sell_price;
        item.product_name = product.name;
        item.price = price;
        total += price * item.quantity;
      }

      // Delete old items and insert new ones
      db.prepare('DELETE FROM order_items WHERE order_id = ?').run(req.params.id);

      const insertItem = db.prepare(
        'INSERT INTO order_items (order_id, product_id, product_name, price, quantity) VALUES (?, ?, ?, ?, ?)'
      );
      const insertAll = db.transaction((items) => {
        for (const item of items) {
          insertItem.run(req.params.id, item.product_id, item.product_name, item.price, item.quantity);
        }
      });
      insertAll(items);
    }

    db.prepare(
      `UPDATE orders SET
        customer_name = COALESCE(?, customer_name),
        customer_phone = COALESCE(?, customer_phone),
        customer_fb = COALESCE(?, customer_fb),
        status = COALESCE(?, status),
        total = ?,
        note = COALESCE(?, note),
        updated_at = CURRENT_TIMESTAMP
       WHERE id = ?`
    ).run(
      customer_name || null,
      customer_phone !== undefined ? customer_phone : null,
      customer_fb !== undefined ? customer_fb : null,
      status || null,
      total,
      note !== undefined ? note : null,
      req.params.id
    );

    const order = db.prepare('SELECT * FROM orders WHERE id = ?').get(req.params.id);
    const orderItems = db.prepare('SELECT * FROM order_items WHERE order_id = ?').all(req.params.id);

    res.json({ ...order, items: orderItems });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Delete order
router.delete('/:id', (req, res) => {
  try {
    const existing = db.prepare('SELECT * FROM orders WHERE id = ?').get(req.params.id);
    if (!existing) {
      return res.status(404).json({ error: 'Order not found' });
    }

    db.prepare('DELETE FROM orders WHERE id = ?').run(req.params.id);
    res.json({ message: 'Order deleted successfully' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
