# Tuần tra, mất dấu và QTE phản công

Ma đi tuần liên tục theo vòng 24 điểm qua sân, hành lang A, hành lang nối, khu B, lối tới kho và ba tầng. Hai hướng tuần được chia cho các nhóm; mỗi ma chọn điểm gần vị trí xuất hiện. Đến điểm mới đổi đích, không đổi theo đồng hồ. Bị chắn đứng yên tám giây thì bỏ điểm đó để tiếp tục vòng. Các điểm nằm trên lối lưu thông, tránh canh bên trong phòng chỉ có một cửa. Sân thượng A vẫn là nơi an toàn của An.

Thoáng thấy người ở xa: dừng nhìn 0,4 giây rồi đi điều tra chỗ thấy cuối, khoảng 2 m/s. Nhìn rõ liên tục 1,25 giây thì xác nhận và lao đuổi; **gần trong 4,5 m phát hiện ngay bước physics kế tiếp**, không chờ bộ đếm quan sát hoặc bước nghi ngờ. Trong tầm đánh thì chuẩn bị vung luôn. Đang đuổi mà mất đường nhìn qua góc/tường thì ngừng lao, chuyển về tìm chậm; tới dấu cuối rồi kiểm tra quanh đó. Ma không nhận tọa độ mới sau tường hoặc khi player nấp. Tiếng chân/cửa vẫn có thể khiến chúng điều tra một dấu mới. Kẻ Dò Tiếng dùng dấu nghe thay mắt ở xa nhưng nhận ra người im lặng trong 2,2 m qua tiếp xúc/hơi thở; Kẻ Rỉ Tai không đứng tụng khi player áp sát.

## Nhịp xuất hiện thưa hơn

Mặc định **6 actor**: 3 học sinh cầm gậy, 1 Kẻ Dò Tiếng, 1 Kẻ Rỉ Tai, 1 Kẻ Chặn Lối. Chỉ một thực thể xa lúc nửa đêm, sau 12 giây mới có thể thêm. Bình thường **tối đa 2 hoạt động**, chuông truy đuổi tối đa **3**; không có 13 ma tuần đồng thời. Luân phiên học sinh và quái đặc biệt. Actor nghỉ ẩn và tắt collider/animation/cảm giác, tái dùng để tránh chi phí tạo mới liên tục.

Mỗi lần thêm cách 22 giây, chỉ chọn điểm trên lối lưu thông, cùng tầng, có nav path, không vướng collider, cách player **14–38 m**, ngoài góc nhìn hoặc bị tường che; cách ma khác ít nhất 7 m. Không có góc an toàn thì đợi, không buộc xuất hiện. Giới hạn thêm khi đã có hai thực thể trong 20 m. Ma ở tầng xa/đã đi quá xa được đưa về pool khi không bị nhìn thấy; ma đang trong tầm nhìn không tự biến mất. Ma đang nấp, trên sân thượng hoặc trong QTE không gọi thêm encounter.

Máy ảnh dành tối thiểu 8 giây không sinh ma thay thế; QTE thành công cũng dành 8 giây để chạy. Ma bị flash vẫn giữ chỗ trong giới hạn và chỉ chính các actor đó trở lại. Không bật các actor đang nghỉ sau flash. `World` inspector có `Smart Spawn Enabled`, `Max Active Ghosts` (3), `Encounter Interval Seconds` (22), `Enemy Count` (3) và `Special Enemy Count` (3).

Đòn đánh bám một đoạn ngắn trong lúc chuẩn bị, sau đó chốt hướng và có cửa sổ va chạm 0,28 giây. Đi bộ liên tục không còn miễn nhiễm; chạy ra ngoài tầm, tránh hướng vung hoặc cắt qua tường vẫn né được. Gậy dùng rig/clip Punch hiện có cùng tư thế vung bổ sung.

## Cách phản công

1. Bị **hai đòn cận chiến trúng thật**, không quá 7 giây giữa các đòn. Đòn bị chặn bởi thời gian miễn sát thương/cheat hoặc sát thương hoảng loạn không tính.
2. Khi **đòn thứ ba** tới, vòng QTE hiện **SPACE · NÉ**. Nhấn mới khi chấm chạy vào cung xanh; giữ SPACE từ trước không tính. QTE dài 0,9 giây, vùng đúng từ 0,18 đến 0,73 giây. Esc dừng thời gian QTE.
3. Đúng nhịp: tránh sát thương đòn thứ ba, nghiêng né, chụp tay/gậy, đấm mặt rồi đạp ma văng ra. Có tay/chân góc nhìn thứ nhất, phản ứng trúng đòn, bụi linh hồn và ba tiếng va chạm. Chuỗi diễn ra 1,15 giây; không dùng đồ hoặc nấp giữa chuỗi.
4. Cú đạp làm choáng ma đánh và các ma trong 4,5 m, **3 giây**. Không xuyên tường/tầng, không tác động cả map. Knockback chạy bằng CharacterBody nên không đẩy xuyên collider. Ma choáng ngừng đánh/nghe/rỉ tai rồi tiếp tục tuần tra.
5. Sau cú đạp có **8 giây adrenaline**: tim đập nhanh, mép màn hình ấm nhẹ, FOV mở nhẹ và biểu tượng nhịp tim đếm giây. Chạy mất **11,5 stamina/giây** thay vì 23 (giảm 50%). Không hồi máu hoặc tự nạp stamina.

Bấm sớm/muộn hoặc không bấm: nhận một đòn thứ ba, không phản công và không có buff; phải chịu hai đòn mới để có cơ hội tiếp. Ba đòn đều có thể từ các ma khác nhau. Không QTE khi đang nấp, bất tử TEST, đã chết hoặc ở sân thượng. Việc ma biến mất giữa chuỗi hủy phản công; đổi thế giới, chết, kết thúc đêm và chơi lại xóa trạng thái chiến đấu.

## Chỉnh và kiểm tra

- `scripts/player_combat.gd`: nhịp QTE, khoảng nối hai đòn, thời gian chuỗi và adrenaline. `scripts/bully_ghost.gd`: khoảng đuổi gần, tốc độ tìm, windup, tầm đánh và stun. `scripts/world.gd::campus_patrol_route`: vòng tuần tra.
- Tay/chân lấy từ mesh Quaternius Casual Male CC0 đang dùng cho nhóm điều tra; chỉ tách và cache một lần, không tải thêm rig cho mỗi cú phản công. `tools/build_horror_audio.py` sinh ba SFX gốc: `counter_grab`, `counter_punch`, `counter_kick`.
- `tools/validate_hunt_combat.gd`: kiểm tra nav mọi chặng, capsule đang đi bị đánh, mất dấu, QTE đúng/hụt/tạm dừng, từng loại ma, phạm vi choáng, knockback và reset. Kết quả ở `hunt-combat-validation.json`.
- `tools/capture_hunt_combat.gd`: bàn phím thật trên màn hình ảo, so hao stamina thường/adrenaline và chụp [QTE](qte-dodge-preview.png), [chụp tay](counter-grab-preview.png), [đấm](counter-punch-preview.png), [đạp](counter-kick-preview.png), [bỏ chạy](adrenaline-escape-preview.png).
- `tools/validate_encounters.gd` kiểm tra roster mặc định, góc spawn, mật độ, floor, nhịp nghỉ, flash, spawn trên lầu và phát hiện sát mặt. Các regression QTE/camera dùng fixture 13 actor bật đồng thời để kiểm tra đủ mọi archetype; đó không phải cấu hình chơi mặc định.
