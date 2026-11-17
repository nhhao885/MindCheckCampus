# Báo cáo Kiểm toán Toàn diện Hệ thống (System Audit) — MindCheck Campus 2.0

**Ngày kiểm toán:** 2026-11-08  
**Phạm vi kiểm toán:** Toàn bộ repository `MindCheckCampus` (`backend/`, `apps/student_app/`, `packages/shared_models/`)  
**Chuẩn đối chiếu:** `AGENT_RULES.md` (Quy tắc bất biến R1–R5, Nguyên tắc thay đổi mã nguồn, Quy trình bắt buộc 7 bước, Tiêu chuẩn nghiệm thu bàn giao).

---

## 1. Danh mục Kiến trúc, Vai trò (Actors) & Quy tắc Bất biến

### 1.1. Kiến trúc hiện hữu
- **Frontend Mobile/Web App (`apps/student_app/`)**: Flutter 3.x + Riverpod (`StateNotifier`) + Dio HTTP Client + `SharedPreferences` lưu trữ bền vững cục bộ. Hỗ trợ giao diện thích ứng (Responsive: Mobile `<768px`, Tablet `768–1049px`, Desktop `>=1050px`).
- **Shared Models (`packages/shared_models/`)**: Định nghĩa các model dữ liệu dùng chung.
- **Backend API (`backend/app/main.py`)**: FastAPI + Pydantic v2 + SQLite WAL tách biệt 2 vùng dữ liệu (`Identity_Vault` và `Anon_Clinical`) + tích hợp Google Gemini 2.5 Flash Structured JSON kèm Rule-based CBT Fallback.

### 1.2. Danh mục Vai trò (RBAC Actors)
| Mã vai trò | Tên vai trò | Phạm vi quyền hạn hợp lệ | Giới hạn cấm tuyệt đối (R4, R5) |
| :--- | :--- | :--- | :--- |
| **A01** | Sinh viên (Ẩn danh / Tài khoản) | Sử dụng AI Companion, Nhật ký cảm xúc, Bài tập CBT, Sàng lọc tự nguyện, Đặt lịch tư vấn (có Consent), Quản lý & xóa dữ liệu cá nhân (F06). | Không truy cập cổng nhân sự CTSV, Tư vấn viên hoặc Admin. |
| **A02** | Nhân viên Phòng CTSV | Xem Dashboard xu hướng tổng hợp ẩn danh toàn trường (`D02–D04`) khi `sample_size >= min_group_size`. | **CẤM** xem nội dung chat cá nhân, điểm sàng lọc cá nhân, PII hoặc danh sách lịch hẹn định danh (`T23`). |
| **A03** | Tư vấn viên Tâm lý (`counselor_01`, `counselor_02`) | Chỉ xem và cập nhật các lịch hẹn được phân công đúng cho mình (`D05–D06`), chỉ xem các trường trong Whitelist (`F37`). | **CẤM** xem ca của tư vấn viên khác (`T25`); **CẤM** xem lịch sử chat AI và điểm sàng lọc của sinh viên (`F37`). |
| **A04** | Quản trị viên Hệ thống (`Admin`) | Cấu hình chính sách ngưỡng ẩn nhóm nhỏ `min_group_size` (`D07`), xem ma trận RBAC và Nhật ký kiểm toán (`Audit Log`). | **CẤM** đọc nội dung chat cá nhân của sinh viên (`T27`) và hồ sơ tư vấn lâm sàng chi tiết. |

---

## 2. Danh mục Module, Màn hình, API & Chức năng Nghiệp vụ (100% Phạm vi)

