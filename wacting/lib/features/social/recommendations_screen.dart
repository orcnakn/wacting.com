import 'package:flutter/material.dart';
import '../../app/widgets/modern_card.dart';
import '../../app/widgets/modern_button.dart';
import 'package:dio/dio.dart';

class RecommendationsScreen extends StatefulWidget {
  final String userToken;

  const RecommendationsScreen({Key? key, required this.userToken}) : super(key: key);

  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _matches = [];

  @override
  void initState() {
    super.initState();
    _fetchAIMatchmaking();
  }

  Future<void> _fetchAIMatchmaking() async {
    setState(() { _isLoading = true; _error = null; });
    await Future.delayed(const Duration(milliseconds: 500));
    
    final mockMatches = [
      {'slogan': 'Defenders of Earth', 'aiMatchScore': 98, 'lastKnownX': 255.4, 'lastKnownY': 102.1},
      {'slogan': 'Cosmic Federation', 'aiMatchScore': 91, 'lastKnownX': 12.9, 'lastKnownY': 400.8},
      {'slogan': 'Red Faction', 'aiMatchScore': 86, 'lastKnownX': 350.5, 'lastKnownY': 350.5},
      {'slogan': 'Blue Shift Alliance', 'aiMatchScore': 81, 'lastKnownX': 45.0, 'lastKnownY': 199.2},
    ];

    setState(() {
      _matches = mockMatches;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        title: const Text('AI STRATEGIC COMMANDS', style: TextStyle(color: Colors.cyanAccent, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.cyanAccent),
            onPressed: () {
              setState(() {
                _isLoading = true;
                _error = null;
              });
              _fetchAIMatchmaking();
            },
          )
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
        : _error != null 
          ? Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _matches.length,
              itemBuilder: (context, index) {
                final match = _matches[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: ModernCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(match['slogan'] ?? 'Unknown Commander', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.cyanAccent.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('${match['aiMatchScore']}% MATCH', style: const TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                            )
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Located at Grid X: ${match['lastKnownX'].toStringAsFixed(1)} Y: ${match['lastKnownY'].toStringAsFixed(1)}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: ModernButton(text: 'SEND ALLIANCE REQUEST', onPressed: () {})),
                            const SizedBox(width: 8),
                            Expanded(child: ModernButton(text: 'GIFT TOKENS', onPressed: () {})),
                          ],
                        )
                      ],
                    )
                  ),
                );
              },
            )
    );
  }
}
