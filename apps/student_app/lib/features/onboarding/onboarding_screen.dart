import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/state_provider.dart';
import '../../shared/models.dart';
import '../support/support_booking_screen.dart';

void showCompanionPersonalizationModal(BuildContext context, WidgetRef ref) {
  final pref = ref.read(mindCheckProvider).companionPref;
  final nameCtrl = TextEditingController(text: pref.nickname);
  String pronoun = '${pref.userPronoun} - ${pref.aiPronoun}';
  if (pronoun != 'bạn - mình' && pronoun != 'em - mình') {
    pronoun = 'bạn - mình';
  }
  String tone = pref.tone;

  showDialog(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            title: const Text('Cá nhân hóa người bạn AI'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Tên gọi của AI',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: pronoun,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Cách xưng hô',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'bạn - mình',
                          child: Text('Gọi "bạn" — Xưng "mình"')),
                      DropdownMenuItem(
                          value: 'em - mình',
                          child: Text('Gọi "em" — Xưng "mình"')),
                    ],
                    onChanged: (v) => setModalState(() => pronoun = v!),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: tone,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Phong cách trò chuyện',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'ấm áp, gần gũi',
                          child: Text('Ấm áp, gần gũi')),
                      DropdownMenuItem(
                          value: 'nhẹ nhàng, khích lệ',
                          child: Text('Nhẹ nhàng, khích lệ')),
                    ],
                    onChanged: (v) => setModalState(() => tone = v!),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: () {
                  final parts = pronoun.split(' - ');
                  ref
                      .read(mindCheckProvider.notifier)
                      .updateCompanionPreference(
                        CompanionPreference(
                          nickname: nameCtrl.text.trim().isEmpty
                              ? 'MindCheck'
                              : nameCtrl.text.trim(),
                          userPronoun: parts[0],
                          aiPronoun: parts[1],
                          tone: tone,
                        ),
                      );
                  Navigator.pop(ctx);
                },
                child: const Text('Lưu thay đổi'),
              ),
            ],
          );
        },
      );
    },
  );
}

class OnboardingFlowScreen extends ConsumerStatefulWidget {
  final VoidCallback onOpenSchoolPortal;
  final VoidCallback? onOpenContaboConfig;

  const OnboardingFlowScreen({
    super.key,
    required this.onOpenSchoolPortal,
    this.onOpenContaboConfig,
  });

