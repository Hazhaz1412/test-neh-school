# Bốn ký ức của An

F5 mở đầu không lời → 23:30 chuẩn bị → chuông 00:00 → đêm 12 phút → 06:00. Chìa tổng trong nhà kho phía Tây B mở các phòng. Vật chứng chỉ hiện trong đêm linh hồn thật, không thu được trong preview B hoặc các chớp cảnh chuẩn bị.

| Vật chứng | Phòng | Trải nghiệm |
|---|---|---|
| Vở vẽ | A tầng 3, Mỹ thuật | Bị phá đồ, chế giễu sở thích |
| Hộp cơm | B tầng 1, lớp 102 | Bị cô lập và đe dọa người muốn kết bạn |
| Thẻ nhớ | B tầng 2, Máy tính | Bị cắt ghép lời nói, lan truyền tin đồn |
| Băng tay / giấy cầu cứu | A tầng 1, Y tế | Che giấu vết thương vì sợ trả đũa |

Nhìn vào đồ và nhấn E để thu. J mở sổ ký ức; các câu chuyện chỉ xuất hiện khi thu đúng vật chứng. Đủ bốn vật chứng, gặp An trên sân thượng khu A, nơi quái không lên được, nhấn E và tự nhập lời an ủi cho từng trải nghiệm. AI chấm ba tiêu chí 0–2: thấu hiểu, công nhận cảm xúc không đổ lỗi, và hỗ trợ an toàn. Cần thấu hiểu ≥1, công nhận ≥1, tổng ≥4; tin đồn và sợ trả đũa còn cần hỗ trợ ≥1. Lời khuyên gây hại không đạt. Chưa đạt có thể thử lại; ký ức đã được an ủi vẫn giữ tiến độ.

