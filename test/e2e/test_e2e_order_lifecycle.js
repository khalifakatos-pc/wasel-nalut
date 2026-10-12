/**
 * E2E Order Lifecycle Test Runner Proxy
 * Calls the authoritative backend/test_e2e_order_lifecycle.js
 */

const { main } = require('../../backend/test_e2e_order_lifecycle');

if (require.main === module) {
  main();
}

module.exports = require('../../backend/test_e2e_order_lifecycle');
