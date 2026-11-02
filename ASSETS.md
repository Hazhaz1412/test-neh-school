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

## Flow gấu bông và hành lang linh hồn

Gấu bông, vở, gậy dính máu, hành lang dài và phòng trú được ghép bằng mesh Godot. Vật cản hành lang dùng nội thất Kenney CC0. Lan dùng rig Casual_Female Quaternius có sẵn; nhóm ma dùng model hiện tượng học sinh có sẵn. Bổ sung hai model nội thất trong mục bên dưới, không thêm texture ngoài.

`corridor_chase.wav`, `strange_knock.wav`, `door_jumpscare.wav`, `gate_static.wav` là âm/nhạc nguyên bản tổng hợp bằng `tools/build_story_audio.py` (sin, bass, percussion và noise seed cố định). Nhạc chạy loop, không dùng bản ghi nhạc bên ngoài. Tiếng cười dùng asset `teasing_giggle.ogg` có nguồn/giấy phép trong `assets/audio/teasing_giggle-source.json`; tiếng chân/gầm dùng các WAV tổng hợp đã có.

`eerie_lullaby.wav`, `ghost_shriek.wav`, `door_bang.wav`, `heartbeat_single.wav` là âm nguyên bản tổng hợp bằng `tools/build_night1_audio.py` (seed cố định), không dùng bản ghi ngoài.

## Nội thất hành lang — cập nhật 2026-10-11

