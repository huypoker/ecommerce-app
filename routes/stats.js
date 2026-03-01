const express = require('express');
const db = require('../database');
const { authenticateToken, requireAdmin } = require('../middleware/auth');

const router = express.Router();

router.use(authenticateToken, requireAdmin);

// GET /api/stats/revenue?period=day|month|year
router.get('/revenue', (req, res) => {
  try {
    const period = req.query.period || 'day';

    let groupExpr;
    if (period === 'month') {
      groupExpr = "strftime('%Y-%m', created_at)";
    } else if (period === 'year') {
      groupExpr = "strftime('%Y', created_at)";
    } else {
      groupExpr = "DATE(created_at)";
    }

    const rows = db.prepare(`
      SELECT ${groupExpr} AS period,
             SUM(total) AS revenue,
             COUNT(*) AS order_count
      FROM orders
      WHERE status = 'da_hoan_thanh'
      GROUP BY ${groupExpr}
      ORDER BY period DESC
    `).all();

    // Summary totals
    const summary = db.prepare(`
      SELECT COALESCE(SUM(total), 0) AS total_revenue,
             COUNT(*) AS total_orders
      FROM orders
      WHERE status = 'da_hoan_thanh'
    `).get();

    res.json({
      period,
      summary: {
        total_revenue: summary.total_revenue,
        total_orders: summary.total_orders,
      },
      data: rows,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
