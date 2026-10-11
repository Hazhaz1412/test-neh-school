# Đêm 1: Ba manh mối và hành lang linh hồn

Flow này thay toàn bộ manh mối và nhiệm vụ cũ. Kịch bản: [Demo-Idea.md](../Demo-Idea.md). Gameplay: `school_progression.gd`, `classroom_lure.gd`, `an_notebook.gd`, `escape_pressure.gd`, `night_story_interactable.gd`, `endless_corridor.gd`.

Ánh sáng, bóng người, máu và âm thanh dẫn dắt; HUD không hiện mục tiêu kể lại sự kiện, bản đồ không đánh dấu gấu. Gần cửa/đồ vật chỉ hiện E. J vẫn lưu vật chứng khi người chơi tự mở. Ánh sáng nền sân được giảm trong đoạn khám phá và khôi phục sau phần tiền truyện. Phòng đầu chỉ sáng đèn; bóng nữ chỉ xuất hiện ở cửa sổ lầu 2 sau khi nhặt gấu. Nhìn từ xa không khiến bóng bỏ đi. Bóng rút vào phòng ngay khi player tới lầu 2, không cần tiến sát. Trong phòng có vở Nguyễn Bình An với chữ viết tay hỗn loạn. Bóng mở cửa 205 thật, đi dọc hành lang rồi qua cửa vào phòng; người chơi có thể theo vào. Pause giữ chuyển động, chơi lại ẩn bóng và khóa lại phòng này.

| Chặng | Tương tác và chuyển tiếp |
| --- | --- |
| Sự kiện 1: 22:30 / ánh đèn | Hai ô cửa kính phòng 103 khu A sáng vàng, ánh sáng hắt xuống sân, không có bóng người. Trong phòng chỉ có gấu bông. E mở cửa và nhặt gấu là xong manh mối 1, đèn tắt. |
| Sự kiện 2: bóng nữ / vở | Bóng nữ đứng ở cửa sổ lầu 2 khu đối diện, nhìn được từ tầng trệt. Player lên lầu 2 thì bóng mở cửa 205 rồi đi vào. E đọc cuốn vở Nguyễn Bình An, trang đầy chữ viết tay nguệch ngoạc, gạch xóa và mắt vẽ lặp lại. |
| Mở cửa | Máu và tiếng gõ dưới tầng trệt dẫn tới phòng 102. E mở cửa gây jumpscare; sau đó mới hiện gậy dính máu. Nhìn gần hoặc E kiểm tra ghi nhận gậy. Vở và gậy có thể thu theo bất kỳ thứ tự nào sau gấu. |
| Mất điện | Chỉ kích hoạt khi có cả gấu, vở và gậy. Tiếng cười chồng lớp và vọng nhiều hướng, đồ vật va đập phía sau, đèn lóe, cửa đóng sầm và ngột ngạt ở rìa màn hình. Không spawn ma đuổi trong trường. Hơi thở/tim tăng, đứng yên có thể mất máu sau ít nhất 10 giây cảnh báo; tiến về cổng làm dịu sức ép. Đèn và biểu tượng thoát hiểm xanh dẫn đường, mục tiêu lưu trong J. Cửa lớp vẫn mở lại được. |
| Cổng chính | Chạy ra cổng trong lúc trường chập chờn giữa hai thế giới. Chạm cổng gây tiếng điện rè và nhiễu trong 2,6 giây, rồi vào hành lang linh hồn. |
| Hành lang | WASD tự di chuyển, Shift 10,5 m/s; đi bộ 6 m/s hồi stamina. Chuột quay tự do, chuột phải nhìn sau. Bốn ngã rẽ, tám đường cụt có tủ chắn cuối đường; dấu chân máu/vải rách gợi đường đúng. Tủ cao để né, ghế dài thấp để nhảy và bàn gầm trống khoảng 0,94 m có ánh lạnh phía sau để Ctrl trượt. Có né hai tủ liên tiếp, tủ đổi chỗ và chướng ngại hạ xuống. Năm ma đuổi theo chính đường player đã chạy, kể cả khi chọn nhầm nhánh. Va cạnh mất 8 HP/khựng 0,55 giây; nhảy đáp trên ghế không tính là va đập. Đèn pin không tiêu pin. |
| Lan xuất hiện | Sau ít nhất 75 giây di chuyển và qua góc thứ tư ở 680 m. Lan quay lưng với player, mặt hướng đúng chiều chạy/rẽ; dừng chờ nếu player chậm. Player theo thêm khoảng 140 m, tự vào phòng cô mở. Cửa đóng và núp trước khi trò chuyện. |
| Hiểu lời nguyền | Visual novel với năm câu hỏi tự chọn: thế giới này, lời nguyền, giải thoát linh hồn, danh tính Lan và đường về trường. Lan không biết An, manh mối hay vị trí em. Nghe bốn giải thích cần thiết rồi chọn lời đáp cuối để mở gầm bàn; danh tính là nhánh tùy chọn. Esc đóng, E tiếp tục, giữ câu đã nghe. |
| Gầm bàn | E chui dưới bàn trong phòng trú, chờ 1,8 giây rồi chuyển sang dưới bàn trong phòng 103 của bản đồ trường. Người chơi vẫn đang núp; tự nhấn E chui ra. Khi trở lại trường mới cấp chìa phòng và mở đường gặp An. |
| Gặp An | An ở sân thượng A. Ba manh mối trong J; chọn câu hỏi và lời đáp theo thứ tự bất kỳ; AI đánh giá câu đã chọn theo ba trải nghiệm: cô lập, sợ bạo lực và cố viết nỗi đau nhưng không được nghe. |
| Bình minh | Cứu An rồi sống tới 06:00 để hoàn thành Đêm 1. Lời nguyền còn tiếp diễn trong những đêm sau. |

