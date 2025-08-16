# Hyperlocal Delivery ETA and Delivery Rate Planning Strategy

This document outlines a comprehensive strategy for delivery time estimation (ETA) and delivery rate planning for an on-demand hyperlocal delivery app. It includes methodologies, system architecture, data requirements, algorithms, and operational processes. It also highlights industry practices from Blinkit, Zepto, Swiggy, and Zomato, and details a phased plan from MVP to advanced optimization.

## 1) Business Goals and KPIs

Primary goals
- Deliver reliable, conservative-yet-competitive ETAs that build trust
- Achieve high on-time rate at a sustainable cost per order
- Drive efficient fleet utilization while protecting rider well-being

Core KPIs (track by cohort: city, micro-zone, store type, time-of-day)
- ETA accuracy:
  - P50 ≤ 2 min error
  - P75 ≤ 5 min error
  - P90 ≤ 8–10 min error
- On-time delivery rate: ≥ 90% (within SLA window)
- SLA compliance (guaranteed-time SKUs/flows): ≥ 95%
- Fulfillment rate: ≥ 98% (post-stock check)
- Average delivery time:
  - Grocery dark-store: 10–20 min
  - Restaurant: 25–40 min
- Cost per order (illustrative):
  - Grocery: ₹30–₹45
  - Restaurant: ₹45–₹70
- Rider utilization (active time utilization): 55–70%
- Cancellation rate: ≤ 2–4% overall; ≤ 1% post-assignment
- Customer NPS: > 45 (grocery), > 30 (restaurant)

## 2) User Journeys and ETA Touchpoints

- Pre-checkout ETA
  - Shown on listing/PDP; fast (<150 ms)
  - Conservative percentile (p80) using cached/micro-zone ETA
- Order confirmation ETA (post-checkout)
  - Recomputed with real-time signals; show a range (e.g., 11–16 min)
- Rider assignment ETA
  - If unassigned: include predicted time-to-assign
  - If assigned: show pickup ETA and drop ETA segments
- Live tracking
  - Segment-wise progress; fast re-estimates on stalls or events
- Notifications
  - Order confirmed, rider assigned, out for delivery, delayed, arrived
- Exceptions
  - Stockouts, prep delays, rider shortage, traffic disruptions
  - Revised ETA + possible compensation on SLA breach

## 3) Data Model and Features

Data domains

- Real-time signals
  - Rider: location (1–5s), status, speed, device quality, acceptance/cancel rate, capacity, shift status
  - Orders: item list, complexity score, payment method, SLA, batching eligibility window
  - Supply availability: active riders per micro-zone, queue backlogs
  - Store: current prep times and backlog, picker staffing (dark store)
  - External: traffic tiles/incidents, weather, surge state, hour/day patterns

- Historical features
  - Store SKU-level prep distributions (p50/p75/p90), category priors for cold start
  - Pickup wait time distributions by store-hour-day
  - Rider travel times by micro-geo and road class; rider performance
  - Batching impact curves (1→2→3 orders marginal delay)
  - Demand/supply heatmaps; zone travel matrices
  - Seasonality and events/festivals

- Contextual features
  - Distance: crow-fly, routed distance/time, elevation/slope, road class mix
  - Destination building: elevator time, gated access, security dwell
  - Item complexity: frozen/fragile/bulk → handling multipliers
  - Payment: COD/UPI → handover dwell time priors
  - Regional traffic patterns and weather regimes

Feature store schema (outline)
- Tables
  - riders_rt(rider_id, lat, lng, speed, status, zone_id, ts)
  - stores_rt(store_id, backlog_count, active_pickers, est_prep_mu, ts)
  - orders_rt(order_id, store_id, items, complexity, batching_eligible_till, ts)
  - traffic_rt(tile_id, travel_time_multiplier, incident_code, ts)
  - weather_rt(zone_id, rain_mm, temp_c, conditions, ts)
  - histories_* (aggregates keyed by store_id/zone_id/hour)
- Feature views
  - fv_travel_time(zone_id_a, zone_id_b, tod_bucket, weather_bucket) → {p50,p75,p90}
  - fv_prep_time(store_id, category_id, tod_bucket) → {p50,p75,p90}
  - fv_assignment_latency(zone_id, supply_demand_ratio, policy, tod_bucket) → {p50,p75,p90}
  - fv_batching_uplift(zone_id, distance_band, load_state) → {mean, p75}

