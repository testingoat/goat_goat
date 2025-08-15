import logging
import requests
import json
from odoo import models, fields, api

_logger = logging.getLogger(__name__)

class ResPartner(models.Model):
    _inherit = 'res.partner'

    # Add a field to track GoatGoat sync status for sellers
    goatgoat_seller_synced = fields.Boolean(
        string='GoatGoat Seller Synced',
        default=False,
        help='Indicates if this seller has been synced with GoatGoat'
    )

    def write(self, vals):
        """Override write method to trigger webhook on seller state changes"""
        result = super(ResPartner, self).write(vals)
        
        # Check if state field was updated for sellers
        if 'state' in vals:
            for record in self:
                # Only sync sellers (supplier_rank = 1) that came from GoatGoat (have ref field)
                if record.supplier_rank == 1 and record.ref:
                    self._send_seller_approval_webhook(record, vals['state'])
        
        return result

    def _send_seller_approval_webhook(self, seller, new_state):
        """Send webhook notification to GoatGoat when seller approval status changes"""
        try:
            # Get webhook configuration from system parameters
            webhook_url = self.env['ir.config_parameter'].sudo().get_param(
                'goatgoat_webhook.seller_approval_url',
                'https://oaynfzqjielnsipttzbs.supabase.co/functions/v1/seller-approval-webhook'
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
                'active': 'approved'
            }

            approval_status = state_mapping.get(new_state, 'pending')

            # Prepare webhook payload (Odoo-style)
            payload = {
                'odoo_seller_id': seller.id,
                'seller_name': seller.name,
                'approval_status': approval_status,
                'state': new_state,
                'ref': seller.ref,  # Supabase UUID
                'updated_at': fields.Datetime.now().isoformat(),
                'webhook_source': 'odoo_seller_module'
            }

            # Send webhook request
            headers = {
                'Content-Type': 'application/json',
                'x-odoo-webhook-token': webhook_token
            }

            _logger.info(f'🚀 GOATGOAT SELLER WEBHOOK - Sending approval sync for seller {seller.name} (ID: {seller.id})')
            _logger.info(f'📤 GOATGOAT SELLER WEBHOOK - Payload: {json.dumps(payload)}')

            response = requests.post(
                webhook_url,
                json=payload,
                headers=headers,
                timeout=30
            )

            if response.status_code == 200:
                _logger.info(f'✅ GOATGOAT SELLER WEBHOOK - Success for seller {seller.name}: {response.text}')
                # Mark as synced
                seller.sudo().write({'goatgoat_seller_synced': True})
            else:
                _logger.error(f'❌ GOATGOAT SELLER WEBHOOK - Failed for seller {seller.name}: {response.status_code} - {response.text}')

        except Exception as e:
            _logger.error(f'❌ GOATGOAT SELLER WEBHOOK - Exception for seller {seller.name}: {str(e)}')

    @api.model
    def test_seller_webhook_connection(self):
        """Test method to verify seller webhook connectivity"""
        try:
            webhook_url = self.env['ir.config_parameter'].sudo().get_param(
                'goatgoat_webhook.seller_approval_url',
                'https://oaynfzqjielnsipttzbs.supabase.co/functions/v1/seller-approval-webhook'
            )
            webhook_token = self.env['ir.config_parameter'].sudo().get_param(
                'goatgoat_webhook.token',
                'odoo-goatgoat-sync-2024'
            )

            # Send test payload
            test_payload = {
                'odoo_seller_id': 999999,
                'seller_name': 'Test Seller Connection',
                'approval_status': 'pending',
                'state': 'draft',
                'ref': 'TEST_SELLER_CONNECTION',
                'updated_at': fields.Datetime.now().isoformat(),
                'webhook_source': 'odoo_seller_test'
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

            _logger.info(f'🧪 GOATGOAT SELLER WEBHOOK TEST - Status: {response.status_code}, Response: {response.text}')
            return {
                'status_code': response.status_code,
                'response': response.text,
                'success': response.status_code == 200
            }

        except Exception as e:
            _logger.error(f'❌ GOATGOAT SELLER WEBHOOK TEST - Exception: {str(e)}')
            return {
                'status_code': 0,
                'response': str(e),
                'success': False
            }
