# Báo cáo Lỗi & Nhật ký Khắc phục (Bug Report) — MindCheck Campus 2.0

**Ngày lập báo cáo:** 2026-11-08  
**Chuẩn đối chiếu:** `AGENT_RULES.md` (Quy tắc bất biến R1–R5, Bảo mật RBAC, Consent, Privacy & k-Anonymity)

---

## Tổng hợp Thống kê Lỗi

| Mức độ nghiêm trọng (Severity) | Số lượng phát hiện | Đã khắc phục (Fixed & Verified) | Còn tồn đọng |
| :--- | :---: | :---: | :---: |
| **Critical (P0)** | 3 | 3 | 0 |
| **High (P1)** | 11 | 11 | 0 |
| **Medium (P2)** | 3 | 3 | 0 |
| **Tổng cộng** | **17** | **17** | **0** |

---

## Chi tiết từng Lỗi, Nguyên nhân gốc & Bản sửa đã áp dụng

### BUG-01 — Lộ thông tin liên hệ định danh (PII Leak) tại `GET /v1/counseling-requests`
- **Mức độ nghiêm trọng:** **Critical (P0)** — Vi phạm R4 (Ẩn danh & Bảo mật PII).
- **Bước tái hiện:** Gửi HTTP `GET /v1/counseling-requests` không truyền tham số hoặc truyền `contact_info` bất kỳ mà không có token xác thực.
- **Nguyên nhân gốc:** Trong `backend/app/main.py`, truy vấn SQL `SELECT * FROM counseling_requests ORDER BY created_at DESC LIMIT 50` chạy trực tiếp khi thiếu bộ lọc sở hữu, trả về toàn bộ `contact_info` (email/SĐT) và `student_note` của các sinh viên khác.
- **Bản sửa đã áp dụng:**
  - Bổ sung cột `requester_token_hash` (SHA-256) trên bảng `counseling_requests` bằng migration không phá hủy (`ALTER TABLE ... ADD COLUMN` có kiểm tra tồn tại).
  - Cấp `requester_token` dùng một lần khi tạo lịch hẹn (`POST /v1/counseling-requests`) và bắt buộc xác thực chủ sở hữu qua `Authorization: Bearer <student_token>` hoặc `X-Booking-Token` trên `GET /v1/counseling-requests` và `PATCH /v1/counseling-requests/{request_id}/cancel`.
  - Kiểm tra khớp `consent_id` khi phát lại `idempotency_key` để ngăn dò trùng khóa lấy dữ liệu người khác.
- **Trạng thái xác minh:** **VERIFIED PASS** (`test_07_counseling_booking_privacy_idempotency_cancel_and_rbac_t25`).

---

### BUG-02 — Thiếu xác thực Phiên Token thực & Hổng phân quyền RBAC 4 vai trò
- **Mức độ nghiêm trọng:** **Critical (P0)** — Vi phạm R5 (RBAC nghiêm ngặt: `T23`, `T25`, `T27`).
- **Bước tái hiện:**
  1. Gọi `GET /v1/admin/analytics-policy` không gửi header quản trị vẫn đọc được toàn bộ `audit_events`.
  2. Nhân sự (`ctsv`, `counselor`, `admin`) gọi vào `/v1/chats`, `/v1/memories`, `/v1/screening-sessions` không bị chặn ở tầng guard.
  3. Token trả về từ `/v1/auth/signup` và `/v1/auth/login` là chuỗi giả lập không lưu DB nên không đối chiếu được danh tính thực.
