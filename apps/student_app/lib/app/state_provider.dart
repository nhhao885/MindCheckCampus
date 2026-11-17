import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../shared/api_service.dart';
import '../shared/local_preferences.dart';
import '../shared/models.dart';

const bool kSeedDemoMode =
    bool.fromEnvironment('MINDCHECK_SEED_DEMO', defaultValue: false);
const bool kProductionMode =
    bool.fromEnvironment('MINDCHECK_PRODUCTION', defaultValue: false);
const String kDefaultApiUrl = String.fromEnvironment(
  'MINDCHECK_API_URL',
  defaultValue: 'http://127.0.0.1:8000/v1',
);

class MindCheckAppState {
  final String? guestId;
  final String? subjectId;
  final String? userId;
  final String? userEmail;
  final String? authToken;
  final String userFaculty;
  final String userAcademicYear;
  final bool isLinkedAccount;
  final bool hasAcceptedPrivacy;
  final CompanionPreference companionPref;
  final NotificationPreference notificationPref;
  final BackendEnvironment backendEnv;
  final String contaboBaseUrl;
  final String geminiApiKey;
  final bool isAiTyping;
  final List<ConsentRecord> consents;
  final List<ChatSessionModel> chatSessions;
  final String activeChatSessionId;
  final List<ChatMessageModel> messages;
  final List<ApprovedMemory> memories;
  final List<MoodEntryModel> moodEntries;
  final List<DailyActivityModel> dailyActivities;
  final List<String> activityPracticeLogs;
  final List<ScreeningToolModel> screeningTools;
  final List<ScreeningResultModel> screeningHistory;
  final List<CounselingBookingModel> bookings;
  final List<KnowledgeArticleModel> articles;
  final List<String> dataRequests;
  final bool suppressScreeningSuggestion;
  final int minGroupSizePolicy;
  final List<AuditEventModel> auditLogs;
  final String? preferredCounselorId;
  final String? preferredBookingNote;
  final AnalyticsOverviewModel? serverAnalytics;
  final Map<String, String> staffTokens;
  final List<CounselorSlotModel> counselorSlots;
  final List<StaffAccountModel> staffDirectory;
  final List<SafetyHotlineModel> safetyHotlines;
  final String? authenticatedStaffId;
  final ActorRole? authenticatedStaffRole;
  final bool isStaffDemoSwitchEnabled;

  MindCheckAppState({
    this.guestId,
    this.subjectId,
    this.userId,
    this.userEmail,
    this.authToken,
    this.userFaculty = 'CNTT',
    this.userAcademicYear = 'Nam_2',
    this.isLinkedAccount = false,
    this.hasAcceptedPrivacy = false,
    this.companionPref = const CompanionPreference(),
    this.notificationPref = const NotificationPreference(),
    this.backendEnv = BackendEnvironment.contaboSingapore,
    this.contaboBaseUrl = kDefaultApiUrl,
    this.geminiApiKey =
        const String.fromEnvironment('GEMINI_API_KEY', defaultValue: ''),
    this.isAiTyping = false,
    required this.consents,
    required this.chatSessions,
    required this.activeChatSessionId,
    required this.messages,
    required this.memories,
    required this.moodEntries,
    required this.dailyActivities,
    this.activityPracticeLogs = const [],
    required this.screeningTools,
    required this.screeningHistory,
    required this.bookings,
    required this.articles,
    required this.dataRequests,
    this.suppressScreeningSuggestion = false,
    this.minGroupSizePolicy = 10,
    required this.auditLogs,
    this.preferredCounselorId,
    this.preferredBookingNote,
    this.serverAnalytics,
    this.staffTokens = const {},
    this.counselorSlots = const [],
    this.staffDirectory = const [],
    this.safetyHotlines = const [],
    this.authenticatedStaffId,
    this.authenticatedStaffRole,
    this.isStaffDemoSwitchEnabled = !kProductionMode,
  });

  bool get simulateOfflineMode =>
      backendEnv == BackendEnvironment.offlineSimulated;

  MindCheckAppState copyWith({
    String? guestId,
    String? subjectId,
    String? userId,
    String? userEmail,
    String? authToken,
    bool clearAuth = false,
    String? userFaculty,
    String? userAcademicYear,
    bool? isLinkedAccount,
    bool? hasAcceptedPrivacy,
    CompanionPreference? companionPref,
    NotificationPreference? notificationPref,
    BackendEnvironment? backendEnv,
    String? contaboBaseUrl,
    String? geminiApiKey,
    bool? isAiTyping,
    List<ConsentRecord>? consents,
    List<ChatSessionModel>? chatSessions,
    String? activeChatSessionId,
    List<ChatMessageModel>? messages,
    List<ApprovedMemory>? memories,
    List<MoodEntryModel>? moodEntries,
    List<DailyActivityModel>? dailyActivities,
    List<String>? activityPracticeLogs,
    List<ScreeningToolModel>? screeningTools,
    List<ScreeningResultModel>? screeningHistory,
    List<CounselingBookingModel>? bookings,
    List<KnowledgeArticleModel>? articles,
    List<String>? dataRequests,
    bool? suppressScreeningSuggestion,
    int? minGroupSizePolicy,
    List<AuditEventModel>? auditLogs,
    String? preferredCounselorId,
    String? preferredBookingNote,
    AnalyticsOverviewModel? serverAnalytics,
    bool clearServerAnalytics = false,
    Map<String, String>? staffTokens,
    List<CounselorSlotModel>? counselorSlots,
    List<StaffAccountModel>? staffDirectory,
    List<SafetyHotlineModel>? safetyHotlines,
    String? authenticatedStaffId,
    ActorRole? authenticatedStaffRole,
    bool clearStaffSession = false,
    bool? isStaffDemoSwitchEnabled,
  }) {
    return MindCheckAppState(
      guestId: guestId ?? this.guestId,
      subjectId: subjectId ?? this.subjectId,
      userId: clearAuth ? null : (userId ?? this.userId),
      userEmail: clearAuth ? null : (userEmail ?? this.userEmail),
      authToken: clearAuth ? null : (authToken ?? this.authToken),
      userFaculty: userFaculty ?? this.userFaculty,
      userAcademicYear: userAcademicYear ?? this.userAcademicYear,
      isLinkedAccount: isLinkedAccount ?? this.isLinkedAccount,
      hasAcceptedPrivacy: hasAcceptedPrivacy ?? this.hasAcceptedPrivacy,
      companionPref: companionPref ?? this.companionPref,
      notificationPref: notificationPref ?? this.notificationPref,
      backendEnv: backendEnv ?? this.backendEnv,
      contaboBaseUrl: contaboBaseUrl ?? this.contaboBaseUrl,
      geminiApiKey: geminiApiKey ?? this.geminiApiKey,
      isAiTyping: isAiTyping ?? this.isAiTyping,
      consents: consents ?? this.consents,
      chatSessions: chatSessions ?? this.chatSessions,
      activeChatSessionId: activeChatSessionId ?? this.activeChatSessionId,
      messages: messages ?? this.messages,
      memories: memories ?? this.memories,
      moodEntries: moodEntries ?? this.moodEntries,
      dailyActivities: dailyActivities ?? this.dailyActivities,
      activityPracticeLogs: activityPracticeLogs ?? this.activityPracticeLogs,
      screeningTools: screeningTools ?? this.screeningTools,
      screeningHistory: screeningHistory ?? this.screeningHistory,
      bookings: bookings ?? this.bookings,
      articles: articles ?? this.articles,
      dataRequests: dataRequests ?? this.dataRequests,
      suppressScreeningSuggestion:
          suppressScreeningSuggestion ?? this.suppressScreeningSuggestion,
      minGroupSizePolicy: minGroupSizePolicy ?? this.minGroupSizePolicy,
      auditLogs: auditLogs ?? this.auditLogs,
      preferredCounselorId: preferredCounselorId ?? this.preferredCounselorId,
      preferredBookingNote: preferredBookingNote ?? this.preferredBookingNote,
      serverAnalytics:
          clearServerAnalytics ? null : (serverAnalytics ?? this.serverAnalytics),
      staffTokens: staffTokens ?? this.staffTokens,
      counselorSlots: counselorSlots ?? this.counselorSlots,
      staffDirectory: staffDirectory ?? this.staffDirectory,
      safetyHotlines: safetyHotlines ?? this.safetyHotlines,
      authenticatedStaffId: clearStaffSession
          ? null
          : (authenticatedStaffId ?? this.authenticatedStaffId),
      authenticatedStaffRole: clearStaffSession
          ? null
          : (authenticatedStaffRole ?? this.authenticatedStaffRole),
      isStaffDemoSwitchEnabled:
          isStaffDemoSwitchEnabled ?? this.isStaffDemoSwitchEnabled,
    );
  }
}

class MindCheckNotifier extends StateNotifier<MindCheckAppState> {
  MindCheckNotifier() : super(_initialState()) {
    _restorePersistedState();
  }

  final _uuid = const Uuid();
  final _api = MindCheckApiService();
  final Set<String> _processedClientMsgIds = {};

  static const String _kGuestId = 'mc_guest_id';
  static const String _kSubjectId = 'mc_subject_id';
  static const String _kUserId = 'mc_user_id';
  static const String _kUserEmail = 'mc_user_email';
  static const String _kAuthToken = 'mc_auth_token';
  static const String _kUserFaculty = 'mc_user_faculty';
  static const String _kUserAcademicYear = 'mc_user_academic_year';
  static const String _kIsLinked = 'mc_is_linked';
  static const String _kAcceptedPrivacy = 'mc_has_accepted_privacy';
  static const String _kCompanionPref = 'mc_companion_pref';
  static const String _kNotificationPref = 'mc_notification_pref';
  static const String _kGeminiApiKey = 'mc_gemini_api_key';
  static const String _kContaboBaseUrl = 'mc_contabo_base_url';
  static const String _kMemories = 'mc_memories';
  static const String _kMoodEntries = 'mc_mood_entries';
  static const String _kScreeningHistory = 'mc_screening_history';
  static const String _kBookings = 'mc_bookings';
  static const String _kPracticeLogs = 'mc_practice_logs';
  static const String _kChatSessions = 'mc_chat_sessions';
  static const String _kChatMessages = 'mc_chat_messages';
  static const String _kConsents = 'mc_consents';

