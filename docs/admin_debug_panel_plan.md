# Admin Debug/Observability Panel Plan (Read-only, Zero-risk)

## Objectives
- Single place to observe Odoo ↔ Supabase ↔ Flutter traffic
- Speed up incident triage: see requests, responses, sessions, auth, and errors
- 100% backward compatible; read-only by default; feature-flag controlled
- Provide actionable insights for system optimization and troubleshooting

## Scope (Phase 1)
- Traffic Explorer (edge functions)
  - List of invocations: timestamp, endpoint, status, latency, caller IP, x-api-key presence
  - Click-through: payload (sanitized), response (sanitized), JSON-RPC body, headers subset
  - Filters: endpoint, status code, date range, search in payload/response
  - **API call volume metrics**: Track requests per endpoint per hour/day
  - **Error rate thresholds**: Alert indicators when error rate > 5% for any endpoint
- Odoo Session Monitor
  - Last 100 auth attempts: success/fail, reason if fail, set-cookie seen?, uid present?
  - Current flag states: FORCE_V2_WEBHOOKS, ENABLE_PRODUCT_DUP_CHECK, ENABLE_AUTO_ACTIVATE_ON_APPROVAL
  - **User agent tracking**: Log client types (mobile app, admin panel, webhook) for debugging
- Product/Webhook Status
  - Recent product approvals: Supabase approval_status changes with source (webhook/status-sync/manual)
  - Duplicate-prevention events (product.template default_code; res.partner ref)
  - Dry-run events: show captured JSON-RPC bodies

## Data Sources
- New table: edge_function_logs (RLS enabled)
  - id uuid pk; ts timestamptz; endpoint text; status int; latency_ms int
  - request jsonb (sanitized); response jsonb (sanitized); flags jsonb; dry_run bool
  - created_by text (service) ; caller_ip text; user_agent text
  - api_call_count int (for volume tracking); error_rate_percent decimal
- Existing: feature_flags (UI toggles), sellers, meat_products, webhook audit tables

## UI (Admin Web, main_admin.dart build)
- Navigation: Dashboard • Traffic • Odoo Sessions • Products • Flags • Settings
- Traffic
  - Table view with pagination; expandable rows
  - JSON viewer with copy-to-clipboard
  - **Alert indicators**: Red badges for endpoints with error rate > 5%
  - **Volume metrics**: API calls per hour/day charts
- Odoo Sessions
  - Small charts: auth success rate, failures by error, cookie presence rate
  - **User agent breakdown**: Mobile app vs admin panel vs webhook traffic
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
- **Basic alerting**: Visual indicators when error rates exceed thresholds

## Phase 2
- Add write-safe controls: feature flag toggles, reprocess-dead-letter buttons
- Automated alerts: Slack/Email on spike of errors/401s
- **Advanced analytics**: Traffic patterns, peak usage times, client-side debugging insights

## Testing
- Seed with synthetic entries using dryRun=true
- Verify indexes: idx_edge_logs_ts, idx_edge_logs_endpoint, idx_edge_logs_status, idx_edge_logs_user_agent
- Ensure all new features are behind feature flags and defaults are safe
- **Performance testing**: Verify UI responsiveness with large log volumes
- **Alert threshold testing**: Confirm error rate calculations and visual indicators work correctly

## Implementation Recommendations

### Immediate Benefits (Phase 1)
1. **Error Rate Monitoring**: 5% threshold provides early warning for system issues
2. **API Volume Tracking**: Identify usage patterns and potential bottlenecks
3. **User Agent Insights**: Distinguish between mobile app, admin panel, and webhook traffic for targeted debugging
4. **Enhanced Troubleshooting**: Correlation between traffic patterns and system behavior

### Technical Considerations
- **Performance**: Index user_agent field for efficient filtering
- **Storage**: Consider log retention policy (30-90 days) to manage database size
- **Security**: Ensure user_agent data doesn't contain sensitive information
- **Scalability**: Design for high-volume logging without impacting edge function performance

### Future Enhancements (Post-Phase 2)
- **Machine Learning**: Anomaly detection for unusual traffic patterns
- **Integration**: Connect with external monitoring tools (DataDog, New Relic)
- **Mobile Analytics**: Deep-dive into mobile app performance metrics
- **Business Intelligence**: Usage analytics for product and feature adoption