- **Nguyên nhân gốc:** Hệ thống ban đầu chưa có bảng `staff_accounts` / `auth_sessions` và chưa có hàm guard chặn nhân sự đọc vùng dữ liệu lâm sàng cá nhân (`Anon_Clinical`).
- **Bản sửa đã áp dụng:**
  - Bổ sung bảng `staff_accounts` (mật khẩu băm `PBKDF2-HMAC-SHA256`) và `auth_sessions` (lưu `token_hash` SHA-256 có thời hạn `expires_at`), cùng endpoint `POST /v1/auth/staff-login`.
  - Xây dựng bộ hàm bảo vệ tập trung trong `backend/app/main.py`: `guard_personal_clinical_access` (chặn tuyệt đối `ctsv`, `counselor`, `admin` truy cập dữ liệu cá nhân kèm ghi Audit Log `DENIED_STAFF_PRIVACY_BOUNDARY`), `require_counselor_actor` (chỉ xem ca của chính mình và trường Whitelist `F37`), `require_analytics_actor`, và `require_admin_actor` (bảo vệ cả `GET` lẫn `PUT /v1/admin/analytics-policy`).
- **Trạng thái xác minh:** **VERIFIED PASS** (`test_08_analytics_real_kanonymity_and_admin_rbac_t23_t24_t27`).

---

### BUG-03 — Lỗ hổng Truy cập chéo người dùng (IDOR) trên Chat, Trí nhớ AI, Mood & Sàng lọc
- **Mức độ nghiêm trọng:** **Critical (P0)** — Vi phạm R4 & cô lập dữ liệu người dùng.
- **Bước tái hiện:** Sinh viên B dùng `subject_id` của mình gọi `GET /v1/chats/{chat_id_A}/messages`, `PATCH /v1/memories/{mem_id_A}`, `DELETE /v1/mood-entries/{entry_id_A}`, hoặc `PUT /v1/screening-sessions/{sess_id_A}/answers` của Sinh viên A.
- **Nguyên nhân gốc:** Các truy vấn `SELECT/UPDATE/DELETE WHERE id = ?` chỉ lọc theo khóa chính tài nguyên mà chưa kiểm tra `row["subject_id"] == caller_subject_id`.
- **Bản sửa đã áp dụng:** Bổ sung `assert_resource_owner(conn, row_subject_id, caller_subject_id, ...)` trên toàn bộ các endpoint đọc/sửa/xóa phiên chat, tin nhắn, trí nhớ AI, bản ghi cảm xúc và phiên sàng lọc; trả mã `403 FORBIDDEN_RESOURCE_OWNER_MISMATCH` và ghi nhận sự kiện vào `audit_events`.
- **Trạng thái xác minh:** **VERIFIED PASS** (`test_02_student_signup_login_link_preferences_and_idor`, `test_04_memory_consent_crud_and_ownership_f10_f12`, `test_05_mood_activities_and_weekly_reflection_boundary_t10_t13`, `test_06_screening_consent_validation_abandon_item9_and_trend_f21_f22`).

---

### BUG-04 — Lỗ hổng đối chiếu mục đích Consent & thiếu Checkbox đồng ý lưu Trí nhớ thủ công
- **Mức độ nghiêm trọng:** **High (P1)** — Vi phạm R2 (Consent rõ ràng cho từng mục đích).
- **Bước tái hiện:**
  1. Tạo Consent với `purpose="privacy_policy"` rồi truyền `consent_id` đó sang `POST /v1/screening-sessions` hoặc `POST /v1/counseling-requests` vẫn được chấp nhận.
  2. Trên màn hình `S28` (`memory_settings_screen.dart`), thêm trí nhớ thủ công không có bước xác nhận đồng ý `ai_memory`.
- **Nguyên nhân gốc:** Các lệnh gọi `verify_consent` thiếu tham số `expected_purpose` và `expected_subject_id`; `MemoryApproveInput.decision` đặt mặc định `"accepted"`; UI thêm trí nhớ thủ công chưa gắn checkbox đồng ý riêng.
- **Bản sửa đã áp dụng:**
  - Bắt buộc truyền `expected_purpose` (`"screening"`, `"counseling_share"`, `"guest_session_link"`, `"ai_memory"`) và `expected_subject_id` vào mọi lệnh gọi `verify_consent`; phân biệt rõ lỗi `CONSENT_DECLINED` và `CONSENT_REVOKED`.
  - Bỏ giá trị mặc định của `MemoryApproveInput.decision`, bắt buộc `consent_accepted=True` hoặc `consent_id` hợp lệ khi gọi `POST /v1/memories`.
  - Bổ sung `CheckboxListTile` (`_consentManualMemory = false` mặc định) trên `memory_settings_screen.dart` và kiểm tra bắt buộc trong `MindCheckNotifier.addManualApprovedMemory`.