Đồng hồ bắt đầu 22:30, chạy liên tục qua nửa đêm và giữ nguyên khi chuyển thế giới. Mặc định mỗi giây chơi tương ứng nửa phút trong game, nên 22:30–06:00 là 15 phút thực. Thời điểm biến cố phụ thuộc vào hành động trong chuỗi, không phụ thuộc mốc 00:00. Màn kết chờ phần hướng dẫn Lan hoàn tất để không cắt mất đoạn chạy tối thiểu nếu người chơi khám phá quá lâu. Esc tạm dừng đồng hồ và minigame; J, M và hội thoại không dừng thời gian.

Ngột ngạt giảm khi khoảng cách tới cổng đạt một mốc gần hơn. Đi vòng không trì hoãn được mãi: sau 55 giây sức ép tối thiểu bắt đầu tăng. Chạm cổng dừng sát thương trước khi nhiễu điện khóa điều khiển. Reset dừng toàn bộ loop, ánh chớp và màn hình ngột ngạt.

Trong hành lang, không nhấn di chuyển thì nhân vật đứng lại. Sprint tiêu 9 stamina/giây, đi bộ hồi 11/giây; khi cạn phải hồi trên 30 mới chạy nhanh lại. Trượt cần ít nhất 7,5 m/s và lấy đà 0,35 giây, kéo dài 0,95 giây; capsule và camera thực sự hạ thấp, không đứng dậy khi còn vướng gầm bàn. Ma vẫn tiến tới độc lập với chuyển động của người chơi; dừng quá lâu có thể chết. Nội thất đổi chỗ bắt đầu ở khoảng cách 22 m, trượt trong 0,77 giây; chướng ngại hạ xuống trong 0,55 giây nhưng giữ khe thấp. Bản bàn Kenney loại bỏ thanh giằng ngang ở gầm tại runtime, giữ nguyên file GLB nguồn. Nhạc và tiếng chân dừng khi núp, tạm dừng hoặc chơi lại.

Bản demo một người chơi: đồng đội có trong cảnh vào trường; họ bị tách khỏi player tại cổng. Lan có model chạy, cửa phòng chuyển động và tương tác 3D. Lời gọi và giải thích hiện bằng chữ, chưa lồng tiếng. Nhạc chạy, tiếng gõ, jumpscare và nhiễu được tổng hợp trong `tools/build_story_audio.py`; tiếng cười ám ảnh và gầm truy đuổi xử lý từ các âm thanh CC0 có sẵn. Nguồn tiếng cười được ghi trong `assets/audio/teasing_giggle-source.json`.

