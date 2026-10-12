const NALUT_CENTER = {
  latitude: 31.8687,
  longitude: 10.9818
};

function calculateHaversineDistance(lat1, lon1, lat2, lon2) {
  if (!lat1 || !lon1 || !lat2 || !lon2) return 0;
  const R = 6371000; // Earth radius in meters
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c; // meters
}

function estimateEtaMinutes(distanceMeters, currentSpeedKmh) {
  const effectiveSpeed = currentSpeedKmh > 10 ? currentSpeedKmh : 25; // default 25 km/h in city
  const speedMetersPerMinute = (effectiveSpeed * 1000) / 60;
  return Math.max(1, Math.ceil(distanceMeters / speedMetersPerMinute));
}

/**
 * Calculates dynamic delivery fee based on geospatial distance from store (or central Nalut) and weight.
 * Base delivery fee starts at 5.00 LYD in central Nalut (radius <= 2.5 km).
 * Scales dynamically: within 2.5 km = 5.00 LYD; beyond 2.5 km = 5.00 + (distance - 2.5) * 0.40 LYD.
 * Beyond 8.0 km, applies distance multiplier so fee >= 7.00 LYD for distant/mountainous zones.
 *
 * @param {Object} store The store object (or null to use Nalut center)
 * @param {number} deliveryLat Destination latitude
 * @param {number} deliveryLng Destination longitude
 * @param {number} totalWeightKg Order weight in kg
 * @param {Object} systemConfig The system pricing configuration
 */
function calculateDynamicDeliveryFee(store, deliveryLat, deliveryLng, totalWeightKg = 1.0, systemConfig = {}) {
  const storeLat = (store && store.latitude) ? store.latitude : NALUT_CENTER.latitude;
  const storeLng = (store && store.longitude) ? store.longitude : NALUT_CENTER.longitude;
  const destLat = deliveryLat || NALUT_CENTER.latitude;
  const destLng = deliveryLng || NALUT_CENTER.longitude;

  const distanceMeters = calculateHaversineDistance(
    storeLat,
    storeLng,
    destLat,
    destLng
  );
  const distanceKm = distanceMeters / 1000.0;

  const pricing = (systemConfig && systemConfig.pricing_config) || {};
  const configuredBaseFee = pricing.base_fee !== undefined ? parseFloat(pricing.base_fee) : 5.00;
  const storeBaseFee = (store && store.base_delivery_fee_lyd !== undefined) ? parseFloat(store.base_delivery_fee_lyd) : 5.00;
  const baseFee = Math.max(5.00, storeBaseFee || configuredBaseFee || 5.00);

  const baseDistanceKm = pricing.base_distance_km !== undefined ? parseFloat(pricing.base_distance_km) : 2.5;
  const perKmRate = pricing.per_km_rate !== undefined ? parseFloat(pricing.per_km_rate) : 0.40;
  const longDistanceThresholdKm = pricing.long_distance_threshold_km !== undefined ? parseFloat(pricing.long_distance_threshold_km) : 8.0;
  const longDistanceMultiplier = pricing.long_distance_multiplier !== undefined ? parseFloat(pricing.long_distance_multiplier) : 1.35;
  const freeWeightKg = pricing.free_weight_kg !== undefined ? parseFloat(pricing.free_weight_kg) : 3.0;
  const perKgSurcharge = pricing.per_kg_surcharge !== undefined ? parseFloat(pricing.per_kg_surcharge) : 0.50;

  let deliveryFee = baseFee;

  if (distanceKm > baseDistanceKm) {
    if (distanceKm <= longDistanceThresholdKm) {
      deliveryFee += (distanceKm - baseDistanceKm) * perKmRate;
    } else {
      const normalExtra = (longDistanceThresholdKm - baseDistanceKm) * perKmRate;
      const longExtra = (distanceKm - longDistanceThresholdKm) * (perKmRate * longDistanceMultiplier);
      deliveryFee += normalExtra + longExtra;
    }
  }

  // Ensure mountainous/distant orders (distance > 8.0km) have fee >= 7.00 LYD
  if (distanceKm > longDistanceThresholdKm && deliveryFee < 7.00) {
    deliveryFee = 7.00;
  }
  deliveryFee = Math.max(baseFee, deliveryFee);

  // Weight surcharge
  if (totalWeightKg > freeWeightKg) {
    const extraWeight = totalWeightKg - freeWeightKg;
    deliveryFee += extraWeight * perKgSurcharge;
  }

  // Round to 2 decimal places
  deliveryFee = Math.round(deliveryFee * 100) / 100;

  return {
    base_fee: Number(baseFee.toFixed(2)),
    delivery_fee_lyd: Number(deliveryFee.toFixed(2)),
    distance_km: Math.round(distanceKm * 100) / 100,
    distance_meters: Math.round(distanceMeters),
    currency: 'LYD',
    estimated_eta_minutes: estimateEtaMinutes(distanceMeters, 25)
  };
}

module.exports = {
  NALUT_CENTER,
  calculateHaversineDistance,
  estimateEtaMinutes,
  calculateDynamicDeliveryFee
};
