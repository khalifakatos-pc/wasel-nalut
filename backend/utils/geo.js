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
 * Calculates dynamic delivery fee based on distance and weight.
 * @param {Object} store The store object
 * @param {number} deliveryLat Destination latitude
 * @param {number} deliveryLng Destination longitude
 * @param {number} totalWeightKg Order weight in kg
 * @param {Object} systemConfig The system pricing configuration
 */
function calculateDynamicDeliveryFee(store, deliveryLat, deliveryLng, totalWeightKg = 1.0, systemConfig) {
  const distanceMeters = calculateHaversineDistance(
    store.latitude,
    store.longitude,
    deliveryLat,
    deliveryLng
  );
  const distanceKm = distanceMeters / 1000.0;

  const pricing = systemConfig.pricing_config || {
    base_fee: 3.00,
    base_distance_km: 2.5,
    per_km_rate: 0.75,
    long_distance_threshold_km: 8.0,
    long_distance_multiplier: 1.25,
    free_weight_kg: 3.0,
    per_kg_surcharge: 0.50
  };

  let deliveryFee = pricing.base_fee;

  // Additional distance fee
  if (distanceKm > pricing.base_distance_km) {
    const extraKm = distanceKm - pricing.base_distance_km;
    if (distanceKm > pricing.long_distance_threshold_km) {
      const normalExtra = pricing.long_distance_threshold_km - pricing.base_distance_km;
      const longExtra = distanceKm - pricing.long_distance_threshold_km;
      deliveryFee += (normalExtra * pricing.per_km_rate) + (longExtra * pricing.per_km_rate * pricing.long_distance_multiplier);
    } else {
      deliveryFee += extraKm * pricing.per_km_rate;
    }
  }

  // Weight surcharge
  if (totalWeightKg > pricing.free_weight_kg) {
    const extraWeight = totalWeightKg - pricing.free_weight_kg;
    deliveryFee += extraWeight * pricing.per_kg_surcharge;
  }

  // Round to nearest 0.50 LYD
  deliveryFee = Math.round(deliveryFee * 2) / 2;
  return {
    delivery_fee_lyd: Math.max(3.00, deliveryFee),
    distance_km: Math.round(distanceKm * 10) / 10,
    distance_meters: Math.round(distanceMeters),
    estimated_eta_minutes: estimateEtaMinutes(distanceMeters, 25)
  };
}

module.exports = {
  calculateHaversineDistance,
  estimateEtaMinutes,
  calculateDynamicDeliveryFee
};
