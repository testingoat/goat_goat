import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/api_config.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  static late SupabaseClient _supabase;

  factory SupabaseService() {
    return _instance;
  }

  SupabaseService._internal();

  // Initialize Supabase with your project credentials
  Future<void> initialize({
    required String supabaseUrl,
    required String supabaseAnonKey,
  }) async {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
    _supabase = Supabase.instance.client;
  }

  // Access the Supabase client
  SupabaseClient get client => _supabase;

  // Authentication methods
  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signUp(email: email, password: password);
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  // Get current user session
  Session? get currentUser => _supabase.auth.currentSession;

  // Database methods

  // ===== SELLER MANAGEMENT =====

  /// Get all sellers with optional filtering
  Future<List<Map<String, dynamic>>> getSellers({
    String? approvalStatus,
    String? sellerType,
    int? limit,
  }) async {
    var query = _supabase.from('sellers').select('*, seller_profile_audit(*)');

    if (approvalStatus != null) {
      query = query.eq('approval_status', approvalStatus);
    }

    if (sellerType != null) {
      query = query.eq('seller_type', sellerType);
    }

    var orderedQuery = query.order('created_at', ascending: false);

    if (limit != null) {
      orderedQuery = orderedQuery.limit(limit);
    }

    final response = await orderedQuery;
    return response;
  }

  /// Get seller by ID with full details
  Future<Map<String, dynamic>?> getSellerById(String sellerId) async {
    final response = await _supabase
        .from('sellers')
        .select('*, seller_profile_audit(*)')
        .eq('id', sellerId)
        .maybeSingle();
    return response;
  }

  /// Get seller by phone number
  Future<Map<String, dynamic>?> getSellerByPhone(String phoneNumber) async {
    final response = await _supabase
        .from('sellers')
        .select()
        .eq('contact_phone', phoneNumber)
        .maybeSingle();
    return response;
  }

  /// Insert new seller
  Future<Map<String, dynamic>> insertSeller(
    Map<String, dynamic> sellerData,
  ) async {
    final response = await _supabase
        .from('sellers')
        .insert(sellerData)
        .select()
        .single();
    return response;
  }

  /// Update seller profile
  Future<Map<String, dynamic>> updateSeller(
    String sellerId,
    Map<String, dynamic> updates,
  ) async {
    try {
      final response = await _supabase
          .from('sellers')
          .update(updates)
          .eq('id', sellerId)
          .select()
          .single();

      return {
        'success': true,
        'seller': response,
        'message': 'Seller updated successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to update seller: ${e.toString()}',
      };
    }
  }

  // ===== PRODUCT MANAGEMENT =====

  /// Get meat products with seller info and enhanced filtering/sorting
  Future<List<Map<String, dynamic>>> getMeatProducts({
    String? sellerId,
    String? approvalStatus,
    bool? isActive,
    String? sortBy, // 'created_at', 'name', 'price', 'updated_at'
    bool ascending = false,
    String? searchQuery,
    int? limit,
  }) async {
    var query = _supabase.from('meat_products').select('''
          *,
          sellers(seller_name, contact_phone, business_city),
          meat_product_images(image_url),
          nutritional_info(*)
        ''');

    // Server-side filters
    if (sellerId != null) {
      query = query.eq('seller_id', sellerId);
    }

    if (approvalStatus != null) {
      query = query.eq('approval_status', approvalStatus);
    }

    if (isActive != null) {
      query = query.eq('is_active', isActive);
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = query.ilike('name', '%$searchQuery%');
    }

    // Server-side sorting
    final sortField = sortBy ?? 'created_at';
    var orderedQuery = query.order(sortField, ascending: ascending);

    if (limit != null) {
      orderedQuery = orderedQuery.limit(limit);
    }

    final response = await orderedQuery;
    return response;
  }

  /// Add new meat product
  Future<Map<String, dynamic>> addMeatProduct(
    Map<String, dynamic> productData,
  ) async {
    try {
      final response = await _supabase
          .from('meat_products')
          .insert(productData)
          .select()
          .single();

      return {
        'success': true,
        'product': response,
        'message': 'Product added successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to add product: ${e.toString()}',
      };
    }
  }

  /// Update meat product
  Future<Map<String, dynamic>> updateMeatProduct(
    String productId,
    Map<String, dynamic> updates,
  ) async {
    try {
      final response = await _supabase
          .from('meat_products')
          .update(updates)
          .eq('id', productId)
          .select()
          .single();

      return {
        'success': true,
        'product': response,
        'message': 'Product updated successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to update product: ${e.toString()}',
      };
    }
  }

  // ===== CUSTOMER MANAGEMENT =====

  /// Get customers with optional filtering
  Future<List<Map<String, dynamic>>> getCustomers({
    String? phoneNumber,
    int? limit,
  }) async {
    var query = _supabase.from('customers').select();

    if (phoneNumber != null) {
      query = query.eq('phone_number', phoneNumber);
    }

    var orderedQuery = query.order('created_at', ascending: false);

    if (limit != null) {
      orderedQuery = orderedQuery.limit(limit);
    }

    final response = await orderedQuery;
    return response;
  }

  /// Add new customer
  Future<Map<String, dynamic>> addCustomer(
    Map<String, dynamic> customerData,
  ) async {
    try {
      final response = await _supabase
          .from('customers')
          .insert(customerData)
          .select()
          .single();

      return {
        'success': true,
        'customer': response,
        'message': 'Customer registered successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to register customer: ${e.toString()}',
      };
    }
  }

  // ===== ORDER MANAGEMENT =====

  /// Get orders with customer and item details
  Future<List<Map<String, dynamic>>> getOrders({
    String? customerId,
    String? status,
    int? limit,
  }) async {
    var query = _supabase.from('orders').select('''
          *,
          customers(full_name, phone_number),
          order_items(quantity, unit_price, product_id)
        ''');

    if (customerId != null) {
      query = query.eq('customer_id', customerId);
    }

    if (status != null) {
      query = query.eq('status', status);
    }

    var orderedQuery = query.order('created_at', ascending: false);

    if (limit != null) {
      orderedQuery = orderedQuery.limit(limit);
    }

    final response = await orderedQuery;
    return response;
  }

  /// Create new order
  Future<Map<String, dynamic>> createOrder(
    Map<String, dynamic> orderData,
  ) async {
    final response = await _supabase
        .from('orders')
        .insert(orderData)
        .select()
        .single();
    return response;
  }

  /// Update order status
  Future<Map<String, dynamic>> updateOrderStatus(
    String orderId,
    String status,
  ) async {
    final response = await _supabase
        .from('orders')
        .update({
          'status': status,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', orderId)
        .select()
        .single();
    return response;
  }

  // ===== EDGE FUNCTION CALLS =====

  /// Call Odoo API proxy
  Future<Map<String, dynamic>> callOdooProxy({
    required String endpoint,
    required Map<String, dynamic> data,
    Map<String, dynamic>? config,
  }) async {
    final response = await _supabase.functions.invoke(
      'odoo-api-proxy',
      body: {
        'odoo_endpoint': endpoint,
        'data': data,
        if (config != null) 'config': config,
      },
    );

    if (response.data != null) {
      return response.data as Map<String, dynamic>;
    } else {
      throw Exception('Odoo API call failed');
    }
  }

  /// Create customer in Odoo
  Future<Map<String, dynamic>> createOdooCustomer({
    required String name,
    required String phone,
    String? email,
    String? address,
    required String customerId,
  }) async {
    final response = await _supabase.functions.invoke(
      'create-odoo-customer',
      body: {
        'name': name,
        'phone': phone,
        'email': email,
        'address': address,
        'customer_id': customerId,
      },
    );

    if (response.data != null) {
      return response.data as Map<String, dynamic>;
    } else {
      throw Exception('Odoo customer creation failed');
    }
  }

  /// Create product in Odoo
  Future<Map<String, dynamic>> createOdooProduct({
    required String name,
    required double price,
    required String sellerId,
    required String sellerUid,
    required String defaultCode,
  }) async {
    final requestBody = {
      'name': name,
      'list_price': price,
      'seller_id': sellerId,
      'seller_uid': sellerUid,
      'default_code': defaultCode,
      'product_type': 'meat',
      'state': 'pending',
    };

    final response = await _supabase.functions.invoke(
      'odoo-api-proxy',
      body: {
        'odoo_endpoint': '/web/dataset/call_kw',
        'data': {
          'jsonrpc': '2.0',
          'method': 'call',
          'params': {
            'model': 'product.template',
            'method': 'create',
            'args': [requestBody],
            'kwargs': {},
          },
          'id': DateTime.now().millisecondsSinceEpoch,
        },
        'config': {
          'serverUrl': 'https://goatgoat.xyz/',
          'database': 'staging',
          'username': 'admin',
          'password': 'admin',
        },
      },
      headers: ApiConfig.edgeFunctionHeaders,
    );

    if (response.data != null && response.data['result'] != null) {
      return {'success': true, 'odoo_product_id': response.data['result']};
    } else {
      throw Exception('Odoo product creation failed');
    }
  }
}
