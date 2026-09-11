"""
End-to-End Simulation & Benchmark for Super App Logistics Engine.

Demonstrates:
- 10 active drivers with distinct vehicle types, ratings, and locations
- 20 incoming multi-category orders (Food, Grocery, E-Commerce, Pharma)
- Real-time dynamic surge pricing based on spatial density imbalance
- Multi-order batching with PDPTW sequence optimization
- Kuhn-Munkres (Hungarian) optimal driver dispatch vs Greedy Baseline
- Complete ETA timeline, food freshness/dwell analysis, and financial KPIs
"""

from __future__ import annotations
import math
import os
import sys
import random
import time
from datetime import datetime, time as dtime
from typing import List, Dict, Tuple

# Ensure package and parent directory are accessible in sys.path
_current_dir = os.path.dirname(os.path.abspath(__file__))
_parent_dir = os.path.dirname(_current_dir)
if _current_dir not in sys.path:
    sys.path.insert(0, _current_dir)
if _parent_dir not in sys.path:
    sys.path.insert(0, _parent_dir)

try:
    from logistics.pricing_engine import (
        PricingEngine,
        PricingConfig,
        DeliveryQuote,
        haversine_distance,
        road_distance_estimate,
    )
    from logistics.batching_optimizer import (
        BatchingOptimizer,
        BatchingConstraints,
        Order,
        Location,
        RouteStop,
        BatchedRoute,
    )
    from logistics.dispatch_engine import (
        DispatchEngine,
        DispatchWeights,
        Driver,
        AssignmentResult,
    )
except (ImportError, ValueError):
    from pricing_engine import (
        PricingEngine,
        PricingConfig,
        DeliveryQuote,
        haversine_distance,
        road_distance_estimate,
    )
    from batching_optimizer import (
        BatchingOptimizer,
        BatchingConstraints,
        Order,
        Location,
        RouteStop,
        BatchedRoute,
    )
    from dispatch_engine import (
        DispatchEngine,
        DispatchWeights,
        Driver,
        AssignmentResult,
    )



