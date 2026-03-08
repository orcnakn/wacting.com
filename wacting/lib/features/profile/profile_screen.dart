import 'package:flutter/material.dart';
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
      backgroundColor: const Color(0xFF0D0D0D), // Deeper true dark
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
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
                        decoration: BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
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
                  const Text(
                    'CypherPunk99',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _sloganCtl,
                    style: const TextStyle(color: Colors.white70),
                    decoration: InputDecoration(
                        labelText: 'Slogan',
                        labelStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.white10,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descCtl,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white70),
                    decoration: InputDecoration(
                        labelText: 'Description',
                        labelStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.white10,
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
            const Text(
              'Map Appearance',
              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 12),
            ModernCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                            const Text('Visual Size', style: TextStyle(color: Colors.white, fontSize: 16)),
                            Text('${_iconSize.toStringAsFixed(1)}x', style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                        ],
                    ),
                    Slider(
                      value: _iconSize,
                      min: 0.5,
                      max: 5.0, // This would dynamically be bound to User.tokens / 100
                      divisions: 45,
                      activeColor: Colors.blueAccent,
                      onChanged: (val) => setState(() => _iconSize = val),
                    ),
                    const SizedBox(height: 12),
                    const Text('Icon Alignment', style: TextStyle(color: Colors.white, fontSize: 16)),
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
                            backgroundColor: MaterialStateProperty.resolveWith<Color>(
                                (states) => states.contains(MaterialState.selected) ? Colors.blueAccent : Colors.transparent,
                            ),
                            foregroundColor: MaterialStateProperty.all(Colors.white)
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
            const Text(
              'Wallet',
              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 14),
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
                             const Text('Total Balance', style: TextStyle(color: Colors.white54, fontSize: 12)),
                         ]
                       ),
                       const SizedBox(height: 4),
                       const Text('12,450 WAC', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                       const SizedBox(height: 8),
                       Row(
                         children: const [
                             Icon(Icons.auto_graph, color: Colors.cyanAccent, size: 14),
                             SizedBox(width: 4),
                             Text('Passive Earnings: +350 WAC', style: TextStyle(color: Colors.cyanAccent, fontSize: 13, fontWeight: FontWeight.bold)),
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
