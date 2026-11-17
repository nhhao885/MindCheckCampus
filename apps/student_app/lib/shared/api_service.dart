import 'dart:convert';
import 'package:dio/dio.dart';
import 'models.dart';

class ServerHealthStatus {
  final bool reachable;
  final int latencyMs;
  final String databaseStatus;
  final bool geminiConfiguredOnServer;
  final String geminiModel;
  final String message;

  const ServerHealthStatus({
    required this.reachable,
    required this.latencyMs,
    this.databaseStatus = 'unknown',
    this.geminiConfiguredOnServer = false,
    this.geminiModel = 'gemini-3-flash-preview',
    required this.message,
  });
}

class MindCheckApiService {
  late Dio _dio;
  String _currentBaseUrl = 'http://127.0.0.1:8000/v1';

  MindCheckApiService() {
    _initDio(_currentBaseUrl);
  }

  void _initDio(String baseUrl) {
    final normalized = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    _currentBaseUrl =
        normalized.isEmpty ? 'http://127.0.0.1:8000/v1' : normalized;
    _dio = Dio(
      BaseOptions(
        baseUrl: _currentBaseUrl,
        connectTimeout: const Duration(milliseconds: 8000),
        receiveTimeout: const Duration(milliseconds: 15000),
        headers: {
          'Content-Type': 'application/json',
          'X-Client-Platform': 'Flutter-MindCheck-2.0',
        },
      ),
    );
  }

  void updateEndpoint(String newBaseUrl) {
    _initDio(newBaseUrl);
  }

  void _syncBaseUrl(BackendEnvironment env, String customContaboUrl) {
    final target = env == BackendEnvironment.contaboSingapore
        ? customContaboUrl.trim()
        : 'http://127.0.0.1:8000/v1';
    if (target.isNotEmpty && target != _currentBaseUrl) {
      updateEndpoint(target);
    }
  }

  static final RegExp _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final RegExp _phoneRe = RegExp(r'^\+?[0-9][0-9\s\-\.]{7,16}$');

  static bool isValidContactInfo(String raw) {
    final cleaned = raw.trim();
    if (cleaned.isEmpty || cleaned.length > 160) return false;
    return _emailRe.hasMatch(cleaned) || _phoneRe.hasMatch(cleaned);
  }

  static bool isValidEmail(String raw) {
    final cleaned = raw.trim();
    return cleaned.isNotEmpty && _emailRe.hasMatch(cleaned);
  }

  /// Hỗ trợ cả định dạng khóa Google AI Studio mới (AQ....) và định dạng cũ (AIza...)
  static bool isPlausibleGeminiApiKey(String raw) {
    final cleaned = raw.trim();
    if (cleaned.isEmpty || cleaned.contains(RegExp(r'\s'))) return false;
    return cleaned.startsWith('AQ.') ||
        cleaned.startsWith('AIza') ||
        cleaned.length >= 24;
  }

  static const List<String> defaultGeminiModels = [
    'gemini-3-flash-preview',
    'gemini-3.1-flash-lite',
  ];

  static const List<String> _highRiskWords = [
    'tự tử',
    'tự sát',
    'tự hại',
    'không muốn sống',
    'chẳng muốn sống',
    'không còn muốn sống',
    'chết đi',
    'muốn chết',
    'kết thúc cuộc đời',
    'bế tắc quá',
    'muốn biến mất',
    'làm đau bản thân',
    'cắt tay',
    'cắt cổ tay',
    'nhảy lầu',
    'uống thuốc quá liều',
  ];

  static const List<String> _highRiskUnaccented = [
    'khong muon song',
    'chang muon song',
    'khong con muon song',
    'ket thuc cuoc doi',
    'lam dau ban than',
    'muon bien mat',
    'muon tu tu',
    'dinh tu tu',
    'se tu tu',
    'muon tu sat',
    'y dinh tu tu',
    'tu hai ban than',
    'cat co tay',
    'nhay lau',
    'muon chet',
  ];

  static final List<RegExp> _forbiddenDiagnosticPatterns = [
    RegExp(r'chẩn đoán\s+(bạn|em)\s+(bị|mắc)', caseSensitive: false),
    RegExp(
      r'(bạn|em)\s+(đang\s+)?(bị|mắc\s+bệnh)\s+(trầm cảm|rối loạn lo âu|tâm thần)',
      caseSensitive: false,
    ),
    RegExp(
      r'điểm\s*(phq-?9|gad-?7|dass-?21)\s*của\s*(bạn|em)\s*là',
      caseSensitive: false,
    ),
    RegExp(r'kê\s+đơn\s+thuốc', caseSensitive: false),
  ];

