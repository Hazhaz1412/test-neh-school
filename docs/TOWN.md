# Khu phố ban ngày

Bản đồ ban ngày của vòng Ngày/Đêm. Peter đi lại bằng xe máy trong phường Cổ Đằng, gặp người dân, lần theo manh mối rồi tới cổng trường lúc chập tối.

## Chạy thử

Mở `scenes/town.tscn` trong Godot rồi bấm F6, hoặc:

```sh
godot --path . res://scenes/town.tscn
godot --headless --path . --script tools/validate_town.gd          # map, chuyến xe, cả ngày
godot --headless --path . --script tools/validate_day_handover.gd  # Enter cuối Đêm 1 sang khu phố
godot --path . --script tools/capture_town_play.gd --resolution 1600x900
```

Cuối Đêm 1, nếu thắng, Enter sang sáng hôm sau.

## Phím

| Phím | Việc |
|---|---|
| WASD, chuột | Đi bộ, nhìn |
| Shift | Chạy, không tốn thể lực |
| F | Lên, xuống xe (xuống khi dưới 11 km/h) |
| W / S / A D / Space | Ga, phanh hoặc lùi, lái, phanh gấp |
| H, V | Còi, đổi góc nhìn trên xe |
| E | Nói chuyện, được cả khi đang ngồi trên xe |
| M | Bản đồ |

## Bản đồ

Khoảng 540 × 300 m, chia đôi bởi sông Trầu.

- **Bờ tây, khu phố Bến Trầu:** đường Cổ Đằng, Phố Chợ, đường Bến Trầu, phố Lò Than, phố Hàng Cau, đường Gò Sậy và sáu hẻm tắt.
- **Cầu Mây:** cầu vồng nối hai bờ.
- **Bờ đông, Đồng Muối:** ruộng muối phản chiếu bầu trời, vắng người, cuối đường là cổng Trường NEH.

Càng đi về phía trường, phố càng thưa và tiếng xe càng nhỏ. Đó là chủ ý.

## Thiết kế di chuyển

Người dùng yêu cầu không bắt đi bộ nhàm chán nhưng cũng không teleport.

- Xe máy tối đa 54 km/h, ngay trước cửa nhà khi bắt đầu.
- Từ nhà tới cổng trường mất 32 giây trong bài kiểm thử lái bằng phím thật.
- Xe không ngã, không hỏng, không cần xăng. Húc tường chỉ mất tốc độ và vẫn xoay được.
- Buông lái thì xe tự bám nhẹ theo hướng đường.
- Nói chuyện được ngay trên xe, trong bán kính 6 m.
- Thời gian trong ngày chỉ trôi khi xong một manh mối, không tính giờ lúc đi lại.
- La bàn chỉ mục tiêu kèm khoảng cách, bản đồ M, tên đường hiện khi đi vào.

## Mã nguồn

| File | Việc |
|---|---|
| `scripts/town/town_plan.gd` | Bản đồ dạng dữ liệu: đường, địa điểm, lô nhà, độ cao mặt đất |
| `scripts/town/town_builder.gd` | Sinh mesh và collider từ bản đồ |
| `scripts/town/mesh_batch.gd` | Gộp hình theo ô 72 m và vật liệu để giảm draw call |
| `scripts/town/town_player.gd` | Đi bộ, lái xe, camera |
| `scripts/town/town_traffic.gd` | Xe chạy theo vòng, người đi bộ |
| `scripts/town/town_person.gd` | Nhân vật Rocketbox người lớn |
| `scripts/town/town_story.gd` | Ngày 1, thoại, NPC |
| `scripts/town/town_hud.gd` | La bàn, bản đồ, nhắc phím |
| `scripts/town/town_sky.gd` | Bốn buổi trong ngày |
| `scripts/town/town_world.gd` | Ghép tất cả |

Thêm đường hay địa điểm: sửa `ROADS` và `PLACES` trong `town_plan.gd`, mọi thứ tự sinh lại, gồm cả bản đồ M. Giao thông viết theo tên đường trong `LOOPS` của `town_traffic.gd`.

Độ cao tính bằng công thức, không qua vật lý. Vật lý chỉ lo tường, nên xe không vấp lề đường.

## Buổi sáng

Tạm thời không có cốt truyện hay nhiệm vụ: người chơi đi lại tự do, nói chuyện phiếm, tới cổng trường là vào Đêm 1.

## Chưa làm

- Chưa vào được trong nhà hay quán, kể cả nhà Peter.
- Cây Kenney còn khối, lệch tông với phần còn lại.
- Rocketbox không có avatar người già hay gương mặt Việt; Bà Sáu trông trẻ hơn vai.
- Hàng hóa trên kệ là khối màu, đèn giao thông chỉ xanh, xe không dừng đèn đỏ.
- Rider giữ một tư thế, chân chưa đặt đúng lên sàn xe.