- Tải thêm `table.glb` và `bookcaseClosedWide.glb` từ [Kenney Furniture Kit](https://kenney.nl/assets/furniture-kit), **CC0 1.0**. URL archive, SHA-256 và kích thước trong `assets/kenney_furniture/chase_sources.json`; giấy phép gốc tiếp tục lưu ở `License.txt`.
- GLB nguồn giữ nguyên. Bản bàn runtime loại bỏ các tam giác của thanh giằng thấp, giữ mặt bàn và bốn chân ở mép: khoảng giữa nhìn xuyên qua và trượt qua được. Tủ sách xếp phía trên khiến khe thấp là đường bắt buộc. Collider mặt/chân tách riêng; khoảng trống khoảng 0,94 m, ánh lạnh phía sau gợi đường đi.
- Tủ kín cao dùng để né, ghế dài Kenney đã có dùng để nhảy. Collider khớp kích thước vật cản nhìn thấy, tránh vùng chắn vô hình ở cạnh tủ. Bóng nữ và Lan dùng Casual_Female Quaternius CC0 có sẵn. Chữ viết tay/vở và màn hình ngột ngạt được vẽ bằng Godot, không dùng ảnh hoặc font tải ngoài.

## Chân dung visual novel

Lan và An dùng bản portrait riêng của rig Casual_Female Quaternius CC0 đã có, render trong SubViewport trong suốt. Lan mặc tím; An mặc xanh và nhỏ hơn. Khung, chữ hiện dần và lựa chọn dựng bằng Control của Godot; không tải thêm ảnh/model/font. Kịch bản hỏi/đáp ở `data/night1_dialogue.json`.

## Microsoft Rocketbox — học sinh ma

- Nguồn: https://github.com/microsoft/Microsoft-Rocketbox
- Giấy phép: MIT, bản gốc ở `assets/rocketbox/LICENSE.txt`.
- Dùng avatar `Male_Child_01` và các clip `m_idle_neutral_01`, `m_walk_bruised`, `m_run_injured`, `m_run_fast_01`, `m_walk_slow_01`.
- Texture trong `assets/rocketbox/textures/` là bản vẽ lại bằng `tools/build_student_textures.gd`: đổi quần áo thành đồng phục bẩn, xóa nét mặt, thêm vết máu. Không lưu TGA gốc trong repo.

## Poly Haven — vật liệu và đèn pin

- Nguồn: https://polyhaven.com, giấy phép CC0.
- `assets/polyhaven_school/`: worn_plaster_wall, painted_concrete_02, dirty_concrete, rough_wood (1k: màu, vân nổi, độ nhám).
- `assets/polyhaven_torch/`: model pastic_torch_6v (1k glTF).

## Âm thanh bước chân và công tắc

- `assets/audio/steps/step_0*.ogg`: "Footsteps" trên OpenGameArt, CC0: https://opengameart.org/content/footsteps-0
- `assets/audio/steps/footstep_wet_0*.ogg`, `switch_0*.ogg`: "100 CC0 SFX #2", CC0: https://opengameart.org/content/100-cc0-sfx-2

## Ống kính điện thoại

- js-aruco2 (MIT): https://www.npmjs.com/package/js-aruco2, dò dấu ArUco trên điện thoại. `assets/lens/markers.json` sinh bằng `tools/build_lens_markers.js`.
- selfsigned (MIT), qrcode (MIT): chứng chỉ LAN và mã QR.

## Khu phố ban ngày

URL tải và SHA-256 của từng file nằm ở `assets/town_sources.json`, tải lại bằng `tools/fetch_town_assets.py`.

- **Poly Haven (CC0):** texture trong `assets/polyhaven_town/textures/`, model trong `models/`, bầu trời HDRI Qwantani trong `sky/`. Giấy phép: https://polyhaven.com/license . Nhà ống, đường, cầu và dây điện là mesh sinh bằng code, chỉ dùng các texture này. `models/jacaranda_street.glb` là bản rút gọn từ `jacaranda_tree` của Poly Haven (CC0) bằng `tools/build_town_tree.py`. Bộ cờ `models/chess_set/` là `chess_set` của Poly Haven (CC0). `Male_Child_01` thuộc Microsoft Rocketbox (MIT), cùng bộ với người dân khu phố.
- **Microsoft Rocketbox (MIT):** 9 avatar người lớn trong `assets/rocketbox/townsfolk/` và các clip `f_*`, `m_gestic_*`, `m_sit_*` trong `assets/rocketbox/animations/`. Texture được thu nhỏ còn 1024 JPG. Giấy phép: `assets/rocketbox/LICENSE.txt`.
- **Nhân vật ban đêm (Rocketbox, MIT):** mọi nhân vật dùng `humanoid_model.gd` giờ là Rocketbox. Lan là `Female_Adult_11`, Minh là `Male_Adult_02`, bóng lớp 306 là `Female_Adult_05`. An là `Female_Child_01` đổi tên thành `An_Student`, áo được `tools/build_an_textures.gd` nhuộm thành áo trắng. Clip chạy và ngồi thụp của Lan: `f_run_fast_01`, `f_crouch_idle`. Riêng cánh tay góc nhìn thứ nhất (`combat_limbs.gd`) vẫn là Quaternius CC0.
- **"low poly scooter", Thomas Saint Pierre (s1pierro), CC BY 3.0:** `assets/polypizza_town/low_poly_scooter.glb`. Trang model: https://poly.pizza/m/awXCP7LUcz6 ; giấy phép: https://creativecommons.org/licenses/by/3.0/ . Bắt buộc ghi công khi phân phối. Runtime đổi tỷ lệ và màu thân xe, không sửa file gốc.
- **Âm thanh:** `town_engine.wav`, `town_horn.wav`, `town_street.wav` do `tools/build_town_audio.py` tổng hợp, không có bản ghi ngoài.

Tham khảo hình thái phố (không đưa ảnh vào game): nhà ống và hẻm theo [Hẻm](https://en.wikipedia.org/wiki/H%E1%BA%BBm), [Vietnamese urban fabric, IIAS](https://iias.asia/the-newsletter/article/vietnamese-urban-fabric). Tên quán, đường và người trong khu phố đều hư cấu.

## Quỷ Ghen Tị

`assets/envy_demon/envy_demon.glb` do `tools/build_envy_demon.py` xuất từ Blender. Nguồn là avatar `Male_Adult_01` và các clip Rocketbox (MIT); script đổi tỉ lệ, phủ đen và thêm sừng, gai vai, vuốt, đuôi, áo dài, ba mắt, răng. Huy chương là mesh trong `scripts/envy_demon_model.gd`. Chạy lại: `blender --background --python tools/build_envy_demon.py`.

`envy_step.wav`, `envy_clink.wav`, `envy_rattle.wav` do `tools/build_envy_audio.py` tổng hợp, không có bản ghi ngoài.

## Nhà của Peter

`assets/home/`: giường, tủ lạnh, bồn cầu, chậu rửa từ Poly Pizza, CC0, URL và mã băm ở `assets/town_sources.json`. Sofa, bàn ăn, ghế, bếp, TV, lò vi sóng từ Poly Haven (CC0), nội thất còn lại từ Kenney (CC0). `hub/assets/gaaglu.png` do `tools/build_gaaglu_icon.py` vẽ. `phone_buzz.wav`, `phone_ding.wav` do `tools/build_town_audio.py` tổng hợp.

## Hành lang đỏ

- **Nhạc (CC0):** `assets/music/chase_wolfgang.ogg` ("Chase!" của Wolfgang_) và `dark_ambience_gabovitch.ogg` ("Dark Ambience Loop" của Iwan Gabovitch). Nguồn ở `assets/music/corridor_sources.json`.
- **Tiếng hù (CC0):** `assets/audio/corridor/` cắt từ "Horror Hit Soundpack 1" của psychhead_.
- **Font (SIL OFL 1.1):** `assets/fonts/` gồm Grenze (Omnibus-Type), Protest Revolution (Octavio Pardo), Sedgwick Ave Display (Kevin Burke), tải từ kho google/fonts, giấy phép nằm cạnh font (`OFL-*.txt`). Cả ba đủ dấu tiếng Việt. `horror_type.gd` phân vai từng font.
- **Tiếng thở dốc (CC0):** `assets/audio/corridor/panting.wav` cắt từ "breathing tired" của mikeask (https://opengameart.org/content/breathing-tired), chuẩn hóa âm lượng, tăng tốc 1,45 lần. Nguồn ở `assets/audio/corridor/sources.json`.
- **Nhện (CC0):** `assets/opengameart_spider/` là "Spider 2" của br-n518 (https://opengameart.org/content/spider-2). `tools/build_spider.py` xuất file blend sang `spider.glb`, giữ nguyên rig và vòng đi.
- **Bàn tay trong hầm (MIT):** không phải model riêng. `corridor_chute.gd` cắt cẳng tay và bàn tay của `Male_Child_01` (Rocketbox) lúc chạy game, dùng texture học sinh sẵn có.
- **Model và texture (CC0, Poly Haven):** `assets/polyhaven_corridor/`, nguồn ở `sources.json` cùng thư mục.
