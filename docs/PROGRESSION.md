# Những nhánh mở đường tới An

Bốn hệ thống có thể bắt đầu theo bất kỳ thứ tự nào, trước cả chìa tổng. Đổi bàn, bị đánh hoặc rời giao diện giữ nguyên thao tác. Thời gian và ma tiếp tục hoạt động; Esc rời bàn, sát thương/QTE ngắt tương tác. R/lượt mới đặt lại mọi thứ. NPC bàn cờ chỉ xuất hiện trong thế giới linh hồn.

| Nhánh | Nơi tương tác | Thao tác | Thay đổi trong cảnh |
| --- | --- | --- | --- |
| ϟ Điện | Nhà kho phía Tây | Click chuyển mạch tắt/A/B. Bốn tải ★ phải cùng hoạt động, mỗi bus ≤5A. | Bóng đèn và đèn điện hộp chìa sáng. |
| ↗ Điều khiển | Sảnh A, bên phải cầu thang | Vạch đường trên lưới có vật cản và trọng số; chỉ tuyến có chi phí tối ưu được truyền. | Mở cửa chắn hành lang A–B trên cả ba tầng. |
| ≋ Bơm | Sân dịch vụ, phía Tây B | Xoay ống, thử van; nước phải tới cống qua đầu nối khớp và không rò. | Mở lối vào B từ sân dịch vụ; tháo nước kho lưu trữ B tầng 2 và mở cửa phòng này. |
| ×○ Bàn cờ | Sảnh A, bên trái cầu thang | Cờ caro 5×5, nối 4 quân, NPC đáp từng lượt; thắng hoặc hòa nhận phần mã. Thua có thể chơi lại. | Quân trên bàn thay đổi, NPC gật đầu, đèn mã khóa sáng. |

Hai nhánh ↗ và ≋ mở **hai đường khác nhau vào B**; không cần làm điện trước. Chìa tổng vẫn ở kho, mở phòng A và các phòng B khi đã có một đường vào B. Có thể tìm ký ức A trong lúc chưa sửa xong các hệ thống. Nhặt đủ ký ức không mở khóa sân thượng hay tự cứu An.

Bốn dây và bốn đèn trên hộp chìa ở đầu cầu thang sân thượng phản ánh từng nhánh. Khi cả bốn sáng, E lấy chìa sân thượng từ phía trong cầu thang; E vào cửa sắt để mở. Cửa thực sự chắn toàn bộ lối ra mái phía Đông. An ở vị trí sân thượng cũ, nơi không có quái. Cứu em ấy cần bốn ký ức và bốn phản hồi an ủi được AI chấp nhận; vẫn phải sống tới 06:00. Đêm giữ thời lượng 12 phút.

Tiếng khóc CC0 có nguồn tại An và hai miệng thông cầu thang, định vị theo khoảng cách. Không phát “tiếng người chơi” để đánh lừa AI ma. Dừng trong thế giới thường, khi An được cứu, tạm dừng hoặc hết đêm. Xem nguồn và xử lý âm thanh ở ASSETS.md.

Game chỉ có biểu tượng thiết bị, đèn đổi màu, dây dẫn, nước và cửa mở để kể tiến độ. Hướng dẫn thao tác nằm trong bàn minigame; thuật toán chỉ hiện khi chọn **Xem kỹ thuật**. Dijkstra chạy từng bước để xem các ô được duyệt, BFS đếm mạng ống thực sự có nước, NPC dùng Minimax với alpha-beta và gợi ý một nước đi. Không có nút giải tự động.

H+P vẫn là bypass có nhãn TEST: mở mọi nhánh/cửa và cấp chìa sân thượng, giữ An để thử hội thoại. Điểm AI không được tạo giả. Các bài test cũ về hội thoại, mái và tuần tra dùng fixture mở tiến trình để kiểm tra riêng các chức năng đó.

## Kiểm chứng

`tools/validate_progression.gd` kiểm tra mỗi nhánh mở trước những nhánh khác/chìa tổng, tiến độ xen kẽ, quá tải, đường tối ưu đối chiếu độc lập, ống kín, NPC chặn/thắng và ván cờ thật, ray/capsule cửa mái, chìa vật lý, tiếng khóc/pause/rescue, reset và bypass. `tools/capture_progression.gd` chạy trên display thật, nhập E, chuột, R, Esc, kiểm tra đồng hồ và lưu ảnh. Cửa chắn dùng MultiMesh (hai draw mỗi cửa), không thêm đèn realtime hoặc rebake campus.
