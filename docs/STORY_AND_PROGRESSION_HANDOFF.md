# NEH School — Tài Liệu Hiện Trạng Cốt Truyện, Diễn Biến & Handoff Thiết Kế Đêm 1+

> **Mục đích tài liệu:** Ghi nhận **chính xác 100% cốt truyện, thế giới, nhân vật và diễn biến gameplay đang thực sự chạy trong code/dữ liệu hiện tại** của dự án *NEH School — Những người chưa trở về*, đồng thời đóng gói bài toán **handoff thiết kế cho giai đoạn bước vào Trường ở Đêm 1** (hiện đang trống mục tiêu và đứt nhịp) cùng các đêm tiếp theo.
>
> **Lưu ý quan trọng khi đọc đối chiếu:** Một số tài liệu thiết kế cũ trong repo (`Demo-Idea.md`, `README.md`, `docs/PROGRESSION.md`, `docs/SOUL_QUEST.md`) mô tả cấu trúc cũ (gộp tất cả vào 1 đêm duy nhất, phòng 205 thay vì 306, 4 mảnh ký ức thay vì 3...). Tài liệu này **chỉ lấy sự thật từ source code và data JSON/JS đang chạy** tại nhánh hiện tại (`f97b4fe`).

---

## 1. Tổng Quan Dự Án & Kiến Trúc 3 Lớp Trải Nghiệm

- **Tên dự án:** *NEH School — Những người chưa trở về* (Đồ án Khóa luận Tốt nghiệp — Godot 4.7 3D góc nhìn thứ nhất kết hợp ARG đa nền tảng).
- **Trục ý tưởng lớn (Macro Premise):** Ngôi trường THPT NEH bỏ hoang từ cuối năm 2009 bị trói buộc bởi lời nguyền của **7 Con Quỷ Đại Tội** (*Ghen Tị, Lười Biếng, Phẫn Nộ, Tham Ăn, Tham Lam, Si Mê, Kiêu Ngạo*), mỗi con quỷ giam giữ linh hồn một nạn nhân chưa thể siêu thoát. Ban ngày người chơi sống ở khu phố xung quanh để điều tra quá khứ nạn nhân và chuẩn bị trang bị; ban đêm bước vào trường ở Cõi Âm để đối phó con quỷ trực đêm, giải thoát linh hồn và sống sót thoát ra.
- **Phạm vi mục tiêu của KLTN:** Hoàn thiện trọn vẹn **2–3 đêm** (Đêm 0 mở màn + Đêm 1 chơi đơn đối đầu *Quỷ Ghen Tị* + từ Đêm 2 định hướng mở rộng Co-op 2 người chơi ở hai thực tại song song, dùng điện thoại soi thấy thế giới của nhau).

### Ba lớp không gian của trò chơi

| Lớp | Thành phần kỹ thuật | Vai trò trong trải nghiệm |
| :--- | :--- | :--- |
| **1. Thế giới 3D trong Game** | Godot 4.7 (`scenes/home.tscn`, `scenes/town.tscn`, `scenes/school_runtime.tscn`, `endless_corridor.gd`) | Căn nhà thuê Số 14 Hẻm 31, khu phố Bến Trầu – Đồng Muối rộng `540 × 300 m` có xe máy/cờ vua/cửa tiệm, khuôn viên Trường THPT NEH 40 phòng (Khu A + Khu B + Nhà kho) và Hành lang đỏ Cõi Âm. |
| **2. Máy tính thật & Mạng Web Giả lập** | Electron Hub (`hub/`): Trình duyệt **Cú Đêm** + Local Server + WebSocket cầu nối `arg_bridge.gd` | Thả shortcut **Gaaglu** và file `Ghi chú.txt` ra màn hình Desktop thật (sau khi xin phép). Cung cấp máy tìm kiếm `gaaglu.com` (trộn kết quả ARG với kết quả DuckDuckGo thật; chặn từ khóa tự hại kèm tổng đài 111/115), 3 tờ báo địa phương, mạng xã hội `langta.vn`, web trường `thptneh.edu.vn` đóng băng từ 11/2009, và cổng dân cư `dancu.hailam.gov.vn`. |
| **3. Điện thoại thật ("Ống kính")** | WebXR / Gyroscope qua Wi-Fi nội bộ (`gaaglu.com/thiet-bi` ↔ `scripts/phone_lens.gd`) | Quét mã QR trên điện thoại thật rồi giơ lên soi vào màn hình PC để nhìn xuyên sang lớp render `OTHER_WORLD` (Thế giới bên kia) chồng khít lên góc nhìn trong game, làm lộ ra vật thể cõi âm và bóng ma học sinh (`LensStalker`) đứng lặng lẽ cách sau lưng người chơi `3.4 m`. |

---

## 2. Bối Cảnh Thế Giới, Tuyến Thời Gian & Hồ Sơ Nhân Vật

### 2.1. Địa lý Phường Cổ Đằng, Tỉnh Hải Lâm
Khu vực bị chia đôi bởi **Sông Trầu** theo trục Bắc – Nam, nối với nhau qua **Cầu Mây**:
- **Bờ Tây — Khu phố Bến Trầu (đông đúc, đời thường):** Gồm trục Đường Bờ Tây, Phố Chợ, Đường Bến Trầu và các con hẻm. Nơi đặt nhà thuê của nhân vật chính (**Số 14, Hẻm 31**), Tạp hóa Bà Sáu (**Hẻm 27**), Bưu cục Cổ Đằng, Chợ Bến Trầu, Quán Phở Tâm Trạng, Cà Phê Bến Sông & Góc Cờ, cùng một tiệm đồ cổ không biển hiệu treo đèn lồng đỏ nằm sâu trong **Hẻm 5** (*Tiệm Không Tên*).
- **Bờ Đông — Khu Đồng Muối (hoang vắng, nhiễm mặn):** Qua khỏi Cầu Mây chỉ còn quán trà đá nhỏ của Bác Lực ở đầu cầu, những ruộng muối bỏ hoang trắng xóa và con đường độc đạo dẫn thẳng tới cổng **Trường THPT NEH** ở rìa Đông (`x = 262, z = 26`).

### 2.2. Tuyến thời gian bi kịch (Ghép từ dữ liệu Web ARG + Môi trường 3D)

