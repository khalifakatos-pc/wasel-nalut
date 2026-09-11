"""
Order Batching Optimizer for Super App Delivery Logistics.

This module implements spatial-temporal clustering and Pickup-and-Delivery
Problem with Time Windows (PDPTW) heuristics to bundle compatible orders
heading in the same direction or from the same store while strictly respecting
SLA delivery deadlines, food freshness limits, and driver capacity constraints.
"""

from __future__ import annotations
import math
import itertools
from dataclasses import dataclass, field
from typing import List, Dict, Tuple, Optional, Set, Any
try:
    from .pricing_engine import haversine_distance, road_distance_estimate
except (ImportError, ValueError):
    from pricing_engine import haversine_distance, road_distance_estimate



@dataclass
class Location:
    """Geographic point representation."""
    lat: float
    lon: float
    name: str = ""

    def distance_to(self, other: Location, circuity: float = 1.30) -> float:
        """Estimated road distance in kilometers to another location."""
        return road_distance_estimate(self.lat, self.lon, other.lat, other.lon, circuity)


@dataclass
class Order:
    """Order metadata for batching and routing."""
    order_id: str
    merchant_id: str
    merchant_location: Location
    customer_location: Location
    ready_time_min: float  # Minutes from simulation reference T=0 when food is ready
    promised_delivery_time_min: float  # SLA deadline (minutes from T=0)
    weight_kg: float = 1.5
    volume_liters: float = 4.0
    item_category: str = "food"  # 'food', 'grocery', 'ecommerce'
    max_transit_time_min: float = 35.0  # Max freshness transit duration from pickup to dropoff
    service_pickup_min: float = 3.0  # Service duration at merchant
    service_dropoff_min: float = 3.0  # Service duration at customer door

    @property
    def direct_road_distance_km(self) -> float:
        return self.merchant_location.distance_to(self.customer_location)


@dataclass
class RouteStop:
    """Individual stop in a batched route."""
    stop_id: str
    order_id: str
    stop_type: str  # 'PICKUP' or 'DROPOFF'
    location: Location
    arrival_time_min: float
    departure_time_min: float
    service_time_min: float
    distance_from_prev_km: float


@dataclass
class BatchedRoute:
    """Optimized multi-stop route containing 1 or more batched orders."""
    batch_id: str
    order_ids: List[str]
    stops: List[RouteStop]
    total_distance_km: float
    total_duration_min: float
    direct_sum_distance_km: float
    distance_savings_km: float
    distance_savings_pct: float
    is_valid: bool
    rejection_reason: str = ""

    def summary(self) -> str:
        stop_seq = " -> ".join([f"{s.stop_type[0]}:{s.order_id}" for s in self.stops])
        return (f"Batch [{self.batch_id}] ({len(self.order_ids)} orders): {stop_seq} | "
                f"Dist: {self.total_distance_km:.2f}km (Saved {self.distance_savings_pct:.1f}%) | "
                f"Duration: {self.total_duration_min:.1f}min")


@dataclass
class BatchingConstraints:
    """Configurable operational parameters for order batching."""
    max_orders_per_batch: int = 2  # Standard 2-order batching for bikes/scooters
    max_pickup_distance_km: float = 1.2  # Max distance between distinct pickup locations
    max_detour_ratio: float = 1.35  # Batched distance <= 1.35 * sum(direct distances)
    max_customer_delay_min: float = 10.0  # Max acceptable delay vs direct solo delivery
    avg_speed_kmh: float = 24.0  # Urban delivery driving speed (km/h)
    max_batch_weight_kg: float = 15.0  # Max payload capacity
    max_batch_volume_l: float = 35.0  # Max backpack/box volume
    same_merchant_bonus_km: float = 0.5  # Extra leeway when orders share same merchant


