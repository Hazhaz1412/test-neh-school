# Bàn giao phiên làm việc

Cập nhật 2026-11-01. Đọc file này trước khi làm tiếp. Kịch bản Đêm 1 ở [Demo-Idea.md](../Demo-Idea.md), luật chơi ở [PROGRESSION.md](PROGRESSION.md), thế giới ARG ở [ARG_WORLD.md](ARG_WORLD.md), asset và giấy phép ở [ASSETS.md](../ASSETS.md).

## Dự án và người dùng

- NEH School là game kinh dị Godot 4.7 cho khóa luận tốt nghiệp. Hướng mới là ARG giả thực: game + web giả chạy trên máy người chơi + điện thoại.
- Người dùng xưng "anh", gọi trợ lý là "em". Trả lời bằng tiếng Việt, ngắn, nói thẳng kết quả.
- Người dùng thích thấy chạy thật hơn nghe kế hoạch, và phản hồi bằng ảnh chụp, log từ máy thật. Có điện thoại Android, dùng Brave, WebXR AR hoạt động.
- Họ sẽ nói thẳng nếu giao diện xấu. Với UI phải tự chụp ảnh và xem trước khi báo xong.

## Git

Nhánh `main`, commit mới nhất `75a8df6 feat: add lens-2ndworld` do người dùng tự commit. Toàn bộ khu phố ban ngày (`scripts/town/`, `scenes/town.tscn`, asset mới khoảng 95 MB) chưa commit. Chỉ commit khi được yêu cầu.

## Việc đang dở, làm trước tiên

**Hiệu chỉnh AR của ống kính chưa từng hoàn tất trên điện thoại thật.**

- Lỗi cuối: thanh tiến độ lên 100% rồi báo "chỉ thấy 0 góc dấu". Đã xác định và sửa: ảnh camera trong AR bị lộn ngược, bộ dò dễ dãi đọc thành mã rác nên không bao giờ lật ảnh.
- Bản sửa ở `hub/web/lens-scan.js` đã kiểm chứng bằng ảnh game thật qua worker thật, **chưa thử trên điện thoại**.
- Bước tiếp: người dùng tải lại trang, quét lại. Xem sau 100% hình có dán đúng màn hình không. Log nằm ở terminal `npm start`, dòng `Ống kính: ...`, và góc trên trang điện thoại.
- Nếu hình lệch: nghi ngờ đầu tiên là ảnh camera không khớp khung nhìn của `XRView` (tỉ lệ, cắt ảnh, xoay dọc) trong `scanCamera` và phép đổi tọa độ ở `lens-xr.js`.

## Khu phố ban ngày

Đã có bản chơi được, chi tiết ở [TOWN.md](TOWN.md). Mở `scenes/town.tscn` và bấm F6. Người dùng chưa tự chơi, cảm giác lái và âm thanh tổng hợp chưa được ai nghe hay thử bằng tay. Cốt truyện ban ngày đã bỏ theo yêu cầu người dùng.

## Quỷ Ghen Tị

Đêm 1 sẽ dùng con quỷ này. Model: `tools/build_envy_demon.py` (chạy Blender nền) và `scripts/envy_demon_model.gd`. Xem thử bằng `tools/capture_envy.gd`. AI hai tầng: `scripts/envy_director.gd` (A, biết vị trí, chỉ gửi vùng gợi ý) và `scripts/envy_demon.gd` (B, chỉ biết điều nó thấy, nghe, được gợi ý; tự lục phòng và chỗ trốn; nín thở lúc nó nghe thì thoát). Quỷ thay ma học sinh sau cảnh Lan, tắt bằng `envy_enabled`. F9 hiện trạng thái A và B. Kiểm thử: `tools/validate_envy.gd`. Chưa có: vứt đồ để nhử, cảnh nó cầm đèn pin của người chơi, cân bằng khi chơi thật. Blender MCP đã cấu hình nhưng không nạp được trong phiên trước, nên dùng Blender dòng lệnh.

## Mạch truyện sau Đêm 1

Chui gầm bàn ra gặp Lan (`Stage.LAN_FAREWELL`), đổi số, sang `scenes/home.tscn`. Nhà: `scripts/home/`. App chat hư cấu "Nối" trong `home_phone.gd`, không chép Line. Kịch bản sáng trong `home_story.gd`. Cài lối tắt ở `hub/desktop.js`, chỉ khi người chơi đồng ý ở màn hình đầu, gỡ bằng `npm run remove-desktop` trong `hub/`. Test cài chỉ dùng HOME tạm, không đụng Desktop thật.