- **Trạng thái xác minh:** **VERIFIED PASS** (`test_04_memory_consent_crud_and_ownership_f10_f12`, `e2e_flows_and_rbac_test.dart`).

---

### BUG-05 — Nguy cơ lộ `GEMINI_API_KEY` trên URL Query String và Log Ngoại lệ
- **Mức độ nghiêm trọng:** **High (P1)** — Vi phạm quy tắc bảo mật khóa bí mật (`AGENT_RULES.md` §2 & §4).
- **Bước tái hiện:** Khi cấu hình `GEMINI_API_KEY` và xảy ra lỗi mạng tới `generativelanguage.googleapis.com`, ngoại lệ `httpx` chứa đầy đủ URL `?key=AIza...` bị in ra stdout.
- **Nguyên nhân gốc:** Cả `backend/app/main.py` và `apps/student_app/lib/shared/api_service.dart` nối khóa API trực tiếp vào query string `?key=` thay vì gửi qua HTTP Header.
- **Bản sửa đã áp dụng:** Chuyển hoàn toàn khóa API sang header chuẩn `x-goog-api-key` ở cả Backend lẫn Flutter Client, đồng thời lọc sạch thông báo lỗi chỉ ghi tên lớp ngoại lệ (`type(exc).__name__`), tuyệt đối không log khóa hay nội dung chat.
- **Trạng thái xác minh:** **VERIFIED PASS** (`test_03_chat_idempotency_safety_and_non_diagnostic_r1_r3`).

---

### BUG-06 — Nút phản hồi nhanh Khủng hoảng gửi tiếp tin nhắn Chat thay vì mở Hỗ trợ An toàn 2 lớp & thiếu số `115`/`111` ở kết quả PHQ-9 Câu 9
- **Mức độ nghiêm trọng:** **High (P1)** — Vi phạm R3 (An toàn 2 lớp).
- **Bước tái hiện:**
  1. Gửi tin nhắn có tín hiệu tự hại trên màn hình Chat -> Bấm nút quick-reply `"Mở Hỗ trợ an toàn & khẩn cấp"` -> Ứng dụng gửi chuỗi chữ đó vào khung chat thay vì mở màn hình `SafetySupportScreen` (`S21`).
  2. Trả lời PHQ-9 với Câu số 9 >= 1 -> Văn bản `interpretation` không hiển thị số đường dây nóng khẩn cấp `115` / `111`.
- **Nguyên nhân gốc:** `chat_companion_screen.dart` gọi trực tiếp `_send(qr)` cho mọi quick-reply; `state_provider.dart` và `backend/app/main.py` chưa đưa thông tin đường dây nóng `115` / `111` vào thông điệp cảnh báo ưu tiên khi `item9_risk == True`.
- **Bản sửa đã áp dụng:**
  - Bổ sung `_handleQuickReply` trong `chat_companion_screen.dart` để điều hướng trực tiếp tới `SafetySupportScreen` (`S21`) hoặc tab Đặt lịch Tư vấn (`S23`) mà không biến hành động khẩn cấp thành cuộc hội thoại chatbot.
  - Cập nhật `evaluate_screening_rule_based` (Backend) và `submitScreeningAnswers` (Flutter) hiển thị rõ đường dây nóng `115` / `111` (`S21`) và kết nối chuyên gia tư vấn trường (`S23`) ngay khi Câu 9 PHQ-9 >= 1 hoặc điểm nguy cơ cao.
  - Bổ sung hậu kiểm `_enforce_non_diagnostic_guardrail` / `enforceNonDiagnosticGuardrail` (`R1`) chặn tuyệt đối mọi câu trả lời chẩn đoán bệnh lý từ LLM.
