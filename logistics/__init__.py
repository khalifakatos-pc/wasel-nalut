"""
Super App Logistics Core Engine.

Modules:
- pricing_engine: Dynamic pricing, surge pricing, tiered delivery fees, surcharges
- batching_optimizer: Order batching heuristics and PDPTW sequence optimizer
- dispatch_engine: Kuhn-Munkres Hungarian bipartite matcher and NN-TW driver dispatch
"""

from .pricing_engine import (
    PricingEngine,
    PricingConfig,
    DeliveryQuote,
    haversine_distance,
    road_distance_estimate,
)
from .batching_optimizer import (
    BatchingOptimizer,
    BatchingConstraints,
    Order,
    Location,
    RouteStop,
    BatchedRoute,
)
from .dispatch_engine import (
    DispatchEngine,
    DispatchWeights,
    Driver,
    AssignmentResult,
    kuhn_munkres,
)

__all__ = [
    "PricingEngine",
    "PricingConfig",
    "DeliveryQuote",
    "haversine_distance",
    "road_distance_estimate",
    "BatchingOptimizer",
    "BatchingConstraints",
    "Order",
    "Location",
    "RouteStop",
    "BatchedRoute",
    "DispatchEngine",
    "DispatchWeights",
    "Driver",
    "AssignmentResult",
    "kuhn_munkres",
]
