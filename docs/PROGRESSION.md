# Đêm 1: Ba manh mối và hành lang linh hồn

> **Cập nhật 2026-11-08 (lần 5) · Đêm 1 kiểu trốn thoát theo đội.** Tên chỉ còn "Đêm 1". Đèn pin luôn là cây của đêm 0; đèn bấm tay và huy chương đã bỏ.
>
> - **Đội:** người chơi và 3 bạn AI: Ba Rô, Huna, Bơ Tồ (`hunt_team.gd`, `teammate_bot.gd`). Code viết theo danh sách người chơi, để sau này thay bot bằng người qua mạng.
> - **Thanh 600 giây:** mỗi lần bị bắt trừ 200 giây; trong lúc bị nhốt thanh tiếp tục chảy. Cứu được tối đa 2 lần, lần bắt thứ 3 là bị loại. Cả đội cùng bị giữ một lúc là thua. Sống tới 06:00 là thắng.
> - **Bị bắt:** bác lôi người đó tới phòng gần nhất trong 4 phòng nhốt (A-101, A-108, B-1101, B-1105) rồi khóa cửa. Lúc bị lôi đi, bấm A/D luân phiên để đẩy thanh kháng cự; thanh tự tụt, nên chỉ thoát được khi bị lôi xa. Mỗi lần thoát, lần sau khó hơn 50%; vào phòng thì tính lại từ đầu.
> - **Bị nhốt:** người chơi đi lại trong phòng được nhưng không ra được cửa. Đồng đội giữ E 3 giây ở ngoài cửa để mở. Phòng nhốt có dấu đỏ nhìn xuyên tường.
> - **Bác bảo vệ (AI của quỷ Ghen Tị):**
>   - Tốc độ gốc bằng 105% người chơi và tăng dần khi rượt.
>   - Tốc độ về lại mức gốc mỗi khi bác leo cửa sổ (1,4 giây, người chơi chỉ mất 0,45 giây), dọn kệ đổ (2,8 giây), bị kệ đè hoặc đóng ván.
>   - Người đã leo được hơn 0,2 giây thì không bắt được.
>   - Bác nghe tiếng chân chạy nên không mất dấu dễ: muốn cắt đuôi phải khuất tầm nhìn và đi êm.
>   - Bị kẹt thì bác bước ngang, không còn dịch chuyển xuyên tường.
>   - Bác nhớ các khe thấp đã thấy học sinh chui và quay lại đóng ván. Khe bị đóng ván thì giữ E 5 giây để gỡ, hoặc trượt vào phá ván và mất 25% máu.
> - **Người chơi:**
>   - Stamina 260.
>   - Thanh mệt: bị rượt càng lâu và hồi stamina càng nhiều thì stamina hồi càng chậm. Cắt đuôi được hoặc bị bắt thì thanh mệt về 0.
>   - Đang chạy bấm C để trượt.
>   - SPACE để leo cửa sổ hoặc kệ đã đổ. E để gạt kệ.
>   - Giữ chuột phải để quay đầu nhìn ra sau; đầu xoay mượt cả lúc quay đi và quay về.
> - **Bãi kiting (`kiting_course.gd`, `kiting_pallet.gd`):** 8 ô vòng đặt ở những chỗ được quét va chạm là trống.
>   - Giữa mỗi ô là chồng thùng để chạy vòng. Đầu tây để trống, đầu đông bịt tường có một khe thấp.
>   - Tường bắc có một khe kệ và một cửa sổ; tường nam có một cửa sổ và một khe thấp.
>   - Đá, cỏ, bụi trang trí nằm trong ô được dọn đi.
> - **Navmesh riêng `hunt_navigation.tres`:** ô 0,125 m, ô dọc 0,125 m, bán kính 0,375 m, leo tối đa 0,3 m (`tools/bake_hunt_navigation.gd`).
>   - Ô 0,25 m làm tròn khoảng chừa ở góc tường xuống còn vài cm, nên người và bot cạ góc.
>   - Mức leo 0,5 m nối sàn với hông dốc cầu thang, nên bác cố trèo lên từ bên hông rồi đi lạc vào gầm cầu thang.
>   - Bác và bot bước lên bậc bằng cách dò mặt bậc ngay trước chân, cao tối đa 0,65 m (`scripts/path_steer.gd`), nên không trèo được lan can hay bàn. Bước né khi bị kẹt không bao giờ đẩy ra khỏi mép dốc.
> - **Bồn cây giữa sân:** bỏ gờ (`tools/build_map.gd`), scene đã dựng lại. So từng node thì chỉ 16 viền bồn cây thay đổi.
> - **Kiểm tra và đo:**
>   - `tools/validate_night_one.gd`: 60 kiểm tra.
>   - `tools/measure_guard_chase.gd`: đo số lần bác đứng đơ, số lần mất dấu, và quãng bác phải đi tăng bao nhiêu sau mỗi lần leo hoặc chui.
>   - `tools/capture_night_one.gd`: ảnh `docs/night1-*.png`.

