# Admin Debug/Observability Panel Plan (Read-only, Zero-risk)

## Objectives
- Single place to observe Odoo ↔ Supabase ↔ Flutter traffic
- Speed up incident triage: see requests, responses, sessions, auth, and errors
- 100% backward compatible; read-only by default; feature-flag controlled

## Scope (Phase 1)
- Traffic Explorer (edge functions)
  - List of invocations: timestamp, endpoint, status, latency, caller IP, x-api-key presence
  - Click-through: payload (sanitized), response (sanitized), JSON-RPC body, headers subset
  - Filters: endpoint, status code, date range, search in payload/response
- Odoo Session Monitor
  - Last 100 auth attempts: success/fail, reason if fail, set-cookie seen?, uid present?
  - Current flag states: FORCE_V2_WEBHOOKS, ENABLE_PRODUCT_DUP_CHECK, ENABLE_AUTO_ACTIVATE_ON_APPROVAL
- Product/Webhook Status
  - Recent product approvals: Supabase approval_status changes with source (webhook/status-sync/manual)
  - Duplicate-prevention events (product.template default_code; res.partner ref)
  - Dry-run events: show captured JSON-RPC bodies

## Data Sources
- New table: edge_function_logs (RLS enabled)
  - id uuid pk; ts timestamptz; endpoint text; status int; latency_ms int
  - request jsonb (sanitized); response jsonb (sanitized); flags jsonb; dry_run bool
  - created_by text (service) ; caller_ip text
- Existing: feature_flags (UI toggles), sellers, meat_products, webhook audit tables

## UI (Admin Web, main_admin.dart build)
- Navigation: Dashboard • Traffic • Odoo Sessions • Products • Flags • Settings
- Traffic
  - Table view with pagination; expandable rows
  - JSON viewer with copy-to-clipboard
- Odoo Sessions
  - Small charts: auth success rate, failures by error, cookie presence rate
- Products
  - Cards: Pending, Approved, Rejected counts; list of last 50 changes
- Flags
  - Read-only list first (Phase 1). Phase 1.1 may allow toggles with role checks

## Implementation Notes
- Logging helpers in edge functions
  - Wrap each handler: start_ts, try/finally to measure latency
  - Sanitize secrets (x-api-key, passwords) before insert
  - Insert minimal record on failure path too
- Feature flags
  - FORCE_V2_WEBHOOKS to gate v1
  - ENABLE_PRODUCT_DUP_CHECK for duplicate checks
  - ENABLE_AUTO_ACTIVATE_ON_APPROVAL for server auto-activation
  - AUTO_SYNC_STATUS_ON_OPEN (client-side) in feature_flags table

## Security
- RLS so only admin role can read edge_function_logs
- Avoid storing raw credentials; hash or redact sensitive fields
- Rate-limit UI queries; index ts, endpoint, status

## Phase 1.1 (Nice-to-have)
- Live tail (WebSocket) of recent edge function logs
- Download logs (CSV/JSON) for a selected time range
- Metric widgets: p50/p95 latency per endpoint, error rate trend
- Correlation Id support (request-id header) to stitch calls across hops

## Phase 2
- Add write-safe controls: feature flag toggles, reprocess-dead-letter buttons
- Automated alerts: Slack/Email on spike of errors/401s

## Testing
- Seed with synthetic entries using dryRun=true
- Verify indexes: idx_edge_logs_ts, idx_edge_logs_endpoint, idx_edge_logs_status
- Ensure all new features are behind feature flags and defaults are safe

