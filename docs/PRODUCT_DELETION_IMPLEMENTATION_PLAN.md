# Product Deletion Implementation Plan

## Executive Summary
This document provides a comprehensive phase-wise implementation plan for product deletion functionality in the Goat Goat Flutter application, ensuring data consistency between Supabase and Odoo systems while maintaining audit trails and recovery mechanisms.

**Status**: 📋 **PLANNING PHASE ONLY**  
**Risk Level**: 🟡 **MEDIUM RISK** - Requires careful Odoo integration  
**Implementation Approach**: Zero-risk pattern with feature flags and gradual rollout

---

## Phase 1: Database Design for Soft Deletion

### 1.1 Database Schema Extensions
**Target**: Supabase `meat_products` table

```sql
-- Add soft deletion fields to meat_products table
ALTER TABLE public.meat_products 
ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS deletion_reason TEXT,
ADD COLUMN IF NOT EXISTS deleted_by UUID REFERENCES auth.users(id),
ADD COLUMN IF NOT EXISTS deletion_type TEXT CHECK (deletion_type IN ('seller_request', 'admin_action', 'system_cleanup')),
ADD COLUMN IF NOT EXISTS is_recoverable BOOLEAN DEFAULT true;

-- Add comments for documentation
COMMENT ON COLUMN public.meat_products.deleted_at IS 'Timestamp when product was soft deleted';
COMMENT ON COLUMN public.meat_products.deletion_reason IS 'Reason for product deletion';
COMMENT ON COLUMN public.meat_products.deleted_by IS 'User who initiated the deletion';
COMMENT ON COLUMN public.meat_products.deletion_type IS 'Type of deletion: seller_request, admin_action, system_cleanup';
COMMENT ON COLUMN public.meat_products.is_recoverable IS 'Whether the product can be recovered';
```

### 1.2 Audit Trail Enhancement
**Target**: Create dedicated product deletion audit table

```sql
-- Create product deletion audit table
CREATE TABLE IF NOT EXISTS public.product_deletion_audit (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID REFERENCES meat_products(id),
  seller_id UUID REFERENCES sellers(id),
  deletion_type TEXT NOT NULL,
  deletion_reason TEXT,
  deleted_by UUID REFERENCES auth.users(id),
  deleted_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  odoo_sync_status TEXT DEFAULT 'pending',
  odoo_sync_at TIMESTAMP WITH TIME ZONE,
  recovery_deadline TIMESTAMP WITH TIME ZONE,
  metadata JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add RLS policies
ALTER TABLE public.product_deletion_audit ENABLE ROW LEVEL SECURITY;

-- Policy: Sellers can view their own product deletion records
CREATE POLICY "Sellers can view own product deletions" ON public.product_deletion_audit
  FOR SELECT USING (seller_id = auth.uid());

-- Policy: Admins can view all deletion records
CREATE POLICY "Admins can view all product deletions" ON public.product_deletion_audit
  FOR ALL USING (auth.jwt() ->> 'role' = 'admin');
```

### 1.3 Database Indexes
```sql
-- Performance indexes for deletion queries
CREATE INDEX IF NOT EXISTS idx_meat_products_deleted_at ON public.meat_products(deleted_at);
CREATE INDEX IF NOT EXISTS idx_meat_products_deletion_type ON public.meat_products(deletion_type);
CREATE INDEX IF NOT EXISTS idx_product_deletion_audit_product_id ON public.product_deletion_audit(product_id);
CREATE INDEX IF NOT EXISTS idx_product_deletion_audit_seller_id ON public.product_deletion_audit(seller_id);
```

---

## Phase 2: Seller Portal UI Implementation

### 2.1 Product Management Screen Enhancement
**File**: `lib/screens/seller_product_management_screen.dart`

#### Features to Add:
- **Delete Button**: Add delete action to product cards/list items
- **Confirmation Dialog**: Multi-step confirmation with reason selection
- **Bulk Delete**: Allow multiple product selection for batch deletion
- **Deletion History**: Show deleted products with recovery options

#### UI Components:
```dart
// Delete button with confirmation
IconButton(
  icon: Icon(Icons.delete_outline, color: Colors.red[600]),
  onPressed: () => _showDeleteConfirmation(product),
)

// Confirmation dialog with reason selection
_showDeleteConfirmation(Map<String, dynamic> product) {
  // Multi-step dialog:
  // 1. Confirm deletion intent
  // 2. Select deletion reason
  // 3. Final confirmation with consequences
}
```

