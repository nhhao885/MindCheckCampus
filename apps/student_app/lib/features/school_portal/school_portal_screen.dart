import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/state_provider.dart';
import '../../shared/models.dart';

class SchoolPortalShell extends ConsumerStatefulWidget {
  final VoidCallback onSwitchToStudentApp;
  const SchoolPortalShell({super.key, required this.onSwitchToStudentApp});

  @override
  ConsumerState<SchoolPortalShell> createState() => _SchoolPortalShellState();
}

class _SchoolPortalShellState extends ConsumerState<SchoolPortalShell> {
  ActorRole _staffRole = ActorRole.ctsv;

  // Bộ lọc Dashboard CTSV (D02-D04) — ánh xạ trực tiếp tới dữ liệu thực tế
  String _facultyFilter = 'ALL';
  String _academicYearFilter = 'ALL';
  String _periodFilter = 'ALL';

  // Bộ lọc, tìm kiếm & ghi chú phản hồi của Tư vấn viên (D05-D06)
  String _bookingStatusFilter = 'ALL';
  String _bookingSearchQuery = '';
  bool _showCrossCounselorSecurityTest = true;
  final TextEditingController _bookingSearchCtrl = TextEditingController();
  final Map<String, TextEditingController> _replyNoteCtrls = {};

  // Bộ lọc & tìm kiếm Nhật ký kiểm toán của Quản trị viên (D07)
  String _auditActionFilter = 'ALL';
  String _auditSearchQuery = '';
  final TextEditingController _auditSearchCtrl = TextEditingController();

  ActorRole _effectiveRole(MindCheckAppState appState) {
    if (!appState.isStaffDemoSwitchEnabled &&
        appState.authenticatedStaffRole != null) {
      return appState.authenticatedStaffRole!;
    }
    return _staffRole;
  }

  String _activeStaffIdForRole(ActorRole role, MindCheckAppState appState) {
    if (!appState.isStaffDemoSwitchEnabled &&
        appState.authenticatedStaffId != null) {
      return appState.authenticatedStaffId!;
    }
    switch (role) {
      case ActorRole.ctsv:
        return 'ctsv_01';
      case ActorRole.counselor1:
        return 'counselor_01';
      case ActorRole.counselor2:
        return 'counselor_02';
      case ActorRole.admin:
        return 'admin_01';
      case ActorRole.student:
        return 'ctsv_01';
    }
  }

  TextEditingController _getReplyCtrl(CounselingBookingModel booking) {
    return _replyNoteCtrls.putIfAbsent(
      booking.requestId,
      () => TextEditingController(text: booking.counselorNote),
    );
  }

