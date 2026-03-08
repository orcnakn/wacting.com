import 'package:flutter/material.dart';
import '../../app/widgets/modern_card.dart';
import '../../app/widgets/modern_button.dart';

class EconomyScreen extends StatelessWidget {
  const EconomyScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        title: const Text('Store', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ModernCard(
              backgroundColor: const Color(0xFF007AFF).withOpacity(0.1),
              child: Column(
                children: const [
                  Text('Current Balance', style: TextStyle(color: Colors.white54, fontSize: 14)),
                  SizedBox(height: 8),
                  Text('12,450 WAC', style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Token Bundles',
              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 16),
            _buildStoreItem('Starter Pack', '1,000 WAC', '\$0.99'),
            _buildStoreItem('Growth Spurt', '5,500 WAC', '\$4.99'),
            _buildStoreItem('World Dominator', '12,000 WAC', '\$9.99', isPopular: true),
            _buildStoreItem('Whale Tier', '25,000 WAC', '\$19.99'),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreItem(String title, String amount, String price, {bool isPopular = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: ModernCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                    if (isPopular) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF007AFF),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('POPULAR', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      )
                    ]
                  ],
                ),
                const SizedBox(height: 4),
                Text(amount, style: const TextStyle(color: Colors.white54, fontSize: 14)),
              ],
            ),
            ModernButton(
              text: price,
              onPressed: () {
                // Trigger RevenueCat purchase flow
              },
            )
          ],
        ),
      ),
    );
  }
}
