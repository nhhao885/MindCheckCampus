import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/state_provider.dart';
import '../../shared/api_service.dart';
import '../../shared/local_preferences.dart';
import '../../shared/models.dart';

class SupportAndCounselingHubScreen extends ConsumerStatefulWidget {
  const SupportAndCounselingHubScreen({super.key});

  @override
  ConsumerState<SupportAndCounselingHubScreen> createState() =>
      _SupportAndCounselingHubScreenState();
}

class _SupportAndCounselingHubScreenState
    extends ConsumerState<SupportAndCounselingHubScreen> {
  String _selectedCounselorId = 'counselor_01';
  String _selectedSlot = 'Thứ 5 (14:00 - 15:00)';
  String _selectedMode = 'Trực tiếp tại phòng P.102';
  String _myBookingFilter = 'ALL';
  final TextEditingController _contactCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();
  // R2: Tuyệt đối không mặc định tích sẵn checkbox đồng ý chia sẻ thông tin đặt lịch
  bool _consentShareBooking = false;
  bool _appliedScreeningPreselection = false;

  @override
  void dispose() {
    _contactCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(mindCheckProvider);
    if (_contactCtrl.text.isEmpty && (appState.userEmail ?? '').isNotEmpty) {
      _contactCtrl.text = appState.userEmail!;
    }
    if (!_appliedScreeningPreselection &&
        appState.preferredCounselorId != null) {
      _selectedCounselorId = appState.preferredCounselorId!;
      if ((appState.preferredBookingNote ?? '').isNotEmpty &&
          _noteCtrl.text.isEmpty) {
        _noteCtrl.text = appState.preferredBookingNote!;
      }
      _appliedScreeningPreselection = true;
    }

    // Danh sách chuyên gia tư vấn đang hoạt động (đồng bộ từ cấu hình Nhân sự của Admin)
    final activeCounselorAccounts = appState.staffDirectory
        .where((s) => s.role == 'counselor' && s.isActive)
        .toList();
    final counselors = activeCounselorAccounts.isNotEmpty
        ? activeCounselorAccounts
            .map((s) => {
                  'id': s.staffId,
                  'name': s.displayName,
                  'unit': s.unitName,
                })
            .toList()
        : [
            {
              'id': 'counselor_01',
              'name': 'ThS. Tâm lý Nguyễn Văn A (Phòng Tư vấn Sinh viên)',
              'unit': 'Phòng Tư vấn Tâm lý Sinh viên',
            },
            {
              'id': 'counselor_02',
              'name': 'ThS. Tâm lý Trần Thị B (Tổ Tư vấn Học đường)',
              'unit': 'Tổ Tư vấn Học đường',
            },
          ];

    if (!counselors.any((c) => c['id'] == _selectedCounselorId)) {
      _selectedCounselorId = counselors.first['id']!;
    }

    // Khung giờ trống thực tế của chuyên gia đang chọn (đồng bộ từ Lịch làm việc của Tư vấn viên A03)
    final counselorAvailableSlots = appState.counselorSlots
        .where(
            (s) => s.counselorId == _selectedCounselorId && s.isAvailable)
        .toList();
    final slotLabels = counselorAvailableSlots.isNotEmpty
        ? counselorAvailableSlots.map((s) => s.slotLabel).toSet().toList()
        : <String>[
            'Thứ 4 (09:00 - 10:00)',
            'Thứ 5 (14:00 - 15:00)',
            'Thứ 6 (09:00 - 10:00)',
          ];
    if (!slotLabels.contains(_selectedSlot)) {
      _selectedSlot = slotLabels.first;
    }

    final filteredMyBookings = appState.bookings.where((b) {
      if (_myBookingFilter == 'ALL') return true;
      return b.status == _myBookingFilter;
    }).toList();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: const Color(0xFFFEF2F2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: Color(0xFFFCA5A5)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 460;
                    final actionBtn = FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SafetySupportScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.shield_outlined, size: 18),
                      label: const Text('Xem ngay'),
                    );

                    const textBlock = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hỗ trợ An toàn & Đường dây nóng Khẩn cấp (S21)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Xem hướng dẫn an toàn tức thì (không yêu cầu đăng nhập hay làm bài test).',
                          style: TextStyle(fontSize: 13, color: Colors.black87),
                        ),
                      ],
                    );

                    if (isNarrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.emergency_rounded,
                                color: Colors.redAccent,
                                size: 26,
                              ),
                              SizedBox(width: 10),
                              Expanded(child: textBlock),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(width: double.infinity, child: actionBtn),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        const Icon(
                          Icons.emergency_rounded,
                          color: Colors.redAccent,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(child: textBlock),
                        const SizedBox(width: 12),
                        actionBtn,
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Đặt lịch hẹn với Chuyên gia Tư vấn Tâm lý của Trường (S23)',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Buổi trò chuyện trực tiếp 1-1 hoàn toàn bảo mật. Chỉ thông tin bạn điền bên dưới mới được gửi cho chuyên gia bạn chọn.',
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCounselorId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Chọn Chuyên gia / Đơn vị tư vấn',
                        prefixIcon: Icon(Icons.person_pin_rounded),
                        border: OutlineInputBorder(),
                      ),
                      items: counselors
                          .map((c) => DropdownMenuItem(
                                value: c['id'],
                                child: Text(c['name']!,
                                    overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        final nextSlots = appState.counselorSlots
                            .where((s) => s.counselorId == v && s.isAvailable)
                            .toList();
                        setState(() {
                          _selectedCounselorId = v;
                          if (nextSlots.isNotEmpty) {
                            _selectedSlot = nextSlots.first.slotLabel;
                            _selectedMode = nextSlots.first.consultationMode;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedSlot,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText:
                            'Chọn khung giờ còn trống (${slotLabels.length} ca đang mở)',
                        prefixIcon: const Icon(Icons.calendar_month_rounded),
                        border: const OutlineInputBorder(),
                      ),
                      items: slotLabels
                          .map((label) => DropdownMenuItem(
                                value: label,
                                child: Text(label,
                                    overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        final matchSlot = counselorAvailableSlots
                            .where((s) => s.slotLabel == v)
                            .firstOrNull;
                        setState(() {
                          _selectedSlot = v;
                          if (matchSlot != null) {
                            _selectedMode = matchSlot.consultationMode;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: slotLabels.map((slotLabel) {
                        final isPicked = _selectedSlot == slotLabel;
                        return ChoiceChip(
                          visualDensity: VisualDensity.compact,
                          avatar: Icon(
                            Icons.access_time_filled_rounded,
                            size: 14,
                            color: isPicked
                                ? const Color(0xFF3B5BDB)
                                : Colors.black45,
                          ),
                          label: Text(
                            slotLabel,
                            style: const TextStyle(fontSize: 11.5),
                          ),
                          selected: isPicked,
                          onSelected: (_) {
                            final matchSlot = counselorAvailableSlots
                                .where((s) => s.slotLabel == slotLabel)
                                .firstOrNull;
                            setState(() {
                              _selectedSlot = slotLabel;
                              if (matchSlot != null) {
                                _selectedMode = matchSlot.consultationMode;
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Hình thức tham vấn mong muốn:',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          avatar: const Icon(Icons.meeting_room_outlined,
                              size: 16),
                          label: const Text('Trực tiếp tại phòng P.102'),
                          selected: _selectedMode.contains('Trực tiếp'),
                          onSelected: (_) => setState(
                              () => _selectedMode = 'Trực tiếp tại phòng P.102'),
                        ),
                        ChoiceChip(
                          avatar:
                              const Icon(Icons.videocam_outlined, size: 16),
                          label: const Text('Trực tuyến (Google Meet)'),
                          selected: _selectedMode.contains('Trực tuyến'),
                          onSelected: (_) => setState(
                              () => _selectedMode = 'Trực tuyến (Google Meet)'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _contactCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Email hoặc Số điện thoại nhận xác nhận lịch',
                        prefixIcon: Icon(Icons.contact_mail_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _noteCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText:
                            'Vấn đề bạn muốn được tư vấn (Tùy chọn, không bắt buộc)',
                        prefixIcon: Icon(Icons.notes_rounded),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _consentShareBooking,
                      onChanged: (v) =>
                          setState(() => _consentShareBooking = v ?? false),
                      title: const Text(
                        'Tôi đồng ý chia sẻ thông tin liên hệ và khung giờ này cho Tư vấn viên phụ trách. (Lịch sử chat AI và điểm sàng lọc KHÔNG tự động đính kèm).',
                        style: TextStyle(fontSize: 13),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          final contact = _contactCtrl.text.trim();
                          final selectedCounselor = counselors.firstWhere(
                            (c) => c['id'] == _selectedCounselorId,
                          );
                          if (!_consentShareBooking) {
                            ref
                                .read(mindCheckProvider.notifier)
                                .createCounselingBooking(
                                  unitName: selectedCounselor['unit'] ??
                                      'Phòng Tư vấn Tâm lý Sinh viên',
                                  counselorId: _selectedCounselorId,
                                  counselorName: selectedCounselor['name']!,
                                  slotTime: _selectedSlot,
                                  consultationMode: _selectedMode,
                                  contactInfo: contact,
                                  studentNote: _noteCtrl.text.trim(),
                                  agreedToShare: false,
                                );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Vui lòng tích chọn đồng ý chia sẻ thông tin liên hệ trước khi gửi lịch hẹn (R2).'),
                              ),
                            );
                            return;
                          }
                          if (!MindCheckApiService.isValidContactInfo(contact)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Vui lòng nhập Email hoặc Số điện thoại hợp lệ (8–17 chữ số) để nhận xác nhận lịch hẹn.'),
                              ),
                            );
                            return;
                          }
                          final created = ref
                              .read(mindCheckProvider.notifier)
                              .createCounselingBooking(
                                unitName: selectedCounselor['unit'] ??
                                    'Phòng Tư vấn Tâm lý Sinh viên',
                                counselorId: _selectedCounselorId,
                                counselorName: selectedCounselor['name']!,
                                slotTime: _selectedSlot,
                                consultationMode: _selectedMode,
                                contactInfo: contact,
                                studentNote: _noteCtrl.text.trim(),
                                agreedToShare: _consentShareBooking,
                              );
                          if (created != null) {
                            _noteCtrl.clear();
                            setState(() => _consentShareBooking = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Đã gửi yêu cầu đặt lịch (${created.requestId}) thành công!'),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.send_rounded),
                        label: const Text('Xác nhận gửi yêu cầu đặt lịch'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Lịch hẹn tư vấn của bạn (S24)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ChoiceChip(
                      label: Text('Tất cả (${appState.bookings.length})',
                          style: const TextStyle(fontSize: 12)),
                      selected: _myBookingFilter == 'ALL',
                      onSelected: (_) =>
                          setState(() => _myBookingFilter = 'ALL'),
                    ),
                    ChoiceChip(
                      label: const Text('Chờ duyệt',
                          style: TextStyle(fontSize: 12)),
                      selected: _myBookingFilter == 'pending',
                      onSelected: (_) =>
                          setState(() => _myBookingFilter = 'pending'),
                    ),
                    ChoiceChip(
                      label: const Text('Đã xác nhận',
                          style: TextStyle(fontSize: 12)),
                      selected: _myBookingFilter == 'confirmed',
                      onSelected: (_) =>
                          setState(() => _myBookingFilter = 'confirmed'),
                    ),
                    ChoiceChip(
                      label: const Text('Hoàn tất',
                          style: TextStyle(fontSize: 12)),
                      selected: _myBookingFilter == 'completed',
                      onSelected: (_) =>
                          setState(() => _myBookingFilter = 'completed'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (filteredMyBookings.isEmpty)
              const Card(
                color: Colors.white,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Bạn chưa có lịch hẹn tư vấn nào. Khi bạn gửi yêu cầu đặt lịch ở trên, trạng thái phản hồi từ chuyên gia sẽ hiển thị tại đây.',
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
              ),
            ...filteredMyBookings.map(
              (b) => Card(
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
                          CircleAvatar(
                            backgroundColor: b.status == 'confirmed'
                                ? const Color(0xFFE6FCF5)
                                : const Color(0xFFEDF2FF),
                            child: Icon(
                              b.status == 'confirmed'
                                  ? Icons.event_available_rounded
                                  : Icons.event_note_rounded,
                              color: b.status == 'confirmed'
                                  ? const Color(0xFF0CA678)
                                  : const Color(0xFF3B5BDB),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${b.counselorName} • ${b.slotTime}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14.5),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Hình thức: ${b.consultationMode} • Mã ca: ${b.requestId}\n'
                                  'Liên hệ: ${b.contactInfo}\n'
                                  'Trạng thái: ${b.status == "pending" ? "Đang chờ xác nhận" : (b.status == "confirmed" ? "Đã xác nhận lịch" : (b.status == "completed" ? "Đã hoàn tất" : (b.status == "declined" ? "Chuyên gia hẹn đổi lịch" : "Đã hủy")))}'
                                  '${b.counselorNote.isNotEmpty ? "\n💬 Phản hồi từ Tư vấn viên: ${b.counselorNote}" : ""}',
                                  style: const TextStyle(
                                      fontSize: 13, color: Colors.black87),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Thanh tiến trình trực quan 3 bước của lịch hẹn
                      _BookingTimelineBar(status: b.status),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: b.status == 'pending' || b.status == 'confirmed'
                            ? TextButton.icon(
                                onPressed: () => ref
                                    .read(mindCheckProvider.notifier)
                                    .updateBookingStatus(
                                      requestId: b.requestId,
                                      newStatus: 'canceled',
                                      actorLabel: 'Student',
                                    ),
                                icon: const Icon(Icons.cancel_outlined,
                                    size: 16, color: Colors.redAccent),
                                label: const Text('Hủy lịch',
                                    style: TextStyle(color: Colors.redAccent)),
                              )
                            : Chip(
                                visualDensity: VisualDensity.compact,
                                label: Text(b.status.toUpperCase(),
                                    style: const TextStyle(fontSize: 11)),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingTimelineBar extends StatelessWidget {
  final String status;
  const _BookingTimelineBar({required this.status});

  @override
  Widget build(BuildContext context) {
    final isCanceledOrDeclined =
        status == 'canceled' || status == 'declined';
    final step2Done = status == 'confirmed' || status == 'completed';
    final step3Done = status == 'completed';

    if (isCanceledOrDeclined) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, size: 15, color: Colors.redAccent),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                status == 'declined'
                    ? 'Chuyên gia đề nghị đổi sang khung giờ khác — Bạn có thể tạo lịch hẹn mới ở trên.'
                    : 'Lịch hẹn này đã được hủy theo yêu cầu của bạn.',
                style: const TextStyle(fontSize: 11.5, color: Colors.redAccent),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          _buildStepDot('1. Đã gửi', true),
          Expanded(
            child: Divider(
              color: step2Done
                  ? const Color(0xFF0CA678)
                  : const Color(0xFFCBD5E1),
              thickness: 2,
              indent: 6,
              endIndent: 6,
            ),
          ),
          _buildStepDot('2. Đã xác nhận', step2Done),
          Expanded(
            child: Divider(
              color: step3Done
                  ? const Color(0xFF0CA678)
                  : const Color(0xFFCBD5E1),
              thickness: 2,
              indent: 6,
              endIndent: 6,
            ),
          ),
          _buildStepDot('3. Hoàn tất', step3Done),
        ],
      ),
    );
  }

  Widget _buildStepDot(String label, bool active) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          active ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
          size: 15,
          color: active ? const Color(0xFF0CA678) : Colors.black38,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
            color: active ? const Color(0xFF087F5B) : Colors.black54,
          ),
        ),
      ],
    );
  }
}

class SafetySupportScreen extends ConsumerWidget {
  const SafetySupportScreen({super.key});

  void _copyNumber(BuildContext context, String number, String label) {
    Clipboard.setData(ClipboardData(text: number));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã sao chép số $number ($label) để bạn quay số nhanh.'),
      ),
    );
  }

  Future<void> _dialOrCopyNumber(
    BuildContext context,
    String number,
    String label,
  ) async {
    Clipboard.setData(ClipboardData(text: number));
    final dialed = await MindCheckDeviceLauncher.dialEmergencyNumber(number);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          dialed
              ? 'Đang mở trình quay số khẩn cấp $number ($label)...'
              : 'Đã chuẩn bị số khẩn cấp $number ($label) vào bộ nhớ tạm để bạn gọi ngay.',
        ),
      ),
    );
  }

  Color _colorForHotline(SafetyHotlineModel h) {
    if (h.phone == '115') return const Color(0xFFDC2626);
    if (h.phone == '111') return const Color(0xFFD97706);
    return const Color(0xFF3B5BDB);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(mindCheckProvider);
    final hotlines = appState.safetyHotlines;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFDC2626),
        foregroundColor: Colors.white,
        title: const Text('Hỗ trợ An toàn & Khẩn cấp (S21)'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
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
                      const Row(
                        children: [
                          Icon(Icons.health_and_safety_rounded,
                              color: Color(0xFFDC2626), size: 28),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Hướng dẫn An toàn & Liên hệ Khẩn cấp',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Bạn không phải đi qua lúc khó khăn này một mình. Nếu bạn đang cảm thấy mất an toàn hoặc kiệt sức quá mức, hãy kết nối ngay với con người thực qua các kênh đã kiểm chứng dưới đây:',
                        style: TextStyle(height: 1.45),
                      ),
                      const SizedBox(height: 14),
                      if (hotlines.isEmpty) ...[
                        _EmergencyContactTile(
                          badge: '115',
                          title: 'Cấp cứu Y tế Toàn quốc (24/7)',
                          subtitle:
                              'Gọi ngay khi có nguy cơ tổn hại sức khỏe thể chất hoặc cần can thiệp y tế khẩn cấp.',
                          color: const Color(0xFFDC2626),
                          onDial: () => _dialOrCopyNumber(
                              context, '115', 'Cấp cứu Y tế'),
                          onCopy: () =>
                              _copyNumber(context, '115', 'Cấp cứu Y tế'),
                        ),
                        const SizedBox(height: 10),
                        _EmergencyContactTile(
                          badge: '111',
                          title:
                              'Tổng đài Quốc gia Bảo vệ & Hỗ trợ Khẩn cấp (24/7)',
                          subtitle:
                              'Miễn phí cước gọi toàn quốc, lắng nghe và kết nối hỗ trợ tâm lý - xã hội khẩn cấp.',
                          color: const Color(0xFFD97706),
                          onDial: () => _dialOrCopyNumber(
                              context, '111', 'Tổng đài Quốc gia 111'),
                          onCopy: () => _copyNumber(
                              context, '111', 'Tổng đài Quốc gia 111'),
                        ),
                      ] else
                        ...hotlines.map(
                          (h) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _EmergencyContactTile(
                              badge: h.phone,
                              title: '${h.name} (${h.hours})',
                              subtitle: h.description,
                              color: _colorForHotline(h),
                              onDial: () =>
                                  _dialOrCopyNumber(context, h.phone, h.name),
                              onCopy: () =>
                                  _copyNumber(context, h.phone, h.name),
                            ),
                          ),
                        ),
                      const Divider(height: 24),
                      const Text(
                        'Lưu ý quan trọng về giới hạn dịch vụ: MindCheck Campus là người bạn đồng hành ban đầu, KHÔNG giám sát 24/7, không tự động gọi cấp cứu và không tự động gửi cảnh báo cho người thân hay nhà trường.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.black54,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Card(
                color: Color(0xFFE6FCF5),
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.spa_rounded, color: Color(0xFF087F5B)),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '3 bước giữ an toàn cho bản thân ngay lúc này',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Color(0xFF087F5B),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                      Text(
                        '1. Tạm rời khỏi không gian kín hoặc vật dụng có thể gây tổn thương; di chuyển đến nơi có ánh sáng hoặc có người xung quanh.\n'
                        '2. Đặt hai bàn chân chạm sàn, thở chậm ra dài hơn hít vào trong 3 nhịp để làm dịu hệ thần kinh.\n'
                        '3. Nhắn tin hoặc gọi cho ít nhất 1 người bạn tin tưởng ("Mình đang rất mệt, bạn ở cạnh hoặc nghe máy giúp mình một chút nhé").',
                        style: TextStyle(height: 1.5, color: Color(0xFF1E293B)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmergencyContactTile extends StatelessWidget {
  final String badge;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onDial;
  final VoidCallback? onCopy;

  const _EmergencyContactTile({
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.color,
    this.onDial,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onDial ?? onCopy,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                badge,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14.5),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12.5, color: Colors.black87),
                ),
              ],
            ),
          ),
          if (onDial != null)
            IconButton(
              tooltip: 'Gọi khẩn cấp $badge',
              onPressed: onDial,
              icon: Icon(Icons.phone_in_talk_rounded, size: 19, color: color),
            ),
          if (onCopy != null)
            IconButton(
              tooltip: 'Sao chép số $badge',
              onPressed: onCopy,
              icon: Icon(Icons.copy_rounded, size: 18, color: color),
            ),
        ],
      ),
    );
  }
}
