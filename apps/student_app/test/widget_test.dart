import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindcheck_student_app/app/state_provider.dart';
import 'package:mindcheck_student_app/main.dart';
import 'package:mindcheck_student_app/shared/local_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'T01, T02 & T18: Onboarding không mặc định đồng ý chính sách (T02) và mở Hỗ trợ an toàn S21 không cần login (T18)',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(const ProviderScope(child: MindCheckCampusApp()));

      // T18: Kiểm tra hiển thị màn hình S01 và nút Hỗ trợ an toàn (S21) luôn truy cập được không cần login
      expect(find.textContaining('MindCheck Campus 2.0'), findsWidgets);
      expect(find.text('Hỗ trợ an toàn (S21)'), findsOneWidget);

      await tester.tap(find.text('Hỗ trợ an toàn (S21)'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Hướng dẫn An toàn & Liên hệ Khẩn cấp'),
        findsOneWidget,
      );
      expect(find.text('115'), findsOneWidget);
      expect(find.text('111'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      // T02: Đi tới bước Chính sách bảo mật (S03) và kiểm tra Checkbox mặc định = false
      await tester.tap(
        find.text('Bắt đầu tìm hiểu & Thiết lập quyền riêng tư'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tiếp tục: Chính sách bảo mật'));
      await tester.pumpAndSettle();

      final checkbox = tester.widget<CheckboxListTile>(
        find.byType(CheckboxListTile),
      );
      expect(checkbox.value, isFalse);

      final nextBtnBefore = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Tiếp tục cá nhân hóa AI'),
      );
      expect(nextBtnBefore.onPressed, isNull);

      // Khi sinh viên chủ động tích chọn đồng ý -> nút Tiếp tục được kích hoạt (T01, T02)
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tiếp tục cá nhân hóa AI'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bắt đầu trò chuyện ẩn danh ngay'));
      await tester.pumpAndSettle();
      expect(find.textContaining('MindCheck •'), findsWidgets);
    },
  );

  test(
    'T05 & T06: Kiểm thử chống nhân đôi tin nhắn Idempotency (T05) và Xử lý lỗi mạng Offline + Retry (T06)',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(mindCheckProvider.notifier);
      notifier.startAnonymousSession();

      // T06: Bật chế độ giả lập mất mạng Offline -> Gửi tin nhắn sẽ ở trạng thái 'failed'
      notifier.toggleOfflineSimulation(true);
      const clientMsgId = 'msg_client_idempotent_001';
      await notifier.sendChatMessage(
        'Em đang rất lo lắng về kỳ thi sắp tới.',
        customClientMsgId: clientMsgId,
      );

      final failedMsg = container
          .read(mindCheckProvider)
          .messages
          .firstWhere((m) => m.messageId == clientMsgId);
      expect(failedMsg.state, 'failed');

      // T06 & T05: Bấm Retry gửi lại với đúng client_message_id -> chuyển thành 'delivered', không tạo bản ghi user trùng
      await notifier.retryFailedMessage(clientMsgId);

      final allWithSameId = container
          .read(mindCheckProvider)
          .messages
          .where((m) => m.messageId == clientMsgId)
          .toList();
      expect(allWithSameId.length, 1);
      expect(allWithSameId.first.state, 'delivered');

      // T05: Gọi lại sendChatMessage với cùng customClientMsgId đã xử lý -> bị chặn chống nhân đôi
      final countBeforeDuplicate =
          container.read(mindCheckProvider).messages.length;
      await notifier.sendChatMessage(
        'Em đang rất lo lắng về kỳ thi sắp tới.',
        customClientMsgId: clientMsgId,
      );
      expect(
        container.read(mindCheckProvider).messages.length,
        countBeforeDuplicate,
      );
    },
  );

  test(
    'T07, T08, T09, T14–T16, T20–T22: Vòng đời Trí nhớ AI, Sàng lọc có xin phép & Đặt lịch đồng bộ',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(mindCheckProvider.notifier);
      notifier.startAnonymousSession();

      // Gửi tin nhắn có từ khóa mệt mỏi/mất ngủ để sinh MemoryProposal
      await notifier.sendChatMessage(
        'Dạ khá mệt, gần đây em ngủ không ngon giấc ạ.',
      );
      final lastMsg = container.read(mindCheckProvider).messages.last;
      expect(lastMsg.memoryProposal, isNotNull);

      // T07: Từ chối lưu trí nhớ -> Không tạo ApprovedMemory
      notifier.respondToMemoryProposal(
        lastMsg.messageId,
        lastMsg.memoryProposal!,
        false,
      );
      expect(container.read(mindCheckProvider).memories.isEmpty, true);

      // T08: Đồng ý lưu trí nhớ & chỉnh sửa nội dung -> Cập nhật đúng bản ghi ApprovedMemory
      notifier.respondToMemoryProposal(
        lastMsg.messageId,
        lastMsg.memoryProposal!,
        true,
      );
      expect(container.read(mindCheckProvider).memories.length, 1);

      final memId = container.read(mindCheckProvider).memories.first.memoryId;
      notifier.editApprovedMemory(
          memId, 'Đang ôn thi học kỳ và cần ngủ đủ giấc');
      expect(
        container.read(mindCheckProvider).memories.first.text,
        'Đang ôn thi học kỳ và cần ngủ đủ giấc',
      );

      // T09: Xóa trí nhớ -> Loại bỏ khỏi danh sách
      notifier.deleteApprovedMemory(memId);
      expect(container.read(mindCheckProvider).memories.isEmpty, true);

      // T14–T16: Ghi nhận từ chối sàng lọc -> Không có kết quả sàng lọc nào bị tính điểm
      notifier.recordScreeningConsent(false);
      expect(
        container
            .read(mindCheckProvider)
            .consents
            .firstWhere((c) => c.purpose == 'screening')
            .decision,
        'declined',
      );
      expect(container.read(mindCheckProvider).screeningHistory.isEmpty, true);

      // Khi đồng ý và hoàn thành bài sàng lọc GAD-7 -> Chấm điểm Rule-based chuẩn, không gắn cờ demo
      notifier.recordScreeningConsent(true);
      final gad7 = container.read(mindCheckProvider).screeningTools.first;
      final screeningRes = notifier.submitScreeningAnswers(
        tool: gad7,
        answers: const [2, 2, 2, 1, 2, 2, 2],
      );
      expect(screeningRes.score, 13);
      expect(screeningRes.demoFlag, isFalse);
      expect(screeningRes.isClinicalDiagnosis, isFalse);
      expect(screeningRes.fourWeekTrend.length, 1);
      expect(container.read(mindCheckProvider).screeningHistory.length, 1);

      // Lượt sàng lọc thứ 2 cùng công cụ -> fourWeekTrend tự nối thêm điểm thật (2 điểm)
      final secondRes = notifier.submitScreeningAnswers(
        tool: gad7,
        answers: const [1, 1, 1, 1, 1, 1, 1],
      );
      expect(secondRes.fourWeekTrend.length, 2);

      // T20: Đặt lịch khi từ chối chia sẻ thông tin -> Chặn tạo yêu cầu
      final blockedBooking = notifier.createCounselingBooking(
        unitName: 'Phòng Tư vấn Tâm lý Sinh viên',
        counselorId: 'counselor_01',
        counselorName: 'ThS. A',
        slotTime: 'Thứ 5 (14:00 - 15:00)',
        contactInfo: 'sv@student.ctuet.edu.vn',
        studentNote: '',
        agreedToShare: false,
      );
      expect(blockedBooking, isNull);

      // T21 & T22: Đặt lịch khi đồng ý -> Tạo yêu cầu pending và đồng bộ kèm ghi chú khi Tư vấn viên duyệt
      final validBooking = notifier.createCounselingBooking(
        unitName: 'Phòng Tư vấn Tâm lý Sinh viên',
        counselorId: 'counselor_01',
        counselorName: 'ThS. A',
        slotTime: 'Thứ 5 (14:00 - 15:00)',
        contactInfo: 'sv@student.ctuet.edu.vn',
        studentNote: 'Cần hỗ trợ giảm căng thẳng thi cử',
        agreedToShare: true,
      );
      expect(validBooking, isNotNull);
      expect(validBooking!.status, 'pending');

      notifier.updateBookingStatus(
        requestId: validBooking.requestId,
        newStatus: 'confirmed',
        actorLabel: 'counselor_01',
        counselorNote: 'Đã xếp lịch tại Phòng P.102',
      );
      final synced = container
          .read(mindCheckProvider)
          .bookings
          .firstWhere((b) => b.requestId == validBooking.requestId);
      expect(synced.status, 'confirmed');
      expect(synced.counselorNote, 'Đã xếp lịch tại Phòng P.102');
    },
  );

  testWidgets(
    'T13, T14–T16, T24 & T25: Kiểm thử Tổng kết tuần < 3 bản ghi (T13), Thoát sàng lọc (T16), Ẩn nhóm nhỏ k-Anonymity thực tế (T24) và Chặn truy cập chéo Tư vấn viên (T25)',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1366, 920));
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

      // T13 (0 bản ghi): Mở tab Cảm xúc khi chưa có dữ liệu check-in -> Báo rõ chưa có dữ liệu trong tuần
      await tester.tap(find.text('Cảm xúc'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.textContaining('Nhật ký cảm xúc & Tổng kết tuần'),
        220,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Chưa có dữ liệu check-in trong tuần này'),
        findsOneWidget,
      );

      // T13 (2 bản ghi < 3): Báo rõ chưa đủ dữ liệu tổng kết tuần (2/3)
      notifier.addMoodEntry('😊 Ổn định', 4, 'Ngày 1');
      notifier.addMoodEntry('🌟 Rất tích cực', 5, 'Ngày 2');
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Chưa đủ dữ liệu tổng kết tuần (hiện có 2/3 lần check-in)'),
        findsOneWidget,
      );

      // T13 (3 bản ghi >= 3): Hiển thị đầy đủ Tổng kết tuần trên thang /5.0
      notifier.addMoodEntry('😐 Hơi mệt', 3, 'Ngày 3');
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Tổng kết tuần: Bạn đã thực hiện 3 lần check-in cảm xúc'),
        findsOneWidget,
      );
      expect(find.text('4.0/5.0'), findsOneWidget);

      // T14–T16: Mở tab Sàng lọc -> Tìm hiểu -> Đồng ý -> Thoát giữa chừng không chấm điểm & không hiện nút demo
      await tester.tap(find.text('Sàng lọc'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tìm hiểu & Thực hiện').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đồng ý & Bắt đầu trả lời'));
      await tester.pumpAndSettle();
      expect(find.text('Điền nhanh mẫu thử nghiệm'), findsNothing);
      await tester.tap(find.text('Thoát bảng hỏi'));
      await tester.pumpAndSettle();
      expect(
        find.text('Chưa có lượt sàng lọc nào được lưu.'),
        findsOneWidget,
      );

      // Tạo 1 lịch hẹn thực cho counselor_01 để kiểm thử chặn chéo RBAC (T25)
      notifier.createCounselingBooking(
        unitName: 'Phòng Tư vấn Tâm lý Sinh viên',
        counselorId: 'counselor_01',
        counselorName: 'ThS. Tâm lý Nguyễn Văn A',
        slotTime: 'Thứ 4 (09:00 - 10:00)',
        contactInfo: 'sv_thucte@student.ctuet.edu.vn',
        studentNote: 'Xin tư vấn kỹ năng quản lý áp lực thi học kỳ.',
        agreedToShare: true,
      );

      // Mở Cổng Web Nhà trường (D01–D07)
      await tester.tap(find.byTooltip('Cổng Web Nhà trường & Tư vấn viên'));
      await tester.pumpAndSettle();

      // T24 (n = 0 < min_group_size = 10): Mặc định khóa hiển thị biểu đồ k-Anonymity (không dùng số giả 1.284)
      expect(
        find.textContaining('Đã khóa hiển thị biểu đồ để bảo vệ quyền riêng tư'),
        findsOneWidget,
      );

      // Khi phát sinh đủ 12 lượt sàng lọc thực tế (n = 12 >= 10) -> Mở khóa KPI thực tế
      final gad7 = container.read(mindCheckProvider).screeningTools.first;
      for (int i = 0; i < 12; i++) {
        notifier.submitScreeningAnswers(
          tool: gad7,
          answers: const [1, 1, 1, 0, 1, 0, 1],
          facultyOverride: 'CNTT',
        );
      }
      await tester.pumpAndSettle();
      expect(find.text('Tổng lượt sàng lọc tự nguyện'), findsOneWidget);
      expect(find.text('12'), findsWidgets);

      // Khi Quản trị viên nâng ngưỡng min_group_size lên 15 -> n = 12 < 15 tự động bị khóa lại!
      final adminChip = find.text(
        'A04 • Quản trị viên Hệ thống (RBAC & k-Anonymity Policy)',
      );
      await tester.ensureVisible(adminChip);
      await tester.pumpAndSettle();
      await tester.tap(adminChip);
      await tester.pumpAndSettle();

      final portalScrollable = find.byType(Scrollable).first;

      final policy15Chip = find.text('Ngưỡng chuẩn 15 SV');
      await tester.scrollUntilVisible(
        policy15Chip,
        220,
        scrollable: portalScrollable,
      );
      await tester.pumpAndSettle();
      await tester.tap(policy15Chip);
      await tester.pumpAndSettle();

      final ctsvChip = find.text(
        'A02 • Nhân viên CTSV (Dashboard Tổng hợp Ẩn danh)',
      );
      await tester.scrollUntilVisible(
        ctsvChip,
        -220,
        scrollable: portalScrollable,
      );
      await tester.pumpAndSettle();
      await tester.tap(ctsvChip);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Đã khóa hiển thị biểu đồ để bảo vệ quyền riêng tư'),
        findsOneWidget,
      );

      // T25: Chuyển sang Tư vấn viên 2 (counselor_02) -> Ca của counselor_01 bị chặn FORBIDDEN và ghi Audit Log
      final counselor2Chip = find.text(
        'A03 • Tư vấn viên 2: ThS. Trần Thị B (Test chặn chéo T25)',
      );
      await tester.scrollUntilVisible(
        counselor2Chip,
        -180,
        scrollable: portalScrollable,
      );
      await tester.pumpAndSettle();
      await tester.tap(counselor2Chip);
      await tester.pumpAndSettle();
      expect(find.textContaining('FORBIDDEN (T25)'), findsOneWidget);

      final forbiddenTestBtn = find.text('Thử mở hồ sơ (Test T25)');
      await tester.scrollUntilVisible(
        forbiddenTestBtn,
        180,
        scrollable: portalScrollable,
      );
      await tester.pumpAndSettle();
      await tester.tap(forbiddenTestBtn);
      await tester.pumpAndSettle();
      expect(
        container.read(mindCheckProvider).auditLogs.any(
              (log) =>
                  log.actor == 'counselor_02' &&
                  log.result == 'DENIED_FORBIDDEN',
            ),
        isTrue,
      );
    },
  );
}
