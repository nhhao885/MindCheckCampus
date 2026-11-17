import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/state_provider.dart';
import '../../app/theme.dart';
import '../../shared/models.dart';
import '../onboarding/onboarding_screen.dart';
import '../support/support_booking_screen.dart';

class StudentHomeAndChatScreen extends ConsumerStatefulWidget {
  final ValueChanged<int> onNavigateTab;
  const StudentHomeAndChatScreen({super.key, required this.onNavigateTab});

  @override
  ConsumerState<StudentHomeAndChatScreen> createState() =>
      _StudentHomeAndChatScreenState();
}

class _StudentHomeAndChatScreenState
    extends ConsumerState<StudentHomeAndChatScreen> {
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _openChatHistoryBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return Consumer(
          builder: (context, refSheet, _) {
            final state = refSheet.watch(mindCheckProvider);
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'Danh sách các phiên trò chuyện của bạn',
                            style: TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () {
                            refSheet
                                .read(mindCheckProvider.notifier)
                                .createNewChatSession();
                            Navigator.pop(sheetCtx);
                          },
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Tạo phiên mới'),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 320),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: state.chatSessions.length,
                        itemBuilder: (ctx, idx) {
                          final s = state.chatSessions[idx];
                          final isSelected =
                              s.sessionId == state.activeChatSessionId;
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            selected: isSelected,
                            leading: Icon(
                              isSelected
                                  ? Icons.chat_bubble_rounded
                                  : Icons.chat_bubble_outline_rounded,
                              color: isSelected
                                  ? const Color(0xFF3B5BDB)
                                  : Colors.black45,
                              size: 19,
                            ),
                            title: Text(
                              s.title,
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                              ),
                            ),
                            onTap: () {
                              refSheet
                                  .read(mindCheckProvider.notifier)
                                  .switchChatSession(s.sessionId);
                              Navigator.pop(sheetCtx);
                            },
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Đổi tên cuộc trò chuyện',
                                  icon: const Icon(Icons.edit_outlined,
                                      size: 18),
                                  onPressed: () =>
                                      _showRenameSessionDialog(context, s),
                                ),
                                IconButton(
                                  tooltip: 'Xóa phiên này',
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.redAccent, size: 19),
                                  onPressed: () => refSheet
                                      .read(mindCheckProvider.notifier)
                                      .deleteChatSession(s.sessionId),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty) return;
    _msgCtrl.clear();
    _scrollToBottom();
    await ref.read(mindCheckProvider.notifier).sendChatMessage(text);
    _scrollToBottom();
  }

  /// R3: Các nút hành động an toàn 2 lớp phải mở trực tiếp Hỗ trợ an toàn (S21) hoặc Đặt lịch Tư vấn (S23), không biến thành tin nhắn chat
  void _handleQuickReply(BuildContext context, String qr) {
    final lower = qr.toLowerCase();
    if (lower.contains('hỗ trợ an toàn') || lower.contains('khẩn cấp')) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SafetySupportScreen()),
      );
      return;
    }
    if (lower.contains('tư vấn viên') || lower.contains('đặt lịch')) {
      widget.onNavigateTab(3);
      return;
    }
    _send(qr);
  }

  Future<void> _retryMessage(String failedMessageId) async {
    _scrollToBottom();
    await ref
        .read(mindCheckProvider.notifier)
        .retryFailedMessage(failedMessageId);
    _scrollToBottom();
  }

  String _formatTime(DateTime dt) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  void _showRenameSessionDialog(BuildContext context, ChatSessionModel s) {
    final ctrl = TextEditingController(text: s.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đổi tên cuộc trò chuyện'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Tên chủ đề trò chuyện',
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
                  .renameChatSession(s.sessionId, ctrl.text);
              Navigator.pop(ctx);
            },
            child: const Text('Lưu tên mới'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(mindCheckProvider);
    final sessionMessages = appState.messages
        .where((m) => m.sessionId == appState.activeChatSessionId)
        .toList();
    final lastMsg = sessionMessages.isNotEmpty ? sessionMessages.last : null;

    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardOpen = keyboardInset > 60;

    return LayoutBuilder(
      builder: (context, constraints) {
        final showSidePanel =
            MindCheckBreakpoints.isDesktop(constraints.maxWidth);
        final isCompactWidth = constraints.maxWidth < 460;
        final isCompactHeight = constraints.maxHeight < 520 || isKeyboardOpen;
        final bubbleMaxWidth =
            (constraints.maxWidth * (isCompactWidth ? 0.80 : 0.68))
                .clamp(220.0, 480.0);

        return Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  // Thanh trạng thái Người bạn số (Digital Companion Presence Bar)
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: isCompactWidth ? 12 : 16,
                      vertical: 8,
                    ),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border:
                          Border(bottom: BorderSide(color: Color(0xFFE5EAF4))),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Stack(
                              children: [
                                const CircleAvatar(
                                  radius: 17,
                                  backgroundColor: Color(0xFFEDF2FF),
                                  child: Icon(
                                    Icons.auto_awesome_rounded,
                                    size: 18,
                                    color: Color(0xFF3B5BDB),
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: appState.simulateOfflineMode
                                          ? Colors.redAccent
                                          : const Color(0xFF0CA678),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white, width: 1.5),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => showCompanionPersonalizationModal(
                                    context, ref),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Người bạn số ${appState.companionPref.nickname} • Phong cách ${appState.companionPref.tone}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: Color(0xFF1E293B),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      'Không gian ẩn danh định hướng CBT • Xưng "${appState.companionPref.aiPronoun}" - gọi "${appState.companionPref.userPronoun}"',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.black54,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip:
                                  'Lịch sử (${appState.chatSessions.length})',
                              onPressed: () =>
                                  _openChatHistoryBottomSheet(context),
                              icon: Badge(
                                label:
                                    Text('${appState.chatSessions.length}'),
                                backgroundColor: const Color(0xFF3B5BDB),
                                child: const Icon(Icons.history_rounded,
                                    size: 20),
                              ),
                            ),
                            IconButton.filledTonal(
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Cuộc trò chuyện mới',
                              onPressed: () => ref
                                  .read(mindCheckProvider.notifier)
                                  .createNewChatSession(),
                              icon: const Icon(Icons.add_comment_outlined,
                                  size: 18),
                            ),
                          ],
                        ),
                        if (!isKeyboardOpen) ...[
                          const SizedBox(height: 6),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                ActionChip(
                                  visualDensity: VisualDensity.compact,
                                  avatar:
                                      const Icon(Icons.mood_rounded, size: 15),
                                  label: Text(
                                    appState.moodEntries.isEmpty
                                        ? 'Check-in cảm xúc hôm nay'
                                        : 'Tâm trạng: ${appState.moodEntries.first.moodChoice}',
                                    style: const TextStyle(fontSize: 11.5),
                                  ),
                                  onPressed: () => widget.onNavigateTab(1),
                                ),
                                const SizedBox(width: 6),
                                ActionChip(
                                  visualDensity: VisualDensity.compact,
                                  avatar: const Icon(Icons.memory_rounded,
                                      size: 15),
                                  label: Text(
                                    'Trí nhớ AI: ${appState.memories.length} mục',
                                    style: const TextStyle(fontSize: 11.5),
                                  ),
                                  onPressed: () => widget.onNavigateTab(4),
                                ),
                                const SizedBox(width: 6),
                                FilterChip(
                                  visualDensity: VisualDensity.compact,
                                  selected: appState.simulateOfflineMode,
                                  avatar: Icon(
                                    appState.simulateOfflineMode
                                        ? Icons.wifi_off_rounded
                                        : Icons.wifi_rounded,
                                    size: 14,
                                  ),
                                  label: Text(
                                    appState.simulateOfflineMode
                                        ? 'Mạng: Đang Offline'
                                        : 'Mạng: Online',
                                    style: const TextStyle(fontSize: 11.5),
                                  ),
                                  onSelected: (v) => ref
                                      .read(mindCheckProvider.notifier)
                                      .toggleOfflineSimulation(v),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (appState.simulateOfflineMode)
                    Container(
                      width: double.infinity,
                      color: const Color(0xFFFFF5F5),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.wifi_off_rounded,
                              color: Colors.redAccent, size: 18),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Đang mất kết nối mạng. Tin nhắn gửi lúc này sẽ chờ bạn bấm "Thử gửi lại (Retry)" khi có mạng.',
                              style: TextStyle(
                                  color: Colors.redAccent, fontSize: 12),
                            ),
                          ),
                          TextButton(
                            onPressed: () => ref
                                .read(mindCheckProvider.notifier)
                                .toggleOfflineSimulation(false),
                            child: const Text('Kết nối lại'),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: ListView.builder(
                          controller: _scrollCtrl,
                          padding: EdgeInsets.symmetric(
                            horizontal: isCompactWidth ? 12 : 16,
                            vertical: 14,
                          ),
                          itemCount: sessionMessages.length +
                              (appState.isAiTyping ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == sessionMessages.length) {
                              return Align(
                                alignment: Alignment.centerLeft,
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Chip(
                                    backgroundColor: const Color(0xFFEDF2FF),
                                    avatar: const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    ),
                                    label: Text(
                                        '${appState.companionPref.nickname} đang lắng nghe & phản hồi...'),
                                  ),
                                ),
                              );
                            }

                            final msg = sessionMessages[index];
                            final isUser = msg.role == 'user';
                            final isSafety =
                                msg.suggestedAction == 'open_safety_support';

                            return _buildMessageItem(
                              context: context,
                              msg: msg,
                              isUser: isUser,
                              isSafety: isSafety,
                              bubbleMaxWidth: bubbleMaxWidth,
                              appState: appState,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  if (lastMsg != null && lastMsg.quickReplies.isNotEmpty)
                    Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          top: BorderSide(color: Color(0xFFF1F5F9)),
                        ),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: isCompactWidth ? 12 : 16,
                        vertical: isCompactHeight ? 6 : 10,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 760),
                          child: isCompactHeight
                              ? SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: lastMsg.quickReplies
                                        .map(
                                          (qr) => Padding(
                                            padding: const EdgeInsets.only(
                                                right: 8),
                                            child: OutlinedButton(
                                              style: OutlinedButton.styleFrom(
                                                visualDensity:
                                                    VisualDensity.compact,
                                                side: const BorderSide(
                                                    color: Color(0xFF4C6EF5)),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(24),
                                                ),
                                              ),
                                              onPressed: () =>
                                                  _handleQuickReply(context, qr),
                                              child: Text(qr,
                                                  style: const TextStyle(
                                                      fontSize: 12.5)),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Gợi ý phản hồi nhanh:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black54,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: lastMsg.quickReplies
                                          .map(
                                            (qr) => OutlinedButton(
                                              style: OutlinedButton.styleFrom(
                                                visualDensity:
                                                    VisualDensity.compact,
                                                side: const BorderSide(
                                                    color: Color(0xFF4C6EF5)),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(24),
                                                ),
                                              ),
                                              onPressed: () =>
                                                  _handleQuickReply(context, qr),
                                              child: Text(qr,
                                                  style: const TextStyle(
                                                      fontSize: 13)),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  SafeArea(
                    top: false,
                    child: Container(
                      color: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: isCompactWidth ? 10 : 14,
                        vertical: 10,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 760),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _msgCtrl,
                                  textInputAction: TextInputAction.send,
                                  minLines: 1,
                                  maxLines: 3,
                                  decoration: InputDecoration(
                                    hintText:
                                        'Tâm sự ẩn danh cùng ${appState.companionPref.nickname}...',
                                    filled: true,
                                    fillColor: const Color(0xFFF8FAFC),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 18, vertical: 12),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(28),
                                      borderSide: const BorderSide(
                                          color: Color(0xFFCBD5E1)),
                                    ),
                                  ),
                                  onSubmitted: _send,
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton.filled(
                                tooltip: 'Gửi tin nhắn',
                                style: IconButton.styleFrom(
                                  backgroundColor: const Color(0xFF4C6EF5),
                                  padding: const EdgeInsets.all(13),
                                ),
                                onPressed: () => _send(_msgCtrl.text),
                                icon: const Icon(Icons.send_rounded),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (showSidePanel) ...[
              const VerticalDivider(width: 1),
              SizedBox(
                width: 320,
                child: _buildDesktopCompanionSidePanel(appState),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildMessageItem({
    required BuildContext context,
    required ChatMessageModel msg,
    required bool isUser,
    required bool isSafety,
    required double bubbleMaxWidth,
    required MindCheckAppState appState,
  }) {
    final bubble = Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      constraints: BoxConstraints(maxWidth: bubbleMaxWidth),
      decoration: BoxDecoration(
        color: isUser
            ? (msg.state == 'failed'
                ? const Color(0xFFB91C1C)
                : const Color(0xFF4C6EF5))
            : (isSafety ? const Color(0xFFFEF2F2) : Colors.white),
        border: isUser
            ? null
            : Border.all(
                color: isSafety
                    ? const Color(0xFFFCA5A5)
                    : const Color(0xFFE2E8F0),
              ),
        boxShadow: isUser
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(isUser ? 20 : 6),
          bottomRight: Radius.circular(isUser ? 6 : 20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            msg.text,
            style: TextStyle(
              color: isUser ? Colors.white : const Color(0xFF1E293B),
              fontSize: 14.8,
              height: 1.44,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isUser) ...[
                Flexible(
                  child: Text(
                    isSafety
                        ? '🛡️ Cơ chế an toàn 2 lớp • Safety Guardrail'
                        : '✨ ${appState.companionPref.nickname} • Định hướng CBT',
                    style: const TextStyle(fontSize: 10, color: Colors.black45),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Text(' • ',
                    style: TextStyle(fontSize: 10, color: Colors.black38)),
              ],
              Text(
                _formatTime(msg.createdAt),
                style: TextStyle(
                  fontSize: 10,
                  color: isUser ? Colors.white70 : Colors.black45,
                ),
              ),
            ],
          ),
          if (msg.state == 'failed') ...[
            const SizedBox(height: 8),
            const Text(
              '⚠️ Chưa gửi được do mất kết nối mạng',
              style: TextStyle(
                  color: Colors.amberAccent,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFFB91C1C),
                visualDensity: VisualDensity.compact,
              ),
              onPressed: () => _retryMessage(msg.messageId),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text(
                'Thử gửi lại (Retry)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );

    return Column(
      crossAxisAlignment:
          isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (isUser)
          bubble
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 6, right: 8),
                child: CircleAvatar(
                  radius: 14,
                  backgroundColor: isSafety
                      ? const Color(0xFFFEE2E2)
                      : const Color(0xFFEDF2FF),
                  child: Icon(
                    isSafety
                        ? Icons.health_and_safety_rounded
                        : Icons.psychology_alt_rounded,
                    size: 16,
                    color: isSafety
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF3B5BDB),
                  ),
                ),
              ),
              Flexible(child: bubble),
            ],
          ),
        if (msg.memoryProposal != null &&
            msg.memoryProposal!.status == 'proposed')
          Card(
            color: const Color(0xFFEDF2FF),
            margin: const EdgeInsets.only(bottom: 8, left: 36),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.bookmark_add_outlined,
                          size: 18, color: Color(0xFF3B5BDB)),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Bạn có muốn AI ghi nhớ thông tin này cho lần trò chuyện sau không?',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '"${msg.memoryProposal!.candidateText}"',
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      FilledButton.tonal(
                        onPressed: () => ref
                            .read(mindCheckProvider.notifier)
                            .respondToMemoryProposal(
                              msg.messageId,
                              msg.memoryProposal!,
                              true,
                            ),
                        child: const Text('Cho phép ghi nhớ'),
                      ),
                      TextButton(
                        onPressed: () => ref
                            .read(mindCheckProvider.notifier)
                            .respondToMemoryProposal(
                              msg.messageId,
                              msg.memoryProposal!,
                              false,
                            ),
                        child: const Text('Không lưu'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        if (msg.suggestedAction == 'suggest_screening' &&
            !appState.suppressScreeningSuggestion)
          Card(
            color: const Color(0xFFE6FCF5),
            margin: const EdgeInsets.only(bottom: 8, left: 36),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🌿 Gợi ý thực hiện bài sàng lọc tự nguyện (PHQ-9 / GAD-7)',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF087F5B)),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Bạn có muốn dành 2 phút thực hiện bảng hỏi chuẩn hóa để hiểu rõ hơn mức độ căng thẳng của mình không?',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      FilledButton.tonal(
                        onPressed: () => widget.onNavigateTab(2),
                        child: const Text('Thực hiện bài sàng lọc'),
                      ),
                      TextButton(
                        onPressed: () => ref
                            .read(mindCheckProvider.notifier)
                            .dismissScreeningSuggestion(),
                        child: const Text('Để sau'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        if (msg.suggestedAction == 'open_safety_support')
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 36),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: Colors.redAccent),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const SafetySupportScreen()),
                  ),
                  icon: const Icon(Icons.emergency_rounded),
                  label: const Text('Mở Hỗ trợ An toàn & Khẩn cấp'),
                ),
                OutlinedButton.icon(
                  onPressed: () => widget.onNavigateTab(3),
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: const Text('Đặt lịch với chuyên gia trường'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDesktopCompanionSidePanel(MindCheckAppState appState) {
    final completedActs = appState.dailyActivities
        .where((a) => a.status == 'completed')
        .length;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(18),
      child: ListView(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3B5BDB), Color(0xFF5C7CFA)],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Không gian của ${appState.companionPref.userPronoun}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Check-in tuần: ${appState.moodEntries.length} lần • Bài tập CBT: $completedActs/${appState.dailyActivities.length}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            color: const Color(0xFFF8FAFC),
            child: ListTile(
              leading:
                  const Icon(Icons.spa_outlined, color: Color(0xFF0CA678)),
              title: const Text('Bài tập Thở & CBT 5 phút',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: const Text('Thở hộp 4-4-4-4 • CBT • Grounding'),
              onTap: () => widget.onNavigateTab(1),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            color: const Color(0xFFF8FAFC),
            child: ListTile(
              leading: const Icon(Icons.assignment_turned_in_outlined,
                  color: Color(0xFF3B5BDB)),
              title: const Text('Sàng lọc tự nguyện',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: const Text('PHQ-9 • GAD-7 • DASS-21'),
              onTap: () => widget.onNavigateTab(2),
            ),
          ),
          const Divider(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Trí nhớ AI đang bật',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: () => widget.onNavigateTab(4),
                child: const Text('Quản lý'),
              ),
            ],
          ),
          if (appState.memories.isEmpty)
            const Text(
              'Chưa có thông tin nào được lưu. AI chỉ ghi nhớ khi bạn bấm cho phép.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            )
          else
            ...appState.memories.map(
              (m) => Card(
                color: const Color(0xFFEDF2FF),
                child: ListTile(
                  dense: true,
                  title:
                      Text(m.text, style: const TextStyle(fontSize: 12.5)),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => ref
                        .read(mindCheckProvider.notifier)
                        .deleteApprovedMemory(m.memoryId),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
