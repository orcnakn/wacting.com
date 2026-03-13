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

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        title: Text('Profil', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: AppColors.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accentBlue,
          labelColor: AppColors.accentBlue,
          unselectedLabelColor: AppColors.textTertiary,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'PROFİL', icon: Icon(Icons.account_circle, size: 18)),
            Tab(text: 'KİŞİSEL', icon: Icon(Icons.people, size: 18)),
            Tab(text: 'BİLDİRİMLER', icon: Icon(Icons.notifications, size: 18)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ProfileTab(),
          _PersonalTab(),
          _NotificationsTab(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROFİL TAB — Avatar, Cüzdan
// ─────────────────────────────────────────────────────────────────────────────
class _ProfileTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Avatar & Kullanıcı Adı
          ModernCard(
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    const CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey,
                      backgroundImage: NetworkImage('https://via.placeholder.com/150'),
                    ),
                    Container(
                      decoration: BoxDecoration(color: AppColors.accentBlue, shape: BoxShape.circle),
                      child: IconButton(
                        icon: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                        onPressed: () {},
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'CypherPunk99',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Cüzdan
          Text(
            'Cüzdan',
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
                    Text('Toplam Bakiye', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text('12,450 WAC', style: TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.auto_graph, color: AppColors.accentTeal, size: 14),
                        const SizedBox(width: 4),
                        Text('Pasif Kazanç: +350 WAC',
                            style: TextStyle(color: AppColors.accentTeal, fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
                ModernButton(
                  text: 'Token Al',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const EconomyScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// KİŞİSEL TAB — Takipçiler / Takip Edilenler
// ─────────────────────────────────────────────────────────────────────────────
class _PersonalTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            indicatorColor: AppColors.navyLight,
            labelColor: AppColors.navyLight,
            unselectedLabelColor: AppColors.textTertiary,
            tabs: const [
              Tab(text: 'Takipçilerim'),
              Tab(text: 'Takip Ettiklerim'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildSocialList(isFollower: true),
                _buildSocialList(isFollower: false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialList({required bool isFollower}) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ModernCard(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.surfaceLight,
                  child: Icon(Icons.person, color: AppColors.textSecondary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('User_$index',
                          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.camera_alt, size: 16, color: Colors.pinkAccent),
                            onPressed: () {},
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.facebook, size: 16, color: Colors.blue),
                            onPressed: () {},
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.message, color: AppColors.navyLight),
                  onPressed: () {},
                ),
                if (!isFollower)
                  TextButton(
                    onPressed: () {},
                    child: Text('Bırak', style: TextStyle(color: AppColors.accentRed)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BİLDİRİMLER TAB
// ─────────────────────────────────────────────────────────────────────────────
class _NotificationsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final notifications = [
      {
        'id': '1',
        'type': 'new_follower',
        'title': 'Yeni Takip İsteği',
        'message': 'CypherPunk99 seni takip etmek istiyor ve 500 WAC teklif etti.',
        'time': '2 dk önce',
        'read': false,
        'actionable': true,
      },
      {
        'id': '2',
        'type': 'token_received',
        'title': 'Token Alındı',
        'message': 'EliteSniper\'dan 150 token aldın.',
        'time': '1 saat önce',
        'read': true,
        'actionable': false,
      },
      {
        'id': '3',
        'type': 'request_approved',
        'title': 'İstek Onaylandı',
        'message': 'NeonRider\'a gönderdiğin takip isteği onaylandı! Tokenlar düşüldü.',
        'time': 'Dün',
        'read': true,
        'actionable': false,
      },
    ];

    if (notifications.isEmpty) {
      return Center(child: Text('Bildirim yok.', style: TextStyle(color: AppColors.textTertiary)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: notifications.length,
      itemBuilder: (context, index) {
        final n = notifications[index];
        final isRead = n['read'] as bool;
        final isActionable = n['actionable'] as bool;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ModernCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: _iconColor(n['type'] as String).withOpacity(0.1),
                  child: Icon(_iconData(n['type'] as String), color: _iconColor(n['type'] as String)),
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
                              color: isRead ? AppColors.textSecondary : AppColors.textPrimary,
                              fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Text(n['time'] as String,
                              style: TextStyle(color: AppColors.accentBlue, fontSize: 11)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(n['message'] as String,
                          style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
                      if (isActionable) ...[
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.accentRed,
                                side: BorderSide(color: AppColors.accentRed),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () {},
                              child: const Text('Reddet'),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.accentTeal,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () {},
                              child: const Text('Kabul Et', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _iconData(String type) {
    switch (type) {
      case 'new_follower': return Icons.person_add;
      case 'token_received': return Icons.monetization_on;
      case 'request_approved': return Icons.check_circle;
      default: return Icons.notifications;
    }
  }

  Color _iconColor(String type) {
    switch (type) {
      case 'new_follower': return AppColors.accentBlue;
      case 'token_received': return AppColors.accentAmber;
      case 'request_approved': return AppColors.accentGreen;
      default: return AppColors.textTertiary;
    }
  }
}
