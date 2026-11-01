# NEH Hub

Trình duyệt giả "Cú Đêm", web stack local và kết nối với game.

```sh
cd hub
npm install
npm start            # chỉ trình duyệt; mở game riêng bằng F5 trong Godot
npm run start:game   # trình duyệt + tự chạy game
npm run web          # chỉ web stack, cổng 5173, không cần Electron
node test/game_link.js   # kiểm tra Godot thật với web stack thật
```

- `main.js`: cửa sổ, tab, chặn request tới tên miền giả rồi chuyển vào web stack.
- `shell/`: giao diện trình duyệt.
- `web/server.js`: web stack và WebSocket `/game`, gắn với `127.0.0.1`, cần token.
- `web/sites.js`: nội dung các trang và danh sách tên miền giả; hiện chỉ còn trang chủ tìm kiếm.
- `profiles.js`: tài khoản đang đăng nhập, theme giao diện và câu suy nghĩ khi ghé trang thật.
- `realweb.js`: đọc kết quả tìm kiếm thật bằng cửa sổ ẩn (DuckDuckGo HTML).
- `../scripts/arg_bridge.gd`: phía game; đọc `~/.config/neh-school/hub.json` để tìm hub.

Giao thức: game gửi `{type:"state", evidence:[...], stage:"..."}`; hub gửi `{type:"door_bang"}`; game đổi tài khoản bằng `{type:"profile", id:"an"}`.

Nếu Electron báo `Cannot read properties of undefined (reading 'whenReady')`, chạy `unset ELECTRON_RUN_AS_NODE` rồi thử lại.
