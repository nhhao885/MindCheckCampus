Mục tiêu: hoàn thiện ứng dụng hiện tại để có thể bàn giao; ưu tiên đúng nghiệp vụ, an toàn dữ liệu và kiểm thử có bằng chứng. Áp dụng cho mọi lần Agent làm việc trong repository.

1. Quy tắc bất biến
- Không chẩn đoán: AI chỉ định hướng CBT bằng tiếng Việt; không chẩn đoán bệnh, không suy diễn PHQ-9/GAD-7/DASS-21 từ hội thoại.
- Consent rõ ràng: các thao tác lưu Trí nhớ AI (F10), sàng lọc (F21), chia sẻ thông tin đặt lịch (F29), liên kết phiên khách (F03) phải có bản ghi consent riêng. Không bật sẵn checkbox.
- An toàn 2 lớp: khi có tín hiệu nguy cơ cao/tự hại, hiển thị màn hình hỗ trợ an toàn và hotline đã xác minh (S21, không cần đăng nhập); đồng thời cung cấp luồng đặt lịch chuyên gia (S23). Không thay thế hỗ trợ khẩn cấp bằng chatbot.
- Ẩn danh & riêng tư: tách Identity Vault khỏi Anon_Clinical. Dashboard CTSV (D02–D04) chỉ hiển thị số liệu tổng hợp; ẩn kết quả khi nhóm có n < min_group_size (mặc định 10). Không trả PII hoặc nội dung chat.
- RBAC nghiêm ngặt: tư vấn viên (A03) chỉ xem lịch hẹn được phân công và dữ liệu trong whitelist; không xem chat/điểm sàng lọc (F37, T25). Admin (A04) được cấu hình ngưỡng (D07) và xem Audit Log, không được đọc chat cá nhân (T27).
2. Nguyên tắc thay đổi mã nguồn
- Đọc README, tài liệu yêu cầu, AGENT_RULES.md hiện có, cấu trúc thư mục và code liên quan trước khi sửa. Nếu file rule hiện có chứa quy tắc khác, phải giữ và hợp nhất; không tự ý xóa.
- Giữ kiến trúc/công nghệ hiện tại trừ khi có lỗi hoặc lý do kỹ thuật rõ ràng. Theo cấu trúc đang có: Flutter tại apps/student_app/, backend FastAPI tại backend/; kiểm tra cấu hình thực tế trước khi kết luận.
- Truy vết mỗi chức năng qua UI → state/service → API → database và ngược lại. Không chỉ sửa giao diện hoặc tạo nút giả.
- Không hardcode dữ liệu nghiệp vụ, kết quả AI, quyền truy cập hoặc trạng thái thành công. Không để mock/demo data xuất hiện trong môi trường bàn giao; dữ liệu seed phục vụ phát triển phải được tách biệt và ghi rõ.
- Không xóa dữ liệu, reset database, chạy migration phá hủy, ghi đè .env, khóa bí mật hoặc thay đổi cấu hình triển khai khi chưa có backup và chưa được cho phép.
- Không ghi log token, mật khẩu, PII, nội dung chat hoặc dữ liệu nhạy cảm. Dùng biến môi trường cho secrets; validate input và xử lý lỗi an toàn.
- Thay đổi phải có phạm vi nhỏ, nhất quán với coding conventions; không tạo refactor lớn không liên quan.
3. Quy trình bắt buộc
1. Audit: lập danh mục module, màn hình, API, chức năng, vai trò và luồng nghiệp vụ từ code/tài liệu. Gắn ID cho từng chức năng nếu chưa có.
2. Trace & fix: xác định lỗi/thiếu sót, nguyên nhân gốc và sửa trực tiếp. Không tự thêm nghiệp vụ ngoài phạm vi; ghi rõ điểm chưa xác định.
3. Test design: tạo test case cho 100% chức năng trong phạm vi. Bao gồm happy path, negative, boundary, validation, quyền truy cập, lỗi mạng/API và trạng thái dữ liệu.
4. Automated test: bổ sung/chạy unit, API/integration, widget và end-to-end cho các luồng quan trọng, tùy hạ tầng có sẵn. Ưu tiên test tự động có thể chạy lặp lại.
5. Security & privacy: kiểm tra authentication, RBAC, truy cập chéo người dùng, consent, lộ PII/chat, anonymization, ngưỡng nhóm nhỏ và audit log.
6. Regression: sau sửa lỗi, chạy lại test liên quan và bộ regression; kiểm tra build và khởi chạy app/backend.
7. Handover: cập nhật hướng dẫn cài đặt, cấu hình, chạy, test và sử dụng; ghi rõ giới hạn còn tồn tại.
4. Tiêu chuẩn nghiệm thu
- Kiểm tra 100% chức năng thuộc phạm vi; mỗi chức năng có test case và kết quả.
- Không còn lỗi Critical/High chưa xử lý. Nếu không thể sửa, phải nêu lý do, tác động, biện pháp giảm thiểu và đánh dấu chưa đạt.
- Các luồng nghiệp vụ chính được kiểm thử end-to-end.
- Có automated test cho chức năng quan trọng và có lệnh chạy cụ thể.
- Có kiểm thử phân quyền, bảo mật, consent và quyền riêng tư.
- Không còn dữ liệu demo ngoài ý muốn; dữ liệu seed phải tách môi trường.
- Có hướng dẫn cài đặt, cấu hình, chạy và sử dụng.
- Có báo cáo kiểm thử dựa trên lần chạy thực tế.
Quy tắc trạng thái: PASS chỉ khi đã chạy và có bằng chứng; FAIL khi chạy nhưng không đạt; BLOCKED khi không thể chạy vì thiếu điều kiện. Không suy đoán kết quả, không ghi PASS chỉ vì đã viết test hoặc code.
5. Tài liệu đầu ra
Lưu trong docs/quality/ (tạo thư mục nếu cần):
- AUDIT.md — danh mục chức năng, phạm vi, phát hiện và mức độ ưu tiên.
- TEST_CASES.md — ID, module, tiền điều kiện, dữ liệu, bước chạy, kết quả mong đợi.
- TEST_REPORT.md — lệnh/môi trường chạy, PASS/FAIL/BLOCKED, bằng chứng và phạm vi chưa test.
- BUG_REPORT.md — mức độ, cách tái hiện, nguyên nhân, bản sửa và trạng thái.
- USER_GUIDE.md — hướng dẫn người dùng.
- SETUP_DEPLOYMENT.md — cài đặt, biến môi trường, database, chạy và triển khai.
Không tạo tài liệu trùng lặp nếu project đã có tài liệu tương đương; cập nhật tài liệu hiện hữu khi phù hợp.
6. Báo cáo kết thúc mỗi đợt
Báo cáo ngắn gọn: đã kiểm tra/sửa module nào; file chính đã thay đổi; lệnh test đã chạy; số lượng PASS/FAIL/BLOCKED; lỗi Critical/High còn lại; việc bị BLOCKED; bước tiếp theo. Không tuyên bố ứng dụng sẵn sàng bàn giao nếu còn tiêu chí nghiệm thu chưa đạt.
PROMPT KÍCH HOẠT AGENT (DÙNG MỖI ĐỢT)
Đọc và tuân thủ AGENT_RULES.md cùng tài liệu trong repository. Audit toàn bộ phạm vi ứng dụng, sau đó trực tiếp hoàn thiện từng module và kiểm thử theo quy tắc. Ưu tiên lỗi Critical/High, luồng nghiệp vụ chính, RBAC, consent và quyền riêng tư. Kiểm tra 100% chức năng trong phạm vi; bổ sung/chạy automated test và end-to-end test phù hợp; sửa lỗi rồi chạy regression. Cập nhật docs/quality/ với test case, báo cáo kết quả thực chạy và hướng dẫn bàn giao. Không xóa dữ liệu hoặc thay đổi phá hủy. Làm liên tục theo từng module, không dừng ở phân tích; chỉ hỏi khi thiếu quyết định nghiệp vụ hoặc cần quyền cho thao tác rủi ro. Cuối mỗi đợt, báo cáo PASS/FAIL/BLOCKED có bằng chứng và nêu rõ phần chưa hoàn thành. Bắt đầu bằng audit và danh sách ưu tiên.