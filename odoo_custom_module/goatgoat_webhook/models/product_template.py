import logging
import requests
import json
from odoo import models, fields, api

_logger = logging.getLogger(__name__)

class ProductTemplate(models.Model):
    _inherit = 'product.template'

    # Add a field to track GoatGoat sync status
    goatgoat_synced = fields.Boolean(
        string='GoatGoat Synced',
        default=False,
        help='Indicates if this product has been synced with GoatGoat'
    )

    def write(self, vals):
        """Override write method to trigger webhook on state changes"""
        result = super(ProductTemplate, self).write(vals)
        
        # Check if state field was updated
        if 'state' in vals:
            for record in self:
                # Only sync products that came from GoatGoat (have default_code starting with GOAT_)
                if record.default_code and record.default_code.startswith('GOAT_'):
                    self._send_approval_webhook(record, vals['state'])
        
        return result

    def _send_approval_webhook(self, product, new_state):
        """Send webhook notification to GoatGoat when product approval status changes"""
        try:
            # Get webhook configuration from system parameters
            webhook_url = self.env['ir.config_parameter'].sudo().get_param(
                'goatgoat_webhook.approval_url',
                'https://oaynfzqjielnsipttzbs.supabase.co/functions/v1/odoo-approval-sync'
            )
            webhook_token = self.env['ir.config_parameter'].sudo().get_param(
                'goatgoat_webhook.token',
                'odoo-goatgoat-sync-2024'
            )

            # Map Odoo states to GoatGoat approval statuses
            state_mapping = {
                'draft': 'pending',
                'pending': 'pending', 
                'approved': 'approved',
                'rejected': 'rejected',
                'done': 'approved',
                'sale': 'approved'
            }

            approval_status = state_mapping.get(new_state, 'pending')

            # Prepare webhook payload
            payload = {
                'odoo_product_id': product.id,
                'product_name': product.name,
                'approval_status': approval_status,
                'state': new_state,
                'default_code': product.default_code,
                'updated_at': fields.Datetime.now().isoformat(),
                'webhook_source': 'odoo_custom_module'
            }

            # Send webhook request
            headers = {
                'Content-Type': 'application/json',
                'x-odoo-webhook-token': webhook_token
            }

            _logger.info(f'🚀 GOATGOAT WEBHOOK - Sending approval sync for product {product.name} (ID: {product.id})')
            _logger.info(f'📤 GOATGOAT WEBHOOK - Payload: {json.dumps(payload)}')

            response = requests.post(
                webhook_url,
                json=payload,
                headers=headers,
                timeout=30
            )

            if response.status_code == 200:
                _logger.info(f'✅ GOATGOAT WEBHOOK - Success for product {product.name}: {response.text}')
                # Mark as synced
                product.sudo().write({'goatgoat_synced': True})
            else:
                _logger.error(f'❌ GOATGOAT WEBHOOK - Failed for product {product.name}: {response.status_code} - {response.text}')

        except Exception as e:
            _logger.error(f'❌ GOATGOAT WEBHOOK - Exception for product {product.name}: {str(e)}')

    @api.model
    def test_webhook_connection(self):
        """Test method to verify webhook connectivity"""
        try:
            webhook_url = self.env['ir.config_parameter'].sudo().get_param(
                'goatgoat_webhook.approval_url',
                'https://oaynfzqjielnsipttzbs.supabase.co/functions/v1/odoo-approval-sync'
            )
            webhook_token = self.env['ir.config_parameter'].sudo().get_param(
                'goatgoat_webhook.token',
                'odoo-goatgoat-sync-2024'
            )

            # Send test payload
            test_payload = {
                'odoo_product_id': 999999,
                'product_name': 'Test Connection',
                'approval_status': 'pending',
                'state': 'draft',
                'default_code': 'GOAT_TEST_CONNECTION',
                'updated_at': fields.Datetime.now().isoformat(),
                'webhook_source': 'odoo_test'
            }

            headers = {
                'Content-Type': 'application/json',
                'x-odoo-webhook-token': webhook_token
            }

            response = requests.post(
                webhook_url,
                json=test_payload,
                headers=headers,
                timeout=10
            )

            _logger.info(f'🧪 GOATGOAT WEBHOOK TEST - Status: {response.status_code}, Response: {response.text}')
            return {
                'status_code': response.status_code,
                'response': response.text,
                'success': response.status_code == 200
            }

        except Exception as e:
            _logger.error(f'❌ GOATGOAT WEBHOOK TEST - Exception: {str(e)}')
            return {
                'status_code': 0,
                'response': str(e),
                'success': False
            }
