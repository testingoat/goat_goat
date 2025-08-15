# Odoo Server-Push Webhook Implementation Plan

## Overview
Configure Odoo to automatically notify Supabase when product approval status changes in the Odoo backend UI, eliminating the need for client-side polling and improving real-time synchronization.

## Current State vs Target State

### Current Flow (Client Pull)
1. User approves product in Odoo UI
2. Approval status changes in Odoo database
3. Flutter app must call `odoo-status-sync` edge function to detect changes
4. Edge function queries Odoo, compares states, updates Supabase

### Target Flow (Server Push)
1. User approves product in Odoo UI
2. Odoo triggers webhook immediately upon status change
3. Webhook directly calls Supabase edge function with status update
4. Supabase updates local database instantly

## Technical Implementation

### 1. Odoo Webhook Configuration

#### A. Create Odoo Webhook Endpoint
Configure Odoo to POST to our existing edge function:
- **Target URL**: `https://oaynfzqjielnsipttzbs.supabase.co/functions/v1/product-sync-webhook`
- **Method**: POST
- **Content-Type**: application/json
- **Authentication**: Include `x-api-key` header with webhook API key

#### B. Webhook Trigger Conditions
Set up triggers for `product.template` model changes:
- **Field**: `state` (pending → approved/rejected)
- **Field**: `active` (false → true, true → false)
- **Timing**: After record update/write

#### C. Payload Structure (v2 Compatible)
```json
{
  "payload_version": "v2",
  "source": "odoo_webhook",
  "product_id": "supabase_uuid_from_seller_uid_field",
  "approval_status": "approved|rejected|pending",
  "product_data": {
    "name": "Product Name",
    "state": "approved",
    "active": true,
    "default_code": "GOAT_123",
    "seller_uid": "supabase_seller_uuid"
  },
  "timestamp": "2025-08-15T10:30:00Z",
  "odoo_product_id": 123
}
```

### 2. Odoo Development Tasks

#### A. Install/Configure Webhook Module
- Use Odoo's built-in webhook functionality or install webhook addon
- Popular options: `webhook_base`, `rest_api`, or custom module

#### B. Create Webhook Record
```python
# Odoo webhook configuration
webhook_vals = {
    'name': 'GoatGoat Product Approval Sync',
    'url': 'https://oaynfzqjielnsipttzbs.supabase.co/functions/v1/product-sync-webhook',
    'method': 'POST',
    'headers': json.dumps({
        'Content-Type': 'application/json',
        'x-api-key': 'YOUR_WEBHOOK_API_KEY'
    }),
    'model_id': self.env.ref('product.model_product_template').id,
    'trigger_fields': 'state,active',
    'active': True
}
```

#### C. Custom Webhook Handler (Python)
```python
def _prepare_webhook_payload(self, record):
    """Prepare payload for Supabase webhook"""
    # Map Odoo state to our approval status
    approval_status = 'pending'
    if record.state == 'approved' or record.active:
        approval_status = 'approved'
    elif record.state == 'rejected' or not record.active:
        approval_status = 'rejected'
    
    return {
        'payload_version': 'v2',
        'source': 'odoo_webhook',
        'product_id': record.seller_uid,  # Supabase UUID
        'approval_status': approval_status,
        'product_data': {
            'name': record.name,
            'state': record.state,
            'active': record.active,
            'default_code': record.default_code,
            'seller_uid': record.seller_uid
        },
        'timestamp': fields.Datetime.now().isoformat(),
        'odoo_product_id': record.id
    }
```

### 3. Supabase Edge Function Updates (Minimal)

Our existing `product-sync-webhook` already supports the required payload structure. Only minor enhancements needed:

#### A. Source Detection
```typescript
// Detect webhook source
const isOdooWebhook = payload.source === 'odoo_webhook';
if (isOdooWebhook) {
  console.log('📨 Received Odoo server-push webhook');
  // Skip Odoo creation, only update Supabase
}
```

#### B. Conditional Processing
- If `source === 'odoo_webhook'`: Skip Odoo API calls, only update Supabase
- If normal payload: Continue existing flow (create in Odoo + update Supabase)

### 4. Security Considerations

#### A. Authentication
- Use existing `x-api-key` header validation
- Consider IP whitelisting for Odoo server
- Validate payload structure and required fields

#### B. Idempotency
- Use `odoo_product_id` + `timestamp` for duplicate detection
- Store processed webhook IDs to prevent replay attacks

#### C. Error Handling
- Implement retry logic in Odoo for failed webhooks
- Log all webhook attempts for debugging
- Graceful degradation: fallback to client-pull if webhooks fail

### 5. Testing Strategy

#### A. Development Testing
1. Set up Odoo webhook in staging environment
2. Approve test product in Odoo UI
3. Verify webhook payload reaches Supabase
4. Confirm Supabase database updates correctly
5. Test Flutter app reflects changes immediately

#### B. Production Rollout
1. Deploy webhook configuration to production Odoo
2. Monitor webhook success/failure rates
3. Keep client-pull as backup during transition period
4. Gradually increase confidence in server-push reliability

### 6. Monitoring & Observability

#### A. Webhook Metrics
- Success/failure rates
- Response times
- Payload validation errors
- Retry attempts

#### B. Integration with Admin Debug Panel
- Log all incoming Odoo webhooks
- Track approval status change events
- Monitor sync latency improvements

### 7. Fallback Strategy

#### A. Hybrid Approach (Recommended)
- Primary: Server-push webhooks from Odoo
- Fallback: Client-pull on screen open (existing feature flag)
- Emergency: Manual "Sync with Odoo" button

#### B. Health Checks
- Periodic validation that webhooks are working
- Automatic fallback to client-pull if webhook failures exceed threshold

## Implementation Timeline

### Phase 1 (Week 1)
- Configure Odoo webhook module
- Create webhook endpoint configuration
- Test payload structure and authentication

### Phase 2 (Week 2)
- Implement custom webhook handler in Odoo
- Add source detection to Supabase edge function
- End-to-end testing in staging

### Phase 3 (Week 3)
- Production deployment
- Monitoring setup
- Performance validation

## Developer Handoff Checklist

- [ ] Odoo webhook module installed and configured
- [ ] Webhook endpoint URL and API key configured
- [ ] Custom payload handler implemented
- [ ] Trigger conditions set for product.template state/active changes
- [ ] Error handling and retry logic implemented
- [ ] Testing completed in staging environment
- [ ] Monitoring and logging configured
- [ ] Documentation updated for operations team

## Success Metrics

- **Latency**: Approval status updates appear in Flutter app within 5 seconds
- **Reliability**: 99%+ webhook delivery success rate
- **User Experience**: Sellers see status changes without manual refresh
- **System Load**: Reduced client-side API calls to Odoo
