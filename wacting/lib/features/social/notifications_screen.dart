import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../core/services/api_service.dart';
import '../../core/services/locale_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _loading = true);
    try {
      final data = await apiService.getNotifications(limit: 50);
      if (mounted) {
        setState(() {
          _notifications = (data['notifications'] as List?) ?? [];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'FOLLOW_REQUEST': return Icons.person_add;
      case 'FOLLOW_ACCEPTED': return Icons.person;
      case 'POLL_CREATED': return Icons.how_to_vote;
      case 'POLL_CLOSED': return Icons.check_circle;
      case 'DAILY_WAC_REWARD': return Icons.monetization_on;
      case 'RAC_PROTEST_STARTED': return Icons.warning;
      case 'DIRECT_MESSAGE': return Icons.message;
      case 'CAMPAIGN_CHANGE': return Icons.edit;
      case 'CAMPAIGN_TRENDING': return Icons.trending_up;
      case 'SYSTEM': return Icons.campaign;
      default: return Icons.info;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'FOLLOW_REQUEST': return AppColors.accentBlue;
      case 'FOLLOW_ACCEPTED': return AppColors.accentGreen;
      case 'POLL_CREATED': return AppColors.accentAmber;
      case 'POLL_CLOSED': return AppColors.accentTeal;
      case 'DAILY_WAC_REWARD': return AppColors.accentAmber;
      case 'RAC_PROTEST_STARTED': return AppColors.accentRed;
      case 'DIRECT_MESSAGE': return AppColors.accentBlue;
      case 'CAMPAIGN_CHANGE': return AppColors.accentTeal;
      case 'CAMPAIGN_TRENDING': return AppColors.accentAmber;
      case 'SYSTEM': return AppColors.accentBlue;
      default: return AppColors.textTertiary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(t('notifications'), style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 28,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: Icon(Icons.arrow_forward, color: AppColors.textPrimary, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              GestureDetector(
                onTap: () async {
                  await apiService.markAllNotificationsRead();
                  _loadNotifications();
                },
                child: Text(t('mark_all_read'), style: TextStyle(color: AppColors.accentTeal, fontSize: 10)),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: AppColors.accentBlue))
          : _notifications.isEmpty
              ? Center(child: Text(t('no_notifications'), style: TextStyle(color: AppColors.textTertiary)))
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final notif = _notifications[index] as Map<String, dynamic>;
                      final type = (notif['type'] ?? 'SYSTEM') as String;
                      final title = (notif['title'] ?? '') as String;
                      final body = (notif['body'] ?? '') as String;
                      final isRead = notif['read'] == true;
                      final createdAt = DateTime.tryParse((notif['createdAt'] ?? '').toString());
                      final timeAgo = createdAt != null
                          ? _timeAgo(createdAt)
                          : '';

                      return InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () async {
                          if (!isRead && notif['id'] != null) {
                            await apiService.markNotificationRead(notif['id']);
                            setState(() => notif['read'] = true);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isRead ? AppColors.surfaceLight : AppColors.accentBlue.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isRead ? AppColors.borderLight : AppColors.accentBlue.withOpacity(0.2),
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(_iconForType(type), color: _colorForType(type), size: 22),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                        fontSize: 13,
                                      )),
                                    if (body.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(body,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(color: AppColors.textTertiary, fontSize: 11)),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(timeAgo, style: TextStyle(color: AppColors.textTertiary, fontSize: 10)),
                              if (!isRead) ...[
                                const SizedBox(width: 6),
                                Container(width: 6, height: 6,
                                  decoration: BoxDecoration(color: AppColors.accentBlue, shape: BoxShape.circle)),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return t('now');
    if (diff.inMinutes < 60) return '${diff.inMinutes}${localeService.isTr ? 'dk' : 'm'}';
    if (diff.inHours < 24) return '${diff.inHours}${localeService.isTr ? 'sa' : 'h'}';
    if (diff.inDays < 7) return '${diff.inDays}${localeService.isTr ? 'g' : 'd'}';
    return '${(diff.inDays / 7).floor()}${localeService.isTr ? 'h' : 'w'}';
  }
}
