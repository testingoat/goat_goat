## GoatGoat Flutter App: Seller & Customer Portals – Bug/Feature Analysis and Zero‑Risk Fix Plan

Author: Custom AI Agent (GPT‑5 based) • Date: 2025‑08‑14

### Guiding principles
- Zero‑risk, backward‑compatible changes only; composition-over-modification
- No core file changes without explicit approval (main.dart, supabase_service.dart, odoo_service.dart)
- Preserve existing Odoo approval workflows; no direct write operations to Odoo from Admin/mobile beyond existing edge-webhook patterns
- Use feature flags where behavior changes UI/flow
- Tests and safe verification runs recommended post changes

---

## SELLER PORTAL

### 1) Shop Open/Close Status – Missing/Unwired (Bug)
- Observed: No explicit is_open field usage surfaced in UI; not found in SupabaseService search. Dashboard shows status badges for seller approval/product approval but not shop open/closed.
- Files: seller_dashboard_screen.dart, supabase_service.dart (no is_open API)
- Impact: Sellers can’t mark shop availability; Customer ETA/availability may mislead.
- Proposed fix (UI-only, zero-risk):
  - Add non-persistent toggle in SellerDashboard UI with a local flag stored under sellers.extra JSONB via updateSeller (no schema change). Key: settings.is_open: true/false.
  - Reflect state in a chip on dashboard; expose to catalog ETA later via read-only (future feature flag).
- Change plan:
  - Add read/write helpers: SupabaseService.updateSeller(sellerId, {"extra": jsonb_set(extra,'{settings,is_open}', to_jsonb(value), true)}) – implement via client merge (no raw SQL). If unsafe, store under local SharedPreferences for seller and annotate as temporary. Mark server write under feature flag kSellerOpenClose.

### 2) Seller not created in Odoo (Bug)
- Observed: SellerSyncService exists but isn’t called on registration; seller_registration_screen.dart only inserts into sellers and returns.
- Files: seller_registration_screen.dart (no SellerSyncService usage), services/seller_sync_service.dart.
- Root cause: Missing call to syncSellerToOdoo after insert. Approval remains local only.
- Fix (non-breaking): After successful insert in OTP flow (OTPVerificationScreen._handleRegistration) or inside OTPServiceFallback.registerSeller, call SellerSyncService.syncSellerToOdoo(seller).
  - Prefer composition: call from OTPVerificationScreen after navigation decision to avoid modifying core OTP service.
- Validation: Show SnackBar “Seller submitted for approval” but don’t block UX if webhook fails.

### 3) Before vendor approval, disable Add Product and Manage Products (Bug)
- Observed: SellerDashboard “Add Product” and “Manage Products” always enabled.
- Files: seller_dashboard_screen.dart
- Fix: Gate buttons when seller.approval_status != 'approved'. Show tooltip/snackbar explaining pending approval. Keep view-only stats working.

### 4) Add Product form – Meat/Livestock selection, image rules, category, UOM (Feature)
- Observed: ProductManagementScreen -> AddProductDialog only supports generic meat with optional image picker; has Stock/Quantity (pieces). Requirements:
  - Selection: MEAT/LIVESTOCK; if MEAT, hide image upload; image should be from stored images; add Chicken/Mutton category selector
  - Remove Quantity; Set default UOM=kg (display)
  - Price range (future)
  - Set payload state:"pending" to Odoo
- Current: OdooService.createProduct already sends state:'pending' and local approval_status:'pending'. Images feature-flagged.
- Fix plan (feature-flagged UI; no core changes):
  - Add radio segmented control for product_type = 'meat' | 'livestock'. Default from seller.seller_type or 'meat'.
  - If type == meat: hide ProductImagePickerPanel; add dropdown for subcategory: ['Chicken','Mutton','Fish','Eggs'] (as UI-only, stored in meat_products.extra.category).
  - Remove Stock/Quantity field visually (keep backward compatibility by writing 0 default). Show Unit read-only as 'kg'.
  - Wire stored image selection: reuse ProductImagePickerPanel but label as “Choose from stored images” with SellerImageService; if meat and rule says pick from stored, prefill selection but keep upload disabled.
  - Keep createProduct call intact; pass extra fields via nutritionalInfo or extend local insert’s extra JSON (use existing JSONB fields per user preference).