| Mốc thời gian | Sự kiện đã xảy ra trong Lore hiện tại | Nguồn dữ liệu trong code |
| :--- | :--- | :--- |
| **14/03/1993** | **Nguyễn Bình An** chào đời, sống cùng cha (Nguyễn Văn Bình) và mẹ (Trần Thị Mận) tại **Số 14, Hẻm 31, Khu phố Bến Trầu**. | `hub/web/registry.js` |
| **2003** | Cha của An qua đời. Hai mẹ con sống nương tựa vào nhau tại căn nhà Số 14 Hẻm 31. | `hub/web/registry.js` |
| **2006 – 2008** | Trên khung cửa phòng ngủ tầng 2 nhà Số 14 Hẻm 31, mẹ hoặc An lấy bút chì đo chiều cao chữ `"A"` đều đặn mỗi năm: `2006`, `2007`, `2008` — **không có vạch năm 2009**. | `scripts/home/home_world.gd` |
| **20/11/2008** | Mới học lớp 10 (`10A6`), An toàn thắng cả **7 ván** tại Giải Cờ vua Học sinh Trường NEH, đánh bại toàn bộ đàn anh khối 12. Khi nhận giải, An nói một câu thẳng thắn: *"Trên bàn cờ, ai cũng phải đi đúng luật."* Những kẻ thua cuộc tự ái bỏ về trước lễ trao giải và bắt đầu ôm mối căm ghét vì thấy mình mất nhiều hơn một ván cờ. | `hub/web/school.js`, `scripts/chess/chess_people.gd` |
| **28/03/2009** | An tiếp tục đạt **Giải Nhất Học sinh giỏi Tỉnh môn Toán**. Cố vấn CLB Cờ vua là **Thầy Khải** biết đám học sinh thua cuộc ghét và trù dập An nhưng đã chọn im lặng không can thiệp. | `hub/web/school.js`, `scripts/chess/chess_people.gd` |
| **07/09/2009** | Đầu năm học mới, mẹ An (bà Mận) gửi đơn phản ánh lần 1 lên trường về việc An bị cô lập và bắt nạt. | `hub/web/registry.js` |
| **19/10/2009** | Bà Mận gửi đơn phản ánh lần 2; Ban giám hiệu Trường NEH gạt đi, kết luận chỉ là *"mâu thuẫn bạn bè thông thường"*. | `hub/web/registry.js` |
| **03/11/2009** | Bà Mận gửi đơn kêu cứu lần 3 kèm theo **một trang vở viết tay** của An (hiện trên hồ sơ điện tử trang vở này đã bị đục bỏ theo yêu cầu gia đình). Trong sổ tay, An viết nghuệch ngoạc những dòng tuyệt vọng: *"đừng bỏ tôi"*, *"về nhà"*, *"ai ở ngoài cửa?"*. | `hub/web/registry.js`, `scripts/an_notebook_page.gd` |
| **22/11/2009** | **Bi kịch xảy ra:** Hồ sơ công dân của Nguyễn Bình An bị đóng vĩnh viễn ở tuổi 16 (lý do bị ẩn dưới mã công văn `118/CV`). Tên của An trên Bảng vàng website trường bị xóa trắng thành `[đã gỡ theo yêu cầu]`. Trên sổ lưu bút website trường xuất hiện một dòng không ngày tháng từ lớp `10A6`: **"tên em đâu rồi"**. | `hub/web/registry.js`, `hub/web/school.js` |
| **23/11/2009 – Cuối 2009** | Trường NEH ra thông báo tạm dừng mọi CLB từ 23/11/2009 để "kiểm kê tài sản", rồi đóng cửa bỏ hoang hoàn toàn vào cuối năm 2009. | `hub/web/school.js`, `data/social_posts.json` |
| **01/2010** | Bà Trần Thị Mận rời khỏi căn nhà Số 14 Hẻm 31 chuyển đi nơi khác, bỏ lại chai nước mắm hết hạn năm 2009, vạch đo chiều cao dừng ở 2008, hình vẽ quân cờ góc gương nhà tắm và **một quân Hậu trắng sứt mẻ kẹt ở khe đầu giường**. | `hub/web/registry.js`, `scripts/home/home_world.gd` |
| **Hiện tại (~2026, 17 năm sau)** | Một lá thư gửi "lớp 10A6 Trường NEH" bị kẹt sau tủ phân loại Bưu cục Cổ Đằng suốt 17 năm vừa được tìm thấy. Con sáo của Bà Sáu ở Hẻm 27 cứ nhại đi nhại lại câu *"Tên em đâu rồi?"*. **Peter Adam** dọn tới thuê chính căn nhà Số 14 Hẻm 31 giá rẻ để cùng nhóm bạn đột nhập điều tra Trường NEH. | `hub/web/news-data.js`, `scripts/town/town_life.gd`, `scripts/home/home_story.gd` |

### 2.3. Hồ sơ Nhân vật & Thực thể

1. **Peter Adam (Nhân vật người chơi điều khiển):**
   - Nhà điều tra hiện tượng siêu nhiên tự do (profile trình duyệt `peter@gaaglu.com`). Vừa thuê căn nhà **Số 14 Hẻm 31** vì giá rẻ và gần Trường NEH mà **không hề biết mình đang ngủ ngay trên chiếc giường cũ của Nguyễn Bình An**.
2. **Nguyễn Bình An (Linh hồn Đêm 1 — Nạn nhân của Quỷ Ghen Tị):**
   - Nữ sinh lớp `10A6`, mã định danh `097193004217`. Tài năng cờ vua và Toán học của cô trở thành cái gai trong mắt những kẻ đố kỵ. Bị cô lập, hành hung bằng gậy, nhốt trong nỗi sợ hãi và cuối cùng ngay cả cái tên trên Bảng vàng cũng bị xóa mất.
   - Hiện linh hồn An đang đứng co ro trên **Sân thượng Khu A** trong Cõi Âm; ban ngày, bóng hồn cô âm thầm đi theo Peter tới bàn cờ của Thầy Khải (nhắc nước đi *"…đi đúng luật…"*). Trong code trình duyệt (`hub/profiles.js`), An còn có sẵn một profile ẩn mang giao diện bị ám màu tím (`binhan@gaaglu.com`).
3. **Lan (Người dẫn đường bí ẩn ở Cõi Âm):**
   - Xuất hiện cứu Peter ở cuối Hành lang đỏ Đêm 0. Hiểu rất rõ cấu trúc Cõi Âm, cổng dịch chuyển dưới gầm bàn, quy luật 7 Con Quỷ Đại Tội và tên của linh hồn đầu tiên (Nguyễn Bình An), nhưng **không biết chuyện đời tư của An** và từ chối tiết lộ thân phận thật của mình (*"Biết tên là đủ rồi"*). Trao đổi số điện thoại với Peter qua ứng dụng **Nối** và cảnh báo tuyệt đối không trả lời tin nhắn của bất kỳ ai khác.
4. **Minh ("Minh Đo Sóng") & Khoa ("Khoa Khoa Học"):**
   - Hai thành viên cùng nhóm điều tra với Peter. Minh là người tổng hợp thông tin đồn đại trên mạng; Khoa phụ trách máy đo từ trường/nhiệt độ và thích đánh cờ chớp ở quán Cà Phê Bến Sông. Cả hai cùng đi vào trường với Peter ở đầu Đêm 0.
5. **Người lạ ẩn danh (`" "` trên ứng dụng Nối):**
   - Ngay sau khi Lan dặn *"Đừng trả lời tin nhắn nào không phải của tôi"* lúc 01:06 sáng, tài khoản không tên `" "` gửi liên tiếp 3 tin nhắn ký tự nhiễu loạn (`GARBLED`) vào máy Peter.
6. **Dàn NPC Khu phố Bến Trầu – Đồng Muối:**
   - **Bà Sáu (Tạp hóa Hẻm 27 & Chủ nhà trọ):** Người cho Peter thuê nhà Số 14 Hẻm 31; lảng tránh khi bị hỏi sao nhà rẻ, chỉ đường cho Peter tìm tiệm đồ lạ có đèn lồng đỏ ở Hẻm 5. Nuôi một con sáo biết nói câu *"Tên em đâu rồi?"*.
   - **Thầy Khải (Đối thủ khó nhất ở Góc Cờ):** Cựu giáo viên cố vấn CLB Cờ vua Trường NEH năm 2009. Mang nỗi dằn vặt suốt 17 năm vì đã làm ngơ khi thấy học sinh cũ trù dập An.
   - **Ông chủ Tiệm Không Tên (Hẻm 5):** Ông lão bán vật phẩm khắc chế quỷ (Đèn pin, Súng muối, Huy chương mạ, Phấn...) và thu hồi lại những món đồ bị Quỷ Ghen Tị cướp mất trong trường để người chơi chuộc lại với giá 50%.
   - **Cô Hoa** (Bưu cục Cổ Đằng), **Bác Lực** (quán trà đá bên kia Cầu Mây — nhớ mãi bóng dáng đứa nhỏ ngày xưa ngày nào cũng ôm bàn cờ đi bộ qua cầu), **Anh Phúc** (Phở Tâm Trạng), **Chị Mai** (bán chuối & vé số ở chợ), **Tí Sún** (cậu nhóc đánh cờ hay chỉ trỏ đánh lạc hướng để ăn gian quân).
