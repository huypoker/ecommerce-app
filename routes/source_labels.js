const express = require('express');
const db = require('../database');
const { authenticateToken, requireAdmin } = require('../middleware/auth');

const router = express.Router();

// Get all source labels (public)
router.get('/', (req, res) => {
  try {
    const labels = db.prepare('SELECT * FROM source_labels ORDER BY name ASC').all();
    res.json(labels);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Create source label (admin only)
router.post('/', authenticateToken, requireAdmin, (req, res) => {
  try {
    const { name } = req.body;
    if (!name || !name.trim()) {
      return res.status(400).json({ error: 'Name is required' });
    }

    const result = db.prepare('INSERT INTO source_labels (name) VALUES (?)').run(name.trim());
    const label = db.prepare('SELECT * FROM source_labels WHERE id = ?').get(result.lastInsertRowid);
    res.status(201).json(label);
  } catch (err) {
    if (err.message.includes('UNIQUE')) {
      return res.status(409).json({ error: 'Label already exists' });
    }
    res.status(500).json({ error: err.message });
  }
});

// Delete source label (admin only)
router.delete('/:id', authenticateToken, requireAdmin, (req, res) => {
  try {
    const existing = db.prepare('SELECT * FROM source_labels WHERE id = ?').get(req.params.id);
    if (!existing) {
      return res.status(404).json({ error: 'Label not found' });
    }
    db.prepare('DELETE FROM source_labels WHERE id = ?').run(req.params.id);
    res.json({ message: 'Label deleted successfully' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
