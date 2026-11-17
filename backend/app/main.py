import hashlib
import hmac
import json
import logging
import os
import re
import secrets
import sqlite3
import time
import unicodedata
import uuid
from contextlib import contextmanager
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, List, Optional

import httpx
from fastapi import FastAPI, Header, HTTPException, Query, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field

BOOT_TIME = time.monotonic()

logger = logging.getLogger("mindcheck.api")

_APP_DIR = os.path.dirname(os.path.abspath(__file__))
_BACKEND_DIR = os.path.abspath(os.path.join(_APP_DIR, ".."))
_REPO_ROOT = os.path.abspath(os.path.join(_BACKEND_DIR, ".."))
_DEFAULT_DB_PATH = os.path.join(_APP_DIR, "mindcheck.db")


def _parse_dotenv_file(dotenv_path: str, target_env: Optional[Dict[str, str]] = None) -> int:
    """Nạp biến môi trường từ tệp .env (không phụ thuộc thư viện ngoài, không ghi đè biến đã đặt sẵn)."""
    if not os.path.isfile(dotenv_path):
        return 0
    loaded = 0
    env_map = target_env if target_env is not None else os.environ
    try:
        with open(dotenv_path, "r", encoding="utf-8") as fh:
            for raw_line in fh:
                line = raw_line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                if line.startswith("export "):
                    line = line[len("export ") :].strip()
                key, val = line.split("=", 1)
                key = key.strip()
                val = val.strip()
                if len(val) >= 2 and (
                    (val[0] == val[-1] == '"') or (val[0] == val[-1] == "'")
                ):
                    val = val[1:-1]
                if key and key not in env_map:
                    env_map[key] = val
                    loaded += 1
    except OSError:
        return 0
    return loaded


def _load_dotenv_files() -> int:
    if os.getenv("MINDCHECK_IGNORE_DOTENV", "0").strip() == "1":
        return 0
    total = 0
    for candidate in (
        os.path.join(_REPO_ROOT, ".env"),
        os.path.join(_BACKEND_DIR, ".env"),
    ):
        total += _parse_dotenv_file(candidate)
    return total


_load_dotenv_files()

DEFAULT_GEMINI_MODEL = "gemini-3-flash-preview"
DEFAULT_GEMINI_FALLBACK_MODELS = ("gemini-3.1-flash-lite", "gemini-2.5-flash")


def get_gemini_model() -> str:
    return os.getenv("GEMINI_MODEL", DEFAULT_GEMINI_MODEL).strip() or DEFAULT_GEMINI_MODEL


def get_gemini_model_candidates() -> List[str]:
    primary = get_gemini_model()
    raw_fallbacks = os.getenv(
        "GEMINI_FALLBACK_MODELS",
        ",".join(DEFAULT_GEMINI_FALLBACK_MODELS),
    )
    candidates = [primary]
    for item in raw_fallbacks.split(","):
        m = item.strip()
        if m and m not in candidates:
            candidates.append(m)
    return candidates


def get_db_path() -> str:
    return os.getenv("MINDCHECK_DB_PATH", _DEFAULT_DB_PATH)


def is_seed_demo_enabled() -> bool:
    return os.getenv("MINDCHECK_SEED_DEMO", "0").strip().lower() in ("1", "true", "yes")


def is_strict_staff_bearer_required() -> bool:
    """Trên Contabo Production, bật MINDCHECK_REQUIRE_STAFF_BEARER=1 để bắt buộc nhân sự dùng Bearer Token."""
    return (
        os.getenv("MINDCHECK_REQUIRE_STAFF_BEARER", "0").strip().lower() in ("1", "true", "yes")
        or os.getenv("MINDCHECK_ENV", "").strip().lower() == "production"
    )


ALLOWED_ORIGINS_RAW = os.getenv("MINDCHECK_CORS_ORIGINS", "*").strip()
ALLOWED_ORIGINS = (
    ["*"]
    if ALLOWED_ORIGINS_RAW == "*"
    else [o.strip() for o in ALLOWED_ORIGINS_RAW.split(",") if o.strip()]
)
_HAS_LOCAL_ORIGIN = ALLOWED_ORIGINS != ["*"] and any(
    "localhost" in o or "127.0.0.1" in o for o in ALLOWED_ORIGINS
)

app = FastAPI(
    title="MindCheck Campus 2.0 - AI Companion & School Portal API",
    version="2.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_origin_regex=(
        r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$" if _HAS_LOCAL_ORIGIN else None
    ),
    allow_credentials=ALLOWED_ORIGINS != ["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.middleware("http")
async def security_headers_middleware(request: Request, call_next):
    response = await call_next(request)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["Referrer-Policy"] = "no-referrer"
    response.headers["Cache-Control"] = "no-store"
    return response


# ============================================================================
# CHUẨN HÓA XỬ LÝ LỖI (ERROR.CODE & MESSAGE - KHÔNG LỘ DỮ LIỆU NHẠY CẢM)
# ============================================================================


class ApiError(Exception):
    def __init__(self, status_code: int, code: str, message: str):
        self.status_code = status_code
        self.code = code
        self.message = message


@app.exception_handler(ApiError)
async def api_error_handler(_: Request, exc: ApiError):
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "error": {"code": exc.code, "message": exc.message},
            "detail": {"code": exc.code, "message": exc.message},
        },
    )


@app.exception_handler(HTTPException)
async def http_exception_handler(_: Request, exc: HTTPException):
    if isinstance(exc.detail, dict) and "code" in exc.detail:
        code = exc.detail["code"]
        msg = exc.detail.get("message", str(exc.detail))
    else:
        code = "HTTP_ERROR"
        msg = str(exc.detail)
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "error": {"code": code, "message": msg},
            "detail": {"code": code, "message": msg},
        },
    )


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(_: Request, exc: RequestValidationError):
    safe_details = [
        {"loc": list(err.get("loc", [])), "msg": err.get("msg", ""), "type": err.get("type", "")}
        for err in exc.errors()
    ]
    return JSONResponse(
        status_code=422,
        content={
            "error": {
                "code": "VALIDATION_FAILED",
                "message": "Dữ liệu đầu vào không hợp lệ.",
                "details": safe_details,
            }
        },
    )


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def hash_token(raw_token: str) -> str:
    return hashlib.sha256(raw_token.strip().encode("utf-8")).hexdigest()


def hash_password(password: str) -> str:
    salt = secrets.token_hex(16)
    dk = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt.encode("utf-8"), 120_000)
    return f"pbkdf2_sha256$120000${salt}${dk.hex()}"


def verify_password(password: str, stored_hash: str) -> bool:
    if stored_hash.startswith("pbkdf2_sha256$"):
        try:
            _, iter_str, salt, digest_hex = stored_hash.split("$", 3)
            dk = hashlib.pbkdf2_hmac(
                "sha256",
                password.encode("utf-8"),
                salt.encode("utf-8"),
                int(iter_str),
            )
            return hmac.compare_digest(dk.hex(), digest_hex)
        except Exception:
            return False
    legacy = hashlib.sha256(f"mindcheck_salt::{password}".encode("utf-8")).hexdigest()
    return hmac.compare_digest(legacy, stored_hash)


_EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
_PHONE_RE = re.compile(r"^\+?[0-9][0-9\s\-\.]{7,16}$")


def is_valid_contact_info(contact: str) -> bool:
    cleaned = contact.strip()
    if not cleaned or len(cleaned) > 160:
        return False
    return bool(_EMAIL_RE.match(cleaned) or _PHONE_RE.match(cleaned))


# ============================================================================
# DATABASE PERSISTENCE (SQLITE - TÁCH 2 VÙNG DỮ LIỆU R4, MIGRATION AN TOÀN)
# ============================================================================


@contextmanager
def get_db():
    conn = sqlite3.connect(get_db_path(), check_same_thread=False, timeout=10.0)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL;")
    conn.execute("PRAGMA synchronous=NORMAL;")
    conn.execute("PRAGMA busy_timeout=5000;")
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def _upsert_staff_from_env(cur: sqlite3.Cursor, ts: str):
    staff_specs = [
        (
            "ctsv_01",
            "ctsv",
            "Chuyên viên Phòng CTSV",
            "Phòng Công tác Sinh viên",
            "MINDCHECK_CTSV_PASSWORD",
        ),
        (
            "counselor_01",
            "counselor",
            "ThS. Tâm lý Nguyễn Văn A",
            "Phòng Tư vấn Tâm lý Sinh viên",
            "MINDCHECK_COUNSELOR1_PASSWORD",
        ),
        (
            "counselor_02",
            "counselor",
            "ThS. Tâm lý Trần Thị B",
            "Tổ Tư vấn Học đường",
            "MINDCHECK_COUNSELOR2_PASSWORD",
        ),
        (
            "admin_01",
            "admin",
            "Quản trị viên Hệ thống",
            "Trung tâm Quản trị & An toàn Thông tin",
            "MINDCHECK_ADMIN_PASSWORD",
        ),
    ]
    for staff_id, role, display_name, unit_name, env_key in staff_specs:
        raw_pw = os.getenv(env_key, "").strip()
        if raw_pw:
            pw_hash = hash_password(raw_pw)
            cur.execute(
                """
                INSERT INTO staff_accounts (staff_id, role, display_name, unit_name, is_active, password_hash, created_at)
                VALUES (?, ?, ?, ?, 1, ?, ?)
                ON CONFLICT(staff_id) DO UPDATE SET
                    role = excluded.role,
                    display_name = excluded.display_name,
                    unit_name = excluded.unit_name,
                    password_hash = excluded.password_hash
                """,
                (staff_id, role, display_name, unit_name, pw_hash, ts),
            )