### 5) Product auto-approving on sync (Bug)
- Observed: “on syncing action its automatically getting approved”
- Files: services/odoo_status_sync_service.dart, product_management_screen.dart (_syncWithOdoo)
- Code: Sync service only updates local approval_status to response from edge function 'odoo-status-sync'. If edge returns approved erroneously, UI appears auto-approving.
- Hypothesis: The edge function may return approved for draft products. App-side mitigation: only accept transition pending -> approved if webhook confirms Odoo state approved AND local has odoo_product_id set or min age > X.
- Zero-risk app-side guard: In _syncSingleProductStatus, before updating to approved, ensure local product has non-null odoo_product_id (requires we store after create). Today createProduct doesn’t set odoo_product_id on local product, only returns it. Safer UI-only: after sync, if statusChanged && new_status == 'approved' but local has no odoo_product_id, treat as unchanged. Add conditional in OdooStatusSyncService.

### 6) Seller login modal moves to top, input disappears when keyboard opens (Bug)
- Observed: Dialog-based MobileNumberModal may get obscured by keyboard; AnimatedPadding uses viewInsets but parent Dialog within showDialog can re-layout unexpectedly.
- Files: mobile_number_modal.dart, seller_portal_screen.dart
- Fix: Use showModalBottomSheet(isScrollControlled:true) or use Dialog + SingleChildScrollView + resizeToAvoidBottomInset true on Navigator root. We already use SingleChildScrollView with AnimatedPadding; add physics and ensure FocusScope handling; alternatively switch to bottom sheet pattern behind a feature flag.

---

## CUSTOMER PORTAL

### 7) Registration captured OTP, name, address(text), email then opened shop directly (Bug)
- Observed: Flow likely okay; confirmation that CustomerPortalScreen uses OTPServiceFallback and after verify saves session then navigates to MyApp() which routes to CustomerAppShell. This is expected.
- Clarify requirement: If more fields are required before entering shop, feature request. Mark as Feature if you want gating.

### 8) Bottom navigation → Cart → "Continue Shopping" leads to blank black screen (Bug)
- Files: customer_shopping_cart_screen.dart
- Code: In empty state button onPressed: Navigator.pop(context). If cart was opened as tab inside IndexedStack (CustomerAppShell), popping may clear the route and show nothing.
- Fix: Detect shell context: when hideBackButton=true (set by shell), route pop is wrong. Instead notify parent to switch tab or push catalog. Zero-risk: if Navigator.canPop is false or hideBackButton true, Navigator.of(context).pushReplacement to CustomerProductCatalogScreen with same customer, or better: use a callback from shell. Minimal fix now: pushReplacement to catalog.

### 9) Maps permission asks but doesn’t enable location (Bug)
- Files: services/auto_location_service.dart
- Behavior: We request Permission.location and open settings only on denial; enabling GPS is OS-level. We also check Geolocator.isLocationServiceEnabled and prompt to open location settings if disabled (Geolocator.openLocationSettings) – already present.
- Clarify: This is expected on Android/iOS; we cannot “enable” GPS. Improve messaging. Also adjust logic to show a persistent banner if services off.

### 10) Default shows 30–45 min in red without placing order (Bug)
- Files: widgets/title_bar_delivery_status_chip.dart, customer_product_catalog_screen.dart (_TitleBarChipSlot sets etaText = '25-30 min'). Color is green; but user saw red 30–45. Possibly older UI. Action: compute ETA via Google Distance Matrix (Feature; planned). For bug: change conservative default to neutral (—) until address available, and chip muted color. Already feature-flagged plan exists.

### 11) After Add to Cart on product page, need option to go to Cart or bottom nav (Feature)
- Files: customer_product_details_screen.dart
- Current: Shows SnackBar only. Fix: After successful add, show SnackBar with “View Cart” action that navigates to cart, or show a bottom sheet with two actions. Non-breaking.

### 12) Product details page should show only seller/AI description; remove duplicate Unit/kg next to price (Bug/Polish)
- Files: customer_product_details_screen.dart
- Current: Price string formats ₹X/unit and details also show Unit row. User asks to remove “Unit/kg” duplication from hero area; keep in details. Fix: Keep ₹X only in hero (remove /kg in header), keep Unit in details.

### 13) Share on product page not working (Bug)
- Files: customer_product_details_screen.dart
- Current: onPressed: () {}. Fix: Integrate share_plus under feature flag; use Share.share with product deep link (or name + price) – UI-only; do not change backend.

### 14) Rare: Cart count correct but cart screen shows empty (Bug)
- Files: shopping_cart_service.dart, customer_shopping_cart_screen.dart
- Hypothesis: Timing/race when fetching items vs summary, or delivery address debounce clears items. Also RLS or select with joins may fail. We use getCartItems and then setState; ensure customer.id passed consistently across app. Mitigation: Add a defensive reload on Cart tab focus; already using RefreshIndicator + pull to refresh. Add “retry” on empty while count badge > 0 (requires passing expectedCount or reading from Notification/Cart cache). Short-term: In _buildEmptyState, change Continue Shopping action to refresh if badge > 0 via provided count (Feature; need count provider). For now add Reload button already present in error state; add also in empty state.

