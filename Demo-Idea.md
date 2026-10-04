## Bối cảnh

Một ngôi trường từng xảy ra nhiều vụ án mạng và tự tử bí ẩn.

Người chơi là một nhóm điều tra hiện tượng siêu nhiên, tìm đến trường vào ban đêm để điều tra những sự việc xảy ra tại đây.

Trong quá trình điều tra, cả nhóm vô tình bị cuốn vào một thế giới được tạo nên từ oán niệm của các linh hồn mắc kẹt trong trường và dính phải lời nguyền.

Kể từ đó, mỗi đêm họ đều bị kéo trở lại ngôi trường. Muốn quay lại cuộc sống bình thường, cả nhóm phải giải thoát các linh hồn và phá bỏ lời nguyền.

Khi màn đêm xuống, người sống bước vào thế giới này sẽ phải trải qua những nỗi đau mà các linh hồn từng chịu đựng.

## Đêm 1: Bạo lực học đường

Người chơi bị kéo vào một thế giới phản ánh các hình thức bạo lực học đường.

### Chướng ngại

- **Bạo lực thể chất:** Ma học sinh không mặt cầm gậy, ghế hoặc các vật dụng khác truy đuổi và tấn công người chơi.
- **Chửi rủa, chế giễu:** Tiếng xì xào và lời xúc phạm gây mất máu, làm nhiễu tầm nhìn và âm thanh nếu nghe quá lâu.
- **Cô lập:** Người chơi có thể bị tách khỏi đồng đội hoặc nhốt trong phòng trong một khoảng thời gian.
- **Bẫy và phá hoại:** Ma có thể đặt bẫy, khóa cửa, làm mất điện hoặc cản đường người chơi.

### Mục tiêu

Trong lúc sinh tồn, cả đội phải tìm và giải thoát các linh hồn đang mắc kẹt trong oán niệm.

Một số khu vực cần hoàn thành nhiệm vụ phụ hoặc minigame để mở đường, ví dụ:

- Tìm chìa khóa hoặc vật phẩm.
- Sửa điện để mở khu vực mới.
- Khôi phục thiết bị hoặc giải các chướng ngại môi trường. (Các minigame như nối ống nước, ... sẽ xuất hiện ở đây)

Khi tìm thấy linh hồn, người chơi tham gia một **minigame hội thoại sử dụng AI** để tìm hiểu vấn đề của họ và giúp họ vượt qua nỗi sợ hoặc oán niệm.

Ví dụ:

> “Nếu mình nói ra, bọn họ sẽ đánh mình nặng hơn.”

Người chơi cần giúp linh hồn hiểu rằng họ không phải chịu đựng một mình và có thể tìm sự giúp đỡ từ người đáng tin cậy.

Nếu cuộc hội thoại thành công, linh hồn được giải thoát.

### Tuyến nhiệm vụ mở trong demo

- An khóc trên sân thượng; cửa sắt chặn toàn bộ lối ra mái. Nghe tiếng vọng trong cầu thang, nhìn bốn dây/đèn trên hộp chìa.
- Bốn nhánh **điện, điều khiển, nước, cờ** làm song song, có thể bỏ dở rồi quay lại. Không bắt buộc A xong mới làm B.
- Điện ở kho: phân tải hai bus. Điều khiển ở sảnh A: nối tuyến tối ưu. Bơm ở sân dịch vụ: xoay ống kín. NPC cờ ở sảnh A: caro 5×5 nối bốn quân.
- Điều khiển mở hành lang nối B; bơm mở đường vào B từ sân dịch vụ và tháo nước kho lưu trữ. Hai lối vào là lựa chọn độc lập.
- Chìa tổng nằm trong kho, đi được bằng đường ngoài phía Tây A ngay từ đầu; mở phòng A, và phòng B khi một lối B đã mở. Có thể tìm vật chứng trong lúc sửa các hệ thống.
- Hoàn thành bốn nhánh mới lấy được **chìa sân thượng** tại đầu cầu thang. Lấy chìa rồi tự mở cửa, gặp An và an ủi về bốn câu chuyện; AI chấm như trước. Nhặt vật phẩm không tự thắng.
- Tiến độ chủ yếu thể hiện qua vật thể, đèn, dây, nước, bàn cờ và cửa, không kể chuyện bằng đoạn chữ dài. Hướng dẫn minigame ngắn; nút xem kỹ thuật minh họa Dijkstra/BFS/Minimax.