> **Cập nhật 2026-11-08 (lần 4) · Đêm 1 không còn thế giới linh hồn:** vào đêm 1 qua cổng trường thì trường vẫn như đêm 0 (`world.guard_night`). Phím B bị tắt, không có ma bắt nạt hay cảnh hù. Kẻ săn vẫn là AI của quỷ Ghen Tị (`envy_director.gd` + `envy_demon.gd`), nhưng mặc thân bác bảo vệ (`guard_hunter_model.gd`): model Rocketbox, mũ, đèn pin có ánh sáng thật, tiếng giày CC0, tiếng chìa khóa và còi. Các hệ thống của đêm săn (tiếng ồn, phấn, hoảng loạn, chuông) kiểm tra `world.night_hunt()` thay vì `spirit_enabled`. Sân thượng không còn là chỗ an toàn ở đêm này. Kiểm tra: `tools/validate_night_one.gd`, `tools/validate_envy_smart.gd`; ảnh: `tools/capture_night_one.gd`.

> **Cập nhật 2026-11-08 (lần 3):**
> - **Hành lang sang khu B:** rộng 6 m, hai bên có trụ tường cách nhau 7 m và hai tủ hồ sơ (`CONNECTOR_PIERS` trong `tools/build_map.gd`), nên nép sau trụ là bác ngoái lại cũng không thấy. Z / X để nghiêng đầu lấp ló (`player.gd`, `_tick_lean`); lúc nghiêng, điểm bác cần thấy là cái đầu.
> - **Navmesh:** bán kính tác nhân giảm từ 0,5 xuống 0,25 m. Godot làm tròn bán kính lên theo ô 0,25 m, nên 0,5 m bịt kín mọi cửa lớp rộng 1,3 m.
> - **Lẻn ra khỏi trường:** cứ 13 giây, rút dần xuống 6,5 giây, bác lại đoán được khu người chơi đang ở, tới lục và mở tủ gần nhất. Thấy người chơi thì bác rượt theo (4,7 m/s). Mất dấu 2,4 giây thì bác lục chỗ thấy lần cuối và hai chỗ nấp gần đó. Nếu bác thấy người chơi chui vào chỗ nấp thì vẫn bị lôi ra. Bị bắt thì bác đứng ngay trên tầng của người chơi rồi quay lại tìm luôn.
> - **Phá cửa:** 24 giây, mỗi lần thua cộng 4 giây, tối đa 32 giây. Bác đứng cửa sổ rọi đèn tới khi còn 15 giây.
> - **Đường hầm mới (`tunnel_escape.gd`) thay hành lang đỏ cũ:** hành lang cũ, Lan, phòng trú và gầm bàn đã gỡ. Hầm là mạng các hành lang có ngã rẽ và ngõ cụt; nhánh đông ở A bị cửa song sắt xích lại. Vật cản đặt sẵn từ đầu, không tự di chuyển. Bác đuổi theo đường ngắn nhất và hai lần chui cửa phòng bơm ra chặn đầu (ở C và L3), buộc người chơi quay lại đi đường khác. Tới G thì sàn sập xuống cống trượt (`corridor_chute.gd`). Cuối hầm là vực, bên dưới là bể nước: người chơi nhảy xuống, dưới nước vẫn nhìn quanh được và SPACE để bơi nhưng không lên nổi, chìm dần, ánh sáng mờ đi rồi tắt hẳn, sau đó tỉnh dậy ở nhà (`finish_dream`).
> - **Âm thanh:** tiếng nước và tiếng giày bác bảo vệ là asset CC0 từ OpenGameArt, xem ASSETS.md.
> - **Đường hầm:** trần có va chạm, nhảy cao 1,1 m (đủ qua rào 0,8 m, đầu không chạm trần 3,2 m). Mặt nước có sóng (`assets/materials/reservoir_water.gdshader`), nhìn từ dưới lên là lớp riêng tối màu (`reservoir_underside.gdshader`). Chạm nước thì nước bắn lên. Dưới nước có sương xanh thật trong Environment và âm thanh qua lọc low-pass; cả hai được gỡ khi xong. Ánh trăng lọt qua lỗ thoát nước trên trần chiếu thành một vũng sáng trên mặt nước.
> - **Kiểm tra:** `tools/validate_tunnel.gd` (có bot chạy thật qua hầm), `tools/validate_progression.gd`.
>
> **Cập nhật 2026-11-08 (lần 2):** Bác bảo vệ giờ lên phòng **B-302** (tầng 3 khu B), không còn vào 306. Máy ảnh chỉ chụp được ở B-302: trong buồng vệ sinh và lúc bám theo, flash bị khóa. Lúc bám theo, nếu cách bác quá 22 m trong 4 giây thì mất dấu và chơi lại đoạn bám. Chụp xong, bác lao ra cửa, người chơi có 4 giây để chui vào một tủ ngoài hành lang (gần nhất là cặp `HallB_2`, cách cửa 6 m). Bác đứng nghe trước tủ nên phải giữ Space nín thở. Sau đó bác tuần tra tầng 2 và tầng 3 trên navmesh (`PATROL` trong `guard_prologue.gd`), nghe tiếng chạy thì tới tận nơi xem. Người chơi phải lẻn ra sân trước cổng chính. Đoạn chạy tự động đã bỏ. Tới gần cổng có cảnh bác đứng ở cửa sổ tầng 3 rọi đèn xuống và quát "Đứng yên đó!". Sau đó người chơi có 20 giây (mỗi lần thua cộng 4 giây, tối đa 28) để lấy tua vít trong thùng đồ nghề, tháo 4 con vít (giữ chuột trái trên vít, xoay vòng tròn 3 vòng) và spam Space đạp tung cửa phòng kỹ thuật (`school_escape.gd`, `door_breaker.gd`). Bác xuất hiện ở cửa chính khi còn 10 giây rồi chạy băng qua sân. An trên sân thượng đã bỏ; Đêm 1 thắng khi sống tới 06:00. Trong hành lang đỏ đã hiện lại model bác bảo vệ: `humanoid_model.gd` từng cộng độ cao của node cha thêm một lần nữa, nên model nằm thấp hơn 300 m. Hai đoạn trượt hầm chậm hơn (11,5 lên 14,5 m/s), các cổng cách nhau ít nhất khoảng 1,4 giây, rebar hiện từ 62 m, và làn trống có cột sáng trắng. Ảnh: `docs/guard-*.png`, `docs/slide-*.png`.
>
> **Cập nhật 2026-11-08 (bác bảo vệ):** sau gương cầm tay là đoạn bác bảo vệ (`guard_prologue.gd`, `security_guard.gd`): trốn trong buồng vệ sinh, bám theo lên phòng 306, chụp giấy tờ, chạy trốn. Đoạn quảng trường và vẽ ký hiệu ở cổng đã bỏ; cổng khóa thì giật cửa hầm trong chốt bảo vệ (`school_escape.gd`). Hành lang đỏ là đường hầm kỹ thuật, không bật thế giới linh hồn, chỉ một người đuổi. Cuốn vở, cảnh đập cửa và phong ấn đã xóa. Chi tiết ở [Demo-Idea.md](../Demo-Idea.md) mục 3–4. Kiểm tra: `godot --headless --fixed-fps 60 --path . --script tools/validate_progression.gd`, ảnh: `tools/capture_guard.gd`.
>
> **Cập nhật 2026-11-08:** phần mở đầu đã đổi sang trinh thám (cài tóc → tiếng vỡ → nhà vệ sinh → tủ côn trùng → gương cầm tay). Bóng ma, vết máu và ma jumpscare đã bỏ. Các hàng từ "Cuốn vở" trở xuống là chuỗi cũ, hiện không còn được nối từ phần mở đầu. `validate_night1_escape.gd`, `capture_night1_escape.gd`, `capture_progression.gd`, `capture_chase_redesign.gd` vẫn kiểm chuỗi cũ nên sẽ báo lỗi. Kiểm chuỗi mới: `validate_progression.gd`, ảnh: `capture_prologue_restroom.gd`.