- **Trạng thái xác minh:** **VERIFIED PASS** (`companion_responsive_test.dart`, `e2e_flows_and_rbac_test.dart`, `test_06_screening_consent_validation_abandon_item9_and_trend_f21_f22`).

---

### BUG-07 — Hardcode dữ liệu giả / Demo trong thống kê CTSV, Lịch hẹn, Xu hướng 4 tuần & Form Đặt lịch
- **Mức độ nghiêm trọng:** **High (P1)** — Vi phạm quy tắc cấm hardcode dữ liệu mẫu trong môi trường bàn giao (`AGENT_RULES.md` §2).
- **Bước tái hiện:**
  1. Khởi chạy mới ứng dụng thấy sẵn lịch hẹn `req_demo_001` và ô liên hệ điền sẵn `sv_cantho@student.ctuet.edu.vn`.
  2. Mở Dashboard CTSV thấy cố định `1284` lượt sàng lọc, `76` ca nguy cơ cao, `51` kết nối; gọi `GET /v1/analytics/overview` trả cố định `142` và `48` bất kể dữ liệu thật trong SQLite.
  3. Hoàn thành sàng lọc lần đầu tiên vẫn hiện 6 điểm xu hướng giả định và `demoFlag = true`.
- **Nguyên nhân gốc:** Dữ liệu phục vụ bản trình diễn ban đầu chưa được tách khỏi mã nghiệp vụ chính thức.
- **Bản sửa đã áp dụng:**
  - Đặt toàn bộ dữ liệu seed mẫu sau biến môi trường `MINDCHECK_SEED_DEMO` (mặc định `false` / `0` ở cả Backend và Flutter `--dart-define`).
  - Viết lại `GET /v1/analytics/overview` và `_buildCtsvDashboard` tính toán trực tiếp `sample_size`, `total_screenings`, `high_risk_count`, `connected_bookings_count`, và phân bổ chủ đề từ dữ liệu thực trong SQLite / State hiện hành, áp dụng nghiêm ngặt khóa `k-Anonymity` khi `n < min_group_size`.
  - Tính `four_week_trend` thực tế từ lịch sử các lần hoàn thành cùng thang đo của đúng `subject_id`; đặt `demoFlag = false` trong môi trường bàn giao; ẩn nút `'Điền nhanh mẫu thử nghiệm'` khi `kSeedDemoMode == false`; để trống mặc định ô liên hệ đặt lịch và kiểm tra định dạng Email/SĐT hợp lệ.
- **Trạng thái xác minh:** **VERIFIED PASS** (`widget_test.dart`, `test_08_analytics_real_kanonymity_and_admin_rbac_t23_t24_t27`).

---

### BUG-08 — Thiếu câu hỏi trên thang đo DASS-21 ở Frontend & thiếu kiểm tra miền giá trị đáp án Sàng lọc
- **Mức độ nghiêm trọng:** **High (P1)** — Sai lệch nghiệp vụ thang đo chuẩn hóa.
- **Bước tái hiện:** Mở bài sàng lọc `DASS-21` trên ứng dụng Flutter chỉ thấy 5 câu hỏi (`maxScore = 15`) thay vì 21 câu chuẩn (`maxScore = 63`); gửi mảng đáp án có giá trị âm hoặc `> 3` lên `PUT /v1/screening-sessions/{id}/answers` không bị chặn `422`.
- **Nguyên nhân gốc:** Danh sách câu hỏi `DASS-21` trong `state_provider.dart` bị rút gọn còn 5 mục; API cập nhật đáp án chưa kiểm tra miền giá trị `0..3` và độ dài mảng câu hỏi khi `completed=True`.
- **Bản sửa đã áp dụng:** Đồng bộ đầy đủ 21 câu hỏi chuẩn Lovibond & Lovibond (1995) của `DASS-21` giữa `state_provider.dart` và `backend/app/main.py`; kiểm tra nghiêm ngặt độ dài mảng đáp án và miền điểm `0..3` (trả `422 INVALID_SCREENING_ANSWERS` hoặc `INCOMPLETE_SCREENING_ANSWERS` khi sai phạm).
- **Trạng thái xác minh:** **VERIFIED PASS** (`companion_responsive_test.dart`, `test_06_screening_consent_validation_abandon_item9_and_trend_f21_f22`).

