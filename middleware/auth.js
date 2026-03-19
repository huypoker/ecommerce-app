const crypto = require('crypto');
const jwt = require('jsonwebtoken');

const JWT_SECRET = process.env.JWT_SECRET || 'ecommerce_secret_key_2026';

function hashPassword(password) {
  const salt = crypto.randomBytes(32).toString('base64url');
  const hash = crypto.createHash('sha256').update(`${salt}:${password}`).digest('hex');
  return `${salt}:${hash}`;
}

function verifyPassword(password, storedHash) {
  const idx = storedHash.indexOf(':');
  if (idx === -1) return false;
  const salt = storedHash.substring(0, idx);
  const expectedHash = storedHash.substring(idx + 1);
  const actualHash = crypto.createHash('sha256').update(`${salt}:${password}`).digest('hex');
  return actualHash === expectedHash;
}

function generateToken(payload) {
  return jwt.sign(payload, JWT_SECRET, { expiresIn: '7d' });
}

function getUser(req) {
  const auth = req.headers.authorization;
  if (!auth || !auth.startsWith('Bearer ')) return null;
  try {
    return jwt.verify(auth.substring(7), JWT_SECRET);
  } catch {
    return null;
  }
}

function requireAuth(req, res, next) {
  const user = getUser(req);
  if (!user) return res.status(401).json({ error: 'Access token required' });
  req.user = user;
  next();
}

function requireAdmin(req, res, next) {
  const user = getUser(req);
  if (!user) return res.status(401).json({ error: 'Access token required' });
  if (user.role !== 'admin') return res.status(403).json({ error: 'Admin access required' });
  req.user = user;
  next();
}

module.exports = { hashPassword, verifyPassword, generateToken, getUser, requireAuth, requireAdmin };
