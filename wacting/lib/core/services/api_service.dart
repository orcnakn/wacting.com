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

  Future<Map<String, dynamic>> emailLogin(String email, String password) async {
    final res = await _dio.post('/auth/email/login', data: {
      'email': email,
      'password': password,
    });
    final data = res.data as Map<String, dynamic>;
    setAuth(data['token'], data['userId']);
    return data;
  }

  Future<Map<String, dynamic>> emailRegister(String email, String password, {String? username}) async {
    final res = await _dio.post('/auth/email/register', data: {
      'email': email,
      'password': password,
      if (username != null) 'username': username,
    });
    final data = res.data as Map<String, dynamic>;
    setAuth(data['token'], data['userId']);
    return data;
  }

  // ── Campaigns ───────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> createCampaign({
    required String title,
    required String slogan,
    String? description,
    String? videoUrl,
    required String iconColor,
    required int iconShape,
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
      if (instagramUrl != null && instagramUrl.isNotEmpty) 'instagramUrl': instagramUrl,
      if (twitterUrl != null && twitterUrl.isNotEmpty) 'twitterUrl': twitterUrl,
      if (facebookUrl != null && facebookUrl.isNotEmpty) 'facebookUrl': facebookUrl,
      if (tiktokUrl != null && tiktokUrl.isNotEmpty) 'tiktokUrl': tiktokUrl,
      if (websiteUrl != null && websiteUrl.isNotEmpty) 'websiteUrl': websiteUrl,
    });
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
    required String title,
    String? description,
    required List<String> options,
    required int durationHours,
  }) async {
    final res = await _dio.post('/vote/create', data: {
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
}

final apiService = ApiService();
