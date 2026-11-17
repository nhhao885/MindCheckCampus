import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/state_provider.dart';
import '../../shared/api_service.dart';
import '../../shared/models.dart';

class KnowledgeMemorySettingsHubScreen extends ConsumerStatefulWidget {
  const KnowledgeMemorySettingsHubScreen({super.key});

  @override
  ConsumerState<KnowledgeMemorySettingsHubScreen> createState() =>
      _KnowledgeMemorySettingsHubScreenState();
}

class _KnowledgeMemorySettingsHubScreenState
    extends ConsumerState<KnowledgeMemorySettingsHubScreen> {
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _newMemoryCtrl = TextEditingController();
  final TextEditingController _searchMemoryCtrl = TextEditingController();
  String _searchQuery = '';
  String _articleCategoryFilter = 'ALL';
  String _selectedFaculty = 'CNTT';
  String _selectedYear = 'Nam_2';
  String _accountMode = 'LINK'; // 'LINK' hoặc 'LOGIN'

  // R2 & T02: Tuyệt đối không mặc định tích sẵn (pre-checked) cho bất kỳ mục đích đồng ý nào
  bool _consentManualMemory = false;
  bool _consentLinkGuest = false;

  Future<void> _pickReminderTime(
    BuildContext context,
    NotificationPreference currentPref,
  ) async {
    final parts = currentPref.reminderTime.split(':');
    final initHour = parts.isNotEmpty ? (int.tryParse(parts[0]) ?? 20) : 20;
    final initMin = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initHour, minute: initMin),
      helpText: 'Chọn giờ nhắc check-in cảm xúc hằng ngày',
    );
    if (picked == null || !mounted) return;
    final hh = picked.hour.toString().padLeft(2, '0');
    final mm = picked.minute.toString().padLeft(2, '0');
    ref.read(mindCheckProvider.notifier).updateNotificationPreference(
          currentPref.copyWith(reminderTime: '$hh:$mm'),
        );
  }

  void _showConfirmEraseDataDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Expanded(
              child: Text('Xác nhận xóa toàn bộ dữ liệu cá nhân (F06)'),
            ),
          ],
        ),
        content: const Text(
          'Hành động này sẽ thu hồi toàn bộ sự đồng ý trước đây và xóa vĩnh viễn lịch sử trò chuyện AI, trí nhớ đã duyệt, nhật ký cảm xúc và kết quả sàng lọc của bạn trên cả thiết bị và máy chủ.\n\nBạn có chắc chắn muốn tiếp tục không?',
          style: TextStyle(height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(mindCheckProvider.notifier)
                  .revokeConsentOrRequestDataAction(
                    'Yêu cầu xóa toàn bộ dữ liệu cá nhân',
                  );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Đã xóa sạch dữ liệu cá nhân & thu hồi đồng ý (F06, T32).',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.delete_forever_rounded, size: 18),
            label: const Text('Xác nhận xóa vĩnh viễn'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _newMemoryCtrl.dispose();
    _searchMemoryCtrl.dispose();
    super.dispose();
  }

  void _submitManualMemory() {
    final raw = _newMemoryCtrl.text.trim();
    if (raw.isEmpty) return;
    if (!_consentManualMemory) {
      ref
          .read(mindCheckProvider.notifier)
          .addManualApprovedMemory(raw, consentAccepted: false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Vui lòng tích chọn đồng ý cho phép AI ghi nhớ thông tin trước khi lưu (R2, F10).',
          ),
        ),
      );
      return;
    }
    final saved = ref
        .read(mindCheckProvider.notifier)
        .addManualApprovedMemory(raw, consentAccepted: true);
    if (saved) {
      _newMemoryCtrl.clear();
      setState(() => _consentManualMemory = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã thêm mục trí nhớ mới vào hồ sơ đồng hành AI.'),
        ),
      );
    }
  }

  void _showEditMemoryDialog(ApprovedMemory memory) {
    final editCtrl = TextEditingController(text: memory.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Chỉnh sửa nội dung Trí nhớ AI'),
        content: TextField(
          controller: editCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              ref
                  .read(mindCheckProvider.notifier)
                  .editApprovedMemory(memory.memoryId, editCtrl.text);
              Navigator.pop(ctx);
            },
            child: const Text('Lưu cập nhật'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(mindCheckProvider);
    final filteredMemories = appState.memories
        .where(
          (m) =>
              _searchQuery.isEmpty ||
              m.text.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();

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
                      'Trí nhớ AI đã được bạn chấp thuận (S28)',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Bạn có toàn quyền thêm mới thủ công, tìm kiếm, chỉnh sửa hoặc xóa bất kỳ thông tin nào AI đang ghi nhớ về mình.',
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _newMemoryCtrl,
                            decoration: const InputDecoration(
                              hintText:
                                  'Thêm mới mục ghi nhớ thủ công (VD: Đang ôn thi Giải tích)...',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: (_) => _submitManualMemory(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: _submitManualMemory,
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Thêm'),
                        ),
                      ],
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _consentManualMemory,
                      onChanged: (v) =>
                          setState(() => _consentManualMemory = v ?? false),
                      title: const Text(
                        'Tôi đồng ý cho phép AI ghi nhớ thông tin này cho các cuộc trò chuyện sau (F10).',
                        style: TextStyle(fontSize: 12.5),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _searchMemoryCtrl,
                      onChanged: (v) => setState(() => _searchQuery = v.trim()),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        hintText: 'Tìm kiếm nhanh trong bộ nhớ AI...',
                        isDense: true,
                        suffixIcon: _searchQuery.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchMemoryCtrl.clear();
                                  setState(() => _searchQuery = '');
                                },
                              ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (filteredMemories.isEmpty)
                      Text(
                        _searchQuery.isEmpty
                            ? 'Danh sách trống — AI hiện chưa lưu thông tin dài hạn nào về bạn.'
                            : 'Không tìm thấy mục ghi nhớ nào khớp từ khóa "$_searchQuery".',
                      )
                    else
                      ...filteredMemories.map(
                        (m) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.bookmark_added_rounded,
                              color: Color(0xFF3B5BDB)),
                          title: Text(m.text),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Chỉnh sửa',
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _showEditMemoryDialog(m),
                              ),
                              IconButton(
                                tooltip: 'Xóa khỏi bộ nhớ AI',
                                icon: const Icon(Icons.delete_forever,
                                    color: Colors.redAccent),
                                onPressed: () => ref
                                    .read(mindCheckProvider.notifier)
                                    .deleteApprovedMemory(m.memoryId),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
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
                      'Thư viện Kiến thức Chăm sóc Sức khỏe Tinh thần (S25)',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          'ALL',
                          ...appState.articles.map((a) => a.category).toSet(),
                        ].map((cat) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              visualDensity: VisualDensity.compact,
                              label: Text(
                                cat == 'ALL' ? 'Tất cả chủ đề' : cat,
                                style: const TextStyle(fontSize: 12),
                              ),
                              selected: _articleCategoryFilter == cat,
                              onSelected: (_) => setState(
                                  () => _articleCategoryFilter = cat),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...appState.articles
                        .where((art) =>
                            _articleCategoryFilter == 'ALL' ||
                            art.category == _articleCategoryFilter)
                        .map(
                          (art) => ExpansionTile(
                        title: Text(art.title,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                            '${art.category} • Nguồn: ${art.verifiedSource}'),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(art.content,
                                style: const TextStyle(height: 1.45)),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                      'Lời nhắc đồng hành & Giờ yên tĩnh (S29)',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Nhắc nhở check-in cảm xúc nhẹ nhàng (${appState.notificationPref.reminderTime})',
                      ),
                      subtitle: Text(
                        'Khung giờ yên tĩnh không làm phiền: ${appState.notificationPref.quietHours}',
                      ),
                      value: appState.notificationPref.enabled,
                      onChanged: (v) => ref
                          .read(mindCheckProvider.notifier)
                          .updateNotificationPreference(
                            appState.notificationPref.copyWith(enabled: v),
                          ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => _pickReminderTime(
                          context,
                          appState.notificationPref,
                        ),
                        icon: const Icon(Icons.access_time_rounded, size: 16),
                        label: Text(
                          'Đổi giờ nhắc (${appState.notificationPref.reminderTime})',
                          style: const TextStyle(fontSize: 12.5),
                        ),
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                          'Ẩn nội dung nhạy cảm trên màn hình khóa điện thoại'),
                      value:
                          appState.notificationPref.hideSensitiveOnLockScreen,
                      onChanged: (v) => ref
                          .read(mindCheckProvider.notifier)
                          .updateNotificationPreference(
                            appState.notificationPref
                                .copyWith(hideSensitiveOnLockScreen: v),
                          ),
                    ),
                  ],
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
                      'Tài khoản & Quyền kiểm soát dữ liệu cá nhân (S30, F06)',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Phiên hiện tại: ${appState.userEmail ?? appState.guestId ?? "Ẩn danh"} • Khoa: ${appState.userFaculty} (${appState.userAcademicYear}) • Số sự đồng ý đã lưu: ${appState.consents.length}',
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        ChoiceChip(
                          visualDensity: VisualDensity.compact,
                          avatar: const Icon(Icons.link_rounded, size: 16),
                          label: const Text(
                            'Liên kết tài khoản mới',
                            style: TextStyle(fontSize: 12.5),
                          ),
                          selected: _accountMode == 'LINK',
                          onSelected: (_) =>
                              setState(() => _accountMode = 'LINK'),
                        ),
                        ChoiceChip(
                          visualDensity: VisualDensity.compact,
                          avatar: const Icon(Icons.sync_lock_rounded, size: 16),
                          label: const Text(
                            'Đăng nhập đồng bộ tài khoản đã có',
                            style: TextStyle(fontSize: 12.5),
                          ),
                          selected: _accountMode == 'LOGIN',
                          onSelected: (_) =>
                              setState(() => _accountMode = 'LOGIN'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText:
                            'Liên kết Email sinh viên để đồng bộ đa thiết bị (Tùy chọn)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _passwordCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText:
                            'Mật khẩu bảo vệ tài khoản (tối thiểu 6 ký tự khi đồng bộ máy chủ)',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (_accountMode == 'LINK') ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          SizedBox(
                            width: 220,
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedFaculty,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Khoa (Ẩn danh thống kê)',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                    value: 'CNTT',
                                    child: Text('Công nghệ thông tin')),
                                DropdownMenuItem(
                                    value: 'KINH_TE',
                                    child: Text('Kinh tế & Quản trị')),
                                DropdownMenuItem(
                                    value: 'NGON_NGU',
                                    child: Text('Ngoại ngữ & Xã hội')),
                                DropdownMenuItem(
                                    value: 'CO_KHI',
                                    child: Text('Kỹ thuật & Công nghệ')),
                              ],
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => _selectedFaculty = v);
                                }
                              },
                            ),
                          ),
                          SizedBox(
                            width: 180,
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedYear,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Năm học',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                    value: 'Nam_1', child: Text('Năm 1')),
                                DropdownMenuItem(
                                    value: 'Nam_2', child: Text('Năm 2')),
                                DropdownMenuItem(
                                    value: 'Nam_3', child: Text('Năm 3')),
                                DropdownMenuItem(
                                    value: 'Nam_4', child: Text('Năm 4')),
                              ],
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => _selectedYear = v);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: _consentLinkGuest,
                        onChanged: (v) =>
                            setState(() => _consentLinkGuest = v ?? false),
                        title: const Text(
                          'Đồng ý chuyển dữ liệu đã lưu từ phiên ẩn danh hiện tại sang tài khoản.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ] else
                      const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        FilledButton.tonal(
                          onPressed: () {
                            final email = _emailCtrl.text.trim();
                            if (!MindCheckApiService.isValidEmail(email)) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Vui lòng nhập địa chỉ Email sinh viên hợp lệ.',
                                  ),
                                ),
                              );
                              return;
                            }
                            final ok = ref
                                .read(mindCheckProvider.notifier)
                                .registerAndLinkAccount(
                                  email: email,
                                  password: _passwordCtrl.text,
                                  faculty: _selectedFaculty,
                                  academicYear: _selectedYear,
                                  consentToLinkGuestData: _consentLinkGuest,
                                );
                            if (ok) {
                              setState(() => _consentLinkGuest = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Đã liên kết tài khoản đồng bộ thành công!',
                                  ),
                                ),
                              );
                            }
                          },
                          child: const Text('Liên kết tài khoản'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final email = _emailCtrl.text.trim();
                            final pass = _passwordCtrl.text;
                            if (!MindCheckApiService.isValidEmail(email) ||
                                pass.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Vui lòng nhập Email hợp lệ và mật khẩu để đăng nhập.',
                                  ),
                                ),
                              );
                              return;
                            }
                            final ok = await ref
                                .read(mindCheckProvider.notifier)
                                .loginStudentAccount(
                                  email: email,
                                  password: pass,
                                );
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  ok
                                      ? 'Đăng nhập tài khoản sinh viên thành công!'
                                      : 'Không thể đăng nhập (kiểm tra kết nối máy chủ hoặc thông tin xác thực).',
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.login_rounded, size: 17),
                          label: const Text('Đăng nhập đồng bộ'),
                        ),
                        if (appState.userEmail != null)
                          TextButton.icon(
                            onPressed: () {
                              ref
                                  .read(mindCheckProvider.notifier)
                                  .logoutStudentAccount();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Đã đăng xuất và quay về chế độ ẩn danh.',
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.logout_rounded, size: 17),
                            label: const Text('Đăng xuất'),
                          ),
                        OutlinedButton.icon(
                          onPressed: () => _showConfirmEraseDataDialog(context),
                          icon: const Icon(
                            Icons.delete_sweep_outlined,
                            size: 17,
                            color: Colors.redAccent,
                          ),
                          label: const Text(
                            'Yêu cầu xóa dữ liệu cá nhân',
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        ),
                      ],
                    ),
                    if (appState.dataRequests.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      ...appState.dataRequests.map(
                        (r) => Text('• $r',
                            style: const TextStyle(
                                fontSize: 12.5, color: Colors.black54)),
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
