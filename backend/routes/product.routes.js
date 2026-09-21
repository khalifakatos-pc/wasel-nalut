const express = require('express');
const router = express.Router();
const productController = require('../controllers/productController');

const wrap = (fn) => (req, res, next) => fn(req, res, req.app.get('db'), next);

router.get('/', wrap(productController.getProducts));
router.get('/:id', wrap(productController.getProductById));
router.post('/', wrap(productController.createProduct));
router.patch('/:id', wrap(productController.updateProduct));
router.delete('/:id', wrap(productController.deleteProduct));

module.exports = router;
