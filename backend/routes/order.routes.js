const express = require('express');
const router = express.Router();
const orderController = require('../controllers/orderController');

const wrap = (fn) => (req, res, next) => fn(req, res, req.app.get('db'), next);

router.post('/checkout', wrap(orderController.checkout));
router.get('/:id', wrap(orderController.getOrder));
router.get('/', wrap(orderController.listOrders));
router.post('/:id/status', wrap(orderController.updateStatus));
router.post('/:id/handover', wrap(orderController.handover));

module.exports = router;