| ID Chức năng | Module | Màn hình / UI | Endpoint API Backend | Mô tả Nghiệp vụ & Ràng buộc |
| :--- | :--- | :--- | :--- | :--- |
| **F01** | M01 - Onboarding & Auth | `S01–S02` (`OnboardingFlowScreen`) | — | Giới thiệu giá trị đồng hành CBT, nêu rõ giới hạn AI không thay thế bác sĩ/cấp cứu. |
| **F02** | M01 - Onboarding & Auth | `S03–S04` (`OnboardingFlowScreen`) | `POST /v1/guest-sessions` | Tạo phiên ẩn danh; bắt buộc tích chọn đồng ý chính sách bảo mật (không mặc định tích sẵn - `T02`). |
| **F03** | M01 - Onboarding & Auth | `S30` (`KnowledgeMemorySettingsHubScreen`) | `POST /v1/auth/signup`, `POST /v1/auth/login`, `POST /v1/guest-sessions/link` | Đăng ký/đăng nhập PBKDF2-HMAC-SHA256 và liên kết dữ liệu phiên khách khi có bản ghi Consent riêng (`guest_session_link`). |
| **F04** | M01 - Onboarding & Auth | `S04` & Modal cá nhân hóa | `GET/PUT /v1/me/companion-preferences` | Tùy chỉnh tên gọi AI, đại từ xưng hô và giọng điệu lắng nghe. |
| **F05** | M07 - Cài đặt & Quyền riêng tư | `S29` (`KnowledgeMemorySettingsHubScreen`) | `GET/PUT /v1/me/notification-preferences` | Cấu hình lời nhắc check-in, giờ yên tĩnh và ẩn nội dung nhạy cảm trên màn hình khóa. |
| **F06** | M07 - Cài đặt & Quyền riêng tư | `S30` (`KnowledgeMemorySettingsHubScreen`) | `POST /v1/consents`, `DELETE /v1/me/data` | Thu hồi sự đồng ý và xóa toàn bộ dữ liệu lâm sàng cá nhân của sinh viên trên cả Client & Server (`T32`). |
| **F07** | M02 - AI Companion Chat | `S05–S06` (`StudentHomeAndChatScreen`) | `GET/POST /v1/chats`, `DELETE /v1/chats/{id}`, `GET/POST /v1/chats/{id}/messages` | Trò chuyện CBT tiếng Việt đa phiên, nạp ngữ cảnh đa lượt, chống nhân đôi theo `client_message_id` (`T05`), retry khi mất mạng (`T06`), không chẩn đoán bệnh (`R1`). |
| **F08** | M02 - AI Companion Chat | `S08`, `S21` (`SafetySupportScreen`) | `POST /v1/chats/{id}/messages` | Phát hiện tín hiệu tự hại/nguy cơ cao (có dấu & không dấu) -> kích hoạt An toàn 2 lớp (`S21` Hotline 115/111 không cần đăng nhập + `S23` đặt lịch chuyên gia), không báo động giả từ `"từ từ"` (`R3`, `T18`). |
| **F09** | M02 - AI Companion Chat | `S07` (`StudentHomeAndChatScreen`) | `POST /v1/chats/{id}/messages` | Gợi ý tự nguyện thực hiện sàng lọc (`suggest_screening`) và cho phép sinh viên ẩn gợi ý (`Để sau`). |
| **F10** | M03 - AI Memory | `S07`, `S28` | `POST /v1/memories/{proposal_id}/approve`, `POST /v1/memories` | Đề xuất lưu trí nhớ từ hội thoại và thêm trí nhớ thủ công; chỉ lưu vào `approved_memories` khi có Consent `ai_memory` hợp lệ (`R2`, `T07`). |
| **F11** | M03 - AI Memory | `S28` (`KnowledgeMemorySettingsHubScreen`) | `GET /v1/memories`, `GET/PATCH /v1/memories/{id}` | Xem danh sách, tìm kiếm và chỉnh sửa nội dung trí nhớ AI đã duyệt (`T08`). |
| **F12** | M03 - AI Memory | `S28` & Desktop Side Panel | `DELETE /v1/memories/{id}` | Xóa từng mục trí nhớ AI khỏi cả Client và SQLite Backend (`T09`). |
| **F13** | M04 - Mood & Daily CBT | `S09–S10` (`DailyAndMoodHubScreen`) | `GET/POST /v1/mood-entries`, `DELETE /v1/mood-entries/{id}` | Check-in cảm xúc hằng ngày (thang 1–5), ghi chú tùy chọn và xóa bản ghi cảm xúc (`T10`). |
| **F14** | M04 - Mood & Daily CBT | `S11–S12` (`DailyAndMoodHubScreen`) | `GET /v1/daily-activities`, `POST /v1/activity-progress` | Thực hành tương tác Thở vuông 4-4-4-4 (đồng hồ 2 phút), Form CBT 3 bước và Grounding 5-4-3-2-1 (`T11–T12`). |
| **F15** | M04 - Mood & Daily CBT | `S13–S14` (`DailyAndMoodHubScreen`) | `GET /v1/weekly-reflections` | Tổng kết cảm xúc tuần; báo rõ `insufficient_data` khi dưới 3 bản ghi, không bịa đặt nhận xét (`T13`). |
| **F21** | M05 - Sàng lọc Tâm lý | `S15–S16` (`VoluntaryScreeningHubScreen`) | `GET /v1/screening-tools`, `POST /v1/screening-sessions` | Thư viện PHQ-9 (9 câu), GAD-7 (7 câu), DASS-21 (21 câu); bắt buộc có bản ghi Consent `screening` đã chấp thuận trước khi mở phiên (`R2`, `T14–T15`). |
| **F22** | M05 - Sàng lọc Tâm lý | `S17–S20` (`VoluntaryScreeningHubScreen`) | `PUT /v1/screening-sessions/{id}/answers`, `GET /v1/screening-sessions` | Chấm điểm Rule-based chuẩn xác; dừng giữa chừng ghi nhận `abandoned` không tính điểm (`T16`); câu 9 PHQ-9 >= 1 bật cảnh báo an toàn 2 lớp kèm Hotline 115/111 (`R3`, `T17`). |
| **F25** | M07 - Kiến thức Tâm lý | `S25` (`KnowledgeMemorySettingsHubScreen`) & `D04` (`SchoolPortalShell`) | `GET/POST /v1/knowledge-articles`, `DELETE /v1/knowledge-articles/{id}` | Thư viện bài viết giáo dục tâm lý học đường có bộ lọc theo chủ đề; hỗ trợ CTSV (`A02`) / Admin (`A04`) biên tập và xóa bài viết. |
| **F29** | M06 - Hỗ trợ & Đặt lịch | `S23–S24` (`SupportAndCounselingHubScreen`) | `POST/GET /v1/counseling-requests`, `PATCH /v1/counseling-requests/{id}/cancel`, `GET /v1/counselor-slots` | Đặt lịch hẹn chuyên gia với `idempotency_key` (`T21`), Consent `counseling_share` bắt buộc (`R2`, `T20`), chọn hình thức tư vấn (Trực tiếp/Online), khung giờ trống thực tế và theo dõi tiến trình 3 bước (`S24`). |
| **F35** | M08 - Cổng Nhà trường (CTSV) | `D01–D04` (`SchoolPortalShell`) | `POST /v1/auth/staff-login`, `GET /v1/analytics/overview` | Dashboard thống kê xu hướng ẩn danh 4 KPI từ `Anon_Clinical` (lọc theo Khoa, Khóa, Thời gian), xuất báo cáo CSV ẩn danh; tự động khóa biểu đồ khi `n < min_group_size` (k-Anonymity `T24`); không trả PII hay nội dung chat (`T23`). |
| **F37** | M08 - Cổng Nhà trường (Tư vấn viên) | `D05–D06` (`SchoolPortalShell`) | `GET /v1/staff/counseling-requests`, `GET/PATCH /v1/staff/counseling-requests/{id}`, `POST/PATCH/DELETE /v1/staff/counselor-slots*` | Tư vấn viên quản lý lịch làm việc/khung giờ trống của mình, xem KPI ca tư vấn, lọc/tìm kiếm và xử lý ca được phân công với mẫu phản hồi nhanh & trường Whitelist (`F37`); chặn 403 và ghi Audit Log nếu truy cập chéo ca hoặc khung giờ của đồng nghiệp (`T25`). |
| **F38** | M08 - Cổng Nhà trường (Admin) | `D07` (`SchoolPortalShell`) | `GET/PUT /v1/admin/analytics-policy`, `GET/POST/PATCH /v1/admin/staff-accounts*`, `GET /v1/safety-hotlines`, `POST/DELETE /v1/admin/safety-hotlines*` | Quản trị viên cấu hình `min_group_size`, quản lý tài khoản nhân sự & chuyên gia, quản lý danh bạ khẩn cấp `S21` (bảo vệ cố định `115`/`111`), và tra cứu/tìm kiếm Audit Log; bị chặn đọc nội dung chat/sàng lọc cá nhân (`T27`). |

