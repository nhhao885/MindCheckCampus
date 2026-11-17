enum ActorRole { student, ctsv, counselor1, counselor2, admin }

enum BackendEnvironment { contaboSingapore, localFastApi, offlineSimulated }

class CompanionPreference {
  final String nickname;
  final String userPronoun;
  final String aiPronoun;
  final String tone;

  const CompanionPreference({
    this.nickname = 'MindCheck',
    this.userPronoun = 'bạn',
    this.aiPronoun = 'mình',
    this.tone = 'ấm áp, gần gũi',
  });

  CompanionPreference copyWith({
    String? nickname,
    String? userPronoun,
    String? aiPronoun,
    String? tone,
  }) {
    return CompanionPreference(
      nickname: nickname ?? this.nickname,
      userPronoun: userPronoun ?? this.userPronoun,
      aiPronoun: aiPronoun ?? this.aiPronoun,
      tone: tone ?? this.tone,
    );
  }

  Map<String, dynamic> toJson() => {
        'nickname': nickname,
        'userPronoun': userPronoun,
        'aiPronoun': aiPronoun,
        'tone': tone,
      };

  factory CompanionPreference.fromJson(Map<String, dynamic> json) {
    return CompanionPreference(
      nickname: json['nickname']?.toString() ?? 'MindCheck',
      userPronoun:
          (json['userPronoun'] ?? json['user_pronoun'])?.toString() ?? 'bạn',
      aiPronoun:
          (json['aiPronoun'] ?? json['ai_pronoun'])?.toString() ?? 'mình',
      tone: json['tone']?.toString() ?? 'ấm áp, gần gũi',
    );
  }
}

class NotificationPreference {
  final bool enabled;
  final String reminderTime;
  final String quietHours;
  final bool hideSensitiveOnLockScreen;

  const NotificationPreference({
    this.enabled = true,
    this.reminderTime = '20:00',
    this.quietHours = '22:00 - 07:00',
    this.hideSensitiveOnLockScreen = true,
  });

  NotificationPreference copyWith({
    bool? enabled,
    String? reminderTime,
    String? quietHours,
    bool? hideSensitiveOnLockScreen,
  }) {
    return NotificationPreference(
      enabled: enabled ?? this.enabled,
      reminderTime: reminderTime ?? this.reminderTime,
      quietHours: quietHours ?? this.quietHours,
      hideSensitiveOnLockScreen:
          hideSensitiveOnLockScreen ?? this.hideSensitiveOnLockScreen,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'reminderTime': reminderTime,
        'quietHours': quietHours,
        'hideSensitiveOnLockScreen': hideSensitiveOnLockScreen,
      };

  factory NotificationPreference.fromJson(Map<String, dynamic> json) {
    return NotificationPreference(
      enabled: json['enabled'] as bool? ?? true,
      reminderTime:
          (json['reminderTime'] ?? json['reminder_time'])?.toString() ??
              '20:00',
      quietHours: (json['quietHours'] ?? json['quiet_hours'])?.toString() ??
          '22:00 - 07:00',
      hideSensitiveOnLockScreen: (json['hideSensitiveOnLockScreen'] ??
              json['hide_sensitive_on_lock_screen']) as bool? ??
          true,
    );
  }
}

class ConsentRecord {
  final String consentId;
  final String purpose;
  final String version;
  final String decision;
  final DateTime timestamp;

