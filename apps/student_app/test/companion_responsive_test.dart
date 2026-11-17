import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindcheck_student_app/app/state_provider.dart';
import 'package:mindcheck_student_app/main.dart';
import 'package:mindcheck_student_app/shared/local_preferences.dart';
import 'package:mindcheck_student_app/shared/models.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'Digital Companion Engine: Đa chủ đề CBT tiếng Việt, cá nhân hóa xưng hô & Safety Guardrail không dấu chuẩn xác',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(mindCheckProvider.notifier);
      notifier.startAnonymousSession();
      notifier.updateCompanionPreference(
        const CompanionPreference(
          nickname: 'Bạn Nhỏ',
          userPronoun: 'em',
          aiPronoun: 'mình',
          tone: 'ấm áp, gần gũi',
        ),
      );

      // 1. Kiểm tra không báo động giả (No false positive) với cụm từ "từ từ" trong bài tập thở
      await notifier.sendChatMessage(
        'Em đang tập hít vào nhẹ và thở ra tu tu nhưng tim vẫn hơi đập nhanh.',
      );
      final breathingReply = container.read(mindCheckProvider).messages.last;
      expect(breathingReply.suggestedAction == 'open_safety_support', isFalse);
      expect(breathingReply.text.toLowerCase(), contains('mình'));

      // 2. Kiểm tra chủ đề cô đơn / nhớ nhà của sinh viên
      await notifier.sendChatMessage(
        'Hôm nay ở ký túc xá em thấy cô đơn và lạc lõng quá.',
      );
      final lonelyReply = container.read(mindCheckProvider).messages.last;
      expect(lonelyReply.suggestedAction == 'open_safety_support', isFalse);
      expect(lonelyReply.text, isNotEmpty);

      // 3. Kiểm tra phát hiện nguy cơ cao tiếng Việt KHÔNG DẤU (R3 Safety Layer)
      await notifier.sendChatMessage(
        'Em be tac qua khong muon song nua',
      );
      final crisisReply = container.read(mindCheckProvider).messages.last;
      expect(crisisReply.suggestedAction, 'open_safety_support');
      expect(crisisReply.providerBadge, contains('Safety Guardrail'));
    },
  );

  test(
    'Clinical Screening Accuracy (R1, R3): DASS-21 chuẩn 21 câu, điểm thấp tích cực & Câu số 9 PHQ-9 >= 1 kích hoạt cảnh báo an toàn 115/111',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(mindCheckProvider.notifier);
      notifier.recordScreeningConsent(true);

      final dass21 = container
          .read(mindCheckProvider)
          .screeningTools
          .firstWhere((t) => t.toolId == 'DASS-21');
      expect(dass21.questions.length, 21);
      final dassRes = notifier.submitScreeningAnswers(
        tool: dass21,
        answers: List<int>.filled(21, 1),
      );
      expect(dassRes.maxScore, 63);
      expect(dassRes.score, 21);
      expect(dassRes.demoFlag, isFalse);

      final phq9 = container
          .read(mindCheckProvider)
          .screeningTools
          .firstWhere((t) => t.toolId == 'PHQ-9');

      // Trường hợp 1: Tổng điểm thấp (2/27) và câu 9 = 0 -> Không cảnh báo nguy cơ cao
      final lowRes = notifier.submitScreeningAnswers(
        tool: phq9,
        answers: const [1, 0, 1, 0, 0, 0, 0, 0, 0],
      );
      expect(lowRes.score, 2);
      expect(lowRes.requiresAttention, isFalse);
      expect(lowRes.levelLabel, contains('tối thiểu'));

      // Trường hợp 2: Tổng điểm thấp (1/27) NHƯNG câu số 9 (ý nghĩ tự hại) = 1 -> Bắt buộc requiresAttention = true + 115/111 (R3)
      final item9AlertRes = notifier.submitScreeningAnswers(
        tool: phq9,
        answers: const [0, 0, 0, 0, 0, 0, 0, 0, 1],
      );
      expect(item9AlertRes.score, 1);
      expect(item9AlertRes.requiresAttention, isTrue);
      expect(item9AlertRes.interpretation, contains('115'));
      expect(item9AlertRes.interpretation, contains('111'));
    },
  );

  testWidgets(
    'Responsive UI/UX (360px Mobile -> 820px Tablet -> 1366px Desktop) & Tuân thủ R2 (Toàn bộ Checkbox không mặc định tích sẵn)',
    (WidgetTester tester) async {
      final viewports = <Size>[
        const Size(360, 780), // Compact Android Phone
        const Size(390, 844), // Standard Mobile
        const Size(820, 1180), // Tablet Portrait
        const Size(1366, 900), // Desktop Web
      ];

      for (final size in viewports) {
        await tester.binding.setSurfaceSize(size);

        final container = ProviderContainer();
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MindCheckCampusApp(
              key: ValueKey('app_${size.width}x${size.height}'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Kiểm tra Onboarding S01 không tràn giao diện ở mọi kích thước
        expect(find.textContaining('MindCheck Campus 2.0'), findsWidgets);

        // Chuyển thẳng vào phiên ẩn danh để kiểm tra toàn bộ 5 phân hệ & Cổng nhà trường
        container.read(mindCheckProvider.notifier).startAnonymousSession();
        await tester.pumpAndSettle();

        // Tab 2: Cảm xúc & Grounding 5-4-3-2-1
        await tester.tap(find.text('Cảm xúc').first);
        await tester.pumpAndSettle();
        final groundingFinder = find.text('Thực hành Grounding 5-4-3-2-1');
        await tester.scrollUntilVisible(
          groundingFinder,
          180,
          scrollable: find.byType(Scrollable).first,
        );
        expect(groundingFinder, findsOneWidget);

        // Tab 3: Sàng lọc
        await tester.tap(find.text('Sàng lọc').first);
        await tester.pumpAndSettle();

        // Tab 4: Tư vấn & Kiểm tra R2 (_consentShareBooking mặc định = false)
        await tester.tap(find.text('Tư vấn').first);
        await tester.pumpAndSettle();
        final bookingConsentFinder = find.widgetWithText(
          CheckboxListTile,
          'Tôi đồng ý chia sẻ thông tin liên hệ và khung giờ này cho Tư vấn viên phụ trách. (Lịch sử chat AI và điểm sàng lọc KHÔNG tự động đính kèm).',
        );
        await tester.scrollUntilVisible(
          bookingConsentFinder,
          180,
          scrollable: find.byType(Scrollable).first,
        );
        expect(
          tester.widget<CheckboxListTile>(bookingConsentFinder).value,
          isFalse,
        );

        // Tab 5: Cài đặt & Kiểm tra R2 (_consentManualMemory và _consentLinkGuest mặc định = false)
        await tester.tap(find.text('Cài đặt').first);
        await tester.pumpAndSettle();

        final manualMemConsentFinder = find.widgetWithText(
          CheckboxListTile,
          'Tôi đồng ý cho phép AI ghi nhớ thông tin này cho các cuộc trò chuyện sau (F10).',
        );
        expect(
          tester.widget<CheckboxListTile>(manualMemConsentFinder).value,
          isFalse,
        );

        final guestLinkFinder = find.widgetWithText(
          CheckboxListTile,
          'Đồng ý chuyển dữ liệu đã lưu từ phiên ẩn danh hiện tại sang tài khoản.',
        );
        await tester.scrollUntilVisible(
          guestLinkFinder,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(
          tester.widget<CheckboxListTile>(guestLinkFinder).value,
          isFalse,
        );

        // Kiểm tra Cổng Nhà trường (School Portal) hiển thị tốt cả trên Mobile 360px lẫn Desktop 1366px
        await tester.tap(find.byTooltip('Cổng Web Nhà trường & Tư vấn viên'));
        await tester.pumpAndSettle();

        container.dispose();
      }

      await tester.binding.setSurfaceSize(null);
    },
  );

  testWidgets(
    'Compact Keyboard Viewport (360x440): Thanh gợi ý nhanh tự động thu gọn ngang để nhường không gian đọc tin nhắn',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 440));
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
      expect(tester.takeException(), isNull);
      expect(find.text('Mình đang lo thi cuối kỳ'), findsOneWidget);
    },
  );
}
