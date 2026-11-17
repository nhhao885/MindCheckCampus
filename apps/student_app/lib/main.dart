import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/state_provider.dart';
import 'app/theme.dart';
import 'features/chat/chat_companion_screen.dart';
import 'features/mood_daily/mood_daily_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/school_portal/school_portal_screen.dart';
import 'features/screening/screening_screen.dart';
import 'features/settings/memory_settings_screen.dart';
import 'features/support/support_booking_screen.dart';
import 'shared/api_service.dart';
import 'shared/models.dart';

export 'features/chat/chat_companion_screen.dart';
export 'features/mood_daily/mood_daily_screen.dart';
export 'features/onboarding/onboarding_screen.dart';
export 'features/school_portal/school_portal_screen.dart';
export 'features/screening/screening_screen.dart';
export 'features/settings/memory_settings_screen.dart';
export 'features/support/support_booking_screen.dart';

void main() {
  runApp(const ProviderScope(child: MindCheckCampusApp()));
}

class MindCheckCampusApp extends StatelessWidget {
  const MindCheckCampusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MindCheck Campus 2.0 – AI Companion',
      debugShowCheckedModeBanner: false,
      theme: MindCheckTheme.lightTheme,
      home: const RootWorkspaceSwitcher(),
    );
  }
}

void showContaboConfigModal(BuildContext context, WidgetRef ref) {
  final appState = ref.read(mindCheckProvider);
  final urlCtrl = TextEditingController(text: appState.contaboBaseUrl);
  final keyCtrl = TextEditingController(text: appState.geminiApiKey);
  ServerHealthStatus? healthResult;
  bool isCheckingHealth = false;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (modalCtx, setModalState) {
          return Consumer(
            builder: (context, refModal, _) {
              final currentState = refModal.watch(mindCheckProvider);
              return Padding(
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 24,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEDF2FF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.cloud_done_rounded,
                                color: Color(0xFF3B5BDB)),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Cấu hình Máy chủ Contabo & Gemini AI API',
                                  style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'Kết nối FastAPI (Contabo VPS Singapore / Local) & Google Gemini Flash AI',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      const Text('Chế độ môi trường mạng:',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Contabo Cloud VPS (Singapore)'),
                            selected: currentState.backendEnv ==
                                BackendEnvironment.contaboSingapore,
                            onSelected: (_) => refModal
                                .read(mindCheckProvider.notifier)
                                .setBackendEnvironment(
                                    BackendEnvironment.contaboSingapore),
                          ),
                          ChoiceChip(
                            label: const Text('Local FastAPI (127.0.0.1:8000)'),
                            selected: currentState.backendEnv ==
                                BackendEnvironment.localFastApi,
                            onSelected: (_) => refModal
                                .read(mindCheckProvider.notifier)
                                .setBackendEnvironment(
                                    BackendEnvironment.localFastApi),
                          ),
                          ChoiceChip(
                            label: const Text('Chế độ Ngoại tuyến (Offline)'),
                            selected: currentState.backendEnv ==
                                BackendEnvironment.offlineSimulated,
                            onSelected: (_) => refModal
                                .read(mindCheckProvider.notifier)
                                .setBackendEnvironment(
                                    BackendEnvironment.offlineSimulated),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: urlCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Địa chỉ Backend API (Contabo VPS / Local)',
                          helperText:
                              'VD Production: https://api.mindcheck.edu.vn/v1 • Android Emulator: http://10.0.2.2:8000/v1',
                          prefixIcon: Icon(Icons.dns_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: keyCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Google Gemini API Key (AQ... / AIza...)',
                          helperText:
                              'Khuyến nghị cấu hình trên Server (.env) hoặc điền tại đây khi kết nối trực tiếp',
                          prefixIcon: Icon(Icons.key_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (healthResult != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: healthResult!.reachable
                                ? const Color(0xFFE6FCF5)
                                : const Color(0xFFFFF7ED),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: healthResult!.reachable
                                  ? const Color(0xFF0CA678)
                                  : const Color(0xFFF59E0B),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                healthResult!.reachable
                                    ? Icons.check_circle_rounded
                                    : Icons.info_outline_rounded,
                                color: healthResult!.reachable
                                    ? const Color(0xFF087F5B)
                                    : const Color(0xFFD97706),
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  healthResult!.message,
                                  style: const TextStyle(fontSize: 12.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          OutlinedButton.icon(
                            onPressed: isCheckingHealth
                                ? null
                                : () async {
                                    setModalState(() => isCheckingHealth = true);
                                    final res = await refModal
                                        .read(mindCheckProvider.notifier)
                                        .checkBackendConnection(
                                          overrideEnv: currentState.backendEnv,
                                          overrideUrl: urlCtrl.text.trim(),
                                        );
                                    if (modalCtx.mounted) {
                                      setModalState(() {
                                        healthResult = res;
                                        isCheckingHealth = false;
                                      });
                                    }
                                  },
                            icon: isCheckingHealth
                                ? const SizedBox(
                                    width: 15,
                                    height: 15,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.network_check_rounded,
                                    size: 18),
                            label: const Text('Kiểm tra kết nối (/v1/health)'),
                          ),
                          FilledButton.icon(
                            onPressed: () {
                              refModal
                                  .read(mindCheckProvider.notifier)
                                  .setBackendEnvironment(
                                    currentState.backendEnv,
                                    customUrl: urlCtrl.text.trim(),
                                    apiKey: keyCtrl.text.trim(),
                                  );
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Đã lưu cấu hình kết nối AI và máy chủ thành công!'),
                                ),
                              );
                            },
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text('Áp dụng cấu hình ngay'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    },
  );
}

class RootWorkspaceSwitcher extends ConsumerStatefulWidget {
  const RootWorkspaceSwitcher({super.key});

  @override
  ConsumerState<RootWorkspaceSwitcher> createState() =>
      _RootWorkspaceSwitcherState();
}

class _RootWorkspaceSwitcherState extends ConsumerState<RootWorkspaceSwitcher> {
  bool _isSchoolWebPortal = false;

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(mindCheckProvider);

    if (_isSchoolWebPortal) {
      return SchoolPortalShell(
        onSwitchToStudentApp: () => setState(() => _isSchoolWebPortal = false),
      );
    }

    if (!appState.hasAcceptedPrivacy) {
      return OnboardingFlowScreen(
        onOpenSchoolPortal: () => setState(() => _isSchoolWebPortal = true),
        onOpenContaboConfig: () => showContaboConfigModal(context, ref),
      );
    }

    return StudentMainShell(
      onOpenSchoolPortal: () => setState(() => _isSchoolWebPortal = true),
    );
  }
}

class StudentMainShell extends ConsumerStatefulWidget {
  final VoidCallback onOpenSchoolPortal;
  const StudentMainShell({super.key, required this.onOpenSchoolPortal});

  @override
  ConsumerState<StudentMainShell> createState() => _StudentMainShellState();
}

class _StudentMainShellState extends ConsumerState<StudentMainShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(mindCheckProvider);
    final pages = [
      StudentHomeAndChatScreen(
        onNavigateTab: (idx) => setState(() => _selectedIndex = idx),
      ),
      const DailyAndMoodHubScreen(),
      VoluntaryScreeningHubScreen(
        onNavigateToBooking: () => setState(() => _selectedIndex = 3),
      ),
      const SupportAndCounselingHubScreen(),
      const KnowledgeMemorySettingsHubScreen(),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final useNavigationRail =
            !MindCheckBreakpoints.isMobile(constraints.maxWidth);
        final isCompactMobile = constraints.maxWidth < 460;
        final isUltraCompact = constraints.maxWidth < 375;

        return Scaffold(
          appBar: AppBar(
            backgroundColor: MindCheckTheme.sereneIndigo,
            foregroundColor: Colors.white,
            titleSpacing: isCompactMobile ? 10 : 16,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.psychology_alt_rounded, size: 20),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MindCheck • ${appState.companionPref.nickname}',
                        style: TextStyle(
                          fontSize: isUltraCompact ? 14 : 15.5,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        appState.backendEnv ==
                                BackendEnvironment.contaboSingapore
                            ? '🟢 Contabo Cloud • ${appState.userEmail ?? appState.guestId ?? "Ẩn danh"}'
                            : (appState.backendEnv ==
                                    BackendEnvironment.localFastApi
                                ? '🔵 Local FastAPI • ${appState.userEmail ?? appState.guestId ?? "Ẩn danh"}'
                                : '🔴 Đang ở chế độ Ngoại tuyến (Offline)'),
                        style: const TextStyle(
                            fontSize: 10.5, color: Colors.white70),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                visualDensity: isCompactMobile
                    ? VisualDensity.compact
                    : VisualDensity.standard,
                constraints: isCompactMobile
                    ? const BoxConstraints(minWidth: 34, minHeight: 34)
                    : null,
                padding: isCompactMobile ? const EdgeInsets.all(6) : null,
                tooltip: 'Cá nhân hóa bạn AI',
                onPressed: () =>
                    showCompanionPersonalizationModal(context, ref),
                icon: const Icon(Icons.tune_rounded, size: 20),
              ),
              IconButton(
                visualDensity: isCompactMobile
                    ? VisualDensity.compact
                    : VisualDensity.standard,
                constraints: isCompactMobile
                    ? const BoxConstraints(minWidth: 34, minHeight: 34)
                    : null,
                padding: isCompactMobile ? const EdgeInsets.all(6) : null,
                tooltip: 'Kết nối AI API & Máy chủ Contabo',
                onPressed: () => showContaboConfigModal(context, ref),
                icon: const Icon(Icons.cloud_done_outlined, size: 20),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  visualDensity: isCompactMobile
                      ? VisualDensity.compact
                      : VisualDensity.standard,
                  minimumSize:
                      isCompactMobile ? const Size(44, 34) : null,
                  tapTargetSize: isCompactMobile
                      ? MaterialTapTargetSize.shrinkWrap
                      : null,
                  padding: EdgeInsets.symmetric(
                      horizontal: isUltraCompact ? 6 : 10),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const SafetySupportScreen()),
                ),
                icon: const Icon(Icons.emergency_rounded,
                    color: Colors.amberAccent, size: 17),
                label: Text(
                  isCompactMobile ? 'SOS' : 'Hỗ trợ khẩn cấp',
                  style: const TextStyle(
                      color: Colors.amberAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5),
                ),
              ),
              IconButton(
                visualDensity: isCompactMobile
                    ? VisualDensity.compact
                    : VisualDensity.standard,
                constraints: isCompactMobile
                    ? const BoxConstraints(minWidth: 34, minHeight: 34)
                    : null,
                padding: isCompactMobile ? const EdgeInsets.all(6) : null,
                tooltip: 'Cổng Web Nhà trường & Tư vấn viên',
                onPressed: widget.onOpenSchoolPortal,
                icon: const Icon(Icons.domain_verification_rounded, size: 20),
              ),
            ],
          ),
          body: useNavigationRail
              ? Row(
                  children: [
                    NavigationRail(
                      backgroundColor: Colors.white,
                      selectedIndex: _selectedIndex,
                      onDestinationSelected: (idx) =>
                          setState(() => _selectedIndex = idx),
                      labelType: NavigationRailLabelType.all,
                      leading: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: FloatingActionButton.small(
                          heroTag: 'new_chat_fab',
                          tooltip: 'Tạo cuộc trò chuyện mới',
                          backgroundColor: const Color(0xFFEDF2FF),
                          foregroundColor: MindCheckTheme.sereneIndigo,
                          elevation: 0,
                          onPressed: () {
                            ref
                                .read(mindCheckProvider.notifier)
                                .createNewChatSession();
                            setState(() => _selectedIndex = 0);
                          },
                          child: const Icon(Icons.add_comment_outlined),
                        ),
                      ),
                      destinations: const [
                        NavigationRailDestination(
                          icon: Icon(Icons.chat_bubble_outline_rounded),
                          selectedIcon: Icon(Icons.chat_bubble_rounded),
                          label: Text('Bạn AI'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.mood_outlined),
                          selectedIcon: Icon(Icons.mood_rounded),
                          label: Text('Cảm xúc'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.assignment_outlined),
                          selectedIcon: Icon(Icons.assignment_rounded),
                          label: Text('Sàng lọc'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.support_agent_outlined),
                          selectedIcon: Icon(Icons.support_agent_rounded),
                          label: Text('Tư vấn'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.memory_outlined),
                          selectedIcon: Icon(Icons.memory_rounded),
                          label: Text('Cài đặt'),
                        ),
                      ],
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: pages[_selectedIndex]),
                  ],
                )
              : pages[_selectedIndex],
          bottomNavigationBar: useNavigationRail
              ? null
              : NavigationBar(
                  backgroundColor: Colors.white,
                  height: 68,
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (idx) =>
                      setState(() => _selectedIndex = idx),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.chat_bubble_outline_rounded),
                      selectedIcon: Icon(Icons.chat_bubble_rounded),
                      label: 'Bạn AI',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.mood_outlined),
                      selectedIcon: Icon(Icons.mood_rounded),
                      label: 'Cảm xúc',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.assignment_outlined),
                      selectedIcon: Icon(Icons.assignment_rounded),
                      label: 'Sàng lọc',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.support_agent_outlined),
                      selectedIcon: Icon(Icons.support_agent_rounded),
                      label: 'Tư vấn',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.memory_outlined),
                      selectedIcon: Icon(Icons.memory_rounded),
                      label: 'Cài đặt',
                    ),
                  ],
                ),
        );
      },
    );
  }
}
