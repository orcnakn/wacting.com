import 'dart:async';
import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../app/widgets/modern_card.dart';
import '../../core/config/app_config.dart';
import 'package:dio/dio.dart';

class AdminDashboardScreen extends StatefulWidget {
  final String adminToken;

  const AdminDashboardScreen({Key? key, required this.adminToken}) : super(key: key);

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _isLoading = true;
  String? _error;
  Timer? _autoRefreshTimer;

  int _totalUsers = 0;
  int _activeUsers = 0;
  int _bannedUsers = 0;
  String _totalTokens = "0";

  @override
  void initState() {
    super.initState();
    _fetchTelemetry();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _fetchTelemetry());
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchTelemetry() async {
    try {
      final dio = Dio();
      final response = await dio.get(
        '${AppConfig.apiBaseUrl}/admin/stats',
        options: Options(
          headers: {'Authorization': 'Bearer ${widget.adminToken}'},
        ),
      );

      if (response.statusCode == 200) {
        setState(() {
          _totalUsers = response.data['totalUsers'] ?? 0;
          _activeUsers = response.data['activeUsers'] ?? 0;
          _bannedUsers = response.data['bannedUsers'] ?? 0;
          _totalTokens = response.data['totalTokensMinted'] ?? "0";
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = "Server returned ${response.statusCode}";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = "Failed to connect to Telemetry Server.";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('WACTING ADMIN PORTAL', style: TextStyle(color: AppColors.accentRed, letterSpacing: 2)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () {
            setState(() { _isLoading = true; _error = null; });
            _fetchTelemetry();
          })
        ],
      ),
      body: _isLoading
        ? Center(child: CircularProgressIndicator(color: AppColors.accentRed))
        : _error != null
          ? Center(child: Text(_error!, style: TextStyle(color: AppColors.accentRed)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Live Traffic & Telemetry', style: TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Icon(Icons.autorenew, color: AppColors.accentGreen, size: 14),
                      const SizedBox(width: 4),
                      Text('Auto-refresh 30s', style: TextStyle(color: AppColors.textTertiary, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Graphing Cards
                  Row(
                    children: [
                      Expanded(child: _buildStatCard('Total Registered Users', _totalUsers.toString(), AppColors.accentBlue)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildStatCard('Active Sessions', _activeUsers.toString(), AppColors.accentGreen)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildStatCard('Platform Bans', _bannedUsers.toString(), AppColors.accentRed)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildStatCard('Total WAC Minted', _totalTokens, AppColors.accentAmber)),
                    ],
                  ),

                  const SizedBox(height: 48),
                  Text('Recent User Reports', style: TextStyle(color: AppColors.textPrimary, fontSize: 20)),
                  const SizedBox(height: 16),
                  ModernCard(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Text("No unresolved reports in queue.", style: TextStyle(color: AppColors.textTertiary)),
                      )
                    )
                  )
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(String title, String value, Color flavor) {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: AppColors.textTertiary, fontSize: 12, letterSpacing: 1)),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(color: flavor, fontSize: 32, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