Mạch đã chốt: Đêm 0 (Intro) gồm toàn bộ đoạn cũ tới khi gặp Lan, về nhà, sáng tự do ở khu phố, tới cổng trường vào Đêm 1 (`world._begin_night_one`, meta `night_one`): quỷ săn ngay, tìm An trên sân thượng, sống tới 06:00. Tài liệu Demo-Idea.md gọi đoạn Intro là "Đêm 1", đó là tên cũ. Cốt truyện ban ngày cũ (bức thư, cô Thanh, bác Lực) đã bị người dùng bỏ. F8 gọi quỷ ở nơi khác. F10 bỏ qua hành lang đỏ. `tools/measure_envy_hunt.gd` đo thời gian quỷ tìm ra người chơi.

## Cách chạy

```sh
cd hub && npm start        # trình duyệt Cú Đêm + web + cổng LAN 8787
npm run start:game         # như trên, tự mở game
node hub/test/anchor.js    # mô phỏng định vị màn hình, 7 mục
node hub/test/game_link.js # Godot thật với web stack thật
godot --headless --path . --script tools/validate_progression.gd
```

Điện thoại: trong Cú Đêm vào `gaaglu.com/thiet-bi`, quét QR, bỏ qua cảnh báo chứng chỉ tự ký, bấm **Mở kênh**. Cần cùng Wi-Fi. Mã URL đổi mỗi lần chạy. Chứng chỉ lưu ở `~/.config/neh-school/lens-cert.json`.

## Kiến trúc

```text
Electron hub (hub/main.js)
├─ Cú Đêm: trình duyệt giả, chặn request bằng protocol.handle
├─ web stack hub/web/server.js, 127.0.0.1 cổng ngẫu nhiên, /game là WebSocket cho Godot
├─ cổng LAN HTTPS hub/web/lens.js, chuyển hình và tin nhắn điện thoại
└─ ~/.config/neh-school/hub.json: port + token để Godot tìm hub
```

| Phần | File |
|---|---|
| Trình duyệt, tab, ghé trang thật, Peter cáu | `hub/main.js`, `hub/shell/` |
| Tài khoản, theme, thoại | `hub/profiles.js` |
| Tìm kiếm thật bằng cửa sổ ẩn (DuckDuckGo HTML) | `hub/realweb.js` |
| Gaaglu, trộn kết quả, chặn từ khóa tự hại | `hub/web/sites.js` |
| Ba tờ báo hư cấu | `hub/web/news.js`, `news-data.js` |
| Phía game của hub | `scripts/arg_bridge.gd` |
| Render thế giới bên kia, stream | `scripts/phone_lens.gd` |
| Dấu và cổng xoay | `scripts/lens_markers.gd`, `assets/materials/lens_gate.gdshader` |
| Trang điện thoại | `hub/web/lens-page.*`, `lens-scan.js` (worker), `lens-anchor.js` (toán), `lens-xr.js` (WebXR) |
| Đồ họa | `scripts/visual_upgrade.gd`, `assets/materials/film_post.gdshader` |
| Ma học sinh | `scripts/humanoid_model.gd` nhánh `student`, `tools/build_student_textures.gd` |

## Ống kính hoạt động thế nào

1. Game mở lớp `OTHER_WORLD`: nhân bản các nhóm mesh dùng chung dữ liệu nhưng vật liệu thế giới linh hồn. Camera chính không thấy lớp này, camera phụ không thấy lớp thường. Con ma thử chỉ ở lớp này.
2. SubViewport render, nén JPEG, gửi qua `/game` tới hub rồi tới điện thoại, khoảng 22 hình/giây.
3. Chế độ AR: màn hình cổng hiện 6 dấu, người chơi rà điện thoại. Mỗi lần dò tạo tia từ camera tới góc dấu; `ScreenAnchor` tính vị trí 3D từng góc rồi khớp mặt phẳng. Đủ tiến độ thì gửi `calibrating:false, aim:true, anchored:true`, cổng nổ mở, dấu mất hẳn, ARCore giữ vị trí.
4. Chế độ dự phòng (không AR hoặc không có `camera-access`): giữ nút soi, dấu hiện mờ, dò liên tục, ghim bằng CSS matrix3d.

Trình tự người dùng đã chốt: phải biết camera thấy vùng nào của màn hình và chỉ vùng đó đổi thế giới; dấu phải ẩn hoàn toàn khi chơi; dấu được ngụy trang thành nghi thức "mở kênh tới thế giới bên kia".

## Quyết định thiết kế đã chốt

