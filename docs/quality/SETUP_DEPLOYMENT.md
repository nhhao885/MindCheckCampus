# Hướng dẫn Cài đặt, Cấu hình & Triển khai (Setup & Deployment) — MindCheck Campus 2.0

**Phiên bản:** 2.0  
**Kiến trúc hệ thống:** Frontend Flutter (`apps/student_app/` + `packages/shared_models/`) • Backend FastAPI Python 3.11+ (`backend/app/main.py`) • Cơ sở dữ liệu SQLite WAL (`Identity_Vault` + `Anon_Clinical`).

---

## 1. Yêu cầu Hệ thống

| Thành phần | Phiên bản khuyến nghị | Ghi chú |
| :--- | :--- | :--- |
| **Python** | `>= 3.11` (đã kiểm chứng trên `3.14.4`) | Dùng cho Backend FastAPI & bộ kiểm thử API/E2E |
| **Flutter SDK** | `>= 3.24` / Dart `>= 3.5` (đã kiểm chứng trên Dart `3.12.0`) | Hỗ trợ build Web, Android, iOS, Windows |
| **SQLite** | Tích hợp sẵn trong Python `sqlite3` (chế độ `WAL`) | Tự động khởi tạo schema an toàn, không phá hủy dữ liệu cũ |
| **Reverse Proxy (Prod)** | Nginx + Certbot (Let's Encrypt TLS 1.2/1.3) | Triển khai trên máy chủ Ubuntu 22.04/24.04 LTS (Contabo VPS) |

---

## 2. Danh mục Biến Môi trường (Environment Variables)

Tạo tệp biến môi trường riêng trên máy chủ (ví dụ `/etc/mindcheck/mindcheck.env` hoặc thiết lập trong phiên shell; **không commit khóa bí mật thật vào Git** và **không ghi đè tệp `.env` đang vận hành nếu chưa sao lưu**):

| Biến môi trường | Mặc định | Ý nghĩa & Khuyến nghị Bảo mật |
| :--- | :--- | :--- |
| `GEMINI_API_KEY` | *(Trống)* | Khóa Google Gemini API (hỗ trợ cả định dạng mới `AQ....` và `AIza...`). Gửi qua header `x-goog-api-key`. Máy chủ FastAPI tự động nạp từ tệp `.env` ở thư mục gốc. |
| `GEMINI_MODEL` | `gemini-3-flash-preview` | Model Gemini chính sử dụng cho Người bạn số CBT tiếng Việt. |
| `GEMINI_FALLBACK_MODELS` | `gemini-3.1-flash-lite,gemini-2.5-flash` | Danh sách model dự phòng tự động chuyển mạch nếu model chính gặp lỗi `404` / `429` / `5xx`. |
| `MINDCHECK_DB_PATH` | `backend/app/mindcheck.db` | Đường dẫn tệp cơ sở dữ liệu SQLite. Trong kiểm thử tự động có thể trỏ sang tệp tạm riêng biệt để bảo toàn dữ liệu thực. |
| `MINDCHECK_SEED_DEMO` | `false` (`0`) | **Bắt buộc để `false` / `0` trên môi trường bàn giao & Production** để không tạo dữ liệu lịch hẹn mẫu. Chỉ bật `1` khi cần dữ liệu minh họa phát triển. |
| `MINDCHECK_CORS_ORIGINS` | `http://localhost:3000,http://127.0.0.1:3000,http://localhost:8080,http://127.0.0.1:8080` | Danh sách tên miền Web được phép gọi API (phân tách bằng dấu phẩy). Trên Production chỉ khai báo đúng domain HTTPS chính thức. |
| `MINDCHECK_TOKEN_TTL_HOURS` | `168` | Thời hạn hiệu lực của phiên đăng nhập Bearer Token (tính theo giờ). |
| `MINDCHECK_STAFF_CTSV_PASSWORD` | *(Mặc định nội bộ dev)* | **Bắt buộc đổi mật khẩu mạnh trên Production** cho tài khoản `ctsv_01`. |
| `MINDCHECK_STAFF_COUNSELOR1_PASSWORD` | *(Mặc định nội bộ dev)* | **Bắt buộc đổi mật khẩu mạnh trên Production** cho tài khoản `counselor_01`. |
| `MINDCHECK_STAFF_COUNSELOR2_PASSWORD` | *(Mặc định nội bộ dev)* | **Bắt buộc đổi mật khẩu mạnh trên Production** cho tài khoản `counselor_02`. |
| `MINDCHECK_STAFF_ADMIN_PASSWORD` | *(Mặc định nội bộ dev)* | **Bắt buộc đổi mật khẩu mạnh trên Production** cho tài khoản `admin_01`. |

### Biến `--dart-define` cho ứng dụng Flutter (Tùy chọn khi build)
- `--dart-define=MINDCHECK_API_URL=https://api.mindcheck.edu.vn/v1`: Địa chỉ mặc định của máy chủ Contabo Cloud.
- `--dart-define=MINDCHECK_SEED_DEMO=false`: Giữ mặc định `false` cho bản bàn giao chính thức.

---

## 3. Cài đặt & Khởi chạy trên Môi trường Phát triển (Local Development)

### 3.1. Cài đặt và chạy Backend FastAPI
Từ thư mục gốc dự án `d:\MindCheckCampus`:

```powershell
# 1. Cài đặt thư viện Python
python -m pip install -r backend/requirements.txt

# 2. Sao chép tệp mẫu .env.example thành .env và điền khóa GEMINI_API_KEY (Backend tự động đọc .env khi khởi chạy)
# Copy-Item .env.example .env

# 3. Khởi chạy máy chủ FastAPI tại cổng 8000
python -m uvicorn backend.app.main:app --host 127.0.0.1 --port 8000 --reload
```

Kiểm tra nhanh trạng thái máy chủ:
- Health Check: `http://127.0.0.1:8000/v1/health`
- Tài liệu OpenAPI (Swagger): `http://127.0.0.1:8000/docs`

### 3.2. Cài đặt và chạy Ứng dụng Flutter (`apps/student_app`)
```powershell
cd apps/student_app
flutter pub get

# Chạy trên trình duyệt Chrome (Web Sinh viên & Cổng Nhà trường D01–D07)
flutter run -d chrome --web-port 8080

# Hoặc chạy trên thiết bị / máy ảo Android
# Lưu ý: Trên Android Emulator, địa chỉ máy chủ Local trên máy host là http://10.0.2.2:8000/v1
flutter run
```

Trong ứng dụng, nhấn biểu tượng **Đám mây (`Kết nối AI API & Máy chủ Contabo`)** trên thanh công cụ để chọn chế độ `Local FastAPI (127.0.0.1:8000)` hoặc `Contabo Cloud VPS` và bấm **Kiểm tra kết nối (`/v1/health`)**.

---

## 4. Quy trình Kiểm thử Tự động (Automated Test Execution)

```powershell
# 1. Kiểm thử Tích hợp, RBAC, Consent, Privacy & E2E trên Backend (tự động dùng SQLite tạm cô lập, không chạm tới mindcheck.db)
python -m unittest backend/tests/test_api_and_ai.py -v

# 2. Phân tích tĩnh mã nguồn Dart/Flutter
flutter analyze apps/student_app packages/shared_models

# 3. Chạy toàn bộ Unit, Widget, Responsive & RBAC E2E Tests của Flutter
cd apps/student_app
flutter test -r expanded
```

---

## 5. Quản lý Cơ sở Dữ liệu & Sao lưu An toàn (Non-Destructive Policy)

1. **Khởi tạo & Nâng cấp không phá hủy:** Hàm `init_db()` trong `backend/app/main.py` chỉ sử dụng `CREATE TABLE IF NOT EXISTS` và hàm `_ensure_column()` kiểm tra cột qua `PRAGMA table_info(...)` trước khi `ALTER TABLE ... ADD COLUMN`. Tuyệt đối không chứa lệnh `DROP TABLE` hay xóa tệp DB hiện hữu.
2. **Tách biệt hai vùng dữ liệu (`R4`):**
   - **Vùng định danh (`Identity_Vault`):** `users`, `staff_accounts`, `auth_sessions`, `guest_account_links`, `counseling_requests` (chỉ sinh ra khi sinh viên đồng ý chia sẻ `F29`).
   - **Vùng lâm sàng ẩn danh (`Anon_Clinical`):** `chat_sessions`, `chat_messages`, `memory_proposals`, `approved_memories`, `mood_entries`, `activity_logs`, `screening_sessions` — liên kết qua khóa giả danh `subject_id`, tách rời khỏi danh tính thật.
3. **Sao lưu định kỳ trên máy chủ Linux/VPS:**
   Sử dụng lệnh sao lưu nóng an toàn của SQLite (tương thích chế độ `WAL`, không làm gián đoạn dịch vụ):
   ```bash
   sqlite3 /var/lib/mindcheck/mindcheck.db ".backup '/var/backups/mindcheck/mindcheck_$(date +%F_%H%M).db'"
   ```

---

## 6. Triển khai Production trên Máy chủ Contabo VPS (Ubuntu + systemd + Nginx HTTPS)

### Bước 1: Chuẩn bị thư mục và môi trường ảo Python
```bash
sudo useradd --system --home /opt/mindcheck --shell /usr/sbin/nologin mindcheck
sudo mkdir -p /opt/mindcheck /var/lib/mindcheck /etc/mindcheck /var/backups/mindcheck
# Sao chép mã nguồn backend vào /opt/mindcheck/backend
python3 -m venv /opt/mindcheck/venv
/opt/mindcheck/venv/bin/pip install --upgrade pip
/opt/mindcheck/venv/bin/pip install -r /opt/mindcheck/backend/requirements.txt
sudo chown -R mindcheck:mindcheck /opt/mindcheck /var/lib/mindcheck /var/backups/mindcheck
```

### Bước 2: Cấu hình tệp `/etc/mindcheck/mindcheck.env` (Quyền `600`)
```ini
GEMINI_API_KEY=AIzaSy_YOUR_PRODUCTION_KEY
MINDCHECK_DB_PATH=/var/lib/mindcheck/mindcheck.db
MINDCHECK_SEED_DEMO=0
MINDCHECK_CORS_ORIGINS=https://campus.mindcheck.edu.vn
MINDCHECK_STAFF_CTSV_PASSWORD=CHANGE_ME_STRONG_PASSWORD_1
MINDCHECK_STAFF_COUNSELOR1_PASSWORD=CHANGE_ME_STRONG_PASSWORD_2
MINDCHECK_STAFF_COUNSELOR2_PASSWORD=CHANGE_ME_STRONG_PASSWORD_3
MINDCHECK_STAFF_ADMIN_PASSWORD=CHANGE_ME_STRONG_PASSWORD_4
```
```bash
sudo chmod 600 /etc/mindcheck/mindcheck.env
sudo chown root:mindcheck /etc/mindcheck/mindcheck.env
```

### Bước 3: Tạo dịch vụ `systemd` (`/etc/systemd/system/mindcheck-api.service`)
```ini
[Unit]
Description=MindCheck Campus 2.0 FastAPI Service
After=network.target

[Service]
User=mindcheck
Group=mindcheck
WorkingDirectory=/opt/mindcheck
EnvironmentFile=/etc/mindcheck/mindcheck.env
ExecStart=/opt/mindcheck/venv/bin/uvicorn backend.app.main:app --host 127.0.0.1 --port 8000 --workers 2
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
```
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now mindcheck-api
```

### Bước 4: Build bản Flutter Web & Cấu hình Nginx + HTTPS
```bash
cd apps/student_app
flutter build web --release \
  --dart-define=MINDCHECK_API_URL=https://api.mindcheck.edu.vn/v1 \
  --dart-define=MINDCHECK_SEED_DEMO=false
```
Đưa thư mục `apps/student_app/build/web` lên `/var/www/mindcheck-web`, trỏ Nginx Reverse Proxy từ `https://api.mindcheck.edu.vn` về `http://127.0.0.1:8000`, và kích hoạt chứng chỉ TLS tự động bằng `sudo certbot --nginx -d api.mindcheck.edu.vn -d campus.mindcheck.edu.vn`.

