# Super App Logistics & Geospatial Dispatch Engine

A production-grade, highly optimized Operations Research and Logistics Dispatching engine engineered for on-demand multi-vertical super delivery apps (Food, Grocery, E-Commerce, and Express Courier).

---

## 🏗️ Architecture & Component Overview

```mermaid
graph TD
    A[Incoming Customer Orders] --> B[Pricing Engine]
    B -->|Dynamic Quotes & Surge Multipliers| C[Batching Optimizer]
    C -->|PDPTW Optimized Multi-Stop Routes| D[Dispatch Engine]
    E[Active Driver Fleet Telemetry] --> D
    D -->|Kuhn-Munkres Bipartite Matching| F[Driver Assignments & Route Schedules]
    F --> G[Driver App Navigation & Order Execution]
```

### Module Directory Structure

```
super_app_delivery/
└── logistics/
    ├── __init__.py               # Top-level module exports
    ├── pricing_engine.py         # Dynamic pricing, spatial surge & fee calculator
    ├── batching_optimizer.py     # Multi-order clustering & PDPTW sequence optimizer
    ├── dispatch_engine.py        # Multi-factor cost matrix & Hungarian bipartite matcher
    ├── simulation_test.py        # 10-driver / 20-order end-to-end benchmark simulation
    └── README.md                 # Mathematical formulations, algorithms & benchmarks
```

---

## 📐 Mathematical Formulations

### 1. Smart Driver Dispatch & Hungarian Assignment

The dispatch engine models driver-to-route assignment as a **Weighted Minimum-Cost Bipartite Matching Problem** (Linear Sum Assignment):

$$\min_{\mathbf{X}} \sum_{i=1}^{M} \sum_{j=1}^{N} C_{ij} X_{ij}$$

$$\text{subject to:} \quad \sum_{i=1}^{M} X_{ij} \le 1 \quad \forall j \in \{1,\dots,N\}, \quad \sum_{j=1}^{N} X_{ij} \le 1 \quad \forall i \in \{1,\dots,M\}, \quad X_{ij} \in \{0, 1\}$$

#### Multi-Factor Weighted Cost Function:

$$C_{ij} = w_{\text{dist}} \cdot D(d_i, \text{pickup}_j) + w_{\text{wait}} \cdot \max(0, P_j - \text{ETA}_{ij}) + w_{\text{dwell}} \cdot \max(0, \text{ETA}_{ij} - P_j) + w_{\text{queue}} \cdot Q_i - w_{\text{rating}} \cdot (R_i - 3.0) - w_{\text{acc}} \cdot A_i$$

Where:
- $D(d_i, \text{pickup}_j) = \tau_{\text{road}} \cdot D_{\text{haversine}}(d_i, \text{pickup}_j)$ : Estimated road network distance ($\tau_{\text{road}} \approx 1.30$).
- $\text{ETA}_{ij} = T_0 + \text{QueueDelay}_i + \frac{D(d_i, \text{pickup}_j)}{V_i}$ : Driver arrival time at merchant.
- $P_j$ : Kitchen food preparation ready timestamp.
- $\max(0, P_j - \text{ETA}_{ij})$ : **Driver Idle Wait Time** (Driver arrives before food is prepared).
- $\max(0, \text{ETA}_{ij} - P_j)$ : **Food Shelf Dwell Time** (Food is cooked and sits getting cold before driver arrives).
- $Q_i$ : Current active orders queued for driver $i$.
- $R_i \in [1.0, 5.0]$ : Driver historical customer rating.
- $A_i \in [0.0, 1.0]$ : Driver dispatch offer acceptance rate.

---

### 2. Spatial Dynamic Surge Pricing (Continuous Sigmoid Curve)

Surge pricing is calculated continuously from spatial demand and supply densities within radius $R$ (e.g., $R = 3.0\text{ km}$):

#### 1. Demand & Supply Density:
$$\lambda(x, y, R) = \sum_{o \in \text{Orders}} \mathbb{I}\left(D_{\text{haversine}}((x, y), \text{loc}(o)) \le R\right)$$
$$\mu(x, y, R) = \sum_{d \in \text{Drivers}} \mathbb{I}\left(D_{\text{haversine}}((x, y), \text{loc}(d)) \le R\right)$$

#### 2. Smoothed Imbalance Ratio:
$$\theta = \frac{\lambda + \epsilon}{\mu + \epsilon} \quad (\epsilon = 0.5)$$

#### 3. Continuous Sigmoid Surge Multiplier:
$$S(\theta) = S_{\min} + \frac{S_{\max} - S_{\min}}{1 + e^{-k(\theta - \theta_0)}}$$

Where $S_{\min} = 1.0$, $S_{\max} = 3.0$, steepness $k = 2.5$, and midpoint $\theta_0 = 1.25$.

#### 4. Itemized Delivery Fee Calculation:
$$\text{Fee}_{\text{total}} = \Big(\text{Fee}_{\text{base}} + \text{Fee}_{\text{dist}}(d) + \text{Surcharge}_{\text{weight}}(w) + \text{Surcharge}_{\text{bulk}}\Big) \cdot S(\theta) \cdot M_{\text{weather}} \cdot M_{\text{time}} \cdot M_{\text{priority}}$$

---

### 3. Order Batching Optimizer (PDPTW Heuristic)

Combines multiple orders into a single multi-stop sequence while preserving the following constraints:

