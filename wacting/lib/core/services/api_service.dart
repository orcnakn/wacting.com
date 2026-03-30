import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    _persistAuth(token, userId);
  }

  void clearAuth() {
    _token = null;
    _userId = null;
    _dio.options.headers.remove('Authorization');
    _clearPersistedAuth();
  }

  Future<void> _persistAuth(String token, String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('wacting_token', token);
    await prefs.setString('wacting_userId', userId);
  }

  Future<void> _clearPersistedAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('wacting_token');
    await prefs.remove('wacting_userId');
  }

  /// Try to restore session from persistent storage. Returns true if restored.
  Future<bool> tryRestoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('wacting_token');
    final userId = prefs.getString('wacting_userId');
    if (token != null && userId != null) {
      _token = token;
      _userId = userId;
      _dio.options.headers['Authorization'] = 'Bearer $token';
      return true;
    }
    return false;
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
    String? stanceType,
    String? categoryType,
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
      if (stanceType != null) 'stanceType': stanceType,
      if (categoryType != null) 'categoryType': categoryType,
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

  Future<Map<String, dynamic>> updateCampaignSpeed(String campaignId, double speed) async {
    final res = await _dio.post('/campaign/$campaignId/speed', data: {'speed': speed});
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> emergencySpendWac(String campaignId, {required String amount, required String target}) async {
    final res = await _dio.post('/campaign/$campaignId/emergency-spend', data: {
      'amount': amount,
      'target': target,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getMyCampaigns() async {
    final res = await _dio.get('/campaign/mine');
    return (res.data as Map<String, dynamic>)['campaigns'] as List<dynamic>;
  }

  Future<List<dynamic>> getAllCampaigns({String? category, String? stance, String sort = 'members', int take = 50}) async {
    final params = <String, dynamic>{'sort': sort, 'take': take};
    if (category != null) params['category'] = category;
    if (stance != null) params['stance'] = stance;
    final res = await _dio.get('/campaign/all', queryParameters: params);
    return (res.data as Map<String, dynamic>)['campaigns'] as List<dynamic>;
  }

  Future<List<dynamic>> getFollowedCampaigns() async {
    final res = await _dio.get('/feed/campaigns/following');
    return (res.data as Map<String, dynamic>)['campaigns'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> getGlobalUsers({int take = 50, int skip = 0}) async {
    final res = await _dio.get('/feed/global/users', queryParameters: {'take': take, 'skip': skip});
    return res.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getGlobalCampaigns({String? category, String? stance, String sort = 'members', int take = 50}) async {
    final params = <String, dynamic>{'sort': sort, 'take': take};
    if (category != null) params['category'] = category;
    if (stance != null) params['stance'] = stance;
    final res = await _dio.get('/feed/global/campaigns', queryParameters: params);
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

  // ── Icon Restrictions ───────────────────────────────────────────────────────

  Future<Map<String, double>?> getMyIconPosition() async {
    try {
      final res = await _dio.get('/icons/my-position');
      final data = res.data as Map<String, dynamic>;
      return {
        'lat': (data['lat'] as num).toDouble(),
        'lng': (data['lng'] as num).toDouble(),
      };
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, List<String>>> getMyBounds() async {
    final res = await _dio.get('/icons/my-bounds');
    final data = res.data as Map<String, dynamic>;
    return {
      'continents': List<String>.from(data['restrictedContinents'] ?? []),
      'countries':  List<String>.from(data['restrictedCountries']  ?? []),
      'cities':     List<String>.from(data['restrictedCities']     ?? []),
    };
  }

  Future<void> restrictBounds({
    List<String> continents = const [],
    List<String> countries = const [],
    List<String> cities = const [],
  }) async {
    await _dio.post('/icons/restrict_bounds', data: {
      'restrictedContinents': continents,
      'restrictedCountries': countries,
      'restrictedCities': cities,
    });
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

  Future<void> updateProfileSocialUrls({
    String? twitterUrl,
    String? facebookUrl,
    String? instagramUrl,
    String? tiktokUrl,
    String? linkedinUrl,
  }) async {
    final body = <String, dynamic>{};
    if (twitterUrl != null) body['twitterUrl'] = twitterUrl;
    if (facebookUrl != null) body['facebookUrl'] = facebookUrl;
    if (instagramUrl != null) body['instagramUrl'] = instagramUrl;
    if (tiktokUrl != null) body['tiktokUrl'] = tiktokUrl;
    if (linkedinUrl != null) body['linkedinUrl'] = linkedinUrl;
    await _dio.put('/api/profile', data: body);
  }

  // ── Follow / Social ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>> followUser(String followingId) async {
    final res = await _dio.post('/follow', data: {'followingId': followingId});
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> unfollowUser(String followingId) async {
    final res = await _dio.post('/unfollow', data: {'followingId': followingId});
    return res.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getFollowers() async {
    final res = await _dio.get('/followers');
    return (res.data as Map<String, dynamic>)['followers'] as List<dynamic>;
  }

  Future<List<dynamic>> getFollowing() async {
    final res = await _dio.get('/following');
    return (res.data as Map<String, dynamic>)['following'] as List<dynamic>;
  }

  // ── Campaign Filters ─────────────────────────────────────────────────────

  Future<List<dynamic>> getLynchedCampaigns() async {
    final res = await _dio.get('/campaign/lynched');
    return (res.data as Map<String, dynamic>)['campaigns'] as List<dynamic>;
  }

  Future<List<dynamic>> getNewestCampaigns() async {
    final res = await _dio.get('/campaign/newest');
    return (res.data as Map<String, dynamic>)['campaigns'] as List<dynamic>;
  }

  // ── Wallet ───────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getWacStatus() async {
    final res = await _dio.get('/wac/status');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getWalletHistory({int page = 1, int limit = 20, String? type}) async {
    final params = <String, dynamic>{'page': page, 'limit': limit};
    if (type != null) params['type'] = type;
    final res = await _dio.get('/api/profile/wallet/history', queryParameters: params);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> transferWac(String toWalletId, String amount) async {
    final res = await _dio.post('/wac/transfer', data: {
      'toWalletId': toWalletId,
      'amount': amount,
    });
    return res.data as Map<String, dynamic>;
  }

  // ── User Location ──────────────────────────────────────────────────────

  Future<void> updateLocation({
    required bool locationEnabled,
    double? locationLat,
    double? locationLng,
    double? locationOffsetMeters,
  }) async {
    final body = <String, dynamic>{'locationEnabled': locationEnabled};
    if (locationLat != null) body['locationLat'] = locationLat;
    if (locationLng != null) body['locationLng'] = locationLng;
    if (locationOffsetMeters != null) body['locationOffsetMeters'] = locationOffsetMeters;
    await _dio.post('/icons/location', data: body);
  }

  Future<List<dynamic>> getUserLocations() async {
    final res = await _dio.get('/icons/locations');
    return (res.data as Map<String, dynamic>)['locations'] as List<dynamic>;
  }

}

final apiService = ApiService();
