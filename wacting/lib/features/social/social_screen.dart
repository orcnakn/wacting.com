import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../app/widgets/modern_card.dart';
import '../../core/services/api_service.dart';

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
      length: 3,
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
               Tab(text: 'KISISEL', icon: Icon(Icons.person)),
               Tab(text: 'GLOBAL', icon: Icon(Icons.public)),
             ],
           ),
        ),
        body: const TabBarView(
          children: [
            _CampaignsTab(),
            _PersonalTab(),
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
      List<dynamic> polls = [];
      if (apiService.userId != null) {
        polls = await apiService.getCampaignPolls(apiService.userId!);
      }
      List<dynamic> history = [];
      try { history = await apiService.getVotingHistory(); } catch (_) {}
      if (mounted) {
        setState(() {
          _myCampaigns = campaigns;
          _myPolls = polls;
          _votingHistory = history;
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
    _tabController.animateTo(3); // 4th tab (index 3)
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
            Tab(text: 'Pasif'),
            Tab(text: 'Takip Edilenler'),
            Tab(text: 'Oylama'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildActiveCampaigns(),
              _buildPassiveCampaigns(),
              _buildFollowedCampaigns(),
              _buildVotingHistory(),
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
        GestureDetector(
          onTap: () => _showCreateCampaignModal(context),
          child: Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.navyPrimary, AppColors.accentBlue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: AppColors.accentBlue.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                child: const Icon(Icons.add, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Kampanya Olustur', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text('Ikon, slogan, tanim ve sosyal medyalarini ekle', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ]),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
            ]),
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
        ..._myCampaigns.map((c) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildDetailedCampaignCard(
            title: c['title'] ?? 'Kampanya',
            slogan: '"${c['slogan'] ?? ''}"',
            participants: 0,
            area: 0,
            myRank: 1,
            totalEarned: 0,
            dailyPremium: 0,
            isRac: false,
            hasActivePoll: _myPolls.any((p) => p['status'] == 'ACTIVE'),
            isLeader: true,
          ),
        )),
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bookmark_border, color: AppColors.textTertiary, size: 48),
          const SizedBox(height: 12),
          Text('Takip ettiginiz kampanyalar burada gorunecek.',
              style: TextStyle(color: AppColors.textTertiary), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentTeal.withOpacity(0.1),
                foregroundColor: AppColors.accentTeal),
            icon: const Icon(Icons.public),
            label: const Text('Global\'den Kesfet'),
          ),
        ],
      ),
    );
  }

  // ── Oylama Gecmisi ────────────────────────────────────────────────────────
  Widget _buildVotingHistory() {
    if (_votingHistory.isEmpty) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text('Henuz oy kullanmadiniz.', style: TextStyle(color: AppColors.textTertiary)),
      ));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
    );
  }

  // ── Campaign Card ──────────────────────────────────────────────────────────
  Widget _buildDetailedCampaignCard({
    required String title,
    required String slogan,
    required int participants,
    required int area,
    required int myRank,
    required double totalEarned,
    required double dailyPremium,
    required bool isRac,
    required bool hasActivePoll,
    required bool isLeader,
  }) {
    final color = isRac ? AppColors.accentRed : AppColors.accentBlue;
    final bgColor = isRac ? AppColors.accentRed.withOpacity(0.06) : AppColors.accentBlue.withOpacity(0.06);

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
          IconButton(icon: Icon(Icons.map, color: AppColors.textTertiary), onPressed: () {}),
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
          _metricCol('Buyukluk', '$area m\u00B2', color),
          _metricCol('Siram', '#$myRank', AppColors.accentAmber),
        ]),
        const SizedBox(height: 16),

        // Earnings
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Toplam Kazanilan', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
              Text('$totalEarned ${isRac ? 'RAC' : 'WAC'}',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
            ]),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('Gunluk Prim (Tahmini)', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
              Text('${dailyPremium > 0 ? '+' : ''}$dailyPremium',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
            ]),
          ]),
        ),

        // Buttons (vote or create poll)
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
                onPressed: () => _showCreatePollModal(context),
              ),
            ),
          ],
        ]),
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
                            SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.accentRed),
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

    // Icon selection state
    final List<Color> _iconColors = [
      AppColors.accentBlue, AppColors.accentTeal, AppColors.accentGreen,
      AppColors.accentAmber, AppColors.accentRed, Colors.purpleAccent,
      Colors.orangeAccent, Colors.teal,
    ];
    final List<IconData> _iconShapes = [
      Icons.flag, Icons.star, Icons.bolt, Icons.local_fire_department,
      Icons.public, Icons.shield, Icons.favorite, Icons.eco,
    ];
    int selectedColorIdx = 0;
    int selectedShapeIdx = 0;

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
            initialChildSize: 0.9,
            minChildSize: 0.5,
            maxChildSize: 0.95,
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
                  padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(ctx).viewInsets.bottom + 32),
                  children: [
                    // ── Baslik ──────────────────────────────────────────────
                    Text('Kampanya Olustur',
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Ikon, slogan ve sosyal medya baglantilari gir.',
                        style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
                    const SizedBox(height: 24),

                    // ── Ikon Secimi ──────────────────────────────────────────
                    Text('Ikon', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 12),
                    // Preview
                    Center(
                      child: Container(
                        width: 72, height: 72,
                        decoration: BoxDecoration(
                          color: _iconColors[selectedColorIdx].withOpacity(0.1),
                          shape: BoxShape.circle,
                          border: Border.all(color: _iconColors[selectedColorIdx], width: 2),
                        ),
                        child: Icon(_iconShapes[selectedShapeIdx], color: _iconColors[selectedColorIdx], size: 36),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Renk secimi
                    Text('Renk', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: List.generate(_iconColors.length, (i) => GestureDetector(
                        onTap: () => setModal(() => selectedColorIdx = i),
                        child: Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: _iconColors[i],
                            shape: BoxShape.circle,
                            border: selectedColorIdx == i
                                ? Border.all(color: AppColors.navyPrimary, width: 2.5)
                                : null,
                          ),
                        ),
                      )),
                    ),
                    const SizedBox(height: 12),
                    // Sekil secimi
                    Text('Sekil', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: List.generate(_iconShapes.length, (i) => GestureDetector(
                        onTap: () => setModal(() => selectedShapeIdx = i),
                        child: Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: selectedShapeIdx == i
                                ? _iconColors[selectedColorIdx].withOpacity(0.1)
                                : AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: selectedShapeIdx == i ? _iconColors[selectedColorIdx] : AppColors.borderLight),
                          ),
                          child: Icon(_iconShapes[i],
                              color: selectedShapeIdx == i ? _iconColors[selectedColorIdx] : AppColors.textTertiary,
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
                            final colorHex = '#${_iconColors[selectedColorIdx].value.toRadixString(16).substring(2).toUpperCase()}';
                            await apiService.createCampaign(
                              title: sloganCtrl.text.trim().substring(0, sloganCtrl.text.trim().length.clamp(0, 50)),
                              slogan: sloganCtrl.text.trim(),
                              description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                              videoUrl: videoCtrl.text.trim().isEmpty ? null : videoCtrl.text.trim(),
                              iconColor: colorHex,
                              iconShape: selectedShapeIdx,
                              instagramUrl: igCtrl.text.trim().isEmpty ? null : igCtrl.text.trim(),
                              twitterUrl: twCtrl.text.trim().isEmpty ? null : twCtrl.text.trim(),
                              facebookUrl: fbCtrl.text.trim().isEmpty ? null : fbCtrl.text.trim(),
                              tiktokUrl: tiktokCtrl.text.trim().isEmpty ? null : tiktokCtrl.text.trim(),
                              websiteUrl: webCtrl.text.trim().isEmpty ? null : webCtrl.text.trim(),
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
                              SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.accentRed),
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
  void _showCreatePollModal(BuildContext context) {
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
                        title: titleCtrl.text.trim(),
                        description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                        options: opts,
                        durationHours: durationHours,
                      );
                      Navigator.pop(ctx);
                      if (mounted) {
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: const Text('Oylama baslatildi!'),
                              backgroundColor: AppColors.navyPrimary),
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.accentRed),
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
// 2. KISISEL (PERSONAL) TAB
// ─────────────────────────────────────────────────────────────────────────────
class _PersonalTab extends StatelessWidget {
  const _PersonalTab();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            indicatorColor: AppColors.navyLight,
            labelColor: AppColors.navyLight,
            unselectedLabelColor: AppColors.textTertiary,
            tabs: const [
              Tab(text: 'Takipcilerim'),
              Tab(text: 'Takip Ettiklerim'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildSocialList(isFollower: true),
                _buildSocialList(isFollower: false),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSocialList({required bool isFollower}) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ModernCard(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(backgroundColor: AppColors.surfaceLight, child: Icon(Icons.person, color: AppColors.textSecondary)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('User_$index', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          IconButton(icon: const Icon(Icons.camera_alt, size: 16, color: Colors.pinkAccent), onPressed: () {}, constraints: const BoxConstraints(), padding: EdgeInsets.zero),
                          const SizedBox(width: 8),
                          IconButton(icon: const Icon(Icons.facebook, size: 16, color: Colors.blue), onPressed: () {}, constraints: const BoxConstraints(), padding: EdgeInsets.zero),
                        ],
                      )
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.message, color: AppColors.navyLight),
                  onPressed: () {
                    // Open DM
                  },
                ),
                if (!isFollower)
                  TextButton(onPressed: () {}, child: Text('Unfollow', style: TextStyle(color: AppColors.accentRed)))
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. GLOBAL TAB
// ─────────────────────────────────────────────────────────────────────────────
class _GlobalTab extends StatelessWidget {
  const _GlobalTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Search
        TextField(
          style: TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Kampanya veya Kullanici Ara...',
            hintStyle: TextStyle(color: AppColors.textTertiary),
            prefixIcon: Icon(Icons.search, color: AppColors.accentBlue),
            filled: true,
            fillColor: AppColors.surfaceLight,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)
          ),
        ),
        const SizedBox(height: 24),

        // Local Campaigns
        Row(
          children: [
            Icon(Icons.location_on, color: AppColors.accentGreen),
            const SizedBox(width: 8),
            Text('Bolgemdeki Kampanyalar', style: TextStyle(color: AppColors.accentGreen, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        _buildMiniCampaignCard('Save The Oceans (Local)', 15000),

        const SizedBox(height: 24),
        Text('En Populer Kampanyalar', style: TextStyle(color: AppColors.accentAmber, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _buildMiniCampaignCard('Global Peace Order', 5000000),
        _buildMiniCampaignCard('Mars Colony Fund', 1200000),

        const SizedBox(height: 24),
        Text('En Cok Tepki Alanlar (RAC)', style: TextStyle(color: AppColors.accentRed, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _buildMiniCampaignCard('Corporate Monopoly', -850000, isRac: true),
      ],
    );
  }

  Widget _buildMiniCampaignCard(String title, int size, {bool isRac = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: ModernCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(isRac ? Icons.warning : Icons.star, color: isRac ? AppColors.accentRed : AppColors.accentAmber),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold))),
            Text('${size} m\u00B2', style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