def init_db():
    with get_db() as conn:
        cur = conn.cursor()

        # --------------------------------------------------------------------
        # VÙNG 1: IDENTITY_VAULT (Dữ liệu định danh - Tách biệt khỏi lâm sàng)
        # Tuyệt đối không lưu subject_id hay khóa ngoại nối sang Anon_Clinical
        # --------------------------------------------------------------------
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS user_accounts (
                user_id TEXT PRIMARY KEY,
                email TEXT UNIQUE NOT NULL,
                password_hash TEXT NOT NULL,
                full_name TEXT DEFAULT '',
                faculty TEXT DEFAULT 'CNTT',
                academic_year TEXT DEFAULT 'Nam_2',
                linked_guest_id TEXT,
                created_at TEXT NOT NULL
            )
            """
        )

        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS staff_accounts (
                staff_id TEXT PRIMARY KEY,
                role TEXT NOT NULL,
                display_name TEXT NOT NULL,
                unit_name TEXT DEFAULT 'Phòng Công tác Sinh viên & Tư vấn',
                is_active INTEGER DEFAULT 1,
                password_hash TEXT NOT NULL,
                created_at TEXT NOT NULL
            )
            """
        )
        staff_cols = {
            r["name"]
            for r in cur.execute("PRAGMA table_info(staff_accounts)").fetchall()
        }
        if "unit_name" not in staff_cols:
            cur.execute(
                "ALTER TABLE staff_accounts ADD COLUMN unit_name TEXT DEFAULT 'Phòng Công tác Sinh viên & Tư vấn'"
            )
        if "is_active" not in staff_cols:
            cur.execute(
                "ALTER TABLE staff_accounts ADD COLUMN is_active INTEGER DEFAULT 1"
            )

        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS auth_sessions (
                token_hash TEXT PRIMARY KEY,
                principal_id TEXT NOT NULL,
                role TEXT NOT NULL,
                subject_id TEXT DEFAULT '',
                email TEXT DEFAULT '',
                created_at TEXT NOT NULL,
                expires_at TEXT NOT NULL
            )
            """
        )

        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS counseling_requests (
                request_id TEXT PRIMARY KEY,
                idempotency_key TEXT UNIQUE NOT NULL,
                unit_name TEXT NOT NULL,
                counselor_id TEXT NOT NULL,
                counselor_name TEXT NOT NULL,
                slot_time TEXT NOT NULL,
                consultation_mode TEXT DEFAULT 'Trực tiếp tại phòng',
                contact_info TEXT NOT NULL,
                student_note TEXT DEFAULT '',
                counselor_note TEXT DEFAULT '',
                requester_token_hash TEXT DEFAULT '',
                consent_id TEXT NOT NULL,
                status TEXT NOT NULL DEFAULT 'pending',
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
            """
        )
        # Safe additive migrations cho CSDL hiện hữu (không xóa/phá hủy dữ liệu)
        existing_cols = {
            r["name"]
            for r in cur.execute("PRAGMA table_info(counseling_requests)").fetchall()
        }
        if "counselor_note" not in existing_cols:
            cur.execute(
                "ALTER TABLE counseling_requests ADD COLUMN counselor_note TEXT DEFAULT ''"
            )
        if "requester_token_hash" not in existing_cols:
            cur.execute(
                "ALTER TABLE counseling_requests ADD COLUMN requester_token_hash TEXT DEFAULT ''"
            )
        if "consultation_mode" not in existing_cols:
            cur.execute(
                "ALTER TABLE counseling_requests ADD COLUMN consultation_mode TEXT DEFAULT 'Trực tiếp tại phòng'"
            )

        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS counselor_slots (
                slot_id TEXT PRIMARY KEY,
                counselor_id TEXT NOT NULL,
                counselor_name TEXT NOT NULL,
                unit_name TEXT NOT NULL,
                slot_label TEXT NOT NULL,
                consultation_mode TEXT DEFAULT 'Trực tiếp tại phòng',
                is_available INTEGER DEFAULT 1,
                updated_at TEXT NOT NULL
            )
            """
        )

        # --------------------------------------------------------------------
        # VÙNG 2: ANON_CLINICAL (Dữ liệu tâm lý ẩn danh & quản trị)
        # --------------------------------------------------------------------
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS guest_sessions (
                guest_id TEXT PRIMARY KEY,
                subject_id TEXT UNIQUE NOT NULL,
                companion_nickname TEXT DEFAULT 'MindCheck',
                user_pronoun TEXT DEFAULT 'bạn',
                ai_pronoun TEXT DEFAULT 'mình',
                ai_tone TEXT DEFAULT 'ấm áp, gần gũi',
                notif_enabled INTEGER DEFAULT 1,
                reminder_time TEXT DEFAULT '20:00',
                quiet_hours TEXT DEFAULT '22:00 - 07:00',
                hide_sensitive_lockscreen INTEGER DEFAULT 1,
                created_at TEXT NOT NULL
            )
            """
        )

        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS consents (
                consent_id TEXT PRIMARY KEY,
                subject_id TEXT NOT NULL,
                purpose TEXT NOT NULL,
                version TEXT NOT NULL DEFAULT 'v1.0-2026',
                decision TEXT NOT NULL,
                created_at TEXT NOT NULL
            )
            """
        )

        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS chat_sessions (
                session_id TEXT PRIMARY KEY,
                subject_id TEXT NOT NULL,
                title TEXT NOT NULL,
                started_at TEXT NOT NULL
            )
            """
        )

        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS chat_messages (
                message_id TEXT PRIMARY KEY,
                client_message_id TEXT UNIQUE NOT NULL,
                session_id TEXT NOT NULL,
                role TEXT NOT NULL,
                text TEXT NOT NULL,
                reply_type TEXT DEFAULT 'supportive_chat',
                quick_replies_json TEXT DEFAULT '[]',
                suggested_action TEXT,
                provider_badge TEXT,
                response_cache_json TEXT,
                created_at TEXT NOT NULL
            )
            """
        )

        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS memory_proposals (
                proposal_id TEXT PRIMARY KEY,
                subject_id TEXT NOT NULL,
                source_message_id TEXT NOT NULL,
                candidate_text TEXT NOT NULL,
                status TEXT NOT NULL DEFAULT 'proposed',
                created_at TEXT NOT NULL
            )
            """
        )

        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS approved_memories (
                memory_id TEXT PRIMARY KEY,
                subject_id TEXT NOT NULL,
                proposal_id TEXT,
                consent_id TEXT NOT NULL,
                text TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
            """
        )

        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS mood_entries (
                entry_id TEXT PRIMARY KEY,
                subject_id TEXT NOT NULL,
                mood_choice TEXT NOT NULL,
                mood_level INTEGER NOT NULL,
                optional_note TEXT DEFAULT '',
                recorded_at TEXT NOT NULL
            )
            """
        )

        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS activity_progress (
                progress_id TEXT PRIMARY KEY,
                subject_id TEXT NOT NULL,
                activity_id TEXT NOT NULL,
                status TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
            """
        )

        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS screening_sessions (
                session_id TEXT PRIMARY KEY,
                subject_id TEXT NOT NULL,
                tool_id TEXT NOT NULL,
                consent_id TEXT NOT NULL,
                status TEXT NOT NULL DEFAULT 'in_progress',
                answers_json TEXT DEFAULT '[]',
                score INTEGER,
                max_score INTEGER,
                level_label TEXT,
                interpretation TEXT,
                requires_attention INTEGER DEFAULT 0,
                faculty TEXT DEFAULT 'CNTT',
                academic_year TEXT DEFAULT 'Nam_2',
                demo_flag INTEGER DEFAULT 0,
                created_at TEXT NOT NULL,
                completed_at TEXT
            )
            """
        )

        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS knowledge_articles (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                category TEXT NOT NULL,
                summary TEXT NOT NULL,
                content TEXT NOT NULL,
                verified_source TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
            """
        )

        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS safety_hotlines (
                hotline_id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                phone TEXT NOT NULL,
                description TEXT NOT NULL,
                hours TEXT DEFAULT '24/7',
                is_verified INTEGER DEFAULT 1,
                updated_at TEXT NOT NULL
            )
            """
        )

        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS audit_events (
                event_id TEXT PRIMARY KEY,
                actor TEXT NOT NULL,
                action TEXT NOT NULL,
                target TEXT NOT NULL,
                result TEXT NOT NULL,
                metadata_json TEXT DEFAULT '{}',
                timestamp TEXT NOT NULL
            )
            """
        )

        ts = now_iso()
        _upsert_staff_from_env(cur, ts)

        # Khởi tạo danh mục nghiệp vụ chuẩn (Bài viết kiến thức, Khung giờ chuyên gia, Hotline khẩn cấp S21)
        if cur.execute("SELECT COUNT(*) AS cnt FROM knowledge_articles").fetchone()["cnt"] == 0:
            default_articles = [
                (
                    "art_01",
                    "Kỹ thuật chia nhỏ mục tiêu ôn thi theo liệu pháp CBT",
                    "Học tập & Thi cử",
                    "Cách vượt qua sự trì hoãn và cảm giác quá tải trước mùa thi học kỳ.",
                    (
                        "Khi đối diện với khối lượng môn học lớn, não bộ thường sinh ra suy nghĩ tự động "
                        "\"Mình không thể làm kịp\". Kỹ thuật CBT giúp bạn tách cảm xúc lo âu khỏi hành động "
                        "thực tế bằng cách chia bài ôn thành các phiên 25 phút (Pomodoro) và ghi nhận từng bước hoàn thành nhỏ."
                    ),
                    "Tài liệu Giáo dục Tâm lý Học đường đã kiểm duyệt",
                    ts,
                ),
                (
                    "art_02",
                    "Vệ sinh giấc ngủ dành cho sinh viên mùa đồ án",
                    "Chăm sóc giấc ngủ",
                    "Thiết lập nhịp sinh học và thư giãn cơ bắp trước khi ngủ 30 phút.",
                    (
                        "Tránh sử dụng màn hình xanh 30 phút trước khi ngủ, kết hợp bài tập thở 4-4-4-4 "
                        "và viết ra giấy những việc cần làm vào sáng mai để não bộ không phải ghi nhớ trong lúc ngủ."
                    ),
                    "Cẩm nang Sức khỏe Tinh thần Sinh viên",
                    ts,
                ),
                (
                    "art_03",
                    "Khi nào nên kết nối Chuyên gia Tư vấn Tâm lý của Trường?",
                    "Đồng hành & An toàn",
                    "Nhận diện dấu hiệu quá tải kéo dài và quy trình bảo mật khi đặt lịch hẹn 1-1.",
                    (
                        "Nếu trạng thái mất ngủ, lo âu hoặc kiệt sức kéo dài trên 2 tuần làm ảnh hưởng việc học tập "
                        "và sinh hoạt, việc trò chuyện 1-1 với chuyên gia tư vấn học đường là bước chủ động tích cực. "
                        "Mọi lịch hẹn trên MindCheck Campus chỉ chia sẻ thông tin liên hệ khi có sự đồng ý của bạn."
                    ),
                    "Phòng Tư vấn Tâm lý Sinh viên",
                    ts,
                ),
            ]
            cur.executemany(
                """
                INSERT INTO knowledge_articles (id, title, category, summary, content, verified_source, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                default_articles,
            )

        if cur.execute("SELECT COUNT(*) AS cnt FROM counselor_slots").fetchone()["cnt"] == 0:
            default_slots = [
                (
                    "slot_c1_01",
                    "counselor_01",
                    "ThS. Tâm lý Nguyễn Văn A",
                    "Phòng Tư vấn Tâm lý Sinh viên",
                    "Thứ 4 (09:00 - 10:00)",
                    "Trực tiếp tại phòng P.102",
                    1,
                    ts,
                ),
                (
                    "slot_c1_02",
                    "counselor_01",
                    "ThS. Tâm lý Nguyễn Văn A",
                    "Phòng Tư vấn Tâm lý Sinh viên",
                    "Thứ 5 (14:00 - 15:00)",
                    "Trực tiếp tại phòng P.102",
                    1,
                    ts,
                ),
                (
                    "slot_c1_03",
                    "counselor_01",
                    "ThS. Tâm lý Nguyễn Văn A",
                    "Phòng Tư vấn Tâm lý Sinh viên",
                    "Thứ 6 (15:30 - 16:30)",
                    "Trực tuyến (Google Meet)",
                    1,
                    ts,
                ),
                (
                    "slot_c2_01",
                    "counselor_02",
                    "ThS. Tâm lý Trần Thị B",
                    "Tổ Tư vấn Học đường",
                    "Thứ 4 (14:00 - 15:00)",
                    "Trực tiếp tại phòng P.204",
                    1,
                    ts,
                ),
                (
                    "slot_c2_02",
                    "counselor_02",
                    "ThS. Tâm lý Trần Thị B",
                    "Tổ Tư vấn Học đường",
                    "Thứ 6 (09:00 - 10:00)",
                    "Trực tuyến (Google Meet)",
                    1,
                    ts,
                ),
            ]
            cur.executemany(
                """
                INSERT INTO counselor_slots (
                    slot_id, counselor_id, counselor_name, unit_name, slot_label,
                    consultation_mode, is_available, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                default_slots,
            )

        if cur.execute("SELECT COUNT(*) AS cnt FROM safety_hotlines").fetchone()["cnt"] == 0:
            default_hotlines = [
                (
                    "hotline_115",
                    "Cấp cứu Y tế Toàn quốc",
                    "115",
                    "Hỗ trợ y tế và khủng hoảng sức khỏe khẩn cấp trên toàn quốc.",
                    "24/7",
                    1,
                    ts,
                ),
                (
                    "hotline_111",
                    "Tổng đài Quốc gia Bảo vệ & Hỗ trợ Khẩn cấp",
                    "111",
                    "Đường dây nóng miễn phí tiếp nhận hỗ trợ tâm lý và bảo vệ khẩn cấp.",
                    "24/7",
                    1,
                    ts,
                ),
                (
                    "hotline_campus_01",
                    "Trực ban Phòng Tư vấn Tâm lý & CTSV Nhà trường",
                    "0292-389-0115",
                    "Hỗ trợ trực tiếp sinh viên trong khuôn viên trường và ký túc xá.",
                    "07:30 - 21:00 (Thứ 2 - Thứ 7)",
                    1,
                    ts,
                ),
            ]
            cur.executemany(
                """
                INSERT INTO safety_hotlines (hotline_id, name, phone, description, hours, is_verified, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                default_hotlines,
            )

        # Tách biệt hoàn toàn dữ liệu seed phát triển (chỉ chạy khi bật MINDCHECK_SEED_DEMO=1)
        if is_seed_demo_enabled():
            cur.execute("SELECT COUNT(*) AS cnt FROM guest_sessions WHERE guest_id = 'guest_default'")
            if cur.fetchone()["cnt"] == 0:
                cur.execute(
                    """
                    INSERT INTO guest_sessions (guest_id, subject_id, created_at)
                    VALUES ('guest_default', 'sub_default', ?)
                    """,
                    (ts,),
                )

            cur.execute("SELECT COUNT(*) AS cnt FROM counseling_requests WHERE request_id = 'req_demo_001'")
            if cur.fetchone()["cnt"] == 0:
                cur.execute(
                    """
                    INSERT INTO consents (consent_id, subject_id, purpose, version, decision, created_at)
                    VALUES ('con_init_booking', 'sub_default', 'counseling_share', 'v1.0-2026', 'accepted', ?)
                    """,
                    (ts,),
                )
                cur.execute(
                    """
                    INSERT INTO counseling_requests (
                        request_id, idempotency_key, unit_name, counselor_id, counselor_name,
                        slot_time, contact_info, student_note, consent_id, status, created_at, updated_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        "req_demo_001",
                        "idem_demo_001",
                        "Phòng Tư vấn Tâm lý Sinh viên",
                        "counselor_01",
                        "ThS. Tâm lý Nguyễn Văn A",
                        "Thứ 4 (09:00 - 10:00)",
                        "sv_demo@student.ctuet.edu.vn",
                        "Em muốn xin tư vấn cách giảm áp lực trước kỳ thi.",
                        "con_init_booking",
                        "pending",
                        ts,
                        ts,
                    ),
                )


init_db()


def log_audit_event(
    conn: sqlite3.Connection,
    actor: str,
    action: str,
    target: str,
    result: str = "SUCCESS",
    metadata: Optional[dict] = None,
) -> dict:
    event_id = f"evt_{uuid.uuid4().hex[:8]}"
    ts = now_iso()
    conn.execute(
        """
        INSERT INTO audit_events (event_id, actor, action, target, result, metadata_json, timestamp)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        """,
        (event_id, actor, action, target, result, json.dumps(metadata or {}, ensure_ascii=False), ts),
    )
    conn.commit()
    return {
        "event_id": event_id,
        "actor": actor,
        "action": action,
        "target": target,
        "result": result,
        "timestamp": ts,
    }


def issue_auth_token(
    conn: sqlite3.Connection,
    principal_id: str,
    role: str,
    subject_id: str = "",
    email: str = "",
    ttl_hours: int = 24 * 7,
) -> str:
    raw_token = f"tok_{role}_{secrets.token_urlsafe(24)}"
    now_dt = datetime.now(timezone.utc)
    exp_dt = now_dt + timedelta(hours=ttl_hours)
    conn.execute(
        """
        INSERT INTO auth_sessions (token_hash, principal_id, role, subject_id, email, created_at, expires_at)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        """,
        (
            hash_token(raw_token),
            principal_id,
            role,
            subject_id,
            email,
            now_dt.isoformat(),
            exp_dt.isoformat(),
        ),
    )
    return raw_token


def resolve_bearer_session(
    conn: sqlite3.Connection, authorization: str
) -> Optional[sqlite3.Row]:
    auth = (authorization or "").strip()
    if not auth:
        return None
    if not auth.lower().startswith("bearer "):
        raise ApiError(
            status_code=401,
            code="INVALID_AUTH_HEADER",
            message="Header Authorization phải theo định dạng 'Bearer <token>'.",
        )
    raw_tok = auth[7:].strip()
    if not raw_tok:
        raise ApiError(
            status_code=401,
            code="INVALID_AUTH_TOKEN",
            message="Token xác thực rỗng hoặc không hợp lệ.",
        )
    row = conn.execute(
        "SELECT * FROM auth_sessions WHERE token_hash = ?",
        (hash_token(raw_tok),),
    ).fetchone()
    if not row:
        raise ApiError(
            status_code=401,
            code="INVALID_OR_EXPIRED_TOKEN",
            message="Token xác thực không tồn tại hoặc đã bị thu hồi.",
        )
    try:
        exp_dt = datetime.fromisoformat(row["expires_at"])
        if exp_dt < datetime.now(timezone.utc):
            raise ApiError(
                status_code=401,
                code="TOKEN_EXPIRED",
                message="Phiên đăng nhập đã hết hạn, vui lòng xác thực lại.",
            )
    except ApiError:
        raise
    except Exception:
        pass
    return row


def guard_personal_clinical_access(
    conn: sqlite3.Connection,
    target: str,
    authorization: str = "",
    x_subject_id: str = "",
    explicit_subject_id: Optional[str] = None,
    x_staff_id: str = "",
    x_staff_role: str = "",
    x_admin_actor: str = "",
    require_subject: bool = False,
) -> str:
    """
    R4, R5, T23, F37, T25, T27:
    1) Tuyệt đối chặn CTSV (A02), Tư vấn viên (A03) và Admin (A04) truy cập dữ liệu lâm sàng cá nhân.
    2) Chống truy cập chéo người dùng (IDOR) giữa các subject_id khác nhau.
    """
    session = resolve_bearer_session(conn, authorization)
    if session and session["role"] in ("ctsv", "counselor", "admin"):
        log_audit_event(
            conn,
            actor=session["principal_id"],
            action="ACCESS_PERSONAL_CLINICAL_DATA",
            target=target,
            result="DENIED_STAFF_CLINICAL_ACCESS",
        )
        raise ApiError(
            status_code=403,
            code="STAFF_CLINICAL_ACCESS_FORBIDDEN",
            message="Nhân sự nhà trường / Quản trị viên bị cấm truy cập hội thoại và dữ liệu lâm sàng cá nhân của sinh viên (R4, R5).",
        )

    staff_actor = (x_admin_actor or x_staff_id or x_staff_role).strip()
    if staff_actor:
        log_audit_event(
            conn,
            actor=staff_actor,
            action="ACCESS_PERSONAL_CLINICAL_DATA",
            target=target,
            result="DENIED_STAFF_CLINICAL_ACCESS",
        )
        raise ApiError(
            status_code=403,
            code="STAFF_CLINICAL_ACCESS_FORBIDDEN",
            message="Tài khoản nhân sự / Quản trị viên không được phép đọc dữ liệu lâm sàng cá nhân (R4, R5, T27).",
        )

    hdr_subj = (x_subject_id or "").strip()
    exp_subj = (explicit_subject_id or "").strip()

    if session:
        token_subj = (session["subject_id"] or "").strip()
        if hdr_subj and token_subj and hdr_subj != token_subj:
            raise ApiError(
                status_code=403,
                code="FORBIDDEN_CROSS_USER_ACCESS",
                message="Không được phép truy cập dữ liệu của phiên người dùng khác.",
            )
        if exp_subj and exp_subj != "sub_default" and token_subj and exp_subj != token_subj:
            raise ApiError(
                status_code=403,
                code="FORBIDDEN_CROSS_USER_ACCESS",
                message="subject_id không khớp với phiên xác thực hiện tại.",
            )
        resolved = token_subj or hdr_subj or exp_subj
    else:
        if hdr_subj and exp_subj and hdr_subj != exp_subj:
            raise ApiError(
                status_code=403,
                code="FORBIDDEN_CROSS_USER_ACCESS",
                message="X-Subject-Id và subject_id không đồng nhất.",
            )
        resolved = hdr_subj or exp_subj

    if require_subject and not resolved:
        raise ApiError(
            status_code=401,
            code="SUBJECT_IDENTITY_REQUIRED",
            message="Vui lòng cung cấp X-Subject-Id hoặc Bearer token để xác minh quyền sở hữu dữ liệu.",
        )
    return resolved


def assert_resource_owner(owner_subject_id: str, caller_subject_id: str):
    if not caller_subject_id or owner_subject_id != caller_subject_id:
        raise ApiError(
            status_code=403,
            code="FORBIDDEN_CROSS_USER_ACCESS",
            message="Bạn không có quyền xem, chỉnh sửa hoặc xóa dữ liệu thuộc về người dùng khác.",
        )


def require_counselor_actor(
    conn: sqlite3.Connection,
    target: str,
    authorization: str = "",
    counselor_id_query: Optional[str] = None,
    x_staff_id: str = "",
    x_staff_role: str = "",
    x_admin_actor: str = "",
) -> str:
    session = resolve_bearer_session(conn, authorization)
    if session:
        if session["role"] != "counselor":
            log_audit_event(
                conn,
                actor=session["principal_id"],
                action="STAFF_COUNSELING_ACCESS_DENIED",
                target=target,
                result="DENIED_INVALID_ROLE",
            )
            raise ApiError(
                status_code=403,
                code="FORBIDDEN_ROLE",
                message="Chỉ Tư vấn viên tâm lý (A03) mới được truy cập danh sách ca tư vấn được phân công (R5).",
            )
        actor = session["principal_id"]
        if counselor_id_query and counselor_id_query.strip() != actor:
            log_audit_event(
                conn,
                actor=actor,
                action="STAFF_COUNSELING_IMPERSONATION_DENIED",
                target=target,
                result="DENIED_CROSS_COUNSELOR",
            )
            raise ApiError(
                status_code=403,
                code="FORBIDDEN_CROSS_COUNSELOR_ACCESS",
                message="Không được phép truy vấn danh sách lịch hẹn của tư vấn viên khác (T25).",
            )
        return actor

    if is_strict_staff_bearer_required():
        attempted_actor = (x_admin_actor or x_staff_id or x_staff_role or "unauthenticated_staff").strip()
        log_audit_event(
            conn,
            actor=attempted_actor,
            action="STAFF_HEADER_FALLBACK_BLOCKED",
            target=target,
            result="DENIED_BEARER_REQUIRED",
        )
        raise ApiError(
            status_code=401,
            code="STAFF_BEARER_TOKEN_REQUIRED",
            message="Môi trường Production yêu cầu xác thực nhân sự bằng Bearer Token hợp lệ (/v1/auth/staff-login).",
        )

    if x_admin_actor.strip() or x_staff_role.strip().lower() in ("ctsv", "admin", "student"):
        bad_actor = (x_admin_actor or x_staff_role or "unknown").strip()
        log_audit_event(
            conn,
            actor=bad_actor,
            action="STAFF_COUNSELING_ACCESS_DENIED",
            target=target,
            result="DENIED_INVALID_ROLE",
        )
        raise ApiError(
            status_code=403,
            code="FORBIDDEN_ROLE",
            message="Vai trò hiện tại không có quyền xem hồ sơ lịch hẹn định danh của sinh viên (R5).",
        )

    hdr_id = x_staff_id.strip()
    qry_id = (counselor_id_query or "").strip()
    if hdr_id and qry_id and hdr_id != qry_id:
        log_audit_event(
            conn,
            actor=hdr_id,
            action="STAFF_COUNSELING_CROSS_QUERY_DENIED",
            target=target,
            result="DENIED_CROSS_COUNSELOR",
        )
        raise ApiError(
            status_code=403,
            code="FORBIDDEN_CROSS_COUNSELOR_ACCESS",
            message="Không được phép truy vấn ca tư vấn của đồng nghiệp khác (T25).",
        )

    effective = hdr_id or qry_id
    if not effective:
        raise ApiError(
            status_code=401,
            code="STAFF_AUTH_REQUIRED",
            message="Yêu cầu xác thực tài khoản Tư vấn viên (Bearer token hoặc X-Staff-Id).",
        )
    if not effective.startswith("counselor_"):
        log_audit_event(
            conn,
            actor=effective,
            action="STAFF_COUNSELING_ACCESS_DENIED",
            target=target,
            result="DENIED_INVALID_ROLE",
        )
        raise ApiError(
            status_code=403,
            code="FORBIDDEN_ROLE",
            message="Định danh nhân sự không thuộc nhóm Tư vấn viên (A03).",
        )
    return effective


def require_analytics_actor(
    conn: sqlite3.Connection,
    authorization: str = "",
    x_staff_role: str = "",
    x_staff_id: str = "",
    x_admin_actor: str = "",
) -> str:
    session = resolve_bearer_session(conn, authorization)
    if session:
        if session["role"] not in ("ctsv", "admin"):
            log_audit_event(
                conn,
                actor=session["principal_id"],
                action="ANALYTICS_OVERVIEW_DENIED",
                target="AnalyticsOverview",
                result="DENIED_INVALID_ROLE",
            )
            raise ApiError(
                status_code=403,
                code="FORBIDDEN_ROLE",
                message="Chỉ Phòng CTSV (A02) hoặc Quản trị viên (A04) mới có quyền xem Dashboard thống kê tổng hợp.",
            )
        return session["principal_id"]

    if is_strict_staff_bearer_required():
        attempted_actor = (x_admin_actor or x_staff_id or x_staff_role or "unauthenticated_staff").strip()
        log_audit_event(
            conn,
            actor=attempted_actor,
            action="STAFF_HEADER_FALLBACK_BLOCKED",
            target="AnalyticsOverview",
            result="DENIED_BEARER_REQUIRED",
        )
        raise ApiError(
            status_code=401,
            code="STAFF_BEARER_TOKEN_REQUIRED",
            message="Môi trường Production yêu cầu xác thực nhân sự bằng Bearer Token hợp lệ (/v1/auth/staff-login).",
        )

    role_hdr = x_staff_role.strip().lower()
    staff_hdr = x_staff_id.strip()
    admin_hdr = x_admin_actor.strip()

    if role_hdr in ("counselor", "student") or staff_hdr.startswith("counselor_"):
        bad_actor = staff_hdr or role_hdr or "unauthorized"
        log_audit_event(
            conn,
            actor=bad_actor,
            action="ANALYTICS_OVERVIEW_DENIED",
            target="AnalyticsOverview",
            result="DENIED_INVALID_ROLE",
        )
        raise ApiError(
            status_code=403,
            code="FORBIDDEN_ROLE",
            message="Vai trò hiện tại không được phép truy cập Dashboard thống kê toàn trường.",
        )

    if admin_hdr:
        return admin_hdr
    if role_hdr in ("ctsv", "admin"):
        return staff_hdr or f"{role_hdr}_portal"
    if staff_hdr.startswith("ctsv_") or staff_hdr.startswith("admin_"):
        return staff_hdr

    raise ApiError(
        status_code=401,
        code="STAFF_AUTH_REQUIRED",
        message="Vui lòng xác thực vai trò CTSV hoặc Admin để xem Dashboard thống kê tổng hợp.",
    )


def require_admin_actor(
    conn: sqlite3.Connection,
    authorization: str = "",
    x_admin_actor: str = "",
    x_staff_role: str = "",
    x_staff_id: str = "",
) -> str:
    session = resolve_bearer_session(conn, authorization)
    if session:
        if session["role"] != "admin":
            log_audit_event(
                conn,
                actor=session["principal_id"],
                action="ADMIN_POLICY_ACCESS_DENIED",
                target="AdminGovernance",
                result="DENIED_NOT_ADMIN",
            )
            raise ApiError(
                status_code=403,
                code="FORBIDDEN_ADMIN_ONLY",
                message="Chỉ Quản trị viên hệ thống (A04) mới có quyền cấu hình chính sách và xem Audit Log (R5).",
            )
        return session["principal_id"]

    if is_strict_staff_bearer_required():
        attempted_actor = (x_admin_actor or x_staff_id or x_staff_role or "unauthenticated_staff").strip()
        log_audit_event(
            conn,
            actor=attempted_actor,
            action="STAFF_HEADER_FALLBACK_BLOCKED",
            target="AdminGovernance",
            result="DENIED_BEARER_REQUIRED",
        )
        raise ApiError(
            status_code=401,
            code="STAFF_BEARER_TOKEN_REQUIRED",
            message="Môi trường Production yêu cầu xác thực Quản trị viên bằng Bearer Token hợp lệ (/v1/auth/staff-login).",
        )

    role_hdr = x_staff_role.strip().lower()
    staff_hdr = x_staff_id.strip()
    admin_hdr = x_admin_actor.strip()

    if role_hdr in ("ctsv", "counselor", "student") or staff_hdr.startswith(("counselor_", "ctsv_")):
        bad_actor = staff_hdr or role_hdr or "unauthorized"
        log_audit_event(
            conn,
            actor=bad_actor,
            action="ADMIN_POLICY_ACCESS_DENIED",
            target="AdminGovernance",
            result="DENIED_NOT_ADMIN",
        )
        raise ApiError(
            status_code=403,
            code="FORBIDDEN_ADMIN_ONLY",
            message="Chỉ Quản trị viên hệ thống (A04) mới được truy cập chức năng này.",
        )

    if admin_hdr:
        return admin_hdr
    if role_hdr == "admin" and staff_hdr:
        return staff_hdr

    raise ApiError(
        status_code=401,
        code="ADMIN_AUTH_REQUIRED",
        message="Yêu cầu xác thực Quản trị viên (Bearer token hoặc X-Admin-Actor).",
    )


def ensure_guest_row(conn: sqlite3.Connection, subject_id: str) -> sqlite3.Row:
    row = conn.execute(
        "SELECT * FROM guest_sessions WHERE subject_id = ? OR guest_id = ?",
        (subject_id, subject_id),
    ).fetchone()
    if not row:
        guest_id = subject_id if subject_id.startswith("guest_") else f"guest_{subject_id}"
        conn.execute(
            """
            INSERT INTO guest_sessions (guest_id, subject_id, created_at)
            VALUES (?, ?, ?)
            """,
            (guest_id, subject_id, now_iso()),
        )
        row = conn.execute(
            "SELECT * FROM guest_sessions WHERE subject_id = ?", (subject_id,)
        ).fetchone()
    return row


def verify_consent(
    conn: sqlite3.Connection,
    consent_id: str,
    expected_purpose: Optional[str] = None,
    expected_subject_id: Optional[str] = None,
    allowed_subject_ids: Optional[List[str]] = None,
):
    if not consent_id or not consent_id.strip():
        raise ApiError(
            status_code=403,
            code="CONSENT_REQUIRED",
            message="Thao tác bắt buộc phải có bản ghi đồng thuận (consent_id) hợp lệ (R2).",
        )
    row = conn.execute(
        "SELECT * FROM consents WHERE consent_id = ?", (consent_id.strip(),)
    ).fetchone()
    if not row:
        raise ApiError(
            status_code=403,
            code="CONSENT_NOT_FOUND",
            message=f"Không tìm thấy bản ghi consent '{consent_id}' (R2).",
        )
    if row["decision"] != "accepted":
        err_code = "CONSENT_REVOKED" if row["decision"] == "revoked" else "CONSENT_DECLINED"
        raise ApiError(
            status_code=403,
            code=err_code,
            message="Người dùng chưa đồng ý hoặc đã thu hồi quyền này (R2).",
        )
    if expected_purpose and row["purpose"] != expected_purpose:
        raise ApiError(
            status_code=403,
            code="CONSENT_PURPOSE_MISMATCH",
            message=f"Bản ghi consent không đúng mục đích '{expected_purpose}' (R2).",
        )

    valid_subjects = set()
    if expected_subject_id and expected_subject_id.strip():
        valid_subjects.add(expected_subject_id.strip())
    if allowed_subject_ids:
        for sid in allowed_subject_ids:
            if sid and sid.strip():
                valid_subjects.add(sid.strip())

    if valid_subjects and row["subject_id"] not in valid_subjects:
        raise ApiError(
            status_code=403,
            code="CONSENT_SUBJECT_MISMATCH",
            message="Bản ghi consent thuộc về một phiên người dùng khác (R2).",
        )

    # Kiểm tra xem người dùng đã thu hồi (revoked) mục đích này sau thời điểm cấp consent chưa
    revoked = conn.execute(
        """
        SELECT consent_id FROM consents
        WHERE subject_id = ? AND purpose = ? AND decision = 'revoked' AND created_at >= ?
          AND consent_id != ?
        LIMIT 1
        """,
        (row["subject_id"], row["purpose"], row["created_at"], row["consent_id"]),
    ).fetchone()
    if revoked:
        raise ApiError(
            status_code=403,
            code="CONSENT_REVOKED",
            message="Sự đồng ý cho mục đích này đã bị thu hồi trước đó (R2).",
        )

    return row


# ============================================================================
# PYDANTIC SCHEMAS
# ============================================================================


class GuestSessionCreateInput(BaseModel):
    privacy_accepted: bool = False
    consent_version: str = "v1.0-2026"


class SignupInput(BaseModel):
    email: str
    password: str
    full_name: str = ""
    faculty: str = "CNTT"
    academic_year: str = "Nam_2"


class LoginInput(BaseModel):
    email: str
    password: str


class StaffLoginInput(BaseModel):
    staff_id: str
    password: str


class LinkGuestSessionInput(BaseModel):
    guest_id: str
    user_id: Optional[str] = None
    consent_id: Optional[str] = None
    consent_to_link: bool = False


class CompanionPrefInput(BaseModel):
    nickname: str = "MindCheck"
    user_pronoun: str = "bạn"
    ai_pronoun: str = "mình"
    tone: str = "ấm áp, gần gũi"


class NotificationPrefInput(BaseModel):
    enabled: bool = True
    reminder_time: str = "20:00"
    quiet_hours: str = "22:00 - 07:00"
    hide_sensitive_on_lock_screen: bool = True


class ConsentCreateInput(BaseModel):
    subject_id: str = "sub_default"
    purpose: str
    version: str = "v1.0-2026"
    decision: Optional[str] = None


class ChatCreateInput(BaseModel):
    subject_id: str = "sub_default"
    title: Optional[str] = None


class ChatTurnItem(BaseModel):
    role: str
    text: str


class ChatMessageInput(BaseModel):
    client_message_id: str
    text: str
    subject_id: str = "sub_default"
    context_opt_in: bool = True
    user_pronoun: str = "bạn"
    ai_pronoun: str = "mình"
    ai_nickname: str = "MindCheck"
    ai_tone: str = "ấm áp, gần gũi"
    approved_memories: List[str] = Field(default_factory=list)
    conversation_history: List[ChatTurnItem] = Field(default_factory=list)


class ManualMemoryCreateInput(BaseModel):
    subject_id: str = "sub_default"
    text: str
    consent_id: Optional[str] = None
    consent_accepted: bool = False


class MemoryApproveInput(BaseModel):
    decision: Optional[str] = None
    consent_id: Optional[str] = None
    candidate_text: Optional[str] = None
    subject_id: str = "sub_default"


class MemoryPatchInput(BaseModel):
    text: str


class MoodEntryCreateInput(BaseModel):
    subject_id: str = "sub_default"
    mood_choice: str
    mood_level: int = Field(ge=1, le=5)
    optional_note: str = ""


class ActivityProgressInput(BaseModel):
    subject_id: str = "sub_default"
    activity_id: str
    status: str


class ScreeningSessionCreateInput(BaseModel):
    tool_id: str
    consent_id: Optional[str] = None
    subject_id: str = "sub_default"
    faculty: str = "CNTT"
    academic_year: str = "Nam_2"


class ScreeningAnswersInput(BaseModel):
    answers: List[int] = Field(default_factory=list)
    completed: bool = True


class ChatSessionRenameInput(BaseModel):
    title: str


class CounselingRequestCreateInput(BaseModel):
    idempotency_key: Optional[str] = None
    unit_name: str = "Phòng Tư vấn Tâm lý Sinh viên"
    counselor_id: str = "counselor_01"
    counselor_name: str = "ThS. Tâm lý Nguyễn Văn A"
    slot_time: str
    consultation_mode: str = "Trực tiếp tại phòng"
    contact_info: str
    student_note: str = ""
    consent_id: Optional[str] = None
    subject_id: Optional[str] = None


class StaffCounselingPatchInput(BaseModel):
    status: str
    slot_time: Optional[str] = None
    consultation_mode: Optional[str] = None
    counselor_note: Optional[str] = None


class AnalyticsPolicyUpdateInput(BaseModel):
    min_group_size: int = Field(ge=5, le=100)


class KnowledgeArticleInput(BaseModel):
    id: Optional[str] = None
    title: str
    category: str = "Kỹ năng Tự chăm sóc"
    summary: str
    content: str
    verified_source: str = "Phòng Tư vấn Tâm lý & CTSV"


class CounselorSlotCreateInput(BaseModel):
    counselor_id: Optional[str] = None
    counselor_name: str = "ThS. Tâm lý Nguyễn Văn A"
    unit_name: str = "Phòng Tư vấn Tâm lý Sinh viên"
    slot_label: str
    consultation_mode: str = "Trực tiếp tại phòng P.102"
    is_available: bool = True


class CounselorSlotPatchInput(BaseModel):
    slot_label: Optional[str] = None
    consultation_mode: Optional[str] = None
    is_available: Optional[bool] = None


class StaffAccountUpsertInput(BaseModel):
    staff_id: str
    role: str
    display_name: str
    unit_name: str = "Phòng Công tác Sinh viên & Tư vấn"
    password: Optional[str] = None
    is_active: bool = True


class StaffAccountPatchInput(BaseModel):
    role: Optional[str] = None
    display_name: Optional[str] = None
    unit_name: Optional[str] = None
    password: Optional[str] = None
    is_active: Optional[bool] = None


class SafetyHotlineInput(BaseModel):
    hotline_id: Optional[str] = None
    name: str
    phone: str
    description: str
    hours: str = "24/7"
    is_verified: bool = True


# ============================================================================
# BỘ DỮ LIỆU CHUẨN: DAILY CBT ACTIVITIES, KNOWLEDGE & SCREENING TOOLS
# ============================================================================

DAILY_ACTIVITIES_CATALOG = [
    {
        "activity_id": "act_01",
        "title": "Hít thở hộp 4-4-4-4 điều hòa căng thẳng",
        "category": "Thử thách 2 phút",
        "duration": "2 phút",
        "steps": [
            "Hít vào nhẹ nhàng bằng mũi trong 4 giây.",
            "Giữ hơi thở nhẹ nhàng trong 4 giây.",
            "Thở ra từ từ bằng miệng trong 4 giây và nghỉ 4 giây.",
        ],
    },
    {
        "activity_id": "act_02",
        "title": "Nhận diện & Tái cấu trúc suy nghĩ tự động (CBT)",
        "category": "Bài tập CBT tự hỗ trợ",
        "duration": "5 phút",
        "steps": [
            "Ghi lại tình huống thực tế đang gây áp lực (VD: Sắp thi cuối kỳ).",
            "Nhận diện suy nghĩ tự động tiêu cực vừa xuất hiện.",
            "Viết lại góc nhìn cân bằng, thực tế và chia nhỏ hành động.",
        ],
    },
    {
        "activity_id": "act_03",
        "title": "Grounding 5-4-3-2-1 kết nối thực tại",
        "category": "Chánh niệm & Thư giãn",
        "duration": "3 phút",
        "steps": [
            "Nhìn 5 đồ vật quanh bạn, chạm vào 4 bề mặt cảm nhận được.",
            "Lắng nghe 3 âm thanh, nhận diện 2 mùi hương và 1 điều bạn biết ơn hôm nay.",
        ],
    },
]

KNOWLEDGE_ARTICLES_CATALOG = [
    {
        "id": "art_01",
        "title": "Kỹ thuật chia nhỏ mục tiêu ôn thi theo liệu pháp CBT",
        "category": "Học tập & Thi cử",
        "summary": "Cách vượt qua sự trì hoãn và cảm giác quá tải trước mùa thi học kỳ.",
        "content": (
            "Khi đối diện với khối lượng môn học lớn, não bộ thường sinh ra suy nghĩ tự động "
            "\"Mình không thể làm kịp\". Kỹ thuật CBT giúp bạn tách cảm xúc lo âu khỏi hành động "
            "thực tế bằng cách chia bài ôn thành các phiên 25 phút (Pomodoro) và ghi nhận từng bước hoàn thành nhỏ."
        ),
        "verified_source": "Tài liệu Giáo dục Tâm lý Học đường đã kiểm duyệt",
    },
    {
        "id": "art_02",
        "title": "Vệ sinh giấc ngủ dành cho sinh viên mùa đồ án",
        "category": "Chăm sóc giấc ngủ",
        "summary": "Thiết lập nhịp sinh học và thư giãn cơ bắp trước khi ngủ 30 phút.",
        "content": (
            "Tránh sử dụng màn hình xanh 30 phút trước khi ngủ, kết hợp bài tập thở 4-4-4-4 "
            "và viết ra giấy những việc cần làm vào sáng mai để não bộ không phải ghi nhớ trong lúc ngủ."
        ),
        "verified_source": "Cẩm nang Sức khỏe Tinh thần Sinh viên",
    },
    {
        "id": "art_03",
        "title": "Khi nào nên kết nối Chuyên gia Tư vấn Tâm lý của Trường?",
        "category": "Đồng hành & An toàn",
        "summary": "Nhận diện dấu hiệu quá tải kéo dài và quy trình bảo mật khi đặt lịch hẹn 1-1.",
        "content": (
            "Nếu trạng thái mất ngủ, lo âu hoặc kiệt sức kéo dài trên 2 tuần làm ảnh hưởng việc học tập "
            "và sinh hoạt, việc trò chuyện 1-1 với chuyên gia tư vấn học đường là bước chủ động tích cực. "
            "Mọi lịch hẹn trên MindCheck Campus chỉ chia sẻ thông tin liên hệ khi có sự đồng ý của bạn."
        ),
        "verified_source": "Phòng Tư vấn Tâm lý Sinh viên",
    },
]

SCREENING_TOOLS_CATALOG: Dict[str, dict] = {
    "PHQ-9": {
        "tool_id": "PHQ-9",
        "name": "Thang đo PHQ-9 (Đánh giá mức độ Trầm cảm)",
        "subtitle": "9 câu hỏi chuẩn hóa sàng lọc triệu chứng trầm cảm trong 2 tuần qua",
        "description": "Kroenke et al. (2001) — Sàng lọc tự nguyện có xin phép, chấm điểm bằng Rule-based Engine, không thay thế chẩn đoán y khoa.",
        "scale_options": [
            {"value": 0, "label": "Hầu như không (0 ngày)"},
            {"value": 1, "label": "Vài ngày (1)"},
            {"value": 2, "label": "Hơn một nửa số ngày (2)"},
            {"value": 3, "label": "Gần như mỗi ngày (3)"},
        ],
        "questions": [
            "1. Ít hứng thú hoặc ít niềm vui khi làm mọi việc?",
            "2. Cảm thấy buồn bã, chán nản hoặc tuyệt vọng?",
            "3. Khó vào giấc ngủ, ngủ không sâu giấc hoặc ngủ quá nhiều?",
            "4. Cảm thấy mệt mỏi hoặc có ít năng lượng?",
            "5. Chán ăn hoặc ăn quá nhiều?",
            "6. Cảm thấy tồi tệ về bản thân — hoặc cảm thấy mình là người thất bại?",
            "7. Khó tập trung vào việc đọc sách, nghe giảng hoặc học tập?",
            "8. Di chuyển hoặc nói năng chậm chạp, hoặc bồn chồn không yên?",
            "9. Có suy nghĩ tiêu cực rằng thà mình biến mất hoặc tự làm đau bản thân?",
        ],
    },
    "GAD-7": {
        "tool_id": "GAD-7",
        "name": "Thang đo GAD-7 (Đánh giá mức độ Lo âu)",
        "subtitle": "7 câu hỏi chuẩn quốc tế đánh giá triệu chứng lo âu trong 2 tuần qua",
        "description": "Spitzer et al. (2006) — Chấm điểm bằng Rule-based Engine, giúp sinh viên tự nhận diện mức độ lo âu.",
        "scale_options": [
            {"value": 0, "label": "Hầu như không (0)"},
            {"value": 1, "label": "Vài ngày (1)"},
            {"value": 2, "label": "Hơn một nửa số ngày (2)"},
            {"value": 3, "label": "Gần như mỗi ngày (3)"},
        ],
        "questions": [
            "1. Cảm thấy lo lắng, bồn chồn hoặc căng thẳng?",
            "2. Không thể ngừng hoặc kiểm soát việc lo lắng?",
            "3. Lo lắng quá nhiều về những điều khác nhau?",
            "4. Khó thư giãn?",
            "5. Bồn chồn đến mức khó ngồi yên?",
            "6. Dễ bực bội hoặc cáu gắt?",
            "7. Cảm thấy sợ hãi như thể điều gì đó tồi tệ sắp xảy ra?",
        ],
    },
    "DASS-21": {
        "tool_id": "DASS-21",
        "name": "Thang đo DASS-21 (Trầm cảm - Lo âu - Căng thẳng)",
        "subtitle": "21 câu hỏi chuẩn đánh giá đa chiều áp lực tâm lý học đường",
        "description": "Lovibond & Lovibond (1995) — Phiên bản chuẩn 21 mục đánh giá Căng thẳng, Lo âu và Trầm cảm.",
        "scale_options": [
            {"value": 0, "label": "Không đúng với tôi chút nào (0)"},
            {"value": 1, "label": "Đúng với tôi phần nào / thỉnh thoảng (1)"},
            {"value": 2, "label": "Đúng với tôi phần nhiều / khá thường xuyên (2)"},
            {"value": 3, "label": "Hoàn toàn đúng với tôi / rất thường xuyên (3)"},
        ],
        "questions": [
            "1. Tôi thấy khó thoải mái, thư giãn.",
            "2. Tôi nhận thấy mình bị khô miệng.",
            "3. Tôi dường như không có chút cảm xúc tích cực nào.",
            "4. Tôi cảm thấy khó thở (thở gấp, hụt hơi dù không gắng sức).",
            "5. Tôi thấy khó bắt tay vào làm việc hoặc ôn bài.",
            "6. Tôi có xu hướng phản ứng thái quá trước các tình huống.",
            "7. Tôi cảm thấy run (ví dụ ở tay).",
            "8. Tôi cảm thấy mình đang tiêu tốn rất nhiều năng lượng thần kinh.",
            "9. Tôi lo lắng về những tình huống có thể khiến mình hoảng sợ.",
            "10. Tôi cảm thấy mình chẳng có gì đáng mong đợi ở tương lai.",
            "11. Tôi thấy bản thân dễ bị kích động, bứt rứt.",
            "12. Tôi thấy khó thư giãn đầu óc.",
            "13. Tôi cảm thấy chán nản và buồn rầu.",
            "14. Tôi không kiên nhẫn với bất kỳ điều gì cản trở việc đang làm.",
            "15. Tôi cảm thấy mình gần như hoảng loạn.",
            "16. Tôi không thể hào hứng với bất kỳ việc gì.",
            "17. Tôi cảm thấy mình không có nhiều giá trị.",
            "18. Tôi thấy mình khá nhạy cảm, dễ tự ái.",
            "19. Tôi nhận thức rõ nhịp tim của mình dù không vận động mạnh.",
            "20. Tôi cảm thấy sợ vô cớ.",
            "21. Tôi cảm thấy cuộc sống thiếu ý nghĩa.",
        ],
    },
}


def compute_subject_screening_trend(
    conn: sqlite3.Connection, subject_id: str, tool_id: str, latest_ratio: Optional[float] = None
) -> List[float]:
    rows = conn.execute(
        """
        SELECT score, max_score FROM screening_sessions
        WHERE subject_id = ? AND tool_id = ? AND status = 'completed'
          AND score IS NOT NULL AND max_score IS NOT NULL AND max_score > 0
        ORDER BY completed_at ASC
        LIMIT 6
        """,
        (subject_id, tool_id),
    ).fetchall()
    points = [
        round(min(max(r["score"] / r["max_score"], 0.05), 0.98), 2)
        for r in rows
    ]
    if latest_ratio is not None and not points:
        points = [latest_ratio]
    return points


DASS21_STRESS_INDICES = (0, 5, 7, 10, 11, 13, 17)
DASS21_ANXIETY_INDICES = (1, 3, 6, 8, 14, 18, 19)
DASS21_DEPRESSION_INDICES = (2, 4, 9, 12, 15, 16, 20)


def compute_dass21_subscales(answers: List[int]) -> Dict[str, int]:
    if len(answers) < 21:
        third = sum(int(x) for x in answers) // 3
        rem = sum(int(x) for x in answers) - third * 2
        return {"stress": third, "anxiety": third, "depression": max(0, rem)}
    return {
        "stress": sum(int(answers[i]) for i in DASS21_STRESS_INDICES),
        "anxiety": sum(int(answers[i]) for i in DASS21_ANXIETY_INDICES),
        "depression": sum(int(answers[i]) for i in DASS21_DEPRESSION_INDICES),
    }


def evaluate_screening_rule_based(
    tool_id: str,
    answers: List[int],
    historical_trend: Optional[List[float]] = None,
) -> dict:
    total = sum(int(x) for x in answers)
    question_count = max(len(answers), 1)
    max_score = question_count * 3
    item9_risk = tool_id == "PHQ-9" and len(answers) >= 9 and answers[8] >= 1
    subscales = compute_dass21_subscales(answers) if tool_id == "DASS-21" else {}

    if tool_id == "PHQ-9":
        if total <= 4 and not item9_risk:
            level = "Mức tối thiểu — bạn đang ổn"
            attention = False
        elif total <= 9 and not item9_risk:
            level = "Mức nhẹ — nên duy trì tự chăm sóc"
            attention = False
        elif total <= 14 and not item9_risk:
            level = "Mức trung bình — nên theo dõi thêm"
            attention = True
        else:
            level = "Mức cần chú ý — nên kết nối chuyên gia tư vấn"
            attention = True
    elif tool_id == "GAD-7":
        if total <= 4:
            level = "Mức thấp — bạn đang ổn"
            attention = False
        elif total <= 9:
            level = "Mức nhẹ — nên thư giãn và theo dõi"
            attention = False
        elif total <= 14:
            level = "Mức trung bình — nên theo dõi thêm"
            attention = True
        else:
            level = "Mức cần chú ý — nên kết nối chuyên gia tư vấn"
            attention = True
    else:
        ratio = total / max_score
        if ratio < 0.34:
            level = "Mức thấp — bạn đang ổn"
            attention = False
        elif ratio < 0.67:
            level = "Mức trung bình — nên theo dõi thêm"
            attention = True
        else:
            level = "Mức cần chú ý — nên kết nối chuyên gia tư vấn"
            attention = True

    ratio_val = round(min(max(total / max_score, 0.05), 0.98), 2)
    if item9_risk or total >= int(max_score * 0.7):
        interpretation = (
            "Hệ thống ghi nhận dấu hiệu cần được hỗ trợ an toàn ưu tiên (An toàn 2 lớp - R3): "
            "Nếu bạn đang cảm thấy mất an toàn, hãy gọi ngay Đường dây nóng Cấp cứu Y tế 115 hoặc Tổng đài Quốc gia 111 (24/7, S21), "
            "đồng thời đặt lịch hẹn trực tiếp với Chuyên gia Tư vấn Tâm lý của trường (S23). "
            "Kết quả này được tính bằng Rule-based Engine và không thay thế chẩn đoán y khoa."
        )
    elif attention:
        interpretation = (
            "Vài dấu hiệu gần đây cho thấy bạn nên trò chuyện với chuyên gia tâm lý của trường trong tuần này (S23) "
            "hoặc tham khảo đường dây hỗ trợ 115 / 111 (S21) khi cần thiết. "
            "Kết quả này được tính tự động bằng Rule-based Engine và không thay thế chẩn đoán y khoa."
        )
    else:
        interpretation = (
            "Trạng thái tinh thần của bạn đang ở ngưỡng ổn định. Hãy tiếp tục duy trì thói quen nghỉ ngơi và bài tập CBT mỗi ngày. "
            "Kết quả này chỉ mang tính tham khảo tự theo dõi, không phải chẩn đoán y khoa."
        )

    trend = list(historical_trend) if historical_trend else [ratio_val]
    return {
        "score": total,
        "max_score": max_score,
        "level_label": level,
        "interpretation": interpretation,
        "requires_attention": attention,
        "item9_safety_alert": item9_risk,
        "recommended_layer": "layer_1_and_2_safety" if attention else "self_care_cbt",
        "four_week_trend": trend,
        "subscale_scores": subscales,
        "is_clinical_diagnosis": False,
        "demo_flag": is_seed_demo_enabled(),
    }


# ============================================================================
# AI COMPANION ENGINE (SAFETY GUARDRAIL + NON-DIAGNOSTIC + GEMINI 2.5 FLASH)
# ============================================================================

HIGH_RISK_PATTERNS = [
    "tự tử",
    "tự sát",
    "tự hại",
    "không muốn sống",
    "chẳng muốn sống",
    "không còn muốn sống",
    "chết đi",
    "muốn chết",
    "kết thúc cuộc đời",
    "bế tắc quá",
    "muốn biến mất",
    "làm đau bản thân",
    "cắt tay",
    "cắt cổ tay",
    "nhảy lầu",
    "uống thuốc quá liều",
]

HIGH_RISK_UNACCENTED_PATTERNS = [
    "khong muon song",
    "chang muon song",
    "khong con muon song",
    "ket thuc cuoc doi",
    "lam dau ban than",
    "muon bien mat",
    "muon tu tu",
    "y dinh tu tu",
    "dinh tu tu",
    "se tu tu",
    "muon tu sat",
    "tu hai ban than",
    "cat co tay",
    "nhay lau",
    "muon chet",
]

FORBIDDEN_DIAGNOSTIC_PATTERNS = [
    r"chẩn đoán\s+(bạn|em)\s+(bị|mắc)",
    r"(bạn|em)\s+(đang\s+)?(bị|mắc\s+bệnh)\s+(trầm cảm|rối loạn lo âu|tâm thần)",
    r"điểm\s*(phq-?9|gad-?7|dass-?21)\s*của\s*(bạn|em)\s*là",
    r"kê\s+đơn\s+thuốc",
]


def _strip_vietnamese_accents(text: str) -> str:
    decomposed = unicodedata.normalize("NFD", text.replace("đ", "d").replace("Đ", "D"))
    return "".join(ch for ch in decomposed if unicodedata.category(ch) != "Mn")


def _detect_high_risk_message(text: str) -> bool:
    lower = text.lower()
    if any(k in lower for k in HIGH_RISK_PATTERNS):
        return True
    unaccented = _strip_vietnamese_accents(lower)
    return any(k in unaccented for k in HIGH_RISK_UNACCENTED_PATTERNS)


def _enforce_non_diagnostic_guardrail(reply_text: str, u_pro: str, ai_pro: str) -> str:
    cleaned = (reply_text or "").strip()
    if not cleaned:
        return (
            f"{ai_pro.capitalize()} đang ở đây lắng nghe {u_pro}. "
            f"Chúng mình cùng chia sẻ chậm rãi từng bước theo hướng tiếp cận CBT nhé."
        )
    lower = cleaned.lower()
    for pat in FORBIDDEN_DIAGNOSTIC_PATTERNS:
        if re.search(pat, lower):
            return (
                f"{ai_pro.capitalize()} lắng nghe những khó khăn {u_pro} đang trải qua. "
                f"Vì {ai_pro} là người bạn đồng hành định hướng CBT nên không thực hiện chẩn đoán bệnh lý hay tự suy diễn điểm thang đo; "
                f"{u_pro} có thể tự nguyện thực hiện bài sàng lọc chuẩn hóa ở mục 'Sàng lọc' hoặc đặt lịch trò chuyện cùng chuyên gia của trường nhé."
            )
    return cleaned


async def _post_gemini_api(
    url: str, request_body: dict, headers: Optional[Dict[str, str]] = None
) -> httpx.Response:
    async with httpx.AsyncClient(timeout=15.0) as client:
        return await client.post(url, json=request_body, headers=headers or {})


async def call_gemini_cbt_engine(
    payload: ChatMessageInput,
    api_key: str,
) -> dict:
    lower = payload.text.lower()
    u_pro = payload.user_pronoun
    ai_pro = payload.ai_pronoun

    # 1. Lớp bảo vệ an toàn ưu tiên tuyệt đối (Rule-based Safety Guardrail - R3)
    if _detect_high_risk_message(payload.text):
        return {
            "reply": (
                f"{ai_pro.capitalize()} nghe thấy {u_pro} đang trải qua khoảnh khắc rất nặng nề và khó khăn. "
                f"Lúc này sự an toàn của {u_pro} là quan trọng nhất. Vì {ai_pro} chỉ là người bạn đồng hành AI "
                f"và không thể thay thế sự hỗ trợ khẩn cấp của con người, {u_pro} hãy mở ngay màn hình Hỗ trợ an toàn (Hotline 115 / 111) "
                f"hoặc đặt lịch kết nối trực tiếp với chuyên gia tư vấn của trường bên dưới nhé."
            ),
            "reply_type": "safety_escalation",
            "quick_replies": [
                "Mở hướng dẫn Hỗ trợ an toàn",
                "Kết nối Tư vấn viên của trường",
            ],
            "should_suggest_screening": False,
            "suggested_action": "open_safety_support",
            "memory_candidate": None,
            "memory_proposal": None,
            "provider_badge": "Safety Guardrail • Cơ chế an toàn 2 lớp",
        }

    # 2. Gọi Google Gemini 2.5 Flash với Header x-goog-api-key (không đặt secret lên URL - R2/Security)
    effective_key = api_key.strip() or os.getenv("GEMINI_API_KEY", "").strip()
    if effective_key:
        system_instruction = (
            f"Bạn là '{payload.ai_nickname}', một 'Người bạn số' (Digital Companion) hỗ trợ sức khỏe tinh thần "
            f"dành cho sinh viên Việt Nam trên ứng dụng MindCheck Campus 2.0. "
            f"Cách xưng hô: gọi sinh viên là '{u_pro}', xưng là '{ai_pro}'. Phong cách lắng nghe: {payload.ai_tone}. "
            f"Thông tin ghi nhớ đã được sinh viên chủ động đồng ý lưu trước đó: {payload.approved_memories}. "
            "NGUYÊN TẮC BẤT BIẾN (R1-R3):\n"
            "1. Đóng vai người bạn đồng hành số thấu cảm theo định hướng CBT (Liệu pháp nhận thức hành vi): lắng nghe không phán xét, phản hồi cảm xúc tinh tế, đặt câu hỏi gợi mở nhẹ nhàng giúp sinh viên nhận diện suy nghĩ tự động và chia nhỏ bước hành động. Trả lời tự nhiên (2-4 câu), ấm áp, gần gũi đúng văn hóa sinh viên Việt Nam.\n"
            "2. Tuyệt đối KHÔNG chẩn đoán bệnh lý, KHÔNG tự suy diễn điểm PHQ-9/GAD-7/DASS-21 từ hội thoại, KHÔNG kê đơn thuốc, KHÔNG tự nhận là bác sĩ/chuyên gia tâm lý, và KHÔNG nói rằng đã tự động đặt lịch hẹn.\n"
            "3. Nếu sinh viên chia sẻ dấu hiệu mất ngủ, mệt mỏi, lo âu, căng thẳng kéo dài, hãy đặt 'should_suggest_screening' = true để mời sinh viên tự nguyện tìm hiểu thang đo PHQ-9/GAD-7.\n"
            "4. Nếu sinh viên chia sẻ một sự kiện/mối bận tâm quan trọng mới (ví dụ: sắp bảo vệ đồ án, thi cuối kỳ môn Giải tích, áp lực học phí, mất ngủ nhiều ngày), hãy trích xuất 1 câu ngắn gọn vào 'memory_candidate' để ứng dụng xin phép sinh viên lưu lại.\n"
            "5. Gợi ý tối đa 3 'quick_replies' ngắn gọn, sát ngữ cảnh để sinh viên dễ bấm trả lời trên điện thoại."
        )

        contents_list: List[Dict[str, Any]] = []
        if payload.context_opt_in and payload.conversation_history:
            for turn in payload.conversation_history[-8:]:
                t_text = (turn.text or "").strip()
                if not t_text:
                    continue
                gemini_role = "model" if turn.role in ("assistant", "model") else "user"
                contents_list.append({"role": gemini_role, "parts": [{"text": t_text}]})
        contents_list.append({"role": "user", "parts": [{"text": payload.text}]})

        request_body = {
            "system_instruction": {"parts": [{"text": system_instruction}]},
            "contents": contents_list,
            "generationConfig": {
                "temperature": 0.7,
                "responseMimeType": "application/json",
                "responseSchema": {
                    "type": "OBJECT",
                    "properties": {
                        "reply": {"type": "STRING"},
                        "quick_replies": {
                            "type": "ARRAY",
                            "items": {"type": "STRING"},
                        },
                        "should_suggest_screening": {"type": "BOOLEAN"},
                        "memory_candidate": {"type": "STRING", "nullable": True},
                    },
                    "required": [
                        "reply",
                        "quick_replies",
                        "should_suggest_screening",
                    ],
                },
            },
        }

        for candidate_model in get_gemini_model_candidates():
            url = (
                f"https://generativelanguage.googleapis.com/v1beta/models/"
                f"{candidate_model}:generateContent"
            )
            try:
                resp = await _post_gemini_api(
                    url,
                    request_body,
                    headers={"x-goog-api-key": effective_key},
                )
                if resp.status_code == 200:
                    raw_text = resp.json()["candidates"][0]["content"]["parts"][0]["text"]
                    parsed = json.loads(raw_text)
                    safe_reply = _enforce_non_diagnostic_guardrail(
                        parsed.get("reply", ""), u_pro, ai_pro
                    )
                    mem_cand = parsed.get("memory_candidate")
                    proposal = None
                    if mem_cand and len(str(mem_cand).strip()) > 5:
                        proposal = {
                            "proposal_id": f"prop_{uuid.uuid4().hex[:8]}",
                            "candidate_text": str(mem_cand).strip(),
                            "status": "proposed",
                        }
                    should_screen = bool(parsed.get("should_suggest_screening", False))
                    return {
                        "reply": safe_reply,
                        "reply_type": "supportive_chat",
                        "quick_replies": (
                            parsed.get("quick_replies")
                            or [
                                "Kể thêm cho mình nghe",
                                "Thử bài tập CBT ngắn",
                                "Không, mình ổn",
                            ]
                        )[:3],
                        "should_suggest_screening": should_screen,
                        "suggested_action": "suggest_screening" if should_screen else None,
                        "memory_candidate": str(mem_cand).strip() if mem_cand else None,
                        "memory_proposal": proposal,
                        "provider_badge": f"Google Gemini ({candidate_model}) • CBT AI Companion",
                    }
                if resp.status_code in (400, 401, 403):
                    logger.warning(
                        "Gemini request rejected with HTTP %s; activating local CBT fallback.",
                        resp.status_code,
                    )
                    break
                logger.warning(
                    "Gemini model '%s' returned HTTP %s; trying next fallback model.",
                    candidate_model,
                    resp.status_code,
                )
            except Exception as exc:
                # Tuyệt đối không ghi log token, API key, PII hay nội dung chat
                logger.warning(
                    "Gemini model '%s' unavailable (%s); trying next fallback.",
                    candidate_model,
                    type(exc).__name__,
                )

    # 3. Kịch bản Người bạn số CBT đa ngữ cảnh Việt hóa (6 nhóm ý định)
    mem_hint = (
        f"({ai_pro.capitalize()} vẫn nhớ điều {u_pro} từng cho phép lưu: \"{payload.approved_memories[0]}\".) "
        if payload.context_opt_in and payload.approved_memories
        else ""
    )

    if any(w in lower for w in ["bài tập thở", "hít thở", "grounding", "thư giãn", "bài tập cbt"]):
        return {
            "reply": (
                f"Tuyệt lắm, {u_pro} cùng {ai_pro} ({payload.ai_nickname}) thả lỏng hai vai và thử 1 nhịp thở hộp 4-4-4-4 ngay nhé: "
                f"hít vào nhẹ bằng mũi 4 giây, giữ nhẹ 4 giây, thở ra chậm bằng miệng 4 giây và nghỉ 4 giây. "
                f"{u_pro.capitalize()} cũng có thể mở tab 'Cảm xúc' để bật đồng hồ nhịp thở trực quan hoặc điền Form CBT 3 bước cùng {ai_pro} nha!"
            ),
            "reply_type": "cbt_coaching",
            "quick_replies": [
                "Mình thấy dễ chịu hơn một chút rồi",
                "Mình muốn tháo gỡ suy nghĩ lo lắng",
                "Cảm ơn bạn nhiều nhé",
            ],
            "should_suggest_screening": False,
            "suggested_action": None,
            "memory_candidate": None,
            "memory_proposal": None,
            "provider_badge": "MindCheck Companion • Hướng dẫn CBT & Chánh niệm",
        }

    if any(w in lower for w in ["ngủ", "mệt", "áp lực", "thi", "lo", "buồn", "deadline", "đồ án", "kiệt sức"]):
        cand_text = f"Đang gặp áp lực học tập/thi cử ({payload.text.strip()[:55]})"
        prop_id = f"prop_{uuid.uuid4().hex[:8]}"
        return {
            "reply": (
                f"Cảm ơn {u_pro} đã tin tưởng tâm sự với {ai_pro}. {mem_hint}"
                f"Khi việc học tập và lịch thi dồn dập, cơ thể lẫn tâm trí đều rất dễ căng cứng và khó ngủ ngon. "
                f"Theo góc nhìn CBT, chúng mình có thể chia khối lượng bài vở thành từng chặng 25 phút thật nhỏ trước; "
                f"đồng thời {u_pro} có muốn thử bảng sàng lọc tự nguyện 2 phút để hiểu rõ hơn mức căng thẳng hiện tại không?"
            ),
            "reply_type": "supportive_chat",
            "quick_replies": [
                "Hướng dẫn mình chia nhỏ việc ôn bài",
                "Hướng dẫn mình bài tập thở",
                "Không, em ổn",
            ],
            "should_suggest_screening": True,
            "suggested_action": "suggest_screening",
            "memory_candidate": cand_text,
            "memory_proposal": {
                "proposal_id": prop_id,
                "candidate_text": cand_text,
                "status": "proposed",
            },
            "provider_badge": "MindCheck CBT Engine • Người bạn số Việt hóa",
        }

    if any(w in lower for w in ["cô đơn", "nhớ nhà", "bạn bè", "gia đình", "lạc lõng", "không ai hiểu"]):
        cand_text = f"Đang trăn trở về kết nối bạn bè/gia đình ({payload.text.strip()[:50]})"
        prop_id = f"prop_{uuid.uuid4().hex[:8]}"
        return {
            "reply": (
                f"{ai_pro.capitalize()} ở đây cùng {u_pro} nhé. {mem_hint}"
                f"Cảm giác lạc lõng giữa nhịp sống đại học là điều rất nhiều bạn sinh viên từng trải qua chứ không phải lỗi của {u_pro} đâu. "
                f"{u_pro.capitalize()} có muốn kể thêm điều gì vừa xảy ra khiến {u_pro} chạnh lòng nhất lúc này không?"
            ),
            "reply_type": "relationship_support",
            "quick_replies": [
                "Mình thấy hơi xa cách với mọi người",
                "Mình nhớ gia đình ở quê",
                "Hướng dẫn mình bài tập thở",
            ],
            "should_suggest_screening": False,
            "suggested_action": None,
            "memory_candidate": cand_text,
            "memory_proposal": {
                "proposal_id": prop_id,
                "candidate_text": cand_text,
                "status": "proposed",
            },
            "provider_badge": "MindCheck CBT Engine • Người bạn số Việt hóa",
        }

    if any(w in lower for w in ["học phí", "tài chính", "làm thêm", "tiền trọ", "chi tiêu"]):
        cand_text = f"Đang cân đối áp lực tài chính/việc làm thêm ({payload.text.strip()[:50]})"
        prop_id = f"prop_{uuid.uuid4().hex[:8]}"
        return {
            "reply": (
                f"Vừa xoay xở việc học trên giảng đường vừa lo chi phí hay đi làm thêm thực sự tốn rất nhiều năng lượng của {u_pro}. "
                f"{ai_pro.capitalize()} rất trân trọng sự nỗ lực bền bỉ đó. Chúng mình cùng tách riêng những khoản/việc {u_pro} kiểm soát được trong tuần này trước nhé?"
            ),
            "reply_type": "financial_stress_cbt",
            "quick_replies": [
                "Mình bị quá tải lịch học và làm thêm",
                "Hướng dẫn mình bài tập CBT",
                "Cảm ơn bạn đã lắng nghe",
            ],
            "should_suggest_screening": True,
            "suggested_action": "suggest_screening",
            "memory_candidate": cand_text,
            "memory_proposal": {
                "proposal_id": prop_id,
                "candidate_text": cand_text,
                "status": "proposed",
            },
            "provider_badge": "MindCheck CBT Engine • Người bạn số Việt hóa",
        }

    if any(w in lower for w in ["ổn", "cảm ơn", "dễ chịu", "vui", "tốt hơn", "đỡ hơn"]):
        return {
            "reply": (
                f"Nghe {u_pro} nói vậy {ai_pro} ({payload.ai_nickname}) mừng lắm! "
                f"Những bước chăm sóc tinh thần nhỏ mỗi ngày đều rất đáng ghi nhận. "
                f"Bất cứ khi nào {u_pro} cần một góc nhỏ yên tĩnh để trò chuyện hay ghi lại cảm xúc trong ngày, {ai_pro} luôn sẵn sàng ở đây nha."
            ),
            "reply_type": "positive_checkin",
            "quick_replies": [
                "Mình muốn check-in cảm xúc hôm nay",
                "Hướng dẫn mình bài tập thở",
                "Hẹn gặp lại bạn sau nhé",
            ],
            "should_suggest_screening": False,
            "suggested_action": None,
            "memory_candidate": None,
            "memory_proposal": None,
            "provider_badge": "MindCheck CBT Engine • Người bạn số Việt hóa",
        }

    return {
        "reply": (
            f"{ai_pro.capitalize()} ({payload.ai_nickname}) vẫn đang ở đây lắng nghe {u_pro} với sự {payload.ai_tone}. {mem_hint}"
            f"Hôm nay {u_pro} muốn tâm sự chuyện trường lớp, cùng {ai_pro} bóc tách một suy nghĩ đang làm {u_pro} bận tâm theo CBT, "
            f"hay thử 2 phút hít thở thư giãn?"
        ),
        "reply_type": "supportive_chat",
        "quick_replies": [
            "Dạ khá mệt, gần đây em ngủ không ngon giấc ạ.",
            "Mình đang lo thi cuối kỳ",
            "Hướng dẫn mình bài tập thở",
        ],
        "should_suggest_screening": False,
        "suggested_action": None,
        "memory_candidate": None,
        "memory_proposal": None,
        "provider_badge": "MindCheck CBT Engine • Người bạn số Việt hóa",
    }


# ============================================================================
# 1. AUTH, PROFILE, CONSENT & PERSONAL DATA CONTROL ENDPOINTS
# ============================================================================


@app.post("/v1/guest-sessions")
def create_guest_session(payload: GuestSessionCreateInput):
    if not payload.privacy_accepted:
        raise ApiError(
            status_code=400,
            code="PRIVACY_CONSENT_REQUIRED",
            message="Vui lòng chủ động xác nhận đồng ý Chính sách quyền riêng tư trước khi bắt đầu (T02).",
        )
    guest_id = f"guest_{uuid.uuid4().hex[:8]}"
    subject_id = f"sub_{uuid.uuid4().hex[:10]}"
    consent_id = f"con_{uuid.uuid4().hex[:8]}"
    ts = now_iso()

    with get_db() as conn:
        conn.execute(
            """
            INSERT INTO guest_sessions (guest_id, subject_id, created_at)
            VALUES (?, ?, ?)
            """,
            (guest_id, subject_id, ts),
        )
        conn.execute(
            """
            INSERT INTO consents (consent_id, subject_id, purpose, version, decision, created_at)
            VALUES (?, ?, 'privacy_policy', ?, 'accepted', ?)
            """,
            (consent_id, subject_id, payload.consent_version, ts),
        )
        session_token = issue_auth_token(
            conn,
            principal_id=guest_id,
            role="guest",
            subject_id=subject_id,
        )

    return {
        "guest_id": guest_id,
        "subject_id": subject_id,
        "consent_id": consent_id,
        "session_token": session_token,
        "privacy_accepted": True,
        "created_at": ts,
    }


@app.post("/v1/auth/signup")
def signup_account(payload: SignupInput):
    email = payload.email.strip().lower()
    if not _EMAIL_RE.match(email) or len(payload.password) < 6:
        raise ApiError(
            status_code=400,
            code="VALIDATION_FAILED",
            message="Email không hợp lệ hoặc mật khẩu dưới 6 ký tự.",
        )
    user_id = f"usr_{uuid.uuid4().hex[:8]}"
    ts = now_iso()
    with get_db() as conn:
        existing = conn.execute(
            "SELECT user_id FROM user_accounts WHERE email = ?", (email,)
        ).fetchone()
        if existing:
            raise ApiError(
                status_code=409,
                code="EMAIL_ALREADY_EXISTS",
                message="Email sinh viên này đã được đăng ký.",
            )
        conn.execute(
            """
            INSERT INTO user_accounts (user_id, email, password_hash, full_name, faculty, academic_year, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            (
                user_id,
                email,
                hash_password(payload.password),
                payload.full_name.strip(),
                payload.faculty,
                payload.academic_year,
                ts,
            ),
        )
        access_token = issue_auth_token(
            conn,
            principal_id=user_id,
            role="student",
            subject_id=f"sub_{user_id}",
            email=email,
        )
    return {
        "user_id": user_id,
        "email": email,
        "full_name": payload.full_name.strip(),
        "faculty": payload.faculty,
        "academic_year": payload.academic_year,
        "access_token": access_token,
        "created_at": ts,
    }


