# Admin Panel Technical Specifications

**Project**: Goat Goat Flutter Web Admin Panel  
**Version**: 1.0  
**Target Completion**: 10 weeks from start date

---

## 🏗️ **DETAILED TECHNICAL ARCHITECTURE**

### **System Architecture Diagram**
```
┌─────────────────────────────────────────────────────────────────┐
│                    GOAT GOAT ECOSYSTEM                         │
├─────────────────────────────────────────────────────────────────┤
│  Mobile App (Flutter)           Admin Panel (Flutter Web)      │
│  ├── Customer Portal            ├── Review Moderation          │
│  ├── Seller Portal              ├── Notification Management    │
│  ├── Product Catalog            ├── User Management            │
│  ├── Shopping Cart              ├── Analytics Dashboard        │
│  └── Order History              └── System Administration      │
├─────────────────────────────────────────────────────────────────┤
│                    SHARED SERVICES LAYER                       │
│  ├── SupabaseService           ├── NotificationService         │
│  ├── OdooService               ├── OrderTrackingService        │
│  ├── ShoppingCartService       └── ProductReviewService        │
├─────────────────────────────────────────────────────────────────┤
│                    BACKEND INFRASTRUCTURE                       │
│  ├── Supabase Database         ├── Supabase Edge Functions     │
│  ├── Supabase Auth             ├── Supabase Storage            │
│  ├── Supabase Realtime         └── Fast2SMS Integration        │
├─────────────────────────────────────────────────────────────────┤
│                    EXTERNAL INTEGRATIONS                       │
│  ├── Odoo ERP System           ├── PhonePe Payment Gateway     │
│  ├── Fast2SMS Service          └── Google Maps API             │
└─────────────────────────────────────────────────────────────────┘
```

### **Admin Panel Specific Architecture**
```
Admin Panel (Flutter Web)
├── Authentication Layer
│   ├── Multi-factor Authentication
│   ├── Role-based Access Control
│   ├── Session Management
│   └── Audit Logging
├── UI Layer (Desktop Optimized)
│   ├── Responsive Layout System
│   ├── Keyboard Shortcuts
│   ├── Multi-window Support
│   └── Data Tables with Pagination
├── Business Logic Layer
│   ├── Admin Service Extensions
│   ├── Real-time Data Synchronization
│   ├── Bulk Operations
│   └── Analytics Processing
└── Data Layer
    ├── Shared Supabase Services
    ├── Admin-specific Queries
    ├── Caching Layer
    └── Real-time Subscriptions
```

---

## 🗄️ **DATABASE SCHEMA EXTENSIONS**

### **Admin User Management**
```sql
-- Admin users table
CREATE TABLE admin_users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  full_name TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('super_admin', 'moderator', 'support', 'analyst')),
  
  -- Permissions (JSONB for flexibility)
  permissions JSONB DEFAULT '{
    "review_moderation": false,
    "notification_management": false,
    "user_management": false,
    "analytics_access": false,
    "system_administration": false
  }'::jsonb,
  
  -- Security
  mfa_secret TEXT,
  mfa_enabled BOOLEAN DEFAULT false,
  password_reset_token TEXT,
  password_reset_expires TIMESTAMP WITH TIME ZONE,
  
  -- Status tracking
  last_login TIMESTAMP WITH TIME ZONE,
  login_attempts INTEGER DEFAULT 0,
  locked_until TIMESTAMP WITH TIME ZONE,
  is_active BOOLEAN DEFAULT true,
  
  -- Audit
  created_by UUID REFERENCES admin_users(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Admin sessions for security tracking
CREATE TABLE admin_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id UUID REFERENCES admin_users(id) ON DELETE CASCADE,
  session_token TEXT NOT NULL UNIQUE,
  
  -- Session metadata
  ip_address INET,
  user_agent TEXT,
  device_info JSONB,
  
  -- Session lifecycle
  expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
  last_activity TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  is_active BOOLEAN DEFAULT true,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Comprehensive audit logging
CREATE TABLE admin_audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id UUID REFERENCES admin_users(id),
  
  -- Action details
  action TEXT NOT NULL, -- 'approve_review', 'send_notification', 'update_user', etc.
  resource_type TEXT NOT NULL, -- 'product_review', 'notification', 'customer', etc.
  resource_id TEXT,
  
  -- Change tracking
  old_values JSONB,
  new_values JSONB,
  change_summary TEXT,
  
  -- Context
  ip_address INET,
  user_agent TEXT,
  session_id UUID REFERENCES admin_sessions(id),
  
  -- Additional metadata
  metadata JSONB DEFAULT '{}'::jsonb,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Admin dashboard widgets configuration
CREATE TABLE admin_dashboard_config (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id UUID REFERENCES admin_users(id) ON DELETE CASCADE,
  
  -- Dashboard layout
  widget_layout JSONB NOT NULL DEFAULT '[]'::jsonb,
  preferences JSONB DEFAULT '{
    "theme": "light",
    "notifications_enabled": true,
    "auto_refresh_interval": 30,
    "default_page_size": 25
  }'::jsonb,
  
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### **Enhanced Notification Management**
```sql
-- Notification campaigns (extending Phase 1.3)
ALTER TABLE notification_campaigns ADD COLUMN IF NOT EXISTS
  created_by_admin UUID REFERENCES admin_users(id);

