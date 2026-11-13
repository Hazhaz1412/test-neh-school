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

R xếp lại bảng của đảo hiện tại. Rơi xuống vực thì về đầu câu đố đang chơi. Kiểm tra: `tools/validate_dream.gd` (headless, giải hết năm câu và thử cả cách sai); ảnh: `tools/capture_dream.gd` ra `docs/dream-*.png`.

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