  static String _stripVietnameseAccents(String input) {
    const map = {
      'à': 'a', 'á': 'a', 'ả': 'a', 'ã': 'a', 'ạ': 'a',
      'ă': 'a', 'ằ': 'a', 'ắ': 'a', 'ẳ': 'a', 'ẵ': 'a', 'ặ': 'a',
      'â': 'a', 'ầ': 'a', 'ấ': 'a', 'ẩ': 'a', 'ẫ': 'a', 'ậ': 'a',
      'đ': 'd',
      'è': 'e', 'é': 'e', 'ẻ': 'e', 'ẽ': 'e', 'ẹ': 'e',
      'ê': 'e', 'ề': 'e', 'ế': 'e', 'ể': 'e', 'ễ': 'e', 'ệ': 'e',
      'ì': 'i', 'í': 'i', 'ỉ': 'i', 'ĩ': 'i', 'ị': 'i',
      'ò': 'o', 'ó': 'o', 'ỏ': 'o', 'õ': 'o', 'ọ': 'o',
      'ô': 'o', 'ồ': 'o', 'ố': 'o', 'ổ': 'o', 'ỗ': 'o', 'ộ': 'o',
      'ơ': 'o', 'ờ': 'o', 'ớ': 'o', 'ở': 'o', 'ỡ': 'o', 'ợ': 'o',
      'ù': 'u', 'ú': 'u', 'ủ': 'u', 'ũ': 'u', 'ụ': 'u',
      'ư': 'u', 'ừ': 'u', 'ứ': 'u', 'ử': 'u', 'ữ': 'u', 'ự': 'u',
      'ỳ': 'y', 'ý': 'y', 'ỷ': 'y', 'ỹ': 'y', 'ỵ': 'y',
    };
    final sb = StringBuffer();
    for (final rune in input.toLowerCase().runes) {
      final ch = String.fromCharCode(rune);
      sb.write(map[ch] ?? ch);
    }
    return sb.toString();
  }

  static bool isHighRiskText(String text) {
    final lower = text.toLowerCase();
    if (_highRiskWords.any((w) => lower.contains(w))) return true;
    final unaccented = _stripVietnameseAccents(lower);
    return _highRiskUnaccented.any((w) => unaccented.contains(w));
  }

  /// R1: Hậu kiểm tuyệt đối không cho phép AI chẩn đoán bệnh lý hoặc tự suy diễn điểm thang đo
  static String enforceNonDiagnosticGuardrail(
    String replyText,
    String uPro,
    String aiPro,
  ) {
    final cleaned = replyText.trim();
    if (cleaned.isEmpty) {
      return '${aiPro.capitalizeFirst()} đang ở đây lắng nghe $uPro. '
          'Chúng mình cùng chia sẻ từng bước chậm rãi theo hướng tiếp cận CBT nhé.';
    }
    for (final pat in _forbiddenDiagnosticPatterns) {
      if (pat.hasMatch(cleaned)) {
        return '${aiPro.capitalizeFirst()} lắng nghe những khó khăn $uPro đang trải qua. '
            'Vì $aiPro là người bạn đồng hành định hướng CBT nên không thực hiện chẩn đoán bệnh lý hay tự suy diễn điểm thang đo; '
            '$uPro có thể tự nguyện thực hiện bài sàng lọc chuẩn hóa ở mục "Sàng lọc" hoặc đặt lịch trò chuyện cùng chuyên gia của trường nhé.';
      }
    }
    return cleaned;
  }

  Map<String, String> _buildUserHeaders({
    String? authToken,
    String? subjectId,
    Map<String, String>? extra,
  }) {
    final headers = <String, String>{};
    if (authToken != null && authToken.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer ${authToken.trim()}';
    }
    if (subjectId != null && subjectId.trim().isNotEmpty) {
      headers['X-Subject-Id'] = subjectId.trim();
    }
    if (extra != null) {
      headers.addAll(extra);
    }
    return headers;
  }

  /// Kiểm tra trạng thái sống của máy chủ Contabo VPS / FastAPI (/v1/health)
  Future<ServerHealthStatus> checkServerHealth({
    required BackendEnvironment env,
    required String customContaboUrl,
  }) async {
    if (env == BackendEnvironment.offlineSimulated) {
      return const ServerHealthStatus(
        reachable: false,
        latencyMs: 0,
        message: 'Đang bật chế độ Giả lập Ngoại tuyến (Offline).',
      );
    }
    _syncBaseUrl(env, customContaboUrl);
    final sw = Stopwatch()..start();
    try {
      final resp = await _dio.get(
        '/health',
        options: Options(
          sendTimeout: const Duration(milliseconds: 5000),
          receiveTimeout: const Duration(milliseconds: 6000),
        ),
      );
      sw.stop();
      if (resp.statusCode == 200 && resp.data is Map) {
        final data = Map<String, dynamic>.from(resp.data as Map);
        final geminiReady = data['gemini_configured_on_server'] == true;
        final geminiModel =
            data['gemini_model']?.toString() ?? 'gemini-3-flash-preview';
        final db = data['database']?.toString() ?? 'ok';
        return ServerHealthStatus(
          reachable: true,
          latencyMs: sw.elapsedMilliseconds,
          databaseStatus: db,
          geminiConfiguredOnServer: geminiReady,
          geminiModel: geminiModel,
          message:
              'Kết nối máy chủ thành công (${sw.elapsedMilliseconds}ms) • DB: $db • Gemini Server: ${geminiReady ? "Sẵn sàng ($geminiModel)" : "Chưa cấu hình"}',
        );
      }
      return ServerHealthStatus(
        reachable: false,
        latencyMs: sw.elapsedMilliseconds,
        message: 'Máy chủ phản hồi mã HTTP ${resp.statusCode}.',
      );
    } catch (_) {
      sw.stop();
      return ServerHealthStatus(
        reachable: false,
        latencyMs: sw.elapsedMilliseconds,
        message:
            'Chưa kết nối được tới $_currentBaseUrl/health (Ứng dụng sẽ tự động dùng CBT Engine dự phòng).',
      );
    }
  }