Flow này thay toàn bộ manh mối và nhiệm vụ cũ. Kịch bản: [Demo-Idea.md](../Demo-Idea.md). Gameplay: `school_progression.gd`, `classroom_lure.gd`, `restroom_scene.gd`, `insect_swarm.gd`, `door_siege.gd`, `school_escape.gd`, `seal_trace.gd`, `progression_gate.gd`, `fear_overlay.gd`, `an_notebook.gd`, `night_story_interactable.gd`, `endless_corridor.gd`.

Ánh sáng, âm thanh và vệt nước dẫn dắt; HUD không hiện mục tiêu kể lại sự kiện, bản đồ không đánh dấu gấu. Gần cửa/đồ vật chỉ hiện E. J vẫn lưu vật chứng khi người chơi tự mở. Ánh sáng nền sân được giảm trong đoạn khám phá và khôi phục sau phần tiền truyện. Chữ chỉ xuất hiện ở các gợi ý phím ngắn của bốn đoạn chạy, vì đó là thao tác mới.

| Chặng | Tương tác và chuyển tiếp |
| --- | --- |
| Sự kiện 1: 22:30 / ánh đèn | Hai ô cửa kính phòng 103 khu A sáng vàng. Trên trần có bóng đèn tuýp phát sáng với quầng chói nhẹ (`classroom_lure.gd`), thỉnh thoảng chập chờn 0,35 giây để gây chú ý. Phòng trống, chỉ có một chiếc cài tóc nhựa hồng gãy đôi, có ánh lấp lánh ở viên đá. E nhặt là xong manh mối 1. |
| Tiếng vỡ trên lầu | 1,3 giây sau khi nhặt, tiếng kính vỡ (bản bị trần nhà làm nghẹt) vang từ nhà vệ sinh A-203, ngay phía trên 103. Đèn 103 chập chờn, bụi rơi từ trần. Cửa A-203 hết khóa. Không còn cửa sắt cầu thang; thứ tự được giữ bằng cửa phòng. |
| Lần theo nước | Gương rơi làm bể vòi: nước phun, tiếng nước chảy nghe được từ đầu cầu thang tầng 2. Sau khoảng 4 giây, trần 103 loang vết ố và nhỏ giọt có tiếng. Vũng nước lan từ chậu rửa ra khe cửa A-203 rồi dọc hành lang về phía cầu thang chính trong 20 giây, nên người chơi lên tới tầng 2 là gặp vệt nước dẫn tới cửa. |
| Nhà vệ sinh A-203 | Sàn gạch, ốp tường, 6 buồng vệ sinh, 4 chậu rửa có gương. Gương thứ ba vỡ hình mạng nhện, mảnh kính trên bàn đá và sàn. Tủ đồ ở góc gần cửa sổ hé cửa 9°, bên trong có thứ chói sáng qua khe, sáng rực hơn khi đèn pin quét trúng. |
| Tủ đồ / côn trùng | E mở tủ: cửa bật mạnh, 16 con gián và nhện lao vào camera rồi bò tán ra mép màn hình, 26 con khác tràn xuống sàn chạy vào gầm buồng. Rung camera, tim đập, khóa di chuyển 1,5 giây. Không gây sát thương. Code: `insect_swarm.gd`. |
| Gương cầm tay | Hết khóa thì chiếc gương cầm tay vỡ nằm trên kệ giữa. E lấy là xong manh mối 2. Chuỗi tiền truyện tạm dừng ở đây, chờ viết tiếp. |
| (Chưa nối) Cuốn vở | E nhặt vở: ghi manh mối 3, nhạc tắt hẳn, cửa đóng. Vở nằm sâu trong phòng nên cửa luôn đóng được. Trang vở có ký hiệu con mắt khóc dùng ở cổng. Sự kiện kế tiếp chờ người chơi đóng vở. |
| Đập cửa | 1,4 giây sau khi đóng vở có một tiếng đập; từ 3,2 giây đập liên tục và nhanh dần, tiếng khóc tiến lại dọc hành lang; từ 7,2 giây điện toàn trường chập chờn; 9 giây cửa bật tung, mất điện hẳn, bắt đầu chạy. Cửa khóa trong lúc này. |
| Đoạn 1: hành lang | Chạy tự động 5,6 m/s trên đường ray cách tường, hành lang rộng 3 m. Bàn ghế bay ra và rơi vào làn: A/D né bàn, Space nhảy ghế dài, Ctrl cúi dưới tủ lơ lửng. Chạm phải khựng 0,5 giây. |
| Đoạn 2: cầu thang | Đi đúng đường cầu thang thật qua ba tầng, khoảng 55 m. Tim 91 nhịp/phút và nhanh dần tới 115. Space trong ±0,15 giây quanh nhịp; ba nhịp đầu để nghe, không phạt. Sai nhịp hoặc bỏ nhịp thì hụt chân. Màn hình tối theo độ sâu và theo hơi thở. Có vòng tròn thu vào tâm đúng nhịp cho người không nghe được âm thanh. |
| Đoạn 3: quảng trường | Vật lý thật, tự chạy 6,1 m/s, chuột hoặc A/D lái. Chỉ hai đèn trên lộ trình còn sáng; tới gần một đèn thì nó nổ tắt và đèn kế tiếp sáng. Không tiến về đèn với ít nhất 2,2 m/s thì ma áp sát 2,4 m/giây. Đài phun nước nằm giữa đèn 1 và 2 nên phải tự lái vòng. Giữ chuột phải quay đèn pin ra sau: nếu trúng ma thì đẩy nó lùi 2,8 m/giây, tốn 14% pin/giây. |
| Đoạn 4: cổng | Nhân vật dừng trước cổng có xích và ký hiệu phát sáng. Bảng đen hiện ký hiệu mờ, giữ chuột trái vẽ theo đúng thứ tự. Ma tiến 0,62 m/giây. Lệch khỏi nét quá 78 px thì đứt nét, lùi lại sáu điểm và mất 1,2 m. Nhấc phấn thì không phạt. |
| Cổng chính | Phong ấn vỡ, tiếng điện rè và nhiễu trong 2,6 giây rồi vào hành lang linh hồn. |
| Hành lang | WASD tự di chuyển, Shift 10,5 m/s; đi bộ 6 m/s hồi stamina. Chuột quay tự do, chuột phải nhìn sau. Bốn ngã rẽ, tám đường cụt có tủ chắn cuối đường; dấu chân máu/vải rách gợi đường đúng. Tủ cao để né, ghế dài thấp để nhảy và bàn gầm trống khoảng 0,94 m có ánh lạnh phía sau để Ctrl trượt. Có né hai tủ liên tiếp, tủ đổi chỗ và chướng ngại hạ xuống. Năm ma đuổi theo chính đường player đã chạy, kể cả khi chọn nhầm nhánh. Va cạnh mất 8 HP/khựng 0,55 giây; nhảy đáp trên ghế không tính là va đập. Đèn pin không tiêu pin. |
| Lan xuất hiện | Sau ít nhất 75 giây di chuyển và qua góc thứ tư ở 680 m. Lan quay lưng với player, mặt hướng đúng chiều chạy/rẽ; dừng chờ nếu player chậm. Player theo thêm khoảng 140 m, tự vào phòng cô mở. Cửa đóng và núp trước khi trò chuyện. |
| Hiểu lời nguyền | Visual novel với năm câu hỏi tự chọn: thế giới này, lời nguyền, giải thoát linh hồn, danh tính Lan và đường về trường. Lan không biết An, manh mối hay vị trí em. Nghe bốn giải thích cần thiết rồi chọn lời đáp cuối để mở gầm bàn; danh tính là nhánh tùy chọn. Esc đóng, E tiếp tục, giữ câu đã nghe. |
| Gầm bàn | E chui dưới bàn trong phòng trú, chờ 1,8 giây rồi chuyển sang dưới bàn trong phòng 103 của bản đồ trường. Người chơi vẫn đang núp; tự nhấn E chui ra. Khi trở lại trường mới cấp chìa phòng và mở đường gặp An. |
| Gặp An | An ở sân thượng A. Ba manh mối trong J; chọn câu hỏi và lời đáp theo thứ tự bất kỳ; AI đánh giá câu đã chọn theo ba trải nghiệm: cô lập, sợ bạo lực và cố viết nỗi đau nhưng không được nghe. |
| Bình minh | Cứu An rồi sống tới 06:00 để hoàn thành Đêm 1. Lời nguyền còn tiếp diễn trong những đêm sau. |

