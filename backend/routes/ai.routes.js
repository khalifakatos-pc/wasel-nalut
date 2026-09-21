const express = require('express');
const router = express.Router();
const aiController = require('../controllers/aiController');

const wrap = (fn) => (req, res, next) => fn(req, res, req.app.get('db'), next);

router.post('/parse-menu-invoice', wrap(aiController.parseMenuAI));
router.post('/stores/:id/bulk-products', wrap(aiController.bulkAddProducts));

module.exports = router;
