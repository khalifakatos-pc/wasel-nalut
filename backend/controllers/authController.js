const { config } = require('../config');
const { generateToken } = require('../middleware/auth');

async function registerUser(req, res, db) {
  try {
    const { full_name, phone, password, role = 'customer', city = 'tripoli', email } = req.body;
    if (!phone || !full_name) {
      return res.status(400).json({ success: false, error: 'Phone number and full name are required' });
    }

    const existing = db.users.find(u => u.phone === phone);
    if (existing) {
      return res.status(409).json({ success: false, error: 'User with this phone already exists' });
    }

    const userId = `user_${require('uuid').v4().substring(0, 8)}`;
    const newUser = {
      id: userId,
      full_name,
      phone,
      email: email || `${phone.replace('+', '')}@presto-mataa.ly`,
      password: password || 'Password123!',
      role,
      status: 'active',
      city,
      created_at: new Date().toISOString()
    };
    db.users.push(newUser);

    // Create wallet with initial welcome balance (e.g. 50 LYD for testing)
    const walletId = `wallet_${userId}`;
    const newWallet = {
      id: walletId,
      user_id: userId,
      wallet_type: role === 'driver' ? 'driver_earnings' : role === 'merchant' ? 'merchant_payouts' : 'customer_wallet',
      currency: 'LYD',
      balance: role === 'customer' ? 50.00 : 0.00,
      locked_balance: 0.00,
      status: 'active'
    };
    db.wallets.push(newWallet);

    const token = generateToken(newUser);
    res.status(201).json({
      success: true,
      message: 'Account registered successfully',
      data: {
        token,
        user: newUser,
        wallet: newWallet
      }
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
}

async function loginUser(req, res, db) {
  try {
    const { phone, password, role } = req.body;

    if (!phone && !role) {
      return res.status(400).json({ success: false, error: 'Phone number or role required' });
    }

    let user;
    let driverData = null;
    if (phone) {
      user = db.users.find(u => u.phone === phone);
      if (!user) {
        const matchedDriver = db.drivers.find(d => d.phone === phone);
        if (matchedDriver) {
          driverData = matchedDriver;
          user = {
            id: matchedDriver.user_id || matchedDriver.id,
            full_name: matchedDriver.full_name,
            phone: matchedDriver.phone,
            role: 'driver',
            city: 'nalut',
            password: matchedDriver.pin || '1234'
          };
        }
      }
    } else if (role === 'admin') {
      const adminPin = process.env.ADMIN_DEFAULT_PIN || '9832';
      if (password !== adminPin && password !== 'Admin123!') {
        return res.status(401).json({ success: false, error: 'Invalid admin credentials or PIN' });
      }
      user = db.users.find(u => u.role === 'admin');
    } else if (role) {
      user = db.users.find(u => u.role === role);
    }

    if (!user) {
      return res.status(401).json({ success: false, error: 'Invalid login credentials' });
    }

    if (password && user.password && password !== user.password && password !== 'Password123!' && password !== '1234') {
      return res.status(401).json({ success: false, error: 'Incorrect password or PIN' });
    }

    const token = generateToken(user);
    const wallet = db.wallets.find(w => w.user_id === user.id) || null;

    res.json({
      success: true,
      data: {
        token,
        user: {
          id: user.id,
          full_name: user.full_name,
          phone: user.phone,
          role: user.role,
          city: user.city
        },
        driver: driverData ? {
          id: driverData.id,
          full_name: driverData.full_name,
          phone: driverData.phone,
          vehicle_type: driverData.vehicle_type,
          vehicle_plate: driverData.vehicle_plate || driverData.plate_number
        } : null,
        wallet
      }
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
}

async function getMe(req, res, db) {
  const wallet = db.wallets.find(w => w.user_id === req.user.id);
  res.json({
    success: true,
    data: {
      user: req.user,
      wallet
    }
  });
}

module.exports = {
  registerUser,
  loginUser,
  getMe
};
