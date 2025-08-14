import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/seller_location_service.dart';

/// SellerLocationPicker
/// Zero-risk widget for capturing seller's business location and managing delivery zones.
/// Integrates with SellerLocationService for GPS functionality.
///
/// Features:
/// - GPS location capture with accuracy display
/// - Delivery radius configuration
/// - Location verification status
/// - Address display and validation
/// - Error handling with user feedback
class SellerLocationPicker extends StatefulWidget {
  final String sellerId;
  final double? currentLatitude;
  final double? currentLongitude;
  final int? currentDeliveryRadius;
  final bool? currentLocationVerified;
  final String? currentAddress;
  final Function(Map<String, dynamic> locationData) onLocationUpdated;
  final Function(String error)? onError;
  final bool enabled;

  const SellerLocationPicker({
    Key? key,
    required this.sellerId,
    this.currentLatitude,
    this.currentLongitude,
    this.currentDeliveryRadius,
    this.currentLocationVerified,
    this.currentAddress,
    required this.onLocationUpdated,
    this.onError,
    this.enabled = true,
  }) : super(key: key);

  @override
  State<SellerLocationPicker> createState() => _SellerLocationPickerState();
}

class _SellerLocationPickerState extends State<SellerLocationPicker> {
  final SellerLocationService _locationService = SellerLocationService();
  final TextEditingController _deliveryRadiusController =
      TextEditingController();

  bool _isCapturingLocation = false;
  String? _locationError;
  Map<String, dynamic>? _capturedLocation;

  @override
  void initState() {
    super.initState();
    _deliveryRadiusController.text =
        widget.currentDeliveryRadius?.toString() ?? '5';
  }

