import 'dart:io';
import 'package:flutter/material.dart';
import '../services/product_image_service.dart';

/// Simple grid to show selected images and allow removal.
/// Stateless for zero-risk; state should be managed by the parent form.
class ProductImageGrid extends StatelessWidget {
  final List<String> imageUrls; // already uploaded URLs
  final void Function(int index)? onRemove;
  final void Function(int from, int to)? onReorder; // mini reorder UI
  final int? uploadingIndex; // show spinner overlay while uploading (optional)

  const ProductImageGrid({
    super.key,
    required this.imageUrls,
    this.onRemove,
    this.onReorder,
    this.uploadingIndex,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrls.isEmpty) {
      return const SizedBox.shrink();
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: imageUrls.length,
      itemBuilder: (context, index) {
        final url = imageUrls[index];
        final isPrimary = index == 0;
        return Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(url, fit: BoxFit.cover),
              ),
            ),
            if (uploadingIndex != null && uploadingIndex == index)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            // Remove button
            Positioned(
              top: 4,
              right: 4,
              child: InkWell(
                onTap: onRemove == null ? null : () => onRemove!(index),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(4),
                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                ),
              ),
            ),
            // Primary badge + reorder affordance
            Positioned(
              left: 4,
              bottom: 4,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isPrimary
                          ? Colors.green.shade600
                          : Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isPrimary ? 'Primary' : 'Secondary',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (!isPrimary && onReorder != null)
                    InkWell(
                      onTap: () => onReorder!(index, 0), // make primary quickly
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Make primary',
                          style: TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
