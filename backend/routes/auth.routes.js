const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');
const { authMiddleware } = require('../middleware/auth');
const { rateLimiter } = require('../middleware/rateLimit');

// Higher-order function to inject 'db' into controller methods
const wrap = (fn) => (req, res, next) => fn(req, res, req.app.get('db'), next);

router.post('/register', wrap(authController.registerUser));
router.post('/login', rateLimiter(15, 60000), wrap(authController.loginUser));

// we use a custom middleware chain for /me to ensure authMiddleware runs first
router.get('/me', (req, res, next) => {
  // Access db from app settings
  const db = req.app.get('db');

  // Run authMiddleware manually here to keep it simple and avoid complex wrapper nesting
  authMiddleware(req, res, (err) => {
    if (err) return next(err);
    authController.getMe(req, res, db);
  });
}, wrap(authController.getMe)); // Fallback

// Overriding /me to be clean
router.get('/me', (req, res, next) => {
  const db = req.app.get('db');
  authMiddleware(req, res, () => {
    authController.getMe(req, res, db);
  });
});

module.exports = router;
