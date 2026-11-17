import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/state_provider.dart';
import '../../shared/models.dart';
import '../support/support_booking_screen.dart';

class VoluntaryScreeningHubScreen extends ConsumerStatefulWidget {
  final VoidCallback onNavigateToBooking;
  const VoluntaryScreeningHubScreen({
    super.key,
    required this.onNavigateToBooking,
  });

  @override
  ConsumerState<VoluntaryScreeningHubScreen> createState() =>
      _VoluntaryScreeningHubScreenState();
}

class _VoluntaryScreeningHubScreenState
    extends ConsumerState<VoluntaryScreeningHubScreen> {
  ScreeningToolModel? _selectedTool;
  bool _inConsentScreen = false;
  bool _inQuestionnaireScreen = false;
  bool _stepByStepMode = true;
  int _currentQuestionIndex = 0;
  String _historyToolFilter = 'ALL';
  Map<int, int> _answers = {};
  ScreeningResultModel? _activeResult;

  void _selectTool(ScreeningToolModel tool) {
    setState(() {
      _selectedTool = tool;
      _inConsentScreen = true;
      _inQuestionnaireScreen = false;
      _currentQuestionIndex = 0;
      _answers = {};
    });
  }

  String _dimensionLabel(String toolId) {
    if (toolId == 'PHQ-9') return 'Mức độ trầm cảm (PHQ-9)';
    if (toolId == 'DASS-21') {
      return 'Tổ hợp Căng thẳng - Lo âu - Trầm cảm (DASS-21)';
    }
    return 'Mức độ lo âu (GAD-7)';
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(mindCheckProvider);
    final filteredHistory = appState.screeningHistory.where((item) {
      if (_historyToolFilter == 'ALL') return true;
      return item.toolId == _historyToolFilter;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            if (!_inConsentScreen && !_inQuestionnaireScreen) ...[
              const Text(
                'Thư viện công cụ sàng lọc tâm lý chuẩn hóa (S15)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Hoàn toàn tự nguyện và riêng tư. Kết quả giúp bạn tự theo dõi sức khỏe tinh thần và kết nối chuyên gia khi cần.',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 12),
              ...appState.screeningTools.map(
                (tool) => Card(
                  color: Colors.white,
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: const Color(0xFFEDF2FF),
                              child: Text(
                                tool.toolId.split('-').first,
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF3B5BDB)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(tool.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16)),
                                  Text(tool.subtitle,
                                      style: const TextStyle(
                                          fontSize: 13, color: Colors.black54)),
                                ],
                              ),
                            ),
                            Chip(
                              visualDensity: VisualDensity.compact,
                              backgroundColor: const Color(0xFFF1F5F9),
                              label: Text(
                                '${tool.questions.length} câu',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(tool.description,
                            style: const TextStyle(fontSize: 13)),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.tonalIcon(
                            onPressed: () => _selectTool(tool),
                            icon: const Icon(Icons.arrow_forward_rounded,
                                size: 18),
                            label: const Text('Tìm hiểu & Thực hiện'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            if (_inConsentScreen && _selectedTool != null)
              Card(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Xác nhận đồng ý thực hiện ${_selectedTool!.name} (S16)',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '• Mục đích: Giúp bạn tự nhận diện mức độ triệu chứng trong 2 tuần qua, KHÔNG thay thế chẩn đoán của bác sĩ chuyên khoa.\n'
                        '• Quyền dừng bất kỳ lúc nào: Bạn có thể thoát giữa chừng nếu không muốn tiếp tục.\n'
                        '• Bảo mật tuyệt đối: Kết quả của bạn không tự động gửi dưới dạng định danh cho nhà trường.',
                        style: TextStyle(height: 1.45),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: () {
                              ref
                                  .read(mindCheckProvider.notifier)
                                  .recordScreeningConsent(true);
                              setState(() {
                                _inConsentScreen = false;
                                _inQuestionnaireScreen = true;
                                _currentQuestionIndex = 0;
                              });
                            },
                            icon: const Icon(Icons.play_circle_outline),
                            label: const Text('Đồng ý & Bắt đầu trả lời'),
                          ),
                          OutlinedButton(
                            onPressed: () {
                              ref
                                  .read(mindCheckProvider.notifier)
                                  .recordScreeningConsent(false);
                              setState(() {
                                _inConsentScreen = false;
                                _selectedTool = null;
                              });
                            },
                            child: const Text('Quay lại thư viện'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            if (_inQuestionnaireScreen && _selectedTool != null)
              Card(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${_selectedTool!.name} (${_answers.length}/${_selectedTool!.questions.length} câu)',
                              style: const TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              ref
                                  .read(mindCheckProvider.notifier)
                                  .abandonScreeningSession(
                                    tool: _selectedTool!,
                                    partialAnswers: _answers.values.toList(),
                                  );
                              setState(() {
                                _inQuestionnaireScreen = false;
                                _selectedTool = null;
                                _answers = {};
                              });
                            },
                            icon: const Icon(Icons.close),
                            label: const Text('Thoát bảng hỏi'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value:
                            _answers.length / _selectedTool!.questions.length,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text(
                            'Trong 2 tuần qua, bạn bị làm phiền bởi các vấn đề sau với tần suất như thế nào?',
                            style:
                                TextStyle(fontSize: 13, color: Colors.black54),
                          ),
                          Wrap(
                            spacing: 6,
                            children: [
                              ChoiceChip(
                                visualDensity: VisualDensity.compact,
                                label: const Text('Chế độ Từng câu',
                                    style: TextStyle(fontSize: 12)),
                                selected: _stepByStepMode,
                                onSelected: (_) =>
                                    setState(() => _stepByStepMode = true),
                              ),
                              ChoiceChip(
                                visualDensity: VisualDensity.compact,
                                label: const Text('Xem tất cả câu',
                                    style: TextStyle(fontSize: 12)),
                                selected: !_stepByStepMode,
                                onSelected: (_) =>
                                    setState(() => _stepByStepMode = false),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Divider(),
                      if (_stepByStepMode) ...[
                        // Thanh chọn nhanh số thứ tự câu hỏi
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: List.generate(
                                _selectedTool!.questions.length, (idx) {
                              final isAnswered = _answers.containsKey(idx);
                              final isCurrent = _currentQuestionIndex == idx;
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: () => setState(
                                      () => _currentQuestionIndex = idx),
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: isCurrent
                                          ? const Color(0xFF3B5BDB)
                                          : (isAnswered
                                              ? const Color(0xFFE6FCF5)
                                              : const Color(0xFFF1F5F9)),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isCurrent
                                            ? const Color(0xFF3B5BDB)
                                            : (isAnswered
                                                ? const Color(0xFF0CA678)
                                                : const Color(0xFFCBD5E1)),
                                      ),
                                    ),
                                    child: Text(
                                      '${idx + 1}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isCurrent
                                            ? Colors.white
                                            : (isAnswered
                                                ? const Color(0xFF087F5B)
                                                : Colors.black87),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                        const SizedBox(height: 14),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: Container(
                            key: ValueKey<int>(_currentQuestionIndex),
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border:
                                  Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Câu hỏi ${_currentQuestionIndex + 1} / ${_selectedTool!.questions.length}',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF3B5BDB),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _selectedTool!
                                      .questions[_currentQuestionIndex],
                                  style: const TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: List.generate(4, (scoreVal) {
                                    final labels =
                                        _selectedTool!.scaleLabels.length >= 4
                                            ? _selectedTool!.scaleLabels
                                            : const [
                                                'Không chút nào (0)',
                                                'Vài ngày (1)',
                                                'Hơn nửa số ngày (2)',
                                                'Gần như mỗi ngày (3)'
                                              ];
                                    return ChoiceChip(
                                      label: Text(labels[scoreVal],
                                          style: const TextStyle(fontSize: 13)),
                                      selected:
                                          _answers[_currentQuestionIndex] ==
                                              scoreVal,
                                      onSelected: (_) {
                                        setState(() {
                                          _answers[_currentQuestionIndex] =
                                              scoreVal;
                                          if (_currentQuestionIndex <
                                              _selectedTool!.questions.length -
                                                  1) {
                                            _currentQuestionIndex++;
                                          }
                                        });
                                      },
                                    );
                                  }),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton.icon(
                              onPressed: _currentQuestionIndex > 0
                                  ? () => setState(
                                      () => _currentQuestionIndex--)
                                  : null,
                              icon: const Icon(Icons.chevron_left),
                              label: const Text('Câu trước'),
                            ),
                            TextButton.icon(
                              onPressed: _currentQuestionIndex <
                                      _selectedTool!.questions.length - 1
                                  ? () => setState(
                                      () => _currentQuestionIndex++)
                                  : null,
                              icon: const Icon(Icons.chevron_right),
                              label: const Text('Câu tiếp theo'),
                            ),
                          ],
                        ),
                      ] else
                        ...List.generate(_selectedTool!.questions.length,
                            (qIdx) {
                          final labels =
                              _selectedTool!.scaleLabels.length >= 4
                                  ? _selectedTool!.scaleLabels
                                  : const [
                                      'Không chút nào (0)',
                                      'Vài ngày (1)',
                                      'Hơn nửa số ngày (2)',
                                      'Gần như mỗi ngày (3)'
                                    ];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_selectedTool!.questions[qIdx],
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: List.generate(4, (scoreVal) {
                                    return ChoiceChip(
                                      label: Text(labels[scoreVal],
                                          style:
                                              const TextStyle(fontSize: 12.5)),
                                      selected: _answers[qIdx] == scoreVal,
                                      onSelected: (_) => setState(
                                          () => _answers[qIdx] = scoreVal),
                                    );
                                  }),
                                ),
                              ],
                            ),
                          );
                        }),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: _answers.length <
                                    _selectedTool!.questions.length
                                ? null
                                : () {
                                    final ordered = List.generate(
                                      _selectedTool!.questions.length,
                                      (i) => _answers[i] ?? 0,
                                    );
                                    final res = ref
                                        .read(mindCheckProvider.notifier)
                                        .submitScreeningAnswers(
                                          tool: _selectedTool!,
                                          answers: ordered,
                                        );
                                    setState(() {
                                      _inQuestionnaireScreen = false;
                                      _activeResult = res;
                                    });
                                  },
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text('Hoàn tất & Xem kết quả'),
                          ),
                          if (kSeedDemoMode)
                            OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  for (int i = 0;
                                      i < _selectedTool!.questions.length;
                                      i++) {
                                    _answers[i] = (i % 2 == 0) ? 2 : 1;
                                  }
                                });
                              },
                              child: const Text('Điền nhanh mẫu thử nghiệm'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            if (_activeResult != null) ...[
              const SizedBox(height: 12),
              Builder(
                builder: (context) {
                  final res = _activeResult!;
                  final ratio =
                      (res.score / (res.maxScore == 0 ? 1 : res.maxScore))
                          .clamp(0.0, 1.0);
                  final barColor = !res.requiresAttention
                      ? const Color(0xFF0CA678)
                      : (ratio >= 0.65
                          ? const Color(0xFFDC2626)
                          : const Color(0xFFF59E0B));

                  // Tìm kết quả thực gần nhất của một thang đo khác (nếu sinh viên đã thực hiện)
                  ScreeningResultModel? secondaryResult;
                  for (final item in appState.screeningHistory) {
                    if (item.toolId != res.toolId) {
                      secondaryResult = item;
                      break;
                    }
                  }

                  return Card(
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'Kết quả tự sàng lọc (${res.toolId}) — S18',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Chip(
                                visualDensity: VisualDensity.compact,
                                backgroundColor: Colors.amber.shade100,
                                label: const Text(
                                  'Kết quả tham khảo (Không chẩn đoán)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_dimensionLabel(res.toolId)} — Điểm: ${res.score}/${res.maxScore}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: LinearProgressIndicator(
                                    value: ratio.clamp(0.04, 1.0),
                                    minHeight: 14,
                                    color: barColor,
                                    backgroundColor: const Color(0xFFD9E2EC),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  res.levelLabel,
                                  style: TextStyle(
                                    color: barColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (res.toolId == 'DASS-21') ...[
                                  const Divider(height: 20),
                                  const Text(
                                    'Phân tích 3 chiều tổ hợp DASS-21 (7 câu chuẩn Lovibond/chiều):',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildSubscaleRow(
                                    'Căng thẳng (Stress — 7 câu)',
                                    res.subscaleScores['stress'] ??
                                        (res.score / 3).round(),
                                    21,
                                    const Color(0xFFF59E0B),
                                  ),
                                  const SizedBox(height: 6),
                                  _buildSubscaleRow(
                                    'Lo âu (Anxiety — 7 câu)',
                                    res.subscaleScores['anxiety'] ??
                                        ((res.score + 1) / 3).round(),
                                    21,
                                    const Color(0xFF3B5BDB),
                                  ),
                                  const SizedBox(height: 6),
                                  _buildSubscaleRow(
                                    'Khí sắc / Trầm cảm (Depression — 7 câu)',
                                    res.subscaleScores['depression'] ??
                                        (res.score -
                                                (res.score / 3).round() -
                                                ((res.score + 1) / 3).round())
                                            .clamp(0, 21),
                                    21,
                                    const Color(0xFF0CA678),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (secondaryResult != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Đối chiếu lượt gần nhất: ${_dimensionLabel(secondaryResult.toolId)} (${secondaryResult.score}/${secondaryResult.maxScore})',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: LinearProgressIndicator(
                                      value: (secondaryResult.score /
                                              secondaryResult.maxScore)
                                          .clamp(0.04, 1.0),
                                      minHeight: 10,
                                      color: secondaryResult.requiresAttention
                                          ? const Color(0xFFF59E0B)
                                          : const Color(0xFF10B981),
                                      backgroundColor: const Color(0xFFD9E2EC),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    secondaryResult.levelLabel,
                                    style: const TextStyle(
                                      color: Colors.black54,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: res.requiresAttention
                                  ? const Color(0xFFFEF2F2)
                                  : const Color(0xFFE6FCF5),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: res.requiresAttention
                                    ? const Color(0xFFFCA5A5)
                                    : const Color(0xFF63E6BE),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  res.requiresAttention
                                      ? '⚠️ Gợi ý đồng hành dành cho bạn'
                                      : '🌿 Ghi nhận tích cực dành cho bạn',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: res.requiresAttention
                                        ? const Color(0xFFDC2626)
                                        : const Color(0xFF087F5B),
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(res.interpretation),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF4C6EF5),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                  horizontal: 12,
                                ),
                              ),
                              onPressed: () {
                                ref
                                    .read(mindCheckProvider.notifier)
                                    .prepareBookingFromScreening(
                                      counselorId: 'counselor_01',
                                      suggestedNote:
                                          'Mong muốn trao đổi thêm sau khi tự thực hiện sàng lọc ${res.toolId}.',
                                    );
                                widget.onNavigateToBooking();
                              },
                              icon: const Icon(Icons.calendar_month_outlined),
                              label: const Text(
                                'Đặt lịch với chuyên gia (Phòng Tư vấn Sinh viên)',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFDC2626),
                                side: const BorderSide(
                                  color: Color(0xFFDC2626),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SafetySupportScreen(),
                                ),
                              ),
                              icon: const Icon(Icons.phone_in_talk_outlined),
                              label: const Text(
                                'Đường dây nóng hỗ trợ',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Lịch sử 4 tuần gần đây',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (res.fourWeekTrend.length < 2)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                'Đây là lượt sàng lọc đầu tiên của bạn với thang đo ${res.toolId}; đường xu hướng sẽ tự động nối điểm từ lần sàng lọc tiếp theo.',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: Colors.black54,
                                ),
                              ),
                            ),
                          SizedBox(
                            height: 95,
                            width: double.infinity,
                            child: CustomPaint(
                              painter: FourWeekTrendLinePainter(
                                points: res.fourWeekTrend,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Lịch sử các lần sàng lọc đã lưu (S19)',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                Wrap(
                  spacing: 6,
                  children: ['ALL', 'GAD-7', 'PHQ-9', 'DASS-21'].map((tKey) {
                    return ChoiceChip(
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        tKey == 'ALL' ? 'Tất cả' : tKey,
                        style: const TextStyle(fontSize: 12),
                      ),
                      selected: _historyToolFilter == tKey,
                      onSelected: (_) =>
                          setState(() => _historyToolFilter = tKey),
                    );
                  }).toList(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (filteredHistory.isEmpty)
              const Card(
                color: Colors.white,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Chưa có lượt sàng lọc nào được lưu.'),
                ),
              )
            else
              ...filteredHistory.map(
                (item) => Card(
                  color: Colors.white,
                  child: ListTile(
                    leading: const Icon(Icons.insights_rounded,
                        color: Color(0xFF3B5BDB)),
                    title: Text(
                        '${item.toolId} — Điểm: ${item.score}/${item.maxScore}'),
                    subtitle: Text(item.levelLabel),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => setState(() => _activeResult = item),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubscaleRow(
    String label,
    int score,
    int maxScore,
    Color color,
  ) {
    final pct = (score / (maxScore == 0 ? 1 : maxScore)).clamp(0.05, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12)),
            Text(
              '$score/$maxScore',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 7,
            color: color,
            backgroundColor: const Color(0xFFE2E8F0),
          ),
        ),
      ],
    );
  }
}

class FourWeekTrendLinePainter extends CustomPainter {
  final List<double> points;
  FourWeekTrendLinePainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final gridPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1.0;

    canvas.drawLine(
      Offset(0, size.height * 0.5),
      Offset(size.width, size.height * 0.5),
      gridPaint,
    );

    final dotPaint = Paint()
      ..color = const Color(0xFF4C6EF5)
      ..style = PaintingStyle.fill;

    if (points.length == 1) {
      final y = size.height - (points.first.clamp(0.1, 0.95) * size.height);
      canvas.drawCircle(Offset(size.width * 0.5, y), 6.0, dotPaint);
      return;
    }

    final linePaint = Paint()
      ..color = const Color(0xFF4C6EF5)
      ..strokeWidth = 2.8
      ..style = PaintingStyle.stroke;

    final path = Path();
    final stepX = size.width / (points.length - 1);

    for (int i = 0; i < points.length; i++) {
      final x = i * stepX;
      final y = size.height - (points[i].clamp(0.1, 0.95) * size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      canvas.drawCircle(Offset(x, y), 5.0, dotPaint);
    }

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
