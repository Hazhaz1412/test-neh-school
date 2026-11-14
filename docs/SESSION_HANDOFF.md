# Bàn giao phiên làm việc

Cập nhật 2026-11-09. Đọc file này trước khi làm tiếp. Luật chơi ở [PROGRESSION.md](PROGRESSION.md), điện thoại ở [PHONE.md](PHONE.md), thế giới ở [ARG_WORLD.md](ARG_WORLD.md), asset ở [ASSETS.md](../ASSETS.md).

## Dự án và người dùng

- NEH School là game Godot 4.7 cho khóa luận tốt nghiệp. Mô tả đăng ký: "Trò chơi giải đố, điều tra góc nhìn thứ nhất theo hướng thực tế thay thế (ARG)".
- **Hướng hiện tại: chỉ điều tra và trinh thám.** Giáo viên hướng dẫn đã bác hướng kinh dị. Không ma quỷ, không linh hồn, không máu me, không người chết. Nhóm bạn phơi bày những chuyện trường đã đóng cửa che giấu: đêm lẻn vào trường lấy bằng chứng, ngày tra cứu trên web.
- **Cốt truyện đang được người dùng viết lại.** Chat và bài đăng cũ đã xóa; đừng tự viết cốt truyện mới khi chưa được yêu cầu.
- Người dùng xưng "anh", gọi trợ lý là "em". Trả lời tiếng Việt, ngắn, nói thẳng kết quả. Thích thấy chạy thật, phản hồi bằng ảnh chụp. Với UI phải tự chụp ảnh và xem trước khi báo xong.
- Thích asset có giấy phép bên ngoài (CC0) hơn âm thanh tự tổng hợp.

## Dọn ngày 2026-11-09

Đã gỡ khỏi code, dữ liệu, web và tài liệu:

- Thế giới linh hồn (phím B), ma học sinh, ba loại thực thể, hù ngẫu nhiên, combat QTE đánh ma, súng muối, chuông truy đuổi kiểu ma.
- An (hồn ma trên sân thượng), Lan, hội thoại visual novel với họ, AI chấm lời an ủi (`tools/soul_ai_*`).
- Quỷ Ghen Tị: AI vẫn dùng cho bác bảo vệ Đêm 1 nhưng đổi tên thành `hunt_director.gd` (A) và `guard_hunter.gd` (B); model quỷ đã xóa; menu nền giờ là bác bảo vệ cầm đèn pin.
- Ống kính điện thoại soi "thế giới bên kia" (render phụ, dấu ArUco, WebXR). **Kênh ghép điện thoại qua LAN và QR vẫn giữ** (`hub/web/phone.js`), trang điện thoại chỉ báo đã ghép, chờ dùng làm tay cầm (gyro, rung).
- Chat cũ (nhóm, Bà Sáu, Bảy Rô, Mười Gió), bài đăng Làng Ta/Fake và Sợi Chỉ, ba bài báo về NEH, ghi chú desktop nhắc "thế giới bên kia".
- Sổ ký ức An thay bằng **sổ điều tra** J (`case_journal.gd`, `data/evidence.json`).
- Giữ nguyên theo ý người dùng: gương vỡ trong nhà vệ sinh, côn trùng nhảy ra từ tủ, chìm trong bể nước rồi tỉnh dậy (đều không siêu nhiên).
- Điện thoại làm lại: nâng máy lên giữa màn hình, màn khóa tự mở, vuốt, cuộn quán tính ([PHONE.md](PHONE.md)).

Mọi thứ đã xóa vẫn còn trong lịch sử git (commit trước `7bcef53`).

## Mạch chơi

Tiền truyện ở nhà 19:40 → Đêm 0 (giấc mơ: cài tóc → gương vỡ → tủ côn trùng → gương cầm tay → trốn và bám theo bác bảo vệ → chụp giấy tờ ở B-302 → lẻn ra → phá cửa phòng kỹ thuật → đường hầm → bể nước) → tỉnh dậy 05:52 → Ngày 1 ở khu phố → Đêm 1 cả nhóm trốn bác bảo vệ tới 06:00. Sáu chương trong `scripts/game_progress.gd`.

## Giấc mơ mặt nước (2026-11-14)

