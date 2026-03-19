const express = require('express');
const db = require('../db');
const { requireAdmin } = require('../middleware/auth');
const router = express.Router();

router.get('/', (req, res) => {
  try {
    const labels = db.prepare('SELECT * FROM source_labels ORDER BY name ASC').all();
    res.json(labels);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.post('/', requireAdmin, (req, res) => {
  try {
    const name = (req.body.name || '').trim();
    if (!name) return res.status(400).json({ error: 'Name is required' });

    const result = db.prepare('INSERT INTO source_labels (name) VALUES (?)').run(name);
    const label = db.prepare('SELECT * FROM source_labels WHERE id = ?').get(result.lastInsertRowid);
    res.status(201).json(label);
  } catch (e) {
    if (e.message.includes('UNIQUE')) return res.status(409).json({ error: 'Label already exists' });
    res.status(500).json({ error: e.message });
  }
});

router.delete('/:id', requireAdmin, (req, res) => {
  try {
    const existing = db.prepare('SELECT * FROM source_labels WHERE id = ?').get(req.params.id);
    if (!existing) return res.status(404).json({ error: 'Label not found' });
    db.prepare('DELETE FROM source_labels WHERE id = ?').run(req.params.id);
    res.json({ message: 'Label deleted successfully' });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

module.exports = router;