def create_simulation_environment() -> Tuple[List[Driver], List[Order], Dict[str, Location]]:
    """Generate realistic simulation scenario in a metropolitan core."""
    # Downtown Core reference: Lat 25.2000, Lon 55.2700 (Dubai Downtown / Business Bay)
    merchants = {
        "M1_BURGER": Location(25.2048, 55.2708, "Gourmet Burger Hub (Downtown)"),
        "M2_SUSHI": Location(25.2085, 55.2755, "Tokyo Sushi Lounge (DIFC)"),
        "M3_PIZZA": Location(25.1980, 55.2730, "Bella Napoli Pizzeria (Business Bay)"),
        "M4_GROCERY": Location(25.2120, 55.2680, "Organic Hypermarket (City Walk)"),
        "M5_PHARMA": Location(25.2010, 55.2810, "Express Pharmacy 24/7 (Trade Center)"),
        "M6_TECH": Location(25.2150, 55.2820, "Tech & Gadgets Express (Karama Hub)"),
    }

    # 10 Drivers distributed across the delivery zones
    drivers = [
        Driver("DRV-01", "Tariq Al-Mansoor", Location(25.2030, 55.2690), "scooter", 4.95, 0.98, 0, 0.0, 20.0, 45.0, 26.0),
        Driver("DRV-02", "Elena Rostova",   Location(25.2070, 55.2740), "bike",    4.85, 0.92, 0, 0.0, 15.0, 30.0, 20.0),
        Driver("DRV-03", "Marcus Vance",    Location(25.2140, 55.2660), "car",     4.75, 0.88, 0, 0.0, 60.0, 120.0, 30.0),
        Driver("DRV-04", "Aisha Al-Hashimi", Location(25.1970, 55.2715), "scooter", 4.92, 0.96, 0, 0.0, 20.0, 45.0, 25.0),
        Driver("DRV-05", "Carlos Mendez",   Location(25.2180, 55.2800), "car",     4.65, 0.82, 0, 0.0, 60.0, 120.0, 28.0),
        Driver("DRV-06", "Fatima Zahra",    Location(25.2005, 55.2785), "scooter", 4.88, 0.94, 0, 0.0, 20.0, 45.0, 26.0),
        Driver("DRV-07", "David Kim",       Location(25.2100, 55.2710), "bike",    4.70, 0.85, 0, 0.0, 15.0, 30.0, 22.0),
        Driver("DRV-08", "Sara Nilsson",    Location(25.2060, 55.2790), "scooter", 4.90, 0.97, 0, 0.0, 20.0, 45.0, 27.0),
        Driver("DRV-09", "Omar Siddiqui",   Location(25.1950, 55.2680), "car",     4.78, 0.90, 0, 0.0, 60.0, 120.0, 29.0),
        Driver("DRV-10", "Jin Woo",         Location(25.2090, 55.2830), "scooter", 4.82, 0.91, 0, 0.0, 20.0, 45.0, 25.0),
    ]

    # 20 Incoming Orders with realistic spatial clustering to demonstrate batching & pricing
    orders = [
        # Cluster 1: Downtown / Business Bay Food Delivery (Compatible for batching)
        Order("ORD-101", "M1_BURGER", merchants["M1_BURGER"], Location(25.1930, 55.2760, "Burj Crown Tower"), ready_time_min=8.0, promised_delivery_time_min=40.0, weight_kg=1.8, volume_liters=4.0, item_category="food"),
        Order("ORD-102", "M1_BURGER", merchants["M1_BURGER"], Location(25.1915, 55.2780, "South Ridge Apts"), ready_time_min=10.0, promised_delivery_time_min=42.0, weight_kg=2.2, volume_liters=5.0, item_category="food"),

        # Cluster 2: DIFC Sushi (Compatible for batching)
        Order("ORD-103", "M2_SUSHI", merchants["M2_SUSHI"], Location(25.2110, 55.2810, "Index Tower DIFC"), ready_time_min=12.0, promised_delivery_time_min=45.0, weight_kg=1.2, volume_liters=3.0, item_category="food"),
        Order("ORD-104", "M2_SUSHI", merchants["M2_SUSHI"], Location(25.2135, 55.2840, "Sky Gardens DIFC"), ready_time_min=14.0, promised_delivery_time_min=45.0, weight_kg=1.5, volume_liters=3.5, item_category="food"),

        # Cluster 3: Pizza Delivery (Same merchant, nearby drops)
        Order("ORD-105", "M3_PIZZA", merchants["M3_PIZZA"], Location(25.1900, 55.2690, "Executive Towers"), ready_time_min=9.0, promised_delivery_time_min=38.0, weight_kg=2.5, volume_liters=8.0, item_category="food"),
        Order("ORD-106", "M3_PIZZA", merchants["M3_PIZZA"], Location(25.1880, 55.2670, "Bay Square Bldg 4"), ready_time_min=11.0, promised_delivery_time_min=40.0, weight_kg=1.9, volume_liters=6.0, item_category="food"),

        # Cluster 4: Organic Grocery Supermarket (Heavy orders)
        Order("ORD-107", "M4_GROCERY", merchants["M4_GROCERY"], Location(25.2200, 55.2610, "Jumeirah 1 Villa"), ready_time_min=5.0, promised_delivery_time_min=50.0, weight_kg=8.5, volume_liters=18.0, item_category="grocery"),
        Order("ORD-108", "M4_GROCERY", merchants["M4_GROCERY"], Location(25.2230, 55.2590, "Jumeirah Beach Residence"), ready_time_min=6.0, promised_delivery_time_min=55.0, weight_kg=6.0, volume_liters=14.0, item_category="grocery"),

        # Cluster 5: Urgent Pharmacy (Express SLAs)
        Order("ORD-109", "M5_PHARMA", merchants["M5_PHARMA"], Location(25.1990, 55.2890, "Emirates Towers"), ready_time_min=3.0, promised_delivery_time_min=25.0, weight_kg=0.5, volume_liters=1.0, item_category="pharma"),
        Order("ORD-110", "M5_PHARMA", merchants["M5_PHARMA"], Location(25.2035, 55.2870, "DIFC Gate Village"), ready_time_min=4.0, promised_delivery_time_min=28.0, weight_kg=0.8, volume_liters=1.5, item_category="pharma"),

        # Cluster 6: Tech E-Commerce (Higher volumetric & weight)
        Order("ORD-111", "M6_TECH", merchants["M6_TECH"], Location(25.2280, 55.2950, "Al Raffa Residence"), ready_time_min=7.0, promised_delivery_time_min=60.0, weight_kg=4.5, volume_liters=12.0, item_category="ecommerce"),
        Order("ORD-112", "M6_TECH", merchants["M6_TECH"], Location(25.2310, 55.2980, "Mankhool Heights"), ready_time_min=8.0, promised_delivery_time_min=60.0, weight_kg=5.2, volume_liters=15.0, item_category="ecommerce"),

        # Cross-Merchant Nearby Pickups (Burger + Pizza in Business Bay/Downtown)
        Order("ORD-113", "M1_BURGER", merchants["M1_BURGER"], Location(25.1960, 55.2740, "The Address Downtown"), ready_time_min=10.0, promised_delivery_time_min=42.0, weight_kg=1.4, volume_liters=3.0, item_category="food"),
        Order("ORD-114", "M3_PIZZA",  merchants["M3_PIZZA"],  Location(25.1945, 55.2725, "Vida Downtown"), ready_time_min=11.0, promised_delivery_time_min=43.0, weight_kg=1.8, volume_liters=5.0, item_category="food"),

        # Solo / Long-Distance Orders
        Order("ORD-115", "M2_SUSHI", merchants["M2_SUSHI"], Location(25.1650, 55.2350, "Al Wasl Road Villa"), ready_time_min=15.0, promised_delivery_time_min=50.0, weight_kg=2.0, volume_liters=4.0, item_category="food"),
        Order("ORD-116", "M4_GROCERY", merchants["M4_GROCERY"], Location(25.1780, 55.2450, "Al Safa 2"), ready_time_min=7.0, promised_delivery_time_min=55.0, weight_kg=7.0, volume_liters=16.0, item_category="grocery"),
        Order("ORD-117", "M1_BURGER", merchants["M1_BURGER"], Location(25.2400, 55.3050, "Deira City Centre Area"), ready_time_min=12.0, promised_delivery_time_min=55.0, weight_kg=1.6, volume_liters=3.5, item_category="food"),
        Order("ORD-118", "M5_PHARMA", merchants["M5_PHARMA"], Location(25.1820, 55.2600, "Business Bay Waterfront"), ready_time_min=5.0, promised_delivery_time_min=30.0, weight_kg=0.9, volume_liters=1.2, item_category="pharma"),
        Order("ORD-119", "M6_TECH", merchants["M6_TECH"], Location(25.2050, 55.2600, "City Walk Residential B2"), ready_time_min=10.0, promised_delivery_time_min=55.0, weight_kg=3.8, volume_liters=9.0, item_category="ecommerce"),
        Order("ORD-120", "M3_PIZZA", merchants["M3_PIZZA"], Location(25.2180, 55.2720, "Satwa Plaza"), ready_time_min=13.0, promised_delivery_time_min=45.0, weight_kg=2.1, volume_liters=6.0, item_category="food"),
    ]

    return drivers, orders, merchants


