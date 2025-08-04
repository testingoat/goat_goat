import 'package:flutter/foundation.dart';
import '../models/saved_address.dart';
import '../supabase_service.dart';
import '../config/maps_config.dart';

/// SavedAddressesService - Isolated service for multiple delivery addresses
/// 
/// This service manages CRUD operations for saved delivery addresses without
/// coupling to existing business logic. Features:
/// - Extends existing customer.delivery_addresses JSONB field
/// - Local caching for performance
/// - Graceful error handling and fallbacks
/// - Integration with existing SupabaseService
/// - Zero impact on existing location functionality
class SavedAddressesService {
  static final SavedAddressesService _instance = SavedAddressesService._internal();
  factory SavedAddressesService() => _instance;
  SavedAddressesService._internal();

  final SupabaseService _supabaseService = SupabaseService();

  // Local cache for performance
  final Map<String, List<SavedAddress>> _addressCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  
  // Cache configuration
  static const int _cacheTTLMinutes = 30;
  static const int _maxAddressesPerCustomer = 10;

  /// Get all saved addresses for a customer
  /// 
  /// Returns cached addresses if available, otherwise fetches from Supabase
  /// Gracefully handles errors by returning empty list
  Future<List<SavedAddress>> getSavedAddresses(String customerId) async {
    try {
      // Check if feature is enabled
      if (!kEnableMultipleAddresses) {
        return [];
      }

      // Check cache first
      if (_isCacheValid(customerId)) {
        final cachedAddresses = _addressCache[customerId];
        if (cachedAddresses != null) {
          if (kDebugMode) {
            print('📍 Saved addresses cache hit for customer: $customerId');
          }
          return cachedAddresses;
        }
      }

      if (kDebugMode) {
        print('📍 Fetching saved addresses from Supabase for: $customerId');
      }

      // Fetch customer data from Supabase
      final customerResponse = await _supabaseService.getCustomerById(customerId);
      
      if (!customerResponse['success']) {
        throw Exception('Failed to fetch customer data');
      }

      final customer = customerResponse['customer'];
      final deliveryAddresses = customer['delivery_addresses'] as Map<String, dynamic>?;
      final savedAddressesJson = deliveryAddresses?['saved_addresses'] as List?;

      List<SavedAddress> addresses = [];
      if (savedAddressesJson != null) {
        addresses = savedAddressesJson
            .map((json) => SavedAddress.fromJson(json as Map<String, dynamic>))
            .where((address) => address.isValid)
            .toList();
      }

      // Sort by last used (most recent first), then by primary status
      addresses.sort((a, b) {
        if (a.isPrimary && !b.isPrimary) return -1;
        if (!a.isPrimary && b.isPrimary) return 1;
        return b.lastUsed.compareTo(a.lastUsed);
      });

      // Cache the results
      _cacheAddresses(customerId, addresses);

      if (kDebugMode) {
        print('✅ Retrieved ${addresses.length} saved addresses');
      }

      return addresses;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting saved addresses: $e');
      }
      // Graceful degradation - return empty list
      return [];
    }
  }

  /// Save a new address for a customer
  /// 
  /// Adds the address to the existing delivery_addresses JSONB field
  /// Maintains backward compatibility with existing structure
  Future<bool> saveAddress(String customerId, SavedAddress address) async {
    try {
      if (!kEnableMultipleAddresses) {
        return false;
      }

      // Get current addresses
      final currentAddresses = await getSavedAddresses(customerId);
      
      // Check limit
      if (currentAddresses.length >= _maxAddressesPerCustomer) {
        if (kDebugMode) {
          print('❌ Maximum addresses limit reached for customer: $customerId');
        }
        return false;
      }

      // Check for duplicates (same coordinates)
      final isDuplicate = currentAddresses.any((existing) =>
          (existing.latitude - address.latitude).abs() < 0.0001 &&
          (existing.longitude - address.longitude).abs() < 0.0001);

      if (isDuplicate) {
        if (kDebugMode) {
          print('❌ Duplicate address detected for customer: $customerId');
        }
        return false;
      }

      // If this is the first address, make it primary
      final newAddress = currentAddresses.isEmpty 
          ? address.setAsPrimary() 
          : address;

      // Add to list
      final updatedAddresses = [...currentAddresses, newAddress];

      // Save to Supabase
      final success = await _updateCustomerAddresses(customerId, updatedAddresses);
      
      if (success) {
        // Update cache
        _cacheAddresses(customerId, updatedAddresses);
        
        if (kDebugMode) {
          print('✅ Saved address for customer: $customerId');
          print('📍 Label: ${address.label}, Address: ${address.shortAddress}');
        }
      }

      return success;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error saving address: $e');
      }
      return false;
    }
  }

  /// Update an existing address
  /// 
  /// Finds and updates the address by ID
  Future<bool> updateAddress(String customerId, SavedAddress updatedAddress) async {
    try {
      if (!kEnableMultipleAddresses) {
        return false;
      }

      final currentAddresses = await getSavedAddresses(customerId);
      final addressIndex = currentAddresses.indexWhere((addr) => addr.id == updatedAddress.id);
      
      if (addressIndex == -1) {
        if (kDebugMode) {
          print('❌ Address not found for update: ${updatedAddress.id}');
        }
        return false;
      }

      // Update the address
      final updatedAddresses = [...currentAddresses];
      updatedAddresses[addressIndex] = updatedAddress;

      // Save to Supabase
      final success = await _updateCustomerAddresses(customerId, updatedAddresses);
      
      if (success) {
        // Update cache
        _cacheAddresses(customerId, updatedAddresses);
        
        if (kDebugMode) {
          print('✅ Updated address for customer: $customerId');
        }
      }

      return success;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error updating address: $e');
      }
      return false;
    }
  }

  /// Delete an address
  /// 
  /// Removes the address from the saved addresses list
  Future<bool> deleteAddress(String customerId, String addressId) async {
    try {
      if (!kEnableMultipleAddresses) {
        return false;
      }

      final currentAddresses = await getSavedAddresses(customerId);
      final updatedAddresses = currentAddresses.where((addr) => addr.id != addressId).toList();
      
      if (updatedAddresses.length == currentAddresses.length) {
        if (kDebugMode) {
          print('❌ Address not found for deletion: $addressId');
        }
        return false;
      }

      // If we deleted the primary address, make the first remaining address primary
      if (updatedAddresses.isNotEmpty && !updatedAddresses.any((addr) => addr.isPrimary)) {
        updatedAddresses[0] = updatedAddresses[0].setAsPrimary();
      }

      // Save to Supabase
      final success = await _updateCustomerAddresses(customerId, updatedAddresses);
      
      if (success) {
        // Update cache
        _cacheAddresses(customerId, updatedAddresses);
        
        if (kDebugMode) {
          print('✅ Deleted address for customer: $customerId');
        }
      }

      return success;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error deleting address: $e');
      }
      return false;
    }
  }

  /// Set an address as primary
  /// 
  /// Updates the primary status and marks as recently used
  Future<bool> setPrimaryAddress(String customerId, String addressId) async {
    try {
      if (!kEnableMultipleAddresses) {
        return false;
      }

      final currentAddresses = await getSavedAddresses(customerId);
      final updatedAddresses = currentAddresses.map((addr) {
        if (addr.id == addressId) {
          return addr.setAsPrimary().markAsUsed();
        } else {
          return addr.removePrimary();
        }
      }).toList();

      // Save to Supabase
      final success = await _updateCustomerAddresses(customerId, updatedAddresses);
      
      if (success) {
        // Update cache
        _cacheAddresses(customerId, updatedAddresses);
        
        if (kDebugMode) {
          print('✅ Set primary address for customer: $customerId');
        }
      }

      return success;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error setting primary address: $e');
      }
      return false;
    }
  }

  /// Mark an address as used (update last_used timestamp)
  /// 
  /// Updates the last used timestamp for analytics and sorting
  Future<bool> markAddressAsUsed(String customerId, String addressId) async {
    try {
      if (!kEnableMultipleAddresses) {
        return false;
      }

      final currentAddresses = await getSavedAddresses(customerId);
      final addressIndex = currentAddresses.indexWhere((addr) => addr.id == addressId);
      
      if (addressIndex == -1) {
        return false;
      }

      final updatedAddresses = [...currentAddresses];
      updatedAddresses[addressIndex] = updatedAddresses[addressIndex].markAsUsed();

      // Save to Supabase
      final success = await _updateCustomerAddresses(customerId, updatedAddresses);
      
      if (success) {
        // Update cache
        _cacheAddresses(customerId, updatedAddresses);
      }

      return success;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error marking address as used: $e');
      }
      return false;
    }
  }

  /// Get primary address for a customer
  /// 
  /// Returns the primary address or null if none exists
  Future<SavedAddress?> getPrimaryAddress(String customerId) async {
    try {
      final addresses = await getSavedAddresses(customerId);
      return addresses.firstWhere(
        (addr) => addr.isPrimary,
        orElse: () => addresses.isNotEmpty ? addresses.first : throw StateError('No addresses'),
      );
    } catch (e) {
      return null;
    }
  }

  /// Clear cache for a customer
  void clearCache(String customerId) {
    _addressCache.remove(customerId);
    _cacheTimestamps.remove(customerId);
    
    if (kDebugMode) {
      print('🧹 Cleared saved addresses cache for customer: $customerId');
    }
  }

  /// Clear all caches
  void clearAllCaches() {
    _addressCache.clear();
    _cacheTimestamps.clear();
    
    if (kDebugMode) {
      print('🧹 Cleared all saved addresses caches');
    }
  }

  /// Check if service is available
  bool isAvailable() {
    return kEnableMultipleAddresses;
  }

  /// Private method to update customer addresses in Supabase
  Future<bool> _updateCustomerAddresses(String customerId, List<SavedAddress> addresses) async {
    try {
      // Get current delivery addresses to preserve existing structure
      final customerResponse = await _supabaseService.getCustomerById(customerId);
      
      if (!customerResponse['success']) {
        return false;
      }

      final customer = customerResponse['customer'];
      final currentDeliveryAddresses = customer['delivery_addresses'] as Map<String, dynamic>? ?? {};

      // Update only the saved_addresses field, preserve existing fields
      final updatedDeliveryAddresses = {
        ...currentDeliveryAddresses,
        'saved_addresses': addresses.map((addr) => addr.toJson()).toList(),
      };

      // Update customer in Supabase
      final updateResponse = await _supabaseService.updateCustomer(customerId, {
        'delivery_addresses': updatedDeliveryAddresses,
      });

      return updateResponse['success'] ?? false;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error updating customer addresses in Supabase: $e');
      }
      return false;
    }
  }

  /// Check if cache is valid for a customer
  bool _isCacheValid(String customerId) {
    final timestamp = _cacheTimestamps[customerId];
    if (timestamp == null) return false;
    
    final age = DateTime.now().difference(timestamp);
    return age.inMinutes < _cacheTTLMinutes;
  }

  /// Cache addresses for a customer
  void _cacheAddresses(String customerId, List<SavedAddress> addresses) {
    _addressCache[customerId] = addresses;
    _cacheTimestamps[customerId] = DateTime.now();
  }
}
