import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/format_utils.dart';
import '../social/notifications_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String? viewUserId; // null = own profile
  const ProfileScreen({Key? key, this.viewUserId}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _profile;
  List<dynamic> _dailyRewards = [];
  bool _loading = true;
  bool _editingName = false;
  final _nameController = TextEditingController();

  bool get _isOwnProfile => widget.viewUserId == null || widget.viewUserId == apiService.userId;
  String get _targetUserId => widget.viewUserId ?? apiService.userId ?? '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    if (!apiService.isLoggedIn) {
      setState(() => _loading = false);
      return;
    }
    try {
      final profileRes = await apiService.getProfileById(_targetUserId);
      List<dynamic> rewards = [];
      try {
        final rewardsRes = await apiService.getDailyRewards(_targetUserId);
        rewards = (rewardsRes['campaigns'] as List?) ?? [];
      } catch (_) {}
      if (mounted) {
        setState(() {
          _profile = profileRes;
          _dailyRewards = rewards;
          _nameController.text = (_profile?['displayName'] ?? '') as String;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateName() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty || newName.length > 16) return;
    // Only letters (including Turkish) and spaces
    if (!RegExp(r'^[a-zA-ZçÇğĞıİöÖşŞüÜ\s]+$').hasMatch(newName)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Sadece harf ve bosluk kullanin.'), backgroundColor: AppColors.accentRed),
      );
      return;
    }
    try {
      await apiService.updateProfile(displayName: newName);
      setState(() {
        _editingName = false;
        _profile?['displayName'] = newName;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Isim guncellenemedi.'), backgroundColor: AppColors.accentRed),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.pageBackground,
        body: Center(child: CircularProgressIndicator(color: AppColors.accentBlue)),
      );
    }

    final displayName = (_profile?['displayName'] ?? 'Kullanici') as String;
    final followerCount = (_profile?['followerCount'] ?? 0) as int;
    final followingCount = (_profile?['followingCount'] ?? 0) as int;
    final avatarUrl = _profile?['avatarUrl'] as String?;
    final sloganText = (_profile?['slogan'] ?? '') as String;

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
            Tab(text: 'PROFIL'),
            Tab(text: 'KISISEL'),
            Tab(text: 'BILDIRIMLER'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── PROFIL Tab ──
          RefreshIndicator(
            onRefresh: _loadProfile,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Avatar
                Center(
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: AppColors.accentBlue.withOpacity(0.1),
                    backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                    child: avatarUrl == null ? Icon(Icons.person, size: 40, color: AppColors.accentBlue) : null,
                  ),
                ),
                const SizedBox(height: 12),

                // Display Name (editable for own profile)
                Center(
                  child: _editingName && _isOwnProfile
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 180,
                              child: TextField(
                                controller: _nameController,
                                autofocus: true,
                                maxLength: 16,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                                decoration: InputDecoration(
                                  counterText: '',
                                  isDense: true,
                                  border: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.accentBlue)),
                                ),
                                onSubmitted: (_) => _updateName(),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.check, color: AppColors.accentGreen, size: 20),
                              onPressed: _updateName,
                            ),
                          ],
                        )
                      : GestureDetector(
                          onTap: _isOwnProfile ? () => setState(() => _editingName = true) : null,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                displayName,
                                style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              if (_isOwnProfile) ...[
                                const SizedBox(width: 6),
                                Icon(Icons.edit, color: AppColors.textTertiary, size: 14),
                              ],
                            ],
                          ),
                        ),
                ),

                if (sloganText.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Center(
                    child: Text('"$sloganText"',
                        style: TextStyle(color: AppColors.accentTeal, fontStyle: FontStyle.italic, fontSize: 13)),
                  ),
                ],
                const SizedBox(height: 16),

                // Follower / Following
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _statCol('Takipci', '$followerCount'),
                    const SizedBox(width: 32),
                    _statCol('Takip', '$followingCount'),
                  ],
                ),
                const SizedBox(height: 24),

                // Active Campaigns with Daily Rewards
                Text('Aktif Kampanyalar',
                    style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                if (_dailyRewards.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(child: Text('Aktif kampanya yok', style: TextStyle(color: AppColors.textTertiary))),
                  )
                else
                  ..._dailyRewards.map((r) {
                    final title = (r['title'] ?? '') as String;
                    final slogan = (r['slogan'] ?? '') as String;
                    final reward = (r['dailyReward'] ?? '0') as String;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.borderLight, width: 0.5),
                        ),
                        child: Row(
                          children: [
                            Container(width: 8, height: 8,
                              decoration: BoxDecoration(color: AppColors.accentBlue, shape: BoxShape.circle)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text('$title — $slogan',
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                            ),
                            const SizedBox(width: 8),
                            Text('+$reward WAC',
                              style: TextStyle(color: AppColors.accentGreen, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),

          // ── KISISEL Tab ──
          _buildPersonalTab(),

          // ── BILDIRIMLER Tab ──
          const NotificationsScreen(),
        ],
      ),
    );
  }

  Widget _statCol(String label, String value) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
      ],
    );
  }

  Widget _buildPersonalTab() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            indicatorColor: AppColors.navyLight,
            labelColor: AppColors.navyLight,
            unselectedLabelColor: AppColors.textTertiary,
            tabs: const [
              Tab(text: 'Takipcilerim'),
              Tab(text: 'Takip Ettiklerim'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildFollowerList(isFollower: true),
                _buildFollowerList(isFollower: false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowerList({required bool isFollower}) {
    return Center(
      child: Text(
        isFollower ? 'Takipci listesi yaklasimda...' : 'Takip listesi yaklasimda...',
        style: TextStyle(color: AppColors.textTertiary),
      ),
    );
  }
}