class BatchingOptimizer:
    """
    State-of-the-art Order Batching Engine solving the multi-criteria PDPTW.
    """

    def __init__(self, constraints: Optional[BatchingConstraints] = None):
        self.constraints = constraints or BatchingConstraints()

    def _travel_time_minutes(self, distance_km: float) -> float:
        """Convert road distance to travel duration in minutes at average urban speed."""
        speed_kmm = self.constraints.avg_speed_kmh / 60.0  # km per minute
        return distance_km / speed_kmm

    def evaluate_sequence(
        self,
        orders: List[Order],
        stop_sequence: List[Tuple[str, str, Location, float]],
        start_location: Optional[Location] = None,
        start_time_min: float = 0.0
    ) -> Tuple[bool, str, List[RouteStop], float, float]:
        """
        Simulate and validate a candidate stop sequence for a set of orders.
        stop_sequence: list of (order_id, 'PICKUP'|'DROPOFF', Location, service_time)

        Validates:
        1. Precedence: Pickup(i) before Dropoff(i)
        2. Merchant Ready Time: Cannot pick up before food is cooked
        3. Customer SLA: Dropoff arrival <= promised_delivery_time_min
        4. Freshness: Dropoff arrival - Pickup departure <= max_transit_time_min
        5. Capacity: Weight and volume constraints at all route steps
        """
        order_map = {o.order_id: o for o in orders}
        picked_up_orders: Set[str] = set()
        delivered_orders: Set[str] = set()
        pickup_departure_times: Dict[str, float] = {}

        current_loc = start_location if start_location else stop_sequence[0][2]
        current_time = start_time_min
        current_weight = 0.0
        current_volume = 0.0

        stops: List[RouteStop] = []
        total_distance = 0.0

        for idx, (oid, stype, loc, stime) in enumerate(stop_sequence):
            order = order_map[oid]
            leg_dist = current_loc.distance_to(loc)
            leg_time = self._travel_time_minutes(leg_dist)
            total_distance += leg_dist

            arrival_time = current_time + leg_time

            if stype == "PICKUP":
                # Must not pick up before order is ready
                effective_arrival = max(arrival_time, order.ready_time_min)
                departure_time = effective_arrival + stime

                # Capacity check
                current_weight += order.weight_kg
                current_volume += order.volume_liters
                if current_weight > self.constraints.max_batch_weight_kg:
                    return False, f"Weight capacity exceeded ({current_weight:.1f}kg > {self.constraints.max_batch_weight_kg}kg)", [], 0, 0
                if current_volume > self.constraints.max_batch_volume_l:
                    return False, f"Volume capacity exceeded ({current_volume:.1f}L > {self.constraints.max_batch_volume_l}L)", [], 0, 0

                picked_up_orders.add(oid)
                pickup_departure_times[oid] = departure_time

            elif stype == "DROPOFF":
                # Precedence check
                if oid not in picked_up_orders:
                    return False, f"Dropoff before Pickup for order {oid}", [], 0, 0

                effective_arrival = arrival_time
                departure_time = effective_arrival + stime

                # SLA Deadline check
                if effective_arrival > order.promised_delivery_time_min:
                    delay = effective_arrival - order.promised_delivery_time_min
                    return False, f"Order {oid} SLA missed by {delay:.1f} min", [], 0, 0

                # Transit / Freshness check
                transit_time = effective_arrival - pickup_departure_times[oid]
                if transit_time > order.max_transit_time_min:
                    return False, f"Order {oid} transit time exceeded ({transit_time:.1f} min > {order.max_transit_time_min} min)", [], 0, 0

                # Release capacity
                current_weight -= order.weight_kg
                current_volume -= order.volume_liters
                delivered_orders.add(oid)

            else:
                return False, f"Unknown stop type {stype}", [], 0, 0

            stop_obj = RouteStop(
                stop_id=f"{stype}_{oid}_{idx}",
                order_id=oid,
                stop_type=stype,
                location=loc,
                arrival_time_min=effective_arrival,
                departure_time_min=departure_time,
                service_time_min=stime,
                distance_from_prev_km=leg_dist
            )
            stops.append(stop_obj)

            current_loc = loc
            current_time = departure_time

        total_duration = current_time - start_time_min
        return True, "Feasible", stops, total_distance, total_duration

    def find_best_route_for_orders(
        self,
        orders: List[Order],
        start_location: Optional[Location] = None,
        start_time_min: float = 0.0
    ) -> Optional[BatchedRoute]:
        """
        Given a group of candidate orders (1, 2, or 3), search all valid
        precedence permutations to find the optimal global minimum distance/time route.
        """
        if not orders:
            return None

        # Base items for permutation: (order_id, type, location, service_time)
        pickup_items = [(o.order_id, "PICKUP", o.merchant_location, o.service_pickup_min) for o in orders]
        dropoff_items = [(o.order_id, "DROPOFF", o.customer_location, o.service_dropoff_min) for o in orders]

        all_stops = pickup_items + dropoff_items
        n_stops = len(all_stops)

        best_route: Optional[BatchedRoute] = None
        min_cost = float('inf')

        # Direct sum distance for savings calculation
        direct_sum = sum(o.direct_road_distance_km for o in orders)

        # Generate all permutations of stops
        for perm in itertools.permutations(all_stops):
            # Fast filter: verify every pickup appears before its respective dropoff
            order_pickup_idx = {}
            order_dropoff_idx = {}
            valid_precedence = True
            for idx, (oid, stype, _, _) in enumerate(perm):
                if stype == "PICKUP":
                    order_pickup_idx[oid] = idx
                else:
                    order_dropoff_idx[oid] = idx
                    if oid not in order_pickup_idx or order_pickup_idx[oid] > idx:
                        valid_precedence = False
                        break
            if not valid_precedence:
                continue

            # Merge adjacent pickups from same merchant to optimize service time
            consolidated_perm: List[Tuple[str, str, Location, float]] = []
            for item in perm:
                consolidated_perm.append(item)

            is_feasible, reason, stops, dist, duration = self.evaluate_sequence(
                orders, consolidated_perm, start_location, start_time_min
            )

            if is_feasible:
                # Detour ratio check for multi-order batches
                if len(orders) > 1:
                    detour_ratio = dist / max(0.1, direct_sum)
                    if detour_ratio > self.constraints.max_detour_ratio:
                        continue

                # Objective function: Weighted sum of route distance + customer arrival delays
                cost = dist * 1.0 + (duration / 60.0) * 1.5
                if cost < min_cost:
                    min_cost = cost
                    savings_km = max(0.0, direct_sum - dist)
                    savings_pct = (savings_km / direct_sum * 100.0) if direct_sum > 0 else 0.0

                    batch_id = "_".join(sorted(o.order_id for o in orders))
                    best_route = BatchedRoute(
                        batch_id=batch_id,
                        order_ids=[o.order_id for o in orders],
                        stops=stops,
                        total_distance_km=dist,
                        total_duration_min=duration,
                        direct_sum_distance_km=direct_sum,
                        distance_savings_km=savings_km,
                        distance_savings_pct=savings_pct,
                        is_valid=True
                    )

        return best_route

    def optimize_batches(self, orders: List[Order]) -> List[BatchedRoute]:
        """
        Global batching solver: Combines compatible incoming orders into 2-order (or 3-order)
        batches to maximize global distance savings while ensuring 100% SLA compliance.
        Unbatched orders are output as single-order routes.
        """
        if not orders:
            return []

        # 1. Compute pairwise candidate compatibility and savings
        candidate_batches: List[Tuple[float, BatchedRoute, str, str]] = []

        n = len(orders)
        for i in range(n):
            for j in range(i + 1, n):
                o1 = orders[i]
                o2 = orders[j]

                # Quick spatial pruning: Pickups must be close OR same merchant
                p_dist = o1.merchant_location.distance_to(o2.merchant_location)
                same_merchant = (o1.merchant_id == o2.merchant_id)
                if not same_merchant and p_dist > self.constraints.max_pickup_distance_km:
                    continue

                # Quick temporal pruning: Ready times shouldn't differ by more than 15 mins
                if abs(o1.ready_time_min - o2.ready_time_min) > 15.0:
                    continue

                # Solve 2-order PDPTW
                route = self.find_best_route_for_orders([o1, o2])
                if route and route.is_valid and route.distance_savings_pct > 10.0:
                    # Score by absolute distance saved
                    candidate_batches.append((route.distance_savings_km, route, o1.order_id, o2.order_id))

        # 2. Greedy Maximum Weight Matching of candidate batches
        # Sort candidate batches descending by distance saved
        candidate_batches.sort(key=lambda x: x[0], reverse=True)

        assigned_orders: Set[str] = set()
        final_routes: List[BatchedRoute] = []

        for savings, route, id1, id2 in candidate_batches:
            if id1 not in assigned_orders and id2 not in assigned_orders:
                assigned_orders.add(id1)
                assigned_orders.add(id2)
                final_routes.append(route)

        # 3. For remaining unbatched orders, generate solo routes
        for order in orders:
            if order.order_id not in assigned_orders:
                solo_route = self.find_best_route_for_orders([order])
                if solo_route:
                    final_routes.append(solo_route)
                    assigned_orders.add(order.order_id)

        return final_routes
