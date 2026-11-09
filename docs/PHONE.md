# Điện thoại trong game

Điện thoại của Peter ở nhà (`scenes/home.tscn`). Giao diện theo quy ước điện thoại hiện đại nhưng không dùng tên, logo hay hình của hãng có thật.

## Cầm như điện thoại thật

- **Tab** nâng máy lên: máy trồi lên từ dưới góc phải, nghiêng rồi dựng thẳng ở giữa màn hình. Căn phòng phía sau mờ và tối đi, đầu nhân vật cúi xuống nhìn máy (`home_player.glance`, FOV thu lại).
- Màn hình sáng lên ở **màn khóa** (giờ, ngày, ổ khóa). Sau khoảng 0,75 giây máy tự mở khóa (nhận diện khuôn mặt); vuốt lên thì mở ngay. Khi mở khóa, màn khóa trượt lên và màn hình chính lùi vào đúng chỗ.
- **App mở ra từ icon** và thu về đúng icon khi thoát. Bấm icon có độ lún; app trang trí thì lắc nhẹ.
- **Vuốt lên từ thanh dưới** để về màn hình chính; trang đang mở co lại theo ngón tay trước khi thả.
- **Danh sách cuộn bằng kéo**: kéo chuột lên xuống như vuốt, thả tay thì trôi theo quán tính rồi dừng dần. Kéo quá đầu hoặc cuối thì danh sách giãn ra rồi bật về. Con lăn chuột cũng đẩy trôi. Thanh cuộn mảnh chỉ hiện khi đang cuộn. Kéo bắt đầu trên một dòng chat không bị tính là bấm.
- **Tab, Esc** hoặc bấm ra ngoài máy để cất: màn hình tắt trước, máy hạ xuống, căn phòng rõ lại.

## App

| App | Nội dung | Dữ liệu |
| --- | --- | --- |
| Fake | Bảng tin mạng xã hội, dùng chung bài với trang `langta.vn` | `data/social_posts.json` |
| Tili | Chat: danh sách đoạn chat và khung chat, có trả lời nhanh | do kịch bản thêm (`phone.add_thread`, `receive`, `offer_replies`) |

Các đoạn chat và bài đăng của cốt truyện cũ đã xóa. Khi trống, Fake hiện "Chưa có bài viết nào", Tili hiện "Chưa có đoạn chat nào". Cốt truyện mới thêm bài vào `social_posts.json` và gọi API của `home_phone.gd` từ `scripts/home/home_story.gd`.

## Code

| File | Vai trò |
| --- | --- |
| `scripts/home/home_phone.gd` | Vỏ máy, màn khóa, màn hình chính, nâng/hạ, cử chỉ vuốt, thông báo |
| `scripts/home/phone/phone_scroll.gd` | Danh sách cuộn kiểu điện thoại: kéo, quán tính, giãn ở mép, thanh cuộn |
| `scripts/home/phone/phone_fake.gd` | App Fake |
| `scripts/home/phone/phone_tili.gd` | App Tili |
| `scripts/home/phone/phone_kit.gd` | Hộp bo góc, chữ, avatar, icon vẽ tay |
| `assets/materials/phone_backdrop.gdshader` | Làm mờ và tối căn phòng sau máy |

Hằng số chỉnh cảm giác: `LIFT_*`, `UNLOCK_AFTER`, `SWIPE_HOME` trong `home_phone.gd`; `FRICTION`, `STRETCH`, `SPRING`, `WHEEL_KICK` trong `phone_scroll.gd`.

## Kiểm tra

```sh
godot --path . --script tools/validate_phone.gd --resolution 1600x900   # chuột giả lập thật, 19 kiểm tra
godot --path . --script tools/capture_phone.gd --resolution 1600x900    # ảnh docs/phone-*.png
```

`validate_phone.gd` gửi sự kiện chuột qua `Input.parse_input_event` theo tọa độ cửa sổ (dự án có co giãn canvas), nên cần display, không chạy headless.
