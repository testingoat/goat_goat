import 'package:flutter/material.dart';

/// Lightweight section header with optional trailing action and badge.
/// Keeps styling subtle to match current theme.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionText;
  final VoidCallback? onAction;
  final Widget? badge;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionText,
    this.onAction,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final color = const Color(0xFF059669); // matches existing emerald accents
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
              letterSpacing: 0.2,
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: 8),
            badge!,
          ],
          const Spacer(),
          if (actionText != null && onAction != null)
            TextButton.icon(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: color,
              ),
              icon: Icon(Icons.chevron_right, size: 18, color: color),
              label: Text(
                actionText!,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }
}