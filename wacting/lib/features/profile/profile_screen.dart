import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../app/widgets/modern_card.dart';
import '../../app/widgets/modern_button.dart';
import '../economy/economy_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  double _iconSize = 1.0;
  String _iconAlign = 'center';

  final TextEditingController _sloganCtl = TextEditingController(text: 'World domination imminent.');
  final TextEditingController _descCtl = TextEditingController(text: 'I am a placeholder description for now.');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        title: Text('Profile', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: AppColors.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Avatar & Name Card
            ModernCard(
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      const CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey,
                        backgroundImage: NetworkImage('https://via.placeholder.com/150'), // Mock avatar
                      ),
                      Container(
                        decoration: BoxDecoration(color: AppColors.accentBlue, shape: BoxShape.circle),
                        child: IconButton(
                          icon: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                          onPressed: () {
                             // TODO: Implement Image Picker upload to backend
                          },
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'CypherPunk99',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _sloganCtl,
                    style: TextStyle(color: AppColors.textSecondary),
                    decoration: InputDecoration(
                        labelText: 'Slogan',
                        labelStyle: TextStyle(color: AppColors.textTertiary),
                        filled: true,
                        fillColor: AppColors.surfaceLight,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descCtl,
                    maxLines: 3,
                    style: TextStyle(color: AppColors.textSecondary),
                    decoration: InputDecoration(
                        labelText: 'Description',
                        labelStyle: TextStyle(color: AppColors.textTertiary),
                        filled: true,
                        fillColor: AppColors.surfaceLight,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                     mainAxisAlignment: MainAxisAlignment.end,
                     children: [
                         ModernButton(text: 'Save Details', onPressed: () {
                             // TODO: Send to PUT /api/profile
                         }),
                     ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Icon Progression Stats
            Text(
              'Map Appearance',
              style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 12),
            ModernCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                            Text('Visual Size', style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
                            Text('${_iconSize.toStringAsFixed(1)}x', style: TextStyle(color: AppColors.accentBlue, fontWeight: FontWeight.bold)),
                        ],
                    ),
                    Slider(
                      value: _iconSize,
                      min: 0.5,
                      max: 5.0, // This would dynamically be bound to User.tokens / 100
                      divisions: 45,
                      activeColor: AppColors.accentBlue,
                      onChanged: (val) => setState(() => _iconSize = val),
                    ),
                    const SizedBox(height: 12),
                    Text('Icon Alignment', style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                        segments: const [
                            ButtonSegment(value: 'top', label: Text('Top')),
                            ButtonSegment(value: 'center', label: Text('Center')),
                            ButtonSegment(value: 'bottom', label: Text('Bottom')),
                        ],
                        selected: <String>{_iconAlign},
                        onSelectionChanged: (Set<String> newSelection) {
                            setState(() {
                                _iconAlign = newSelection.first;
                            });
                        },
                        style: ButtonStyle(
                            backgroundColor: WidgetStateProperty.resolveWith<Color>(
                                (states) => states.contains(WidgetState.selected) ? AppColors.accentBlue : Colors.transparent,
                            ),
                            foregroundColor: WidgetStateProperty.resolveWith<Color>(
                                (states) => states.contains(WidgetState.selected) ? Colors.white : AppColors.textPrimary,
                            ),
                        ),
                    ),
                    const SizedBox(height: 16),
                    Align(
                        alignment: Alignment.centerRight,
                        child: ModernButton(text: 'Apply Settings', onPressed: () {})
                    )
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Token Wallet
            Text(
              'Wallet',
              style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 12),
            ModernCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Row(
                         children: [
                             Text('Total Balance', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                         ]
                       ),
                       const SizedBox(height: 4),
                       Text('12,450 WAC', style: TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold)),
                       const SizedBox(height: 8),
                       Row(
                         children: [
                             Icon(Icons.auto_graph, color: AppColors.accentTeal, size: 14),
                             SizedBox(width: 4),
                             Text('Passive Earnings: +350 WAC', style: TextStyle(color: AppColors.accentTeal, fontSize: 13, fontWeight: FontWeight.bold)),
                         ]
                       )
                    ],
                  ),
                  ModernButton(
                    text: 'Get Tokens',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const EconomyScreen()),
                      );
                    },
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
