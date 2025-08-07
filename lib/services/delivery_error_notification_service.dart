import 'package:flutter/material.dart';

/// Service for handling delivery-related error notifications
/// Provides small, precise error messages for users
class DeliveryErrorNotificationService {
  
  /// Show delivery error notification to user
  static void showDeliveryError(
    BuildContext context, {
    required String errorType,
    String? customMessage,
    Duration duration = const Duration(seconds: 4),
  }) {
    String message;
    Color backgroundColor;
    IconData icon;

    switch (errorType) {
      case 'incomplete_address':
        message = customMessage ?? 'Please enter a complete address';
        backgroundColor = Colors.orange[600]!;
        icon = Icons.location_off;
        break;
        
      case 'address_not_found':
        message = customMessage ?? 'Address not found. Try a different address';
        backgroundColor = Colors.red[600]!;
        icon = Icons.search_off;
        break;
        
      case 'location_not_serviceable':
        message = customMessage ?? 'Delivery not available to this location';
        backgroundColor = Colors.red[600]!;
        icon = Icons.delivery_dining_outlined;
        break;
        
      case 'api_error':
        message = customMessage ?? 'Unable to calculate delivery fee';
        backgroundColor = Colors.grey[600]!;
        icon = Icons.error_outline;
        break;
        
      case 'network_error':
        message = customMessage ?? 'Check your internet connection';
        backgroundColor = Colors.grey[600]!;
        icon = Icons.wifi_off;
        break;
        
      case 'distance_calculation_failed':
        message = customMessage ?? 'Cannot calculate distance. Enter full address';
        backgroundColor = Colors.orange[600]!;
        icon = Icons.straighten_outlined;
        break;
        
      default:
        message = customMessage ?? 'Delivery fee calculation failed';
        backgroundColor = Colors.grey[600]!;
        icon = Icons.warning_outlined;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// Show delivery success notification
  static void showDeliverySuccess(
    BuildContext context, {
    required double fee,
    required double distance,
    String? tier,
  }) {
    final message = fee > 0 
        ? 'Delivery fee: ₹${fee.toStringAsFixed(0)} (${distance.toStringAsFixed(1)}km)'
        : 'Free delivery applied!';
        
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              fee > 0 ? Icons.delivery_dining : Icons.local_shipping,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green[600],
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// Get user-friendly error message for delivery issues
  static String getErrorMessage(String errorType, {String? details}) {
    switch (errorType) {
      case 'Location not serviceable':
        return 'Delivery not available to this location';
      case 'No delivery configuration available':
        return 'Delivery service temporarily unavailable';
      case 'Failed to calculate delivery fee':
        return 'Unable to calculate delivery fee';
      case 'Address not found':
        return 'Address not found. Try a different address';
      case 'Network error':
        return 'Check your internet connection';
      default:
        return details ?? 'Delivery calculation failed';
    }
  }

  /// Determine error type from delivery service response
  static String determineErrorType(Map<String, dynamic> deliveryResult) {
    final error = deliveryResult['error']?.toString() ?? '';
    
    if (error.contains('not serviceable')) {
      return 'location_not_serviceable';
    } else if (error.contains('not found') || error.contains('geocoding')) {
      return 'address_not_found';
    } else if (error.contains('network') || error.contains('fetch')) {
      return 'network_error';
    } else if (error.contains('distance') || error.contains('calculation')) {
      return 'distance_calculation_failed';
    } else if (error.contains('configuration')) {
      return 'api_error';
    } else {
      return 'api_error';
    }
  }
}