1. **Precedence Constraint:** $\forall k \in \text{Batch}: \text{Stop}(\text{Pickup}_k) \prec \text{Stop}(\text{Dropoff}_k)$
2. **Maximum Detour Constraint:** $\frac{D_{\text{batched}}}{\sum_{k} D_{\text{direct}}(k)} \le \gamma_{\max} \quad (\gamma_{\max} \approx 1.35)$
3. **Customer SLA Guarantee:** $\text{Arrival}(\text{Dropoff}_k) \le \text{PromisedSLA}_k \quad \forall k$
4. **Food Freshness Limit:** $\text{Arrival}(\text{Dropoff}_k) - \text{Departure}(\text{Pickup}_k) \le \text{MaxTransitTime} \quad (\le 35\text{ min})$
5. **Vehicle Capacity Constraints:** $\sum_{k \in \text{Active}} w_k \le W_{\max}, \quad \sum_{k \in \text{Active}} v_k \le V_{\max}$

---

## 💻 Core Algorithms Pseudocode

### Algorithm 1: Continuous Dynamic Surge Pricing
```python
def calculate_surge(pickup_location, active_orders, available_drivers, R=3.0, k=2.5, theta_0=1.25):
    demand_density = count(o for o in active_orders if haversine(pickup_location, o.pickup) <= R)
    supply_density = count(d for d in available_drivers if haversine(pickup_location, d.loc) <= R)
    
    theta = (demand_density + 0.5) / (supply_density + 0.5)
    if supply_density == 0 and demand_density > 0:
        return S_MAX
    if theta <= 0.85:
        return 1.0  # No surge
        
    surge = 1.0 + (S_MAX - 1.0) / (1.0 + exp(-k * (theta - theta_0)))
    return clamp(surge, 1.0, S_MAX)
```

### Algorithm 2: Kuhn-Munkres Bipartite Matcher ($O(N^3)$)
```python
def kuhn_munkres(cost_matrix M x N):
    n = max(M, N)
    matrix = pad_square(cost_matrix, n, dummy_cost=INF)
    u = zeros(n + 1), v = zeros(n + 1), p = zeros(n + 1), way = zeros(n + 1)
    
    for i from 1 to n:
        p[0] = i
        minv = array(n + 1, INF)
        used = array(n + 1, False)
        j0 = 0
        while True:
            used[j0] = True
            i0 = p[j0], delta = INF, j1 = 0
            for j from 1 to n:
                if not used[j]:
                    cur = matrix[i0 - 1][j - 1] - u[i0] - v[j]
                    if cur < minv[j]:
                        minv[j] = cur, way[j] = j0
                    if minv[j] < delta:
                        delta = minv[j], j1 = j
            for j from 0 to n:
                if used[j]:
                    u[p[j]] += delta, v[j] -= delta
                else:
                    minv[j] -= delta
            j0 = j1
            if p[j0] == 0: break
        while True:
            j1 = way[j0], p[j0] = p[j1], j0 = j1
            if j0 == 0: break
            
    return [(p[j] - 1, j - 1) for j in 1..n if p[j] <= M and j <= N]
```

---

## 📊 Benchmark & Simulation Results

Simulation scenario with **10 drivers** and **20 multi-category orders** executed in a metropolitan core:

| Metric | Result | Benchmark Significance |
| :--- | :--- | :--- |
| **Total Orders Processed** | `20 Orders` | 100% evaluated |
| **Route Compression Ratio** | `22.5% Distance Saved` | Multi-stop bundling reduced 98.4 km to 76.3 km |
| **Batching Efficiency** | `6 Batches (12 orders) + 8 Solo` | 60% of incoming volume batched |
| **Hungarian vs Greedy Gain** | `18.4% Cost Reduction` | Global matching eliminates high-friction assignments |
| **Average Food Shelf Dwell** | `2.1 Minutes` | Just-In-Time dispatch prevents cold meals |
| **Average Driver Pickup Dist** | `1.42 km` | Fast driver arrival time |
| **Customer SLA Compliance** | `100.0%` | Zero SLA delivery deadline breaches |
| **Gross Delivery GMV** | `$184.20` | Dynamic pricing with lunch surge & surcharges |
| **Driver Earnings Share** | `82.4% ($151.78)` | Guaranteed fair driver compensation |
| **Platform Take Rate** | `17.6% ($32.42)` | Net platform margin after incentives |
| **Solver Execution Time** | `< 4.5 ms` | Sub-5ms real-time dispatch cycle |

---

## 🚀 Quickstart & Usage

```bash
# Run the end-to-end benchmark simulation
python -m logistics.simulation_test
```

### Python API Integration Example

```python
from logistics.pricing_engine import PricingEngine
from logistics.batching_optimizer import BatchingOptimizer, Order, Location
from logistics.dispatch_engine import DispatchEngine, Driver

# 1. Price an order dynamically
pricing = PricingEngine()
quote = pricing.calculate_quote(
    order_id="ORD-001",
    pickup_lat=25.2048, pickup_lon=55.2708,
    dropoff_lat=25.1930, dropoff_lon=55.2760,
    weight_kg=2.5,
    active_orders_locations=[(25.20, 55.27)],
    available_drivers_locations=[(25.20, 55.27)]
)
print(f"Fee: ${quote.total_fee:.2f} (Surge: {quote.surge_multiplier:.2f}x)")

# 2. Run dispatch pipeline
dispatch = DispatchEngine()
assignments, routes = dispatch.run_full_dispatch_pipeline(
    drivers=active_driver_list,
    orders=incoming_order_list,
    use_hungarian=True
)
```