  static MindCheckAppState _initialState() {
    const defaultSessionId = 'chat_session_01';
    return MindCheckAppState(
      consents: [],
      chatSessions: [
        ChatSessionModel(
          sessionId: defaultSessionId,
          title: 'Cuộc trò chuyện đồng hành #1',
          startedAt: DateTime.now(),
        ),
      ],
      activeChatSessionId: defaultSessionId,
      messages: [
        ChatMessageModel(
          messageId: 'msg_welcome',
          sessionId: defaultSessionId,
          role: 'assistant',
          text:
              'Chào bạn! Dạo này việc học có khiến bạn thấy mệt mỏi hay áp lực không?',
          quickReplies: const [
            'Dạ khá mệt, gần đây em ngủ không ngon giấc ạ.',
            'Mình đang lo thi cuối kỳ',
            'Không, em ổn',
          ],
          createdAt: DateTime.now(),
        ),
      ],
      memories: [],
      moodEntries: [],
      dailyActivities: [
        DailyActivityModel(
          activityId: 'act_01',
          title: 'Hít thở hộp 4-4-4-4 điều hòa căng thẳng',
          category: 'Thử thách 2 phút',
          duration: '2 phút',
          steps: const [
            'Hít vào nhẹ nhàng bằng mũi trong 4 giây.',
            'Giữ hơi thở nhẹ nhàng trong 4 giây.',
            'Thở ra từ từ bằng miệng trong 4 giây và nghỉ 4 giây.',
          ],
        ),
        DailyActivityModel(
          activityId: 'act_02',
          title: 'Nhận diện & Tái cấu trúc suy nghĩ tự động (CBT)',
          category: 'Bài tập CBT tự hỗ trợ',
          duration: '5 phút',
          steps: const [
            'Ghi lại tình huống thực tế đang gây áp lực (VD: Sắp thi cuối kỳ).',
            'Nhận diện suy nghĩ tự động tiêu cực vừa xuất hiện.',
            'Viết lại góc nhìn cân bằng, thực tế và chia nhỏ hành động.',
          ],
        ),
        DailyActivityModel(
          activityId: 'act_03',
          title: 'Grounding 5-4-3-2-1 kết nối thực tại',
          category: 'Chánh niệm & Thư giãn',
          duration: '3 phút',
          steps: const [
            'Nhận biết 5 đồ vật nhìn thấy và 4 bề mặt bạn chạm vào được.',
            'Lắng nghe 3 âm thanh, 2 mùi hương và 1 điều bạn biết ơn hôm nay.',
          ],
        ),
      ],
      screeningTools: const [
        ScreeningToolModel(
          toolId: 'GAD-7',
          name: 'Thang đo GAD-7 (Đánh giá mức độ Lo âu)',
          subtitle:
              '7 câu hỏi chuẩn quốc tế đánh giá triệu chứng trong 2 tuần qua',
          description:
              'Spitzer et al. (2006) — Chấm điểm bằng Rule-based Engine, giúp bạn tự nhận diện mức độ lo âu.',
          questions: [
            '1. Cảm thấy lo lắng, bồn chồn hoặc căng thẳng?',
            '2. Không thể ngừng hoặc kiểm soát việc lo lắng?',
            '3. Lo lắng quá nhiều về những điều khác nhau?',
            '4. Khó thư giãn?',
            '5. Bồn chồn đến mức khó ngồi yên?',
            '6. Dễ bực bội hoặc cáu gắt?',
            '7. Cảm thấy sợ hãi như thể điều gì đó tồi tệ sắp xảy ra?',
          ],
        ),
        ScreeningToolModel(
          toolId: 'PHQ-9',
          name: 'Thang đo PHQ-9 (Đánh giá mức độ Trầm cảm)',
          subtitle: '9 câu hỏi chuẩn hóa sàng lọc triệu chứng trầm cảm',
          description:
              'Kroenke et al. (2001) — Sàng lọc tự nguyện có xin phép, không thay thế chẩn đoán y khoa.',
          questions: [
            '1. Ít hứng thú hoặc ít niềm vui khi làm mọi việc?',
            '2. Cảm thấy buồn bã, chán nản hoặc tuyệt vọng?',
            '3. Khó vào giấc ngủ, ngủ không sâu giấc hoặc ngủ quá nhiều?',
            '4. Cảm thấy mệt mỏi hoặc có ít năng lượng?',
            '5. Chán ăn hoặc ăn quá nhiều?',
            '6. Cảm thấy tồi tệ về bản thân?',
            '7. Khó tập trung vào việc đọc sách hoặc học tập?',
            '8. Di chuyển hoặc nói năng chậm chạp, hoặc bồn chồn bất thường?',
            '9. Có suy nghĩ tiêu cực về sự an toàn của bản thân?',
          ],
        ),
        ScreeningToolModel(
          toolId: 'DASS-21',
          name: 'Thang đo DASS-21 (Trầm cảm - Lo âu - Căng thẳng)',
          subtitle: '21 câu hỏi chuẩn đánh giá đa chiều áp lực tâm lý học đường',
          description:
              'Lovibond & Lovibond (1995) — Phiên bản chuẩn 21 mục đánh giá Căng thẳng, Lo âu và Trầm cảm.',
          scaleLabels: [
            'Không đúng chút nào (0)',
            'Đúng phần nào / thỉnh thoảng (1)',
            'Đúng phần nhiều / thường xuyên (2)',
            'Hoàn toàn đúng / rất thường xuyên (3)',
          ],
          questions: [
            '1. Tôi thấy khó thoải mái, thư giãn.',
            '2. Tôi nhận thấy mình bị khô miệng.',
            '3. Tôi dường như không có chút cảm xúc tích cực nào.',
            '4. Tôi cảm thấy khó thở (thở gấp, hụt hơi dù không gắng sức).',
            '5. Tôi thấy khó bắt tay vào làm việc hoặc ôn bài.',
            '6. Tôi có xu hướng phản ứng thái quá trước các tình huống.',
            '7. Tôi cảm thấy run (ví dụ ở tay).',
            '8. Tôi cảm thấy mình đang tiêu tốn rất nhiều năng lượng thần kinh.',
            '9. Tôi lo lắng về những tình huống có thể khiến mình hoảng sợ.',
            '10. Tôi cảm thấy mình chẳng có gì đáng mong đợi ở tương lai.',
            '11. Tôi thấy bản thân dễ bị kích động, bứt rứt.',
            '12. Tôi thấy khó thư giãn đầu óc.',
            '13. Tôi cảm thấy chán nản và buồn rầu.',
            '14. Tôi không kiên nhẫn với bất kỳ điều gì cản trở việc đang làm.',
            '15. Tôi cảm thấy mình gần như hoảng loạn.',
            '16. Tôi không thể hào hứng với bất kỳ việc gì.',
            '17. Tôi cảm thấy mình không có nhiều giá trị.',
            '18. Tôi thấy mình khá nhạy cảm, dễ tự ái.',
            '19. Tôi nhận thức rõ nhịp tim của mình dù không vận động mạnh.',
            '20. Tôi cảm thấy sợ vô cớ.',
            '21. Tôi cảm thấy cuộc sống thiếu ý nghĩa.',
          ],
        ),
      ],
      screeningHistory: [],
      bookings: [
        if (kSeedDemoMode)
          CounselingBookingModel(
            requestId: 'req_demo_001',
            unitName: 'Phòng Tư vấn Tâm lý Sinh viên',
            counselorId: 'counselor_01',
            counselorName: 'ThS. Tâm lý Nguyễn Văn A',
            slotTime: 'Thứ 4 (09:00 - 10:00)',
            contactInfo: 'sv_demo@student.ctuet.edu.vn',
            studentNote: 'Em muốn xin tư vấn cách giảm áp lực trước kỳ thi.',
            consentId: 'con_init_booking',
            status: 'pending',
            createdAt: DateTime.now().subtract(const Duration(hours: 2)),
          ),
      ],
      articles: const [
        KnowledgeArticleModel(
          id: 'art_01',
          title: 'Kỹ thuật chia nhỏ mục tiêu ôn thi theo liệu pháp CBT',
          category: 'Học tập & Thi cử',
          summary:
              'Cách vượt qua sự trì hoãn và cảm giác quá tải trước mùa thi học kỳ.',
          content:
              'Khi đối diện với khối lượng môn học lớn, não bộ thường sinh ra suy nghĩ tự động "Mình không thể làm kịp". Kỹ thuật CBT giúp bạn tách cảm xúc lo âu khỏi hành động thực tế bằng cách chia bài ôn thành các phiên 25 phút (Pomodoro) và ghi nhận từng bước hoàn thành nhỏ.',
          verifiedSource:
              'Tài liệu Giáo dục Tâm lý Học đường đã kiểm duyệt',
        ),
        KnowledgeArticleModel(
          id: 'art_02',
          title: 'Vệ sinh giấc ngủ dành cho sinh viên mùa đồ án',
          category: 'Chăm sóc giấc ngủ',
          summary:
              'Thiết lập nhịp sinh học và thư giãn cơ bắp trước khi ngủ 30 phút.',
          content:
              'Tránh sử dụng màn hình xanh 30 phút trước khi ngủ, kết hợp bài tập thở 4-4-4-4 và viết ra giấy những việc cần làm vào sáng mai để não bộ không phải ghi nhớ trong lúc ngủ.',
          verifiedSource: 'Cẩm nang Sức khỏe Tinh thần Sinh viên',
        ),
        KnowledgeArticleModel(
          id: 'art_03',
          title: 'Nhận diện dấu hiệu kiệt sức học đường và tìm kiếm hỗ trợ',
          category: 'An toàn & Tự chăm sóc',
          summary:
              'Khi nào bạn nên chủ động kết nối chuyên gia tư vấn tâm lý của trường.',
          content:
              'Cảm giác mệt mỏi kéo dài trên 2 tuần, mất hứng thú học tập hoặc rối loạn giấc ngủ là tín hiệu cơ thể cần được lắng nghe. Hãy sử dụng tính năng Đặt lịch Tư vấn Tâm lý (S23) hoặc gọi 115 / 111 nếu cảm thấy mất an toàn.',
          verifiedSource: 'Phòng Tư vấn Tâm lý & Công tác Sinh viên',
        ),
      ],
      counselorSlots: const [
        CounselorSlotModel(
          slotId: 'slot_c1_01',
          counselorId: 'counselor_01',
          counselorName: 'ThS. Tâm lý Nguyễn Văn A',
          unitName: 'Phòng Tư vấn Tâm lý Sinh viên',
          slotLabel: 'Thứ 4 (09:00 - 10:00)',
          consultationMode: 'Trực tiếp tại phòng P.102',
          isAvailable: true,
        ),
        CounselorSlotModel(
          slotId: 'slot_c1_02',
          counselorId: 'counselor_01',
          counselorName: 'ThS. Tâm lý Nguyễn Văn A',
          unitName: 'Phòng Tư vấn Tâm lý Sinh viên',
          slotLabel: 'Thứ 5 (14:00 - 15:00)',
          consultationMode: 'Trực tiếp tại phòng P.102',
          isAvailable: true,
        ),
        CounselorSlotModel(
          slotId: 'slot_c1_03',
          counselorId: 'counselor_01',
          counselorName: 'ThS. Tâm lý Nguyễn Văn A',
          unitName: 'Phòng Tư vấn Tâm lý Sinh viên',
          slotLabel: 'Thứ 6 (15:30 - 16:30)',
          consultationMode: 'Trực tuyến (Google Meet)',
          isAvailable: true,
        ),
        CounselorSlotModel(
          slotId: 'slot_c2_01',
          counselorId: 'counselor_02',
          counselorName: 'ThS. Tâm lý Trần Thị B',
          unitName: 'Tổ Tư vấn Học đường',
          slotLabel: 'Thứ 4 (14:00 - 15:00)',
          consultationMode: 'Trực tiếp tại phòng P.204',
          isAvailable: true,
        ),
        CounselorSlotModel(
          slotId: 'slot_c2_02',
          counselorId: 'counselor_02',
          counselorName: 'ThS. Tâm lý Trần Thị B',
          unitName: 'Tổ Tư vấn Học đường',
          slotLabel: 'Thứ 6 (09:00 - 10:00)',
          consultationMode: 'Trực tuyến (Google Meet)',
          isAvailable: true,
        ),
      ],
      staffDirectory: const [
        StaffAccountModel(
          staffId: 'ctsv_01',
          role: 'ctsv',
          displayName: 'Chuyên viên Phòng CTSV',
          unitName: 'Phòng Công tác Sinh viên',
          isActive: true,
        ),
        StaffAccountModel(
          staffId: 'counselor_01',
          role: 'counselor',
          displayName: 'ThS. Tâm lý Nguyễn Văn A (Phòng Tư vấn Sinh viên)',
          unitName: 'Phòng Tư vấn Tâm lý Sinh viên',
          isActive: true,
        ),
        StaffAccountModel(
          staffId: 'counselor_02',
          role: 'counselor',
          displayName: 'ThS. Tâm lý Trần Thị B (Tổ Tư vấn Học đường)',
          unitName: 'Tổ Tư vấn Học đường',
          isActive: true,
        ),
        StaffAccountModel(
          staffId: 'admin_01',
          role: 'admin',
          displayName: 'Quản trị viên Hệ thống',
          unitName: 'Trung tâm Quản trị & An toàn Thông tin',
          isActive: true,
        ),
      ],
      safetyHotlines: const [
        SafetyHotlineModel(
          hotlineId: 'hotline_115',
          name: 'Cấp cứu Y tế Toàn quốc',
          phone: '115',
          description:
              'Hỗ trợ y tế và khủng hoảng sức khỏe khẩn cấp trên toàn quốc.',
          hours: '24/7',
          isVerified: true,
        ),
        SafetyHotlineModel(
          hotlineId: 'hotline_111',
          name: 'Tổng đài Quốc gia Bảo vệ & Hỗ trợ Khẩn cấp',
          phone: '111',
          description:
              'Đường dây nóng miễn phí tiếp nhận hỗ trợ tâm lý và bảo vệ khẩn cấp.',
          hours: '24/7',
          isVerified: true,
        ),
        SafetyHotlineModel(
          hotlineId: 'hotline_campus_01',
          name: 'Trực ban Phòng Tư vấn Tâm lý & CTSV Nhà trường',
          phone: '0292-389-0115',
          description:
              'Hỗ trợ trực tiếp sinh viên trong khuôn viên trường và ký túc xá.',
          hours: '07:30 - 21:00 (Thứ 2 - Thứ 7)',
          isVerified: true,
        ),
      ],
      dataRequests: [],
      auditLogs: [],
    );
  }

