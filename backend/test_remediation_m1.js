const fs = require('fs');

console.log('--- Remediated Assertions Suite ---');
const server = fs.readFileSync('backend/server.js', 'utf8');

// 1. Check no prevDriver.status = 'available'
if (server.includes("prevDriver.status = 'available'")) {
  console.error('FAIL: prevDriver.status = available still found');
  process.exit(1);
}
if (!server.includes("prevDriver.status = 'online_idle'")) {
  console.error('FAIL: prevDriver.status = online_idle not found');
  process.exit(1);
}
console.log('✅ 1. Driver status enum fixed to online_idle');

// 2. Check PIN mandatory on purge
if (server.includes('if (pin && pin !==')) {
  console.error('FAIL: optional pin still found');
  process.exit(1);
}
if (!server.includes("if (!pin || (pin !== '7788' && pin !== req.user?.pin))")) {
  console.error('FAIL: mandatory pin check not found');
  process.exit(1);
}
console.log('✅ 2. PIN mandatory on purge');

// 3. Check terminal order check on reassign
if (!server.includes("['delivered', 'cancelled'].includes(order.status)")) {
  console.error('FAIL: terminal status check not found in reassign');
  process.exit(1);
}
console.log('✅ 3. Terminal order check on reassign present');

// 4. Check cache eviction predicate
if (server.includes('o.order_number === order.id')) {
  console.error('FAIL: cache eviction typo still found');
  process.exit(1);
}
if (!server.includes('o.order_number === order.order_number')) {
  console.error('FAIL: corrected cache eviction predicate not found');
  process.exit(1);
}
console.log('✅ 4. Cache eviction predicate typo fixed');

// 5. Check adminOverride authorization
if (server.includes("const isAdmin = Boolean(req.body.adminOverride")) {
  console.error('FAIL: unauthenticated isAdmin in handleOrderStatusUpdate');
  process.exit(1);
}
if (server.includes("const isAdmin = Boolean(req.body?.adminOverride")) {
  console.error('FAIL: unauthenticated isAdmin in /cancel');
  process.exit(1);
}
console.log('✅ 5. Authorization bypass fixed on adminOverride');

console.log('🎉 ALL REMEDIATION CHECKS VERIFIED SUCCESSFULLY!');
