# NEH School — Khu A + B / Đêm 01

Demo khám phá trường 3D bằng Godot 4. **Khu A là khối chữ U ngược ba tầng**, bao quanh sân trong 44 × 44 m có đài phun nước. **Khu B** là khối học tập và phòng chức năng ở phía Bắc, nối với khu A bằng hành lang kín dài **35 m trên cả ba tầng**. Có **nhà kho riêng** ở sân dịch vụ phía Tây khu B và **sân thượng khu A** đi lên bằng cầu thang từ tầng 3.

Các nhiệm vụ cầu chì, sửa điện và nhật ký của bản cũ đã được bỏ. F5 chạy **mở đầu không lời**: điều tra → chuẩn bị dụng cụ → xe tới → cắt khóa cửa bảo trì qua tường bao cao. Player vào trường lúc **23:30**, 60 giây chuẩn bị rồi chuông nửa đêm chuyển hẳn sang thế giới linh hồn. Đêm **00:00–06:00 kéo dài 12 phút**. Chìa tổng trong kho mở đường; cần sống tới bình minh và giải cứu linh hồn để hoàn thành. Đã có 4 vật chứng, sổ ký ức J và ô tự nhập lời an ủi; kết nối Gemini 3.8 Flash dùng key Google AI Studio trong file riêng trên máy. Xem [nhiệm vụ và cấu hình AI](docs/SOUL_QUEST.md). Chi tiết/ảnh: [docs/OPENING.md](docs/OPENING.md).

## Chạy

Mở `project.godot` bằng Godot 4.3+ (đã kiểm tra bằng 4.7.2), đợi import GLB rồi nhấn **F5**. Renderer Compatibility không yêu cầu Vulkan. Từ terminal: `godot --path .`.

| Điều khiển | Chức năng |
| --- | --- |
| Chuột / WASD | Nhìn / di chuyển |
| Shift | Chạy, có stamina |
| F | Bật/tắt đèn pin |
| 1–6 / cuộn chuột | Chọn vật phẩm trong 6 ô túi |
| Chuột trái | Dùng vật đang cầm; chọn máy ảnh để chụp |
| Q | Thả vật đang chọn xuống sàn, E nhặt lại |
| E | Nhặt chìa/đồ tiếp tế, dùng cửa và chỗ nấp, kiểm tra cổng phong kín |
| ENTER | Bỏ qua phim mở đầu, vẫn bắt đầu chuẩn bị lúc 23:30 |
| N | Bắt đầu lại mở đầu sau khi kết thúc lượt |
| Ctrl | Đi nhẹ, giảm tiếng chân |
| Space | Giữ khi nấp để nín thở; nhấn đúng cung xanh để né/phản công trong QTE |
| G / chuột trái khi cầm phấn | Giữ tích lực, thả ném; tối đa ×5 tầm xa sau 1,5 giây |
| B | Bật/tắt linh hồn trong preview; bị khóa khi đang sinh tồn |
| J | Sổ ký ức, manh mối và vị trí vật chứng |
| M | Mở/đóng sơ đồ; trong sinh tồn, thực thể vẫn hoạt động |
| F6 | Đổi chất lượng Nhẹ / Cân bằng / Cao; lưu cho lần chơi sau |
| F7 | Bật/tắt FPS và số lượt vẽ |
| Esc | Thả/bắt chuột, dừng di chuyển |
| R | Chơi lại; giữ chế độ sinh tồn nếu đang trong một đêm |
| H + P cùng lúc | Bật/tắt TEST: bất tử, tốc độ ×3, có chìa/bốn ký ức, giữ An để thử hội thoại |

Đi qua sân trong tới cửa giữa dãy Bắc khu A để tìm cầu thang. Hai đầu cánh Tây–Đông tầng 1 cũng có lối vào từ sân trước. Cầu thang đi lên tầng 2, tầng 3 và sân thượng; ở các chiếu nghỉ, vòng sang phía Đông để ra hành lang hoặc sân thượng.

