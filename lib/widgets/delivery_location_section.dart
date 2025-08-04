import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';
import '../models/saved_address.dart';
import '../config/maps_config.dart';
import '../screens/location_selector_screen.dart';
import '../widgets/saved_addresses_carousel.dart';

/// DeliveryLocationSection - Compact map widget for customer product catalog
///
/// This widget provides a 120px height map section that shows the user's current
/// location and allows them to set their delivery address. Features:
/// - Compact design that fits between search bar and product grid
/// - Shows current location with marker
/// - FAB to open full-screen location selector
/// - Follows app's emerald color scheme and glass-morphism design
/// - Graceful handling of location permissions and errors
class DeliveryLocationSection extends StatefulWidget {
  final String customerId;
  final Function(Map<String, dynamic>)? onLocationSelected;

  const DeliveryLocationSection({
    super.key,
    required this.customerId,
    this.onLocationSelected,
  });

  @override
  State<DeliveryLocationSection> createState() =>
      _DeliveryLocationSectionState();
}

class _DeliveryLocationSectionState extends State<DeliveryLocationSection> {
  final LocationService _locationService = LocationService();
  GoogleMapController? _mapController;

  LatLng _currentLocation = const LatLng(kDefaultLatitude, kDefaultLongitude);
  LatLng? _deliveryLocation;
  String? _deliveryAddress;
  bool _isLoadingLocation = true;
  bool _hasLocationPermission = false;
  String? _errorMessage;

  // Phase C.2: Saved addresses state
  SavedAddress? _selectedSavedAddress;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  /// Initialize location services and get current position
  Future<void> _initializeLocation() async {
    try {
      // Check if location is available
      bool isAvailable = await _locationService.isLocationAvailable();

      if (isAvailable) {
        // Get current location
        Position? position = await _locationService.getCurrentLocation();

        if (position != null) {
          setState(() {
            _currentLocation = LatLng(position.latitude, position.longitude);
            _hasLocationPermission = true;
            _isLoadingLocation = false;
          });

          // Move camera to current location
          _mapController?.animateCamera(
            CameraUpdate.newLatLng(_currentLocation),
          );
        } else {
          setState(() {
            _hasLocationPermission = false;
            _isLoadingLocation = false;
            _errorMessage = 'Unable to get current location';
          });
        }
      } else {
        setState(() {
          _hasLocationPermission = false;
          _isLoadingLocation = false;
          _errorMessage = 'Location permission required';
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingLocation = false;
        _errorMessage = 'Location error: ${e.toString()}';
      });
    }
  }

  /// Open full-screen location selector
  Future<void> _openLocationSelector() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => LocationSelectorScreen(
          customerId: widget.customerId,
          initialLocation: _deliveryLocation ?? _currentLocation,
          initialAddress: _deliveryAddress,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _deliveryLocation = LatLng(result['latitude'], result['longitude']);
        _deliveryAddress = result['address'];
      });

      // Move camera to selected location
      _mapController?.animateCamera(CameraUpdate.newLatLng(_deliveryLocation!));

