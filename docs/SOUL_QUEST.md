# An và ba manh mối mở đầu

Gấu bông trong phòng sáng đèn, cuốn vở Nguyễn Bình An ở phòng 205 và gậy dính máu ở phòng đối diện thay toàn bộ vật chứng cũ. Chúng được thu trong flow mở đầu và lưu vào J, trước khi chạy ra cổng và gặp Lan. Sau khi núp và nghe Lan giải thích lời nguyền, tìm An trên sân thượng A. Xem [flow Đêm 1](PROGRESSION.md).

| Manh mối | Trải nghiệm của An |
| --- | --- |
| Gấu bông | Bị cô lập, chế giễu, không có ai ở cạnh. |
| Gậy dính máu | Bị đánh đập và sợ trả đũa nếu kể ra. |
| Vở Nguyễn Bình An | Đã cố viết ra tổn thương nhưng không ai lắng nghe; cần được tôn trọng thay vì phán xét chữ viết. |

An cần cả ba manh mối và lời giải thích của Lan trước khi hội thoại nhiệm vụ mở. Người chơi tự chọn câu hỏi về từng manh mối rồi chọn lời đáp trong visual novel có chân dung/chữ hiện dần. Không bắt buộc thứ tự; AI chấm câu đã chọn về thấu hiểu, công nhận cảm xúc và hỗ trợ an toàn (mỗi tiêu chí 0–2). Cần thấu hiểu ≥1, công nhận ≥1, tổng ≥4; nỗi sợ trả đũa còn cần hỗ trợ ≥1. Lời khuyên gây hại không đạt. Chưa đạt có thể thử lại, tiến độ lời đã được chấp nhận được giữ.

API lỗi, JSON sai hoặc phản hồi cũ không tăng tiến độ. Sát thương, hết giờ hoặc rời thoại hủy yêu cầu đang chờ. J và hội thoại không dừng đồng hồ. Nghe phản ứng của An, chọn tiếp tục và xác nhận lời tạm biệt mới giải thoát em. Giải thoát An chưa thắng sớm: phải sống đến bình minh. R xóa tiến độ. Nội dung là truyện hư cấu; đánh giá AI là cơ chế demo.

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

Có thể chạy thủ công khi bridge chưa mở:

```bash
python3 tools/run_with_ai.py --provider gemini --model gemini-3.8-flash --ai-only
```

Bỏ `--ai-only` để mở cả Godot. Key nhập ở terminal được ẩn và không lưu. Cấu hình `comfort_ai_url` trong World inspector nếu bridge chạy ở địa chỉ khác.

## Kiểm tra và test nhanh

H+P bật/tắt TEST có nhãn, bỏ qua mở đầu, cấp ba manh mối/chìa và giữ An để nói chuyện thật. Esc → Đưa tới An để thử chấm AI xóa tiến độ an ủi, đưa player tới tương tác E của An và vẫn cần provider/key thật. Esc → Hoàn thành đêm bỏ qua chấm để kiểm tra màn kết. H/P trong ô nhập không bật cheat.

```sh
python3 tools/test_soul_ai.py
godot --headless --path . --script tools/validate_soul_quest.gd
godot --headless --path . --script tools/validate_cheats.gd
```

Test Python dùng fixture request/response. Test Godot xác minh điều kiện ba manh mối, ray E của An, không đóng giả điểm khi lỗi, phản hồi cũ/gây hại, hủy khi bị thương, đồng hồ/hội thoại, bình minh và reset. Các bài này không gọi API thật hoặc chứng minh chất lượng rubric của AI.

An ở sân thượng A, dãy Bắc, phía Đông cầu thang trung tâm. M có chấm xanh An. Ba dãy sân thượng A là vùng trú an toàn, mọi archetype bị chặn lên; đồng hồ và pin vẫn trôi. Không còn câu đố giấy tại cửa sân thượng.

Giao diện và nhánh thoại: [VISUAL_NOVEL.md](VISUAL_NOVEL.md). Lan chỉ biết về lời nguyền, không kể thay câu chuyện của An.
