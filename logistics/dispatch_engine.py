"""
Smart Driver Dispatch Engine for Super App Logistics.

This module implements:
1. Multi-factor Weighted Cost Matrix formulation (Road distance, JIT Prep-Time matching,
   driver rating, acceptance rate, current queue, and vehicle capability constraints).
2. Kuhn-Munkres (Hungarian Algorithm) O(N^3) Bipartite Matching optimizer (pure Python + SciPy fallback).
3. Greedy Nearest-Neighbor with Time Windows (NN-TW) heuristic.
4. Rolling Horizon Batch Dispatch Controller connecting Batched Routes to Drivers.
"""

from __future__ import annotations
import math
from dataclasses import dataclass, field
from typing import List, Dict, Tuple, Optional, Any, Set
try:
    from .pricing_engine import haversine_distance, road_distance_estimate
    from .batching_optimizer import Location, Order, BatchedRoute, BatchingOptimizer
except (ImportError, ValueError):
    from pricing_engine import haversine_distance, road_distance_estimate
    from batching_optimizer import Location, Order, BatchedRoute, BatchingOptimizer



@dataclass
class Driver:
    """Delivery driver state and capability profile."""
    driver_id: str
    name: str
    current_location: Location
    vehicle_type: str = "scooter"  # 'bike', 'scooter', 'car', 'van'
    rating: float = 4.8  # 1.0 to 5.0 scale
    acceptance_rate: float = 0.92  # 0.0 to 1.0 scale
    active_orders_count: int = 0
    current_queue_remaining_min: float = 0.0  # Estimated minutes until driver is free
    max_weight_capacity_kg: float = 20.0
    max_volume_capacity_l: float = 40.0
    average_speed_kmh: float = 25.0
    is_online: bool = True
    battery_or_fuel_pct: float = 85.0


@dataclass
class DispatchWeights:
    """Configurable weights for multi-factor dispatch objective function."""
    weight_pickup_distance: float = 1.8  # Cost per km to pickup point
    weight_driver_wait_time: float = 0.6  # Penalty per minute driver waits at store (early arrival)
    weight_food_dwell_time: float = 1.4  # Penalty per minute food sits on counter (late arrival)
    weight_active_queue: float = 3.0  # Penalty per existing active order in driver queue
    weight_rating_discount: float = 1.5  # Cost discount for top ratings: (rating - 3.0) * weight
    weight_acceptance_discount: float = 2.0  # Cost discount for high acceptance rate: rate * weight
    max_dispatch_radius_km: float = 8.0  # Hard cutoff radius for driver assignment
    infeasible_cost_penalty: float = 1e6  # Large penalty for impossible/violating matches


@dataclass
class AssignmentResult:
    """Outcome of matching a driver to an order/batch."""
    driver_id: str
    batch_id: str
    order_ids: List[str]
    pickup_distance_km: float
    driver_eta_to_pickup_min: float
    food_dwell_time_min: float
    driver_wait_time_min: float
    total_cost_score: float
    estimated_total_delivery_time_min: float
    is_batched: bool

    def summary(self) -> str:
        orders_str = ", ".join(self.order_ids)
        return (f"Driver [{self.driver_id}] -> Orders [{orders_str}] | "
                f"Pickup Dist: {self.pickup_distance_km:.2f}km | "
                f"Pickup ETA: {self.driver_eta_to_pickup_min:.1f}min | "
                f"Dwell: {self.food_dwell_time_min:.1f}min | "
                f"Wait: {self.driver_wait_time_min:.1f}min | "
                f"Cost Score: {self.total_cost_score:.2f}")


def kuhn_munkres(cost_matrix: List[List[float]]) -> List[Tuple[int, int]]:
    """
    Pure Python implementation of the Kuhn-Munkres (Hungarian) Algorithm for
    minimum-cost bipartite matching. Supports arbitrary rectangular matrices
    (M drivers x N tasks) by padding with dummy nodes.
    Complexity: O(max(M, N)^3).
    """
    if not cost_matrix or not cost_matrix[0]:
        return []

    original_rows = len(cost_matrix)
    original_cols = len(cost_matrix[0])
    n = max(original_rows, original_cols)

    # Pad matrix to n x n square with 0 or max cost for dummies
    max_val = max(max(row) for row in cost_matrix) if cost_matrix else 0.0
    dummy_cost = max_val * 2.0 + 1000.0

    square_matrix = [[0.0] * n for _ in range(n)]
    for i in range(n):
        for j in range(n):
            if i < original_rows and j < original_cols:
                square_matrix[i][j] = cost_matrix[i][j]
            else:
                square_matrix[i][j] = dummy_cost

    # Potential labeling
    u = [0.0] * (n + 1)
    v = [0.0] * (n + 1)
    p = [0] * (n + 1)
    way = [0] * (n + 1)

    for i in range(1, n + 1):
        p[0] = i
        j0 = 0
        minv = [float('inf')] * (n + 1)
        used = [False] * (n + 1)

        while True:
            used[j0] = True
            i0 = p[j0]
            delta = float('inf')
            j1 = 0

            for j in range(1, n + 1):
                if not used[j]:
                    cur = square_matrix[i0 - 1][j - 1] - u[i0] - v[j]
                    if cur < minv[j]:
                        minv[j] = cur
                        way[j] = j0
                    if minv[j] < delta:
                        delta = minv[j]
                        j1 = j

            for j in range(n + 1):
                if used[j]:
                    u[p[j]] += delta
                    v[j] -= delta
                else:
                    minv[j] -= delta

            j0 = j1
            if p[j0] == 0:
                break

        while True:
            j1 = way[j0]
            p[j0] = p[j1]
            j0 = j1
            if j0 == 0:
                break

    # Extract valid matches from 1-based indexing
    assignments = []
    for j in range(1, n + 1):
        i = p[j]
        if i > 0 and (i - 1) < original_rows and (j - 1) < original_cols:
            assignments.append((i - 1, j - 1))

    return assignments