Chi tiết vị trí, điều kiện và kiểm chứng: [docs/PROGRESSION.md](docs/PROGRESSION.md).

### Cắt đuôi trong demo

- Ma phát hiện thì khựng nhìn rồi lao nhanh trong một đợt ngắn; có tiếng gầm và chân chạy định hướng, sau đó tiếp tục truy đuổi và tìm quanh nơi thấy cuối nếu mất dấu.
- E nấp trong tủ dụng cụ hoặc dưới bàn, tự tắt đèn pin và đổi góc nhìn; E ra ngoài. Có tủ ngoài hành lang để dùng trước khi tìm chìa.
- Phải cắt tầm nhìn trước khi nấp. Nếu ma chứng kiến lúc vào, nó nhớ chỗ nấp, tới kiểm tra và ép player ra. Chỗ nấp không cho bất tử khi đã bị phát hiện.

### Đêm 00:00–06:00 và giải cứu linh hồn

- Một đêm 00:00–06:00 kéo dài **12 phút thực**. Muốn hoàn thành phải vừa sống tới bình minh, vừa giải cứu một linh hồn học sinh bị bắt nạt. Chìa tổng chỉ mở đường, không kết thúc đêm.
- Phần tiếp theo sẽ là tìm các mảnh linh hồn, rồi hội thoại động viên/hỗ trợ với AI đánh giá. Hiện chưa triển khai thu mảnh hoặc AI; director có hook xác nhận giải cứu cho bước đó. Nếu chưa cứu được em ấy, sống tới 06:00 vẫn báo đêm chưa hoàn thành.
- Tám học sinh cầm gậy và năm thực thể đại diện cho hành vi bạo lực: hai Kẻ Dò Tiếng (rình rập/đe dọa), hai Kẻ Rỉ Tai (tin đồn/chế giễu/gọi đám đông) và một Kẻ Chặn Lối (cưỡng ép/cô lập/chiếm đồ).
- Kẻ Dò Tiếng không dùng mắt: chạy, cửa mở, hơi thở hoảng loạn và tiếng ho có thể dẫn nó tới. Ctrl đi nhẹ, Space nín thở khi nấp, G ném phấn dụ nó sang chỗ va chạm.
- Kẻ Rỉ Tai gây hoảng loạn nếu còn đường nhìn; rọi đèn vào mặt để ngắt trong thời gian ngắn hoặc khuất sau tường. Kẻ Chặn Lối to và đánh mạnh, có windup chậm để người chơi dụ/né.
- Pin đèn, sơ cứu và phấn hữu hạn, nhặt bằng E. Hồi stamina chậm hơn khi hoảng loạn; quá hoảng loạn kéo dài gây mất sinh lực. Hết hơi khi nấp gây ho.
- Chuông trường báo một đợt săn 12 giây. Lấy chìa kích hoạt chuông; các đợt sau tới định kỳ. M xem sơ đồ không dừng nguy hiểm; Esc dừng game. B vẫn là công cụ preview ngoài lượt sinh tồn và bị khóa trong lượt để không tránh thực thể hoặc hồi máu.

### Gameplay Loop

**Sinh tồn → khám phá → mở đường / làm minigame → tìm linh hồn → hội thoại AI → giải thoát linh hồn**

Khi cứu đủ số linh hồn cần thiết, lời nguyền của đêm đó bắt đầu tan biến.

Người chơi sau đó chỉ cần cố gắng sống sót cho đến khi trời sáng để hoàn thành đêm.

### Mở đầu không lời đã triển khai

F5 mở đoạn phim khoảng 70 giây: bảng báo về mất tích/bí ẩn với ảnh, khoanh đỏ và dây nối → chỉ manh mối, đối chiếu giấy, nhìn nhau gật đầu → nhặt đồ → xe tới trường. Không có đối thoại hoặc phụ đề kể chuyện. Nhân vật dùng rig Quaternius có sẵn thay model vuông cũ.

Tường bao cao 3,6 m, trụ cổng 4,4 m, mặt tường cũ và cổng sắt đóng. Cả nhóm kiểm tra cổng chính, đi sang cửa bảo trì, dùng kìm cắt ổ khóa, mở cánh cửa rồi lần lượt đi vào bằng đường cửa. Không nhảy hay trèo tường. Cửa đóng lại sau khi vào.