  Future<void> _restorePersistedState() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final savedGuestId = prefs.getString(_kGuestId);
    final savedSubjectId = prefs.getString(_kSubjectId);
    final savedUserId = prefs.getString(_kUserId);
    final savedUserEmail = prefs.getString(_kUserEmail);
    final savedAuthToken = prefs.getString(_kAuthToken);
    final savedFaculty = prefs.getString(_kUserFaculty);
    final savedAcademicYear = prefs.getString(_kUserAcademicYear);
    final savedIsLinked = prefs.getBool(_kIsLinked);
    final savedPrivacy = prefs.getBool(_kAcceptedPrivacy);
    final savedCompMap = prefs.getJsonMap(_kCompanionPref);
    final savedNotifMap = prefs.getJsonMap(_kNotificationPref);
    final savedApiKey = prefs.getString(_kGeminiApiKey);
    final savedBaseUrl = prefs.getString(_kContaboBaseUrl);
    final savedMemories = prefs
        .getJsonList(_kMemories)
        .map(ApprovedMemory.fromJson)
        .toList();
    final savedMoods = prefs
        .getJsonList(_kMoodEntries)
        .map(MoodEntryModel.fromJson)
        .toList();
    final savedScreenings = prefs
        .getJsonList(_kScreeningHistory)
        .map(ScreeningResultModel.fromJson)
        .toList();
    final savedBookings = prefs
        .getJsonList(_kBookings)
        .map(CounselingBookingModel.fromJson)
        .toList();
    final savedPracticeLogs = prefs
        .getJsonList(_kPracticeLogs)
        .map((e) => e['log']?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
    final savedSessions = prefs
        .getJsonList(_kChatSessions)
        .map(ChatSessionModel.fromJson)
        .toList();
    final savedMessages = prefs
        .getJsonList(_kChatMessages)
        .map(ChatMessageModel.fromJson)
        .toList();
    final savedConsents = prefs
        .getJsonList(_kConsents)
        .map(ConsentRecord.fromJson)
        .toList();

    if (savedGuestId == null &&
        savedPrivacy == null &&
        savedCompMap == null &&
        savedMemories.isEmpty &&
        savedMoods.isEmpty &&
        savedScreenings.isEmpty &&
        savedMessages.isEmpty) {
      return;
    }

    state = state.copyWith(
      guestId: savedGuestId ?? state.guestId,
      subjectId: savedSubjectId ?? state.subjectId,
      userId: savedUserId ?? state.userId,
      userEmail: savedUserEmail ?? state.userEmail,
      authToken: savedAuthToken ?? state.authToken,
      userFaculty: savedFaculty ?? state.userFaculty,
      userAcademicYear: savedAcademicYear ?? state.userAcademicYear,
      isLinkedAccount: savedIsLinked ?? state.isLinkedAccount,
      hasAcceptedPrivacy: savedPrivacy ?? state.hasAcceptedPrivacy,
      companionPref: savedCompMap != null
          ? CompanionPreference.fromJson(savedCompMap)
          : state.companionPref,
      notificationPref: savedNotifMap != null
          ? NotificationPreference.fromJson(savedNotifMap)
          : state.notificationPref,
      geminiApiKey: savedApiKey ?? state.geminiApiKey,
      contaboBaseUrl: savedBaseUrl ?? state.contaboBaseUrl,
      consents: savedConsents.isNotEmpty ? savedConsents : state.consents,
      chatSessions:
          savedSessions.isNotEmpty ? savedSessions : state.chatSessions,
      activeChatSessionId: savedSessions.isNotEmpty
          ? savedSessions.first.sessionId
          : state.activeChatSessionId,
      messages: savedMessages.isNotEmpty ? savedMessages : state.messages,
      memories: savedMemories.isNotEmpty ? savedMemories : state.memories,
      moodEntries: savedMoods.isNotEmpty ? savedMoods : state.moodEntries,
      screeningHistory: savedScreenings.isNotEmpty
          ? savedScreenings
          : state.screeningHistory,
      bookings: savedBookings.isNotEmpty ? savedBookings : state.bookings,
      activityPracticeLogs: savedPracticeLogs.isNotEmpty
          ? savedPracticeLogs
          : state.activityPracticeLogs,
    );
  }

  Future<void> _persistState() async {
    if (!mounted) return;
    final snap = state;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    if (snap.guestId != null) {
      await prefs.setString(_kGuestId, snap.guestId!);
    }
    if (snap.subjectId != null) {
      await prefs.setString(_kSubjectId, snap.subjectId!);
    }
    if (snap.userId != null) {
      await prefs.setString(_kUserId, snap.userId!);
    }
    if (snap.userEmail != null) {
      await prefs.setString(_kUserEmail, snap.userEmail!);
    }
    if (snap.authToken != null) {
      await prefs.setString(_kAuthToken, snap.authToken!);
    }
    await prefs.setString(_kUserFaculty, snap.userFaculty);
    await prefs.setString(_kUserAcademicYear, snap.userAcademicYear);
    await prefs.setBool(_kIsLinked, snap.isLinkedAccount);
    await prefs.setBool(_kAcceptedPrivacy, snap.hasAcceptedPrivacy);
    await prefs.setJsonMap(_kCompanionPref, snap.companionPref.toJson());
    await prefs.setJsonMap(_kNotificationPref, snap.notificationPref.toJson());
    await prefs.setString(_kGeminiApiKey, snap.geminiApiKey);
    await prefs.setString(_kContaboBaseUrl, snap.contaboBaseUrl);
    await prefs.setJsonList(
      _kConsents,
      snap.consents.map((e) => e.toJson()).toList(),
    );
    await prefs.setJsonList(
      _kChatSessions,
      snap.chatSessions.map((e) => e.toJson()).toList(),
    );
    await prefs.setJsonList(
      _kChatMessages,
      snap.messages.map((e) => e.toJson()).toList(),
    );
    await prefs.setJsonList(
      _kMemories,
      snap.memories.map((e) => e.toJson()).toList(),
    );
    await prefs.setJsonList(
      _kMoodEntries,
      snap.moodEntries.map((e) => e.toJson()).toList(),
    );
    await prefs.setJsonList(
      _kScreeningHistory,
      snap.screeningHistory.map((e) => e.toJson()).toList(),
    );
    await prefs.setJsonList(
      _kBookings,
      snap.bookings.map((e) => e.toJson()).toList(),
    );
    await prefs.setJsonList(
      _kPracticeLogs,
      snap.activityPracticeLogs.map((e) => {'log': e}).toList(),
    );
  }

  String get _effectiveSubjectId =>
      state.subjectId ?? state.guestId ?? 'sub_default';

  Map<String, String> _userHeaders() {
    final headers = <String, String>{'X-Subject-Id': _effectiveSubjectId};
    if (state.authToken != null && state.authToken!.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer ${state.authToken!.trim()}';
    }
    return headers;
  }

  Future<ServerHealthStatus> checkBackendConnection({
    BackendEnvironment? overrideEnv,
    String? overrideUrl,
  }) {
    return _api.checkServerHealth(
      env: overrideEnv ?? state.backendEnv,
      customContaboUrl: overrideUrl ?? state.contaboBaseUrl,
    );
  }

  void setBackendEnvironment(
    BackendEnvironment env, {
    String? customUrl,
    String? apiKey,
  }) {
    state = state.copyWith(
      backendEnv: env,
      contaboBaseUrl: customUrl ?? state.contaboBaseUrl,
      geminiApiKey: apiKey ?? state.geminiApiKey,
    );
    _persistState();
  }

  void toggleOfflineSimulation(bool offline) {
    state = state.copyWith(
      backendEnv: offline
          ? BackendEnvironment.offlineSimulated
          : BackendEnvironment.contaboSingapore,
    );
  }

  void startAnonymousSession() {
    final newGuestId = 'guest_${_uuid.v4().substring(0, 6)}';
    final newSubjectId = 'sub_guest_${_uuid.v4().substring(0, 8)}';
    final consent = ConsentRecord(
      consentId: 'con_${_uuid.v4().substring(0, 6)}',
      purpose: 'privacy_policy',
      decision: 'accepted',
      timestamp: DateTime.now(),
    );
    final pref = state.companionPref;
    final updatedMessages = state.messages.map((m) {
      if (m.messageId == 'msg_welcome' && state.messages.length == 1) {
        final aiCap = pref.aiPronoun.isEmpty
            ? 'Mình'
            : '${pref.aiPronoun[0].toUpperCase()}${pref.aiPronoun.substring(1)}';
        return ChatMessageModel(
          messageId: m.messageId,
          sessionId: m.sessionId,
          role: 'assistant',
          text:
              'Chào ${pref.userPronoun}! $aiCap là ${pref.nickname} — người bạn đồng hành số của ${pref.userPronoun}. Dạo này việc học hay cuộc sống có điều gì làm ${pref.userPronoun} thấy mệt mỏi hay áp lực không?',
          quickReplies: m.quickReplies,
          createdAt: m.createdAt,
        );
      }
      return m;
    }).toList();

    state = state.copyWith(
      guestId: newGuestId,
      subjectId: newSubjectId,
      hasAcceptedPrivacy: true,
      consents: [...state.consents, consent],
      messages: updatedMessages,
    );
    _persistState();

    _api
        .createGuestSessionOnServer(
          env: state.backendEnv,
          customContaboUrl: state.contaboBaseUrl,
        )
        .then((serverData) {
          if (!mounted || serverData == null) return;
          final sGuest = serverData['guest_id']?.toString();
          final sSubj = serverData['subject_id']?.toString();
          final sTok = serverData['access_token']?.toString();
          state = state.copyWith(
            guestId: sGuest ?? state.guestId,
            subjectId: sSubj ?? state.subjectId,
            authToken: sTok ?? state.authToken,
          );
          _persistState();
          _api.syncBackgroundPut(
            '/me/companion-preferences',
            {
              'nickname': state.companionPref.nickname,
              'user_pronoun': state.companionPref.userPronoun,
              'ai_pronoun': state.companionPref.aiPronoun,
              'tone': state.companionPref.tone,
            },
            env: state.backendEnv,
            customContaboUrl: state.contaboBaseUrl,
            headers: _userHeaders(),
          );
        });
  }