@app.post("/v1/auth/login")
def login_account(payload: LoginInput):
    email = payload.email.strip().lower()
    with get_db() as conn:
        row = conn.execute(
            "SELECT * FROM user_accounts WHERE email = ?", (email,)
        ).fetchone()
        if not row or not verify_password(payload.password, row["password_hash"]):
            raise ApiError(
                status_code=401,
                code="INVALID_CREDENTIALS",
                message="Email hoặc mật khẩu không chính xác.",
            )
        linked_guest = row["linked_guest_id"]
        bound_subject = f"sub_{row['user_id']}"
        if linked_guest:
            g_row = conn.execute(
                "SELECT subject_id FROM guest_sessions WHERE guest_id = ?",
                (linked_guest,),
            ).fetchone()
            if g_row:
                bound_subject = g_row["subject_id"]
        access_token = issue_auth_token(
            conn,
            principal_id=row["user_id"],
            role="student",
            subject_id=bound_subject,
            email=row["email"],
        )
    return {
        "user_id": row["user_id"],
        "email": row["email"],
        "full_name": row["full_name"],
        "faculty": row["faculty"],
        "academic_year": row["academic_year"],
        "linked_guest_id": row["linked_guest_id"],
        "subject_id": bound_subject,
        "access_token": access_token,
    }