  ConsentRecord({
    required this.consentId,
    required this.purpose,
    this.version = 'v1.0-2026',
    required this.decision,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'consentId': consentId,
        'purpose': purpose,
        'version': version,
        'decision': decision,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ConsentRecord.fromJson(Map<String, dynamic> json) {
    return ConsentRecord(
      consentId: (json['consentId'] ?? json['consent_id'])?.toString() ?? '',
      purpose: json['purpose']?.toString() ?? 'privacy_policy',
      version: json['version']?.toString() ?? 'v1.0-2026',
      decision: json['decision']?.toString() ?? 'accepted',
      timestamp: DateTime.tryParse(
            (json['timestamp'] ?? json['created_at'])?.toString() ?? '',
          ) ??
          DateTime.now(),
    );
  }
}

class MemoryProposal {
  final String proposalId;
  final String sourceMessageId;
  final String candidateText;
  final String status;

  MemoryProposal({
    required this.proposalId,
    required this.sourceMessageId,
    required this.candidateText,
    this.status = 'proposed',
  });

  MemoryProposal copyWith({String? status}) {
    return MemoryProposal(
      proposalId: proposalId,
      sourceMessageId: sourceMessageId,
      candidateText: candidateText,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() => {
        'proposalId': proposalId,
        'sourceMessageId': sourceMessageId,
        'candidateText': candidateText,
        'status': status,
      };

  factory MemoryProposal.fromJson(Map<String, dynamic> json) {
    return MemoryProposal(
      proposalId:
          (json['proposalId'] ?? json['proposal_id'])?.toString() ?? '',
      sourceMessageId:
          (json['sourceMessageId'] ?? json['source_message_id'])?.toString() ??
              '',
      candidateText:
          (json['candidateText'] ?? json['candidate_text'])?.toString() ?? '',
      status: json['status']?.toString() ?? 'proposed',
    );
  }
}

class ApprovedMemory {
  final String memoryId;
  final String text;
  final DateTime updatedAt;

  ApprovedMemory({
    required this.memoryId,
    required this.text,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'memoryId': memoryId,
        'text': text,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ApprovedMemory.fromJson(Map<String, dynamic> json) {
    return ApprovedMemory(
      memoryId: (json['memoryId'] ?? json['memory_id'])?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      updatedAt: DateTime.tryParse(
            (json['updatedAt'] ?? json['updated_at'])?.toString() ?? '',
          ) ??
          DateTime.now(),
    );
  }
}

class ChatMessageModel {
  final String messageId;
  final String sessionId;
  final String role;
  final String text;
  final String state;
  final List<String> quickReplies;
  final String? suggestedAction;
  final MemoryProposal? memoryProposal;
  final String providerBadge;
  final DateTime createdAt;

  ChatMessageModel({
    required this.messageId,
    required this.sessionId,
    required this.role,
    required this.text,
    this.state = 'delivered',
    this.quickReplies = const [],
    this.suggestedAction,
    this.memoryProposal,
    this.providerBadge = 'Contabo SG • Gemini 2.5 Flash',
    required this.createdAt,
  });

  ChatMessageModel copyWith({
    String? state,
    MemoryProposal? memoryProposal,
  }) {
    return ChatMessageModel(
      messageId: messageId,
      sessionId: sessionId,
      role: role,
      text: text,
      state: state ?? this.state,
      quickReplies: quickReplies,
      suggestedAction: suggestedAction,
      memoryProposal: memoryProposal ?? this.memoryProposal,
      providerBadge: providerBadge,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'messageId': messageId,
        'sessionId': sessionId,
        'role': role,
        'text': text,
        'state': state,
        'quickReplies': quickReplies,
        'suggestedAction': suggestedAction,
        'memoryProposal': memoryProposal?.toJson(),
        'providerBadge': providerBadge,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    final rawQr = (json['quickReplies'] ?? json['quick_replies'])
        as List<dynamic>?;
    final rawMp = json['memoryProposal'] ?? json['memory_proposal'];
    return ChatMessageModel(
      messageId: (json['messageId'] ?? json['message_id'])?.toString() ?? '',
      sessionId: (json['sessionId'] ?? json['session_id'])?.toString() ??
          'chat_session_01',
      role: json['role']?.toString() ?? 'assistant',
      text: json['text']?.toString() ?? '',
      state: json['state']?.toString() ?? 'delivered',
      quickReplies:
          rawQr != null ? rawQr.map((e) => e.toString()).toList() : const [],
      suggestedAction:
          (json['suggestedAction'] ?? json['suggested_action'])?.toString(),
      memoryProposal: rawMp is Map
          ? MemoryProposal.fromJson(Map<String, dynamic>.from(rawMp))
          : null,
      providerBadge:
          (json['providerBadge'] ?? json['provider_badge'])?.toString() ??
              'Contabo SG • Gemini 2.5 Flash',
      createdAt: DateTime.tryParse(
            (json['createdAt'] ?? json['created_at'])?.toString() ?? '',
          ) ??
          DateTime.now(),
    );
  }
}

class ChatSessionModel {
  final String sessionId;
  final String title;
  final DateTime startedAt;

  ChatSessionModel({
    required this.sessionId,
    required this.title,
    required this.startedAt,
  });

  ChatSessionModel copyWith({String? title}) {
    return ChatSessionModel(
      sessionId: sessionId,
      title: title ?? this.title,
      startedAt: startedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'title': title,
        'startedAt': startedAt.toIso8601String(),
      };

  factory ChatSessionModel.fromJson(Map<String, dynamic> json) {
    return ChatSessionModel(
      sessionId: (json['sessionId'] ?? json['session_id'])?.toString() ??
          'chat_session_01',
      title: json['title']?.toString() ?? 'Cuộc trò chuyện đồng hành',
      startedAt: DateTime.tryParse(
            (json['startedAt'] ?? json['started_at'])?.toString() ?? '',
          ) ??
          DateTime.now(),
    );
  }
}

class MoodEntryModel {
  final String entryId;
  final String moodChoice;
  final int moodLevel;
  final String optionalNote;
  final DateTime recordedAt;

  MoodEntryModel({
    required this.entryId,
    required this.moodChoice,
    required this.moodLevel,
    required this.optionalNote,
    required this.recordedAt,
  });

  Map<String, dynamic> toJson() => {
        'entryId': entryId,
        'moodChoice': moodChoice,
        'moodLevel': moodLevel,
        'optionalNote': optionalNote,
        'recordedAt': recordedAt.toIso8601String(),
      };

  factory MoodEntryModel.fromJson(Map<String, dynamic> json) {
    return MoodEntryModel(
      entryId: (json['entryId'] ?? json['entry_id'])?.toString() ?? '',
      moodChoice:
          (json['moodChoice'] ?? json['mood_choice'])?.toString() ?? '😊 Ổn định',
      moodLevel:
          ((json['moodLevel'] ?? json['mood_level']) as num?)?.toInt() ?? 4,
      optionalNote:
          (json['optionalNote'] ?? json['optional_note'])?.toString() ?? '',
      recordedAt: DateTime.tryParse(
            (json['recordedAt'] ?? json['recorded_at'])?.toString() ?? '',
          ) ??
          DateTime.now(),
    );
  }
}

class DailyActivityModel {
  final String activityId;
  final String title;
  final String category;
  final String duration;
  final List<String> steps;
  final String status;
  final String? lastPracticeSummary;

  DailyActivityModel({
    required this.activityId,
    required this.title,
    required this.category,
    required this.duration,
    required this.steps,
    this.status = 'not_started',
    this.lastPracticeSummary,
  });

  DailyActivityModel copyWith({
    String? status,
    String? lastPracticeSummary,
  }) {
    return DailyActivityModel(
      activityId: activityId,
      title: title,
      category: category,
      duration: duration,
      steps: steps,
      status: status ?? this.status,
      lastPracticeSummary: lastPracticeSummary ?? this.lastPracticeSummary,
    );
  }
}

class ScreeningToolModel {
  final String toolId;
  final String name;
  final String subtitle;
  final String description;
  final List<String> questions;
  final List<String> scaleLabels;

  const ScreeningToolModel({
    required this.toolId,
    required this.name,
    required this.subtitle,
    required this.description,
    required this.questions,
    this.scaleLabels = const [
      'Không chút nào (0)',
      'Vài ngày (1)',
      'Hơn nửa số ngày (2)',
      'Gần như mỗi ngày (3)',
    ],
  });
}

class ScreeningResultModel {
  static const List<int> dass21StressIndices = [0, 5, 7, 10, 11, 13, 17];
  static const List<int> dass21AnxietyIndices = [1, 3, 6, 8, 14, 18, 19];
  static const List<int> dass21DepressionIndices = [2, 4, 9, 12, 15, 16, 20];

  static Map<String, int> computeDass21Subscales(List<int> answers) {
    if (answers.length < 21) {
      final total = answers.fold<int>(0, (s, v) => s + v);
      final third = (total / 3).round();
      final second = ((total + 1) / 3).round();
      final rem = (total - third - second).clamp(0, 21);
      return {'stress': third, 'anxiety': second, 'depression': rem};
    }
    return {
      'stress': dass21StressIndices.fold<int>(0, (s, i) => s + answers[i]),
      'anxiety': dass21AnxietyIndices.fold<int>(0, (s, i) => s + answers[i]),
      'depression':
          dass21DepressionIndices.fold<int>(0, (s, i) => s + answers[i]),
    };
  }

  final String sessionId;
  final String toolId;
  final int score;
  final int maxScore;
  final String levelLabel;
  final String interpretation;
  final bool requiresAttention;
  final List<double> fourWeekTrend;
  final Map<String, int> subscaleScores;
  final DateTime completedAt;
  final String faculty;
  final String academicYear;
  final bool isClinicalDiagnosis;
  final bool demoFlag;

  ScreeningResultModel({
    required this.sessionId,
    required this.toolId,
    required this.score,
    required this.maxScore,
    required this.levelLabel,
    required this.interpretation,
    required this.requiresAttention,
    this.fourWeekTrend = const [],
    this.subscaleScores = const {},
    required this.completedAt,
    this.faculty = 'CNTT',
    this.academicYear = 'Nam_2',
    this.isClinicalDiagnosis = false,
    this.demoFlag = false,
  });

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'toolId': toolId,
        'score': score,
        'maxScore': maxScore,
        'levelLabel': levelLabel,
        'interpretation': interpretation,
        'requiresAttention': requiresAttention,
        'fourWeekTrend': fourWeekTrend,
        'subscaleScores': subscaleScores,
        'completedAt': completedAt.toIso8601String(),
        'faculty': faculty,
        'academicYear': academicYear,
        'isClinicalDiagnosis': isClinicalDiagnosis,
        'demoFlag': demoFlag,
      };

  factory ScreeningResultModel.fromJson(Map<String, dynamic> json) {
    final rawTrend =
        (json['fourWeekTrend'] ?? json['four_week_trend']) as List<dynamic>?;
    final rawSub = json['subscaleScores'] ?? json['subscale_scores'];
    final parsedSub = <String, int>{};
    if (rawSub is Map) {
      for (final entry in rawSub.entries) {
        final k = entry.key?.toString() ?? '';
        final v = (entry.value as num?)?.toInt();
        if (k.isNotEmpty && v != null) {
          parsedSub[k] = v;
        }
      }
    }
    return ScreeningResultModel(
      sessionId: (json['sessionId'] ?? json['session_id'])?.toString() ?? '',
      toolId: (json['toolId'] ?? json['tool_id'])?.toString() ?? 'GAD-7',
      score: (json['score'] as num?)?.toInt() ?? 0,
      maxScore: ((json['maxScore'] ?? json['max_score']) as num?)?.toInt() ?? 21,
      levelLabel:
          (json['levelLabel'] ?? json['level_label'])?.toString() ?? '',
      interpretation: json['interpretation']?.toString() ?? '',
      requiresAttention:
          (json['requiresAttention'] ?? json['requires_attention']) as bool? ??
              false,
      fourWeekTrend: rawTrend != null
          ? rawTrend.map((e) => (e as num).toDouble()).toList()
          : const [],
      subscaleScores: parsedSub,
      completedAt: DateTime.tryParse(
            (json['completedAt'] ?? json['completed_at'])?.toString() ?? '',
          ) ??
          DateTime.now(),
      faculty: json['faculty']?.toString() ?? 'CNTT',
      academicYear:
          (json['academicYear'] ?? json['academic_year'])?.toString() ??
              'Nam_2',
      isClinicalDiagnosis: (json['isClinicalDiagnosis'] ??
              json['is_clinical_diagnosis']) as bool? ??
          false,
      demoFlag: (json['demoFlag'] ?? json['demo_flag']) as bool? ?? false,
    );
  }
}

class CounselingBookingModel {
  final String requestId;
  final String unitName;
  final String counselorId;
  final String counselorName;
  final String slotTime;
  final String consultationMode;
  final String contactInfo;
  final String studentNote;
  final String counselorNote;
  final String consentId;
  final String requesterToken;
  final String status;
  final DateTime createdAt;

  CounselingBookingModel({
    required this.requestId,
    required this.unitName,
    required this.counselorId,
    required this.counselorName,
    required this.slotTime,
    this.consultationMode = 'Trực tiếp tại phòng P.102',
    required this.contactInfo,
    required this.studentNote,
    this.counselorNote = '',
    required this.consentId,
    this.requesterToken = '',
    this.status = 'pending',
    required this.createdAt,
  });

  CounselingBookingModel copyWith({
    String? requestId,
    String? status,
    String? slotTime,
    String? consultationMode,
    String? counselorNote,
    String? requesterToken,
  }) {
    return CounselingBookingModel(
      requestId: requestId ?? this.requestId,
      unitName: unitName,
      counselorId: counselorId,
      counselorName: counselorName,
      slotTime: slotTime ?? this.slotTime,
      consultationMode: consultationMode ?? this.consultationMode,
      contactInfo: contactInfo,
      studentNote: studentNote,
      counselorNote: counselorNote ?? this.counselorNote,
      consentId: consentId,
      requesterToken: requesterToken ?? this.requesterToken,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'requestId': requestId,
        'unitName': unitName,
        'counselorId': counselorId,
        'counselorName': counselorName,
        'slotTime': slotTime,
        'consultationMode': consultationMode,
        'contactInfo': contactInfo,
        'studentNote': studentNote,
        'counselorNote': counselorNote,
        'consentId': consentId,
        'requesterToken': requesterToken,
        'status': status,
        'createdAt': createdAt.toIso8601String(),
      };

  factory CounselingBookingModel.fromJson(Map<String, dynamic> json) {
    return CounselingBookingModel(
      requestId: (json['requestId'] ?? json['request_id'])?.toString() ?? '',
      unitName: (json['unitName'] ?? json['unit_name'])?.toString() ??
          'Phòng Tư vấn Tâm lý Sinh viên',
      counselorId: (json['counselorId'] ?? json['counselor_id'])?.toString() ??
          'counselor_01',
      counselorName:
          (json['counselorName'] ?? json['counselor_name'])?.toString() ??
              'ThS. Tâm lý Nguyễn Văn A',
      slotTime: (json['slotTime'] ?? json['slot_time'])?.toString() ??
          'Thứ 4 (09:00 - 10:00)',
      consultationMode:
          (json['consultationMode'] ?? json['consultation_mode'])?.toString() ??
              'Trực tiếp tại phòng P.102',
      contactInfo:
          (json['contactInfo'] ?? json['contact_info'])?.toString() ?? '',
      studentNote:
          (json['studentNote'] ?? json['student_note'])?.toString() ?? '',
      counselorNote:
          (json['counselorNote'] ?? json['counselor_note'])?.toString() ?? '',
      consentId: (json['consentId'] ?? json['consent_id'])?.toString() ?? '',
      requesterToken:
          (json['requesterToken'] ?? json['requester_token'])?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      createdAt: DateTime.tryParse(
            (json['createdAt'] ?? json['created_at'])?.toString() ?? '',
          ) ??
          DateTime.now(),
    );
  }
}

class CounselorSlotModel {
  final String slotId;
  final String counselorId;
  final String counselorName;
  final String unitName;
  final String slotLabel;
  final String consultationMode;
  final bool isAvailable;

  const CounselorSlotModel({
    required this.slotId,
    required this.counselorId,
    required this.counselorName,
    required this.unitName,
    required this.slotLabel,
    this.consultationMode = 'Trực tiếp tại phòng P.102',
    this.isAvailable = true,
  });

  CounselorSlotModel copyWith({
    String? slotLabel,
    String? consultationMode,
    bool? isAvailable,
  }) {
    return CounselorSlotModel(
      slotId: slotId,
      counselorId: counselorId,
      counselorName: counselorName,
      unitName: unitName,
      slotLabel: slotLabel ?? this.slotLabel,
      consultationMode: consultationMode ?? this.consultationMode,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }

  Map<String, dynamic> toJson() => {
        'slotId': slotId,
        'counselorId': counselorId,
        'counselorName': counselorName,
        'unitName': unitName,
        'slotLabel': slotLabel,
        'consultationMode': consultationMode,
        'isAvailable': isAvailable,
      };

  factory CounselorSlotModel.fromJson(Map<String, dynamic> json) {
    return CounselorSlotModel(
      slotId: (json['slotId'] ?? json['slot_id'])?.toString() ?? '',
      counselorId:
          (json['counselorId'] ?? json['counselor_id'])?.toString() ?? 'counselor_01',
      counselorName:
          (json['counselorName'] ?? json['counselor_name'])?.toString() ??
              'ThS. Tâm lý Nguyễn Văn A',
      unitName: (json['unitName'] ?? json['unit_name'])?.toString() ??
          'Phòng Tư vấn Tâm lý Sinh viên',
      slotLabel: (json['slotLabel'] ?? json['slot_label'])?.toString() ?? '',
      consultationMode:
          (json['consultationMode'] ?? json['consultation_mode'])?.toString() ??
              'Trực tiếp tại phòng P.102',
      isAvailable: (json['isAvailable'] ?? json['is_available']) as bool? ?? true,
    );
  }
}

class StaffAccountModel {
  final String staffId;
  final String role;
  final String displayName;
  final String unitName;
  final bool isActive;

  const StaffAccountModel({
    required this.staffId,
    required this.role,
    required this.displayName,
    this.unitName = 'Phòng Công tác Sinh viên & Tư vấn',
    this.isActive = true,
  });

  StaffAccountModel copyWith({
    String? role,
    String? displayName,
    String? unitName,
    bool? isActive,
  }) {
    return StaffAccountModel(
      staffId: staffId,
      role: role ?? this.role,
      displayName: displayName ?? this.displayName,
      unitName: unitName ?? this.unitName,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toJson() => {
        'staffId': staffId,
        'role': role,
        'displayName': displayName,
        'unitName': unitName,
        'isActive': isActive,
      };

  factory StaffAccountModel.fromJson(Map<String, dynamic> json) {
    return StaffAccountModel(
      staffId: (json['staffId'] ?? json['staff_id'])?.toString() ?? '',
      role: json['role']?.toString() ?? 'counselor',
      displayName:
          (json['displayName'] ?? json['display_name'])?.toString() ?? '',
      unitName: (json['unitName'] ?? json['unit_name'])?.toString() ??
          'Phòng Công tác Sinh viên & Tư vấn',
      isActive: (json['isActive'] ?? json['is_active']) as bool? ?? true,
    );
  }
}

class SafetyHotlineModel {
  final String hotlineId;
  final String name;
  final String phone;
  final String description;
  final String hours;
  final bool isVerified;

  const SafetyHotlineModel({
    required this.hotlineId,
    required this.name,
    required this.phone,
    required this.description,
    this.hours = '24/7',
    this.isVerified = true,
  });

  Map<String, dynamic> toJson() => {
        'hotlineId': hotlineId,
        'name': name,
        'phone': phone,
        'description': description,
        'hours': hours,
        'isVerified': isVerified,
      };

  factory SafetyHotlineModel.fromJson(Map<String, dynamic> json) {
    return SafetyHotlineModel(
      hotlineId: (json['hotlineId'] ?? json['hotline_id'])?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      hours: json['hours']?.toString() ?? '24/7',
      isVerified: (json['isVerified'] ?? json['is_verified']) as bool? ?? true,
    );
  }
}

class KnowledgeArticleModel {
  final String id;
  final String title;
  final String category;
  final String summary;
  final String content;
  final String verifiedSource;

  const KnowledgeArticleModel({
    required this.id,
    required this.title,
    required this.category,
    required this.summary,
    required this.content,
    required this.verifiedSource,
  });

  KnowledgeArticleModel copyWith({
    String? title,
    String? category,
    String? summary,
    String? content,
    String? verifiedSource,
  }) {
    return KnowledgeArticleModel(
      id: id,
      title: title ?? this.title,
      category: category ?? this.category,
      summary: summary ?? this.summary,
      content: content ?? this.content,
      verifiedSource: verifiedSource ?? this.verifiedSource,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'summary': summary,
        'content': content,
        'verifiedSource': verifiedSource,
      };

  factory KnowledgeArticleModel.fromJson(Map<String, dynamic> json) {
    return KnowledgeArticleModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      category: json['category']?.toString() ?? 'Kỹ năng Tự chăm sóc',
      summary: json['summary']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      verifiedSource: (json['verifiedSource'] ?? json['verified_source'])
              ?.toString() ??
          'Tài liệu Giáo dục Tâm lý Học đường đã kiểm duyệt',
    );
  }
}

class AuditEventModel {
  final String eventId;
  final String actor;
  final String action;
  final String target;
  final String result;
  final DateTime timestamp;

  AuditEventModel({
    required this.eventId,
    required this.actor,
    required this.action,
    required this.target,
    required this.result,
    required this.timestamp,
  });

  factory AuditEventModel.fromJson(Map<String, dynamic> json) {
    return AuditEventModel(
      eventId: (json['eventId'] ?? json['event_id'])?.toString() ?? '',
      actor: json['actor']?.toString() ?? '',
      action: json['action']?.toString() ?? '',
      target: json['target']?.toString() ?? '',
      result: json['result']?.toString() ?? '',
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class AnalyticsTopicStat {
  final String topic;
  final double percentage;

  const AnalyticsTopicStat({
    required this.topic,
    required this.percentage,
  });

  factory AnalyticsTopicStat.fromJson(Map<String, dynamic> json) {
    return AnalyticsTopicStat(
      topic: json['topic']?.toString() ?? '',
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class AnalyticsOverviewModel {
  final bool suppressed;
  final int sampleSize;
  final int minGroupSize;
  final String faculty;
  final String academicYear;
  final String period;
  final int totalScreenings;
  final int highRiskCount;
  final int connectedBookingsCount;
  final double bookingConversionRate;
  final int moodCheckinCount;
  final double avgMoodLevel;
  final int cbtCompletedCount;
  final List<AnalyticsTopicStat> topTopics;
  final List<int> weeklyCheckinTrend;
  final String? message;

  const AnalyticsOverviewModel({
    required this.suppressed,
    required this.sampleSize,
    required this.minGroupSize,
    this.faculty = 'ALL',
    this.academicYear = 'ALL',
    this.period = 'ALL',
    this.totalScreenings = 0,
    this.highRiskCount = 0,
    this.connectedBookingsCount = 0,
    this.bookingConversionRate = 0.0,
    this.moodCheckinCount = 0,
    this.avgMoodLevel = 0.0,
    this.cbtCompletedCount = 0,
    this.topTopics = const [],
    this.weeklyCheckinTrend = const [],
    this.message,
  });

  factory AnalyticsOverviewModel.fromJson(Map<String, dynamic> json) {
    final metrics = json['metrics'] is Map
        ? Map<String, dynamic>.from(json['metrics'] as Map)
        : null;
    final rawTopics = metrics?['top_topics_aggregated'] as List<dynamic>?;
    final rawTrend = metrics?['weekly_checkin_trend'] as List<dynamic>?;
    return AnalyticsOverviewModel(
      suppressed: json['suppressed'] as bool? ?? true,
      sampleSize: (json['sample_size'] as num?)?.toInt() ?? 0,
      minGroupSize: (json['min_group_size'] as num?)?.toInt() ?? 10,
      faculty: json['faculty']?.toString() ?? 'ALL',
      academicYear: json['academic_year']?.toString() ?? 'ALL',
      period: json['period']?.toString() ?? 'ALL',
      totalScreenings: (metrics?['total_screenings'] as num?)?.toInt() ?? 0,
      highRiskCount: (metrics?['high_risk_count'] as num?)?.toInt() ?? 0,
      connectedBookingsCount:
          (metrics?['connected_bookings_count'] as num?)?.toInt() ?? 0,
      bookingConversionRate:
          (metrics?['booking_conversion_rate'] as num?)?.toDouble() ?? 0.0,
      moodCheckinCount:
          (metrics?['mood_checkin_count'] as num?)?.toInt() ?? 0,
      avgMoodLevel: (metrics?['avg_mood_level'] as num?)?.toDouble() ?? 0.0,
      cbtCompletedCount:
          (metrics?['cbt_completed_count'] as num?)?.toInt() ?? 0,
      topTopics: rawTopics != null
          ? rawTopics
              .whereType<Map>()
              .map((e) =>
                  AnalyticsTopicStat.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      weeklyCheckinTrend: rawTrend != null
          ? rawTrend.map((e) => (e as num).toInt()).toList()
          : const [],
      message: json['message']?.toString(),
    );
  }
}
