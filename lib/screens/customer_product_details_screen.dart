import 'package:flutter/material.dart';
import '../widgets/product_review_widget.dart';
import '../services/shopping_cart_service.dart';
import 'customer_product_reviews_screen.dart';

class CustomerProductDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> product;
  final Map<String, dynamic> customer;

  const CustomerProductDetailsScreen({
    super.key,
    required this.product,
    required this.customer,
  });

  Color get primaryColor => const Color(0xFF059669);

  @override
  Widget build(BuildContext context) {
    final sellerName = product['sellers']?['seller_name'] as String?;
    final productName = (product['name'] ?? 'Product').toString();
    final price = product['price'];
    final unit = _readUnit(product) ?? 'kg';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back',
        ),
        title: Text(
          productName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: () {},
            tooltip: 'Share',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildHeroHeader(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (sellerName != null && sellerName.isNotEmpty)
                        Row(
                          children: [
                            _SellerChipView(label: sellerName),
                            const SizedBox(width: 8),
                            Text('Seller', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                          ],
                        ),
                      if (sellerName != null && sellerName.isNotEmpty) const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _formatPrice(price, unit),
                            style: TextStyle(color: primaryColor, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 0.2),
                          ),
                          const SizedBox(width: 8),
                          Text('(inclusive of all taxes)', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(
                              child: ProductReviewSummary(
                                productId: product['id'],
                                showFullStats: false,
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: () => _openReviews(context),
                              icon: Icon(Icons.chevron_right, color: primaryColor, size: 18),
                              label: Text('View Reviews', style: TextStyle(color: primaryColor, fontWeight: FontWeight.w600)),
                              style: TextButton.styleFrom(
                                foregroundColor: primaryColor,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildHighlightsIfAny(),
                      const SizedBox(height: 16),
                      _buildDetailsSection(unit),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, -2)),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _formatPrice(price, unit),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: primaryColor, fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 40,
                    child: ElevatedButton(
                      onPressed: () => _addToCart(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                      ),
                      child: const Text('Add to Cart', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.2)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Navigate to the existing full reviews screen using the same parameters.
  void _openReviews(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => CustomerProductReviewsScreen(
          product: product,
          customer: customer,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;
          final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(position: animation.drive(tween), child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  // Reuse the same add-to-cart behavior as the catalog: add 1 unit and show SnackBar, stay on page.
  Future<void> _addToCart(BuildContext context) async {
    try {
      final service = ShoppingCartService();
      final result = await service.addToCart(
        customerId: customer['id'],
        productId: product['id'],
        quantity: 1,
        unitPrice: (product['price'] as num).toDouble(),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Added to cart'),
          backgroundColor: result['success'] == true ? primaryColor : Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildHeroHeader() {
    return Container(
      color: primaryColor.withValues(alpha: 0.10),
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Container(
            height: 220,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: const Center(child: Icon(Icons.fastfood, size: 96, color: Color(0xFF059669))),
          ),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [_DotView(active: true, color: primaryColor)]),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildHighlightsIfAny() {
    final chips = <String>[];
    if (product['category'] != null) chips.add(product['category'].toString());
    if (product['type'] != null) chips.add(product['type'].toString());
    if (product['cut'] != null) chips.add(product['cut'].toString());
    if (chips.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Highlights', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: chips
              .map(
                (c) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(c, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildDetailsSection(String unit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Product Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        _DetailRowView(label: 'Unit', value: unit),
        if (product['description'] != null) ...[
          const SizedBox(height: 6),
          _DetailRowView(label: 'Description', value: product['description'].toString()),
        ],
      ],
    );
  }
  
  String _formatPrice(dynamic price, String unit) {
    final p = (price is num) ? price.toDouble() : double.tryParse(price?.toString() ?? '0') ?? 0.0;
    return '₹${p.toStringAsFixed(p.truncateToDouble() == p ? 0 : 1)}/$unit';
  }
 
  String? _readUnit(Map<String, dynamic> prod) {
    if (prod['unit'] is String && (prod['unit'] as String).isNotEmpty) {
      return prod['unit'];
    }
    return 'kg';
  }
}
 
// Helper widgets must be top-level (outside of the CustomerProductDetailsScreen class).
class _SellerChipView extends StatelessWidget {
  final String label;
  const _SellerChipView({super.key, required this.label});
 
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.store_mall_directory, size: 14, color: Color(0xFF059669)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
 
class _DetailRowView extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRowView({super.key, required this.label, required this.value});
 
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
 
class _DotView extends StatelessWidget {
  final bool active;
  final Color color;
  const _DotView({super.key, required this.active, required this.color});
 
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: active ? 18 : 8,
      height: 8,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: active ? color : color.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}