@app.post("/v1/auth/staff-login")
def staff_login(payload: StaffLoginInput):
    staff_id = payload.staff_id.strip()
    with get_db() as conn:
        row = conn.execute(
            "SELECT * FROM staff_accounts WHERE staff_id = ?", (staff_id,)
        ).fetchone()
        if not row or not verify_password(payload.password, row["password_hash"]):
            log_audit_event(
                conn,
                actor=staff_id or "unknown_staff",
                action="STAFF_LOGIN_FAILED",
                target="StaffAuth",
                result="DENIED_INVALID_CREDENTIALS",
            )
            raise ApiError(
                status_code=401,
                code="INVALID_STAFF_CREDENTIALS",
                message="Thông tin đăng nhập nhân sự không chính xác hoặc tài khoản chưa được kích hoạt.",
            )
        is_active = bool(row["is_active"]) if "is_active" in row.keys() else True
        if not is_active:
            log_audit_event(
                conn,
                actor=staff_id,
                action="STAFF_LOGIN_DISABLED_ACCOUNT",
                target="StaffAuth",
                result="DENIED_ACCOUNT_DISABLED",
            )
            raise ApiError(
                status_code=403,
                code="STAFF_ACCOUNT_DISABLED",
                message="Tài khoản nhân sự này hiện đang bị tạm khóa bởi Quản trị viên.",
            )
        token = issue_auth_token(
            conn,
            principal_id=row["staff_id"],
            role=row["role"],
        )
        log_audit_event(
            conn,
            actor=row["staff_id"],
            action=f"STAFF_LOGIN ({row['role']})",
            target="StaffAuth",
            result="SUCCESS",
        )
    return {
        "staff_id": row["staff_id"],
        "role": row["role"],
        "display_name": row["display_name"],
        "unit_name": (
            row["unit_name"]
            if "unit_name" in row.keys()
            else "Phòng Công tác Sinh viên & Tư vấn"
        ),
        "access_token": token,
    }


@app.post("/v1/guest-sessions/link")
def link_guest_session(
    payload: LinkGuestSessionInput,
    authorization: str = Header(default=""),
):
    guest_id = payload.guest_id.strip()
    if not guest_id:
        raise ApiError(
            status_code=400,
            code="VALIDATION_FAILED",
            message="guest_id không được để trống.",
        )

    with get_db() as conn:
        session = resolve_bearer_session(conn, authorization)
        if session and session["role"] in ("ctsv", "counselor", "admin"):
            raise ApiError(
                status_code=403,
                code="FORBIDDEN_ROLE",
                message="Nhân sự không được thực hiện liên kết tài khoản sinh viên.",
            )

        g_row = conn.execute(
            "SELECT * FROM guest_sessions WHERE guest_id = ? OR subject_id = ?",
            (guest_id, guest_id),
        ).fetchone()
        effective_subject = g_row["subject_id"] if g_row else guest_id

        target_user_id = (payload.user_id or "").strip()
        if session and session["role"] == "student":
            if target_user_id and target_user_id != session["principal_id"]:
                raise ApiError(
                    status_code=403,
                    code="FORBIDDEN_CROSS_USER_ACCESS",
                    message="Không thể liên kết phiên ẩn danh vào tài khoản của sinh viên khác.",
                )
            target_user_id = session["principal_id"]

        if target_user_id:
            u_row = conn.execute(
                "SELECT user_id FROM user_accounts WHERE user_id = ?",
                (target_user_id,),
            ).fetchone()
            if not u_row:
                raise ApiError(
                    status_code=404,
                    code="USER_NOT_FOUND",
                    message="Không tìm thấy tài khoản sinh viên cần liên kết.",
                )

        if payload.consent_id:
            consent_row = verify_consent(
                conn,
                payload.consent_id,
                expected_purpose="guest_session_link",
                allowed_subject_ids=[guest_id, effective_subject],
            )
            consent_id = consent_row["consent_id"]
        elif payload.consent_to_link:
            consent_id = f"con_{uuid.uuid4().hex[:8]}"
            conn.execute(
                """
                INSERT INTO consents (consent_id, subject_id, purpose, version, decision, created_at)
                VALUES (?, ?, 'guest_session_link', 'v1.0-2026', 'accepted', ?)
                """,
                (consent_id, effective_subject, now_iso()),
            )
        else:
            raise ApiError(
                status_code=403,
                code="CONSENT_REQUIRED",
                message="Cần sự đồng ý rõ ràng của sinh viên để liên kết dữ liệu phiên ẩn danh vào tài khoản (F03, R2).",
            )

        if target_user_id:
            conn.execute(
                "UPDATE user_accounts SET linked_guest_id = ? WHERE user_id = ?",
                (guest_id, target_user_id),
            )

    return {
        "linked": True,
        "guest_id": guest_id,
        "subject_id": effective_subject,
        "user_id": target_user_id or None,
        "consent_id": consent_id,
        "linked_at": now_iso(),
    }


@app.get("/v1/me/companion-preferences")
def get_companion_preferences(
    authorization: str = Header(default=""),
    x_subject_id: str = Header(default=""),
    x_staff_id: str = Header(default=""),
    x_staff_role: str = Header(default=""),
    x_admin_actor: str = Header(default=""),
):
    with get_db() as conn:
        subj = guard_personal_clinical_access(
            conn,
            target="CompanionPreferences",
            authorization=authorization,
            x_subject_id=x_subject_id,
            x_staff_id=x_staff_id,
            x_staff_role=x_staff_role,
            x_admin_actor=x_admin_actor,
        ) or "sub_default"
        row = ensure_guest_row(conn, subj)
        return {
            "subject_id": row["subject_id"],
            "nickname": row["companion_nickname"],
            "user_pronoun": row["user_pronoun"],
            "ai_pronoun": row["ai_pronoun"],
            "tone": row["ai_tone"],
        }


@app.put("/v1/me/companion-preferences")
def update_companion_preferences(
    payload: CompanionPrefInput,
    authorization: str = Header(default=""),
    x_subject_id: str = Header(default=""),
    x_staff_id: str = Header(default=""),
    x_staff_role: str = Header(default=""),
    x_admin_actor: str = Header(default=""),
):
    if not payload.nickname.strip():
        raise ApiError(
            status_code=400,
            code="VALIDATION_FAILED",
            message="Tên gọi bạn đồng hành AI không được để trống.",
        )
    with get_db() as conn:
        subj = guard_personal_clinical_access(
            conn,
            target="CompanionPreferences",
            authorization=authorization,
            x_subject_id=x_subject_id,
            x_staff_id=x_staff_id,
            x_staff_role=x_staff_role,
            x_admin_actor=x_admin_actor,
        ) or "sub_default"
        row = ensure_guest_row(conn, subj)
        conn.execute(
            """
            UPDATE guest_sessions
            SET companion_nickname = ?, user_pronoun = ?, ai_pronoun = ?, ai_tone = ?
            WHERE subject_id = ?
            """,
            (
                payload.nickname.strip(),
                payload.user_pronoun.strip(),
                payload.ai_pronoun.strip(),
                payload.tone.strip(),
                row["subject_id"],
            ),
        )
    return {
        "subject_id": subj,
        "nickname": payload.nickname.strip(),
        "user_pronoun": payload.user_pronoun.strip(),
        "ai_pronoun": payload.ai_pronoun.strip(),
        "tone": payload.tone.strip(),
        "updated_at": now_iso(),
    }


@app.get("/v1/me/notification-preferences")
def get_notification_preferences(
    authorization: str = Header(default=""),
    x_subject_id: str = Header(default=""),
    x_staff_id: str = Header(default=""),
    x_staff_role: str = Header(default=""),
    x_admin_actor: str = Header(default=""),
):
    with get_db() as conn:
        subj = guard_personal_clinical_access(
            conn,
            target="NotificationPreferences",
            authorization=authorization,
            x_subject_id=x_subject_id,
            x_staff_id=x_staff_id,
            x_staff_role=x_staff_role,
            x_admin_actor=x_admin_actor,
        ) or "sub_default"
        row = ensure_guest_row(conn, subj)
        return {
            "subject_id": row["subject_id"],
            "enabled": bool(row["notif_enabled"]),
            "reminder_time": row["reminder_time"],
            "quiet_hours": row["quiet_hours"],
            "hide_sensitive_on_lock_screen": bool(row["hide_sensitive_lockscreen"]),
        }


@app.put("/v1/me/notification-preferences")
def update_notification_preferences(
    payload: NotificationPrefInput,
    authorization: str = Header(default=""),
    x_subject_id: str = Header(default=""),
    x_staff_id: str = Header(default=""),
    x_staff_role: str = Header(default=""),
    x_admin_actor: str = Header(default=""),
):
    with get_db() as conn:
        subj = guard_personal_clinical_access(
            conn,
            target="NotificationPreferences",
            authorization=authorization,
            x_subject_id=x_subject_id,
            x_staff_id=x_staff_id,
            x_staff_role=x_staff_role,
            x_admin_actor=x_admin_actor,
        ) or "sub_default"
        row = ensure_guest_row(conn, subj)
        conn.execute(
            """
            UPDATE guest_sessions
            SET notif_enabled = ?, reminder_time = ?, quiet_hours = ?, hide_sensitive_lockscreen = ?
            WHERE subject_id = ?
            """,
            (
                1 if payload.enabled else 0,
                payload.reminder_time.strip(),
                payload.quiet_hours.strip(),
                1 if payload.hide_sensitive_on_lock_screen else 0,
                row["subject_id"],
            ),
        )
    return {
        "subject_id": subj,
        "enabled": payload.enabled,
        "reminder_time": payload.reminder_time.strip(),
        "quiet_hours": payload.quiet_hours.strip(),
        "hide_sensitive_on_lock_screen": payload.hide_sensitive_on_lock_screen,
        "updated_at": now_iso(),
    }