def run_simulation():
    """Execute complete end-to-end logistics optimization simulation."""
    print("=" * 100)
    print("SUPER APP LOGISTICS ENGINE: END-TO-END BENCHMARK SIMULATION")
    print("=" * 100)

    drivers, orders, merchants = create_simulation_environment()

    # Extract spatial coordinates for density calculations
    order_pickup_locs = [(o.merchant_location.lat, o.merchant_location.lon) for o in orders]
    driver_locs = [(d.current_location.lat, d.current_location.lon) for d in drivers]

    # Initialize engines
    pricing_engine = PricingEngine(PricingConfig(
        base_fee=2.50,
        per_km_rate=0.85,
        free_weight_kg=3.0,
        per_kg_surcharge=0.50,
        surge_max=2.8,
        peak_hour_multiplier=1.20
    ))
    batch_optimizer = BatchingOptimizer(BatchingConstraints(
        max_orders_per_batch=2,
        max_pickup_distance_km=1.2,
        max_detour_ratio=1.35,
        avg_speed_kmh=24.0
    ))
    dispatch_engine = DispatchEngine(DispatchWeights(
        weight_pickup_distance=1.8,
        weight_driver_wait_time=0.6,
        weight_food_dwell_time=1.5,
        weight_active_queue=3.0,
        weight_rating_discount=1.5,
        weight_acceptance_discount=2.0
    ))

    # =========================================================================
    # PHASE 1: REAL-TIME DYNAMIC PRICING CALCULATION
    # =========================================================================
    print("\n[PHASE 1] REAL-TIME DYNAMIC PRICING & SURGE ENGINE")
    print("-" * 100)
    print(f"{'Order ID':<9} | {'Category':<10} | {'Dist (km)':<9} | {'Base+Dist':<9} | {'Weight S/C':<10} | {'Surge':<7} | {'Total Fee':<10} | {'Driver Payout':<13} | {'Platform Take'}")
    print("-" * 100)

    quotes: Dict[str, DeliveryQuote] = {}
    total_gmv = 0.0
    total_driver_payout = 0.0
    total_platform_rev = 0.0

    simulation_time = datetime(2026, 8, 24, 12, 30)  # Peak lunch hour (12:30 PM)

    for order in orders:
        quote = pricing_engine.calculate_quote(
            order_id=order.order_id,
            pickup_lat=order.merchant_location.lat,
            pickup_lon=order.merchant_location.lon,
            dropoff_lat=order.customer_location.lat,
            dropoff_lon=order.customer_location.lon,
            weight_kg=order.weight_kg,
            active_orders_locations=order_pickup_locs,
            available_drivers_locations=driver_locs,
            weather_condition="clear",
            current_time=simulation_time
        )
        quotes[order.order_id] = quote
        total_gmv += quote.total_fee
        total_driver_payout += quote.driver_payout
        total_platform_rev += quote.platform_fee

        base_and_dist = quote.base_fee + quote.distance_fee
        print(f"{quote.order_id:<9} | {order.item_category:<10} | {quote.distance_km:>7.2f}km | "
              f"${base_and_dist:>7.2f} | ${quote.weight_surcharge:>8.2f} | {quote.surge_multiplier:>5.2f}x | "
              f"${quote.total_fee:>8.2f} | ${quote.driver_payout:>11.2f} | ${quote.platform_fee:>7.2f}")

    print("-" * 100)
    print(f"Total GMV: ${total_gmv:.2f} | Total Driver Payout: ${total_driver_payout:.2f} | Platform Revenue: ${total_platform_rev:.2f} (Take Rate: {(total_platform_rev/total_gmv)*100:.1f}%)")

    # =========================================================================
    # PHASE 2: ORDER BATCHING OPTIMIZATION
    # =========================================================================
    print("\n\n[PHASE 2] ORDER BATCHING & MULTI-STOP ROUTE OPTIMIZATION")
    print("-" * 100)
    
    start_batch_time = time.perf_counter()
    optimized_routes = batch_optimizer.optimize_batches(orders)
    batch_runtime_ms = (time.perf_counter() - start_batch_time) * 1000.0

    solo_distance_sum = sum(o.direct_road_distance_km for o in orders)
    batched_distance_sum = sum(r.total_distance_km for r in optimized_routes)
    total_km_saved = solo_distance_sum - batched_distance_sum
    pct_km_saved = (total_km_saved / solo_distance_sum) * 100.0

    print(f"Incoming Orders: {len(orders)} -> Formed Routes: {len(optimized_routes)} (Solver Runtime: {batch_runtime_ms:.2f}ms)")
    print(f"Total Direct Distance: {solo_distance_sum:.2f} km -> Batched Route Distance: {batched_distance_sum:.2f} km")
    print(f"Total Road Distance Saved: {total_km_saved:.2f} km ({pct_km_saved:.1f}% saving)")
    print("-" * 100)

    for idx, route in enumerate(optimized_routes, 1):
        batch_type = "BATCHED (2 Orders)" if len(route.order_ids) > 1 else "SOLO (1 Order)"
        stop_desc = " -> ".join([f"[{s.stop_type[0]}:{s.order_id}]" for s in route.stops])
        print(f"Route #{idx:02d} [{batch_type:<18}] {stop_desc:<40} | Dist: {route.total_distance_km:>5.2f}km | Duration: {route.total_duration_min:>4.1f}min | Saved: {route.distance_savings_pct:>4.1f}%")

    # =========================================================================
    # PHASE 3: DRIVER DISPATCH & KUHN-MUNKRES MATCHING
    # =========================================================================
    print("\n\n[PHASE 3] SMART DRIVER DISPATCH OPTIMIZATION (HUNGARIAN vs GREEDY)")
    print("-" * 100)

    start_hungarian_time = time.perf_counter()
    hungarian_assignments = dispatch_engine.solve_hungarian_dispatch(
        drivers=drivers,
        routes=optimized_routes,
        orders=orders,
        current_time_min=0.0
    )
    hungarian_runtime_ms = (time.perf_counter() - start_hungarian_time) * 1000.0

    greedy_assignments = dispatch_engine.solve_greedy_nearest_neighbor(
        drivers=drivers,
        routes=optimized_routes,
        orders=orders,
        current_time_min=0.0
    )

    hungarian_total_cost = sum(a.total_cost_score for a in hungarian_assignments)
    greedy_total_cost = sum(a.total_cost_score for a in greedy_assignments)
    cost_improvement_pct = ((greedy_total_cost - hungarian_total_cost) / max(1.0, greedy_total_cost)) * 100.0

    print(f"Hungarian Algorithm Total Cost: {hungarian_total_cost:.2f} (Runtime: {hungarian_runtime_ms:.2f}ms)")
    print(f"Greedy NN-TW Algorithm Total Cost: {greedy_total_cost:.2f}")
    print(f"Hungarian Optimization Gain: {cost_improvement_pct:.1f}% cost reduction over greedy heuristic")
    print("-" * 100)
    print(f"{'Driver':<8} | {'Driver Name':<18} | {'Vehicle':<7} | {'Assigned Route/Orders':<24} | {'Pickup Dist':<11} | {'Pickup ETA':<10} | {'Dwell Time':<10} | {'Cost Score'}")
    print("-" * 100)

    driver_dict = {d.driver_id: d for d in drivers}
    for assign in hungarian_assignments:
        drv = driver_dict[assign.driver_id]
        orders_repr = "+".join(assign.order_ids)
        print(f"{assign.driver_id:<8} | {drv.name:<18} | {drv.vehicle_type:<7} | {orders_repr:<24} | "
              f"{assign.pickup_distance_km:>8.2f}km | {assign.driver_eta_to_pickup_min:>7.1f} min | "
              f"{assign.food_dwell_time_min:>7.1f} min | {assign.total_cost_score:>9.2f}")

    # =========================================================================
    # PHASE 4: DETAILED EXECUTION TIMELINE & ETA VALIDATION
    # =========================================================================
    print("\n\n[PHASE 4] CHRONOLOGICAL DISPATCH TIMELINE & SLA COMPLIANCE")
    print("-" * 100)

    sla_violations = 0
    route_map = {r.batch_id: r for r in optimized_routes}
    order_map = {o.order_id: o for o in orders}

    for assign in hungarian_assignments:
        drv = driver_dict[assign.driver_id]
        route = route_map[assign.batch_id]
        print(f"\n[DRIVER {drv.driver_id} - {drv.name} ({drv.vehicle_type.upper()}) | Rating: {drv.rating}* | Acc: {drv.acceptance_rate*100:.0f}%]")
        print(f"  + T=0.0m : Dispatched -> Heading to {route.stops[0].location.name} (Dist: {assign.pickup_distance_km:.2f}km)")

        current_clock = assign.driver_eta_to_pickup_min

        for s_idx, stop in enumerate(route.stops):
            order = order_map[stop.order_id]
            if s_idx > 0:
                current_clock += stop.distance_from_prev_km / (drv.average_speed_kmh / 60.0)

            if stop.stop_type == "PICKUP":
                ready_status = f"Ready @ T={order.ready_time_min:.1f}m"
                if current_clock < order.ready_time_min:
                    dwell_desc = f"(Driver waits {order.ready_time_min - current_clock:.1f}m for cooking)"
                    current_clock = order.ready_time_min
                else:
                    dwell_desc = f"(Food ready for {current_clock - order.ready_time_min:.1f}m)"
                current_clock += stop.service_time_min
                print(f"  * T={current_clock:>4.1f}m : PICKUP Order {order.order_id} at {stop.location.name} {ready_status} {dwell_desc}")

            elif stop.stop_type == "DROPOFF":
                current_clock += stop.service_time_min
                sla_margin = order.promised_delivery_time_min - current_clock
                if sla_margin >= 0:
                    sla_status = f"ON-TIME ({sla_margin:.1f}m before SLA deadline)"
                else:
                    sla_status = f"DELAYED ({abs(sla_margin):.1f}m breach)"
                    sla_violations += 1
                print(f"  v T={current_clock:>4.1f}m : DELIVER Order {order.order_id} to {stop.location.name} -> {sla_status}")

    # =========================================================================
    # PHASE 5: EXECUTIVE KPI DASHBOARD & BENCHMARK SUMMARY
    # =========================================================================
    print("\n" + "=" * 100)
    print("EXECUTIVE PERFORMANCE KPI DASHBOARD")
    print("=" * 100)
    avg_pickup_dist = sum(a.pickup_distance_km for a in hungarian_assignments) / max(1, len(hungarian_assignments))
    avg_dwell_time = sum(a.food_dwell_time_min for a in hungarian_assignments) / max(1, len(hungarian_assignments))
    total_assigned_orders = sum(len(a.order_ids) for a in hungarian_assignments)

    print(f"1. Total Incoming Orders:            {len(orders)}")
    print(f"2. Total Successfully Dispatched:    {total_assigned_orders} / {len(orders)} ({(total_assigned_orders/len(orders))*100:.1f}%)")
    print(f"3. Active Drivers Utilized:          {len(hungarian_assignments)} / {len(drivers)} ({(len(hungarian_assignments)/len(drivers))*100:.1f}%)")
    print(f"4. Total Road Distance Saved:        {total_km_saved:.2f} km ({pct_km_saved:.1f}% route compression)")
    print(f"5. Average Driver Pickup Distance:   {avg_pickup_dist:.2f} km")
    print(f"6. Average Food Shelf Dwell Time:    {avg_dwell_time:.2f} minutes (Just-In-Time dispatch)")
    print(f"7. SLA Compliance Rate:              {((total_assigned_orders - sla_violations) / max(1, total_assigned_orders))*100:.1f}% ({sla_violations} SLA violations)")
    print(f"8. Hungarian vs Greedy Improvement:  {cost_improvement_pct:.1f}% reduction in global system friction")
    print(f"9. Gross Merchandise Delivery Value: ${total_gmv:.2f}")
    print(f"10. Driver Total Earnings:           ${total_driver_payout:.2f} (Avg ${(total_driver_payout/len(hungarian_assignments)):.2f}/driver)")
    print(f"11. Net Platform Logistics Margin:   ${total_platform_rev:.2f} ({(total_platform_rev/total_gmv)*100:.1f}% take rate)")
    print("=" * 100)


if __name__ == "__main__":
    run_simulation()
