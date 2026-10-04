# Máy ảnh và túi sáu ô

Máy ảnh có từ đầu ở ô **2**. Nhấn **2**, rồi **chuột trái** để chụp. Cú chớp 0,55 giây tăng ánh sáng 3D toàn cảnh, kể cả phòng kín; mọi ma ở tất cả các tầng biến mất **6 giây**. Khi tan, chúng mất collider, dừng di chuyển, ngừng đánh/nghe/rỉ tai và quên chỗ nấp nghi ngờ. Chúng trở lại cùng vị trí và collider sau đó, có 1 giây hồi đòn. Nếu player đang đứng đúng vị trí ma, ma chờ player rời ra để tránh hiện collider trong người.

Một ảnh tốn **20 điểm phần trăm** từ thanh pin chung với đèn pin, màn trập hồi **1,5 giây**. 100% đủ **5 ảnh** khi không dùng đèn. Nhặt pin dự phòng, chọn ô pin và chuột trái sạc **+50**, tối đa 100. Cú chụp tiếp theo có thể kéo dài thời gian ma tan nhưng vẫn mất đủ pin. Dùng lúc bị vây để mở lối thoát; nguồn pin hữu hạn suốt đêm 12 phút.

Đèn pin tiêu **0,675%/giây**, đầy pin dùng khoảng **148 giây** (gấp đôi trước). Camera tiếp tục dùng nguồn chung nên chụp sẽ rút ngắn thời gian đèn còn sáng.

**1–6/cuộn chuột** chọn ô, **chuột trái** dùng đồ, **Q** thả xuống sàn, **E** nhặt. Túi đúng sáu vật, không cộng dồn. Khởi đầu: đèn pin, máy ảnh, ba viên phấn, một ô trống. Mỗi pin/sơ cứu/phấn chiếm một ô. Đầy túi thì đồ nhặt vẫn nằm tại chỗ. Dùng vật tiêu hao giải phóng ô; không tiêu sơ cứu lúc đầy máu hay pin lúc đầy năng lượng. Q có thể thả cả máy ảnh/đèn pin để dành chỗ, và E nhặt lại; năng lượng vẫn thuộc thanh pin chung, không được nhân đôi khi thả/nhặt.

Chìa khóa tổng và bốn ký ức thuộc nhiệm vụ, lưu riêng. **F** chọn và bật/tắt đèn pin; **G** chọn phấn; giữ G (hoặc chuột trái khi cầm phấn) tối đa 1,5 giây rồi thả để ném xa tới ×5. Chạm nhanh ném như cũ. Thanh lực chỉ hiện lúc tích; đổi đồ, nấp, mở giao diện, tạm dừng hoặc mất focus hủy lực mà không mất viên phấn. Phấn chỉ tiêu khi ném thật và không xuyên tường ở tốc độ cao. Chọn vật khác tắt đèn để tiết kiệm. Khi nấp có thể chọn và dùng pin/sơ cứu; không chụp hoặc thả đồ xuyên tủ. M/J/phần nhập lời an ủi chặn sử dụng đồ trong giao diện và vẫn để đêm chạy; Esc đóng băng cả hồi màn trập và thời gian ma tan.

Chỉnh node School → **Survival · camera**: `camera_banish_seconds`, `camera_shot_cooldown`. Chi phí cố định 20 nằm ở `player.gd`; hiệu ứng ánh sáng ở `camera_flash.gd`, banishment ở `bully_ghost.gd`/`school_entity.gd`, túi và sử dụng ở `player.gd`, prop cầm ở `held_item.gd`, icon ở `compact_hud.gd`. Model có sẵn/giấy phép trong [ASSETS](../ASSETS.md).

```sh
godot --headless --path . --script tools/validate_chalk.gd
godot --path . --script tools/validate_chalk.gd --resolution 1280x720
godot --headless --path . --script tools/validate_camera.gd
godot --path . --script tools/validate_camera.gd --resolution 1280x720
godot --path . --script tools/capture_camera.gd --resolution 1280x720
```

Validation kiểm tra chi phí, pin chung, cooldown/pause, cả 13 ma/4 loại trên nhiều tầng, collider/AI/tiếng khi tan và khi trở lại, ánh 3D/phục hồi sương, túi đầy, dùng/thả/nhặt không nhân đồ, model cầm, reset và chặn dùng lúc chết/nấp/giao diện. Bản có display kiểm tra thêm phím số, cuộn chuột và click thật. Ảnh dưới bố trí bốn loại ma để minh họa, dùng model/hiệu ứng thật trong Godot.

- [Đang cầm máy ảnh](camera-ready-preview.png)
- [Cú chớp, ma biến mất](camera-flash-preview.png)
- [Ma quay lại](camera-return-preview.png)
- [Giữ phấn đầy lực](chalk-charge-preview.png)

Tầm ném đo bằng CharacterBody trên sân thực tế: ném nhanh khoảng **6,2 m**, đầy lực khoảng **30,6 m** với cùng góc nhìn, gần **×5**. Góc nhắm, độ cao và vật cản vẫn ảnh hưởng điểm rơi. `CHALK_CHARGE_SECONDS`, `CHALK_MAX_RANGE_MULTIPLIER` và `BATTERY_RECHARGE` ở `player.gd` cho phép chỉnh tiếp. `validate_chalk.gd` kiểm tra tầm bay/va chạm thật, lực giữa chừng, hủy charge, tiêu hao và input giữ/thả.
