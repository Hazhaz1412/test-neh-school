> Bản sinh tồn hiện tại, thực thể chuyên biệt và cách chơi: [SURVIVAL.md](SURVIVAL.md).

# Thế giới linh hồn và nhiệm vụ 01

## Học sinh không mặt

Dùng rig/hierarchy Quaternius Suit_Male và animation Idle/Walk/Punch; sprint là Walk tăng tốc. Dáng cao/gầy hơn, tay dài và đầu bầu dục trắng bị nứt; đầu nghiêng, thân chao và nhịp animation lệch giữa từng con. Đồng phục có cổ áo, cà vạt, huy hiệu và cúc để vẫn nhận ra là học sinh trong bối cảnh bạo lực học đường. Không thêm mắt, mũi hoặc miệng.

[Ma học sinh hiện tại](bully-ghosts-preview.png)

## Áp sát và chỗ nấp

Ma có nhịp khựng đầu nhìn player 0,34 giây rồi lao 6,4 m/s trong 1,1 giây, sau đó đuổi 4,65 m/s và hồi 5 giây trước đợt lao kế tiếp. Không dịch chuyển qua vật cản. Có tiếng gầm và chân chạy định hướng, thân chúi mạnh hơn trong đợt lao, tín hiệu màn hình ngắn khi bị phát hiện. Đòn gậy có 0,42 giây chuẩn bị, cooldown 1,15 giây, vẫn mất 14 HP/cú và có cửa sổ né.

[Ma lao tới](ghost-rush-preview.png) · [Tủ bên ngoài](hiding-locker-preview.png) · [Nhìn từ trong tủ](hiding-locker-inside.png) · [Nấp dưới bàn](hiding-table-inside.png)

47 chỗ nấp có collider thật và được bake vào đường đi: 40 chỗ trong các phòng/kho, 6 tủ ngoài hành lang, 1 bàn bổ sung trong kho. Tủ có khe nhìn, bàn dùng model Kenney desk và collider riêng cho mặt/chân, không dùng hộp kín cả gầm. Vị trí cover giữ ổn định ở cả hai thế giới; chỉ vật liệu đổi khi B. Runtime gộp mesh và collider tĩnh của cover vào các batch không gian, giữ script/vùng tương tác riêng để tránh tăng nhiều lượt vẽ.

**E** nhìn gần mặt tủ/gầm bàn để vào; E lần nữa để ra. Tự tắt đèn pin, hạ camera/capsule khi dưới bàn; bước chân dừng và camera chỉ xoay trong phạm vi cover. Chọn vị trí đứng trống khi thoát, giữ nguyên trạng thái khi B, dừng AI khi M/Esc. Không cho tương tác từ xa hoặc lúc pause.

Đám cầm gậy chỉ biết nơi nấp nếu thấy người chơi trước lúc vào. Kẻ Dò Tiếng mới còn có thể phát hiện hơi thở/tiếng ho khi hoảng loạn; Space nín thở hữu hạn là cách đối phó. Nhân chứng giữ vị trí cover và tới kiểm tra rồi ép ra; ma không chứng kiến chỉ tới vị trí thấy cuối và tìm vòng quanh, không theo dõi tọa độ ẩn. Cú vung đang chuẩn bị bị chặn khi player đã nấp. Nếu bị phát hiện nhưng lối ra không còn chỗ đứng, ma vẫn gây sát thương sau khi kiểm tra, tránh lợi dụng vật chặn lối để bất tử.

- `scripts/hiding_spot.gd`: cover, tương tác, vị trí nấp/lối ra, kiểm tra khi bị chứng kiến.
- `scripts/player.gd`: capsule/camera/đèn pin và input nấp.
- `tools/hiding_builder.gd`: vị trí và loại cover; chạy `tools/build_map.gd` để sinh source/runtime và bake nav sau khi chỉnh.
- `scripts/bully_ghost.gd`: `rush_speed`, `rush_duration`, `rush_recovery`, `windup`, trạng thái nhìn/đuổi/tìm và nhớ cover.
- `tools/build_horror_audio.py`: các WAV tổng hợp sẵn; gầm/chân phát bằng AudioStreamPlayer3D giới hạn 24 m.

## Cảnh đổi thực sự khi nhấn B

| Thế giới thường | Thế giới linh hồn |
| --- | --- |
| Bàn ghế/sách ở vị trí ban đầu | Một phần ghế và bàn treo ngược sát trần; sách nổi lên |
| Tường sơn và mặt sân sạch | Tường mục, sàn bê tông nứt, vết đỏ và vật liệu cây/đài phun nước biến đổi |
| Hành lang nối trống | Ghế treo, rễ đen qua trần/cửa sổ, dấu tay kéo dài và lời đe dọa |
| Không có ma/âm thanh oán khí | Tám ma học sinh cầm gậy và năm thực thể chuyên biệt; tiếng rền nền, nhịp tim khi bị truy đuổi và viền màn hình đập nhẹ |