Đồng hồ bắt đầu 22:30, chạy liên tục qua nửa đêm và giữ nguyên khi chuyển thế giới. Mặc định mỗi giây chơi tương ứng nửa phút trong game, nên 22:30–06:00 là 15 phút thực. Thời điểm biến cố phụ thuộc vào hành động trong chuỗi, không phụ thuộc mốc 00:00. Màn kết chờ phần hướng dẫn Lan hoàn tất để không cắt mất đoạn chạy tối thiểu nếu người chơi khám phá quá lâu. Esc tạm dừng đồng hồ và minigame; J, M và hội thoại không dừng thời gian.

## Dynamic Difficulty Adjustment

Cả bốn đoạn dùng chung một giá trị: `gap`, khoảng cách tính bằng mét giữa ma và người chơi trên đúng đường người chơi vừa chạy. Lỗi trừ `gap`; ma bị bắt khi `gap` về 0.

- **Rubber-banding:** `gap` trên 7,5 m thì ma tăng tốc 1,4 m/giây, nên chơi tốt không cắt đuôi được; `gap` dưới 3 m thì ma chậm lại 1,1 m/giây, nên chơi kém không bị bắt ngay. Chỉ nhiều lỗi liên tiếp mới đưa `gap` về 0. Đoạn 4 tắt cơ chế này vì áp lực ở đó là thời gian.
- **Điểm lưu theo đoạn:** bị bắt chỉ chơi lại đoạn đang chạy, không mất máu; vị trí, đường ma đuổi và pin trở về đầu đoạn.
- **Trợ giúp theo số lần thua:** mỗi lần thua cùng một đoạn tăng mức trợ giúp, tối đa 2. Mỗi mức giảm 18% hình phạt, giãn khoảng cách chướng ngại thêm 25%, nới cửa sổ nhịp tim thêm 0,05 giây và nới vùng vẽ thêm 10 px.
- **Số liệu:** `escape.report` lưu số lỗi, `gap` thấp nhất và thời gian từng đoạn; `escape.attempts` lưu số lần thua. Bài kiểm tra in dòng `DDA / ...` để đưa vào báo cáo.

