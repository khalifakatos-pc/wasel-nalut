const express = require('express');
const router = express.Router();
const storeController = require('../controllers/storeController');

const wrap = (fn) => (req, res, next) => fn(req, res, req.app.get('db'), next);

router.get('/', wrap(storeController.getStores));
router.get('/:id', wrap(storeController.getStoreById));
router.get('/:id/menu', wrap(storeController.getStoreMenu));
router.post('/', wrap(storeController.createStore));
router.patch('/:id', wrap(storeController.updateStore));
router.post('/:id/heartbeat', wrap(storeController.storeHeartbeat));
router.delete('/:id', wrap(storeController.deleteStore));

module.exports = router;
