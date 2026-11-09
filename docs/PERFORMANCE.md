# Hiệu năng / 2026-10-03

Đã đo bằng Godot 4.7.2 Compatibility, GPU NVIDIA GeForce RTX 3060, cửa sổ 1280 × 720. Bản sau dùng **Cân bằng**, scale 3D 1.0. Tắt VSync và giới hạn FPS trong công cụ đo. Đây là số đo khung hình ở camera cố định, không phải cam kết FPS trên mọi máy.

## Kết quả

| Cảnh | Trung vị trước (ms) | Trung vị sau (ms) | P95 trước → sau (ms) | Lượt vẽ trước → sau |
| --- | ---: | ---: | ---: | ---: |
| Sân trường / thường | 34.23 | 7.98 | 40.73 → 9.56 | 25,552 → 4,586 |
| Hành lang A / thường | 33.43 | 7.91 | 43.98 → 9.75 | 24,220 → 4,627 |
| Thư viện B / thường | 7.42 | 1.61 | 9.18 → 2.58 | 3,692 → 589 |

Node trong cây khi khởi tạo: 24,003 → 9,233. Dữ liệu gốc: [trước](performance-before.json), [sau](performance-after.json).

Mỗi camera có 1,2 giây làm nóng và 1,8 giây lấy mẫu. Thời gian khung hình dùng đồng hồ thực giữa các frame; bảng báo trung vị và P95. Dừng physics của người chơi để giữ bố cục ổn định, nhưng animation và hiệu ứng vẫn chạy. Vì vậy bảng chủ yếu đo render và phần cập nhật nền; gameplay truy đuổi được kiểm tra bằng validation riêng. Số liệu CPU/physics trong JSON là monitor Godot, không dùng chúng để suy ra FPS. Không đo cold-start hoặc tải ở máy cấu hình thấp.

## Thay đổi

- Gộp 8.061 mesh tĩnh thành 1.347 MultiMesh theo ô X/Z 16 m, tách tầng theo cao độ 3,9 m. Giữ vật liệu và vùng bounds để culling; chuẩn hóa BoxMesh và dùng lại vật liệu trùng nhau. Cách instancing dựa trên [tài liệu MultiMesh của Godot](https://docs.godotengine.org/en/stable/classes/class_multimesh.html).
- Gộp 3.562 body tĩnh thành 194 vùng, giữ từng CollisionShape, transform và layer. Collider kính giữ riêng để ray nhìn xuyên kính; cửa trượt và trigger tương tác giữ riêng.
- Bật đèn gần người chơi theo ngân sách 8/12/24, cập nhật mỗi 0,35 giây. Ống đèn phát sáng vẫn hiển thị xa. Nhẹ tắt bóng trăng/đèn pin, render 3D ở 75%; Cân bằng/Cao giữ độ phân giải gốc và tăng phạm vi/chất lượng bóng.
- Mesh tro và giọt nước giảm số đoạn/ring. Tránh shader toàn màn hình khi thế giới thường không có hiệu ứng trúng đòn; cache đèn chập chờn; kiểm tra cửa/actor mỗi 0,2 giây.
- **F6** đổi chất lượng, lưu lựa chọn. **F7** hiện FPS và lượt vẽ khi chơi.

## Giữ scene chỉnh sửa và scene chạy

`scenes/school.tscn` giữ các node riêng để chỉnh map và GLB. F5 dùng `scenes/school_runtime.tscn`, sinh từ scene gốc bằng `tools/runtime_optimizer.gd`. Không sửa tay scene runtime: build map, bake navigation và `tools/optimize_map.gd` đều ghi lại nó.

Bản runtime có `scripts/static_multimesh.gd` lưu mảng placement trên resource, thay vì dựa vào buffer GPU của renderer headless. Điều này sửa lỗi scene tối ưu bị mất tường/sàn/cây khi tải lại. Đã chụp và kiểm tra ảnh bằng renderer thật sau khi sửa; số đo “sau” trong bảng là bản có đầy đủ hình học.

```sh
godot --headless --path . --script tools/optimize_map.gd
godot --headless --path . --script tools/validate_runtime.gd
godot --path . --script tools/validate_runtime.gd --resolution 1280x720
godot --path . --script tools/profile_performance.gd --resolution 1280x720 -- /tmp/neh-performance.json
```

Validation runtime đối chiếu **tất cả** placement/kích thước mesh và shape/transform/layer collider với scene gốc, danh mục phòng, ngân sách đèn ba mức, đèn gần người chơi và F7. Với display, còn đối chiếu từng placement với transform thực của GPU. Các validation map và annex đã qua cho đường đi, cửa, cầu thang và sân thượng. Preview mới: [sân trường](campus-preview.png), [hành lang nối](connector-preview.png), [sân thượng](rooftop-preview.png).

Các mốc đo sau đó (thế giới linh hồn, 13 thực thể) đã bỏ cùng với các hệ thống đó ngày 2026-11-09. Đo lại bằng `tools/profile_performance.gd` khi cần số mới.