## 4) Estimation Components and Algorithms

### 4.1 Order Preparation Time Model
- Baseline
  - Rule-based per category (produce, meats, restaurant course), with store overrides
- ML model
  - GBDT (LightGBM/XGBoost) per store or store-cluster
  - Features: item count, category mix, complexity, queue length, picker count, time-of-day, day-of-week, predicted rider arrival time
  - Output: quantiles or distribution parameters; provide p50/p75/p90
- Cold start
  - Cluster/store-type priors; Bayesian shrinkage until N orders observed

Pseudo-logic
- prep_p = GBDT(store_id, category_mix, qty, backlog, picker_count, tod, dow)
- prep_quantiles = calibrate(prep_p, store_cluster_priors)

### 4.2 Pickup Wait Time
- Queueing model: M/M/s with Erlang-C approximation
  - λ = arrival rate; μ = service rate; s = active pickers
- Residual correction: ML model for non-Poisson effects

pickup_wait = max(0, mm_s_wait_time(λ, μ, s)) + residual_correction(features)

### 4.3 Travel Time Prediction
- Routing engine
  - Google Directions API or OSRM/Valhalla
- Calibration layer using rider telemetry
  - Features: road classes, turns/intersections, time-of-day, weather, rider speed profiles
  - Outputs: multipliers or deltas; quantiles p50/p75/p90
- Micro-segmentation
  - Per-road-class, per-zone multipliers updated frequently

### 4.4 Assignment Latency Model
- Predict time-to-assign distribution
  - Features: supply_demand_ratio, idle distance distribution, acceptance rate, policy parameters
  - Output: p50/p75/p90 assignment time

### 4.5 Batching Model
- Probability of batching: logistic regression/GBDT over density, window, directional similarity
- Impact function: marginal delay per additional stop
- Expected penalty: prob_batch × uplift

### 4.6 End-to-End ETA Aggregation
- Segment graph
  - T_assign + T_to_store + T_prep/wait + T_pickup_queue + T_to_customer (+ batch penalties)
- Uncertainty propagation
  - Sum conservative percentiles; optionally use Cornish-Fisher if distributions known
- User-facing ETA
  - Show p75–p80 externally; use p50 internally for ops targets

### 4.7 Continuous Learning and Experimentation
- Online updates
  - Sliding-window recalibration (30–60 min) for multipliers
- Drift detection
  - PSI/KS tests; auto fall back to priors if drift detected
- A/B framework
  - Variants: percentile choice, batching thresholds, assignment policy, router
  - Metrics: on-time, error bands, NPS/CSAT, cancel rate, CP0

## 5) Dispatch and Supply Planning

### 5.1 Real-time Dispatch Logic
- Composite score for feasible riders every 3–5s per unassigned order
  - score = w1·ETA_to_store + w2·future_drop_penalty + w3·reliability + w4·zone_balance + w5·batching_gain − penalties(unhealthy shift hours)
- Constraints: max detour, rider capacity, shelf life, SLA window
- Policies
  - Zone-first with backoff radius under scarcity
  - Batching window: hold X seconds if probability high and SLA safe
  - Rebalancing: proactive repositioning to predicted hotspots

### 5.2 Supply Forecasting
- Short-term demand forecasting (5–60 min) per micro-zone
  - GBDT or Prophet/ARIMA with exogenous signals (weather/events)
- Convert demand to required active riders via takt time
- Dynamic incentives and surge pay with guardrails

### 5.3 Zoning and Geofencing
- Micro-zones (0.5–1.5 km cells) with adjacency graph
- Zone travel time matrix updated hourly
- Dark-store readiness: internal SLA per store zone (pick-pack staffing, max backlog)

## 6) System Architecture

Event-driven, low-latency design

- Ingestion
  - Rider GPS (1–5s), orders, store status, traffic, weather → Kafka/PubSub topics
- Stream processing
  - Flink/Spark/Kafka Streams for aggregates and feature materialization
  - Online Feature Store (Feast + Redis/Bigtable/DynamoDB)
- Model serving (real-time)
  - ETA service (gRPC/HTTP), p95 under 200–400 ms
  - Components: routing client, feature fetch (p95 < 30 ms), models, aggregator
- Data lake/warehouse
  - Raw/curated layers (Parquet) in S3/GCS; dbt for transformations; analytics in BigQuery/Snowflake/Redshift
