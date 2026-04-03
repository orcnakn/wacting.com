import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:shared_preferences/shared_preferences.dart';
import '../../app/theme.dart';
import '../../core/services/api_service.dart';
import '../../core/services/locale_service.dart';
import '../../core/utils/format_utils.dart';

import '../social/notifications_screen.dart';
import 'story_section.dart';
import 'followers_section.dart';

class ProfileScreen extends StatefulWidget {
  final String? viewUserId;
  const ProfileScreen({Key? key, this.viewUserId}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _profile;
  bool _loading = true;
  bool _editingName = false;
  bool _editingBio = false;
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();

  // Wallet state
  Map<String, dynamic>? _wacStatus;
  List<dynamic> _txHistory = [];
  bool _walletLoading = true;

  // Location state
  bool _locationEnabled = false;
  double _locationOffsetMeters = 0;
  final _offsetController = TextEditingController(text: '0');

  // Settings state
  bool _settingsExpanded = false;

  bool get _isOwnProfile => widget.viewUserId == null || widget.viewUserId == apiService.userId;
  String get _targetUserId => widget.viewUserId ?? apiService.userId ?? '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
    _loadProfile();
    _restoreLocationSettings();
    localeService.addListener(_onLocaleChanged);
  }

  void _onLocaleChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _restoreLocationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _locationEnabled = prefs.getBool('wacting_location_enabled') ?? false;
        _locationOffsetMeters = prefs.getDouble('wacting_location_offset') ?? 0;
        _offsetController.text = _locationOffsetMeters.toInt().toString();
      });
    }
  }

  Future<void> _persistLocationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('wacting_location_enabled', _locationEnabled);
    await prefs.setDouble('wacting_location_offset', _locationOffsetMeters);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _bioController.dispose();
    _offsetController.dispose();
    localeService.removeListener(_onLocaleChanged);
    super.dispose();
  }

  Future<void> _loadProfile() async {
    if (!apiService.isLoggedIn) {
      setState(() => _loading = false);
      return;
    }
    try {
      final profileRes = await apiService.getProfileById(_targetUserId);
      if (mounted) {
        setState(() {
          _profile = profileRes;
          _nameController.text = (_profile?['displayName'] ?? '') as String;
          _bioController.text = (_profile?['description'] ?? '') as String;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadWallet() async {
    if (!apiService.isLoggedIn) {
      setState(() => _walletLoading = false);
      return;
    }
    try {
      final results = await Future.wait([
        apiService.getWacStatus(),
        apiService.getWalletHistory(),
      ]);
      if (mounted) {
        setState(() {
          _wacStatus = results[0] as Map<String, dynamic>;
          final histData = results[1] as Map<String, dynamic>;
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
        SnackBar(content: Text(t('only_letters')), backgroundColor: AppColors.accentRed),
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
        SnackBar(content: Text(t('name_update_failed')), backgroundColor: AppColors.accentRed),
      );
    }
  }

  Future<void> _updateBio() async {
    final newBio = _bioController.text.trim();
    try {
      await apiService.updateProfile(description: newBio);
      setState(() {
        _editingBio = false;
        _profile?['description'] = newBio;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('bio_update_failed')), backgroundColor: AppColors.accentRed),
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

    final displayName = (_profile?['displayName'] ?? t('user')) as String;
    final avatarUrl = _profile?['avatarUrl'] as String?;
    final sloganText = (_profile?['slogan'] ?? '') as String;

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        title: Text(_isOwnProfile ? t('profile') : displayName, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: AppColors.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        bottom: null,
      ),
      body: _buildProfileTab(displayName, avatarUrl, sloganText),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PROFIL TAB
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildProfileTab(String displayName, String? avatarUrl, String sloganText) {
    final bio = (_profile?['description'] ?? '') as String;

    return RefreshIndicator(
      onRefresh: _loadProfile,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Avatar ──
          Center(
            child: CircleAvatar(
              radius: 44,
              backgroundColor: AppColors.accentBlue.withOpacity(0.1),
              backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
              child: avatarUrl == null ? Icon(Icons.person, size: 44, color: AppColors.accentBlue) : null,
            ),
          ),
          const SizedBox(height: 12),

          // ── Display Name ──
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

          // ── Seviye rozeti ──
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accentAmber.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Lv. ${_profile?['profileLevel'] ?? 1}',
                style: TextStyle(color: AppColors.accentAmber, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Bolum 1: Kisisel Bilgiler ──
          _buildSocialPlatformsSection(),
          const SizedBox(height: 16),

          // ── Katildigi Kampanyalar ──
          _buildJoinedCampaignsSection(),
          const SizedBox(height: 16),

          // ── Bolum 2: Takipciler ──
          FollowersSection(
            userId: widget.viewUserId ?? apiService.userId ?? '',
            followerCount: (_profile?['followerCount'] ?? 0) as int,
            followingCount: (_profile?['followingCount'] ?? 0) as int,
          ),
          const SizedBox(height: 16),

          // ── Bolum 3: Story ──
          StorySection(
            isOwnProfile: _isOwnProfile,
            userId: widget.viewUserId ?? apiService.userId ?? '',
          ),

          // ── Ayarlar (sadece kendi profili) ──
          if (_isOwnProfile) ...[
            const SizedBox(height: 24),
            _buildSettingsSection(),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BIO SECTION
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildBioSection(String bio) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.auto_stories, color: AppColors.accentBlue, size: 18),
          const SizedBox(width: 8),
          Text('Story', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
          const Spacer(),
          if (_isOwnProfile && !_editingBio)
            GestureDetector(
              onTap: () => setState(() => _editingBio = true),
              child: Icon(Icons.edit, color: AppColors.textTertiary, size: 16),
            ),
        ]),
        const SizedBox(height: 8),
        if (_editingBio && _isOwnProfile) ...[
          TextField(
            controller: _bioController,
            maxLines: 4,
            maxLength: 250,
            style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: t('about_placeholder'),
              hintStyle: TextStyle(color: AppColors.textTertiary),
              filled: true,
              fillColor: AppColors.surfaceWhite,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.borderLight)),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton(
              onPressed: () => setState(() {
                _editingBio = false;
                _bioController.text = (_profile?['description'] ?? '') as String;
              }),
              child: Text(t('cancel'), style: TextStyle(color: AppColors.textTertiary)),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              onPressed: _updateBio,
              child: Text(t('save')),
            ),
          ]),
        ] else
          Text(
            bio.isNotEmpty ? bio : (_isOwnProfile ? t('no_bio_own') : t('no_bio_other')),
            style: TextStyle(
              color: bio.isNotEmpty ? AppColors.textSecondary : AppColors.textTertiary,
              fontSize: 13,
              fontStyle: bio.isEmpty ? FontStyle.italic : FontStyle.normal,
            ),
          ),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // JOINED CAMPAIGNS SECTION
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildJoinedCampaignsSection() {
    final memberships = (_profile?['campaignMemberships'] as List?) ?? [];
    if (memberships.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.campaign, color: AppColors.accentBlue, size: 18),
          const SizedBox(width: 8),
          Text(t('campaigns'), style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.accentBlue.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('${memberships.length}', style: TextStyle(color: AppColors.accentBlue, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 10),
        ...memberships.map<Widget>((m) {
          final campaign = m['campaign'] as Map<String, dynamic>? ?? {};
          final title = (campaign['title'] ?? '') as String;
          final slogan = (campaign['slogan'] ?? '') as String;
          final cachedLevel = campaign['cachedLevel'];
          final levelStr = cachedLevel is double ? cachedLevel.toStringAsFixed(0) : '${cachedLevel ?? 0}';
          final stanceType = (campaign['stanceType'] ?? 'SUPPORT') as String;
          final stanceColor = stanceType == 'EMERGENCY' ? const Color(0xFFFF0000) : const Color(0xFF4CAF50);

          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceWhite,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: stanceColor.withOpacity(0.2), width: 0.5),
            ),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (slogan.isNotEmpty)
                    Text(slogan, style: TextStyle(color: AppColors.textTertiary, fontSize: 11),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accentAmber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('Lv.$levelStr', style: TextStyle(color: AppColors.accentAmber, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ]),
          );
        }),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SOCIAL PLATFORMS SECTION
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSocialPlatformsSection() {
    final platforms = [
      _PlatformDef('instagram', 'Instagram', Icons.camera_alt, const Color(0xFFE1306C)),
      _PlatformDef('twitter', 'X (Twitter)', Icons.close, const Color(0xFF1DA1F2), textLabel: 'X'),
      _PlatformDef('facebook', 'Facebook', Icons.facebook, const Color(0xFF1877F2)),
      _PlatformDef('tiktok', 'TikTok', Icons.music_note, const Color(0xFF000000)),
      _PlatformDef('linkedin', 'LinkedIn', Icons.work, const Color(0xFF0A66C2)),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.share, color: AppColors.accentBlue, size: 18),
          const SizedBox(width: 8),
          Text(t('social_media'), style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
          const Spacer(),
          Builder(builder: (_) {
            final max = _getMaxFollowerEntry();
            if (max == null) return const SizedBox.shrink();
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.accentBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${max['short']}: ${_formatFollowerCount(max['count'] as int)}',
                style: TextStyle(color: AppColors.accentBlue, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            );
          }),
        ]),
        const SizedBox(height: 12),
        ...platforms.map((p) => _buildPlatformRow(p)),
        // Wacting platform follow
        _buildWactingFollowRow(),
      ]),
    );
  }

  Widget _buildPlatformRow(_PlatformDef platform) {
    final url = _getSocialUrl(platform.key);
    final hasUrl = url != null && url.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderLight, width: 0.5),
      ),
      child: Row(children: [
        // Platform icon
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: platform.color.withOpacity(0.1),
          ),
          child: Center(
            child: platform.textLabel != null
                ? Text(platform.textLabel!, style: TextStyle(color: platform.color, fontSize: 14, fontWeight: FontWeight.w900))
                : Icon(platform.icon, color: platform.color, size: 18),
          ),
        ),
        const SizedBox(width: 12),
        // Platform name + username + follower count
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(platform.name, style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
              if (_getFollowerCount(platform.key) > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: platform.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _formatFollowerCount(_getFollowerCount(platform.key)),
                    style: TextStyle(color: platform.color, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ]),
            if (hasUrl)
              Text(url!, style: TextStyle(color: AppColors.textTertiary, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis)
            else
              Text(t('not_connected'), style: TextStyle(color: AppColors.textTertiary, fontSize: 11, fontStyle: FontStyle.italic)),
          ]),
        ),
        // Follow button
        if (hasUrl && !_isOwnProfile)
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: platform.color,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              minimumSize: const Size(0, 32),
            ),
            onPressed: () {
              String fullUrl = url!;
              if (!fullUrl.startsWith('http')) fullUrl = 'https://$fullUrl';
              html.window.open(fullUrl, '_blank');
            },
            child: Text(t('follow'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        if (hasUrl && _isOwnProfile)
          Icon(Icons.check_circle, color: AppColors.accentGreen, size: 20),
        if (!hasUrl && _isOwnProfile)
          GestureDetector(
            onTap: () => _showEditSocialUrlDialog(platform.key, platform.name),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.accentBlue.withOpacity(0.5)),
              ),
              child: Text(t('add'), style: TextStyle(color: AppColors.accentBlue, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ),
      ]),
    );
  }

  Widget _buildWactingFollowRow() {
    final isFollowedByViewer = (_profile?['isFollowedByViewer'] ?? false) as bool;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderLight, width: 0.5),
      ),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
          child: const Center(
            child: Text('W', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Wacting', style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
            Text(isFollowedByViewer ? t('following_you') : t('platform_follow'),
                style: TextStyle(color: AppColors.textTertiary, fontSize: 11)),
          ]),
        ),
        if (!_isOwnProfile)
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isFollowedByViewer ? AppColors.surfaceLight : const Color(0xFFFF416C),
              foregroundColor: isFollowedByViewer ? AppColors.textPrimary : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              minimumSize: const Size(0, 32),
            ),
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
            child: Text(
              isFollowedByViewer ? t('unfollow') : t('follow'),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
      ]),
    );
  }

  void _showEditSocialUrlDialog(String platform, String platformName) {
    final usernameController = TextEditingController();
    final followerController = TextEditingController();
    final platformHints = {
      'instagram': '@kullaniciadi',
      'twitter': '@kullaniciadi',
      'facebook': 'kullaniciadi',
      'tiktok': '@kullaniciadi',
      'linkedin': 'kullaniciadi',
    };
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$platformName Ekle', style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: usernameController,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: platformHints[platform] ?? 'Kullanici adi',
                hintStyle: TextStyle(color: AppColors.textTertiary),
                prefixIcon: Icon(Icons.person, color: AppColors.textTertiary, size: 18),
                filled: true,
                fillColor: AppColors.surfaceLight,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.borderLight)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: followerController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Takipci sayisi (opsiyonel)',
                hintStyle: TextStyle(color: AppColors.textTertiary),
                prefixIcon: Icon(Icons.people, color: AppColors.textTertiary, size: 18),
                filled: true,
                fillColor: AppColors.surfaceLight,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.borderLight)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t('cancel'), style: TextStyle(color: AppColors.textTertiary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentBlue, foregroundColor: Colors.white),
            onPressed: () async {
              final username = usernameController.text.trim();
              if (username.isEmpty) return;
              try {
                // Send username — backend auto-generates URL
                switch (platform) {
                  case 'instagram': await apiService.updateProfileSocialUrls(instagramUrl: username); break;
                  case 'twitter': await apiService.updateProfileSocialUrls(twitterUrl: username); break;
                  case 'facebook': await apiService.updateProfileSocialUrls(facebookUrl: username); break;
                  case 'tiktok': await apiService.updateProfileSocialUrls(tiktokUrl: username); break;
                  case 'linkedin': await apiService.updateProfileSocialUrls(linkedinUrl: username); break;
                }
                // Update follower count if provided
                final followerText = followerController.text.trim();
                if (followerText.isNotEmpty) {
                  final count = int.tryParse(followerText);
                  if (count != null && count > 0) {
                    await apiService.updateSocialFollowers(platform, count);
                  }
                }
                Navigator.pop(ctx);
                _loadProfile();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(t('link_update_failed')), backgroundColor: AppColors.accentRed),
                );
              }
            },
            child: Text(t('save')),
          ),
        ],
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

  int _getFollowerCount(String platform) {
    switch (platform) {
      case 'instagram': return (_profile?['instagramFollowers'] as int?) ?? 0;
      case 'twitter': return (_profile?['twitterFollowers'] as int?) ?? 0;
      case 'facebook': return (_profile?['facebookFollowers'] as int?) ?? 0;
      case 'tiktok': return (_profile?['tiktokFollowers'] as int?) ?? 0;
      case 'linkedin': return (_profile?['linkedinFollowers'] as int?) ?? 0;
      default: return 0;
    }
  }

  String _formatFollowerCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '$count';
  }

  /// En yüksek takipçi sayısına sahip platformu döndürür.
  /// Dönen map: {'short': 'IG', 'count': 125000} veya null (hiç takipçi yoksa)
  Map<String, dynamic>? _getMaxFollowerEntry() {
    const entries = [
      {'key': 'instagram', 'short': 'IG'},
      {'key': 'twitter',   'short': 'X'},
      {'key': 'facebook',  'short': 'FB'},
      {'key': 'tiktok',    'short': 'TT'},
      {'key': 'linkedin',  'short': 'LI'},
    ];
    String? bestShort;
    int bestCount = 0;
    for (final e in entries) {
      final c = _getFollowerCount(e['key']!);
      if (c > bestCount) { bestCount = c; bestShort = e['short']; }
    }
    if (bestCount == 0) return null;
    return {'short': bestShort, 'count': bestCount};
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SETTINGS SECTION
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSettingsSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(children: [
        // Header
        GestureDetector(
          onTap: () => setState(() => _settingsExpanded = !_settingsExpanded),
          child: Container(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Icon(Icons.settings, color: AppColors.textSecondary, size: 20),
              const SizedBox(width: 8),
              Text(t('settings'), style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
              const Spacer(),
              Icon(
                _settingsExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                color: AppColors.textTertiary,
                size: 24,
              ),
            ]),
          ),
        ),

        if (_settingsExpanded) ...[
          Divider(height: 1, color: AppColors.borderLight),

          // ── Konum Ayarlari ──
          _buildLocationSection(),

          Divider(height: 1, color: AppColors.borderLight),

          // ── Kullanim Sozlesmesi ──
          _buildSettingsTile(
            icon: Icons.description_outlined,
            title: t('terms_of_use'),
            subtitle: t('terms_view'),
            onTap: () => _showTermsDialog(),
          ),

          Divider(height: 1, color: AppColors.borderLight),

          // ── Gizlilik Politikasi ──
          _buildSettingsTile(
            icon: Icons.privacy_tip_outlined,
            title: t('privacy_policy'),
            subtitle: t('privacy_view'),
            onTap: () => _showPrivacyDialog(),
          ),

          Divider(height: 1, color: AppColors.borderLight),

          // ── Bildirim Ayarlari ──
          _buildSettingsTile(
            icon: Icons.notifications_outlined,
            title: t('notification_settings'),
            subtitle: t('notification_manage'),
            onTap: () => _showNotificationSettingsDialog(),
          ),

          Divider(height: 1, color: AppColors.borderLight),

          // ── Istek ve Sikayet ──
          _buildSettingsTile(
            icon: Icons.feedback_outlined,
            title: t('feedback'),
            subtitle: t('feedback_send'),
            onTap: () => _showFeedbackDialog(),
          ),

          Divider(height: 1, color: AppColors.borderLight),

          // ── Dil Secimi ──
          _buildSettingsTile(
            icon: Icons.language,
            title: t('language'),
            subtitle: t('language_desc'),
            onTap: () => _showLanguageDialog(),
          ),

          Divider(height: 1, color: AppColors.borderLight),

          // ── Hesap Dondurma ──
          _buildSettingsTile(
            icon: Icons.pause_circle_outline,
            title: t('freeze_account'),
            subtitle: t('freeze_desc'),
            onTap: () => _showFreezeAccountDialog(),
            color: AppColors.accentAmber,
          ),

          Divider(height: 1, color: AppColors.borderLight),

          // ── Hesap Kapatma ──
          _buildSettingsTile(
            icon: Icons.delete_forever_outlined,
            title: t('delete_account'),
            subtitle: t('delete_desc'),
            onTap: () => _showDeleteAccountDialog(),
            color: AppColors.accentRed,
          ),

          Divider(height: 1, color: AppColors.borderLight),

          // ── Engellenen Kullanicilar ──
          _buildSettingsTile(
            icon: Icons.block,
            title: t('blocked_users'),
            subtitle: t('blocked_manage'),
            onTap: () => _showBlockedUsersDialog(),
          ),

          Divider(height: 1, color: AppColors.borderLight),

          // ── Yardim ──
          _buildSettingsTile(
            icon: Icons.help_outline,
            title: t('help'),
            subtitle: t('help_desc'),
            onTap: () => _showHelpDialog(),
          ),

          Divider(height: 1, color: AppColors.borderLight),

          // ── Cikis Yap ──
          Padding(
            padding: const EdgeInsets.all(14),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentRed.withOpacity(0.1),
                  foregroundColor: AppColors.accentRed,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.logout, size: 18),
                label: Text(t('logout'), style: const TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(t('logout'), style: TextStyle(color: AppColors.textPrimary)),
                      content: Text(t('logout_confirm'),
                          style: TextStyle(color: AppColors.textSecondary)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(t('cancel'), style: TextStyle(color: AppColors.textTertiary)),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentRed, foregroundColor: Colors.white),
                          onPressed: () {
                            Navigator.pop(ctx);
                            apiService.clearAuth();
                            html.window.location.reload();
                          },
                          child: Text(t('logout')),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? color,
  }) {
    final tileColor = color ?? AppColors.textSecondary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Icon(icon, color: tileColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(color: color ?? AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
              Text(subtitle, style: TextStyle(color: AppColors.textTertiary, fontSize: 11)),
            ]),
          ),
          Icon(Icons.chevron_right, color: AppColors.textTertiary, size: 20),
        ]),
      ),
    );
  }

  // ── Settings Dialogs ──

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            Row(children: [
              Icon(Icons.description_outlined, color: AppColors.accentBlue, size: 22),
              const SizedBox(width: 8),
              Text(t('terms_of_use'), style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
            ]),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  _getTermsText(),
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.6),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _showPrivacyDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            Row(children: [
              Icon(Icons.privacy_tip_outlined, color: AppColors.accentBlue, size: 22),
              const SizedBox(width: 8),
              Text(t('privacy_policy'), style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
            ]),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  t('privacy_coming'),
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.6),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _showNotificationSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.notifications_outlined, color: AppColors.accentBlue, size: 22),
          const SizedBox(width: 8),
          Text(t('notification_settings'), style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
        ]),
        content: Text(t('notification_coming'),
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('ok'))),
        ],
      ),
    );
  }

  void _showFeedbackDialog() {
    final subjectCtrl = TextEditingController();
    final messageCtrl = TextEditingController();
    String feedbackType = 'istek';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 450),
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.feedback_outlined, color: AppColors.accentBlue, size: 22),
                const SizedBox(width: 8),
                Text(t('feedback'), style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ]),
              const SizedBox(height: 16),
              // Type selection
              Row(children: [
                _feedbackTypeChip(t('feedback_request'), 'istek', feedbackType, (val) => setDialogState(() => feedbackType = val)),
                const SizedBox(width: 8),
                _feedbackTypeChip(t('feedback_complaint'), 'sikayet', feedbackType, (val) => setDialogState(() => feedbackType = val)),
                const SizedBox(width: 8),
                _feedbackTypeChip(t('feedback_suggestion'), 'oneri', feedbackType, (val) => setDialogState(() => feedbackType = val)),
              ]),
              const SizedBox(height: 12),
              TextField(
                controller: subjectCtrl,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: t('feedback_subject'),
                  hintStyle: TextStyle(color: AppColors.textTertiary),
                  filled: true, fillColor: AppColors.surfaceWhite,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.borderLight)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: messageCtrl,
                maxLines: 4,
                maxLength: 500,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: t('feedback_message'),
                  hintStyle: TextStyle(color: AppColors.textTertiary),
                  filled: true, fillColor: AppColors.surfaceWhite,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.borderLight)),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text(t('feedback_sent')),
                        backgroundColor: AppColors.accentGreen,
                      ),
                    );
                  },
                  child: Text(t('send'), style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _feedbackTypeChip(String label, String value, String current, Function(String) onSelect) {
    final selected = current == value;
    return GestureDetector(
      onTap: () => onSelect(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentBlue : AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.accentBlue : AppColors.borderLight),
        ),
        child: Text(label, style: TextStyle(
          color: selected ? Colors.white : AppColors.textSecondary,
          fontSize: 12, fontWeight: FontWeight.w600,
        )),
      ),
    );
  }

  void _showFreezeAccountDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.pause_circle_outline, color: AppColors.accentAmber, size: 22),
          const SizedBox(width: 8),
          Text(t('freeze_account'), style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t('freeze_confirm'),
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 12),
          Text(t('freeze_when'),
              style: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          _bulletPoint(t('freeze_1')),
          _bulletPoint(t('freeze_2')),
          _bulletPoint(t('freeze_3')),
          _bulletPoint(t('freeze_4')),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t('cancel'), style: TextStyle(color: AppColors.textTertiary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentAmber, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(t('freeze_coming')), backgroundColor: AppColors.accentAmber),
              );
            },
            child: Text(t('freeze')),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.delete_forever_outlined, color: AppColors.accentRed, size: 22),
          const SizedBox(width: 8),
          Text(t('delete_account'), style: TextStyle(color: AppColors.accentRed, fontSize: 16)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t('delete_irreversible'),
              style: TextStyle(color: AppColors.accentRed, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(t('delete_when'),
              style: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          _bulletPoint(t('delete_1')),
          _bulletPoint(t('delete_2')),
          _bulletPoint(t('delete_3')),
          _bulletPoint(t('delete_4')),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t('cancel'), style: TextStyle(color: AppColors.textTertiary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentRed, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(t('delete_coming')), backgroundColor: AppColors.accentRed),
              );
            },
            child: Text(t('delete_permanent')),
          ),
        ],
      ),
    );
  }

  void _showBlockedUsersDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.block, color: AppColors.textSecondary, size: 22),
          const SizedBox(width: 8),
          Text(t('blocked_users'), style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
        ]),
        content: Text(t('blocked_empty'),
            style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('ok'))),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.help_outline, color: AppColors.accentBlue, size: 22),
          const SizedBox(width: 8),
          Text(t('help'), style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t('faq'), style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(t('faq_coming'), style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
          const SizedBox(height: 16),
          Text(t('contact'), style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('destek@wacting.com', style: TextStyle(color: AppColors.accentBlue, fontSize: 12)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('ok'))),
        ],
      ),
    );
  }

  Widget _bulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('• ', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        Expanded(child: Text(text, style: TextStyle(color: AppColors.textSecondary, fontSize: 12))),
      ]),
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.language, color: AppColors.accentBlue, size: 22),
          const SizedBox(width: 8),
          Text(t('language_select'), style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
        ]),
        // İleride 20 dil ekleneceği için taşmayı önlemek adına SingleChildScrollView ekledik.
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: LocaleService.supportedLocales.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: _languageOption(entry.value, entry.key, ctx),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  String _getLanguageFlag(String locale) {
    switch (locale) {
      case 'tr': return '🇹🇷';
      case 'en': return '🇬🇧';
      case 'es': return '🇪🇸';
      case 'de': return '🇩🇪';
      default: return '🌍'; // Tanımlı olmayanlar için varsayılan dünya ikonu
    }
  }

  Widget _languageOption(String label, String locale, BuildContext ctx) {
    final isSelected = localeService.locale == locale;
    return InkWell(
      onTap: () {
        localeService.setLocale(locale);
        Navigator.pop(ctx);
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentBlue.withOpacity(0.1) : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.accentBlue : AppColors.borderLight,
          ),
        ),
        child: Row(children: [
          Text(_getLanguageFlag(locale), style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: TextStyle(
            color: AppColors.textPrimary, fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ))),
          if (isSelected)
            Icon(Icons.check_circle, color: AppColors.accentBlue, size: 20),
        ]),
      ),
    );
  }

  String _getTermsText() => t('terms_content');

  // ═══════════════════════════════════════════════════════════════════════════
  // LOCATION SECTION (inside settings)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildLocationSection() {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.location_on, color: AppColors.accentBlue, size: 20),
          const SizedBox(width: 8),
          Text(t('location_settings'), style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: Text(
              _locationEnabled ? t('location_on') : t('location_off'),
              style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
            ),
          ),
          Switch(
            value: _locationEnabled,
            activeColor: AppColors.accentTeal,
            onChanged: (val) async {
              if (val) {
                try {
                  final geo = html.window.navigator.geolocation;
                  final pos = await geo.getCurrentPosition(
                    enableHighAccuracy: true,
                    timeout: const Duration(seconds: 10),
                  );
                  final lat = pos.coords!.latitude! as double;
                  final lng = pos.coords!.longitude! as double;
                  await apiService.updateLocation(
                    locationEnabled: true,
                    locationLat: lat,
                    locationLng: lng,
                    locationOffsetMeters: _locationOffsetMeters,
                  );
                  setState(() => _locationEnabled = true);
                  _persistLocationSettings();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(t('location_enabled'))),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(t('location_denied')), backgroundColor: Colors.red),
                    );
                  }
                }
              } else {
                await apiService.updateLocation(locationEnabled: false);
                setState(() => _locationEnabled = false);
                _persistLocationSettings();
              }
            },
          ),
        ]),
        if (_locationEnabled) ...[
          const SizedBox(height: 8),
          Text(t('location_offset'), style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 4),
          Text(t('location_offset_desc'),
            style: TextStyle(color: AppColors.textTertiary, fontSize: 11)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _offsetController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: '0',
                  hintStyle: TextStyle(color: AppColors.textTertiary),
                  suffixText: 'm',
                  suffixStyle: TextStyle(color: AppColors.textTertiary),
                  filled: true,
                  fillColor: AppColors.surfaceWhite,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.borderLight)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentTeal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onPressed: () async {
                final offset = double.tryParse(_offsetController.text) ?? 0;
                setState(() => _locationOffsetMeters = offset);
                _persistLocationSettings();
                try {
                  await apiService.updateLocation(
                    locationEnabled: true,
                    locationOffsetMeters: offset,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(t('offset_set').replaceAll('{offset}', '${offset.toInt()}'))),
                  );
                } catch (_) {}
              },
              child: Text(t('save')),
            ),
          ]),
        ],
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // WALLET TAB
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildWalletTab() {
    if (_walletLoading) {
      _loadWallet();
      return Center(child: CircularProgressIndicator(color: AppColors.accentBlue));
    }

    final wacBalance = formatWac(_wacStatus?['wacBalance'] ?? '0');
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
            onSend: () => _showTransferModal(context),
            onReceive: () => _copyWalletId(walletId),
          ),
          const SizedBox(height: 20),
          Text(t('tx_history'), style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          if (_txHistory.isEmpty)
            Center(child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(t('no_tx'), style: TextStyle(color: AppColors.textTertiary)),
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
          Text('${t('wallet_label')}: ', style: TextStyle(color: AppColors.textTertiary, fontSize: 11)),
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
            label: Text(t('send'), style: const TextStyle(fontWeight: FontWeight.bold)),
            onPressed: onSend,
          )),
          const SizedBox(width: 8),
          Expanded(child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: color.withOpacity(0.1), foregroundColor: color,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.arrow_downward, size: 16),
            label: Text(t('receive_token'), style: const TextStyle(fontWeight: FontWeight.bold)),
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
    final tokenType = 'WAC';

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
      SnackBar(content: Text(t('wallet_copied')), backgroundColor: AppColors.navyPrimary, duration: const Duration(seconds: 1)),
    );
  }

  void _showTransferModal(BuildContext context) {
    final walletCtrl = TextEditingController();
    final amountCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceWhite,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 32),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('WAC ${t('send_token')}', style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: walletCtrl,
            style: TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: t('target_wallet'),
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
              hintText: t('amount'),
              suffixText: 'WAC',
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
                backgroundColor: AppColors.accentAmber,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                try {
                  await apiService.transferWac(walletCtrl.text.trim(), amountCtrl.text.trim());
                  Navigator.pop(ctx);
                  setState(() => _walletLoading = true);
                  _loadWallet();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(t('transfer_success')), backgroundColor: AppColors.navyPrimary),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(t('transfer_failed').replaceAll('{error}', '$e')), backgroundColor: AppColors.accentRed),
                  );
                }
              },
              child: Text(t('send_token').toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _PlatformDef {
  final String key;
  final String name;
  final IconData icon;
  final Color color;
  final String? textLabel;
  const _PlatformDef(this.key, this.name, this.icon, this.color, {this.textLabel});
}