Không có lựa chọn đóng sẵn hoặc bộ từ khóa đóng giả AI. Dịch vụ không sẵn sàng/timeout/JSON sai không tăng tiến độ. Đánh giá là cơ chế demo, không phải thang đo tâm lý đã kiểm định. Nội dung là các câu chuyện hư cấu; nguyên tắc hỗ trợ tham khảo [UNICEF: hỗ trợ trẻ bị bắt nạt](https://www.unicef.org/egypt/bullying/tips-parents-bullied).

J và cuộc trò chuyện không dừng đồng hồ, tài nguyên hoặc quái. Gõ chữ không kích hoạt R/B/F/M của game. Khi bị thương, hết giờ, bị truy đuổi ở gần hoặc rời cuộc trò chuyện, yêu cầu đang chờ bị hủy; phản hồi cũ không cứu được An. Đủ bốn cuộc trò chuyện mới giải thoát An; vẫn phải sống tới 06:00 để thắng. R xóa toàn bộ tiến độ.

## Chạy AI Gemini 3.8 Flash

Python 3 chuẩn, không cần pip. Model đã chọn: `gemini-3.8-flash`; provider `gemini`.

File key riêng: `~/.config/neh-school/ai.json`, quyền 0600, ngoài project:

```json
{
  "provider": "gemini",
  "model": "gemini-3.8-flash",
  "api_key": "DIEN_KEY_GOOGLE_AI_STUDIO_TREN_MAY"
}
```

Tạo key tại [Google AI Studio](https://aistudio.google.com/apikey) rồi thay giá trị `api_key` trên máy. Key OpenCode cũ được giữ riêng ở `opencode_api_key` khi chuyển provider; không gửi nó cho Google. Đừng đưa key vào chat, `.gd`, scene hoặc repo. Có thể dùng `GOOGLE_API_KEY` hoặc `GEMINI_API_KEY` thay cho file; `GOOGLE_API_KEY` được ưu tiên.

F5 tự chạy bridge localhost nếu chưa có; bridge đọc lại file mỗi yêu cầu, nên thay key không cần dựng lại map hoặc game. Godot chỉ gọi `http://127.0.0.1:8765/comfort`. Key nằm ở Python; không được trả về qua health API hoặc log.

Gemini dùng REST `generateContent`, schema JSON cho ba điểm và phản hồi, thinking level `low` để giảm độ trễ. Không dùng đoạn reasoning làm điểm. Output bị safety block, bị cắt vì hết token, JSON sai hoặc API lỗi không tăng tiến độ. Không đổi model tự động, không dùng điểm từ khóa thay AI. Suy luận chạy trên API, không chiếm GPU của game.

Google hiện có [free tier cho Gemini 3.8 Flash](https://ai.google.dev/gemini-api/docs/pricing) với quota theo project. Chọn project Free Tier ở AI Studio để dùng miễn phí; project có billing sẽ theo bảng giá của Google. Game không thay đổi billing. [Model và khả năng JSON](https://ai.google.dev/gemini-api/docs/models/gemini-3.8-flash), [REST structured output](https://ai.google.dev/gemini-api/docs/generate-content/structured-output).

Có thể chạy thủ công khi bridge chưa mở:

```bash
python3 tools/run_with_ai.py --provider gemini --model gemini-3.8-flash --ai-only
```

Bỏ `--ai-only` để mở cả Godot. Key nhập ở terminal được ẩn và không lưu. Cấu hình `comfort_ai_url` trong World inspector nếu bridge chạy ở địa chỉ khác.

**Trạng thái kiểm chứng:** đã chấm trực tiếp bằng `gemini-3.8-flash` với key riêng: HTTP 200 qua localhost bridge, `source: ai`, điểm 2/2/2 cho lời an ủi thử về bức vẽ. Protocol còn được kiểm tra bằng fixture: header key, schema/MIME enum, bỏ qua reasoning, chặn output chưa hoàn chỉnh và tách key giữa provider. Thử OpenCode trước đó nhận HTTP 403 `FreeTierError` vì free tier chỉ dùng trong OpenCode; adapter cũ còn dùng được nếu quyền API của tài khoản cho phép, không giả mạo client.

## Chẩn đoán và test nhanh

Kiểm tra ngày 2026-10-04: ban đầu thiếu key; sau khi anh thêm key, health `configured: true` và GET model HTTP 200. Lỗi chấm HTTP 400 nằm ở request: REST `responseFormat.text.mimeType` yêu cầu enum `APPLICATION_JSON`, không phải chuỗi MIME `application/json` dùng trong SDK. Bridge v4 đã sửa theo [API reference](https://ai.google.dev/api/generate-content#TextResponseFormat), được restart và chấm trực tiếp thành công HTTP 200. Gemini có lúc trả 503 quá tải; bridge thử lại tối đa ba lần, chờ 0,5 rồi 1 giây, tổng thời hạn 80 giây (Godot 90 giây). Không retry lỗi key, request sai hay quota. UI báo quá tải cụ thể, giữ lời đang nhập và cho thử lại; không tạo điểm giả hoặc tự đổi model. Không cần thay key hiện tại.

**H + P** bật/tắt chế độ test: bất tử, tốc độ ×3, chìa và bốn ký ức được thu bằng bypass có nhãn TEST; An vẫn xuất hiện, chưa được giải cứu. Đây không phải điểm do AI chấm. Đêm vẫn chạy để test gameplay. **Esc → Đưa tới An để thử chấm AI** bỏ tiến độ an ủi/giải cứu, giữ vật chứng và đưa player tới vị trí E thật của An; thử đủ bốn cuộc trò chuyện qua API như bình thường. Bất tử tránh bị ngắt lời bởi đòn đánh. **Esc → Hoàn thành đêm, tới 06:00** bỏ qua thời gian để xem kết thúc. R tạo lượt sạch, cheat mặc định tắt. H/P gõ trong ô hội thoại không kích hoạt tổ hợp.

`tools/test_soul_ai.py`: 12 fixture tests, bao gồm mã lỗi HTTP, thiếu key, response lỗi không chứa credential hay điểm giả. `tools/validate_cheats.gd`: input H+P thật, tốc độ/capsule, bất tử, nút test, thông báo lỗi AI và reset. Ngoài fixture đã chấm thật qua localhost với key hợp lệ; kiểm tra rubric/chất lượng phản hồi cần thêm nhiều lời an ủi khác.

## Kiểm tra

```bash
python3 tools/test_soul_ai.py
godot --headless --path . --script tools/validate_cheats.gd
godot --path . --script tools/validate_cheats.gd --resolution 1280x720
godot --headless --path . --script tools/validate_soul_quest.gd
```

Kiểm tra API dùng HTTP fixture; kiểm tra Godot dùng phản hồi protocol cố định, ghi rõ trong mã. Đã kiểm tra vị trí capsule/tia E của cả bốn vật chứng, khóa chìa, chặn nhặt từ xa, thiếu ký ức, JSON sai/phản hồi cũ, lời gây hại, đêm không dừng khi đọc/nhập, không thắng sớm, thắng lúc bình minh và reset. Muốn kiểm chứng chất lượng AI cần chạy lại với provider thật đã được cấu hình.

An ở **sân thượng khu A, dãy Bắc**, gần lan can nhìn xuống sân trong, phía Đông khối cầu thang. Đi cầu thang trung tâm A qua tầng 3, ra sân thượng ở cửa Đông rồi đi tới lan can sân trong. M có chấm xanh An; J ghi vị trí mới. Ba dãy sân thượng A là vùng an toàn, mọi archetype bị chặn lên cả khi nghe/chase; họ mất dấu khi player lên. Đồng hồ và pin vẫn chạy, nên lên nơi trú trước khi thu đủ vật chứng sẽ không giải quyết được nhiệm vụ.

[An trên sân thượng](soul-rooftop-preview.png) · [Menu test](cheat-menu-preview.png) · [Thông báo AI qua bridge thật](soul-ai-status-preview.png).

`tools/validate_soul_rooftop.gd` kiểm tra player đi bộ thật từ tầng 3 tới An, ray E, cả 13 quái và ba archetype đặc biệt mất dấu, không nghe/đánh tại sân thượng, quay về điểm tuần tra khi lọt vào hoặc hết hiệu ứng máy ảnh. Đồng hồ/pin vẫn trôi, hoảng loạn giảm và không gây sát thương tại nơi trú. Các kiểm tra này chạy khi cheat tắt.

An có ánh hồn xanh và vòng nhỏ dưới chân để dễ nhận ra trong tối, không thêm đèn realtime. B preview ngoài lượt cũng hiện An để tìm vị trí; hội thoại nhiệm vụ cần vào đêm và đủ vật chứng. Mái hành lang nối đã hạ 15 cm cho bằng mặt sân thượng A; mesh, collider, scene runtime và navmesh cùng được cập nhật. Player đi qua khe nối Đông–Tây và quay lại được bằng capsule thật. Dừng lượt đang chạy và F5 lại sau khi cập nhật scene để thấy bố trí mới.

Cửa lên An hiện khóa: xem [tiến trình bốn nhánh](PROGRESSION.md). H+P mở tiến trình để thử AI. Chìa tổng mở A trước; B cần điều khiển hoặc bơm. Bốn ký ức và điểm AI không thể bỏ qua khóa sân thượng trong lượt thường.