[Lớp học trước](realm-classroom-before.png) · [Lớp học sau](realm-classroom-after.png) · [Hành lang nối](spirit-connector-preview.png) · [Thư viện](realm-library-preview.png) · [Dấu tay](realm-handprints-preview.png) · [Nhà kho](realm-warehouse-preview.png)

Texture tường và sàn là ảnh diffuse 1K có sẵn từ Poly Haven CC0; nguồn/giấy phép ở [ASSETS.md](../ASSETS.md). Đèn pin và độ sáng nền giữ khả năng nhìn đường/cửa, thay vì che toàn cảnh bằng bóng tối.

## Nhiệm vụ 01

39 cửa phòng A/B khóa lúc bắt đầu. Hành lang, cầu thang và sân thượng vẫn đi được, cửa kho riêng không khóa. Qua hành lang nối sang B tầng 1 → rẽ Tây → sân dịch vụ → mở cửa kho bằng E. Chìa nằm trên bàn ở cuối kho; nhìn gần và nhấn E để lấy. Sơ đồ M đánh dấu nhà kho.

[Nhặt chìa](master-key-preview.png) · [Thông báo hoàn thành](master-key-collected-preview.png)

Chìa mở quyền dùng E với mọi cửa phòng, không tự mở các cửa. Ma không mở được cửa phòng khóa trước khi có chìa; sau khi có chìa thì chúng có thể mở để truy đuổi. Inventory và trạng thái cửa giữ qua B, đặt lại khi R/run mới. Không thể nhặt chìa từ xa, qua tường hoặc khi đang dừng game. Chìa có trong cả hai thế giới.

## Chỉnh tiếp

- `scripts/bully_ghost.gd`: tỷ lệ, đồng phục, pose, animation và hành vi truy đuổi/đánh. Head material: `assets/materials/ghost_skin.gdshader`.
- `scripts/realm_prop_rules.gd`: chọn prop và transform biến thể. Kho và bàn đặt chìa được giữ ổn định.
- `tools/runtime_optimizer.gd`: lưu cả placement normal/realm và transform collider, phân nhóm theo loại vật liệu. Sau khi chỉnh rule/scene, chạy `tools/optimize_map.gd` để tạo runtime mới.
- `scripts/spirit_scenery.gd`: vật liệu mục, ghế treo hành lang, rễ, dấu tay và chữ trên tường. Các manifestation được tạo một lần, bật/tắt visibility khi B.
- `scripts/world.gd`: nhiệm vụ, inventory, ánh sáng/sương Inspector, âm thanh và độ nguy hiểm. `scripts/master_key.gd`: visual và tương tác chìa; `classroom_door.gd`: kiểm tra khóa.

Mỗi đồ vật đổi vị trí có **mesh và collider cùng transform**, không để collider vô hình dưới ghế treo. Navmesh tĩnh vẫn dùng footprint bố cục thường; đồ được nâng khỏi sàn, nên đường đi của ma vẫn an toàn nhưng có thể vòng qua chỗ trống cũ. Khi trở về mà đứng trong footprint đồ vừa hiện lại, người chơi được đưa sang nền trống gần nhất cùng tầng, có kiểm tra capsule và đường nhìn để không xuyên tường.

Các biến thể giữ instancing, không dựng thêm một bản trường đầy đủ hoặc chạy transform hàng nghìn props mỗi frame. Hai loop âm thanh nhỏ phát sẵn từ WAV. F6/F7 giữ chức năng chọn chất lượng và xem FPS.

## Kiểm tra

```sh
godot --headless --path . --script tools/validate_hiding.gd
godot --path . --script tools/validate_hiding.gd --resolution 1280x720
godot --headless --path . --script tools/validate_quest.gd
godot --headless --path . --script tools/validate_realm_scenery.gd
godot --path . --script tools/validate_realm_scenery.gd --resolution 1280x720
godot --path . --script tools/capture_horror_quest.gd --resolution 1280x720
```

Quest validation dùng capsule thật đi từ cổng tới chìa qua các hành lang còn mở, kiểm tra quyền mở mọi cửa, nhặt một lần và giữ inventory qua hai thế giới/run mới. Capture dùng đúng input E để nhặt chìa trước khi chụp cảnh. Realm validation kiểm tra thay đổi/khôi phục vật liệu và collider, nhiều lần bật/tắt không tích lũy decor, vị trí GPU (với display) và tránh kẹt dưới đồ vật khi đổi thế giới. Validation map/annex/spirit vẫn kiểm tra các tầng, sân thượng, cửa và ma thật đi lên cầu thang, truy đuổi, đánh.

Hiding validation kiểm tra ray/capsule/lối vào và ra của cả 47 cover, hai loại cover, pause/từ xa, đợt lao vượt tốc độ chạy, nấp không bị nhìn thấy, nấp có nhân chứng tới kiểm tra, đòn gậy cũ không xuyên cover, giữ trạng thái qua B và tìm quanh vị trí nhớ. Bản có display dùng input E thật; dummy headless gọi cùng target/method vì không bắt được chuột.