### 15) Payment gateway: after payment, redirect to tracking instead of checkout (Bug/Feature)
- Files: customer_checkout_screen.dart
- Current: _processPhonePePayment is TODO; COD pops to root. Fix plan:
  - Integrate existing PhonePe service (edge function) with success callback navigating to a new OrderTrackingScreen (order id from created order). We already have services/order_tracking_service.dart.
  - Non-breaking: After payment success, Navigator.pushReplacement to tracking; on failure, show retry.

### 16) Voice search (Feature)
- Planned in services/voice_search_service.dart. Leave feature-flagged.

### 17) Customer profile screens:
- Orders: “Start Shopping” button should go Home (Bug) – currently Navigator.pop; if initial route, it may close dialog only. Fix: pushReplacement to CustomerProductCatalogScreen, or navigate to shell index 0.
- Addresses: Doesn’t show saved address; redirects to Home (Bug) – Account hub currently routes to catalog for Addresses. To show real address manager, navigate to LocationSelectorScreen or dedicated SavedAddresses screen. Feature.
- Profile: Routes to Home instead of profile data (Bug/Feature) – current Account Profile routes to catalog. Implement a read-only CustomerProfileScreen rendering registration fields. Feature.
- Logout: Session not terminated (Bug) – CustomerAppShell uses AuthService.clearSession and SupabaseService.signOut in Account->Logout. That exists; verify it’s wired in the shell, not in Portal. If user logs out elsewhere, ensure both are called. Add confirmation of prefs cleared.

---

## RISK‑FREE CHANGE LIST (by file)

- seller_dashboard_screen.dart
  - Disable Add Product/Manage Products buttons when seller.approval_status != 'approved'. Show tooltip/snackbar.
  - Optional: Add Shop Open/Close chip + toggle with local SharedPreferences or extra JSON under feature flag.

- otp_verification_screen.dart
  - After successful seller registration, call SellerSyncService.syncSellerToOdoo(seller). Do not block user.

- product_management_screen.dart
  - Add product_type selector, meat subcategory dropdown, hide image picker when type == meat per rule, remove Stock field visually, display Unit=kg (no DB change). Store extras in local JSON via createProduct optional fields.
  - Fix _syncWithOdoo feedback; no logic change.

- odoo_status_sync_service.dart
  - Guard: On transition to approved, only update if local product has odoo_product_id (or optionally if response confirms created). This prevents “auto-approve” when webhook misreports.

- customer_shopping_cart_screen.dart
  - In empty state Continue Shopping, if embedded in shell, pushReplacement to CustomerProductCatalogScreen.

- customer_product_details_screen.dart
  - After add to cart, SnackBar with View Cart action (navigate). Remove “/kg” from price display in header to avoid duplication. Implement Share via share_plus (feature flag).

- customer_order_history_screen.dart
  - Start Shopping button: pushReplacement to CustomerProductCatalogScreen.

- customer_portal_screen.dart
  - No change unless you want to gate entering catalog behind mandatory profile fields (Feature).

---

## TEST PLAN (high‑level)

- Unit/Widget tests
  - SellerDashboard buttons disabled when approval_status != approved
  - OdooStatusSyncService: pending -> approved only if odoo_product_id present
  - Cart empty state Continue Shopping navigates to catalog when in shell
  - ProductDetails: addToCart shows View Cart action and navigates
  - Share button triggers Share.share when feature flag enabled

- Manual checks
  - Seller registration → sync to Odoo webhook; failure doesn’t block
  - Mobile number modal keyboard behavior verified on small devices
  - Maps permission flows show proper SnackBars; Geolocator settings link works
  - Checkout: after payment success, navigate to tracking

---

## OPEN QUESTIONS / CONFIRMATIONS

1) Shop Open/Close: OK to persist to sellers.extra JSONB? Or keep local only for now?
2) Product form: Exact allowed subcategories for meat? And images rule: strictly from stored images only for meat?
3) Odoo sync guard: Approve only when odoo_product_id is set – acceptable interim safeguard?
4) Customer profile: Do you want dedicated screens for Profile and Addresses in Phase 1, or keep Account hub routing to Catalog for now?

---

## NEXT STEPS
- With your approval, I’ll implement the low‑risk UI changes above behind feature flags and add the sync guard in OdooStatusSyncService, plus minimal navigation fixes. I’ll leave PhonePe integration wiring to a separate PR (needs confirmation of existing edge function contract).

