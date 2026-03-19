import 'dart:async';
import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../core/services/api_service.dart';
import '../core/services/socket_service.dart';
import 'grid/grid_screen.dart';
import 'social/social_screen.dart';
import 'social/notifications_screen.dart';
import 'profile/profile_screen.dart';

enum MapFilter { none, nearby, trending, lynched, newest }

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
  MapFilter _selectedFilter = MapFilter.none;
  Set<String>? _filteredCampaignIds;

  final List<Widget> _screens = [
    const GridScreen(),
    const SocialScreen(userToken: 'mock_jwt_local_testing'),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
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

  Future<void> _applyFilter(MapFilter filter) async {
    if (filter == MapFilter.none) {
      setState(() {
        _selectedFilter = MapFilter.none;
        _filteredCampaignIds = null;
      });
      return;
    }

    try {
      List<dynamic> campaigns;
      switch (filter) {
        case MapFilter.nearby:
          campaigns = await apiService.getNearbyCampaigns();
          break;
        case MapFilter.trending:
          campaigns = await apiService.getTrendingCampaigns();
          break;
        case MapFilter.lynched:
          campaigns = await apiService.getLynchedCampaigns();
          break;
        case MapFilter.newest:
          campaigns = await apiService.getNewestCampaigns();
          break;
        default:
          campaigns = [];
      }
      final ids = campaigns.map((c) => (c['id'] ?? '') as String).toSet();
      setState(() {
        _selectedFilter = filter;
        _filteredCampaignIds = ids;
      });
    } catch (_) {
      setState(() {
        _selectedFilter = filter;
        _filteredCampaignIds = {};
      });
    }
  }

  String _filterLabel(MapFilter f) {
    switch (f) {
      case MapFilter.none: return 'Filtre Yok';
      case MapFilter.nearby: return 'Bolgemdeki';
      case MapFilter.trending: return 'Trend';
      case MapFilter.lynched: return 'Linclenen';
      case MapFilter.newest: return 'Yeni';
    }
  }

  IconData _filterIcon(MapFilter f) {
    switch (f) {
      case MapFilter.none: return Icons.filter_list_off;
      case MapFilter.nearby: return Icons.location_on;
      case MapFilter.trending: return Icons.trending_up;
      case MapFilter.lynched: return Icons.warning;
      case MapFilter.newest: return Icons.new_releases;
    }
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
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.public),
                  label: 'WORLD',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.people_alt),
                  label: 'FEED',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.account_circle),
                  label: 'PROFILE',
                ),
              ],
            ),
          ),
        ),
        // Notification star — always visible, dim when no unread
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 12,
          child: GestureDetector(
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
                    top: -4,
                    right: -4,
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
        ),
        // Map filter dropdown (below notification star)
        if (_currentIndex == 0)
          Positioned(
            top: MediaQuery.of(context).padding.top + (_unreadCount > 0 ? 56 : 8),
            left: 12,
            child: _buildFilterDropdown(),
          ),
      ],
    );
  }

  Widget _buildFilterDropdown() {
    return PopupMenuButton<MapFilter>(
      onSelected: _applyFilter,
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: AppColors.navyPrimary,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _selectedFilter != MapFilter.none
              ? AppColors.accentBlue.withOpacity(0.2)
              : AppColors.navyPrimary.withOpacity(0.85),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _selectedFilter != MapFilter.none
                ? AppColors.accentBlue
                : AppColors.accentTeal.withOpacity(0.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_filterIcon(_selectedFilter), color: AppColors.accentTeal, size: 16),
            const SizedBox(width: 4),
            Text(
              _filterLabel(_selectedFilter),
              style: TextStyle(color: AppColors.accentTeal, fontSize: 11, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down, color: AppColors.accentTeal, size: 16),
          ],
        ),
      ),
      itemBuilder: (context) => MapFilter.values.map((f) => PopupMenuItem(
        value: f,
        child: Row(
          children: [
            Icon(_filterIcon(f), color: _selectedFilter == f ? AppColors.accentBlue : Colors.white70, size: 18),
            const SizedBox(width: 8),
            Text(
              _filterLabel(f),
              style: TextStyle(
                color: _selectedFilter == f ? AppColors.accentBlue : Colors.white,
                fontWeight: _selectedFilter == f ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      )).toList(),
    );
  }
}
