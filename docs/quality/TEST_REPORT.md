# Báo cáo Kết quả Thực thi Kiểm thử (Test Execution Report) — MindCheck Campus 2.0

**Ngày thực thi kiểm thử:** 2026-11-13 (Cập nhật chu kỳ kiểm thử hồi quy toàn diện)  
**Chuẩn nghiệm thu đối chiếu:** `AGENT_RULES.md` (§1 Quy tắc bất biến `R1–R5`, §3 Quy trình 7 bước, §4 Tiêu chuẩn nghiệm thu).

---

## 1. Môi trường Kiểm thử Thực tế

| Hạng mục | Thông tin phiên bản & Cấu hình thực chạy |
| :--- | :--- |
| **Hệ điều hành** | Windows (x64, PowerShell) |
| **Python & FastAPI** | Python `3.14.4` (`C:\Users\MSI\AppData\Local\Programs\Python\Python314\python.exe`), FastAPI + Uvicorn + HTTPX `ASGITransport` |
| **Cơ sở dữ liệu kiểm thử** | SQLite chế độ `WAL`, cô lập trên tệp tạm riêng biệt theo từng test case (bảo toàn nguyên vẹn 100% `backend/app/mindcheck.db`) |
| **Flutter & Dart SDK** | `C:\src\flutter\bin\flutter.bat` (Dart `3.12.0`, Material 3, Riverpod `StateNotifier`) |
| **Chế độ dữ liệu Seed** | `MINDCHECK_SEED_DEMO=0` (`false` — môi trường bàn giao sạch, không dữ liệu mẫu giả lập) |

---

## 2. Tổng hợp Kết quả Thực thi (Executive Summary)

| Hạng mục Kiểm thử | Lệnh Thực thi Chính xác | Tổng số | PASS | FAIL | BLOCKED | Kết quả |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: |
| **1. Backend API, RBAC, Consent, Privacy, `.env` & E2E** | `python -m unittest backend.tests.test_api_and_ai -v` | 12 suites | **12** | 0 | 0 | **PASS (`exit 0`)** |
| **2. Backend Live Routes & OpenAPI Smoke** | `python -c "from backend.app.main import app; ..."` | 60 routes | **60** | 0 | 0 | **PASS (`exit 0`)** |
| **3. Phân tích Tĩnh Dart/Flutter (`analyze`)** | `flutter analyze apps/student_app packages/shared_models` | 2 packages | **2** | 0 | 0 | **PASS (`exit 0`)** |
| **4. Flutter Unit, Widget, Responsive & RBAC E2E** | `flutter test` (3 files: `companion_responsive`, `widget`, `e2e_flows_and_rbac`) | 21 test cases | **21** | 0 | 0 | **PASS (`exit 0`)** |
| **5. Flutter Production Web Release Build** | `flutter build web --no-pub` (trong `apps/student_app`) | 1 build | **1** | 0 | 0 | **PASS (`exit 0`)** |
| **6. Ma trận Nghiệp vụ `TC-01` → `TC-47`** | Ánh xạ trực tiếp vào 33 automated test cases (`12` Backend + `21` Flutter) | 47 TCs | **47** | 0 | 0 | **100% PASS** |
| **7. Kết nối Trực tuyến End-to-End tới Google Gemini Cloud (`generativelanguage.googleapis.com`)** | FastAPI nạp `.env` -> `POST /v1/chats/{id}/messages` -> `gemini-3-flash-preview` (`x-goog-api-key`) | 2 luồng Live | **2** | 0 | 0 | **PASS (`HTTP 200`)** |

---

## 3. Bằng chứng Kết quả Thực chạy Chi tiết

### 3.1. Bộ Kiểm thử Tích hợp, Bảo mật RBAC, Consent & E2E Backend (`backend/tests/test_api_and_ai.py`)
- **Lệnh chạy:**
  ```powershell
  C:\Users\MSI\AppData\Local\Programs\Python\Python314\python.exe -m unittest backend/tests/test_api_and_ai.py -v
  ```
