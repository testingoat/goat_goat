{
    'name': 'GoatGoat Webhook Integration',
    'version': '1.0.0',
    'category': 'Integration',
    'summary': 'Webhook integration for GoatGoat product approval sync',
    'description': '''
        This module automatically sends webhook notifications to GoatGoat Supabase
        when product approval status changes in Odoo.
        
        Features:
        - Automatic webhook calls on product state changes
        - Configurable webhook URL and authentication
        - Error handling and logging
        - Support for product approval workflow
    ''',
    'author': 'GoatGoat Team',
    'website': 'https://goatgoat.info',
    'depends': ['base', 'product'],
    'data': [
        'data/webhook_config.xml',
    ],
    'installable': True,
    'auto_install': False,
    'application': False,
}
