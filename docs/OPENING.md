# Mở đầu và đồng hồ

Đêm 0 mở bằng cảnh nhóm tới trường trong khoảng 34 giây: van dừng trước cổng, nhóm kiểm tra lối vào, cắt khóa cửa bảo trì và đi qua cửa. Enter bỏ qua, Esc dừng/tiếp tục. Xem hết hoặc bỏ qua đều giao điều khiển cho người chơi trong sân lúc **22:30**, ba đồng đội đứng gần đó và rời đi khi xuống hầm.

Đồng hồ trôi liên tục khi chơi; nhặt bằng chứng không khóa hay đặt lại giờ. Biến cố do hành động trong chuỗi kích hoạt ([PROGRESSION](PROGRESSION.md)), không tự xảy ra lúc 00:00. `night_duration_seconds` (mặc định 720) là số giây thực cho sáu giờ trong game.

N bắt đầu lượt mới khi chưa chơi hoặc lượt đã kết thúc; R tải lại từ mở đầu.

Mã: `opening_cinematic.gd`, `survival_director.gd`, `school_progression.gd`. Model và giấy phép ở [ASSETS.md](../ASSETS.md).

```sh
godot --headless --path . --script tools/validate_opening.gd
godot --path . --script tools/capture_opening.gd --resolution 1280x720
```
