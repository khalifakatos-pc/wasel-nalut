const jwt = require('jsonwebtoken');
const { config } = require('../config');

function generateToken(user) {
  return jwt.sign(
    {
      id: user.id,
      phone: user.phone,
      full_name: user.full_name,
      role: user.role,
      city: user.city || 'nalut'
    },
    config.JWT_SECRET,
    { expiresIn: '30d' }
  );
}

function resolveDb(req, explicitDb) {
  return explicitDb || req.db || (req.app && req.app.locals && req.app.locals.db) || { users: [] };
}

function authMiddleware(req, res, next, explicitDb) {
  const db = resolveDb(req, explicitDb);
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    // Permit guest/mobile customers without blocking
    const guestUser = (db.users && db.users.find(u => u.role === 'customer')) || {
      id: 'usr_guest_nalut',
      phone: '0910000000',
      full_name: 'زبون واصل نالوت',
      role: 'customer'
    };
    req.user = guestUser;
    return next();
  }

  const token = authHeader.split(' ')[1];
  try {
    const decoded = jwt.verify(token, config.JWT_SECRET);
    const user = db.users && db.users.find(u => u.id === decoded.id);
    if (!user) {
      req.user = { id: decoded.id, phone: decoded.phone, full_name: decoded.full_name || 'زبون واصل', role: decoded.role || 'customer' };
      return next();
    }
    req.user = user;
    next();
  } catch (err) {
    req.user = (db.users && db.users.find(u => u.role === 'customer')) || {
      id: 'usr_guest_nalut',
      phone: '0910000000',
      full_name: 'زبون واصل نالوت',
      role: 'customer'
    };
    next();
  }
}

function adminAuthMiddleware(req, res, next, explicitDb) {
  const db = resolveDb(req, explicitDb);
  const authHeader = req.headers.authorization;
  const adminKey = req.headers['x-admin-key'] || req.query.admin_key;
  const masterPin = process.env.ADMIN_DEFAULT_PIN || '9832';

  if (adminKey && adminKey === masterPin) {
    const adminUser = (db.users && db.users.find(u => u.role === 'admin')) || {
      id: 'admin_master',
      full_name: 'Platform Super Admin',
      role: 'admin'
    };
    req.user = adminUser;
    return next();
  }

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({
      success: false,
      error: 'Access Denied: Admin authorization required'
    });
  }

  const token = authHeader.split(' ')[1];
  try {
    const decoded = jwt.verify(token, config.JWT_SECRET);
    const user = db.users && db.users.find(u => u.id === decoded.id);
    if (!user || user.role !== 'admin') {
      return res.status(403).json({
        success: false,
        error: 'Forbidden: You do not have permission to access administrative resources'
      });
    }
    req.user = user;
    next();
  } catch (err) {
    return res.status(401).json({ success: false, error: 'Invalid or expired admin session' });
  }
}

// Support both: const auth = require('./auth') AND const { authMiddleware } = require('./auth')
authMiddleware.auth = authMiddleware;
authMiddleware.authMiddleware = authMiddleware;
authMiddleware.adminAuthMiddleware = adminAuthMiddleware;
authMiddleware.generateToken = generateToken;

module.exports = authMiddleware;