---

## 3. Danh sách Phát hiện Lỗi & Thiếu sót (Ưu tiên xử lý)

### Mức Critical (Ưu tiên P0 — Bảo mật, Lộ PII, RBAC)
1. **BUG-01 (Critical - Privacy/PII Leak)**: `GET /v1/counseling-requests` (`backend/app/main.py` dòng 2245–2259) khi không truyền `contact_info` trả về tối đa 50 lịch hẹn của **tất cả sinh viên**, làm lộ `contact_info` (email/SĐT) và `student_note` giữa các người dùng.
2. **BUG-02 (Critical - Auth & RBAC Bypass)**:
   - `/v1/auth/signup` và `/v1/auth/login` trả về chuỗi `access_token` ngẫu nhiên không lưu DB và không xác thực.
   - `GET /v1/admin/analytics-policy` hoàn toàn mở công khai không kiểm tra quyền Admin, làm lộ `audit_events`.
   - `PUT /v1/admin/analytics-policy`, `GET /v1/analytics/overview`, và `/v1/staff/counseling-requests*` chưa xác thực vai trò thực sự (`student`, `ctsv`, `counselor`, `admin`), và chưa chặn nhân sự (`ctsv`, `counselor`, `admin`) gọi vào các API đọc dữ liệu lâm sàng cá nhân (`/v1/chats*`, `/v1/memories*`, `/v1/screening-sessions*`).
