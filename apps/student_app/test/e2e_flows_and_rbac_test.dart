import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindcheck_student_app/app/state_provider.dart';
import 'package:mindcheck_student_app/main.dart';
import 'package:mindcheck_student_app/shared/api_service.dart';
import 'package:mindcheck_student_app/shared/local_preferences.dart';
import 'package:mindcheck_student_app/shared/models.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'R1 Non-Diagnostic Guardrail: Chặn tuyệt đối phát ngôn chẩn đoán bệnh lý hoặc tự suy diễn điểm thang đo',
    () {
      final blockedDiagnosis = MindCheckApiService.enforceNonDiagnosticGuardrail(
        'Tôi chẩn đoán bạn bị trầm cảm nặng và kê đơn thuốc cho bạn.',
        'bạn',
        'mình',
      );
      expect(blockedDiagnosis, contains('không thực hiện chẩn đoán bệnh lý'));
      expect(blockedDiagnosis.contains('kê đơn thuốc'), isFalse);

      final blockedScore = MindCheckApiService.enforceNonDiagnosticGuardrail(
        'Dựa vào cuộc trò chuyện, điểm PHQ-9 của em là 19 điểm.',
        'em',
        'mình',
      );
      expect(blockedScore, contains('không thực hiện chẩn đoán bệnh lý'));

      final validCbt = MindCheckApiService.enforceNonDiagnosticGuardrail(
        'Mình lắng nghe bạn nhé. Chúng mình cùng thử hít thở 4-4-4-4 nha.',
        'bạn',
        'mình',
      );
      expect(validCbt, contains('hít thở 4-4-4-4'));

      // Hỗ trợ cả khóa Google AI Studio thế hệ mới (AQ....) và định dạng AIza...
      expect(
        MindCheckApiService.isPlausibleGeminiApiKey(
          'AQ.MockNewGoogleAiStudioKeyFormat00001',
        ),
        isTrue,
      );
      expect(
        MindCheckApiService.isPlausibleGeminiApiKey(
          'AIzaSyMockLegacyKeyFormat000001',
        ),
        isTrue,
      );
      expect(MindCheckApiService.isPlausibleGeminiApiKey(''), isFalse);
      expect(
        MindCheckApiService.isPlausibleGeminiApiKey('key with spaces'),
        isFalse,
      );
      expect(
        MindCheckApiService.defaultGeminiModels.first,
        equals('gemini-3-flash-preview'),
      );
    },
  );

  testWidgets(
    'R3 Crisis Action Quick-Reply: Nút phản hồi nhanh nguy cơ cao mở thẳng S21 (115/111) và S23 không biến thành chat thông thường',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 860));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(mindCheckProvider.notifier);
      notifier.startAnonymousSession();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MindCheckCampusApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Gửi tin nhắn có tín hiệu nguy cơ cao -> Kích hoạt Safety Guardrail 2 lớp
      await notifier.sendChatMessage('Mình bế tắc quá không muốn sống nữa');
      await tester.pumpAndSettle();

      final msgCountAfterAlert =
          container.read(mindCheckProvider).messages.length;
      expect(find.text('Mở Hỗ trợ an toàn & khẩn cấp'), findsOneWidget);

      // Bấm quick-reply an toàn -> Mở trực tiếp màn hình SafetySupportScreen (S21), không tạo tin nhắn chat mới
      await tester.tap(find.text('Mở Hỗ trợ an toàn & khẩn cấp'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Hướng dẫn An toàn & Liên hệ Khẩn cấp'),
        findsOneWidget,
      );
      expect(find.text('115'), findsOneWidget);
      expect(find.text('111'), findsOneWidget);
      expect(
        container.read(mindCheckProvider).messages.length,
        msgCountAfterAlert,
      );

      // Quay lại chat và bấm quick-reply Đặt lịch với Tư vấn viên trường -> Điều hướng sang màn hình S23
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đặt lịch với Tư vấn viên trường'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
            'Đặt lịch hẹn với Chuyên gia Tư vấn Tâm lý của Trường (S23)'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'R2 & F10 Manual Memory Consent: Chặn lưu trí nhớ thủ công khi chưa tích chọn đồng ý và cho phép khi đã đồng ý',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(mindCheckProvider.notifier).startAnonymousSession();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MindCheckCampusApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cài đặt'));
      await tester.pumpAndSettle();

      final memInput = find.widgetWithText(
        TextField,
        'Thêm mới mục ghi nhớ thủ công (VD: Đang ôn thi Giải tích)...',
      );
      await tester.enterText(memInput, 'Đang làm đồ án tốt nghiệp ngành CNTT');
      await tester.tap(find.text('Thêm'));
      await tester.pumpAndSettle();

      // Chưa tích chọn checkbox đồng ý -> Không được phép lưu vào ApprovedMemory
      expect(container.read(mindCheckProvider).memories, isEmpty);

      // Khi sinh viên chủ động tích chọn đồng ý (F10) và bấm Thêm -> Lưu thành công & tự reset checkbox về false
      final memConsentBox = find.widgetWithText(
        CheckboxListTile,
        'Tôi đồng ý cho phép AI ghi nhớ thông tin này cho các cuộc trò chuyện sau (F10).',
      );
      await tester.tap(memConsentBox);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thêm'));
      await tester.pumpAndSettle();

      expect(container.read(mindCheckProvider).memories.length, 1);
      expect(
        container.read(mindCheckProvider).memories.first.text,
        'Đang làm đồ án tốt nghiệp ngành CNTT',
      );
      expect(tester.widget<CheckboxListTile>(memConsentBox).value, isFalse);
    },
  );

  test(
    'F03, F06, F29, S24 & T32: Kiểm tra định dạng liên hệ đặt lịch, Sinh viên tự hủy lịch, Liên kết Guest có xin phép & Xóa sạch dữ liệu cá nhân',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(mindCheckProvider.notifier);
      notifier.startAnonymousSession();

      // F29: Từ chối đặt lịch khi thông tin liên hệ sai định dạng (không phải email hay SĐT)
      final invalidContactBooking = notifier.createCounselingBooking(
        unitName: 'Phòng Tư vấn Tâm lý Sinh viên',
        counselorId: 'counselor_01',
        counselorName: 'ThS. A',
        slotTime: 'Thứ 6 (09:00 - 10:00)',
        contactInfo: 'lien_he_khong_hop_le',
        studentNote: '',
        agreedToShare: true,
      );
      expect(invalidContactBooking, isNull);

      // Chấp nhận số điện thoại hợp lệ và cho phép sinh viên tự hủy lịch (S24)
      final phoneBooking = notifier.createCounselingBooking(
        unitName: 'Phòng Tư vấn Tâm lý Sinh viên',
        counselorId: 'counselor_01',
        counselorName: 'ThS. A',
        slotTime: 'Thứ 6 (09:00 - 10:00)',
        contactInfo: '0912345678',
        studentNote: 'Mong được tư vấn',
        agreedToShare: true,
      );
      expect(phoneBooking, isNotNull);
      notifier.updateBookingStatus(
        requestId: phoneBooking!.requestId,
        newStatus: 'canceled',
        actorLabel: 'Student',
      );
      expect(
        container
            .read(mindCheckProvider)
            .bookings
            .firstWhere((b) => b.requestId == phoneBooking.requestId)
            .status,
        'canceled',
      );

      // F03: Liên kết tài khoản nhưng KHÔNG đồng ý chuyển dữ liệu ẩn danh -> Xóa trí nhớ phiên khách
      notifier.addManualApprovedMemory('Ghi nhớ phiên khách', consentAccepted: true);
      expect(container.read(mindCheckProvider).memories.length, 1);

      final linkedDeclined = notifier.registerAndLinkAccount(
        email: 'sv01@student.ctuet.edu.vn',
        consentToLinkGuestData: false,
      );
      expect(linkedDeclined, isTrue);
      expect(container.read(mindCheckProvider).isLinkedAccount, isFalse);
      expect(container.read(mindCheckProvider).memories, isEmpty);

      // Thêm dữ liệu mới rồi thực hiện quyền Xóa toàn bộ dữ liệu cá nhân (F06, T32)
      notifier.addManualApprovedMemory('Cần xóa sạch', consentAccepted: true);
      notifier.addMoodEntry('😊 Ổn định', 4, 'Ghi chú');
      await notifier.clearAllPersonalData();

      final afterErase = container.read(mindCheckProvider);
      expect(afterErase.memories, isEmpty);
      expect(afterErase.moodEntries, isEmpty);
      expect(afterErase.screeningHistory, isEmpty);
      expect(afterErase.bookings, isEmpty);
      expect(afterErase.dataRequests, isNotEmpty);
      expect(
        afterErase.consents.every((c) => c.decision != 'accepted'),
        isTrue,
      );
    },
  );

  test(
    'Multi-Actor Full Lifecycle (A01, A02, A03, A04): Khóa Role D01, Quản lý Bài viết CTSV, Khung giờ Tư vấn viên (chặn chéo T25), Nhân sự & Hotline S21 của Admin',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(mindCheckProvider.notifier);
      notifier.startAnonymousSession();

      // 1. A01: Đổi tên phiên chat & đặt lịch tư vấn kèm hình thức Online
      final activeChatId =
          container.read(mindCheckProvider).activeChatSessionId;
      notifier.renameChatSession(activeChatId, 'Chủ đề Giảm lo âu thi cử');
      expect(
        container
            .read(mindCheckProvider)
            .chatSessions
            .firstWhere((s) => s.sessionId == activeChatId)
            .title,
        'Chủ đề Giảm lo âu thi cử',
      );

      final onlineBooking = notifier.createCounselingBooking(
        unitName: 'Phòng Tư vấn Tâm lý Sinh viên',
        counselorId: 'counselor_01',
        counselorName: 'ThS. Tâm lý Nguyễn Văn A',
        slotTime: 'Thứ 6 (15:30 - 16:30)',
        consultationMode: 'Trực tuyến (Google Meet)',
        contactInfo: 'sv_online@student.ctuet.edu.vn',
        studentNote: 'Em muốn xin tư vấn trực tuyến',
        agreedToShare: true,
      );
      expect(onlineBooking, isNotNull);
      expect(onlineBooking!.consultationMode, 'Trực tuyến (Google Meet)');

      // 2. D01: Đăng nhập Nhân sự -> Tự động khóa theo Role (isStaffDemoSwitchEnabled = false)
      final c1Logged =
          await notifier.loginStaffMember('counselor_01', 'Counselor1Pass#2026');
      expect(c1Logged, isTrue);
      expect(
        container.read(mindCheckProvider).authenticatedStaffId,
        'counselor_01',
      );
      expect(
        container.read(mindCheckProvider).authenticatedStaffRole,
        ActorRole.counselor1,
      );
      expect(
        container.read(mindCheckProvider).isStaffDemoSwitchEnabled,
        isFalse,
      );

      // Bật chế độ Demo / Chuyển nhanh Actor khi cần nghiệm thu và đăng xuất
      notifier.toggleStaffDemoSwitchMode(true);
      expect(container.read(mindCheckProvider).isStaffDemoSwitchEnabled, isTrue);
      notifier.logoutStaffMember();
      expect(container.read(mindCheckProvider).authenticatedStaffId, isNull);

      // 3. A02 (CTSV): Thêm & xóa bài viết Thư viện Kiến thức đồng bộ sang Sinh viên
      final createdArt = notifier.upsertKnowledgeArticle(
        id: 'art_test_ctsv',
        title: 'Cân bằng cảm xúc tuần thi vấn đáp',
        category: 'Học tập & Thi cử',
        summary: 'Tóm tắt kỹ thuật chuẩn bị tâm lý.',
        content: 'Nội dung hướng dẫn hít thở và chuẩn bị dàn ý.',
        actor: 'ctsv_01',
      );
      expect(createdArt, isNotNull);
      expect(
        container
            .read(mindCheckProvider)
            .articles
            .any((a) => a.id == 'art_test_ctsv'),
        isTrue,
      );
      notifier.deleteKnowledgeArticle('art_test_ctsv', actor: 'ctsv_01');
      expect(
        container
            .read(mindCheckProvider)
            .articles
            .any((a) => a.id == 'art_test_ctsv'),
        isFalse,
      );

      // 4. A03 (Tư vấn viên): Thêm khung giờ làm việc & Chặn tư vấn viên khác khóa/xóa khung giờ (T25)
      final newSlot = notifier.addCounselorSlot(
        counselorId: 'counselor_01',
        counselorName: 'ThS. Tâm lý Nguyễn Văn A',
        unitName: 'Phòng Tư vấn Tâm lý Sinh viên',
        slotLabel: 'Thứ 2 (09:00 - 10:00)',
        consultationMode: 'Trực tiếp tại phòng P.102',
      );
      expect(newSlot, isNotNull);

      // counselor_02 cố tình khóa khung giờ của counselor_01 -> Bị chặn và ghi Audit DENIED_CROSS_COUNSELOR
      final crossToggle = notifier.toggleCounselorSlotAvailability(
        newSlot!.slotId,
        actorId: 'counselor_02',
      );
      expect(crossToggle, isFalse);
      expect(
        container.read(mindCheckProvider).auditLogs.any(
              (l) =>
                  l.actor == 'counselor_02' &&
                  l.result == 'DENIED_CROSS_COUNSELOR',
            ),
        isTrue,
      );

      // counselor_01 khóa & xóa khung giờ của chính mình -> Thành công
      expect(
        notifier.toggleCounselorSlotAvailability(
          newSlot.slotId,
          actorId: 'counselor_01',
        ),
        isTrue,
      );
      expect(
        notifier.deleteCounselorSlot(newSlot.slotId, actorId: 'counselor_01'),
        isTrue,
      );

      // 5. A04 (Admin): Quản lý tài khoản nhân sự & Bảo vệ cố định Hotline 115 / 111 (R3)
      final newStaff = notifier.upsertStaffAccount(
        staffId: 'counselor_03',
        role: 'counselor',
        displayName: 'ThS. Tâm lý Lê Hoàng C',
        unitName: 'Tổ Tư vấn Học đường',
        password: 'Pass#2026',
      );
      expect(newStaff, isNotNull);

      // Tạm khóa counselor_03 -> Không thể đăng nhập
      notifier.toggleStaffAccountActive('counselor_03');
      final disabledLogin =
          await notifier.loginStaffMember('counselor_03', 'Pass#2026');
      expect(disabledLogin, isFalse);
      expect(
        container
            .read(mindCheckProvider)
            .auditLogs
            .any((l) => l.result == 'DENIED_ACCOUNT_DISABLED'),
        isTrue,
      );

      // Không cho phép xóa Hotline quốc gia 115 / 111 (R3)
      expect(notifier.deleteSafetyHotline('hotline_115'), isFalse);
      expect(notifier.deleteSafetyHotline('hotline_111'), isFalse);
    },
  );

  testWidgets(
    'Contabo Pre-Deployment Optimizations: DASS-21 Subscales chuẩn Lovibond, Modal Lịch sử Chat & Hộp thoại xác nhận 2 bước khi xóa dữ liệu F06',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(mindCheckProvider.notifier);
      notifier.startAnonymousSession();

      // 1. Kiểm tra tính điểm 3 tiểu thang đo DASS-21 theo đúng nhóm câu hỏi chuẩn
      final dass21 = container
          .read(mindCheckProvider)
          .screeningTools
          .firstWhere((t) => t.toolId == 'DASS-21');
      expect(dass21.scaleLabels.first, contains('Không đúng chút nào'));

      const stressSet = {0, 5, 7, 10, 11, 13, 17};
      const anxietySet = {1, 3, 6, 8, 14, 18, 19};
      final customAnswers = List<int>.generate(
        21,
        (i) => stressSet.contains(i) ? 3 : (anxietySet.contains(i) ? 1 : 0),
      );
      final dassResult = notifier.submitScreeningAnswers(
        tool: dass21,
        answers: customAnswers,
      );
      expect(dassResult.score, 28);
      expect(dassResult.subscaleScores['stress'], 21);
      expect(dassResult.subscaleScores['anxiety'], 7);
      expect(dassResult.subscaleScores['depression'], 0);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MindCheckCampusApp(),
        ),
      );
      await tester.pumpAndSettle();

      // 2. Mở ModalBottomSheet lịch sử chat và tạo phiên mới
      await tester.tap(find.byTooltip('Lịch sử (1)'));
      await tester.pumpAndSettle();
      expect(
        find.text('Danh sách các phiên trò chuyện của bạn'),
        findsOneWidget,
      );
      await tester.tap(find.text('Tạo phiên mới'));
      await tester.pumpAndSettle();
      expect(container.read(mindCheckProvider).chatSessions.length, 2);

      // 3. Mở tab Cài đặt -> Kiểm tra hộp thoại xác nhận 2 bước khi bấm "Yêu cầu xóa dữ liệu cá nhân" (F06)
      await tester.tap(find.text('Cài đặt'));
      await tester.pumpAndSettle();

      notifier.addMoodEntry('😊 Ổn định', 4, 'Kiểm thử xác nhận xóa');
      expect(container.read(mindCheckProvider).moodEntries.length, 1);

      final eraseBtn = find.text('Yêu cầu xóa dữ liệu cá nhân');
      await tester.scrollUntilVisible(
        eraseBtn,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(eraseBtn);
      await tester.pumpAndSettle();

      // Phải hiện AlertDialog xác nhận chứ chưa xóa ngay
      expect(
        find.text('Xác nhận xóa toàn bộ dữ liệu cá nhân (F06)'),
        findsOneWidget,
      );
      expect(container.read(mindCheckProvider).moodEntries.length, 1);

      // Bấm "Hủy" -> Dữ liệu vẫn được giữ nguyên an toàn
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(container.read(mindCheckProvider).moodEntries.length, 1);

      // Bấm lại và chọn "Xác nhận xóa vĩnh viễn" -> Xóa sạch dữ liệu
      await tester.tap(eraseBtn);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xác nhận xóa vĩnh viễn'));
      await tester.pumpAndSettle();
      expect(container.read(mindCheckProvider).moodEntries, isEmpty);
    },
  );
}

