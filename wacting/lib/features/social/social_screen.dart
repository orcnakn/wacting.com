import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../app/theme.dart';
import '../../app/widgets/modern_card.dart';
import '../../core/services/api_service.dart';
import '../profile/profile_screen.dart';

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

class _CampaignsTabState extends State<_CampaignsTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<dynamic> _myCampaigns = [];
  List<dynamic> _myPolls = [];
  List<dynamic> _votingHistory = [];
  List<dynamic> _followedCampaigns = [];
  bool _loadingCampaigns = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    if (!apiService.isLoggedIn) {
      setState(() => _loadingCampaigns = false);
      return;
    }
    try {
      final campaigns = await apiService.getMyCampaigns();
      // Load polls for ALL my campaigns (not userId)
      List<dynamic> polls = [];
      for (final c in campaigns) {
        final cid = c['id'] as String?;
        if (cid == null) continue;
        try {
          final campaignPolls = await apiService.getCampaignPolls(cid);
          polls.addAll(campaignPolls);
        } catch (_) {}
      }
      List<dynamic> history = [];
      try { history = await apiService.getVotingHistory(); } catch (_) {}
      List<dynamic> followedCampaigns = [];
      try { followedCampaigns = await apiService.getFollowedCampaigns(); } catch (_) {}
      if (mounted) {
        setState(() {
          _myCampaigns = campaigns;
          _myPolls = polls;
          _votingHistory = history;
          _followedCampaigns = followedCampaigns;
          _loadingCampaigns = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingCampaigns = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatCountdown(DateTime endsAt) {
    final diff = endsAt.difference(DateTime.now());
    if (diff.isNegative) return 'Sona erdi';
    final h = diff.inHours;
    final m = diff.inMinutes.remainder(60);
    return '${h}sa ${m}dk kaldi';
  }

  void _navigateToVotingHistory() {
    _tabController.animateTo(2); // Oylama tab (index 2)
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accentTeal,
          labelColor: AppColors.accentTeal,
          unselectedLabelColor: AppColors.textTertiary,
          isScrollable: true,
          tabAlignment: TabAlignment.center,
          tabs: const [
            Tab(text: 'Aktif'),
            Tab(text: 'Takip Edilenler'),
            Tab(text: 'Oylama'),
            Tab(text: 'Gecmis'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildActiveCampaigns(),
              _buildFollowedCampaigns(),
              _buildVotingHistory(),
              _buildPassiveCampaigns(),
            ],
          ),
        ),
      ],
    );
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
          return sorted.map((c) {
            final myStaked = double.tryParse((c['myStakedWac'] ?? '0').toString()) ?? 0;
            final totalStaked = double.tryParse((c['totalWacStaked'] ?? '0').toString()) ?? 0;
            final memberCount = (c['memberCount'] ?? c['_count']?['members'] ?? 0) as int;
            final isLeader = c['isLeader'] == true;

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

  // ── Takip Edilenler ────────────────────────────────────────────────────────
  Widget _buildFollowedCampaigns() {
    if (_followedCampaigns.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bookmark_border, color: AppColors.textTertiary, size: 48),
            const SizedBox(height: 12),
            Text('Takip ettiginiz kampanyalar burada gorunecek.',
                style: TextStyle(color: AppColors.textTertiary), textAlign: TextAlign.center),
          ],
        ),
      );
    }

    final sorted = [..._followedCampaigns];
    sorted.sort((a, b) {
      final aDate = DateTime.tryParse((a['createdAt'] ?? '').toString()) ?? DateTime(0);
      final bDate = DateTime.tryParse((b['createdAt'] ?? '').toString()) ?? DateTime(0);
      return bDate.compareTo(aDate);
    });

    return ListView(
      padding: const EdgeInsets.all(16),
      children: sorted.map((c) {
        final totalStaked = double.tryParse((c['totalWacStaked'] ?? '0').toString()) ?? 0;
        final memberCount = (c['memberCount'] ?? 0) as int;
        final title = (c['title'] ?? 'Kampanya') as String;
        final slogan = (c['slogan'] ?? '') as String;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _buildCompactMyCampaignRow(
            campaignId: c['id'] ?? '',
            title: title,
            slogan: slogan,
            participants: memberCount,
            totalWacStaked: totalStaked,
            myStakedWac: 0,
            isLeader: false,
          ),
        );
      }).toList(),
    );
  }

  // ── Oylama Sekmesi ────────────────────────────────────────────────────────
  Widget _buildVotingHistory() {
    final hasActivePolls = _myPolls.isNotEmpty;
    final hasHistory = _votingHistory.isNotEmpty;

    if (!hasActivePolls && !hasHistory) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.how_to_vote, color: AppColors.textTertiary, size: 48),
          const SizedBox(height: 12),
          Text('Aktif oylama yok.', style: TextStyle(color: AppColors.textTertiary)),
        ]),
      ));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Aktif Oylamalar ──
        if (hasActivePolls) ...[
          Text('Aktif Oylamalar',
              style: TextStyle(color: AppColors.accentAmber, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),
          ..._myPolls.map((poll) {
            final p = poll as Map<String, dynamic>;
            final options = (p['options'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
            final totalWac = options.fold<double>(0, (s, o) => s + ((o['totalWac'] ?? 0) as num).toDouble());
            DateTime endsAt;
            try { endsAt = DateTime.parse(p['endsAt']); } catch (_) { endsAt = DateTime.now(); }
            final isExpired = endsAt.isBefore(DateTime.now());

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ModernCard(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.how_to_vote, color: isExpired ? AppColors.textTertiary : AppColors.accentAmber, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(p['title'] ?? '',
                          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: (isExpired ? AppColors.textTertiary : AppColors.accentAmber).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(isExpired ? 'Sona Erdi' : _formatCountdown(endsAt),
                          style: TextStyle(
                              color: isExpired ? AppColors.textTertiary : AppColors.accentAmber,
                              fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ]),
                  if ((p['description'] as String?)?.isNotEmpty == true) ...[
                    const SizedBox(height: 6),
                    Text(p['description'] as String, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ],
                  const SizedBox(height: 12),
                  ...options.map((opt) {
                    final wacPct = totalWac > 0 ? ((opt['totalWac'] ?? 0) as num).toDouble() / totalWac : 0.0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text(opt['text'] as String,
                              style: TextStyle(color: AppColors.textPrimary, fontSize: 13))),
                          Text('${(wacPct * 100).toStringAsFixed(1)}%',
                              style: TextStyle(color: AppColors.textTertiary, fontSize: 11)),
                        ]),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: wacPct, backgroundColor: AppColors.borderLight,
                            color: AppColors.accentBlue, minHeight: 4,
                          ),
                        ),
                      ]),
                    );
                  }),
                  if (!isExpired) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentAmber.withOpacity(0.1),
                            foregroundColor: AppColors.accentAmber,
                            padding: const EdgeInsets.symmetric(vertical: 10)),
                        icon: const Icon(Icons.how_to_vote, size: 16),
                        label: const Text('Oy Ver', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () => _showVoteModalForPoll(context, p),
                      ),
                    ),
                  ],
                ]),
              ),
            );
          }),
          const SizedBox(height: 16),
        ],

        // ── Oy Gecmisi ──
        if (hasHistory) ...[
          Text('Oy Kullandigim Anketler',
              style: TextStyle(color: AppColors.textTertiary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ..._votingHistory.map((h) {
            final result = (h['result'] ?? 'Devam Ediyor') as String;
            final isActive = result == 'Devam Ediyor';
            final didWin = result == 'Kazandi';
            final statusColor = isActive
                ? AppColors.accentTeal
                : (didWin ? AppColors.accentAmber : AppColors.textTertiary);
            final statusIcon = isActive
                ? Icons.hourglass_top
                : (didWin ? Icons.emoji_events : Icons.close);

            DateTime endsAt;
            try { endsAt = DateTime.parse(h['endsAt']); } catch (_) { endsAt = DateTime.now(); }

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ModernCard(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(statusIcon, color: statusColor, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text((h['pollTitle'] ?? '') as String,
                          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(result,
                          style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Divider(color: AppColors.borderLight),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Secimim', style: TextStyle(color: AppColors.textTertiary, fontSize: 11)),
                      Text((h['myChoice'] ?? '') as String,
                          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                    ]),
                    if (h['winnerOption'] != null) Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('Kazanan', style: TextStyle(color: AppColors.textTertiary, fontSize: 11)),
                      Text(h['winnerOption'] as String,
                          style: TextStyle(color: didWin ? AppColors.accentAmber : AppColors.textTertiary, fontWeight: FontWeight.w600)),
                    ]),
                    if (isActive) Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('Kalan Sure', style: TextStyle(color: AppColors.textTertiary, fontSize: 11)),
                      Text(_formatCountdown(endsAt),
                          style: TextStyle(color: AppColors.accentTeal, fontWeight: FontWeight.bold, fontSize: 12)),
                    ]),
                  ]),
                ]),
              ),
            );
          }),
        ],
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
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceWhite,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: _buildDetailedCampaignCard(
          campaignId: campaignId,
          title: title,
          slogan: slogan,
          participants: participants,
          totalWacStaked: totalWacStaked,
          myStakedWac: myStakedWac,
          isRac: false,
          hasActivePoll: _myPolls.isNotEmpty,
          isLeader: isLeader,
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
            onTap: _navigateToVotingHistory,
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
                    Text(_myPolls.isNotEmpty ? _formatCountdown(DateTime.parse(_myPolls.first['endsAt'])) : '',
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
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('Cikis Cezasi (%30)', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
              Text('${_fmtWac(myStakedWac * 0.30)} WAC',
                  style: TextStyle(color: AppColors.accentRed, fontWeight: FontWeight.bold, fontSize: 14)),
            ]),
          ]),
        ),

        // Buttons
        const SizedBox(height: 12),
        Row(children: [
          if (hasActivePoll && !isLeader) Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentAmber.withOpacity(0.1),
                  foregroundColor: AppColors.accentAmber),
              icon: const Icon(Icons.how_to_vote, size: 18),
              label: const Text('Oy Ver'),
              onPressed: () => _showVoteModal(context),
            ),
          ),
          if (isLeader) ...[
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentGreen.withOpacity(0.1),
                    foregroundColor: AppColors.accentGreen),
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text('Oylama Baslat'),
                onPressed: () => _showCreatePollModal(context, campaignId),
              ),
            ),
          ],
          const SizedBox(width: 8),
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

  // ── Vote Modal ─────────────────────────────────────────────────────────────
  void _showVoteModal(BuildContext context) {
    if (_myPolls.isEmpty) return;
    String? selectedOptionId;
    final poll = _myPolls.first as Map<String, dynamic>;
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
              const Spacer(),
              Text('${poll['totalVoters'] ?? 0} katilimci',
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
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
                      // WAC progress bar
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
                        Text('${(((opt['totalWac'] ?? 0) as num).toDouble() / 1000).toStringAsFixed(1)}K WAC',
                            style: TextStyle(color: AppColors.textTertiary, fontSize: 11)),
                        Text('${opt['voterCount']} kisi',
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
                          _navigateToVotingHistory();
                          _loadData(); // Refresh
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Oyunuz kaydedildi!'),
                              backgroundColor: AppColors.navyPrimary,
                            ),
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
  List<dynamic> _following = [];
  List<dynamic> _campaignFollowers = [];
  bool _loading = true;

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
      final following = await apiService.getFollowing();
      List<dynamic> campaignFollowers = [];
      try {
        final res = await apiService.getFollowers();
        campaignFollowers = res;
      } catch (_) {}
      if (mounted) {
        setState(() {
          _following = following;
          _campaignFollowers = campaignFollowers;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _loading
        ? Center(child: CircularProgressIndicator(color: AppColors.accentBlue))
        : RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Icon(Icons.person_add, color: AppColors.accentBlue),
              const SizedBox(width: 8),
              Text('Takip Edilenler', style: TextStyle(color: AppColors.accentBlue, fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('${_following.length}', style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),
          if (_following.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(child: Text('Henuz kimseyi takip etmiyorsun.',
                  style: TextStyle(color: AppColors.textTertiary))),
            )
          else
            ...(_following.map((f) {
              final user = f['following'] as Map<String, dynamic>?;
              if (user == null) return const SizedBox.shrink();
              final name = (user['displayName'] ?? user['slogan'] ?? 'Kullanici') as String;
              final slogan = (user['slogan'] ?? '') as String;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: GestureDetector(
                  onTap: () {
                    final uid = user['id'] as String?;
                    if (uid != null) {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => ProfileScreen(viewUserId: uid),
                      ));
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.borderLight, width: 0.5),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.accentBlue.withOpacity(0.1),
                          child: Icon(Icons.person, size: 16, color: AppColors.accentBlue),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                              if (slogan.isNotEmpty)
                                Text(slogan, style: TextStyle(color: AppColors.textTertiary, fontSize: 11),
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () async {
                            try {
                              await apiService.unfollowUser(user['id']);
                              _loadData();
                            } catch (_) {}
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.accentRed.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('Birak', style: TextStyle(color: AppColors.accentRed, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            })),

          const SizedBox(height: 24),
          Divider(color: AppColors.borderLight),
          const SizedBox(height: 16),

          Row(
            children: [
              Icon(Icons.people, color: AppColors.accentTeal),
              const SizedBox(width: 8),
              Text('Takipciler', style: TextStyle(color: AppColors.accentTeal, fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('${_campaignFollowers.length}', style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),
          if (_campaignFollowers.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(child: Text('Henuz takipcin yok.',
                  style: TextStyle(color: AppColors.textTertiary))),
            )
          else
            ...(_campaignFollowers.map((f) {
              final user = f['follower'] as Map<String, dynamic>?;
              if (user == null) return const SizedBox.shrink();
              final name = (user['displayName'] ?? user['slogan'] ?? 'Kullanici') as String;
              final slogan = (user['slogan'] ?? '') as String;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: GestureDetector(
                  onTap: () {
                    final uid = user['id'] as String?;
                    if (uid != null) {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => ProfileScreen(viewUserId: uid),
                      ));
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.borderLight, width: 0.5),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.accentTeal.withOpacity(0.1),
                          child: Icon(Icons.person, size: 16, color: AppColors.accentTeal),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                              if (slogan.isNotEmpty)
                                Text(slogan, style: TextStyle(color: AppColors.textTertiary, fontSize: 11),
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            })),
        ],
      ),
    );
  }
}