---

### BUG-09 — Đứt mạch đồng bộ End-to-End UI → State → API → SQLite ở các thao tác Xóa/Cập nhật & Thứ tự Onboarding
- **Mức độ nghiêm trọng:** **High (P1)** — Vi phạm yêu cầu truy vết đầy đủ từ UI đến DB (`AGENT_RULES.md` §3 Bước 4).
- **Bước tái hiện:**
  1. Ở bước cuối Onboarding (`S04`), `updateCompanionPreference` chạy trước `startAnonymousSession` nên gửi `X-Subject-Id: sub_default` thay vì `guestId` mới.
  2. Các thao tác xóa phiên chat, sửa/xóa trí nhớ AI, xóa bản ghi cảm xúc, thoát sàng lọc giữa chừng (`T16`), hủy lịch từ phía sinh viên (`S24`) và xóa toàn bộ dữ liệu cá nhân (`F06`) chưa gọi đầy đủ API tương ứng hoặc thiếu endpoint xóa tổng thể trên Backend.
- **Nguyên nhân gốc:** Một số phương thức trong `MindCheckNotifier` chỉ mới cập nhật `SharedPreferences` cục bộ; Backend thiếu `DELETE /v1/me/data`, `GET /v1/screening-sessions`, `GET /v1/knowledge-articles` và `PATCH /v1/counseling-requests/{id}/cancel`.
- **Bản sửa đã áp dụng:**
  - Bổ sung đầy đủ các endpoint còn thiếu trên `backend/app/main.py` và kết nối trọn vẹn qua `MindCheckApiService` + `MindCheckNotifier`.
  - Đảo thứ tự tại `onboarding_screen.dart` để tạo `guestId`/`subjectId` trước khi lưu cá nhân hóa AI.
  - Nâng cấp màn hình `S30` hỗ trợ đầy đủ mật khẩu, chọn Khoa/Năm học, Đăng ký liên kết, Đăng nhập đồng bộ, Đăng xuất và Xóa sạch dữ liệu cá nhân (`F06`).
- **Trạng thái xác minh:** **VERIFIED PASS** (`test_09_data_erasure_f06_t32`, `test_10_e2e_anonymous_to_linked_screening_booking_and_counselor_confirm`, `e2e_flows_and_rbac_test.dart`).

---

### BUG-10 — Lệch quy tắc Biên `T13` trên giao diện Tổng kết cảm xúc tuần
- **Mức độ nghiêm trọng:** **Medium (P2)** — Không nhất quán quy tắc nghiệp vụ `T13`.
- **Bước tái hiện:** Mới lưu 1 hoặc 2 bản ghi cảm xúc trên màn hình `DailyAndMoodHubScreen`, giao diện đã hiển thị thanh trung bình tuần tính trên thang `/4.0` trong khi Backend quy định tối thiểu 3 bản ghi trên thang `1..5`.
- **Nguyên nhân gốc:** Điều kiện kiểm tra trên UI chỉ xét `moodEntries.isEmpty` thay vì `< 3`, và thiếu lựa chọn mức `5` (`🌟 Rất tích cực`).
- **Bản sửa đã áp dụng:** Bổ sung đầy đủ 5 mức cảm xúc (`1..5`), hiển thị thông báo rõ ràng `Chưa đủ dữ liệu tổng kết tuần (hiện có X/3 lần check-in)` khi có `1` hoặc `2` bản ghi, và chỉ mở khóa thẻ Tổng kết tuần thang `/5.0` khi đạt từ `3` bản ghi trở lên.
- **Trạng thái xác minh:** **VERIFIED PASS** (`widget_test.dart`, `test_05_mood_activities_and_weekly_reflection_boundary_t10_t13`).

