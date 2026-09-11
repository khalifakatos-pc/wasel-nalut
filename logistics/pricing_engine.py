"""
Dynamic Pricing & Delivery Fee Calculator for Super App Logistics.

This module calculates real-time delivery fees, dynamic surge multipliers based on
spatial demand/supply density imbalance, weight/volume surcharges for e-commerce,
and environmental/temporal adjustments.
"""

from __future__ import annotations
import math
from dataclasses import dataclass, field
from datetime import datetime, time
from typing import List, Dict, Tuple, Optional, Any


def haversine_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """
    Calculate the great circle distance in kilometers between two points
    on the earth (specified in decimal degrees).
    """
    r_earth = 6371.0088  # Mean Earth radius in kilometers
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = (math.sin(dlat / 2.0) ** 2 +
         math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) *
         math.sin(dlon / 2.0) ** 2)
    c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a))
    return r_earth * c


def road_distance_estimate(lat1: float, lon1: float, lat2: float, lon2: float,
                           detour_factor: float = 1.30) -> float:
    """
    Estimate realistic road network driving distance from Haversine distance
    using an urban road circuity/detour factor (default 1.30x).
    """
    return haversine_distance(lat1, lon1, lat2, lon2) * detour_factor


@dataclass
class PricingConfig:
    """Global configuration parameters for delivery fee calculation."""
    # Base fee structure
    base_fee: float = 2.50  # Base unlock fee ($)
    base_distance_km: float = 2.0  # Included distance in base fee (km)
    per_km_rate: float = 0.85  # Rate per km beyond base_distance_km ($/km)
    long_distance_threshold_km: float = 8.0  # Long distance surcharge threshold
    long_distance_rate_multiplier: float = 1.25  # Premium on km beyond long distance threshold

    # E-commerce Weight & Volume Surcharges
    free_weight_kg: float = 3.0  # Included weight in standard delivery (kg)
    per_kg_surcharge: float = 0.50  # Surcharge per additional kg ($/kg)
    max_standard_weight_kg: float = 25.0  # Maximum weight for two-wheeler dispatch
    volumetric_divisor: float = 5000.0  # cm^3 per kg (IATA standard)
    bulky_item_flat_fee: float = 3.00  # Flat surcharge for oversized packages

    # Surge Pricing Parameters (Sigmoid Model)
    surge_min: float = 1.0  # Minimum multiplier (no surge)
    surge_max: float = 3.0  # Cap on surge multiplier
    surge_k: float = 2.5  # Sigmoid steepness parameter
    surge_midpoint_ratio: float = 1.25  # Demand/supply ratio where surge is halfway to max
    density_search_radius_km: float = 3.0  # Radius for local supply/demand density estimation

    # Temporal & Weather Multipliers
    peak_hour_multiplier: float = 1.20  # Peak lunch / dinner surcharge
    late_night_multiplier: float = 1.30  # 23:00 to 05:00 surcharge
    rain_multiplier: float = 1.25  # Moderate rain
    heavy_storm_multiplier: float = 1.60  # Severe weather / storm

    # Platform Take-Rate
    platform_commission_pct: float = 0.20  # 20% platform take rate, 80% driver payout
    driver_min_guaranteed_payout: float = 3.00  # Minimum driver earnings per drop


@dataclass
class DeliveryQuote:
    """Detailed breakdown of a computed delivery fee quote."""
    order_id: str
    distance_km: float
    base_fee: float
    distance_fee: float
    weight_surcharge: float
    bulk_surcharge: float
    surge_multiplier: float
    surge_amount: float
    weather_multiplier: float
    time_multiplier: float
    subtotal_before_multipliers: float
    total_fee: float
    driver_payout: float
    platform_fee: float
    effective_per_km: float
    applied_surge_reason: str

    def to_dict(self) -> Dict[str, Any]:
        return {
            "order_id": self.order_id,
            "distance_km": round(self.distance_km, 2),
            "base_fee": round(self.base_fee, 2),
            "distance_fee": round(self.distance_fee, 2),
            "weight_surcharge": round(self.weight_surcharge, 2),
            "bulk_surcharge": round(self.bulk_surcharge, 2),
            "surge_multiplier": round(self.surge_multiplier, 2),
            "surge_amount": round(self.surge_amount, 2),
            "weather_multiplier": round(self.weather_multiplier, 2),
            "time_multiplier": round(self.time_multiplier, 2),
            "total_fee": round(self.total_fee, 2),
            "driver_payout": round(self.driver_payout, 2),
            "platform_fee": round(self.platform_fee, 2),
            "effective_per_km": round(self.effective_per_km, 2),
            "applied_surge_reason": self.applied_surge_reason
        }


