import 'package:flutter/material.dart';
import '../../app/widgets/modern_card.dart';
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
  
  int _totalUsers = 0;
  int _activeUsers = 0;
  int _bannedUsers = 0;
  String _totalTokens = "0";

  @override
  void initState() {
    super.initState();
    _fetchTelemetry();
  }

  Future<void> _fetchTelemetry() async {
    try {
      final dio = Dio();
      final response = await dio.get(
        'http://127.0.0.1:3000/admin/stats',
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
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('WACTING ADMIN PORTAL', style: TextStyle(color: Colors.redAccent, letterSpacing: 2)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () {
            setState(() { _isLoading = true; _error = null; });
            _fetchTelemetry();
          })
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
        : _error != null 
          ? Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Live Traffic & Telemetry', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  
                  // Graphing Cards
                  Row(
                    children: [
                      Expanded(child: _buildStatCard('Total Registered Users', _totalUsers.toString(), Colors.blueAccent)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildStatCard('Active Sessions', _activeUsers.toString(), Colors.greenAccent)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildStatCard('Platform Bans', _bannedUsers.toString(), Colors.redAccent)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildStatCard('Total WAC Minted', _totalTokens, Colors.amberAccent)),
                    ],
                  ),
                  
                  const SizedBox(height: 48),
                  const Text('Recent User Reports', style: TextStyle(color: Colors.white, fontSize: 20)),
                  const SizedBox(height: 16),
                  ModernCard(
                    child: const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text("No unresolved reports in queue.", style: TextStyle(color: Colors.white54)),
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
          Text(title, style: TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 1)),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(color: flavor, fontSize: 32, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