Muốn qua **khu B**, từ khu cầu thang đi vào hành lang phía sau (hướng Bắc / -Z) và đi hết đoạn 35 m. Cả ba tầng đều có đường nối tương ứng. **Nhà kho**: tại hành lang khu B tầng 1 đi về phía Tây, ra sân dịch vụ rồi đi theo đường lát tới cửa kho. M mở sơ đồ có vị trí hai khu và kho.

## Nhiệm vụ 01 / Chìa khóa tổng

Ban đầu **39 cửa phòng khu A và B đều khóa**. Các hành lang, cầu thang, sân thượng và đường qua B vẫn đi được; **cửa nhà kho riêng không khóa** để người chơi có thể lấy chìa.

Từ cổng đi vòng đài phun nước tới cửa giữa dãy Bắc A. Qua khu cầu thang rồi đi hết hành lang nối sang B tầng 1. Rẽ trái về phía Tây, ra sân dịch vụ, đi theo đường lát tới kho. E mở cửa kho, tìm **chìa khóa màu vàng trên bàn phía cuối kho**, nhìn gần và nhấn E để lấy. **M** đánh dấu nhà kho và nhiệm vụ trên sơ đồ.

Sau khi lấy, mọi cửa phòng có thể mở bằng E; chúng không tự mở hết. Ma cũng chỉ mở được các cửa phòng khi người chơi đã có chìa. Đổi thế giới bằng B giữ chìa và trạng thái cửa; R bắt đầu lại và đặt lại nhiệm vụ. Chìa nhặt được trong cả hai thế giới, không thể nhặt từ xa hay qua tường.

[Chìa trong kho](docs/master-key-preview.png) · [Sau khi nhặt](docs/master-key-collected-preview.png)

## Đêm sinh tồn

F5 tự chạy mở đầu; N bắt đầu một lượt mới khi chưa chạy hoặc đã kết thúc. Lấy chìa tổng trong kho để mở đường, sống **00:00–06:00** và cứu linh hồn. **Cổng không cho thoát bằng chìa tổng**. Thu 4 vật chứng trong các phòng, gặp An trên sân thượng khu A và tự nhập lời an ủi cho 4 trải nghiệm. AI phải xác nhận từng câu; chưa giải cứu thì bình minh báo chưa hoàn thành. R chơi lại từ đoạn phim. N không hồi tài nguyên giữa lượt; B không được dùng để né nguy hiểm/hồi máu. Esc dừng game, M chỉ xem đường và không dừng AI trong lượt sinh tồn.

Có **13 thực thể**: tám học sinh cầm gậy, hai Kẻ Dò Tiếng, hai Kẻ Rỉ Tai và một Kẻ Chặn Lối. Mỗi loại có cách đối phó riêng; [hướng dẫn sinh tồn và ảnh thực tế](docs/SURVIVAL.md). Pin, sơ cứu và phấn dùng một lần; nguồn giới hạn khuyến khích đi vòng tìm đồ. Hoảng loạn làm hơi thở to hơn, hồi stamina chậm hơn và nguy hiểm nếu duy trì ở mức tối đa.

Để test nhanh: **giữ H, bấm P** (hoặc ngược lại). TEST bỏ qua mở đầu/chuẩn bị, bật bất tử và tốc độ ×3, cho chìa tổng và bốn ký ức, giữ An xuất hiện để nói chuyện. Đêm vẫn chơi được để test ma. **Esc → TEST · Đưa tới An để thử chấm AI** giữ chìa/ký ức nhưng xóa tiến độ an ủi, đưa player tới An; vẫn gọi AI thật và cần key. **Esc → TEST · Hoàn thành đêm, tới 06:00** kiểm tra kết thúc ngay. H+P tắt sức mạnh; nhiệm vụ đã hoàn thành vẫn giữ và lượt luôn gắn nhãn TEST. R chơi lại xóa cheat/tất cả tiến độ. Chữ H/P đang nhập trong hội thoại không bật cheat.

