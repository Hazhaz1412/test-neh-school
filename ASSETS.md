# Assets và tham khảo

## Kenney — Furniture Kit

- Nguồn chính thức: https://kenney.nl/assets/furniture-kit
- Archive: https://kenney.nl/media/pages/assets/furniture-kit/440e0608a4-1677580847/kenney_furniture-kit.zip
- Tác giả: Kenney (https://kenney.nl).
- Giấy phép: CC0, dùng được cho cá nhân, giáo dục và thương mại; không bắt buộc ghi công.
- Giấy phép gốc: `assets/kenney_furniture/License.txt`.
- Model GLB gốc được giữ nguyên. Scene điều chỉnh tỷ lệ và thêm collider.
- Nội thất dùng trong bản hiện tại: desk, chair, chairDesk, bookcaseOpen, books, bench, computerScreen, computerKeyboard, cardboardBoxClosed, coatRackStanding, trashcan. Dùng lại cho thư viện, phòng máy, giáo viên, phòng chức năng và nhà kho; không tải thêm pack cho phần mở rộng này. Giường y tế thử nghiệm ghép từ bench với đệm mesh; khay/mẫu thí nghiệm và thiết bị trên mái là mesh đơn giản.

## Kenney — Nature Kit

- Nguồn chính thức: https://kenney.nl/assets/nature-kit
- Archive: https://kenney.nl/media/pages/assets/nature-kit/37ac38a37b-1677698939/kenney_nature-kit.zip
- Tác giả: Kenney.
- Giấy phép: CC0; bản gốc ở `assets/kenney_nature/License.txt`.
- Dùng cây tree_detailed, tree_oak, tree_pineRoundB, tree_detailed_fall; bụi plant_bush, plant_bushLarge; grass; flower_purpleA; stone_largeA, stone_largeC.
- Giữ nguyên các file GLB. Trong scene, vật liệu cây/cỏ được điều chỉnh sang matte (metallic = 0), với màu lá xanh trầm và tán cây mùa thu hồng dịu. Material gốc trong GLB đánh dấu metallic = 1. Collider cây chỉ bao thân, không bao cả tán.
- Node model có metadata `source_asset` để lần về GLB gốc; các override vật liệu được lưu trong scene.

## Fountain — Poly by Google

**“Fountain” by Poly by Google**, licensed under **CC BY 3.0**.

- Trang model: https://poly.pizza/m/7AydBrjR2Ss
- File GLB: https://static.poly.pizza/d378ea52-e38b-49de-be1a-6a2ad1b86776.glb
- Giấy phép: https://creativecommons.org/licenses/by/3.0/
- Ghi công riêng: `assets/poly_fountain/CREDITS.md`.
- Giữ nguyên GLB; scene đổi tỷ lệ xuống cao 2.8 m, đặt vào sân trong, thêm collider và hiệu ứng giọt nước của Godot.
- Khi phân phối demo, giữ phần ghi công này và đường dẫn giấy phép.

## Quaternius — Ultimate Animated Character Pack

- Nguồn tác giả: https://quaternius.com/packs/ultimatedanimatedcharacter.html .
- Bản phân phối CC0 do chính tác giả đăng: https://opengameart.org/content/animated-characters-pack .
- Dùng Casual_Male, Casual_Female và Suit_Male FBX gốc, lấy ngày 2026-10-04. URL archive và SHA-256 ở `assets/quaternius_characters/sources.json`; ghi công/giấy phép ở `assets/quaternius_characters/CREDITS.md`.
- Thay model khối vuông cũ cho cả đội điều tra và thực thể. Runtime chuẩn hóa tỷ lệ, giảm đầu lớn của người điều tra, đổi màu quần áo và gắn dụng cụ theo xương tay. Thực thể dùng đồng phục Suit_Male, đầu bầu dục không mặt, pose và gậy theo rig. File FBX nguồn giữ nguyên.
- Idle, Walk, PickUp và Punch là animation có sẵn. Sprint dùng Walk tăng tốc, không có clip Run riêng. Pack Kenney Blocky cũ giữ trong assets nhưng không còn được dùng làm nhân vật runtime.

## Kenney — Car Kit

- Nguồn chính thức: https://kenney.nl/assets/car-kit ; CC0, giấy phép gốc tại `assets/kenney_car/License.txt`.
- Van GLB và colormap gốc dùng cho cảnh cả nhóm tới trường, URL tải/hash ở `assets/kenney_car/sources.json`. Camera, đèn pha và chuyển động xe do Godot điều khiển.

Scene gốc giữ các instance GLB để chỉnh sửa. Scene runtime tối ưu dùng lại mesh/vật liệu của chúng trong MultiMesh theo ô không gian; metadata `source_asset` trên pivot Furniture/Landscape giữ đường dẫn về asset gốc. File nguồn và giấy phép giữ nguyên.

## Poly Haven — Texture cho thế giới linh hồn

- **Cracked Concrete**, Dimitrios Savva: https://polyhaven.com/a/cracked_concrete — diffuse JPG 1K, dùng cho sàn nứt.
- **Concrete Wall 003**, Dimitrios Savva / Rico Cilliers: https://polyhaven.com/a/concrete_wall_003 — diffuse JPG 1K, dùng cho tường mục và lớp bẩn trên đồ vật.
- Hai asset **CC0 1.0**: https://polyhaven.com/license ; https://creativecommons.org/publicdomain/zero/1.0/ .
- File gốc giữ nguyên trong `assets/polyhaven_horror/`; `sources.json` lưu URL tải, kích thước và SHA-256. Tổng hai JPG khoảng 1,1 MB. Shader chiếu texture theo tọa độ thế giới và thêm vết oán khí; không dùng normal/displacement map.

## Âm thanh tổng hợp trong project

`assets/audio/spirit_ambience.wav` và `threat_heartbeat.wav` là hai loop mono 16 kHz do `tools/build_horror_audio.py` tổng hợp từ sóng sin và noise seed cố định. Các WAV này không dùng bản ghi giọng người; nhạc nền CC0 riêng được ghi bên dưới. Hai loop khoảng 288 KB; phát bằng AudioStreamPlayer, không tổng hợp mỗi frame. `ghost_snarl.wav` (0,85 giây) và `ghost_step.wav` (0,15 giây) cũng được script này tổng hợp, thêm khoảng 32 KB, phát định hướng bằng AudioStreamPlayer3D. Không dùng giọng người bên ngoài.

Các assets trên được lấy ngày 2026-10-03. Không cần tải thêm để mở project.

## Tham khảo kiến trúc (không đưa ảnh vào game)

- Ritsumeikan University, Biwako Kusatsu Campus Tricea, Yasui Architects: https://www.yasui-archi.co.jp/en/works/detail/621124/index.html — tham khảo quan hệ giữa sân trong, dãy nhà và hành lang mở nhiều tầng.
- Các ảnh trường học Nhật tìm qua image search dùng để tham khảo nhịp cột, cửa sổ dài và sân trường; không tải ảnh vào assets.

Khu A chữ U ngược và khu B nối bằng hành lang là bố cục hư cấu theo yêu cầu, không phải bản sao một trường thực tế hay asset lấy từ anime. Kiến trúc, hành lang kín, tường/cửa sổ và cửa lớp trượt có collider được ghép bằng mesh trong Godot. Sky đêm/trăng đỏ, shader mặt sân và màn hình oán khí, cầu thang, tay vịn, gậy và hiệu ứng nước/tro là code trong project; cây, nội thất, đài phun nước và nhân vật dùng model bên ngoài nêu ở trên.

Chỗ nấp dưới bàn dùng lại `assets/kenney_furniture/desk.glb`, đổi tỷ lệ và thêm collider mặt/chân riêng để gầm trống. Tủ dụng cụ có khe nhìn được ghép bằng BoxMesh theo hình khối sẵn của trường; collider và vùng tương tác do Godot tạo. Không thêm texture/model tải ngoài cho đợt này.

## Thực thể và lượt sinh tồn

Ba archetype dùng rig/animation `Suit_Male.fbx` Quaternius CC0: Kẻ Dò Tiếng thêm băng che mặt/tai bằng mesh nhỏ; Kẻ Rỉ Tai dùng lại mesh đầu thành ba mặt; Kẻ Chặn Lối đổi tỷ lệ và thêm cặp/đai bằng mesh. Không chỉnh file FBX nguồn. Đồ tiếp tế và phấn dùng BoxMesh nhỏ; các âm `whisper_chorus.wav`, `school_bell.wav`, `player_breath.wav` cũng do `tools/build_horror_audio.py` tổng hợp sẵn từ sin/noise, không dùng giọng người hoặc nhạc thu ngoài. Bộ ba âm mới tổng khoảng 250 KB mono 16 kHz.

## Mở đầu không lời và tường bao cũ

Bảng điều tra dùng sáu ảnh chụp chính map demo trong `docs/`, đặt trên QuadMesh với crop UV để không hiện HUD. Bài báo, khoanh đỏ, ghim, dây nối và dụng cụ bổ sung dùng mesh/Label3D; không lấy ảnh báo hay ảnh nạn nhân ngoài đời. Tường cao dùng lại texture Concrete Wall 003 có sẵn. Trụ, chóp tường, cổng sắt và cửa bảo trì có collider được ghép trong Godot; kìm cắt khóa là prop nhỏ trong cutscene.

`midnight_bell.wav` (5 giây, ding–dong hai lần), `arrival_engine.wav` và `arrival_climb.wav` (foley chuyển động/cắt khóa, tên file được giữ để tương thích) cũng do script audio tổng hợp. Mở đầu không có giọng nói hay phụ đề hội thoại.


## Nhạc nền và SFX nhiệm vụ ký ức

[Lost in a bad place (horror ambience loop)](https://opengameart.org/content/lost-in-a-bad-place-horror-ambience-loop) của **congusbongus**, CC0, tải 2026-10-04. File gốc `assets/music/lost.ogg`; nguồn và SHA-256 trong `assets/music/sources.json`. Chạy loop ở âm lượng thấp, điều chỉnh theo trạng thái đêm/nguy hiểm/giải cứu.

`footstep`, `torch`, `door`, `lock`, `pickup`, `paper`, `hurt`, `memory`, `rescue` trong `assets/audio/*.wav` là SFX nguyên bản tổng hợp sẵn bởi `tools/build_horror_audio.py` (sin/noise seed cố định). Không sinh mỗi frame. Bốn voice 3D dùng chung cho tiếng chân/cửa, giới hạn 24 m; một voice 2D cho tương tác. Không thêm đèn realtime cho vật chứng. Model An dùng lại Casual_Female Quaternius CC0; vở/hộp/thiết bị dùng Kenney Furniture CC0 có sẵn.

## Máy ảnh — Poly by Google

- [Camera, Poly by Google](https://poly.pizza/m/0nfSsetwy0Z), [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/), tải 2026-10-04.
- GLB nguồn giữ nguyên tại `assets/models/camera/camera.glb`; URL tải/hash trong `sources.json`, ghi công trong `CREDITS.md` cùng thư mục. Godot chuẩn hóa tỷ lệ/hướng, đặt vào tay và dùng vật liệu unshaded cho model cầm để nhìn rõ trong đêm. Camera rơi xuống sàn giữ vật liệu gốc.
- `camera.wav`: màn trập cơ khí + tụ flash sạc, SFX tổng hợp nguyên bản bằng `tools/build_horror_audio.py`, mono 16 kHz, 0,65 giây.
- Cú chớp thay ánh nền/trăng/sương tạm thời và một uniform màn hình; không thêm đèn realtime hay shadow map. Icon túi được vẽ bằng Godot.

## QTE phản công

Tay và giày góc nhìn thứ nhất lấy từ mesh `Casual_Male.fbx` Quaternius CC0 đã có trong dự án, giữ silhouette/vertex color và tách các tam giác theo bone weights, cache một lần. Phản công và gậy tiếp tục dùng cùng rig/clip Punch, bổ sung pose bằng script. Không có pack/model mới cần tải. Ba SFX `counter_grab.wav`, `counter_punch.wav`, `counter_kick.wav` do `tools/build_horror_audio.py` sinh từ sin/noise seed cố định; tim adrenaline dùng lại `threat_heartbeat.wav`. Bụi trúng đòn dùng CPUParticles ít hạt, không thêm đèn/shadow realtime.

### Tiếng khóc định vị của An

[Girl Crying — mvVoiceActing](https://freesound.org/people/mvVoiceActing/sounds/218184/) · CC0 1.0. Bản preview công khai được cắt đoạn 5–15 giây, lọc nhẹ, fade và chuyển mono Ogg 24 kHz. Metadata và SHA-256: `assets/audio/an_cry-source.json`. Phát từ sân thượng, vọng qua hai miệng thông cầu thang; dừng khi An được cứu.
