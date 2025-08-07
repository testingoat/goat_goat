import 'package:flutter/material.dart';
import '../config/ui_flags.dart';

/// A horizontally scrollable row of category shortcuts shown below the search bar.
/// Designed to be lightweight and theme-friendly. Uses monochrome icons with
/// brand-accent on selection/tap feedback.
class CategoryShortcutRow extends StatelessWidget {
  final List<CategoryShortcut> categories;
  final void Function(CategoryShortcut) onTap;

  const CategoryShortcutRow({
    super.key,
    required this.categories,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!UiFlags.categoryShortcutsEnabled || categories.isEmpty) {
      return const SizedBox.shrink();
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;
    final horizontalPadding = isTablet ? 24.0 : 12.0;
    final itemSpacing = isTablet ? 10.0 : 8.0;

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: SizedBox(
        height: 64, // Reduced from 76px to 64px
        child: ListView.separated(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          scrollDirection: Axis.horizontal,
          itemCount: categories.length,
          separatorBuilder: (_, __) => SizedBox(width: itemSpacing),
          itemBuilder: (context, index) {
            final item = categories[index];
            return _CategoryChip(
              item: item,
              isTablet: isTablet,
              onTap: () {
                logUi('Category shortcut tapped: ${item.label}');
                onTap(item);
              },
            );
          },
        ),
      ),
    );
  }
}

class _CategoryChip extends StatefulWidget {
  final CategoryShortcut item;
  final VoidCallback onTap;
  final bool isTablet;

  const _CategoryChip({
    required this.item,
    required this.onTap,
    this.isTablet = false,
  });

  @override
  State<_CategoryChip> createState() => _CategoryChipState();
}

class _CategoryChipState extends State<_CategoryChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF059669);

    // Responsive sizing
    final chipWidth = widget.isTablet ? 80.0 : 72.0;
    final horizontalPadding = widget.isTablet ? 10.0 : 8.0;
    final verticalPadding = widget.isTablet ? 8.0 : 6.0;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: chipWidth,
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _pressed ? 0.10 : 0.06),
              blurRadius: _pressed ? 10 : 8,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(
            color: _pressed
                ? accent.withValues(alpha: 0.5)
                : const Color(0x11000000),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.item.icon,
              size: widget.isTablet ? 20.0 : 18.0, // Responsive icon size
              color: _pressed ? accent : Colors.grey[800],
            ),
            SizedBox(
              height: widget.isTablet ? 4.0 : 2.0,
            ), // Phase 4I: Reduced spacing to fix overflow
            Text(
              widget.item.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: widget.isTablet
                    ? 11.0
                    : 10.0, // Phase 4I: Reduced font size to fix overflow
                fontWeight: FontWeight.w600,
                color: Colors.grey[900],
                height: 1.0, // Phase 4I: Reduced line height to fix overflow
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Simple data class for category shortcuts.
class CategoryShortcut {
  final String id;
  final String label;
  final IconData icon;
  final String? query; // optional search query to apply

  const CategoryShortcut({
    required this.id,
    required this.label,
    required this.icon,
    this.query,
  });
}
