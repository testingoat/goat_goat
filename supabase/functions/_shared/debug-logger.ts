/**
 * Debug Panel Logging Helper for Supabase Edge Functions
 * Zero-risk implementation that logs execution data to debug panel tables
 * 
 * Usage in edge functions:
 * import { DebugLogger } from '../_shared/debug-logger.ts';
 * 
 * const logger = new DebugLogger('function-name');
 * await logger.logExecution(request, response, startTime);
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';

export interface LogExecutionOptions {
  endpoint: string;
  status: number;
  latency_ms: number;
  request_data?: any;
  response_data?: any;
  user_agent?: string;
  caller_ip?: string;
  flags?: Record<string, any>;
  dry_run?: boolean;
  error_message?: string;
}

export interface OdooSessionLogOptions {
  success: boolean;
  failure_reason?: string;
  set_cookie_seen?: boolean;
  uid_present?: boolean;
  session_id?: string;
  endpoint_called?: string;
  caller_ip?: string;
  user_agent?: string;
}

export interface ProductWebhookEventOptions {
  product_id?: string;
  seller_id?: string;
  event_type: 'approval' | 'rejection' | 'sync' | 'duplicate_check' | 'dry_run';
  event_source: 'webhook' | 'status-sync' | 'manual' | 'auto';
  old_status?: string;
  new_status?: string;
  event_data?: Record<string, any>;
  dry_run_data?: Record<string, any>;
  duplicate_check_field?: string;
  duplicate_value?: string;
  duplicate_prevented?: boolean;
}

export class DebugLogger {
  private supabase: any;
  private endpoint: string;
  private enabled: boolean;

  constructor(endpoint: string) {
    this.endpoint = endpoint;
    this.enabled = Deno.env.get('ENABLE_DEBUG_LOGGING') !== 'false'; // Enabled by default
    
    if (this.enabled) {
      const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
      const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
      this.supabase = createClient(supabaseUrl, supabaseServiceKey);
    }
  }

  /**
   * Sanitize sensitive data from request/response objects
   */
  private sanitizeData(data: any): any {
    if (!data || typeof data !== 'object') return data;

    const sanitized = { ...data };
    
    // Remove sensitive fields
    const sensitiveFields = [
      'password', 'api_key', 'x-api-key', 'authorization', 'cookie', 
      'session_token', 'access_token', 'refresh_token', 'secret'
    ];
    
    for (const field of sensitiveFields) {
      if (sanitized[field]) {
        delete sanitized[field];
      }
    }

    // Mask phone numbers (keep last 4 digits)
    if (sanitized.phone_number && typeof sanitized.phone_number === 'string') {
      const phone = sanitized.phone_number;
      sanitized.phone_number = '****' + phone.slice(-4);
    }

    // Mask email addresses (keep domain)
    if (sanitized.email && typeof sanitized.email === 'string') {
      const email = sanitized.email;
      const [, domain] = email.split('@');
      sanitized.email = '****@' + (domain || '');
    }

    return sanitized;
  }

  /**
   * Log edge function execution to debug panel
   */
  async logExecution(options: LogExecutionOptions): Promise<void> {
    if (!this.enabled) return;

    try {
      const logData = {
        endpoint: options.endpoint || this.endpoint,
        status: options.status,
        latency_ms: options.latency_ms,
        request: this.sanitizeData(options.request_data) || {},
        response: this.sanitizeData(options.response_data) || {},
        flags: options.flags || {},
        dry_run: options.dry_run || false,
        created_by: `edge_function_${this.endpoint.replace('-', '_')}`,
        caller_ip: options.caller_ip,
        user_agent: options.user_agent,
        api_call_count: 1,
        error_rate_percent: options.status >= 400 ? 100.0 : 0.0,
        ts: new Date().toISOString(),
      };

      await this.supabase
        .from('edge_function_logs')
        .insert(logData);

      console.log(`📊 DEBUG_LOGGER - Logged execution for ${options.endpoint}`);
    } catch (error) {
      console.error(`❌ DEBUG_LOGGER - Failed to log execution:`, error);
      // Don't throw - logging failures shouldn't break the main function
    }
  }

  /**
   * Log Odoo session attempt
   */
  async logOdooSession(options: OdooSessionLogOptions): Promise<void> {
    if (!this.enabled) return;

    try {
      const logData = {
        success: options.success,
        failure_reason: options.failure_reason,
        set_cookie_seen: options.set_cookie_seen || false,
        uid_present: options.uid_present || false,
        session_id: options.session_id,
        endpoint_called: options.endpoint_called || this.endpoint,
        caller_ip: options.caller_ip,
        user_agent: options.user_agent,
        attempt_timestamp: new Date().toISOString(),
      };

      await this.supabase
        .from('odoo_session_logs')
        .insert(logData);

      console.log(`📊 DEBUG_LOGGER - Logged Odoo session attempt`);
    } catch (error) {
      console.error(`❌ DEBUG_LOGGER - Failed to log Odoo session:`, error);
    }
  }

  /**
   * Log product webhook event
   */
  async logProductWebhookEvent(options: ProductWebhookEventOptions): Promise<void> {
    if (!this.enabled) return;

    try {
      const logData = {
        product_id: options.product_id,
        seller_id: options.seller_id,
        event_type: options.event_type,
        event_source: options.event_source,
        old_status: options.old_status,
        new_status: options.new_status,
        event_data: options.event_data || {},
        dry_run_data: options.dry_run_data || {},
        duplicate_check_field: options.duplicate_check_field,
        duplicate_value: options.duplicate_value,
        duplicate_prevented: options.duplicate_prevented || false,
      };

      await this.supabase
        .from('product_webhook_events')
        .insert(logData);

      console.log(`📊 DEBUG_LOGGER - Logged product webhook event: ${options.event_type}`);
    } catch (error) {
      console.error(`❌ DEBUG_LOGGER - Failed to log product event:`, error);
    }
  }

  /**
   * Log feature flag change
   */
  async logFeatureFlagChange(flagName: string, oldValue: boolean, newValue: boolean, changedBy: string = 'system', reason?: string): Promise<void> {
    if (!this.enabled) return;

    try {
      const logData = {
        flag_name: flagName,
        old_value: oldValue,
        new_value: newValue,
        changed_by: changedBy,
        change_reason: reason,
      };

      await this.supabase
        .from('feature_flag_changes')
        .insert(logData);

      console.log(`📊 DEBUG_LOGGER - Logged feature flag change: ${flagName} ${oldValue} → ${newValue}`);
    } catch (error) {
      console.error(`❌ DEBUG_LOGGER - Failed to log feature flag change:`, error);
    }
  }

  /**
   * Helper method to wrap edge function execution with automatic logging
   */
  static async wrapExecution<T>(
    endpoint: string,
    request: Request,
    handler: () => Promise<Response>
  ): Promise<Response> {
    const logger = new DebugLogger(endpoint);
    const startTime = Date.now();
    
    try {
      // Extract request info
      const url = new URL(request.url);
      const userAgent = request.headers.get('user-agent') || 'Unknown';
      const callerIp = request.headers.get('x-forwarded-for') || 
                      request.headers.get('x-real-ip') || 
                      'unknown';
      
      let requestData: any = {};
      try {
        if (request.method !== 'GET' && request.headers.get('content-type')?.includes('application/json')) {
          requestData = await request.clone().json();
        }
      } catch (e) {
        // Ignore JSON parsing errors
      }

      // Execute the handler
      const response = await handler();
      const latency = Date.now() - startTime;

      // Extract response data
      let responseData: any = {};
      try {
        const responseText = await response.clone().text();
        if (responseText) {
          responseData = JSON.parse(responseText);
        }
      } catch (e) {
        // Ignore JSON parsing errors
      }

      // Log the execution
      await logger.logExecution({
        endpoint,
        status: response.status,
        latency_ms: latency,
        request_data: requestData,
        response_data: responseData,
        user_agent: userAgent,
        caller_ip: callerIp,
        flags: {
          method: request.method,
          path: url.pathname,
          query_params: Object.fromEntries(url.searchParams),
        },
      });

      return response;
    } catch (error) {
      const latency = Date.now() - startTime;
      
      // Log the error
      await logger.logExecution({
        endpoint,
        status: 500,
        latency_ms: latency,
        request_data: {},
        response_data: { error: error.message },
        user_agent: request.headers.get('user-agent') || 'Unknown',
        caller_ip: request.headers.get('x-forwarded-for') || 'unknown',
        error_message: error.message,
      });

      throw error;
    }
  }
}

export default DebugLogger;
