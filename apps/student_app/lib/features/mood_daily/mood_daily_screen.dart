import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/state_provider.dart';
import '../../shared/models.dart';

class DailyAndMoodHubScreen extends ConsumerStatefulWidget {
  const DailyAndMoodHubScreen({super.key});

  @override
  ConsumerState<DailyAndMoodHubScreen> createState() =>
      _DailyAndMoodHubScreenState();
}

class _DailyAndMoodHubScreenState extends ConsumerState<DailyAndMoodHubScreen> {
  String? _selectedMood;
  int _selectedMoodLevel = 3;
  String _moodFilter = 'ALL';
  final TextEditingController _moodNoteCtrl = TextEditingController();

  @override
  void dispose() {
    _moodNoteCtrl.dispose();
    super.dispose();
  }

  String _interactiveButtonLabel(String activityId) {
    if (activityId == 'act_01') return 'Mở đồng hồ thở 2 phút';
    if (activityId == 'act_03') return 'Thực hành Grounding 5-4-3-2-1';
    return 'Mở Form CBT 3 bước';
  }

  void _openInteractiveActivityModal(DailyActivityModel act) {
    ref
        .read(mindCheckProvider.notifier)
        .updateActivityStatus(act.activityId, 'in_progress');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        if (act.activityId == 'act_01') {
          return _BreathingExerciseModal(
            activity: act,
            onCompleted: (summary) {
              ref.read(mindCheckProvider.notifier).updateActivityStatus(
                    act.activityId,
                    'completed',
                    practiceSummary: summary,
                  );
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Tuyệt vời! Bạn đã hoàn thành thử thách thở vuông 4-4-4-4 và lưu vào lịch sử.',
                  ),
                ),
              );
            },
            onSkipped: () {
              ref
                  .read(mindCheckProvider.notifier)
                  .updateActivityStatus(act.activityId, 'skipped');
              Navigator.pop(ctx);
            },
          );
        }

        if (act.activityId == 'act_03') {
          return _GroundingFiveStepModal(
            activity: act,
            onCompleted: (summary) {
              ref.read(mindCheckProvider.notifier).updateActivityStatus(
                    act.activityId,
                    'completed',
                    practiceSummary: summary,
                  );
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Đã hoàn thành bài tập Grounding 5-4-3-2-1 kết nối thực tại!',
                  ),
                ),
              );
            },
            onSkipped: () {
              ref
                  .read(mindCheckProvider.notifier)
                  .updateActivityStatus(act.activityId, 'skipped');
              Navigator.pop(ctx);
            },
          );
        }

        return _CbtThreeStepFormModal(
          activity: act,
          onCompleted: (summary, reframedThought) {
            ref.read(mindCheckProvider.notifier).updateActivityStatus(
                  act.activityId,
                  'completed',
                  practiceSummary: summary,
                );
            if (reframedThought.trim().isNotEmpty) {
              ref.read(mindCheckProvider.notifier).addMoodEntry(
                    '😊 Ổn định',
                    4,
                    'Hoàn thành bài tập CBT: ${reframedThought.trim()}',
                  );
            }
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Đã lưu kết quả bài tập tái cấu trúc nhận thức CBT vào lịch sử!',
                ),
              ),
            );
          },
          onSkipped: () {
            ref
                .read(mindCheckProvider.notifier)
                .updateActivityStatus(act.activityId, 'skipped');
            Navigator.pop(ctx);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(mindCheckProvider);
    final moodOptions = [
      {'label': '🌟 Rất tích cực', 'level': 5},
      {'label': '😊 Ổn định', 'level': 4},
      {'label': '😐 Hơi mệt', 'level': 3},
      {'label': '😟 Lo lắng', 'level': 2},
      {'label': '😔 Căng thẳng', 'level': 1},
    ];

    final completedCount = appState.dailyActivities
        .where((a) => a.status == 'completed')
        .length;

    final avgEnergy = appState.moodEntries.isEmpty
        ? 0.0
        : appState.moodEntries
                .map((e) => e.moodLevel)
                .reduce((a, b) => a + b) /
            appState.moodEntries.length;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Check-in cảm xúc hôm nay',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Dành 5 giây lắng nghe cảm xúc hiện tại của chính mình.',
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: moodOptions.map((item) {
                        final label = item['label'] as String;
                        final level = item['level'] as int;
                        return ChoiceChip(
                          label: Text(label),
                          selected: _selectedMood == label,
                          onSelected: (_) => setState(() {
                            _selectedMood = label;
                            _selectedMoodLevel = level;
                          }),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _moodNoteCtrl,
                      decoration: const InputDecoration(
                        labelText:
                            'Ghi chú thêm về điều bạn đang nghĩ (tùy chọn)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _selectedMood == null
                          ? null
                          : () {
                              ref
                                  .read(mindCheckProvider.notifier)
                                  .addMoodEntry(
                                    _selectedMood!,
                                    _selectedMoodLevel,
                                    _moodNoteCtrl.text,
                                  );
                              _moodNoteCtrl.clear();
                              setState(() => _selectedMood = null);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Đã lưu trạng thái cảm xúc vào nhật ký của bạn.',
                                  ),
                                ),
                              );
                            },
                      icon: const Icon(Icons.favorite_border_rounded),
                      label: const Text('Lưu vào Nhật ký cảm xúc'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Hoạt động đồng hành & Bài tập tự hỗ trợ CBT (S11–S12)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...appState.dailyActivities.map(
              (act) => Card(
                color: Colors.white,
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              act.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Chip(
                            visualDensity: VisualDensity.compact,
                            backgroundColor: act.status == 'completed'
                                ? const Color(0xFFE6FCF5)
                                : const Color(0xFFEDF2FF),
                            label: Text(
                              act.status == 'completed'
                                  ? 'Đã hoàn thành'
                                  : (act.status == 'skipped'
                                      ? 'Đã bỏ qua'
                                      : act.duration),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...act.steps.map(
                        (s) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '• $s',
                            style: const TextStyle(
                              fontSize: 13.5,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                      if (act.lastPracticeSummary != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE6FCF5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '✓ Lần thực hành gần nhất: ${act.lastPracticeSummary}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF087F5B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: () =>
                                _openInteractiveActivityModal(act),
                            icon:
                                const Icon(Icons.play_arrow_rounded, size: 18),
                            label: Text(_interactiveButtonLabel(act.activityId)),
                          ),
                          OutlinedButton(
                            onPressed: () => ref
                                .read(mindCheckProvider.notifier)
                                .updateActivityStatus(
                                  act.activityId,
                                  'completed',
                                  practiceSummary:
                                      'Hoàn thành nhanh ${act.title}',
                                ),
                            child: const Text('Đánh dấu hoàn thành'),
                          ),
                          TextButton(
                            onPressed: () => ref
                                .read(mindCheckProvider.notifier)
                                .updateActivityStatus(
                                    act.activityId, 'skipped'),
                            child: const Text('Bỏ qua hôm nay'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (appState.activityPracticeLogs.isNotEmpty) ...[
              const SizedBox(height: 8),
              Card(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Lịch sử thực hành Thử thách & CBT gần đây',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ...appState.activityPracticeLogs.take(5).map(
                            (log) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  const Icon(Icons.task_alt_rounded,
                                      size: 16, color: Color(0xFF0CA678)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(log,
                                        style: const TextStyle(fontSize: 13)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Card(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nhật ký cảm xúc & Tổng kết tuần của bạn',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (appState.moodEntries.isEmpty)
                      const Text(
                        'Chưa có dữ liệu check-in trong tuần này. Hãy chọn một biểu tượng cảm xúc ở phía trên để bắt đầu theo dõi nhé.',
                        style: TextStyle(color: Colors.black54),
                      )
                    else ...[
                      if (appState.moodEntries.length < 3)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.info_outline_rounded,
                                  color: Color(0xFFD97706), size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Chưa đủ dữ liệu tổng kết tuần (hiện có ${appState.moodEntries.length}/3 lần check-in). Hãy duy trì check-in tối thiểu 3 lần để mở khóa biểu đồ mức cân bằng tuần (T13).',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF92400E),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEDF2FF),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tổng kết tuần: Bạn đã thực hiện ${appState.moodEntries.length} lần check-in cảm xúc và hoàn thành $completedCount bài tập tự chăm sóc.',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Text(
                                    'Mức cân bằng trung bình:',
                                    style: TextStyle(
                                        fontSize: 12.5, color: Colors.black54),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: LinearProgressIndicator(
                                        value:
                                            (avgEnergy / 5.0).clamp(0.1, 1.0),
                                        minHeight: 10,
                                        color: avgEnergy >= 3.5
                                            ? const Color(0xFF0CA678)
                                            : const Color(0xFFF59E0B),
                                        backgroundColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${avgEnergy.toStringAsFixed(1)}/5.0',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12.5,
                                      color: Color(0xFF3B5BDB),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Biểu đồ cột trực quan 7 lần check-in gần nhất
                              SizedBox(
                                height: 74,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: appState.moodEntries
                                      .take(7)
                                      .toList()
                                      .reversed
                                      .map((entry) {
                                    final barH =
                                        (entry.moodLevel / 5.0 * 44).clamp(10.0, 44.0);
                                    final col = entry.moodLevel >= 4
                                        ? const Color(0xFF0CA678)
                                        : (entry.moodLevel == 3
                                            ? const Color(0xFF3B5BDB)
                                            : const Color(0xFFF59E0B));
                                    return Column(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Text(
                                          entry.moodChoice.characters.first,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        const SizedBox(height: 2),
                                        Container(
                                          width: 18,
                                          height: barH,
                                          decoration: BoxDecoration(
                                            color: col,
                                            borderRadius:
                                                const BorderRadius.vertical(
                                              top: Radius.circular(5),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const Divider(height: 20),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          ChoiceChip(
                            visualDensity: VisualDensity.compact,
                            label: Text(
                              'Tất cả (${appState.moodEntries.length})',
                              style: const TextStyle(fontSize: 12),
                            ),
                            selected: _moodFilter == 'ALL',
                            onSelected: (_) =>
                                setState(() => _moodFilter = 'ALL'),
                          ),
                          ChoiceChip(
                            visualDensity: VisualDensity.compact,
                            label: const Text('Tích cực (🌟/😊)',
                                style: TextStyle(fontSize: 12)),
                            selected: _moodFilter == 'POSITIVE',
                            onSelected: (_) =>
                                setState(() => _moodFilter = 'POSITIVE'),
                          ),
                          ChoiceChip(
                            visualDensity: VisualDensity.compact,
                            label: const Text('Cần lắng nghe (😐/😟/😔)',
                                style: TextStyle(fontSize: 12)),
                            selected: _moodFilter == 'LOW',
                            onSelected: (_) =>
                                setState(() => _moodFilter = 'LOW'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ...appState.moodEntries.where((e) {
                        if (_moodFilter == 'POSITIVE') return e.moodLevel >= 4;
                        if (_moodFilter == 'LOW') return e.moodLevel <= 3;
                        return true;
                      }).map(
                        (e) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFFEDF2FF),
                            child: Text(e.moodChoice.characters.first),
                          ),
                          title: Text(
                            e.moodChoice,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            e.optionalNote.isEmpty
                                ? 'Không có ghi chú'
                                : e.optionalNote,
                          ),
                          trailing: IconButton(
                            tooltip: 'Xóa bản ghi này',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => ref
                                .read(mindCheckProvider.notifier)
                                .deleteMoodEntry(e.entryId),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// S11: Đồng hồ đếm ngược 2 phút chuẩn Thở vuông 4-4-4-4 (Box Breathing)
class _BreathingExerciseModal extends StatefulWidget {
  final DailyActivityModel activity;
  final ValueChanged<String> onCompleted;
  final VoidCallback onSkipped;

  const _BreathingExerciseModal({
    required this.activity,
    required this.onCompleted,
    required this.onSkipped,
  });

  @override
  State<_BreathingExerciseModal> createState() =>
      _BreathingExerciseModalState();
}

class _BreathingExerciseModalState extends State<_BreathingExerciseModal> {
  static const int _totalSeconds = 120;
  int _remainingSeconds = _totalSeconds;
  int _elapsedSeconds = 0;
  bool _isRunning = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingSeconds <= 1) {
        timer.cancel();
        setState(() {
          _remainingSeconds = 0;
          _isRunning = false;
        });
        widget.onCompleted('Hoàn thành trọn vẹn 2 phút thở vuông 4-4-4-4');
      } else {
        setState(() {
          _remainingSeconds--;
          _elapsedSeconds++;
        });
      }
    });
  }

  void _toggleTimer() {
    if (_isRunning) {
      _timer?.cancel();
      setState(() => _isRunning = false);
    } else {
      setState(() => _isRunning = true);
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Chu kỳ 16s chuẩn Box Breathing:
    // 0..3: Hít vào (4s), 4..7: Giữ hơi (4s), 8..11: Thở ra (4s), 12..15: Thả lỏng nghỉ (4s)
    final cycleSec = _elapsedSeconds % 16;
    final phaseCount = 4 - (cycleSec % 4);
    String phaseTitle;
    double circleSize;
    Color circleColor;

    if (cycleSec < 4) {
      phaseTitle = 'Hít vào nhẹ nhàng ($phaseCount giây)';
      circleSize = 160;
      circleColor = const Color(0xFF3B5BDB);
    } else if (cycleSec < 8) {
      phaseTitle = 'Giữ hơi thở êm ($phaseCount giây)';
      circleSize = 168;
      circleColor = const Color(0xFF0CA678);
    } else if (cycleSec < 12) {
      phaseTitle = 'Thở ra từ từ ($phaseCount giây)';
      circleSize = 116;
      circleColor = const Color(0xFF5C7CFA);
    } else {
      phaseTitle = 'Thả lỏng vai & nghỉ ($phaseCount giây)';
      circleSize = 112;
      circleColor = const Color(0xFF0D9488);
    }

    final mins = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (_remainingSeconds % 60).toString().padLeft(2, '0');

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.activity.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Đồng hồ đếm ngược 2 phút: $mins:$secs',
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3B5BDB),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 180,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeInOut,
                  width: circleSize,
                  height: circleSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: circleColor.withValues(alpha: 0.16),
                    border: Border.all(color: circleColor, width: 4),
                  ),
                  alignment: Alignment.center,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      phaseTitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: circleColor,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _toggleTimer,
                  icon: Icon(_isRunning ? Icons.pause : Icons.play_arrow),
                  label: Text(_isRunning ? 'Tạm dừng' : 'Tiếp tục'),
                ),
                FilledButton.icon(
                  onPressed: () => widget.onCompleted(
                    'Đã thực hành bài tập thở vuông (${_elapsedSeconds}s)',
                  ),
                  icon: const Icon(Icons.done_all_rounded),
                  label: const Text('Hoàn thành bài tập'),
                ),
                TextButton(
                  onPressed: widget.onSkipped,
                  child: const Text('Bỏ qua hôm nay'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Bài tập tương tác Grounding 5-4-3-2-1 kết nối thực tại giảm lo âu cấp tính
class _GroundingFiveStepModal extends StatefulWidget {
  final DailyActivityModel activity;
  final ValueChanged<String> onCompleted;
  final VoidCallback onSkipped;

  const _GroundingFiveStepModal({
    required this.activity,
    required this.onCompleted,
    required this.onSkipped,
  });

  @override
  State<_GroundingFiveStepModal> createState() =>
      _GroundingFiveStepModalState();
}

class _GroundingFiveStepModalState extends State<_GroundingFiveStepModal> {
  final List<bool> _checked = [false, false, false, false, false];

  static const List<Map<String, String>> _sensorySteps = [
    {
      'badge': '5',
      'title': 'Nhìn quanh và gọi tên 5 đồ vật bạn đang thấy',
      'hint': 'VD: Mặt bàn gỗ, cốc nước, tán cây ngoài cửa sổ...',
    },
    {
      'badge': '4',
      'title': 'Chạm nhẹ và cảm nhận 4 bề mặt xung quanh',
      'hint': 'VD: Vải áo, mặt sàn dưới bàn chân, lưng ghế...',
    },
    {
      'badge': '3',
      'title': 'Lắng nghe 3 âm thanh tự nhiên gần hoặc xa',
      'hint': 'VD: Tiếng quạt quay, tiếng gió, nhịp thở của mình...',
    },
    {
      'badge': '2',
      'title': 'Nhận diện 2 mùi hương hoặc luồng không khí',
      'hint': 'VD: Hương trà, mùi sách vở, không khí mát...',
    },
    {
      'badge': '1',
      'title': 'Nói thầm 1 điều bạn trân trọng ở bản thân hôm nay',
      'hint': 'VD: "Cảm ơn mình vì hôm nay vẫn đang kiên trì cố gắng."',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final doneCount = _checked.where((v) => v).length;

    return Padding(
      padding: EdgeInsets.only(
        left: 22,
        right: 22,
        top: 22,
        bottom: MediaQuery.of(context).viewInsets.bottom + 22,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.activity.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Tích chọn từng giác quan khi bạn đã thực hiện xong ($doneCount/5 bước):',
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
            const SizedBox(height: 12),
            ...List.generate(_sensorySteps.length, (idx) {
              final item = _sensorySteps[idx];
              return CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _checked[idx],
                onChanged: (v) => setState(() => _checked[idx] = v ?? false),
                title: Text(
                  '${item['badge']} • ${item['title']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
                subtitle: Text(
                  item['hint']!,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              );
            }),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () => widget.onCompleted(
                    'Hoàn thành Grounding 5-4-3-2-1 (${doneCount == 0 ? 5 : doneCount}/5 giác quan)',
                  ),
                  icon: const Icon(Icons.done_all_rounded),
                  label: const Text('Hoàn thành kết nối thực tại'),
                ),
                OutlinedButton(
                  onPressed: widget.onSkipped,
                  child: const Text('Bỏ qua hôm nay'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// S12: Form 3 bước tương tác cho bài tập CBT
class _CbtThreeStepFormModal extends StatefulWidget {
  final DailyActivityModel activity;
  final void Function(String summary, String reframedThought) onCompleted;
  final VoidCallback onSkipped;

  const _CbtThreeStepFormModal({
    required this.activity,
    required this.onCompleted,
    required this.onSkipped,
  });

  @override
  State<_CbtThreeStepFormModal> createState() => _CbtThreeStepFormModalState();
}

class _CbtThreeStepFormModalState extends State<_CbtThreeStepFormModal> {
  final _situationCtrl = TextEditingController();
  final _thoughtCtrl = TextEditingController();
  final _reframeCtrl = TextEditingController();

  @override
  void dispose() {
    _situationCtrl.dispose();
    _thoughtCtrl.dispose();
    _reframeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.activity.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Thực hành 3 bước bóc tách suy nghĩ tự động theo liệu pháp CBT:',
              style: TextStyle(color: Colors.black54, fontSize: 13),
            ),
            const Divider(height: 22),
            TextField(
              controller: _situationCtrl,
              decoration: const InputDecoration(
                labelText: 'Bước 1: Tình huống thực tế đang khiến bạn bận tâm',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _thoughtCtrl,
              decoration: const InputDecoration(
                labelText: 'Bước 2: Suy nghĩ tự động tiêu cực vừa xuất hiện',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reframeCtrl,
              decoration: const InputDecoration(
                labelText:
                    'Bước 3: Góc nhìn thay thế cân bằng & hành động nhỏ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () {
                    final reframe = _reframeCtrl.text.trim();
                    final summary = reframe.isNotEmpty
                        ? 'CBT 3 bước: "$reframe"'
                        : 'Hoàn thành bài tập CBT 3 bước';
                    widget.onCompleted(summary, reframe);
                  },
                  icon: const Icon(Icons.done_all_rounded),
                  label: const Text('Lưu & Hoàn thành CBT'),
                ),
                OutlinedButton(
                  onPressed: widget.onSkipped,
                  child: const Text('Bỏ qua hôm nay'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