VALID_CONSENT_PURPOSES = (
    "privacy_policy",
    "guest_session_link",
    "ai_memory",
    "screening",
    "counseling_share",
)


@app.post("/v1/consents")
def record_consent(
    payload: ConsentCreateInput,
    authorization: str = Header(default=""),
    x_subject_id: str = Header(default=""),
    x_staff_id: str = Header(default=""),
    x_staff_role: str = Header(default=""),
    x_admin_actor: str = Header(default=""),
):
    if payload.decision not in ("accepted", "declined", "revoked"):
        raise ApiError(
            status_code=400,
            code="EXPLICIT_DECISION_REQUIRED",
            message="Phải chỉ định rõ decision là 'accepted', 'declined' hoặc 'revoked' (T02).",
        )
    purpose = payload.purpose.strip()
    if purpose not in VALID_CONSENT_PURPOSES:
        raise ApiError(
            status_code=400,
            code="INVALID_CONSENT_PURPOSE",
            message=f"Mục đích consent không hợp lệ. Chọn một trong: {', '.join(VALID_CONSENT_PURPOSES)}.",
        )
    consent_id = f"con_{uuid.uuid4().hex[:8]}"
    ts = now_iso()
    with get_db() as conn:
        subj = guard_personal_clinical_access(
            conn,
            target="Consents",
            authorization=authorization,
            x_subject_id=x_subject_id,
            explicit_subject_id=payload.subject_id,
            x_staff_id=x_staff_id,
            x_staff_role=x_staff_role,
            x_admin_actor=x_admin_actor,
        ) or payload.subject_id
        conn.execute(
            """
            INSERT INTO consents (consent_id, subject_id, purpose, version, decision, created_at)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            (consent_id, subj, purpose, payload.version, payload.decision, ts),
        )
    return {
        "consent_id": consent_id,
        "subject_id": subj,
        "purpose": purpose,
        "version": payload.version,
        "decision": payload.decision,
        "timestamp": ts,
    }


@app.get("/v1/consents")
def list_my_consents(
    subject_id: Optional[str] = Query(default=None),
    authorization: str = Header(default=""),
    x_subject_id: str = Header(default=""),
    x_staff_id: str = Header(default=""),
    x_staff_role: str = Header(default=""),
    x_admin_actor: str = Header(default=""),
):
    with get_db() as conn:
        subj = guard_personal_clinical_access(
            conn,
            target="Consents",
            authorization=authorization,
            x_subject_id=x_subject_id,
            explicit_subject_id=subject_id,
            x_staff_id=x_staff_id,
            x_staff_role=x_staff_role,
            x_admin_actor=x_admin_actor,
            require_subject=True,
        )
        rows = conn.execute(
            "SELECT * FROM consents WHERE subject_id = ? ORDER BY created_at DESC",
            (subj,),
        ).fetchall()
        return {
            "subject_id": subj,
            "items": [
                {
                    "consent_id": r["consent_id"],
                    "purpose": r["purpose"],
                    "version": r["version"],
                    "decision": r["decision"],
                    "timestamp": r["created_at"],
                }
                for r in rows
            ],
        }


@app.delete("/v1/me/data")
def erase_personal_clinical_data(
    subject_id: Optional[str] = Query(default=None),
    authorization: str = Header(default=""),
    x_subject_id: str = Header(default=""),
    x_staff_id: str = Header(default=""),
    x_staff_role: str = Header(default=""),
    x_admin_actor: str = Header(default=""),
):
    """F06 & S30 (T32): Quyền tự xóa toàn bộ dữ liệu lâm sàng cá nhân của chính sinh viên."""
    with get_db() as conn:
        subj = guard_personal_clinical_access(
            conn,
            target="ErasePersonalData",
            authorization=authorization,
            x_subject_id=x_subject_id,
            explicit_subject_id=subject_id,
            x_staff_id=x_staff_id,
            x_staff_role=x_staff_role,
            x_admin_actor=x_admin_actor,
            require_subject=True,
        )
        session_ids = [
            r["session_id"]
            for r in conn.execute(
                "SELECT session_id FROM chat_sessions WHERE subject_id = ?", (subj,)
            ).fetchall()
        ]
        for sid in session_ids:
            conn.execute("DELETE FROM chat_messages WHERE session_id = ?", (sid,))
        conn.execute("DELETE FROM chat_sessions WHERE subject_id = ?", (subj,))
        conn.execute("DELETE FROM memory_proposals WHERE subject_id = ?", (subj,))
        conn.execute("DELETE FROM approved_memories WHERE subject_id = ?", (subj,))
        conn.execute("DELETE FROM mood_entries WHERE subject_id = ?", (subj,))
        conn.execute("DELETE FROM activity_progress WHERE subject_id = ?", (subj,))
        conn.execute("DELETE FROM screening_sessions WHERE subject_id = ?", (subj,))
        conn.execute(
            "UPDATE consents SET decision = 'revoked' WHERE subject_id = ? AND decision = 'accepted'",
            (subj,),
        )
        log_audit_event(
            conn,
            actor="student_self_service",
            action="ERASE_PERSONAL_CLINICAL_DATA (F06)",
            target="Anon_Clinical_Subject",
            result="SUCCESS",
        )
    return {
        "erased": True,
        "subject_id": subj,
        "erased_at": now_iso(),
    }


# ============================================================================
# 2. CHAT & MEMORY ENDPOINTS (T05, T07-T09 + OWNERSHIP PROTECTION)
# ============================================================================


@app.get("/v1/chats")
def list_chat_sessions(
    subject_id: Optional[str] = Query(default=None),
    authorization: str = Header(default=""),
    x_subject_id: str = Header(default=""),
    x_staff_id: str = Header(default=""),
    x_staff_role: str = Header(default=""),
    x_admin_actor: str = Header(default=""),
):
    with get_db() as conn:
        subj = guard_personal_clinical_access(
            conn,
            target="ChatSessions",
            authorization=authorization,
            x_subject_id=x_subject_id,
            explicit_subject_id=subject_id,
            x_staff_id=x_staff_id,
            x_staff_role=x_staff_role,
            x_admin_actor=x_admin_actor,
            require_subject=True,
        )
        rows = conn.execute(
            "SELECT * FROM chat_sessions WHERE subject_id = ? ORDER BY started_at DESC",
            (subj,),
        ).fetchall()
        return {
            "items": [
                {
                    "session_id": r["session_id"],
                    "subject_id": r["subject_id"],
                    "title": r["title"],
                    "started_at": r["started_at"],
                }
                for r in rows
            ]
        }


@app.post("/v1/chats")
def create_chat_session(
    payload: ChatCreateInput,
    authorization: str = Header(default=""),
    x_subject_id: str = Header(default=""),
    x_staff_id: str = Header(default=""),
    x_staff_role: str = Header(default=""),
    x_admin_actor: str = Header(default=""),
):
    session_id = f"chat_{uuid.uuid4().hex[:8]}"
    ts = now_iso()
    title = (payload.title or "").strip() or "Cuộc trò chuyện đồng hành mới"
    with get_db() as conn:
        subj = guard_personal_clinical_access(
            conn,
            target="CreateChatSession",
            authorization=authorization,
            x_subject_id=x_subject_id,
            explicit_subject_id=payload.subject_id,
            x_staff_id=x_staff_id,
            x_staff_role=x_staff_role,
            x_admin_actor=x_admin_actor,
        ) or payload.subject_id
        conn.execute(
            """
            INSERT INTO chat_sessions (session_id, subject_id, title, started_at)
            VALUES (?, ?, ?, ?)
            """,
            (session_id, subj, title, ts),
        )
    return {
        "session_id": session_id,
        "subject_id": subj,
        "title": title,
        "started_at": ts,
    }


@app.patch("/v1/chats/{chat_id}")
def rename_chat_session(
    chat_id: str,
    payload: ChatSessionRenameInput,
    subject_id: Optional[str] = Query(default=None),
    authorization: str = Header(default=""),
    x_subject_id: str = Header(default=""),
    x_staff_id: str = Header(default=""),
    x_staff_role: str = Header(default=""),
    x_admin_actor: str = Header(default=""),
):
    new_title = payload.title.strip()
    if not new_title:
        raise ApiError(
            status_code=400,
            code="VALIDATION_FAILED",
            message="Tiêu đề cuộc trò chuyện không được để trống.",
        )
    with get_db() as conn:
        caller_subj = guard_personal_clinical_access(
            conn,
            target=f"ChatSession:{chat_id}",
            authorization=authorization,
            x_subject_id=x_subject_id,
            explicit_subject_id=subject_id,
            x_staff_id=x_staff_id,
            x_staff_role=x_staff_role,
            x_admin_actor=x_admin_actor,
            require_subject=True,
        )
        sess = conn.execute(
            "SELECT * FROM chat_sessions WHERE session_id = ?", (chat_id,)
        ).fetchone()
        if not sess:
            raise ApiError(
                status_code=404,
                code="CHAT_SESSION_NOT_FOUND",
                message="Không tìm thấy phiên trò chuyện.",
            )
        assert_resource_owner(sess["subject_id"], caller_subj)
        conn.execute(
            "UPDATE chat_sessions SET title = ? WHERE session_id = ?",
            (new_title, chat_id),
        )
    return {
        "session_id": chat_id,
        "subject_id": caller_subj,
        "title": new_title,
        "updated_at": now_iso(),
    }


@app.delete("/v1/chats/{chat_id}")
def delete_chat_session(
    chat_id: str,
    subject_id: Optional[str] = Query(default=None),
    authorization: str = Header(default=""),
    x_subject_id: str = Header(default=""),
    x_staff_id: str = Header(default=""),
    x_staff_role: str = Header(default=""),
    x_admin_actor: str = Header(default=""),
):
    with get_db() as conn:
        caller_subj = guard_personal_clinical_access(
            conn,
            target=f"ChatSession:{chat_id}",
            authorization=authorization,
            x_subject_id=x_subject_id,
            explicit_subject_id=subject_id,
            x_staff_id=x_staff_id,
            x_staff_role=x_staff_role,
            x_admin_actor=x_admin_actor,
            require_subject=True,
        )
        sess = conn.execute(
            "SELECT * FROM chat_sessions WHERE session_id = ?", (chat_id,)
        ).fetchone()
        if not sess:
            raise ApiError(
                status_code=404,
                code="CHAT_SESSION_NOT_FOUND",
                message="Không tìm thấy phiên trò chuyện.",
            )
        assert_resource_owner(sess["subject_id"], caller_subj)
        conn.execute("DELETE FROM chat_messages WHERE session_id = ?", (chat_id,))
        conn.execute("DELETE FROM chat_sessions WHERE session_id = ?", (chat_id,))
    return {"deleted": True, "session_id": chat_id}


@app.get("/v1/chats/{chat_id}/messages")
def list_chat_messages(
    chat_id: str,
    subject_id: Optional[str] = Query(default=None),
    authorization: str = Header(default=""),
    x_subject_id: str = Header(default=""),
    x_staff_id: str = Header(default=""),
    x_staff_role: str = Header(default=""),
    x_admin_actor: str = Header(default=""),
):
    with get_db() as conn:
        caller_subj = guard_personal_clinical_access(
            conn,
            target=f"ChatMessages:{chat_id}",
            authorization=authorization,
            x_subject_id=x_subject_id,
            explicit_subject_id=subject_id,
            x_staff_id=x_staff_id,
            x_staff_role=x_staff_role,
            x_admin_actor=x_admin_actor,
            require_subject=True,
        )
        sess = conn.execute(
            "SELECT * FROM chat_sessions WHERE session_id = ?", (chat_id,)
        ).fetchone()
        if not sess:
            raise ApiError(
                status_code=404,
                code="CHAT_SESSION_NOT_FOUND",
                message="Không tìm thấy phiên trò chuyện.",
            )
        assert_resource_owner(sess["subject_id"], caller_subj)

        rows = conn.execute(
            "SELECT * FROM chat_messages WHERE session_id = ? ORDER BY created_at ASC",
            (chat_id,),
        ).fetchall()
        items = []
        for r in rows:
            cached = {}
            if r["response_cache_json"]:
                try:
                    cached = json.loads(r["response_cache_json"])
                except Exception:
                    cached = {}
            items.append(
                {
                    "message_id": r["message_id"],
                    "client_message_id": r["client_message_id"],
                    "session_id": r["session_id"],
                    "user_text": r["text"],
                    "assistant_reply": cached.get("reply", ""),
                    "reply_type": r["reply_type"],
                    "quick_replies": json.loads(r["quick_replies_json"] or "[]"),
                    "suggested_action": r["suggested_action"],
                    "provider_badge": r["provider_badge"],
                    "created_at": r["created_at"],
                }
            )
        return {"session_id": chat_id, "items": items}


@app.post("/v1/chats/{chat_id}/messages")
async def send_chat_message(
    chat_id: str,
    payload: ChatMessageInput,
    x_gemini_key: str = Header(default=""),
    authorization: str = Header(default=""),
    x_subject_id: str = Header(default=""),
    x_staff_id: str = Header(default=""),
    x_staff_role: str = Header(default=""),
    x_admin_actor: str = Header(default=""),
):
    if not payload.text.strip() or not payload.client_message_id.strip():
        raise ApiError(
            status_code=400,
            code="VALIDATION_FAILED",
            message="Tin nhắn và client_message_id không được để trống.",
        )

    with get_db() as conn:
        effective_subj = guard_personal_clinical_access(
            conn,
            target=f"SendChatMessage:{chat_id}",
            authorization=authorization,
            x_subject_id=x_subject_id,
            explicit_subject_id=payload.subject_id,
            x_staff_id=x_staff_id,
            x_staff_role=x_staff_role,
            x_admin_actor=x_admin_actor,
        ) or payload.subject_id
        payload.subject_id = effective_subj

        # Kiểm tra quyền sở hữu phiên chat nếu phiên đã tồn tại
        sess = conn.execute(
            "SELECT session_id, subject_id FROM chat_sessions WHERE session_id = ?",
            (chat_id,),
        ).fetchone()
        if sess and sess["subject_id"] != effective_subj:
            raise ApiError(
                status_code=403,
                code="FORBIDDEN_CROSS_USER_ACCESS",
                message="Không được phép gửi tin nhắn vào phiên trò chuyện của người dùng khác.",
            )

        # T05: Kiểm tra client_message_id chống trùng lặp trong SQLite
        dup = conn.execute(
            """
            SELECT m.response_cache_json, s.subject_id
            FROM chat_messages m
            JOIN chat_sessions s ON s.session_id = m.session_id
            WHERE m.client_message_id = ?
            """,
            (payload.client_message_id.strip(),),
        ).fetchone()
        if dup:
            if dup["subject_id"] != effective_subj:
                raise ApiError(
                    status_code=409,
                    code="DUPLICATE_CLIENT_MESSAGE_ID",
                    message="client_message_id đã tồn tại.",
                )
            if dup["response_cache_json"]:
                cached = json.loads(dup["response_cache_json"])
                cached["idempotent_replay"] = True
                return cached

        if not sess:
            conn.execute(
                "INSERT INTO chat_sessions (session_id, subject_id, title, started_at) VALUES (?, ?, ?, ?)",
                (chat_id, effective_subj, "Cuộc trò chuyện đồng hành", now_iso()),
            )

        if not payload.approved_memories and payload.context_opt_in:
            mem_rows = conn.execute(
                "SELECT text FROM approved_memories WHERE subject_id = ? ORDER BY updated_at DESC",
                (effective_subj,),
            ).fetchall()
            payload.approved_memories = [r["text"] for r in mem_rows]

        if not payload.conversation_history and payload.context_opt_in:
            hist_rows = conn.execute(
                """
                SELECT text, response_cache_json FROM chat_messages
                WHERE session_id = ? ORDER BY created_at DESC LIMIT 4
                """,
                (chat_id,),
            ).fetchall()
            reconstructed: List[ChatTurnItem] = []
            for hr in reversed(hist_rows):
                reconstructed.append(ChatTurnItem(role="user", text=hr["text"]))
                if hr["response_cache_json"]:
                    try:
                        c_data = json.loads(hr["response_cache_json"])
                        if c_data.get("reply"):
                            reconstructed.append(
                                ChatTurnItem(role="assistant", text=c_data["reply"])
                            )
                    except Exception:
                        pass
            payload.conversation_history = reconstructed

    ai_out = await call_gemini_cbt_engine(payload, x_gemini_key)
    msg_id = f"msg_{uuid.uuid4().hex[:8]}"
    ts = now_iso()

    response = {
        "message_id": msg_id,
        "client_message_id": payload.client_message_id.strip(),
        "session_id": chat_id,
        "reply": ai_out["reply"],
        "reply_type": ai_out["reply_type"],
        "quick_replies": ai_out["quick_replies"],
        "should_suggest_screening": ai_out["should_suggest_screening"],
        "suggested_action": ai_out["suggested_action"],
        "memory_candidate": ai_out["memory_candidate"],
        "memory_proposal": ai_out["memory_proposal"],
        "provider_badge": ai_out["provider_badge"],
        "requires_confirmation": ai_out["memory_proposal"] is not None,
        "is_clinical_diagnosis": False,
        "demo": is_seed_demo_enabled(),
        "created_at": ts,
    }

    with get_db() as conn:
        conn.execute(
            """
            INSERT INTO chat_messages (
                message_id, client_message_id, session_id, role, text,
                reply_type, quick_replies_json, suggested_action, provider_badge,
                response_cache_json, created_at
            ) VALUES (?, ?, ?, 'user_and_assistant', ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                msg_id,
                payload.client_message_id.strip(),
                chat_id,
                payload.text.strip(),
                ai_out["reply_type"],
                json.dumps(ai_out["quick_replies"], ensure_ascii=False),
                ai_out["suggested_action"],
                ai_out["provider_badge"],
                json.dumps(response, ensure_ascii=False),
                ts,
            ),
        )

        # Lưu memory_proposal ở trạng thái 'proposed' (chưa thành approved_memory khi chưa có consent T07)
        if ai_out["memory_proposal"]:
            prop = ai_out["memory_proposal"]
            conn.execute(
                """
                INSERT INTO memory_proposals (proposal_id, subject_id, source_message_id, candidate_text, status, created_at)
                VALUES (?, ?, ?, ?, 'proposed', ?)
                """,
                (
                    prop["proposal_id"],
                    payload.subject_id,
                    msg_id,
                    prop["candidate_text"],
                    ts,
                ),
            )

    return response


