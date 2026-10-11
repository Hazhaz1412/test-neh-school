# Bản gửi chơi thử Linux / Windows

`dist/NEH-School-Linux-Windows-x64.7z` là gói nhỏ nhất đã tạo (khoảng 45 MiB). ZIP khoảng 72 MiB là lựa chọn giải nén phổ biến. Mỗi file nén chứa cả hai nền tảng x64; hai executable dùng chung PCK có SHA-256 giống nhau, không nhân đôi dữ liệu map/assets. Tổng khi giải nén khoảng 189 MiB. Giải nén cả thư mục, chạy `.exe` trên Windows hoặc `.x86_64` trên Linux; README kèm hướng dẫn và quyền execute. Không cần Godot/.NET.

Release dùng template standard GDScript 4.7.2, không phải Mono. Template được tải từ release chính thức bằng HTTP Range, chỉ lấy Linux/Windows release và kiểm CRC ZIP. Cache local ở `.export_templates/4.7.2.stable`, có `.gdignore` và gitignore. Export bỏ ảnh kiểm thử/tài liệu/tools/scene xây dựng; giữ sáu ảnh bảng điều tra, assets runtime, script gameplay và JSON bốn ký ức.

Cầu nối AI Python được kèm ngoài PCK, tự tìm cạnh executable. Không copy file cấu hình hoặc API key riêng. Người thử cần Python 3, Internet và API key riêng nếu muốn hoàn tất hội thoại; nếu chưa cấu hình, gameplay vẫn chạy và menu TEST cho kiểm tra kết thúc. Chi tiết nằm trong README của gói. Không có điểm AI giả.

Đã chạy binary Linux thật và Windows qua Wine trên màn hình ảo riêng: mở đầu đủ ảnh/model, Enter, vào đêm bằng H+P, HUD/ma/scene, Esc. Windows chưa kiểm chứng trên máy Windows vật lý. Ảnh và manifest/checksum nằm trong `dist/`. Hai archive đã kiểm tra giải nén/CRC thành công.

Build lại với cache hiện có:

```sh
godot --headless --path . --export-release Linux dist/staging/NEH-School/NEH-School.x86_64
godot --headless --path . --export-release Windows dist/windows-build/NEH-School.exe
```

So SHA-256 hai PCK trước khi dùng chung; copy exe Windows sang staging, giữ cầu nối, data, README, CREDITS và license engine rồi nén staging. Cập nhật checksum sau mỗi lần build. Các template cache và artifacts không được đưa vào PCK.