class DispatchEngine:
    """
    Intelligent geospatial dispatching and optimization engine.
    """

    def __init__(self, weights: Optional[DispatchWeights] = None):
        self.weights = weights or DispatchWeights()
        self._has_scipy = False
        try:
            from scipy.optimize import linear_sum_assignment
            self._has_scipy = True
        except ImportError:
            self._has_scipy = False

    def compute_cost_score(
        self,
        driver: Driver,
        route: BatchedRoute,
        order_map: Dict[str, Order],
        current_time_min: float = 0.0
    ) -> Tuple[float, float, float, float]:
        """
        Calculate the multi-factor weighted dispatch cost function for a (Driver, Route) pair.

        Formulation:
        C(i, j) = w_dist * D(driver_i, first_pickup_j)
                + w_wait * max(0, ReadyTime_j - ETA_driver)   [Driver arrives before food is ready]
                + w_dwell * max(0, ETA_driver - ReadyTime_j)  [Food waits on shelf for driver]
                + w_queue * ActiveOrders_i
                - w_rating * (Rating_i - 3.0)
                - w_acc * AcceptanceRate_i
        """
        w = self.weights
        first_stop = route.stops[0]
        pickup_loc = first_stop.location

        # 1. Driver travel distance and ETA to first pickup
        pickup_distance_km = driver.current_location.distance_to(pickup_loc)

        if pickup_distance_km > w.max_dispatch_radius_km:
            return w.infeasible_cost_penalty, pickup_distance_km, 0.0, 0.0

        driver_speed_kmm = max(10.0, driver.average_speed_kmh) / 60.0
        travel_to_pickup_min = pickup_distance_km / driver_speed_kmm
        driver_eta_pickup_min = current_time_min + driver.current_queue_remaining_min + travel_to_pickup_min

        # 2. Check ready time of first pickup order
        first_order = order_map.get(first_stop.order_id)
        ready_time = first_order.ready_time_min if first_order else current_time_min

        # Dwell vs Wait analysis (Just-In-Time dispatch)
        if driver_eta_pickup_min > ready_time:
            # Driver arrives after food is cooked -> food is dwelling
            food_dwell_time = driver_eta_pickup_min - ready_time
            driver_wait_time = 0.0
        else:
            # Driver arrives before food is cooked -> driver waits at restaurant
            food_dwell_time = 0.0
            driver_wait_time = ready_time - driver_eta_pickup_min

        # 3. Capacity & Vehicle constraints
        total_batch_weight = sum(order_map[oid].weight_kg for oid in route.order_ids if oid in order_map)
        total_batch_volume = sum(order_map[oid].volume_liters for oid in route.order_ids if oid in order_map)

        if total_batch_weight > driver.max_weight_capacity_kg or total_batch_volume > driver.max_volume_capacity_l:
            return w.infeasible_cost_penalty, pickup_distance_km, food_dwell_time, driver_wait_time

        # 4. Multi-factor cost summation
        cost = (
            w.weight_pickup_distance * pickup_distance_km +
            w.weight_driver_wait_time * driver_wait_time +
            w.weight_food_dwell_time * food_dwell_time +
            w.weight_active_queue * (driver.active_orders_count + (driver.current_queue_remaining_min / 10.0)) -
            w.weight_rating_discount * max(0.0, driver.rating - 3.0) -
            w.weight_acceptance_discount * driver.acceptance_rate
        )

        return cost, pickup_distance_km, food_dwell_time, driver_wait_time

    def solve_hungarian_dispatch(
        self,
        drivers: List[Driver],
        routes: List[BatchedRoute],
        orders: List[Order],
        current_time_min: float = 0.0
    ) -> List[AssignmentResult]:
        """
        Global optimal bipartite matching using Kuhn-Munkres Hungarian algorithm.
        Constructs the MxN cost matrix and computes the global minimum-cost driver assignment.
        """
        if not drivers or not routes:
            return []

        order_map = {o.order_id: o for o in orders}
        m = len(drivers)
        n = len(routes)

        # Build cost matrix and store metrics
        cost_matrix = [[0.0] * n for _ in range(m)]
        metrics_matrix = [[(0.0, 0.0, 0.0)] * n for _ in range(m)]

        for i, driver in enumerate(drivers):
            for j, route in enumerate(routes):
                cost, p_dist, dwell, wait = self.compute_cost_score(
                    driver, route, order_map, current_time_min
                )
                cost_matrix[i][j] = cost
                metrics_matrix[i][j] = (p_dist, dwell, wait)

        # Solve matching
        if self._has_scipy:
            from scipy.optimize import linear_sum_assignment
            row_ind, col_ind = linear_sum_assignment(cost_matrix)
            pairs = list(zip(row_ind, col_ind))
        else:
            pairs = kuhn_munkres(cost_matrix)

        assignments: List[AssignmentResult] = []
        for i, j in pairs:
            if i < m and j < n:
                cost = cost_matrix[i][j]
                if cost >= self.weights.infeasible_cost_penalty:
                    # Infeasible assignment (e.g. out of range or capacity violated)
                    continue

                driver = drivers[i]
                route = routes[j]
                p_dist, dwell, wait = metrics_matrix[i][j]

                speed_kmm = max(10.0, driver.average_speed_kmh) / 60.0
                driver_eta_pickup = current_time_min + driver.current_queue_remaining_min + (p_dist / speed_kmm)
                total_completion_time = driver_eta_pickup + route.total_duration_min

                assignment = AssignmentResult(
                    driver_id=driver.driver_id,
                    batch_id=route.batch_id,
                    order_ids=route.order_ids,
                    pickup_distance_km=p_dist,
                    driver_eta_to_pickup_min=driver_eta_pickup,
                    food_dwell_time_min=dwell,
                    driver_wait_time_min=wait,
                    total_cost_score=cost,
                    estimated_total_delivery_time_min=total_completion_time,
                    is_batched=len(route.order_ids) > 1
                )
                assignments.append(assignment)

        return assignments

    def solve_greedy_nearest_neighbor(
        self,
        drivers: List[Driver],
        routes: List[BatchedRoute],
        orders: List[Order],
        current_time_min: float = 0.0
    ) -> List[AssignmentResult]:
        """
        Greedy Nearest-Neighbor heuristic with Time Windows (NN-TW).
        Iteratively assigns the lowest available cost pair.
        """
        if not drivers or not routes:
            return []

        order_map = {o.order_id: o for o in orders}
        available_driver_indices = set(range(len(drivers)))
        unassigned_route_indices = set(range(len(routes)))
        assignments: List[AssignmentResult] = []

        # Sort routes by urgency (earliest customer SLA)
        route_urgency = []
        for j, route in enumerate(routes):
            min_sla = min(order_map[oid].promised_delivery_time_min for oid in route.order_ids if oid in order_map)
            route_urgency.append((min_sla, j))
        route_urgency.sort(key=lambda x: x[0])

        for _, j in route_urgency:
            if not available_driver_indices:
                break
            route = routes[j]

            best_i = None
            best_cost = float('inf')
            best_metrics = (0.0, 0.0, 0.0)

            for i in available_driver_indices:
                driver = drivers[i]
                cost, p_dist, dwell, wait = self.compute_cost_score(
                    driver, route, order_map, current_time_min
                )
                if cost < best_cost and cost < self.weights.infeasible_cost_penalty:
                    best_cost = cost
                    best_i = i
                    best_metrics = (p_dist, dwell, wait)

            if best_i is not None:
                available_driver_indices.remove(best_i)
                driver = drivers[best_i]
                p_dist, dwell, wait = best_metrics
                speed_kmm = max(10.0, driver.average_speed_kmh) / 60.0
                driver_eta_pickup = current_time_min + driver.current_queue_remaining_min + (p_dist / speed_kmm)
                total_completion_time = driver_eta_pickup + route.total_duration_min

                assignment = AssignmentResult(
                    driver_id=driver.driver_id,
                    batch_id=route.batch_id,
                    order_ids=route.order_ids,
                    pickup_distance_km=p_dist,
                    driver_eta_to_pickup_min=driver_eta_pickup,
                    food_dwell_time_min=dwell,
                    driver_wait_time_min=wait,
                    total_cost_score=best_cost,
                    estimated_total_delivery_time_min=total_completion_time,
                    is_batched=len(route.order_ids) > 1
                )
                assignments.append(assignment)

        return assignments

    def run_full_dispatch_pipeline(
        self,
        drivers: List[Driver],
        orders: List[Order],
        batching_optimizer: Optional[BatchingOptimizer] = None,
        use_hungarian: bool = True,
        current_time_min: float = 0.0
    ) -> Tuple[List[AssignmentResult], List[BatchedRoute]]:
        """
        Complete end-to-end dispatch pipeline:
        1. Cluster & batch compatible incoming orders
        2. Assign drivers to batched and solo routes using Kuhn-Munkres or NN-TW
        """
        optimizer = batching_optimizer or BatchingOptimizer()
        routes = optimizer.optimize_batches(orders)

        if use_hungarian:
            assignments = self.solve_hungarian_dispatch(drivers, routes, orders, current_time_min)
        else:
            assignments = self.solve_greedy_nearest_neighbor(drivers, routes, orders, current_time_min)

        return assignments, routes
