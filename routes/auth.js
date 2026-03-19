const express = require('express');
const db = require('../db');
const { hashPassword, verifyPassword, generateToken } = require('../middleware/auth');
const router = express.Router();

router.post('/login', (req, res) => {
  try {
    const { email, password } = req.body;
    if (!email || !password) return res.status(400).json({ error: 'Email and password are required' });

    const user = db.prepare('SELECT * FROM users WHERE email = ?').get(email);
    if (!user) return res.status(401).json({ error: 'Invalid email or password' });

    if (!verifyPassword(password, user.password)) return res.status(401).json({ error: 'Invalid email or password' });

    const token = generateToken({ id: user.id, email: user.email, role: user.role, name: user.name });
    res.json({ token, user: { id: user.id, name: user.name, email: user.email, role: user.role } });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.post('/register', (req, res) => {
  try {
    const { name, email, password, role } = req.body;
    if (!name || !email || !password) return res.status(400).json({ error: 'Name, email and password are required' });

    const existing = db.prepare('SELECT id FROM users WHERE email = ?').get(email);
    if (existing) return res.status(409).json({ error: 'Email already registered' });

    const hashedPassword = hashPassword(password);
    const userRole = role === 'admin' ? 'admin' : 'user';
    const result = db.prepare('INSERT INTO users (name, email, password, role) VALUES (?, ?, ?, ?)').run(name, email, hashedPassword, userRole);
    const userId = result.lastInsertRowid;

    const token = generateToken({ id: userId, email, role: userRole, name });
    res.status(201).json({ token, user: { id: userId, name, email, role: userRole } });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

module.exports = router;