H+P là bypass TEST có nhãn: bỏ qua chuỗi mở đầu, cấp ba manh mối và chìa, giữ An để thử hội thoại thật. R bắt đầu lại lúc 22:30 và đặt lại toàn bộ tiến độ, cửa, tư thế, điện và âm thanh.

## Kiểm tra

```sh
godot --headless --path . --script tools/validate_progression.gd
godot --headless --fixed-fps 60 --path . --script tools/validate_story_chase.gd
godot --headless --fixed-fps 60 --path . --script tools/validate_corridor_choices.gd
godot --headless --fixed-fps 60 --path . --script tools/validate_escape_pressure.gd
godot --headless --path . --script tools/validate_opening.gd
godot --headless --path . --script tools/validate_soul_quest.gd
godot --path . --script tools/capture_progression.gd --resolution 1280x720
godot --path . --script tools/capture_classroom_lure.gd --resolution 1280x720
godot --path . --script tools/capture_chase_redesign.gd --resolution 1280x720
```

Validation kiểm tra ray E thật của cửa/gấu/vở/gậy, thứ tự jumpscare–gậy và đủ ba manh mối mới mất điện, đồng hồ và reset. Chase dùng va chạm vật lý từng bước 1/60 giây, đưa WASD/Shift/Space/Ctrl vào handler thực, không cheat; kiểm tra stamina, bốn góc rẽ, nội thất chuyển động, đủ thời gian gặp Lan, tự vào phòng, cổng gầm bàn và đứng lại thì chết. Capture lớp học kiểm tra nhìn lâu từ xa vẫn đứng, nửa cầu thang chưa trigger, tới lầu 2 thì rút đi, cửa 205 tương tác được và nhân vật đi qua được. Bài choices kiểm tra tam giác model thật để đảm bảo gầm nhìn xuyên được, khe không có collider, Ctrl qua được còn nhảy không qua, đi nhầm nhánh không bị đánh từ xa và quay lại chọn đường được. Bài pressure kiểm tra cảnh báo, tạm dừng, chạy tới cổng giảm áp lực, đứng yên chết và reset. Capture redesign lưu các cảnh dựng kiểm tra riêng; không thay cho bài traversal toàn chặng. Bài AI dùng phản hồi protocol cố định, không khẳng định chất lượng hay khả năng truy cập API thật.

Kết quả: `progression-validation.json`, `chase-validation.json`, `progression-rendered-validation.json`, `classroom-lure-validation.json`, `chase-rendered-validation.json`, `corridor-choices-validation.json`, `escape-pressure-validation.json`.

Ảnh hai sự kiện: [phòng sáng từ cổng](night1-lure-arrival.png), [phòng sáng từ sân](night1-lure-courtyard.png), [bóng người phía đối diện](night1-opposite-shadow.png), [bóng biến mất / vết máu](night1-shadow-withdrawn.png). Kiểm tra riêng: `classroom-lure-validation.json`.

Ảnh mới: [vở của An](night1-an-notebook.png), [ngột ngạt khi mất điện](night1-blackout-pressure.png).

Ảnh phần sau: [cổng thoát hiểm](night1-emergency-exit.png), [hành lang đỏ](night1-corridor-run.png), [ma phía sau](night1-corridor-ghosts.png), [góc rẽ](night1-corridor-corner.png), [khe trượt nhìn xuyên được](night1-corridor-furniture.png), [Lan chạy quay lưng](night1-lan-back-facing.png), [bàn của Lan](night1-lan-table.png), [dưới bàn trong trường](night1-school-under-table.png).

Hội thoại: [giao diện, lựa chọn và phạm vi hiểu biết của Lan](VISUAL_NOVEL.md). Ảnh [Lan](night1-vn-lan-questions.png), [An](night1-vn-an-replies.png).
