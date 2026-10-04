# Mở đầu và một đêm trong trường

F5 tự chạy mở đầu không lời khoảng 70 giây. **ENTER** bỏ qua phim, **ESC** dừng/tiếp tục. Xem hết hay bỏ qua đều đưa player thật vào sân phía trong lúc **23:30**, có ba đồng đội còn đứng gần đó.

## Cảnh điều tra và đường vào

36 giây đầu ở phòng điều tra: camera đọc bảng báo, ảnh mất tích/vụ án, khoanh đỏ và dây nối; một người chỉ manh mối, người khác đối chiếu giấy; cả nhóm nhìn nhau gật đầu rồi nhặt dụng cụ. Bảng dùng ảnh chụp map demo, không có thoại hoặc phụ đề kể chuyện. Sáu bài báo hư cấu là nội dung nằm trong cảnh.

Tiếp theo van tới đường trước trường. Cổng chính khóa và tường bao 3,6 m ngăn bên ngoài; có trụ đá 4,4 m, chóp tường và mặt vữa cũ. Nhóm kiểm tra cổng rồi đi sang cửa bảo trì x=12 m, dùng kìm cắt ổ khóa, mở cánh cửa có hinge và lần lượt đi qua lỗ cửa 1,8 m. Chân luôn ở mặt đất. Cửa đóng sau khi vào, không trở thành lối thoát sớm. Vườn, sân và nội thất giữ bố cục hiện có.

Các nhân vật dùng FBX Quaternius CC0, van dùng Kenney CC0. Cả hai có nguồn/giấy phép trong [ASSETS.md](../ASSETS.md). Rig có sẵn điều khiển bước đi, nhặt đồ và xương tay; pose nhìn/gật đầu được thêm bằng Godot.

## Chuyển thế giới và đồng hồ

- **23:30–00:00:** 60 giây thực để chuẩn bị. Đồ vật và bầu trời chớp đổi qua thế giới linh hồn trong vài khoảng ngắn; chưa spawn thực thể, chưa tiêu tài nguyên sinh tồn.
- **00:00:** phát chuông bốn nốt ding–dong ding–dong, khóa ở thế giới linh hồn, spawn 13 thực thể và xóa các đồng đội của đoạn phim.
- **00:00–06:00:** 720 giây thực, tức 12 phút. Pin, nín thở, phấn, hoảng loạn và AI hoạt động. M xem sơ đồ không dừng đồng hồ/AI; ESC dừng cả hai.
- **06:00:** dừng truy đuổi, trả sân trường về thế giới thường và chuyển sky sang bình minh. Chỉ thành công nếu player sống và linh hồn đã được giải cứu. Chìa khóa hoặc tương tác cổng không thể thắng sớm.

N bắt đầu lại khi chưa có lượt hoặc sau khi kết thúc; không hồi tài nguyên giữa lượt đang sống. R tải lại mở đầu. B vẫn dùng khi preview ngoài lượt. Muốn mở project để preview mà không autoplay, tắt `play_opening_on_launch` trong World inspector rồi sinh lại runtime.

**Nhiệm vụ 4 ký ức đã triển khai:** thu vật chứng, đọc J rồi tự nhập lời an ủi cho An. `mark_soul_rescued()` chỉ nhận đủ vật chứng và 4 đánh giá đạt, không còn là hook gọi tự do. Kết nối AI thật cần cấu hình Gemini; xem [SOUL_QUEST.md](SOUL_QUEST.md).

## Chỉnh và kiểm tra

World inspector: `play_opening_on_launch`, `preparation_duration_seconds` (60), `night_duration_seconds` (720). Cảnh ở `opening_cinematic.gd` / `investigation_prologue.gd`; đồng hồ/chuông/kết quả ở `survival_director.gd`; model và alias animation ở `humanoid_model.gd`. `tools/perimeter_builder.gd` tạo tường/cổng/cửa bảo trì; `tools/update_perimeter.gd` cập nhật riêng chu vi, bake navigation rồi sinh runtime. Build map đầy đủ cũng gọi cùng builder.

```sh
godot --headless --path . --script tools/validate_opening.gd
godot --path . --script tools/capture_opening.gd --resolution 1280x720
```

Kiểm tra dùng scene chạy thật: khóa input, ảnh/khoanh đỏ, xe/đội, dụng cụ/cửa chuyển động, chân trên đất khi đi qua cửa, skip/pause, capsule handoff, phút chuẩn bị, chuyển chính xác nửa đêm, âm chuông, tài nguyên/clock pause và kết quả 06:00 có/không có rescue hook. Các validation AI/chỗ nấp/runtime kiểm tra riêng.

Ảnh mới: [bảng điều tra](opening-evidence-preview.png), [nhặt dụng cụ](opening-equipment-preview.png), [xe tới](opening-arrival-preview.png), [cắt khóa](opening-service-lock-preview.png), [qua cửa bảo trì](opening-service-entry-preview.png), [23:30](opening-2330-preview.png), [nửa đêm](opening-midnight-preview.png).
