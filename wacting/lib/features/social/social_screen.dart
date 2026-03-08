import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../app/widgets/modern_card.dart';

class SocialScreen extends StatefulWidget {
  final String userToken;

  const SocialScreen({Key? key, required this.userToken}) : super(key: key);

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  // Mock Data
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0D0D),
        appBar: AppBar(
           title: const Text('Akış (Feed)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: Colors.white)),
           backgroundColor: Colors.transparent,
           elevation: 0,
           centerTitle: true,
           bottom: const TabBar(
             indicatorColor: Colors.blueAccent,
             labelColor: Colors.blueAccent,
             unselectedLabelColor: Colors.white54,
             indicatorWeight: 3,
             tabs: [
               Tab(text: 'KAMPANYALAR', icon: Icon(Icons.flag)),
               Tab(text: 'KİŞİSEL', icon: Icon(Icons.person)),
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

  // Mock active poll data
  final Map<String, dynamic> _activePoll = {
    'id': 'poll_001',
    'title': 'Önümüzdeki ay için stratejimiz ne olsun?',
    'description': 'Kampanyamızın yönünü belirlemek için oy kullanın.',
    'endsAt': DateTime.now().add(const Duration(hours: 18, minutes: 34)),
    'options': [
      {'id': 'opt_1', 'text': 'Yeni bölgelere genişle', 'voterCount': 148, 'totalWac': 75000},
      {'id': 'opt_2', 'text': 'Mevcut bölgeyi pekiştir', 'voterCount': 210, 'totalWac': 120000},
      {'id': 'opt_3', 'text': 'RAC havuzunu temizle', 'voterCount': 55, 'totalWac': 15000},
    ],
    'totalVoters': 413,
    'myVote': null, // null = not voted yet
  };

  bool _isMyOwnCampaign = true; // Mock: current user is campaign leader

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
    return '${h}sa ${m}dk kaldı';
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
          indicatorColor: Colors.cyanAccent,
          labelColor: Colors.cyanAccent,
          unselectedLabelColor: Colors.white38,
          isScrollable: true,
          tabAlignment: TabAlignment.center,
          tabs: const [
            Tab(text: 'Aktif'),
            Tab(text: 'Pasif'),
            Tab(text: 'Takip Edilenler'),
            Tab(text: '🗳️ Oylama'),
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
        _buildDetailedCampaignCard(
          title: 'Commander of the North',
          slogan: '"Winter is coming.. bring WAC"',
          participants: 2450,
          area: 145000,
          myRank: 12,
          totalEarned: 450,
          dailyPremium: 12.5,
          isRac: false,
          hasActivePoll: true,
          isLeader: _isMyOwnCampaign,
        ),
        const SizedBox(height: 16),
        const Text('Tepki (Protest) Havuzları',
            style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildDetailedCampaignCard(
          title: 'Anti-Spam Coalition',
          slogan: '"Temiz harita istiyoruz"',
          participants: 800,
          area: -45000,
          myRank: 45,
          totalEarned: -50,
          dailyPremium: -1.0,
          isRac: true,
          hasActivePoll: false,
          isLeader: false,
        ),
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
          const Center(child: Text('Ayrıldığınız kampanya yok.', style: TextStyle(color: Colors.white54))),
        ...history.map((h) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ModernCard(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(h['title']!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                _metricCol('Katıldı', h['joinedAt']!, Colors.white54),
                _metricCol('Ayrıldı', h['exitedAt']!, Colors.white54),
                _metricCol('Kazanılan', '${h['totalEarned']} WAC', Colors.amberAccent),
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
          const Icon(Icons.bookmark_border, color: Colors.white38, size: 48),
          const SizedBox(height: 12),
          const Text('Takip ettiğiniz kampanyalar burada görünecek.',
              style: TextStyle(color: Colors.white54), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent.withOpacity(0.2),
                foregroundColor: Colors.cyanAccent),
            icon: const Icon(Icons.public),
            label: const Text('Global\'den Keşfet'),
          ),
        ],
      ),
    );
  }

  // ── Oylama Geçmişi ────────────────────────────────────────────────────────
  Widget _buildVotingHistory() {
    final mockHistory = [
      {
        'title': 'Önümüzdeki ay için stratejimiz ne olsun?',
        'campaign': 'Commander of the North',
        'myChoice': 'Mevcut bölgeyi pekiştir',
        'winner': null, // null = still active
        'status': 'Devam Ediyor',
        'endsAt': DateTime.now().add(const Duration(hours: 18, minutes: 34)),
      },
      {
        'title': 'Yeni simge rengi seçimi',
        'campaign': 'Commander of the North',
        'myChoice': 'Neon Mavi',
        'winner': 'Neon Mavi',
        'status': 'Kazandı',
        'endsAt': DateTime.now().subtract(const Duration(days: 3)),
      },
      {
        'title': 'Kış seferi başlatalım mı?',
        'campaign': 'Commander of the North',
        'myChoice': 'Hayır',
        'winner': 'Evet',
        'status': 'Kaybetti',
        'endsAt': DateTime.now().subtract(const Duration(days: 7)),
      },
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Oy Kullandığım Anketler',
            style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...mockHistory.map((h) {
          final isActive = h['winner'] == null;
          final didWin = h['winner'] != null && h['winner'] == h['myChoice'];
          final statusColor = isActive
              ? Colors.cyanAccent
              : (didWin ? Colors.amberAccent : Colors.white38);
          final statusIcon = isActive
              ? Icons.hourglass_top
              : (didWin ? Icons.emoji_events : Icons.close);

          final endsAt = h['endsAt'] as DateTime;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ModernCard(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(statusIcon, color: statusColor, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(h['title'] as String,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(h['status'] as String,
                        style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ]),
                const SizedBox(height: 8),
                Text(h['campaign'] as String,
                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 8),
                const Divider(color: Colors.white10),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Seçimim', style: TextStyle(color: Colors.white54, fontSize: 11)),
                    Text(h['myChoice'] as String,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ]),
                  if (h['winner'] != null) Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    const Text('Kazanan', style: TextStyle(color: Colors.white54, fontSize: 11)),
                    Text(h['winner'] as String,
                        style: TextStyle(color: didWin ? Colors.amberAccent : Colors.white54, fontWeight: FontWeight.w600)),
                  ]),
                  if (isActive) Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    const Text('Kalan Süre', style: TextStyle(color: Colors.white54, fontSize: 11)),
                    Text(_formatCountdown(endsAt),
                        style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 12)),
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
    final color = isRac ? Colors.redAccent : Colors.blueAccent;
    final bgHex = isRac ? 0xFF2A0808 : 0xFF081C2A;

    return ModernCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header row
        Row(children: [
          CircleAvatar(
              backgroundColor: color.withOpacity(0.2),
              radius: 24,
              child: Icon(isRac ? Icons.warning : Icons.flag, color: color)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            Text(slogan, style: const TextStyle(color: Colors.white70, fontStyle: FontStyle.italic)),
          ])),
          IconButton(icon: const Icon(Icons.map, color: Colors.white54), onPressed: () {}),
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
                  color: Colors.amberAccent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amberAccent.withOpacity(0.4))),
              child: Row(children: [
                const Icon(Icons.how_to_vote, color: Colors.amberAccent, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('🗳️ Aktif Oylama Var!',
                        style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(_formatCountdown(_activePoll['endsAt'] as DateTime),
                        style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  ]),
                ),
                const Icon(Icons.arrow_forward_ios, color: Colors.amberAccent, size: 14),
              ]),
            ),
          ),
        ],

        const SizedBox(height: 16),
        const Divider(color: Colors.white10),
        const SizedBox(height: 16),

        // Metrics
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _metricCol('Katılımcı', '$participants', color),
          _metricCol('Büyüklük', '$area m²', color),
          _metricCol('Sıram', '#$myRank', Colors.amberAccent),
        ]),
        const SizedBox(height: 16),

        // Earnings
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Color(bgHex), borderRadius: BorderRadius.circular(8)),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Toplam Kazanılan', style: TextStyle(color: Colors.white54, fontSize: 12)),
              Text('$totalEarned ${isRac ? 'RAC' : 'WAC'}',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
            ]),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              const Text('Günlük Prim (Tahmini)', style: TextStyle(color: Colors.white54, fontSize: 12)),
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
                  backgroundColor: Colors.amberAccent.withOpacity(0.2),
                  foregroundColor: Colors.amberAccent),
              icon: const Icon(Icons.how_to_vote, size: 18),
              label: const Text('Oy Ver'),
              onPressed: () => _showVoteModal(context),
            ),
          ),
          if (isLeader) ...[
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.greenAccent.withOpacity(0.15),
                    foregroundColor: Colors.greenAccent),
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text('Oylama Başlat'),
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
    String? selectedOptionId;
    final poll = _activePoll;
    final options = poll['options'] as List<Map<String, dynamic>>;
    final totalWac = options.fold<double>(0, (s, o) => s + (o['totalWac'] as int).toDouble());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.how_to_vote, color: Colors.amberAccent),
              const SizedBox(width: 8),
              Text(_formatCountdown(poll['endsAt'] as DateTime),
                  style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('${poll['totalVoters']} katılımcı',
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ]),
            const SizedBox(height: 12),
            Text(poll['title'] as String,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            if ((poll['description'] as String?)?.isNotEmpty == true) ...[
              const SizedBox(height: 6),
              Text(poll['description'] as String,
                  style: const TextStyle(color: Colors.white70)),
            ],
            const SizedBox(height: 20),
            ...options.map((opt) {
              final wacPct = totalWac > 0 ? (opt['totalWac'] as int) / totalWac : 0.0;
              final isSelected = selectedOptionId == opt['id'];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GestureDetector(
                  onTap: () => setModal(() => selectedOptionId = opt['id'] as String),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.amberAccent.withOpacity(0.15) : const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: isSelected ? Colors.amberAccent : Colors.white12, width: isSelected ? 1.5 : 1),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                            color: isSelected ? Colors.amberAccent : Colors.white38, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(opt['text'] as String,
                              style: TextStyle(
                                  color: isSelected ? Colors.amberAccent : Colors.white,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      // WAC progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: wacPct,
                          backgroundColor: Colors.white10,
                          color: isSelected ? Colors.amberAccent : Colors.blueAccent,
                          minHeight: 4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('${((opt['totalWac'] as int) / 1000).toStringAsFixed(1)}K WAC',
                            style: const TextStyle(color: Colors.white54, fontSize: 11)),
                        Text('${opt['voterCount']} kişi',
                            style: const TextStyle(color: Colors.white54, fontSize: 11)),
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
                    backgroundColor: Colors.amberAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: selectedOptionId == null
                    ? null
                    : () {
                        Navigator.pop(ctx);
                        _navigateToVotingHistory();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✅ Oyunuz kaydedildi! Oylama Geçmişinde takip edebilirsiniz.'),
                            backgroundColor: Color(0xFF1E1E1E),
                          ),
                        );
                      },
                child: const Text('OY VER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ]),
        ),
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
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 32),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Yeni Oylama Başlat', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _modalField(titleCtrl, 'Başlık (max 140 karakter)', maxLength: 140),
              const SizedBox(height: 10),
              _modalField(descCtrl, 'Açıklama (isteğe bağlı)', maxLines: 2),
              const SizedBox(height: 16),
              const Text('Seçenekler (en az 2, en fazla 5)',
                  style: TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 8),
              ...optionCtrls.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _modalField(e.value, 'Seçenek ${e.key + 1}'),
              )),
              if (optionCtrls.length < 5)
                TextButton.icon(
                  onPressed: () => setModal(() => optionCtrls.add(TextEditingController())),
                  icon: const Icon(Icons.add, color: Colors.cyanAccent),
                  label: const Text('Seçenek Ekle', style: TextStyle(color: Colors.cyanAccent)),
                ),
              const SizedBox(height: 16),
              const Text('Oylama Süresi', style: TextStyle(color: Colors.white54, fontSize: 13)),
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
                          color: selected ? Colors.cyanAccent.withOpacity(0.2) : const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: selected ? Colors.cyanAccent : Colors.white12)),
                      child: Text('${h}sa', style: TextStyle(color: selected ? Colors.cyanAccent : Colors.white54)),
                    ),
                  ),
                );
              }).toList()),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent.withOpacity(0.9),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('🗳️ Oylama başlatıldı! Tüm katılımcılara bildirim gönderildi.')),
                    );
                  },
                  child: const Text('OYLAMAYA BAŞLA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
      style: const TextStyle(color: Colors.white),
      maxLines: maxLines,
      maxLength: maxLength,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: const Color(0xFF2A2A2A),
        counterStyle: const TextStyle(color: Colors.white38),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _metricCol(String label, String val, Color color) {
    return Column(children: [
      Text(val, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. KİŞİSEL (PERSONAL) TAB
// ─────────────────────────────────────────────────────────────────────────────
class _PersonalTab extends StatelessWidget {
  const _PersonalTab();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            indicatorColor: Colors.purpleAccent,
            labelColor: Colors.purpleAccent,
            unselectedLabelColor: Colors.white38,
            tabs: [
              Tab(text: 'Takipçilerim'),
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
                CircleAvatar(backgroundColor: Colors.grey.shade800, child: const Icon(Icons.person, color: Colors.white)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('User_$index', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                  icon: const Icon(Icons.message, color: Colors.purpleAccent),
                  onPressed: () {
                    // Open DM
                  },
                ),
                if (!isFollower) 
                  TextButton(onPressed: () {}, child: const Text('Unfollow', style: TextStyle(color: Colors.redAccent)))
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
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Kampanya veya Kullanıcı Ara...',
            hintStyle: const TextStyle(color: Colors.white54),
            prefixIcon: const Icon(Icons.search, color: Colors.blueAccent),
            filled: true,
            fillColor: const Color(0xFF1E1E1E),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)
          ),
        ),
        const SizedBox(height: 24),
        
        // Local Campaigns
        const Row(
          children: [
            Icon(Icons.location_on, color: Colors.greenAccent),
            SizedBox(width: 8),
            Text('Bölgemdeki Kampanyalar', style: TextStyle(color: Colors.greenAccent, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        _buildMiniCampaignCard('Save The Oceans (Local)', 15000),
        
        const SizedBox(height: 24),
        const Text('En Popüler Kampanyalar', style: TextStyle(color: Colors.amberAccent, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _buildMiniCampaignCard('Global Peace Order', 5000000),
        _buildMiniCampaignCard('Mars Colony Fund', 1200000),

        const SizedBox(height: 24),
        const Text('En Çok Tepki Alanlar (RAC)', style: TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold)),
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
            Icon(isRac ? Icons.warning : Icons.star, color: isRac ? Colors.redAccent : Colors.amberAccent),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            Text('${size} m²', style: const TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}