**Máy ảnh** có sẵn ở ô 2: chọn rồi nhấn chuột trái. Một cú chớp làm sáng toàn bộ cảnh và đẩy lùi mọi thực thể trong **6 giây**, tiêu **20 điểm phần trăm pin**, hồi màn trập **1,5 giây**. Máy ảnh dùng chung năng lượng với đèn pin; nhặt pin dự phòng bằng E, chọn ô pin rồi dùng để sạc +50. Chuyển khỏi đèn pin sẽ tắt đèn. 100% pin đủ 5 ảnh nếu không dùng đèn. Không chụp khi đang nấp, mở giao diện, tạm dừng hoặc đã chết.

Túi có **6 ô, mỗi ô một vật**, không cộng dồn: ban đầu đèn pin, máy ảnh, ba viên phấn và một ô trống. Đồ tiếp tế được cất để dùng sau; đầy túi thì Q thả bớt và E nhặt lại. Sơ cứu hồi +30 HP khi dùng, phấn tiêu một ô khi ném. Chìa khóa tổng và bốn ký ức được lưu riêng trong nhiệm vụ. [Ảnh máy ảnh và cú chớp](docs/CAMERA.md).

- **Ctrl** đi nhẹ, giữ khoảng cách để tránh Kẻ Dò Tiếng; khi nấp và hoảng loạn, **Space** nín thở. Hết hơi sẽ ho và có thể lộ tủ.
- **Giữ/thả G** hoặc chuột trái khi cầm phấn để tích lực rồi ném, tối đa xa ×5 sau 1,5 giây: tiếng va chạm kéo thực thể nghe thấy sang chỗ rơi. Không ném được khi đang nấp.
- **F** rọi vào mặt Kẻ Rỉ Tai khoảng 0,7 giây để ngắt tiếng và có 2,4 giây rút lui; hoặc cắt đường nhìn bằng tường/cửa.
- Kẻ Chặn Lối có thân lớn chặn đường thật, bước nặng và gậy mạnh nhưng chuẩn bị 0,85 giây; dụ nó sang một phía rồi chạy vòng.
- Chuông mỗi đợt săn báo 12 giây thực thể nghe xa hơn; lấy chìa cũng gây một đợt săn.

## Hiệu năng

F5 chạy `scenes/school_runtime.tscn`, được sinh từ scene gốc `scenes/school.tscn`. Mesh tĩnh được gộp bằng MultiMesh theo từng ô không gian và tầng; collider tĩnh được gộp theo vùng, giữ nguyên hình dạng. Cửa, tương tác và ma vẫn hoạt động riêng.

**F6** đổi mức chất lượng: Nhẹ giảm độ phân giải 3D xuống 75%, tắt bóng trăng/đèn pin và dùng tối đa 8 đèn gần người chơi; Cân bằng giữ độ phân giải 3D gốc với 12 đèn; Cao dùng 24 đèn và bóng xa hơn. Ống đèn vẫn hiển thị ở các phòng xa. Lựa chọn được lưu trong `user://settings.cfg`. **F7** hiện FPS/lượt vẽ để kiểm tra khi di chuyển.

Map hiện tại gộp 8.448 mesh tĩnh thành 1.548 nhóm và 3.882 body tĩnh thành 228 vùng, bao gồm hình học/collider của tủ và bàn nấp. Script/vùng tương tác E của từng chỗ nấp vẫn riêng. Các nhóm lưu thêm biến thể cho thế giới linh hồn. Hạt tro/nước dùng mesh ít polygon hơn; kiểm tra cửa tự mở được giãn nhịp, hiệu ứng toàn màn hình tắt khi ở thế giới thường. Số đo trước/sau và cách kiểm tra ở [docs/PERFORMANCE.md](docs/PERFORMANCE.md).

## Thế giới linh hồn / oán khí

