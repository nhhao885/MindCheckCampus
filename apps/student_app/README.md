# MindCheck Campus 2.0 — Ứng dụng Sinh viên & Cổng Quản trị Học đường (`apps/student_app`)

Ứng dụng đa nền tảng (Web, Android, iOS, Desktop) của hệ thống **MindCheck Campus 2.0**, xây dựng bằng **Flutter 3.x**, **Riverpod (`StateNotifier`)**, **Dio** và lưu trữ bền vững cục bộ kết hợp đồng bộ hai chiều với **FastAPI Backend (`backend/app/main.py`)**.

---

## Kiến trúc & Phân hệ Chính

- **`lib/main.dart`**: Khởi tạo ứng dụng, chuyển đổi giữa Không gian Sinh viên (`S01–S30`) và Cổng Web Nhà trường (`D01–D07`), cấu hình kết nối máy chủ (`Contabo Cloud` / `Local FastAPI` / `Offline`).
- **`lib/app/state_provider.dart`**: Quản lý trạng thái trung tâm, đồng bộ API hai chiều, động cơ CBT tiếng Việt dự phòng ngoại tuyến, kiểm soát Consent (`R2`), Hậu kiểm không chẩn đoán (`R1`) và An toàn 2 lớp (`R3`).
- **`lib/features/`**:
  - `onboarding/`: Luồng giới thiệu, cam kết bảo mật (`S03` không tích sẵn checkbox) và cá nhân hóa bạn AI (`S01–S04`).
  - `chat/`: Trò chuyện CBT đa phiên, chống trùng tin nhắn (`Idempotency`), đề xuất lưu Trí nhớ AI có xin phép và thẻ Hỗ trợ Khủng hoảng 2 lớp (`S05–S08`).
  - `mood_daily/`: Check-in cảm xúc 5 mức, đồng hồ Thở vuông 4-4-4-4, Form CBT 3 bước, Grounding 5-4-3-2-1 và Tổng kết tuần chuẩn `>= 3` bản ghi (`S09–S14`).
  - `screening/`: Sàng lọc tự nguyện `GAD-7`, `PHQ-9`, `DASS-21` (đủ 21 câu chuẩn), kiểm tra nguy cơ Câu 9 `PHQ-9` và xu hướng cá nhân thực tế (`S15–S20`).
  - `support/`: Hỗ trợ khẩn cấp `115`/`111` không cần đăng nhập (`S21`) và Đặt lịch/Hủy lịch tư vấn tâm lý học đường (`S23–S24`).
  - `settings/`: Quản lý Trí nhớ AI (`S28`), Thư viện kiến thức (`S25`), Tùy chỉnh thông báo (`S29`), Liên kết tài khoản & Xóa toàn bộ dữ liệu cá nhân (`F06`, `S30`).
  - `school_portal/`: Cổng quản trị phân quyền nghiêm ngặt theo 4 vai trò (`CTSV` với khóa nhóm nhỏ `k-Anonymity`, `Tư vấn viên` với Whitelist `F37` & chặn truy cập chéo `T25`, `Admin` cấu hình ngưỡng & tra cứu `Audit Logs`).

---

## Lệnh Chạy & Kiểm thử Nhanh

```powershell
# Cài đặt dependencies
flutter pub get

# Phân tích tĩnh mã nguồn
flutter analyze

# Chạy toàn bộ bộ kiểm thử tự động (Unit, Widget, Responsive 360px->1366px, RBAC & E2E)
flutter test -r expanded

# Khởi chạy trên trình duyệt Web
flutter run -d chrome --web-port 8080
```

## Tài liệu Chất lượng & Bàn giao

Xem đầy đủ hồ sơ kiểm toán, danh mục test cases, báo cáo kết quả kiểm thử thực tế, hướng dẫn người dùng và hướng dẫn triển khai tại thư mục [`../../docs/quality/`](../../docs/quality/):
- [`AUDIT.md`](../../docs/quality/AUDIT.md)
- [`TEST_CASES.md`](../../docs/quality/TEST_CASES.md)
- [`TEST_REPORT.md`](../../docs/quality/TEST_REPORT.md)
- [`BUG_REPORT.md`](../../docs/quality/BUG_REPORT.md)
- [`USER_GUIDE.md`](../../docs/quality/USER_GUIDE.md)
- [`SETUP_DEPLOYMENT.md`](../../docs/quality/SETUP_DEPLOYMENT.md)
