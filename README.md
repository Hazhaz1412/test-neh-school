# NEH School

Trò chơi giải đố, điều tra góc nhìn thứ nhất theo hướng thực tế thay thế (ARG), làm bằng Godot 4.7. Một nhóm bạn lần theo những chuyện Trường THPT NEH (đã đóng cửa) chôn giấu: ban đêm lẻn vào trường thu thập bằng chứng và trốn bác bảo vệ, ban ngày tra cứu trên web giả chạy ngay trên máy người chơi.

Game không có yếu tố siêu nhiên: không ma, không linh hồn, không máu me. Mọi người, địa danh, tổ chức và trang web trong game đều hư cấu ([thế giới](docs/ARG_WORLD.md)). Cốt truyện đang được viết lại; các đoạn chat và bài đăng cũ đã được xóa, khung điện thoại và web vẫn sẵn sàng để thêm nội dung mới.

## Chạy

Mở `project.godot` bằng Godot 4.7, đợi import rồi nhấn **F5** (màn hình chính). Từ terminal: `godot --path .`. Renderer Forward+ cần Vulkan; máy không có sẽ lùi về OpenGL.

Phần web (trình duyệt Cú Đêm, Gaaglu, kênh ghép điện thoại) chạy riêng trong `hub/`, xem [hub/README.md](hub/README.md):

```sh
cd hub && npm ci && npm start
```

Bản phát hành phải đóng gói bằng `tools/package_build.sh linux|windows` ([EXPORT](docs/EXPORT.md)).

## Mạch chơi hiện tại

| Chương | Scene | Nội dung |
| --- | --- | --- |
| Tiền truyện | `scenes/home.tscn` | 19:40, Peter dọn vào số 14 Hẻm 31, lên lầu đi ngủ |
| Đêm 0 · Giấc mơ | `scenes/school_runtime.tscn` | Lẻn vào trường, tìm ba bằng chứng, bám theo và trốn bác bảo vệ, thoát qua đường hầm kỹ thuật |
| Tỉnh giấc · 05:52 | `scenes/home.tscn` | Tỉnh dậy, điện thoại, cài Gaaglu (nếu người chơi đồng ý), ra phố |
| Ngày 1 · Khu phố | `scenes/town.tscn` | Buổi sáng tự do: cờ vua, caro, tiệm không tên, mua đồ cho đêm |
| Đêm 1 | `scenes/school_runtime.tscn` | Cả nhóm bốn người trốn bác bảo vệ tới 06:00, bị bắt thì chờ đồng đội cứu |

Chi tiết từng đêm ở [docs/PROGRESSION.md](docs/PROGRESSION.md), khu phố ở [docs/TOWN.md](docs/TOWN.md), điện thoại ở [docs/PHONE.md](docs/PHONE.md).

## Điều khiển trong trường

| Phím | Chức năng |
| --- | --- |
| Chuột / WASD | Nhìn / di chuyển |
| Shift | Chạy, tốn stamina |
| Ctrl | Đi nhẹ; trong đường hầm, lấy đà rồi Ctrl để trượt |
| C | Cúi |
| Space | Nhảy; nín thở khi đang nấp |
| Z / X | Nghiêng người nhìn qua góc |
| E | Nhặt, mở cửa, nấp, ra khỏi chỗ nấp |
| F | Bật/tắt đèn pin |
| 1–6 / cuộn chuột | Chọn đồ trong túi sáu ô |
| Chuột trái | Dùng đồ đang cầm (chụp ảnh, sạc pin, sơ cứu, ném phấn) |
| Giữ/thả G | Tích lực rồi ném phấn để đánh lạc hướng bác bảo vệ |
| Q | Thả đồ đang chọn |
| J | Sổ điều tra: diễn biến và các bằng chứng đã có |
| M | Sơ đồ trường |
| F6 / F7 | Chất lượng đồ họa / FPS |
| Esc | Tạm dừng, xem hướng dẫn |
| R | Chơi lại |
| H + P | Chế độ TEST: bất tử, nhanh ×3, đủ bằng chứng |

Trong nhà: **Tab** nâng điện thoại lên, **E** tương tác, **Esc/Tab** hoặc bấm ra ngoài để cất điện thoại.

## Bản đồ trường

Khu A là khối chữ U ba tầng quanh sân trong có đài phun, khu B ở phía Bắc nối với khu A bằng hành lang kín trên cả ba tầng; có nhà kho ở sân dịch vụ và sân thượng khu A. Mỗi tầng là hai vòng kín, bốn cầu thang. Sửa kiến trúc bằng `tools/build_map.gd` rồi `tools/bake_night_navigation.gd`; F5 chạy bản tối ưu `scenes/school_runtime.tscn` sinh từ `scenes/school.tscn` ([hiệu năng](docs/PERFORMANCE.md)).

## Mã nguồn chính

| Phần | File |
| --- | --- |
| Thế giới đêm, HUD, chất lượng | `scripts/world.gd` |
| Đồng hồ đêm, thắng/thua | `scripts/survival_director.gd` |
| Mạch Đêm 0 và bằng chứng | `scripts/school_progression.gd`, `restroom_scene.gd`, `guard_prologue.gd`, `school_escape.gd`, `tunnel_escape.gd` |
| Sổ điều tra (J) | `scripts/case_journal.gd`, `data/evidence.json` |
| Bác bảo vệ Đêm 1 (AI hai tầng) | `scripts/hunt_director.gd` (A, biết hết, chỉ gợi ý vùng), `scripts/guard_hunter.gd` (B, chỉ biết điều thấy, nghe) |
| Nhóm bốn người, nhà giam, cứu nhau | `scripts/hunt_team.gd`, `teammate_bot.gd`, `kiting_course.gd` |
| Người chơi, túi đồ | `scripts/player.gd`, `held_item.gd`, `compact_hud.gd` |
| Nhà và điện thoại | `scripts/home/`, `scripts/home/phone/` |
| Khu phố | `scripts/town/`, `scripts/chess/`, `scripts/caro/` |
| Liên kết với web | `scripts/arg_bridge.gd` |

## Kiểm tra

```sh
godot --headless --path . --script tools/validate_map.gd
godot --headless --path . --fixed-fps 60 --script tools/validate_progression.gd
godot --headless --path . --fixed-fps 60 --script tools/validate_tunnel.gd
godot --headless --path . --script tools/validate_night_one.gd
godot --headless --path . --script tools/validate_hunter.gd
godot --headless --path . --script tools/validate_home.gd
godot --path . --script tools/validate_phone.gd --resolution 1600x900
node hub/test/webs.js
node hub/test/game_link.js
```

Danh sách đầy đủ trong `tools/validate_*.gd`. `validate_runtime.gd` và `validate_chess_play.gd` đang đỏ (xem [bàn giao](docs/SESSION_HANDOFF.md)). Ảnh chụp bằng các `tools/capture_*.gd`, cần display.

## Tài liệu

- [Bàn giao phiên làm việc](docs/SESSION_HANDOFF.md): đọc trước khi làm tiếp
- [Tiến trình Đêm 0 và Đêm 1](docs/PROGRESSION.md)
- [Điện thoại trong game](docs/PHONE.md)
- [Mở đầu và đồng hồ](docs/OPENING.md) · [Máy ảnh và túi đồ](docs/CAMERA.md)
- [Khu phố ban ngày](docs/TOWN.md) · [Thế giới ARG](docs/ARG_WORLD.md)
- [Hiệu năng](docs/PERFORMANCE.md) · [Đóng gói](docs/EXPORT.md)
- [Asset và giấy phép](ASSETS.md)