  Future<Map<String, dynamic>?> createGuestSessionOnServer({
    required BackendEnvironment env,
    required String customContaboUrl,
  }) async {
    if (env == BackendEnvironment.offlineSimulated) return null;
    _syncBaseUrl(env, customContaboUrl);
    try {
      final resp = await _dio.post(
        '/guest-sessions',
        data: {'privacy_accepted': true, 'consent_version': 'v1.0-2026'},
      );
      if (resp.statusCode == 200 && resp.data is Map) {
        return Map<String, dynamic>.from(resp.data as Map);
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> signupStudent({
    required String email,
    required String password,
    String fullName = '',
    String faculty = 'CNTT',
    String academicYear = 'Nam_2',
    required BackendEnvironment env,
    required String customContaboUrl,
  }) async {
    if (env == BackendEnvironment.offlineSimulated) return null;
    _syncBaseUrl(env, customContaboUrl);
    try {
      final resp = await _dio.post(
        '/auth/signup',
        data: {
          'email': email.trim(),
          'password': password,
          'full_name': fullName.trim(),
          'faculty': faculty,
          'academic_year': academicYear,
        },
      );
      if (resp.statusCode == 200 && resp.data is Map) {
        return Map<String, dynamic>.from(resp.data as Map);
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> loginStudent({
    required String email,
    required String password,
    required BackendEnvironment env,
    required String customContaboUrl,
  }) async {
    if (env == BackendEnvironment.offlineSimulated) return null;
    _syncBaseUrl(env, customContaboUrl);
    try {
      final resp = await _dio.post(
        '/auth/login',
        data: {'email': email.trim(), 'password': password},
      );
      if (resp.statusCode == 200 && resp.data is Map) {
        return Map<String, dynamic>.from(resp.data as Map);
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> loginStaff({
    required String staffId,
    required String password,
    required BackendEnvironment env,
    required String customContaboUrl,
  }) async {
    if (env == BackendEnvironment.offlineSimulated) return null;
    _syncBaseUrl(env, customContaboUrl);
    try {
      final resp = await _dio.post(
        '/auth/staff-login',
        data: {'staff_id': staffId.trim(), 'password': password},
      );
      if (resp.statusCode == 200 && resp.data is Map) {
        return Map<String, dynamic>.from(resp.data as Map);
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> linkGuestSessionOnServer({
    required String guestId,
    String? userId,
    required bool consentToLink,
    String? authToken,
    required BackendEnvironment env,
    required String customContaboUrl,
  }) async {
    if (env == BackendEnvironment.offlineSimulated || !consentToLink) {
      return null;
    }
    _syncBaseUrl(env, customContaboUrl);
    try {
      final resp = await _dio.post(
        '/guest-sessions/link',
        options: Options(headers: _buildUserHeaders(authToken: authToken)),
        data: {
          'guest_id': guestId,
          if (userId != null && userId.isNotEmpty) 'user_id': userId,
          'consent_to_link': consentToLink,
        },
      );
      if (resp.statusCode == 200 && resp.data is Map) {
        return Map<String, dynamic>.from(resp.data as Map);
      }
    } catch (_) {}
    return null;
  }

  Future<String?> createConsentOnServer({
    required String subjectId,
    required String purpose,
    required String decision,
    String? authToken,
    required BackendEnvironment env,
    required String customContaboUrl,
  }) async {
    if (env == BackendEnvironment.offlineSimulated) return null;
    _syncBaseUrl(env, customContaboUrl);
    try {
      final resp = await _dio.post(
        '/consents',
        options: Options(
          headers: _buildUserHeaders(
            authToken: authToken,
            subjectId: subjectId,
          ),
        ),
        data: {
          'subject_id': subjectId,
          'purpose': purpose,
          'decision': decision,
        },
      );
      if (resp.statusCode == 200 && resp.data is Map) {
        return (resp.data as Map)['consent_id']?.toString();
      }
    } catch (_) {}
    return null;
  }

  Future<bool> erasePersonalDataOnServer({
    required String subjectId,
    String? authToken,
    required BackendEnvironment env,
    required String customContaboUrl,
  }) async {
    if (env == BackendEnvironment.offlineSimulated) return false;
    _syncBaseUrl(env, customContaboUrl);
    try {
      final resp = await _dio.delete(
        '/me/data',
        options: Options(
          headers: _buildUserHeaders(
            authToken: authToken,
            subjectId: subjectId,
          ),
        ),
      );
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> submitScreeningFullFlowOnServer({
    required String subjectId,
    required String toolId,
    required List<int> answers,
    required bool completed,
    String faculty = 'CNTT',
    String academicYear = 'Nam_2',
    String? authToken,
    required BackendEnvironment env,
    required String customContaboUrl,
  }) async {
    if (env == BackendEnvironment.offlineSimulated) return null;
    _syncBaseUrl(env, customContaboUrl);
    try {
      final consentId = await createConsentOnServer(
        subjectId: subjectId,
        purpose: 'screening',
        decision: 'accepted',
        authToken: authToken,
        env: env,
        customContaboUrl: customContaboUrl,
      );
      if (consentId == null) return null;

      final headers = _buildUserHeaders(
        authToken: authToken,
        subjectId: subjectId,
      );
      final startResp = await _dio.post(
        '/screening-sessions',
        options: Options(headers: headers),
        data: {
          'tool_id': toolId,
          'consent_id': consentId,
          'subject_id': subjectId,
          'faculty': faculty,
          'academic_year': academicYear,
        },
      );
      if (startResp.statusCode != 200 || startResp.data is! Map) return null;
      final sessionId = (startResp.data as Map)['session_id']?.toString();
      if (sessionId == null || sessionId.isEmpty) return null;

      final putResp = await _dio.put(
        '/screening-sessions/$sessionId/answers',
        options: Options(headers: headers),
        data: {'answers': answers, 'completed': completed},
      );
      if (putResp.statusCode == 200 && putResp.data is Map) {
        return Map<String, dynamic>.from(putResp.data as Map);
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> createBookingOnServer({
    required String subjectId,
    required String idempotencyKey,
    required String unitName,
    required String counselorId,
    required String counselorName,
    required String slotTime,
    String consultationMode = 'Trực tiếp tại phòng P.102',
    required String contactInfo,
    required String studentNote,
    String? authToken,
    required BackendEnvironment env,
    required String customContaboUrl,
  }) async {
    if (env == BackendEnvironment.offlineSimulated) return null;
    _syncBaseUrl(env, customContaboUrl);
    try {
      final consentId = await createConsentOnServer(
        subjectId: subjectId,
        purpose: 'counseling_share',
        decision: 'accepted',
        authToken: authToken,
        env: env,
        customContaboUrl: customContaboUrl,
      );
      if (consentId == null) return null;

      final resp = await _dio.post(
        '/counseling-requests',
        options: Options(
          headers: _buildUserHeaders(
            authToken: authToken,
            subjectId: subjectId,
          ),
        ),
        data: {
          'idempotency_key': idempotencyKey,
          'unit_name': unitName,
          'counselor_id': counselorId,
          'counselor_name': counselorName,
          'slot_time': slotTime,
          'consultation_mode': consultationMode,
          'contact_info': contactInfo,
          'student_note': studentNote,
          'consent_id': consentId,
          'subject_id': subjectId,
        },
      );
      if (resp.statusCode == 200 && resp.data is Map) {
        return Map<String, dynamic>.from(resp.data as Map);
      }
    } catch (_) {}
    return null;
  }

  Future<bool> cancelStudentBookingOnServer({
    required String requestId,
    String? requesterToken,
    String? authToken,
    required BackendEnvironment env,
    required String customContaboUrl,
  }) async {
    if (env == BackendEnvironment.offlineSimulated) return false;
    _syncBaseUrl(env, customContaboUrl);
    try {
      final headers = <String, String>{};
      if (authToken != null && authToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $authToken';
      }
      if (requesterToken != null && requesterToken.isNotEmpty) {
        headers['X-Booking-Token'] = requesterToken;
      }
      final resp = await _dio.patch(
        '/counseling-requests/$requestId/cancel',
        options: Options(headers: headers),
      );
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<AnalyticsOverviewModel?> fetchAnalyticsOverview({
    String faculty = 'ALL',
    String academicYear = 'ALL',
    String period = 'ALL',
    String? staffToken,
    required BackendEnvironment env,
    required String customContaboUrl,
  }) async {
    if (env == BackendEnvironment.offlineSimulated) return null;
    _syncBaseUrl(env, customContaboUrl);
    try {
      final headers = <String, String>{
        if (staffToken != null && staffToken.isNotEmpty)
          'Authorization': 'Bearer $staffToken'
        else ...{
          'X-Staff-Role': 'ctsv',
          'X-Staff-Id': 'ctsv_01',
        },
      };
      final resp = await _dio.get(
        '/analytics/overview',
        queryParameters: {
          'faculty': faculty,
          'academic_year': academicYear,
          'period': period,
        },
        options: Options(headers: headers),
      );
      if (resp.statusCode == 200 && resp.data is Map) {
        return AnalyticsOverviewModel.fromJson(
          Map<String, dynamic>.from(resp.data as Map),
        );
      }
    } catch (_) {}
    return null;
  }

  Future<List<CounselorSlotModel>?> fetchCounselorSlots({
    String? counselorId,
    required BackendEnvironment env,
    required String customContaboUrl,
  }) async {
    if (env == BackendEnvironment.offlineSimulated) return null;
    _syncBaseUrl(env, customContaboUrl);
    try {
      final resp = await _dio.get(
        '/counselor-slots',
        queryParameters: {
          if (counselorId != null && counselorId.isNotEmpty)
            'counselor_id': counselorId,
        },
      );
      if (resp.statusCode == 200 && resp.data is Map) {
        final items = (resp.data as Map)['items'] as List<dynamic>? ?? const [];
        return items
            .whereType<Map>()
            .map((e) => CounselorSlotModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (_) {}
    return null;
  }

  Future<List<KnowledgeArticleModel>?> fetchKnowledgeArticles({
    required BackendEnvironment env,
    required String customContaboUrl,
  }) async {
    if (env == BackendEnvironment.offlineSimulated) return null;
    _syncBaseUrl(env, customContaboUrl);
    try {
      final resp = await _dio.get('/knowledge-articles');
      if (resp.statusCode == 200 && resp.data is Map) {
        final items = (resp.data as Map)['items'] as List<dynamic>? ?? const [];
        return items
            .whereType<Map>()
            .map((e) =>
                KnowledgeArticleModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (_) {}
    return null;
  }

  Future<List<SafetyHotlineModel>?> fetchSafetyHotlines({
    required BackendEnvironment env,
    required String customContaboUrl,
  }) async {
    if (env == BackendEnvironment.offlineSimulated) return null;
    _syncBaseUrl(env, customContaboUrl);
    try {
      final resp = await _dio.get('/safety-hotlines');
      if (resp.statusCode == 200 && resp.data is Map) {
        final items = (resp.data as Map)['items'] as List<dynamic>? ?? const [];
        return items
            .whereType<Map>()
            .map((e) => SafetyHotlineModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (_) {}
    return null;
  }

  Future<List<StaffAccountModel>?> fetchAdminStaffAccounts({
    String? adminToken,
    required BackendEnvironment env,
    required String customContaboUrl,
  }) async {
    if (env == BackendEnvironment.offlineSimulated) return null;
    _syncBaseUrl(env, customContaboUrl);
    try {
      final headers = <String, String>{
        if (adminToken != null && adminToken.isNotEmpty)
          'Authorization': 'Bearer $adminToken'
        else
          'X-Admin-Actor': 'admin_01',
      };
      final resp = await _dio.get(
        '/admin/staff-accounts',
        options: Options(headers: headers),
      );
      if (resp.statusCode == 200 && resp.data is Map) {
        final items = (resp.data as Map)['items'] as List<dynamic>? ?? const [];
        return items
            .whereType<Map>()
            .map((e) => StaffAccountModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (_) {}
    return null;
  }

  Future<List<CounselingBookingModel>?> fetchStaffAssignedBookings({
    required String counselorId,
    String? staffToken,
    required BackendEnvironment env,
    required String customContaboUrl,
  }) async {
    if (env == BackendEnvironment.offlineSimulated) return null;
    _syncBaseUrl(env, customContaboUrl);
    try {
      final headers = <String, String>{
        if (staffToken != null && staffToken.isNotEmpty)
          'Authorization': 'Bearer $staffToken'
        else
          'X-Staff-Id': counselorId,
      };
      final resp = await _dio.get(
        '/staff/counseling-requests',
        queryParameters: {'counselor_id': counselorId},
        options: Options(headers: headers),
      );
      if (resp.statusCode == 200 && resp.data is Map) {
        final items = (resp.data as Map)['items'] as List<dynamic>? ?? const [];
        return items
            .whereType<Map>()
            .map((e) =>
                CounselingBookingModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> fetchAdminPolicyAndAudits({
    String? adminToken,
    required BackendEnvironment env,
    required String customContaboUrl,
  }) async {
    if (env == BackendEnvironment.offlineSimulated) return null;
    _syncBaseUrl(env, customContaboUrl);
    try {
      final headers = <String, String>{
        if (adminToken != null && adminToken.isNotEmpty)
          'Authorization': 'Bearer $adminToken'
        else
          'X-Admin-Actor': 'admin_01',
      };
      final resp = await _dio.get(
        '/admin/analytics-policy',
        options: Options(headers: headers),
      );
      if (resp.statusCode == 200 && resp.data is Map) {
        return Map<String, dynamic>.from(resp.data as Map);
      }
    } catch (_) {}
    return null;
  }

  /// Hydration (Đợt 2): Tải dữ liệu cá nhân của Sinh viên từ máy chủ Contabo khi đăng nhập đa thiết bị
  Future<CompanionPreference?> fetchStudentCompanionPreference({
    required String subjectId,
    String? authToken,
    required BackendEnvironment env,
    required String customContaboUrl,
  }) async {
    if (env == BackendEnvironment.offlineSimulated) return null;
    _syncBaseUrl(env, customContaboUrl);
    try {
      final resp = await _dio.get(
        '/me/companion-preferences',
        options: Options(
          headers: _buildUserHeaders(
            authToken: authToken,
            subjectId: subjectId,
          ),
        ),
      );
      if (resp.statusCode == 200 && resp.data is Map) {
        return CompanionPreference.fromJson(
          Map<String, dynamic>.from(resp.data as Map),
        );
      }
    } catch (_) {}
    return null;
  }

  Future<NotificationPreference?> fetchStudentNotificationPreference({
    required String subjectId,
    String? authToken,
    required BackendEnvironment env,
    required String customContaboUrl,
  }) async {
    if (env == BackendEnvironment.offlineSimulated) return null;
    _syncBaseUrl(env, customContaboUrl);
    try {
      final resp = await _dio.get(
        '/me/notification-preferences',
        options: Options(
          headers: _buildUserHeaders(
            authToken: authToken,
            subjectId: subjectId,
          ),
        ),
      );
      if (resp.statusCode == 200 && resp.data is Map) {
        return NotificationPreference.fromJson(
          Map<String, dynamic>.from(resp.data as Map),
        );
      }
    } catch (_) {}
    return null;
  }

  Future<List<ApprovedMemory>?> fetchStudentMemories({
    required String subjectId,
    String? authToken,
    required BackendEnvironment env,
    required String customContaboUrl,
  }) async {
    if (env == BackendEnvironment.offlineSimulated) return null;
    _syncBaseUrl(env, customContaboUrl);
    try {
      final resp = await _dio.get(
        '/memories',
        options: Options(
          headers: _buildUserHeaders(
            authToken: authToken,
            subjectId: subjectId,
          ),
        ),
      );
      if (resp.statusCode == 200 && resp.data is Map) {
        final items = (resp.data as Map)['items'] as List<dynamic>? ?? const [];
        return items
            .whereType<Map>()
            .map((e) => ApprovedMemory.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (_) {}
    return null;
  }

  Future<List<MoodEntryModel>?> fetchStudentMoodEntries({
    required String subjectId,
    String? authToken,
    required BackendEnvironment env,
    required String customContaboUrl,
  }) async {
    if (env == BackendEnvironment.offlineSimulated) return null;
    _syncBaseUrl(env, customContaboUrl);
    try {
      final resp = await _dio.get(
        '/mood-entries',
        options: Options(
          headers: _buildUserHeaders(
            authToken: authToken,
            subjectId: subjectId,
          ),
        ),
      );
      if (resp.statusCode == 200 && resp.data is Map) {
        final items = (resp.data as Map)['items'] as List<dynamic>? ?? const [];
        return items
            .whereType<Map>()
            .map((e) => MoodEntryModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (_) {}
    return null;
  }

  Future<List<ScreeningResultModel>?> fetchStudentScreeningHistory({
    required String subjectId,
    String? authToken,
    required BackendEnvironment env,
    required String customContaboUrl,
  }) async {
    if (env == BackendEnvironment.offlineSimulated) return null;
    _syncBaseUrl(env, customContaboUrl);
    try {
      final resp = await _dio.get(
        '/screening-sessions',
        options: Options(
          headers: _buildUserHeaders(
            authToken: authToken,
            subjectId: subjectId,
          ),
        ),
      );
      if (resp.statusCode == 200 && resp.data is Map) {
        final items = (resp.data as Map)['items'] as List<dynamic>? ?? const [];
        return items
            .whereType<Map>()
            .map((e) =>
                ScreeningResultModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (_) {}
    return null;
  }

  Future<List<CounselingBookingModel>?> fetchStudentBookings({
    String? authToken,
    required BackendEnvironment env,
    required String customContaboUrl,
  }) async {
    if (env == BackendEnvironment.offlineSimulated) return null;
    _syncBaseUrl(env, customContaboUrl);
    try {
      final resp = await _dio.get(
        '/counseling-requests',
        options: Options(
          headers: _buildUserHeaders(authToken: authToken),
        ),
      );
      if (resp.statusCode == 200 && resp.data is Map) {
        final items = (resp.data as Map)['items'] as List<dynamic>? ?? const [];
        return items
            .whereType<Map>()
            .map((e) =>
                CounselingBookingModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>> sendChatMessage({
    required String chatId,
    required String clientMessageId,
    required String text,
    required CompanionPreference pref,
    required List<ApprovedMemory> memories,
    required BackendEnvironment env,
    required String customContaboUrl,
    String subjectId = 'sub_default',
    String? authToken,
    List<ChatMessageModel> recentMessages = const [],
    String geminiApiKey = '',
  }) async {
    if (env == BackendEnvironment.offlineSimulated) {
      throw Exception(
        'NETWORK_UNAVAILABLE: Mất kết nối mạng tới máy chủ.',
      );
    }

    final lower = text.toLowerCase();
    final uPro = pref.userPronoun;
    final aiPro = pref.aiPronoun;

    // 1. Kiểm duyệt an toàn tức thì (Safety Guardrail ưu tiên số 1 - R3)
    if (isHighRiskText(text)) {
      return {
        'reply':
            '${aiPro.capitalizeFirst()} nghe thấy $uPro đang trải qua khoảnh khắc cực kỳ khó khăn. '
            'Vì $aiPro chỉ là người bạn đồng hành AI và không thể thay thế sự hỗ trợ khẩn cấp của con người, '
            '$uPro hãy mở ngay màn hình Hỗ trợ an toàn & Khẩn cấp (Hotline 115 / 111) hoặc đặt lịch kết nối trực tiếp với chuyên gia tư vấn của trường bên dưới nhé.',
        'quick_replies': [
          'Mở Hỗ trợ an toàn & khẩn cấp',
          'Đặt lịch với Tư vấn viên trường',
        ],
        'suggested_action': 'open_safety_support',
        'memory_proposal': null,
        'provider_badge': 'Cơ chế an toàn 2 lớp • Safety Guardrail',
      };
    }

    _syncBaseUrl(env, customContaboUrl);

    final historyPayload = recentMessages
        .where((m) => m.state == 'delivered' && m.text.trim().isNotEmpty)
        .take(8)
        .map((m) => {'role': m.role, 'text': m.text})
        .toList();

    // 2. Ưu tiên gọi qua Backend FastAPI (Contabo VPS hoặc Localhost)
    try {
      final response = await _dio.post(
        '/chats/$chatId/messages',
        options: Options(
          receiveTimeout: const Duration(milliseconds: 20000),
          headers: _buildUserHeaders(
            authToken: authToken,
            subjectId: subjectId,
            extra: {
              if (geminiApiKey.trim().isNotEmpty)
                'X-Gemini-Key': geminiApiKey.trim(),
            },
          ),
        ),
        data: {
          'client_message_id': clientMessageId,
          'text': text,
          'subject_id': subjectId,
          'context_opt_in': true,
          'user_pronoun': pref.userPronoun,
          'ai_pronoun': pref.aiPronoun,
          'ai_nickname': pref.nickname,
          'ai_tone': pref.tone,
          'approved_memories': memories.map((m) => m.text).toList(),
          'conversation_history': historyPayload,
        },
      );
      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final serverMap = Map<String, dynamic>.from(response.data as Map);
        serverMap['reply'] = enforceNonDiagnosticGuardrail(
          serverMap['reply']?.toString() ?? '',
          uPro,
          aiPro,
        );
        return serverMap;
      }
    } catch (_) {
      // Nếu Backend FastAPI chưa bật, chuyển sang Gemini trực tiếp (nếu có key hợp lệ) hoặc CBT Engine cục bộ
    }

    // 3. Nếu người dùng điền Google Gemini API Key (gửi qua header x-goog-api-key, TUYỆT ĐỐI không gắn trên URL)
    final trimmedKey = geminiApiKey.trim();
    if (isPlausibleGeminiApiKey(trimmedKey)) {
      final directDio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );
      final sysPrompt =
          'Bạn là "${pref.nickname}", một Người bạn số (Digital Companion) định hướng CBT cho sinh viên Việt Nam. '
          'Gọi người dùng là "$uPro", xưng là "$aiPro", giọng văn ${pref.tone}. '
          'Trí nhớ đã được sinh viên duyệt: ${memories.map((e) => e.text).toList()}. '
          'Trả lời ngắn gọn 2-4 câu, ấm áp, thấu cảm, tuyệt đối KHÔNG chẩn đoán y khoa hay suy diễn điểm PHQ-9/GAD-7/DASS-21. '
          'Nếu người dùng nói về mệt mỏi, mất ngủ, áp lực thi cử kéo dài, đặt should_suggest_screening=true và trích xuất memory_candidate.';

      final contents = <Map<String, dynamic>>[
        ...historyPayload.map((h) => {
              'role': h['role'] == 'assistant' ? 'model' : 'user',
              'parts': [
                {'text': h['text']}
              ],
            }),
        {
          'role': 'user',
          'parts': [
            {'text': text}
          ],
        },
      ];

      for (final modelId in defaultGeminiModels) {
        try {
          final res = await directDio.post(
            'https://generativelanguage.googleapis.com/v1beta/models/$modelId:generateContent',
            options: Options(headers: {'x-goog-api-key': trimmedKey}),
            data: {
              'system_instruction': {
                'parts': [
                  {'text': sysPrompt}
                ]
              },
              'contents': contents,
              'generationConfig': {
                'temperature': 0.7,
                'responseMimeType': 'application/json',
                'responseSchema': {
                  'type': 'OBJECT',
                  'properties': {
                    'reply': {'type': 'STRING'},
                    'quick_replies': {
                      'type': 'ARRAY',
                      'items': {'type': 'STRING'}
                    },
                    'should_suggest_screening': {'type': 'BOOLEAN'},
                    'memory_candidate': {'type': 'STRING', 'nullable': true},
                  },
                  'required': [
                    'reply',
                    'quick_replies',
                    'should_suggest_screening'
                  ],
                },
              },
            },
          );

          if (res.statusCode == 200) {
            final rawJson =
                res.data['candidates'][0]['content']['parts'][0]['text'];
            final parsed = jsonDecode(rawJson) as Map<String, dynamic>;
            final memCand = parsed['memory_candidate']?.toString().trim();
            final safeReply = enforceNonDiagnosticGuardrail(
              parsed['reply']?.toString() ?? '',
              uPro,
              aiPro,
            );
            return {
              'reply': safeReply,
              'quick_replies':
                  List<String>.from(parsed['quick_replies'] ?? []),
              'suggested_action': parsed['should_suggest_screening'] == true
                  ? 'suggest_screening'
                  : null,
              'memory_proposal': (memCand != null && memCand.length > 5)
                  ? {
                      'proposal_id':
                          'prop_${DateTime.now().millisecondsSinceEpoch}',
                      'candidate_text': memCand,
                    }
                  : null,
              'provider_badge': 'Google Gemini ($modelId) • Live AI Companion',
            };
          }
        } on DioException catch (e) {
          final code = e.response?.statusCode;
          if (code == 400 || code == 401 || code == 403) {
            break;
          }
        } catch (_) {}
      }
    }

    // 4. Kịch bản Người bạn số CBT thông minh đa ý định (Offline / Local Fallback)
    final memReminder = memories.isNotEmpty
        ? '(${aiPro.capitalizeFirst()} vẫn nhớ điều $uPro từng cho phép lưu: "${memories.first.text}".) '
        : '';

    if (lower.contains('bài tập thở') ||
        lower.contains('hít thở') ||
        lower.contains('thư giãn') ||
        lower.contains('bài tập cbt') ||
        lower.contains('grounding')) {
      return {
        'reply':
            'Tuyệt lắm, $uPro cùng $aiPro (${pref.nickname}) thả lỏng hai vai và thử 1 nhịp thở hộp 4-4-4-4 ngay nhé: '
            'hít vào nhẹ bằng mũi 4 giây, giữ nhẹ 4 giây, thở ra chậm 4 giây và nghỉ 4 giây. '
            '${uPro.capitalizeFirst()} cũng có thể bấm sang mục "Cảm xúc" để bật đồng hồ nhịp thở 2 phút hoặc điền Form CBT 3 bước nha!',
        'quick_replies': [
          'Mình thấy dễ chịu hơn một chút rồi',
          'Mình đang lo thi cuối kỳ',
          'Cảm ơn bạn nhiều nhé',
        ],
        'suggested_action': null,
        'memory_proposal': null,
        'provider_badge': 'MindCheck Companion • Hướng dẫn CBT & Chánh niệm',
      };
    }

    if (lower.contains('ngủ') ||
        lower.contains('mệt') ||
        lower.contains('áp lực') ||
        lower.contains('thi') ||
        lower.contains('lo') ||
        lower.contains('deadline') ||
        lower.contains('đồ án')) {
      return {
        'reply':
            'Cảm ơn $uPro đã tin tưởng chia sẻ với $aiPro. $memReminder'
            'Khi lịch học và thi cử dồn dập, tâm trí rất dễ căng cứng khiến giấc ngủ chập chờn. '
            '${aiPro.capitalizeFirst()} có thể cùng $uPro chia nhỏ việc ôn bài theo chặng 25 phút, hoặc mời $uPro thực hiện bài sàng lọc tự nguyện 2 phút để lắng nghe cơ thể rõ hơn nhé?',
        'quick_replies': [
          'Hướng dẫn mình bài tập thở',
          'Có, khá thường xuyên',
          'Không, em ổn',
        ],
        'suggested_action': 'suggest_screening',
        'memory_proposal': {
          'proposal_id': 'prop_${DateTime.now().millisecondsSinceEpoch}',
          'candidate_text':
              'Đang gặp áp lực học tập/thi cử và cần cải thiện giấc ngủ.',
        },
        'provider_badge': 'MindCheck Companion • CBT Engine Việt hóa',
      };
    }

    if (lower.contains('cô đơn') ||
        lower.contains('nhớ nhà') ||
        lower.contains('bạn bè') ||
        lower.contains('gia đình') ||
        lower.contains('buồn')) {
      return {
        'reply':
            '${aiPro.capitalizeFirst()} ở đây lắng nghe $uPro nhé. $memReminder'
            'Những khoảng lặng hay cảm giác chênh vênh giữa giảng đường đông đúc là điều rất tự nhiên. '
            '${uPro.capitalizeFirst()} muốn kể thêm điều vừa làm $uPro chạnh lòng nhất không?',
        'quick_replies': [
          'Mình thấy hơi lạc lõng',
          'Mình nhớ gia đình ở quê',
          'Hướng dẫn mình bài tập thở',
        ],
        'suggested_action': null,
        'memory_proposal': {
          'proposal_id': 'prop_${DateTime.now().millisecondsSinceEpoch}',
          'candidate_text':
              'Đang cần sự sẻ chia về cảm xúc kết nối bạn bè/gia đình.',
        },
        'provider_badge': 'MindCheck Companion • CBT Engine Việt hóa',
      };
    }

    if (lower.contains('ổn') ||
        lower.contains('cảm ơn') ||
        lower.contains('dễ chịu') ||
        lower.contains('vui')) {
      return {
        'reply':
            'Nghe $uPro nói vậy $aiPro (${pref.nickname}) vui lắm! '
            'Duy trì được sự cân bằng nhỏ mỗi ngày đã là một thành công rất đáng trân trọng rồi. '
            'Khi nào $uPro muốn ghi lại nhật ký cảm xúc hay trò chuyện tiếp, $aiPro luôn sẵn sàng ở đây nha.',
        'quick_replies': [
          'Hướng dẫn mình bài tập thở',
          'Mình muốn thử bài tập CBT',
          'Hẹn gặp lại bạn nhé',
        ],
        'suggested_action': null,
        'memory_proposal': null,
        'provider_badge': 'MindCheck Companion • CBT Engine Việt hóa',
      };
    }

    return {
      'reply':
          '${aiPro.capitalizeFirst()} (${pref.nickname}) vẫn đang lắng nghe $uPro với sự ${pref.tone}. $memReminder'
          'Hôm nay $uPro muốn cùng $aiPro bóc tách suy nghĩ tự động theo phương pháp CBT hay thực hiện bài tập thở 2 phút?',
      'quick_replies': [
        'Dạ khá mệt, gần đây em ngủ không ngon giấc ạ.',
        'Mình đang lo thi cuối kỳ',
        'Hướng dẫn mình bài tập thở',
      ],
      'suggested_action': null,
      'memory_proposal': null,
      'provider_badge': 'MindCheck Companion • CBT Engine Việt hóa',
    };
  }

  /// Đồng bộ nền không chặn UI (Optimistic Background Sync) với máy chủ Contabo FastAPI
  Future<void> syncBackgroundPost(
    String path,
    Map<String, dynamic> data, {
    required BackendEnvironment env,
    required String customContaboUrl,
    Map<String, String>? headers,
  }) async {
    if (env == BackendEnvironment.offlineSimulated) return;
    _syncBaseUrl(env, customContaboUrl);
    try {
      await _dio.post(
        path,
        data: data,
        options: Options(headers: headers),
      );
    } catch (_) {}
  }

  Future<void> syncBackgroundPut(
    String path,
    Map<String, dynamic> data, {
    required BackendEnvironment env,
    required String customContaboUrl,
    Map<String, String>? headers,
  }) async {
    if (env == BackendEnvironment.offlineSimulated) return;
    _syncBaseUrl(env, customContaboUrl);
    try {
      await _dio.put(
        path,
        data: data,
        options: Options(headers: headers),
      );
    } catch (_) {}
  }

  Future<void> syncBackgroundPatch(
    String path,
    Map<String, dynamic> data, {
    required BackendEnvironment env,
    required String customContaboUrl,
    Map<String, String>? headers,
  }) async {
    if (env == BackendEnvironment.offlineSimulated) return;
    _syncBaseUrl(env, customContaboUrl);
    try {
      await _dio.patch(
        path,
        data: data,
        options: Options(headers: headers),
      );
    } catch (_) {}
  }

  Future<void> syncBackgroundDelete(
    String path, {
    required BackendEnvironment env,
    required String customContaboUrl,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
  }) async {
    if (env == BackendEnvironment.offlineSimulated) return;
    _syncBaseUrl(env, customContaboUrl);
    try {
      await _dio.delete(
        path,
        queryParameters: queryParameters,
        options: Options(headers: headers),
      );
    } catch (_) {}
  }
}

extension _CapFirst on String {
  String capitalizeFirst() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