Bản co-op (một người cầm đèn, một người phá khóa) chưa làm vì game chưa có multiplayer.

Trong hành lang, không nhấn di chuyển thì nhân vật đứng lại. Sprint tiêu 9 stamina/giây, đi bộ hồi 11/giây; khi cạn phải hồi trên 30 mới chạy nhanh lại. Trượt cần ít nhất 7,5 m/s và lấy đà 0,35 giây, kéo dài 0,95 giây; capsule và camera thực sự hạ thấp, không đứng dậy khi còn vướng gầm bàn. Ma vẫn tiến tới độc lập với chuyển động của người chơi; dừng quá lâu có thể chết. Nội thất đổi chỗ bắt đầu ở khoảng cách 22 m, trượt trong 0,77 giây; chướng ngại hạ xuống trong 0,55 giây nhưng giữ khe thấp. Bản bàn Kenney loại bỏ thanh giằng ngang ở gầm tại runtime, giữ nguyên file GLB nguồn. Nhạc và tiếng chân dừng khi núp, tạm dừng hoặc chơi lại.

Bản demo một người chơi: đồng đội có trong cảnh vào trường; họ bị tách khỏi player tại cổng. Lan có model chạy, cửa phòng chuyển động và tương tác 3D. Lời gọi và giải thích hiện bằng chữ, chưa lồng tiếng. Nhạc chạy, tiếng gõ, jumpscare và nhiễu được tổng hợp trong `tools/build_story_audio.py`; tiếng cười ám ảnh và gầm truy đuổi xử lý từ các âm thanh CC0 có sẵn. Nguồn tiếng cười được ghi trong `assets/audio/teasing_giggle-source.json`.