ALTER TABLE notification_campaigns ADD COLUMN IF NOT EXISTS
  approval_status TEXT DEFAULT 'draft' CHECK (approval_status IN ('draft', 'pending_approval', 'approved', 'rejected'));

ALTER TABLE notification_campaigns ADD COLUMN IF NOT EXISTS
  approved_by UUID REFERENCES admin_users(id);

ALTER TABLE notification_campaigns ADD COLUMN IF NOT EXISTS
  approved_at TIMESTAMP WITH TIME ZONE;

-- Admin notification queue for internal notifications
CREATE TABLE admin_notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id UUID REFERENCES admin_users(id) ON DELETE CASCADE,
  
  -- Notification content
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  notification_type TEXT NOT NULL CHECK (notification_type IN ('info', 'warning', 'error', 'success')),
  priority TEXT DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
  
  -- Action details
  action_url TEXT,
  action_label TEXT,
  
  -- Status
  is_read BOOLEAN DEFAULT false,
  read_at TIMESTAMP WITH TIME ZONE,
  
  -- Auto-expire
  expires_at TIMESTAMP WITH TIME ZONE,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### **Review Moderation Enhancements**
```sql
-- Review moderation queue
CREATE TABLE review_moderation_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  review_id UUID REFERENCES product_reviews(id) ON DELETE CASCADE,
  
  -- Assignment
  assigned_to UUID REFERENCES admin_users(id),
  assigned_at TIMESTAMP WITH TIME ZONE,
  
  -- Priority and categorization
  priority TEXT DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
  category TEXT, -- 'spam', 'inappropriate', 'fake', 'quality_issue', etc.
  
  -- Moderation metadata
  auto_flagged BOOLEAN DEFAULT false,
  flag_reasons JSONB DEFAULT '[]'::jsonb,
  
  -- Status tracking
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'in_review', 'completed')),
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Review moderation history
CREATE TABLE review_moderation_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  review_id UUID REFERENCES product_reviews(id) ON DELETE CASCADE,
  admin_id UUID REFERENCES admin_users(id),
  
  -- Action details
  action TEXT NOT NULL CHECK (action IN ('approved', 'rejected', 'flagged', 'escalated')),
  reason TEXT,
  notes TEXT,
  
  -- Previous state
  previous_status TEXT,
  new_status TEXT,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

---

## 🔐 **SECURITY IMPLEMENTATION**

### **Authentication Service**
```dart
class AdminAuthService {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  // Multi-factor authentication
  Future<Map<String, dynamic>> authenticateAdmin({
    required String email,
    required String password,
    String? mfaCode,
  }) async {
    try {
      // 1. Verify credentials
      final adminUser = await _verifyAdminCredentials(email, password);
      if (adminUser == null) {
        return {'success': false, 'message': 'Invalid credentials'};
      }
      
      // 2. Check account status
      if (!adminUser['is_active']) {
        return {'success': false, 'message': 'Account is deactivated'};
      }
      
      // 3. Check for account lockout
      if (adminUser['locked_until'] != null) {
        final lockedUntil = DateTime.parse(adminUser['locked_until']);
        if (DateTime.now().isBefore(lockedUntil)) {
          return {'success': false, 'message': 'Account is temporarily locked'};
        }
      }
      
      // 4. Verify MFA if enabled
      if (adminUser['mfa_enabled'] == true) {
        if (mfaCode == null) {
          return {'success': false, 'message': 'MFA code required', 'requires_mfa': true};
        }
        
        final mfaValid = await _verifyMFACode(adminUser['mfa_secret'], mfaCode);
        if (!mfaValid) {
          return {'success': false, 'message': 'Invalid MFA code'};
        }
      }
      
      // 5. Create session
      final session = await _createAdminSession(adminUser['id']);
      
      // 6. Update last login
      await _updateLastLogin(adminUser['id']);
      
      // 7. Log successful login
      await _logAdminAction(
        adminId: adminUser['id'],
        action: 'login',
        resourceType: 'admin_session',
        resourceId: session['id'],
      );
      
      return {
        'success': true,
        'admin': adminUser,
        'session': session,
      };
      
    } catch (e) {
      return {'success': false, 'message': 'Authentication failed: $e'};
    }
  }
  