---

### BUG-11 — Lệch nhãn điều hướng trong `companion_responsive_test.dart`
- **Mức độ nghiêm trọng:** **Medium (P2)** — Lỗi kiểm thử tự động.
- **Bước tái hiện:** Chạy `flutter test test/companion_responsive_test.dart` báo không tìm thấy widget `'Hỗ trợ'` (dòng 137) và `'Mình đang áp lực thi cử'` (dòng 184).
- **Nguyên nhân gốc:** Thanh điều hướng chính trong `main.dart` đặt tên tab thứ 4 là `'Tư vấn'` và câu gợi ý mở đầu trong `state_provider.dart` là `'Mình đang lo thi cuối kỳ'`.
- **Bản sửa đã áp dụng:** Đồng bộ chính xác nhãn kiểm thử và bổ sung kiểm tra toàn bộ các `CheckboxListTile` đồng ý (`R2`) trên mọi kích thước màn hình (`360px` → `1366px`).
- **Trạng thái xác minh:** **VERIFIED PASS** (`companion_responsive_test.dart`).

---

### BUG-12 — Xung đột giá trị mặc định `Header(default="sub_default")` khi xác thực bằng `Bearer` Token
- **Mức độ nghiêm trọng:** **High (P1)** — Phát hiện trong quá trình chạy Integration Test Backend (`test_02`).
- **Bước tái hiện:** Sinh viên đăng nhập nhận `Bearer` token hợp lệ rồi gọi `PUT /v1/me/companion-preferences` hoặc `PUT /v1/me/notification-preferences` mà không gửi kèm header `X-Subject-Id` -> Server trả lỗi `403 FORBIDDEN_CROSS_USER_ACCESS`.
- **Nguyên nhân gốc:** Tham số `x_subject_id: str = Header(default="sub_default")` tự gán `"sub_default"`, làm hàm `guard_personal_clinical_access` tưởng nhầm client đang cố truy cập hồ sơ `"sub_default"` khác với `subject_id` trong `Bearer` token.
- **Bản sửa đã áp dụng:** Đổi mặc định header `x_subject_id` thành `""` trên các endpoint cá nhân hóa và cập nhật `guard_personal_clinical_access` ưu tiên lấy `subject_id` xác thực từ phiên `Bearer` khi client không chỉ định tường minh `subject_id` khác.
- **Trạng thái xác minh:** **VERIFIED PASS** (`test_02_student_signup_login_link_preferences_and_idor`).

---

### BUG-13 — Race condition truy cập `state` sau khi `MindCheckNotifier` đã `dispose()` trong `_persistState()`
- **Mức độ nghiêm trọng:** **High (P1)** — Phát hiện trong quá trình chạy bộ kiểm thử đơn vị Flutter (`state_provider.dart`).
- **Bước tái hiện:** Gọi liên tiếp các thao tác bất đồng bộ cập nhật trạng thái (`sendChatMessage`, `recordScreeningConsent`, `submitScreeningAnswers`, `createCounselingBooking`) rồi đóng `ProviderContainer` ngay sau đó -> Ném ngoại lệ `Bad state: Tried to use MindCheckNotifier after dispose was called` ở các câu lệnh `await prefs.set...` kế tiếp.
- **Nguyên nhân gốc:** Hàm `_persistState()` trong `state_provider.dart` chỉ kiểm tra `if (!mounted) return;` một lần duy nhất sau `await SharedPreferences.getInstance()`, nhưng lại tiếp tục đọc trực tiếp thuộc tính `this.state.*` qua 15 điểm dừng `await` nối tiếp khi `StateNotifier` có thể đã bị hủy.
- **Bản sửa đã áp dụng:** Kiểm tra `if (!mounted) return;` và chụp ảnh bất biến `final snap = state;` ngay đầu hàm `_persistState()` trước lệnh `await` đầu tiên; toàn bộ quá trình tuần tự hóa dữ liệu xuống `SharedPreferences` đọc hoàn toàn từ bản chụp `snap`.
- **Trạng thái xác minh:** **VERIFIED PASS** (`widget_test.dart`, `companion_responsive_test.dart`, `e2e_flows_and_rbac_test.dart`).

