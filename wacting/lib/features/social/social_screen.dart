import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../app/theme.dart';
import '../../app/widgets/modern_card.dart';
import '../../core/services/api_service.dart';
import '../profile/profile_screen.dart';
import '../grid/grid_screen.dart' show globalMapNavigateTo;
import '../root_navigation.dart' show globalSwitchTab;

String _extractError(dynamic e, [String fallback = 'Bir hata olustu.']) {
  if (e is DioException && e.response?.data is Map) {
    return (e.response!.data as Map)['error']?.toString() ?? fallback;
  }
  return fallback;
}

class SocialScreen extends StatefulWidget {
  final String userToken;

  const SocialScreen({Key? key, required this.userToken}) : super(key: key);

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  // Mock Data

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.pageBackground,
        appBar: AppBar(
           title: Text('Akis (Feed)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: AppColors.textPrimary)),
           backgroundColor: Colors.transparent,
           elevation: 0,
           centerTitle: true,
           bottom: TabBar(
             indicatorColor: AppColors.accentBlue,
             labelColor: AppColors.accentBlue,
             unselectedLabelColor: AppColors.textTertiary,
             indicatorWeight: 3,
             tabs: const [
               Tab(text: 'KAMPANYALAR', icon: Icon(Icons.flag)),
               Tab(text: 'GLOBAL', icon: Icon(Icons.public)),
             ],
           ),
        ),
        body: const TabBarView(
          children: [
            _CampaignsTab(),
            _GlobalTab(),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. KAMPANYALAR (CAMPAIGNS) TAB — 4 sub-tabs
// ─────────────────────────────────────────────────────────────────────────────
class _CampaignsTab extends StatefulWidget {
  const _CampaignsTab();
  @override
  State<_CampaignsTab> createState() => _CampaignsTabState();
}

class _CampaignsTabState extends State<_CampaignsTab> {
  List<dynamic> _myCampaigns = [];
  bool _loadingCampaigns = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!apiService.isLoggedIn) {
      setState(() => _loadingCampaigns = false);
      return;
    }
    try {
      final campaigns = await apiService.getMyCampaigns();
      if (mounted) {
        setState(() {
          _myCampaigns = campaigns;
          _loadingCampaigns = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingCampaigns = false);
    }
  }

  Widget _emergencyInfoTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(children: [
        Text(label, style: TextStyle(color: AppColors.textTertiary, fontSize: 10)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  String _formatEmergencyExpiry(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      final diff = dt.difference(DateTime.now());
      if (diff.isNegative) return 'Suresi doldu';
      if (diff.inDays > 0) return '${diff.inDays} gun kaldi';
      return '${diff.inHours}sa ${diff.inMinutes.remainder(60)}dk kaldi';
    } catch (_) {
      return isoDate;
    }
  }

  String _formatCountdown(DateTime endsAt) {
    final diff = endsAt.difference(DateTime.now());
    if (diff.isNegative) return 'Sona erdi';
    final h = diff.inHours;
    final m = diff.inMinutes.remainder(60);
    return '${h}sa ${m}dk kaldi';
  }

  @override
  Widget build(BuildContext context) {
    return _buildActiveCampaigns();
  }

  // ── Aktif Kampanyalar ──────────────────────────────────────────────────────
  Widget _buildActiveCampaigns() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Kampanya Olustur Butonu ──────────────────────────────────────────
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () => _showCreateCampaignModal(context),
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.navyPrimary, AppColors.accentBlue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.add, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                const Text('Kampanya Olustur', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              ]),
            ),
          ),
        ),
        if (_loadingCampaigns)
          Center(child: Padding(
            padding: const EdgeInsets.all(32),
            child: CircularProgressIndicator(color: AppColors.accentBlue),
          )),
        if (!_loadingCampaigns && _myCampaigns.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(child: Text('Henuz kampanyaniz yok. Yukaridaki butondan olusturun!',
                style: TextStyle(color: AppColors.textTertiary), textAlign: TextAlign.center)),
          ),
        ...(() {
          final sorted = [..._myCampaigns];
          sorted.sort((a, b) {
            final aDate = DateTime.tryParse((a['createdAt'] ?? '').toString()) ?? DateTime(0);
            final bDate = DateTime.tryParse((b['createdAt'] ?? '').toString()) ?? DateTime(0);
            return bDate.compareTo(aDate);
          });
          return sorted.asMap().entries.map((entry) {
            final idx = entry.key;
            final c = entry.value;
            final myStaked = double.tryParse((c['myStakedWac'] ?? '0').toString()) ?? 0;
            final totalStaked = double.tryParse((c['totalWacStaked'] ?? '0').toString()) ?? 0;
            final memberCount = (c['memberCount'] ?? c['_count']?['members'] ?? 0) as int;
            final isLeader = c['isLeader'] == true;
            final speed = (c['speed'] as num?)?.toDouble() ?? 0.5;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildCompactMyCampaignRow(
                campaignId: c['id'] ?? '',
                title: c['title'] ?? 'Kampanya',
                slogan: c['slogan'] ?? '',
                participants: memberCount,
                totalWacStaked: totalStaked,
                myStakedWac: myStaked,
                isLeader: isLeader,
                rank: idx + 1,
                speed: speed,
                pinnedLat: (c['pinnedLat'] as num?)?.toDouble(),
                pinnedLng: (c['pinnedLng'] as num?)?.toDouble(),
                isEmergency: c['stanceType'] == 'EMERGENCY',
                emergencyWacPool: (c['emergencyWacPool'] is String)
                    ? double.tryParse(c['emergencyWacPool']) ?? 0
                    : (c['emergencyWacPool'] as num?)?.toDouble() ?? 0,
                emergencyAreaM2: (c['emergencyAreaM2'] as num?)?.toDouble() ?? 0,
                emergencyExpiresAt: c['emergencyExpiresAt'] as String?,
              ),
            );
          });
        })(),
      ],
    );
  }

  // ── Pasif Kampanyalar ──────────────────────────────────────────────────────
  Widget _buildPassiveCampaigns() {
    final history = [
      {'title': 'Ocean Savers', 'joinedAt': '2025-01-10', 'exitedAt': '2025-04-03', 'totalEarned': '1240.5'},
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (history.isEmpty)
          Center(child: Text('Ayrildiginiz kampanya yok.', style: TextStyle(color: AppColors.textTertiary))),
        ...history.map((h) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ModernCard(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(h['title']!, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                _metricCol('Katildi', h['joinedAt']!, AppColors.textTertiary),
                _metricCol('Ayrildi', h['exitedAt']!, AppColors.textTertiary),
                _metricCol('Kazanilan', '${h['totalEarned']} WAC', AppColors.accentAmber),
              ]),
            ]),
          ),
        )),
      ],
    );
  }

  // ── Vote Modal for specific poll ─────────────────────────────────────────
  void _showVoteModalForPoll(BuildContext context, Map<String, dynamic> poll) {
    String? selectedOptionId;
    final options = (poll['options'] as List<dynamic>).cast<Map<String, dynamic>>();
    final totalWac = options.fold<double>(0, (s, o) => s + ((o['totalWac'] ?? 0) as num).toDouble());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceWhite,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.how_to_vote, color: AppColors.accentAmber),
              const SizedBox(width: 8),
              Text(_formatCountdown(DateTime.parse(poll['endsAt'])),
                  style: TextStyle(color: AppColors.accentAmber, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 12),
            Text(poll['title'] as String,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
            if ((poll['description'] as String?)?.isNotEmpty == true) ...[
              const SizedBox(height: 6),
              Text(poll['description'] as String,
                  style: TextStyle(color: AppColors.textSecondary)),
            ],
            const SizedBox(height: 20),
            ...options.map((opt) {
              final wacPct = totalWac > 0 ? ((opt['totalWac'] ?? 0) as num).toDouble() / totalWac : 0.0;
              final isSelected = selectedOptionId == opt['id'];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GestureDetector(
                  onTap: () => setModal(() => selectedOptionId = opt['id'] as String),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.accentAmber.withOpacity(0.08) : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: isSelected ? AppColors.accentAmber : AppColors.borderLight, width: isSelected ? 1.5 : 1),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                            color: isSelected ? AppColors.accentAmber : AppColors.textTertiary, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(opt['text'] as String,
                              style: TextStyle(
                                  color: isSelected ? AppColors.accentAmber : AppColors.textPrimary,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: wacPct,
                          backgroundColor: AppColors.borderLight,
                          color: isSelected ? AppColors.accentAmber : AppColors.accentBlue,
                          minHeight: 4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('${(wacPct * 100).toStringAsFixed(1)}%',
                            style: TextStyle(color: AppColors.textTertiary, fontSize: 11)),
                        Text('${opt['voterCount'] ?? 0} kisi',
                            style: TextStyle(color: AppColors.textTertiary, fontSize: 11)),
                      ]),
                    ]),
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentAmber,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: selectedOptionId == null
                    ? null
                    : () async {
                        try {
                          await apiService.castVote(poll['id'], selectedOptionId!);
                          Navigator.pop(ctx);
                          _loadData();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: const Text('Oyunuz kaydedildi!'), backgroundColor: AppColors.navyPrimary),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(_extractError(e, 'Oy kullanilamadi.')), backgroundColor: AppColors.accentRed),
                          );
                        }
                      },
                child: const Text('OY VER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Compact Single-Line Campaign Row ───────────────────────────────────────
  Widget _buildCompactMyCampaignRow({
    required String campaignId,
    required String title,
    required String slogan,
    required int participants,
    required double totalWacStaked,
    required double myStakedWac,
    required bool isLeader,
    int? rank,
    double speed = 0.5,
    double? pinnedLat,
    double? pinnedLng,
    bool isEmergency = false,
    double emergencyWacPool = 0,
    double emergencyAreaM2 = 0,
    String? emergencyExpiresAt,
  }) {
    String fmtWac(double v) => v >= 1000
        ? '${(v / 1000).toStringAsFixed(1)}K'
        : v.toStringAsFixed(1);

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _showCampaignDetailSheet(
        campaignId: campaignId,
        title: title,
        slogan: slogan,
        participants: participants,
        totalWacStaked: totalWacStaked,
        myStakedWac: myStakedWac,
        isLeader: isLeader,
        speed: speed,
        pinnedLat: pinnedLat,
        pinnedLng: pinnedLng,
        isEmergency: isEmergency,
        emergencyWacPool: emergencyWacPool,
        emergencyAreaM2: emergencyAreaM2,
        emergencyExpiresAt: emergencyExpiresAt,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderLight, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 10, height: 10,
              decoration: BoxDecoration(
                color: isLeader ? AppColors.accentAmber : AppColors.accentBlue,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$title — $slogan',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${fmtWac(totalWacStaked)} WAC',
              style: TextStyle(color: AppColors.accentAmber, fontSize: 11, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 6),
            Text(
              '$participants',
              style: TextStyle(color: AppColors.textTertiary, fontSize: 11),
            ),
            Icon(Icons.people_alt_outlined, color: AppColors.textTertiary, size: 14),
            if (rank != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accentTeal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('#$rank', style: TextStyle(color: AppColors.accentTeal, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: AppColors.textTertiary, size: 16),
          ],
        ),
      ),
    );
  }

  void _showCampaignDetailSheet({
    required String campaignId,
    required String title,
    required String slogan,
    required int participants,
    required double totalWacStaked,
    required double myStakedWac,
    required bool isLeader,
    double speed = 0.5,
    double? pinnedLat,
    double? pinnedLng,
    bool isEmergency = false,
    double emergencyWacPool = 0,
    double emergencyAreaM2 = 0,
    String? emergencyExpiresAt,
  }) {
    double currentSpeed = speed;
    double spendAmount = 1.0;
    String spendTarget = 'duration'; // duration or area
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceWhite,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _buildDetailedCampaignCard(
              campaignId: campaignId,
              title: title,
              slogan: slogan,
              participants: participants,
              totalWacStaked: totalWacStaked,
              myStakedWac: myStakedWac,
              isRac: false,
              hasActivePoll: false,
              isLeader: isLeader,
            ),
            // ── Emergency campaign controls ──
            if (isEmergency && isLeader) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.warning_rounded, color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Text('Acil Durum Ayarlari', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: _emergencyInfoTile('WAC Havuzu', emergencyWacPool.toStringAsFixed(2))),
                    const SizedBox(width: 8),
                    Expanded(child: _emergencyInfoTile('Logo Alani', '${(emergencyAreaM2 / 1000).toStringAsFixed(1)}K m\u00B2')),
                  ]),
                  const SizedBox(height: 6),
                  if (emergencyExpiresAt != null)
                    _emergencyInfoTile('Bitis', _formatEmergencyExpiry(emergencyExpiresAt)),
                  const SizedBox(height: 12),
                  Text('WAC Harcama', style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Row(children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setModal(() => spendTarget = 'duration'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: spendTarget == 'duration' ? Colors.red.withOpacity(0.15) : AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: spendTarget == 'duration' ? Colors.red : AppColors.borderLight),
                          ),
                          child: Column(children: [
                            Icon(Icons.timer, color: spendTarget == 'duration' ? Colors.red : AppColors.textTertiary, size: 20),
                            const SizedBox(height: 2),
                            Text('Sure Uzat', style: TextStyle(
                              color: spendTarget == 'duration' ? Colors.red : AppColors.textSecondary,
                              fontSize: 11, fontWeight: FontWeight.w600,
                            )),
                            Text('1 WAC = 3 gun', style: TextStyle(color: AppColors.textTertiary, fontSize: 9)),
                          ]),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setModal(() => spendTarget = 'area'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: spendTarget == 'area' ? Colors.red.withOpacity(0.15) : AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: spendTarget == 'area' ? Colors.red : AppColors.borderLight),
                          ),
                          child: Column(children: [
                            Icon(Icons.zoom_out_map, color: spendTarget == 'area' ? Colors.red : AppColors.textTertiary, size: 20),
                            const SizedBox(height: 2),
                            Text('Logo Buyut', style: TextStyle(
                              color: spendTarget == 'area' ? Colors.red : AppColors.textSecondary,
                              fontSize: 11, fontWeight: FontWeight.w600,
                            )),
                            Text('1 WAC = 10K m\u00B2', style: TextStyle(color: AppColors.textTertiary, fontSize: 9)),
                          ]),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Text('Miktar: ${spendAmount.toStringAsFixed(1)} WAC',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  Slider(
                    value: spendAmount.clamp(0.1, emergencyWacPool.clamp(0.1, double.infinity)),
                    min: 0.1,
                    max: emergencyWacPool > 0 ? emergencyWacPool : 0.1,
                    divisions: emergencyWacPool > 1 ? (emergencyWacPool * 10).toInt().clamp(1, 100) : 1,
                    activeColor: Colors.red,
                    label: '${spendAmount.toStringAsFixed(1)} WAC',
                    onChanged: (v) => setModal(() => spendAmount = v),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: Icon(spendTarget == 'duration' ? Icons.timer : Icons.zoom_out_map, size: 18),
                      onPressed: emergencyWacPool <= 0 ? null : () async {
                        try {
                          final result = await apiService.emergencySpendWac(
                            campaignId,
                            amount: spendAmount.toStringAsFixed(6),
                            target: spendTarget,
                          );
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(result['message'] ?? 'Basarili')),
                          );
                          _loadData();
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
                          );
                        }
                      },
                      label: Text(spendTarget == 'duration'
                        ? 'Sure Uzat (${(spendAmount * 3).toStringAsFixed(0)} gun)'
                        : 'Logo Buyut (${(spendAmount * 10000).toStringAsFixed(0)} m\u00B2)'),
                    ),
                  ),
                ]),
              ),
            ],
            // ── Normal campaign speed control ──
            if (!isEmergency && isLeader) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.speed, color: AppColors.accentBlue, size: 18),
                    const SizedBox(width: 8),
                    Text('Kampanya Hizi', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Text(
                      currentSpeed == 0 ? 'Sabit' : '${currentSpeed.toStringAsFixed(1)}x',
                      style: TextStyle(color: AppColors.accentBlue, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Text(
                    currentSpeed == 0
                        ? 'Ikon haritada sabit duruyor'
                        : '1000 km / ${(1 + (1 - currentSpeed) * 10).toStringAsFixed(0)} saniye',
                    style: TextStyle(color: AppColors.textTertiary, fontSize: 11),
                  ),
                  Slider(
                    value: currentSpeed,
                    min: 0, max: 1, divisions: 10,
                    activeColor: AppColors.accentBlue,
                    label: currentSpeed == 0 ? 'Sabit' : '${currentSpeed.toStringAsFixed(1)}x',
                    onChanged: (v) => setModal(() => currentSpeed = v),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () async {
                        try {
                          await apiService.updateCampaignSpeed(campaignId, currentSpeed);
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Hiz guncellendi: ${currentSpeed.toStringAsFixed(1)}x')),
                          );
                          _loadData();
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
                          );
                        }
                      },
                      child: const Text('Hizi Kaydet'),
                    ),
                  ),
                ]),
              ),
            ],
            // Konuma Git — gecici olarak gizlendi
          ]),
        ),
      ),
    );
  }

  // ── Campaign Card ──────────────────────────────────────────────────────────
  Widget _buildDetailedCampaignCard({
    required String campaignId,
    required String title,
    required String slogan,
    required int participants,
    required double totalWacStaked,
    required double myStakedWac,
    required bool isRac,
    required bool hasActivePoll,
    required bool isLeader,
  }) {
    final color = isRac ? AppColors.accentRed : AppColors.accentBlue;
    final bgColor = isRac ? AppColors.accentRed.withOpacity(0.06) : AppColors.accentBlue.withOpacity(0.06);

    String _fmtWac(double v) => v >= 1000
        ? '${(v / 1000).toStringAsFixed(1)}K'
        : v.toStringAsFixed(1);

    return ModernCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header row
        Row(children: [
          CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              radius: 24,
              child: Icon(isRac ? Icons.warning : Icons.flag, color: color)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
            Text(slogan, style: TextStyle(color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
          ])),
          if (isLeader)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.accentAmber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('Lider', style: TextStyle(color: AppColors.accentAmber, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
        ]),

        // Poll badge (if active poll exists)
        if (hasActivePoll) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {},
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                  color: AppColors.accentAmber.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.accentAmber.withOpacity(0.3))),
              child: Row(children: [
                Icon(Icons.how_to_vote, color: AppColors.accentAmber, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Aktif Oylama Var!',
                        style: TextStyle(color: AppColors.accentAmber, fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                  ]),
                ),
                Icon(Icons.arrow_forward_ios, color: AppColors.accentAmber, size: 14),
              ]),
            ),
          ),
        ],

        const SizedBox(height: 16),
        Divider(color: AppColors.borderLight),
        const SizedBox(height: 16),

        // Metrics
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _metricCol('Katilimci', '$participants', color),
          _metricCol('Toplam Stake', '${_fmtWac(totalWacStaked)} WAC', color),
          _metricCol('Benim Stake', '${_fmtWac(myStakedWac)} WAC', AppColors.accentAmber),
        ]),
        const SizedBox(height: 16),

        // Staking info
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Stake Oranim', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
              Text(
                totalWacStaked > 0
                    ? '%${(myStakedWac / totalWacStaked * 100).toStringAsFixed(1)}'
                    : '%0.0',
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
            ]),
            // Cikis cezasi — gecici olarak gizlendi
            // Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            //   Text('Cikis Cezasi (%30)', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
            //   Text('${_fmtWac(myStakedWac * 0.30)} WAC',
            //       style: TextStyle(color: AppColors.accentRed, fontWeight: FontWeight.bold, fontSize: 14)),
            // ]),
          ]),
        ),

        // Buttons
        const SizedBox(height: 12),
        Row(children: [
          // Oylama butonlari — gecici olarak gizlendi
          // Stake Ekle butonu
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentTeal.withOpacity(0.1),
                  foregroundColor: AppColors.accentTeal),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Stake Ekle'),
              onPressed: () => _showAddStakeModal(context, campaignId),
            ),
          ),
          const SizedBox(width: 8),
          // Ayril butonu
          SizedBox(
            width: 48,
            child: IconButton(
              style: IconButton.styleFrom(
                backgroundColor: AppColors.accentRed.withOpacity(0.1),
              ),
              icon: Icon(Icons.exit_to_app, color: AppColors.accentRed, size: 20),
              onPressed: () => _showLeaveConfirmation(context, campaignId, title, myStakedWac),
            ),
          ),
        ]),
      ]),
    );
  }

  // ── Add Stake Modal ─────────────────────────────────────────────────────────
  void _showAddStakeModal(BuildContext context, String campaignId) {
    final amountCtrl = TextEditingController(text: '1');

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceWhite,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 32),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('WAC Stake Ekle', style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Kampanyaya ek WAC stake edin. Stake arttikca kampanyanin buyuklugu ve odulleri artar.',
              style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
          const SizedBox(height: 16),
          TextField(
            controller: amountCtrl,
            keyboardType: TextInputType.number,
            style: TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              hintText: 'Miktar',
              suffixText: 'WAC',
              suffixStyle: TextStyle(color: AppColors.accentAmber, fontWeight: FontWeight.bold),
              filled: true,
              fillColor: AppColors.surfaceLight,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentTeal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text.trim());
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: const Text('Gecerli bir miktar girin.'), backgroundColor: AppColors.accentRed),
                  );
                  return;
                }
                try {
                  await apiService.addCampaignStake(campaignId, amount.toStringAsFixed(6));
                  Navigator.pop(ctx);
                  _loadData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${amount.toStringAsFixed(1)} WAC stake eklendi!'), backgroundColor: AppColors.navyPrimary),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(_extractError(e, 'Stake eklenemedi.')), backgroundColor: AppColors.accentRed),
                  );
                }
              },
              child: const Text('STAKE EKLE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Leave Campaign Confirmation ─────────────────────────────────────────────
  void _showLeaveConfirmation(BuildContext context, String campaignId, String title, double myStakedWac) {
    final penalty = myStakedWac * 0.30;
    final returnAmount = myStakedWac * 0.70;
    final racReward = (penalty * 2).floor();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Kampanyadan Ayril', style: TextStyle(color: AppColors.textPrimary)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('"$title" kampanyasindan ayrilmak istediginize emin misiniz?',
              style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accentRed.withOpacity(0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Cikis Detaylari:', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              _penaltyRow('Toplam Stake', '${myStakedWac.toStringAsFixed(1)} WAC', AppColors.textPrimary),
              _penaltyRow('Iade (%70)', '${returnAmount.toStringAsFixed(1)} WAC', AppColors.accentGreen),
              _penaltyRow('Yakilacak (%15)', '${(penalty * 0.5).toStringAsFixed(1)} WAC', AppColors.accentRed),
              _penaltyRow('Dev Fonu (%15)', '${(penalty * 0.5).toStringAsFixed(1)} WAC', AppColors.accentAmber),
              const Divider(),
              _penaltyRow('RAC Odulu', '$racReward RAC', AppColors.accentTeal),
            ]),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Iptal', style: TextStyle(color: AppColors.textTertiary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final result = await apiService.leaveCampaign(campaignId);
                _loadData();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result['message'] ?? 'Kampanyadan ayrildiniz.'),
                    backgroundColor: AppColors.navyPrimary,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(_extractError(e, 'Ayrilma basarisiz.')), backgroundColor: AppColors.accentRed),
                );
              }
            },
            child: const Text('Ayril'),
          ),
        ],
      ),
    );
  }

  Widget _penaltyRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
      ]),
    );
  }

  // ── Create Campaign Modal ──────────────────────────────────────────────────
  void _showCreateCampaignModal(BuildContext context) {
    final sloganCtrl  = TextEditingController();
    final descCtrl    = TextEditingController();
    final videoCtrl   = TextEditingController();
    final igCtrl      = TextEditingController();
    final twCtrl      = TextEditingController();
    final fbCtrl      = TextEditingController();
    final tiktokCtrl  = TextEditingController();
    final webCtrl     = TextEditingController();

    // WAC stake amount
    final stakeCtrl = TextEditingController(text: '1');

    // Speed state (0.0–1.0; 0.5 = 75% of reference speed)
    double campaignSpeed = 0.5;

    final List<IconData> _iconShapes = [
      Icons.flag, Icons.star, Icons.bolt, Icons.local_fire_department,
      Icons.public, Icons.shield, Icons.favorite, Icons.eco,
    ];
    int selectedShapeIdx = 0;

    // Stance & Category
    String? selectedStance;
    String? selectedCategory;

    final stanceOptions = [
      {'key': 'PROTEST', 'label': 'Protesto / Itiraz', 'emoji': '🛑', 'color': const Color(0xFFFF4444), 'desc': 'Bir uygulamayi, yasayi veya durumu durdurma cagrisi.'},
      {'key': 'SUPPORT', 'label': 'Destek / Ovgu', 'emoji': '✅', 'color': const Color(0xFF4CAF50), 'desc': 'Bir gelismeyi, teknolojiyi veya markayi destekleme.'},
      {'key': 'REFORM', 'label': 'Cozum / Reform', 'emoji': '🛠', 'color': const Color(0xFF2196F3), 'desc': 'Somut bir proje, yasa tasarisi veya alternatif sunma.'},
      {'key': 'EMERGENCY', 'label': 'Acil Cagri', 'emoji': '🆘', 'color': const Color(0xFFFF9800), 'desc': 'Aninda mudahale gerektiren acil durumlar.'},
    ];

    final categoryOptions = [
      {'key': 'GLOBAL_PEACE', 'label': 'Kuresel Baris ve Insanlik', 'emoji': '🌍'},
      {'key': 'JUSTICE_RIGHTS', 'label': 'Adalet ve Sivil Haklar', 'emoji': '⚖️'},
      {'key': 'ECOLOGY_NATURE', 'label': 'Ekoloji ve Doga', 'emoji': '🌱'},
      {'key': 'TECH_FUTURE', 'label': 'Teknoloji ve Gelecek', 'emoji': '💡'},
      {'key': 'SOLIDARITY_RELIEF', 'label': 'Dayanisma ve Yardim', 'emoji': '🤝'},
      {'key': 'ECONOMY_LABOR', 'label': 'Ekonomi ve Emek', 'emoji': '💼'},
      {'key': 'AWARENESS', 'label': 'Farkindalik ve Sorgulama', 'emoji': '🔍'},
      {'key': 'ENTERTAINMENT', 'label': 'Sahne, Marka ve Eglence', 'emoji': '🌟'},
    ];

    Color _getStanceColor() {
      if (selectedStance == null) return AppColors.accentBlue;
      final s = stanceOptions.firstWhere((o) => o['key'] == selectedStance, orElse: () => stanceOptions[1]);
      return s['color'] as Color;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceWhite,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          Widget _field(TextEditingController ctrl, String hint,
              {int maxLines = 1, int? maxLength, String? prefix, IconData? icon}) {
            return TextField(
              controller: ctrl,
              style: TextStyle(color: AppColors.textPrimary),
              maxLines: maxLines,
              maxLength: maxLength,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: AppColors.textTertiary),
                prefixIcon: icon != null ? Icon(icon, color: AppColors.textTertiary, size: 20) : null,
                prefixText: prefix,
                prefixStyle: TextStyle(color: AppColors.textTertiary),
                filled: true,
                fillColor: AppColors.surfaceLight,
                counterStyle: TextStyle(color: AppColors.textTertiary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            );
          }

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.55,
            minChildSize: 0.3,
            maxChildSize: 0.8,
            builder: (ctx2, scrollCtrl) => Column(children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.borderMedium, borderRadius: BorderRadius.circular(2)),
              ),
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(ctx).viewInsets.bottom + 24),
                  children: [
                    // ── Baslik ──────────────────────────────────────────────
                    Text('Kampanya Olustur',
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Ikon, slogan ve sosyal medya baglantilari gir.',
                        style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
                    const SizedBox(height: 24),

                    // ── Durus Secimi ───────────────────────────────────────
                    Text('Durus Tipi', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text('Kampanyanin durusunu sec - ikon rengi buna gore belirlenir.',
                        style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                    const SizedBox(height: 12),
                    ...stanceOptions.map((s) {
                      final isSelected = selectedStance == s['key'];
                      final color = s['color'] as Color;
                      return GestureDetector(
                        onTap: () => setModal(() => selectedStance = s['key'] as String),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected ? color.withOpacity(0.1) : AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isSelected ? color : AppColors.borderLight, width: isSelected ? 2 : 0.5),
                          ),
                          child: Row(children: [
                            Text(s['emoji'] as String, style: const TextStyle(fontSize: 24)),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(s['label'] as String,
                                  style: TextStyle(color: isSelected ? color : AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                              Text(s['desc'] as String,
                                  style: TextStyle(color: AppColors.textTertiary, fontSize: 11)),
                            ])),
                            if (isSelected) Icon(Icons.check_circle, color: color, size: 22),
                          ]),
                        ),
                      );
                    }),

                    const SizedBox(height: 20),

                    // ── Kategori Secimi ────────────────────────────────────
                    Text('Kategori', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text('Kampanyanin kategorisini sec.',
                        style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: categoryOptions.map((c) {
                        final isSelected = selectedCategory == c['key'];
                        return GestureDetector(
                          onTap: () => setModal(() => selectedCategory = c['key'] as String),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? _getStanceColor().withOpacity(0.1) : AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: isSelected ? _getStanceColor() : AppColors.borderLight, width: isSelected ? 2 : 0.5),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Text(c['emoji'] as String, style: const TextStyle(fontSize: 16)),
                              const SizedBox(width: 6),
                              Text(c['label'] as String,
                                  style: TextStyle(color: isSelected ? _getStanceColor() : AppColors.textPrimary, fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                            ]),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 20),

                    // ── Ikon Sekil ──────────────────────────────────────────
                    Text('Ikon Sekli', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        width: 72, height: 72,
                        decoration: BoxDecoration(
                          color: _getStanceColor().withOpacity(0.1),
                          shape: BoxShape.circle,
                          border: Border.all(color: _getStanceColor(), width: 2),
                        ),
                        child: Icon(_iconShapes[selectedShapeIdx], color: _getStanceColor(), size: 36),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: List.generate(_iconShapes.length, (i) => GestureDetector(
                        onTap: () => setModal(() => selectedShapeIdx = i),
                        child: Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: selectedShapeIdx == i
                                ? _getStanceColor().withOpacity(0.1)
                                : AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: selectedShapeIdx == i ? _getStanceColor() : AppColors.borderLight),
                          ),
                          child: Icon(_iconShapes[i],
                              color: selectedShapeIdx == i ? _getStanceColor() : AppColors.textTertiary,
                              size: 22),
                        ),
                      )),
                    ),

                    const SizedBox(height: 24),
                    Divider(color: AppColors.borderLight),
                    const SizedBox(height: 16),

                    // ── Slogan ────────────────────────────────────────────────
                    Text('Slogan', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 8),
                    _field(sloganCtrl, '"Sloganini buraya yaz..."', maxLength: 100, icon: Icons.format_quote),

                    const SizedBox(height: 16),

                    // ── Kampanya Tanimi ───────────────────────────────────────
                    Text('Kampanya Tanimi', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 8),
                    _field(descCtrl, 'Kampanyani detayli anlat...', maxLines: 5, maxLength: 1000, icon: Icons.description_outlined),

                    const SizedBox(height: 24),
                    Divider(color: AppColors.borderLight),
                    const SizedBox(height: 16),

                    // ── Video ─────────────────────────────────────────────────
                    Text('Video', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text('YouTube veya Vimeo linki ekle', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                    const SizedBox(height: 8),
                    _field(videoCtrl, 'https://youtube.com/...', icon: Icons.play_circle_outline),

                    const SizedBox(height: 24),
                    Divider(color: AppColors.borderLight),
                    const SizedBox(height: 16),

                    // ── Sosyal Medya ──────────────────────────────────────────
                    Text('Sosyal Medya Baglantilari',
                        style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 12),

                    // Instagram
                    Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                      Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE1306C), Color(0xFF833AB4), Color(0xFFF77737)],
                            begin: Alignment.topLeft, end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: _field(igCtrl, 'instagram.com/kullanici', prefix: 'instagram.com/')),
                    ]),
                    const SizedBox(height: 10),

                    // Twitter / X
                    Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                      Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(color: AppColors.navyDark, borderRadius: BorderRadius.circular(10)),
                        child: const Center(
                          child: Text('X', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: _field(twCtrl, 'x.com/kullanici', prefix: 'x.com/')),
                    ]),
                    const SizedBox(height: 10),

                    // Facebook
                    Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                      Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(color: const Color(0xFF1877F2), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.facebook, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: _field(fbCtrl, 'facebook.com/sayfa', prefix: 'facebook.com/')),
                    ]),
                    const SizedBox(height: 10),

                    // TikTok
                    Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                      Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(color: AppColors.navyDark, borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.music_note, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: _field(tiktokCtrl, 'tiktok.com/@kullanici', prefix: 'tiktok.com/@')),
                    ]),
                    const SizedBox(height: 10),

                    // Web sitesi
                    Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                      Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.borderLight)),
                        child: Icon(Icons.language, color: AppColors.textTertiary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: _field(webCtrl, 'https://kampanyasitesi.com', icon: null)),
                    ]),

                    const SizedBox(height: 24),
                    Divider(color: AppColors.borderLight),
                    const SizedBox(height: 16),

                    // ── WAC Stake ───────────────────────────────────────────
                    Text('WAC Stake', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text('Kampanyaya stake edilecek WAC miktari (min. 1 WAC)',
                        style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                    const SizedBox(height: 8),
                    _field(stakeCtrl, '1', icon: Icons.account_balance_wallet),

                    const SizedBox(height: 24),
                    Divider(color: AppColors.borderLight),
                    const SizedBox(height: 16),

                    // ── Hareket Hızı ──────────────────────────────────────────
                    Text('Hareket Hızı',
                        style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text('İkonun haritadaki hareket hızını ayarla (0 = sabit, 0.5 = varsayılan)',
                        style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.directions_run, color: AppColors.textTertiary, size: 18),
                        Expanded(
                          child: Slider(
                            value: campaignSpeed,
                            min: 0.0,
                            max: 1.0,
                            divisions: 10,
                            activeColor: _getStanceColor(),
                            inactiveColor: AppColors.borderMedium,
                            onChanged: (v) => setModal(() => campaignSpeed = v),
                          ),
                        ),
                        SizedBox(
                          width: 36,
                          child: Text(
                            campaignSpeed.toStringAsFixed(2),
                            style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                    if (campaignSpeed == 0.0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('İkon sabit kalır, hareket etmez.',
                            style: TextStyle(color: AppColors.accentAmber, fontSize: 11)),
                      ),

                    const SizedBox(height: 32),

                    // ── Olustur Butonu ────────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.navyPrimary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.flag, size: 20),
                        label: const Text('KAMPANYAYI OLUSTUR',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5)),
                        onPressed: () async {
                          if (sloganCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: const Text('Slogan gerekli!'), backgroundColor: AppColors.accentRed),
                            );
                            return;
                          }
                          try {
                            final stakeVal = double.tryParse(stakeCtrl.text.trim()) ?? 1.0;
                            if (stakeVal < 1) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: const Text('En az 1 WAC stake gerekli!'), backgroundColor: AppColors.accentRed),
                              );
                              return;
                            }
                            if (selectedStance == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: const Text('Durus tipi secimi gerekli!'), backgroundColor: AppColors.accentRed),
                              );
                              return;
                            }
                            if (selectedCategory == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: const Text('Kategori secimi gerekli!'), backgroundColor: AppColors.accentRed),
                              );
                              return;
                            }
                            final stanceColorMap = {
                              'PROTEST': '#FF4444', 'SUPPORT': '#4CAF50',
                              'REFORM': '#2196F3', 'EMERGENCY': '#FF9800',
                            };
                            final colorHex = stanceColorMap[selectedStance] ?? '#2C3E50';
                            await apiService.createCampaign(
                              title: sloganCtrl.text.trim().substring(0, sloganCtrl.text.trim().length.clamp(0, 50)),
                              slogan: sloganCtrl.text.trim(),
                              description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                              videoUrl: videoCtrl.text.trim().isEmpty ? null : videoCtrl.text.trim(),
                              iconColor: colorHex,
                              iconShape: selectedShapeIdx,
                              speed: campaignSpeed,
                              stakeAmount: stakeVal.toStringAsFixed(6),
                              instagramUrl: igCtrl.text.trim().isEmpty ? null : igCtrl.text.trim(),
                              twitterUrl: twCtrl.text.trim().isEmpty ? null : twCtrl.text.trim(),
                              facebookUrl: fbCtrl.text.trim().isEmpty ? null : fbCtrl.text.trim(),
                              tiktokUrl: tiktokCtrl.text.trim().isEmpty ? null : tiktokCtrl.text.trim(),
                              websiteUrl: webCtrl.text.trim().isEmpty ? null : webCtrl.text.trim(),
                              stanceType: selectedStance,
                              categoryType: selectedCategory,
                            );
                            Navigator.pop(ctx);
                            if (mounted) {
                              setState(() {}); // Refresh
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Kampanyan olusturuldu!'),
                                  backgroundColor: AppColors.navyPrimary,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(_extractError(e, 'Bir hata olustu.')), backgroundColor: AppColors.accentRed),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ]),
          );
        },
      ),
    );
  }

  // ── Create Poll Modal ──────────────────────────────────────────────────────
  void _showCreatePollModal(BuildContext context, String campaignId) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final optionCtrls = [TextEditingController(), TextEditingController()];
    int durationHours = 24;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceWhite,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 32),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Yeni Oylama Baslat', style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _modalField(titleCtrl, 'Baslik (max 140 karakter)', maxLength: 140),
              const SizedBox(height: 10),
              _modalField(descCtrl, 'Aciklama (istege bagli)', maxLines: 2),
              const SizedBox(height: 16),
              Text('Secenekler (en az 2, en fazla 5)',
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
              const SizedBox(height: 8),
              ...optionCtrls.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _modalField(e.value, 'Secenek ${e.key + 1}'),
              )),
              if (optionCtrls.length < 5)
                TextButton.icon(
                  onPressed: () => setModal(() => optionCtrls.add(TextEditingController())),
                  icon: Icon(Icons.add, color: AppColors.accentTeal),
                  label: Text('Secenek Ekle', style: TextStyle(color: AppColors.accentTeal)),
                ),
              const SizedBox(height: 16),
              Text('Oylama Suresi', style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
              const SizedBox(height: 8),
              Row(children: [24, 48, 72].map((h) {
                final selected = durationHours == h;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setModal(() => durationHours = h),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                          color: selected ? AppColors.accentTeal.withOpacity(0.1) : AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: selected ? AppColors.accentTeal : AppColors.borderLight)),
                      child: Text('${h}sa', style: TextStyle(color: selected ? AppColors.accentTeal : AppColors.textTertiary)),
                    ),
                  ),
                );
              }).toList()),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () async {
                    if (titleCtrl.text.trim().isEmpty) return;
                    final opts = optionCtrls
                        .map((c) => c.text.trim())
                        .where((t) => t.isNotEmpty)
                        .toList();
                    if (opts.length < 2) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: const Text('En az 2 secenek gerekli!'), backgroundColor: AppColors.accentRed),
                      );
                      return;
                    }
                    try {
                      await apiService.createPoll(
                        campaignId: campaignId,
                        title: titleCtrl.text.trim(),
                        description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                        options: opts,
                        durationHours: durationHours,
                      );
                      Navigator.pop(ctx);
                      if (mounted) {
                        _loadData(); // Reload polls
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: const Text('Oylama baslatildi!'),
                              backgroundColor: AppColors.navyPrimary),
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(_extractError(e, 'Bir hata olustu.')), backgroundColor: AppColors.accentRed),
                      );
                    }
                  },
                  child: const Text('OYLAMAYA BASLA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _modalField(TextEditingController ctrl, String hint, {int maxLines = 1, int? maxLength}) {
    return TextField(
      controller: ctrl,
      style: TextStyle(color: AppColors.textPrimary),
      maxLines: maxLines,
      maxLength: maxLength,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.textTertiary),
        filled: true,
        fillColor: AppColors.surfaceLight,
        counterStyle: TextStyle(color: AppColors.textTertiary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _metricCol(String label, String val, Color color) {
    return Column(children: [
      Text(val, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
      Text(label, style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. GLOBAL TAB — Takip Edilenler & Takipçiler
// ─────────────────────────────────────────────────────────────────────────────
class _GlobalTab extends StatefulWidget {
  const _GlobalTab();

  @override
  State<_GlobalTab> createState() => _GlobalTabState();
}

class _GlobalTabState extends State<_GlobalTab> {
  List<dynamic> _campaigns = [];
  bool _loading = true;
  String? _selectedCategory;
  String? _selectedStance;

  static const _categories = <String, String>{
    'GLOBAL_PEACE': 'Baris',
    'JUSTICE_RIGHTS': 'Adalet',
    'ECOLOGY_NATURE': 'Doga',
    'TECH_FUTURE': 'Teknoloji',
    'SOLIDARITY_RELIEF': 'Dayanisma',
    'ECONOMY_LABOR': 'Ekonomi',
    'AWARENESS': 'Farkindalik',
    'ENTERTAINMENT': 'Eglence',
  };

  static const _stanceColors = <String, Color>{
    'SUPPORT': Color(0xFF4CAF50),
    'REFORM': Color(0xFF2196F3),
    'PROTEST': Color(0xFFFF4444),
    'EMERGENCY': Color(0xFFFF0000),
  };

  static const _stanceLabels = <String, String>{
    'SUPPORT': 'Destek',
    'REFORM': 'Reform',
    'PROTEST': 'Protesto',
    'EMERGENCY': 'Acil',
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!apiService.isLoggedIn) {
      setState(() => _loading = false);
      return;
    }
    try {
      final campaigns = await apiService.getAllCampaigns(
        category: _selectedCategory,
        stance: _selectedStance,
        sort: 'members',
      );
      if (mounted) {
        setState(() {
          _campaigns = campaigns;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onCategoryChanged(String? category) {
    setState(() {
      _selectedCategory = category;
      _loading = true;
    });
    _loadData();
  }

  void _onStanceChanged(String? stance) {
    setState(() {
      _selectedStance = stance;
      _loading = true;
    });
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Stance filter chips
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            children: [
              _stanceChip(null, 'Tumu'),
              _stanceChip('SUPPORT', 'Destek'),
              _stanceChip('REFORM', 'Reform'),
              _stanceChip('PROTEST', 'Protesto'),
              _stanceChip('EMERGENCY', 'Acil'),
            ],
          ),
        ),
        // Category filter chips
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            children: [
              _filterChip(null, 'Tumu'),
              ..._categories.entries.map((e) => _filterChip(e.key, e.value)),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? Center(child: CircularProgressIndicator(color: AppColors.accentBlue))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: _campaigns.isEmpty
                      ? ListView(children: [
                          Padding(
                            padding: const EdgeInsets.all(32),
                            child: Center(child: Text(
                              _selectedCategory != null
                                  ? 'Bu kategoride kampanya bulunamadi.'
                                  : 'Henuz aktif kampanya yok.',
                              style: TextStyle(color: AppColors.textTertiary),
                              textAlign: TextAlign.center,
                            )),
                          ),
                        ])
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          itemCount: _campaigns.length,
                          itemBuilder: (ctx, i) => _buildCampaignCard(_campaigns[i], i + 1),
                        ),
                ),
        ),
      ],
    );
  }

  Widget _filterChip(String? category, String label) {
    final selected = _selectedCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () => _onCategoryChanged(category),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? AppColors.accentBlue : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.accentBlue : AppColors.borderLight,
              width: 0.5,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textSecondary,
              fontSize: 12,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _stanceChip(String? stance, String label) {
    final selected = _selectedStance == stance;
    final stanceColor = stance != null ? (_stanceColors[stance] ?? AppColors.accentBlue) : AppColors.accentBlue;
    final chipColor = selected ? stanceColor : AppColors.surfaceLight;
    final borderColor = selected ? stanceColor : AppColors.borderLight;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () => _onStanceChanged(stance),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: chipColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 0.5),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textSecondary,
              fontSize: 12,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCampaignCard(dynamic c, int rank) {
    final title = (c['title'] ?? '') as String;
    final slogan = (c['slogan'] ?? '') as String;
    final campaignId = (c['id'] ?? '') as String;
    final stanceType = (c['stanceType'] ?? 'SUPPORT') as String;
    final categoryType = (c['categoryType'] ?? '') as String;
    final memberCount = (c['memberCount'] ?? 0) as int;
    final totalWac = c['totalWacStaked']?.toString() ?? '0';
    final leader = c['leader'] as Map<String, dynamic>?;
    final leaderName = (leader?['displayName'] ?? leader?['slogan'] ?? 'Lider') as String;
    final stanceColor = _stanceColors[stanceType] ?? AppColors.accentBlue;
    final stanceLabel = _stanceLabels[stanceType] ?? stanceType;
    final categoryLabel = _categories[categoryType] ?? categoryType;

    return GestureDetector(
      onTap: () => _openCampaignDetail(campaignId),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: stanceColor.withOpacity(0.3), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: stanceColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(child: Text(
                    '#$rank',
                    style: TextStyle(color: stanceColor, fontSize: 11, fontWeight: FontWeight.bold),
                  )),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(title, style: TextStyle(
                    color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold,
                  ), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: stanceColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(stanceLabel, style: TextStyle(
                    color: stanceColor, fontSize: 10, fontWeight: FontWeight.bold,
                  )),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, color: AppColors.textTertiary, size: 16),
              ],
            ),
            if (slogan.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(slogan, style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.people, size: 14, color: AppColors.textTertiary),
                const SizedBox(width: 4),
                Text('$memberCount uye', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                const SizedBox(width: 16),
                Icon(Icons.account_balance_wallet, size: 14, color: AppColors.textTertiary),
                const SizedBox(width: 4),
                Text('$totalWac WAC', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                const SizedBox(width: 16),
                Icon(Icons.category, size: 14, color: AppColors.textTertiary),
                const SizedBox(width: 4),
                Text(categoryLabel, style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                const Spacer(),
                Text(leaderName, style: TextStyle(color: AppColors.accentTeal, fontSize: 11, fontWeight: FontWeight.w500),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openCampaignDetail(String campaignId) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceWhite,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _CampaignDetailSheet(campaignId: campaignId, onChanged: _loadData),
    );
  }
}

// ─── Campaign Detail Bottom Sheet ───────────────────────────────────────────
class _CampaignDetailSheet extends StatefulWidget {
  final String campaignId;
  final VoidCallback onChanged;
  const _CampaignDetailSheet({required this.campaignId, required this.onChanged});
  @override
  State<_CampaignDetailSheet> createState() => _CampaignDetailSheetState();
}

class _CampaignDetailSheetState extends State<_CampaignDetailSheet> {
  bool _loading = true;
  Map<String, dynamic>? _campaign;
  List<dynamic> _members = [];
  bool _isMember = false;
  bool _isLeader = false;
  bool _joining = false;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        apiService.getCampaign(widget.campaignId),
        apiService.getCampaignMembers(widget.campaignId),
      ]);
      final campData = results[0] as Map<String, dynamic>;
      final membersData = results[1] as Map<String, dynamic>;
      final members = (membersData['members'] as List?) ?? [];
      final myId = apiService.userId;
      if (mounted) {
        setState(() {
          _campaign = campData['campaign'] as Map<String, dynamic>?;
          _members = members;
          _isMember = members.any((m) => m['userId'] == myId);
          _isLeader = _campaign?['leaderId'] == myId;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _joinCampaign() async {
    setState(() => _joining = true);
    try {
      await apiService.joinCampaign(widget.campaignId);
      await _load();
      widget.onChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_extractError(e))),
        );
      }
    }
    if (mounted) setState(() => _joining = false);
  }

  Future<void> _leaveCampaign() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kampanyadan Ayril'),
        content: const Text('Kampanyadan ayrilmak istediginize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Iptal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ayril', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _leaving = true);
    try {
      await apiService.leaveCampaign(widget.campaignId);
      await _load();
      widget.onChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_extractError(e))),
        );
      }
    }
    if (mounted) setState(() => _leaving = false);
  }

  String _extractError(dynamic e) {
    if (e is DioException && e.response?.data != null) {
      final data = e.response!.data;
      if (data is Map<String, dynamic>) return data['error']?.toString() ?? 'Bir hata olustu.';
    }
    return 'Baglanti hatasi.';
  }

  String _fmtWac(dynamic v) {
    final d = double.tryParse(v.toString()) ?? 0;
    return d >= 1000 ? '${(d / 1000).toStringAsFixed(1)}K' : d.toStringAsFixed(1);
  }

  static const _stanceColors = {
    'SUPPORT': Color(0xFF4CAF50),
    'REFORM': Color(0xFF2196F3),
    'PROTEST': Color(0xFFFF4444),
    'EMERGENCY': Color(0xFFFF0000),
  };
  static const _stanceLabels = {
    'SUPPORT': 'Destek',
    'REFORM': 'Reform',
    'PROTEST': 'Protesto',
    'EMERGENCY': 'Acil',
  };

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(48),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_campaign == null) {
      return const Padding(
        padding: EdgeInsets.all(48),
        child: Center(child: Text('Kampanya bulunamadi.')),
      );
    }
    final c = _campaign!;
    final title = (c['title'] ?? '') as String;
    final slogan = (c['slogan'] ?? '') as String;
    final description = (c['description'] ?? '') as String;
    final stanceType = (c['stanceType'] ?? 'SUPPORT') as String;
    final totalWac = c['totalWacStaked']?.toString() ?? '0';
    final memberCount = (c['_count'] as Map?)?['members'] ?? _members.length;
    final leader = c['leader'] as Map<String, dynamic>?;
    final leaderName = (leader?['slogan'] ?? leader?['displayName'] ?? 'Lider') as String;
    final stanceColor = _stanceColors[stanceType] ?? AppColors.accentBlue;
    final stanceLabel = _stanceLabels[stanceType] ?? stanceType;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: AppColors.borderLight, borderRadius: BorderRadius.circular(2))),
            ),
            // Title + stance badge
            Row(children: [
              Expanded(child: Text(title, style: TextStyle(
                color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold,
              ))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: stanceColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                child: Text(stanceLabel, style: TextStyle(color: stanceColor, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ]),
            if (slogan.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(slogan, style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            ],
            if (description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(description, style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
            ],
            const SizedBox(height: 16),
            // Stats row
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                _statItem(Icons.people, '$memberCount', 'Uye'),
                _statItem(Icons.account_balance_wallet, _fmtWac(totalWac), 'WAC'),
                _statItem(Icons.person, leaderName, 'Lider'),
              ]),
            ),
            const SizedBox(height: 16),
            // Join / Leave buttons
            if (!_isLeader) ...[
              if (!_isMember)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _joining ? null : _joinCampaign,
                    icon: _joining
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.add, size: 18),
                    label: Text(_joining ? 'Katiliniyor...' : 'Kampanyaya Katil'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: stanceColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _leaving ? null : _leaveCampaign,
                    icon: _leaving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.exit_to_app, size: 18),
                    label: Text(_leaving ? 'Ayrılınıyor...' : 'Kampanyadan Ayril'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
            ],
            // Members list
            Text('Uyeler (Siralama)', style: TextStyle(
              color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold,
            )),
            const SizedBox(height: 8),
            ..._members.asMap().entries.map((entry) {
              final i = entry.key;
              final m = entry.value as Map<String, dynamic>;
              final user = m['user'] as Map<String, dynamic>?;
              final name = (user?['slogan'] ?? user?['email'] ?? 'Kullanici') as String;
              final stakedWac = m['stakedWac']?.toString() ?? '0';
              final isLeaderMember = m['userId'] == c['leaderId'];
              final isMe = m['userId'] == apiService.userId;
              return Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isMe ? stanceColor.withOpacity(0.08) : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                  border: isMe ? Border.all(color: stanceColor.withOpacity(0.3)) : null,
                ),
                child: Row(children: [
                  SizedBox(width: 24, child: Text(
                    '#${i + 1}',
                    style: TextStyle(color: AppColors.textTertiary, fontSize: 12, fontWeight: FontWeight.bold),
                  )),
                  if (isLeaderMember)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(Icons.star, size: 14, color: AppColors.accentAmber),
                    ),
                  Expanded(child: Text(
                    name + (isMe ? ' (Sen)' : ''),
                    style: TextStyle(
                      color: isMe ? stanceColor : AppColors.textPrimary,
                      fontSize: 13, fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                    ),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  )),
                  Text(_fmtWac(stakedWac) + ' WAC',
                    style: TextStyle(color: AppColors.accentAmber, fontSize: 11, fontWeight: FontWeight.w600)),
                ]),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _statItem(IconData icon, String value, String label) {
    return Expanded(child: Column(children: [
      Icon(icon, size: 18, color: AppColors.textTertiary),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
          maxLines: 1, overflow: TextOverflow.ellipsis),
      Text(label, style: TextStyle(color: AppColors.textTertiary, fontSize: 10)),
    ]));
  }
}