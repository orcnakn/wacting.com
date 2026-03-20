import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/theme.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/format_utils.dart';

import '../social/notifications_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String? viewUserId;
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

  bool _showFollowers = false;
  bool _showFollowing = false;
  List<dynamic> _followersList = [];
  List<dynamic> _followingList = [];

  Map<String, dynamic>? _wacStatus;
  Map<String, dynamic>? _racBalance;
  List<dynamic> _txHistory = [];
  bool _walletLoading = true;

  bool get _isOwnProfile => widget.viewUserId == null || widget.viewUserId == apiService.userId;
  String get _targetUserId => widget.viewUserId ?? apiService.userId ?? '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _isOwnProfile ? 2 : 1, vsync: this);
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

  Future<void> _loadFollowers() async {
    try {
      final data = await apiService.getFollowers();
      if (mounted) setState(() => _followersList = data);
    } catch (_) {}
  }

  Future<void> _loadFollowing() async {
    try {
      final data = await apiService.getFollowing();
      if (mounted) setState(() => _followingList = data);
    } catch (_) {}
  }

  Future<void> _loadWallet() async {
    if (!apiService.isLoggedIn) {
      setState(() => _walletLoading = false);
      return;
    }
    try {
      final results = await Future.wait([
        apiService.getWacStatus(),
        apiService.getRacBalance(),
        apiService.getWalletHistory(),
      ]);
      if (mounted) {
        setState(() {
          _wacStatus = results[0] as Map<String, dynamic>;
          _racBalance = results[1] as Map<String, dynamic>;
          final histData = results[2] as Map<String, dynamic>;
          _txHistory = (histData['transactions'] as List?) ?? [];
          _walletLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _walletLoading = false);
    }
  }

  Future<void> _updateName() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty || newName.length > 16) return;
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
    final isFollowedByViewer = (_profile?['isFollowedByViewer'] ?? false) as bool;

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        title: Text(_isOwnProfile ? 'Profil' : displayName, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: AppColors.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        bottom: _isOwnProfile ? TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accentBlue,
          labelColor: AppColors.accentBlue,
          unselectedLabelColor: AppColors.textTertiary,
          indicatorWeight: 3,
          onTap: (index) {
            if (index == 1 && _walletLoading) _loadWallet();
          },
          tabs: const [
            Tab(text: 'PROFIL'),
            Tab(text: 'CUZDAN'),
          ],
        ) : null,
      ),
      body: _isOwnProfile
        ? TabBarView(
        controller: _tabController,
        children: [
          _buildProfileTab(displayName, followerCount, followingCount, avatarUrl, sloganText, isFollowedByViewer),
          _buildWalletTab(),
        ],
      )
        : _buildProfileTab(displayName, followerCount, followingCount, avatarUrl, sloganText, isFollowedByViewer),
    );
  }

  Widget _buildProfileTab(String displayName, int followerCount, int followingCount, String? avatarUrl, String sloganText, bool isFollowedByViewer) {
    return RefreshIndicator(
            onRefresh: _loadProfile,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: AppColors.accentBlue.withOpacity(0.1),
                    backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                    child: avatarUrl == null ? Icon(Icons.person, size: 40, color: AppColors.accentBlue) : null,
                  ),
                ),
                const SizedBox(height: 12),
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
                              Text(displayName, style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                              if (_isOwnProfile) ...[
                                const SizedBox(width: 6),
                                Icon(Icons.edit, color: AppColors.textTertiary, size: 14),
                              ],
                            ],
                          ),
                        ),
                ),
                const SizedBox(height: 8),
                _buildSocialMediaRow(isFollowedByViewer),
                if (sloganText.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: Text('"$sloganText"',
                        style: TextStyle(color: AppColors.accentTeal, fontStyle: FontStyle.italic, fontSize: 13)),
                  ),
                ],
                const SizedBox(height: 12),
                // Daily passive reward
                if (_dailyRewards.isNotEmpty)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.accentGreen.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.accentGreen.withOpacity(0.3)),
                      ),
                      child: Text(
                        '+${_dailyRewards.fold<double>(0, (sum, r) => sum + (double.tryParse((r['dailyReward'] ?? '0').toString()) ?? 0)).toStringAsFixed(2)} WAC / gun',
                        style: TextStyle(color: AppColors.accentGreen, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () {
                        setState(() => _showFollowers = !_showFollowers);
                        if (_showFollowers && _followersList.isEmpty) _loadFollowers();
                      },
                      child: _statCol('Takipci', '$followerCount', _showFollowers),
                    ),
                    const SizedBox(width: 32),
                    GestureDetector(
                      onTap: () {
                        setState(() => _showFollowing = !_showFollowing);
                        if (_showFollowing && _followingList.isEmpty) _loadFollowing();
                      },
                      child: _statCol('Takip', '$followingCount', _showFollowing),
                    ),
                  ],
                ),
                if (_showFollowers) _buildFollowList(_followersList, isFollower: true),
                if (_showFollowing) _buildFollowList(_followingList, isFollower: false),
                const SizedBox(height: 24),
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
              // Follow button for other profiles
              if (!_isOwnProfile) ...[
                const SizedBox(height: 20),
                Center(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isFollowedByViewer ? AppColors.surfaceLight : AppColors.accentBlue,
                      foregroundColor: isFollowedByViewer ? AppColors.textPrimary : Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    ),
                    icon: Icon(isFollowedByViewer ? Icons.person_remove : Icons.person_add, size: 18),
                    label: Text(isFollowedByViewer ? 'Takibi Birak' : 'Takip Et'),
                    onPressed: () async {
                      try {
                        if (isFollowedByViewer) {
                          await apiService.unfollowUser(_targetUserId);
                        } else {
                          await apiService.followUser(_targetUserId);
                        }
                        _loadProfile();
                      } catch (_) {}
                    },
                  ),
                ),
              ],
              ],
            ),
          );
  }

  Widget _buildSocialMediaRow(bool isFollowedByViewer) {
    final socialLinksOrder = _profile?['socialLinksOrder'] as String?;
    List<String> order = [];
    if (socialLinksOrder != null && socialLinksOrder.isNotEmpty) {
      try {
        order = List<String>.from(
          (socialLinksOrder.startsWith('['))
              ? (socialLinksOrder.split(',').map((e) => e.replaceAll(RegExp(r'[\[\]" ]'), '').trim()))
              : [socialLinksOrder],
        );
      } catch (_) {}
    }
    if (order.isEmpty) {
      final platforms = ['instagram', 'twitter', 'facebook', 'tiktok', 'linkedin'];
      for (final p in platforms) {
        final url = _profile?['${p}Url'] ?? _profile?['${p == 'twitter' ? 'twitter' : p}Url'];
        if (url != null && url.toString().isNotEmpty) order.add(p);
      }
    }
    order.add('wacting');

    if (order.length <= 1) return const SizedBox.shrink();

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Wrap(
          spacing: 10,
          children: order.map((platform) {
            if (platform == 'wacting') return _buildWactingIcon(isFollowedByViewer);
            final url = _getSocialUrl(platform);
            if (url == null || url.isEmpty) return const SizedBox.shrink();
            return _buildSocialIcon(platform, url, isFollowedByViewer);
          }).toList(),
        ),
      ),
    );
  }

  String? _getSocialUrl(String platform) {
    switch (platform) {
      case 'instagram': return _profile?['instagramUrl'] as String?;
      case 'twitter': return _profile?['twitterUrl'] as String?;
      case 'facebook': return _profile?['facebookUrl'] as String?;
      case 'tiktok': return _profile?['tiktokUrl'] as String?;
      case 'linkedin': return _profile?['linkedinUrl'] as String?;
      default: return null;
    }
  }

  Widget _buildSocialIcon(String platform, String url, bool isFollowed) {
    final Map<String, _SocialIconData> icons = {
      'instagram': _SocialIconData(Icons.camera_alt, const LinearGradient(
        colors: [Color(0xFFE1306C), Color(0xFF833AB4), Color(0xFFF77737)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      )),
      'twitter': _SocialIconData(Icons.close, null, bgColor: const Color(0xFF1DA1F2)),
      'facebook': _SocialIconData(Icons.facebook, null, bgColor: const Color(0xFF1877F2)),
      'tiktok': _SocialIconData(Icons.music_note, null, bgColor: Colors.black87),
      'linkedin': _SocialIconData(Icons.work, null, bgColor: const Color(0xFF0A66C2)),
    };
    final data = icons[platform];
    if (data == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () {
        String fullUrl = url;
        if (!fullUrl.startsWith('http')) fullUrl = 'https://$fullUrl';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(fullUrl), duration: const Duration(seconds: 2)),
        );
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: data.gradient,
          color: data.gradient == null ? data.bgColor : null,
          border: isFollowed ? Border.all(color: AppColors.accentTeal, width: 2) : null,
        ),
        child: Center(
          child: platform == 'twitter'
              ? const Text('X', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))
              : Icon(data.icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _buildWactingIcon(bool isFollowed) {
    return Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        border: isFollowed ? Border.all(color: AppColors.accentTeal, width: 2) : null,
      ),
      child: const Center(
        child: Text('W', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
      ),
    );
  }

  Widget _statCol(String label, String value, bool expanded) {
    return Column(
      children: [
        Text(value, style: TextStyle(
          color: expanded ? AppColors.accentBlue : AppColors.textPrimary,
          fontWeight: FontWeight.bold, fontSize: 16,
        )),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
            Icon(expanded ? Icons.expand_less : Icons.expand_more,
                color: AppColors.textTertiary, size: 14),
          ],
        ),
      ],
    );
  }

  Widget _buildFollowList(List<dynamic> items, {required bool isFollower}) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Center(child: Text(
          isFollower ? 'Henuz takipcin yok.' : 'Henuz kimseyi takip etmiyorsun.',
          style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
        )),
      );
    }
    return Container(
      margin: const EdgeInsets.only(top: 8),
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderLight, width: 0.5),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: items.length,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemBuilder: (context, index) {
          final item = items[index] as Map<String, dynamic>;
          final user = isFollower ? item['follower'] : item['following'];
          if (user == null) return const SizedBox.shrink();
          final name = (user['displayName'] ?? user['slogan'] ?? 'Kullanici') as String;
          final slogan = (user['slogan'] ?? '') as String;
          return ListTile(
            dense: true,
            onTap: () {
              final uid = user['id'] as String?;
              if (uid != null && uid != _targetUserId) {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ProfileScreen(viewUserId: uid),
                ));
              }
            },
            leading: CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.accentBlue.withOpacity(0.1),
              child: Icon(Icons.person, size: 16, color: AppColors.accentBlue),
            ),
            title: Text(name, style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: slogan.isNotEmpty
                ? Text(slogan, style: TextStyle(color: AppColors.textTertiary, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis)
                : null,
            trailing: !isFollower && _isOwnProfile
                ? GestureDetector(
                    onTap: () async {
                      try {
                        await apiService.unfollowUser(user['id']);
                        _loadFollowing();
                        _loadProfile();
                      } catch (_) {}
                    },
                    child: Text('Birak', style: TextStyle(color: AppColors.accentRed, fontSize: 11, fontWeight: FontWeight.bold)),
                  )
                : null,
          );
        },
      ),
    );
  }

  Widget _buildWalletTab() {
    if (_walletLoading) {
      _loadWallet();
      return Center(child: CircularProgressIndicator(color: AppColors.accentBlue));
    }

    final wacBalance = formatWac(_wacStatus?['wacBalance'] ?? '0');
    final racBal = _racBalance?['racBalance'] ?? 0;
    final walletId = _profile?['walletId'] ?? '';

    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _walletLoading = true);
        await _loadWallet();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildWalletCard(
            title: 'WAC',
            icon: Icons.account_balance_wallet,
            color: AppColors.accentAmber,
            walletId: walletId,
            balance: '$wacBalance WAC',
            onSend: () => _showTransferModal(context, isWac: true),
            onReceive: () => _copyWalletId(walletId),
          ),
          const SizedBox(height: 12),
          _buildWalletCard(
            title: 'RAC',
            icon: Icons.shield,
            color: AppColors.accentTeal,
            walletId: walletId,
            balance: '$racBal RAC',
            onSend: () => _showTransferModal(context, isWac: false),
            onReceive: () => _copyWalletId(walletId),
          ),
          const SizedBox(height: 20),
          Text('Islem Gecmisi', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          if (_txHistory.isEmpty)
            Center(child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Henuz islem yok.', style: TextStyle(color: AppColors.textTertiary)),
            ))
          else
            ..._txHistory.map((tx) => _buildTxRow(tx as Map<String, dynamic>)),
        ],
      ),
    );
  }

  Widget _buildWalletCard({
    required String title,
    required IconData icon,
    required Color color,
    required String walletId,
    required String balance,
    required VoidCallback onSend,
    required VoidCallback onReceive,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Text('Cuzdan: ', style: TextStyle(color: AppColors.textTertiary, fontSize: 11)),
          Expanded(child: Text(walletId, style: TextStyle(color: AppColors.textPrimary, fontSize: 11, fontFamily: 'monospace'),
              maxLines: 1, overflow: TextOverflow.ellipsis)),
          GestureDetector(
            onTap: () => _copyWalletId(walletId),
            child: Icon(Icons.copy, color: AppColors.textTertiary, size: 14),
          ),
        ]),
        const SizedBox(height: 6),
        Text(balance, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 24)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: color.withOpacity(0.1), foregroundColor: color,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.arrow_upward, size: 16),
            label: const Text('Gonder', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: onSend,
          )),
          const SizedBox(width: 8),
          Expanded(child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: color.withOpacity(0.1), foregroundColor: color,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.arrow_downward, size: 16),
            label: const Text('Al', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: onReceive,
          )),
        ]),
      ]),
    );
  }

  Widget _buildTxRow(Map<String, dynamic> tx) {
    final type = (tx['type'] ?? '') as String;
    final amount = (tx['amount'] ?? '0') as String;
    final note = (tx['note'] ?? '') as String;
    final createdAt = DateTime.tryParse((tx['createdAt'] ?? '').toString())?.toLocal();
    final timeStr = createdAt != null ? '${createdAt.hour.toString().padLeft(2,'0')}:${createdAt.minute.toString().padLeft(2,'0')}' : '';
    final dateStr = createdAt != null ? '${createdAt.day}/${createdAt.month}/${createdAt.year}' : '';

    final isIncoming = type.contains('RETURN') || type.contains('REWARD') || type.contains('BONUS') || type.contains('DEPOSIT') || type.contains('WELCOME');
    final color = isIncoming ? AppColors.accentGreen : AppColors.accentRed;
    final prefix = isIncoming ? '+' : '-';
    final tokenType = type.startsWith('RAC') ? 'RAC' : 'WAC';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderLight, width: 0.5),
      ),
      child: Row(children: [
        Icon(isIncoming ? Icons.arrow_downward : Icons.arrow_upward, color: color, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(type.replaceAll('_', ' '), style: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
          if (note.isNotEmpty)
            Text(note, style: TextStyle(color: AppColors.textTertiary, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('$prefix$amount $tokenType', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
          Text('$dateStr $timeStr', style: TextStyle(color: AppColors.textTertiary, fontSize: 10)),
        ]),
      ]),
    );
  }

  void _copyWalletId(String walletId) {
    Clipboard.setData(ClipboardData(text: walletId));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: const Text('Cuzdan kodu kopyalandi!'), backgroundColor: AppColors.navyPrimary, duration: const Duration(seconds: 1)),
    );
  }

  void _showTransferModal(BuildContext context, {required bool isWac}) {
    final walletCtrl = TextEditingController();
    final amountCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceWhite,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 32),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${isWac ? "WAC" : "RAC"} Gonder', style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: walletCtrl,
            style: TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Hedef cuzdan kodu',
              hintStyle: TextStyle(color: AppColors.textTertiary),
              filled: true, fillColor: AppColors.surfaceLight,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: amountCtrl,
            keyboardType: TextInputType.number,
            style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              hintText: 'Miktar',
              suffixText: isWac ? 'WAC' : 'RAC',
              suffixStyle: TextStyle(color: AppColors.accentAmber, fontWeight: FontWeight.bold),
              filled: true, fillColor: AppColors.surfaceLight,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isWac ? AppColors.accentAmber : AppColors.accentTeal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                try {
                  if (isWac) {
                    await apiService.transferWac(walletCtrl.text.trim(), amountCtrl.text.trim());
                  } else {
                    await apiService.transferRac(walletCtrl.text.trim(), int.parse(amountCtrl.text.trim()));
                  }
                  Navigator.pop(ctx);
                  setState(() => _walletLoading = true);
                  _loadWallet();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: const Text('Transfer basarili!'), backgroundColor: AppColors.navyPrimary),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Transfer basarisiz: $e'), backgroundColor: AppColors.accentRed),
                  );
                }
              },
              child: Text('GONDER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _SocialIconData {
  final IconData icon;
  final Gradient? gradient;
  final Color? bgColor;
  _SocialIconData(this.icon, this.gradient, {this.bgColor});
}