  @override
  ConsumerState<OnboardingFlowScreen> createState() =>
      _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState extends ConsumerState<OnboardingFlowScreen> {
  int _step = 0;
  bool _policyChecked = false;
  final TextEditingController _nicknameCtrl =
      TextEditingController(text: 'MindCheck');
  String _selectedPronoun = 'bạn - mình';
  String _selectedTone = 'ấm áp, gần gũi';

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isCompact = screenWidth < 520;
        final isUltraCompact = screenWidth < 375;

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF1E293B),
            surfaceTintColor: Colors.white,
            titleSpacing: isUltraCompact ? 8 : (isCompact ? 10 : 16),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isUltraCompact) ...[
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B5BDB),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.psychology_alt_rounded,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    'MindCheck Campus 2.0',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isUltraCompact ? 14 : 17,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton.icon(
                style: isCompact
                    ? TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                            horizontal: isUltraCompact ? 6 : 8),
                        minimumSize: const Size(44, 34),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      )
                    : null,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const SafetySupportScreen()),
                ),
                icon: const Icon(Icons.emergency_rounded,
                    color: Colors.redAccent, size: 17),
                label: Text(
                  isUltraCompact
                      ? 'SOS'
                      : (isCompact ? 'Khẩn cấp' : 'Hỗ trợ an toàn (S21)'),
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: isUltraCompact ? 12 : 14,
                  ),
                ),
              ),
              if (widget.onOpenContaboConfig != null)
                IconButton(
                  visualDensity: isCompact ? VisualDensity.compact : null,
                  constraints: isCompact
                      ? const BoxConstraints(minWidth: 34, minHeight: 34)
                      : null,
                  padding: isCompact ? const EdgeInsets.all(6) : null,
                  tooltip: 'Cấu hình AI & Máy chủ Contabo',
                  onPressed: widget.onOpenContaboConfig,
                  icon: const Icon(Icons.cloud_queue_rounded,
                      color: Color(0xFF3B5BDB), size: 20),
                ),
              IconButton(
                visualDensity: isCompact ? VisualDensity.compact : null,
                constraints: isCompact
                    ? const BoxConstraints(minWidth: 34, minHeight: 34)
                    : null,
                padding: isCompact ? const EdgeInsets.all(6) : null,
                tooltip: 'Cổng Nhà trường & Chuyên gia',
                onPressed: widget.onOpenSchoolPortal,
                icon: const Icon(Icons.admin_panel_settings_outlined, size: 20),
              ),
            ],
          ),
          body: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isCompact ? 16 : 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  children: [
                    Row(
                      children: List.generate(4, (idx) {
                        final active = idx <= _step;
                        return Expanded(
                          child: Container(
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: active
                                  ? const Color(0xFF3B5BDB)
                                  : const Color(0xFFD8E0F0),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24)),
                      child: Padding(
                        padding: EdgeInsets.all(isCompact ? 20 : 28),
                        child: _buildStepBody(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStepBody(BuildContext context) {
    if (_step == 0) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3B5BDB), Color(0xFF5C7CFA)],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.spa_rounded, size: 48, color: Colors.white),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFE6FCF5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Không gian đồng hành tâm lý học đường ẩn danh',
              style: TextStyle(
                color: Color(0xFF099268),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Người bạn đồng hành AI lắng nghe & thấu cảm cùng sinh viên',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          const Text(
            'Trò chuyện riêng tư theo liệu pháp nhận thức hành vi (CBT), tự nguyện kiểm tra sức khỏe tinh thần (PHQ-9, GAD-7, DASS-21) và kết nối chuyên gia tâm lý của trường bất cứ khi nào bạn sẵn sàng.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54, height: 1.45),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
              onPressed: () => setState(() => _step = 1),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_forward_rounded, size: 18),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Bắt đầu tìm hiểu & Thiết lập quyền riêng tư',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              onPressed: widget.onOpenSchoolPortal,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.school_outlined, size: 18),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Dành cho Phòng CTSV & Tư vấn viên nhà trường',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (_step == 1) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Giá trị đồng hành & Giới hạn dịch vụ AI',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          _buildInfoTile(
            Icons.chat_bubble_outline_rounded,
            'Bạn đồng hành định hướng CBT tiếng Việt',
            'Lắng nghe không phán xét, hỗ trợ bạn tháo gỡ áp lực học tập, thi cử. Cuộc trò chuyện không tự động biến thành chẩn đoán y khoa.',
          ),
          _buildInfoTile(
            Icons.memory_rounded,
            'Quyền kiểm soát ghi nhớ tuyệt đối',
            'AI chỉ lưu thông tin quan trọng khi được bạn đồng ý và bạn có thể chỉnh sửa hoặc xóa hoàn toàn bất cứ lúc nào.',
          ),
          _buildInfoTile(
            Icons.verified_user_outlined,
            'Cơ chế an toàn hai lớp',
            'Khi phát hiện dấu hiệu căng thẳng cao, hệ thống chủ động cung cấp danh bạ hỗ trợ khẩn cấp và cầu nối đặt lịch cùng chuyên gia trường.',
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: () => setState(() => _step = 0),
                  child: const Text('Quay lại'),
                ),
                FilledButton(
                  onPressed: () => setState(() => _step = 2),
                  child: const Text('Tiếp tục: Chính sách bảo mật'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (_step == 2) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cam kết Bảo mật & Tách biệt Danh tính',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    '• Trải nghiệm ẩn danh ngay từ đầu: Bạn không bắt buộc phải cung cấp tên thật, email hay mã số sinh viên để trò chuyện với AI.'),
                SizedBox(height: 6),
                Text(
                    '• Bảo vệ trước nhà trường: Phòng Công tác sinh viên chỉ xem biểu đồ xu hướng tổng hợp toàn trường, không thể xem lịch sử chat hay điểm sàng lọc cá nhân.'),
                SizedBox(height: 6),
                Text(
                    '• Chia sẻ có sự đồng ý: Chỉ khi bạn chủ động đặt lịch hẹn, thông tin liên hệ mới được gửi riêng cho tư vấn viên phụ trách.'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _policyChecked,
            onChanged: (v) => setState(() => _policyChecked = v ?? false),
            title: const Text(
              'Tôi đã đọc, hiểu rõ giới hạn của AI và đồng ý với Chính sách Quyền riêng tư của MindCheck Campus.',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: () => setState(() => _step = 1),
                  child: const Text('Quay lại'),
                ),
                FilledButton(
                  onPressed:
                      _policyChecked ? () => setState(() => _step = 3) : null,
                  child: const Text('Tiếp tục cá nhân hóa AI'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Cá nhân hóa người bạn đồng hành AI',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _nicknameCtrl,
          decoration: const InputDecoration(
            labelText: 'Đặt tên cho người bạn AI của bạn',
            prefixIcon: Icon(Icons.badge_outlined),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _selectedPronoun,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Cách xưng hô bạn muốn sử dụng',
            prefixIcon: Icon(Icons.record_voice_over_outlined),
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(
                value: 'bạn - mình', child: Text('Gọi "bạn" — Xưng "mình"')),
            DropdownMenuItem(
                value: 'em - mình', child: Text('Gọi "em" — Xưng "mình"')),
          ],
          onChanged: (v) => setState(() => _selectedPronoun = v!),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _selectedTone,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Phong cách lắng nghe',
            prefixIcon: Icon(Icons.auto_awesome_outlined),
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(
                value: 'ấm áp, gần gũi', child: Text('Ấm áp, gần gũi')),
            DropdownMenuItem(
                value: 'nhẹ nhàng, khích lệ',
                child: Text('Nhẹ nhàng, khích lệ')),
          ],
          onChanged: (v) => setState(() => _selectedTone = v!),
        ),
        const Divider(height: 28),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () {
              final parts = _selectedPronoun.split(' - ');
              ref.read(mindCheckProvider.notifier).startAnonymousSession();
              ref.read(mindCheckProvider.notifier).updateCompanionPreference(
                    CompanionPreference(
                      nickname: _nicknameCtrl.text.trim().isEmpty
                          ? 'MindCheck'
                          : _nicknameCtrl.text.trim(),
                      userPronoun: parts[0],
                      aiPronoun: parts[1],
                      tone: _selectedTone,
                    ),
                  );
            },
            icon: const Icon(Icons.shield_outlined),
            label: const Text('Bắt đầu trò chuyện ẩn danh ngay'),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoTile(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEDF2FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF3B5BDB), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style:
                        const TextStyle(fontSize: 13, color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