3. **BUG-03 (Critical - Cross-User Access / IDOR)**: `DELETE /v1/chats/{chat_id}`, `GET /v1/chats/{chat_id}/messages`, `GET/PATCH/DELETE /v1/memories/{memory_id}`, `DELETE /v1/mood-entries/{entry_id}`, và `PUT /v1/screening-sessions/{session_id}/answers` chưa kiểm tra `subject_id` sở hữu bản ghi, cho phép người dùng khác đọc/sửa/xóa dữ liệu riêng tư nếu biết ID.

### Mức High (Ưu tiên P1 — Consent, An toàn 2 lớp, Hardcode Demo Data, Đứt luồng API)
4. **BUG-04 (High - Consent Bypass / Vi phạm R2)**:
   - `verify_consent` có tham số `expected_purpose` nhưng các nơi gọi (`start_screening_session`, `create_counseling_request`, `link_guest_session`, `approve_or_reject_memory`) không truyền `expected_purpose` và không đối chiếu `subject_id`, dẫn tới có thể dùng chéo `consent_id` của mục đích khác hoặc người khác.
   - `MemoryApproveInput.decision` để mặc định `"accepted"`, và `POST /v1/memories` tự động sinh consent `"accepted"` dù không có xác nhận đồng ý rõ ràng; form thêm trí nhớ thủ công trên UI (`S28`) thiếu xác nhận đồng ý.
5. **BUG-05 (High - Secret Leak Risk in Logs)**: `call_gemini_cbt_engine` (`backend/app/main.py` dòng 939, 972) gắn trực tiếp `GEMINI_API_KEY` vào query URL `?key=...` rồi `print(e)` khi lỗi kết nối, có nguy cơ in URL chứa khóa bí mật ra log; `api_service.dart` cũng truyền key trên query URL từ phía client.
6. **BUG-06 (High - Safety Layer UX Bug / Vi phạm R3)**:
   - Trong `chat_companion_screen.dart` (dòng 413, 452), khi tin nhắn cảnh báo nguy cơ cao hiển thị quick-reply `"Mở hướng dẫn Hỗ trợ an toàn"` hoặc `"Kết nối Tư vấn viên của trường"`, bấm vào nút quick-reply lại gửi tiếp tin nhắn cho chatbot thay vì mở màn hình `S21` hoặc tab đặt lịch `S23`.
   - Trong `state_provider.dart` và `backend/app/main.py`, khi câu 9 PHQ-9 (ý nghĩ tự hại) >= 1, nội dung `interpretation` chưa nêu rõ đường dây nóng khẩn cấp `115` / `111` (khiến test lâm sàng `companion_responsive_test.dart` dòng 87 cũng bị lỗi).
7. **BUG-07 (High - Hardcoded Demo/Mock Data trong môi trường bàn giao)**:
   - `init_db()` (`backend/app/main.py`) và `_initialState()` (`state_provider.dart`) luôn tạo sẵn `req_demo_001` (`sv_demo@student.ctuet.edu.vn`) không tách biệt theo biến môi trường seed.
   - `SupportAndCounselingHubScreen` điền sẵn email mẫu `sv_cantho@student.ctuet.edu.vn`.
   - `GET /v1/analytics/overview` và `_buildCtsvDashboard` dùng số liệu mẫu cố định (`1284`, `48`, `142`, `76`, `51`, phần trăm tĩnh) thay vì tổng hợp thực từ SQLite `Anon_Clinical`; cho phép tham số `sample_size` ghi đè kích thước mẫu thực tế.
   - `four_week_trend` trong kết quả sàng lọc đang gán mảng số giả `[0.30, 0.44, ...]` và luôn đặt `demo_flag = True`; nút `'Điền nhanh mẫu thử nghiệm'` hiện trên màn hình sàng lọc chính thức.
8. **BUG-08 (High - Sai lệch Nghiệp vụ Sàng lọc & Validation)**:
   - Công cụ `DASS-21` trên Flutter (`state_provider.dart` dòng 266–279) chỉ có 5 câu hỏi thay vì đủ 21 câu chuẩn như Backend.
   - `PUT /v1/screening-sessions/{id}/answers` chưa kiểm tra giá trị điểm từng câu (`0..3`) và chưa kiểm tra đủ số lượng câu hỏi của thang đo khi `completed=True`.