H+P là bypass TEST có nhãn: bỏ qua chuỗi mở đầu, cấp ba manh mối và chìa, giữ An để thử hội thoại thật. R bắt đầu lại lúc 22:30 và đặt lại toàn bộ tiến độ, cửa, tư thế, điện và âm thanh.

## Kiểm tra

```sh
godot --headless --path . --script tools/validate_progression.gd
godot --headless --fixed-fps 60 --path . --script tools/validate_story_chase.gd
godot --headless --fixed-fps 60 --path . --script tools/validate_corridor_choices.gd
godot --headless --fixed-fps 60 --path . --script tools/validate_night1_escape.gd
godot --headless --path . --script tools/validate_opening.gd
godot --headless --path . --script tools/validate_soul_quest.gd
godot --path . --script tools/capture_progression.gd --resolution 1280x720
godot --path . --script tools/capture_classroom_lure.gd --resolution 1280x720
godot --path . --script tools/capture_chase_redesign.gd --resolution 1280x720
godot --path . --script tools/capture_night1_escape.gd --resolution 1280x720
```

Validation kiểm tra ray E thật của cửa/gấu/vở/gậy, thứ tự gấu–gậy–vở, đồng hồ và reset. Bài `validate_night1_escape.gd` chạy nguyên chuỗi mới: capsule thật không vượt được cửa sắt, từng nhịp jumpscare, nhạc tăng theo tầng, raycast nhìn thấy bóng, đập cửa, 300 seed × 3 mức trợ giúp đều có đường né, rồi bot đưa input vào handler thật qua cả bốn đoạn, kể cả thua ở từng đoạn và chơi lại đúng đoạn đó. Chase dùng va chạm vật lý từng bước 1/60 giây, đưa WASD/Shift/Space/Ctrl vào handler thực, không cheat; kiểm tra stamina, bốn góc rẽ, nội thất chuyển động, đủ thời gian gặp Lan, tự vào phòng, cổng gầm bàn và đứng lại thì chết. Capture lớp học kiểm tra phòng sáng đèn và bóng ở cửa sổ tầng 3. Bài choices kiểm tra tam giác model thật để đảm bảo gầm nhìn xuyên được, khe không có collider, Ctrl qua được còn nhảy không qua, đi nhầm nhánh không bị đánh từ xa và quay lại chọn đường được. Capture redesign lưu các cảnh dựng kiểm tra riêng; không thay cho bài traversal toàn chặng. Bài AI dùng phản hồi protocol cố định, không khẳng định chất lượng hay khả năng truy cập API thật.

