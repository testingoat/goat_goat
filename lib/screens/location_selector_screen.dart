import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';

/// LocationSelectorScreen - Full-screen location picker
///
/// This screen provides a full-screen Google Maps interface for precise
/// location selection. Features:
/// - Full-screen map with draggable marker
/// - My location button to center on current position
/// - Address display with reverse geocoding
/// - Confirm button to save selected location
/// - Follows app's emerald color scheme and design patterns
class LocationSelectorScreen extends StatefulWidget {
  final String customerId;
  final LatLng initialLocation;
  final String? initialAddress;

  const LocationSelectorScreen({
    super.key,
    required this.customerId,
    required this.initialLocation,
    this.initialAddress,
  });

  @override
  State<LocationSelectorScreen> createState() => _LocationSelectorScreenState();
}

class _LocationSelectorScreenState extends State<LocationSelectorScreen> {
  final LocationService _locationService = LocationService();
  GoogleMapController? _mapController;

  late LatLng _selectedLocation;
  String? _selectedAddress;
  bool _isLoadingAddress = false;
  bool _hasLocationPermission = false;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
    _selectedAddress = widget.initialAddress;
    _checkLocationPermission();
    _loadAddressForLocation(_selectedLocation);
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  /// Check if location permission is available
  Future<void> _checkLocationPermission() async {
    bool isAvailable = await _locationService.isLocationAvailable();
    setState(() {
      _hasLocationPermission = isAvailable;
    });
  }

  /// Load address for given location using reverse geocoding
  Future<void> _loadAddressForLocation(LatLng location) async {
    setState(() {
      _isLoadingAddress = true;
    });

    try {
      String? address = await _locationService.reverseGeocode(
        location.latitude,
        location.longitude,
      );

      setState(() {
        _selectedAddress = address ?? 'Unknown location';
        _isLoadingAddress = false;
      });
    } catch (e) {
      setState(() {
        _selectedAddress = 'Unable to get address';
        _isLoadingAddress = false;
      });
    }
  }

  /// Handle map tap to select new location
  void _onMapTap(LatLng location) {
    setState(() {
      _selectedLocation = location;
    });
    _loadAddressForLocation(location);
  }

  /// Move to current location
  Future<void> _moveToCurrentLocation() async {
    try {
      Position? position = await _locationService.getCurrentLocation();

      if (position != null) {
        LatLng currentLocation = LatLng(position.latitude, position.longitude);

        setState(() {
          _selectedLocation = currentLocation;
        });

        _mapController?.animateCamera(CameraUpdate.newLatLng(currentLocation));

        _loadAddressForLocation(currentLocation);
      } else {
        _showSnackBar('Unable to get current location');
      }
    } catch (e) {
      _showSnackBar('Error getting location: ${e.toString()}');
    }
  }

  /// Confirm location selection and save
  Future<void> _confirmLocation() async {
    if (!mounted) return;

    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF059669)),
          ),
        ),
      );

      // Save location using LocationService
      bool success = await _locationService.saveDeliveryLocation(
        customerId: widget.customerId,
        latitude: _selectedLocation.latitude,
        longitude: _selectedLocation.longitude,
        address: _selectedAddress,
      );

      // Hide loading
      if (mounted) Navigator.pop(context);

      if (success) {
        // Return result to previous screen
        if (mounted) {
          Navigator.pop(context, {
            'latitude': _selectedLocation.latitude,
            'longitude': _selectedLocation.longitude,
            'address': _selectedAddress,
          });
        }
      } else {
        if (mounted) _showSnackBar('Failed to save delivery location');
      }
    } catch (e) {
      // Hide loading
      if (mounted) Navigator.pop(context);
      if (mounted) _showSnackBar('Error saving location: ${e.toString()}');
    }
  }

  /// Show snackbar message
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  /// Build app bar
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'Select Delivery Location',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
      backgroundColor: const Color(0xFF059669),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        if (_hasLocationPermission)
          IconButton(
            icon: const Icon(Icons.my_location, color: Colors.white),
            onPressed: _moveToCurrentLocation,
            tooltip: 'My Location',
          ),
      ],
    );
  }

  /// Build main body with map
  Widget _buildBody() {
    return Stack(
      children: [
        // Google Map
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: _selectedLocation,
            zoom: 16.0,
          ),
          onMapCreated: (GoogleMapController controller) {
            _mapController = controller;
          },
          onTap: _onMapTap,
          markers: {
            Marker(
              markerId: const MarkerId('selected_location'),
              position: _selectedLocation,
              draggable: true,
              onDragEnd: (LatLng location) {
                setState(() {
                  _selectedLocation = location;
                });
                _loadAddressForLocation(location);
              },
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueGreen,
              ),
              infoWindow: InfoWindow(
                title: 'Delivery Location',
                snippet: _selectedAddress ?? 'Loading address...',
              ),
            ),
          },
          myLocationEnabled: _hasLocationPermission,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          compassEnabled: true,
          tiltGesturesEnabled: true,
          rotateGesturesEnabled: true,
          scrollGesturesEnabled: true,
          zoomGesturesEnabled: true,
          mapType: MapType.normal,
        ),

        // Address info card
        _buildAddressCard(),

        // Instructions overlay
        _buildInstructionsOverlay(),
      ],
    );
  }

  /// Build address information card
  Widget _buildAddressCard() {
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.location_on,
                  color: Color(0xFF059669),
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Delivery Address',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_isLoadingAddress)
              const Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF059669),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Loading address...',
                    style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                  ),
                ],
              )
            else
              Text(
                _selectedAddress ?? 'Unknown location',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B7280),
                  height: 1.4,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Build instructions overlay
  Widget _buildInstructionsOverlay() {
    return Positioned(
      bottom: 100,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'Tap on the map or drag the marker to select your delivery location',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  /// Build bottom confirmation bar
  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _confirmLocation,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            child: const Text(
              'Confirm Delivery Location',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}
