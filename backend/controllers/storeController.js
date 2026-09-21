const { config } = require('../config');
const { calculateDynamicDeliveryFee } = require('../utils/geo');

async function getStores(req, res, db) {
  try {
    const { type, city, search, district, featured, lat, lng } = req.query;
    let stores = [...db.stores];

    if (type) {
      stores = stores.filter(s => s.type === type.toLowerCase());
    }
    if (city) {
      stores = stores.filter(s => s.city.toLowerCase() === city.toLowerCase());
    }
    if (district) {
      stores = stores.filter(s => s.district.toLowerCase().includes(district.toLowerCase()));
    }
    if (featured === 'true') {
      stores = stores.filter(s => s.is_featured);
    }
    if (search) {
      const q = search.toLowerCase();
      stores = stores.filter(s =>
        s.name.toLowerCase().includes(q) ||
        s.name_en.toLowerCase().includes(q) ||
        (s.cuisine_tags && s.cuisine_tags.some(t => t.toLowerCase().includes(q)))
      );
    }

    if (lat && lng) {
      const userLat = parseFloat(lat);
      const userLng = parseFloat(lng);
      stores = stores.map(store => {
        const distanceMeters = require('../utils/geo').calculateHaversineDistance(userLat, userLng, store.latitude, store.longitude);
        const feeQuote = calculateDynamicDeliveryFee(store, userLat, userLng, 1.0, db.system_config);
        return {
          ...store,
          distance_meters: Math.round(distanceMeters),
          distance_km: Math.round((distanceMeters / 1000) * 10) / 10,
          calculated_delivery_fee_lyd: feeQuote.delivery_fee_lyd,
          calculated_eta_minutes: feeQuote.estimated_eta_minutes
        };
      });
      stores.sort((a, b) => a.distance_meters - b.distance_meters);
    }

    res.set('Cache-Control', 'public, max-age=15, stale-while-revalidate=60');
    res.json({
      success: true,
      count: stores.length,
      data: stores
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
}

async function getStoreById(req, res, db) {
  const store = db.stores.find(s => s.id === req.params.id);
  if (!store) {
    return res.status(404).json({ success: false, error: 'Store not found' });
  }
  res.set('Cache-Control', 'public, max-age=30, stale-while-revalidate=120');
  res.json({
    success: true,
    data: store
  });
}

async function getStoreMenu(req, res, db) {
  try {
    const store = db.stores.find(s => s.id === req.params.id);
    if (!store) {
      return res.status(404).json({ success: false, error: 'Store not found' });
    }

    const storeProducts = db.products.filter(p => p.store_id === store.id);
    const categoryIds = [...new Set(storeProducts.map(p => p.category_id))];
    const categories = db.categories.filter(c => categoryIds.includes(c.id));

    const menuSections = categories.map(cat => ({
      category: cat,
      products: storeProducts.filter(p => p.category_id === cat.id)
    }));

    res.set('Cache-Control', 'public, max-age=30, stale-while-revalidate=120');
    res.json({
      success: true,
      store: {
        id: store.id,
        name: store.name,
        name_en: store.name_en,
        type: store.type,
        rating: store.rating,
        delivery_time_min: store.delivery_time_min,
        delivery_time_max: store.delivery_time_max,
        base_delivery_fee_lyd: store.base_delivery_fee_lyd,
        badge: store.badge
      },
      categories,
      menu_sections: menuSections,
      all_products: storeProducts,
      products: storeProducts,
      data: {
        store_id: store.id,
        products: storeProducts
      }
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
}

async function createStore(req, res, db) {
  try {
    const s = req.body;
    if (!s.name) {
      return res.status(400).json({ success: false, error: 'Store name is required' });
    }
    const newStore = {
      id: s.id || `store_nalut_${Date.now()}`,
      name: s.name,
      name_en: s.name_en || s.name,
      type: s.type || 'restaurant',
      district: s.district || 'نالوت',
      city: 'nalut',
      phone: s.phone || '',
      pin: s.pin || '1234',
      app_mode: s.app_mode || ((s.type === 'grocery' || s.type === 'pharmacy') ? 'retail' : 'kitchen'),
      commission_rate: s.commission_rate || 10.0,
      rating: 5.0,
      review_count: 0,
      delivery_time_min: s.delivery_time_min || 20,
      delivery_time_max: s.delivery_time_max || 35,
      min_order_lyd: s.min_order_lyd || 10.0,
      base_delivery_fee_lyd: s.base_delivery_fee_lyd || 4.0,
      latitude: s.latitude || 31.8686,
      longitude: s.longitude || 10.9818,
      is_open: s.is_open !== false,
      is_featured: s.is_featured !== false,
      created_at: new Date().toISOString()
    };
    db.stores.unshift(newStore);

    // DB helpers are currently in server.js, we will move them to repositories later.
    // For now, we call the helper via a shared context or app method.
    if (req.app.locals.saveStoreToPg) {
      req.app.locals.saveStoreToPg(newStore);
    }
    if (req.app.locals.saveSeedData) {
      req.app.locals.saveSeedData();
    }

    if (req.io) {
      req.io.emit('store:created', newStore);
    }
    res.status(201).json({ success: true, data: newStore });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
}

async function updateStore(req, res, db) {
  try {
    const store = db.stores.find(s => s.id === req.params.id);
    if (!store) {
      return res.status(404).json({ success: false, error: 'Store not found' });
    }
    Object.assign(store, req.body);
    if (req.body.is_open !== undefined) {
      store.is_open = req.body.is_open === true || req.body.is_open === 'true' || req.body.is_open === 1;
      store.last_heartbeat = store.is_open ? Date.now() : 0;
    }
    if (req.app.locals.saveSeedData) req.app.locals.saveSeedData();
    if (req.app.locals.saveStoreToPg) req.app.locals.saveStoreToPg(store);

    if (req.io) {
      req.io.emit('store:updated', store);
      req.io.emit('store:status_changed', { store_id: store.id, is_open: store.is_open });
    }
    res.json({ success: true, data: store });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
}

async function storeHeartbeat(req, res, db) {
  try {
    const store = db.stores.find(s => s.id === req.params.id);
    if (!store) {
      return res.status(404).json({ success: false, error: 'Store not found' });
    }
    const wasClosed = !store.is_open;
    store.last_heartbeat = Date.now();
    store.is_open = true;

    if (wasClosed) {
      if (req.app.locals.saveStoreToPg) req.app.locals.saveStoreToPg(store);
      if (req.app.locals.saveSeedData) req.app.locals.saveSeedData();
      if (req.io) {
        req.io.emit('store:status_changed', { store_id: store.id, is_open: true });
        req.io.emit('store:updated', store);
      }
    }
    res.json({
      success: true,
      store_id: store.id,
      is_open: store.is_open,
      last_heartbeat: store.last_heartbeat
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
}

async function deleteStore(req, res, db) {
  db.stores = db.stores.filter(s => s.id !== req.params.id);
  db.products = db.products.filter(p => p.store_id !== req.params.id);
  if (req.app.locals.saveSeedData) req.app.locals.saveSeedData();
  if (req.app.locals.deleteStoreFromPg) req.app.locals.deleteStoreFromPg(req.params.id);
  if (req.io) {
    req.io.emit('store:deleted', { id: req.params.id });
  }
  res.json({ success: true, message: 'Store deleted' });
}

module.exports = {
  getStores,
  getStoreById,
  getStoreMenu,
  createStore,
  updateStore,
  storeHeartbeat,
  deleteStore
};