  @override
  void dispose() {
    _deliveryRadiusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        _buildSectionHeader('Business Location & Delivery Zone'),

        // Current location display
        _buildCurrentLocationDisplay(),

        const SizedBox(height: 16),

        // GPS capture button
        if (widget.enabled) _buildGpsCaptureButton(),

        const SizedBox(height: 16),

        // Delivery radius configuration
        _buildDeliveryRadiusConfig(),

        // Error message
        if (_locationError != null) ...[
          const SizedBox(height: 12),
          _buildErrorMessage(),
        ],

        const SizedBox(height: 16),

        // Save button
        if (widget.enabled && _hasChanges()) _buildSaveButton(),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: const Color(0xFF059669),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentLocationDisplay() {
    final hasLocation =
        widget.currentLatitude != null && widget.currentLongitude != null;
    final hasCapturedLocation = _capturedLocation != null;

    // Determine display state
    Color backgroundColor;
    Color borderColor;
    Color iconColor;
    Color textColor;
    IconData icon;
    String statusText;

    if (hasCapturedLocation && !hasLocation) {
      // Location captured but not saved
      backgroundColor = Colors.orange[50]!;
      borderColor = Colors.orange[200]!;
      iconColor = Colors.orange[700]!;
      textColor = Colors.orange[800]!;
      icon = Icons.location_searching;
      statusText = 'Location Captured - Click Save to Persist';
    } else if (hasLocation) {
      // Location saved
      backgroundColor = Colors.green[50]!;
      borderColor = Colors.green[200]!;
      iconColor = Colors.green[700]!;
      textColor = Colors.green[800]!;
      icon = Icons.location_on;
      statusText = 'Business Location Set';
    } else {
      // No location
      backgroundColor = Colors.grey[50]!;
      borderColor = Colors.grey[300]!;
      iconColor = Colors.grey[600]!;
      textColor = Colors.grey[700]!;
      icon = Icons.location_off;
      statusText = 'Location Not Set';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
              if (widget.currentLocationVerified == true) ...[
                const SizedBox(width: 8),
                Icon(Icons.verified, color: Colors.green[700], size: 16),
              ],
            ],
          ),

          if (hasLocation) ...[
            const SizedBox(height: 8),
            if (widget.currentAddress != null &&
                widget.currentAddress!.isNotEmpty)
              Text(
                widget.currentAddress!,
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
            const SizedBox(height: 4),
            Text(
              'Coordinates: ${widget.currentLatitude!.toStringAsFixed(6)}, ${widget.currentLongitude!.toStringAsFixed(6)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontFamily: 'monospace',
              ),
            ),
          ] else if (hasCapturedLocation) ...[
            const SizedBox(height: 8),
            Text(
              _capturedLocation!['address'] ?? 'Address not available',
              style: TextStyle(fontSize: 13, color: Colors.orange[700]),
            ),
            const SizedBox(height: 4),
            Text(
              'Coordinates: ${_capturedLocation!['latitude'].toStringAsFixed(6)}, ${_capturedLocation!['longitude'].toStringAsFixed(6)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange[600],
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Accuracy: ${_capturedLocation!['accuracy'].toInt()}m • Click Save to persist this location',
              style: TextStyle(
                fontSize: 11,
                color: Colors.orange[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              'Capture your business location to enable delivery zone management and help customers find you.',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGpsCaptureButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isCapturingLocation ? null : _captureLocation,
        icon: _isCapturingLocation
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.my_location),
        label: Text(
          _isCapturingLocation
              ? 'Capturing Location...'
              : 'Capture Current Location',
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF059669),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  Widget _buildDeliveryRadiusConfig() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Delivery Radius (km)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _deliveryRadiusController,
          enabled: widget.enabled,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(2),
          ],
          decoration: InputDecoration(
            hintText: 'Enter delivery radius in kilometers',
            prefixIcon: const Icon(
              Icons.delivery_dining,
              color: Color(0xFF059669),
            ),
            suffixText: 'km',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF059669)),
            ),
            filled: true,
            fillColor: widget.enabled ? Colors.white : Colors.grey[50],
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter delivery radius';
            }
            final radius = int.tryParse(value);
            return SellerLocationService.validateDeliveryRadius(radius);
          },
        ),
        const SizedBox(height: 8),
        Text(
          'Customers within this radius will be able to place orders for delivery.',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 20, color: Colors.red[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _locationError!,
              style: TextStyle(fontSize: 14, color: Colors.red[700]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _saveLocationData,
        icon: const Icon(Icons.save),
        label: const Text('Save Location & Delivery Zone'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF059669),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  bool _hasChanges() {
    final currentRadius = int.tryParse(_deliveryRadiusController.text) ?? 5;
    final hasRadiusChange =
        currentRadius != (widget.currentDeliveryRadius ?? 5);
    final hasLocationChange = _capturedLocation != null;

    return hasRadiusChange || hasLocationChange;
  }

  Future<void> _captureLocation() async {
    setState(() {
      _isCapturingLocation = true;
      _locationError = null;
    });

    try {
      final result = await _locationService.captureBusinessLocation();

      if (result['success']) {
        setState(() {
          _capturedLocation = result;
        });

        // Show success message with clear next steps
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Location captured successfully! Click "Save Location & Delivery Zone" to save.',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green[600],
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'SAVE NOW',
                textColor: Colors.white,
                onPressed: _saveLocationData,
              ),
            ),
          );
        }

        // Show accuracy warning if present
        if (result['accuracy_warning'] != null) {
          _showAccuracyWarning(result['accuracy_warning']);
        }
      } else {
        setState(() {
          _locationError = result['error'];
        });

        // Show detailed error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Location Error: ${result['error']}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.red[600],
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'RETRY',
                textColor: Colors.white,
                onPressed: _captureLocation,
              ),
            ),
          );
        }

        if (widget.onError != null) {
          widget.onError!(result['error']);
        }
      }
    } catch (e) {
      final errorMessage = 'Failed to capture location: ${e.toString()}';
      setState(() {
        _locationError = errorMessage;
      });

      // Show exception error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.warning, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Location capture failed: $e',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.orange[600],
            duration: const Duration(seconds: 5),
          ),
        );
      }

      if (widget.onError != null) {
        widget.onError!(errorMessage);
      }
    } finally {
      setState(() {
        _isCapturingLocation = false;
      });
    }
  }

  void _showAccuracyWarning(String warning) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Accuracy'),
          content: Text(warning),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _captureLocation(); // Try again
              },
              child: const Text('Try Again'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveLocationData() async {
    // Validate delivery radius
    final radiusText = _deliveryRadiusController.text.trim();
    if (radiusText.isEmpty) {
      setState(() {
        _locationError = 'Please enter delivery radius';
      });
      return;
    }

    final deliveryRadius = int.tryParse(radiusText);
    final radiusError = SellerLocationService.validateDeliveryRadius(
      deliveryRadius,
    );
    if (radiusError != null) {
      setState(() {
        _locationError = radiusError;
      });
      return;
    }

    // Prepare location data
    final locationData = <String, dynamic>{
      'delivery_radius_km': deliveryRadius,
    };

    // Add captured location if available
    if (_capturedLocation != null) {
      locationData['latitude'] = _capturedLocation!['latitude'];
      locationData['longitude'] = _capturedLocation!['longitude'];
      locationData['address'] = _capturedLocation!['address'];
      locationData['location_verified'] = true;
    }

    // Call the callback with location data
    widget.onLocationUpdated(locationData);

    // Clear captured location after saving
    setState(() {
      _capturedLocation = null;
      _locationError = null;
    });
  }
}
