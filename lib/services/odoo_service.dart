import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/api_config.dart';

class OdooService {
  static final OdooService _instance = OdooService._internal();
  factory OdooService() => _instance;
  OdooService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  // ===== PRODUCT MANAGEMENT =====

  /// Create product in Odoo and sync with local database
  Future<Map<String, dynamic>> createProduct({
    required String name,
    required double price,
    required String sellerId, // UUID for database
    required String sellerUid, // UUID for Odoo
    required String sellerName, // Name for Odoo
    String? description,
    List<String>? imageUrls,
    Map<String, dynamic>? nutritionalInfo,
  }) async {
    try {
      print('🚀 PRODUCT CREATION DEBUG - Starting createProduct method');
      print('🔍 DEBUG - Method called with:');
      print('🔍 DEBUG - name: "$name"');
      print('🔍 DEBUG - price: $price');
      print('🔍 DEBUG - sellerId: "$sellerId" (${sellerId.runtimeType})');
      print('🔍 DEBUG - sellerUid: "$sellerUid" (${sellerUid.runtimeType})');
      print('🔍 DEBUG - sellerName: "$sellerName" (${sellerName.runtimeType})');
      print('🔍 DEBUG - description: "$description"');

      // Validate required fields
      if (name.trim().isEmpty) {
        throw Exception('Product name is required');
      }
      if (price <= 0) {
        throw Exception('Product price must be greater than 0');
      }
      if (sellerId.trim().isEmpty) {
        throw Exception('Seller ID is required');
      }
      if (sellerUid.trim().isEmpty) {
        throw Exception('Seller UID is required');
      }
      if (sellerName.trim().isEmpty) {
        throw Exception('Seller Name is required');
      }

      print('✅ Validation passed - all required fields present');

      // Generate unique product code
      final defaultCode = 'GOAT_${DateTime.now().millisecondsSinceEpoch}';

      // Request body for Odoo (includes fields that Odoo needs but database doesn't)
      final requestBody = {
        'name': name,
        'list_price': price,
        'seller_id': sellerName, // ✅ FIXED: Use seller name for Odoo
        'seller_uid': sellerUid, // ✅ Use UUID for Odoo
        'default_code':
            defaultCode, // This is for Odoo only, not for local database
        'product_type':
            'meat', // FIXED: edge function expects product_type, not meat_type
        'state': 'pending',
        'description': description,
      };

      print('📤 Odoo Request - Body: $requestBody');

      // Use API key authentication for edge functions (based on webhook requirements)
      final headers = ApiConfig.edgeFunctionHeaders;

      print('🔐 Using API key authentication for edge function');
      print('🔐 API Key: ${ApiConfig.edgeFunctionApiKey}');
      print('🔐 Headers: $headers');

      // FIXED APPROACH: Create product locally first, then sync to Odoo via webhook
      print(
        '🔄 Creating product locally first, then syncing to Odoo via webhook',
      );

      // Create product in local database immediately (matching actual schema)
      final productData = {
        'name': name,
        'price': price,
        'seller_id': sellerId,
        'description': description,
        'approval_status': 'pending',
        'stock': 0, // Default stock value
        // Note: removed default_code, is_active, created_at, updated_at as they don't exist in schema
      };

      print('🔍 DEBUG - Database productData: $productData');
      print('🔍 DEBUG - sellerId type: ${sellerId.runtimeType}');
      print('🔍 DEBUG - sellerId value: "$sellerId"');

      final localProduct = await _supabase
          .from('meat_products')
          .insert(productData)
          .select()
          .single();

      print('✅ Product created locally with ID: ${localProduct['id']}');

      // Now trigger Odoo sync via webhook (this is the working approach)
      Map<String, dynamic> odooSyncResult;
      try {
        odooSyncResult = await _syncToOdooViaWebhook(localProduct, requestBody);
      } catch (e) {
        print('⚠️ Odoo sync failed, but product created locally: $e');
        odooSyncResult = {
          'success': true,
          'odoo_sync': false,
          'message':
              'Product created locally. Odoo sync will be retried later.',
        };
      }

      // Add nutritional info if provided
      if (nutritionalInfo != null) {
        await _supabase.from('nutritional_info').insert({
          'product_id': localProduct['id'],
          ...nutritionalInfo,
        });
      }

      // Add product images if provided
      if (imageUrls != null && imageUrls.isNotEmpty) {
        final imageData = imageUrls
            .map(
              (url) => {
                'product_id': localProduct['id'],
                'image_url': url,
                'is_primary': imageUrls.indexOf(url) == 0,
              },
            )
            .toList();

        await _supabase.from('meat_product_images').insert(imageData);
      }

      // Return combined result
      final finalResult = {
        'success': true,
        'message': odooSyncResult['message'] ?? 'Product created successfully',
        'product': localProduct,
        'odoo_sync': odooSyncResult['odoo_sync'] ?? false,
        'odoo_product_id': odooSyncResult['odoo_product_id'],
      };

      print('🎯 FINAL RESULT - Product creation completed:');
      print('🎯 FINAL RESULT - Success: ${finalResult['success']}');
      print('🎯 FINAL RESULT - Message: ${finalResult['message']}');
      print('🎯 FINAL RESULT - Odoo Sync: ${finalResult['odoo_sync']}');
      print(
        '🎯 FINAL RESULT - Odoo Product ID: ${finalResult['odoo_product_id']}',
      );

      return finalResult;
    } catch (e) {
      print('Error creating product: $e');
      return {
        'success': false,
        'message': 'Failed to create product: ${e.toString()}',
      };
    }
  }