Nhấn **B** để sang phiên bản trường bị oán khí biến dạng: tường mục, sàn nứt có vệt đỏ, cây đen, đài phun nước tối, dấu bàn tay kéo dài và lời đe dọa trên tường. Nhiều bàn/ghế có sẵn treo ngược sát trần; sách nổi khỏi kệ. Hành lang nối có ghế treo, rễ đen chạy qua trần và cửa sổ. Texture tường/sàn lấy từ Poly Haven CC0, thay vì chỉ đổi màu cả cảnh.

Trăng đỏ, sương lạnh, đèn đỏ chập chờn và tro giữ không khí đêm; đèn pin vẫn giúp đọc đường và vật thể. Có tiếng rền nền; nhịp tim và viền màn hình tăng khi ma đang đuổi tới gần. Tắt B khôi phục đúng vật liệu, vị trí đồ vật/collider và xóa ma; khi vật thể hiện lại chồng lên người chơi, nhân vật được chuyển sang chỗ trống gần đó. Chìa khóa và trạng thái cửa giữ nguyên.

Ảnh so sánh và chi tiết chỉnh sửa: [docs/HORROR.md](docs/HORROR.md).

- Chỉ thế giới linh hồn mới spawn ma: mặc định **8 ma không mặt cầm gậy gỗ** cùng 5 thực thể chuyên biệt; đám cầm gậy gồm hai nhóm ba con ở sân trong/hành lang tầng 1 và hai con đi lẻ: một ở khu B tầng 2, một ở khu A tầng 3.
- Ma tuần tra; phát hiện người chơi thì khựng nhìn 0,34 giây, gầm và lao tới ở 6,4 m/s trong 1,1 giây, nhanh hơn player chạy. Sau đó đuổi ở 4,65 m/s, cần hồi 5 giây trước đợt lao tiếp. Tiếng chân gấp và pose chúi về trước báo đợt lao. Đồng bọn được báo tới; mất dấu thì tìm và đảo mắt quanh vị trí cuối cùng, rồi trở về tuần tra.
- Navigation dùng collider thật của trường, có đường qua cầu thang, hành lang nối sang B và lên sân thượng. Quái bị chặn khỏi sân thượng A; An chờ phía Đông cửa cầu thang, có ánh hồn xanh và dấu trên M. Mái nối bằng mặt sân thượng để player đi qua hai nửa. Tường và sàn chặn tầm nhìn, ma không đánh xuyên chúng.
- Cửa lớp đóng chặn người chơi và tầm nhìn của ma. Trước khi có chìa tổng, ma cũng không thể mở cửa phòng bị khóa. Sau khi có chìa, ma gần cửa có thể mở để tiếp tục truy đuổi; đóng cửa chỉ tạo một khoảng nghỉ ngắn.
- Vung gậy có độ trễ 0.42 giây để người chơi né/chạy. Mỗi cú trúng mất 14 sinh lực; có 0.75 giây miễn sát thương sau khi trúng. Chưa có phản công.
- Hết sinh lực trong preview: **B** về cảnh thường hoặc **R** chơi lại; trong sinh tồn dùng **R/N** chơi lại. B hồi đầy sinh lực khi đổi thế giới để tiện tinh chỉnh demo. Esc tạm dừng truy đuổi; M chỉ dừng AI trong preview, không dừng trong đêm sinh tồn.

Thân/rig và animation Idle/Walk/Punch dùng Quaternius Suit_Male; sprint dùng Walk tăng tốc. Ma có dáng cao gầy, tay dài, đầu bầu dục trắng có vết nứt nhưng không có mắt/mũi/miệng, tóc đen, cổ áo, cà vạt, huy hiệu học sinh và tay áo bẩn. Đầu nghiêng và thân chao lệch, nhịp animation khác nhau giữa từng con; vẫn là học sinh trong bối cảnh bạo lực học đường.

## Nấp và cắt đuôi

Có **47 chỗ nấp**: mỗi phòng/kho có một tủ hoặc bàn làm việc có gầm trống, sáu tủ hành lang ở A/B trên ba tầng và thêm một bàn trong kho. Các tủ hành lang và hai chỗ trong nhà kho dùng được trước khi có chìa khóa tổng.

