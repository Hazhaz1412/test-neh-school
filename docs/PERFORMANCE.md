# Hiệu năng / 2026-10-03

Đã đo bằng Godot 4.7.2 Compatibility, GPU NVIDIA GeForce RTX 3060, cửa sổ 1280 × 720. Bản sau dùng **Cân bằng**, scale 3D 1.0. Tắt VSync và giới hạn FPS trong công cụ đo. Đây là số đo khung hình ở camera cố định, không phải cam kết FPS trên mọi máy.

## Kết quả

| Cảnh | Trung vị trước (ms) | Trung vị sau (ms) | P95 trước → sau (ms) | Lượt vẽ trước → sau |
| --- | ---: | ---: | ---: | ---: |
| Sân trường / thường | 34.23 | 7.98 | 40.73 → 9.56 | 25,552 → 4,586 |
| Hành lang A / thường | 33.43 | 7.91 | 43.98 → 9.75 | 24,220 → 4,627 |
| Thư viện B / thường | 7.42 | 1.61 | 9.18 → 2.58 | 3,692 → 589 |
| Sân trường / linh hồn | 35.83 | 8.74 | 40.50 → 11.07 | 25,813 → 4,816 |
| Hành lang A / linh hồn | 35.68 | 8.93 | 42.07 → 11.00 | 24,714 → 4,902 |
| Thư viện B / linh hồn | 7.81 | 1.92 | 9.89 → 2.90 | 3,692 → 590 |

Node trong cây khi khởi tạo: 24,003 → 9,233. Dữ liệu gốc: [trước](performance-before.json), [sau](performance-after.json).

Mỗi camera có 1,2 giây làm nóng và 1,8 giây lấy mẫu. Thời gian khung hình dùng đồng hồ thực giữa các frame; bảng báo trung vị và P95. Dừng physics của người chơi và ma để giữ bố cục ổn định, nhưng animation và hiệu ứng vẫn chạy. Vì vậy bảng chủ yếu đo render và phần cập nhật nền; gameplay truy đuổi được kiểm tra bằng validation riêng. Số liệu CPU/physics trong JSON là monitor Godot, không dùng chúng để suy ra FPS. Không đo cold-start hoặc tải ở máy cấu hình thấp.

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

Validation runtime đối chiếu **tất cả** placement/kích thước mesh và shape/transform/layer collider với scene gốc, danh mục phòng, ngân sách đèn ba mức, đèn gần người chơi và F7. Với display, còn đối chiếu từng placement với transform thực của GPU. Các validation map, annex, spirit đã qua cho đường đi, cửa, cầu thang/sân thượng và AI. Preview mới: [sân trường](campus-preview.png), [hành lang nối](connector-preview.png), [linh hồn](spirit-world-preview.png), [sân thượng](rooftop-preview.png).

## Thế giới linh hồn biến dạng / nhiệm vụ chìa tổng

Đo lại sau khi thêm học sinh có pose/đồng phục mới, vật liệu mục, props biến dạng, manifestation và âm thanh. Cùng GPU RTX 3060, 1280 × 720, Cân bằng. Cây scene khi khởi tạo có 9.392 node; map gộp 8.063 mesh thành 1.453 nhóm, 3.563 body thành 194 vùng.

| Cảnh | Trung vị (ms) | P95 (ms) | Lượt vẽ |
| --- | ---: | ---: | ---: |
| Sân trường / thường | 8.09 | 10.01 | 4,836 |
| Hành lang A / thường | 8.32 | 10.14 | 4,859 |
| Thư viện B / thường | 1.66 | 2.56 | 605 |
| Sân trường / linh hồn | 9.64 | 12.02 | 5,383 |
| Hành lang A / linh hồn | 10.02 | 14.37 | 5,406 |
| Thư viện B / linh hồn | 2.23 | 3.19 | 687 |

Dữ liệu: [performance-horror.json](performance-horror.json). Cùng giới hạn camera cố định/AI dừng nêu trên. Các biến thể MM và collider đổi khi B, không chạy hàng nghìn transform mỗi frame; texture diffuse 1K và hai loop mono nhỏ giữ tải nhẹ. Bảng trước/sau phía trên là mốc của bản tối ưu ban đầu.

## Truy đuổi dữ hơn và 47 chỗ nấp

Bản này có 47 cover có collider, hai âm thanh định hướng ngắn và AI nhìn/đợt lao/kiểm tra nơi nấp. Mesh và collider cover được gộp vào runtime; script, label và Area tương tác giữ riêng. Tổng 8.448 mesh → 1.548 batch, 3.882 body → 228 vùng; 10.095 node khi khởi tạo.

Cùng RTX 3060, 1280 × 720, Cân bằng và phương pháp camera cố định/AI dừng ở trên. Bảng so sánh cover riêng lẻ và cover đã gộp; các thay đổi AI được kiểm tra gameplay riêng.

