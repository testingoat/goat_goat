import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/product_image_service.dart';
import 'product_image_grid.dart';
import 'package:image_picker/image_picker.dart';

/// ProductImagePickerPanel
/// Light wrapper to upload images to Supabase and emit list of URLs.
/// - No package dependencies (uses File only if provided by parent), so minimal risk.
/// - In web builds, expect bytes to be provided by parent integration.
class ProductImagePickerPanel extends StatefulWidget {
  final String sellerId;
  final String? productId;
  final List<String> initialUrls;
  final ValueChanged<List<String>> onChanged;

  const ProductImagePickerPanel({
    super.key,
    required this.sellerId,
    this.productId,
    this.initialUrls = const [],
    required this.onChanged,
  });

  @override
  State<ProductImagePickerPanel> createState() =>
      _ProductImagePickerPanelState();
}

class _ProductImagePickerPanelState extends State<ProductImagePickerPanel> {
  final _svc = ProductImageService();
  bool _uploading = false;
  int? _uploadingIndex;
  final List<String> _urls = [];

  @override
  void initState() {
    super.initState();
    _urls.addAll(widget.initialUrls);
  }

  Future<void> _pickAndUpload() async {
    if (_urls.length >= 3) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maximum 3 images allowed')),
        );
      }
      return;
    }

    // Gallery-only for now to avoid manifest edits; Camera can be enabled later.
    try {
      final picker = await _loadPicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      await uploadBytes(file.name, bytes, contentType: 'image/jpeg');
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('Image pick/upload failed: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Image selection failed: $e')));
      }
    }
  }

  Future<void> _pickFromCamera() async {
    if (_urls.length >= 3) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maximum 3 images allowed')),
        );
      }
      return;
    }
    try {
      final picker = await _loadPicker();
      final file = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      await uploadBytes(file.name, bytes, contentType: 'image/jpeg');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Camera failed: $e')));
      }
    }
  }

  Future<void> _pickMultiWeb() async {
    if (!kIsWeb) return;
    try {
      final picker = await _loadPicker();
      final files = await picker.pickMultiImage(
        limit: 3 - _urls.length,
        imageQuality: 90,
      );
      if (files == null || files.isEmpty) return;
      for (final f in files) {
        final bytes = await f.readAsBytes();
        await uploadBytes(f.name, bytes, contentType: 'image/jpeg');
        if (_urls.length >= 3) break;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    }
  }

  Future<dynamic> _loadPicker() async {
    // Defer import to avoid web build issues if package missing on some targets.
    return ImagePicker();
  }

  Future<void> uploadBytes(
    String filename,
    Uint8List bytes, {
    String contentType = 'image/jpeg',
  }) async {
    setState(() {
      _uploading = true;
      _uploadingIndex = _urls.length; // next slot being uploaded
    });
    try {
      final url = await _svc.uploadImage(
        sellerId: widget.sellerId,
        productId: widget.productId,
        filename: filename,
        bytes: bytes,
        contentType: contentType,
      );
      setState(() {
        _urls.add(url);
        _uploadingIndex = null;
      });
      widget.onChanged(List<String>.from(_urls));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _reorder(int from, int to) {
    if (from < 0 || from >= _urls.length || to < 0 || to >= _urls.length) {
      return;
    }
    setState(() {
      final moved = _urls.removeAt(from);
      _urls.insert(to, moved);
    });
    widget.onChanged(List<String>.from(_urls));
  }

  void _removeAt(int i) {
    setState(() => _urls.removeAt(i));
    widget.onChanged(List<String>.from(_urls));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Product Images',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: _uploading ? null : _pickAndUpload,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Gallery'),
                ),
                TextButton.icon(
                  onPressed: _uploading ? null : _pickFromCamera,
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Camera'),
                ),
                if (kIsWeb)
                  TextButton.icon(
                    onPressed: _uploading ? null : _pickMultiWeb,
                    icon: const Icon(Icons.file_upload_outlined),
                    label: const Text('Upload'),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_uploading) const LinearProgressIndicator(minHeight: 2),
        const SizedBox(height: 8),
        ProductImageGrid(
          imageUrls: _urls,
          onRemove: _removeAt,
          onReorder: _reorder,
          uploadingIndex: _uploadingIndex,
        ),
      ],
    );
  }
}
