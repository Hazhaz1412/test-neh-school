# Đêm 01: sinh tồn trong oán khí bạo lực học đường

F5 chạy [mở đầu không lời](OPENING.md), đưa nhóm điều tra qua cửa bảo trì vào trường lúc 23:30. Sau 60 giây chuẩn bị, chuông 00:00 kéo player sang thế giới linh hồn. Sống từ **00:00 tới 06:00 trong 12 phút thực**, đồng thời cần giải cứu một linh hồn học sinh bị bắt nạt. Chìa tổng trong kho chỉ mở 39 cửa phòng, không mở cổng thắng sớm.

Đã có 4 vật chứng và hội thoại tự nhập với AI qua bridge Gemini; xem [SOUL_QUEST.md](SOUL_QUEST.md) để cấu hình key/model. Bản hiện tại có đồng hồ, chuông, sinh tồn và kết quả bình minh; chưa cứu được linh hồn thì báo đêm chưa hoàn thành. ENTER bỏ qua phim, ESC dừng phim/game, R bắt đầu lại mở đầu, N bắt đầu lại sau khi kết thúc. B chỉ dùng cho preview ngoài lượt.

## Đọc dấu hiệu và chọn cách đối phó

Các thực thể đại diện cho hành vi gây bạo lực và oán khí của trường, giữ đồng phục/hình ảnh học đường.

| Thực thể | Dấu hiệu và nguy hiểm | Chiến thuật |
| --- | --- | --- |
| 3 học sinh cầm gậy | Đầu không mặt, tiếng gầm và chân dồn, lao nhanh, báo đồng bọn khi nhìn thấy | Cắt đường nhìn trước khi E nấp; giữ stamina cho đợt lao; đóng cửa để có khoảng nghỉ |
| 1 Kẻ Dò Tiếng | Cao gầy, băng che mặt và tai lớn, phản ứng với tiếng chân/cửa; không dùng mắt | Ctrl đi nhẹ và giữ khoảng cách; G ném phấn tạo tiếng va chạm thật; khi nấp và hoảng loạn, Space nín thở |
| 1 Kẻ Rỉ Tai | Ba mặt, miệng bị bịt, tiếng chorus định hướng; cảnh báo trước khi tăng hoảng loạn và gọi các thực thể nghe gần | Khuất tường/cửa hoặc F rọi vào mặt 0,7 giây: ngắt tiếng trong 2,4 giây, cần 8 giây trước lần ngắt bằng đèn kế tiếp |
| 1 Kẻ Chặn Lối | Thân lớn, cặp chiếm giữ và đai, bước trầm; chặn người chơi bằng collider và đánh mất 24 HP | Dụ lệch khỏi lối đi, chờ gậy chuẩn bị 0,85 giây rồi vòng qua; không cố đi xuyên thân hoặc đấu sát mặt |

Tiếng bị giảm qua tường/cửa và không được dùng để theo dõi người chơi ở tầng khác. Quái tới nơi **nghe/thấy cuối**, không nhận tọa độ player ẩn mỗi frame. Đám cầm gậy không tự biết chỗ nấp không chứng kiến; Kẻ Dò Tiếng có thể biết nếu nghe hơi thở/ho đủ gần. Phấn chuyển hướng điều tra của Kẻ Dò Tiếng kể cả khi nó vừa nghi một tủ.

Mặc định 6 thực thể trong pool, thường tối đa 2 hoạt động, chuông truy đuổi tối đa 3; chỉ xuất hiện ở điểm khuất cách player ít nhất 14 m và có khoảng nghỉ sau flash/phản công. Ma tuần theo vòng toàn trường qua cả A/B và ba tầng, đến điểm rồi mới chuyển chặng. Thấy thoáng xa thì điều tra chậm, nhìn rõ 1,25 giây thì đuổi; gần trong 4,5 m phản ứng ngay bước physics kế tiếp; cắt đường nhìn khiến nó trở lại tìm vị trí cuối. Sau hai đòn cận chiến liên tiếp, đòn thứ ba mở QTE **SPACE** đúng cung xanh: né → chụp tay/gậy → đấm → đạp. Thành công làm choáng nhóm ma gần 3 giây và adrenaline 8 giây, giảm 50% hao stamina khi chạy. Bấm hụt vẫn chịu đòn và không được buff. [Chi tiết tuần tra/QTE](HUNT_COMBAT.md).

## Tài nguyên và nhịp săn

