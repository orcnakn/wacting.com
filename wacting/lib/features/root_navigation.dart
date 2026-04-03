import 'dart:async';
import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../core/services/api_service.dart';
import '../core/services/locale_service.dart';
import '../core/services/socket_service.dart';
import 'grid/grid_screen.dart';
import 'social/social_screen.dart';
import 'social/notifications_screen.dart';
import 'profile/profile_screen.dart';

// Global callback to switch bottom nav tab from anywhere
void Function(int index)? globalSwitchTab;

class RootNavigation extends StatefulWidget {
  const RootNavigation({Key? key}) : super(key: key);

  @override
  State<RootNavigation> createState() => _RootNavigationState();
}

class _RootNavigationState extends State<RootNavigation> {
  int _currentIndex = 0;
  int _unreadCount = 0;
  Timer? _pollTimer;
  StreamSubscription? _notificationSub;
  final List<Widget> _screens = [
    const GridScreen(),
    const SocialScreen(userToken: 'mock_jwt_local_testing'),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    globalSwitchTab = (int index) {
      if (mounted) setState(() => _currentIndex = index);
    };
    _fetchUnreadCount();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _fetchUnreadCount();
    });
    _notificationSub = socketService.notificationStream.listen((_) {
      _fetchUnreadCount();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _notificationSub?.cancel();
    super.dispose();
  }

  Future<void> _fetchUnreadCount() async {
    if (!apiService.isLoggedIn) return;
    try {
      final count = await apiService.getUnreadNotificationCount();
      if (mounted) {
        setState(() {
          _unreadCount = count;
        });
      }
    } catch (_) {}
  }

  void _openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
    _fetchUnreadCount();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.navyDark, width: 1)),
            ),
            child: BottomNavigationBar(
              backgroundColor: AppColors.navyPrimary,
              selectedItemColor: AppColors.navSelected,
              unselectedItemColor: AppColors.navUnselected,
              showSelectedLabels: true,
              showUnselectedLabels: true,
              type: BottomNavigationBarType.fixed,
              elevation: 0,
              currentIndex: _currentIndex,
              onTap: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              items: [
                BottomNavigationBarItem(
                  icon: const Icon(Icons.public),
                  label: t('world'),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.people_alt),
                  label: t('feed'),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.account_circle),
                  label: t('profile_nav'),
                ),
              ],
            ),
          ),
        ),
        // Story button + Notification star — top right
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          right: 12,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Yakinda...', textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 13)),
                      backgroundColor: AppColors.navyPrimary.withOpacity(0.9),
                      duration: const Duration(milliseconds: 800),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      margin: EdgeInsets.only(
                        bottom: MediaQuery.of(context).size.height - 140,
                        left: MediaQuery.of(context).size.width / 2 - 50,
                        right: MediaQuery.of(context).size.width / 2 - 50,
                      ),
                    ),
                  );
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.navyPrimary.withOpacity(0.85),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.auto_stories,
                    color: AppColors.textTertiary.withOpacity(0.5),
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _openNotifications,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.navyPrimary.withOpacity(0.85),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.star,
                        color: _unreadCount > 0
                            ? AppColors.accentAmber
                            : AppColors.textTertiary.withOpacity(0.3),
                        size: 24,
                      ),
                    ),
                    if (_unreadCount > 0)
                      Positioned(
                        top: -2,
                        right: -2,
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: const BoxDecoration(
                            color: AppColors.accentRed,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              _unreadCount > 99 ? '99+' : '$_unreadCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
