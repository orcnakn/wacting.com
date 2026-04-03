import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../core/services/api_service.dart';
import '../../core/services/locale_service.dart';
import 'profile_screen.dart';

class FollowersSection extends StatefulWidget {
  final String userId;
  final int followerCount;
  final int followingCount;

  const FollowersSection({
    Key? key,
    required this.userId,
    this.followerCount = 0,
    this.followingCount = 0,
  }) : super(key: key);

  @override
  State<FollowersSection> createState() => _FollowersSectionState();
}

class _FollowersSectionState extends State<FollowersSection> {
  List<dynamic> _followers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFollowers();
  }

  Future<void> _loadFollowers() async {
    try {
      final followers = await apiService.getFollowers();
      if (mounted) setState(() { _followers = followers; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.people, color: AppColors.accentBlue, size: 18),
          const SizedBox(width: 8),
          Text(t('followers'), style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.accentBlue.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('${widget.followerCount}', style: TextStyle(color: AppColors.accentBlue, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.accentTeal.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('${widget.followingCount} ${t('following')}', style: TextStyle(color: AppColors.accentTeal, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 10),
        if (_loading)
          Center(child: Padding(
            padding: const EdgeInsets.all(16),
            child: CircularProgressIndicator(color: AppColors.accentBlue, strokeWidth: 2),
          ))
        else if (_followers.isEmpty)
          Center(child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Henuz takipci yok.', style: TextStyle(color: AppColors.textTertiary, fontSize: 12, fontStyle: FontStyle.italic)),
          ))
        else
          ..._followers.take(10).map<Widget>((f) {
            final follower = f['follower'] ?? f;
            final name = (follower['displayName'] ?? '') as String;
            final slogan = (follower['slogan'] ?? '') as String;
            final followerId = (follower['id'] ?? '') as String;
            final displayLabel = name.isNotEmpty ? name : (slogan.isNotEmpty ? slogan : 'Kullanici');

            return GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ProfileScreen(viewUserId: followerId),
                ));
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceWhite,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.borderLight, width: 0.5),
                ),
                child: Row(children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.accentBlue.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(child: Icon(Icons.person, color: AppColors.accentBlue, size: 16)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(displayLabel, style: TextStyle(
                    color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500,
                  ), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  Icon(Icons.chevron_right, color: AppColors.textTertiary, size: 16),
                ]),
              ),
            );
          }),
        if (_followers.length > 10)
          Center(child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('+${_followers.length - 10} daha', style: TextStyle(color: AppColors.textTertiary, fontSize: 11)),
          )),
      ]),
    );
  }
}