7. **Quỷ Ghen Tị — Envy Demon (Trùm Đêm 1):**
   - Hình dáng cao gầy, đen kịt, trên cổ đeo lủng lẳng những tấm huy chương cướp được.
   - **Quy luật săn mồi (`envy_director.gd` + `envy_demon.gd`):** Nó săn kẻ "có nhiều hơn nó". Người chơi càng giữ nhiều vật phẩm trong túi (hoặc cầm theo **Huy chương mạ**), bán kính rỉ tai khoanh vùng của nó càng siết chặt (từ `18 m` thu hẹp xuống tới `5 m`). Khi tóm được người chơi: nếu có **Súng muối** sẽ bắn mù mắt nó để thoát; nếu không có súng muối, nó sẽ **cướp Huy chương mạ hoặc Máy ảnh** rồi đứng say sưa ngắm chiến lợi phẩm suốt `4 giây` và tha mạng; nếu tay trắng không có gì đáng giá để cướp, nó giết ngay lập tức.

---

## 3. Diễn Biến Cốt Truyện & Gameplay Hiện Tại (6 Chương Theo Đúng Code)

Tiến trình game được quản lý qua 6 chương trong `scripts/game_progress.gd` (lưu tại `user://progress.cfg`):

### Chương 0: `prologue` — Tiền truyện · Căn nhà số 14, Hẻm 31
- **Thời gian & Bối cảnh:** Thứ Sáu, `19:40` tối tại `scenes/home.tscn`.
- **Diễn biến:**
  1. Peter đứng trong phòng khách căn nhà mới thuê. Người chơi có thể đi quanh nhà tương tác các vật dụng để đọc suy nghĩ nội tâm của Peter (5 manh mối ngầm về An đã cấy sẵn trong nhà: chai nước mắm hết hạn 2009, nước vòi rỉ đỏ mùi sắt, ký hiệu quân cờ góc gương phòng tắm, vạch đo chiều cao `"A": 2006–2008` trên khung cửa phòng ngủ, và quân Hậu trắng sứt mẻ kẹt ở khe đầu giường).
  2. Mở điện thoại (`Tab`) vào ứng dụng **Nối**: đọc tin nhắn dặn dò của Bà Sáu, sau đó chuyển sang tab **Làng Ta** lướt hết 8 bài đăng mạng xã hội địa phương. Các bài đăng này gieo trước toàn bộ điềm báo cho Đêm 0 (cửa sổ tầng 3 sáng đèn vàng, tiếng gõ bên trong Phòng 102 và cây gậy dính máu, tiếng chuông trường lúc 00:00 dù đã cắt điện từ 2010, nhiệt độ Phòng 306 tụt xuống `-7°C`, dòng tên bị xóa trên Bảng vàng 2009, và bài đăng thứ 8 phá bức tường thứ tư: *"bạn đang đọc cái này ở đâu vậy"*).
  3. Lướt tới đáy feed sẽ kích hoạt tin nhắn nhóm **"Nhóm điều tra"** (Minh, Khoa). Người chơi chọn 1 trong 2 câu trả lời để chốt kế hoạch đột nhập trường lúc `22:30` tối nay. Khoa nhắn câu cuối: *"Đừng vô một mình."*
  4. Người chơi mở cửa chính bước ra ngoài → chuyển sang cảnh trường học.

