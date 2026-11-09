# Tiến trình Đêm 0 và Đêm 1

Cập nhật 2026-11-09. Game không còn yếu tố siêu nhiên: không ma, không thế giới linh hồn, không An hay Lan, không máu. Đối thủ duy nhất là bác bảo vệ trường. Cốt truyện đang được viết lại; phần dưới là những gì đang chạy được trong code.

## Đêm 0 · Giấc mơ (`school_progression.gd`)

Peter ngủ trong căn nhà mới và mơ thấy mình cùng nhóm lẻn vào Trường NEH. Đêm 0 kết thúc bằng việc tỉnh dậy ở nhà.

| Chặng | Nội dung | Code |
| --- | --- | --- |
| Mở đầu 22:30 | Nhóm tới bằng van, cắt khóa cửa bảo trì, đi vào sân ([OPENING](OPENING.md)) | `opening_cinematic.gd` |
| Phòng 103 sáng đèn | Hai ô cửa kính sáng vàng, đèn tuýp chập chờn. Phòng trống, chỉ có chiếc cài tóc nhựa hồng gãy đôi. E nhặt: **bằng chứng 1** | `classroom_lure.gd`, `night_story_interactable.gd` |
| Tiếng vỡ trên lầu | 1,3 giây sau, gương nhà vệ sinh A-203 (ngay trên 103) rơi làm bể vòi. Nước tràn ra hành lang và thấm xuống trần 103 | `restroom_scene.gd` |
| Nhà vệ sinh A-203 | Gương vỡ, tủ đồ hé cửa có thứ chói sáng. E mở tủ: gián và nhện tràn ra (không gây sát thương). Lấy chiếc gương cầm tay vỡ: **bằng chứng 2** | `insect_swarm.gd`, `restroom_cabinet.gd` |
| Trốn | Bác bảo vệ nghe tiếng, lên soát tầng 2, đẩy từng cửa buồng. Trốn trong buồng, giữ Space nín thở. Tiếng đổ trên tầng 3 kéo bác đi | `guard_prologue.gd`, `security_guard.gd`, `restroom_stall.gd` |
| Bám theo | Bám bác lên B-302, đi nhẹ, tránh đèn pin và những lần bác ngoái lại. Cách quá 22 m trong 4 giây là mất dấu, chơi lại đoạn bám | `guard_prologue.gd` |
| Chụp giấy tờ | Máy ảnh chỉ dùng được ở B-302. Chụp tập giấy và tấm ảnh lớp học bác đang dọn: **bằng chứng 3**. Flash làm lộ người chơi | `camera_flash.gd`, `camera_viewfinder.gd` |
| Lẻn ra | 4 giây để chui vào tủ hành lang, bác đứng nghe trước tủ. Sau đó bác lục tầng 2 và 3 trên navmesh, người chơi phải lẻn ra cổng chính | `guard_prologue.gd`, `hiding_spot.gd` |
| Phá cửa | Cổng bị xích, bác quát từ cửa sổ tầng 3. 20 giây (+4 giây mỗi lần thua, tối đa 28): lấy tua vít, tháo 4 con vít (giữ chuột trái, xoay 3 vòng), spam Space đạp cửa phòng kỹ thuật | `school_escape.gd`, `door_breaker.gd` |
| Đường hầm | Mạng hầm kỹ thuật đèn đỏ khẩn cấp. Bác đuổi theo đường ngắn nhất, hai lần chui cửa phòng bơm ra chặn đầu. Có vết nứt phải nhảy, cầu thang gãy, cống trượt (nghiêng để né rebar và dây điện) | `tunnel_escape.gd`, `corridor_chute.gd`, `corridor_spiders.gd`, `tunnel_fx.gd` |
| Bể nước | Cảnh dựng: nhìn xuống, quay lại thấy bác, lấy đà, nhảy hụt, bám tấm ván rồi ván gãy. Rơi xuống bể, chìm dần, tỉnh dậy ở nhà | `tunnel_escape.gd` (`BEATS`), `finish_dream` |

Ánh sáng, tiếng động và vệt nước dẫn đường; HUD không kể lại sự kiện. Bằng chứng nằm trong sổ điều tra (J, `case_journal.gd`, dữ liệu `data/evidence.json`).