  /// Update product in both Odoo and local database
  Future<Map<String, dynamic>> updateProduct({
    required String productId,
    String? name,
    double? price,
    String? description,
    String? category,
    bool? isActive,
  }) async {
    try {
      // Get current product data
      final currentProduct = await _supabase
          .from('meat_products')
          .select()
          .eq('id', productId)
          .single();

      final odooProductId = currentProduct['odoo_product_id'];

      // Update in Odoo if product exists there
      if (odooProductId != null) {
        final odooUpdateData = <String, dynamic>{};
        if (name != null) odooUpdateData['name'] = name;
        if (price != null) odooUpdateData['list_price'] = price;
        if (description != null) odooUpdateData['description'] = description;
        if (category != null) odooUpdateData['category'] = category;

        if (odooUpdateData.isNotEmpty) {
          await _supabase.functions.invoke(
            'odoo-api-proxy',
            body: {
              'odoo_endpoint': 'product.product',
              'data': {
                'method': 'write',
                'args': [
                  [odooProductId],
                  odooUpdateData,
                ],
              },
            },
          );
        }
      }

      // Update in local database (only fields that exist in schema)
      final localUpdateData = <String, dynamic>{};
      if (name != null) localUpdateData['name'] = name;
      if (price != null) localUpdateData['price'] = price;
      if (description != null) localUpdateData['description'] = description;
      // Note: removed category, is_active, updated_at as they don't exist in schema

      final updatedProduct = await _supabase
          .from('meat_products')
          .update(localUpdateData)
          .eq('id', productId)
          .select()
          .single();

      return {
        'success': true,
        'message': 'Product updated successfully',
        'product': updatedProduct,
      };
    } catch (e) {
      print('Error updating product: $e');
      return {
        'success': false,
        'message': 'Failed to update product: ${e.toString()}',
      };
    }
  }

  // ===== CUSTOMER MANAGEMENT =====