### Chương 1: `night0` — Đêm 0 · Ngôi trường
- **Thời gian & Bối cảnh:** Thứ Sáu, `22:30` đêm tại `scenes/school_runtime.tscn`.
- **Diễn biến tuyến tính (dẫn đường hoàn toàn bằng ánh sáng & âm thanh, HUD ẩn sạch dòng nhắc mục tiêu):**
  1. **Phim cắt cảnh mở đầu (`opening_cinematic.gd`, 34 giây, không thoại):** Xe van đỗ ngoài rào phụ, 4 nhân vật bước xuống cắt khóa đột nhập vào sân trường trong sương mù, rồi trả quyền điều khiển cho Peter ở sân trước Khu A. *(Lưu ý lỗi nhân sự trong code được nêu rõ ở Mục 5.2).*
  2. **Mồi nhử Phòng A-103 (`ROOM_LURE`):** Toàn bộ 4 cầu thang lên tầng trên đều bị khóa bằng cổng sắt xếp (`progression_gate.gd`). Giữa ngôi trường tối đen chỉ có cửa sổ Phòng A-103 hắt ánh đèn vàng ấm. Bên trong phòng trống trơn, đặt độc nhất con **Gấu bông** (Mảnh ký ức #1: `isolation` — *Bị cô lập*). Vừa nhặt gấu bông, bóng đèn nổ phụt tắt.
  3. **Vệt máu dẫn sang Phòng A-102 & Cú hù xoay lưng (`BLOOD_TRAIL` → `CLUB_SCARE`):** Vệt máu loang từ chỗ con gấu kéo dài ra hành lang dẫn thẳng sang Phòng A-102 kèm tiếng gõ nhịp bên trong. Khi nhặt **Cây gậy dính máu** (Mảnh ký ức #2: `fear` — *Nỗi sợ bị hành hung*), mọi âm thanh im bặt `1.5s`, tiếng ghế gỗ kéo sát phía sau lưng vang lên. Game đợi người chơi tự quay chuột lại (hoặc rỉ tai thúc ép mỗi `6s`) rồi tung bóng ma lao thẳng vào mặt (`2.6s` màn hình đỏ + tiếng tim đập). Ngay sau đó, tiếng hát ru ma mị vang lên từ tầng trên, bóng một nữ sinh thấp thoáng ở chiếu nghỉ cầu thang và cửa sổ tầng 3, đồng thời chốt sắt cầu thang mở khóa đánh *"cạch"*.
  4. **Theo tiếng hát ru lên Phòng A-306 & Bị vây cửa (`ASCEND` → `DOOR_SIEGE`):** Tiếng hát ru lớn dần từ tầng 1 lên tầng 3 (`-24 dB` → `-8 dB`). Ở cuối hành lang Cánh Tây tầng 3, bóng nữ sinh đứng đợi; vừa thấy tia nhìn của Peter chạm tới, bóng ma vụt chạy vào **Phòng A-306** đóng sầm cửa. Peter mở cửa bước vào nhặt **Cuốn sổ tay của An** (Mảnh ký ức #3: `notebook` — *Tiếng kêu cứu cuối cùng*, vẽ các dòng chữ *"đừng bỏ tôi"*, *"về nhà"*, *"ai ở ngoài cửa?"* và ký hiệu con mắt khóc bằng máu). Vừa gấp sổ lại, cửa phòng tự đóng sập chốt khóa, tiếng đập cửa điên cuồng dồn dập suốt `9 giây` kèm tiếng khóc tiến sát và điện toàn trường chập chờn rồi tắt phụt — cánh cửa bật tung!
  5. **4 Chặng chạy trốn sinh tử (`ESCAPE_RUN`, `school_escape.gd`, có DDA tự cân bằng khoảng cách `gap`):**
     - *Chặng 1 (Hành lang tầng 3):* Nhân vật tự lao chạy về phía cầu thang giữa; người chơi lách trái/phải (`A/D`), nhảy (`Space`) qua bàn học trượt ngang và trượt gầm (`Ctrl`) dưới xà đổ.
     - *Chặng 2 (Lao xuống cầu thang giữa):* Bấm `Space` đúng nhịp tim đập thình thịch để giữ đà lao xuống 3 tầng lầu không bị khựng.
     - *Chặng 3 (Vượt sân trường trong bóng tối):* Chạy xuyên sân hướng về các cột đèn đường lần lượt nổ bóng, đồng thời nhấn giữ chuột phải (`RMB`) lia đèn pin ngược ra sau lưng để hãm tốc bóng ma đang rượt sát gót.
     - *Chặng 4 (Phá phong ấn Cổng chính):* Cổng sắt bị quấn xích đỏ với ký hiệu con mắt khóc; người chơi giữ chuột trái (`LMB`) vẽ phấn theo nét bùa (`seal_trace.gd`) trước khi bóng ma chạm tới lưng.
  6. **Nhiễu sóng tại Cổng chính (`GATE_INTERFERENCE`):** Phong ấn vỡ nhưng cánh cổng vẫn không mở. Màn hình nhiễu trắng/đỏ chớp giật `2.6 giây` giữa hai thực tại — Peter bị kéo tụt một mình vào **Cõi Âm**, đồng đội biến mất.

### Chương 2: `corridor` — Đêm 0 · Hành lang đỏ
- **Diễn biến:**
  1. **Cuộc rượt đuổi 900m (`endless_corridor.gd`):** Mê cung hành lang ngập ánh đèn đỏ dài `900 m` gồm 11 khúc cua chữ T có nhánh cụt đánh lừa (nhánh sống được gợi ý ngầm bằng vệt chân máu và mảnh vải rách). 5 bóng ma dị dạng rượt phía sau trên nền nhạc 150 BPM hai lớp. Giữa đường sàn gỗ sập xuống **2 lần** (ở mốc `384 m` và `636 m`), đẩy Peter trượt xuống máng hầm tối (`corridor_chute.gd`): phải nghiêng đầu né những cánh tay thò ra từ vách hầm và lắc mạnh chuột để hất lũ nhện bò kín mặt (`corridor_spiders.gd`), trong khi những dòng chữ hù dọa chớp lên (*"ĐỪNG NHÌN LẠI"*, *"TÊN EM ĐÂU RỒI"*).
  2. **Được Lan giải cứu (`LAN_DIALOGUE`):** Sau khi trụ được tối thiểu `75 giây` và vượt qua mốc `730 m`, **Lan** mở cửa một căn phòng trú ẩn gọi Peter chạy vào rồi sập cửa chặn lũ ma bên ngoài. Hội thoại Visual Novel diễn ra với 4 câu hỏi bắt buộc (*Đây là đâu? / Lời nguyền là gì? / Những linh hồn ở đây là ai? / Làm sao thoát khỏi đây?*) và 1 câu hỏi phụ (*Còn cô là ai?*). Lan giải thích về thế giới song song của ngôi trường và chỉ cho Peter cách thoát duy nhất: **bò xuống dưới gầm chiếc bàn gỗ trong phòng** (`TABLE_ESCAPE` → `UNDER_TABLE`).
  3. **Điểm cắt cảnh thực tế hiện tại (`LAN_FAREWELL`):** Peter chui qua gầm bàn và trồi lên dưới gầm bàn **Phòng A-103** của ngôi trường. Khác với bản ý tưởng cũ (vốn định bắt người chơi đi tìm An ngay trong Đêm 0), code hiện tại (`school_progression.gd:484-508`) đặt **Lan đứng đợi sẵn ngay cạnh bàn**, bảo *"Mới một giờ đêm thôi"*, tự lưu số của cô vào điện thoại Peter, dặn *"Đừng trả lời tin nhắn nào không phải của tôi. Về đi. Ngày mai còn dài."* rồi chuyển cảnh thẳng về nhà!

### Chương 3: `home` — Về nhà · 1 giờ sáng
- **Thời gian & Bối cảnh:** Thứ Bảy, `01:06` sáng tại `scenes/home.tscn`.
- **Diễn biến:**
  1. Lần đầu về nhà sẽ hiện hộp thoại xin phép người chơi bật hiệu ứng ARG ngoài màn hình Desktop máy tính thật.
  2. Khi Peter bước lên cầu thang tầng 2 (`y > 2.4`), điện thoại đổ chuông tin nhắn **Nối** từ **Lan**:
     - Lan tiết lộ lời nguyền gồm **7 con quỷ ứng với 7 đại tội**, mỗi con giam một linh hồn.
     - Cảnh báo con tiếp theo là **Ghen Tị**: *"Cao, đen, đeo đầy huy chương cướp được. Nó săn người có nhiều nhất."*
     - Cho biết tên linh hồn đầu tiên cần giải thoát là **Nguyễn Bình An**, dặn: *"Ban ngày đi tìm hiểu chuyện gì đã xảy ra với em ấy. Hiểu đủ thì mới giải thoát được... Ngủ đi đã. Sáng tôi nhắn."* rồi offline.
  3. Đúng `5 giây` sau, người gửi không tên `" "` bắn vào máy 3 tin nhắn nhiễu loạn không đọc được chữ.
  4. Cùng lúc đó, trình duyệt **Gaaglu / Cú Đêm** tự cài đặt ra Desktop thật (hoặc báo trên màn hình PC trong phòng ngủ của Peter kèm tờ `Ghi chú.txt`: *"Chỉ khi kết nối với thế giới bên kia, mới có thể tìm thấy sự thật."*).
  5. Khi người chơi mở Gaaglu (hoặc đọc ghi chú trên PC trong phòng), giường ngủ mở khóa tương tác → `"Ngủ tới 07:00 · Ngày 1"` → chuyển sang Khu phố.

### Chương 4: `town` — Ngày 1 · Khu phố Bến Trầu – Đồng Muối
- **Thời gian & Bối cảnh:** Thứ Bảy, `07:00 – 22:00` tại `scenes/town.tscn`.
- **Nhịp thời gian & Mục tiêu hiện tại:** Nhiệm vụ tuyến tính ban ngày cũ đã bị gỡ bỏ. Mục tiêu duy nhất hiển thị là: **"Tới cổng Trường NEH khi bạn sẵn sàng"** (người chơi có thể tới cổng trường bất cứ lúc nào để vào Đêm 1 ngay, hoặc tự do dạo phố cho tới `22:00` thì tự động chuyển sang Đêm 1). Đồng hồ trôi 1 phút game cho mỗi 30 giây di chuyển cộng thêm thời gian tiêu tốn của từng hoạt động.
- **Các hoạt động tự chọn đang hoạt động đầy đủ trong Khu phố:**
  1. **Trò chuyện với 6 NPC phố:** Cô Hoa, Bà Sáu, Bác Lực, Anh Phúc, Chị Mai, Khoa. (Bà Sáu và Chị Mai gợi ý về ông lão bán đồ kỳ dị treo đèn lồng đỏ ở Hẻm 5).
  2. **Đấu cờ vua 3D tại Góc Cờ (`chess_view.gd`):**
     - *Tí Sún* (tốn 30 phút, thưởng `10$`; có trò chỉ tay đánh lạc hướng camera để trộm quân — bắt quả tang được thưởng thêm `5$`).
     - *Khoa* (tốn 60 phút, cờ chớp đồng hồ 5 phút, thưởng `60$`).
     - *Thầy Khải* (tốn 60 phút, thưởng `140$`): Trong ván đấu với Thầy Khải, mỗi ván người chơi có 1 lần bấm nút **"Lắng nghe"** — màn hình lạnh đi, tiếng thở phả sát sau gáy, bóng hồn **An** thì thầm *"…đi đúng luật…"* và tô sáng nước đi mạnh nhất trên bàn cờ! Thắng được Thầy Khải sẽ mở khóa đoạn tự thú của ông về cái chết và sự bất công mà An phải chịu năm 2009.
  3. **Mua sắm chuẩn bị tại Tiệm Không Tên (Hẻm 5, ẩn khỏi bản đồ):**
     - Khởi đầu Peter có sẵn `300$` và túi đồ 4 ô (`night_gear.gd`).
     - Các mặt hàng: **Đèn pin xịn** (`300$`, không tốn ô túi — **nếu không mua, vào Đêm 1 Peter chỉ có Đèn quay tay `crank` phải bấm `R` lên dây cót kêu lạch cạch thu hút quỷ!**), **Súng muối** (`180$`, 1 phát thoát chết khi bị Ghen Tị tóm), **Huy chương mạ** (`120$`, mồi nhử để Ghen Tị cướp thay vì giết, nhưng làm quỷ đánh hơi sát hơn), **Túi sơ cứu** (`40$`), **Pin dự phòng** (`30$`), **Phấn trắng** (`10$`), cùng mục **Chuộc lại đồ bị cướp** giá 50%.
  4. **Đời sống khu phố (`town_life.gd`):** Ăn phở (`5$`) và uống cà phê (`3$`) giúp giảm tối đa `-20%` tốc độ hao thể lực ban đêm; uống trà đá (`1$`); mua vé số (`2$`, 8% trúng `30$`); cho con sáo của Bà Sáu ăn (`0$`, nghe nó nhại *"Tên em đâu rồi?"*); đọc bảng tin phường; câu cá bờ sông Trầu (tốn 30 phút, bán cá được `4–12$` hoặc đôi khi kéo lên cảm giác rợn gáy *"Dưới nước có gì đó nhìn lên"*).
  5. **Điều tra ARG trên Trình duyệt Cú Đêm (chạy song song ngoài cửa sổ game):**
     - Người chơi tự lên `gaaglu.com` gõ tìm `"THPT NEH"` hoặc `"Nguyễn Bình An"` → đọc 3 tờ báo địa phương → vào `thptneh.edu.vn` thấy Bảng vàng bị đục tên `[đã gỡ theo yêu cầu]` và sổ lưu bút *"tên em đâu rồi"* → đọc bài giải Cờ vua 2008 để lấy đáp án câu hỏi bảo mật nội bộ (`cờ vua`) → mở được danh sách đăng ký thi HSG `DS-07/2009` lấy được số định danh 12 số của An (`097193004217`) → đem qua `dancu.hailam.gov.vn` tra ra toàn bộ hồ sơ công dân đã đóng ngày `22/11/2009` cùng 3 lá đơn kêu cứu của bà Trần Thị Mận và địa chỉ nhà **Số 14 Hẻm 31**.

### Chương 5: `night1` — Đêm 1 · Ghen Tị (Hiện trạng đang chạy trong code)
- Khi tới cổng trường (hoặc đồng hồ điểm `22:00`), màn hình hiện banner `"ĐÊM 1 · 22:30"` rồi nạp `scenes/school_runtime.tscn` với cờ `night_one = true`.
- Toàn bộ những gì diễn ra từ giây phút này chính là **điểm nghẽn cần Handoff thiết kế** được mổ xẻ chi tiết ngay ở Mục 4 dưới đây.

---

## 4. HANDOFF TRỌNG TÂM: Vì Sao "Vào Trường Đêm 1 Buổi Tối Không Biết Làm Gì Hết" & Các Đứt Gãy Hiện Tại

### 4.1. Giải phẫu chính xác chuyện gì đang xảy ra khi bước vào Trường ở Đêm 1

Khi kiểm tra trực tiếp `scripts/world.gd` (dòng `420–430`) và `scripts/school_progression.gd` (dòng `517–564`), hàm `begin_night_one()` hiện tại thực chất chỉ là **một khung thử nghiệm AI Quỷ Ghen Tị** chứ chưa có kịch bản Đêm 1:

1. **`begin_night_one()` đang gọi thẳng `bypass_for_test()`:**
   - Vừa load xong map lúc `22:30`, người chơi bị đặt thẳng vào vị trí sau cổng chính (`Vector3(12, 0.05, 75.2)`) **ngay bên trong Cõi Âm** (`begin_midnight()`), bỏ qua hoàn toàn cảm giác bước vào ngôi trường bỏ hoang buổi tối hay khoảnh khắc chuyển giao sang thế giới bên kia.
2. **Không có một dòng mục tiêu hay dẫn dắt nào trên màn hình:**
   - `world.gd:326` gán cứng `objective_label.visible = false`.
   - Giao diện rút gọn `compact_hud.gd` chỉ vẽ đồng hồ `22:30`, 3 hình thoi ký ức màu xanh **đã sáng đầy sẵn**, biểu tượng chìa khóa nhỏ xíu, chữ `"J"` và 6 ô túi đồ. Nếu người chơi không tự mò bấm `J` (Nhật ký) hoặc `M` (Bản đồ), màn hình hoàn toàn trống trơn, đứng giữa sân trường tối om mà không hề biết mình cần đi đâu hay làm gì.
3. **Toàn bộ 40 căn phòng trong trường đang "rỗng nhiệm vụ":**
   - Do `bypass_for_test()` tự động đánh dấu cả 3 mảnh ký ức của An (`isolation`, `fear`, `notebook` — vốn nhặt từ Đêm 0) là **đã tìm thấy**, đồng thời tự động nhét luôn **Chìa khóa tổng (`collect_master_key()`)** vào túi người chơi (và xóa `notice_time = 0` nên cũng không báo là đã có chìa khóa!), đồng thời mở toang tất cả cổng sắt cầu thang.
   - Hệ quả: **24 phòng Khu A + 15 phòng Khu B + Nhà kho dịch vụ không chứa bất kỳ manh mối cốt truyện, vật phẩm nhiệm vụ hay câu đố nào của Đêm 1** (chỉ còn lác đác vài cục pin/túi cứu thương/phấn sinh tồn).
4. **Đứt hoàn toàn kết nối với chuỗi điều tra Ban ngày & Web ARG:**
   - Dù ban ngày người chơi có bỏ hàng giờ giải mã website trường, tìm ra mã định danh `097193004217`, đọc 3 lá đơn của mẹ An, thắng cờ Thầy Khải để nghe lời thú tội, nghe con sáo kêu *"Tên em đâu rồi?"*, hay phát hiện căn nhà mình thuê chính là nhà của An — **không một thông tin nào trong số đó được truyền sang hay sử dụng ở Đêm 1** (`hub/web/` chưa gửi sự kiện hoàn thành hồ sơ về Godot, và `soul_quest.gd` cũng chỉ kiểm tra đúng 3 món đồ Đêm 0 là gấu bông, gậy máu, sổ tay).
5. **Đường tắt 30 giây lên thẳng Sân thượng gặp An & Vùng an toàn tuyệt đối 100%:**
   - Ngay từ giây đầu tiên vào Đêm 1, người chơi có thể chạy thẳng một mạch qua cầu thang giữa lên **Sân thượng Khu A** (`y >= 11.35`) mất chưa tới 30 giây.
   - Trên sân thượng, hàm `world.is_soul_sanctuary()` bảo vệ người chơi **an toàn tuyệt đối 100%** trước Quỷ Ghen Tị (`_player_exposed()` trả về `false`).
   - Hội thoại giải thoát An (`soul_quest.gd`) cho chọn 3 câu trả lời có sẵn cho mỗi chủ đề rồi gửi qua local server nhờ **Gemini API (`gemini-3.8-flash`)** chấm điểm đồng cảm (`>= 70` điểm). *(Lưu ý kỹ thuật: Nếu máy người chơi không tạo sẵn file `~/.config/neh-school/ai.json` chứa Gemini API Key, hội thoại sẽ báo lỗi kết nối và kẹt cứng không thể giải thoát cho An!)*
6. **"Thời gian chết" 12–13 phút thực sau khi cứu xong An & Vòng lặp cụt sau 06:00:**
   - Kể cả khi người chơi trò chuyện xong và giải thoát cho An chỉ sau ~2 phút chơi (khoảng `23:30` trong game), **đêm chơi vẫn KHÔNG kết thúc**.
   - Người chơi buộc phải chờ đồng hồ chạy đủ **15 phút đời thực** cho tới `06:00` sáng (`survival_director.gd:195`) mới qua màn — và vì sân thượng miễn nhiễm quỷ hoàn toàn, người chơi chỉ việc đứng im treo máy trên sân thượng chờ trời sáng!
   - Khi điểm `06:00` sáng và bấm `Enter`, game thưởng `+150$`, chuyển đồ bị Ghen Tị cướp sang danh sách chuộc đồ ở Tiệm Không Tên, reset đồng hồ về `07:00` và... **nạp lại đúng Khu phố Ngày 1** (chưa có Ngày 2 hay Đêm 2).

---

### 4.2. Sáu đứt gãy & mâu thuẫn cốt truyện (Narrative Gaps) cần hàn gắn khi viết tiếp

| # | Đứt gãy / Mâu thuẫn trong bản hiện tại | Chi tiết vị trí trong code |
| :---: | :--- | :--- |
| **1** | **Lời hứa bỏ ngỏ của Lan** | Lúc `01:06` sáng (`home_story.gd:8-9`), Lan dặn *"Ban ngày đi tìm hiểu chuyện gì đã xảy ra với em ấy. Hiểu đủ thì mới giải thoát được... Ngủ đi đã. Sáng tôi nhắn."* Nhưng suốt Ngày 1 lẫn lúc bước vào Đêm 1, Lan hoàn toàn không nhắn tin lại, không hướng dẫn cách giải thoát hay cách rút khỏi trường sau khi cứu hồn. |
| **2** | **Lan xuất hiện nhầm trong nhóm bạn ở phim mở đầu Đêm 0** | `opening_cinematic.gd:113-115` tạo 4 nhân vật leo rào vào trường gồm `["Minh", "Lan", "Khoa", "PlayerDouble"]` và dùng luôn model `Female_Adult_11` của Lan. Điều này mâu thuẫn trực tiếp với nhóm chat đầu game (chỉ có Peter, Minh, Khoa) và việc gặp Lan ở Hành lang đỏ Peter còn hỏi *"Còn cô là ai?"* như lần đầu gặp mặt. |
| **3** | **Số phận phi lý của Minh & Khoa sau Đêm 0** | Đêm 0 cả nhóm cùng cắt khóa vào trường, cổng bị phong ấn, Peter bị kéo vào Cõi Âm và Lan nói *"Các bạn đã bị ràng buộc bởi lời nguyền"*. Thế nhưng lúc `01:06` Minh vẫn nhắn hỏi *"Tối qua mày biến đi đâu vậy?"*, sáng Ngày 1 Khoa ngồi đánh cờ tỉnh bơ ở quán cà phê (*"Mày sống rồi à. Có gì tối tính"*), rồi tới tối Đêm 1 Peter lại lủi thủi vào trường một mình mà không có lấy một dòng tin nhắn hay lý do vì sao Minh và Khoa không đi cùng. |
| **4** | **Lệch số phòng CLB Cờ vua giữa Lore và Map mới** | Bài báo web trường (`hub/web/school.js:97`) và lời thoại Thầy Khải (`chess_people.gd`) đều ghi CLB Cờ vua sinh hoạt tại **Phòng 205**. Tuy nhiên sau bản refactor map trường (`tools/build_map.gd`), **A-205** đang là *Lớp học*, còn **A-206** ngay sát vách (và **B-304** ở Khu B) mới là *Phòng Câu lạc bộ*. |
| **5** | **Cú twist "Nhà Số 14 Hẻm 31 là nhà của An" chưa có điểm nổ (Payoff)** | Môi trường nhà Peter và hồ sơ dân cư `097193004217` đã cài cắm cực hay việc Peter đang ở chính ngôi nhà tuổi thơ của An (có cả quân Hậu trắng sứt mẻ kẹt đầu giường), nhưng hiện chưa có cảnh/thoại nào để Peter nhận ra sự thật này hoặc mang kỷ vật đó vào trường cho An. |
| **6** | **3 tin nhắn nhiễu của Người lạ (`" "`) & Lá thư 17 năm ở Bưu cục** | Đã gieo rất ấn tượng ở Chương 3 và trên báo Hải Lâm / lời thoại Cô Hoa, nhưng chưa dẫn tới sự kiện, mối đe dọa hay vật phẩm nào trong Ngày 1 – Đêm 1. |

---

## 5. Kho "Nguyên Liệu, Bản Đồ & Cơ Chế Đã Code Sẵn" Có Thể Tận Dụng Ngay

Khi thiết kế diễn biến mới cho Đêm 1 và các đêm tiếp theo, **không cần xây lại từ số 0** — trong codebase đang có sẵn một lượng lớn không gian 3D và cơ chế gameplay đã lập trình xong nhưng đang để trống hoặc ngủ đông:

### 5.1. Sơ đồ 40 phòng có sẵn trong Trường THPT NEH (`tools/build_map.gd`)

Mỗi tầng của Khu A và Khu B được nối với nhau bằng **3 hành lang cầu** (hành lang giữa, nối Tây, nối Đông), tạo thành **2 vòng lặp rượt đuổi khép kín không ngõ cụt trên mọi tầng**:

| Khu vực | Tầng 1 | Tầng 2 | Tầng 3 | Điểm đặc biệt |
| :--- | :--- | :--- | :--- | :--- |
| **Khu A — Dãy Bắc** | **A-101** Phòng Giáo viên<br>**A-102** Lớp học *(Gậy máu Đêm 0)*<br>**A-103** Lớp học *(Gấu bông & Gầm bàn Lan)*<br>**A-104** Phòng Y tế | **A-201** Phòng Máy tính<br>**A-202** Lớp học<br>**A-203** Lớp học<br>**A-204** Phòng Thí nghiệm | **A-301** Phòng Mỹ thuật<br>**A-302** Lớp học<br>**A-303** Lớp học<br>**A-304** Phòng Âm nhạc | Cầu thang chính ở giữa dãy Bắc là **lối duy nhất dẫn lên Sân thượng Khu A & Tháp đồng hồ**. |
| **Khu A — Cánh Tây** | **A-105** Thư viện<br>**A-106** Lớp học | **A-205** Lớp học<br>**A-206** Phòng Câu lạc bộ | **A-305** Phòng Lưu trữ<br>**A-306** Lớp học *(Sổ tay An Đêm 0)* | Gần Vườn Tây & Hồ nước ngoài sân. Có cầu thang phụ cuối cánh (chỉ lên tới tầng 3). |
| **Khu A — Cánh Đông** | **A-107** Lớp học<br>**A-108** Kho Thiết bị | **A-207** Phòng Thí nghiệm<br>**A-208** Lớp học | **A-307** Lớp học<br>**A-308** Phòng Đa năng | Gần Sân bóng rổ (`SPORTS / 立入禁止`). Có cầu thang phụ cuối cánh. |
| **Khu B — Tòa Phụ Phía Sau** | **B-101** Thư viện<br>**B-102** Lớp học<br>**B-103** Phòng Thí nghiệm<br>**B-104** Phòng Giáo viên<br>**B-105** Phòng Y tế | **B-201** Phòng Máy tính<br>**B-202** Lớp học<br>**B-203** Phòng Mỹ thuật<br>**B-204** Phòng Lưu trữ<br>**B-205** Lớp học | **B-301** Phòng Đa năng<br>**B-302** Lớp học<br>**B-303** Phòng Âm nhạc<br>**B-304** Phòng Câu lạc bộ<br>**B-305** Kho Thiết bị | **Hoàn toàn chưa được dùng tới trong Đêm 0 lẫn Đêm 1!** Có cầu thang phụ phía Đông Bắc. |
| **Sân dịch vụ Tây Bắc** | **Phòng 990 — Nhà kho Thiết bị Trường** (`12 × 12 m` tách biệt ngoài sân sau) | — | — | Đã đặt sẵn `master_key.gd` trên bàn nhưng Đêm 1 đang ẩn đi và tự cho sẵn chìa khóa. |

### 5.2. Bảy hệ thống gameplay & ARG đã code sẵn nhưng chưa gắn (hoặc đang tắt) ở Đêm 1

1. **Hệ thống Chìa khóa tổng Nhà kho (`master_key.gd`) & Cổng sắt khóa tầng (`progression_gate.gd`):** Có thể bật lại ngay lập tức để khóa Sân thượng hoặc các phòng lưu trữ/CLB, buộc người chơi phải đi vòng xuống sân sau vào Nhà kho 990 hoặc tìm chìa khóa riêng.
2. **Hệ thống 4 loại Ma học đường + QTE Cận chiến (`bully_ghost.gd`, `school_entity.gd`, `encounter_director.gd`, `player_combat.gd`):**
   - Trong trường đã spawn sẵn 13 thực thể chia thành 6 vùng (Ma học sinh cầm gậy tuần tra, **Kẻ Dò Tiếng / Listener** mù nhưng phóng tới khi người chơi chạy rầm rập, **Kẻ Rỉ Tai / Whisperer** đứng chặn hành lang tối làm tụt thể lực và báo động lũ ma khác, **Kẻ Chặn Lối / Blocker** chỉ dịch chuyển áp sát khi người chơi quay lưng đi giống Weeping Angels) kèm cơ chế **QTE bấm `Space` ở đòn thứ 3** để lách người quật ngã ma. Hiện tại đầu Đêm 1 `envy_director.gd` đang gọi `set_dormant(true)` cho toàn bộ hệ thống này ngủ đông!
3. **Ống kính Điện thoại thật soi Cõi Âm (`phone_lens.gd`, layer `OTHER_WORLD`):**
   - Đã hoạt động hoàn chỉnh qua QR code. Rất lý tưởng để thiết kế các dấu vết, mật mã, quân cờ, tên thật trên Bảng vàng hoặc đường dẫn ẩn **chỉ nhìn thấy khi giơ điện thoại thật lên soi vào màn hình PC**.
4. **Profile trình duyệt bị ám của An (`hub/profiles.js` → `PROFILES.an`) & Cầu nối 2 chiều `arg_bridge.gd`:**
   - Trình duyệt Cú Đêm đã hỗ trợ gói tin `{ type: 'profile', id: 'an' }` đổi toàn bộ giao diện trình duyệt sang màu tím ma mị của `binhan@gaaglu.com` với những dòng suy nghĩ của chính An (*"Anh tìm gì ngoài đó vậy?"*, *"Họ cũng đứng nhìn như vậy."*, *"Quay lại đi."*). Cầu nối WebSocket cũng có thể bắn sự kiện từ Web về Godot ngay khi người chơi mở được hồ sơ `097193004217` hoặc xem Bảng vàng bị xóa tên!
5. **Cá tính cơ chế của Quỷ Ghen Tị (`envy_director.gd`):**
   - Đã có sẵn logic "càng mang nhiều đồ / vật phẩm giá trị, quỷ càng khoanh vùng rát" và "thích cướp chiến lợi phẩm đứng ngắm 4 giây". Cơ chế này cực hợp để gắn với một nhiệm vụ cốt truyện kiểu: **người chơi phải đi thu hồi chiếc Cúp / Huy chương Cờ vua hoặc Bảng tên thật của An** — ngay khoảnh khắc cầm kỷ vật vinh quang của An trên tay, lòng đố kỵ của Quỷ Ghen Tị bùng phát cực đại!
6. **Gầm bàn dịch chuyển giữa hai thế giới (`school_progression.gd` — gầm bàn Phòng A-103):**
   - Đã thiết lập lore rõ ràng ở Đêm 0 (chui qua gầm bàn để thoát khỏi Cõi Âm về thế giới thật). Có thể dùng chính cơ chế này làm **lối rút lui sinh tử sau khi giải thoát linh hồn An**, thay vì bắt người chơi đứng chờ đồng hồ chạy không tới `06:00` sáng!
7. **Kinh tế chuộc đồ Tiệm Không Tên (`night_gear.gd` `pawned`):**
   - Máy ảnh hoặc đồ bị Ghen Tị cướp trong đêm sáng hôm sau sẽ xuất hiện trên kệ Tiệm Không Tên ở Hẻm 5 để chuộc lại — tạo sợi dây liên kết rất tự nhiên sang Ngày 2.

---

## 6. Bộ Câu Hỏi Phân Tích & Quyết Định Thiết Kế Cần Chốt (Handoff Checklist)

Bạn có thể dùng trực tiếp danh sách các câu hỏi dưới đây làm đề bài khi đem tài liệu này đi phân tích và xây dựng kịch bản chi tiết:

### Nhóm A — Thiết kế lại Trải nghiệm & Nhiệm vụ Đêm 1 (Trọng tâm cần giải quyết ngay)
1. **Cách bước vào trường lúc 22:30 Đêm 1:**
   - Khi Peter bước qua cổng trường Đêm 1, trường đang ở **thế giới thật** (phải thực hiện một hành động/nghi thức như chui qua gầm bàn Phòng 103 hoặc chờ chuông điểm 00:00 để bước sang Cõi Âm), hay bị kéo thẳng vào Cõi Âm ngay tại cổng?
   - Làm sao truyền đạt mục tiêu đầu đêm cho người chơi một cách tự nhiên mà vẫn giữ chất kinh dị (ví dụ: tin nhắn hướng dẫn của Lan trên ứng dụng Nối trước khi mất sóng + mục tiêu rõ ràng trong Nhật ký `J` / lời độc thoại ngắn của Peter)?
2. **Kết nối Điều tra Ban ngày / Web ARG vào Đêm 1 như thế nào?**
   - Người chơi cần biết hoặc mang theo những gì từ Ban ngày để giải thoát được cho An? *(Gợi ý nguyên liệu sẵn có: ① Quân Hậu trắng sứt mẻ lấy từ khe đầu giường nhà Số 14 Hẻm 31; ② Lá thư kẹt 17 năm lấy từ Cô Hoa ở Bưu cục; ③ Chuyện ở Phòng CLB Cờ vua từ Thầy Khải; ④ Việc tên của An bị xóa khỏi Bảng vàng trên web trường & mã hồ sơ `097193004217`).*
   - Nếu người chơi lười điều tra ban ngày mà lao thẳng vào trường Đêm 1 thì sao? (Vẫn cho vào nhưng thiếu manh mối nên bị kẹt/thất bại phải qua ngày hôm sau điều tra tiếp, hay có manh mối thay thế khó hơn rất nhiều nằm sâu trong Khu B của trường?)
3. **Chuỗi nhiệm vụ 3 hồi bên trong Trường Đêm 1 sẽ dùng những phòng nào trong 40 phòng?**
   - *Ví dụ khung cấu trúc để phân tích:*
     - **Hồi 1 (Khám phá & Khôi phục sự thật bị xóa bỏ):** Lối lên Sân thượng ban đầu bị khóa/chặn bởi lời nguyền. Peter phải xuống Khu B / Phòng Lưu trữ (`A-305` hoặc `B-204`) / Phòng CLB Cờ vua (`A-206` hoặc `B-304`) / Phòng Giáo viên (`A-101`) để tìm lại những thứ đám kẻ xấu và nhà trường đã tước đoạt của An (Bảng tên thật bị gỡ khỏi Bảng vàng, biên bản/chiếc cúp cờ vua bị giấu, trang vở viết tay bị xé khỏi đơn của mẹ An) — có thể kết hợp **Ống kính điện thoại** để soi thấy vị trí giấu trong Cõi Âm.
     - **Hồi 2 (Đỉnh điểm với Quỷ Ghen Tị & Lên Sân thượng):** Khi Peter cầm kỷ vật chiến thắng của An trên tay, Quỷ Ghen Tị cảm nhận được "kẻ đang giữ vinh quang" và truy lùng gắt gao nhất. Peter phải vừa giữ kỷ vật không để bị nó cướp mất, vừa mở đường lên Sân thượng Khu A gặp An.
     - **Hồi 3 (Đối thoại giải thoát An & Thoát khỏi Cõi Âm):** Xử lý lại hội thoại với An (có phương án chấm điểm offline / lựa chọn nhánh rẽ dựa trên bằng chứng thu thập được để không bị soft-lock khi thiếu Gemini API key). Ngay khi An siêu thoát, vùng an toàn trên sân thượng tan biến, Quỷ Ghen Tị nổi điên truy sát lần cuối — Peter phải chạy ngược xuống trường tìm lối thoát (chui gầm bàn Phòng 103 hoặc mở cổng chính) để **kết thúc ngay Đêm 1 một cách kịch tính**, xóa bỏ hoàn toàn 12 phút đứng chờ tới `06:00` sáng!
4. **Vai trò của 13 bóng ma phụ trong Đêm 1:**
   - Tiếp tục tắt hết để chỉ một mình Quỷ Ghen Tị tạo áp lực rình rập kiểu *Alien: Isolation*, hay đánh thức một vài thực thể đặc thù (ví dụ *Kẻ Rỉ Tai* hoặc bóng ma đám học sinh cầm gậy từng bắt nạt An canh giữ quanh Phòng CLB Cờ vua / Phòng Lưu trữ)?

### Nhóm B — Hàn gắn Mạch truyện Đêm 0 → Ngày 1 → Đêm 1
5. **Vai trò thật sự của Minh và Khoa:**
   - Phim mở đầu Đêm 0 nên sửa lại model/tên nhân vật thứ 3 từ `Lan` thành ai (bỏ bớt còn 3 người Peter–Minh–Khoa cho khớp nhóm chat, hay thêm 1 thành viên thứ 4 khác)?
   - Chuyện gì đã xảy ra với Minh và Khoa lúc Peter bị hút vào Cõi Âm ở cổng trường Đêm 0? Vì sao Đêm 1 họ không vào trường cùng Peter? *(Gợi ý: Họ thoát được ra ngoài ở thế giới thật nên tưởng Peter tự bỏ về; hoặc một trong hai người bị thương/ám nặng sau Đêm 0; hoặc một người sau đó bị kẹt ở tầng thực tại lệch pha — làm bàn đạp dẫn thẳng vào chế độ **Co-op 2 thực tại song song ở Đêm 2**!)*
6. **Danh tính thật của Lan & Người lạ `" "`:**
   - Lan thực sự là ai trong bi kịch năm 2009 của Trường NEH (một cựu giáo viên, một học sinh khóa trên còn sống bị mắc kẹt nửa hồn, chị/người thân của một nạn nhân khác, hay chính một mảnh chấp niệm)?
   - Kẻ nhắn 3 tin nhiễu loạn `" "` trên app Nối là con quỷ giả dạng để dụ người chơi trả lời (phá luật *"Đừng trả lời tin nhắn nào không phải của tôi"* của Lan), hay là tín hiệu cầu cứu của Nguyễn Bình An / đồng đội bị kẹt ở thế giới bên kia?
7. **Điểm nổ cho cú twist Căn nhà Số 14 Hẻm 31:**
   - Khoảnh khắc Peter phát hiện căn nhà mình đang ngủ chính là nhà của An sẽ diễn ra ở đâu để tạo cảm xúc mạnh nhất (lúc tra ra địa chỉ trên `dancu.hailam.gov.vn` rồi chạy về phòng ngủ cậy khe đầu giường lấy quân Hậu trắng, hay lúc An nhắc tới *"vạch bút chì trên khung cửa"* trên sân thượng)?

### Nhóm C — Lộ trình Ngày 2, Đêm 2–3 & Kết cục Đồ án (KLTN Scope)
8. **Chọn Đại tội & Linh hồn nào cho Đêm 2 (và Đêm 3 nếu có)?**
   - Trong 6 con quỷ còn lại mà Lan đã nêu tên (*Lười Biếng, Phẫn Nộ, Tham Ăn, Tham Lam, Si Mê, Kiêu Ngạo*), đâu là 1–2 tội lỗi gắn chặt nhất với chính vụ bao che cái chết của An năm 2009 để toàn bộ 2–3 đêm tạo thành **một đại tự sự thống nhất** chứ không bị rời rạc?
     - *Ví dụ gợi ý liên kết trực tiếp từ Lore sẵn có:*
       - **Kiêu Ngạo (Pride)** hoặc **Phẫn Nộ (Wrath):** Kẻ cầm đầu nhóm học sinh khối 12 đã thua cờ An năm 2008 và ra tay ở Phòng 102.
       - **Lười Biếng / Thờ Ơ (Sloth)** hoặc **Tham Lam (Greed):** Sự làm ngơ, bao che và ém nhẹm đơn kêu cứu (`118/CV`, gỡ tên Bảng vàng để giữ thành tích trường) của người lớn / lãnh đạo nhà trường cuối năm 2009.
9. **Tích hợp Co-op 2 người chơi + Ống kính điện thoại từ Đêm 2:**
   - Nếu Đêm 2 mở Co-op (1 người ở Trường Thế giới thật / tầng thực tại A, 1 người ở Cõi Âm / tầng thực tại B), cốt truyện sẽ giải thích người chơi thứ 2 là ai (Khoa hoặc Minh bước vào trường tìm Peter, hay chính Lan)?
10. **Điểm khép lại trọn vẹn cho bản Demo/KLTN:**
    - Sau 2–3 đêm, cái kết của bản KLTN sẽ dừng ở một cao trào mở (giải thoát được An và vạch trần sự thật vụ đóng cửa trường năm 2009 lên mặt báo Hải Lâm / Làng Ta, mở ra những đại tội còn lại) hay khép lại trọn vẹn hành trình của Peter tại căn nhà Số 14 Hẻm 31?

