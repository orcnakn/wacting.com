import 'package:flutter/material.dart';
import '../../app/widgets/modern_card.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Mock notifications for UI demonstration
    final notifications = [
      {
        'id': '1',
        'type': 'new_follower',
        'title': 'New Follow Request',
        'message': 'CypherPunk99 wants to follow you and pledged 500 WAC.',
        'time': '2 mins ago',
        'read': false,
        'actionable': true,
      },
      {
        'id': '2',
        'type': 'token_received',
        'title': 'Tokens Received',
        'message': 'You received 150 tokens from EliteSniper.',
        'time': '1 hour ago',
        'read': true,
        'actionable': false,
      },
      {
        'id': '3',
        'type': 'request_approved',
        'title': 'Request Approved',
        'message': 'Your follow request to NeonRider was approved! Tokens deducted.',
        'time': 'Yesterday',
        'read': true,
        'actionable': false,
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        title: const Text('Alerts & Intel', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: notifications.isEmpty
          ? const Center(child: Text('No intel received.', style: TextStyle(color: Colors.white54)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final n = notifications[index];
                final isRead = n['read'] as bool;
                final isActionable = n['actionable'] as bool;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: ModernCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          backgroundColor: _getIconColor(n['type'] as String).withOpacity(0.2),
                          child: Icon(_getIconData(n['type'] as String), color: _getIconColor(n['type'] as String)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    n['title'] as String,
                                    style: TextStyle(
                                      color: isRead ? Colors.white70 : Colors.white,
                                      fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    n['time'] as String,
                                    style: const TextStyle(color: Colors.blueAccent, fontSize: 12),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                n['message'] as String,
                                style: const TextStyle(color: Colors.white54, fontSize: 14),
                              ),
                              if (isActionable) ...[
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.redAccent,
                                        side: const BorderSide(color: Colors.redAccent),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      onPressed: () {},
                                      child: const Text('Deny'),
                                    ),
                                    const SizedBox(width: 12),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.cyanAccent,
                                        foregroundColor: Colors.black,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      onPressed: () {},
                                      child: const Text('Accept', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              ]
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  IconData _getIconData(String type) {
    switch (type) {
      case 'new_follower':
        return Icons.person_add;
      case 'token_received':
        return Icons.monetization_on;
      case 'request_approved':
        return Icons.check_circle;
      default:
        return Icons.notifications;
    }
  }

  Color _getIconColor(String type) {
    switch (type) {
      case 'new_follower':
        return Colors.blueAccent;
      case 'token_received':
        return Colors.amberAccent;
      case 'request_approved':
        return Colors.greenAccent;
      default:
        return Colors.white54;
    }
  }
}