Nhìn vào mặt tủ hoặc mép gầm bàn rồi **E** để nấp; **E** lần nữa để ra. Nấp tự tắt đèn pin, dừng bước chân, giữ khả năng nhìn qua khe tủ hoặc từ góc thấp dưới bàn; chuột chỉ xoay trong phạm vi chỗ nấp. Ra ngoài trả lại đèn pin và capsule đứng. Nếu có vật/người chặn lối ra, game giữ người chơi trong chỗ nấp và báo thử lại, tránh đưa người chơi xuyên vật thể.

**Cắt tầm nhìn trước khi nấp.** Ma không thấy người đã nấp và không đánh xuyên tủ bằng cú vung cũ. Nếu ma chứng kiến lúc chui vào, nó nhớ đúng chỗ đó, đi tới kiểm tra khoảng 1,15 giây rồi ép người chơi ra; khi lối ra bị chắn, người bị phát hiện vẫn chịu sát thương. Kẻ Dò Tiếng còn có thể tìm tủ theo hơi thở/ho. Esc dừng AI; M chỉ dừng trong preview. B giữ chỗ nấp khi thay thế giới ngoài lượt sinh tồn; R bắt đầu lại.

[Chi tiết và ảnh thử](docs/HORROR.md)

## Bố cục

```text
                       BẮC / -Z
          ┌────────────────────────────────┐
          │ KHU B / 3 TẦNG                 │
          │ Thư viện · lớp · phòng chức năng│
 NHÀ KHO ←├──────────┐      ┌──────────────┤
 Sân dịch vụ         │      │
                     │ NỐI  │
                     │ 35 m │  Hành lang kín / 3 tầng
                     │      │
          ┌──────────┴──────┴──────────────┐
          │ KHU A / DÃY BẮC · CẦU THANG    │
          │ 3 tầng + sân thượng             │
          ├───────┐                ┌───────┤
          │ CÁNH  │   SÂN TRONG    │ CÁNH  │
          │ TÂY   │  ĐÀI PHUN NƯỚC │ ĐÔNG  │
          │       │ cây · hoa · ghế│       │
          └───────┘                └───────┘
 VƯỜN TÂY          SÂN TRƯỚC          SÂN BÓNG RỔ
                        │
                    CỔNG CHÍNH
```

- Khu đất khoảng 120 × 166 m. Sân trước, sân trong, vườn đá/hồ và sân bóng rổ giữ vị trí; phần đất phía Bắc được mở rộng cho khu B và kho, hàng cây phía sau chuyển ra sát ranh mới.
- **Khu A:** 24 phòng (8 mỗi tầng: 4 dãy Bắc, 2 mỗi cánh). Phòng dãy Bắc 15 × 18 m, phòng hai cánh 13 × 24 m; lớn hơn bố cục trước.
- **Khu B:** 15 phòng (5 mỗi tầng), diện tích khoảng 352–440 m² mỗi phòng. Bố trí hai bên hành lang, gồm phòng dài, phòng rộng, cửa ở hai hướng.
- Tổng cộng **39 phòng trong hai khu + 1 nhà kho riêng 12 × 12 m**. Có 16 lớp học, còn lại là thư viện, máy tính, thí nghiệm, giáo viên, y tế, mỹ thuật, âm nhạc, câu lạc bộ, đa năng, lưu trữ và kho thiết bị.
- Lớp học có ba kiểu bố trí: bàn theo hàng, bàn ghép thành cụm, bàn chữ U. Các phòng chức năng dùng giá sách/đọc sách, máy tính, bàn thực hành, bàn làm việc, chỗ nghỉ y tế, khu tập diễn, kệ và thùng đồ tùy loại.
- Tầng 1 cao độ 0; tầng 2 là 3.9 m; tầng 3 là 7.8 m; **sân thượng khu A là 11.7 m**, có tường chắn quanh mép, bồn nước và cụm thông gió tạo vật cản/khoảng khuất.
- Hành lang kín có bề rộng lọt lòng khoảng 2.75 m, trần thấp khoảng 3 m, cửa sổ có kính/collider. Cửa phòng đóng chặn đường và tầm nhìn; E mở/đóng. Cầu thang có collider dốc liên tục để đi lên mà không cần nhảy.
- Cửa sổ có khoảng mở thật để nhìn ra sân, cây, trời đêm và mặt trăng; ánh trăng có đổ bóng.

