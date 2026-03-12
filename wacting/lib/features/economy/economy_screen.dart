import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../app/widgets/modern_card.dart';
import '../../app/widgets/modern_button.dart';

class EconomyScreen extends StatelessWidget {
  const EconomyScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        title: Text('Store', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: AppColors.textPrimary)),
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
              backgroundColor: AppColors.accentBlue.withOpacity(0.06),
              child: Column(
                children: [
                  Text('Current Balance', style: TextStyle(color: AppColors.textTertiary, fontSize: 14)),
                  const SizedBox(height: 8),
                  Text('12,450 WAC', style: TextStyle(color: AppColors.textPrimary, fontSize: 36, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Token Bundles',
              style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 16),
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
                    Text(title, style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                    if (isPopular) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accentBlue,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('POPULAR', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      )
                    ]
                  ],
                ),
                const SizedBox(height: 4),
                Text(amount, style: TextStyle(color: AppColors.textTertiary, fontSize: 14)),
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