  // Role-based access control
  Future<bool> hasPermission(String adminId, String permission) async {
    try {
      final admin = await _supabase
          .from('admin_users')
          .select('role, permissions')
          .eq('id', adminId)
          .single();
      
      // Super admin has all permissions
      if (admin['role'] == 'super_admin') {
        return true;
      }
      
      // Check specific permission
      final permissions = admin['permissions'] as Map<String, dynamic>;
      return permissions[permission] == true;
      
    } catch (e) {
      return false;
    }
  }
  
  // Session management
  Future<bool> validateSession(String sessionToken) async {
    try {
      final session = await _supabase
          .from('admin_sessions')
          .select('*, admin_users(*)')
          .eq('session_token', sessionToken)
          .eq('is_active', true)
          .maybeSingle();
      
      if (session == null) return false;
      
      // Check expiration
      final expiresAt = DateTime.parse(session['expires_at']);
      if (DateTime.now().isAfter(expiresAt)) {
        await _deactivateSession(session['id']);
        return false;
      }
      
      // Update last activity
      await _updateSessionActivity(session['id']);
      
      return true;
      
    } catch (e) {
      return false;
    }
  }
  
  // Audit logging
  Future<void> logAdminAction({
    required String adminId,
    required String action,
    required String resourceType,
    String? resourceId,
    Map<String, dynamic>? oldValues,
    Map<String, dynamic>? newValues,
    String? changeSummary,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _supabase.from('admin_audit_log').insert({
        'admin_id': adminId,
        'action': action,
        'resource_type': resourceType,
        'resource_id': resourceId,
        'old_values': oldValues,
        'new_values': newValues,
        'change_summary': changeSummary,
        'metadata': metadata,
        'ip_address': await _getCurrentIPAddress(),
        'user_agent': await _getCurrentUserAgent(),
      });
    } catch (e) {
      print('Failed to log admin action: $e');
    }
  }
}
```

### **Permission-Based UI Components**
```dart
class PermissionGuard extends StatelessWidget {
  final String permission;
  final Widget child;
  final Widget? fallback;
  
  const PermissionGuard({
    Key? key,
    required this.permission,
    required this.child,
    this.fallback,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: AdminAuthService().hasPermission(
        AdminSession.currentAdminId,
        permission,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }
        
        if (snapshot.data == true) {
          return child;
        }
        
        return fallback ?? const SizedBox.shrink();
      },
    );
  }
}

// Usage example
PermissionGuard(
  permission: 'review_moderation',
  child: ElevatedButton(
    onPressed: () => _approveReview(),
    child: Text('Approve Review'),
  ),
  fallback: Text('Insufficient permissions'),
)
```

---

## 📱 **DESKTOP-OPTIMIZED UI COMPONENTS**

### **Responsive Layout System**
```dart
class AdminResponsiveLayout extends StatelessWidget {
  final Widget sidebar;
  final Widget content;
  final Widget? rightPanel;
  
  const AdminResponsiveLayout({
    Key? key,
    required this.sidebar,
    required this.content,
    this.rightPanel,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Ultra-wide desktop (1920px+)
        if (constraints.maxWidth >= 1920) {
          return Row(
            children: [
              SizedBox(width: 280, child: sidebar),
              Expanded(flex: 2, child: content),
              if (rightPanel != null)
                SizedBox(width: 320, child: rightPanel!),
            ],
          );
        }
        
        // Standard desktop (1366px+)
        if (constraints.maxWidth >= 1366) {
          return Row(
            children: [
              SizedBox(width: 240, child: sidebar),
              Expanded(child: content),
            ],
          );
        }
        
        // Tablet fallback
        return Column(
          children: [
            SizedBox(height: 60, child: _buildTabletHeader()),
            Expanded(child: content),
          ],
        );
      },
    );
  }
}
```

### **Advanced Data Table Component**
```dart
class AdminDataTable<T> extends StatefulWidget {
  final List<T> data;
  final List<AdminDataColumn<T>> columns;
  final Function(T)? onRowTap;
  final Function(List<T>)? onSelectionChanged;
  final bool allowMultiSelect;
  final int itemsPerPage;
  