Sau bể nước ở hành lang đỏ, người chơi trồi lên ở `scenes/dream_shore.tscn` (chương "Đêm 0 · Mặt nước"), đi qua cổng trường thì mới tỉnh ở nhà. Sàn sụp thành vực rộng 99 m có ba đảo (`dream_rift.gd`); qua vực là năm câu đố, điều phối trong `dream_world.gd` (`STAGES`):

1. `bridge1`: lối đi vỡ chỉ liền khi đứng cạnh bàn học lẻ (`anamorphic_bridge.gd`, phấn chiếu bằng `anamorphic_path.gdshader`); chụp ảnh ở đó thì cầu thành thật.
2. `board`: tấm bảng chỉ có ở "ngày ấy". Ảnh mang vật đi: `memory_camera.gd` lưu transform của vật so với ống kính, đặt xuống là `mắt * rel`. Chụp ngang thì bảng nằm ngang, phải chụp dọc đầu bảng.
3. `leap`: hai bảng, khoảng trống 18 m, phải nhảy cóc. Chụp từ xa thì bảng rơi xa; không chụp được tấm đang đứng lên; hai bảng chung một ảnh thì dời cùng nhau.
4. `bridge2`: điểm nhìn (bàn lẻ lơ lửng) nằm ngoài vực, phải lấy tấm bảng của đảo làm cầu tàu ra đó.
5. `gate`: cổng xích; ảnh "ngày ấy" dán đúng góc thì cổng mở.
6. `lucid` (thêm 2026-11-14): qua cổng là "biết mình đang mơ" (`lucid_sky.gd`). Đồ trong sân (bàn giáo viên, sách khổng lồ, tờ giấy thi, bảng đen) nổi lên thành 16 bậc xoắn quanh cột cờ, lên tới biển mây; trên mây có cửa lớp sáng đèn, bước qua là tỉnh. Bốn bậc (`MISSING`) đã trôi đi: giữ chuột trái hoặc E để kéo vật về trước mắt, nhìn đâu vật tới đó, thả ra thì vật ở yên. Không kéo được vật đang đứng. Bậc thiếu cao gấp đôi tầm nhảy nên bắt buộc phải kéo. Không thua, không đếm giờ; rơi thì lơ lửng xuống nước rồi leo lại.

Nhảy (Space) có ở cả giấc mơ, nhẹ như không trọng lực (`dream_player.gd`). Trước cổng, khi bay gần như không trôi ngang (`AIR_DRIFT`), nên không nhảy tắt qua vực được. Sau cổng nhảy cao hơn, giữ Space khi rơi thì lơ lửng. Gờ thấp dưới 0.4 m được tự bước lên (`_step_up`): trước đây bảng đặt lệch vài cm so với mép đảo làm kẹt người chơi.

Người dùng muốn giấc mơ chill và ảo kiểu lucid dream, không căng thẳng. Đã bỏ tiếng nước đổ rì rào lúc sàn sập, giảm tiếng đổ vỡ và rung.

R xếp lại bảng của đảo hiện tại. Rơi xuống vực thì về đầu câu đố đang chơi. Kiểm tra: `tools/validate_dream.gd` (headless; giải hết năm câu, thử cả cách sai, rồi kéo bốn bậc thiếu và cho bot nhảy thật hết 16 bậc lên mây, vào cửa); ảnh: `tools/capture_dream.gd` ra `docs/dream-*.png` (cảnh lucid là `dream-6-*`).

## Giấc mơ đồng cỏ (2026-11-14)

Thắng Đêm 1, bấm Enter ("Về nhà ngủ") là vào `scenes/dream_meadow.tscn`, chương "Đêm 1 · Đồng cỏ". Kết màn: qua cửa nhà trên hành tinh về lại đồng cỏ tối, nằm lên giường lần hai thì sang `town.tscn`.

