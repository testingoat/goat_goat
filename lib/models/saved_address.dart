/// SavedAddress - Data model for multiple delivery addresses
/// 
/// This model represents a saved delivery address that customers can store
/// for quick selection. Supports the Phase C.2 multiple addresses feature.
class SavedAddress {
  final String id;
  final String label;
  final String address;
  final double latitude;
  final double longitude;
  final bool isPrimary;
  final DateTime createdAt;
  final DateTime lastUsed;

  const SavedAddress({
    required this.id,
    required this.label,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.isPrimary = false,
    required this.createdAt,
    required this.lastUsed,
  });

  /// Create SavedAddress from JSON (Supabase JSONB)
  factory SavedAddress.fromJson(Map<String, dynamic> json) {
    return SavedAddress(
      id: json['id'] ?? '',
      label: json['label'] ?? '',
      address: json['address'] ?? '',
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      isPrimary: json['is_primary'] ?? false,
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      lastUsed: DateTime.parse(json['last_used'] ?? DateTime.now().toIso8601String()),
    );
  }

  /// Convert SavedAddress to JSON (for Supabase JSONB)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'is_primary': isPrimary,
      'created_at': createdAt.toIso8601String(),
      'last_used': lastUsed.toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  SavedAddress copyWith({
    String? id,
    String? label,
    String? address,
    double? latitude,
    double? longitude,
    bool? isPrimary,
    DateTime? createdAt,
    DateTime? lastUsed,
  }) {
    return SavedAddress(
      id: id ?? this.id,
      label: label ?? this.label,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isPrimary: isPrimary ?? this.isPrimary,
      createdAt: createdAt ?? this.createdAt,
      lastUsed: lastUsed ?? this.lastUsed,
    );
  }

  /// Update last used timestamp
  SavedAddress markAsUsed() {
    return copyWith(lastUsed: DateTime.now());
  }

  /// Set as primary address
  SavedAddress setAsPrimary() {
    return copyWith(isPrimary: true);
  }

  /// Remove primary status
  SavedAddress removePrimary() {
    return copyWith(isPrimary: false);
  }

  /// Get display name for UI
  String get displayName {
    return label.isNotEmpty ? label : 'Saved Address';
  }

  /// Get short address for UI (first 30 characters)
  String get shortAddress {
    if (address.length <= 30) return address;
    return '${address.substring(0, 27)}...';
  }

  /// Get icon based on label
  String get iconName {
    switch (label.toLowerCase()) {
      case 'home':
        return 'home';
      case 'office':
      case 'work':
        return 'work';
      case 'school':
      case 'college':
        return 'school';
      case 'hospital':
        return 'local_hospital';
      case 'mall':
      case 'shopping':
        return 'shopping_cart';
      case 'restaurant':
        return 'restaurant';
      case 'gym':
        return 'fitness_center';
      default:
        return 'location_on';
    }
  }

  /// Validate address data
  bool get isValid {
    return id.isNotEmpty &&
           label.isNotEmpty &&
           address.isNotEmpty &&
           latitude >= -90 && latitude <= 90 &&
           longitude >= -180 && longitude <= 180;
  }

  /// Generate unique ID for new address
  static String generateId() {
    return 'addr_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Create new address from location data
  static SavedAddress fromLocationData({
    required String label,
    required Map<String, dynamic> locationData,
  }) {
    return SavedAddress(
      id: generateId(),
      label: label,
      address: locationData['address'] ?? 'Unknown location',
      latitude: (locationData['latitude'] ?? 0.0).toDouble(),
      longitude: (locationData['longitude'] ?? 0.0).toDouble(),
      isPrimary: false,
      createdAt: DateTime.now(),
      lastUsed: DateTime.now(),
    );
  }

  /// Convert to location data format (compatible with existing LocationService)
  Map<String, dynamic> toLocationData() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'label': label,
      'saved_address_id': id,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'SavedAddress(id: $id, label: $label, address: $shortAddress, isPrimary: $isPrimary)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SavedAddress && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  /// Common address labels for quick selection
  static const List<String> commonLabels = [
    'Home',
    'Office',
    'Work',
    'School',
    'Hospital',
    'Mall',
    'Restaurant',
    'Gym',
    'Other',
  ];

  /// Predefined address types with icons
  static const Map<String, String> addressTypes = {
    'Home': 'home',
    'Office': 'work',
    'Work': 'work',
    'School': 'school',
    'Hospital': 'local_hospital',
    'Mall': 'shopping_cart',
    'Restaurant': 'restaurant',
    'Gym': 'fitness_center',
    'Other': 'location_on',
  };
}