## Đêm 1 · Trốn bác bảo vệ tới 06:00

Vào từ cổng trường sau buổi sáng ở khu phố (`world._begin_night_one`, meta `night_one`). Trường vẫn là trường bình thường (`world.guard_night`).

- **Đội:** người chơi và 3 bạn AI: Ba Rô, Huna, Bơ Tồ (`hunt_team.gd`, `teammate_bot.gd`). Code viết theo danh sách người chơi để sau này thay bot bằng người qua mạng.
- **Thanh 600 giây:** mỗi lần bị bắt trừ 200 giây, thanh tiếp tục chảy khi bị nhốt. Cả đội cùng bị giữ một lúc là thua; sống tới 06:00 là thắng.
- **Bị bắt:** bác lôi người đó tới phòng nhốt gần nhất (A-101, A-108, B-1101, B-1105) rồi khóa cửa. Lúc bị lôi, bấm A/D luân phiên để vùng ra; mỗi lần thoát, lần sau khó hơn 50%. Trong phòng nhốt đi lại được nhưng không ra được cửa; đồng đội giữ E 3 giây ở ngoài để mở.
- **Bác bảo vệ:** AI hai tầng. A (`hunt_director.gd`) biết vị trí mọi người nhưng chỉ được gợi ý một vùng. B (`guard_hunter.gd`) chỉ biết điều thấy và nghe, tự lục phòng và chỗ nấp, đứng nghe trước tủ (nín thở để thoát). Tốc độ gốc bằng 105% người chơi chạy và tăng dần khi rượt; leo cửa sổ, dọn kệ đổ hay đóng ván làm tốc độ về mức gốc. Bác nhớ các khe thấp đã thấy học sinh chui và quay lại đóng ván; giữ E 5 giây để gỡ, hoặc trượt vào phá ván và mất 25% sức khỏe. Bác không bao giờ bị gọi lui.
- **Tịch thu:** đồ bác giữ lại (`guard_hunter.confiscated`) xuất hiện ở tiệm không tên, chuộc lại nửa giá (`night_gear.gd`).
- **Bãi kiting:** 8 ô vòng có chồng thùng, cửa sổ, khe kệ và khe thấp (`kiting_course.gd`, `kiting_pallet.gd`), navmesh riêng `scenes/hunt_navigation.tres`.
- **Người chơi:** stamina 260, thanh mệt khi bị rượt lâu, Space leo cửa sổ/kệ đổ, E gạt kệ, giữ chuột phải quay đầu nhìn sau, Z/X nghiêng người.
- F9 hiện trạng thái A và B để chẩn đoán.

## Đồng hồ

Bắt đầu 22:30, chạy liên tục; mặc định 22:30–06:00 là 12 phút thực (`night_duration_seconds`). Biến cố phụ thuộc hành động, không phụ thuộc mốc giờ. Esc dừng đồng hồ; J và M không dừng.

## TEST

H + P: bất tử, tốc độ ×3, bỏ qua chuỗi Đêm 0, đủ ba bằng chứng. Esc → **TEST · Hoàn thành đêm** nhảy tới 06:00. Lượt có dùng TEST được ghi trên màn kết.

## Kiểm tra

```sh
godot --headless --fixed-fps 60 --path . --script tools/validate_progression.gd   # Đêm 0, 104 kiểm tra
godot --headless --fixed-fps 60 --path . --script tools/validate_tunnel.gd        # đường hầm, có bot chạy thật
godot --headless --fixed-fps 60 --path . --script tools/validate_chute.gd         # cống trượt
godot --headless --path . --script tools/validate_night_one.gd                    # Đêm 1, 60 kiểm tra
godot --headless --path . --script tools/validate_hunter.gd                       # AI A/B của bác bảo vệ
godot --headless --path . --script tools/validate_hunter_smart.gd
godot --headless --path . --script tools/validate_gear.gd
godot --headless --path . --script tools/measure_guard_chase.gd                   # đo cân bằng rượt đuổi
godot --path . --script tools/capture_guard.gd --resolution 1280x720
godot --path . --script tools/capture_night_one.gd --resolution 1280x720
```

Ảnh: `docs/guard-*.png`, `docs/prologue-*.png`, `docs/tunnel-*.png`, `docs/slide-*.png`, `docs/night1-*.png`.