- Mở đầu trong tối: đồng cỏ đồi lượn dưới trời u ám, chỉ có một chỗ sáng ở xa 90 m, nơi các tia sáng ánh cầu vồng rọi xuống một cái cây và một cái giường. Hàng cột điện đi xa dần vào sương.
- Tia sáng (`meadow_beam.gdshader`): 12 dải quad luôn xoay mặt về phía mắt, sáng theo hình chuông ngang dải, đáy mềm theo depth buffer nên hòa vào cỏ, không còn cạnh hay góc. Quầng sáng trên cỏ là một Decal tròn mờ dần, chỉ chiếu lớp 1; cây và giường đặt ở lớp 2 để không bị hắt xám.
- Bước vào vùng sáng thì trong 7 giây trời chuyển sang xanh mây trắng, bong bóng bay lên, cá bơi lượn trên không quanh cây; xa hơn có cá đuối và cá voi.
- E cạnh giường để nằm xuống, nhìn lên tán cây. Mắt chớp rồi nhắm hẳn. Trong lúc nhắm, trời chuyển sang đêm đầy sao và nhạc khu vui chơi nổi lên; mắt chớp mở ra vì tiếng nhạc.
- Ban đêm (`scripts/meadow/land_fold.gd`): đồng cỏ hóa ra là đáy của một cái hộp cỏ. Nhìn dọc trục x, hộp là hình vuông cạnh 220 m, góc bo bán kính 36 m, dài 2,4 km mỗi bên. Theo thứ tự: đáy là đồng cỏ có giường; tường là khu vui chơi (vòng đu quay, vòng ngựa gỗ, lều xiếc, quầy, xe bỏng ngô, trò đập búa, khinh khí cầu); trần có lối đất đèn lồng dẫn tới một ngôi nhà gạch đỏ bình thường; tường bên kia đi xuống lại đáy, thành một vòng khép kín. Trọng lực luôn hướng về mặt gần nhất (`up_at`: từ người chơi về hình chữ nhật lõi), xoay dần từng bước, nên qua góc không thấy dốc; validator đo dốc lớn nhất dưới chân dưới 1°. Đứng ở đâu ngửa đầu lên cũng thấy mặt đối diện; trên trần nhìn lên là đồng cỏ có giường. Sương đêm xanh nhạt (mật độ 0.0036) làm các mặt xa tan vào sương cho cảm giác vô tận; người dùng chê bản hộp 96 m là chật. Trăng không đổ bóng, vì có bóng thì các mặt che tối lẫn nhau.
- Shift để chạy trong mơ (7,5 m/s). Chạy từ giường tới cửa nhà mất khoảng 42 giây. Ra xa quá 170 m theo trục x thì bị đẩy nhẹ lại.
- Cỏ và đất trên các mặt hộp dùng chung shader với đồng cỏ (chế độ box, toạ độ u dọc x, s vòng quanh hộp). Kích thước hộp nằm ở `land_fold.gd` và được đưa vào shader bằng `box_uniforms`; `ground_height` làm phẳng hai mép đáy và bỏ đồi trong lòng hộp (sửa ở shader thì sửa cả `dream_meadow.gd`).
- Ngôi nhà dựng bằng code (`build_house` trong `land_fold.gd`, dùng lại cho nhà trên hành tinh). Cửa là lỗ thật xuyên tường. Bấm E thì cửa xoay vào trong, khung cửa đã hiện sẵn bên trong nhà, cứ thế đi xuyên qua (`portal.gd`).
- Bên trong nhà (`scripts/meadow/house_inside.gd`, đặt ở y = -6000):
  - Phòng khách to gấp 16 lần: trần 42 m, giấy dán tường vàng, sàn gỗ, thảm, sofa, ghế bành, đồng hồ quả lắc, kệ sách, cửa sổ trời đêm, rèm, và cánh cửa bé tí dưới chân tường (cửa ra).
  - Cầu thang xoắn bằng 24 chồng sách dẫn lên bàn trà. Trên bàn có đèn dầu và quả cầu thủy tinh; trong quả cầu là hành tinh tí hon có một mặt trời tí hon.
  - Bấm E vào quả cầu thì mắt rơi vào trong, độ cao giảm theo hàm mũ (kiểu "powers of ten"), rồi đứng trên hành tinh thật bán kính 45 m (`PLANET_AT`, ở z = -12000).
  - Quanh hành tinh có bản sao cả căn phòng phóng to K = 45 lần, ánh sáng phóng theo, nên khung hình cuối cú rơi khớp đúng khung hình đứng trên hành tinh, không bị cắt cảnh.
  - Trên hành tinh có nhà gạch, cây và giường. Giường chỉ để trang trí, không ngủ được (người dùng yêu cầu).
  - Cửa nhà gạch mở ra cảnh đầu tiên của màn: đồng cỏ tối, một chỗ sáng ở xa.
    - Lúc chạm quả cầu, game dựng thêm một bản `dream_meadow` ở chế độ `preview` (không có người chơi, HUD, hộp hay phần trong nhà) trong World3D riêng nằm bên trong SubViewport của cổng (`portal.gd`, `hand_over`).
    - Bước qua cửa thì chính bản đó được gắn lên làm cảnh hiện tại (`_into_first_meadow` rồi `begin_again`), không nạp lại nên không khựng. Người chơi đứng ở điểm xuất phát, quay về phía chỗ sáng.
    - Lần này (`again`) giường không dẫn sang ban đêm: nhắm mắt là tỉnh dậy thật, sang `town.tscn`.
