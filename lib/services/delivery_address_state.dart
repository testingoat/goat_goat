/// Delivery Address State Management Service
///
/// This service provides shared state management for delivery addresses
/// across Cart and Checkout screens to ensure address persistence and
/// eliminate UI duplication issues.
///
/// Key Features:
/// - Single source of truth for delivery address
/// - Persistence across screen navigation
/// - Automatic state synchronization
/// - Zero-risk implementation with backward compatibility

class DeliveryAddressState {
  // Private static variables for state storage
  static String? _currentAddress;
  static Map<String, dynamic>? _locationData;
  static DateTime? _lastUpdated;
  static String? _customerId;

  /// Set the current delivery address with optional location data
  ///
  /// [address] - The formatted address string
  /// [locationData] - Optional map containing lat/lng, placeId, etc.
  /// [customerId] - Customer ID for address association
  static void setAddress(
    String address, {
    Map<String, dynamic>? locationData,
    String? customerId,
  }) {
    _currentAddress = address.trim().isEmpty ? null : address.trim();
    _locationData = locationData;
    _lastUpdated = DateTime.now();
    _customerId = customerId;
    
    print('📍 ADDRESS_STATE - Address updated: ${address.length > 50 ? '${address.substring(0, 50)}...' : address}');
    if (locationData != null) {
      print('📍 ADDRESS_STATE - Location data: lat=${locationData['latitude']}, lng=${locationData['longitude']}');
    }
  }

  /// Get the current delivery address
  ///
  /// Returns the formatted address string or null if not set
  static String? getCurrentAddress() {
    return _currentAddress;
  }

  /// Get the current location data
  ///
  /// Returns map containing latitude, longitude, placeId, etc. or null if not set
  static Map<String, dynamic>? getLocationData() {
    return _locationData != null ? Map<String, dynamic>.from(_locationData!) : null;
  }

  /// Check if an address is currently set
  ///
  /// Returns true if a valid address is stored
  static bool hasAddress() {
    return _currentAddress != null && _currentAddress!.isNotEmpty;
  }

  /// Get the timestamp when address was last updated
  ///
  /// Returns DateTime of last update or null if never set
  static DateTime? getLastUpdated() {
    return _lastUpdated;
  }

  /// Get the customer ID associated with current address
  ///
  /// Returns customer ID or null if not set
  static String? getCustomerId() {
    return _customerId;
  }

  /// Clear the current address state
  ///
  /// Useful for logout or address reset scenarios
  static void clearAddress() {
    _currentAddress = null;
    _locationData = null;
    _lastUpdated = null;
    _customerId = null;
    
    print('📍 ADDRESS_STATE - Address cleared');
  }

  /// Check if address belongs to specific customer
  ///
  /// [customerId] - Customer ID to check against
  /// Returns true if address belongs to the customer
  static bool belongsToCustomer(String customerId) {
    return _customerId == customerId;
  }

  /// Get address summary for debugging
  ///
  /// Returns formatted string with address state information
  static String getStateSummary() {
    if (!hasAddress()) {
      return 'No address set';
    }
    
    final address = _currentAddress!;
    final shortAddress = address.length > 30 ? '${address.substring(0, 30)}...' : address;
    final hasLocation = _locationData != null;
    final customerInfo = _customerId != null ? ' (Customer: $_customerId)' : '';
    final timeInfo = _lastUpdated != null ? ' (Updated: ${_lastUpdated!.toLocal()})' : '';
    
    return 'Address: $shortAddress${hasLocation ? ' [+Location]' : ''}$customerInfo$timeInfo';
  }

  /// Initialize address from customer profile
  ///
  /// [customer] - Customer data map
  /// This method auto-populates address from customer profile if available
  static void initializeFromCustomer(Map<String, dynamic> customer) {
    final customerId = customer['id'] as String?;
    final profileAddress = customer['address'] as String?;
    
    if (customerId == null) {
      print('⚠️ ADDRESS_STATE - Cannot initialize: No customer ID');
      return;
    }
    
    // Only initialize if no address is set or if it's for a different customer
    if (!hasAddress() || !belongsToCustomer(customerId)) {
      if (profileAddress != null && profileAddress.isNotEmpty) {
        setAddress(
          profileAddress,
          customerId: customerId,
        );
        print('✅ ADDRESS_STATE - Initialized from customer profile');
      } else {
        // Clear state for new customer with no address
        clearAddress();
        _customerId = customerId;
        print('📍 ADDRESS_STATE - Initialized empty state for customer: $customerId');
      }
    } else {
      print('📍 ADDRESS_STATE - Using existing address for customer: $customerId');
    }
  }

  /// Update address if it belongs to current customer
  ///
  /// [address] - New address string
  /// [locationData] - Optional location data
  /// [customerId] - Customer ID for validation
  /// 
  /// Only updates if the address belongs to the specified customer
  static bool updateAddressForCustomer(
    String address,
    String customerId, {
    Map<String, dynamic>? locationData,
  }) {
    if (_customerId == null || _customerId == customerId) {
      setAddress(
        address,
        locationData: locationData,
        customerId: customerId,
      );
      return true;
    } else {
      print('⚠️ ADDRESS_STATE - Update rejected: Address belongs to different customer');
      return false;
    }
  }

  /// Get address data for order creation
  ///
  /// Returns map suitable for order creation with all address information
  static Map<String, dynamic>? getOrderAddressData() {
    if (!hasAddress()) {
      return null;
    }
    
    return {
      'address': _currentAddress!,
      'location_data': _locationData,
      'customer_id': _customerId,
      'updated_at': _lastUpdated?.toIso8601String(),
    };
  }

  /// Validate address for order placement
  ///
  /// [customerId] - Customer ID to validate against
  /// Returns validation result with error message if invalid
  static Map<String, dynamic> validateForOrder(String customerId) {
    if (!hasAddress()) {
      return {
        'valid': false,
        'error': 'No delivery address set',
      };
    }
    
    if (!belongsToCustomer(customerId)) {
      return {
        'valid': false,
        'error': 'Address belongs to different customer',
      };
    }
    
    if (_currentAddress!.length < 10) {
      return {
        'valid': false,
        'error': 'Address too short - please provide complete address',
      };
    }
    
    return {
      'valid': true,
      'address': _currentAddress!,
      'location_data': _locationData,
    };
  }
}