## Preview từ renderer Godot

- [Ba thực thể mới](docs/survival-entities-preview.png)
- [Nín thở trong tủ](docs/survival-hiding-preview.png)
- [Đèn pin ngắt Kẻ Rỉ Tai](docs/survival-light-counter-preview.png)
- [Cửa bảo trì thay cảnh trèo tường](docs/opening-service-entry-preview.png)
- [Toàn cảnh khu A + B](docs/campus-ab-preview.png)
- [Hành lang nối dài](docs/connector-preview.png)
- [Hành lang nối trong thế giới linh hồn](docs/spirit-connector-preview.png)
- [Hành lang khu B](docs/annex-hall-preview.png)
- [Lớp học khu B](docs/annex-classroom-preview.png)
- [Thư viện](docs/library-preview.png)
- [Phòng thí nghiệm](docs/lab-preview.png)
- [Nhà kho bên ngoài](docs/warehouse-exterior-preview.png)
- [Nội thất nhà kho](docs/warehouse-preview.png)
- [Sân thượng](docs/rooftop-preview.png)
- [Từ sân thượng nhìn xuống sân trong](docs/rooftop-courtyard-preview.png)
- [Từ sân trước](docs/campus-preview.png)
- [Sân trong](docs/courtyard-preview.png)
- [Đài phun nước](docs/fountain-preview.png)
- [Hành lang tầng 2](docs/second-floor-preview.png)
- [Hành lang kín](docs/hallway-preview.png)
- [Hành lang tầng 3 nhìn qua cửa sổ xuống sân](docs/third-floor-preview.png)
- [Phòng học rộng hơn](docs/classroom-preview.png)
- [Cửa lớp](docs/classroom-door-preview.png)
- [Mặt trăng qua cửa sổ lớp học](docs/window-moon-preview.png)
- [Cầu thang](docs/stairs-preview.png)
- [Sơ đồ trong game](docs/map-preview.png)
- [Thế giới thường](docs/normal-world-preview.png)
- [Thế giới linh hồn](docs/spirit-world-preview.png)
- [Lớp học thường](docs/realm-classroom-before.png) / [Lớp học bị biến dạng](docs/realm-classroom-after.png)
- [Thư viện linh hồn](docs/realm-library-preview.png)
- [Dấu tay trên tường](docs/realm-handprints-preview.png)
- [Nhà kho linh hồn](docs/realm-warehouse-preview.png)
- [Hành lang kín trong thế giới linh hồn](docs/spirit-hallway-preview.png)
- [Ma không mặt cầm gậy](docs/bully-ghosts-preview.png)

## Chỉnh trong Godot

Mở **`scenes/school.tscn` để chỉnh sửa**, rồi tạo lại scene runtime trước khi nhấn F5. `school_runtime.tscn` là bản sinh tự động để chơi. Toàn bộ bố cục gốc đã lưu thành scene, chỉnh trực tiếp được:

| Node | Nội dung |
| --- | --- |
| Architecture | Sàn, tường, cửa sổ, lớp học, cửa trượt, hành lang A/B, cầu thang và sân thượng |
| Furniture | Nội thất Kenney và model đài phun nước |
| Campus | Sân, đèn sân, cổng, hàng rào, sân bóng rổ và nước phun |
| Landscape | Model cây, hoa, cỏ, bụi và đá Kenney |
| Atmosphere | Sky đêm, ánh trăng, đèn trong lớp và cầu thang |
| Player | Nhân vật, camera, capsule và đèn pin |
| Navigation | Navmesh nối hai khu, kho và sân thượng; quái bị chặn khỏi sân thượng A, nơi An chờ |