      // Notify parent widget
      widget.onLocationSelected?.call(result);
    }
  }

  /// Handle location permission request
  Future<void> _requestLocationPermission() async {
    bool hasPermission = await _locationService.ensurePermissions();

    if (hasPermission) {
      _initializeLocation();
    } else {
      // Show dialog to open settings
      _showLocationSettingsDialog();
    }
  }

  /// Show dialog to open location settings
  void _showLocationSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Permission Required'),
        content: const Text(
          'To show your current location and set delivery address, please enable location permissions in your device settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _locationService.openLocationSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
            ),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  /// Handle saved address selection from carousel
  void _onSavedAddressSelected(SavedAddress address) {
    setState(() {
      _selectedSavedAddress = address;
      _deliveryLocation = LatLng(address.latitude, address.longitude);
      _deliveryAddress = address.address;
    });

    // Move camera to selected address
    _mapController?.animateCamera(CameraUpdate.newLatLng(_deliveryLocation!));

    // Notify parent widget
    final locationData = address.toLocationData();
    widget.onLocationSelected?.call(locationData);
  }

  /// Handle add new address button press
  void _onAddNewAddressPressed() {
    // Open the full-screen location selector
    _openLocationSelector();
  }

  @override
  Widget build(BuildContext context) {
    // Calculate total height based on feature flags
    final totalHeight = kCompactMapHeight + (kEnableMultipleAddresses ? 64 : 0);

    return Container(
      height: totalHeight,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          // Existing compact map section
          Container(
            height: kCompactMapHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(kMapBorderRadius),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(kMapBorderRadius),
              child: Stack(
                children: [
                  // Google Map
                  _buildMap(),

                  // Loading overlay
                  if (_isLoadingLocation) _buildLoadingOverlay(),

                  // Error overlay
                  if (_errorMessage != null && !_isLoadingLocation)
                    _buildErrorOverlay(),

                  // Location info overlay
                  if (!_isLoadingLocation && _errorMessage == null)
                    _buildLocationInfo(),

                  // FAB for location selector
                  if (!_isLoadingLocation) _buildLocationFAB(),
                ],
              ),
            ),
          ),

          // Phase C.2: Saved addresses carousel (feature flagged)
          if (kEnableMultipleAddresses)
            SavedAddressesCarousel(
              customerId: widget.customerId,
              selectedAddress: _selectedSavedAddress,
              onAddressSelected: _onSavedAddressSelected,
              onAddNewPressed: _onAddNewAddressPressed,
            ),
        ],
      ),
    );
  }

  /// Build Google Map widget
  Widget _buildMap() {
    Set<Marker> markers = {};

    // Add current location marker
    if (_hasLocationPermission) {
      markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: _currentLocation,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'Current Location'),
        ),
      );
    }

    // Add delivery location marker
    if (_deliveryLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('delivery_location'),
          position: _deliveryLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          infoWindow: InfoWindow(
            title: 'Delivery Location',
            snippet: _deliveryAddress ?? 'Selected location',
          ),
        ),
      );
    }

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: _currentLocation,
        zoom: kDefaultMapZoom,
      ),
      markers: markers,
      onMapCreated: (GoogleMapController controller) {
        _mapController = controller;
      },
      myLocationEnabled: _hasLocationPermission,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
      tiltGesturesEnabled: false,
      rotateGesturesEnabled: false,
      scrollGesturesEnabled: true,
      zoomGesturesEnabled: true,
      mapType: MapType.normal,
    );
  }

  /// Build loading overlay
  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.white.withValues(alpha: 0.9),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF059669)),
              strokeWidth: 2,
            ),
            SizedBox(height: 8),
            Text(
              'Getting your location...',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF059669),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build error overlay
  Widget _buildErrorOverlay() {
    return Container(
      color: Colors.white.withValues(alpha: 0.95),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off, size: 32, color: Colors.grey[600]),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _requestLocationPermission,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                minimumSize: const Size(0, 32),
              ),
              child: const Text(
                'Enable Location',
                style: TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build location info overlay
  Widget _buildLocationInfo() {
    return Positioned(
      top: 8,
      left: 8,
      right: 60, // Leave space for FAB
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              _deliveryLocation != null ? Icons.location_on : Icons.my_location,
              size: 16,
              color: const Color(0xFF059669),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _deliveryLocation != null
                    ? (_deliveryAddress ?? 'Delivery location set')
                    : 'Tap to set delivery location',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF374151),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build floating action button for location selector
  Widget _buildLocationFAB() {
    return Positioned(
      bottom: 8,
      right: 8,
      child: FloatingActionButton.small(
        onPressed: _openLocationSelector,
        backgroundColor: const Color(0xFF059669),
        foregroundColor: Colors.white,
        elevation: 4,
        child: const Icon(Icons.edit_location, size: 20),
      ),
    );
  }
}