---

### BUG-14 — Tràn bố cục ngang (`RenderFlex overflow`) ở Thanh bên Desktop (`284px`) và Thanh công cụ Màn hình siêu hẹp (`360px`)
- **Mức độ nghiêm trọng:** **Medium (P2)** — Phát hiện bằng kiểm thử Widget đa kích thước màn hình (`360px` → `1366px`).
- **Bước tái hiện:**
  1. Mở màn hình Chat ở chế độ Desktop có Side Panel rộng `320px` (vùng nội dung `284px`) với phông chữ rộng -> Dòng tiêu đề `'Trí nhớ AI đang bật'` đặt cạnh nút `'Quản lý'` bị tràn phải.
  2. Thu hẹp khung nhìn cửa sổ xuống `360px` (chế độ chia đôi màn hình hoặc điện thoại nhỏ): `OnboardingFlowScreen` và `SchoolPortalShell` đọc `MediaQuery.of(context).size.width` của cửa sổ gốc thay vì `LayoutBuilder` `constraints.maxWidth`, khiến thanh `AppBar.actions` giữ nhãn dài và tràn `71px`.
- **Nguyên nhân gốc:** Thiếu `Expanded` bao bọc `Text` trong `Row` của `_buildDesktopCompanionSidePanel` (`chat_companion_screen.dart`), và dùng `MediaQuery` thay vì `LayoutBuilder` cho điều kiện thu gọn `AppBar` trên `onboarding_screen.dart` và `school_portal_screen.dart`.
- **Bản sửa đã áp dụng:** Bọc `Expanded` + `TextOverflow.ellipsis` cho tiêu đề trong `_buildDesktopCompanionSidePanel`, bọc `Flexible` cho nhãn nút dài trên Onboarding, và chuyển toàn bộ tính toán breakpoint trên `OnboardingFlowScreen` và `SchoolPortalShell` sang `LayoutBuilder` (`constraints.maxWidth`).
- **Trạng thái xác minh:** **VERIFIED PASS** (`companion_responsive_test.dart`, `widget_test.dart`, `e2e_flows_and_rbac_test.dart`).

---

### BUG-15 — Hardcode model `gemini-2.5-flash` trả về lỗi `404` trên các dự án Google AI Studio mới
- **Mức độ nghiêm trọng:** **High (P1)** — Phát hiện khi kiểm thử tích hợp trực tuyến với khóa Google AI Studio thực tế.
- **Bước tái hiện:** Gửi yêu cầu `POST https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent` bằng khóa Google AI Studio mới -> Máy chủ Google trả về HTTP `404` (`models/gemini-2.5-flash is no longer available to new users`).
- **Nguyên nhân gốc:** Endpoint model trong `backend/app/main.py` và `apps/student_app/lib/shared/api_service.dart` gắn cứng `gemini-2.5-flash` mà chưa hỗ trợ cấu hình model hiện hành hoặc cơ chế tự động chuyển mạch (fallback) sang dòng Gemini 3 Flash mới.
- **Bản sửa đã áp dụng:**
  - Cập nhật model mặc định sang `gemini-3-flash-preview` và bổ sung chuỗi chuyển mạch tự động `GEMINI_FALLBACK_MODELS` (`gemini-3.1-flash-lite`, `gemini-2.5-flash`) khi gặp lỗi `404` / `429` / `5xx` trên cả Backend (`get_gemini_model_candidates()`) và Flutter (`defaultGeminiModels`).
  - Bổ sung thông tin `gemini_model` vào phản hồi của `GET /v1/health`.