### 2.2 Deletion Reason Categories
```dart
enum DeletionReason {
  outOfStock('Out of Stock - Permanently'),
  qualityIssues('Quality Issues'),
  priceChange('Major Price Change Required'),
  seasonalItem('Seasonal Item - End of Season'),
  supplierIssues('Supplier No Longer Available'),
  regulatoryIssues('Regulatory/Compliance Issues'),
  businessDecision('Business Strategy Change'),
  other('Other - Please Specify');
}
```

### 2.3 Recovery Interface
- **Deleted Products Tab**: Show soft-deleted products
- **Recovery Actions**: One-click recovery within deadline
- **Permanent Deletion**: Admin-only after recovery deadline

---

## Phase 3: Odoo Integration Strategy

### 3.1 Webhook Enhancement
**File**: `supabase/functions/product-deletion-webhook/index.ts`

#### Deletion Sync Process:
1. **Soft Delete in Supabase**: Mark product as deleted
2. **Odoo Notification**: Send deletion webhook to Odoo
3. **Odoo Response**: Confirm deletion or report conflicts
4. **Status Update**: Update sync status in Supabase

#### Webhook Payload:
```typescript
interface ProductDeletionPayload {
  product_id: string;
  seller_id: string;
  odoo_product_id: number;
  deletion_type: 'soft_delete' | 'permanent_delete';
  deletion_reason: string;
  deleted_by: string;
  recovery_deadline: string;
  metadata: {
    has_active_orders: boolean;
    inventory_count: number;
    last_sold_date: string;
  };
}
```

### 3.2 Odoo Conflict Resolution
**Scenarios to Handle**:
- **Active Orders**: Product has pending orders in Odoo
- **Inventory Issues**: Non-zero inventory in Odoo
- **Pricing Dependencies**: Product used in pricing calculations
- **Promotional Campaigns**: Product part of active promotions

#### Resolution Strategy:
```typescript
// Conflict resolution workflow
if (odooResponse.conflicts.length > 0) {
  // Mark as 'deletion_pending' instead of 'deleted'
  // Notify seller of conflicts
  // Provide resolution options
  // Retry deletion after conflicts resolved
}
```

### 3.3 Bidirectional Sync
- **Odoo → Supabase**: Handle products deleted in Odoo
- **Conflict Detection**: Identify sync discrepancies
- **Reconciliation**: Automated conflict resolution where possible

---

## Phase 4: Admin Approval Workflow (Optional)

### 4.1 Admin Dashboard Integration
**Consideration**: Whether product deletions require admin approval

#### Approval Workflow Options:
1. **Immediate Deletion**: Sellers can delete immediately (current plan)
2. **Admin Approval**: Deletions require admin review
3. **Hybrid Approach**: High-value products require approval

### 4.2 Admin Interface Features
- **Deletion Requests**: Queue of pending deletion requests
- **Bulk Approval**: Approve multiple deletions at once
- **Override Capability**: Admin can override seller deletions
- **Analytics**: Deletion patterns and trends

---

## Phase 5: Audit Trail and Recovery Mechanisms

### 5.1 Comprehensive Audit Logging
**Service**: `ProductDeletionAuditService`

#### Audit Events:
- Product deletion initiated
- Deletion reason provided
- Odoo sync attempted/completed
- Recovery performed
- Permanent deletion executed

### 5.2 Recovery Mechanisms
#### Recovery Timeline:
- **0-7 days**: Seller self-recovery
- **7-30 days**: Admin-assisted recovery
- **30+ days**: Permanent deletion (data retention policy)

#### Recovery Process:
```dart
class ProductRecoveryService {
  Future<bool> recoverProduct(String productId) async {
    // 1. Validate recovery eligibility
    // 2. Check Odoo conflicts
    // 3. Restore product status
    // 4. Update audit trail
    // 5. Notify relevant parties
  }
}
```

### 5.3 Data Retention Policy
- **Soft Deleted Products**: Retained for 30 days
- **Audit Records**: Retained for 2 years
- **Recovery Data**: Retained for 90 days after permanent deletion

---

## Impact Analysis

### 5.1 Existing Orders Impact
**Critical Consideration**: Products with active orders

#### Mitigation Strategy:
- **Order Status Check**: Verify no pending orders before deletion
- **Grace Period**: Allow order completion before deletion
- **Alternative Products**: Suggest replacements for deleted products

### 5.2 Customer Favorites Impact
**User Experience**: Customers who favorited deleted products

#### Handling Approach:
- **Notification**: Inform customers of product unavailability
- **Recommendations**: Suggest similar products
- **Wishlist Management**: Remove from wishlists with notification

