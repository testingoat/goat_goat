import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../services/seller_image_service.dart';

/// SellerImagePicker
/// Zero-risk widget for uploading seller images (logo, profile, shop).
/// Follows the same pattern as existing image picker components.
///
/// Features:
/// - Image selection from gallery or camera
/// - Automatic compression and validation
/// - Upload progress indication
/// - Error handling with user feedback
/// - Consistent UI with app theme
class SellerImagePicker extends StatefulWidget {
  final String sellerId;
  final SellerImageType imageType;
  final String? currentImageUrl;
  final Function(String imageUrl) onImageUploaded;
  final Function(String error)? onError;
  final bool enabled;

  const SellerImagePicker({
    Key? key,
    required this.sellerId,
    required this.imageType,
    this.currentImageUrl,
    required this.onImageUploaded,
    this.onError,
    this.enabled = true,
  }) : super(key: key);

  @override
  State<SellerImagePicker> createState() => _SellerImagePickerState();
}

class _SellerImagePickerState extends State<SellerImagePicker> {
  final SellerImageService _imageService = SellerImageService();
  final ImagePicker _picker = ImagePicker();

  bool _isUploading = false;
  String? _uploadError;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image type label
        Text(
          widget.imageType.displayName,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),

        // Image display and upload area
        Container(
          width: double.infinity,
          height: _getImageHeight(),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: _buildImageContent(),
        ),

        // Error message
        if (_uploadError != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, size: 16, color: Colors.red[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _uploadError!,
                    style: TextStyle(fontSize: 12, color: Colors.red[700]),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 8),

        // Upload buttons
        if (widget.enabled) _buildUploadButtons(),
      ],
    );
  }

  double _getImageHeight() {
    switch (widget.imageType) {
      case SellerImageType.logo:
        return 80; // Smaller for logo
      case SellerImageType.profile:
        return 120; // Medium for profile
      case SellerImageType.shop:
        return 160; // Larger for shop image
    }
  }

  Widget _buildImageContent() {
    if (_isUploading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF059669)),
              strokeWidth: 2,
            ),
            SizedBox(height: 8),
            Text(
              'Uploading...',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (widget.currentImageUrl != null && widget.currentImageUrl!.isNotEmpty) {
      return Stack(
        children: [
          // Current image
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              widget.currentImageUrl!,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                        : null,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF059669),
                    ),
                    strokeWidth: 2,
                  ),
                );
              },
            ),
          ),

          // Delete button
          if (widget.enabled)
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: _showDeleteConfirmation,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red[600],
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 16, color: Colors.white),
                ),
              ),
            ),
        ],
      );
    }

    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    IconData icon;
    String text;

    switch (widget.imageType) {
      case SellerImageType.logo:
        icon = Icons.business;
        text = 'Add Business Logo';
        break;
      case SellerImageType.profile:
        icon = Icons.person;
        text = 'Add Your Photo';
        break;
      case SellerImageType.shop:
        icon = Icons.storefront;
        text = 'Add Shop Photo';
        break;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 32, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text(
            text,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildUploadButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isUploading
                ? null
                : () => _pickImage(ImageSource.gallery),
            icon: const Icon(Icons.photo_library, size: 16),
            label: const Text('Gallery'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF059669),
              side: const BorderSide(color: Color(0xFF059669)),
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isUploading
                ? null
                : () => _pickImage(ImageSource.camera),
            icon: const Icon(Icons.camera_alt, size: 16),
            label: const Text('Camera'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF059669),
              side: const BorderSide(color: Color(0xFF059669)),
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      setState(() {
        _uploadError = null;
      });

      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image == null) return;

      // Read image bytes
      final Uint8List bytes = await image.readAsBytes();

      // Validate image
      final validationError = SellerImageService.validateImage(
        bytes: bytes,
        filename: image.name,
      );

      if (validationError != null) {
        setState(() {
          _uploadError = validationError;
        });
        if (widget.onError != null) {
          widget.onError!(validationError);
        }
        return;
      }

      // Compress image if needed
      final compressedBytes = await _compressImage(bytes, image.name);

      // Upload image
      await _uploadImage(compressedBytes, image.name);
    } catch (e) {
      final errorMessage = 'Failed to pick image: ${e.toString()}';
      setState(() {
        _uploadError = errorMessage;
      });
      if (widget.onError != null) {
        widget.onError!(errorMessage);
      }
    }
  }

  Future<Uint8List> _compressImage(Uint8List bytes, String filename) async {
    try {
      // Only compress if image is larger than 1MB
      if (bytes.length <= 1024 * 1024) {
        return bytes;
      }

      final compressedBytes = await FlutterImageCompress.compressWithList(
        bytes,
        minHeight: 1080,
        minWidth: 1080,
        quality: 80,
        format: CompressFormat.jpeg,
      );

      return Uint8List.fromList(compressedBytes);
    } catch (e) {
      // If compression fails, return original bytes
      return bytes;
    }
  }

  Future<void> _uploadImage(Uint8List bytes, String filename) async {
    setState(() {
      _isUploading = true;
      _uploadError = null;
    });

    try {
      final imageUrl = await _imageService.uploadSellerImage(
        sellerId: widget.sellerId,
        imageType: widget.imageType,
        filename: filename,
        bytes: bytes,
        contentType: SellerImageService.getContentType(filename),
      );

      widget.onImageUploaded(imageUrl);
    } catch (e) {
      final errorMessage = 'Upload failed: ${e.toString()}';
      setState(() {
        _uploadError = errorMessage;
      });
      if (widget.onError != null) {
        widget.onError!(errorMessage);
      }
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete ${widget.imageType.displayName}'),
          content: Text(
            'Are you sure you want to delete this ${widget.imageType.displayName.toLowerCase()}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteImage();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteImage() async {
    if (widget.currentImageUrl == null) return;

    try {
      final success = await _imageService.deleteSellerImage(
        widget.currentImageUrl!,
      );
      if (success) {
        widget.onImageUploaded(''); // Empty string indicates deletion
      } else {
        setState(() {
          _uploadError = 'Failed to delete image';
        });
      }
    } catch (e) {
      setState(() {
        _uploadError = 'Delete failed: ${e.toString()}';
      });
    }
  }
}
