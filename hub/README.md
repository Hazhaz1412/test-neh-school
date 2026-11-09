# NEH Hub

Trình duyệt giả "Cú Đêm", web stack local và kết nối với game.

```sh
cd hub
npm install
npm start            # chỉ trình duyệt; mở game riêng bằng F5 trong Godot
npm run start:game   # trình duyệt + tự chạy game
npm run web          # chỉ web stack, cổng 5173, không cần Electron
node test/game_link.js   # kiểm tra Godot thật với web stack thật
node test/webs.js        # các trang giả qua HTTP thật
node test/desktop.js     # lối tắt desktop, trong HOME tạm
```

- `main.js`: cửa sổ, tab, chặn request tới tên miền giả rồi chuyển vào web stack.
- `shell/`: giao diện trình duyệt.
- `web/server.js`: web stack và WebSocket `/game`, gắn với `127.0.0.1`, cần token.
- `web/sites.js`: Gaaglu (tìm kiếm, trộn kết quả thật với trang giả) và danh sách tên miền giả.
- `web/news.js`, `web/news-data.js`: ba tờ báo hư cấu, hiện chỉ có tin đời thường làm nền; mọi bài được tìm qua Gaaglu.
- `web/social.js` (Làng Ta, `langta.vn`) và `web/soichi.js` (Sợi Chỉ, `soichi.vn`): mạng xã hội hư cấu. Bài đăng ở `../data/social_posts.json` (dùng chung với app Fake trong game) và `../data/soichi_posts.json`, đang trống chờ cốt truyện mới.
- `web/school.js`: website Trường THPT NEH (`thptneh.edu.vn`), dừng ở cuối năm 2009.
- `web/registry.js`: cổng dữ liệu dân cư hư cấu của tỉnh Hải Lâm (`dancu.hailam.gov.vn`). Những gì người chơi nhập chỉ được so sánh rồi bỏ, không lưu, không ghi log.
- `profiles.js`: tài khoản đang đăng nhập (Peter), theme giao diện và câu suy nghĩ khi ghé trang thật.
- `web/phone.js`, `web/phone-page.*`: kênh ghép điện thoại qua LAN.
- `desktop.js`: lối tắt Gaaglu và ghi chú trên desktop, chỉ khi người chơi đồng ý trong game; `npm run remove-desktop` để gỡ.
- `realweb.js`: đọc kết quả tìm kiếm thật bằng cửa sổ ẩn (DuckDuckGo HTML).
- `../scripts/arg_bridge.gd`: phía game; đọc `~/.config/neh-school/hub.json` để tìm hub.

Giao thức: game gửi `{type:"state", evidence:[...], stage:"..."}` và `{type:"install_gaaglu", consent:true}`; hub gửi `{type:"door_bang"}`, `{type:"phone", on}` khi điện thoại ghép hoặc rời, `{type:"phone_input", ...}` cho dữ liệu từ điện thoại, `{type:"contact", id}` khi người chơi nhắn một liên hệ trên Sợi Chỉ.

## Ghép điện thoại

Chạy `npm start`. Vào `gaaglu.com/thiet-bi` trong Cú Đêm để lấy mã QR, hoặc lấy địa chỉ in ở terminal. Điện thoại phải cùng Wi-Fi với máy này, bấm bỏ qua cảnh báo chứng chỉ tự ký. Trang điện thoại hiện chỉ báo đã ghép; game nhận `phone_paired` trong `arg_bridge.gd`. Phần ống kính soi thế giới bên kia (WebXR, dấu ArUco) đã bỏ cùng hướng kinh dị. Cổng mặc định 8787, đổi bằng `NEH_PHONE_PORT`.

Nếu Electron báo `Cannot read properties of undefined (reading 'whenReady')`, chạy `unset ELECTRON_RUN_AS_NODE` rồi thử lại.