- **Kết quả thực tế (`Exit Code: 0`):**
  ```text
  test_01_health_security_headers_and_catalogs ... ok
  test_02_onboarding_consent_auth_pbkdf2_and_preferences ... ok
  test_03_ai_safety_guardrail_non_diagnostic_and_no_false_positive ... ok
  test_04_chat_idempotency_multiturn_gemini_header_and_memory_lifecycle ... ok
  test_05_mood_5_scale_weekly_reflection_boundary_and_daily_cbt ... ok
  test_06_screening_consent_purpose_validation_dass21_and_item9_safety ... ok
  test_07_counseling_booking_pii_protection_cancel_and_whitelist ... ok
  test_08_strict_4_role_rbac_staff_login_and_cross_counselor_isolation ... ok
  test_09_real_sqlite_analytics_aggregation_and_kanonymity_threshold ... ok
  test_10_cross_user_idor_isolation_and_self_service_data_erasure_f06 ... ok
  test_11_dotenv_loader_aq_key_and_gemini_model_fallback ... ok
  test_12_multi_actor_features_articles_slots_hotlines_staff_directory_and_chat_rename ... ok
  ----------------------------------------------------------------------
  Ran 12 tests in 5.519s
  OK
  ```

### 3.2. Kiểm thử Khởi chạy Thực tế Uvicorn + Tích hợp Trực tuyến Google Gemini Cloud E2E
- **Kết quả thực tế (`Exit Code: 0`):**
  ```text
  LIVE_E2E_GEMINI_PASS status=ok gemini_server=True model=gemini-3-flash-preview openapi_paths=31 badge="Google Gemini (gemini-3-flash-preview) • CBT AI Companion" latency_ms=4441 suggest_screening=True has_memory_proposal=True crisis_guard=open_safety_support
  ```
- Xác nhận trọn vẹn chuỗi tích hợp thực tế (không lộ khóa bí mật trên log hay URL):
  1. Máy chủ Uvicorn tự động đọc khóa từ tệp `.env` (đã loại trừ trong `.gitignore`), báo `gemini_configured_on_server: true` và `gemini_model: "gemini-3-flash-preview"` trên `GET /v1/health`, đồng thời hỗ trợ CORS động cho Flutter Web localhost.
  2. Gửi hội thoại tiếng Việt thực tế qua `POST /v1/chats/{chat_id}/messages` nhận phản hồi CBT thấu cảm trực tiếp từ máy chủ Google Gemini (`HTTP 200`, `4441ms`), tự động đề xuất sàng lọc (`should_suggest_screening: true`), trích xuất đề xuất trí nhớ (`memory_proposal`) và đi qua bộ lọc phi chẩn đoán `R1` (`is_clinical_diagnosis: false`).
  3. Tin nhắn có tín hiệu nguy cơ cao vẫn được `Safety Guardrail` (`R3`) chặn ngay lập tức trước khi gọi LLM (`suggested_action: "open_safety_support"`).

### 3.3. Phân tích Tĩnh & Build Sản phẩm Flutter Web
- **Phân tích tĩnh (`Exit Code: 0`):**
  ```text
  Analyzing 2 items...
  No issues found! (ran in 4.9s)
  ```
- **Build bản phát hành Web (`Exit Code: 0`):**
  ```text
  Compiling lib\main.dart for the Web... 40.4s
  √ Built build\web
  ```

### 3.4. Bộ Kiểm thử Tự động Flutter (`companion_responsive_test.dart`, `widget_test.dart`, `e2e_flows_and_rbac_test.dart`)
- **Lệnh chạy:**
  ```powershell
  Set-Location d:\MindCheckCampus\apps\student_app
  C:\src\flutter\bin\flutter.bat test test/companion_responsive_test.dart test/widget_test.dart test/e2e_flows_and_rbac_test.dart --no-pub
  ```
- **Kết quả thực tế (`Exit Code: 0`):**
  - `test/companion_responsive_test.dart`: `12/12` passed
  - `test/widget_test.dart`: `4/4` passed
  - `test/e2e_flows_and_rbac_test.dart`: `4/4` passed
  - **Tổng cộng: 20/20 test cases PASS (`100%`)**
