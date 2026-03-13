import 'package:flutter/material.dart';
import '../app/theme.dart';
import 'grid/grid_screen.dart';
import 'social/social_screen.dart';
import 'profile/profile_screen.dart';

class RootNavigation extends StatefulWidget {
  const RootNavigation({Key? key}) : super(key: key);

  @override
  State<RootNavigation> createState() => _RootNavigationState();
}

class _RootNavigationState extends State<RootNavigation> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const GridScreen(),
    const SocialScreen(userToken: 'mock_jwt_local_testing'),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
    );
  }
}