Kết quả: `progression-validation.json`, `chase-validation.json`, `progression-rendered-validation.json`, `classroom-lure-validation.json`, `chase-rendered-validation.json`, `corridor-choices-validation.json`, `night1-escape-validation.json`.

Ảnh mở đầu: [phòng sáng từ cổng](night1-lure-arrival.png), [phòng sáng từ sân](night1-lure-courtyard.png). Kiểm tra riêng: `classroom-lure-validation.json`.

Ảnh chuỗi mới: [cửa sắt](night1-stair-gate.png), [ma lao tới](night1-jumpscare-lunge.png), [màn hình đỏ](night1-jumpscare-red.png), [bóng ở cửa sổ tầng 3](night1-opposite-shadow.png), [bóng cuối hành lang](night1-hall-shadow.png), [vở của An](night1-an-notebook.png), [đèn chớp](night1-siege-flicker.png), [né đồ](night1-escape-corridor.png), [cầu thang](night1-escape-stairs.png), [đèn quảng trường](night1-escape-lamps.png), [phong ấn cổng](night1-gate-seal.png), [bảng đen](night1-gate-chalkboard.png).

Ảnh phần sau: [hành lang đỏ](night1-corridor-run.png), [ma phía sau](night1-corridor-ghosts.png), [góc rẽ](night1-corridor-corner.png), [khe trượt nhìn xuyên được](night1-corridor-furniture.png), [Lan chạy quay lưng](night1-lan-back-facing.png), [bàn của Lan](night1-lan-table.png), [dưới bàn trong trường](night1-school-under-table.png).

Hội thoại: [giao diện, lựa chọn và phạm vi hiểu biết của Lan](VISUAL_NOVEL.md). Ảnh [Lan](night1-vn-lan-questions.png), [An](night1-vn-an-replies.png).
