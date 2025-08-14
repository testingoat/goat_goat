import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Image types supported by the seller image service
enum SellerImageType {
  logo('logo', 'Business Logo'),
  profile('profile', 'Seller Photo'),
  shop('shop', 'Shop Photo');

  const SellerImageType(this.folder, this.displayName);
  final String folder;
  final String displayName;
}

/// SellerImageService
/// Zero-risk service for uploading and managing seller images in Supabase Storage.
/// Follows the same pattern as ProductImageService for consistency.
///
/// Supports three types of seller images:
/// - Business Logo: Display in seller profile header
/// - Seller Image: Personal photo of the seller
/// - Shop Image: Photo of the physical shop/business
class SellerImageService {
  final SupabaseClient _client = Supabase.instance.client;
  static const String bucket =
      'meat-product-images'; // Using existing bucket for now

  /// Upload a seller image and return its public URL
  ///
  /// Uses the same RLS-compliant approach as ProductImageService
  /// Path structure: seller-images/{seller_id}/{image_type}/{timestamp_filename}
  ///
  /// Parameters:
  /// - sellerId: The seller's UUID
  /// - imageType: Type of image (logo, profile, shop)
  /// - filename: Original filename
  /// - bytes: Image data as bytes
  /// - contentType: MIME type (defaults to image/jpeg)
  Future<String> uploadSellerImage({
    required String sellerId,
    required SellerImageType imageType,
    required String filename,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    if (kDebugMode) {
      print(
        '🖼️ SellerImageService: Starting ${imageType.displayName} upload for seller: $sellerId',
      );
    }

    // Ensure authenticated session for RLS compliance
    try {
      final session = _client.auth.currentSession;
      if (session == null) {
        if (kDebugMode) {
          print(
            '🔐 SellerImageService: No auth session found, signing in anonymously...',
          );
        }

        // Sign in anonymously to satisfy RLS policy
        final authResponse = await _client.auth.signInAnonymously();
        if (authResponse.user == null) {
          throw Exception('Anonymous authentication failed');
        }

        if (kDebugMode) {
          print('✅ SellerImageService: Anonymous authentication successful');
        }
      }
    } catch (authError) {
      if (kDebugMode) {
        print(
          '⚠️ SellerImageService: Auth failed, attempting upload anyway: $authError',
        );
      }
      // Continue with upload attempt - the storage might still work
    }

    // Prepare file path with timestamp for uniqueness
    final safeName = filename.replaceAll(' ', '_');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = p.extension(filename).toLowerCase();
    final finalFilename = '${timestamp}_$safeName';

    // Use authenticated user's UID as top-level folder if available, otherwise use sellerId
    final uid = _client.auth.currentUser?.id;
    final topFolder = (uid != null && uid.isNotEmpty) ? uid : sellerId;
    final path = '$topFolder/${imageType.folder}/$finalFilename';

    if (kDebugMode) {
      print('📁 SellerImageService: Upload path: $path');
      print('📊 SellerImageService: File size: ${bytes.length} bytes');
      print('🎯 SellerImageService: Image type: ${imageType.displayName}');
    }

    try {
      // Upload to Supabase Storage
      await _client.storage
          .from(bucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              cacheControl: 'public, max-age=31536000', // Cache for 1 year
              contentType: contentType,
              upsert: true, // Allow overwriting existing files
            ),
          );

      // Generate public URL
      final publicUrl = _client.storage.from(bucket).getPublicUrl(path);

      if (kDebugMode) {
        print(
          '✅ SellerImageService: ${imageType.displayName} upload successful',
        );
        print('🔗 SellerImageService: Public URL: $publicUrl');
      }

      return publicUrl;
    } catch (uploadError) {
      if (kDebugMode) {
        print(
          '❌ SellerImageService: ${imageType.displayName} upload failed: $uploadError',
        );
      }
      rethrow; // Let the calling widget handle the error display
    }
  }

  /// Delete a seller image from storage
  ///
  /// Parameters:
  /// - imageUrl: The full public URL of the image to delete
  Future<bool> deleteSellerImage(String imageUrl) async {
    try {
      // Extract path from public URL
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;

      // Find the path after 'seller-images'
      final bucketIndex = pathSegments.indexOf(bucket);
      if (bucketIndex == -1 || bucketIndex >= pathSegments.length - 1) {
        throw Exception('Invalid image URL format');
      }

      final path = pathSegments.sublist(bucketIndex + 1).join('/');

      if (kDebugMode) {
        print('🗑️ SellerImageService: Deleting image at path: $path');
      }

      await _client.storage.from(bucket).remove([path]);

      if (kDebugMode) {
        print('✅ SellerImageService: Image deleted successfully');
      }

      return true;
    } catch (deleteError) {
      if (kDebugMode) {
        print('❌ SellerImageService: Delete failed: $deleteError');
      }
      return false;
    }
  }

  /// Get the appropriate database field name for an image type
  ///
  /// Returns the column name in the sellers table for the given image type
  static String getDbFieldName(SellerImageType imageType) {
    switch (imageType) {
      case SellerImageType.logo:
        return 'business_logo_url';
      case SellerImageType.profile:
        return 'seller_image_url';
      case SellerImageType.shop:
        return 'shop_image_url';
    }
  }

  /// Validate image file before upload
  ///
  /// Checks file size, format, and other constraints
  /// Returns null if valid, error message if invalid
  static String? validateImage({
    required Uint8List bytes,
    required String filename,
    int maxSizeBytes = 5 * 1024 * 1024, // 5MB default
  }) {
    // Check file size
    if (bytes.length > maxSizeBytes) {
      final maxSizeMB = (maxSizeBytes / (1024 * 1024)).toStringAsFixed(1);
      return 'Image size must be less than ${maxSizeMB}MB';
    }

    // Check file extension
    final extension = p.extension(filename).toLowerCase();
    const allowedExtensions = ['.jpg', '.jpeg', '.png', '.webp'];
    if (!allowedExtensions.contains(extension)) {
      return 'Only JPG, PNG, and WebP images are supported';
    }

    // Basic file validation (check if it starts with image magic bytes)
    if (bytes.length < 8) {
      return 'Invalid image file';
    }

    // Check for common image magic bytes
    final header = bytes.take(8).toList();
    bool isValidImage = false;

    // JPEG magic bytes
    if (header.length >= 2 && header[0] == 0xFF && header[1] == 0xD8) {
      isValidImage = true;
    }
    // PNG magic bytes
    else if (header.length >= 8 &&
        header[0] == 0x89 &&
        header[1] == 0x50 &&
        header[2] == 0x4E &&
        header[3] == 0x47) {
      isValidImage = true;
    }
    // WebP magic bytes
    else if (header.length >= 8 &&
        header[0] == 0x52 &&
        header[1] == 0x49 &&
        header[2] == 0x46 &&
        header[3] == 0x46 &&
        header[8] == 0x57 &&
        header[9] == 0x45 &&
        header[10] == 0x42 &&
        header[11] == 0x50) {
      isValidImage = true;
    }

    if (!isValidImage) {
      return 'Invalid image format';
    }

    return null; // Valid image
  }

  /// Get content type from filename extension
  static String getContentType(String filename) {
    final extension = p.extension(filename).toLowerCase();
    switch (extension) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      default:
        return 'image/jpeg'; // Default fallback
    }
  }
}