- Cổng (`portal.gd`):
  - Camera phụ render vào SubViewport (HDR, chưa tonemap, để môi trường của mắt chỉnh màu một lần), hiện theo screen-space lên một hộp lộn trong ra sau khung cửa.
  - Chỉ render khi cửa trong tầm nhìn và gần (dưới 160 m).
  - Lớp hiển thị: vỏ nhà = 4 và màn cổng = 8, cả hai bị ẩn khỏi camera cổng. Phòng = 16, hành tinh = 32, bản sao phòng = 64; mỗi nhóm có đèn riêng, trăng chỉ chiếu 1|2|4.
  - Đi qua là `carry()`: dời vị trí, xoay `frame`, xoay vận tốc.
- Chỗ cho minigame giải đố sau này: căn phòng, kệ sách, đồng hồ, hành tinh.
- Khu vui chơi (bản to):
  - Quảng trường bán kính 34 m (`PLAZA`), tâm cách chân tường 42 m (`FAIR_AT`).
  - Đu quay cao 40 m, vòng ngựa gỗ, lều xiếc, đu dây xoay (`_swing_ride`), 8 quầy, 2 xe bỏng ngô, trò đập búa, 18 cột đèn lồng có dây bóng đèn và dây cờ đuôi nheo, 5 khinh khí cầu, pháo hoa nổ ngẫu nhiên kèm ánh chớp (`_tick_fireworks`).
  - Lối đi xuyên quảng trường (x từ -2 đến 5 theo trục z cục bộ) được giữ trống, không có vật cản.
- Đu quay (`scripts/meadow/ferris_wheel.gd`, thay cho GLB tĩnh):
  - Dựng bằng code: 12 cabin luôn treo thẳng, bình thường quay chậm.
  - Đứng ở bục rồi bấm E thì đu quay quay tới khi một cabin dừng đúng bục, người chơi ngồi vào. Vẫn nhìn quanh được; người ngồi tự nghiêng ra mép cabin theo hướng đang nhìn.
  - Lên 15 giây, lượn qua đỉnh 25 giây, xuống 15 giây, cả vòng khoảng 57 giây.
  - Gần đỉnh thì hiện một vòm sao bán kính 140 m quanh trục, chỉ nửa trên đường chân trời của tường, có Ngân Hà và mặt trăng. Pháo hoa nổ dày quanh đỉnh (`_tick_fireworks`).
  - Máy đấm lực dời ra (-12, 0, 3).
  - Ô vuông tối thấy xa xa từ khu vui chơi là ngôi nhà trên trần nhìn qua sương, không phải lỗi.
- Bóng đen (`scripts/meadow/fair_crowd.gd`):
  - 25 người đứng theo 11 nhóm, cộng 4 người đi dạo dọc lối đi. Thân là người Rocketbox tô đen, không có collider.
  - Mỗi nhóm nói lần lượt vài câu, mỗi câu trong một hộp thoại trên đầu người nói. Nói hết thì nghỉ 7–15 giây rồi lặp lại.
  - Hộp thoại chỉ hiện khi người chơi đứng cách người nói dưới 7 m (`HEAR`). Chữ và hộp dùng alpha cut nên không bị DOF làm nhòe. Kích thước hộp lấy theo chữ đã dàn trang.
  - Lời thoại nằm trong `GROUPS`.