class PricingEngine:
    """
    Production-grade dynamic pricing and delivery fee calculation engine.
    """

    def __init__(self, config: Optional[PricingConfig] = None):
        self.config = config or PricingConfig()

    def calculate_surge_multiplier(
        self,
        pickup_lat: float,
        pickup_lon: float,
        active_orders_locations: List[Tuple[float, float]],
        available_drivers_locations: List[Tuple[float, float]],
        smoothing_epsilon: float = 0.5
    ) -> Tuple[float, str]:
        """
        Calculate continuous dynamic surge pricing multiplier based on spatial
        Supply-Demand Density Imbalance within radius R.

        Mathematical Formulation:
            Demand Density: lambda = |{o in Orders | dist(pickup, o) <= R}|
            Supply Density: mu = |{d in Drivers | dist(pickup, d) <= R}|
            Imbalance Ratio: theta = (lambda + epsilon) / (mu + epsilon)

            Sigmoid Surge Function:
            S(theta) = S_min + (S_max - S_min) / (1 + exp(-k * (theta - theta_0)))
        """
        cfg = self.config
        radius = cfg.density_search_radius_km

        # Count active demand in local cluster
        local_demand = sum(
            1 for lat, lon in active_orders_locations
            if haversine_distance(pickup_lat, pickup_lon, lat, lon) <= radius
        )

        # Count available drivers in local cluster
        local_supply = sum(
            1 for lat, lon in available_drivers_locations
            if haversine_distance(pickup_lat, pickup_lon, lat, lon) <= radius
        )

        # Imbalance ratio with Laplace-style smoothing
        theta = (local_demand + smoothing_epsilon) / (local_supply + smoothing_epsilon)

        if local_supply == 0 and local_demand > 0:
            surge = cfg.surge_max
            reason = f"Extreme driver shortage ({local_demand} orders, 0 drivers in {radius}km)"
        elif theta <= 0.85:
            # High supply surplus
            surge = cfg.surge_min
            reason = f"Normal supply ({local_demand} orders vs {local_supply} drivers in {radius}km)"
        else:
            # Sigmoid transition
            exponent = -cfg.surge_k * (theta - cfg.surge_midpoint_ratio)
            # Clip exponent to avoid math overflow
            clipped_exp = max(-30.0, min(30.0, exponent))
            surge = cfg.surge_min + (cfg.surge_max - cfg.surge_min) / (1.0 + math.exp(clipped_exp))
            surge = round(max(cfg.surge_min, min(cfg.surge_max, surge)), 2)
            reason = f"Dynamic surge {surge:.2f}x (Demand/Supply ratio: {theta:.2f} in {radius}km)"

        return surge, reason

    def get_time_multiplier(self, current_time: Optional[datetime] = None) -> float:
        """
        Get time-of-day pricing multiplier (peak lunch/dinner or late night).
        """
        now = current_time or datetime.now()
        t = now.time()

        # Lunch peak: 11:30 - 13:45
        lunch_start = time(11, 30)
        lunch_end = time(13, 45)
        # Dinner peak: 18:30 - 21:15
        dinner_start = time(18, 30)
        dinner_end = time(21, 15)
        # Late night: 23:00 - 05:00
        late_night_start = time(23, 0)
        late_night_end = time(5, 0)

        if (lunch_start <= t <= lunch_end) or (dinner_start <= t <= dinner_end):
            return self.config.peak_hour_multiplier
        elif t >= late_night_start or t <= late_night_end:
            return self.config.late_night_multiplier
        return 1.0

    def get_weather_multiplier(self, weather_condition: str = "clear") -> float:
        """
        Get weather-based multiplier: 'clear', 'cloudy', 'rain', 'heavy_rain', 'storm'.
        """
        cond = weather_condition.lower().strip()
        if cond in ("heavy_rain", "storm", "snow", "thunderstorm"):
            return self.config.heavy_storm_multiplier
        elif cond in ("rain", "drizzle", "wet"):
            return self.config.rain_multiplier
        return 1.0

    def calculate_quote(
        self,
        order_id: str,
        pickup_lat: float,
        pickup_lon: float,
        dropoff_lat: float,
        dropoff_lon: float,
        weight_kg: float = 1.0,
        dimensions_cm: Optional[Tuple[float, float, float]] = None,
        active_orders_locations: Optional[List[Tuple[float, float]]] = None,
        available_drivers_locations: Optional[List[Tuple[float, float]]] = None,
        weather_condition: str = "clear",
        current_time: Optional[datetime] = None,
        is_priority: bool = False
    ) -> DeliveryQuote:
        """
        Compute transparent, fully itemized delivery fee quote.
        """
        cfg = self.config
        distance_km = road_distance_estimate(pickup_lat, pickup_lon, dropoff_lat, dropoff_lon)

        # 1. Base Distance Fee
        base_fee = cfg.base_fee
        if distance_km <= cfg.base_distance_km:
            distance_fee = 0.0
        elif distance_km <= cfg.long_distance_threshold_km:
            extra_km = distance_km - cfg.base_distance_km
            distance_fee = extra_km * cfg.per_km_rate
        else:
            # Tiered pricing for long distance
            mid_km = cfg.long_distance_threshold_km - cfg.base_distance_km
            long_km = distance_km - cfg.long_distance_threshold_km
            distance_fee = (mid_km * cfg.per_km_rate) + (long_km * cfg.per_km_rate * cfg.long_distance_rate_multiplier)

        # 2. Weight & Volumetric Surcharges
        volumetric_weight = 0.0
        bulk_surcharge = 0.0
        if dimensions_cm:
            l, w, h = dimensions_cm
            volume_cm3 = l * w * h
            volumetric_weight = volume_cm3 / cfg.volumetric_divisor
            if volume_cm3 > 40_000.0 or any(dim > 50.0 for dim in (l, w, h)):
                bulk_surcharge = cfg.bulky_item_flat_fee

        billable_weight = max(weight_kg, volumetric_weight)
        if billable_weight > cfg.free_weight_kg:
            extra_weight = billable_weight - cfg.free_weight_kg
            weight_surcharge = extra_weight * cfg.per_kg_surcharge
        else:
            weight_surcharge = 0.0

        # Subtotal of cost components before multipliers
        subtotal_cost = base_fee + distance_fee + weight_surcharge + bulk_surcharge

        # 3. Dynamic Surge Multiplier
        if active_orders_locations is not None and available_drivers_locations is not None:
            surge_mult, surge_reason = self.calculate_surge_multiplier(
                pickup_lat, pickup_lon, active_orders_locations, available_drivers_locations
            )
        else:
            surge_mult = 1.0
            surge_reason = "Base pricing (no surge data)"

        # 4. Temporal and Weather Multipliers
        weather_mult = self.get_weather_multiplier(weather_condition)
        time_mult = self.get_time_multiplier(current_time)
        priority_mult = 1.25 if is_priority else 1.0

        combined_environmental_mult = weather_mult * time_mult * priority_mult
        surge_amount = subtotal_cost * (surge_mult - 1.0)
        
        # Total Delivery Fee calculation
        total_fee = (subtotal_cost * surge_mult) * combined_environmental_mult
        total_fee = max(cfg.base_fee, round(total_fee, 2))

        # Driver Payout vs Platform Revenue
        # Driver receives 100% of the surge premium + 80% of standard fee
        driver_standard_cut = subtotal_cost * (1.0 - cfg.platform_commission_pct)
        driver_payout = max(cfg.driver_min_guaranteed_payout, (driver_standard_cut + surge_amount) * weather_mult)
        driver_payout = min(driver_payout, total_fee * 0.90)  # Platform retains at least 10%
        driver_payout = round(driver_payout, 2)
        platform_fee = round(total_fee - driver_payout, 2)

        effective_per_km = total_fee / max(0.5, distance_km)

        return DeliveryQuote(
            order_id=order_id,
            distance_km=distance_km,
            base_fee=base_fee,
            distance_fee=distance_fee,
            weight_surcharge=weight_surcharge,
            bulk_surcharge=bulk_surcharge,
            surge_multiplier=surge_mult,
            surge_amount=surge_amount,
            weather_multiplier=weather_mult,
            time_multiplier=time_mult,
            subtotal_before_multipliers=subtotal_cost,
            total_fee=total_fee,
            driver_payout=driver_payout,
            platform_fee=platform_fee,
            effective_per_km=effective_per_km,
            applied_surge_reason=surge_reason
        )