Chọn node gốc **School**, trong Inspector có nhóm **Spirit realm · visuals** và **Spirit realm · bullies** để chỉnh màu/mật độ sương, ánh sáng nền, số ma (0–12), khoảng phát hiện, tốc độ đuổi và sát thương. Các thay đổi này được áp dụng khi bật B. Độ trễ đánh, thời gian giữa các cú đánh và tốc độ tuần tra nằm trong `scripts/bully_ghost.gd`; hiệu ứng màn hình ở `assets/materials/spirit_overlay.gdshader`. Khi chạy, ma và tro xuất hiện dưới `SpiritBullies` và `Resentment` trong Remote scene tree.

Nhiệm vụ và inventory ở `scripts/world.gd`, vật phẩm ở `scripts/master_key.gd`; bàn đặt chìa nằm trong scene gốc. Quy tắc biến dạng đồ vật ở `scripts/realm_prop_rules.gd`, material/manifestation và khôi phục vật lý ở `scripts/spirit_scenery.gd`; shader ở `assets/materials/realm_surface.gdshader` và `ghost_skin.gdshader`. Hai loop âm thanh nhỏ được tổng hợp bằng `tools/build_horror_audio.py`.

Cửa phòng nằm dưới `Architecture/ClassroomDoorXXX`; `scripts/classroom_door.gd` điều khiển tốc độ trượt, mở/đóng và tránh đóng vào người đang đứng ở ngưỡng cửa. Collider cửa ở layer 3 (giá trị bitmask 4), target tương tác ở layer 4 (8). Navmesh bake phần tường/sàn ở layer 1, để cửa mở vẫn có đường đi; ma phải tự mở cửa và chịu collider của cửa khi di chuyển.

Danh mục phòng được lưu trong metadata `room_catalog` của School, gồm loại phòng, khu, kích thước, tâm và kiểu bố trí; HUD và sơ đồ dùng chung danh mục này. `tools/build_map.gd` có các hàm `build_annex`, `build_connector`, `build_service_storage`, `build_rooftop` và `furnish_room` để chỉnh bố cục hoặc nội thất từng loại.

Di chuyển node cha của prop để di chuyển cả model và collider. `tools/build_map.gd` giữ bố cục và các kích thước để chỉnh có hệ thống. **Dựng lại sẽ ghi đè `scenes/school.tscn`, hãy lưu riêng các chỉnh sửa bằng tay trước:**

```sh
godot --headless --editor --path . --import --quit
godot --headless --path . --script tools/build_map.gd
```

Build map tự bake navigation và tạo scene runtime. Sau khi tự chỉnh tường, sàn, collider hoặc cầu thang trong scene gốc, lưu scene rồi bake lại đường đi; lệnh này cũng tạo lại runtime:

```sh
godot --headless --path . --script tools/bake_navigation.gd
```

Nếu chỉ chỉnh visual, ánh sáng hoặc tham số Inspector, không đổi collider, tạo lại runtime bằng:

```sh
godot --headless --path . --script tools/optimize_map.gd
```

## Kiểm tra và chụp ảnh

```sh
godot --headless --path . --script tools/validate_map.gd
godot --headless --path . --script tools/validate_spirit.gd
godot --headless --path . --script tools/validate_annex.gd
godot --headless --path . --script tools/validate_runtime.gd
godot --headless --path . --script tools/validate_quest.gd
godot --headless --path . --script tools/validate_realm_scenery.gd
godot --path . --script tools/capture_preview.gd --resolution 1280x720
godot --path . --script tools/capture_spirit.gd --resolution 1280x720
godot --path . --script tools/capture_annex.gd --resolution 1280x720
godot --path . --script tools/capture_horror_quest.gd --resolution 1280x720
```

