# Mở đầu và đồng hồ

F5 mở cảnh nhóm điều tra tới trường trong khoảng 34 giây: van dừng trước cổng, nhóm kiểm tra lối vào, cắt khóa cửa bảo trì và đi qua cửa. Enter bỏ qua, Esc dừng/tiếp tục. Cảnh vào trường không còn bảng điều tra hoặc bài báo. Xem hết hoặc bỏ qua đều giao điều khiển cho player trong sân trường lúc **22:30**, có ba đồng đội gần đó.

Đồng hồ trôi liên tục khi chơi; nhặt manh mối và chuyển thế giới không khóa hay đặt lại giờ. Đèn một phòng học kéo người chơi vào nhặt gấu bông, rồi bóng nữ ở cửa sổ lầu 2 dẫn tới vở Nguyễn Bình An khi người chơi lên lầu; vết máu và âm thanh lặp dẫn qua phòng đối diện. Mở cửa bị jumpscare rồi thấy gậy; đủ cả ba manh mối mới tắt điện, tiếng cười vang liên tục và ngột ngạt tăng dần, nhiệm vụ đổi thành thoát ra cổng. Chỉ từ đoạn này trường mới chập chờn giữa hai thế giới. Chạm cổng gây nhiễu điện rồi kéo player hoàn toàn vào hành lang linh hồn.

Đoạn chạy tự điều khiển bằng WASD và Shift, có stamina, quay đầu nhìn ma được; đèn pin không tiêu pin. Phải tự chọn đường qua bốn ngã rẽ có đường cụt; dấu chân máu/vải rách gợi đường đúng. Né tủ cao, nhảy qua ghế và Ctrl trượt qua gầm bàn trống sau khi lấy đà; có tủ đổi chỗ và chướng ngại hạ xuống. **Sau ít nhất 75 giây di chuyển và qua góc thứ tư** mới gặp Lan, chạy theo cô thêm một đoạn rồi vào phòng núp. Cửa đóng trước khi player chọn câu hỏi với Lan qua visual novel. Lan chỉ biết lời nguyền và các linh hồn cần được giải thoát, không biết An hay các manh mối; sau đó chui gầm bàn để về trường. Xem [flow đầy đủ](PROGRESSION.md).

Mặc định đồng hồ tăng nửa phút mỗi giây thực. Từ 22:30 tới 06:00 mất 15 phút thực; Esc dừng đồng hồ, các giao diện đọc/nói không dừng. Nhặt gấu/vở/gậy hoặc chạm cổng không tự cứu An hay thắng sớm. Sau Lan, tìm An trên sân thượng, an ủi qua AI rồi sống tới bình minh.

N bắt đầu lượt mới khi chưa chơi hoặc lượt kết thúc; R tải lại từ mở đầu. B dùng trong preview ngoài lượt. `night_duration_seconds` đặt tốc độ đồng hồ (720 giây tương ứng sáu giờ trong game); biến cố không còn dùng `preparation_duration_seconds`.

Mã: `opening_cinematic.gd`, `survival_director.gd`, `school_progression.gd`, `endless_corridor.gd`. Model Quaternius và van Kenney cùng giấy phép ở [ASSETS.md](../ASSETS.md).

```sh
godot --headless --path . --script tools/validate_opening.gd
godot --path . --script tools/capture_opening.gd --resolution 1280x720
```