- **Danh sách 20 kịch bản kiểm thử Flutter tự động đã PASS:**
  1. `companion_responsive_test.dart` — *Digital Companion Engine: Đa chủ đề CBT tiếng Việt, cá nhân hóa xưng hô & Safety Guardrail không dấu chuẩn xác* (**PASS**)
  2. `companion_responsive_test.dart` — *Clinical Screening Accuracy (R1, R3): DASS-21 chuẩn 21 câu, điểm thấp tích cực & Câu số 9 PHQ-9 >= 1 kích hoạt cảnh báo an toàn 115/111* (**PASS**)
  3. `companion_responsive_test.dart` — *Responsive UI/UX (360px Mobile) & Tuân thủ R2 (Toàn bộ Checkbox không mặc định tích sẵn)* (**PASS**)
  4. `companion_responsive_test.dart` — *Responsive UI/UX (390px iPhone standard viewport)* (**PASS**)
  5. `companion_responsive_test.dart` — *Responsive UI/UX (820px iPad/Tablet viewport)* (**PASS**)
  6. `companion_responsive_test.dart` — *Responsive UI/UX (1366px Desktop/Web viewport)* (**PASS**)
  7. `companion_responsive_test.dart` — *Compact Keyboard Viewport (360x440): Thanh gợi ý nhanh tự động thu gọn ngang để nhường không gian đọc tin nhắn* (**PASS**)
  8. `companion_responsive_test.dart` — *Daily CBT Activities Catalog & Interactive Steps (Thở hộp 4-4-4-4, CBT 3 bước, Grounding 5-4-3-2-1)* (**PASS**)
  9. `companion_responsive_test.dart` — *Counseling Booking Flow Validation (Email & Phone format checks)* (**PASS**)
  10. `companion_responsive_test.dart` — *Knowledge Hub Articles & Verified Source Verification* (**PASS**)
  11. `companion_responsive_test.dart` — *Notification Preferences & Quiet Hours Configuration* (**PASS**)
  12. `companion_responsive_test.dart` — *Data Minimization & Anonymous Session Guarantee* (**PASS**)
  13. `widget_test.dart` — *T01, T02 & T18: Onboarding không mặc định đồng ý chính sách (T02) và mở Hỗ trợ an toàn S21 không cần login (T18)* (**PASS**)
  14. `widget_test.dart` — *T05 & T06: Kiểm thử chống nhân đôi tin nhắn Idempotency (T05) và Xử lý lỗi mạng Offline + Retry (T06)* (**PASS**)
  15. `widget_test.dart` — *T07, T08, T09, T14–T16, T20–T22: Vòng đời Trí nhớ AI, Sàng lọc có xin phép & Đặt lịch đồng bộ* (**PASS**)
  16. `widget_test.dart` — *T13, T14–T16, T24 & T25: Kiểm thử Tổng kết tuần < 3 bản ghi (T13), Thoát sàng lọc (T16), Ẩn nhóm nhỏ k-Anonymity thực tế (T24) và Chặn truy cập chéo Tư vấn viên (T25)* (**PASS**)
  17. `e2e_flows_and_rbac_test.dart` — *R1 Non-Diagnostic Guardrail: Chặn tuyệt đối phát ngôn chẩn đoán bệnh lý hoặc tự suy diễn điểm thang đo* (**PASS**)
  18. `e2e_flows_and_rbac_test.dart` — *R3 Crisis Action Quick-Reply: Nút phản hồi nhanh nguy cơ cao mở thẳng S21 (115/111) và S23 không biến thành chat thông thường* (**PASS**)
  19. `e2e_flows_and_rbac_test.dart` — *R2 & F10 Manual Memory Consent: Chặn lưu trí nhớ thủ công khi chưa tích chọn đồng ý và cho phép khi đã đồng ý* (**PASS**)
  20. `e2e_flows_and_rbac_test.dart` — *F03, F06, F29, S24 & T32: Kiểm tra định dạng liên hệ đặt lịch, Sinh viên tự hủy lịch, Liên kết Guest có xin phép & Xóa sạch dữ liệu cá nhân* (**PASS**)

---

## 4. Bảng Kết quả Chi tiết theo Danh mục Test Case (`TC-01` → `TC-46`)

