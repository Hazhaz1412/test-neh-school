# NEH Hub

Trình duyệt giả "Cú Đêm", web stack local và kết nối với game.

```sh
cd hub
npm install
npm start            # chỉ trình duyệt; mở game riêng bằng F5 trong Godot
npm run start:game   # trình duyệt + tự chạy game
npm run web          # chỉ web stack, cổng 5173, không cần Electron
node test/game_link.js   # kiểm tra Godot thật với web stack thật
node test/webs.js        # web trường và cổng dân cư qua HTTP thật
```

- `main.js`: cửa sổ, tab, chặn request tới tên miền giả rồi chuyển vào web stack.
- `shell/`: giao diện trình duyệt.
- `web/server.js`: web stack và WebSocket `/game`, gắn với `127.0.0.1`, cần token.
- `web/sites.js`: nội dung các trang và danh sách tên miền giả; hiện chỉ còn trang chủ tìm kiếm.
- `web/news.js`, `web/news-data.js`: ba tờ báo hư cấu và bài viết tạm; mọi bài được tìm qua Gaaglu.
- `web/school.js`: website Trường THPT NEH (`thptneh.edu.vn`), dừng ở cuối năm 2009.
- `web/registry.js`: cổng dữ liệu dân cư hư cấu của tỉnh Hải Lâm (`dancu.hailam.gov.vn`). Những gì người chơi nhập chỉ được so sánh rồi bỏ, không lưu, không ghi log.
- `profiles.js`: tài khoản đang đăng nhập, theme giao diện và câu suy nghĩ khi ghé trang thật.
- `realweb.js`: đọc kết quả tìm kiếm thật bằng cửa sổ ẩn (DuckDuckGo HTML).
- `../scripts/arg_bridge.gd`: phía game; đọc `~/.config/neh-school/hub.json` để tìm hub.

Giao thức: game gửi `{type:"state", evidence:[...], stage:"..."}`; hub gửi `{type:"door_bang"}`; game đổi tài khoản bằng `{type:"profile", id:"an"}`.

## Ống kính điện thoại

Chạy `npm start`, rồi mở game bằng F5. Vào `gaaglu.com/thiet-bi` trong Cú Đêm để lấy mã QR, hoặc lấy địa chỉ in ở terminal. Điện thoại phải cùng Wi-Fi với máy này, bấm bỏ qua cảnh báo chứng chỉ tự ký, rồi soi camera vào màn hình game. Cổng mặc định 8787, đổi bằng `NEH_LENS_PORT`.

Nếu Electron báo `Cannot read properties of undefined (reading 'whenReady')`, chạy `unset ELECTRON_RUN_AS_NODE` rồi thử lại.
