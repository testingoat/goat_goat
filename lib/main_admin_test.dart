import 'package:flutter/material.dart';

void main() {
  print('🚀 Starting minimal admin test...');
  runApp(const MinimalAdminApp());
}

class MinimalAdminApp extends StatelessWidget {
  const MinimalAdminApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    print('📱 Building MinimalAdminApp...');
    return MaterialApp(
      title: 'Admin Test',
      home: Scaffold(
        backgroundColor: Colors.green[50],
        body: Center(
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.admin_panel_settings,
                  size: 64,
                  color: Colors.green[600],
                ),
                const SizedBox(height: 16),
                Text(
                  'Goat Goat Admin Panel',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[800],
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Test Version - Loading Successfully!',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    print('✅ Button clicked - Flutter is working!');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Flutter web is working correctly!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                  child: const Text('Test Button'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