  const AdminDataTable({
    Key? key,
    required this.data,
    required this.columns,
    this.onRowTap,
    this.onSelectionChanged,
    this.allowMultiSelect = false,
    this.itemsPerPage = 25,
  }) : super(key: key);
  
  @override
  State<AdminDataTable<T>> createState() => _AdminDataTableState<T>();
}

class _AdminDataTableState<T> extends State<AdminDataTable<T>> {
  int _currentPage = 0;
  String _sortColumn = '';
  bool _sortAscending = true;
  Set<T> _selectedItems = {};
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Table header with sorting
        _buildTableHeader(),
        
        // Table content
        Expanded(
          child: SingleChildScrollView(
            child: _buildTableContent(),
          ),
        ),
        
        // Pagination and selection info
        _buildTableFooter(),
      ],
    );
  }
  
  Widget _buildTableHeader() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          // Select all checkbox
          if (widget.allowMultiSelect)
            Checkbox(
              value: _selectedItems.length == widget.data.length,
              onChanged: _toggleSelectAll,
            ),
          
          // Column headers
          ...widget.columns.map((column) => _buildColumnHeader(column)),
        ],
      ),
    );
  }
}
```

### **Keyboard Shortcuts System**
```dart
class AdminKeyboardShortcuts extends StatelessWidget {
  final Widget child;
  
  const AdminKeyboardShortcuts({Key? key, required this.child}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: {
        // Global shortcuts
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyR): 
          RefreshIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyF): 
          SearchIntent(),
        LogicalKeySet(LogicalKeyboardKey.escape): 
          CancelIntent(),
        
        // Review moderation shortcuts
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyA): 
          ApproveIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyD): 
          RejectIntent(),
        
        // Navigation shortcuts
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.digit1): 
          NavigateToIntent('dashboard'),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.digit2): 
          NavigateToIntent('reviews'),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.digit3): 
          NavigateToIntent('notifications'),
      },
      child: Actions(
        actions: {
          RefreshIntent: CallbackAction<RefreshIntent>(
            onInvoke: (intent) => _handleRefresh(context),
          ),
          SearchIntent: CallbackAction<SearchIntent>(
            onInvoke: (intent) => _handleSearch(context),
          ),
          ApproveIntent: CallbackAction<ApproveIntent>(
            onInvoke: (intent) => _handleApprove(context),
          ),
        },
        child: child,
      ),
    );
  }
}
```

---

## 🔄 **REAL-TIME INTEGRATION**

### **Real-time Dashboard Updates**
```dart
class AdminRealtimeService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final Map<String, StreamSubscription> _subscriptions = {};
  
  void initializeRealtimeSubscriptions() {
    // Real-time review moderation queue
    _subscriptions['reviews'] = _supabase
        .from('product_reviews')
        .stream(primaryKey: ['id'])
        .eq('moderation_status', 'pending')
        .listen((data) {
          AdminEventBus.instance.emit('reviews_updated', data);
        });
    
    // Real-time notification delivery status
    _subscriptions['notifications'] = _supabase
        .from('notification_logs')
        .stream(primaryKey: ['id'])
        .listen((data) {
          AdminEventBus.instance.emit('notifications_updated', data);
        });
    
    // Real-time order updates
    _subscriptions['orders'] = _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .listen((data) {
          AdminEventBus.instance.emit('orders_updated', data);
        });
  }
  
  void dispose() {
    _subscriptions.values.forEach((subscription) => subscription.cancel());
    _subscriptions.clear();
  }
}

// Event bus for cross-component communication
class AdminEventBus {
  static final AdminEventBus instance = AdminEventBus._internal();
  AdminEventBus._internal();
  
  final Map<String, List<Function(dynamic)>> _listeners = {};
  
  void emit(String event, dynamic data) {
    _listeners[event]?.forEach((listener) => listener(data));
  }
  
