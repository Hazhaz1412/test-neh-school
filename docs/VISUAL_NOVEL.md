# Hội thoại Đêm 1

Lan và An dùng chung khung visual novel: chân dung 3D bên trái, tên người đang nói và chữ hiện dần ở dưới, lựa chọn ở bên phải. Câu hỏi và lời đáp của player xuất hiện thành lượt thoại riêng trước khi nhân vật trả lời. Không hiện ô nhập chữ hoặc điểm chấm.

- Chuột hoặc phím 1–6: chọn câu thoại. Khi chữ chưa hiện hết, phím số chỉ hiện hết chữ; bấm lần nữa mới chọn.
- Space/Enter hoặc nhấn khung thoại: hiện hết câu. Khi chỉ có một lựa chọn, Space/Enter tiếp tục lượt tiếp theo.
- Esc hoặc nút rời hội thoại: đóng, E tương tác lại để nói tiếp. Đồng hồ vẫn trôi. Bị thương, rời phạm vi an toàn hoặc kết thúc lượt sẽ đóng hội thoại và hủy yêu cầu đang chờ.

Lan biết thế giới linh hồn, lời nguyền và việc cần giải thoát những linh hồn mắc kẹt. Cô **không biết An, các manh mối, câu chuyện của em hoặc vị trí em**. Người chơi có thể chọn câu hỏi theo thứ tự bất kỳ; nhánh danh tính giữ bí ẩn. Nghe đủ về thế giới, lời nguyền, cách giúp linh hồn và gầm bàn rồi chọn đáp lại để đi tiếp. Đóng rồi nói lại giữ các giải thích đã nghe. Lan chỉ dẫn cách về trường; player tự khám phá và lần theo tiếng khóc để tìm An.

An có ba nhánh hỏi về gấu bông, gậy và vở; thêm câu hỏi xác nhận tên. Mỗi nhánh có ba lời đáp để chọn. Lời đã chọn được gửi nguyên văn tới dịch vụ AI hiện có. Điểm/unsafe vẫn do AI quyết định; chọn nút không tự tăng tiến độ. Sau phản hồi, An nói một câu phù hợp với kết quả: có thể mở lòng hoặc giải thích vì sao em chưa cảm thấy được hiểu. Có thể chọn lời khác, hỏi chuyện khác hoặc đọc lại một nhánh đã hoàn thành. Hoàn thành cả ba nhánh còn cần nghe và đáp lại lời tạm biệt; sau đó tiếp tục sống tới bình minh.

Nếu dịch vụ lỗi, câu đã chọn được giữ lại, có nút thử lại hoặc chọn lời khác; không cấp tiến độ thay cho AI. Phản hồi trễ sau khi rời hội thoại không được tính. Chơi lại xóa mọi tiến độ.

Kịch bản: `data/night1_dialogue.json`. Giao diện: `scripts/visual_novel_dialogue.gd`; controller: `school_progression.gd` và `soul_quest.gd`. Portrait dùng asset CC0 sẵn có, không cần tải thêm.

```sh
godot --headless --fixed-fps 60 --path . --script tools/validate_visual_novel.gd
godot --fixed-fps 60 --path . --script tools/validate_visual_novel.gd --resolution 1280x720
godot --headless --fixed-fps 60 --path . --script tools/validate_soul_quest.gd
godot --headless --fixed-fps 60 --path . --script tools/validate_story_chase.gd
```

Bài visual novel dùng protocol fixture cục bộ để kiểm tra request/response, không gọi nhà cung cấp AI thật hay khẳng định chất lượng chấm. Kiểm tra gồm thứ tự hỏi tự chọn, phím số/typewriter, giới hạn hiểu biết của Lan, E mở lại, gầm bàn, chọn lời đáp, kết quả đạt/chưa đạt, ngăn đổi chủ đề khi chờ, hủy khi bị thương, lời tạm biệt và reset. Kết quả: `visual-novel-validation.json`.

Ảnh: [câu hỏi Lan](night1-vn-lan-questions.png), [Lan trả lời](night1-vn-lan-answer.png), [câu hỏi An](night1-vn-an-questions.png), [lựa chọn đáp](night1-vn-an-replies.png), [phản ứng An](night1-vn-an-reaction.png), [tạm biệt](night1-vn-an-farewell.png).