@app.post("/v1/memories/{proposal_id}/approve")
def approve_or_reject_memory(
    proposal_id: str,
    payload: MemoryApproveInput,
    authorization: str = Header(default=""),
    x_subject_id: str = Header(default=""),
    x_staff_id: str = Header(default=""),
    x_staff_role: str = Header(default=""),
    x_admin_actor: str = Header(default=""),
):
    if payload.decision not in ("accepted", "approved", "rejected", "declined"):
        raise ApiError(
            status_code=400,
            code="EXPLICIT_DECISION_REQUIRED",
            message="Phải chỉ định rõ decision là 'accepted'/'approved' hoặc 'rejected'/'declined' (R2).",
        )
    is_accepted = payload.decision in ("accepted", "approved")
    ts = now_iso()

    with get_db() as conn:
        caller_subj = guard_personal_clinical_access(
            conn,
            target=f"ApproveMemory:{proposal_id}",
            authorization=authorization,
            x_subject_id=x_subject_id,
            explicit_subject_id=payload.subject_id,
            x_staff_id=x_staff_id,
            x_staff_role=x_staff_role,
            x_admin_actor=x_admin_actor,
        ) or payload.subject_id

        prop_row = conn.execute(
            "SELECT * FROM memory_proposals WHERE proposal_id = ?", (proposal_id,)
        ).fetchone()
        if prop_row and prop_row["subject_id"] != caller_subj:
            raise ApiError(
                status_code=403,
                code="FORBIDDEN_CROSS_USER_ACCESS",
                message="Không được phép phê duyệt đề xuất trí nhớ của người dùng khác.",
            )

        candidate_text = (
            (payload.candidate_text or "").strip()
            or (prop_row["candidate_text"] if prop_row else "")
        )
        subject_id = prop_row["subject_id"] if prop_row else caller_subj

        if not is_accepted:
            consent_id = f"con_{uuid.uuid4().hex[:8]}"
            conn.execute(
                """
                INSERT INTO consents (consent_id, subject_id, purpose, version, decision, created_at)
                VALUES (?, ?, 'ai_memory', 'v1.0-2026', 'declined', ?)
                """,
                (consent_id, subject_id, ts),
            )
            if prop_row:
                conn.execute(
                    "UPDATE memory_proposals SET status = 'rejected' WHERE proposal_id = ?",
                    (proposal_id,),
                )
            return {
                "proposal_id": proposal_id,
                "status": "rejected",
                "consent_id": consent_id,
                "approved_memory": None,
            }

        if not candidate_text:
            raise ApiError(
                status_code=404,
                code="PROPOSAL_NOT_FOUND",
                message="Không tìm thấy đề xuất trí nhớ để phê duyệt.",
            )

        # Kiểm tra hoặc ghi nhận bản ghi Consent cho AI Memory (R2, F10, T07)
        if payload.consent_id:
            verify_consent(
                conn,
                payload.consent_id,
                expected_purpose="ai_memory",
                expected_subject_id=subject_id,
            )
            consent_id = payload.consent_id.strip()
        else:
            consent_id = f"con_{uuid.uuid4().hex[:8]}"
            conn.execute(
                """
                INSERT INTO consents (consent_id, subject_id, purpose, version, decision, created_at)
                VALUES (?, ?, 'ai_memory', 'v1.0-2026', 'accepted', ?)
                """,
                (consent_id, subject_id, ts),
            )

        if prop_row:
            conn.execute(
                "UPDATE memory_proposals SET status = 'approved' WHERE proposal_id = ?",
                (proposal_id,),
            )

        memory_id = f"mem_{uuid.uuid4().hex[:8]}"
        conn.execute(
            """
            INSERT INTO approved_memories (memory_id, subject_id, proposal_id, consent_id, text, updated_at)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            (memory_id, subject_id, proposal_id, consent_id, candidate_text, ts),
        )

    return {
        "proposal_id": proposal_id,
        "status": "approved",
        "consent_id": consent_id,
        "approved_memory": {
            "memory_id": memory_id,
            "subject_id": subject_id,
            "text": candidate_text,
            "updated_at": ts,
        },
    }


@app.post("/v1/memories")
def create_manual_approved_memory(
    payload: ManualMemoryCreateInput,
    authorization: str = Header(default=""),
    x_subject_id: str = Header(default=""),
    x_staff_id: str = Header(default=""),
    x_staff_role: str = Header(default=""),
    x_admin_actor: str = Header(default=""),
):
    text = payload.text.strip()
    if not text:
        raise ApiError(
            status_code=400,
            code="VALIDATION_FAILED",
            message="Nội dung trí nhớ không được để trống.",
        )
    ts = now_iso()
    memory_id = f"mem_{uuid.uuid4().hex[:8]}"
    with get_db() as conn:
        subj = guard_personal_clinical_access(
            conn,
            target="CreateManualMemory",
            authorization=authorization,
            x_subject_id=x_subject_id,
            explicit_subject_id=payload.subject_id,
            x_staff_id=x_staff_id,
            x_staff_role=x_staff_role,
            x_admin_actor=x_admin_actor,
        ) or payload.subject_id

        if payload.consent_id:
            verify_consent(
                conn,
                payload.consent_id,
                expected_purpose="ai_memory",
                expected_subject_id=subj,
            )
            consent_id = payload.consent_id.strip()
        elif payload.consent_accepted:
            consent_id = f"con_{uuid.uuid4().hex[:8]}"
            conn.execute(
                """
                INSERT INTO consents (consent_id, subject_id, purpose, version, decision, created_at)
                VALUES (?, ?, 'ai_memory', 'v1.0-2026', 'accepted', ?)
                """,
                (consent_id, subj, ts),
            )
        else:
            raise ApiError(
                status_code=403,
                code="CONSENT_REQUIRED",
                message="Lưu Trí nhớ AI bắt buộc phải có bản ghi consent 'ai_memory' hoặc xác nhận đồng ý rõ ràng (F10, R2).",
            )

        conn.execute(
            """
            INSERT INTO approved_memories (memory_id, subject_id, proposal_id, consent_id, text, updated_at)
            VALUES (?, ?, NULL, ?, ?, ?)
            """,
            (memory_id, subj, consent_id, text, ts),
        )
    return {
        "memory_id": memory_id,
        "subject_id": subj,
        "consent_id": consent_id,
        "text": text,
        "updated_at": ts,
    }


@app.get("/v1/memories")
def list_approved_memories(
    subject_id: Optional[str] = Query(default=None),
    authorization: str = Header(default=""),
    x_subject_id: str = Header(default=""),
    x_staff_id: str = Header(default=""),
    x_staff_role: str = Header(default=""),
    x_admin_actor: str = Header(default=""),
):
    with get_db() as conn:
        subj = guard_personal_clinical_access(
            conn,
            target="ListMemories",
            authorization=authorization,
            x_subject_id=x_subject_id,
            explicit_subject_id=subject_id,
            x_staff_id=x_staff_id,
            x_staff_role=x_staff_role,
            x_admin_actor=x_admin_actor,
            require_subject=True,
        )
        rows = conn.execute(
            "SELECT * FROM approved_memories WHERE subject_id = ? ORDER BY updated_at DESC",
            (subj,),
        ).fetchall()
        return {
            "items": [
                {
                    "memory_id": r["memory_id"],
                    "subject_id": r["subject_id"],
                    "proposal_id": r["proposal_id"],
                    "consent_id": r["consent_id"],
                    "text": r["text"],
                    "updated_at": r["updated_at"],
                }
                for r in rows
            ]
        }


@app.get("/v1/memories/{memory_id}")
def get_approved_memory(
    memory_id: str,
    subject_id: Optional[str] = Query(default=None),
    authorization: str = Header(default=""),
    x_subject_id: str = Header(default=""),
    x_staff_id: str = Header(default=""),
    x_staff_role: str = Header(default=""),
    x_admin_actor: str = Header(default=""),
):
    with get_db() as conn:
        caller_subj = guard_personal_clinical_access(
            conn,
            target=f"GetMemory:{memory_id}",
            authorization=authorization,
            x_subject_id=x_subject_id,
            explicit_subject_id=subject_id,
            x_staff_id=x_staff_id,
            x_staff_role=x_staff_role,
            x_admin_actor=x_admin_actor,
            require_subject=True,
        )
        row = conn.execute(
            "SELECT * FROM approved_memories WHERE memory_id = ?", (memory_id,)
        ).fetchone()
        if not row:
            raise ApiError(
                status_code=404,
                code="MEMORY_NOT_FOUND",
                message="Không tìm thấy mục trí nhớ đã lưu.",
            )
        assert_resource_owner(row["subject_id"], caller_subj)
        return {
            "memory_id": row["memory_id"],
            "subject_id": row["subject_id"],
            "proposal_id": row["proposal_id"],
            "consent_id": row["consent_id"],
            "text": row["text"],
            "updated_at": row["updated_at"],
        }


@app.patch("/v1/memories/{memory_id}")
def update_approved_memory(
    memory_id: str,
    payload: MemoryPatchInput,
    subject_id: Optional[str] = Query(default=None),
    authorization: str = Header(default=""),
    x_subject_id: str = Header(default=""),
    x_staff_id: str = Header(default=""),
    x_staff_role: str = Header(default=""),
    x_admin_actor: str = Header(default=""),
):
    if not payload.text.strip():
        raise ApiError(
            status_code=400,
            code="VALIDATION_FAILED",
            message="Nội dung trí nhớ không được để trống (T08).",
        )
    ts = now_iso()
    with get_db() as conn:
        caller_subj = guard_personal_clinical_access(
            conn,
            target=f"UpdateMemory:{memory_id}",
            authorization=authorization,
            x_subject_id=x_subject_id,
            explicit_subject_id=subject_id,
            x_staff_id=x_staff_id,
            x_staff_role=x_staff_role,
            x_admin_actor=x_admin_actor,
            require_subject=True,
        )
        row = conn.execute(
            "SELECT subject_id FROM approved_memories WHERE memory_id = ?", (memory_id,)
        ).fetchone()
        if not row:
            raise ApiError(
                status_code=404,
                code="MEMORY_NOT_FOUND",
                message="Không tìm thấy mục trí nhớ để cập nhật.",
            )
        assert_resource_owner(row["subject_id"], caller_subj)
        conn.execute(
            "UPDATE approved_memories SET text = ?, updated_at = ? WHERE memory_id = ?",
            (payload.text.strip(), ts, memory_id),
        )
    return {
        "memory_id": memory_id,
        "text": payload.text.strip(),
        "updated_at": ts,
    }


@app.delete("/v1/memories/{memory_id}")
def delete_approved_memory(
    memory_id: str,
    subject_id: Optional[str] = Query(default=None),
    authorization: str = Header(default=""),
    x_subject_id: str = Header(default=""),
    x_staff_id: str = Header(default=""),
    x_staff_role: str = Header(default=""),
    x_admin_actor: str = Header(default=""),
):
    with get_db() as conn:
        caller_subj = guard_personal_clinical_access(
            conn,
            target=f"DeleteMemory:{memory_id}",
            authorization=authorization,
            x_subject_id=x_subject_id,
            explicit_subject_id=subject_id,
            x_staff_id=x_staff_id,
            x_staff_role=x_staff_role,
            x_admin_actor=x_admin_actor,
            require_subject=True,
        )
        row = conn.execute(
            "SELECT subject_id FROM approved_memories WHERE memory_id = ?", (memory_id,)
        ).fetchone()
        if not row:
            raise ApiError(
                status_code=404,
                code="MEMORY_NOT_FOUND",
                message="Không tìm thấy mục trí nhớ để xóa (T09).",
            )
        assert_resource_owner(row["subject_id"], caller_subj)
        conn.execute("DELETE FROM approved_memories WHERE memory_id = ?", (memory_id,))
    return {"deleted": True, "memory_id": memory_id}


# ============================================================================
# 3. MOOD CHECK-IN, DAILY CBT, KNOWLEDGE & WEEKLY REFLECTIONS (T10-T13)
# ============================================================================


@app.get("/v1/mood-entries")
def list_mood_entries(
    subject_id: Optional[str] = Query(default=None),
    authorization: str = Header(default=""),
    x_subject_id: str = Header(default=""),
    x_staff_id: str = Header(default=""),
    x_staff_role: str = Header(default=""),
    x_admin_actor: str = Header(default=""),
):
    with get_db() as conn:
        subj = guard_personal_clinical_access(
            conn,
            target="ListMoodEntries",
            authorization=authorization,
            x_subject_id=x_subject_id,
            explicit_subject_id=subject_id,
            x_staff_id=x_staff_id,
            x_staff_role=x_staff_role,
            x_admin_actor=x_admin_actor,
            require_subject=True,
        )
        rows = conn.execute(
            "SELECT * FROM mood_entries WHERE subject_id = ? ORDER BY recorded_at DESC",
            (subj,),
        ).fetchall()
        return {
            "items": [
                {
                    "entry_id": r["entry_id"],
                    "subject_id": r["subject_id"],
                    "mood_choice": r["mood_choice"],
                    "mood_level": r["mood_level"],
                    "optional_note": r["optional_note"],
                    "recorded_at": r["recorded_at"],
                }
                for r in rows
            ]
        }


@app.post("/v1/mood-entries")
def create_mood_entry(
    payload: MoodEntryCreateInput,
    authorization: str = Header(default=""),
    x_subject_id: str = Header(default=""),
    x_staff_id: str = Header(default=""),
    x_staff_role: str = Header(default=""),
    x_admin_actor: str = Header(default=""),
):
    if not payload.mood_choice.strip():
        raise ApiError(
            status_code=400,
            code="VALIDATION_FAILED",
            message="Vui lòng chọn trạng thái cảm xúc.",
        )
    entry_id = f"mood_{uuid.uuid4().hex[:8]}"
    ts = now_iso()
    with get_db() as conn:
        subj = guard_personal_clinical_access(
            conn,
            target="CreateMoodEntry",
            authorization=authorization,
            x_subject_id=x_subject_id,
            explicit_subject_id=payload.subject_id,
            x_staff_id=x_staff_id,
            x_staff_role=x_staff_role,
            x_admin_actor=x_admin_actor,
        ) or payload.subject_id
        conn.execute(
            """
            INSERT INTO mood_entries (entry_id, subject_id, mood_choice, mood_level, optional_note, recorded_at)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            (
                entry_id,
                subj,
                payload.mood_choice.strip(),
                payload.mood_level,
                payload.optional_note.strip(),
                ts,
            ),
        )
    return {
        "entry_id": entry_id,
        "subject_id": subj,
        "mood_choice": payload.mood_choice.strip(),
        "mood_level": payload.mood_level,
        "optional_note": payload.optional_note.strip(),
        "recorded_at": ts,
    }


@app.delete("/v1/mood-entries/{entry_id}")
def delete_mood_entry_by_path(
    entry_id: str,
    subject_id: Optional[str] = Query(default=None),
    authorization: str = Header(default=""),
    x_subject_id: str = Header(default=""),
    x_staff_id: str = Header(default=""),
    x_staff_role: str = Header(default=""),
    x_admin_actor: str = Header(default=""),
):
    with get_db() as conn:
        caller_subj = guard_personal_clinical_access(
            conn,
            target=f"DeleteMoodEntry:{entry_id}",
            authorization=authorization,
            x_subject_id=x_subject_id,
            explicit_subject_id=subject_id,
            x_staff_id=x_staff_id,
            x_staff_role=x_staff_role,
            x_admin_actor=x_admin_actor,
            require_subject=True,
        )
        row = conn.execute(
            "SELECT subject_id FROM mood_entries WHERE entry_id = ?", (entry_id,)
        ).fetchone()
        if not row:
            raise ApiError(
                status_code=404,
                code="MOOD_ENTRY_NOT_FOUND",
                message="Không tìm thấy bản ghi cảm xúc cần xóa.",
            )
        assert_resource_owner(row["subject_id"], caller_subj)
        conn.execute("DELETE FROM mood_entries WHERE entry_id = ?", (entry_id,))
    return {"deleted": True, "entry_id": entry_id}


@app.delete("/v1/mood-entries")
def delete_mood_entry_by_query(
    entry_id: str = Query(...),
    subject_id: Optional[str] = Query(default=None),
    authorization: str = Header(default=""),
    x_subject_id: str = Header(default=""),
    x_staff_id: str = Header(default=""),
    x_staff_role: str = Header(default=""),
    x_admin_actor: str = Header(default=""),
):
    return delete_mood_entry_by_path(
        entry_id=entry_id,
        subject_id=subject_id,
        authorization=authorization,
        x_subject_id=x_subject_id,
        x_staff_id=x_staff_id,
        x_staff_role=x_staff_role,
        x_admin_actor=x_admin_actor,
    )


@app.get("/v1/daily-activities")
def get_daily_activities(
    subject_id: str = Query(default="sub_default"),
    authorization: str = Header(default=""),
    x_subject_id: str = Header(default=""),
    x_staff_id: str = Header(default=""),
    x_staff_role: str = Header(default=""),
    x_admin_actor: str = Header(default=""),
):
    with get_db() as conn:
        subj = guard_personal_clinical_access(
            conn,
            target="DailyActivities",
            authorization=authorization,
            x_subject_id=x_subject_id,
            explicit_subject_id=subject_id,
            x_staff_id=x_staff_id,
            x_staff_role=x_staff_role,
            x_admin_actor=x_admin_actor,
        ) or subject_id
        prog_rows = conn.execute(
            "SELECT activity_id, status, updated_at FROM activity_progress WHERE subject_id = ?",
            (subj,),
        ).fetchall()
        status_map = {r["activity_id"]: r["status"] for r in prog_rows}

    items = []
    for act in DAILY_ACTIVITIES_CATALOG:
        item = dict(act)
        item["status"] = status_map.get(act["activity_id"], "not_started")
        items.append(item)
    return {"items": items}


@app.post("/v1/activity-progress")
def record_activity_progress(
    payload: ActivityProgressInput,
    authorization: str = Header(default=""),
    x_subject_id: str = Header(default=""),
    x_staff_id: str = Header(default=""),
    x_staff_role: str = Header(default=""),
    x_admin_actor: str = Header(default=""),
):
    if payload.status not in ("not_started", "in_progress", "completed", "skipped"):
        raise ApiError(
            status_code=400,
            code="VALIDATION_FAILED",
            message="Trạng thái bài tập không hợp lệ.",
        )
    valid_ids = {a["activity_id"] for a in DAILY_ACTIVITIES_CATALOG}
    if payload.activity_id not in valid_ids:
        raise ApiError(
            status_code=404,
            code="ACTIVITY_NOT_FOUND",
            message="Không tìm thấy mã bài tập CBT.",
        )
    ts = now_iso()
    progress_id = f"prog_{uuid.uuid4().hex[:8]}"
    with get_db() as conn:
        subj = guard_personal_clinical_access(
            conn,
            target="ActivityProgress",
            authorization=authorization,
            x_subject_id=x_subject_id,
            explicit_subject_id=payload.subject_id,
            x_staff_id=x_staff_id,
            x_staff_role=x_staff_role,
            x_admin_actor=x_admin_actor,
        ) or payload.subject_id
        existing = conn.execute(
            "SELECT progress_id FROM activity_progress WHERE subject_id = ? AND activity_id = ?",
            (subj, payload.activity_id),
        ).fetchone()
        if existing:
            progress_id = existing["progress_id"]
            conn.execute(
                "UPDATE activity_progress SET status = ?, updated_at = ? WHERE progress_id = ?",
                (payload.status, ts, progress_id),
            )
        else:
            conn.execute(
                """
                INSERT INTO activity_progress (progress_id, subject_id, activity_id, status, updated_at)
                VALUES (?, ?, ?, ?, ?)
                """,
                (progress_id, subj, payload.activity_id, payload.status, ts),
            )
    return {
        "progress_id": progress_id,
        "subject_id": subj,
        "activity_id": payload.activity_id,
        "status": payload.status,
        "updated_at": ts,
    }


@app.get("/v1/weekly-reflections")
def get_weekly_reflections(
    subject_id: Optional[str] = Query(default=None),
    min_entries: int = Query(default=3, ge=1, le=14),
    authorization: str = Header(default=""),
    x_subject_id: str = Header(default=""),
    x_staff_id: str = Header(default=""),
    x_staff_role: str = Header(default=""),
    x_admin_actor: str = Header(default=""),
):
    with get_db() as conn:
        subj = guard_personal_clinical_access(
            conn,
            target="WeeklyReflections",
            authorization=authorization,
            x_subject_id=x_subject_id,
            explicit_subject_id=subject_id,
            x_staff_id=x_staff_id,
            x_staff_role=x_staff_role,
            x_admin_actor=x_admin_actor,
            require_subject=True,
        )
        mood_rows = conn.execute(
            "SELECT * FROM mood_entries WHERE subject_id = ? ORDER BY recorded_at DESC LIMIT 14",
            (subj,),
        ).fetchall()
        completed_acts = conn.execute(
            "SELECT COUNT(*) AS cnt FROM activity_progress WHERE subject_id = ? AND status = 'completed'",
            (subj,),
        ).fetchone()["cnt"]

    count = len(mood_rows)
    if count < min_entries:
        return {
            "subject_id": subj,
            "insufficient_data": True,
            "entry_count": count,
            "required_entries": min_entries,
            "completed_activities": completed_acts,
            "summary": (
                f"Chưa đủ dữ liệu cảm xúc trong tuần (hiện có {count}/{min_entries} bản ghi). "
                "Hãy ghi nhận cảm xúc thêm vài ngày để hệ thống tổng hợp bức tranh tuần chính xác nhé."
            ),
        }

    avg_level = round(sum(r["mood_level"] for r in mood_rows) / count, 2)
    return {
        "subject_id": subj,
        "insufficient_data": False,
        "entry_count": count,
        "average_mood_level": avg_level,
        "completed_activities": completed_acts,
        "summary": (
            f"Trong {count} lần check-in gần nhất, mức năng lượng trung bình của bạn đạt {avg_level}/5.0 "
            f"và bạn đã hoàn thành {completed_acts} bài tập CBT tự hỗ trợ."
        ),
    }


@app.get("/v1/knowledge-articles")
def list_knowledge_articles(category: Optional[str] = Query(default=None)):
    with get_db() as conn:
        if category and category.strip() and category.strip() != "ALL":
            rows = conn.execute(
                "SELECT * FROM knowledge_articles WHERE category = ? ORDER BY id ASC",
                (category.strip(),),
            ).fetchall()
        else:
            rows = conn.execute(
                "SELECT * FROM knowledge_articles ORDER BY id ASC"
            ).fetchall()
        if not rows:
            return {"items": KNOWLEDGE_ARTICLES_CATALOG}
        return {
            "items": [
                {
                    "id": r["id"],
                    "title": r["title"],
                    "category": r["category"],
                    "summary": r["summary"],
                    "content": r["content"],
                    "verified_source": r["verified_source"],
                    "updated_at": r["updated_at"],
                }
                for r in rows
            ]
        }


@app.post("/v1/knowledge-articles")
def create_or_update_knowledge_article(
    payload: KnowledgeArticleInput,
    authorization: str = Header(default=""),
    x_staff_role: str = Header(default=""),
    x_staff_id: str = Header(default=""),
    x_admin_actor: str = Header(default=""),
):
    title = payload.title.strip()
    summary = payload.summary.strip()
    content = payload.content.strip()
    if not title or not summary or not content:
        raise ApiError(
            status_code=400,
            code="VALIDATION_FAILED",
            message="Tiêu đề, tóm tắt và nội dung bài viết không được để trống.",
        )
    art_id = (payload.id or "").strip() or f"art_{uuid.uuid4().hex[:6]}"
    ts = now_iso()
    with get_db() as conn:
        actor = require_analytics_actor(
            conn,
            authorization=authorization,
            x_staff_role=x_staff_role,
            x_staff_id=x_staff_id,
            x_admin_actor=x_admin_actor,
        )
        conn.execute(
            """
            INSERT INTO knowledge_articles (id, title, category, summary, content, verified_source, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                title = excluded.title,
                category = excluded.category,
                summary = excluded.summary,
                content = excluded.content,
                verified_source = excluded.verified_source,
                updated_at = excluded.updated_at
            """,
            (
                art_id,
                title,
                payload.category.strip() or "Kỹ năng Tự chăm sóc",
                summary,
                content,
                payload.verified_source.strip() or "Phòng Tư vấn Tâm lý & CTSV",
                ts,
            ),
        )
        log_audit_event(
            conn,
            actor=actor,
            action=f"UPSERT_KNOWLEDGE_ARTICLE ({art_id})",
            target=art_id,
            result="SUCCESS",
        )
    return {
        "id": art_id,
        "title": title,
        "category": payload.category.strip() or "Kỹ năng Tự chăm sóc",
        "summary": summary,
        "content": content,
        "verified_source": payload.verified_source.strip() or "Phòng Tư vấn Tâm lý & CTSV",
        "updated_at": ts,
    }


@app.delete("/v1/knowledge-articles/{article_id}")
def delete_knowledge_article(
    article_id: str,
    authorization: str = Header(default=""),
    x_staff_role: str = Header(default=""),
    x_staff_id: str = Header(default=""),
    x_admin_actor: str = Header(default=""),
):
    with get_db() as conn:
        actor = require_analytics_actor(
            conn,
            authorization=authorization,
            x_staff_role=x_staff_role,
            x_staff_id=x_staff_id,
            x_admin_actor=x_admin_actor,
        )
        existing = conn.execute(
            "SELECT id FROM knowledge_articles WHERE id = ?", (article_id,)
        ).fetchone()
        if not existing:
            raise ApiError(
                status_code=404,
                code="ARTICLE_NOT_FOUND",
                message="Không tìm thấy bài viết kiến thức.",
            )
        conn.execute("DELETE FROM knowledge_articles WHERE id = ?", (article_id,))
        log_audit_event(
            conn,
            actor=actor,
            action=f"DELETE_KNOWLEDGE_ARTICLE ({article_id})",
            target=article_id,
            result="SUCCESS",
        )
    return {"deleted": True, "id": article_id}


# ============================================================================
# 4. VOLUNTARY SCREENING ENGINE (PHQ-9, GAD-7, DASS-21 - T14-T17, R2, R3)
# ============================================================================


@app.get("/v1/screening-tools")
def list_screening_tools():
    return {"items": list(SCREENING_TOOLS_CATALOG.values())}


@app.get("/v1/screening-sessions")
def list_screening_sessions(
    subject_id: Optional[str] = Query(default=None),
    authorization: str = Header(default=""),
    x_subject_id: str = Header(default=""),
    x_staff_id: str = Header(default=""),
    x_staff_role: str = Header(default=""),
    x_admin_actor: str = Header(default=""),
):
    with get_db() as conn:
        subj = guard_personal_clinical_access(
            conn,
            target="ListScreeningSessions",
            authorization=authorization,
            x_subject_id=x_subject_id,
            explicit_subject_id=subject_id,
            x_staff_id=x_staff_id,
            x_staff_role=x_staff_role,
            x_admin_actor=x_admin_actor,
            require_subject=True,
        )
        rows = conn.execute(
            """
            SELECT * FROM screening_sessions
            WHERE subject_id = ? AND status = 'completed'
            ORDER BY completed_at DESC
            """,
            (subj,),
        ).fetchall()
        items = []
        for r in rows:
            trend = compute_subject_screening_trend(conn, subj, r["tool_id"])
            raw_ans = []
            try:
                raw_ans = json.loads(r["answers_json"] or "[]")
            except Exception:
                raw_ans = []
            subscales = (
                compute_dass21_subscales(raw_ans)
                if r["tool_id"] == "DASS-21" and raw_ans
                else {}
            )
            items.append(
                {
                    "session_id": r["session_id"],
                    "tool_id": r["tool_id"],
                    "score": r["score"],
                    "max_score": r["max_score"],
                    "level_label": r["level_label"],
                    "interpretation": r["interpretation"],
                    "requires_attention": bool(r["requires_attention"]),
                    "four_week_trend": trend,
                    "subscale_scores": subscales,
                    "faculty": r["faculty"] if "faculty" in r.keys() else "CNTT",
                    "academic_year": r["academic_year"] if "academic_year" in r.keys() else "Nam_2",
                    "is_clinical_diagnosis": False,
                    "demo_flag": bool(r["demo_flag"]),
                    "completed_at": r["completed_at"],
                }
            )
        return {"items": items}


@app.post("/v1/screening-sessions")
def start_screening_session(
    payload: ScreeningSessionCreateInput,
    authorization: str = Header(default=""),
    x_subject_id: str = Header(default=""),
    x_staff_id: str = Header(default=""),
    x_staff_role: str = Header(default=""),
    x_admin_actor: str = Header(default=""),
):
    tool_id = payload.tool_id.upper().strip()
    if tool_id not in SCREENING_TOOLS_CATALOG:
        raise ApiError(
            status_code=404,
            code="SCREENING_TOOL_NOT_FOUND",
            message=f"Không hỗ trợ bộ công cụ '{payload.tool_id}'. Chọn PHQ-9, GAD-7 hoặc DASS-21.",
        )

    with get_db() as conn:
        subj = guard_personal_clinical_access(
            conn,
            target="StartScreeningSession",
            authorization=authorization,
            x_subject_id=x_subject_id,
            explicit_subject_id=payload.subject_id,
            x_staff_id=x_staff_id,
            x_staff_role=x_staff_role,
            x_admin_actor=x_admin_actor,
        ) or payload.subject_id

        # F21, R2, T14 & T15: Bắt buộc có consent_id đúng mục đích 'screening' và khớp subject_id
        verify_consent(
            conn,
            payload.consent_id or "",
            expected_purpose="screening",
            expected_subject_id=subj,
        )

        session_id = f"scr_{uuid.uuid4().hex[:8]}"
        ts = now_iso()
        demo_val = 1 if is_seed_demo_enabled() else 0
        conn.execute(
            """
            INSERT INTO screening_sessions (
                session_id, subject_id, tool_id, consent_id, status,
                faculty, academic_year, demo_flag, created_at
            ) VALUES (?, ?, ?, ?, 'in_progress', ?, ?, ?, ?)
            """,
            (
                session_id,
                subj,
                tool_id,
                payload.consent_id.strip(),
                payload.faculty,
                payload.academic_year,
                demo_val,
                ts,
            ),
        )

    return {
        "session_id": session_id,
        "subject_id": subj,
        "tool_id": tool_id,
        "consent_id": payload.consent_id.strip(),
        "status": "in_progress",
        "is_clinical_diagnosis": False,
        "demo_flag": bool(demo_val),
        "created_at": ts,
    }


