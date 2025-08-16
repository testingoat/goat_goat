# 📊 Edge Function Logging Integration Guide

## 🎯 Overview

This guide explains how to instrument Supabase Edge Functions with the DebugLogger to populate the admin debug panel with real traffic data. The logging system provides comprehensive monitoring without affecting core business logic.

## 🔧 Quick Setup

### Method 1: Automatic Wrapper (Recommended)

Use the `DebugLogger.wrapExecution()` method for automatic logging:

```typescript
import { DebugLogger } from '../_shared/debug-logger.ts';

Deno.serve(async (req) => {
  return await DebugLogger.wrapExecution('your-function-name', req, async () => {
    // Your existing function logic here
    const result = await yourBusinessLogic();
    
    return new Response(JSON.stringify(result), {
      headers: { 'Content-Type': 'application/json' },
    });
  });
});
```

### Method 2: Manual Logging

For more control over what gets logged:

```typescript
import { DebugLogger } from '../_shared/debug-logger.ts';

Deno.serve(async (req) => {
  const logger = new DebugLogger('your-function-name');
  const startTime = Date.now();
  
  try {
    // Your business logic
    const result = await yourBusinessLogic();
    
    // Log successful execution
    await logger.logExecution({
      endpoint: 'your-function-name',
      status: 200,
      latency_ms: Date.now() - startTime,
      request_data: await req.clone().json(),
      response_data: result,
      user_agent: req.headers.get('user-agent') || 'Unknown',
      caller_ip: req.headers.get('x-forwarded-for') || 'unknown',
    });
    
    return new Response(JSON.stringify(result), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (error) {
    // Log error execution
    await logger.logExecution({
      endpoint: 'your-function-name',
      status: 500,
      latency_ms: Date.now() - startTime,
      error_message: error.message,
    });
    
    throw error;
  }
});
```

## 🎯 Priority Functions to Instrument

Based on business importance and traffic volume:

### High Priority (Immediate)
1. **product-sync-webhook** - Core product approval workflow
2. **odoo-status-sync** - Critical Odoo integration
3. **fast2sms-custom** - OTP and notifications
4. **send-push-notification** - User notifications

### Medium Priority
5. **seller-approval-webhook** - Seller onboarding
6. **product-approval-webhook** - Product management
7. **odoo-approval-sync** - Odoo synchronization

### Low Priority
8. **seller-status-sync** - Seller status updates
9. **seller-sync-webhook** - Seller data sync

## 🔍 Logging Features

### Automatic Data Sanitization
- Phone numbers: `+91XXXXXXXXXX` → `+91****XXXX`
- Emails: `user@domain.com` → `****@domain.com`
- Sensitive fields automatically masked

### Odoo Session Logging
For Odoo-related functions, add session logging:

```typescript
// Log Odoo session attempts
await logger.logOdooSession({
  success: sessionEstablished,
  failure_reason: error?.message,
  set_cookie_seen: !!setCookieHeader,
  uid_present: !!uid,
  session_id: sessionId,
  endpoint_called: 'your-function-name',
});
```

### Product Webhook Events
For product-related webhooks:

```typescript
await logger.logProductWebhookEvent({
  product_id: productData.id,
  seller_id: productData.seller_id,
  event_type: 'approval',
  event_source: 'webhook',
  old_status: 'pending',
  new_status: 'approved',
  event_data: productData,
});
```

## 🚀 Implementation Steps

### Step 1: Choose Functions to Instrument
Start with high-priority functions that handle the most traffic.

### Step 2: Add Logging Import
```typescript
import { DebugLogger } from '../_shared/debug-logger.ts';
```

### Step 3: Implement Logging
Use either the wrapper method or manual logging based on your needs.

### Step 4: Deploy and Test
```bash
supabase functions deploy your-function-name
```

### Step 5: Verify in Debug Panel
Check the admin panel at https://goatgoat.info to see real traffic data.

## 🔧 Configuration

### Environment Variables
- `ENABLE_DEBUG_LOGGING`: Set to `false` to disable logging (default: `true`)
- `SUPABASE_MANAGEMENT_TOKEN`: Required for native Supabase logs integration

### Feature Flags
The logging system respects the debug panel feature flags and can be controlled remotely.

## 📊 Integration with Admin Panel

### Custom Logs
- Stored in `edge_function_logs` table
- Accessible via DebugPanelService
- Real-time traffic monitoring

### Supabase Native Logs
- Accessed via Management API
- Comprehensive system logs
- Database, API Gateway, and Edge Function logs

### Combined View
The debug panel provides a unified view combining:
- Custom instrumented logs
- Supabase native system logs
- Real-time traffic analysis
- Anomaly detection

## 🛡️ Zero-Risk Implementation

### Safety Features
- ✅ Logging failures don't affect business logic
- ✅ Automatic data sanitization
- ✅ Configurable via environment variables
- ✅ Feature flag controlled
- ✅ No modifications to core business functions

### Error Handling
- All logging operations are wrapped in try-catch
- Logging errors are logged to console but don't throw
- Business logic continues even if logging fails

## 📈 Benefits

### For Developers
- Real-time traffic monitoring
- Performance analysis
- Error tracking and debugging
- System health monitoring

### For Business
- User behavior insights
- System performance metrics
- Proactive issue detection
- Data-driven optimization

## 🔄 Next Steps

1. **Immediate**: Instrument high-priority functions
2. **Short-term**: Add Supabase Management API token for native logs
3. **Medium-term**: Instrument remaining functions
4. **Long-term**: Advanced analytics and alerting

## 📞 Support

For questions or issues with logging implementation:
- Check the DebugLogger source code in `supabase/functions/_shared/debug-logger.ts`
- Review existing instrumented functions for examples
- Test logging in development before deploying to production

The logging system is designed to be zero-risk and non-intrusive, ensuring your business logic remains unaffected while providing comprehensive monitoring capabilities.
