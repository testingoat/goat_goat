# Goat Goat - Meat Marketplace Flutter Application

A comprehensive meat marketplace Flutter application with dual-mode architecture supporting both sellers and customers. Features real-time Supabase backend integration, Odoo ERP synchronization, and advanced e-commerce functionality.

## 🚀 **Quick Start**

### Prerequisites
- Flutter 3.8.1+ installed
- Dart 3.8.1+ installed
- Supabase account and project setup
- Android Studio / VS Code with Flutter extensions

### Installation
```bash
# Clone the repository
git clone <repository-url>
cd goat_goat

# Install dependencies
flutter pub get

# Run the application
flutter run -d windows  # or android/ios
```

## 📱 **Features**

### **Seller Portal**
- 📊 Product management with approval workflows
- 🔄 Real-time Odoo ERP synchronization
- 📱 Phone-based OTP authentication
- ✅ Product activation/deactivation controls
- 🔍 Advanced filtering and sorting
- ✏️ Product editing with re-approval workflow

### **Customer Portal**
- 🛒 Product browsing and shopping cart
- 📱 Phone-based registration and login
- 🔍 Product search and filtering
- 🛍️ Real-time cart management
- 👤 Profile management

### **System Features**
- 🔐 Secure authentication via Fast2SMS OTP
- 💾 Supabase backend with PostgreSQL
- 🏢 Odoo ERP integration for business operations
- 💳 PhonePe payment gateway integration
- 🎨 Modern emerald-themed UI design

## 🏗️ **Architecture**

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Flutter App   │◄──►│   Supabase       │◄──►│   Odoo ERP      │
│                 │    │   - Database     │    │   - Products    │
│ - Seller Portal │    │   - Edge Funcs   │    │   - Customers   │
│ - Customer Port │    │   - Storage      │    │   - Sync        │
│ - OTP Auth      │    │   - RLS Policies │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## 📚 **Documentation**

- **[Comprehensive Technical Documentation](COMPREHENSIVE_PROJECT_DOCUMENTATION.md)** - Complete system reference
- **[Documentation Analysis Report](DOCUMENTATION_ANALYSIS_REPORT.md)** - Documentation review and gaps analysis
- **[Odoo Integration Documentation](ODOO_INTEGRATION_FIX_DOCUMENTATION.md)** - Detailed Odoo integration guide
- **[Legacy Knowledge Base](Knowledgebase.md)** - Historical documentation and guidelines

## 🛠️ **Development**

### **Project Structure**
```
lib/
├── main.dart                 # Application entry point
├── screens/                  # UI screens
│   ├── product_management_screen.dart
│   ├── customer_portal_screen.dart
│   └── ...
├── services/                 # Business logic services
│   ├── odoo_service.dart
│   ├── shopping_cart_service.dart
│   └── ...
├── widgets/                  # Reusable UI components
└── config/                   # Configuration files
```

### **Key Technologies**
- **Frontend**: Flutter 3.8.1+ (Dart)
- **Backend**: Supabase (PostgreSQL + Edge Functions)
- **ERP**: Odoo Integration
- **SMS**: Fast2SMS API
- **Payment**: PhonePe Gateway

## 🔧 **Configuration**

### **Environment Setup**
1. Create Supabase project
2. Configure environment variables in Supabase secrets
3. Deploy edge functions
4. Set up Odoo ERP connection
5. Configure Fast2SMS API key

### **Required Secrets**
- `SUPABASE_URL` - Supabase project URL
- `SUPABASE_ANON_KEY` - Public API key
- `FAST2SMS_API_KEY` - SMS service API key
- `WEBHOOK_API_KEY` - Webhook authentication
- `ODOO_URL`, `ODOO_DB`, `ODOO_USERNAME`, `ODOO_PASSWORD` - Odoo credentials

## 🚀 **Deployment**

### **Flutter Build**
```bash
# Development
flutter run -d windows

# Production builds
flutter build windows --release
flutter build android --release
flutter build ios --release
```

### **Backend Deployment**
```bash
# Deploy Supabase functions
npx supabase functions deploy product-sync-webhook
npx supabase functions deploy odoo-status-sync
```

## 🧪 **Testing**

The project includes comprehensive testing scripts:
- `test_customer_portal_complete.js` - Customer portal testing
- `test_status_sync_webhook.js` - Odoo integration testing
- Various integration test scripts

## 📞 **Support**

- **Project ID**: oaynfzqjielnsipttzbs
- **Supabase URL**: https://oaynfzqjielnsipttzbs.supabase.co
- **Documentation**: See comprehensive documentation files
- **Issues**: Check documentation analysis report for known issues

## 📄 **License**

This project is proprietary software. All rights reserved.

---

**Last Updated**: 2025-07-27
**Version**: 2.0
**Status**: Production Ready