- **6 ô túi**, mỗi vật chiếm một ô: đèn pin, máy ảnh, ba viên phấn ban đầu và một ô trống. 1–6/cuộn chuột chọn; chuột trái dùng; Q thả và E nhặt lại. Pin/sơ cứu/phấn được cất, không tự dùng lúc nhặt. Chìa và ký ức lưu riêng trong nhiệm vụ.
- **Pin 100**, đèn bật mất 0,675/giây, dùng được khoảng 148 giây khi đầy, gấp đôi trước. Máy ảnh cùng nguồn, mỗi ảnh mất 20 điểm phần trăm; sáng cả cảnh và mọi ma biến mất 6 giây, hồi màn trập 1,5 giây. Có 5 pin dự phòng, mỗi pin sạc +50 khi dùng, một lần. Chuyển khỏi đèn sẽ tắt đèn; hết pin thật sự tắt, ánh nền vẫn đọc được đường. [Chi tiết máy ảnh](CAMERA.md).
- **3 túi sơ cứu**, mỗi túi +30 HP khi chọn và dùng. Không tự hồi máu trong lượt; chưa cần thì giữ trong túi hoặc để lại. Hai túi trong các phòng y tế cần chìa, một ở kho.
- **3 viên phấn ban đầu**, hai điểm nhặt thêm một viên/điểm. Giữ/thả G hoặc chuột trái khi cầm phấn: tích lực 1,5 giây để xa tối đa ×5; ném bằng CharacterBody có gravity/collision; mỗi viên dùng một ô. Chỉ tiếng va chạm thật phát tín hiệu dụ quái, không đặt tiếng xuyên tường. Người ném được loại khỏi va chạm của chính viên phấn.
- **Stamina 130**, thêm 30% sức bền. Chạy tiêu 23/giây; hồi 15/giây khi không hoảng loạn, 12/giây trong chỗ nấp. HUD tính theo dung lượng 130, lượt mới hồi đủ 130.
- **Hơi thở 100**, Space khi nấp tiêu 24/giây, thả để hồi 17/giây. Hết hơi sẽ ho; phải hồi hơn 40 mới nín tiếp được. Nín không thể duy trì vô hạn.
- **Hoảng loạn 0–100** tăng khi bị áp sát/rỉ tai, giảm khi khuất và an toàn. Nó làm hồi stamina chậm và hơi thở nghe rõ hơn; giữ ở 98+ trong một lượt gây 5 HP mỗi giây. Cắt đường nhìn và giữ yên trong nơi trú giúp ổn định. Âm thở cá nhân tắt khi nín.
- Chuông báo **12 giây săn**, bán kính nghe ×1,35. Lần đầu sau 45 giây, kế tiếp mỗi 55 giây; sau phút thứ ba còn 38 giây. Lấy chìa cũng kích hoạt một đợt. Chuông không cung cấp tọa độ player cho mọi quái.

**M không dừng AI trong lượt sinh tồn.** Esc vẫn dừng game đơn. Pin, hơi thở, chuông và AI không trôi khi Esc; N không cho hồi tài nguyên giữa một lượt sống. Thắng/thua mới cho bắt đầu đêm mới, R luôn bắt đầu lại từ đầu.

47 tủ/gầm bàn tiếp tục có collider và tương tác E thật. Gầm bàn hạ capsule và camera; tủ nhìn qua khe. Đèn tắt khi vào và chỉ trở lại nếu còn pin. Lối ra bị chắn không đẩy player xuyên collider. Ma chứng kiến lúc chui vào hoặc Kẻ Dò Tiếng nghe được ở đó tới kiểm tra rồi ép player ra.

## Chỉnh trong project

- `scripts/school_entity.gd`: archetype, hình dạng và đối phó (listener/whisperer/blocker); dùng chung rig/navigation/LOS/melee với `bully_ghost.gd`.
- `scripts/world.gd`: `special_enemy_count` 0–5, đội hình/tọa độ patrol, dispatch tiếng và mode N/B/R/M.
- `scripts/player.gd`: đi nhẹ, exhaustion sprint, pin/hoảng loạn/hơi, ném phấn; `chalk_decoy.gd`: chuyển động/va chạm phấn.
- `scripts/survival_director.gd`: đồng hồ 23:30–06:00, chuyển nửa đêm, rescue hook, chuông, nguồn tiếp tế, cảnh báo, âm thở và kết quả bình minh.
- `scripts/survival_item.gd`: E, kiểm tra LOS/target, vật phẩm dùng một lần và cổng phong kín.
- `tools/build_horror_audio.py`: tổng hợp WAV trước khi chạy, không sinh âm mỗi frame.

```sh
godot --headless --path . --script tools/validate_opening.gd
godot --headless --path . --script tools/validate_survival.gd
godot --path . --script tools/validate_survival.gd --resolution 1280x720
godot --headless --path . --script tools/validate_spirit.gd
godot --headless --path . --script tools/validate_quest.gd
godot --headless --path . --script tools/validate_runtime.gd
```

Validation dùng NavAgent/CharacterBody, collider/LOS, âm nghe qua tường/tầng, pin/sơ cứu/phấn hữu hạn, nín thở/ho, quái tới kiểm tra tủ, beam-stun và club windup/damage thật. Có display thì dùng binding E thật với camera định sẵn; headless gọi cùng phương thức vì dummy display không bắt chuột. Runtime validation đối chiếu hình học/collider tĩnh với source; các node sinh tồn động được loại khỏi so sánh hình học campus.

Thu 4 vật chứng và an ủi 4 trải nghiệm của An; chìa tổng không thay được nhiệm vụ giải cứu. An chờ trên sân thượng khu A, dãy Bắc, phía Đông khối cầu thang. Toàn bộ sân thượng A là vùng an toàn: quái không lên, không nghe/đánh player ở đây và bỏ truy đuổi khi player tới nơi; hoảng loạn giảm, không gây sát thương. Thời gian và pin vẫn tiêu bình thường. M đánh dấu An, J ghi vị trí.

## Ảnh từ Godot

- [Bắt đầu đêm sinh tồn](survival-start-preview.png)
- [Ba thực thể mới](survival-entities-preview.png): bố trí cạnh nhau để so sánh hình dạng; lúc chơi chúng tuần tra ở các khu khác nhau.
- [Nín thở nhìn qua khe tủ](survival-hiding-preview.png)
- [Rọi đèn ngắt tiếng rỉ tai](survival-light-counter-preview.png)
- [Chuông nửa đêm](opening-midnight-preview.png)

Chụp lại bằng `godot --path . --script tools/capture_survival.gd --resolution 1280x720` khi có display.