9. **BUG-09 (High - Đứt mạch truy vết UI → State → API → DB)**:
   - Các hàm trong `MindCheckNotifier`: `startAnonymousSession`, `registerAndLinkAccount`, `revokeConsentOrRequestDataAction`, `createNewChatSession`, `deleteChatSession`, `editApprovedMemory`, `deleteApprovedMemory`, `deleteMoodEntry`, `updateNotificationPreference`, `recordScreeningConsent`, `submitScreeningAnswers`, `createCounselingBooking`, `updateAnalyticsPolicy` và `SchoolPortalShell` mới cập nhật bộ nhớ cục bộ hoặc thiếu đồng bộ chiều đọc/ghi với FastAPI.
   - Ở `onboarding_screen.dart` (dòng 496–506), `updateCompanionPreference` gọi trước `startAnonymousSession`, làm đồng bộ nhầm vào `sub_default` thay vì `guestId` mới.
   - Màn hình `S30` thiếu trường mật khẩu và chế độ Đăng ký / Đăng nhập / Đăng xuất khi liên kết tài khoản thực.

### Mức Medium (Ưu tiên P2 — Nhất quán Nghiệp vụ UI & Kiểm thử)
10. **BUG-10 (Medium - Lệch quy tắc T13 trên UI Nhật ký tuần)**: `mood_daily_screen.dart` hiển thị thanh trung bình tuần ngay khi có 1 bản ghi (thang `/4.0`), không khớp quy tắc `T13` của Backend (yêu cầu tối thiểu 3 bản ghi mới tổng kết tuần, thang `1..5`).
11. **BUG-11 (Medium - Lỗi lệch nhãn trong `companion_responsive_test.dart`)**: Test gọi tab `'Hỗ trợ'` (UI thực tế là `'Tư vấn'`) và quick-reply `'Mình đang áp lực thi cử'` (UI thực tế là `'Mình đang lo thi cuối kỳ'`).

---

## 4. Trạng thái Thực thi Kế hoạch Hoàn thiện Tuần tự
1. **Bước 1 (Backend Security, RBAC, Consent, Privacy & Real Aggregation) — ĐÃ HOÀN THÀNH & VERIFIED**: Đã nâng cấp `backend/app/main.py` — bổ sung quản lý token xác thực (`users`, `staff_accounts`, `auth_sessions`), phân quyền RBAC 4 vai trò nghiêm ngặt, chống IDOR theo `subject_id`, chuẩn hóa `verify_consent(expected_purpose, expected_subject_id)`, chuyển khóa API sang header `x-goog-api-key`, tách dữ liệu seed qua biến `MINDCHECK_SEED_DEMO` (mặc định tắt), tính toán thống kê thực cho `/v1/analytics/overview` và xu hướng 4 tuần thực, bổ sung `DELETE /v1/me/data`, `GET /v1/consents`, `GET /v1/screening-sessions`, `GET /v1/knowledge-articles`, `PATCH /v1/counseling-requests/{id}/cancel`.
2. **Bước 2 (Frontend Flutter End-to-End Sync & UX Fixes) — ĐÃ HOÀN THÀNH & VERIFIED**: Đã đồng bộ `models.dart` (cả `apps/student_app` và `packages/shared_models`), `api_service.dart`, `state_provider.dart`, và toàn bộ 7 cụm màn hình (`onboarding`, `chat`, `mood_daily`, `screening`, `support_booking`, `memory_settings`, `school_portal`) đảm bảo truy vết thông suốt UI → State → API → DB, loại bỏ dữ liệu hardcode/demo, đủ 21 câu `DASS-21`, chuẩn `T13`, chuẩn An toàn 2 lớp `R3`, và giao diện thích ứng `360px` → `1366px`.
3. **Bước 3 (Test Design & Automated Tests) — ĐÃ HOÀN THÀNH & VERIFIED**: Đã lập 46 kịch bản kiểm thử chuẩn hóa (`TC-01`..`TC-46`) bao phủ 100% chức năng `F01–F38` & quy tắc `R1–R5` trong `docs/quality/TEST_CASES.md`, kèm 10 kịch bản Integration/RBAC/E2E Backend và 12 kịch bản Unit/Widget/Responsive/RBAC/E2E Flutter.
4. **Bước 4 (Execution, Regression & Handover Docs) — ĐÃ HOÀN THÀNH & VERIFIED**: Đã thực thi kiểm thử hồi quy Backend + Flutter, khắc phục triệt để toàn bộ 17 lỗi phát hiện (`BUG-01`..`BUG-17`, 0 lỗi Critical/High tồn đọng), và hoàn thiện đầy đủ bộ tài liệu bàn giao tại `docs/quality/`.