  /// Create customer in Odoo and sync with local database
  Future<Map<String, dynamic>> createCustomer({
    required String name,
    required String phone,
    String? email,
    String? address,
    String? city,
    String? pincode,
  }) async {
    try {
      // Check if customer already exists locally
      final existingCustomer = await _supabase
          .from('customers')
          .select()
          .eq('phone_number', phone)
          .maybeSingle();

      if (existingCustomer != null) {
        return {
          'success': true,
          'message': 'Customer already exists',
          'customer': existingCustomer,
        };
      }

      // Create customer in local database first
      final customerData = {
        'full_name': name,
        'phone_number': phone,
        'email': email,
        'address': address,
        'city': city,
        'pincode': pincode,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final localCustomer = await _supabase
          .from('customers')
          .insert(customerData)
          .select()
          .single();

      // Create customer in Odoo via edge function
      try {
        final odooResponse = await _supabase.functions.invoke(
          'create-odoo-customer',
          body: {
            'name': name,
            'phone': phone,
            'email': email,
            'address': address,
            'customer_id': localCustomer['id'],
          },
        );

        if (odooResponse.data != null && odooResponse.data['success'] == true) {
          // Update local customer with Odoo partner ID
          await _supabase
              .from('customers')
              .update({
                'odoo_partner_id': odooResponse.data['odoo_partner_id'],
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', localCustomer['id']);

          localCustomer['odoo_partner_id'] =
              odooResponse.data['odoo_partner_id'];
        }
      } catch (e) {
        print('Failed to create customer in Odoo: $e');
        // Continue with local customer creation even if Odoo fails
      }

      return {
        'success': true,
        'message': 'Customer created successfully',
        'customer': localCustomer,
      };
    } catch (e) {
      print('Error creating customer: $e');
      return {
        'success': false,
        'message': 'Failed to create customer: ${e.toString()}',
      };
    }
  }

  // ===== ORDER MANAGEMENT =====

  /// Sync order with Odoo
  Future<Map<String, dynamic>> syncOrderWithOdoo({
    required String orderId,
    required String customerId,
    required List<Map<String, dynamic>> orderItems,
    required double totalAmount,
  }) async {
    try {
      // Get customer and order details
      final customer = await _supabase
          .from('customers')
          .select()
          .eq('id', customerId)
          .single();

      final order = await _supabase
          .from('orders')
          .select('*, order_items(*, meat_products(*))')
          .eq('id', orderId)
          .single();

      // Prepare order data for Odoo
      final odooOrderData = {
        'partner_id': customer['odoo_partner_id'],
        'order_line': orderItems
            .map(
              (item) => {
                'product_id': item['meat_products']['odoo_product_id'],
                'product_uom_qty': item['quantity'],
                'price_unit': item['unit_price'],
              },
            )
            .toList(),
        'amount_total': totalAmount,
        'state': 'draft',
      };

      // Create order in Odoo
      final odooResponse = await _supabase.functions.invoke(
        'odoo-api-proxy',
        body: {
          'odoo_endpoint': 'sale.order',
          'data': {
            'method': 'create',
            'args': [odooOrderData],
          },
        },
      );

      if (odooResponse.data != null && odooResponse.data['success'] == true) {
        // Update local order with Odoo order ID
        await _supabase
            .from('orders')
            .update({
              'odoo_order_id': odooResponse.data['odoo_order_id'],
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', orderId);

        return {
          'success': true,
          'message': 'Order synced with Odoo successfully',
          'odoo_order_id': odooResponse.data['odoo_order_id'],
        };
      } else {
        throw Exception('Failed to create order in Odoo');
      }
    } catch (e) {
      print('Error syncing order with Odoo: $e');
      return {
        'success': false,
        'message': 'Failed to sync order with Odoo: ${e.toString()}',
      };
    }
  }

  // ===== INVENTORY MANAGEMENT =====

  /// Get product inventory from Odoo
  Future<Map<String, dynamic>> getProductInventory(String odooProductId) async {
    try {
      final response = await _supabase.functions.invoke(
        'odoo-api-proxy',
        body: {
          'odoo_endpoint': 'stock.quant',
          'data': {
            'method': 'search_read',
            'args': [
              [
                ['product_id', '=', int.parse(odooProductId)],
              ],
              ['quantity', 'available_quantity', 'location_id'],
            ],
          },
        },
      );

      if (response.data != null && response.data['success'] == true) {
        return {'success': true, 'inventory': response.data['result']};
      } else {
        throw Exception('Failed to get inventory from Odoo');
      }
    } catch (e) {
      print('Error getting inventory: $e');
      return {
        'success': false,
        'message': 'Failed to get inventory: ${e.toString()}',
      };
    }
  }

  /// Update product inventory in Odoo
  Future<Map<String, dynamic>> updateProductInventory({
    required String odooProductId,
    required double quantity,
    String? locationId,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'odoo-api-proxy',
        body: {
          'odoo_endpoint': 'stock.change.product.qty',
          'data': {
            'method': 'create',
            'args': [
              {
                'product_id': int.parse(odooProductId),
                'new_quantity': quantity,
                if (locationId != null) 'location_id': int.parse(locationId),
              },
            ],
          },
        },
      );

      if (response.data != null && response.data['success'] == true) {
        return {'success': true, 'message': 'Inventory updated successfully'};
      } else {
        throw Exception('Failed to update inventory in Odoo');
      }
    } catch (e) {
      print('Error updating inventory: $e');
      return {
        'success': false,
        'message': 'Failed to update inventory: ${e.toString()}',
      };
    }
  }

  /// Update product with re-approval workflow
  Future<Map<String, dynamic>> updateProductLocal(
    String productId,
    Map<String, dynamic> updates,
  ) async {
    try {
      print('🔄 UPDATE PRODUCT - Starting update for product: $productId');
      print('🔄 UPDATE PRODUCT - Updates: $updates');

      // 1. Get current product
      final currentProduct = await _supabase
          .from('meat_products')
          .select('*')
          .eq('id', productId)
          .single();

      print(
        '📦 UPDATE PRODUCT - Current product: ${currentProduct['name']}, status: ${currentProduct['approval_status']}',
      );

      // 2. Determine if re-approval is needed
      bool needsReapproval = false;
      if (currentProduct['approval_status'] == 'approved') {
        // Check if critical fields changed
        if (updates['name'] != currentProduct['name'] ||
            updates['price'] != currentProduct['price']) {
          needsReapproval = true;
        }
      }

      // 3. Prepare update data
      final updateData = {
        ...updates,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // 4. If needs re-approval, reset status
      if (needsReapproval) {
        updateData['approval_status'] = 'pending';
        updateData['approved_at'] = null;
        updateData['is_active'] = false; // Deactivate until re-approved
        print('⚠️ UPDATE PRODUCT - Product will need re-approval');
      }

      // 5. Update local database
      await _supabase
          .from('meat_products')
          .update(updateData)
          .eq('id', productId);

      print('✅ UPDATE PRODUCT - Successfully updated product');

      // 6. Prepare response message
      String message = 'Product updated successfully';
      if (needsReapproval) {
        message += '. Product will need re-approval before becoming active.';
      }

      return {
        'success': true,
        'message': message,
        'needs_reapproval': needsReapproval,
      };
    } catch (e) {
      print('❌ UPDATE PRODUCT - Error: ${e.toString()}');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to update product',
      };
    }
  }

  /// Toggle product active/inactive status
  Future<Map<String, dynamic>> toggleProductActive(
    String productId,
    bool newActiveState,
  ) async {
    try {
      print(
        '🔄 TOGGLE ACTIVE - Starting toggle for product: $productId to $newActiveState',
      );

      // 1. Get current product
      final product = await _supabase
          .from('meat_products')
          .select('*')
          .eq('id', productId)
          .single();

      print(
        '📦 TOGGLE ACTIVE - Current product: ${product['name']}, status: ${product['approval_status']}, active: ${product['is_active']}',
      );

      // 2. Business rule validation
      if (product['approval_status'] != 'approved' && newActiveState) {
        throw Exception('Only approved products can be activated');
      }

      // 3. Update local database only (no Odoo sync to avoid complexity)
      await _supabase
          .from('meat_products')
          .update({
            'is_active': newActiveState,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', productId);

      print('✅ TOGGLE ACTIVE - Successfully updated product active status');

      return {
        'success': true,
        'message':
            'Product ${newActiveState ? 'activated' : 'deactivated'} successfully',
        'new_active_state': newActiveState,
      };
    } catch (e) {
      print('❌ TOGGLE ACTIVE - Error: ${e.toString()}');
      return {
        'success': false,
        'error': e.toString(),
        'message':
            'Failed to ${newActiveState ? 'activate' : 'deactivate'} product',
      };
    }
  }

  /// Sync product to Odoo via webhook (the working approach)
  Future<Map<String, dynamic>> _syncToOdooViaWebhook(
    Map<String, dynamic> localProduct,
    Map<String, dynamic> requestBody,
  ) async {
    try {
      print(
        '🔗 WEBHOOK DEBUG - Starting Odoo sync via product-approval-webhook',
      );
      print('🔗 WEBHOOK DEBUG - Local Product: $localProduct');
      print('🔗 WEBHOOK DEBUG - Request Body: $requestBody');

      // Prepare webhook payload
      final webhookPayload = {
        'product_id': localProduct['id'],
        'seller_id': localProduct['seller_id'], // UUID for database reference
        'product_type': 'meat',
        'approval_status': 'pending',
        'updated_at': DateTime.now().toIso8601String(),
        // Include the original product data for Odoo creation
        // The requestBody already has the correct seller_id (name) for Odoo
        'product_data': requestBody,
      };

      print('🔗 WEBHOOK DEBUG - Payload: $webhookPayload');
      print('🔗 WEBHOOK DEBUG - Headers: ${ApiConfig.webhookHeaders}');
      print('🔗 WEBHOOK DEBUG - API Key: ${ApiConfig.webhookApiKey}');

      // Use the working webhook approach - FIXED WEBHOOK
      final webhookResponse = await _supabase.functions.invoke(
        'product-sync-webhook',
        body: webhookPayload,
        headers: ApiConfig.webhookHeaders,
      );

      print('📥 WEBHOOK RESPONSE - Status: ${webhookResponse.status}');
      print('📥 WEBHOOK RESPONSE - Data: ${webhookResponse.data}');

      if (webhookResponse.data != null && webhookResponse.data is Map) {
        print(
          '📥 WEBHOOK RESPONSE - Error in data: ${webhookResponse.data['error']}',
        );
      }

      if (webhookResponse.status == 200) {
        print('✅ WEBHOOK SUCCESS - Product synced to Odoo successfully');
        return {
          'success': true,
          'odoo_sync': true,
          'message': 'Product created and synced to Odoo successfully',
          'odoo_product_id': webhookResponse.data?['odoo_product_id'],
        };
      } else {
        print('❌ WEBHOOK FAILED - Status: ${webhookResponse.status}');
        final errorMsg = webhookResponse.data?['error'] ?? 'Unknown error';
        print('❌ WEBHOOK FAILED - Error: $errorMsg');
        throw Exception(
          'Webhook failed with status ${webhookResponse.status}: $errorMsg',
        );
      }
    } catch (e) {
      print('❌ WEBHOOK EXCEPTION - Sync failed: $e');
      print('❌ WEBHOOK EXCEPTION - Stack trace: ${StackTrace.current}');
      return {
        'success': true,
        'odoo_sync': false,
        'message': 'Product created locally. Odoo sync will be retried later.',
        'error': e.toString(),
      };
    }
  }
}
