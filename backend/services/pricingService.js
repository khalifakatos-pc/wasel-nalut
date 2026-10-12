/**
 * ============================================================================
 * WASEL NALUT DYNAMIC PRICING ENGINE (R1)
 * Central Logistics & Dynamic Delivery Pricing Engine for Nalut, Libya.
 *
 * Base Coordinates: Central Nalut (31.8687, 10.9818)
 * Base Fee: Starts at 5.00 LYD in central Nalut (radius <= 2.5 km).
 * Scales dynamically:
 *   - <= 2.5 km: 5.00 LYD base fee
 *   - 2.5 km - 8.0 km: 5.00 + (distance - 2.5) * 0.40 LYD
 *   - > 8.0 km: Long distance multiplier applied, fee >= 7.00 LYD
 * ============================================================================
 */

const {
  NALUT_CENTER,
  calculateHaversineDistance,
  estimateEtaMinutes,
  calculateDynamicDeliveryFee
} = require('../utils/geo');

class PricingService {
  constructor(systemConfig = {}) {
    this.systemConfig = systemConfig;
    this.center = NALUT_CENTER;
  }

  /**
   * Calculates delivery fee for a given store, destination, and weight.
   */
  calculateFee(store, deliveryLat, deliveryLng, totalWeightKg = 1.0, configOverride = null) {
    const config = configOverride || this.systemConfig;
    return calculateDynamicDeliveryFee(store, deliveryLat, deliveryLng, totalWeightKg, config);
  }

  /**
   * Generates a formal pricing quote object.
   *
   * @param {Object} params
   * @param {Object} [params.store]
   * @param {string} [params.store_id]
   * @param {number} [params.lat]
   * @param {number} [params.lng]
   * @param {number} [params.delivery_lat]
   * @param {number} [params.delivery_lng]
   * @param {number} [params.weight_kg]
   * @param {Object} [params.db]
   * @returns {Object} Quote { base_fee, distance_km, delivery_fee_lyd, currency, estimated_eta_minutes }
   */
  getQuote({ store, store_id, lat, lng, delivery_lat, delivery_lng, weight_kg = 1.0, db = null }) {
    let resolvedStore = store;
    if (!resolvedStore && store_id && db && Array.isArray(db.stores)) {
      resolvedStore = db.stores.find(s => s.id === store_id);
    }

    const destLat = parseFloat(delivery_lat !== undefined ? delivery_lat : (lat !== undefined ? lat : this.center.latitude));
    const destLng = parseFloat(delivery_lng !== undefined ? delivery_lng : (lng !== undefined ? lng : this.center.longitude));

    const pricingConfig = (db && db.system_config) ? db.system_config : this.systemConfig;
    const result = calculateDynamicDeliveryFee(resolvedStore, destLat, destLng, weight_kg, pricingConfig);

    return {
      base_fee: result.base_fee,
      distance_km: result.distance_km,
      distance_meters: result.distance_meters,
      delivery_fee_lyd: result.delivery_fee_lyd,
      currency: result.currency || 'LYD',
      estimated_eta_minutes: result.estimated_eta_minutes
    };
  }
}

module.exports = new PricingService();
module.exports.PricingService = PricingService;
module.exports.NALUT_CENTER = NALUT_CENTER;