- **Co-op:** không làm 1 người chơi + 1 người lướt web. Hướng đề xuất đang bàn: 2 người cùng trong trường, mỗi người ở một thực tại, dùng điện thoại soi vào màn hình mình để thấy thế giới của người kia. Khóa luận cần co-op để show kỹ thuật. Người dùng từng nói có ý tưởng co-op riêng, rồi chốt theo hướng soi điện thoại. Giữ Đêm 1 là phần một người, co-op từ Đêm 2 ở chế độ tự do, host giữ quyền quyết định (ENet).
- **Vòng chơi đề xuất:** Ngày điều tra trên web, Đêm sống sót trong trường, Bình minh web đổi theo kết quả. 7 ngày, mỗi đêm một linh hồn. Làm trọn 2–3 đêm tốt hơn 7 đêm dang dở.
- **Thế giới:** tỉnh Hải Lâm, phường Cổ Đằng, khu phố Bến Trầu (nơi Peter Adam sống), đường Đồng Muối (Trường THPT NEH). Peter và đội là nhóm điều tra hiện tượng siêu nhiên bị kẹt trong lời nguyền.
- **Twist cuối:** web chạy trên chính máy người chơi; trong co-op là máy chủ phòng.
- **Web:** Gaaglu (tên miền `gaaglu.com`), Cú Đêm, kết quả thật trộn với tin trong game. Trang thật cho lướt và bấm, khóa bàn phím, Peter cáu theo ba nấc rồi tự quay lại.

## Ranh giới phải giữ

- Không sao chép logo, tên, giao diện của Chrome, Google, VnExpress, Tuổi Trẻ, Dân Trí, kể cả khi đổi màu. Người dùng từng yêu cầu chép UI báo: đã từ chối chép và làm bố cục riêng theo quy ước chung. Giữ cách đó.
- Người, trường, cơ quan, sự kiện trong game đều hư cấu. Không dùng tên trường có thật.
- Từ khóa tự hại luôn thoát khỏi thế giới giả, hiện thông tin hỗ trợ thật (111, 115).
- Không sửa file hosts, không cài CA, không autostart, không đụng file thật của người chơi.
- Chỉ dùng asset có giấy phép rõ (CC0, MIT, CC-BY), ghi vào `ASSETS.md`.
- Mọi cơ chế điện thoại phải có phương án chơi không cần điện thoại.

## Bẫy môi trường

- `ELECTRON_RUN_AS_NODE=1` được truyền từ VS Code: phải `unset` trước khi chạy Electron, nếu không báo lỗi `whenReady`.
- **Người dùng thường đang chạy `npm start` và Godot.** Không dùng `pkill -x godot` hay kill rộng. Trước khi kill, xác minh đúng PID của bài test. Tiến trình `node .../.bin/electron .` là của người dùng.
- Test song song với phiên của họ: đặt `NEH_LENS_PORT=8799`, `NEH_HUB_SESSION=<file tạm>`, và `HOME=<thư mục tạm>` cho Electron. Nếu không, test sẽ ghi đè và xóa `hub.json` của họ.
- Wrapper `godot` tìm binary theo `HOME`, nên không đổi `HOME` khi gọi godot.
- `pkill -f <mẫu>` khớp cả dòng lệnh shell của chính nó, làm lệnh chết với exit 144.
- Sửa `hub/web/lens-*.js|html` chỉ cần tải lại trang. Sửa `main.js`, `server.js`, `lens.js` phải chạy lại hub.
- WebXR không chạy được trên máy phát triển. Tách toán ra file thuần để test bằng node, phần còn lại cần người dùng thử.
- Test camera giả: Electron với `use-fake-device-for-media-stream` và `use-file-for-fake-video-capture=<file.mjpeg>`, ảnh mjpeg dựng từ `docs/lens-desktop.png` bóp phối cảnh. Script đó nằm ở scratchpad nên phải viết lại nếu cần. `tools/capture_lens.gd` chạy game thật và chụp ảnh.

## Trạng thái kiểm thử

- 4 validator lỗi có sẵn từ trước, không liên quan: `hiding`, `realm_scenery`, `survival`, `runtime` (đã so với commit cũ, lỗi y hệt).
- `validate_arg_bridge.gd` chỉ chạy qua `hub/test/game_link.js`.
- `school_runtime.tscn` có thể đã cũ so với `school.tscn`; F5 chạy bản runtime.

## Việc còn lại

**Ống kính:**
- Xác nhận AR trên điện thoại thật, chỉnh theo kết quả.
- Tạm dừng game khi cổng đang mở.
- Ma thử mới chỉ đi theo: nối vào AI ma thật, thêm âm thanh trên điện thoại.
- Đồ dời chỗ trong thế giới linh hồn chưa khớp, cửa chưa có bản linh hồn, bấm B khi đang soi chưa xử lý, ma vẫn đi khi Esc.
- Sau hiệu chỉnh, `aim` bật liên tục nên game luôn render thêm camera phụ. Chưa có trạng thái "đang soi hay không", ví dụ dựa vào việc màn hình có nằm trong khung camera.

