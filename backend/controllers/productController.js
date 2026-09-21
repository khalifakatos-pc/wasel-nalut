const { config } = require('../config');

async function getProducts(req, res, db) {
  try {
    const { store_id, category_id, search } = req.query;
    let products = [...db.products];
    if (store_id) {
      products = products.filter(p => p.store_id === store_id);
    }
    if (category_id) {
      products = products.filter(p => p.category_id === category_id);
    }
    if (search) {
      const q = search.toLowerCase();
      products = products.filter(p =>
        (p.name && p.name.toLowerCase().includes(q)) ||
        (p.name_ar && p.name_ar.toLowerCase().includes(q)) ||
        (p.description && p.description.toLowerCase().includes(q))
      );
    }
    res.json({
      success: true,
      count: products.length,
      data: products
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
}

async function getProductById(req, res, db) {
  const product = db.products.find(p => p.id === req.params.id);
  if (!product) {
    return res.status(404).json({ success: false, error: 'Product not found' });
  }
  const store = db.stores.find(s => s.id === product.store_id);
  res.json({
    success: true,
    data: {
      ...product,
      store: store ? { id: store.id, name: store.name, type: store.type } : null
    }
  });
}

async function createProduct(req, res, db) {
  try {
    const p = req.body;
    if (!p.name && !p.name_ar) {
      return res.status(400).json({ success: false, error: 'Product name is required' });
    }
    const price = parseFloat(p.price || p.price_lyd || 0);
    const stockQuantity = p.stock_quantity !== undefined && p.stock_quantity !== null
      ? parseInt(p.stock_quantity, 10)
      : 50;
    const isAvailable = p.is_available !== undefined
      ? (p.is_available === true || p.is_available === 'true' || p.is_available === 1)
      : (stockQuantity > 0);

    const newProd = {
      id: p.id || `prod_${require('uuid').v4().substring(0, 8)}`,
      store_id: p.store_id || 'store_default',
      name: p.name || p.name_ar,
      name_ar: p.name_ar || p.name,
      price: price,
      price_lyd: price,
      category: p.category || 'عام',
      category_id: p.category_id || '',
      description: p.description || p.desc_ar || '',
      desc_ar: p.desc_ar || p.description || '',
      image_url: p.image_url || '',
      in_stock: isAvailable && stockQuantity > 0,
      is_available: isAvailable && stockQuantity > 0,
      stock_quantity: stockQuantity,
      is_popular: p.is_popular === true || p.is_popular === 'true',
      unit: p.unit || 'قطعة',
      created_at: new Date().toISOString()
    };

    db.products.push(newProd);
    if (req.app.locals.saveSeedData) req.app.locals.saveSeedData();
    if (req.app.locals.saveProductToPg) req.app.locals.saveProductToPg(newProd);

    if (req.io) {
      req.io.emit('product:created', newProd);
      req.io.emit('store:menu_updated', { store_id: newProd.store_id });
    }
    res.status(201).json({ success: true, data: newProd });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
}

async function updateProduct(req, res, db) {
  try {
    const product = db.products.find(p => p.id === req.params.id);
    if (!product) {
      return res.status(404).json({ success: false, error: 'Product not found' });
    }
    const updates = req.body;
    if (updates.price !== undefined || updates.price_lyd !== undefined) {
      const newPrice = parseFloat(updates.price_lyd || updates.price);
      product.price = newPrice;
      product.price_lyd = newPrice;
    }
    if (updates.stock_quantity !== undefined && updates.stock_quantity !== null) {
      const qty = parseInt(updates.stock_quantity, 10);
      product.stock_quantity = isNaN(qty) ? 0 : Math.max(0, qty);
      if (product.stock_quantity === 0) {
        product.in_stock = false;
        product.is_available = false;
      } else {
        product.in_stock = true;
        product.is_available = true;
      }
    }
    if (updates.is_available !== undefined) {
      const isAvail = updates.is_available === true || updates.is_available === 'true' || updates.is_available === 1;
      product.is_available = isAvail;
      product.in_stock = isAvail;
      if (!isAvail) {
        product.stock_quantity = 0;
      } else if (product.stock_quantity === 0 || product.stock_quantity === undefined) {
        product.stock_quantity = 10;
      }
    } else if (updates.in_stock !== undefined) {
      const inStk = updates.in_stock === true || updates.in_stock === 'true' || updates.in_stock === 1;
      product.in_stock = inStk;
      product.is_available = inStk;
      if (!inStk) {
        product.stock_quantity = 0;
      } else if (product.stock_quantity === 0 || product.stock_quantity === undefined) {
        product.stock_quantity = 10;
      }
    }
    if (updates.name) product.name = updates.name;
    if (updates.name_ar) product.name_ar = updates.name_ar;
    if (updates.description) product.description = updates.description;
    if (updates.desc_ar) product.desc_ar = updates.desc_ar;
    if (updates.category) product.category = updates.category;
    if (updates.unit) product.unit = updates.unit;

    if (req.app.locals.saveSeedData) req.app.locals.saveSeedData();
    if (req.app.locals.saveProductToPg) req.app.locals.saveProductToPg(product);

    if (req.io) {
      req.io.emit('product:updated', product);
      req.io.emit('product:stock_changed', {
        product_id: product.id,
        store_id: product.store_id,
        in_stock: product.in_stock,
        is_available: product.is_available,
        stock_quantity: product.stock_quantity
      });
      req.io.emit('store:menu_updated', { store_id: product.store_id });
    }
    res.json({ success: true, data: product });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
}

async function deleteProduct(req, res, db) {
  try {
    const idx = db.products.findIndex(p => p.id === req.params.id);
    if (idx === -1) {
      return res.status(404).json({ success: false, error: 'Product not found' });
    }
    const deleted = db.products.splice(idx, 1)[0];
    if (req.app.locals.saveSeedData) req.app.locals.saveSeedData();
    if (req.app.locals.deleteProductFromPg) req.app.locals.deleteProductFromPg(req.params.id);

    if (req.io) {
      req.io.emit('product:deleted', { id: deleted.id, store_id: deleted.store_id });
      req.io.emit('store:menu_updated', { store_id: deleted.store_id });
    }
    res.json({ success: true, message: 'Product deleted', data: deleted });
  } catch (err) {
    res.status(500).json({ success: false, error:错误 message });
  }
}

module.exports = {
  getProducts,
  getProductById,
  createProduct,
  updateProduct,
  deleteProduct
};
