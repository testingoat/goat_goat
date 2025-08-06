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

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: SizedBox(
        height: 76,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          scrollDirection: Axis.horizontal,
          itemCount: categories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            final item = categories[index];
            return _CategoryChip(
              item: item,
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

  const _CategoryChip({required this.item, required this.onTap});

  @override
  State<_CategoryChip> createState() => _CategoryChipState();
}

class _CategoryChipState extends State<_CategoryChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF059669);

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 88,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
            color: _pressed ? accent.withValues(alpha: 0.5) : const Color(0x11000000),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.item.icon,
              size: 22,
              color: _pressed ? accent : Colors.grey[800],
            ),
            const SizedBox(height: 6),
            Text(
              widget.item.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[900],
                height: 1.1,
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