| Cảnh | Cover riêng lẻ (ms) | Đã gộp (ms) | P95 đã gộp (ms) | Lượt vẽ riêng → gộp |
| --- | ---: | ---: | ---: | ---: |
| Sân trường / thường | 10.38 | 8.20 | 9.96 | 5,778 → 5,136 |
| Hành lang A / thường | 10.36 | 8.59 | 11.57 | 5,735 → 5,135 |
| Thư viện B / thường | 1.64 | 1.54 | 2.55 | 605 → 605 |
| Sân trường / linh hồn | 11.61 | 9.88 | 11.93 | 6,326 → 5,684 |
| Hành lang A / linh hồn | 11.97 | 10.04 | 12.11 | 6,292 → 5,684 |
| Thư viện B / linh hồn | 2.25 | 2.09 | 2.98 | 687 → 687 |

Dữ liệu: [cover riêng lẻ](performance-hiding-unbatched.json), [cover đã gộp](performance-hiding.json). Khoảng 2 ms render tăng thêm do cover riêng lẻ được giảm sau khi gộp. Không suy ra FPS gameplay trên mọi máy từ số đo camera cố định này.

## 13 thực thể và hệ thống sinh tồn / 2026-10-04

Thêm 5 thực thể chuyên biệt, 10 vật phẩm hữu hạn, cổng thoát, HUD tài nguyên và audio chuông/hơi thở/chorus. Không thêm đèn realtime hoặc thay đổi hình học tĩnh; giữ batch/collider của bản chỗ nấp.

Đo riêng sau khi các validation kết thúc, trên cùng RTX 3060, 1280 × 720, Cân bằng. Có 10.159 node khi khởi tạo, trước khi spawn thực thể. Trong các góc linh hồn có đủ 13 thực thể; physics của chúng và người chơi dừng để giữ camera/bố cục, animation và cập nhật nền vẫn chạy. Đây là phép đo render ở preview B, không đo toàn bộ truy đuổi/chuông của lượt N.

| Cảnh | Trung vị (ms) | P95 (ms) | Lượt vẽ |
| --- | ---: | ---: | ---: |
| Sân trường / thường | 8.24 | 12.32 | 5.185 |
| Hành lang A / thường | 8.68 | 12.48 | 5.185 |
| Thư viện B / thường | 1.68 | 2.74 | 611 |
| Sân trường / linh hồn | 10.92 | 14.95 | 5.977 |
| Hành lang A / linh hồn | 10.65 | 13.92 | 5.918 |
| Thư viện B / linh hồn | 2.52 | 4.49 | 695 |

Dữ liệu: [performance-survival.json](performance-survival.json). So với mốc 8 ma/47 chỗ nấp, render sân trong linh hồn tăng khoảng 1 ms trung vị. Các cơ chế nghe/nấp/va chạm/stun và toàn bộ vòng chìa → cổng đã qua `tools/validate_survival.gd` bằng renderer thật; hiding, quest, spirit và runtime vẫn có 0 lỗi. Chưa đo FPS gameplay trên máy cấu hình thấp.

## Mở đầu, model Quaternius và tường bao cao / 2026-10-04

Tường bao 3,6 m và cổng sắt vẫn nằm trong batch tĩnh; riêng cánh cửa bảo trì có collider chuyển động được giữ ngoài batch. Map hiện gộp 8.423 mesh thành 1.559 nhóm và 3.774 body thành 224 vùng; cây scene ban đầu có 10.071 node. Bộ phim và phòng điều tra sinh khi bắt đầu, dọn sau handoff; ba đồng đội được dọn ở nửa đêm. Model FBX nguồn chỉ tải ba biến thể cần dùng, mesh/animation sửa được cache; không thêm đèn cho gameplay thường.

Đo bản cuối bằng Godot Compatibility, RTX 3060, 1280 × 720, Cân bằng, cùng phương pháp camera cố định/AI dừng nêu trên. Đã kết thúc validation trước khi đo. Dữ liệu [performance-opening.json](performance-opening.json); đây là render preview với 13 thực thể, không phải FPS truy đuổi thực tế hoặc phép đo đoạn phim.

| Cảnh | Trung vị (ms) | P95 (ms) | Lượt vẽ |
| --- | ---: | ---: | ---: |
| Sân trường / thường | 8.74 | 13.79 | 5,185 |
| Hành lang A / thường | 8.78 | 12.05 | 5,185 |
| Thư viện B / thường | 2.19 | 3.44 | 616 |
| Sân trường / linh hồn | 16.21 | 28.13 | 5,832 |
| Hành lang A / linh hồn | 12.63 | 25.24 | 5,812 |
| Thư viện B / linh hồn | 4.42 | 6.80 | 700 |

Các validation opening, survival, spirit, hiding, quest, map, annex, realm scenery và runtime đều có 0 assertion lỗi. Survival và runtime còn chạy bằng renderer thật. Kiểm tra mở đầu dùng capsule thật qua cửa bảo trì và bị chắn khi cửa đóng, kể cả ở độ cao vượt tường cũ; kiểm tra skip ngay lúc khởi tạo không còn lỗi material. Các số đo cũ phía trên là mốc lịch sử của từng bản. Vòng chìa → cổng ở mốc trước đã được thay bằng đồng hồ 00:00–06:00 + rescue hook; thu mảnh/hội thoại AI chưa có.
