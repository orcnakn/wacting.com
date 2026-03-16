import 'package:dio/dio.dart';
import '../config/app_config.dart';

class ApiService {
  static final ApiService _instance = ApiService._();
  factory ApiService() => _instance;
  ApiService._();

  String? _token;
  String? _userId;

  String? get token => _token;
  String? get userId => _userId;
  bool get isLoggedIn => _token != null;

  late final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConfig.apiBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  Dio get dio => _dio;

  void setAuth(String token, String userId) {
    _token = token;
    _userId = userId;
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  void clearAuth() {
    _token = null;
    _userId = null;
    _dio.options.headers.remove('Authorization');
  }

  // ── Auth ────────────────────────────────────────────────────────────────────

  /// Register — token DÖNMEZ, needsVerification: true döner
  Future<Map<String, dynamic>> emailRegister(String email, String password, {String? username}) async {
    final res = await _dio.post('/auth/email/register', data: {
      'email': email,
      'password': password,
      if (username != null) 'username': username,
    });
    return res.data as Map<String, dynamic>;
  }

  /// 6 haneli aktivasyon kodunu doğrula — başarılıysa token döner
  Future<Map<String, dynamic>> verifyCode(String email, String code) async {
    final res = await _dio.post('/auth/verify-code', data: {
      'email': email,
      'code': code,
    });
    final data = res.data as Map<String, dynamic>;
    if (data['token'] != null) {
      setAuth(data['token'], data['userId']);
    }
    return data;
  }

  /// Aktivasyon kodunu tekrar gönder
  Future<Map<String, dynamic>> resendVerification(String email) async {
    final res = await _dio.post('/auth/resend-verification', data: {
      'email': email,
    });
    return res.data as Map<String, dynamic>;
  }

  /// Login — sadece doğrulanmış kullanıcılar giriş yapabilir
  Future<Map<String, dynamic>> emailLogin(String email, String password) async {
    final res = await _dio.post('/auth/email/login', data: {
      'email': email,
      'password': password,
    });
    final data = res.data as Map<String, dynamic>;
    if (data['token'] != null) {
      setAuth(data['token'], data['userId']);
    }
    return data;
  }

  // ── Social Login ───────────────────────────────────────────────────────────

  /// Social login — accepts token + userId from OAuth callback
  void handleSocialLoginResult(String token, String usrId) {
    setAuth(token, usrId);
  }

  /// Get the OAuth start URL for a given provider
  String getOAuthStartUrl(String provider) {
    return '${AppConfig.apiBaseUrl}/auth/oauth/start/$provider';
  }

  // ── Campaigns ───────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> createCampaign({
    required String title,
    required String slogan,
    String? description,
    String? videoUrl,
    required String iconColor,
    required int iconShape,
    double speed = 0.5,
    String stakeAmount = '1.000000',
    String? instagramUrl,
    String? twitterUrl,
    String? facebookUrl,
    String? tiktokUrl,
    String? websiteUrl,
  }) async {
    final res = await _dio.post('/campaign/create', data: {
      'title': title,
      'slogan': slogan,
      if (description != null && description.isNotEmpty) 'description': description,
      if (videoUrl != null && videoUrl.isNotEmpty) 'videoUrl': videoUrl,
      'iconColor': iconColor,
      'iconShape': iconShape,
      'speed': speed,
      'stakeAmount': stakeAmount,
      if (instagramUrl != null && instagramUrl.isNotEmpty) 'instagramUrl': instagramUrl,
      if (twitterUrl != null && twitterUrl.isNotEmpty) 'twitterUrl': twitterUrl,
      if (facebookUrl != null && facebookUrl.isNotEmpty) 'facebookUrl': facebookUrl,
      if (tiktokUrl != null && tiktokUrl.isNotEmpty) 'tiktokUrl': tiktokUrl,
      if (websiteUrl != null && websiteUrl.isNotEmpty) 'websiteUrl': websiteUrl,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> joinCampaign(String campaignId, {String stakeAmount = '1.000000'}) async {
    final res = await _dio.post('/campaign/$campaignId/join', data: {
      'stakeAmount': stakeAmount,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> leaveCampaign(String campaignId) async {
    final res = await _dio.post('/campaign/$campaignId/leave');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> addCampaignStake(String campaignId, String amount) async {
    final res = await _dio.post('/campaign/$campaignId/stake', data: {
      'amount': amount,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getCampaign(String campaignId) async {
    final res = await _dio.get('/campaign/$campaignId');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getCampaignMembers(String campaignId) async {
    final res = await _dio.get('/campaign/$campaignId/members');
    return res.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getMyCampaigns() async {
    final res = await _dio.get('/campaign/mine');
    return (res.data as Map<String, dynamic>)['campaigns'] as List<dynamic>;
  }

  Future<List<dynamic>> getAllCampaigns() async {
    final res = await _dio.get('/campaign/all');
    return (res.data as Map<String, dynamic>)['campaigns'] as List<dynamic>;
  }

  // ── Polls / Voting ──────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> createPoll({
    required String campaignId,
    required String title,
    String? description,
    required List<String> options,
    required int durationHours,
  }) async {
    final res = await _dio.post('/vote/create', data: {
      'campaignId': campaignId,
      'title': title,
      if (description != null && description.isNotEmpty) 'description': description,
      'options': options,
      'durationHours': durationHours,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getCampaignPolls(String campaignId) async {
    final res = await _dio.get('/vote/campaign/$campaignId');
    return (res.data as Map<String, dynamic>)['polls'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> castVote(String pollId, String optionId) async {
    final res = await _dio.post('/vote/$pollId/vote', data: {
      'optionId': optionId,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getVotingHistory() async {
    final res = await _dio.get('/vote/history');
    return (res.data as Map<String, dynamic>)['history'] as List<dynamic>;
  }

  Future<List<dynamic>> getNearbyCampaigns() async {
    final res = await _dio.get('/campaign/nearby');
    return (res.data as Map<String, dynamic>)['campaigns'] as List<dynamic>;
  }

  Future<List<dynamic>> getPopularCampaigns() async {
    final res = await _dio.get('/campaign/popular');
    return (res.data as Map<String, dynamic>)['campaigns'] as List<dynamic>;
  }

  Future<List<dynamic>> getTrendingCampaigns() async {
    final res = await _dio.get('/campaign/trending');
    return (res.data as Map<String, dynamic>)['campaigns'] as List<dynamic>;
  }

  // ── Notifications ────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getNotifications({int page = 1, int limit = 20}) async {
    final res = await _dio.get('/api/notifications', queryParameters: {'page': page, 'limit': limit});
    return res.data;
  }

  Future<int> getUnreadNotificationCount() async {
    try {
      final res = await _dio.get('/api/notifications/unread-count');
      return (res.data['count'] ?? 0) as int;
    } catch (_) {
      return 0;
    }
  }

  Future<void> markNotificationRead(String id) async {
    await _dio.put('/api/notifications/$id/read');
  }

  Future<void> markAllNotificationsRead() async {
    await _dio.put('/api/notifications/read-all');
  }

  // ── Profile ──────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getProfileById(String userId) async {
    final res = await _dio.get('/api/profile/$userId');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getDailyRewards(String userId) async {
    final res = await _dio.get('/api/profile/$userId/daily-rewards');
    return res.data as Map<String, dynamic>;
  }

  Future<void> updateProfile({String? displayName, String? avatarUrl, String? slogan, String? description}) async {
    final body = <String, dynamic>{};
    if (displayName != null) body['displayName'] = displayName;
    if (avatarUrl != null) body['avatarUrl'] = avatarUrl;
    if (slogan != null) body['slogan'] = slogan;
    if (description != null) body['description'] = description;
    await _dio.put('/api/profile', data: body);
  }
}

final apiService = ApiService();