**Đồ họa:**
- Người dùng muốn đổi luôn model Lan, An, đồng đội; Rocketbox còn Female_Child và nhiều avatar khác.
- Chưa có tay cầm đèn pin. Đèn hiện là loại xách vàng, khá to.
- Bịt mắt Kẻ Dò Tiếng và mặt nạ Kẻ Rỉ Tai chưa kiểm tra trên model mới.
- Cây và nội thất Kenney vẫn khối. Máy không Vulkan sẽ lùi về OpenGL.

**Web:**
- Chưa có màn hình thông báo riêng tư và nút tắt web thật. Bắt buộc trước khi cho người ngoài chơi.
- Chưa có kết quả mẫu khi DuckDuckGo chặn bot (đã từng bị chặn tạm thời). Không phát hành công khai với cửa sổ ẩn.
- Báo chưa đổi theo tiến độ game. Ảnh báo là hình code vẽ, cần ảnh hư cấu thật.
- Hộp chọn file trên trang thật và bộ gõ Telex chưa kiểm tra.

**Gameplay:**
- Nhận phản hồi về khu phố, rồi viết Đêm 2 để nối thành vòng trọn Ngày, Đêm.
- Thử co-op kỹ thuật: hai người thấy nhau, ma đuổi người gần nhất, mỗi người một thế giới.
- Thêm preset Windows; hiện chỉ có Linux.

## Shop, cú vồ của quỷ Ghen Tị

- `scripts/night_gear.gd`: tiền (nghìn đồng), túi 4 ô, đồ bị cướp; lưu `user://night_gear.cfg`, chỉ chốt khi thắng đêm nên chơi lại không bị phạt hai lần.
- Tiệm không tên ở Hẻm 5 (`curio` trong `town_plan.gd`, không hiện trên bản đồ), giao diện `scripts/town/town_shop.gd`. Bà Sáu và chị Mai gợi ý đường tới.
- `envy_demon.gd`: mọi cú bắt đều là chụp lên (GRAB). Bắn súng muối bằng chuột trái → quỷ STAGGER rồi lui, A im 19 s, người chơi có adrenaline 8 s. Không bắn → lấy đồ giá trị nhất (huy chương, rồi máy ảnh) và thả. Không có gì → chết. Đèn pin không bao giờ bị lấy; đồ bị lấy chuộc lại ở tiệm bằng nửa giá.
- Test: `tools/validate_gear.gd`. Ảnh: `tools/capture_gear.gd`. Cây phố: `tools/build_town_tree.py`.

## Chuỗi web của An

Gaaglu → `thptneh.edu.vn` → Văn bản → danh sách dự thi cho số định danh `097193004217`; bài giải Cờ vua cho đáp án. Hai thứ này mở hồ sơ ở `dancu.hailam.gov.vn`. Mã tỉnh 097 không thuộc tỉnh thật nào. Cổng không dùng quốc huy hay tên cơ quan thật. Chưa có tín hiệu gửi về game khi người chơi mở hồ sơ.

## Ngày, cờ vua, phố

- Đêm 0 kết thúc lúc 01:06, ngủ tới 07:00. Đồng hồ ngày ở `town_world.gd`: chỉ trôi 1 phút mỗi 30 giây khi người chơi di chuyển, còn lại do hoạt động tiêu. Hết 22:00 tự vào đêm.
- Đơn vị tiền là $. `scripts/chess/`: luật (perft ở `tools/validate_chess_rules.gd`), bot, bàn cờ 3D, ba đối thủ (`chess_people.gd`), giao diện (`chess_view.gd`). Test chơi thật: `tools/validate_chess_play.gd`.
- `scripts/town/town_life.gd`: người đi bộ, loa phường, hoạt động trên phố. Phở, cà phê tăng `boosts`, giảm tiêu stamina trong đêm.

## Tiền truyện

F5 giờ vào `scenes/home.tscn` lúc 19:40: Peter (nhóm điều tra cùng Minh, Khoa) thuê số 14 Hẻm 31 để theo dõi Trường NEH, không biết đây là nhà cũ của An (`registry.js`). Lướt Làng Ta trên điện thoại, chốt với nhóm, ra cửa, rồi mới vào cảnh mở đầu Đêm 0. Bài đăng dùng chung ở `data/social_posts.json` cho điện thoại và web `langta.vn`.
