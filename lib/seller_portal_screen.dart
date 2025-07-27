import 'package:flutter/material.dart';
import 'dart:ui';
import 'mobile_number_modal.dart';
import 'seller_registration_screen.dart';

class SellerPortalScreen extends StatelessWidget {
  const SellerPortalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFFECFDF5), // emerald-50
              const Color(0xFFDCFAE6), // green-100
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // For larger screens, center the content
              if (constraints.maxWidth > 600) {
                return SingleChildScrollView(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: const _SellerPortalContent(),
                    ),
                  ),
                );
              }
              // For smaller screens, use full width with padding
              return const SingleChildScrollView(child: _SellerPortalContent());
            },
          ),
        ),
      ),
    );
  }
}

class _SellerPortalContent extends StatelessWidget {
  const _SellerPortalContent();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Back button
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, size: 30),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ),

          const SizedBox(height: 16),

          // Title section
          const Text(
            'Seller Portal',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Business Growth Platform',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),

          const SizedBox(height: 48),

          // NEW SELLER Card
          _GlassCard(
            title: 'NEW SELLER',
            icon: Icons.person_add,
            features: const [
              'Quick registration process',
              'Advanced analytics tools',
              'Inventory management',
              '24/7 support',
            ],
            buttonText: 'Get Started',
            onTap: () {
              // Navigate to new seller registration
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SellerRegistrationScreen(),
                ),
              );
            },
          ),

          const SizedBox(height: 32),

          // EXISTING SELLER Card
          _GlassCard(
            title: 'EXISTING SELLER',
            icon: Icons.account_circle,
            features: const [
              'Access your dashboard',
              'Manage your listings',
              'View analytics',
              'Process orders',
            ],
            buttonText: 'Sign In',
            onTap: () {
              // Show mobile number modal
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return const MobileNumberModal();
                },
              );
            },
          ),

          const SizedBox(height: 48),
        ],
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<String> features;
  final String buttonText;
  final VoidCallback onTap;

  const _GlassCard({
    required this.title,
    required this.icon,
    required this.features,
    required this.buttonText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.3),
            Colors.green.withOpacity(0.1),
          ],
        ),
        border: Border.all(width: 1, color: Colors.white.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.3),
                      ),
                      child: Icon(icon, size: 32, color: Colors.green[700]),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                ...features.map(
                  (feature) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.green[600],
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          feature,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                    ),
                    child: Text(
                      buttonText,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
