const express = require('express');
const db = require('../db');
const { hashPassword, requireSuperAdmin } = require('../middleware/auth');
const router = express.Router();

// Get all users
router.get('/', requireSuperAdmin, (req, res) => {
  try {
    const users = db.prepare(
      'SELECT id, name, email, role, created_at FROM users ORDER BY created_at DESC'
    ).all();
    res.json(users);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Create user
router.post('/', requireSuperAdmin, (req, res) => {
  try {
    const { name, email, password, role } = req.body;
    if (!name || !email || !password) {
      return res.status(400).json({ error: 'Name, email and password are required' });
    }
    const existing = db.prepare('SELECT id FROM users WHERE email = ?').get(email);
    if (existing) return res.status(409).json({ error: 'Email already exists' });

    const validRoles = ['user', 'admin', 'super_admin'];
    const userRole = validRoles.includes(role) ? role : 'user';
    const hashed = hashPassword(password);
    const result = db.prepare(
      'INSERT INTO users (name, email, password, role) VALUES (?, ?, ?, ?)'
    ).run(name, email, hashed, userRole);

    res.status(201).json({
      id: result.lastInsertRowid, name, email, role: userRole,
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Update user
router.put('/:id', requireSuperAdmin, (req, res) => {
  try {
    const userId = parseInt(req.params.id);
    const existing = db.prepare('SELECT * FROM users WHERE id = ?').get(userId);
    if (!existing) return res.status(404).json({ error: 'User not found' });

    // Prevent modifying own super_admin record role
    if (existing.role === 'super_admin' && req.user.id === userId && req.body.role !== 'super_admin') {
      return res.status(400).json({ error: 'Cannot change your own super_admin role' });
    }

    const { name, email, password, role } = req.body;
    const validRoles = ['user', 'admin', 'super_admin'];
    const newRole = role && validRoles.includes(role) ? role : existing.role;
    const newName = name || existing.name;
    const newEmail = email || existing.email;

    // Check email uniqueness if changed
    if (newEmail !== existing.email) {
      const emailTaken = db.prepare('SELECT id FROM users WHERE email = ? AND id != ?').get(newEmail, userId);
      if (emailTaken) return res.status(409).json({ error: 'Email already exists' });
    }

    if (password && password.trim()) {
      const hashed = hashPassword(password);
      db.prepare('UPDATE users SET name = ?, email = ?, password = ?, role = ? WHERE id = ?')
        .run(newName, newEmail, hashed, newRole, userId);
    } else {
      db.prepare('UPDATE users SET name = ?, email = ?, role = ? WHERE id = ?')
        .run(newName, newEmail, newRole, userId);
    }

    const updated = db.prepare('SELECT id, name, email, role, created_at FROM users WHERE id = ?').get(userId);
    res.json(updated);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Delete user
router.delete('/:id', requireSuperAdmin, (req, res) => {
  try {
    const userId = parseInt(req.params.id);
    if (req.user.id === userId) {
      return res.status(400).json({ error: 'Cannot delete your own account' });
    }
    const existing = db.prepare('SELECT * FROM users WHERE id = ?').get(userId);
    if (!existing) return res.status(404).json({ error: 'User not found' });

    db.prepare('DELETE FROM users WHERE id = ?').run(userId);
    res.json({ message: 'User deleted successfully' });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

module.exports = router;