- **Trạng thái xác minh:** **VERIFIED PASS** (`test_11_dotenv_loader_aq_key_and_gemini_model_fallback` & Live E2E Uvicorn + Google Gemini Cloud `HTTP 200`).

---

### BUG-16 — Bộ lọc `startsWith('AIza')` trên Flutter từ chối khóa Google AI Studio định dạng mới (`AQ....`)
- **Mức độ nghiêm trọng:** **High (P1)** — Chặn kết nối Gemini trực tiếp với định dạng khóa mới của Google AI Studio.
- **Bước tái hiện:** Người dùng sử dụng khóa Google AI Studio thế hệ mới bắt đầu bằng tiền tố `AQ.` -> Điều kiện `if (trimmedKey.startsWith('AIza'))` tại `apps/student_app/lib/shared/api_service.dart` bỏ qua lời gọi Gemini API.
- **Nguyên nhân gốc:** Giả định cũ rằng mọi khóa Gemini API đều có tiền tố `AIza`.
- **Bản sửa đã áp dụng:** Bổ sung hàm `MindCheckApiService.isPlausibleGeminiApiKey(String raw)` chấp nhận cả định dạng `AQ....` và `AIza...` (không chứa khoảng trắng), đồng thời cập nhật nhãn hướng dẫn trên `apps/student_app/lib/main.dart`.
- **Trạng thái xác minh:** **VERIFIED PASS** (`e2e_flows_and_rbac_test.dart`).

---

### BUG-17 — Backend chưa tự động nạp tệp `.env` khi khởi chạy trực tiếp & Timeout/CORS hẹp cho phiên Chat Live Gemini
- **Mức độ nghiêm trọng:** **High (P1)** — Cản trở vận hành thực tế khi chạy `uvicorn backend.app.main:app` kèm tệp `.env`.
- **Bước tái hiện:**
  1. Khai báo `GEMINI_API_KEY` trong tệp `.env` ở thư mục gốc rồi chạy `uvicorn backend.app.main:app` mà không `export` thủ công trên shell -> `GET /v1/health` báo `gemini_configured_on_server: false`.
  2. Chạy `flutter run -d chrome` (cổng localhost ngẫu nhiên) hoặc khi Gemini suy luận sâu mất `5s–8s` -> Dễ chạm ngưỡng CORS hoặc `receiveTimeout = 7000ms` cũ của Dio.
- **Nguyên nhân gốc:** `backend/app/main.py` chưa có bộ nạp tệp `.env` độc lập trước khi khởi tạo FastAPI/CORS; `receiveTimeout` mặc định cho chat trong `api_service.dart` hơi ngắn so với thời gian sinh JSON cấu trúc tiếng Việt của LLM.
- **Bản sửa đã áp dụng:**
  - Bổ sung `_parse_dotenv_file` và `_load_dotenv_files` (không phụ thuộc gói ngoài, không ghi đè biến đã đặt sẵn, có cờ cô lập `MINDCHECK_IGNORE_DOTENV=1` cho kiểm thử đơn vị) cùng tệp `.gitignore` và `.env.example` an toàn.
  - Hỗ trợ `allow_origin_regex` cho các cổng động `localhost`/`127.0.0.1` khi phát triển nội bộ (vẫn khóa chặt theo tên miền HTTPS cụ thể trên Production).
  - Nâng `receiveTimeout` của endpoint gửi tin nhắn chat lên `20000ms` (Client) và `15.0s` (Backend upstream).
- **Trạng thái xác minh:** **VERIFIED PASS** (`test_11_dotenv_loader_aq_key_and_gemini_model_fallback` & Live E2E Uvicorn + `.env`).