- Caching/fallbacks
  - Redis zone matrices for pre-checkout; routing timeouts (e.g., 120 ms) fall back to crow-fly×multiplier
  - Degradation modes: freeze batching, increase shown percentile, suppress aggressive promises
- Observability
  - Metrics: per-component latency, error rates, ETA error quantiles
  - Tracing: OpenTelemetry
  - Alerts: SLO breaches (p95 > 400 ms), ETA P90 error > 10 min, on-time dip > 5% hour-over-hour

Latency budget (p95)
- Feature fetch 30 ms
- Routing 100–150 ms (or cached)
- Models 20–60 ms
- Aggregation + IO 30–60 ms
- Total: 180–300 ms

### API Contracts (Examples)

POST /eta/quote
Request:
```json
{
  "order_id": "optional",
  "store_id": "uuid",
  "customer_lat": 12.93,
  "customer_lng": 77.59,
  "items": [{"sku":"id","qty":2,"category":"produce"}],
  "payment_method": "UPI",
  "batching_allowed": true
}
```
Response:
```json
{
  "eta_minutes": 14,
  "eta_range": {"min": 11, "max": 17},
  "segments": {
    "assignment_p75": 2.1,
    "to_store_p75": 4.0,
    "prep_or_wait_p75": 4.5,
    "to_customer_p75": 3.1,
    "batch_penalty_exp": 0.6
  },
  "confidence": {"p50": 12, "p75": 14, "p90": 18},
  "policy": {"percentile_shown": "p75", "batching_considered": true}
}
```

POST /dispatch/assign
Request:
```json
{
  "order_id": "uuid",
  "zone_id": "z123",
  "policy": {"max_radius_km": 3, "allow_batch": true}
}
```
Response:
```json
{
  "assigned_rider_id": "r789",
  "predicted_time_to_pickup_min": 6.5,
  "batched_with": ["order_b"]
}
```

## 7) Operational Workflows

- Store SLAs
  - Prep-time contracts per store/category; staffing to achieve target μ in M/M/s
  - Exception flow: backlog breach → disable batching; auto ETA uplift
- Rider operations
  - Shift vs on-demand mix; heatmap positioning; SOPs for high-rise/gated entries; safety guidelines
- Customer communication
  - Proactive delay notice if predicted breach > 3–4 min; compensation for SLA breaches
  - Transparent ETA revisions with reason codes (traffic, weather, store load)

## 8) Risks and Edge Cases

- Cold starts: cluster priors; conservative ETAs initially; fast-learn after 50–100 orders
- Extreme weather/festivals: “storm mode” multipliers; relaxed promises; surge incentives
- Rider shortages: widen search radius gradually; cap order intake; increase incentives
- Bulky/fragile items: handling multipliers; restrict batching
- Fraud/gaming: detect GPS anomalies, rejections, long dwell without movement; mitigate via scoring, audits, and enforcement

## 9) Benchmarking and Industry Practices

- Blinkit/Zepto (dark stores)
  - Strong control of prep via pick-pack SLAs; aggressive batching in dense zones; dynamic zone resizing
  - Conservative pre-checkout ETAs; rapid post-confirmation re-estimation
- Swiggy/Zomato (restaurants)
  - High prep variance; leverage merchant/KDS signals
  - Dispatch balances proximity and readiness; pre-batching based on route similarity
- Trade-off
  - Optimistic ETAs can acquire users but erode trust if missed
  - Best practice: conservative user-facing ETA (p75–p80) with early delivery delight; avoid frequent rolling extensions

## 10) Governance and Experimentation

- A/B testing plans
  - ETA percentile (p70 vs p80), batching thresholds, assignment weights, router provider
- Accuracy audits
  - Weekly by cohort (geo, store, time, weather); investigate tails (P90+)
- Fairness and rider well-being
  - Cap continuous duty; enforce breaks; incentives avoid risky behavior; transparent assignment rules

## Phased Implementation Plan

### MVP (4–8 weeks)
- Pre-checkout ETA with cached zone matrices + simple routing fallback
- Prep-time rules by category + store priors
- Simple assignment latency prior by zone
- End-to-end ETA = p75(sum of components); re-estimate every 60s
- Dispatch: nearest feasible rider; no batching or simple 10–20s hold rule
- Infra: Redis cache, REST ETA service, nightly batch aggregates
- KPIs: ETA P50/P75/P90 error, on-time, cancel rate, latency