@app.put("/v1/screening-sessions/{session_id}/answers")
def submit_screening_answers(
    session_id: str,
    payload: ScreeningAnswersInput,
    subject_id: Optional[str] = Query(default=None),
    authorization: str = Header(default=""),
    x_subject_id: str = Header(default=""),
    x_staff_id: str = Header(default=""),
    x_staff_role: str = Header(default=""),
    x_admin_actor: str = Header(default=""),
):
    with get_db() as conn:
        caller_subj = guard_personal_clinical_access(
            conn,
            target=f"SubmitScreeningAnswers:{session_id}",
            authorization=authorization,
            x_subject_id=x_subject_id,
            explicit_subject_id=subject_id,
            x_staff_id=x_staff_id,
            x_staff_role=x_staff_role,
            x_admin_actor=x_admin_actor,
        )
        sess = conn.execute(
            "SELECT * FROM screening_sessions WHERE session_id = ?", (session_id,)
        ).fetchone()
        if not sess:
            raise ApiError(
                status_code=404,
                code="SCREENING_SESSION_NOT_FOUND",
                message="Không tìm thấy phiên sàng lọc.",
            )
        if caller_subj and sess["subject_id"] != caller_subj:
            raise ApiError(
                status_code=403,
                code="FORBIDDEN_CROSS_USER_ACCESS",
                message="Không được phép nộp câu trả lời cho phiên sàng lọc của người dùng khác.",
            )

        tool_id = sess["tool_id"]
        expected_len = len(SCREENING_TOOLS_CATALOG[tool_id]["questions"])
        ts = now_iso()

        if any((not isinstance(a, int) or a < 0 or a > 3) for a in payload.answers):
            raise ApiError(
                status_code=400,
                code="INVALID_ANSWER_RANGE",
                message="Điểm từng câu trả lời phải là số nguyên từ 0 đến 3.",
            )

        # T16: Nếu sinh viên thoát giữa chừng (completed=False) -> đánh dấu abandoned, không tính điểm
        if not payload.completed:
            conn.execute(
                """
                UPDATE screening_sessions
                SET status = 'abandoned', answers_json = ?, score = NULL, level_label = NULL, completed_at = ?
                WHERE session_id = ?
                """,
                (json.dumps(payload.answers), ts, session_id),
            )
            return {
                "session_id": session_id,
                "tool_id": tool_id,
                "status": "abandoned",
                "score": None,
                "level_label": None,
                "is_clinical_diagnosis": False,
                "demo_flag": is_seed_demo_enabled(),
                "message": "Phiên sàng lọc đã dừng theo lựa chọn của bạn, hệ thống không chấm điểm hoàn chỉnh.",
            }

        if not payload.answers:
            raise ApiError(
                status_code=400,
                code="EMPTY_ANSWERS",
                message="Danh sách câu trả lời không được rỗng khi hoàn tất phiên sàng lọc.",
            )
        if len(payload.answers) != expected_len:
            raise ApiError(
                status_code=400,
                code="INCOMPLETE_ANSWERS",
                message=f"Thang đo {tool_id} yêu cầu trả lời đủ {expected_len} câu hỏi (hiện nhận {len(payload.answers)}).",
            )

        prelim = evaluate_screening_rule_based(tool_id, payload.answers)
        demo_val = 1 if is_seed_demo_enabled() else 0
        conn.execute(
            """
            UPDATE screening_sessions
            SET status = 'completed',
                answers_json = ?,
                score = ?,
                max_score = ?,
                level_label = ?,
                interpretation = ?,
                requires_attention = ?,
                demo_flag = ?,
                completed_at = ?
            WHERE session_id = ?
            """,
            (
                json.dumps(payload.answers),
                prelim["score"],
                prelim["max_score"],
                prelim["level_label"],
                prelim["interpretation"],
                1 if prelim["requires_attention"] else 0,
                demo_val,
                ts,
                session_id,
            ),
        )
        trend = compute_subject_screening_trend(conn, sess["subject_id"], tool_id)

    return {
        "session_id": session_id,
        "tool_id": tool_id,
        "status": "completed",
        "score": prelim["score"],
        "max_score": prelim["max_score"],
        "level_label": prelim["level_label"],
        "interpretation": prelim["interpretation"],
        "requires_attention": prelim["requires_attention"],
        "item9_safety_alert": prelim["item9_safety_alert"],
        "recommended_layer": prelim["recommended_layer"],
        "four_week_trend": trend,
        "subscale_scores": prelim.get("subscale_scores", {}),
        "is_clinical_diagnosis": False,
        "demo_flag": bool(demo_val),
        "completed_at": ts,
    }


# ============================================================================
# 5. SUPPORT, BOOKING & SCHOOL PORTAL (T20-T21, T23-T25, T27, F37)
# ============================================================================


@app.post("/v1/counseling-requests")
def create_counseling_request(
    payload: CounselingRequestCreateInput,
    x_idempotency_key: str = Header(default=""),
    authorization: str = Header(default=""),
    x_subject_id: str = Header(default=""),
):
    contact_clean = payload.contact_info.strip()
    slot_clean = payload.slot_time.strip()
    if not is_valid_contact_info(contact_clean) or not slot_clean:
        raise ApiError(
            status_code=400,
            code="VALIDATION_FAILED",
            message="Vui lòng cung cấp Email/Số điện thoại hợp lệ và khung giờ hẹn.",
        )

    idem_key = (
        (payload.idempotency_key or "").strip()
        or x_idempotency_key.strip()
        or f"idem_{uuid.uuid4().hex[:10]}"
    )

    with get_db() as conn:
        session = resolve_bearer_session(conn, authorization)
        if session and session["role"] in ("ctsv", "counselor", "admin"):
            raise ApiError(
                status_code=403,
                code="FORBIDDEN_ROLE",
                message="Nhân sự không tạo lịch hẹn thay mặt sinh viên trên API này.",
            )

        # T21: Chống tạo trùng lịch hẹn theo idempotency_key (chỉ replay cho cùng consent_id để không lộ PII)
        existing = conn.execute(
            "SELECT * FROM counseling_requests WHERE idempotency_key = ?",
            (idem_key,),
        ).fetchone()
        if existing:
            if (payload.consent_id or "").strip() != existing["consent_id"]:
                raise ApiError(
                    status_code=409,
                    code="DUPLICATE_IDEMPOTENCY_KEY",
                    message="Khóa idempotency_key đã được sử dụng cho một yêu cầu khác.",
                )
            return {
                "request_id": existing["request_id"],
                "idempotency_key": existing["idempotency_key"],
                "unit_name": existing["unit_name"],
                "counselor_id": existing["counselor_id"],
                "counselor_name": existing["counselor_name"],
                "slot_time": existing["slot_time"],
                "contact_info": existing["contact_info"],
                "student_note": existing["student_note"],
                "counselor_note": existing["counselor_note"] if "counselor_note" in existing.keys() else "",
                "consent_id": existing["consent_id"],
                "status": existing["status"],
                "created_at": existing["created_at"],
                "idempotent_replay": True,
            }

        # F29, R2, T20: Bắt buộc kiểm tra consent_id đúng mục đích 'counseling_share'
        # Lưu ý R4: Chỉ đối chiếu subject_id trong bộ nhớ nếu có, TUYỆT ĐỐI không ghi subject_id vào bảng counseling_requests
        expected_subj = (
            (session["subject_id"] if session else "")
            or x_subject_id.strip()
            or (payload.subject_id or "").strip()
            or None
        )
        verify_consent(
            conn,
            payload.consent_id or "",
            expected_purpose="counseling_share",
            expected_subject_id=expected_subj,
        )

        req_id = f"req_{uuid.uuid4().hex[:8]}"
        requester_token = f"btk_{secrets.token_urlsafe(20)}"
        req_token_hash = hash_token(requester_token)
        mode_clean = (payload.consultation_mode or "Trực tiếp tại phòng").strip()
        ts = now_iso()
        conn.execute(
            """
            INSERT INTO counseling_requests (
                request_id, idempotency_key, unit_name, counselor_id, counselor_name,
                slot_time, consultation_mode, contact_info, student_note, requester_token_hash,
                consent_id, status, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending', ?, ?)
            """,
            (
                req_id,
                idem_key,
                payload.unit_name.strip(),
                payload.counselor_id.strip(),
                payload.counselor_name.strip(),
                slot_clean,
                mode_clean,
                contact_clean,
                payload.student_note.strip(),
                req_token_hash,
                payload.consent_id.strip(),
                ts,
                ts,
            ),
        )

    return {
        "request_id": req_id,
        "idempotency_key": idem_key,
        "unit_name": payload.unit_name.strip(),
        "counselor_id": payload.counselor_id.strip(),
        "counselor_name": payload.counselor_name.strip(),
        "slot_time": slot_clean,
        "consultation_mode": mode_clean,
        "contact_info": contact_clean,
        "student_note": payload.student_note.strip(),
        "counselor_note": "",
        "consent_id": payload.consent_id.strip(),
        "requester_token": requester_token,
        "status": "pending",
        "created_at": ts,
    }


def _whitelist_counseling_request(row: sqlite3.Row) -> dict:
    """F37 & R5: Chỉ trả các trường Whitelist, tuyệt đối không trả chat_text, screening_score hay token_hash."""
    keys = row.keys()
    return {
        "request_id": row["request_id"],
        "unit_name": row["unit_name"],
        "counselor_id": row["counselor_id"],
        "counselor_name": row["counselor_name"],
        "slot_time": row["slot_time"],
        "consultation_mode": (
            row["consultation_mode"]
            if "consultation_mode" in keys
            else "Trực tiếp tại phòng"
        ),
        "contact_info": row["contact_info"],
        "student_note": row["student_note"],
        "counselor_note": row["counselor_note"] if "counselor_note" in keys else "",
        "status": row["status"],
        "created_at": row["created_at"],
        "updated_at": row["updated_at"],
    }


@app.get("/v1/counseling-requests")
def list_student_counseling_requests(
    contact_info: Optional[str] = Query(default=None),
    authorization: str = Header(default=""),
    x_booking_token: str = Header(default=""),
):
    """
    S24: Sinh viên chỉ được xem lịch hẹn của chính mình (xác minh bằng X-Booking-Token hoặc Bearer token tài khoản).
    Đã loại bỏ hoàn toàn việc trả danh sách 50 lịch hẹn của người khác (chống lộ PII).
    """
    with get_db() as conn:
        session = resolve_bearer_session(conn, authorization)
        if session and session["role"] in ("ctsv", "counselor", "admin"):
            raise ApiError(
                status_code=403,
                code="FORBIDDEN_ROLE",
                message="Nhân sự vui lòng sử dụng endpoint phân quyền /v1/staff/counseling-requests.",
            )

        btk = x_booking_token.strip()
        if btk:
            token_hashes = [hash_token(t.strip()) for t in btk.split(",") if t.strip()]
            placeholders = ",".join("?" for _ in token_hashes)
            rows = conn.execute(
                f"SELECT * FROM counseling_requests WHERE requester_token_hash IN ({placeholders}) ORDER BY created_at DESC",
                tuple(token_hashes),
            ).fetchall()
            return {"items": [_whitelist_counseling_request(r) for r in rows]}

        if session and session["role"] == "student" and session["email"]:
            target_contact = session["email"].strip()
            if contact_info and contact_info.strip().lower() != target_contact.lower():
                raise ApiError(
                    status_code=403,
                    code="FORBIDDEN_CROSS_USER_ACCESS",
                    message="Không được phép tra cứu lịch hẹn bằng thông tin liên hệ của sinh viên khác.",
                )
            rows = conn.execute(
                "SELECT * FROM counseling_requests WHERE LOWER(contact_info) = LOWER(?) ORDER BY created_at DESC",
                (target_contact,),
            ).fetchall()
            return {"items": [_whitelist_counseling_request(r) for r in rows]}

        raise ApiError(
            status_code=401,
            code="BOOKING_AUTH_REQUIRED",
            message="Vui lòng cung cấp X-Booking-Token hoặc đăng nhập tài khoản sinh viên để xem lịch hẹn cá nhân.",
        )


@app.patch("/v1/counseling-requests/{request_id}/cancel")
def cancel_student_counseling_request(
    request_id: str,
    authorization: str = Header(default=""),
    x_booking_token: str = Header(default=""),
):
    with get_db() as conn:
        session = resolve_bearer_session(conn, authorization)
        row = conn.execute(
            "SELECT * FROM counseling_requests WHERE request_id = ?", (request_id,)
        ).fetchone()
        if not row:
            raise ApiError(
                status_code=404,
                code="COUNSELING_REQUEST_NOT_FOUND",
                message="Không tìm thấy yêu cầu đặt lịch tư vấn.",
            )

        authorized = False
        btk = x_booking_token.strip()
        if btk:
            provided_hashes = {hash_token(t.strip()) for t in btk.split(",") if t.strip()}
            if row["requester_token_hash"] and row["requester_token_hash"] in provided_hashes:
                authorized = True
        if session and session["role"] == "student" and session["email"]:
            if row["contact_info"].strip().lower() == session["email"].strip().lower():
                authorized = True

        if not authorized:
            raise ApiError(
                status_code=403,
                code="FORBIDDEN_BOOKING_ACCESS",
                message="Bạn không có quyền hủy lịch hẹn của người dùng khác.",
            )

        if row["status"] not in ("pending", "confirmed", "accepted"):
            raise ApiError(
                status_code=400,
                code="INVALID_BOOKING_STATE",
                message=f"Không thể hủy lịch hẹn đang ở trạng thái '{row['status']}'.",
            )

        ts = now_iso()
        conn.execute(
            "UPDATE counseling_requests SET status = 'canceled', updated_at = ? WHERE request_id = ?",
            (ts, request_id),
        )
        updated = conn.execute(
            "SELECT * FROM counseling_requests WHERE request_id = ?", (request_id,)
        ).fetchone()
        return _whitelist_counseling_request(updated)


@app.get("/v1/staff/counseling-requests")
def list_staff_assigned_counseling_requests(
    counselor_id: Optional[str] = Query(default=None),
    authorization: str = Header(default=""),
    x_staff_id: str = Header(default=""),
    x_staff_role: str = Header(default=""),
    x_admin_actor: str = Header(default=""),
):
    """R5: Tư vấn viên chỉ nhận danh sách ca được gán cho chính mình (Whitelist F37)."""
    with get_db() as conn:
        effective_actor = require_counselor_actor(
            conn,
            target="ListAssignedCounselingRequests",
            authorization=authorization,
            counselor_id_query=counselor_id,
            x_staff_id=x_staff_id,
            x_staff_role=x_staff_role,
            x_admin_actor=x_admin_actor,
        )
        rows = conn.execute(
            "SELECT * FROM counseling_requests WHERE counselor_id = ? ORDER BY created_at DESC",
            (effective_actor,),
        ).fetchall()
        return {
            "counselor_id": effective_actor,
            "items": [_whitelist_counseling_request(r) for r in rows],
        }


@app.get("/v1/staff/counseling-requests/{request_id}")
def get_staff_counseling_request(
    request_id: str,
    counselor_id: Optional[str] = Query(default=None),
    authorization: str = Header(default=""),
    x_staff_id: str = Header(default=""),
    x_staff_role: str = Header(default=""),
    x_admin_actor: str = Header(default=""),
):
    with get_db() as conn:
        effective_actor = require_counselor_actor(
            conn,
            target=request_id,
            authorization=authorization,
            counselor_id_query=counselor_id,
            x_staff_id=x_staff_id,
            x_staff_role=x_staff_role,
            x_admin_actor=x_admin_actor,
        )
        row = conn.execute(
            "SELECT * FROM counseling_requests WHERE request_id = ?", (request_id,)
        ).fetchone()
        if not row:
            raise ApiError(
                status_code=404,
                code="COUNSELING_REQUEST_NOT_FOUND",
                message="Không tìm thấy yêu cầu đặt lịch tư vấn.",
            )

        # T25 & R5: Chặn truy cập chéo giữa counselor_01 và counselor_02
        if row["counselor_id"] != effective_actor:
            log_audit_event(
                conn,
                actor=effective_actor,
                action="READ_COUNSELING_REQUEST_DENIED",
                target=request_id,
                result="DENIED_CROSS_COUNSELOR",
            )
            raise ApiError(
                status_code=403,
                code="FORBIDDEN_CROSS_COUNSELOR_ACCESS",
                message=f"Tư vấn viên '{effective_actor}' không có quyền xem ca tư vấn được gán cho '{row['counselor_id']}' (T25).",
            )

        return _whitelist_counseling_request(row)


VALID_COUNSELING_STATUSES = (
    "pending",
    "confirmed",
    "accepted",
    "completed",
    "declined",
    "rescheduled",
    "canceled",
    "cancelled",
)


@app.patch("/v1/staff/counseling-requests/{request_id}")
def update_staff_counseling_request(
    request_id: str,
    payload: StaffCounselingPatchInput,
    counselor_id: Optional[str] = Query(default=None),
    authorization: str = Header(default=""),
    x_staff_id: str = Header(default=""),
    x_staff_role: str = Header(default=""),
    x_admin_actor: str = Header(default=""),
):
    if payload.status not in VALID_COUNSELING_STATUSES:
        raise ApiError(
            status_code=400,
            code="VALIDATION_FAILED",
            message="Trạng thái lịch hẹn không hợp lệ.",
        )

    with get_db() as conn:
        effective_actor = require_counselor_actor(
            conn,
            target=request_id,
            authorization=authorization,
            counselor_id_query=counselor_id,
            x_staff_id=x_staff_id,
            x_staff_role=x_staff_role,
            x_admin_actor=x_admin_actor,
        )
        row = conn.execute(
            "SELECT * FROM counseling_requests WHERE request_id = ?", (request_id,)
        ).fetchone()
        if not row:
            raise ApiError(
                status_code=404,
                code="COUNSELING_REQUEST_NOT_FOUND",
                message="Không tìm thấy yêu cầu đặt lịch tư vấn.",
            )

        if row["counselor_id"] != effective_actor:
            log_audit_event(
                conn,
                actor=effective_actor,
                action=f"UPDATE_COUNSELING_REQUEST_DENIED ({payload.status})",
                target=request_id,
                result="DENIED_CROSS_COUNSELOR",
            )
            raise ApiError(
                status_code=403,
                code="FORBIDDEN_CROSS_COUNSELOR_ACCESS",
                message=f"Tư vấn viên '{effective_actor}' không được phép cập nhật ca của '{row['counselor_id']}' (T25).",
            )

        new_slot = (payload.slot_time or row["slot_time"]).strip()
        existing_note = row["counselor_note"] if "counselor_note" in row.keys() else ""
        new_note = (
            payload.counselor_note.strip()
            if payload.counselor_note is not None
            else existing_note
        )
        ts = now_iso()
        conn.execute(
            """
            UPDATE counseling_requests
            SET status = ?, slot_time = ?, counselor_note = ?, updated_at = ?
            WHERE request_id = ?
            """,
            (payload.status, new_slot, new_note, ts, request_id),
        )
        log_audit_event(
            conn,
            actor=effective_actor,
            action=f"UPDATE_BOOKING_STATUS -> {payload.status}",
            target=request_id,
            result="SUCCESS",
        )
        updated = conn.execute(
            "SELECT * FROM counseling_requests WHERE request_id = ?", (request_id,)
        ).fetchone()
        return _whitelist_counseling_request(updated)


@app.get("/v1/counselor-slots")
def list_counselor_slots(
    counselor_id: Optional[str] = Query(default=None),
    only_available: bool = Query(default=False),
):
    with get_db() as conn:
        clauses: List[str] = []
        params: List[Any] = []
        if counselor_id and counselor_id.strip():
            clauses.append("counselor_id = ?")
            params.append(counselor_id.strip())
        if only_available:
            clauses.append("is_available = 1")
        where_sql = f"WHERE {' AND '.join(clauses)}" if clauses else ""
        rows = conn.execute(
            f"SELECT * FROM counselor_slots {where_sql} ORDER BY counselor_id ASC, slot_id ASC",
            tuple(params),
        ).fetchall()
        return {
            "items": [
                {
                    "slot_id": r["slot_id"],
                    "counselor_id": r["counselor_id"],
                    "counselor_name": r["counselor_name"],
                    "unit_name": r["unit_name"],
                    "slot_label": r["slot_label"],
                    "consultation_mode": r["consultation_mode"],
                    "is_available": bool(r["is_available"]),
                    "updated_at": r["updated_at"],
                }
                for r in rows
            ]
        }