- Di chuyển trong đồng cỏ bớt trơn: `floor_grip` 16 và `air_grip` 5 (mặc định của `dream_player.gd` vẫn là 5 và 3 cho giấc mơ mặt nước). Trong căn phòng khổng lồ dùng tiếng bước trên gỗ của Kenney.
- Tàu lượn siêu tốc (`scripts/meadow/roller_coaster.gd`, bản thường, dựng để chuẩn bị):
  - Đường ray là một `Curve3D` khép kín dài khoảng 750 m, nằm phía đông quảng trường (x từ 42 đến 300, z từ -30 đến 25, hệ toạ độ của khu vui chơi). Ray, xương sống, thanh ngang, cột đỡ và đèn LED dọc ray đều đùn ra theo khung của đường cong (`frame_at`).
  - Lộ trình: ga, đoạn phóng (đẩy 14 m/s² lên 40 m/s), dốc top hat cao 64 m, vòng lộn ngược bán kính 14 m, vòng xoắn nghiêng nửa vòng, ba gò nảy, khúc cua dài về ga.
  - Tàu 4 toa và sàn ga là của Kenney. Bấm E ở bục cạnh toa đầu là ngồi ghế đầu (`SEAT`); chạy theo trọng lực và lực cản, góc nhìn mở rộng theo tốc độ, phanh vào ga. Cả vòng khoảng 69 giây.
  - Chuyến bay giấc mơ (`scripts/meadow/coaster_dream.gd`):
    - Lối vào: trên dốc top hat, ở độ cao 30 m có một vòng ánh sáng. Tàu đi qua là chớp trắng và sang đường ray vô tận. Đường ray này nằm ở `DREAM_AT` (y = 15000), dùng lớp hiển thị 128 và môi trường riêng.
    - Đường ray: là spline Catmull-Rom sinh dần 1000 m phía trước tàu và xóa 220 m phía sau, mỗi khúc dài 120 m. Tàu chạy 40–88 m/s tùy dốc.
    - Bốn vùng nối mượt vào nhau, xen giữa là đoạn chuyển 260 m:
      - biển đêm (sóng phát sáng, cột đá, phao đèn), tới 1100 m;
      - dưới đáy biển (sứa, tảo, cá voi, cá đuối, cá barramundi lấy từ đồng cỏ), tới 2200 m;
      - mây hoàng hôn (biển mây bên dưới, đèn trời bay lên), tới 3300 m;
      - vũ trụ (thiên thạch, hành tinh có vành, tinh vân), tới 4500 m.
    - Lối ra: ở 4440 m có một lỗ khóa ánh sáng, đưa tàu về khúc cua cuối trước ga.
    - Đoạn mây: người dùng chê mây che tầm nhìn. Giờ 70% số mây nằm dưới ray 32–70 m làm biển mây, phần còn lại cách ray từ 45 m trở ra; sương mỏng (0.0009); mặt trời lệch sang bên; hành tinh chỉ hiện khi gần tới vũ trụ.
  - Minigame "bắt mảnh ký ức":
    - 12 mảnh pha lê đặt dọc đường (`SHARDS`): bên cạnh, trên đầu, dưới ray.
    - Nhìn thẳng vào một mảnh khoảng 0,18 giây (hoặc bay xuyên qua nó) là nhặt được: mảnh lóe trắng, bay về phía mắt, có tiếng chuông.
    - Góc trên bên phải hiện "✦ Mảnh ký ức n/12"; giữa màn hình có tâm ngắm nhỏ.
    - Các mảnh đã nhặt được lưu vào `user://progress.cfg`, mục `meadow/memory_shards`, để sau này dùng cho việc thoát khỏi vòng lặp.
  - Âm thanh và hiệu ứng khi đi tàu:
    - Âm thanh: gió và tiếng rung to dần theo tốc độ, tiếng phóng, tiếng cổng sáng, tiếng vụt khi lướt qua vật thể, tiếng rơi xuống và trồi lên mặt nước, nhạc nền riêng khi đi tàu.
    - Hình: góc nhìn rộng ra theo tốc độ, camera rung, vệt tốc độ ở rìa màn hình, tia lửa ở bánh xe, bọt nước, chớp trắng; hiệu ứng mờ dịu bớt trong lúc bay.
  - Nhạc khu vui chơi giờ nhỏ dần khi đi xa (`unit_size` 12, `max_distance` 150) và tắt hẳn khi đi tàu.
  - Validator: bot tự quay đầu nhìn các mảnh và nhặt đủ 12/12; cả vòng đi tàu khoảng 134 giây.