Validation map kiểm tra lối đi ba tầng, lối vào trường, sân/vườn/sân thể thao, collider cửa sổ, tầm nhìn đến trăng và CharacterBody đi lên/xuống cầu thang. Nó còn kiểm tra chọn cửa để tương tác, cửa đóng chặn người chơi, mở cửa rồi đi qua, tránh đóng vào người, và ma thật mở cửa để đi vào lớp. Validation spirit kiểm tra B, nhóm/ma lẻ, vật liệu không mặt, animation, ma thật đi lên tầng 3, phát hiện/báo nhóm/truy đuổi/đánh, chắn tầm nhìn, hồi sinh và xóa ma khi tắt B, kể cả bật/tắt nhanh lúc navigation chưa sẵn sàng. Validation annex kiểm tra đường nối ba tầng, mọi cửa phòng khu B, đường tới kho, nav tới sân thượng, diện tích/loại/bố trí phòng và capsule thật đi hết hành lang 35 m. Validation runtime đối chiếu vị trí/kích thước toàn bộ mesh, hình dạng/transform/layer của collider với scene gốc, danh mục phòng, ba mức chất lượng, đèn gần người chơi và F7. Chạy validation runtime với display còn kiểm tra từng transform trong buffer GPU. Tất cả kiểm tra/capture dùng main scene thực tế của project. Validation quest đi thật từ cổng tới kho khi các phòng khóa, nhặt chìa bằng ray E, kiểm tra khóa/mở khóa, trạng thái qua B và run mới. Validation realm scenery kiểm tra biến dạng mesh/collider, vật liệu, phục hồi qua nhiều lần đổi thế giới và tránh kẹt người chơi; chạy với display còn đối chiếu buffer GPU. Chụp preview cần display, không dùng headless.

## Phạm vi

Hiện là demo một người chơi, phong cách low-poly đêm, có mở đầu không lời, đồng hồ 23:30–06:00, đêm 12 phút, pool 6 thực thể (thường 2 hoạt động, tối đa 3), tài nguyên hữu hạn và 47 chỗ nấp. Chi tiết dấu hiệu/đối phó ở [docs/SURVIVAL.md](docs/SURVIVAL.md). Chưa có multiplayer. Đã có nhiệm vụ 4 ký ức và hội thoại tự nhập; cần key Google AI Studio để chấm bằng Gemini 3.8 Flash. Đài phun nước có model có sẵn và hiệu ứng giọt nước, chưa mô phỏng nước hoặc phản xạ theo vật thể.

Nguồn assets, giấy phép và tham khảo kiến trúc nằm trong [ASSETS.md](ASSETS.md). `Demo-Idea.md` ghi ý tưởng cùng các quyết định mở đầu/đồng hồ mới.

HUD đã gọn lại: đồng hồ, 4 biểu tượng ký ức, chìa và các thanh tài nguyên cần thiết. Hướng dẫn nằm trong màn Esc; câu chuyện nằm trong J. Nhạc CC0 và SFX hành động xem [ASSETS.md](ASSETS.md).

Ảnh giao diện hiện tại: [HUD](docs/compact-hud-preview.png), [vật chứng](docs/soul-memory-preview.png), [sổ ký ức](docs/soul-journal-preview.png), [tự nhập lời an ủi](docs/soul-comfort-preview.png).

Tuần tra/QTE mới: ma nhớ dấu cuối, thấy sát thì phản ứng ngay. Pool 6 thực thể, tối đa 2 khi khám phá / 3 lúc chuông truy đuổi, spawn ngoài tầm nhìn và có nhịp nghỉ. Sau hai đòn trúng, SPACE đúng vòng QTE của đòn thứ ba để né → phản công → choáng ma gần 3 giây và adrenaline 8 giây (hao stamina chạy giảm 50%). [Chi tiết](docs/HUNT_COMBAT.md).

Tiến trình mới: [bốn nhánh làm xen kẽ](docs/PROGRESSION.md), hai lối mở B, cửa sân thượng có khóa cuối và tiếng khóc định vị của An. Tiến độ làm dở được giữ; nhặt đủ ký ức vẫn cần hoàn thành các hệ thống, mở mái và an ủi qua AI. Chạy `tools/validate_progression.gd` để kiểm chứng, `tools/capture_progression.gd` trên display để thử input và chụp ảnh.