  void on(String event, Function(dynamic) listener) {
    _listeners[event] ??= [];
    _listeners[event]!.add(listener);
  }
  
  void off(String event, Function(dynamic) listener) {
    _listeners[event]?.remove(listener);
  }
}
```

---

---

## 🎯 **SPECIFIC FEATURE IMPLEMENTATIONS**

### **Review Moderation Interface**
```dart
class AdminReviewModerationScreen extends StatefulWidget {
  @override
  State<AdminReviewModerationScreen> createState() => _AdminReviewModerationScreenState();
}

class _AdminReviewModerationScreenState extends State<AdminReviewModerationScreen> {
  final AdminReviewService _reviewService = AdminReviewService();
  List<Map<String, dynamic>> _pendingReviews = [];
  Set<String> _selectedReviews = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPendingReviews();
    _setupRealtimeUpdates();
  }

  @override
  Widget build(BuildContext context) {
    return AdminResponsiveLayout(
      sidebar: AdminSidebar(currentPage: 'reviews'),
      content: Column(
        children: [
          // Header with bulk actions
          _buildModerationHeader(),

          // Filters and search
          _buildFiltersBar(),

          // Reviews table
          Expanded(
            child: AdminDataTable<Map<String, dynamic>>(
              data: _pendingReviews,
              columns: [
                AdminDataColumn(
                  label: 'Product',
                  getValue: (review) => review['meat_products']['name'],
                  width: 200,
                ),
                AdminDataColumn(
                  label: 'Customer',
                  getValue: (review) => review['customers']['full_name'],
                  width: 150,
                ),
                AdminDataColumn(
                  label: 'Rating',
                  getValue: (review) => review['rating'],
                  width: 80,
                  builder: (review) => _buildRatingStars(review['rating']),
                ),
                AdminDataColumn(
                  label: 'Review',
                  getValue: (review) => review['review_text'],
                  width: 300,
                  builder: (review) => _buildReviewPreview(review),
                ),
                AdminDataColumn(
                  label: 'Date',
                  getValue: (review) => review['created_at'],
                  width: 120,
                  builder: (review) => _buildDateCell(review['created_at']),
                ),
                AdminDataColumn(
                  label: 'Actions',
                  getValue: (review) => '',
                  width: 200,
                  builder: (review) => _buildActionButtons(review),
                ),
              ],
              allowMultiSelect: true,
              onSelectionChanged: (selected) {
                setState(() {
                  _selectedReviews = selected.map((r) => r['id'] as String).toSet();
                });
              },
            ),
          ),
        ],
      ),
      rightPanel: _buildReviewDetailPanel(),
    );
  }

  Widget _buildModerationHeader() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          Text(
            'Review Moderation',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Spacer(),
          if (_selectedReviews.isNotEmpty) ...[
            ElevatedButton.icon(
              onPressed: () => _bulkApproveReviews(),
              icon: Icon(Icons.check),
              label: Text('Approve Selected (${_selectedReviews.length})'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            ),
            SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () => _bulkRejectReviews(),
              icon: Icon(Icons.close),
              label: Text('Reject Selected (${_selectedReviews.length})'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _bulkApproveReviews() async {
    final confirmed = await _showBulkActionDialog(
      'Approve Reviews',
      'Are you sure you want to approve ${_selectedReviews.length} reviews?',
    );

    if (confirmed) {
      await _reviewService.bulkModerateReviews(
        reviewIds: _selectedReviews.toList(),
        action: 'approved',
        reason: 'Bulk approval',
      );

      _loadPendingReviews();
      setState(() => _selectedReviews.clear());
    }
  }
}
```

### **Notification Management Interface**
```dart
class AdminNotificationManagementScreen extends StatefulWidget {
  @override
  State<AdminNotificationManagementScreen> createState() => _AdminNotificationManagementScreenState();
}

class _AdminNotificationManagementScreenState extends State<AdminNotificationManagementScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return AdminResponsiveLayout(
      sidebar: AdminSidebar(currentPage: 'notifications'),
      content: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  'Notification Management',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Spacer(),
                ElevatedButton.icon(
                  onPressed: () => _openNotificationComposer(),
                  icon: Icon(Icons.add),
                  label: Text('Send Custom Notification'),
                ),
              ],
            ),
          ),

          // Tabs
          TabBar(
            controller: _tabController,
            tabs: [
              Tab(text: 'Dashboard'),
              Tab(text: 'Templates'),
              Tab(text: 'Campaigns'),
              Tab(text: 'Analytics'),
            ],
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildNotificationDashboard(),
                _buildTemplateManagement(),
                _buildCampaignManagement(),
                _buildNotificationAnalytics(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationDashboard() {
    return GridView.count(
      crossAxisCount: 4,
      padding: EdgeInsets.all(16),
      children: [
        _buildMetricCard('Total Sent Today', '1,234', Icons.send, Colors.blue),
        _buildMetricCard('Delivery Rate', '98.5%', Icons.check_circle, Colors.green),
        _buildMetricCard('Failed Deliveries', '18', Icons.error, Colors.red),
        _buildMetricCard('Pending Queue', '45', Icons.schedule, Colors.orange),
      ],
    );
  }

  Widget _buildTemplateManagement() {
    return Column(
      children: [
        // Template actions
        Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              ElevatedButton.icon(
                onPressed: () => _createNewTemplate(),
                icon: Icon(Icons.add),
                label: Text('New Template'),
              ),
              SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _importTemplates(),
                icon: Icon(Icons.upload),
                label: Text('Import Templates'),
              ),
            ],
          ),
        ),

        // Templates list
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _loadNotificationTemplates(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              final templates = snapshot.data ?? [];
              return ListView.builder(
                itemCount: templates.length,
                itemBuilder: (context, index) {
                  final template = templates[index];
                  return _buildTemplateCard(template);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
```

---

## 🚀 **DEPLOYMENT STRATEGY**

### **Infrastructure Setup**
```yaml
# docker-compose.admin.yml
version: '3.8'
services:
  admin-panel:
    build:
      context: .
      dockerfile: Dockerfile.admin
    ports:
      - "8080:80"
    environment:
      - SUPABASE_URL=${SUPABASE_URL}
      - SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}
      - ADMIN_DOMAIN=admin.goatgoat.com
    volumes:
      - ./nginx.admin.conf:/etc/nginx/nginx.conf
    depends_on:
      - nginx-proxy

  nginx-proxy:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.proxy.conf:/etc/nginx/nginx.conf
      - ./ssl:/etc/nginx/ssl
```

### **Build Configuration**
```dockerfile
# Dockerfile.admin
FROM cirrusci/flutter:stable AS build

# Copy source code
COPY . /app
WORKDIR /app

# Build admin panel
RUN flutter config --enable-web
RUN flutter build web --target=lib/main_admin.dart --release

# Production image
FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
COPY nginx.admin.conf /etc/nginx/nginx.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

### **CI/CD Pipeline**
```yaml
# .github/workflows/admin-deploy.yml
name: Deploy Admin Panel

on:
  push:
    branches: [main]
    paths: ['lib_admin/**', 'lib/main_admin.dart']

jobs:
  deploy-admin:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.16.0'

      - name: Build Admin Panel
        run: |
          flutter config --enable-web
          flutter build web --target=lib/main_admin.dart --release

      - name: Deploy to Admin Subdomain
        run: |
          # Deploy to admin.goatgoat.com
          aws s3 sync build/web s3://admin-goatgoat-com --delete
          aws cloudfront create-invalidation --distribution-id ${{ secrets.ADMIN_CLOUDFRONT_ID }} --paths "/*"
```

### **Domain Configuration**
```nginx
# nginx.proxy.conf
server {
    listen 80;
    server_name admin.goatgoat.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name admin.goatgoat.com;

    ssl_certificate /etc/nginx/ssl/admin.goatgoat.com.crt;
    ssl_certificate_key /etc/nginx/ssl/admin.goatgoat.com.key;

    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains";

    # Admin panel restrictions
    allow 10.0.0.0/8;     # Internal network
    allow 192.168.0.0/16; # Private network
    deny all;             # Deny all other IPs

    location / {
        proxy_pass http://admin-panel:80;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

---

## 📊 **TESTING STRATEGY**

### **Integration Testing**
```dart
// test/admin_integration_test.dart
void main() {
  group('Admin Panel Integration Tests', () {
    testWidgets('Review moderation workflow', (tester) async {
      // 1. Login as admin
      await tester.pumpWidget(AdminApp());
      await tester.enterText(find.byKey(Key('email')), 'admin@goatgoat.com');
      await tester.enterText(find.byKey(Key('password')), 'password');
      await tester.tap(find.byKey(Key('login')));
      await tester.pumpAndSettle();

      // 2. Navigate to review moderation
      await tester.tap(find.text('Reviews'));
      await tester.pumpAndSettle();

      // 3. Approve a review
      await tester.tap(find.byKey(Key('approve_review_1')));
      await tester.pumpAndSettle();

      // 4. Verify review is approved in mobile app
      final mobileApp = await IntegrationTestWidgetsFlutterBinding.ensureInitialized()
          .defaultBinaryMessenger
          .send('test_mobile_app', utf8.encode('check_review_status'));

      expect(utf8.decode(mobileApp!), contains('approved'));
    });

    testWidgets('Notification sending workflow', (tester) async {
      // Test notification creation and delivery
      await tester.pumpWidget(AdminApp());

      // Login and navigate to notifications
      await _loginAsAdmin(tester);
      await tester.tap(find.text('Notifications'));
      await tester.pumpAndSettle();

      // Create custom notification
      await tester.tap(find.text('Send Custom Notification'));
      await tester.enterText(find.byKey(Key('notification_title')), 'Test Notification');
      await tester.enterText(find.byKey(Key('notification_message')), 'This is a test');
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();

      // Verify notification appears in logs
      expect(find.text('Notification sent successfully'), findsOneWidget);
    });
  });
}
```

### **Performance Testing**
```dart
// test/admin_performance_test.dart
void main() {
  group('Admin Panel Performance Tests', () {
    test('Review moderation page load time', () async {
      final stopwatch = Stopwatch()..start();

      // Load 1000 pending reviews
      final reviews = await AdminReviewService().getPendingReviews(limit: 1000);

      stopwatch.stop();

      // Should load within 2 seconds
      expect(stopwatch.elapsedMilliseconds, lessThan(2000));
      expect(reviews.length, equals(1000));
    });

    test('Bulk review moderation performance', () async {
      final stopwatch = Stopwatch()..start();

      // Approve 100 reviews in bulk
      await AdminReviewService().bulkModerateReviews(
        reviewIds: List.generate(100, (i) => 'review_$i'),
        action: 'approved',
        reason: 'Performance test',
      );

      stopwatch.stop();

      // Should complete within 5 seconds
      expect(stopwatch.elapsedMilliseconds, lessThan(5000));
    });
  });
}
```

---

## 📈 **MONITORING & ANALYTICS**

### **Admin Panel Monitoring**
```dart
class AdminMonitoringService {
  static void trackAdminAction(String action, Map<String, dynamic> metadata) {
    // Track admin actions for analytics
    Supabase.instance.client.from('admin_analytics').insert({
      'admin_id': AdminSession.currentAdminId,
      'action': action,
      'metadata': metadata,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  static void trackPerformanceMetric(String metric, double value) {
    // Track performance metrics
    Supabase.instance.client.from('admin_performance_metrics').insert({
      'metric_name': metric,
      'value': value,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
}
```

### **Error Tracking**
```dart
class AdminErrorHandler {
  static void handleError(dynamic error, StackTrace stackTrace) {
    // Log error to Supabase
    Supabase.instance.client.from('admin_error_logs').insert({
      'admin_id': AdminSession.currentAdminId,
      'error_message': error.toString(),
      'stack_trace': stackTrace.toString(),
      'timestamp': DateTime.now().toIso8601String(),
    });

    // Send to external monitoring (optional)
    // Sentry.captureException(error, stackTrace: stackTrace);
  }
}
```

---

## 🎯 **SUCCESS METRICS & KPIs**

### **Technical Metrics**
- **Page Load Time**: < 2 seconds for all admin pages
- **API Response Time**: < 500ms for all admin operations
- **Uptime**: 99.9% availability
- **Error Rate**: < 0.1% of all admin actions

### **Business Metrics**
- **Review Moderation Efficiency**: 50% reduction in moderation time
- **Notification Delivery Rate**: 98%+ successful delivery
- **Admin User Satisfaction**: 4.5/5 rating
- **Support Ticket Reduction**: 30% fewer customer support tickets

### **Security Metrics**
- **Failed Login Attempts**: Monitor and alert on suspicious activity
- **Session Security**: All sessions expire within 8 hours
- **Audit Coverage**: 100% of admin actions logged
- **Access Control**: Zero unauthorized access incidents

---

**IMPLEMENTATION TIMELINE**: 10 weeks total with phased rollout and comprehensive testing to ensure zero disruption to existing mobile app functionality.