  bool registerAndLinkAccount({
    required String email,
    String password = '',
    String fullName = '',
    String faculty = 'CNTT',
    String academicYear = 'Nam_2',
    required bool consentToLinkGuestData,
  }) {
    final cleanEmail = email.trim();
    if (!MindCheckApiService.isValidEmail(cleanEmail)) {
      return false;
    }
    final prevGuestId = state.guestId;
    final uid = 'usr_${_uuid.v4().substring(0, 6)}';
    final consent = ConsentRecord(
      consentId: 'con_${_uuid.v4().substring(0, 6)}',
      purpose: 'guest_session_link',
      decision: consentToLinkGuestData ? 'accepted' : 'declined',
      timestamp: DateTime.now(),
    );
    state = state.copyWith(
      userId: uid,
      userEmail: cleanEmail,
      userFaculty: faculty,
      userAcademicYear: academicYear,
      hasAcceptedPrivacy: true,
      isLinkedAccount: consentToLinkGuestData,
      consents: [...state.consents, consent],
      memories: consentToLinkGuestData ? state.memories : [],
    );
    _persistState();

    final effectivePassword =
        password.trim().length >= 6 ? password.trim() : 'MindCheck@2026';
    _signupAndLinkBackground(
      email: cleanEmail,
      password: effectivePassword,
      fullName: fullName,
      faculty: faculty,
      academicYear: academicYear,
      guestId: prevGuestId,
      consentToLink: consentToLinkGuestData,
    );
    return true;
  }

  Future<void> _signupAndLinkBackground({
    required String email,
    required String password,
    required String fullName,
    required String faculty,
    required String academicYear,
    required String? guestId,
    required bool consentToLink,
  }) async {
    final signupData = await _api.signupStudent(
      email: email,
      password: password,
      fullName: fullName,
      faculty: faculty,
      academicYear: academicYear,
      env: state.backendEnv,
      customContaboUrl: state.contaboBaseUrl,
    );
    if (!mounted || signupData == null) return;
    final sUid = signupData['user_id']?.toString();
    final sSubj = signupData['subject_id']?.toString();
    final sTok = signupData['access_token']?.toString();
    state = state.copyWith(
      userId: sUid ?? state.userId,
      subjectId: sSubj ?? state.subjectId,
      authToken: sTok ?? state.authToken,
    );
    if (consentToLink && guestId != null && guestId.isNotEmpty) {
      await _api.linkGuestSessionOnServer(
        guestId: guestId,
        userId: sUid,
        consentToLink: true,
        authToken: sTok,
        env: state.backendEnv,
        customContaboUrl: state.contaboBaseUrl,
      );
    }
    if (mounted) {
      _persistState();
    }
  }