@app.post("/v1/staff/counselor-slots")
def create_counselor_slot(
    payload: CounselorSlotCreateInput,
    counselor_id: Optional[str] = Query(default=None),
    authorization: str = Header(default=""),
    x_staff_id: str = Header(default=""),
    x_staff_role: str = Header(default=""),
    x_admin_actor: str = Header(default=""),
):
    slot_label = payload.slot_label.strip()
    if not slot_label:
        raise ApiError(
            status_code=400,
            code="VALIDATION_FAILED",
            message="Khung giờ làm việc không được để trống.",
        )
    with get_db() as conn:
        effective_actor = require_counselor_actor(
            conn,
            target="CreateCounselorSlot",
            authorization=authorization,
            counselor_id_query=counselor_id or payload.counselor_id,
            x_staff_id=x_staff_id,
            x_staff_role=x_staff_role,
            x_admin_actor=x_admin_actor,
        )
        slot_id = f"slot_{effective_actor}_{uuid.uuid4().hex[:6]}"
        ts = now_iso()
        conn.execute(
            """
            INSERT INTO counselor_slots (
                slot_id, counselor_id, counselor_name, unit_name, slot_label,
                consultation_mode, is_available, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                slot_id,
                effective_actor,
                payload.counselor_name.strip(),
                payload.unit_name.strip(),
                slot_label,
                payload.consultation_mode.strip() or "Trực tiếp tại phòng P.102",
                1 if payload.is_available else 0,
                ts,
            ),
        )
        log_audit_event(
            conn,
            actor=effective_actor,
            action=f"CREATE_COUNSELOR_SLOT ({slot_label})",
            target=slot_id,
            result="SUCCESS",
        )
    return {
        "slot_id": slot_id,
        "counselor_id": effective_actor,
        "counselor_name": payload.counselor_name.strip(),
        "unit_name": payload.unit_name.strip(),
        "slot_label": slot_label,
        "consultation_mode": payload.consultation_mode.strip() or "Trực tiếp tại phòng P.102",
        "is_available": payload.is_available,
        "updated_at": ts,
    }


@app.patch("/v1/staff/counselor-slots/{slot_id}")
def patch_counselor_slot(
    slot_id: str,
    payload: CounselorSlotPatchInput,
    counselor_id: Optional[str] = Query(default=None),
    authorization: str = Header(default=""),
    x_staff_id: str = Header(default=""),
    x_staff_role: str = Header(default=""),
    x_admin_actor: str = Header(default=""),
):
    with get_db() as conn:
        effective_actor = require_counselor_actor(
            conn,
            target=slot_id,
            authorization=authorization,
            counselor_id_query=counselor_id,
            x_staff_id=x_staff_id,
            x_staff_role=x_staff_role,
            x_admin_actor=x_admin_actor,
        )
        row = conn.execute(
            "SELECT * FROM counselor_slots WHERE slot_id = ?", (slot_id,)
        ).fetchone()
        if not row:
            raise ApiError(
                status_code=404,
                code="COUNSELOR_SLOT_NOT_FOUND",
                message="Không tìm thấy khung giờ làm việc.",
            )
        if row["counselor_id"] != effective_actor:
            log_audit_event(
                conn,
                actor=effective_actor,
                action="UPDATE_COUNSELOR_SLOT_DENIED",
                target=slot_id,
                result="DENIED_CROSS_COUNSELOR",
            )
            raise ApiError(
                status_code=403,
                code="FORBIDDEN_CROSS_COUNSELOR_ACCESS",
                message="Không được phép chỉnh sửa khung giờ làm việc của tư vấn viên khác (T25).",
            )
        new_label = (payload.slot_label or row["slot_label"]).strip()
        new_mode = (payload.consultation_mode or row["consultation_mode"]).strip()
        new_avail = (
            (1 if payload.is_available else 0)
            if payload.is_available is not None
            else row["is_available"]
        )
        ts = now_iso()
        conn.execute(
            """
            UPDATE counselor_slots
            SET slot_label = ?, consultation_mode = ?, is_available = ?, updated_at = ?
            WHERE slot_id = ?
            """,
            (new_label, new_mode, new_avail, ts, slot_id),
        )
        log_audit_event(
            conn,
            actor=effective_actor,
            action=f"UPDATE_COUNSELOR_SLOT ({slot_id} -> available={bool(new_avail)})",
            target=slot_id,
            result="SUCCESS",
        )
        updated = conn.execute(
            "SELECT * FROM counselor_slots WHERE slot_id = ?", (slot_id,)
        ).fetchone()
        return {
            "slot_id": updated["slot_id"],
            "counselor_id": updated["counselor_id"],
            "counselor_name": updated["counselor_name"],
            "unit_name": updated["unit_name"],
            "slot_label": updated["slot_label"],
            "consultation_mode": updated["consultation_mode"],
            "is_available": bool(updated["is_available"]),
            "updated_at": updated["updated_at"],
        }


@app.delete("/v1/staff/counselor-slots/{slot_id}")
def delete_counselor_slot(
    slot_id: str,
    counselor_id: Optional[str] = Query(default=None),
    authorization: str = Header(default=""),
    x_staff_id: str = Header(default=""),
    x_staff_role: str = Header(default=""),
    x_admin_actor: str = Header(default=""),
):
    with get_db() as conn:
        effective_actor = require_counselor_actor(
            conn,
            target=slot_id,
            authorization=authorization,
            counselor_id_query=counselor_id,
            x_staff_id=x_staff_id,
            x_staff_role=x_staff_role,
            x_admin_actor=x_admin_actor,
        )
        row = conn.execute(
            "SELECT * FROM counselor_slots WHERE slot_id = ?", (slot_id,)
        ).fetchone()
        if not row:
            raise ApiError(
                status_code=404,
                code="COUNSELOR_SLOT_NOT_FOUND",
                message="Không tìm thấy khung giờ làm việc.",
            )
        if row["counselor_id"] != effective_actor:
            log_audit_event(
                conn,
                actor=effective_actor,
                action="DELETE_COUNSELOR_SLOT_DENIED",
                target=slot_id,
                result="DENIED_CROSS_COUNSELOR",
            )
            raise ApiError(
                status_code=403,
                code="FORBIDDEN_CROSS_COUNSELOR_ACCESS",
                message="Không được phép xóa khung giờ của tư vấn viên khác (T25).",
            )
        conn.execute("DELETE FROM counselor_slots WHERE slot_id = ?", (slot_id,))
        log_audit_event(
            conn,
            actor=effective_actor,
            action=f"DELETE_COUNSELOR_SLOT ({slot_id})",
            target=slot_id,
            result="SUCCESS",
        )
    return {"deleted": True, "slot_id": slot_id}


def _get_current_min_group_size(conn: sqlite3.Connection) -> int:
    row = conn.execute(
        """
        SELECT metadata_json FROM audit_events
        WHERE target = 'AnalyticsPolicy' AND result = 'SUCCESS'
        ORDER BY timestamp DESC LIMIT 1
        """
    ).fetchone()
    if row and row["metadata_json"]:
        try:
            meta = json.loads(row["metadata_json"])
            return int(meta.get("min_group_size", 10))
        except Exception:
            pass
    return 10


@app.get("/v1/analytics/overview")
def get_analytics_overview(
    faculty: str = Query(default="ALL"),
    academic_year: str = Query(default="ALL"),
    period: str = Query(default="ALL"),
    authorization: str = Header(default=""),
    x_staff_role: str = Header(default=""),
    x_staff_id: str = Header(default=""),
    x_admin_actor: str = Header(default=""),
):
    """
    D02–D04, R4, T23, T24:
    Tổng hợp số liệu thực trực tiếp từ vùng Anon_Clinical (SQLite).
    Tuyệt đối không trả PII hoặc nội dung hội thoại; tự động khóa khi n < min_group_size.
    """
    fac_clean = faculty.strip() or "ALL"
    year_clean = academic_year.strip() or "ALL"
    period_clean = period.strip() or "ALL"

    with get_db() as conn:
        require_analytics_actor(
            conn,
            authorization=authorization,
            x_staff_role=x_staff_role,
            x_staff_id=x_staff_id,
            x_admin_actor=x_admin_actor,
        )
        min_group_size = _get_current_min_group_size(conn)

        clauses = ["status = 'completed'"]
        params: List[Any] = []
        cutoff_iso: Optional[str] = None
        if fac_clean != "ALL":
            clauses.append("faculty = ?")
            params.append(fac_clean)
        if year_clean != "ALL":
            clauses.append("academic_year = ?")
            params.append(year_clean)
        if period_clean in ("7d", "30d", "semester"):
            days = 7 if period_clean == "7d" else (30 if period_clean == "30d" else 120)
            cutoff_iso = (datetime.now(timezone.utc) - timedelta(days=days)).isoformat()
            clauses.append("completed_at >= ?")
            params.append(cutoff_iso)

        where_sql = " AND ".join(clauses)
        scr_rows = conn.execute(
            f"""
            SELECT tool_id, score, max_score, requires_attention, completed_at
            FROM screening_sessions
            WHERE {where_sql}
            ORDER BY completed_at ASC
            """,
            tuple(params),
        ).fetchall()

        n = len(scr_rows)

        # T24 & R4: Chặn hiển thị số liệu khi n < min_group_size (k-Anonymity)
        if n < min_group_size:
            return {
                "suppressed": True,
                "k_anonymity_blocked": True,
                "sample_size": n,
                "min_group_size": min_group_size,
                "faculty": fac_clean,
                "academic_year": year_clean,
                "period": period_clean,
                "message": (
                    f"Đã ẩn dữ liệu thống kê do kích thước mẫu thực tế của nhóm lọc (n = {n}) nhỏ hơn "
                    f"ngưỡng k-Anonymity tối thiểu ({min_group_size}) nhằm bảo vệ quyền riêng tư sinh viên (T24)."
                ),
                "metrics": None,
                "pii_included": False,
            }

        low_cnt = 0
        mod_cnt = 0
        high_cnt = 0
        tool_counts: Dict[str, int] = {"PHQ-9": 0, "GAD-7": 0, "DASS-21": 0}

        for r in scr_rows:
            t_id = r["tool_id"]
            if t_id in tool_counts:
                tool_counts[t_id] += 1
            score = r["score"] or 0
            max_s = max(r["max_score"] or 21, 1)
            ratio = score / max_s
            req_att = bool(r["requires_attention"])
            if not req_att:
                low_cnt += 1
            elif ratio >= 0.67 or (t_id in ("PHQ-9", "GAD-7") and score >= 15):
                high_cnt += 1
            else:
                mod_cnt += 1

        low_pct = round(low_cnt * 100.0 / n, 1)
        mod_pct = round(mod_cnt * 100.0 / n, 1)
        high_pct = round(max(0.0, 100.0 - low_pct - mod_pct), 1)
        attention_total = mod_cnt + high_cnt

        if cutoff_iso:
            connected_bookings = conn.execute(
                "SELECT COUNT(*) AS cnt FROM counseling_requests WHERE status IN ('pending', 'confirmed', 'accepted', 'completed') AND created_at >= ?",
                (cutoff_iso,),
            ).fetchone()["cnt"]
            mood_stats = conn.execute(
                "SELECT COUNT(*) AS cnt, AVG(mood_level) AS avg_lvl FROM mood_entries WHERE recorded_at >= ?",
                (cutoff_iso,),
            ).fetchone()
            cbt_completed_count = conn.execute(
                "SELECT COUNT(*) AS cnt FROM activity_progress WHERE status = 'completed' AND updated_at >= ?",
                (cutoff_iso,),
            ).fetchone()["cnt"]
        else:
            connected_bookings = conn.execute(
                "SELECT COUNT(*) AS cnt FROM counseling_requests WHERE status IN ('pending', 'confirmed', 'accepted', 'completed')"
            ).fetchone()["cnt"]
            mood_stats = conn.execute(
                "SELECT COUNT(*) AS cnt, AVG(mood_level) AS avg_lvl FROM mood_entries"
            ).fetchone()
            cbt_completed_count = conn.execute(
                "SELECT COUNT(*) AS cnt FROM activity_progress WHERE status = 'completed'"
            ).fetchone()["cnt"]

        mood_checkin_count = int(mood_stats["cnt"] or 0)
        avg_mood_level = round(float(mood_stats["avg_lvl"] or 0.0), 2)

        conversion_rate = round(
            min(100.0, (connected_bookings * 100.0) / max(n, 1)), 1
        )

        # Tổng hợp chủ đề ẩn danh từ reply_type & thang đo (tuyệt đối không đọc text hội thoại)
        type_rows = conn.execute(
            "SELECT reply_type, COUNT(*) AS cnt FROM chat_messages GROUP BY reply_type"
        ).fetchall()
        type_map = {r["reply_type"]: r["cnt"] for r in type_rows}

        acad_weight = tool_counts["DASS-21"] + type_map.get("supportive_chat", 0)
        anx_weight = tool_counts["GAD-7"] + type_map.get("cbt_coaching", 0)
        dep_weight = tool_counts["PHQ-9"]
        fin_rel_weight = (
            type_map.get("financial_stress_cbt", 0)
            + type_map.get("relationship_support", 0)
        )
        weight_sum = max(acad_weight + anx_weight + dep_weight + fin_rel_weight, 1)

        top_topics = [
            {
                "topic": "Áp lực học tập, thi cử & căng thẳng đa chiều",
                "percentage": round(acad_weight * 100.0 / weight_sum, 1),
            },
            {
                "topic": "Lo âu & điều hòa cảm xúc (GAD-7 / CBT)",
                "percentage": round(anx_weight * 100.0 / weight_sum, 1),
            },
            {
                "topic": "Giấc ngủ, năng lượng & khí sắc (PHQ-9)",
                "percentage": round(dep_weight * 100.0 / weight_sum, 1),
            },
            {
                "topic": "Tài chính, việc làm thêm & kết nối xã hội",
                "percentage": round(fin_rel_weight * 100.0 / weight_sum, 1),
            },
        ]

        # Tính xu hướng theo 4 chặng thời gian thực tế của tập mẫu
        chunk = max(n // 4, 1)
        weekly_trend = [
            len(scr_rows[0:chunk]),
            len(scr_rows[chunk : chunk * 2]),
            len(scr_rows[chunk * 2 : chunk * 3]),
            len(scr_rows[chunk * 3 :]),
        ]

    return {
        "suppressed": False,
        "k_anonymity_blocked": False,
        "sample_size": n,
        "min_group_size": min_group_size,
        "faculty": fac_clean,
        "academic_year": year_clean,
        "period": period_clean,
        "metrics": {
            "total_screenings": n,
            "high_risk_count": attention_total,
            "connected_bookings_count": connected_bookings,
            "booking_conversion_rate": conversion_rate,
            "mood_checkin_count": mood_checkin_count,
            "avg_mood_level": avg_mood_level,
            "cbt_completed_count": cbt_completed_count,
            "stress_distribution": {
                "low_stable_pct": low_pct,
                "moderate_watch_pct": mod_pct,
                "high_support_needed_pct": high_pct,
            },
            "top_topics_aggregated": top_topics,
            "weekly_checkin_trend": weekly_trend,
        },
        "pii_included": False,
    }


@app.get("/v1/safety-hotlines")
def list_safety_hotlines():
    """S21 & R3: Danh bạ khẩn cấp 115 / 111 và đơn vị hỗ trợ an toàn (truy cập tự do không cần đăng nhập)."""
    with get_db() as conn:
        rows = conn.execute(
            "SELECT * FROM safety_hotlines ORDER BY hotline_id ASC"
        ).fetchall()
        return {
            "items": [
                {
                    "hotline_id": r["hotline_id"],
                    "name": r["name"],
                    "phone": r["phone"],
                    "description": r["description"],
                    "hours": r["hours"],
                    "is_verified": bool(r["is_verified"]),
                    "updated_at": r["updated_at"],
                }
                for r in rows
            ]
        }


@app.post("/v1/admin/safety-hotlines")
def upsert_safety_hotline(
    payload: SafetyHotlineInput,
    authorization: str = Header(default=""),
    x_admin_actor: str = Header(default=""),
    x_staff_role: str = Header(default=""),
    x_staff_id: str = Header(default=""),
):
    name = payload.name.strip()
    phone = payload.phone.strip()
    desc = payload.description.strip()
    if not name or not phone or not desc:
        raise ApiError(
            status_code=400,
            code="VALIDATION_FAILED",
            message="Tên đơn vị, số điện thoại và mô tả hỗ trợ khẩn cấp không được để trống.",
        )
    hotline_id = (payload.hotline_id or "").strip() or f"hotline_{uuid.uuid4().hex[:6]}"
    ts = now_iso()
    with get_db() as conn:
        actor = require_admin_actor(
            conn,
            authorization=authorization,
            x_admin_actor=x_admin_actor,
            x_staff_role=x_staff_role,
            x_staff_id=x_staff_id,
        )
        conn.execute(
            """
            INSERT INTO safety_hotlines (hotline_id, name, phone, description, hours, is_verified, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(hotline_id) DO UPDATE SET
                name = excluded.name,
                phone = excluded.phone,
                description = excluded.description,
                hours = excluded.hours,
                is_verified = excluded.is_verified,
                updated_at = excluded.updated_at
            """,
            (
                hotline_id,
                name,
                phone,
                desc,
                payload.hours.strip() or "24/7",
                1 if payload.is_verified else 0,
                ts,
            ),
        )
        log_audit_event(
            conn,
            actor=actor,
            action=f"UPSERT_SAFETY_HOTLINE ({phone})",
            target=hotline_id,
            result="SUCCESS",
        )
    return {
        "hotline_id": hotline_id,
        "name": name,
        "phone": phone,
        "description": desc,
        "hours": payload.hours.strip() or "24/7",
        "is_verified": payload.is_verified,
        "updated_at": ts,
    }


@app.delete("/v1/admin/safety-hotlines/{hotline_id}")
def delete_safety_hotline(
    hotline_id: str,
    authorization: str = Header(default=""),
    x_admin_actor: str = Header(default=""),
    x_staff_role: str = Header(default=""),
    x_staff_id: str = Header(default=""),
):
    if hotline_id in ("hotline_115", "hotline_111"):
        raise ApiError(
            status_code=400,
            code="CORE_HOTLINE_PROTECTED",
            message="Không thể xóa đường dây nóng khẩn cấp quốc gia 115 / 111 (R3).",
        )
    with get_db() as conn:
        actor = require_admin_actor(
            conn,
            authorization=authorization,
            x_admin_actor=x_admin_actor,
            x_staff_role=x_staff_role,
            x_staff_id=x_staff_id,
        )
        conn.execute("DELETE FROM safety_hotlines WHERE hotline_id = ?", (hotline_id,))
        log_audit_event(
            conn,
            actor=actor,
            action=f"DELETE_SAFETY_HOTLINE ({hotline_id})",
            target=hotline_id,
            result="SUCCESS",
        )
    return {"deleted": True, "hotline_id": hotline_id}


@app.get("/v1/admin/staff-accounts")
def list_admin_staff_accounts(
    authorization: str = Header(default=""),
    x_admin_actor: str = Header(default=""),
    x_staff_role: str = Header(default=""),
    x_staff_id: str = Header(default=""),
):
    with get_db() as conn:
        require_admin_actor(
            conn,
            authorization=authorization,
            x_admin_actor=x_admin_actor,
            x_staff_role=x_staff_role,
            x_staff_id=x_staff_id,
        )
        rows = conn.execute(
            "SELECT staff_id, role, display_name, unit_name, is_active, created_at FROM staff_accounts ORDER BY staff_id ASC"
        ).fetchall()
        return {
            "items": [
                {
                    "staff_id": r["staff_id"],
                    "role": r["role"],
                    "display_name": r["display_name"],
                    "unit_name": r["unit_name"] or "Phòng Công tác Sinh viên & Tư vấn",
                    "is_active": bool(r["is_active"]),
                    "created_at": r["created_at"],
                }
                for r in rows
            ]
        }


@app.post("/v1/admin/staff-accounts")
def upsert_admin_staff_account(
    payload: StaffAccountUpsertInput,
    authorization: str = Header(default=""),
    x_admin_actor: str = Header(default=""),
    x_staff_role: str = Header(default=""),
    x_staff_id: str = Header(default=""),
):
    staff_id = payload.staff_id.strip()
    role = payload.role.strip().lower()
    display_name = payload.display_name.strip()
    if not staff_id or not display_name or role not in ("ctsv", "counselor", "admin"):
        raise ApiError(
            status_code=400,
            code="VALIDATION_FAILED",
            message="Mã nhân sự, họ tên hiển thị và vai trò (ctsv / counselor / admin) phải hợp lệ.",
        )
    with get_db() as conn:
        actor = require_admin_actor(
            conn,
            authorization=authorization,
            x_admin_actor=x_admin_actor,
            x_staff_role=x_staff_role,
            x_staff_id=x_staff_id,
        )
        existing = conn.execute(
            "SELECT * FROM staff_accounts WHERE staff_id = ?", (staff_id,)
        ).fetchone()
        raw_pw = (payload.password or "").strip()
        if not existing and len(raw_pw) < 6:
            raise ApiError(
                status_code=400,
                code="VALIDATION_FAILED",
                message="Mật khẩu khởi tạo cho tài khoản nhân sự mới phải từ 6 ký tự trở lên.",
            )
        pw_hash = hash_password(raw_pw) if raw_pw else existing["password_hash"]
        ts = now_iso()
        conn.execute(
            """
            INSERT INTO staff_accounts (staff_id, role, display_name, unit_name, is_active, password_hash, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(staff_id) DO UPDATE SET
                role = excluded.role,
                display_name = excluded.display_name,
                unit_name = excluded.unit_name,
                is_active = excluded.is_active,
                password_hash = excluded.password_hash
            """,
            (
                staff_id,
                role,
                display_name,
                payload.unit_name.strip() or "Phòng Công tác Sinh viên & Tư vấn",
                1 if payload.is_active else 0,
                pw_hash,
                ts,
            ),
        )
        log_audit_event(
            conn,
            actor=actor,
            action=f"UPSERT_STAFF_ACCOUNT ({staff_id}:{role})",
            target=staff_id,
            result="SUCCESS",
        )
    return {
        "staff_id": staff_id,
        "role": role,
        "display_name": display_name,
        "unit_name": payload.unit_name.strip() or "Phòng Công tác Sinh viên & Tư vấn",
        "is_active": payload.is_active,
        "created_at": ts,
    }


@app.patch("/v1/admin/staff-accounts/{staff_id}")
def patch_admin_staff_account(
    staff_id: str,
    payload: StaffAccountPatchInput,
    authorization: str = Header(default=""),
    x_admin_actor: str = Header(default=""),
    x_staff_role: str = Header(default=""),
    x_staff_id: str = Header(default=""),
):
    with get_db() as conn:
        actor = require_admin_actor(
            conn,
            authorization=authorization,
            x_admin_actor=x_admin_actor,
            x_staff_role=x_staff_role,
            x_staff_id=x_staff_id,
        )
        row = conn.execute(
            "SELECT * FROM staff_accounts WHERE staff_id = ?", (staff_id,)
        ).fetchone()
        if not row:
            raise ApiError(
                status_code=404,
                code="STAFF_ACCOUNT_NOT_FOUND",
                message="Không tìm thấy tài khoản nhân sự.",
            )
        new_role = (payload.role or row["role"]).strip().lower()
        if new_role not in ("ctsv", "counselor", "admin"):
            raise ApiError(
                status_code=400,
                code="VALIDATION_FAILED",
                message="Vai trò nhân sự không hợp lệ.",
            )
        new_name = (payload.display_name or row["display_name"]).strip()
        new_unit = (payload.unit_name or row["unit_name"] or "").strip()
        new_active = (
            (1 if payload.is_active else 0)
            if payload.is_active is not None
            else row["is_active"]
        )
        raw_pw = (payload.password or "").strip()
        new_pw_hash = hash_password(raw_pw) if len(raw_pw) >= 6 else row["password_hash"]
        conn.execute(
            """
            UPDATE staff_accounts
            SET role = ?, display_name = ?, unit_name = ?, is_active = ?, password_hash = ?
            WHERE staff_id = ?
            """,
            (new_role, new_name, new_unit, new_active, new_pw_hash, staff_id),
        )
        log_audit_event(
            conn,
            actor=actor,
            action=f"PATCH_STAFF_ACCOUNT ({staff_id}:active={bool(new_active)})",
            target=staff_id,
            result="SUCCESS",
        )
    return {
        "staff_id": staff_id,
        "role": new_role,
        "display_name": new_name,
        "unit_name": new_unit,
        "is_active": bool(new_active),
    }


@app.get("/v1/admin/analytics-policy")
def get_admin_analytics_policy(
    authorization: str = Header(default=""),
    x_admin_actor: str = Header(default=""),
    x_staff_role: str = Header(default=""),
    x_staff_id: str = Header(default=""),
):
    with get_db() as conn:
        require_admin_actor(
            conn,
            authorization=authorization,
            x_admin_actor=x_admin_actor,
            x_staff_role=x_staff_role,
            x_staff_id=x_staff_id,
        )
        min_group = _get_current_min_group_size(conn)
        audits = conn.execute(
            "SELECT * FROM audit_events ORDER BY timestamp DESC LIMIT 50"
        ).fetchall()
        return {
            "min_group_size": min_group,
            "raw_chat_access_allowed": False,
            "audit_events": [
                {
                    "event_id": r["event_id"],
                    "actor": r["actor"],
                    "action": r["action"],
                    "target": r["target"],
                    "result": r["result"],
                    "timestamp": r["timestamp"],
                }
                for r in audits
            ],
        }


@app.put("/v1/admin/analytics-policy")
def update_admin_analytics_policy(
    payload: AnalyticsPolicyUpdateInput,
    authorization: str = Header(default=""),
    x_admin_actor: str = Header(default=""),
    x_staff_role: str = Header(default=""),
    x_staff_id: str = Header(default=""),
):
    with get_db() as conn:
        effective_admin = require_admin_actor(
            conn,
            authorization=authorization,
            x_admin_actor=x_admin_actor,
            x_staff_role=x_staff_role,
            x_staff_id=x_staff_id,
        )
        audit = log_audit_event(
            conn,
            actor=effective_admin,
            action=f"UPDATE_MIN_GROUP_SIZE_POLICY ({payload.min_group_size})",
            target="AnalyticsPolicy",
            result="SUCCESS",
            metadata={"min_group_size": payload.min_group_size},
        )
    return {
        "min_group_size": payload.min_group_size,
        "updated_by": effective_admin,
        "audit_event": audit,
    }


@app.get("/v1/health")
def health_check():
    has_env_key = bool(os.getenv("GEMINI_API_KEY", "").strip())
    db_ok = False
    try:
        with get_db() as conn:
            conn.execute("SELECT 1").fetchone()
            db_ok = True
    except Exception:
        db_ok = False
    return {
        "status": "ok" if db_ok else "degraded",
        "version": "2.0.0",
        "database": "sqlite3_2zone_wal_ready" if db_ok else "db_error",
        "gemini_configured_on_server": has_env_key,
        "gemini_model": get_gemini_model(),
        "seed_demo_enabled": is_seed_demo_enabled(),
        "strict_staff_bearer": is_strict_staff_bearer_required(),
        "uptime_seconds": round(time.monotonic() - BOOT_TIME, 1),
        "timestamp": now_iso(),
    }