- Mẫu đu quay miễn phí xoay được: đã tìm (Poly Pizza, OpenGameArt, các chợ asset) nhưng không có bản CC0 nào tách được vòng quay và cabin; bản đẹp đều trả phí. Vì vậy vẫn dùng đu quay dựng bằng code, cabin treo ra ngoài vành để không che tầm nhìn.
- Trò chơi ở khu vui chơi làm sau: chỗ đã chừa là các Marker3D `GameStall1..3`, `GameStriker`, `GameCarousel` trong node `Fair`. Lều xiếc giờ chỉ để trang trí.
- Không thua, không đếm giờ. Nhảy lơ lửng như giấc mơ mặt nước (dùng chung `dream_player.gd`, `lucid = true`). Đi xa hơn 150 m thì bị giữ lại nhẹ nhàng ở mép.
- Người dùng muốn cảm giác liminal space / dreamcore. Hậu kỳ `dreamcore_post.gdshader` gồm: nhòe rìa, quầng sáng, lệch màu, nâng vùng tối thành tím nhạt, hạt phim, viền tối. Thêm DOF làm mờ cảnh xa.
- Cỏ: ba lớp MultiMesh (8 / 16 / 32 m) chỉ mang số lượng; vị trí từng ngọn do shader tính, cùng hàm `ground_height()` với collider (sửa một bên thì phải sửa bên kia). Validator so collider với mặt đất vẽ ra.
- Đang dev nên chương này có `"open": true` trong `game_progress.gd`: luôn mở trong menu Chọn chương, không cần thắng Đêm 1.
- Tối ưu (đo bằng `tools/bench_meadow.gd`, `MEADOW_QUALITY=0|1|2`): mức đồ họa trong Cài đặt quyết định lượng cỏ, tầm cỏ dày, SSAO, DOF, tầm bóng; mức Nhẹ còn vẽ 3D ở 75% rồi FSR phóng lên và tắt bóng của cây. Bồ công anh và bụi cây đã giảm lưới. Trời chỉ tính lại bản đồ phản chiếu khi độ sáng đổi. Trên RTX 3060 ở chỗ nặng nhất (cạnh cây, ban ngày): Nhẹ 367 FPS, Cân bằng 233, Cao 177 (trước khi tối ưu: 160).
- Kiểm tra: `tools/validate_meadow.gd` (gồm cả đi thật qua chỗ gập tới lều). Ảnh: `tools/capture_meadow.gd` ra `docs/meadow-*.png`, cảnh đêm là `meadow-night-*`. Trên RTX 3060, mức Cân bằng ban đêm được 171–206 FPS.

## Cách chạy

```sh
cd hub && npm start        # trình duyệt Cú Đêm + web + cổng LAN 8787
npm run start:game         # như trên, tự mở game
node hub/test/webs.js      # web giả qua HTTP thật
node hub/test/desktop.js   # lối tắt desktop, chỉ trong HOME tạm
node hub/test/game_link.js # Godot thật với web stack thật
```

Điện thoại: trong Cú Đêm vào `gaaglu.com/thiet-bi`, quét QR, bỏ qua cảnh báo chứng chỉ tự ký. Cần cùng Wi-Fi. Chứng chỉ lưu ở `~/.config/neh-school/lens-cert.json` (giữ tên cũ để điện thoại không phải chấp nhận lại).

## Kiến trúc hub

```text
Electron hub (hub/main.js)
├─ Cú Đêm: trình duyệt giả, chặn request bằng protocol.handle
├─ web stack hub/web/server.js, 127.0.0.1 cổng ngẫu nhiên, /game là WebSocket cho Godot
├─ cổng LAN HTTPS hub/web/phone.js, trang hub/web/phone-page.*
└─ ~/.config/neh-school/hub.json: port + token để Godot tìm hub
```