  Future<bool> loginStudentAccount({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim();
    if (!MindCheckApiService.isValidEmail(cleanEmail) ||
        password.trim().isEmpty) {
      return false;
    }
    final data = await _api.loginStudent(
      email: cleanEmail,
      password: password,
      env: state.backendEnv,
      customContaboUrl: state.contaboBaseUrl,
    );
    if (!mounted || data == null) return false;
    state = state.copyWith(
      userId: data['user_id']?.toString() ?? state.userId,
      subjectId: data['subject_id']?.toString() ?? state.subjectId,
      authToken: data['access_token']?.toString() ?? state.authToken,
      userEmail: data['email']?.toString() ?? cleanEmail,
      userFaculty: data['faculty']?.toString() ?? state.userFaculty,
      userAcademicYear:
          data['academic_year']?.toString() ?? state.userAcademicYear,
      isLinkedAccount: true,
      hasAcceptedPrivacy: true,
    );
    await _persistState();
    await hydrateStudentDataFromServer();
    return true;
  }

  /// Hydration (Đợt 2): Tự động tải dữ liệu lịch sử của Sinh viên từ máy chủ Contabo về thiết bị
  Future<void> hydrateStudentDataFromServer() async {
    final subj = _effectiveSubjectId;
    final tok = state.authToken;
    final env = state.backendEnv;
    final url = state.contaboBaseUrl;

    final compPref = await _api.fetchStudentCompanionPreference(
      subjectId: subj,
      authToken: tok,
      env: env,
      customContaboUrl: url,
    );
    final notifPref = await _api.fetchStudentNotificationPreference(
      subjectId: subj,
      authToken: tok,
      env: env,
      customContaboUrl: url,
    );
    final serverMems = await _api.fetchStudentMemories(
      subjectId: subj,
      authToken: tok,
      env: env,
      customContaboUrl: url,
    );
    final serverMoods = await _api.fetchStudentMoodEntries(
      subjectId: subj,
      authToken: tok,
      env: env,
      customContaboUrl: url,
    );
    final serverScreenings = await _api.fetchStudentScreeningHistory(
      subjectId: subj,
      authToken: tok,
      env: env,
      customContaboUrl: url,
    );
    final serverBookings = await _api.fetchStudentBookings(
      authToken: tok,
      env: env,
      customContaboUrl: url,
    );
    if (!mounted) return;

    state = state.copyWith(
      companionPref: compPref ?? state.companionPref,
      notificationPref: notifPref ?? state.notificationPref,
      memories: (serverMems != null && serverMems.isNotEmpty)
          ? serverMems
          : state.memories,
      moodEntries: (serverMoods != null && serverMoods.isNotEmpty)
          ? serverMoods
          : state.moodEntries,
      screeningHistory:
          (serverScreenings != null && serverScreenings.isNotEmpty)
              ? serverScreenings
              : state.screeningHistory,
      bookings: (serverBookings != null && serverBookings.isNotEmpty)
          ? serverBookings
          : state.bookings,
    );
    await _persistState();
  }

  void logoutStudentAccount() {
    state = state.copyWith(
      clearAuth: true,
      isLinkedAccount: false,
      guestId: 'guest_${_uuid.v4().substring(0, 6)}',
      subjectId: 'sub_guest_${_uuid.v4().substring(0, 8)}',
    );
    _persistState();
  }

  void updateCompanionPreference(CompanionPreference pref) {
    final aiCap = pref.aiPronoun.isEmpty
        ? 'Mình'
        : '${pref.aiPronoun[0].toUpperCase()}${pref.aiPronoun.substring(1)}';
    final updatedMessages = state.messages.map((m) {
      if (m.messageId == 'msg_welcome' && state.messages.length == 1) {
        return ChatMessageModel(
          messageId: m.messageId,
          sessionId: m.sessionId,
          role: 'assistant',
          text:
              'Chào ${pref.userPronoun}! $aiCap là ${pref.nickname} — người bạn đồng hành số của ${pref.userPronoun}. Dạo này việc học hay cuộc sống có điều gì làm ${pref.userPronoun} thấy mệt mỏi hay áp lực không?',
          quickReplies: m.quickReplies,
          createdAt: m.createdAt,
        );
      }
      return m;
    }).toList();
    state = state.copyWith(companionPref: pref, messages: updatedMessages);
    _persistState();
    _api.syncBackgroundPut(
      '/me/companion-preferences',
      {
        'nickname': pref.nickname,
        'user_pronoun': pref.userPronoun,
        'ai_pronoun': pref.aiPronoun,
        'tone': pref.tone,
      },
      env: state.backendEnv,
      customContaboUrl: state.contaboBaseUrl,
      headers: _userHeaders(),
    );
  }

  void updateNotificationPreference(NotificationPreference pref) {
    state = state.copyWith(notificationPref: pref);
    _persistState();
    _api.syncBackgroundPut(
      '/me/notification-preferences',
      {
        'enabled': pref.enabled,
        'reminder_time': pref.reminderTime,
        'quiet_hours': pref.quietHours,
        'hide_sensitive_on_lock_screen': pref.hideSensitiveOnLockScreen,
      },
      env: state.backendEnv,
      customContaboUrl: state.contaboBaseUrl,
      headers: _userHeaders(),
    );
  }

  Future<void> clearAllPersonalData({bool resetToOnboarding = false}) async {
    final prevSubj = _effectiveSubjectId;
    final prevTok = state.authToken;
    final prevEnv = state.backendEnv;
    final prevUrl = state.contaboBaseUrl;

    await _api.erasePersonalDataOnServer(
      subjectId: prevSubj,
      authToken: prevTok,
      env: prevEnv,
      customContaboUrl: prevUrl,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    _processedClientMsgIds.clear();
    final fresh = _initialState();
    final revokedConsents = state.consents
        .map(
          (c) => ConsentRecord(
            consentId: c.consentId,
            purpose: c.purpose,
            version: c.version,
            decision: c.decision == 'accepted' ? 'revoked' : c.decision,
            timestamp: DateTime.now(),
          ),
        )
        .toList();
    state = fresh.copyWith(
      hasAcceptedPrivacy: !resetToOnboarding && state.hasAcceptedPrivacy,
      guestId: resetToOnboarding ? null : 'guest_${_uuid.v4().substring(0, 6)}',
      subjectId:
          resetToOnboarding ? null : 'sub_guest_${_uuid.v4().substring(0, 8)}',
      clearAuth: true,
      isLinkedAccount: false,
      consents: resetToOnboarding ? [] : revokedConsents,
      memories: [],
      moodEntries: [],
      screeningHistory: [],
      bookings: [],
      activityPracticeLogs: [],
      dataRequests: [
        'Đã xóa toàn bộ dữ liệu cá nhân & thu hồi đồng ý lúc ${DateTime.now().toIso8601String().substring(11, 16)}',
      ],
    );
  }

  void revokeConsentOrRequestDataAction(String actionLabel) {
    final prevSubj = _effectiveSubjectId;
    final prevTok = state.authToken;
    _api.erasePersonalDataOnServer(
      subjectId: prevSubj,
      authToken: prevTok,
      env: state.backendEnv,
      customContaboUrl: state.contaboBaseUrl,
    );
    SharedPreferences.getInstance().then((prefs) => prefs.clear());
    _processedClientMsgIds.clear();
    final revokedConsents = state.consents
        .map(
          (c) => ConsentRecord(
            consentId: c.consentId,
            purpose: c.purpose,
            version: c.version,
            decision: c.decision == 'accepted' ? 'revoked' : c.decision,
            timestamp: DateTime.now(),
          ),
        )
        .toList();
    state = state.copyWith(
      consents: revokedConsents,
      memories: [],
      moodEntries: [],
      screeningHistory: [],
      activityPracticeLogs: [],
      dataRequests: [
        '$actionLabel — Đã thu hồi đồng ý & xóa dữ liệu cá nhân lúc ${DateTime.now().toIso8601String().substring(11, 16)}',
        ...state.dataRequests,
      ],
    );
  }

  void createNewChatSession() {
    final newId = 'chat_${_uuid.v4().substring(0, 6)}';
    final newSession = ChatSessionModel(
      sessionId: newId,
      title: 'Cuộc trò chuyện #${state.chatSessions.length + 1}',
      startedAt: DateTime.now(),
    );
    final welcomeMsg = ChatMessageModel(
      messageId: _uuid.v4(),
      sessionId: newId,
      role: 'assistant',
      text:
          'Chào ${state.companionPref.userPronoun}! ${state.companionPref.aiPronoun.toUpperCase()} (${state.companionPref.nickname}) sẵn sàng lắng nghe ${state.companionPref.userPronoun} ở cuộc trò chuyện mới này.',
      quickReplies: const [
        'Dạ khá mệt, gần đây em ngủ không ngon giấc ạ.',
        'Mình muốn thử bài tập CBT',
      ],
      createdAt: DateTime.now(),
    );
    state = state.copyWith(
      chatSessions: [newSession, ...state.chatSessions],
      activeChatSessionId: newId,
      messages: [...state.messages, welcomeMsg],
    );
    _persistState();
    _api.syncBackgroundPost(
      '/chats',
      {'subject_id': _effectiveSubjectId, 'title': newSession.title},
      env: state.backendEnv,
      customContaboUrl: state.contaboBaseUrl,
      headers: _userHeaders(),
    );
  }

  void switchChatSession(String sessionId) {
    state = state.copyWith(activeChatSessionId: sessionId);
  }

  void renameChatSession(String sessionId, String newTitle) {
    final trimmed = newTitle.trim();
    if (trimmed.isEmpty) return;
    state = state.copyWith(
      chatSessions: state.chatSessions
          .map((s) => s.sessionId == sessionId ? s.copyWith(title: trimmed) : s)
          .toList(),
    );
    _persistState();
    _api.syncBackgroundPatch(
      '/chats/$sessionId',
      {'title': trimmed},
      env: state.backendEnv,
      customContaboUrl: state.contaboBaseUrl,
      headers: _userHeaders(),
    );
  }

  void deleteChatSession(String sessionId) {
    final remaining =
        state.chatSessions.where((s) => s.sessionId != sessionId).toList();
    final remainingMsgs =
        state.messages.where((m) => m.sessionId != sessionId).toList();
    _api.syncBackgroundDelete(
      '/chats/$sessionId',
      env: state.backendEnv,
      customContaboUrl: state.contaboBaseUrl,
      headers: _userHeaders(),
    );
    if (remaining.isEmpty) {
      state = state.copyWith(chatSessions: [], messages: remainingMsgs);
      createNewChatSession();
    } else {
      state = state.copyWith(
        chatSessions: remaining,
        activeChatSessionId: remaining.first.sessionId,
        messages: remainingMsgs,
      );
      _persistState();
    }
  }

  Future<void> sendChatMessage(String text, {String? customClientMsgId}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final clientMsgId = customClientMsgId ?? _uuid.v4();
    if (_processedClientMsgIds.contains(clientMsgId)) return;

    final existingIdx =
        state.messages.indexWhere((m) => m.messageId == clientMsgId);
    if (existingIdx >= 0) {
      final updatedList = [...state.messages];
      updatedList[existingIdx] = updatedList[existingIdx].copyWith(
        state: state.simulateOfflineMode ? 'failed' : 'delivered',
      );
      state = state.copyWith(
        messages: updatedList,
        isAiTyping: !state.simulateOfflineMode,
      );
    } else {
      final userMsg = ChatMessageModel(
        messageId: clientMsgId,
        sessionId: state.activeChatSessionId,
        role: 'user',
        text: trimmed,
        state: state.simulateOfflineMode ? 'failed' : 'delivered',
        createdAt: DateTime.now(),
      );
      state = state.copyWith(
        messages: [...state.messages, userMsg],
        isAiTyping: !state.simulateOfflineMode,
      );
    }

    try {
      final sessionHistory = state.messages
          .where((m) =>
              m.sessionId == state.activeChatSessionId &&
              m.messageId != clientMsgId)
          .toList();
      final result = await _api.sendChatMessage(
        chatId: state.activeChatSessionId,
        clientMessageId: clientMsgId,
        text: trimmed,
        pref: state.companionPref,
        memories: state.memories,
        env: state.backendEnv,
        customContaboUrl: state.contaboBaseUrl,
        subjectId: _effectiveSubjectId,
        authToken: state.authToken,
        recentMessages: sessionHistory,
        geminiApiKey: state.geminiApiKey,
      );
      if (!mounted) return;

      _processedClientMsgIds.add(clientMsgId);

      MemoryProposal? proposal;
      if (result['memory_proposal'] != null) {
        final mp = result['memory_proposal'] as Map<String, dynamic>;
        proposal = MemoryProposal(
          proposalId: mp['proposal_id'].toString(),
          sourceMessageId: clientMsgId,
          candidateText: mp['candidate_text'].toString(),
        );
      }

      final String? action = state.suppressScreeningSuggestion &&
              result['suggested_action'] == 'suggest_screening'
          ? null
          : result['suggested_action'] as String?;

      final deliveredMessages = state.messages
          .map((m) =>
              m.messageId == clientMsgId ? m.copyWith(state: 'delivered') : m)
          .toList();

      final aiMsg = ChatMessageModel(
        messageId: _uuid.v4(),
        sessionId: state.activeChatSessionId,
        role: 'assistant',
        text: result['reply'].toString(),
        quickReplies: List<String>.from(result['quick_replies'] ?? const []),
        suggestedAction: action,
        memoryProposal: proposal,
        providerBadge: result['provider_badge']?.toString() ??
            'Contabo SG • Gemini 2.5 Flash',
        createdAt: DateTime.now(),
      );

      state = state.copyWith(
        messages: [...deliveredMessages, aiMsg],
        isAiTyping: false,
      );
      _persistState();
    } catch (_) {
      if (!mounted) return;
      final failedMessages = state.messages
          .map((m) =>
              m.messageId == clientMsgId ? m.copyWith(state: 'failed') : m)
          .toList();
      state = state.copyWith(
        messages: failedMessages,
        isAiTyping: false,
      );
      _persistState();
    }
  }

  /// T05 & T06: Thử gửi lại tin nhắn lỗi mạng với đúng `client_message_id` cũ để chống nhân đôi
  Future<void> retryFailedMessage(String failedMessageId) async {
    final target = state.messages
        .where((m) => m.messageId == failedMessageId)
        .firstOrNull;
    if (target == null) return;
    if (state.simulateOfflineMode) {
      toggleOfflineSimulation(false);
    }
    await sendChatMessage(target.text, customClientMsgId: target.messageId);
  }

  void respondToMemoryProposal(
    String messageId,
    MemoryProposal proposal,
    bool accepted,
  ) {
    final newStatus = accepted ? 'approved' : 'rejected';
    final updatedMessages = state.messages.map((m) {
      if (m.messageId == messageId && m.memoryProposal != null) {
        return m.copyWith(
          memoryProposal: m.memoryProposal!.copyWith(status: newStatus),
        );
      }
      return m;
    }).toList();

    final consent = ConsentRecord(
      consentId: 'con_${_uuid.v4().substring(0, 6)}',
      purpose: 'ai_memory',
      decision: accepted ? 'accepted' : 'declined',
      timestamp: DateTime.now(),
    );

    final updatedMemories = accepted
        ? [
            ApprovedMemory(
              memoryId: 'mem_${_uuid.v4().substring(0, 6)}',
              text: proposal.candidateText,
              updatedAt: DateTime.now(),
            ),
            ...state.memories,
          ]
        : state.memories;

    state = state.copyWith(
      messages: updatedMessages,
      consents: [...state.consents, consent],
      memories: updatedMemories,
    );
    _persistState();
    _api.syncBackgroundPost(
      '/memories/${proposal.proposalId}/approve',
      {
        'decision': accepted ? 'accepted' : 'rejected',
        'candidate_text': proposal.candidateText,
        'subject_id': _effectiveSubjectId,
      },
      env: state.backendEnv,
      customContaboUrl: state.contaboBaseUrl,
      headers: _userHeaders(),
    );
  }

  /// R2 & F10: Lưu trí nhớ thủ công bắt buộc phải có sự đồng ý rõ ràng (consentAccepted == true)
  bool addManualApprovedMemory(String text, {bool consentAccepted = true}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    final consent = ConsentRecord(
      consentId: 'con_${_uuid.v4().substring(0, 6)}',
      purpose: 'ai_memory',
      decision: consentAccepted ? 'accepted' : 'declined',
      timestamp: DateTime.now(),
    );
    if (!consentAccepted) {
      state = state.copyWith(consents: [...state.consents, consent]);
      _persistState();
      return false;
    }
    final newMem = ApprovedMemory(
      memoryId: 'mem_${_uuid.v4().substring(0, 6)}',
      text: trimmed,
      updatedAt: DateTime.now(),
    );
    state = state.copyWith(
      consents: [...state.consents, consent],
      memories: [newMem, ...state.memories],
    );
    _persistState();
    _api.syncBackgroundPost(
      '/memories',
      {
        'subject_id': _effectiveSubjectId,
        'text': trimmed,
        'consent_accepted': true,
      },
      env: state.backendEnv,
      customContaboUrl: state.contaboBaseUrl,
      headers: _userHeaders(),
    );
    return true;
  }

  void editApprovedMemory(String memoryId, String newText) {
    final trimmed = newText.trim();
    if (trimmed.isEmpty) return;
    state = state.copyWith(
      memories: state.memories
          .map((m) => m.memoryId == memoryId
              ? ApprovedMemory(
                  memoryId: memoryId,
                  text: trimmed,
                  updatedAt: DateTime.now(),
                )
              : m)
          .toList(),
    );
    _persistState();
    _api.syncBackgroundPatch(
      '/memories/$memoryId',
      {'text': trimmed},
      env: state.backendEnv,
      customContaboUrl: state.contaboBaseUrl,
      headers: _userHeaders(),
    );
  }

  void deleteApprovedMemory(String memoryId) {
    state = state.copyWith(
      memories: state.memories.where((m) => m.memoryId != memoryId).toList(),
    );
    _persistState();
    _api.syncBackgroundDelete(
      '/memories/$memoryId',
      env: state.backendEnv,
      customContaboUrl: state.contaboBaseUrl,
      headers: _userHeaders(),
    );
  }

  void dismissScreeningSuggestion() {
    state = state.copyWith(suppressScreeningSuggestion: true);
  }

  void addMoodEntry(String moodChoice, int moodLevel, String note) {
    final safeLevel = moodLevel.clamp(1, 5);
    final entry = MoodEntryModel(
      entryId: 'mood_${_uuid.v4().substring(0, 6)}',
      moodChoice: moodChoice,
      moodLevel: safeLevel,
      optionalNote: note.trim(),
      recordedAt: DateTime.now(),
    );
    state = state.copyWith(moodEntries: [entry, ...state.moodEntries]);
    _persistState();
    _api.syncBackgroundPost(
      '/mood-entries',
      {
        'subject_id': _effectiveSubjectId,
        'mood_choice': moodChoice,
        'mood_level': safeLevel,
        'optional_note': note.trim(),
      },
      env: state.backendEnv,
      customContaboUrl: state.contaboBaseUrl,
      headers: _userHeaders(),
    );
  }

  void deleteMoodEntry(String entryId) {
    state = state.copyWith(
      moodEntries:
          state.moodEntries.where((e) => e.entryId != entryId).toList(),
    );
    _persistState();
    _api.syncBackgroundDelete(
      '/mood-entries/$entryId',
      env: state.backendEnv,
      customContaboUrl: state.contaboBaseUrl,
      headers: _userHeaders(),
    );
  }

  void updateActivityStatus(
    String activityId,
    String status, {
    String? practiceSummary,
  }) {
    final timeStr = DateTime.now().toIso8601String().substring(11, 16);
    final updatedActivities = state.dailyActivities
        .map((a) => a.activityId == activityId
            ? a.copyWith(
                status: status,
                lastPracticeSummary: practiceSummary ?? a.lastPracticeSummary,
              )
            : a)
        .toList();

    final updatedLogs = (practiceSummary != null && practiceSummary.isNotEmpty)
        ? ['$practiceSummary (lúc $timeStr)', ...state.activityPracticeLogs]
        : state.activityPracticeLogs;

    state = state.copyWith(
      dailyActivities: updatedActivities,
      activityPracticeLogs: updatedLogs,
    );
    _persistState();
    _api.syncBackgroundPost(
      '/activity-progress',
      {
        'subject_id': _effectiveSubjectId,
        'activity_id': activityId,
        'status': status,
      },
      env: state.backendEnv,
      customContaboUrl: state.contaboBaseUrl,
      headers: _userHeaders(),
    );
  }

  void recordScreeningConsent(bool accepted) {
    final consent = ConsentRecord(
      consentId: 'con_${_uuid.v4().substring(0, 6)}',
      purpose: 'screening',
      decision: accepted ? 'accepted' : 'declined',
      timestamp: DateTime.now(),
    );
    state = state.copyWith(consents: [...state.consents, consent]);
    _persistState();
    _api.createConsentOnServer(
      subjectId: _effectiveSubjectId,
      purpose: 'screening',
      decision: accepted ? 'accepted' : 'declined',
      authToken: state.authToken,
      env: state.backendEnv,
      customContaboUrl: state.contaboBaseUrl,
    );
  }

  /// T16: Ghi nhận thoát sàng lọc giữa chừng (abandoned) mà KHÔNG chấm điểm hay tạo lịch sử kết quả
  void abandonScreeningSession({
    required ScreeningToolModel tool,
    required List<int> partialAnswers,
  }) {
    _api.submitScreeningFullFlowOnServer(
      subjectId: _effectiveSubjectId,
      toolId: tool.toolId,
      answers: partialAnswers,
      completed: false,
      faculty: state.userFaculty,
      academicYear: state.userAcademicYear,
      authToken: state.authToken,
      env: state.backendEnv,
      customContaboUrl: state.contaboBaseUrl,
    );
  }

  ScreeningResultModel submitScreeningAnswers({
    required ScreeningToolModel tool,
    required List<int> answers,
    String? facultyOverride,
    String? academicYearOverride,
  }) {
    final normalizedAnswers = answers.map((a) => a.clamp(0, 3)).toList();
    final totalScore =
        normalizedAnswers.fold<int>(0, (sum, item) => sum + item);
    final maxScore = tool.questions.length * 3;
    final ratio = maxScore > 0 ? (totalScore / maxScore) : 0.0;
    final item9Risk = tool.toolId == 'PHQ-9' &&
        normalizedAnswers.length >= 9 &&
        normalizedAnswers[8] >= 1;

    String levelLabel;
    bool requiresAttention;

    if (tool.toolId == 'PHQ-9') {
      if (totalScore <= 4 && !item9Risk) {
        levelLabel = 'Mức tối thiểu — bạn đang ổn';
        requiresAttention = false;
      } else if (totalScore <= 9 && !item9Risk) {
        levelLabel = 'Mức nhẹ — nên duy trì tự chăm sóc';
        requiresAttention = false;
      } else if (totalScore <= 14 && !item9Risk) {
        levelLabel = 'Mức trung bình — nên theo dõi thêm';
        requiresAttention = true;
      } else {
        levelLabel = 'Mức cần chú ý — nên kết nối chuyên gia tư vấn';
        requiresAttention = true;
      }
    } else if (tool.toolId == 'GAD-7') {
      if (totalScore <= 4) {
        levelLabel = 'Mức thấp — bạn đang ổn';
        requiresAttention = false;
      } else if (totalScore <= 9) {
        levelLabel = 'Mức nhẹ — nên thư giãn và theo dõi';
        requiresAttention = false;
      } else if (totalScore <= 14) {
        levelLabel = 'Mức trung bình — nên theo dõi thêm';
        requiresAttention = true;
      } else {
        levelLabel = 'Mức cần chú ý — nên kết nối chuyên gia tư vấn';
        requiresAttention = true;
      }
    } else {
      if (ratio < 0.34) {
        levelLabel = 'Mức thấp — bạn đang ổn';
        requiresAttention = false;
      } else if (ratio < 0.67) {
        levelLabel = 'Mức trung bình — nên theo dõi thêm';
        requiresAttention = true;
      } else {
        levelLabel = 'Mức cần chú ý — nên kết nối chuyên gia tư vấn';
        requiresAttention = true;
      }
    }

    final String interpretation;
    if (item9Risk || totalScore >= (maxScore * 0.7).floor()) {
      interpretation =
          'Hệ thống ghi nhận dấu hiệu cần được hỗ trợ an toàn ưu tiên (An toàn 2 lớp - R3): '
          'Nếu bạn đang cảm thấy mất an toàn, hãy gọi ngay Đường dây nóng Cấp cứu Y tế 115 hoặc Tổng đài Quốc gia 111 (24/7, S21), '
          'đồng thời đặt lịch hẹn trực tiếp với Chuyên gia Tư vấn Tâm lý của trường (S23). '
          'Kết quả được tính bằng Rule-based Engine và không thay thế chẩn đoán y khoa.';
    } else if (requiresAttention) {
      interpretation =
          'Vài dấu hiệu gần đây cho thấy bạn nên trò chuyện với chuyên gia tâm lý của trường trong tuần này (S23) '
          'hoặc tham khảo đường dây hỗ trợ 115 / 111 (S21) khi cần thiết. '
          'Kết quả được chấm bằng Rule-based Engine, mang tính tham khảo tự theo dõi và không thay thế chẩn đoán y khoa.';
    } else {
      interpretation =
          'Trạng thái tinh thần của bạn đang ở ngưỡng ổn định. Hãy tiếp tục duy trì nhịp nghỉ ngơi điều độ, check-in cảm xúc và thực hành bài tập thở hoặc CBT ngắn mỗi ngày. '
          'Kết quả mang tính tham khảo tự theo dõi, không phải chẩn đoán y khoa.';
    }

    // Tính xu hướng thật từ lịch sử sàng lọc của cùng thang đo (không dùng mảng giả định)
    final priorSameTool = state.screeningHistory
        .where((r) => r.toolId == tool.toolId && r.maxScore > 0)
        .toList()
        .reversed
        .toList();
    final recentRatios = priorSameTool
        .skip(priorSameTool.length > 5 ? priorSameTool.length - 5 : 0)
        .map((r) => (r.score / r.maxScore).clamp(0.05, 0.98))
        .toList();
    final realTrend = <double>[
      ...recentRatios,
      ratio.clamp(0.05, 0.98),
    ];

    final effectiveFaculty = facultyOverride ?? state.userFaculty;
    final effectiveYear = academicYearOverride ?? state.userAcademicYear;
    final subscales = tool.toolId == 'DASS-21'
        ? ScreeningResultModel.computeDass21Subscales(normalizedAnswers)
        : const <String, int>{};

    final result = ScreeningResultModel(
      sessionId: 'scr_${_uuid.v4().substring(0, 6)}',
      toolId: tool.toolId,
      score: totalScore,
      maxScore: maxScore,
      levelLabel: levelLabel,
      interpretation: interpretation,
      requiresAttention: requiresAttention,
      fourWeekTrend: realTrend,
      subscaleScores: subscales,
      completedAt: DateTime.now(),
      faculty: effectiveFaculty,
      academicYear: effectiveYear,
      isClinicalDiagnosis: false,
      demoFlag: kSeedDemoMode,
    );

    state = state.copyWith(
      screeningHistory: [result, ...state.screeningHistory],
      clearServerAnalytics: true,
    );
    _persistState();

    _api.submitScreeningFullFlowOnServer(
      subjectId: _effectiveSubjectId,
      toolId: tool.toolId,
      answers: normalizedAnswers,
      completed: true,
      faculty: effectiveFaculty,
      academicYear: effectiveYear,
      authToken: state.authToken,
      env: state.backendEnv,
      customContaboUrl: state.contaboBaseUrl,
    );

    return result;
  }

  void prepareBookingFromScreening({
    required String counselorId,
    required String suggestedNote,
  }) {
    state = state.copyWith(
      preferredCounselorId: counselorId,
      preferredBookingNote: suggestedNote,
    );
  }

  CounselingBookingModel? createCounselingBooking({
    required String unitName,
    required String counselorId,
    required String counselorName,
    required String slotTime,
    String consultationMode = 'Trực tiếp tại phòng P.102',
    required String contactInfo,
    required String studentNote,
    required bool agreedToShare,
  }) {
    final consent = ConsentRecord(
      consentId: 'con_${_uuid.v4().substring(0, 6)}',
      purpose: 'counseling_share',
      decision: agreedToShare ? 'accepted' : 'declined',
      timestamp: DateTime.now(),
    );
    state = state.copyWith(consents: [...state.consents, consent]);

    if (!agreedToShare) {
      _persistState();
      return null;
    }

    final cleanContact = contactInfo.trim();
    if (!MindCheckApiService.isValidContactInfo(cleanContact)) {
      _persistState();
      return null;
    }

    final localId = 'req_${_uuid.v4().substring(0, 6)}';
    final idempotencyKey = 'idem_$localId';
    final booking = CounselingBookingModel(
      requestId: localId,
      unitName: unitName,
      counselorId: counselorId,
      counselorName: counselorName,
      slotTime: slotTime,
      consultationMode: consultationMode,
      contactInfo: cleanContact,
      studentNote: studentNote.trim(),
      consentId: consent.consentId,
      status: 'pending',
      createdAt: DateTime.now(),
    );

    state = state.copyWith(
      bookings: [booking, ...state.bookings],
      clearServerAnalytics: true,
    );
    _persistState();

    _api
        .createBookingOnServer(
          subjectId: _effectiveSubjectId,
          idempotencyKey: idempotencyKey,
          unitName: unitName,
          counselorId: counselorId,
          counselorName: counselorName,
          slotTime: slotTime,
          consultationMode: consultationMode,
          contactInfo: cleanContact,
          studentNote: studentNote.trim(),
          authToken: state.authToken,
          env: state.backendEnv,
          customContaboUrl: state.contaboBaseUrl,
        )
        .then((serverBooking) {
          if (!mounted || serverBooking == null) return;
          final serverReqId = serverBooking['request_id']?.toString();
          final reqToken = serverBooking['requester_token']?.toString() ?? '';
          if (serverReqId == null || serverReqId.isEmpty) return;
          state = state.copyWith(
            bookings: state.bookings
                .map(
                  (b) => b.requestId == localId
                      ? b.copyWith(
                          requestId: serverReqId,
                          requesterToken: reqToken,
                        )
                      : b,
                )
                .toList(),
          );
          _persistState();
        });

    return booking;
  }

  void updateBookingStatus({
    required String requestId,
    required String newStatus,
    required String actorLabel,
    String? counselorNote,
    String? updatedSlotTime,
  }) {
    final targetBooking = state.bookings
        .where((b) => b.requestId == requestId)
        .firstOrNull;
    final audit = AuditEventModel(
      eventId: 'evt_${_uuid.v4().substring(0, 6)}',
      actor: actorLabel,
      action: 'UPDATE_BOOKING_STATUS -> $newStatus',
      target: requestId,
      result: 'SUCCESS',
      timestamp: DateTime.now(),
    );
    state = state.copyWith(
      bookings: state.bookings
          .map((b) => b.requestId == requestId
              ? b.copyWith(
                  status: newStatus,
                  counselorNote: counselorNote ?? b.counselorNote,
                  slotTime: updatedSlotTime ?? b.slotTime,
                )
              : b)
          .toList(),
      auditLogs: [audit, ...state.auditLogs],
      clearServerAnalytics: true,
    );
    _persistState();

    if (actorLabel == 'Student' && newStatus == 'canceled') {
      _api.cancelStudentBookingOnServer(
        requestId: requestId,
        requesterToken: targetBooking?.requesterToken,
        authToken: state.authToken,
        env: state.backendEnv,
        customContaboUrl: state.contaboBaseUrl,
      );
    } else if (actorLabel.startsWith('counselor_')) {
      final staffTok = state.staffTokens[actorLabel];
      _api.syncBackgroundPatch(
        '/staff/counseling-requests/$requestId',
        {
          'status': newStatus,
          if (counselorNote != null) 'counselor_note': counselorNote,
          if (updatedSlotTime != null) 'slot_time': updatedSlotTime,
        },
        env: state.backendEnv,
        customContaboUrl: state.contaboBaseUrl,
        headers: {
          if (staffTok != null && staffTok.isNotEmpty)
            'Authorization': 'Bearer $staffTok'
          else
            'X-Staff-Id': actorLabel,
        },
      );
    }
  }

  void updateAnalyticsPolicy(int newMinGroupSize, String adminActor) {
    final clamped = newMinGroupSize.clamp(5, 100);
    final audit = AuditEventModel(
      eventId: 'evt_${_uuid.v4().substring(0, 6)}',
      actor: adminActor,
      action: 'UPDATE_MIN_GROUP_SIZE_POLICY ($clamped)',
      target: 'AnalyticsPolicy',
      result: 'SUCCESS',
      timestamp: DateTime.now(),
    );
    state = state.copyWith(
      minGroupSizePolicy: clamped,
      auditLogs: [audit, ...state.auditLogs],
      clearServerAnalytics: true,
    );
    final adminTok = state.staffTokens[adminActor];
    _api.syncBackgroundPut(
      '/admin/analytics-policy',
      {'min_group_size': clamped},
      env: state.backendEnv,
      customContaboUrl: state.contaboBaseUrl,
      headers: {
        if (adminTok != null && adminTok.isNotEmpty)
          'Authorization': 'Bearer $adminTok'
        else
          'X-Admin-Actor': adminActor,
      },
    );
  }

  ActorRole _resolveActorRoleFromStaffId(String staffId, [String? roleStr]) {
    final cleanId = staffId.trim().toLowerCase();
    final cleanRole = (roleStr ?? '').trim().toLowerCase();
    if (cleanId == 'counselor_02') return ActorRole.counselor2;
    if (cleanId.startsWith('counselor') || cleanRole == 'counselor') {
      return ActorRole.counselor1;
    }
    if (cleanId.startsWith('admin') || cleanRole == 'admin') {
      return ActorRole.admin;
    }
    return ActorRole.ctsv;
  }

  Future<bool> loginStaffMember(String staffId, String password) async {
    final cleanStaffId = staffId.trim();
    if (cleanStaffId.isEmpty) return false;

    // Kiểm tra trạng thái hoạt động trong danh bạ nhân sự cục bộ
    final localStaff = state.staffDirectory
        .where((s) => s.staffId == cleanStaffId)
        .firstOrNull;
    if (localStaff != null && !localStaff.isActive) {
      recordAuditEvent(
        actor: cleanStaffId,
        action: 'STAFF_LOGIN_DISABLED_ACCOUNT',
        target: 'StaffAuth',
        result: 'DENIED_ACCOUNT_DISABLED',
      );
      return false;
    }

    final res = await _api.loginStaff(
      staffId: cleanStaffId,
      password: password,
      env: state.backendEnv,
      customContaboUrl: state.contaboBaseUrl,
    );
    if (!mounted) return false;

    String? token = res?['access_token']?.toString();
    final serverRole = res?['role']?.toString();

    // Cho phép xác thực phiên nhân sự ngay cả khi chạy chế độ Local/Offline nếu đúng mã nhân sự hợp lệ và mật khẩu >= 4 ký tự
    if ((token == null || token.isEmpty) &&
        localStaff != null &&
        password.trim().length >= 4) {
      token = 'tok_local_${cleanStaffId}_${_uuid.v4().substring(0, 8)}';
    }
    if (token == null || token.isEmpty) return false;

    final resolvedRole = _resolveActorRoleFromStaffId(
      cleanStaffId,
      serverRole ?? localStaff?.role,
    );
    final updatedTokens = Map<String, String>.from(state.staffTokens);
    updatedTokens[cleanStaffId] = token;
    state = state.copyWith(
      staffTokens: updatedTokens,
      authenticatedStaffId: cleanStaffId,
      authenticatedStaffRole: resolvedRole,
      isStaffDemoSwitchEnabled: false,
    );
    recordAuditEvent(
      actor: cleanStaffId,
      action: 'STAFF_LOGIN (${localStaff?.role ?? serverRole ?? "staff"})',
      target: 'AuthSession',
      result: 'SUCCESS',
    );
    return true;
  }

  void logoutStaffMember() {
    final prevStaff = state.authenticatedStaffId ?? 'staff';
    state = state.copyWith(
      clearStaffSession: true,
      isStaffDemoSwitchEnabled: true,
    );
    recordAuditEvent(
      actor: prevStaff,
      action: 'STAFF_LOGOUT',
      target: 'AuthSession',
      result: 'SUCCESS',
    );
  }

  void toggleStaffDemoSwitchMode(bool enabled) {
    state = state.copyWith(isStaffDemoSwitchEnabled: enabled);
  }

  // ---------------------------------------------------------------------------
  // A02 (CTSV) & A04 (Admin): Quản lý Thư viện Kiến thức Tâm lý Học đường
  // ---------------------------------------------------------------------------
  KnowledgeArticleModel? upsertKnowledgeArticle({
    String? id,
    required String title,
    required String category,
    required String summary,
    required String content,
    String verifiedSource = 'Phòng Tư vấn Tâm lý & Công tác Sinh viên',
    String actor = 'ctsv_01',
  }) {
    final cleanTitle = title.trim();
    final cleanSummary = summary.trim();
    final cleanContent = content.trim();
    if (cleanTitle.isEmpty || cleanSummary.isEmpty || cleanContent.isEmpty) {
      return null;
    }
    final artId = (id != null && id.trim().isNotEmpty)
        ? id.trim()
        : 'art_${_uuid.v4().substring(0, 6)}';
    final article = KnowledgeArticleModel(
      id: artId,
      title: cleanTitle,
      category: category.trim().isEmpty ? 'Kỹ năng Tự chăm sóc' : category.trim(),
      summary: cleanSummary,
      content: cleanContent,
      verifiedSource: verifiedSource.trim().isEmpty
          ? 'Phòng Tư vấn Tâm lý & Công tác Sinh viên'
          : verifiedSource.trim(),
    );

    final exists = state.articles.any((a) => a.id == artId);
    final updatedList = exists
        ? state.articles.map((a) => a.id == artId ? article : a).toList()
        : [article, ...state.articles];

    final audit = AuditEventModel(
      eventId: 'evt_${_uuid.v4().substring(0, 6)}',
      actor: actor,
      action: 'UPSERT_KNOWLEDGE_ARTICLE ($artId)',
      target: artId,
      result: 'SUCCESS',
      timestamp: DateTime.now(),
    );
    state = state.copyWith(
      articles: updatedList,
      auditLogs: [audit, ...state.auditLogs],
    );
    final staffTok = state.staffTokens[actor];
    _api.syncBackgroundPost(
      '/knowledge-articles',
      {
        'id': artId,
        'title': article.title,
        'category': article.category,
        'summary': article.summary,
        'content': article.content,
        'verified_source': article.verifiedSource,
      },
      env: state.backendEnv,
      customContaboUrl: state.contaboBaseUrl,
      headers: {
        if (staffTok != null && staffTok.isNotEmpty)
          'Authorization': 'Bearer $staffTok'
        else ...{
          'X-Staff-Role': actor.startsWith('admin') ? 'admin' : 'ctsv',
          'X-Staff-Id': actor,
        },
      },
    );
    return article;
  }

  void deleteKnowledgeArticle(String articleId, {String actor = 'ctsv_01'}) {
    final audit = AuditEventModel(
      eventId: 'evt_${_uuid.v4().substring(0, 6)}',
      actor: actor,
      action: 'DELETE_KNOWLEDGE_ARTICLE ($articleId)',
      target: articleId,
      result: 'SUCCESS',
      timestamp: DateTime.now(),
    );
    state = state.copyWith(
      articles: state.articles.where((a) => a.id != articleId).toList(),
      auditLogs: [audit, ...state.auditLogs],
    );
    final staffTok = state.staffTokens[actor];
    _api.syncBackgroundDelete(
      '/knowledge-articles/$articleId',
      env: state.backendEnv,
      customContaboUrl: state.contaboBaseUrl,
      headers: {
        if (staffTok != null && staffTok.isNotEmpty)
          'Authorization': 'Bearer $staffTok'
        else ...{
          'X-Staff-Role': actor.startsWith('admin') ? 'admin' : 'ctsv',
          'X-Staff-Id': actor,
        },
      },
    );
  }

  // ---------------------------------------------------------------------------
  // A03 (Tư vấn viên): Quản lý Lịch làm việc & Khung giờ trống (Availability Slots)
  // ---------------------------------------------------------------------------
  CounselorSlotModel? addCounselorSlot({
    required String counselorId,
    required String counselorName,
    required String unitName,
    required String slotLabel,
    String consultationMode = 'Trực tiếp tại phòng P.102',
  }) {
    final cleanLabel = slotLabel.trim();
    if (cleanLabel.isEmpty) return null;
    final slotId = 'slot_${counselorId}_${_uuid.v4().substring(0, 5)}';
    final newSlot = CounselorSlotModel(
      slotId: slotId,
      counselorId: counselorId,
      counselorName: counselorName,
      unitName: unitName,
      slotLabel: cleanLabel,
      consultationMode: consultationMode.trim().isEmpty
          ? 'Trực tiếp tại phòng P.102'
          : consultationMode.trim(),
      isAvailable: true,
    );
    final audit = AuditEventModel(
      eventId: 'evt_${_uuid.v4().substring(0, 6)}',
      actor: counselorId,
      action: 'CREATE_COUNSELOR_SLOT ($cleanLabel)',
      target: slotId,
      result: 'SUCCESS',
      timestamp: DateTime.now(),
    );
    state = state.copyWith(
      counselorSlots: [...state.counselorSlots, newSlot],
      auditLogs: [audit, ...state.auditLogs],
    );
    final staffTok = state.staffTokens[counselorId];
    _api.syncBackgroundPost(
      '/staff/counselor-slots',
      {
        'counselor_id': counselorId,
        'counselor_name': counselorName,
        'unit_name': unitName,
        'slot_label': cleanLabel,
        'consultation_mode': newSlot.consultationMode,
        'is_available': true,
      },
      env: state.backendEnv,
      customContaboUrl: state.contaboBaseUrl,
      headers: {
        if (staffTok != null && staffTok.isNotEmpty)
          'Authorization': 'Bearer $staffTok'
        else
          'X-Staff-Id': counselorId,
      },
    );
    return newSlot;
  }

  bool toggleCounselorSlotAvailability(
    String slotId, {
    required String actorId,
  }) {
    final target =
        state.counselorSlots.where((s) => s.slotId == slotId).firstOrNull;
    if (target == null) return false;
    if (target.counselorId != actorId) {
      recordAuditEvent(
        actor: actorId,
        action: 'UPDATE_COUNSELOR_SLOT_DENIED',
        target: slotId,
        result: 'DENIED_CROSS_COUNSELOR',
      );
      return false;
    }
    final nextAvail = !target.isAvailable;
    final audit = AuditEventModel(
      eventId: 'evt_${_uuid.v4().substring(0, 6)}',
      actor: actorId,
      action: 'UPDATE_COUNSELOR_SLOT ($slotId -> available=$nextAvail)',
      target: slotId,
      result: 'SUCCESS',
      timestamp: DateTime.now(),
    );
    state = state.copyWith(
      counselorSlots: state.counselorSlots
          .map((s) =>
              s.slotId == slotId ? s.copyWith(isAvailable: nextAvail) : s)
          .toList(),
      auditLogs: [audit, ...state.auditLogs],
    );
    final staffTok = state.staffTokens[actorId];
    _api.syncBackgroundPatch(
      '/staff/counselor-slots/$slotId',
      {'is_available': nextAvail},
      env: state.backendEnv,
      customContaboUrl: state.contaboBaseUrl,
      headers: {
        if (staffTok != null && staffTok.isNotEmpty)
          'Authorization': 'Bearer $staffTok'
        else
          'X-Staff-Id': actorId,
      },
    );
    return true;
  }

  bool deleteCounselorSlot(String slotId, {required String actorId}) {
    final target =
        state.counselorSlots.where((s) => s.slotId == slotId).firstOrNull;
    if (target == null) return false;
    if (target.counselorId != actorId) {
      recordAuditEvent(
        actor: actorId,
        action: 'DELETE_COUNSELOR_SLOT_DENIED',
        target: slotId,
        result: 'DENIED_CROSS_COUNSELOR',
      );
      return false;
    }
    final audit = AuditEventModel(
      eventId: 'evt_${_uuid.v4().substring(0, 6)}',
      actor: actorId,
      action: 'DELETE_COUNSELOR_SLOT ($slotId)',
      target: slotId,
      result: 'SUCCESS',
      timestamp: DateTime.now(),
    );
    state = state.copyWith(
      counselorSlots:
          state.counselorSlots.where((s) => s.slotId != slotId).toList(),
      auditLogs: [audit, ...state.auditLogs],
    );
    final staffTok = state.staffTokens[actorId];
    _api.syncBackgroundDelete(
      '/staff/counselor-slots/$slotId',
      env: state.backendEnv,
      customContaboUrl: state.contaboBaseUrl,
      headers: {
        if (staffTok != null && staffTok.isNotEmpty)
          'Authorization': 'Bearer $staffTok'
        else
          'X-Staff-Id': actorId,
      },
    );
    return true;
  }

  // ---------------------------------------------------------------------------
  // A04 (Admin): Quản lý Tài khoản Nhân sự & Đường dây nóng S21
  // ---------------------------------------------------------------------------
  StaffAccountModel? upsertStaffAccount({
    required String staffId,
    required String role,
    required String displayName,
    required String unitName,
    String? password,
    bool isActive = true,
    String adminActor = 'admin_01',
  }) {
    final cleanId = staffId.trim();
    final cleanRole = role.trim().toLowerCase();
    final cleanName = displayName.trim();
    if (cleanId.isEmpty ||
        cleanName.isEmpty ||
        !const ['ctsv', 'counselor', 'admin'].contains(cleanRole)) {
      return null;
    }
    final item = StaffAccountModel(
      staffId: cleanId,
      role: cleanRole,
      displayName: cleanName,
      unitName: unitName.trim().isEmpty
          ? 'Phòng Công tác Sinh viên & Tư vấn'
          : unitName.trim(),
      isActive: isActive,
    );
    final exists = state.staffDirectory.any((s) => s.staffId == cleanId);
    final updatedDir = exists
        ? state.staffDirectory
            .map((s) => s.staffId == cleanId ? item : s)
            .toList()
        : [...state.staffDirectory, item];
    final audit = AuditEventModel(
      eventId: 'evt_${_uuid.v4().substring(0, 6)}',
      actor: adminActor,
      action: 'UPSERT_STAFF_ACCOUNT ($cleanId:$cleanRole)',
      target: cleanId,
      result: 'SUCCESS',
      timestamp: DateTime.now(),
    );
    state = state.copyWith(
      staffDirectory: updatedDir,
      auditLogs: [audit, ...state.auditLogs],
    );
    final adminTok = state.staffTokens[adminActor];
    _api.syncBackgroundPost(
      '/admin/staff-accounts',
      {
        'staff_id': cleanId,
        'role': cleanRole,
        'display_name': cleanName,
        'unit_name': item.unitName,
        if (password != null && password.trim().isNotEmpty)
          'password': password.trim(),
        'is_active': isActive,
      },
      env: state.backendEnv,
      customContaboUrl: state.contaboBaseUrl,
      headers: {
        if (adminTok != null && adminTok.isNotEmpty)
          'Authorization': 'Bearer $adminTok'
        else
          'X-Admin-Actor': adminActor,
      },
    );
    return item;
  }

  void toggleStaffAccountActive(
    String staffId, {
    String adminActor = 'admin_01',
  }) {
    final target =
        state.staffDirectory.where((s) => s.staffId == staffId).firstOrNull;
    if (target == null) return;
    final nextActive = !target.isActive;
    final audit = AuditEventModel(
      eventId: 'evt_${_uuid.v4().substring(0, 6)}',
      actor: adminActor,
      action: 'PATCH_STAFF_ACCOUNT ($staffId:active=$nextActive)',
      target: staffId,
      result: 'SUCCESS',
      timestamp: DateTime.now(),
    );
    state = state.copyWith(
      staffDirectory: state.staffDirectory
          .map((s) =>
              s.staffId == staffId ? s.copyWith(isActive: nextActive) : s)
          .toList(),
      auditLogs: [audit, ...state.auditLogs],
    );
    final adminTok = state.staffTokens[adminActor];
    _api.syncBackgroundPatch(
      '/admin/staff-accounts/$staffId',
      {'is_active': nextActive},
      env: state.backendEnv,
      customContaboUrl: state.contaboBaseUrl,
      headers: {
        if (adminTok != null && adminTok.isNotEmpty)
          'Authorization': 'Bearer $adminTok'
        else
          'X-Admin-Actor': adminActor,
      },
    );
  }

  SafetyHotlineModel? upsertSafetyHotline({
    String? hotlineId,
    required String name,
    required String phone,
    required String description,
    String hours = '24/7',
    String adminActor = 'admin_01',
  }) {
    final cleanName = name.trim();
    final cleanPhone = phone.trim();
    final cleanDesc = description.trim();
    if (cleanName.isEmpty || cleanPhone.isEmpty || cleanDesc.isEmpty) {
      return null;
    }
    final hid = (hotlineId != null && hotlineId.trim().isNotEmpty)
        ? hotlineId.trim()
        : 'hotline_${_uuid.v4().substring(0, 6)}';
    final item = SafetyHotlineModel(
      hotlineId: hid,
      name: cleanName,
      phone: cleanPhone,
      description: cleanDesc,
      hours: hours.trim().isEmpty ? '24/7' : hours.trim(),
      isVerified: true,
    );
    final exists = state.safetyHotlines.any((h) => h.hotlineId == hid);
    final updatedHotlines = exists
        ? state.safetyHotlines
            .map((h) => h.hotlineId == hid ? item : h)
            .toList()
        : [...state.safetyHotlines, item];
    final audit = AuditEventModel(
      eventId: 'evt_${_uuid.v4().substring(0, 6)}',
      actor: adminActor,
      action: 'UPSERT_SAFETY_HOTLINE ($cleanPhone)',
      target: hid,
      result: 'SUCCESS',
      timestamp: DateTime.now(),
    );
    state = state.copyWith(
      safetyHotlines: updatedHotlines,
      auditLogs: [audit, ...state.auditLogs],
    );
    final adminTok = state.staffTokens[adminActor];
    _api.syncBackgroundPost(
      '/admin/safety-hotlines',
      {
        'hotline_id': hid,
        'name': cleanName,
        'phone': cleanPhone,
        'description': cleanDesc,
        'hours': item.hours,
        'is_verified': true,
      },
      env: state.backendEnv,
      customContaboUrl: state.contaboBaseUrl,
      headers: {
        if (adminTok != null && adminTok.isNotEmpty)
          'Authorization': 'Bearer $adminTok'
        else
          'X-Admin-Actor': adminActor,
      },
    );
    return item;
  }

  bool deleteSafetyHotline(String hotlineId, {String adminActor = 'admin_01'}) {
    if (hotlineId == 'hotline_115' || hotlineId == 'hotline_111') {
      return false;
    }
    final audit = AuditEventModel(
      eventId: 'evt_${_uuid.v4().substring(0, 6)}',
      actor: adminActor,
      action: 'DELETE_SAFETY_HOTLINE ($hotlineId)',
      target: hotlineId,
      result: 'SUCCESS',
      timestamp: DateTime.now(),
    );
    state = state.copyWith(
      safetyHotlines: state.safetyHotlines
          .where((h) => h.hotlineId != hotlineId)
          .toList(),
      auditLogs: [audit, ...state.auditLogs],
    );
    final adminTok = state.staffTokens[adminActor];
    _api.syncBackgroundDelete(
      '/admin/safety-hotlines/$hotlineId',
      env: state.backendEnv,
      customContaboUrl: state.contaboBaseUrl,
      headers: {
        if (adminTok != null && adminTok.isNotEmpty)
          'Authorization': 'Bearer $adminTok'
        else
          'X-Admin-Actor': adminActor,
      },
    );
    return true;
  }

  Future<void> refreshPortalDataFromServer({
    String faculty = 'ALL',
    String academicYear = 'ALL',
    String period = 'ALL',
    String? activeCounselorId,
  }) async {
    final analyticsTok =
        state.staffTokens['ctsv_01'] ?? state.staffTokens['admin_01'];
    final overview = await _api.fetchAnalyticsOverview(
      faculty: faculty,
      academicYear: academicYear,
      period: period,
      staffToken: analyticsTok,
      env: state.backendEnv,
      customContaboUrl: state.contaboBaseUrl,
    );
    if (!mounted) return;
    if (overview != null) {
      state = state.copyWith(
        serverAnalytics: overview,
        minGroupSizePolicy: overview.minGroupSize,
      );
    }

    final slots = await _api.fetchCounselorSlots(
      env: state.backendEnv,
      customContaboUrl: state.contaboBaseUrl,
    );
    if (!mounted) return;
    if (slots != null && slots.isNotEmpty) {
      state = state.copyWith(counselorSlots: slots);
    }

    final articles = await _api.fetchKnowledgeArticles(
      env: state.backendEnv,
      customContaboUrl: state.contaboBaseUrl,
    );
    if (!mounted) return;
    if (articles != null && articles.isNotEmpty) {
      state = state.copyWith(articles: articles);
    }

    final hotlines = await _api.fetchSafetyHotlines(
      env: state.backendEnv,
      customContaboUrl: state.contaboBaseUrl,
    );
    if (!mounted) return;
    if (hotlines != null && hotlines.isNotEmpty) {
      state = state.copyWith(safetyHotlines: hotlines);
    }

    final staffList = await _api.fetchAdminStaffAccounts(
      adminToken: state.staffTokens['admin_01'],
      env: state.backendEnv,
      customContaboUrl: state.contaboBaseUrl,
    );
    if (!mounted) return;
    if (staffList != null && staffList.isNotEmpty) {
      state = state.copyWith(staffDirectory: staffList);
    }

    if (activeCounselorId != null && activeCounselorId.isNotEmpty) {
      final assigned = await _api.fetchStaffAssignedBookings(
        counselorId: activeCounselorId,
        staffToken: state.staffTokens[activeCounselorId],
        env: state.backendEnv,
        customContaboUrl: state.contaboBaseUrl,
      );
      if (!mounted) return;
      if (assigned != null && assigned.isNotEmpty) {
        final merged = <String, CounselingBookingModel>{
          for (final b in state.bookings) b.requestId: b,
          for (final b in assigned) b.requestId: b,
        };
        state = state.copyWith(bookings: merged.values.toList());
      }
    }

    final adminData = await _api.fetchAdminPolicyAndAudits(
      adminToken: state.staffTokens['admin_01'],
      env: state.backendEnv,
      customContaboUrl: state.contaboBaseUrl,
    );
    if (!mounted || adminData == null) return;
    final rawLogs = (adminData['audit_events'] ??
        adminData['recent_audit_logs']) as List<dynamic>?;
    if (rawLogs != null && rawLogs.isNotEmpty) {
      final parsedLogs = rawLogs
          .whereType<Map>()
          .map((e) => AuditEventModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      state = state.copyWith(auditLogs: parsedLogs);
    }
  }

  void recordAuditEvent({
    required String actor,
    required String action,
    required String target,
    required String result,
  }) {
    final audit = AuditEventModel(
      eventId: 'evt_${_uuid.v4().substring(0, 6)}',
      actor: actor,
      action: action,
      target: target,
      result: result,
      timestamp: DateTime.now(),
    );
    state = state.copyWith(auditLogs: [audit, ...state.auditLogs]);
  }
}

final mindCheckProvider =
    StateNotifierProvider<MindCheckNotifier, MindCheckAppState>(
  (ref) => MindCheckNotifier(),
);