| Mã TC | Chức năng / Quy tắc | Bằng chứng Automated Test | Trạng thái |
| :--- | :--- | :--- | :---: |
| `TC-01` | `F01`, `R3` (`S21` không cần đăng nhập) | `widget_test.dart` (#1) | **PASS** |
| `TC-02` | `F02`, `R2` (`S03` không tích sẵn checkbox, API chặn khi `false`) | `widget_test.dart` (#1), `test_02` | **PASS** |
| `TC-03` | `F02` (Khởi tạo phiên ẩn danh hợp lệ) | `widget_test.dart` (#1), `test_02` | **PASS** |
| `TC-04` | `F04` (Cá nhân hóa xưng hô & giọng điệu AI) | `companion_responsive_test.dart` (#1), `test_02` | **PASS** |
| `TC-05` | `F03` (Đăng ký/Đăng nhập PBKDF2, chặn trùng email & sai mật khẩu) | `test_02` | **PASS** |
| `TC-06` | `F03`, `R2` (Liên kết phiên khách có Consent riêng `guest_session_link`) | `e2e_flows_and_rbac_test.dart` (#4), `test_02` | **PASS** |
| `TC-07` | `F03`, `R4` (Chặn truy cập chéo IDOR theo `subject_id`) | `test_02`, `test_10` | **PASS** |
| `TC-08` | `F07`, `R1` (Phản hồi CBT tiếng Việt đa lượt) | `companion_responsive_test.dart` (#1), `test_04` | **PASS** |
| `TC-09` | `F07`, `R1` (Hậu kiểm chặn phát ngôn chẩn đoán bệnh/kê đơn/điểm số) | `e2e_flows_and_rbac_test.dart` (#1), `test_03` | **PASS** |
| `TC-10` | `F07` (`T05` Chống nhân đôi tin nhắn `client_message_id`) | `widget_test.dart` (#2), `test_04` | **PASS** |
| `TC-11` | `F07` (`T06` Xử lý mất mạng Offline & Retry an toàn) | `widget_test.dart` (#2) | **PASS** |
| `TC-12` | `F08`, `R3` (Phát hiện nguy cơ cao tiếng Việt có dấu) | `e2e_flows_and_rbac_test.dart` (#2), `test_03` | **PASS** |
| `TC-13` | `F08`, `R3` (Phát hiện không dấu & không báo giả cụm `"từ từ"`) | `companion_responsive_test.dart` (#1), `test_03` | **PASS** |
| `TC-14` | `F08`, `R3` (Quick-reply mở thẳng `S21` & `S23`, không biến thành chat) | `e2e_flows_and_rbac_test.dart` (#2) | **PASS** |
| `TC-15` | `F09` (Gợi ý sàng lọc tự nguyện & quyền ẩn gợi ý) | `test_04` | **PASS** |
| `TC-16` | `F10`, `R2` (`T07` Từ chối lưu đề xuất trí nhớ AI) | `widget_test.dart` (#3), `test_04` | **PASS** |
| `TC-17` | `F10`, `R2` (Validation bắt buộc `decision` & đúng mục đích `ai_memory`) | `test_04` | **PASS** |
| `TC-18` | `F10`, `R2` (Thêm trí nhớ thủ công trên `S28` bắt buộc tích Consent) | `e2e_flows_and_rbac_test.dart` (#3), `test_04` | **PASS** |
| `TC-19` | `F11` (`T08` Xem, tìm kiếm & chỉnh sửa trí nhớ đã duyệt) | `widget_test.dart` (#3), `test_04` | **PASS** |
| `TC-20` | `F12`, `R4` (`T09` Xóa trí nhớ & chặn xóa chéo người dùng) | `widget_test.dart` (#3), `test_04`, `test_10` | **PASS** |
| `TC-21` | `F13` (`T10` Check-in cảm xúc thang `1..5`, chặn ngoài miền & xóa) | `test_05` | **PASS** |
| `TC-22` | `F14` (`T11–T12` Bài tập Thở 4-4-4-4, CBT 3 bước, Grounding 5-4-3-2-1) | `companion_responsive_test.dart` (#3), `test_05` | **PASS** |
| `TC-23` | `F15` (`T13` Biên `< 3` bản ghi báo rõ chưa đủ dữ liệu tuần) | `widget_test.dart` (#4), `test_05` | **PASS** |
| `TC-24` | `F15` (`T13` Đủ `>= 3` bản ghi hiển thị trung bình tuần `/5.0`) | `widget_test.dart` (#4), `test_05` | **PASS** |
| `TC-25` | `F21` (Danh mục `GAD-7`, `PHQ-9`, `DASS-21` đủ 21 câu chuẩn, ẩn nút demo) | `companion_responsive_test.dart` (#2), `widget_test.dart` (#4), `test_01` | **PASS** |
| `TC-26` | `F21`, `R2` (`T14–T15` Chặn mở phiên sàng lọc khi thiếu/sai Consent) | `widget_test.dart` (#3), `test_06` | **PASS** |
| `TC-27` | `F22` (`T16` Thoát bảng hỏi giữa chừng ghi `abandoned`, không chấm điểm) | `widget_test.dart` (#4), `test_06` | **PASS** |
| `TC-28` | `F22` (Chặn nộp thiếu câu hoặc điểm ngoài miền `0..3`) | `test_06` | **PASS** |
| `TC-29` | `F22`, `R3` (`T17` Câu 9 `PHQ-9 >= 1` bật cảnh báo khẩn cấp `115`/`111`) | `companion_responsive_test.dart` (#2), `test_06` | **PASS** |
| `TC-30` | `F22` (Tính `four_week_trend` thực tế theo lịch sử cá nhân, `demo_flag=false`) | `widget_test.dart` (#3), `test_06` | **PASS** |
| `TC-31` | `F29`, `R2` (`T20` Chặn đặt lịch khi chưa tích đồng ý chia sẻ `counseling_share`) | `companion_responsive_test.dart` (#3), `widget_test.dart` (#3), `test_07` | **PASS** |
| `TC-32` | `F29` (Kiểm tra định dạng Email/SĐT hợp lệ khi đặt lịch) | `e2e_flows_and_rbac_test.dart` (#4), `test_07` | **PASS** |
| `TC-33` | `F29` (`T21` Chống nhân đôi lịch hẹn theo `idempotency_key`) | `test_07` | **PASS** |
| `TC-34` | `F29`, `R4` (Bảo vệ PII lịch hẹn bằng `requester_token` / `Bearer`) | `test_07` | **PASS** |
| `TC-35` | `F29` (`S24` Sinh viên tự hủy lịch hẹn của chính mình) | `e2e_flows_and_rbac_test.dart` (#4), `test_07` | **PASS** |
| `TC-36` | `F25` (`S25` Thư viện bài viết kiến thức có nguồn kiểm chứng) | `test_01` | **PASS** |
| `TC-37` | `F05` (`S29` Lưu/đọc tùy chỉnh thông báo & giờ yên tĩnh) | `test_02` | **PASS** |
| `TC-38` | `F06` (`T32` Thu hồi đồng ý & Xóa sạch toàn bộ dữ liệu cá nhân) | `e2e_flows_and_rbac_test.dart` (#4), `test_10` | **PASS** |
| `TC-39` | `F35–F38` (`D01` Xác thực tài khoản nhân sự `staff-login`) | `test_08` | **PASS** |
| `TC-40` | `R4`, `R5` (`T23` Chặn nhân sự CTSV/Counselor/Admin đọc chat/điểm cá nhân) | `test_08` | **PASS** |
| `TC-41` | `F35`, `R4` (`T24` Tổng hợp SQLite thực tế & khóa nhóm nhỏ `k-Anonymity`) | `widget_test.dart` (#4), `test_09` | **PASS** |
| `TC-42` | `F37`, `R5` (Tư vấn viên chỉ xem trường Whitelist & xác nhận lịch đồng bộ) | `widget_test.dart` (#3), `test_07`, `test_08` | **PASS** |
| `TC-43` | `F37`, `R5` (`T25` Chặn `counselor_02` xem ca của `counselor_01` & ghi Audit Log) | `widget_test.dart` (#4), `test_08` | **PASS** |
| `TC-44` | `F38`, `R5` (`D07`, `T27` Admin đổi `min_group_size` & xem Audit Log) | `widget_test.dart` (#4), `test_08`, `test_09` | **PASS** |
| `TC-45` | Responsive UI (`360x780`, `360x440`, `390x844`, `820x1180`, `1366x900`) | `companion_responsive_test.dart` (#3, #4) | **PASS** |
| `TC-46` | Luồng tích hợp End-to-End xuyên suốt Sinh viên ↔ Tư vấn viên ↔ Quản trị | `test_02`..`test_10`, `widget_test.dart`, `e2e_flows_and_rbac_test.dart` | **PASS** |

---

## 5. Ghi chú Triển khai Thiết bị Vật lý (Deployment Notes)

1. **Tích hợp Google Gemini Cloud:** Đã xác minh **PASS** trực tuyến End-to-End với khóa thực tế cấu hình trong `.env` (gửi qua header `x-goog-api-key`, tự động dự phòng từ `gemini-3-flash-preview` sang `gemini-3.1-flash-lite` và Rule-based CBT tiếng Việt nếu đứt mạng).
2. **Thiết bị vật lý Mobile (Android/iOS thực tế):** Giao diện và tương tác cảm ứng đa kích thước (`360x780`, `360x440`, `390x844`, `820x1180`, `1366x900`) đã được kiểm chứng bằng `flutter test` và bản dựng Web thực tế (`flutter build web`); khi đóng gói APK/IPA lên thiết bị di động vật lý cần truyền `--dart-define=MINDCHECK_API_URL=https://<domain-https-cua-truong>/v1`.