| Phần | File |
| --- | --- |
| Trình duyệt, tab, ghé trang thật, Peter cáu | `hub/main.js`, `hub/shell/`, `hub/profiles.js` |
| Tìm kiếm thật bằng cửa sổ ẩn | `hub/realweb.js` |
| Gaaglu, trộn kết quả, chặn từ khóa tự hại | `hub/web/sites.js` |
| Báo, trường, cổng dân cư, Làng Ta, Sợi Chỉ | `hub/web/news*.js`, `school.js`, `registry.js`, `social.js`, `soichi.js` |
| Phía game | `scripts/arg_bridge.gd` (`phone_paired` khi có điện thoại ghép) |

Tin nhắn hub → game: `door_bang`, `phone` (`on`), `phone_input`, `contact` (Sợi Chỉ, hiện chưa có liên hệ nào). Game → hub: `state`, `install_gaaglu`.

## Ranh giới phải giữ

- Không sao chép logo, tên, giao diện của Chrome, Google, báo hay hãng điện thoại thật, kể cả khi đổi màu.
- Người, trường, cơ quan, sự kiện trong game đều hư cấu.
- Từ khóa tự hại luôn thoát khỏi thế giới giả, hiện thông tin hỗ trợ thật (111, 115).
- Không sửa file hosts, không cài CA, không autostart, không đụng file thật của người chơi. Lối tắt desktop chỉ khi người chơi đồng ý ở màn hình đầu; gỡ bằng `npm run remove-desktop`.
- Chỉ dùng asset có giấy phép rõ, ghi vào `ASSETS.md`.
- Mọi cơ chế điện thoại thật phải có phương án chơi không cần điện thoại.

## Bẫy môi trường

- `ELECTRON_RUN_AS_NODE=1` được truyền từ VS Code: phải `unset` trước khi chạy Electron.
- **Người dùng thường đang chạy `npm start` và Godot.** Không kill rộng. Test song song: đặt `NEH_PHONE_PORT=8799`, `NEH_HUB_SESSION=<file tạm>`, `HOME=<thư mục tạm>` cho Electron.
- Wrapper `godot` tìm binary theo `HOME`, nên không đổi `HOME` khi gọi godot.
- Dự án co giãn canvas: test gửi chuột phải đổi sang tọa độ cửa sổ bằng `root.get_final_transform()` (xem `tools/validate_phone.gd`).
- Sau `change_scene_to_file` scene rời cây ngay; đổi scene từ trong xử lý input thì dùng `call_deferred`.
- Bản build phải dùng `tools/package_build.sh`: hub, `data/` và ảnh `docs/` nằm cạnh file chạy.

## Trạng thái kiểm thử (2026-11-09)

Qua: map, annex, progression (104), tunnel (56), chute, opening, night_one (60), hunter, hunter_smart, gear, chalk, menu, home, prologue, town, muoi_gio, caro, chess_rules, day_handover, quest, phone (19, cần display), và ba test hub.

Đỏ:
- `validate_runtime.gd`: đọc `MultiMesh.placements` không tồn tại; lỗi có từ trước đợt dọn.
- `validate_chess_play.gd`: 7 kiểm tra click bàn cờ trượt khi chạy headless. Code cờ không bị đụng tới trong đợt dọn; chưa xác minh trên commit cũ.

## Việc còn lại

- Người dùng viết cốt truyện mới; sau đó thêm chat (`home_story.gd`), bài đăng (`data/social_posts.json`, `data/soichi_posts.json`), bài báo, bằng chứng (`data/evidence.json`).
- Thoại của Bảy Rô (`scripts/caro/caro_people.gd`, `REVEAL`) và Thầy Khải (`scripts/chess/chess_people.gd`, `LORE`) vẫn nói về An bị bắt nạt năm 2009; đã bỏ phần siêu nhiên, giữ chờ cốt truyện mới.
- Kênh điện thoại: dựng tay cầm gyro/rung cho minigame.
- `school_runtime.tscn` còn metadata `realm_placements` cũ của các batch nội thất; vô hại, sẽ mất khi sinh lại runtime bằng `tools/optimize_map.gd` sau khi sửa `tools/runtime_optimizer.gd`.
- Thêm preset Windows; web cần màn hình thông báo riêng tư và nút tắt web thật trước khi cho người ngoài chơi.