Camera trở về player lúc **23:30**; có **60 giây chuẩn bị** để tới 00:00, các lần chớp đổi đồ vật giữa hai thế giới xuất hiện dần. Đúng nửa đêm có chuông ding–dong ding–dong, chuyển hẳn sang thế giới linh hồn và đồng đội biến mất. ENTER chỉ bỏ qua phim, vẫn giữ giai đoạn chuẩn bị và vị trí tới trường giống nhau. ESC dừng phim/game; B chỉ dùng trong preview ngoài lượt.

Các tham số duration nằm trong World inspector; chi tiết [docs/OPENING.md](docs/OPENING.md).


## Demo: bốn ký ức và lời an ủi tự nhập

Vật chứng ở Mỹ thuật A3, lớp 102 B1, Máy tính B2 và Y tế A1; bốn chuyện là phá đồ, cô lập, tin đồn và sợ cầu cứu. J chứa manh mối đã thu; HUD chỉ giữ biểu tượng. Đủ vật chứng gặp An trên sân thượng khu A và tự nhập lời an ủi cho từng chuyện. AI chấm thấu hiểu/công nhận/hỗ trợ an toàn. Không dùng lựa chọn cố định hoặc điểm từ khóa thay AI. Đã đổi sang `gemini-3.8-flash` qua Gemini API trực tiếp, key Google AI Studio trong `~/.config/neh-school/ai.json`; cần key Google để chấm thật. OpenCode free đã thử nhưng chặn game qua HTTP 403. Thắng khi cứu An và sống tới 06:00. Chi tiết: [SOUL_QUEST](docs/SOUL_QUEST.md).

Âm thanh: nhạc nền CC0 Lost in a bad place, tiếng bước chân/cửa/khóa/đèn pin/nhặt đồ/giấy/vật chứng/giải thoát; nhạc tăng nhẹ khi nguy hiểm và dịu khi cứu An.

## Máy ảnh phòng thân và túi đồ (2026-10-04)

- Máy ảnh có sẵn, ô 2 → chuột trái chụp. Chớp sáng toàn map, mọi thực thể biến mất 6 giây rồi quay lại; trong lúc tan chúng không đánh, nghe, rỉ tai hay chặn lối. Hồi màn trập 1,5 giây; tham số chỉnh trong Inspector.
- Mỗi ảnh mất 20 điểm phần trăm pin, dùng chung pin đèn pin. Pin dự phòng nhặt để mang theo rồi dùng sạc +50. Đổi khỏi đèn thì đèn tắt.
- Đúng 6 ô, mỗi ô một vật, không chồng: đèn pin + máy ảnh + 3 viên phấn, còn một ô. 1–6/cuộn chuột chọn, chuột trái dùng, Q thả và E nhặt lại. Sơ cứu +30 HP; pin/sơ cứu không tự dùng lúc nhặt.
- Chìa khóa tổng và 4 ký ức lưu riêng trong nhiệm vụ. Máy ảnh không chụp trong nơi nấp/giao diện/tạm dừng; khi nấp vẫn có thể dùng pin và sơ cứu.
- Model máy ảnh dùng asset Poly by Google (CC BY 3.0), giữ nguồn/credit; có SFX màn trập và hiệu ứng ánh 3D không thêm đèn realtime. Xem `docs/CAMERA.md`.

Tinh chỉnh tiếp: mỗi pin dự phòng sạc **+50 điểm phần trăm** (giới hạn 100). Phấn **giữ G hoặc chuột trái khi đang cầm → thả để ném**, đầy lực sau **1,5 giây**, tầm xa tối đa khoảng **5 lần** ném nhanh. Thanh lực chỉ hiện lúc giữ. Hủy khi đổi đồ, nấp, mở giao diện, Esc hoặc mất focus; không trừ phấn cho đến khi thực sự ném. Quỹ đạo/va chạm vẫn dùng physics, không xuyên tường khi ném mạnh.

## Chế độ test H + P và chẩn đoán AI (2026-10-04)

