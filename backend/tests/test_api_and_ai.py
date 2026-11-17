import atexit
import json
import os
import shutil
import sys
import tempfile
import unittest
from unittest.mock import AsyncMock, patch

import httpx

# Sử dụng DB tạm thời độc lập cho bộ kiểm thử tự động (tuyệt đối không chạm vào DB thật)
_TEMP_DB_DIR = tempfile.mkdtemp(prefix="mindcheck_test_")
atexit.register(lambda: shutil.rmtree(_TEMP_DB_DIR, ignore_errors=True))
os.environ["MINDCHECK_IGNORE_DOTENV"] = "1"
os.environ.pop("GEMINI_API_KEY", None)
os.environ.pop("GEMINI_MODEL", None)
os.environ["MINDCHECK_DB_PATH"] = os.path.join(_TEMP_DB_DIR, "test_mindcheck.db")
os.environ["MINDCHECK_SEED_DEMO"] = "0"
os.environ["MINDCHECK_CTSV_PASSWORD"] = "CtsvTestPass#2026"
os.environ["MINDCHECK_COUNSELOR1_PASSWORD"] = "Counselor1Pass#2026"
os.environ["MINDCHECK_COUNSELOR2_PASSWORD"] = "Counselor2Pass#2026"
os.environ["MINDCHECK_ADMIN_PASSWORD"] = "AdminTestPass#2026"

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
from app.main import _parse_dotenv_file, app, init_db  # noqa: E402


class MindCheckBackendApiAndAiTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        init_db()
        transport = httpx.ASGITransport(app=app)
        self.client = httpx.AsyncClient(transport=transport, base_url="http://testserver")

    async def asyncTearDown(self):
        await self.client.aclose()

    async def test_01_health_security_headers_and_catalogs(self):
        resp = await self.client.get("/v1/health")
        self.assertEqual(resp.status_code, 200)
        data = resp.json()
        self.assertEqual(data["status"], "ok")
        self.assertIn("sqlite3_2zone", data["database"])
        self.assertFalse(data["seed_demo_enabled"])
        self.assertEqual(resp.headers.get("x-content-type-options"), "nosniff")
        self.assertEqual(resp.headers.get("x-frame-options"), "DENY")
        self.assertEqual(resp.headers.get("referrer-policy"), "no-referrer")
        self.assertEqual(resp.headers.get("cache-control"), "no-store")

        # Đảm bảo môi trường bàn giao không tự động chèn dữ liệu demo req_demo_001
        no_demo = await self.client.get(
            "/v1/staff/counseling-requests/req_demo_001",
            headers={"X-Staff-Id": "counselor_01"},
        )
        self.assertEqual(no_demo.status_code, 404)

        # Kiểm tra danh mục bài viết kiến thức & bộ công cụ sàng lọc chuẩn (PHQ-9: 9, GAD-7: 7, DASS-21: 21)
        arts = await self.client.get("/v1/knowledge-articles")
        self.assertEqual(arts.status_code, 200)
        self.assertGreaterEqual(len(arts.json()["items"]), 3)

        tools_resp = await self.client.get("/v1/screening-tools")
        self.assertEqual(tools_resp.status_code, 200)
        tool_map = {t["tool_id"]: t for t in tools_resp.json()["items"]}
        self.assertEqual(len(tool_map["PHQ-9"]["questions"]), 9)
        self.assertEqual(len(tool_map["GAD-7"]["questions"]), 7)
        self.assertEqual(len(tool_map["DASS-21"]["questions"]), 21)

    async def test_02_onboarding_consent_auth_pbkdf2_and_preferences(self):
        # T02: Không cho tạo phiên khách nếu privacy_accepted = False
        bad_guest = await self.client.post(
            "/v1/guest-sessions", json={"privacy_accepted": False}
        )
        self.assertEqual(bad_guest.status_code, 400)
        self.assertEqual(bad_guest.json()["error"]["code"], "PRIVACY_CONSENT_REQUIRED")

        # Tạo phiên ẩn danh hợp lệ + nhận session_token
        ok_guest = await self.client.post(
            "/v1/guest-sessions", json={"privacy_accepted": True}
        )
        self.assertEqual(ok_guest.status_code, 200)
        guest_id = ok_guest.json()["guest_id"]
        subject_id = ok_guest.json()["subject_id"]
        guest_token = ok_guest.json()["session_token"]
        self.assertTrue(guest_token.startswith("tok_guest_"))

        # Kiểm tra validation đăng ký tài khoản
        bad_signup = await self.client.post(
            "/v1/auth/signup",
            json={"email": "invalid-email", "password": "123"},
        )
        self.assertEqual(bad_signup.status_code, 400)

        # Đăng ký & Đăng nhập bằng PBKDF2-HMAC-SHA256
        email = f"sv_{guest_id}@student.ctuet.edu.vn"
        signup = await self.client.post(
            "/v1/auth/signup",
            json={
                "email": email,
                "password": "SafePassword2026!",
                "full_name": "Sinh Viên Kiểm Thử",
                "faculty": "CNTT",
                "academic_year": "Nam_3",
            },
        )
        self.assertEqual(signup.status_code, 200)
        user_id = signup.json()["user_id"]
        self.assertTrue(signup.json()["access_token"].startswith("tok_student_"))

        dup_signup = await self.client.post(
            "/v1/auth/signup",
            json={"email": email, "password": "SafePassword2026!"},
        )
        self.assertEqual(dup_signup.status_code, 409)

        login_fail = await self.client.post(
            "/v1/auth/login", json={"email": email, "password": "WrongPassword"}
        )
        self.assertEqual(login_fail.status_code, 401)

        # F03 / R2: Liên kết phiên khách khi chưa đồng ý -> Bị chặn 403 CONSENT_REQUIRED
        link_blocked = await self.client.post(
            "/v1/guest-sessions/link",
            json={"guest_id": guest_id, "user_id": user_id, "consent_to_link": False},
        )
        self.assertEqual(link_blocked.status_code, 403)
        self.assertEqual(link_blocked.json()["error"]["code"], "CONSENT_REQUIRED")

        # Liên kết hợp lệ khi có sự đồng ý rõ ràng
        link_ok = await self.client.post(
            "/v1/guest-sessions/link",
            json={"guest_id": guest_id, "user_id": user_id, "consent_to_link": True},
        )
        self.assertEqual(link_ok.status_code, 200)
        self.assertTrue(link_ok.json()["linked"])

        # Đăng nhập lại phải tự động ánh xạ sang subject_id của phiên khách đã liên kết
        login_ok = await self.client.post(
            "/v1/auth/login", json={"email": email, "password": "SafePassword2026!"}
        )
        self.assertEqual(login_ok.status_code, 200)
        self.assertEqual(login_ok.json()["user_id"], user_id)
        self.assertEqual(login_ok.json()["subject_id"], subject_id)
        student_token = login_ok.json()["access_token"]

        # Tùy biến cá nhân hóa Người bạn số & Thông báo nhắc nhở kín đáo
        empty_nick = await self.client.put(
            "/v1/me/companion-preferences",
            headers={"Authorization": f"Bearer {student_token}"},
            json={"nickname": "   "},
        )
        self.assertEqual(empty_nick.status_code, 400)

        pref_put = await self.client.put(
            "/v1/me/companion-preferences",
            headers={"Authorization": f"Bearer {student_token}"},
            json={
                "nickname": "Bạn Mây",
                "user_pronoun": "em",
                "ai_pronoun": "mình",
                "tone": "nhẹ nhàng, khích lệ",
            },
        )
        self.assertEqual(pref_put.status_code, 200)
        pref_get = await self.client.get(
            "/v1/me/companion-preferences",
            headers={"Authorization": f"Bearer {student_token}"},
        )
        self.assertEqual(pref_get.json()["nickname"], "Bạn Mây")

        notif_put = await self.client.put(
            "/v1/me/notification-preferences",
            headers={"Authorization": f"Bearer {student_token}"},
            json={
                "enabled": True,
                "reminder_time": "21:15",
                "quiet_hours": "22:30 - 06:30",
                "hide_sensitive_on_lock_screen": True,
            },
        )
        self.assertEqual(notif_put.status_code, 200)
        notif_get = await self.client.get(
            "/v1/me/notification-preferences",
            headers={"Authorization": f"Bearer {student_token}"},
        )
        self.assertEqual(notif_get.json()["reminder_time"], "21:15")

    async def test_03_ai_safety_guardrail_non_diagnostic_and_no_false_positive(self):
        # R3: Tin nhắn nguy cơ cao có dấu -> Kích hoạt Safety Guardrail ngay lập tức
        crisis_1 = await self.client.post(
            "/v1/chats/chat_safety/messages",
            json={
                "client_message_id": "cmsg_safety_01",
                "text": "Dạo này mình bế tắc quá và không muốn sống nữa",
                "subject_id": "sub_safety",
            },
        )
        self.assertEqual(crisis_1.status_code, 200)
        self.assertEqual(crisis_1.json()["reply_type"], "safety_escalation")
        self.assertEqual(crisis_1.json()["suggested_action"], "open_safety_support")
        self.assertIn("115", crisis_1.json()["reply"])

        # R3: Tin nhắn nguy cơ cao KHÔNG DẤU trên điện thoại -> Vẫn kích hoạt Safety Guardrail
        crisis_unaccented = await self.client.post(
            "/v1/chats/chat_safety/messages",
            json={
                "client_message_id": "cmsg_safety_02",
                "text": "em met moi lam, em khong muon song nua",
                "subject_id": "sub_safety",
            },
        )
        self.assertEqual(crisis_unaccented.status_code, 200)
        self.assertEqual(crisis_unaccented.json()["reply_type"], "safety_escalation")

        # Kiểm tra chống dương tính giả (False Positive) với từ "từ từ" trong bài tập thở
        safe_breath = await self.client.post(
            "/v1/chats/chat_safety/messages",
            json={
                "client_message_id": "cmsg_safe_breath_01",
                "text": "Mình đang tập hít thở từ từ theo hướng dẫn bài tập thở",
                "subject_id": "sub_safety",
            },
        )
        self.assertEqual(safe_breath.status_code, 200)
        self.assertNotEqual(safe_breath.json()["reply_type"], "safety_escalation")
        self.assertEqual(safe_breath.json()["reply_type"], "cbt_coaching")

        # R1: Hậu kiểm chống chẩn đoán bệnh lý / tự suy diễn điểm PHQ-9 từ LLM
        async def _mock_bad_diagnostic_llm(url, request_body, headers=None):
            payload = {
                "candidates": [
                    {
                        "content": {
                            "parts": [
                                {
                                    "text": json.dumps(
                                        {
                                            "reply": "Mình chẩn đoán em bị trầm cảm nặng và điểm PHQ-9 của em là 22.",
                                            "quick_replies": ["Vâng"],
                                            "should_suggest_screening": True,
                                            "memory_candidate": None,
                                        },
                                        ensure_ascii=False,
                                    )
                                }
                            ]
                        }
                    }
                ]
            }
            return httpx.Response(200, json=payload)

        with patch("app.main._post_gemini_api", new=AsyncMock(side_effect=_mock_bad_diagnostic_llm)):
            guarded = await self.client.post(
                "/v1/chats/chat_safety/messages",
                headers={"X-Gemini-Key": "AIzaSyMockDiagnosticGuard"},
                json={
                    "client_message_id": "cmsg_guardrail_r1",
                    "text": "Gần đây em hơi buồn vì điểm thi thấp",
                    "subject_id": "sub_safety",
                    "user_pronoun": "em",
                    "ai_pronoun": "mình",
                },
            )
            self.assertEqual(guarded.status_code, 200)
            self.assertNotIn("chẩn đoán em bị", guarded.json()["reply"].lower())
            self.assertIn("không thực hiện chẩn đoán bệnh lý", guarded.json()["reply"])
            self.assertFalse(guarded.json()["is_clinical_diagnosis"])

    async def test_04_chat_idempotency_multiturn_gemini_header_and_memory_lifecycle(self):
        subj = "sub_mem_test"
        # Tạo phiên chat mới
        created_chat = await self.client.post(
            "/v1/chats",
            headers={"X-Subject-Id": subj},
            json={"subject_id": subj, "title": "Ôn thi Giải tích"},
        )
        self.assertEqual(created_chat.status_code, 200)
        chat_id = created_chat.json()["session_id"]

        # T05: Idempotency chống nhân đôi tin nhắn khi gửi lại cùng client_message_id
        msg_payload = {
            "client_message_id": "cmsg_idem_100",
            "text": "Gần đây em mất ngủ và rất áp lực vì sắp thi cuối kỳ môn Giải tích.",
            "subject_id": subj,
            "ai_nickname": "Mây",
            "user_pronoun": "em",
            "ai_pronoun": "mình",
        }
        first = await self.client.post(f"/v1/chats/{chat_id}/messages", json=msg_payload)
        self.assertEqual(first.status_code, 200)
        first_data = first.json()
        self.assertTrue(first_data["should_suggest_screening"])
        self.assertIsNotNone(first_data["memory_proposal"])
        self.assertFalse(first_data["demo"])

        replay = await self.client.post(f"/v1/chats/{chat_id}/messages", json=msg_payload)
        self.assertEqual(replay.status_code, 200)
        self.assertTrue(replay.json().get("idempotent_replay"))
        self.assertEqual(replay.json()["message_id"], first_data["message_id"])

        # Kiểm thử Gemini 2.5 Flash: Key nằm trong header x-goog-api-key (KHÔNG nằm trên URL) + Multi-turn Context
        captured_gemini_req = {}

        async def _mock_gemini_post(url, request_body, headers=None):
            captured_gemini_req["url"] = url
            captured_gemini_req["body"] = request_body
            captured_gemini_req["headers"] = headers or {}
            mock_gemini_payload = {
                "candidates": [
                    {
                        "content": {
                            "parts": [
                                {
                                    "text": (
                                        '{"reply": "Mình hiểu môn Giải tích đang làm em căng thẳng. '
                                        'Chúng mình chia đề cương thành 3 phần nhỏ nhé?", '
                                        '"quick_replies": ["Chia đề cương ngay", "Tập thở 2 phút"], '
                                        '"should_suggest_screening": false, '
                                        '"memory_candidate": "Đang ôn thi cuối kỳ môn Giải tích"}'
                                    )
                                }
                            ]
                        }
                    }
                ]
            }
            return httpx.Response(200, json=mock_gemini_payload)

        with patch("app.main._post_gemini_api", new=AsyncMock(side_effect=_mock_gemini_post)):
            second = await self.client.post(
                f"/v1/chats/{chat_id}/messages",
                headers={"X-Gemini-Key": "AIzaSyMockTestKeyForUnitTesting"},
                json={
                    "client_message_id": "cmsg_gemini_turn_2",
                    "text": "Đúng rồi ạ, chương tích phân khó quá làm em lo không kịp.",
                    "subject_id": subj,
                    "context_opt_in": True,
                },
            )
            self.assertEqual(second.status_code, 200)
            s_data = second.json()
            self.assertIn("Google Gemini", s_data["provider_badge"])
            self.assertIn("Giải tích", s_data["reply"])
            self.assertNotIn("AIza", captured_gemini_req["url"])
            self.assertEqual(
                captured_gemini_req["headers"].get("x-goog-api-key"),
                "AIzaSyMockTestKeyForUnitTesting",
            )
            self.assertGreaterEqual(len(captured_gemini_req["body"]["contents"]), 3)

        # Không có X-Subject-Id khi lấy lịch sử -> Chặn 401 SUBJECT_IDENTITY_REQUIRED
        unauth_hist = await self.client.get(f"/v1/chats/{chat_id}/messages")
        self.assertEqual(unauth_hist.status_code, 401)

        hist = await self.client.get(
            f"/v1/chats/{chat_id}/messages", headers={"X-Subject-Id": subj}
        )
        self.assertEqual(hist.status_code, 200)
        self.assertEqual(len(hist.json()["items"]), 2)

        # T07-T09 & R2: Vòng đời Trí nhớ AI (Thiếu decision -> 400; Từ chối -> Không lưu; Duyệt -> Sửa -> Xóa)
        prop_1 = first_data["memory_proposal"]["proposal_id"]
        no_decision = await self.client.post(
            f"/v1/memories/{prop_1}/approve",
            headers={"X-Subject-Id": subj},
            json={"subject_id": subj},
        )
        self.assertEqual(no_decision.status_code, 400)

        reject_res = await self.client.post(
            f"/v1/memories/{prop_1}/approve",
            headers={"X-Subject-Id": subj},
            json={"decision": "rejected", "subject_id": subj},
        )
        self.assertEqual(reject_res.status_code, 200)
        self.assertEqual(reject_res.json()["status"], "rejected")
        self.assertIsNone(reject_res.json()["approved_memory"])

        prop_2 = s_data["memory_proposal"]["proposal_id"]
        approve_res = await self.client.post(
            f"/v1/memories/{prop_2}/approve",
            headers={"X-Subject-Id": subj},
            json={"decision": "accepted", "subject_id": subj},
        )
        self.assertEqual(approve_res.status_code, 200)
        mem_id = approve_res.json()["approved_memory"]["memory_id"]

        patch_res = await self.client.patch(
            f"/v1/memories/{mem_id}",
            headers={"X-Subject-Id": subj},
            json={"text": "Cần ưu tiên ngủ trước 23h mùa thi Giải tích"},
        )
        self.assertEqual(patch_res.status_code, 200)
        self.assertEqual(
            patch_res.json()["text"], "Cần ưu tiên ngủ trước 23h mùa thi Giải tích"
        )

        del_res = await self.client.delete(
            f"/v1/memories/{mem_id}", headers={"X-Subject-Id": subj}
        )
        self.assertEqual(del_res.status_code, 200)
        self.assertTrue(del_res.json()["deleted"])

        # F10: Thêm trí nhớ thủ công không có consent -> Bị chặn 403 CONSENT_REQUIRED
        manual_blocked = await self.client.post(
            "/v1/memories",
            headers={"X-Subject-Id": subj},
            json={"subject_id": subj, "text": "Thích nghe nhạc piano khi ôn bài", "consent_accepted": False},
        )
        self.assertEqual(manual_blocked.status_code, 403)

        manual_ok = await self.client.post(
            "/v1/memories",
            headers={"X-Subject-Id": subj},
            json={"subject_id": subj, "text": "Thích nghe nhạc piano khi ôn bài", "consent_accepted": True},
        )
        self.assertEqual(manual_ok.status_code, 200)
        self.assertTrue(manual_ok.json()["consent_id"].startswith("con_"))

    async def test_05_mood_5_scale_weekly_reflection_boundary_and_daily_cbt(self):
        subj = "sub_mood_tester"
        # Kiểm tra biên giá trị mood_level (chỉ chấp nhận 1..5)
        bad_mood = await self.client.post(
            "/v1/mood-entries",
            json={"subject_id": subj, "mood_choice": "Sai biên", "mood_level": 6},
        )
        self.assertEqual(bad_mood.status_code, 422)

        # T13: Khi chưa có bản ghi (0/3) -> insufficient_data = True
        empty_ref = await self.client.get(
            "/v1/weekly-reflections", params={"subject_id": subj}
        )
        self.assertEqual(empty_ref.status_code, 200)
        self.assertTrue(empty_ref.json()["insufficient_data"])

        created_entries = []
        for lvl, label in [(5, "🌟 Rất tích cực"), (3, "😐 Hơi mệt")]:
            r = await self.client.post(
                "/v1/mood-entries",
                json={
                    "subject_id": subj,
                    "mood_choice": label,
                    "mood_level": lvl,
                    "optional_note": "Check-in tự động",
                },
            )
            self.assertEqual(r.status_code, 200)
            created_entries.append(r.json()["entry_id"])

        # T13 biên: Mới có 2/3 bản ghi -> Vẫn phải báo insufficient_data = True
        two_ref = await self.client.get(
            "/v1/weekly-reflections", params={"subject_id": subj}
        )
        self.assertTrue(two_ref.json()["insufficient_data"])
        self.assertEqual(two_ref.json()["entry_count"], 2)

        # Thêm bản ghi thứ 3 -> Đủ ngưỡng tổng hợp tuần
        r3 = await self.client.post(
            "/v1/mood-entries",
            json={"subject_id": subj, "mood_choice": "😊 Ổn định", "mood_level": 4},
        )
        self.assertEqual(r3.status_code, 200)
        created_entries.append(r3.json()["entry_id"])

        act_res = await self.client.post(
            "/v1/activity-progress",
            json={"subject_id": subj, "activity_id": "act_01", "status": "completed"},
        )
        self.assertEqual(act_res.status_code, 200)

        full_ref = await self.client.get(
            "/v1/weekly-reflections", params={"subject_id": subj}
        )
        self.assertFalse(full_ref.json()["insufficient_data"])
        self.assertEqual(full_ref.json()["average_mood_level"], 4.0)
        self.assertEqual(full_ref.json()["completed_activities"], 1)

        # Xóa 1 bản ghi cảm xúc -> Quay lại 2/3 -> insufficient_data = True
        del_mood = await self.client.delete(
            f"/v1/mood-entries/{created_entries[0]}",
            headers={"X-Subject-Id": subj},
        )
        self.assertEqual(del_mood.status_code, 200)

        after_del_ref = await self.client.get(
            "/v1/weekly-reflections", params={"subject_id": subj}
        )
        self.assertTrue(after_del_ref.json()["insufficient_data"])

    async def test_06_screening_consent_purpose_validation_dass21_and_item9_safety(self):
        subj = "sub_scr"
        # T14: Không có consent_id -> Bị chặn 403 CONSENT_REQUIRED
        no_consent = await self.client.post(
            "/v1/screening-sessions",
            json={"tool_id": "PHQ-9", "subject_id": subj},
        )
        self.assertEqual(no_consent.status_code, 403)
        self.assertEqual(no_consent.json()["error"]["code"], "CONSENT_REQUIRED")

        # R2: Dùng sai mục đích consent ('privacy_policy' thay vì 'screening') -> Chặn 403 CONSENT_PURPOSE_MISMATCH
        wrong_purpose = await self.client.post(
            "/v1/consents",
            json={"subject_id": subj, "purpose": "privacy_policy", "decision": "accepted"},
        )
        wrong_cid = wrong_purpose.json()["consent_id"]
        mismatch_res = await self.client.post(
            "/v1/screening-sessions",
            json={"tool_id": "PHQ-9", "consent_id": wrong_cid, "subject_id": subj},
        )
        self.assertEqual(mismatch_res.status_code, 403)
        self.assertEqual(mismatch_res.json()["error"]["code"], "CONSENT_PURPOSE_MISMATCH")

        # R2: Dùng consent của subject khác -> Chặn 403 CONSENT_SUBJECT_MISMATCH
        other_c = await self.client.post(
            "/v1/consents",
            json={"subject_id": "sub_other_person", "purpose": "screening", "decision": "accepted"},
        )
        other_mismatch = await self.client.post(
            "/v1/screening-sessions",
            json={"tool_id": "PHQ-9", "consent_id": other_c.json()["consent_id"], "subject_id": subj},
        )
        self.assertEqual(other_mismatch.status_code, 403)
        self.assertEqual(other_mismatch.json()["error"]["code"], "CONSENT_SUBJECT_MISMATCH")

        # Tạo consent hợp lệ đúng mục đích 'screening'
        c_res = await self.client.post(
            "/v1/consents",
            json={"subject_id": subj, "purpose": "screening", "decision": "accepted"},
        )
        consent_id = c_res.json()["consent_id"]

        # T16: Thoát giữa chừng (completed=False) -> status = abandoned, score = None
        sess_ab = await self.client.post(
            "/v1/screening-sessions",
            json={"tool_id": "GAD-7", "consent_id": consent_id, "subject_id": subj},
        )
        ab_id = sess_ab.json()["session_id"]
        ab_put = await self.client.put(
            f"/v1/screening-sessions/{ab_id}/answers",
            headers={"X-Subject-Id": subj},
            json={"answers": [1, 2], "completed": False},
        )
        self.assertEqual(ab_put.status_code, 200)
        self.assertEqual(ab_put.json()["status"], "abandoned")
        self.assertIsNone(ab_put.json()["score"])

        # Validation: Điểm ngoài khoảng 0..3 hoặc nộp thiếu câu khi completed=True
        sess_phq = await self.client.post(
            "/v1/screening-sessions",
            json={"tool_id": "PHQ-9", "consent_id": consent_id, "subject_id": subj},
        )
        phq_id = sess_phq.json()["session_id"]

        bad_range = await self.client.put(
            f"/v1/screening-sessions/{phq_id}/answers",
            headers={"X-Subject-Id": subj},
            json={"answers": [0, 0, 0, 0, 0, 0, 0, 0, 4], "completed": True},
        )
        self.assertEqual(bad_range.status_code, 400)
        self.assertEqual(bad_range.json()["error"]["code"], "INVALID_ANSWER_RANGE")

        incomplete = await self.client.put(
            f"/v1/screening-sessions/{phq_id}/answers",
            headers={"X-Subject-Id": subj},
            json={"answers": [1, 2, 1], "completed": True},
        )
        self.assertEqual(incomplete.status_code, 400)
        self.assertEqual(incomplete.json()["error"]["code"], "INCOMPLETE_ANSWERS")

        # R3 & T17: PHQ-9 tổng điểm thấp (1/27) nhưng Câu số 9 >= 1 -> Phải bật cảnh báo an toàn 2 lớp (115/111 + S23)
        phq_put = await self.client.put(
            f"/v1/screening-sessions/{phq_id}/answers",
            headers={"X-Subject-Id": subj},
            json={"answers": [0, 0, 0, 0, 0, 0, 0, 0, 1], "completed": True},
        )
        self.assertEqual(phq_put.status_code, 200)
        self.assertTrue(phq_put.json()["requires_attention"])
        self.assertTrue(phq_put.json()["item9_safety_alert"])
        self.assertEqual(phq_put.json()["recommended_layer"], "layer_1_and_2_safety")
        self.assertIn("115", phq_put.json()["interpretation"])
        self.assertFalse(phq_put.json()["demo_flag"])
        self.assertFalse(phq_put.json()["is_clinical_diagnosis"])

        # DASS-21 chuẩn đủ 21 câu hỏi
        sess_dass = await self.client.post(
            "/v1/screening-sessions",
            json={"tool_id": "DASS-21", "consent_id": consent_id, "subject_id": subj},
        )
        dass_put = await self.client.put(
            f"/v1/screening-sessions/{sess_dass.json()['session_id']}/answers",
            headers={"X-Subject-Id": subj},
            json={"answers": [2] * 21, "completed": True},
        )
        self.assertEqual(dass_put.status_code, 200)
        self.assertEqual(dass_put.json()["score"], 42)
        self.assertEqual(dass_put.json()["max_score"], 63)
        self.assertTrue(dass_put.json()["requires_attention"])

        # Lấy lịch sử sàng lọc cá nhân từ SQLite (chỉ gồm các phiên completed)
        hist = await self.client.get(
            "/v1/screening-sessions", headers={"X-Subject-Id": subj}
        )
        self.assertEqual(hist.status_code, 200)
        self.assertEqual(len(hist.json()["items"]), 2)

    async def test_07_counseling_booking_pii_protection_cancel_and_whitelist(self):
        c_res = await self.client.post(
            "/v1/consents",
            json={
                "subject_id": "sub_book",
                "purpose": "counseling_share",
                "decision": "accepted",
            },
        )
        cid = c_res.json()["consent_id"]

        # Validation định dạng thông tin liên hệ
        bad_contact = await self.client.post(
            "/v1/counseling-requests",
            json={
                "counselor_id": "counselor_01",
                "slot_time": "Thứ 5 (14:00 - 15:00)",
                "contact_info": "lien_he_khong_hop_le",
                "consent_id": cid,
                "subject_id": "sub_book",
            },
        )
        self.assertEqual(bad_contact.status_code, 400)

        # T21: Tạo lịch hẹn hợp lệ có idempotency_key & nhận requester_token bảo mật
        book_payload = {
            "idempotency_key": "idem_booking_999",
            "counselor_id": "counselor_01",
            "counselor_name": "ThS. Nguyễn Văn A",
            "slot_time": "Thứ 5 (14:00 - 15:00)",
            "contact_info": "sv_book@student.ctuet.edu.vn",
            "student_note": "Cần tư vấn kỹ năng quản lý thời gian ôn thi",
            "consent_id": cid,
            "subject_id": "sub_book",
        }
        b1 = await self.client.post("/v1/counseling-requests", json=book_payload)
        self.assertEqual(b1.status_code, 200)
        req_id = b1.json()["request_id"]
        btk = b1.json()["requester_token"]
        self.assertTrue(btk.startswith("btk_"))

        # Replay cùng idempotency_key + cùng consent_id -> thành công
        b2_replay = await self.client.post("/v1/counseling-requests", json=book_payload)
        self.assertEqual(b2_replay.status_code, 200)
        self.assertTrue(b2_replay.json().get("idempotent_replay"))
        self.assertEqual(b2_replay.json()["request_id"], req_id)

        # Kẻ tấn công đoán idempotency_key nhưng không có consent_id gốc -> Chặn 409 (chống lộ PII)
        spoof_replay = await self.client.post(
            "/v1/counseling-requests",
            json={**book_payload, "consent_id": "con_spoof"},
        )
        self.assertEqual(spoof_replay.status_code, 409)

        # Chống lộ PII: GET /v1/counseling-requests không có token xác thực phải trả 401 thay vì lộ 50 dòng
        unauth_list = await self.client.get("/v1/counseling-requests")
        self.assertEqual(unauth_list.status_code, 401)

        # Sinh viên có X-Booking-Token xem đúng lịch hẹn của chính mình
        own_list = await self.client.get(
            "/v1/counseling-requests",
            headers={"X-Booking-Token": btk},
        )
        self.assertEqual(own_list.status_code, 200)
        self.assertEqual(len(own_list.json()["items"]), 1)
        self.assertEqual(own_list.json()["items"][0]["request_id"], req_id)

        # Người khác có token sai không thể hủy lịch hẹn
        wrong_cancel = await self.client.patch(
            f"/v1/counseling-requests/{req_id}/cancel",
            headers={"X-Booking-Token": "btk_wrong_token"},
        )
        self.assertEqual(wrong_cancel.status_code, 403)

        # Chính chủ hủy lịch hẹn thành công
        ok_cancel = await self.client.patch(
            f"/v1/counseling-requests/{req_id}/cancel",
            headers={"X-Booking-Token": btk},
        )
        self.assertEqual(ok_cancel.status_code, 200)
        self.assertEqual(ok_cancel.json()["status"], "canceled")

    async def test_08_strict_4_role_rbac_staff_login_and_cross_counselor_isolation(self):
        # Đăng nhập 4 tài khoản nhân sự thật qua /v1/auth/staff-login
        bad_staff = await self.client.post(
            "/v1/auth/staff-login",
            json={"staff_id": "admin_01", "password": "WrongPassword"},
        )
        self.assertEqual(bad_staff.status_code, 401)

        ctsv_login = await self.client.post(
            "/v1/auth/staff-login",
            json={"staff_id": "ctsv_01", "password": "CtsvTestPass#2026"},
        )
        c1_login = await self.client.post(
            "/v1/auth/staff-login",
            json={"staff_id": "counselor_01", "password": "Counselor1Pass#2026"},
        )
        c2_login = await self.client.post(
            "/v1/auth/staff-login",
            json={"staff_id": "counselor_02", "password": "Counselor2Pass#2026"},
        )
        adm_login = await self.client.post(
            "/v1/auth/staff-login",
            json={"staff_id": "admin_01", "password": "AdminTestPass#2026"},
        )
        for res in (ctsv_login, c1_login, c2_login, adm_login):
            self.assertEqual(res.status_code, 200)

        ctsv_hdr = {"Authorization": f"Bearer {ctsv_login.json()['access_token']}"}
        c1_hdr = {"Authorization": f"Bearer {c1_login.json()['access_token']}"}
        c2_hdr = {"Authorization": f"Bearer {c2_login.json()['access_token']}"}
        adm_hdr = {"Authorization": f"Bearer {adm_login.json()['access_token']}"}

        # R4, R5, T23, F37, T27: CTSV, Tư vấn viên và Admin TUYỆT ĐỐI BỊ CHẶN (403) khỏi dữ liệu lâm sàng cá nhân
        for staff_hdr in (ctsv_hdr, c1_hdr, adm_hdr):
            r_chats = await self.client.get("/v1/chats", headers=staff_hdr)
            self.assertEqual(r_chats.status_code, 403)
            self.assertEqual(r_chats.json()["error"]["code"], "STAFF_CLINICAL_ACCESS_FORBIDDEN")

            r_mem = await self.client.get("/v1/memories", headers=staff_hdr)
            self.assertEqual(r_mem.status_code, 403)

            r_mood = await self.client.get("/v1/mood-entries", headers=staff_hdr)
            self.assertEqual(r_mood.status_code, 403)

            r_scr = await self.client.get("/v1/screening-sessions", headers=staff_hdr)
            self.assertEqual(r_scr.status_code, 403)

        # Tạo 1 lịch hẹn gán cho counselor_01
        c_res = await self.client.post(
            "/v1/consents",
            json={"subject_id": "sub_rbac", "purpose": "counseling_share", "decision": "accepted"},
        )
        b_res = await self.client.post(
            "/v1/counseling-requests",
            json={
                "counselor_id": "counselor_01",
                "counselor_name": "ThS. Nguyễn Văn A",
                "slot_time": "Thứ 3 (09:00 - 10:00)",
                "contact_info": "0912345678",
                "student_note": "Mong được tư vấn về áp lực đồ án",
                "consent_id": c_res.json()["consent_id"],
                "subject_id": "sub_rbac",
            },
        )
        req_id = b_res.json()["request_id"]

        # R5: CTSV và Admin không được xem danh sách ca tư vấn định danh của sinh viên
        self.assertEqual(
            (await self.client.get("/v1/staff/counseling-requests", headers=ctsv_hdr)).status_code,
            403,
        )
        self.assertEqual(
            (await self.client.get("/v1/staff/counseling-requests", headers=adm_hdr)).status_code,
            403,
        )

        # T25: counselor_02 cố đọc/cập nhật ca của counselor_01 -> Chặn 403 & ghi Audit Log
        c2_read = await self.client.get(
            f"/v1/staff/counseling-requests/{req_id}", headers=c2_hdr
        )
        self.assertEqual(c2_read.status_code, 403)
        self.assertEqual(c2_read.json()["error"]["code"], "FORBIDDEN_CROSS_COUNSELOR_ACCESS")

        # F37 & T22: counselor_01 xác nhận ca hợp lệ, chỉ nhận trường Whitelist
        c1_patch = await self.client.patch(
            f"/v1/staff/counseling-requests/{req_id}",
            headers=c1_hdr,
            json={
                "status": "confirmed",
                "counselor_note": "Mời em ghé Phòng Tư vấn P.102 lúc 09:00 nhé.",
            },
        )
        self.assertEqual(c1_patch.status_code, 200)
        body = c1_patch.json()
        self.assertEqual(body["status"], "confirmed")
        self.assertNotIn("chat_text", body)
        self.assertNotIn("screening_score", body)
        self.assertNotIn("requester_token_hash", body)

        # R5: Tư vấn viên bị chặn khỏi Analytics toàn trường & Admin Policy
        self.assertEqual(
            (await self.client.get("/v1/analytics/overview", headers=c1_hdr)).status_code,
            403,
        )
        self.assertEqual(
            (await self.client.get("/v1/admin/analytics-policy", headers=c1_hdr)).status_code,
            403,
        )
        # CTSV xem được Analytics nhưng bị chặn khỏi Admin Policy
        self.assertEqual(
            (await self.client.get("/v1/admin/analytics-policy", headers=ctsv_hdr)).status_code,
            403,
        )

        # Admin xem Audit Logs nhưng raw_chat_access_allowed = False
        adm_pol = await self.client.get("/v1/admin/analytics-policy", headers=adm_hdr)
        self.assertEqual(adm_pol.status_code, 200)
        self.assertFalse(adm_pol.json()["raw_chat_access_allowed"])
        self.assertTrue(
            any(
                ev["result"] == "DENIED_CROSS_COUNSELOR"
                for ev in adm_pol.json()["audit_events"]
            )
        )

    async def test_09_real_sqlite_analytics_aggregation_and_kanonymity_threshold(self):
        # Hàm phụ tạo phiên sàng lọc thật trong SQLite
        async def _seed_screening(idx: int, faculty: str, answers):
            subj = f"sub_stat_{faculty}_{idx}"
            c = await self.client.post(
                "/v1/consents",
                json={"subject_id": subj, "purpose": "screening", "decision": "accepted"},
            )
            s = await self.client.post(
                "/v1/screening-sessions",
                json={
                    "tool_id": "GAD-7",
                    "consent_id": c.json()["consent_id"],
                    "subject_id": subj,
                    "faculty": faculty,
                    "academic_year": "Nam_2",
                },
            )
            p = await self.client.put(
                f"/v1/screening-sessions/{s.json()['session_id']}/answers",
                headers={"X-Subject-Id": subj},
                json={"answers": answers, "completed": True},
            )
            self.assertEqual(p.status_code, 200)

        # Nhóm NGON_NGU chỉ có 4 mẫu (< 10) -> Bắt buộc bị khóa k-Anonymity
        for i in range(4):
            await _seed_screening(i, "NGON_NGU", [1, 1, 1, 0, 0, 1, 0])

        # Nhóm CNTT_K48 có 12 mẫu (>= 10): 8 mẫu ổn định, 4 mẫu cần chú ý
        for i in range(8):
            await _seed_screening(i, "CNTT_K48", [0, 1, 0, 1, 0, 0, 1])
        for i in range(8, 12):
            await _seed_screening(i, "CNTT_K48", [3, 2, 2, 2, 2, 2, 2])

        ctsv_hdr = {"X-Staff-Role": "ctsv", "X-Staff-Id": "ctsv_01"}

        # T24 & R4: n = 4 < min_group_size (10) -> suppressed = True
        suppressed = await self.client.get(
            "/v1/analytics/overview",
            params={"faculty": "NGON_NGU"},
            headers=ctsv_hdr,
        )
        self.assertEqual(suppressed.status_code, 200)
        self.assertTrue(suppressed.json()["suppressed"])
        self.assertEqual(suppressed.json()["sample_size"], 4)
        self.assertIsNone(suppressed.json()["metrics"])

        # T23 & R4: n = 12 >= 10 -> Hiển thị số liệu thực từ SQLite, không có PII
        allowed = await self.client.get(
            "/v1/analytics/overview",
            params={"faculty": "CNTT_K48"},
            headers=ctsv_hdr,
        )
        self.assertEqual(allowed.status_code, 200)
        a_json = allowed.json()
        self.assertFalse(a_json["suppressed"])
        self.assertFalse(a_json["pii_included"])
        self.assertEqual(a_json["sample_size"], 12)
        self.assertEqual(a_json["metrics"]["total_screenings"], 12)
        self.assertEqual(a_json["metrics"]["high_risk_count"], 4)
        raw_dump = json.dumps(a_json, ensure_ascii=False)
        self.assertNotIn("@student.ctuet.edu.vn", raw_dump)
        self.assertNotIn("0912345678", raw_dump)

        # D07 & T27: Admin nâng min_group_size lên 15 -> Nhóm n=12 lập tức chuyển sang trạng thái khóa k-Anonymity
        pol_put = await self.client.put(
            "/v1/admin/analytics-policy",
            headers={"X-Admin-Actor": "admin_01"},
            json={"min_group_size": 15},
        )
        self.assertEqual(pol_put.status_code, 200)

        now_suppressed = await self.client.get(
            "/v1/analytics/overview",
            params={"faculty": "CNTT_K48"},
            headers=ctsv_hdr,
        )
        self.assertTrue(now_suppressed.json()["suppressed"])
        self.assertEqual(now_suppressed.json()["min_group_size"], 15)

        # Khôi phục min_group_size = 10 cho các kiểm thử tiếp theo
        await self.client.put(
            "/v1/admin/analytics-policy",
            headers={"X-Admin-Actor": "admin_01"},
            json={"min_group_size": 10},
        )

    async def test_10_cross_user_idor_isolation_and_self_service_data_erasure_f06(self):
        g_a = (await self.client.post("/v1/guest-sessions", json={"privacy_accepted": True})).json()
        g_b = (await self.client.post("/v1/guest-sessions", json={"privacy_accepted": True})).json()
        subj_a, tok_a = g_a["subject_id"], g_a["session_token"]
        tok_b = g_b["session_token"]
        hdr_a = {"Authorization": f"Bearer {tok_a}"}
        hdr_b = {"Authorization": f"Bearer {tok_b}"}

        # User A tạo dữ liệu cá nhân (Chat + Memory + Mood + Screening)
        chat_a = (
            await self.client.post(
                "/v1/chats", headers=hdr_a, json={"subject_id": subj_a, "title": "Riêng tư của A"}
            )
        ).json()["session_id"]
        await self.client.post(
            f"/v1/chats/{chat_a}/messages",
            headers=hdr_a,
            json={"client_message_id": "cmsg_idor_a1", "text": "Bí mật riêng của A", "subject_id": subj_a},
        )
        mem_a = (
            await self.client.post(
                "/v1/memories",
                headers=hdr_a,
                json={"subject_id": subj_a, "text": "Ghi nhớ riêng của A", "consent_accepted": True},
            )
        ).json()["memory_id"]
        mood_a = (
            await self.client.post(
                "/v1/mood-entries",
                headers=hdr_a,
                json={"subject_id": subj_a, "mood_choice": "😊 Ổn", "mood_level": 4},
            )
        ).json()["entry_id"]
        con_scr_a = (
            await self.client.post(
                "/v1/consents",
                headers=hdr_a,
                json={"subject_id": subj_a, "purpose": "screening", "decision": "accepted"},
            )
        ).json()["consent_id"]
        scr_a = (
            await self.client.post(
                "/v1/screening-sessions",
                headers=hdr_a,
                json={"tool_id": "GAD-7", "consent_id": con_scr_a, "subject_id": subj_a},
            )
        ).json()["session_id"]

        # IDOR Check: User B cố đọc/sửa/xóa tài nguyên của User A -> Bị chặn 403 toàn bộ
        self.assertEqual(
            (await self.client.get(f"/v1/chats/{chat_a}/messages", headers=hdr_b)).status_code,
            403,
        )
        self.assertEqual(
            (await self.client.delete(f"/v1/chats/{chat_a}", headers=hdr_b)).status_code,
            403,
        )
        self.assertEqual(
            (await self.client.get(f"/v1/memories/{mem_a}", headers=hdr_b)).status_code,
            403,
        )
        self.assertEqual(
            (await self.client.patch(f"/v1/memories/{mem_a}", headers=hdr_b, json={"text": "Hack"})).status_code,
            403,
        )
        self.assertEqual(
            (await self.client.delete(f"/v1/memories/{mem_a}", headers=hdr_b)).status_code,
            403,
        )
        self.assertEqual(
            (await self.client.delete(f"/v1/mood-entries/{mood_a}", headers=hdr_b)).status_code,
            403,
        )
        self.assertEqual(
            (
                await self.client.put(
                    f"/v1/screening-sessions/{scr_a}/answers",
                    headers=hdr_b,
                    json={"answers": [0] * 7, "completed": True},
                )
            ).status_code,
            403,
        )

        # User A hoàn tất bài sàng lọc của chính mình
        ok_scr = await self.client.put(
            f"/v1/screening-sessions/{scr_a}/answers",
            headers=hdr_a,
            json={"answers": [1] * 7, "completed": True},
        )
        self.assertEqual(ok_scr.status_code, 200)

        # F06 & S30 (T32): User A tự yêu cầu xóa toàn bộ dữ liệu lâm sàng cá nhân
        erase_res = await self.client.delete("/v1/me/data", headers=hdr_a)
        self.assertEqual(erase_res.status_code, 200)
        self.assertTrue(erase_res.json()["erased"])

        # Xác minh toàn bộ dữ liệu của A đã được xóa sạch và các consent cũ chuyển sang 'revoked'
        self.assertEqual(len((await self.client.get("/v1/chats", headers=hdr_a)).json()["items"]), 0)
        self.assertEqual(len((await self.client.get("/v1/memories", headers=hdr_a)).json()["items"]), 0)
        self.assertEqual(len((await self.client.get("/v1/mood-entries", headers=hdr_a)).json()["items"]), 0)
        self.assertEqual(
            len((await self.client.get("/v1/screening-sessions", headers=hdr_a)).json()["items"]),
            0,
        )
        reuse_revoked = await self.client.post(
            "/v1/screening-sessions",
            headers=hdr_a,
            json={"tool_id": "GAD-7", "consent_id": con_scr_a, "subject_id": subj_a},
        )
        self.assertEqual(reuse_revoked.status_code, 403)
        self.assertEqual(reuse_revoked.json()["error"]["code"], "CONSENT_REVOKED")

    async def test_11_dotenv_loader_aq_key_and_gemini_model_fallback(self):
        # 1. Kiểm thử _parse_dotenv_file không ghi đè biến đã đặt sẵn và hỗ trợ ngoặc kép
        sample_env_path = os.path.join(_TEMP_DB_DIR, "sample_test.env")
        with open(sample_env_path, "w", encoding="utf-8") as fh:
            fh.write(
                "# Comment line\n"
                "GEMINI_API_KEY=\"AQ.MockSampleKeyForDotenvParserTest0001\"\n"
                "export GEMINI_MODEL='gemini-3-flash-preview'\n"
                "EXISTING_KEY=should_not_override\n"
            )
        target_map = {"EXISTING_KEY": "preserved_value"}
        loaded_count = _parse_dotenv_file(sample_env_path, target_env=target_map)
        self.assertEqual(loaded_count, 2)
        self.assertEqual(target_map["GEMINI_API_KEY"], "AQ.MockSampleKeyForDotenvParserTest0001")
        self.assertEqual(target_map["GEMINI_MODEL"], "gemini-3-flash-preview")
        self.assertEqual(target_map["EXISTING_KEY"], "preserved_value")

        # 2. Kiểm thử tự động chuyển mạch (Fallback) khi model đầu trả 404 sang gemini-3.1-flash-lite + khóa AQ.
        called_urls = []

        async def _mock_fallback_chain(url, request_body, headers=None):
            called_urls.append((url, (headers or {}).get("x-goog-api-key", "")))
            if "gemini-2.5-flash:" in url:
                return httpx.Response(
                    404,
                    json={"error": {"message": "Model no longer available to new users"}},
                )
            return httpx.Response(
                200,
                json={
                    "candidates": [
                        {
                            "content": {
                                "parts": [
                                    {
                                        "text": json.dumps(
                                            {
                                                "reply": "Mình ở đây lắng nghe bạn chia sẻ chuyện ôn thi nhé.",
                                                "quick_replies": ["Thử thở 4-4-4-4", "Chia nhỏ đề cương"],
                                                "should_suggest_screening": False,
                                                "memory_candidate": None,
                                            }
                                        )
                                    }
                                ]
                            }
                        }
                    ]
                },
            )

        with patch.dict(
            os.environ,
            {
                "GEMINI_MODEL": "gemini-2.5-flash",
                "GEMINI_FALLBACK_MODELS": "gemini-3.1-flash-lite",
            },
            clear=False,
        ):
            with patch("app.main._post_gemini_api", new=AsyncMock(side_effect=_mock_fallback_chain)):
                res = await self.client.post(
                    "/v1/chats/chat_fallback_test/messages",
                    headers={"X-Gemini-Key": "AQ.MockValidNewStudioKeyFormat123456"},
                    json={
                        "client_message_id": "cmsg_fallback_01",
                        "text": "Hôm nay mình hơi hồi hộp trước buổi thuyết trình.",
                        "subject_id": "sub_fallback_user",
                    },
                )
                self.assertEqual(res.status_code, 200)
                body = res.json()
                self.assertEqual(len(called_urls), 2)
                self.assertIn("gemini-2.5-flash:generateContent", called_urls[0][0])
                self.assertIn("gemini-3.1-flash-lite:generateContent", called_urls[1][0])
                self.assertNotIn("AQ.", called_urls[0][0])
                self.assertEqual(called_urls[1][1], "AQ.MockValidNewStudioKeyFormat123456")
                self.assertIn("gemini-3.1-flash-lite", body["provider_badge"])

    async def test_12_multi_actor_features_articles_slots_hotlines_staff_directory_and_chat_rename(self):
        # 1. A01: Đổi tên cuộc trò chuyện & kiểm tra chống IDOR
        g1 = (await self.client.post("/v1/guest-sessions", json={"privacy_accepted": True})).json()
        g2 = (await self.client.post("/v1/guest-sessions", json={"privacy_accepted": True})).json()
        hdr1 = {"Authorization": f"Bearer {g1['session_token']}"}
        hdr2 = {"Authorization": f"Bearer {g2['session_token']}"}

        c_res = await self.client.post(
            "/v1/chats",
            headers=hdr1,
            json={"subject_id": g1["subject_id"], "title": "Tiêu đề cũ"},
        )
        chat_id = c_res.json()["session_id"]

        # Người dùng khác đổi tên -> Bị chặn 403
        bad_rename = await self.client.patch(
            f"/v1/chats/{chat_id}",
            headers=hdr2,
            json={"title": "Đổi tên trái phép"},
        )
        self.assertEqual(bad_rename.status_code, 403)

        ok_rename = await self.client.patch(
            f"/v1/chats/{chat_id}",
            headers=hdr1,
            json={"title": "Nhật ký ôn thi Giải tích"},
        )
        self.assertEqual(ok_rename.status_code, 200)
        self.assertEqual(ok_rename.json()["title"], "Nhật ký ôn thi Giải tích")

        # 2. A02 (CTSV): Quản lý bài viết Thư viện Kiến thức (Chặn Sinh viên & Tư vấn viên)
        ctsv_hdr = {"X-Staff-Role": "ctsv", "X-Staff-Id": "ctsv_01"}
        c1_hdr = {"X-Staff-Role": "counselor", "X-Staff-Id": "counselor_01"}
        c2_hdr = {"X-Staff-Role": "counselor", "X-Staff-Id": "counselor_02"}
        adm_hdr = {"X-Admin-Actor": "admin_01"}

        self.assertEqual(
            (
                await self.client.post(
                    "/v1/knowledge-articles",
                    headers=c1_hdr,
                    json={
                        "title": "Bài viết trái phép",
                        "summary": "Tóm tắt",
                        "content": "Nội dung",
                    },
                )
            ).status_code,
            403,
        )

        art_create = await self.client.post(
            "/v1/knowledge-articles",
            headers=ctsv_hdr,
            json={
                "id": "art_ctsv_new",
                "title": "Kỹ năng cân bằng việc làm thêm và học tập",
                "category": "Kỹ năng sống",
                "summary": "Phân bổ thời gian hợp lý cho sinh viên làm thêm.",
                "content": "Nội dung chi tiết hướng dẫn sinh viên ưu tiên sức khỏe giấc ngủ.",
                "verified_source": "Phòng Công tác Sinh viên",
            },
        )
        self.assertEqual(art_create.status_code, 200)

        arts_list = await self.client.get("/v1/knowledge-articles")
        self.assertTrue(any(a["id"] == "art_ctsv_new" for a in arts_list.json()["items"]))

        art_del = await self.client.delete(
            "/v1/knowledge-articles/art_ctsv_new", headers=ctsv_hdr
        )
        self.assertEqual(art_del.status_code, 200)

        # 3. A03 (Tư vấn viên): Quản lý khung giờ làm việc (Availability Slots) & Chặn chéo T25
        slots_init = await self.client.get("/v1/counselor-slots")
        self.assertEqual(slots_init.status_code, 200)
        self.assertGreaterEqual(len(slots_init.json()["items"]), 4)

        created_slot = await self.client.post(
            "/v1/staff/counselor-slots",
            headers=c1_hdr,
            json={
                "counselor_name": "ThS. Tâm lý Nguyễn Văn A",
                "unit_name": "Phòng Tư vấn Tâm lý Sinh viên",
                "slot_label": "Thứ 2 (08:30 - 09:30)",
                "consultation_mode": "Trực tiếp tại phòng P.102",
                "is_available": True,
            },
        )
        self.assertEqual(created_slot.status_code, 200)
        slot_id = created_slot.json()["slot_id"]

        # T25: counselor_02 cố tình khóa hoặc xóa khung giờ của counselor_01 -> Chặn 403
        cross_slot_patch = await self.client.patch(
            f"/v1/staff/counselor-slots/{slot_id}",
            headers=c2_hdr,
            json={"is_available": False},
        )
        self.assertEqual(cross_slot_patch.status_code, 403)
        self.assertEqual(
            cross_slot_patch.json()["error"]["code"],
            "FORBIDDEN_CROSS_COUNSELOR_ACCESS",
        )

        ok_slot_patch = await self.client.patch(
            f"/v1/staff/counselor-slots/{slot_id}",
            headers=c1_hdr,
            json={"is_available": False},
        )
        self.assertEqual(ok_slot_patch.status_code, 200)
        self.assertFalse(ok_slot_patch.json()["is_available"])

        # 4. A04 (Admin): Quản lý Hotline khẩn cấp S21 (bảo vệ 115/111) & Danh mục tài khoản nhân sự
        hotlines = await self.client.get("/v1/safety-hotlines")
        self.assertEqual(hotlines.status_code, 200)
        phones = [h["phone"] for h in hotlines.json()["items"]]
        self.assertIn("115", phones)
        self.assertIn("111", phones)

        # Cố xóa hotline_115 -> Bị chặn 400 CORE_HOTLINE_PROTECTED (R3)
        del_115 = await self.client.delete(
            "/v1/admin/safety-hotlines/hotline_115", headers=adm_hdr
        )
        self.assertEqual(del_115.status_code, 400)
        self.assertEqual(del_115.json()["error"]["code"], "CORE_HOTLINE_PROTECTED")

        # Admin tạo & tạm khóa tài khoản nhân sự mới
        staff_upsert = await self.client.post(
            "/v1/admin/staff-accounts",
            headers=adm_hdr,
            json={
                "staff_id": "counselor_03",
                "role": "counselor",
                "display_name": "ThS. Tâm lý Lê Hoàng C",
                "unit_name": "Tổ Tư vấn Học đường",
                "password": "Counselor3Pass#2026",
                "is_active": True,
            },
        )
        self.assertEqual(staff_upsert.status_code, 200)

        staff_list = await self.client.get("/v1/admin/staff-accounts", headers=adm_hdr)
        self.assertEqual(staff_list.status_code, 200)
        self.assertTrue(
            any(s["staff_id"] == "counselor_03" for s in staff_list.json()["items"])
        )

        # Tạm khóa counselor_03 -> Đăng nhập phải bị chặn 403 STAFF_ACCOUNT_DISABLED
        await self.client.patch(
            "/v1/admin/staff-accounts/counselor_03",
            headers=adm_hdr,
            json={"is_active": False},
        )
        disabled_login = await self.client.post(
            "/v1/auth/staff-login",
            json={"staff_id": "counselor_03", "password": "Counselor3Pass#2026"},
        )
        self.assertEqual(disabled_login.status_code, 403)
        self.assertEqual(
            disabled_login.json()["error"]["code"], "STAFF_ACCOUNT_DISABLED"
        )

    async def test_13_contabo_strict_bearer_mode_and_dass21_subscales(self):
        # 1. Kiểm thử tính chuẩn 3 tiểu thang đo DASS-21 theo đúng nhóm 7 câu Lovibond (không chia 3)
        subj = "sub_dass21_subscale_test"
        c_res = await self.client.post(
            "/v1/consents",
            json={"subject_id": subj, "purpose": "screening", "decision": "accepted"},
        )
        s_res = await self.client.post(
            "/v1/screening-sessions",
            json={
                "tool_id": "DASS-21",
                "consent_id": c_res.json()["consent_id"],
                "subject_id": subj,
            },
        )
        # Đặt toàn bộ 7 câu Stress = 3 (tổng 21), 7 câu Anxiety = 1 (tổng 7), 7 câu Depression = 0 (tổng 0)
        stress_idx = {0, 5, 7, 10, 11, 13, 17}
        anxiety_idx = {1, 3, 6, 8, 14, 18, 19}
        custom_answers = [
            3 if i in stress_idx else (1 if i in anxiety_idx else 0)
            for i in range(21)
        ]
        put_res = await self.client.put(
            f"/v1/screening-sessions/{s_res.json()['session_id']}/answers",
            headers={"X-Subject-Id": subj},
            json={"answers": custom_answers, "completed": True},
        )
        self.assertEqual(put_res.status_code, 200)
        p_data = put_res.json()
        self.assertEqual(p_data["score"], 28)
        self.assertEqual(p_data["subscale_scores"]["stress"], 21)
        self.assertEqual(p_data["subscale_scores"]["anxiety"], 7)
        self.assertEqual(p_data["subscale_scores"]["depression"], 0)

        # 2. Kiểm thử chế độ bảo mật Contabo Production (MINDCHECK_REQUIRE_STAFF_BEARER=1):
        # Chặn tuyệt đối các request nhân sự giả mạo Header không có Bearer Token
        with patch.dict(os.environ, {"MINDCHECK_REQUIRE_STAFF_BEARER": "1"}, clear=False):
            spoof_admin = await self.client.get(
                "/v1/admin/analytics-policy",
                headers={"X-Admin-Actor": "admin_01"},
            )
            self.assertEqual(spoof_admin.status_code, 401)
            self.assertEqual(
                spoof_admin.json()["error"]["code"],
                "STAFF_BEARER_TOKEN_REQUIRED",
            )

            spoof_ctsv = await self.client.get(
                "/v1/analytics/overview",
                headers={"X-Staff-Role": "ctsv", "X-Staff-Id": "ctsv_01"},
            )
            self.assertEqual(spoof_ctsv.status_code, 401)

            spoof_counselor = await self.client.get(
                "/v1/staff/counseling-requests",
                headers={"X-Staff-Id": "counselor_01"},
            )
            self.assertEqual(spoof_counselor.status_code, 401)

            # Khi đăng nhập hợp lệ qua /v1/auth/staff-login -> Bearer Token hoạt động bình thường
            adm_login = await self.client.post(
                "/v1/auth/staff-login",
                json={"staff_id": "admin_01", "password": "AdminTestPass#2026"},
            )
            self.assertEqual(adm_login.status_code, 200)
            adm_token = adm_login.json()["access_token"]
            ok_admin = await self.client.get(
                "/v1/admin/analytics-policy",
                headers={"Authorization": f"Bearer {adm_token}"},
            )
            self.assertEqual(ok_admin.status_code, 200)
            self.assertTrue(
                any(
                    ev["result"] == "DENIED_BEARER_REQUIRED"
                    for ev in ok_admin.json()["audit_events"]
                )
            )


if __name__ == "__main__":
    unittest.main(verbosity=2)