  @override
  void dispose() {
    _bookingSearchCtrl.dispose();
    _auditSearchCtrl.dispose();
    for (final ctrl in _replyNoteCtrls.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _showStaffLoginDialog(BuildContext context, MindCheckAppState appState) {
    final role = _effectiveRole(appState);
    final defaultId = _activeStaffIdForRole(role, appState);
    final staffIdCtrl = TextEditingController(text: defaultId);
    final passCtrl = TextEditingController(text: 'MindCheck#2026');
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            title: const Text('Đăng nhập Nhân sự Nhà trường (D01)'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Khi đăng nhập thành công, hệ thống tự động khóa giao diện đúng theo Vai trò (Role) của tài khoản nhân sự:',
                    style: TextStyle(fontSize: 12.5, color: Colors.black54),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: appState.staffDirectory
                        .where((s) => s.isActive)
                        .map((s) {
                      return ActionChip(
                        visualDensity: VisualDensity.compact,
                        avatar: const Icon(Icons.badge_outlined, size: 15),
                        label: Text('${s.staffId} (${s.role.toUpperCase()})',
                            style: const TextStyle(fontSize: 11.5)),
                        onPressed: () =>
                            setModalState(() => staffIdCtrl.text = s.staffId),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: staffIdCtrl,
                    decoration: const InputDecoration(
                      labelText:
                          'Mã nhân sự (ctsv_01 / counselor_01 / admin_01)',
                      prefixIcon: Icon(Icons.badge_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Mật khẩu nhân sự',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Đóng'),
              ),
              FilledButton.icon(
                onPressed: () async {
                  final targetId = staffIdCtrl.text.trim();
                  final ok = await ref
                      .read(mindCheckProvider.notifier)
                      .loginStaffMember(targetId, passCtrl.text);
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  if (!context.mounted) return;
                  final updatedState = ref.read(mindCheckProvider);
                  if (ok && updatedState.authenticatedStaffRole != null) {
                    setState(() {
                      _staffRole = updatedState.authenticatedStaffRole!;
                    });
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        ok
                            ? 'Đã xác thực phiên nhân sự $targetId và khóa giao diện theo Role!'
                            : 'Không thể xác thực tài khoản $targetId (tài khoản bị khóa hoặc sai thông tin).',
                      ),
                    ),
                  );
                  if (ok) {
                    final effRole = _effectiveRole(updatedState);
                    ref
                        .read(mindCheckProvider.notifier)
                        .refreshPortalDataFromServer(
                          faculty: _facultyFilter,
                          academicYear: _academicYearFilter,
                          period: _periodFilter,
                          activeCounselorId: (effRole == ActorRole.counselor1 ||
                                  effRole == ActorRole.counselor2)
                              ? targetId
                              : null,
                        );
                  }
                },
                icon: const Icon(Icons.login_rounded, size: 18),
                label: const Text('Đăng nhập & Khóa theo Role'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showExportAnalyticsModal(
    BuildContext context, {
    required bool isSuppressed,
    required int sampleSize,
    required int minGroup,
    required int totalScreenings,
    required int totalHighRisk,
    required String highRiskPct,
    required int totalConnected,
    required int moodCount,
    required String avgMoodStr,
    required int cbtCompleted,
  }) {
    final nowStr = DateTime.now().toIso8601String().substring(0, 10);
    final csvContent = isSuppressed
        ? 'ngay_bao_cao,khoa,nam_hoc,ky_thong_ke,co_mau_n,nguong_k_anonymity,trang_thai\n'
            '$nowStr,$_facultyFilter,$_academicYearFilter,$_periodFilter,$sampleSize,$minGroup,LOCKED_K_ANONYMITY'
        : 'ngay_bao_cao,khoa,nam_hoc,ky_thong_ke,tong_sang_loc,nguy_co_can_chu_y,ty_le_nguy_co_pct,ket_noi_tu_van,luot_checkin_cam_xuc,diem_cam_xuc_tb,hoan_thanh_cbt,co_chua_pii\n'
            '$nowStr,$_facultyFilter,$_academicYearFilter,$_periodFilter,$totalScreenings,$totalHighRisk,$highRiskPct,$totalConnected,$moodCount,$avgMoodStr,$cbtCompleted,FALSE';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xuất Báo cáo Thống kê Ẩn danh (CSV / Bản in)'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isSuppressed
                    ? '🔒 Nhóm lọc hiện tại (n = $sampleSize < ngưỡng $minGroup) đang được bảo vệ bởi k-Anonymity nên bản xuất chỉ ghi nhận trạng thái khóa bảo mật.'
                    : '✅ Báo cáo tổng hợp từ vùng Anon_Clinical (cam kết 0% PII, không chứa thông tin định danh hay hội thoại riêng tư):',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: SelectableText(
                  csvContent,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
          FilledButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: csvContent));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'Đã sao chép dữ liệu báo cáo CSV ẩn danh vào bộ nhớ tạm!'),
                ),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 17),
            label: const Text('Sao chép CSV'),
          ),
        ],
      ),
    );
  }

  void _showArticleEditorDialog(
    BuildContext context, {
    KnowledgeArticleModel? existing,
    required String actorId,
  }) {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final catCtrl = TextEditingController(
        text: existing?.category ?? 'Kỹ năng Tự chăm sóc');
    final sumCtrl = TextEditingController(text: existing?.summary ?? '');
    final contentCtrl = TextEditingController(text: existing?.content ?? '');
    final srcCtrl = TextEditingController(
        text: existing?.verifiedSource ??
            'Phòng Tư vấn Tâm lý & Công tác Sinh viên');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null
            ? 'Thêm bài viết Thư viện Kiến thức mới'
            : 'Chỉnh sửa bài viết Kiến thức'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tiêu đề bài viết hướng dẫn',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: catCtrl,
                decoration: const InputDecoration(
                  labelText: 'Chủ đề (VD: Học tập & Thi cử, Chăm sóc giấc ngủ)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: sumCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tóm tắt ngắn gọn',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: contentCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Nội dung hướng dẫn chi tiết',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: srcCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nguồn kiểm duyệt chuyên môn',
                  border: OutlineInputBorder(),
                ),
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
              final saved = ref
                  .read(mindCheckProvider.notifier)
                  .upsertKnowledgeArticle(
                    id: existing?.id,
                    title: titleCtrl.text,
                    category: catCtrl.text,
                    summary: sumCtrl.text,
                    content: contentCtrl.text,
                    verifiedSource: srcCtrl.text,
                    actor: actorId,
                  );
              if (saved != null) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Đã cập nhật bài viết vào Thư viện Kiến thức của sinh viên!'),
                  ),
                );
              }
            },
            child: const Text('Lưu bài viết'),
          ),
        ],
      ),
    );
  }

  void _showAddCounselorSlotDialog(
    BuildContext context, {
    required String counselorId,
    required String counselorName,
    required String unitName,
  }) {
    final slotCtrl = TextEditingController();
    String mode = 'Trực tiếp tại phòng P.102';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Thêm Khung giờ làm việc mới'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: slotCtrl,
                decoration: const InputDecoration(
                  labelText: 'Khung giờ (VD: Thứ 3 (09:30 - 10:30))',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: mode,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Hình thức tư vấn',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Trực tiếp tại phòng P.102',
                    child: Text('Trực tiếp tại phòng P.102'),
                  ),
                  DropdownMenuItem(
                    value: 'Trực tiếp tại phòng P.204',
                    child: Text('Trực tiếp tại phòng P.204'),
                  ),
                  DropdownMenuItem(
                    value: 'Trực tuyến (Google Meet)',
                    child: Text('Trực tuyến (Google Meet)'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) setModalState(() => mode = v);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                final created = ref
                    .read(mindCheckProvider.notifier)
                    .addCounselorSlot(
                      counselorId: counselorId,
                      counselorName: counselorName,
                      unitName: unitName,
                      slotLabel: slotCtrl.text,
                      consultationMode: mode,
                    );
                if (created != null) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Đã mở thêm khung giờ tư vấn mới và đồng bộ sang màn hình S23 của sinh viên!'),
                    ),
                  );
                }
              },
              child: const Text('Thêm khung giờ'),
            ),
          ],
        ),
      ),
    );
  }

  void _showUpsertStaffDialog(
    BuildContext context, {
    StaffAccountModel? existing,
  }) {
    final idCtrl = TextEditingController(text: existing?.staffId ?? '');
    final nameCtrl = TextEditingController(text: existing?.displayName ?? '');
    final unitCtrl = TextEditingController(
        text: existing?.unitName ?? 'Phòng Tư vấn Tâm lý Sinh viên');
    final passCtrl = TextEditingController();
    String selectedRole = existing?.role ?? 'counselor';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text(existing == null
              ? 'Thêm Tài khoản Nhân sự / Chuyên gia mới'
              : 'Cập nhật Tài khoản Nhân sự (${existing.staffId})'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: idCtrl,
                  enabled: existing == null,
                  decoration: const InputDecoration(
                    labelText: 'Mã nhân sự (VD: counselor_03 / ctsv_02)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Họ tên & Học vị hiển thị',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Vai trò phân quyền RBAC',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'ctsv',
                      child: Text('A02 • Nhân viên Phòng CTSV (Analytics)'),
                    ),
                    DropdownMenuItem(
                      value: 'counselor',
                      child: Text('A03 • Tư vấn viên Tâm lý Học đường'),
                    ),
                    DropdownMenuItem(
                      value: 'admin',
                      child: Text('A04 • Quản trị viên Hệ thống (Admin)'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setModalState(() => selectedRole = v);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: unitCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Đơn vị công tác',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Mật khẩu khởi tạo / đặt lại (>= 6 ký tự)',
                    border: OutlineInputBorder(),
                  ),
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
                final saved = ref
                    .read(mindCheckProvider.notifier)
                    .upsertStaffAccount(
                      staffId: idCtrl.text,
                      role: selectedRole,
                      displayName: nameCtrl.text,
                      unitName: unitCtrl.text,
                      password: passCtrl.text,
                      isActive: existing?.isActive ?? true,
                    );
                if (saved != null) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Đã lưu thông tin nhân sự ${saved.staffId} (${saved.role.toUpperCase()})!'),
                    ),
                  );
                }
              },
              child: const Text('Lưu tài khoản'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddHotlineDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final hoursCtrl = TextEditingController(text: '24/7');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thêm Đường dây nóng Hỗ trợ An toàn (S21)'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tên đơn vị hỗ trợ khẩn cấp',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(
                  labelText: 'Số điện thoại liên hệ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: hoursCtrl,
                decoration: const InputDecoration(
                  labelText: 'Khung giờ trực hỗ trợ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Mô tả phạm vi hỗ trợ',
                  border: OutlineInputBorder(),
                ),
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
              final saved = ref
                  .read(mindCheckProvider.notifier)
                  .upsertSafetyHotline(
                    name: nameCtrl.text,
                    phone: phoneCtrl.text,
                    description: descCtrl.text,
                    hours: hoursCtrl.text,
                  );
              if (saved != null) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Đã cập nhật danh bạ khẩn cấp S21 và đồng bộ sang ứng dụng sinh viên!'),
                  ),
                );
              }
            },
            child: const Text('Lưu Hotline'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(mindCheckProvider);
    final effectiveRole = _effectiveRole(appState);
    final activeStaffId = _activeStaffIdForRole(effectiveRole, appState);
    final hasServerToken = appState.staffTokens.containsKey(activeStaffId);
    final isRoleLocked = !appState.isStaffDemoSwitchEnabled &&
        appState.authenticatedStaffId != null;

    return LayoutBuilder(
      builder: (context, portalConstraints) {
        final screenWidth = portalConstraints.maxWidth;
        final isCompact = screenWidth < 560;

        return Scaffold(
          backgroundColor: const Color(0xFFF1F5F9),
          appBar: AppBar(
            backgroundColor: const Color(0xFF1E3A8A),
            foregroundColor: Colors.white,
            titleSpacing: isCompact ? 10 : 16,
            title: Row(
              children: [
                const Icon(Icons.analytics_outlined, size: 22),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'MindCheck Campus — Cổng Quản trị & Tư vấn Học đường (D01–D07)',
                    style: TextStyle(
                      fontSize: isCompact ? 14.5 : 17,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                visualDensity: isCompact ? VisualDensity.compact : null,
                constraints: isCompact
                    ? const BoxConstraints(minWidth: 36, minHeight: 36)
                    : null,
                padding: isCompact ? const EdgeInsets.all(6) : null,
                tooltip: 'Đồng bộ số liệu trực tiếp từ Máy chủ',
                onPressed: () {
                  ref
                      .read(mindCheckProvider.notifier)
                      .refreshPortalDataFromServer(
                        faculty: _facultyFilter,
                        academicYear: _academicYearFilter,
                        period: _periodFilter,
                        activeCounselorId:
                            (effectiveRole == ActorRole.counselor1 ||
                                    effectiveRole == ActorRole.counselor2)
                                ? activeStaffId
                                : null,
                      );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đang đồng bộ dữ liệu thực từ máy chủ...'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                icon: const Icon(Icons.sync_rounded),
              ),
              FilledButton.tonalIcon(
                style: isCompact
                    ? FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        visualDensity: VisualDensity.compact,
                      )
                    : null,
                onPressed: widget.onSwitchToStudentApp,
                icon: const Icon(Icons.phone_iphone_rounded, size: 17),
                label: Text(isCompact ? 'App SV' : 'Mở Ứng dụng Sinh viên'),
              ),
              SizedBox(width: isCompact ? 8 : 12),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              // Tối ưu chuẩn Dashboard Web 1280–1440px (T29) & tương thích Mobile/Tablet
              constraints: const BoxConstraints(maxWidth: 1380),
              child: ListView(
                cacheExtent: 2400,
                padding: EdgeInsets.all(isCompact ? 12 : 20),
                children: [
                  // Thanh xác thực Nhân sự (D01) & Chế độ Demo/Chuyển nhanh Actor
                  Card(
                    color: const Color(0xFFEDF2FF),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isRoleLocked
                                        ? Icons.lock_person_rounded
                                        : Icons.verified_user_rounded,
                                    color: const Color(0xFF1E3A8A),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      isRoleLocked
                                          ? 'Phiên nhân sự đang khóa theo Role: $activeStaffId (Đã ẩn các vai trò khác - D01)'
                                          : 'Vai trò nhân sự đang đăng nhập (Kiểm soát truy cập RBAC nghiêm ngặt - D01):',
                                      style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  FilterChip(
                                    visualDensity: VisualDensity.compact,
                                    selected: appState.isStaffDemoSwitchEnabled,
                                    avatar: Icon(
                                      appState.isStaffDemoSwitchEnabled
                                          ? Icons.swap_horiz_rounded
                                          : Icons.lock_outline_rounded,
                                      size: 16,
                                    ),
                                    label: Text(
                                      appState.isStaffDemoSwitchEnabled
                                          ? 'Chế độ Demo / Chuyển nhanh Actor: BẬT'
                                          : 'Chế độ Khóa Role (Strict RBAC)',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    onSelected: (val) => ref
                                        .read(mindCheckProvider.notifier)
                                        .toggleStaffDemoSwitchMode(val),
                                  ),
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    onPressed: () =>
                                        _showStaffLoginDialog(context, appState),
                                    icon: Icon(
                                      hasServerToken
                                          ? Icons.verified_rounded
                                          : Icons.key_rounded,
                                      size: 16,
                                      color: hasServerToken
                                          ? const Color(0xFF0CA678)
                                          : const Color(0xFF1E3A8A),
                                    ),
                                    label: Text(
                                      hasServerToken
                                          ? 'Đã xác thực ($activeStaffId)'
                                          : 'Xác thực Token Nhân sự',
                                      style: const TextStyle(fontSize: 12.5),
                                    ),
                                  ),
                                  if (appState.authenticatedStaffId != null)
                                    TextButton.icon(
                                      style: TextButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      onPressed: () {
                                        ref
                                            .read(mindCheckProvider.notifier)
                                            .logoutStaffMember();
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                'Đã đăng xuất phiên nhân sự.'),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.logout_rounded,
                                          size: 16),
                                      label: const Text('Đăng xuất',
                                          style: TextStyle(fontSize: 12)),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          if (appState.isStaffDemoSwitchEnabled) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              children: [
                                ChoiceChip(
                                  label: const Text(
                                      'A02 • Nhân viên CTSV (Dashboard Tổng hợp Ẩn danh)'),
                                  selected: effectiveRole == ActorRole.ctsv,
                                  onSelected: (_) => setState(
                                      () => _staffRole = ActorRole.ctsv),
                                ),
                                ChoiceChip(
                                  label: const Text(
                                      'A03 • Tư vấn viên 1: ThS. Nguyễn Văn A'),
                                  selected:
                                      effectiveRole == ActorRole.counselor1,
                                  onSelected: (_) => setState(
                                      () => _staffRole = ActorRole.counselor1),
                                ),
                                ChoiceChip(
                                  label: const Text(
                                      'A03 • Tư vấn viên 2: ThS. Trần Thị B (Test chặn chéo T25)'),
                                  selected:
                                      effectiveRole == ActorRole.counselor2,
                                  onSelected: (_) => setState(
                                      () => _staffRole = ActorRole.counselor2),
                                ),
                                ChoiceChip(
                                  label: const Text(
                                      'A04 • Quản trị viên Hệ thống (RBAC & k-Anonymity Policy)'),
                                  selected: effectiveRole == ActorRole.admin,
                                  onSelected: (_) => setState(
                                      () => _staffRole = ActorRole.admin),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ================================================================
                  // 1. ACTOR A02 – NHÂN VIÊN CTSV (D02–D04)
                  // ================================================================
                  if (effectiveRole == ActorRole.ctsv)
                    _buildCtsvDashboard(context, appState, activeStaffId),

                  // ================================================================
                  // 2. ACTOR A03 – TƯ VẤN VIÊN TÂM LÝ (D05–D06)
                  // ================================================================
                  if (effectiveRole == ActorRole.counselor1 ||
                      effectiveRole == ActorRole.counselor2)
                    _buildCounselorWorkspace(
                        context, appState, effectiveRole, activeStaffId),

                  // ================================================================
                  // 3. ACTOR A04 – QUẢN TRỊ VIÊN HỆ THỐNG (D07)
                  // ================================================================
                  if (effectiveRole == ActorRole.admin)
                    _buildAdminGovernancePanel(
                        context, appState, activeStaffId),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // ACTOR A02: NHÂN VIÊN PHÒNG CÔNG TÁC SINH VIÊN (D02–D04)
  // ===========================================================================
  Widget _buildCtsvDashboard(
    BuildContext context,
    MindCheckAppState appState,
    String activeStaffId,
  ) {
    final serverMatch = appState.serverAnalytics != null &&
            appState.serverAnalytics!.faculty == _facultyFilter &&
            appState.serverAnalytics!.academicYear == _academicYearFilter &&
            appState.serverAnalytics!.period == _periodFilter
        ? appState.serverAnalytics
        : null;

    final now = DateTime.now();
    final filteredScreenings = appState.screeningHistory.where((r) {
      final facOk = _facultyFilter == 'ALL' || r.faculty == _facultyFilter;
      final yrOk = _academicYearFilter == 'ALL' ||
          r.academicYear == _academicYearFilter;
      bool periodOk = true;
      if (_periodFilter == '7d') {
        periodOk = now.difference(r.completedAt).inDays <= 7;
      } else if (_periodFilter == '30d') {
        periodOk = now.difference(r.completedAt).inDays <= 30;
      } else if (_periodFilter == 'semester') {
        periodOk = now.difference(r.completedAt).inDays <= 120;
      }
      return facOk && yrOk && periodOk;
    }).toList();

    final minGroup = serverMatch?.minGroupSize ?? appState.minGroupSizePolicy;
    final sampleSize = serverMatch?.sampleSize ?? filteredScreenings.length;
    final isSuppressed = serverMatch?.suppressed ?? (sampleSize < minGroup);

    final totalScreenings =
        serverMatch?.totalScreenings ?? filteredScreenings.length;
    final totalHighRisk = serverMatch?.highRiskCount ??
        filteredScreenings.where((r) => r.requiresAttention).length;
    final highRiskPct = totalScreenings > 0
        ? ((totalHighRisk / totalScreenings) * 100).toStringAsFixed(1)
        : '0.0';
    final totalConnected = serverMatch?.connectedBookingsCount ??
        appState.bookings
            .where((b) => b.status != 'canceled' && b.status != 'declined')
            .length;
    final conversionRate = serverMatch != null &&
            serverMatch.bookingConversionRate > 0
        ? serverMatch.bookingConversionRate.toStringAsFixed(1)
        : (totalScreenings > 0
            ? ((totalConnected / totalScreenings) * 100)
                .clamp(0.0, 100.0)
                .toStringAsFixed(1)
            : '0.0');

    final moodCount =
        serverMatch?.moodCheckinCount ?? appState.moodEntries.length;
    final avgMood = serverMatch != null && serverMatch.avgMoodLevel > 0
        ? serverMatch.avgMoodLevel
        : (appState.moodEntries.isEmpty
            ? 0.0
            : appState.moodEntries
                    .map((e) => e.moodLevel)
                    .reduce((a, b) => a + b) /
                appState.moodEntries.length);
    final avgMoodStr = avgMood.toStringAsFixed(1);
    final cbtCompleted = serverMatch?.cbtCompletedCount ??
        appState.dailyActivities.where((a) => a.status == 'completed').length;

    // Tính phân bổ thực tế theo công cụ sàng lọc / chủ đề từ dữ liệu thật
    final List<Map<String, dynamic>> topics;
    if (serverMatch != null && serverMatch.topTopics.isNotEmpty) {
      const palette = [
        Color(0xFF3B5BDB),
        Color(0xFF0CA678),
        Color(0xFFF59E0B),
        Color(0xFF8B5CF6),
      ];
      topics = List.generate(serverMatch.topTopics.length, (idx) {
        final item = serverMatch.topTopics[idx];
        return {
          'label': item.topic,
          'pct': (item.percentage / 100.0).clamp(0.0, 1.0),
          'color': palette[idx % palette.length],
        };
      });
    } else {
      final gadCount =
          filteredScreenings.where((r) => r.toolId == 'GAD-7').length;
      final phqCount =
          filteredScreenings.where((r) => r.toolId == 'PHQ-9').length;
      final dassCount =
          filteredScreenings.where((r) => r.toolId == 'DASS-21').length;
      final denom = totalScreenings > 0 ? totalScreenings : 1;
      topics = [
        {
          'label': 'Lo âu học đường — Thang đo GAD-7 ($gadCount lượt)',
          'pct': (gadCount / denom).clamp(0.0, 1.0),
          'color': const Color(0xFF3B5BDB),
        },
        {
          'label': 'Khí sắc & Giấc ngủ — Thang đo PHQ-9 ($phqCount lượt)',
          'pct': (phqCount / denom).clamp(0.0, 1.0),
          'color': const Color(0xFF0CA678),
        },
        {
          'label':
              'Tổ hợp Căng thẳng-Lo âu-Trầm cảm — DASS-21 ($dassCount lượt)',
          'pct': (dassCount / denom).clamp(0.0, 1.0),
          'color': const Color(0xFFF59E0B),
        },
      ];
    }

    // Phân bổ thực theo mức điểm để vẽ biểu đồ cột minh bạch
    final lowCount =
        filteredScreenings.where((r) => !r.requiresAttention).length;
    final moderateCount = filteredScreenings
        .where((r) =>
            r.requiresAttention &&
            (r.maxScore > 0 && r.score / r.maxScore < 0.7))
        .length;
    final highCount = filteredScreenings
        .where((r) =>
            r.requiresAttention &&
            (r.maxScore > 0 && r.score / r.maxScore >= 0.7))
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Thanh bộ lọc Khoa, Năm học, Kỳ thống kê & Xuất báo cáo CSV
        Card(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bảng điều khiển Xu hướng Sức khỏe Tinh thần Toàn trường (D02–D04)',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Số liệu tổng hợp thực tế từ vùng Anon_Clinical — Tuyệt đối không chứa PII hay nội dung hội thoại (R4, T23).',
                          style: TextStyle(fontSize: 13, color: Colors.black54),
                        ),
                      ],
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => _showExportAnalyticsModal(
                        context,
                        isSuppressed: isSuppressed,
                        sampleSize: sampleSize,
                        minGroup: minGroup,
                        totalScreenings: totalScreenings,
                        totalHighRisk: totalHighRisk,
                        highRiskPct: highRiskPct,
                        totalConnected: totalConnected,
                        moodCount: moodCount,
                        avgMoodStr: avgMoodStr,
                        cbtCompleted: cbtCompleted,
                      ),
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text('Xuất báo cáo ẩn danh (CSV)'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 260),
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _facultyFilter,
                        items: const [
                          DropdownMenuItem(
                            value: 'ALL',
                            child: Text(
                              'Khoa: Toàn trường (ALL)',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'CNTT',
                            child: Text(
                              'Khoa Công nghệ thông tin (CNTT)',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'KINH_TE',
                            child: Text(
                              'Khoa Kinh tế & Quản trị (KINH_TE)',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'NGON_NGU',
                            child: Text(
                              'Khoa Ngoại ngữ & Xã hội (NGON_NGU)',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'CO_KHI',
                            child: Text(
                              'Khoa Kỹ thuật & Công nghệ (CO_KHI)',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _facultyFilter = v);
                          ref
                              .read(mindCheckProvider.notifier)
                              .refreshPortalDataFromServer(
                                faculty: v,
                                academicYear: _academicYearFilter,
                                period: _periodFilter,
                              );
                        },
                      ),
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 210),
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _academicYearFilter,
                        items: const [
                          DropdownMenuItem(
                            value: 'ALL',
                            child: Text(
                              'Khóa/Năm: Tất cả (ALL)',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'Nam_1',
                            child: Text('Sinh viên Năm 1'),
                          ),
                          DropdownMenuItem(
                            value: 'Nam_2',
                            child: Text('Sinh viên Năm 2'),
                          ),
                          DropdownMenuItem(
                            value: 'Nam_3',
                            child: Text('Sinh viên Năm 3'),
                          ),
                          DropdownMenuItem(
                            value: 'Nam_4',
                            child: Text('Sinh viên Năm 4'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _academicYearFilter = v);
                          ref
                              .read(mindCheckProvider.notifier)
                              .refreshPortalDataFromServer(
                                faculty: _facultyFilter,
                                academicYear: v,
                                period: _periodFilter,
                              );
                        },
                      ),
                    ),
                    Wrap(
                      spacing: 6,
                      children: [
                        {'key': 'ALL', 'label': 'Toàn thời gian'},
                        {'key': '7d', 'label': '7 ngày qua'},
                        {'key': '30d', 'label': '30 ngày qua'},
                        {'key': 'semester', 'label': 'Học kỳ này'},
                      ].map((p) {
                        final pKey = p['key']!;
                        return ChoiceChip(
                          visualDensity: VisualDensity.compact,
                          label: Text(p['label']!,
                              style: const TextStyle(fontSize: 12)),
                          selected: _periodFilter == pKey,
                          onSelected: (_) {
                            setState(() => _periodFilter = pKey);
                            ref
                                .read(mindCheckProvider.notifier)
                                .refreshPortalDataFromServer(
                                  faculty: _facultyFilter,
                                  academicYear: _academicYearFilter,
                                  period: pKey,
                                );
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Kiểm tra quy tắc k-Anonymity (sample_size < min_group_size - F35, T24)
        if (isSuppressed)
          Card(
            color: const Color(0xFFFFF7ED),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lock_person_rounded,
                      color: Color(0xFFEA580C), size: 36),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '🔒 Đã khóa hiển thị biểu đồ để bảo vệ quyền riêng tư (k-Anonymity Guardrail — F35, T24)',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF9A3412),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Nhóm lọc hiện tại ($_facultyFilter / $_academicYearFilter) hiện có n = $sampleSize mẫu dữ liệu ẩn danh, nhỏ hơn ngưỡng an toàn tối thiểu (min_group_size = $minGroup) do Quản trị viên cấu hình. '
                          'Hệ thống tự động ẩn toàn bộ KPI và biểu đồ chi tiết để ngăn chặn nguy cơ suy luận danh tính sinh viên.',
                          style: const TextStyle(height: 1.45),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
        else ...[
          // 4 Thẻ KPI tổng hợp hoàn toàn từ số liệu thực tế
          LayoutBuilder(
            builder: (context, kpiConstraints) {
              final maxW = kpiConstraints.maxWidth;
              final double cardWidth = maxW >= 1120
                  ? (maxW - 48) / 4
                  : (maxW >= 660 ? (maxW - 16) / 2 : maxW);

              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _buildKpiCard(
                    width: cardWidth,
                    title: 'Tổng lượt sàng lọc tự nguyện',
                    value: '$totalScreenings',
                    subtitle:
                        'Cỡ mẫu ẩn danh hợp lệ (n = $sampleSize >= ngưỡng $minGroup)',
                    color: const Color(0xFF2B9E66),
                    icon: Icons.assignment_turned_in_rounded,
                  ),
                  _buildKpiCard(
                    width: cardWidth,
                    title: 'Nguy cơ cần chú ý (Trung bình/Cao)',
                    value: '$totalHighRisk ($highRiskPct%)',
                    subtitle:
                        'Tỷ lệ lượt sàng lọc vượt ngưỡng khuyến nghị gặp chuyên gia',
                    color: const Color(0xFFD94848),
                    icon: Icons.warning_amber_rounded,
                  ),
                  _buildKpiCard(
                    width: cardWidth,
                    title: 'Đã kết nối chuyên gia tư vấn',
                    value: '$totalConnected ($conversionRate%)',
                    subtitle:
                        'Tổng yêu cầu đặt lịch tư vấn & tỷ lệ chuyển đổi hỗ trợ',
                    color: const Color(0xFF3B5BDB),
                    icon: Icons.handshake_outlined,
                  ),
                  _buildKpiCard(
                    width: cardWidth,
                    title: 'Cảm xúc & Thực hành CBT ẩn danh',
                    value: '$moodCount lượt • $avgMoodStr/5.0',
                    subtitle:
                        'Đã hoàn thành $cbtCompleted bài tập tự hỗ trợ CBT & thở',
                    color: const Color(0xFF7C3AED),
                    icon: Icons.self_improvement_rounded,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 960;
              final maxCount = [lowCount, moderateCount, highCount, 1]
                  .reduce((a, b) => a > b ? a : b);

              final barChartCard = Card(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Phân tầng mức độ sàng lọc thực tế (D02)',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Tổng hợp trực tiếp từ $totalScreenings phiếu sàng lọc đã hoàn thành (n >= $minGroup):',
                        style: const TextStyle(
                            fontSize: 13, color: Colors.black54),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 205,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(
                              child: _buildBar(
                                'Ổn định / Nhẹ',
                                (lowCount / maxCount * 140).clamp(14.0, 145.0),
                                '$lowCount',
                                const Color(0xFF2B9E66),
                                44,
                              ),
                            ),
                            Expanded(
                              child: _buildBar(
                                'Trung bình',
                                (moderateCount / maxCount * 140)
                                    .clamp(14.0, 145.0),
                                '$moderateCount',
                                const Color(0xFFF59E0B),
                                44,
                              ),
                            ),
                            Expanded(
                              child: _buildBar(
                                'Cần ưu tiên hỗ trợ',
                                (highCount / maxCount * 140).clamp(14.0, 145.0),
                                '$highCount',
                                const Color(0xFFD94848),
                                44,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '* Dữ liệu tổng hợp ẩn danh (n >= min_group_size) — không thể truy vết về cá nhân sinh viên.',
                        style: TextStyle(
                            color: Colors.black54,
                            fontSize: 12.5,
                            fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
              );

              final topicChartCard = Card(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Phân bổ công cụ & chủ đề sàng lọc ẩn danh (D03)',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Tỷ trọng thực tế theo nhóm thang đo tự nguyện:',
                        style: TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                      const SizedBox(height: 18),
                      ...topics.map((t) {
                        final label = t['label'] as String;
                        final pct = t['pct'] as double;
                        final color = t['color'] as Color;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      label,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13.5),
                                    ),
                                  ),
                                  Text(
                                    '${(pct * 100).round()}%',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: color),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: pct,
                                  minHeight: 12,
                                  color: color,
                                  backgroundColor: const Color(0xFFE2E8F0),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              );

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: barChartCard),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: topicChartCard),
                  ],
                );
              }
              return Column(
                children: [
                  barChartCard,
                  const SizedBox(height: 16),
                  topicChartCard,
                ],
              );
            },
          ),
        ],
        const SizedBox(height: 16),

        // Quản lý Thư viện Kiến thức Học đường (Dành cho CTSV)
        Card(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quản lý Thư viện Kiến thức Tâm lý Học đường (F25)',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Biên tập bài viết giáo dục kỹ năng tự chăm sóc hiển thị trên ứng dụng của sinh viên:',
                          style: TextStyle(fontSize: 13, color: Colors.black54),
                        ),
                      ],
                    ),
                    FilledButton.icon(
                      onPressed: () => _showArticleEditorDialog(
                        context,
                        actorId: activeStaffId,
                      ),
                      icon: const Icon(Icons.post_add_rounded, size: 18),
                      label: const Text('Thêm bài viết mới'),
                    ),
                  ],
                ),
                const Divider(height: 22),
                ...appState.articles.map(
                  (art) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFEDF2FF),
                      child: Icon(Icons.menu_book_rounded,
                          color: Color(0xFF3B5BDB), size: 20),
                    ),
                    title: Text(art.title,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle:
                        Text('${art.category} • Nguồn: ${art.verifiedSource}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Chỉnh sửa bài viết',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _showArticleEditorDialog(
                            context,
                            existing: art,
                            actorId: activeStaffId,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Xóa bài viết',
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.redAccent),
                          onPressed: () => ref
                              .read(mindCheckProvider.notifier)
                              .deleteKnowledgeArticle(art.id,
                                  actor: activeStaffId),
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
    );
  }

  // ===========================================================================
  // ACTOR A03: TƯ VẤN VIÊN TÂM LÝ HỌC ĐƯỜNG (D05–D06)
  // ===========================================================================
  Widget _buildCounselorWorkspace(
    BuildContext context,
    MindCheckAppState appState,
    ActorRole effectiveRole,
    String currentStaffId,
  ) {
    final staffAccount = appState.staffDirectory
        .where((s) => s.staffId == currentStaffId)
        .firstOrNull;
    final currentStaffName = staffAccount != null
        ? '${staffAccount.displayName} (${staffAccount.staffId})'
        : (effectiveRole == ActorRole.counselor1
            ? 'ThS. Nguyễn Văn A (counselor_01)'
            : 'ThS. Trần Thị B (counselor_02)');
    final currentUnitName =
        staffAccount?.unitName ?? 'Phòng Tư vấn Tâm lý Sinh viên';

    final statusFilters = [
      {'key': 'ALL', 'label': 'Tất cả'},
      {'key': 'pending', 'label': 'Chờ xác nhận (pending)'},
      {'key': 'confirmed', 'label': 'Đã xác nhận (confirmed)'},
      {'key': 'completed', 'label': 'Đã hoàn tất (completed)'},
      {'key': 'declined', 'label': 'Hẹn đổi lịch (declined)'},
      {'key': 'canceled', 'label': 'Đã hủy (canceled)'},
    ];

    final myAssignedAll = appState.bookings
        .where((b) => b.counselorId == currentStaffId)
        .toList();
    final pendingCount =
        myAssignedAll.where((b) => b.status == 'pending').length;
    final confirmedCount =
        myAssignedAll.where((b) => b.status == 'confirmed').length;
    final completedCount =
        myAssignedAll.where((b) => b.status == 'completed').length;

    final mySlots = appState.counselorSlots
        .where((s) => s.counselorId == currentStaffId)
        .toList();

    final showUnassignedForTest =
        appState.isStaffDemoSwitchEnabled || _showCrossCounselorSecurityTest;

    final filteredBookings = appState.bookings.where((b) {
      if (!showUnassignedForTest && b.counselorId != currentStaffId) {
        return false;
      }
      final statusOk =
          _bookingStatusFilter == 'ALL' || b.status == _bookingStatusFilter;
      if (!statusOk) return false;
      if (_bookingSearchQuery.isEmpty) return true;
      final q = _bookingSearchQuery.toLowerCase();
      return b.requestId.toLowerCase().contains(q) ||
          b.contactInfo.toLowerCase().contains(q) ||
          b.studentNote.toLowerCase().contains(q) ||
          b.slotTime.toLowerCase().contains(q);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Thẻ KPI Tổng quan Ca tư vấn của Chuyên gia
        LayoutBuilder(
          builder: (context, kpiBox) {
            final maxW = kpiBox.maxWidth;
            final double w = maxW >= 1020
                ? (maxW - 48) / 4
                : (maxW >= 620 ? (maxW - 16) / 2 : maxW);
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _buildKpiCard(
                  width: w,
                  title: 'Ca phân công cho bạn',
                  value: '${myAssignedAll.length}',
                  subtitle: 'Chỉ hiển thị các trường Whitelist (F37)',
                  color: const Color(0xFF3B5BDB),
                  icon: Icons.folder_shared_outlined,
                ),
                _buildKpiCard(
                  width: w,
                  title: 'Chờ xác nhận (pending)',
                  value: '$pendingCount',
                  subtitle: 'Cần phản hồi giờ hẹn & phòng tư vấn',
                  color: const Color(0xFFF59E0B),
                  icon: Icons.pending_actions_rounded,
                ),
                _buildKpiCard(
                  width: w,
                  title: 'Đã xác nhận (confirmed)',
                  value: '$confirmedCount',
                  subtitle: 'Đã đồng bộ lịch hẹn về màn hình S24',
                  color: const Color(0xFF0CA678),
                  icon: Icons.event_available_rounded,
                ),
                _buildKpiCard(
                  width: w,
                  title: 'Đã hoàn tất (completed)',
                  value: '$completedCount',
                  subtitle: 'Tổng số buổi tham vấn đã thực hiện',
                  color: const Color(0xFF7C3AED),
                  icon: Icons.task_alt_rounded,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),

        // 2. Quản lý Khung giờ làm việc / Lịch trống của Tư vấn viên
        Card(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quản lý Lịch làm việc & Khung giờ trống — $currentStaffName',
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Các khung giờ đang bật sẽ hiển thị trực tiếp trên màn hình Đặt lịch (S23) của sinh viên:',
                          style: TextStyle(fontSize: 13, color: Colors.black54),
                        ),
                      ],
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => _showAddCounselorSlotDialog(
                        context,
                        counselorId: currentStaffId,
                        counselorName:
                            staffAccount?.displayName ?? currentStaffName,
                        unitName: currentUnitName,
                      ),
                      icon: const Icon(Icons.add_alarm_rounded, size: 18),
                      label: const Text('Thêm khung giờ mới'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (mySlots.isEmpty)
                  const Text(
                      'Chưa có khung giờ làm việc nào. Hãy bấm "Thêm khung giờ mới" để mở ca tư vấn.')
                else
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: mySlots.map((slot) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: slot.isAvailable
                              ? const Color(0xFFE6FCF5)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: slot.isAvailable
                                ? const Color(0xFF0CA678)
                                : const Color(0xFFCBD5E1),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              slot.isAvailable
                                  ? Icons.check_circle_rounded
                                  : Icons.pause_circle_outline_rounded,
                              size: 16,
                              color: slot.isAvailable
                                  ? const Color(0xFF087F5B)
                                  : Colors.black45,
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  slot.slotLabel,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  '${slot.consultationMode} • ${slot.isAvailable ? "Đang nhận lịch" : "Tạm khóa"}',
                                  style: const TextStyle(
                                      fontSize: 11.5, color: Colors.black54),
                                ),
                              ],
                            ),
                            const SizedBox(width: 6),
                            Switch(
                              value: slot.isAvailable,
                              onChanged: (_) => ref
                                  .read(mindCheckProvider.notifier)
                                  .toggleCounselorSlotAvailability(
                                    slot.slotId,
                                    actorId: currentStaffId,
                                  ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Xóa khung giờ',
                              icon: const Icon(Icons.close, size: 16),
                              onPressed: () => ref
                                  .read(mindCheckProvider.notifier)
                                  .deleteCounselorSlot(
                                    slot.slotId,
                                    actorId: currentStaffId,
                                  ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 3. Danh sách & Xử lý Lịch hẹn Tư vấn Học đường (D05-D06)
        Card(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quản lý Lịch hẹn Tư vấn Học đường — $currentStaffName (D05–D06)',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Chỉ hiển thị các trường Whitelist do sinh viên đồng ý chia sẻ (F37). Không hiển thị lịch sử chat AI hay điểm sàng lọc.',
                          style: TextStyle(fontSize: 13, color: Colors.black54),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: statusFilters.map((st) {
                        final key = st['key']!;
                        return ChoiceChip(
                          label: Text(st['label']!,
                              style: const TextStyle(fontSize: 12.5)),
                          selected: _bookingStatusFilter == key,
                          onSelected: (_) =>
                              setState(() => _bookingStatusFilter = key),
                        );
                      }).toList(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _bookingSearchCtrl,
                        onChanged: (v) =>
                            setState(() => _bookingSearchQuery = v.trim()),
                        decoration: InputDecoration(
                          prefixIcon:
                              const Icon(Icons.search_rounded, size: 18),
                          hintText:
                              'Tìm kiếm lịch hẹn theo mã ca, email/SĐT liên hệ, khung giờ hoặc ghi chú...',
                          isDense: true,
                          border: const OutlineInputBorder(),
                          suffixIcon: _bookingSearchQuery.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.clear, size: 16),
                                  onPressed: () {
                                    _bookingSearchCtrl.clear();
                                    setState(() => _bookingSearchQuery = '');
                                  },
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilterChip(
                      selected: showUnassignedForTest,
                      label: const Text('Hiện kiểm tra chặn chéo T25',
                          style: TextStyle(fontSize: 12)),
                      onSelected: (v) => setState(
                          () => _showCrossCounselorSecurityTest = v),
                    ),
                  ],
                ),
                const Divider(height: 24),
                if (filteredBookings.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child:
                        Text('Không có lịch hẹn nào khớp với bộ lọc hiện tại.'),
                  )
                else
                  ...filteredBookings.map((b) {
                    final isAssigned = b.counselorId == currentStaffId;

                    // T25: Chặn truy cập chéo khi Tư vấn viên 2 cố mở lịch hẹn của Tư vấn viên 1
                    if (!isAssigned) {
                      final forbiddenBtn = FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red.shade100,
                          foregroundColor: Colors.red.shade900,
                        ),
                        onPressed: () {
                          ref
                              .read(mindCheckProvider.notifier)
                              .recordAuditEvent(
                                actor: currentStaffId,
                                action: 'ATTEMPT_READ_UNASSIGNED_REQUEST',
                                target: b.requestId,
                                result: 'DENIED_FORBIDDEN',
                              );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: Colors.red.shade800,
                              content: Text(
                                '403 FORBIDDEN (T25): Đã chặn $currentStaffId truy cập ca ${b.requestId} của ${b.counselorId} và ghi Audit Log!',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.lock_outline, size: 16),
                        label: const Text('Thử mở hồ sơ (Test T25)'),
                      );

                      return Card(
                        color: const Color(0xFFFEF2F2),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: LayoutBuilder(
                            builder: (context, itemBox) {
                              final infoColumn = Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Yêu cầu ${b.requestId} — Đang gán cho ${b.counselorName} (${b.counselorId})',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'FORBIDDEN (T25): Tài khoản của bạn không được phân công xử lý ca tư vấn này. Mọi hành vi mở trái phép đều bị chặn và ghi Audit Log.',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                ],
                              );

                              if (itemBox.maxWidth < 580) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Icon(
                                          Icons.gpp_bad_rounded,
                                          color: Colors.redAccent,
                                          size: 26,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(child: infoColumn),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: forbiddenBtn,
                                    ),
                                  ],
                                );
                              }

                              return Row(
                                children: [
                                  const Icon(
                                    Icons.gpp_bad_rounded,
                                    color: Colors.redAccent,
                                    size: 28,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(child: infoColumn),
                                  const SizedBox(width: 12),
                                  forbiddenBtn,
                                ],
                              );
                            },
                          ),
                        ),
                      );
                    }

                    final replyCtrl = _getReplyCtrl(b);

                    return Card(
                      color: const Color(0xFFF8FAFC),
                      margin: const EdgeInsets.only(bottom: 14),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    'Mã lịch hẹn: ${b.requestId} • Đơn vị: ${b.unitName}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15),
                                  ),
                                ),
                                Chip(
                                  backgroundColor: b.status == 'confirmed'
                                      ? const Color(0xFFE6FCF5)
                                      : (b.status == 'completed'
                                          ? const Color(0xFFEDF2FF)
                                          : const Color(0xFFFFF7ED)),
                                  label: Text(
                                    b.status.toUpperCase(),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                                '• Khung giờ đăng ký: ${b.slotTime} (${b.consultationMode})'),
                            Text(
                                '• Liên hệ sinh viên (Whitelist F37): ${b.contactInfo}'),
                            Text(
                              '• Ghi chú của sinh viên: ${b.studentNote.isEmpty ? "Không có ghi chú" : b.studentNote}',
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Mẫu phản hồi nhanh (Quick Templates):',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black54),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                ActionChip(
                                  visualDensity: VisualDensity.compact,
                                  label: const Text('Xác nhận tại Phòng P.102',
                                      style: TextStyle(fontSize: 11.5)),
                                  onPressed: () {
                                    replyCtrl.text =
                                        'Thầy/Cô đã xác nhận lịch tại Phòng Tư vấn P.102, em đến đúng giờ nhé.';
                                  },
                                ),
                                ActionChip(
                                  visualDensity: VisualDensity.compact,
                                  label: const Text(
                                      'Xác nhận Online (Google Meet)',
                                      style: TextStyle(fontSize: 11.5)),
                                  onPressed: () {
                                    replyCtrl.text =
                                        'Đã xác nhận tư vấn trực tuyến qua Google Meet (link đã gửi qua email liên hệ của em).';
                                  },
                                ),
                                ActionChip(
                                  visualDensity: VisualDensity.compact,
                                  label: const Text('Hẹn dời sang ca sau',
                                      style: TextStyle(fontSize: 11.5)),
                                  onPressed: () {
                                    replyCtrl.text =
                                        'Chuyên gia có lịch họp đột xuất, mời em chọn khung giờ khác phù hợp nhé.';
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: replyCtrl,
                              decoration: const InputDecoration(
                                labelText:
                                    'Ghi chú phản hồi giờ hẹn / phòng tư vấn gửi về màn hình S24 của sinh viên (T22)',
                                hintText:
                                    'VD: Cô/Thầy đã xác nhận lịch tại Phòng Tư vấn P.102, em đến đúng giờ nhé.',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                FilledButton.icon(
                                  onPressed: () {
                                    ref
                                        .read(mindCheckProvider.notifier)
                                        .updateBookingStatus(
                                          requestId: b.requestId,
                                          newStatus: 'confirmed',
                                          actorLabel: currentStaffId,
                                          counselorNote: replyCtrl.text.trim(),
                                        );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Đã xác nhận lịch hẹn và đồng bộ phản hồi về màn hình S24 của sinh viên!'),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.check_circle_outline,
                                      size: 18),
                                  label: const Text(
                                      'Xác nhận lịch hẹn (confirmed)'),
                                ),
                                FilledButton.tonalIcon(
                                  onPressed: () {
                                    ref
                                        .read(mindCheckProvider.notifier)
                                        .updateBookingStatus(
                                          requestId: b.requestId,
                                          newStatus: 'completed',
                                          actorLabel: currentStaffId,
                                          counselorNote: replyCtrl.text.trim(),
                                        );
                                  },
                                  icon: const Icon(Icons.done_all_rounded,
                                      size: 18),
                                  label: const Text(
                                      'Đánh dấu Đã tư vấn (completed)'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    ref
                                        .read(mindCheckProvider.notifier)
                                        .updateBookingStatus(
                                          requestId: b.requestId,
                                          newStatus: 'declined',
                                          actorLabel: currentStaffId,
                                          counselorNote: replyCtrl.text
                                                  .trim()
                                                  .isEmpty
                                              ? 'Chuyên gia có lịch họp đột xuất, mời bạn chọn khung giờ khác.'
                                              : replyCtrl.text.trim(),
                                        );
                                  },
                                  icon: const Icon(
                                      Icons.schedule_send_outlined,
                                      size: 18),
                                  label: const Text('Hẹn đổi giờ (declined)'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // ACTOR A04: QUẢN TRỊ VIÊN HỆ THỐNG (D07)
  // ===========================================================================
  Widget _buildAdminGovernancePanel(
    BuildContext context,
    MindCheckAppState appState,
    String activeStaffId,
  ) {
    final totalAudits = appState.auditLogs.length;
    final deniedAudits = appState.auditLogs
        .where((l) => l.result.toUpperCase().contains('DENIED'))
        .length;
    final allowedAudits = totalAudits - deniedAudits;

    final filteredAudits = appState.auditLogs.where((log) {
      final actionOk =
          _auditActionFilter == 'ALL' || log.action.contains(_auditActionFilter);
      if (!actionOk) return false;
      if (_auditSearchQuery.isEmpty) return true;
      final q = _auditSearchQuery.toLowerCase();
      return log.actor.toLowerCase().contains(q) ||
          log.action.toLowerCase().contains(q) ||
          log.target.toLowerCase().contains(q) ||
          log.result.toLowerCase().contains(q);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Ma trận phân quyền RBAC (Staff Roles)
        Card(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ma trận Phân quyền Hệ thống RBAC & Bảo vệ Dữ liệu (D07 — R4, R5)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Đảm bảo tách biệt vùng dữ liệu định danh (Identity_Vault) và dữ liệu lâm sàng ẩn danh (Anon_Clinical):',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 14),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor:
                        WidgetStateProperty.all(const Color(0xFFEDF2FF)),
                    columns: const [
                      DataColumn(label: Text('Vai trò (Actor)')),
                      DataColumn(label: Text('Hội thoại AI & Điểm cá nhân')),
                      DataColumn(label: Text('Lịch hẹn định danh (F37)')),
                      DataColumn(label: Text('Thống kê toàn trường')),
                      DataColumn(label: Text('Cấu hình Policy & Audit')),
                    ],
                    rows: const [
                      DataRow(cells: [
                        DataCell(Text('A01 • Sinh viên',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(Text('✅ Toàn quyền sở hữu & xóa (F06)')),
                        DataCell(Text('✅ Tự nguyện gửi có Consent')),
                        DataCell(Text('❌ Không truy cập')),
                        DataCell(Text('❌ Không truy cập')),
                      ]),
                      DataRow(cells: [
                        DataCell(Text('A02 • Nhân viên CTSV',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(Text('🚫 CẤM TUYỆT ĐỐI (T23)')),
                        DataCell(Text('🚫 CẤM TUYỆT ĐỐI')),
                        DataCell(Text('✅ Chỉ xem khi n >= min_group_size')),
                        DataCell(Text('❌ Không truy cập')),
                      ]),
                      DataRow(cells: [
                        DataCell(Text('A03 • Tư vấn viên',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(Text('🚫 CẤM TUYỆT ĐỐI (F37)')),
                        DataCell(Text('✅ Chỉ xem ca gán cho chính mình (T25)')),
                        DataCell(Text('❌ Không truy cập')),
                        DataCell(Text('❌ Không truy cập')),
                      ]),
                      DataRow(cells: [
                        DataCell(Text('A04 • Quản trị viên',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(Text('🚫 CẤM ĐỌC CHAT CÁ NHÂN (T27)')),
                        DataCell(Text('❌ Không xem nội dung tư vấn')),
                        DataCell(Text('✅ Cấu hình ngưỡng k-Anonymity')),
                        DataCell(Text('✅ Quản lý RBAC & Audit Logs')),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 2. Thanh trượt chỉnh ngưỡng ẩn nhóm nhỏ (min_group_size)
        Card(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cấu hình Ngưỡng Bảo vệ Nhóm nhỏ k-Anonymity (min_group_size)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'Ngưỡng hiện tại: Tối thiểu ${appState.minGroupSizePolicy} sinh viên trong bộ lọc mới cho phép hiển thị thống kê trên Dashboard CTSV.',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, color: Color(0xFF1E3A8A)),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text('5 SV',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Expanded(
                      child: Slider(
                        value: appState.minGroupSizePolicy
                            .clamp(5, 25)
                            .toDouble(),
                        min: 5,
                        max: 25,
                        divisions: 20,
                        label: '${appState.minGroupSizePolicy} SV',
                        onChanged: (val) {
                          ref
                              .read(mindCheckProvider.notifier)
                              .updateAnalyticsPolicy(val.round(), 'admin_01');
                        },
                      ),
                    ),
                    const Text('25 SV',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                Wrap(
                  spacing: 10,
                  children: [8, 10, 15, 20].map((val) {
                    return ChoiceChip(
                      label: Text('Ngưỡng chuẩn $val SV'),
                      selected: appState.minGroupSizePolicy == val,
                      onSelected: (_) => ref
                          .read(mindCheckProvider.notifier)
                          .updateAnalyticsPolicy(val, 'admin_01'),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 3. Quản lý Danh mục Tài khoản Nhân sự & Chuyên gia Tư vấn
        Card(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quản lý Tài khoản Nhân sự & Chuyên gia Tư vấn (Identity_Vault)',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Phân quyền vai trò CTSV / Tư vấn viên / Admin và kiểm soát trạng thái kích hoạt tài khoản:',
                          style: TextStyle(fontSize: 13, color: Colors.black54),
                        ),
                      ],
                    ),
                    FilledButton.icon(
                      onPressed: () => _showUpsertStaffDialog(context),
                      icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                      label: const Text('Thêm nhân sự mới'),
                    ),
                  ],
                ),
                const Divider(height: 22),
                ...appState.staffDirectory.map(
                  (staff) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: staff.isActive
                          ? const Color(0xFFEDF2FF)
                          : const Color(0xFFF1F5F9),
                      child: Icon(
                        staff.role == 'admin'
                            ? Icons.admin_panel_settings_rounded
                            : (staff.role == 'counselor'
                                ? Icons.psychology_rounded
                                : Icons.analytics_rounded),
                        color: staff.isActive
                            ? const Color(0xFF3B5BDB)
                            : Colors.black38,
                      ),
                    ),
                    title: Text(
                      '${staff.displayName} (${staff.staffId})',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Vai trò: ${staff.role.toUpperCase()} • Đơn vị: ${staff.unitName} • ${staff.isActive ? "Đang hoạt động" : "Đang tạm khóa"}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: staff.isActive,
                          onChanged: staff.staffId == 'admin_01'
                              ? null
                              : (_) => ref
                                  .read(mindCheckProvider.notifier)
                                  .toggleStaffAccountActive(
                                    staff.staffId,
                                    adminActor: activeStaffId,
                                  ),
                        ),
                        IconButton(
                          tooltip: 'Cập nhật thông tin nhân sự',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _showUpsertStaffDialog(
                            context,
                            existing: staff,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 4. Quản lý Danh bạ Đường dây nóng Hỗ trợ An toàn (S21)
        Card(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quản lý Danh bạ Khẩn cấp & Đường dây nóng An toàn (S21 — R3)',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Hai số khẩn cấp quốc gia 115 và 111 được khóa bảo vệ cố định; Admin có thể bổ sung số trực ban của trường:',
                          style: TextStyle(fontSize: 13, color: Colors.black54),
                        ),
                      ],
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => _showAddHotlineDialog(context),
                      icon: const Icon(Icons.add_call, size: 18),
                      label: const Text('Thêm Hotline hỗ trợ'),
                    ),
                  ],
                ),
                const Divider(height: 22),
                ...appState.safetyHotlines.map((h) {
                  final isCore = h.hotlineId == 'hotline_115' ||
                      h.hotlineId == 'hotline_111';
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFFEF2F2),
                      child: Text(
                        h.phone.length <= 4 ? h.phone : 'SOS',
                        style: const TextStyle(
                          color: Color(0xFFDC2626),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    title: Text(
                      '${h.name} — ${h.phone} (${h.hours})',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(h.description),
                    trailing: isCore
                        ? const Chip(
                            visualDensity: VisualDensity.compact,
                            label: Text('Cố định Quốc gia (R3)',
                                style: TextStyle(fontSize: 11)),
                          )
                        : IconButton(
                            tooltip: 'Xóa Hotline phụ',
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.redAccent),
                            onPressed: () => ref
                                .read(mindCheckProvider.notifier)
                                .deleteSafetyHotline(
                                  h.hotlineId,
                                  adminActor: activeStaffId,
                                ),
                          ),
                  );
                }),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 5. Bảng tra cứu Nhật ký Kiểm toán (Audit Events) có tìm kiếm & bộ lọc
        Card(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Nhật ký Kiểm toán Bảo mật (Audit Events — T27) • Tổng: $totalAudits (Hợp lệ: $allowedAudits | Chặn DENIED: $deniedAudits)',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Tất cả sự kiện'),
                          selected: _auditActionFilter == 'ALL',
                          onSelected: (_) =>
                              setState(() => _auditActionFilter = 'ALL'),
                        ),
                        ChoiceChip(
                          label: const Text('Cập nhật k-Anonymity'),
                          selected: _auditActionFilter ==
                              'UPDATE_MIN_GROUP_SIZE_POLICY',
                          onSelected: (_) => setState(() => _auditActionFilter =
                              'UPDATE_MIN_GROUP_SIZE_POLICY'),
                        ),
                        ChoiceChip(
                          label: const Text('Cập nhật Lịch hẹn'),
                          selected:
                              _auditActionFilter == 'UPDATE_BOOKING_STATUS',
                          onSelected: (_) => setState(
                              () => _auditActionFilter = 'UPDATE_BOOKING_STATUS'),
                        ),
                        ChoiceChip(
                          label: const Text('Cảnh báo Chặn truy cập (DENIED)'),
                          selected: _auditActionFilter ==
                              'ATTEMPT_READ_UNASSIGNED_REQUEST',
                          onSelected: (_) => setState(() => _auditActionFilter =
                              'ATTEMPT_READ_UNASSIGNED_REQUEST'),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _auditSearchCtrl,
                  onChanged: (v) =>
                      setState(() => _auditSearchQuery = v.trim()),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    hintText:
                        'Tìm kiếm sự kiện kiểm toán theo Actor, Action hoặc Target...',
                    isDense: true,
                    border: const OutlineInputBorder(),
                    suffixIcon: _auditSearchQuery.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              _auditSearchCtrl.clear();
                              setState(() => _auditSearchQuery = '');
                            },
                          ),
                  ),
                ),
                const Divider(height: 24),
                if (filteredAudits.isEmpty)
                  const Text(
                      'Chưa có sự kiện kiểm toán nào khớp bộ lọc. Hãy thử đổi ngưỡng min_group_size hoặc kiểm tra quyền Tư vấn viên.')
                else
                  ...filteredAudits.map(
                    (log) => ListTile(
                      dense: true,
                      leading: Icon(
                        log.result.contains('DENIED')
                            ? Icons.gpp_bad_rounded
                            : Icons.verified_user_outlined,
                        color: log.result.contains('DENIED')
                            ? Colors.redAccent
                            : const Color(0xFF0CA678),
                      ),
                      title: Text(
                        '${log.action} -> [${log.result}]',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Actor: ${log.actor} | Target: ${log.target} | Thời gian: ${log.timestamp.toIso8601String().substring(11, 19)}',
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBar(
    String label,
    double height,
    String countLabel,
    Color color,
    double barWidth,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          countLabel,
          style: TextStyle(
            fontSize: barWidth < 24 ? 10 : 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: barWidth,
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: barWidth < 24 ? 10.5 : 12,
          ),
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required double width,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.black54, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold, color: color),
                ),
                const SizedBox(height: 4),
                Text(subtitle,
                    style:
                        const TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