### V1 (~3 months)
- GBDT models for prep-time and assignment latency; M/M/s pickup wait + ML residuals
- ML-calibrated travel-time with telemetry; per-road-class multipliers
- Batching model (probability + uplift) and composite-score dispatch
- Short-term demand forecasting; rider heatmap nudges; light surge
- Event-driven pipeline (Kafka), online feature store (Feast+Redis), tracing+dashboards
- A/B framework; drift detection; conservative fallbacks

### V2+ (6–12 months)
- Per-store SKU prep distributions; adaptive picker staffing
- Advanced routing (OSRM/Valhalla) with custom penalties; traffic incidents integration
- Reinforcement learning for dispatch (guard-railed by rules)
- Dynamic SLA pricing & delivery fees; promise optimization by cohort
- Full incident playbooks; chaos drills; automated throttling
- Multi-city scaling; cost optimization via autoscaling/spot instances

## Algorithmic Pseudo-logic

Prep-time
```
if recent_store_data:
  q = GBDT(features)
else:
  q = cluster_prior(category, store_type)
prep = quantile(q, target_percentile)
```

Pickup wait (M/M/s + residual)
```
mm_s = erlang_c_wait(lambda, mu, s)
pickup_wait = max(0, mm_s) + residual_GBDT(features)
```

Travel time
```
path = router.route(store, customer)
base_tt = sum(edge.time for edge in path)
mult = cal_model(features(path, tod, weather))
tt_p50 = base_tt * mult.p50
tt_p75 = base_tt * mult.p75
```

Assignment latency
```
sdr = active_riders(zone) / incoming_orders(zone)
assign_q = GBDT(zone, sdr, tod, policy)
t_assign = quantile(assign_q, 0.75)
```

Batching impact
```
prob_batch = logistic(features_density, window, directionality)
uplift = uplift_model(distance_band, load)
expected_penalty = prob_batch * uplift
```

End-to-end ETA
```
eta_components = [
  t_assign_p75,
  to_store_p75,
  max(prep_p75 - to_store_p50, 0),
  pickup_queue_p75,
  to_customer_p75,
  batch_penalty_exp
]
eta_p75 = sum(eta_components)
shown_eta = ceil_to_minute(eta_p75)
```

## Monitoring KPIs and Alerts

- ETA P90 error > 8 min in 2 consecutive 15-min windows → Level 2 alert
- On-time < 88% hour-over-hour → Level 2 alert
- ETA service p95 latency > 400 ms for 5 min → Level 1 alert
- Drift PSI > 0.2 vs last week in zone Z for prep-time → Investigate
- Rider shortage: supply_demand_ratio < 0.6 for 10 min → Trigger surge

## Incident and Extreme-load Playbooks

- Router degraded
  - Switch to cached matrices + crow-fly multiplier; increase percentile to p80; pause batching
- Weather/festival spike
  - Activate storm-mode multipliers; increase incentives; widen dispatch radius but cap promises
- Store backlog surge
  - Queue cap; temporarily hide store for pre-checkout ETA in affected zones

## Grocery vs Restaurant and Geography Guidance

- Grocery (dark stores)
  - Strong prep control → tighter ETAs; batching in dense zones
  - Rider positioning around dark stores; shelf-life rules
- Restaurant
  - Higher prep variance → rely on merchant/KDS signals and queue modeling
  - More conservative batching; careful pickup wait estimates
- Small cities
  - Larger zones; simpler models; rely on priors
- Large metros
  - Fine micro-zones; rich telemetry; invest in calibration and dynamic incentives

## Cost and Scalability Considerations

- Cloud: GCP (Pub/Sub, BigQuery, Vertex AI) or AWS (MSK/Kinesis, Redshift, SageMaker); start with managed Kafka + Redis + GKE/EKS
- Open-source: Feast (feature store), OSRM/Valhalla (routing), Prometheus+Grafana, Airflow+dbt, MLflow
- Cost optimization: Cache pre-checkout ETAs, batch routing calls, prefer matrix endpoints, or self-host routing

## Conclusion

This strategy aligns with industry leaders: reliable ETAs, dynamic dispatch, optional batching, and continuous learning. Launch a conservative MVP in 4–8 weeks, deliver a robust V1 in ~3 months, and pursue advanced optimizations over 6–12 months with strong governance and rider well-being at the core.