### 5.3 Inventory Synchronization
**Data Consistency**: Ensure Supabase and Odoo inventory alignment

#### Sync Strategy:
- **Pre-deletion Validation**: Check inventory status
- **Inventory Adjustment**: Handle remaining stock
- **Cost Accounting**: Update financial records

---

## Technical Implementation Details

### 6.1 Service Architecture
```dart
// Core deletion service
class ProductDeletionService {
  Future<DeletionResult> deleteProduct({
    required String productId,
    required String sellerId,
    required DeletionReason reason,
    String? customReason,
  });
  
  Future<List<DeletedProduct>> getDeletedProducts(String sellerId);
  Future<bool> recoverProduct(String productId);
  Future<bool> permanentlyDeleteProduct(String productId);
}
```

### 6.2 Error Handling
- **Network Failures**: Retry mechanism for Odoo sync
- **Partial Failures**: Handle Supabase success + Odoo failure
- **Rollback Capability**: Undo deletion if sync fails

### 6.3 Performance Considerations
- **Batch Operations**: Efficient bulk deletion processing
- **Background Jobs**: Async Odoo synchronization
- **Caching Strategy**: Cache deletion status for UI performance

---

## Testing Strategy

### 7.1 Unit Testing
- Product deletion service methods
- Odoo webhook integration
- Recovery mechanisms
- Audit trail generation

### 7.2 Integration Testing
- End-to-end deletion workflow
- Supabase ↔ Odoo synchronization
- Error scenarios and rollback
- Performance under load

### 7.3 User Acceptance Testing
- Seller deletion workflow
- Admin approval process
- Recovery functionality
- Customer impact scenarios

---

## Deployment Plan

### 8.1 Feature Flag Implementation
```dart
class FeatureFlags {
  static const bool enableProductDeletion = false; // Start disabled
  static const bool enableBulkDeletion = false;
  static const bool enableAdminApproval = false;
  static const bool enableAutoRecovery = false;
}
```

### 8.2 Gradual Rollout
1. **Phase A**: Internal testing with feature flags
2. **Phase B**: Limited seller beta testing
3. **Phase C**: Full rollout with monitoring
4. **Phase D**: Advanced features (bulk, admin approval)

### 8.3 Monitoring and Alerts
- **Deletion Rate Monitoring**: Track deletion patterns
- **Sync Failure Alerts**: Odoo integration issues
- **Recovery Rate Tracking**: Success of recovery operations
- **Performance Metrics**: Deletion operation performance

---

## Risk Mitigation

### 9.1 Data Loss Prevention
- **Soft Deletion Only**: No immediate permanent deletion
- **Multiple Confirmations**: Prevent accidental deletions
- **Audit Trail**: Complete deletion history
- **Recovery Window**: 30-day recovery period

### 9.2 Business Continuity
- **Graceful Degradation**: System works if Odoo is unavailable
- **Rollback Capability**: Undo deletions if needed
- **Alternative Workflows**: Manual processes as backup

### 9.3 Integration Risks
- **Odoo Compatibility**: Ensure webhook compatibility
- **Version Management**: Handle Odoo version changes
- **API Rate Limits**: Respect Odoo API constraints

---

## Success Criteria

### 10.1 Functional Requirements
- ✅ Sellers can delete products with confirmation
- ✅ Deletion reasons are captured and stored
- ✅ Odoo synchronization works reliably
- ✅ Recovery mechanism functions correctly
- ✅ Audit trail is comprehensive

### 10.2 Performance Requirements
- ✅ Deletion completes within 5 seconds
- ✅ Odoo sync completes within 30 seconds
- ✅ Recovery operations complete within 10 seconds
- ✅ UI remains responsive during operations

### 10.3 Business Requirements
- ✅ Zero data loss incidents
- ✅ 99.9% Odoo sync success rate
- ✅ <1% accidental deletion rate
- ✅ Customer satisfaction maintained

---

## Conclusion

The product deletion functionality requires careful implementation with strong emphasis on data integrity, audit trails, and recovery mechanisms. The phased approach ensures minimal risk while providing comprehensive deletion capabilities that meet business requirements.

**Next Steps**:
1. Stakeholder review and approval
2. Technical architecture finalization
3. Development timeline planning
4. Resource allocation
5. Implementation kickoff

**Estimated Timeline**: 6-8 weeks for complete implementation
**Resource Requirements**: 1 senior developer, 1 QA engineer, DevOps support
**Dependencies**: Odoo API documentation, stakeholder approvals
