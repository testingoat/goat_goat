/// API Configuration for GoatGoat Application
class ApiConfig {
  // Edge Function Authentication (CORRECT API KEY from Supabase secrets)
  static const String edgeFunctionApiKey =
      'dev-webhook-api-key-2024-secure-odoo-integration';

  // Webhook Authentication (based on your webhook documentation)
  static const String webhookApiKey =
      'dev-webhook-api-key-2024-secure-odoo-integration';

  // Odoo Integration Settings
  static const String odooProductEndpoint = 'odoo-create-product';
  static const String odooSellerEndpoint = 'seller-approval-webhook';
  static const String odooProductApprovalEndpoint =
      'product-sync-webhook'; // FIXED WEBHOOK
  static const String odooStatusSyncEndpoint =
      'odoo-status-sync'; // NEW: Status sync
  static const String odooLivestockEndpoint = 'livestock-approval-webhook';

  // Request Headers for Edge Functions
  static Map<String, String> get edgeFunctionHeaders => {
    'Content-Type': 'application/json',
    'x-api-key': edgeFunctionApiKey,
  };

  // Request Headers for Webhooks
  static Map<String, String> get webhookHeaders => {
    'Content-Type': 'application/json',
    'x-api-key': webhookApiKey,
  };

  // Debug logging flag
  static const bool enableDebugLogging = true;

  // Authentication method
  static const String authMethod = 'api_key'; // 'api_key' or 'jwt'
}