- Giữ H và P cùng lúc để bật/tắt TEST; không tự lặp khi giữ và không bật do gõ chữ trong hội thoại. Bật: bất tử, tốc độ đi/chạy ×3, hoàn thành chìa tổng + 4 ký ức; giữ An chờ hội thoại trên sân thượng. Đêm vẫn chạy để thử quái và các dụng cụ.
- Esc có hai nút TEST: đưa tới An với đủ vật chứng nhưng xóa tiến độ an ủi để thử AI thật; hoặc hoàn thành mọi thứ và nhảy tới 06:00. Bypass không tạo phản hồi/điểm AI giả. HUD/kết thúc có nhãn TEST; tắt cheat không hoàn tác nhiệm vụ, R xóa toàn bộ để bắt đầu lượt sạch.
- Lỗi “chưa nhận đánh giá” ban đầu do file AI chưa có key Gemini; sau khi thêm key phát hiện REST dùng sai MIME enum, đã sửa thành `APPLICATION_JSON` và chấm trực tiếp thành công qua Gemini. Bridge v3 + giao diện báo nguyên nhân cụ thể (thiếu/sai key, quyền/quota, mạng, timeout, output sai), giữ lời đang nhập và không tăng tiến độ lỗi. Key vẫn để ở `~/.config/neh-school/ai.json`.

Tinh chỉnh An: chuyển lên sân thượng khu A (nhánh Bắc), có đánh dấu trên M và chỉ đường trong J. Toàn bộ ba dãy sân thượng A là nơi trú an toàn: quái không phát hiện/nghe/đánh người ở đó, không đi theo path lên, và mất dấu khi player lên tới. Thời gian/tài nguyên vẫn chạy. H+P chỉ cấp chìa + 4 ký ức, **không tự giải cứu/ẩn An**; chỉ nút hoàn thành đêm trong Esc mới bypass giải cứu.

An đứng phía Đông lối ra cầu thang sân thượng, có ánh hồn/vòng xanh nhẹ để tìm được trong tối; B preview cũng hiện An. Hạ mái hành lang nối bằng mặt sân thượng A (bỏ gờ 15 cm), cập nhật collider/runtime/navmesh để player đi được giữa hai nửa sân thượng. Test nhanh: H+P → Esc → Đưa tới An → E. Cần chạy lại scene sau khi cập nhật map.

Tinh chỉnh tài nguyên: đèn pin tiêu 0,675%/giây, thời lượng đầy pin khoảng 148 giây (gấp đôi); stamina tối đa 130 (+30%), cập nhật cả hồi/reset và tỷ lệ HUD. Máy ảnh vẫn tốn 20%/ảnh, hộp pin sạc 50%. Gemini đã chấm thật qua bridge v4 HTTP 200; lỗi 503 quá tải thử lại tối đa ba lần trong giới hạn 80 giây, không tự đổi model hay tạo điểm giả.

## Nhịp săn và QTE phản công (2026-10-04)

Ma đi vòng tuần toàn trường A/B, sân, lối kho và ba tầng; đến điểm mới đổi đích. Thấy xa thì tới dấu cuối và tìm chậm, gần mới lao. Mất đường nhìn sau góc/tường thì không biết vị trí player mới. Đòn gậy bám ngắn rồi chốt hướng, có cửa sổ va chạm, sửa miễn nhiễm khi giữ di chuyển.

Sau **hai đòn cận chiến trúng liên tiếp**, đòn thứ ba mở vòng **SPACE · NÉ**: bấm đúng cung xanh mới né, chụp tay/gậy, đấm và đạp ma ra. Bấm sai/hết giờ vẫn mất máu và không có buff. Thành công: nhóm ma gần choáng **3 giây**, tim đập/adrenaline **8 giây**, stamina chạy tiêu chậm **50%**. Tay/chân tận dụng nhân vật Quaternius CC0, có chuyển động camera, bụi hồn và SFX va chạm; không thêm HUD dài dòng. Xem [docs/HUNT_COMBAT.md](docs/HUNT_COMBAT.md).

Giảm mật độ: pool 6 thực thể (3 học sinh + mỗi loại đặc biệt 1), bình thường tối đa 2 đang hoạt động, chuông truy đuổi tối đa 3. Spawn theo nhịp 22 giây tại điểm khuất, cách player 14–38 m, đúng tầng và có nav/collider an toàn; chưa có chỗ thì chờ. Quái xa tái dùng kín đáo, không biến mất khi bị nhìn. Flash/phản công không gọi thêm ma bù ngay. Thấy rõ liên tục 1,25 giây thì xác nhận và dí; player sát trong 4,5 m thì nhận ra ngay bước physics kế tiếp, không đợi tick quan sát. Kẻ Dò Tiếng phát hiện tiếp xúc rất gần, Kẻ Rỉ Tai thôi đứng tụng khi áp sát.
