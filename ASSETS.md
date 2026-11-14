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

## Poly Haven — Texture bê tông nứt

- **Cracked Concrete**, Dimitrios Savva: https://polyhaven.com/a/cracked_concrete — diffuse JPG 1K, dùng cho sàn và vách nứt trong đường hầm.
- **Concrete Wall 003**, Dimitrios Savva / Rico Cilliers: https://polyhaven.com/a/concrete_wall_003 — diffuse JPG 1K, dùng cho tường mục và lớp bẩn trên đồ vật.
- Hai asset **CC0 1.0**: https://polyhaven.com/license ; https://creativecommons.org/publicdomain/zero/1.0/ .
- File gốc giữ nguyên trong `assets/polyhaven_horror/`; `sources.json` lưu URL tải, kích thước và SHA-256. Tổng hai JPG khoảng 1,1 MB. Shader chiếu texture theo tọa độ thế giới; không dùng normal/displacement map.

## Âm thanh tổng hợp trong project

`assets/audio/threat_heartbeat.wav` là loop mono 16 kHz do `tools/build_night_audio.py` tổng hợp từ sóng sin và noise seed cố định, không dùng bản ghi giọng người.

Các assets trên được lấy ngày 2026-10-03. Không cần tải thêm để mở project.

## Tham khảo kiến trúc (không đưa ảnh vào game)

- Ritsumeikan University, Biwako Kusatsu Campus Tricea, Yasui Architects: https://www.yasui-archi.co.jp/en/works/detail/621124/index.html — tham khảo quan hệ giữa sân trong, dãy nhà và hành lang mở nhiều tầng.
- Các ảnh trường học Nhật tìm qua image search dùng để tham khảo nhịp cột, cửa sổ dài và sân trường; không tải ảnh vào assets.

Khu A chữ U ngược và khu B nối bằng hành lang là bố cục hư cấu theo yêu cầu, không phải bản sao một trường thực tế hay asset lấy từ anime. Kiến trúc, hành lang kín, tường/cửa sổ và cửa lớp trượt có collider được ghép bằng mesh trong Godot. Sky đêm/trăng, shader mặt sân và hiệu ứng màn hình, cầu thang, tay vịn và hiệu ứng nước là code trong project; cây, nội thất, đài phun nước và nhân vật dùng model bên ngoài nêu ở trên.

Chỗ nấp dưới bàn dùng lại `assets/kenney_furniture/desk.glb`, đổi tỷ lệ và thêm collider mặt/chân riêng để gầm trống. Tủ dụng cụ có khe nhìn được ghép bằng BoxMesh theo hình khối sẵn của trường; collider và vùng tương tác do Godot tạo. Không thêm texture/model tải ngoài cho đợt này.

## Mở đầu không lời và tường bao cũ

Bảng điều tra dùng sáu ảnh chụp chính map demo trong `docs/`, đặt trên QuadMesh với crop UV để không hiện HUD. Bài báo, khoanh đỏ, ghim, dây nối và dụng cụ bổ sung dùng mesh/Label3D; không lấy ảnh báo hay ảnh nạn nhân ngoài đời. Tường cao dùng lại texture Concrete Wall 003 có sẵn. Trụ, chóp tường, cổng sắt và cửa bảo trì có collider được ghép trong Godot; kìm cắt khóa là prop nhỏ trong cutscene.

`midnight_bell.wav` (5 giây, ding–dong hai lần), `arrival_engine.wav` và `arrival_climb.wav` (foley chuyển động/cắt khóa, tên file được giữ để tương thích) cũng do script audio tổng hợp. Mở đầu không có giọng nói hay phụ đề hội thoại.


## Nhạc nền và SFX nhiệm vụ ký ức

[Lost in a bad place (horror ambience loop)](https://opengameart.org/content/lost-in-a-bad-place-horror-ambience-loop) của **congusbongus**, CC0, tải 2026-10-04. File gốc `assets/music/lost.ogg`; nguồn và SHA-256 trong `assets/music/sources.json`. Chạy loop ở âm lượng thấp, điều chỉnh theo trạng thái đêm/nguy hiểm/giải cứu.

`footstep`, `torch`, `door`, `lock`, `pickup`, `paper`, `hurt`, `memory`, `camera`, `school_bell`, `midnight_bell`, `player_breath`, `arrival_*` trong `assets/audio/` là SFX nguyên bản tổng hợp sẵn bởi `tools/build_night_audio.py` (sin/noise seed cố định). Không sinh mỗi frame.

## Máy ảnh — Poly by Google

- [Camera, Poly by Google](https://poly.pizza/m/0nfSsetwy0Z), [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/), tải 2026-10-04.
- GLB nguồn giữ nguyên tại `assets/models/camera/camera.glb`; URL tải/hash trong `sources.json`, ghi công trong `CREDITS.md` cùng thư mục. Godot chuẩn hóa tỷ lệ/hướng, đặt vào tay và dùng vật liệu unshaded cho model cầm để nhìn rõ trong đêm. Camera rơi xuống sàn giữ vật liệu gốc.
- `camera.wav`: màn trập cơ khí + tụ flash sạc, SFX tổng hợp nguyên bản bằng `tools/build_horror_audio.py`, mono 16 kHz, 0,65 giây.
- Cú chớp thay ánh nền/trăng/sương tạm thời và một uniform màn hình; không thêm đèn realtime hay shadow map. Icon túi được vẽ bằng Godot.

## Âm nước và tiếng giày bác bảo vệ (tải 2026-11-08)

- `assets/audio/water/ocean_splash.ogg`: [Ocean splash](https://opengameart.org/content/ocean-splash), CC0.
- `assets/audio/water/water_splash_01.ogg`, `water_splash_04.ogg`: [6 short water splashes](https://opengameart.org/content/6-short-water-splashes), qubodup cắt từ pdsounds.org, public domain/CC0; đổi FLAC sang Ogg.
- `assets/audio/water/bubbles_*.ogg`: [Bubble Sound Effects](https://opengameart.org/content/bubble-sound-effects) của Brian MacIntosh, CC0; đổi WAV sang Ogg.
- `assets/audio/water/underwater_pad.ogg`: [Underwater Ambient Pad](https://opengameart.org/content/underwater-ambient-pad) của isaiah658, CC0.
- `assets/audio/guard_steps/stone_*.ogg`: bước chân trên nền đá trong [Fantozzi's Footsteps](https://opengameart.org/content/fantozzis-footsteps-grasssand-stone), CC0 (gốc từ freesound.org).
- URL tải và SHA-256 của file gốc lẫn file trong dự án: `assets/audio/water/sources.json`, `assets/audio/guard_steps/sources.json`.

`door_bang.wav`, `heartbeat_single.wav` là âm nguyên bản tổng hợp bằng `tools/build_night1_audio.py` (seed cố định), không dùng bản ghi ngoài. `corridor_chase.wav` (nhạc rượt đuổi) do `tools/build_chase_music.py` tổng hợp. `lamp_pop.wav`, `chair_scrape.wav`, `chair_impact.wav` do `tools/build_prop_audio.py` tổng hợp. `guard_rattle.wav` (bác bảo vệ lay tủ khi nghe) do `tools/build_rattle_audio.py` tổng hợp.

## Nội thất hành lang — cập nhật 2026-10-11

- Tải thêm `table.glb` và `bookcaseClosedWide.glb` từ [Kenney Furniture Kit](https://kenney.nl/assets/furniture-kit), **CC0 1.0**. URL archive, SHA-256 và kích thước trong `assets/kenney_furniture/chase_sources.json`; giấy phép gốc tiếp tục lưu ở `License.txt`.
- GLB nguồn giữ nguyên. Bản bàn runtime loại bỏ các tam giác của thanh giằng thấp, giữ mặt bàn và bốn chân ở mép: khoảng giữa nhìn xuyên qua và trượt qua được. Tủ sách xếp phía trên khiến khe thấp là đường bắt buộc. Collider mặt/chân tách riêng; khoảng trống khoảng 0,94 m, ánh lạnh phía sau gợi đường đi.
- Tủ kín cao dùng để né, ghế dài Kenney đã có dùng để nhảy. Collider khớp kích thước vật cản nhìn thấy, tránh vùng chắn vô hình ở cạnh tủ. Màn hình ngột ngạt được vẽ bằng Godot, không dùng ảnh hoặc font tải ngoài.

## Poly Haven — vật liệu và đèn pin

- Nguồn: https://polyhaven.com, giấy phép CC0.
- `assets/polyhaven_school/`: worn_plaster_wall, painted_concrete_02, dirty_concrete, rough_wood (1k: màu, vân nổi, độ nhám).
- `assets/polyhaven_torch/`: model pastic_torch_6v (1k glTF).

## Âm thanh bước chân và công tắc

- `assets/audio/steps/step_0*.ogg`: "Footsteps" trên OpenGameArt, CC0: https://opengameart.org/content/footsteps-0
- `assets/audio/steps/footstep_wet_0*.ogg`, `switch_0*.ogg`: "100 CC0 SFX #2", CC0: https://opengameart.org/content/100-cc0-sfx-2

## Kênh ghép điện thoại

- selfsigned (MIT), qrcode (MIT): chứng chỉ LAN và mã QR.

## Khu phố ban ngày

URL tải và SHA-256 của từng file nằm ở `assets/town_sources.json`, tải lại bằng `tools/fetch_town_assets.py`.

- **Poly Haven (CC0):** texture trong `assets/polyhaven_town/textures/`, model trong `models/`, bầu trời HDRI Qwantani trong `sky/`. Giấy phép: https://polyhaven.com/license . Nhà cửa, đường, cầu và dây điện là mesh sinh bằng code, chỉ dùng các texture này. Bảy texture thêm ngày 2026-11-11 cho các kiểu nhà mới: `red_brick`, `damaged_plaster`, `worn_mossy_plasterwall`, `yellow_plaster` (tường gạch trần, vữa bong, khu tập thể), `exterior_wall_cladding_03`, `stone_tile_wall`, `granite_tile_03` (mặt tiền nhà hiện đại). `models/jacaranda_street.glb` là bản rút gọn từ `jacaranda_tree` của Poly Haven (CC0) bằng `tools/build_town_tree.py`. Bộ cờ `models/chess_set/` là `chess_set` của Poly Haven (CC0). `Male_Child_01` thuộc Microsoft Rocketbox (MIT), cùng bộ với người dân khu phố.
- **Microsoft Rocketbox (MIT):** 9 avatar người lớn trong `assets/rocketbox/townsfolk/` và các clip `f_*`, `m_gestic_*`, `m_sit_*` trong `assets/rocketbox/animations/`. Texture được thu nhỏ còn 1024 JPG. Giấy phép: `assets/rocketbox/LICENSE.txt`.
- **Nhân vật (Rocketbox, MIT):** mọi nhân vật dùng `humanoid_model.gd` là Rocketbox: bác bảo vệ `Security_Male_01`, nhóm bạn `Male_Child_01`, `Female_Child_01`, `Male_Adult_08`, dân phố các avatar `Female_Adult_*`, `Male_Adult_*`. Cánh tay góc nhìn thứ nhất là PSX arms.
- **"low poly scooter", Thomas Saint Pierre (s1pierro), CC BY 3.0:** `assets/polypizza_town/low_poly_scooter.glb`. Trang model: https://poly.pizza/m/awXCP7LUcz6 ; giấy phép: https://creativecommons.org/licenses/by/3.0/ . Bắt buộc ghi công khi phân phối. Runtime đổi tỷ lệ và màu thân xe, không sửa file gốc.
- **Âm thanh:** `town_engine.wav`, `town_horn.wav`, `town_street.wav` do `tools/build_town_audio.py` tổng hợp, không có bản ghi ngoài.

Tham khảo hình thái phố (không đưa ảnh vào game): nhà ống và hẻm theo [Hẻm](https://en.wikipedia.org/wiki/H%E1%BA%BBm), [Vietnamese urban fabric, IIAS](https://iias.asia/the-newsletter/article/vietnamese-urban-fabric). Tên quán, đường và người trong khu phố đều hư cấu.

## Nhà của Peter

`assets/home/`: giường, tủ lạnh, bồn cầu, chậu rửa từ Poly Pizza, CC0, URL và mã băm ở `assets/town_sources.json`. Sofa, bàn ăn, ghế, bếp, TV, lò vi sóng từ Poly Haven (CC0), nội thất còn lại từ Kenney (CC0). `hub/assets/gaaglu.png` do `tools/build_gaaglu_icon.py` vẽ. `phone_buzz.wav`, `phone_ding.wav` do `tools/build_town_audio.py` tổng hợp.

### Bếp: minigame mì net (`scripts/home/home_kitchen.gd`)

Model trong `assets/kitchen/`, đều CC0 1.0, lấy ngày 2026-11-14. Trang gốc, URL tải và SHA-256 nằm ở `assets/kitchen/sources.json`.
- Poly Pizza: bếp ga đôi "Stove" (MilkAndBanana), "Kitchen Sink" (Kenney, kéo giãn cho vừa khoảng trống trên tủ bếp), "Pot" (Kay Lousberg), "Frying Pan" (CreativeTrio), "Mixing Bowl" (MilkAndBanana, dùng làm tô), "Soda Can" (Kenney, chính là lon Xiteen; chữ XITEEN là Label3D), "Bottle Ketchup" (Kenney, dùng làm chai tương ớt), "Egg", "Egg Cooked", "Meat Sausage", "Leek" (dùng làm hành lá, bóp mỏng lại), "Cooking Spatula" (đều của Kenney), "Chef Knife", "Chopsticks" (MilkAndBanana).
- Poly Haven: "Wooden Cutting Board".
- Dựng bằng code: gói mì How How (hộp và nhãn Label3D), mặt sợi mì (`assets/materials/noodles.gdshader`), hạt hành thái, giọt tương ớt, mảnh vỏ trứng. Tên How How và Xiteen là nhái hư cấu.

Âm thanh trong `assets/audio/kitchen/`, CC0 1.0. Nguồn, đoạn cắt và mã băm của cả file gốc lẫn file đã cắt nằm ở `assets/audio/kitchen/sources.json`.
- "General Household Sound Effects" (https://opengameart.org/content/general-household-sound-effects): nước sôi, chiên, dao thớt, đũa chạm tô, tiếng ga xì. Đều cắt ngắn từ bản ghi dài.
- "stove switch" (https://opengameart.org/content/stove-switch): vặn bếp.
- "cutlery sounds" (https://opengameart.org/content/cutlery-sounds): đặt lon xuống bàn, cầm đũa.
- Dùng lại âm thanh đã có của game: `paper.wav` (xé gói), `water_drip.wav` (thả mì), `water_leak.wav` (chắt nước), `chair_scrape.wav` (kéo ghế).

## Hành lang đỏ

- **Nhạc (CC0):** `assets/music/chase_wolfgang.ogg` ("Chase!" của Wolfgang_) và `dark_ambience_gabovitch.ogg` ("Dark Ambience Loop" của Iwan Gabovitch). Nguồn ở `assets/music/corridor_sources.json`.
- **Tiếng hù (CC0):** `assets/audio/corridor/` cắt từ "Horror Hit Soundpack 1" của psychhead_.
- **Font (SIL OFL 1.1):** `assets/fonts/` gồm Grenze (Omnibus-Type), Protest Revolution (Octavio Pardo), Sedgwick Ave Display (Kevin Burke), tải từ kho google/fonts, giấy phép nằm cạnh font (`OFL-*.txt`). Cả ba đủ dấu tiếng Việt. `horror_type.gd` phân vai từng font.
- **Giường y tế:** dùng lại `assets/home/bed.glb` (CC0, Poly Pizza) kê trên chân sắt dựng bằng code, chỉ đặt ở phòng y tế.
- **Tiếng thở dốc (CC0):** `assets/audio/corridor/panting.wav` cắt từ "breathing tired" của mikeask (https://opengameart.org/content/breathing-tired), chuẩn hóa âm lượng, tăng tốc 1,45 lần. Nguồn ở `assets/audio/corridor/sources.json`.
- **Nhện (CC0):** `assets/opengameart_spider/` là "Spider 2" của br-n518 (https://opengameart.org/content/spider-2). `tools/build_spider.py` xuất file blend sang `spider.glb`, giữ nguyên rig và vòng đi.
- **Bàn tay trong hầm (MIT):** không phải model riêng. `corridor_chute.gd` cắt cẳng tay và bàn tay của `Male_Child_01` (Rocketbox) lúc chạy game, dùng texture học sinh sẵn có.
- **Model và texture (CC0, Poly Haven):** `assets/polyhaven_corridor/`, nguồn ở `sources.json` cùng thư mục.

## Tiền truyện: nhà vệ sinh và côn trùng

- **Gián (CC BY 3.0):** "Cockroach" by Poly by Google, https://poly.pizza/m/eSCFQN_47V4, giấy phép https://creativecommons.org/licenses/by/3.0/. File giữ nguyên ở `assets/polypizza_insects/cockroach.glb`, ghi công và mã băm ở `assets/polypizza_insects/CREDITS.md`. Khi phân phối demo phải giữ phần ghi công này.
- **Nhện:** dùng lại "Spider 2" CC0 ở `assets/opengameart_spider/`.
- **Nhà vệ sinh A-203:** bồn cầu, chậu rửa dùng lại `assets/home/toilet.glb`, `basin.glb` (CC0). Gạch dùng `floor_tiles_08` Poly Haven (CC0) có sẵn. Vách buồng, tủ đồ, gương tường dựng bằng mesh trong `tools/build_map.gd` và `scripts/restroom_scene.gd`.
- **Cài tóc gãy, gương cầm tay vỡ:** không tìm được bản CC0 tải trực tiếp, nên dựng bằng mesh trong `scripts/night_story_interactable.gd`. Kính nứt và ánh lấp lánh là shader tự viết: `assets/materials/cracked_glass.gdshader`, `glint.gdshader`.
- **Âm thanh:** `mirror_crash.wav`, `mirror_crash_muffled.wav`, `water_leak.wav`, `water_drip.wav`, `insect_burst.wav`, `insect_skitter.wav` tổng hợp bằng `tools/build_restroom_audio.py`.

## Tiền truyện: bác bảo vệ

- **Model:** `Security_Male_01` của Microsoft Rocketbox (MIT), đã có sẵn trong `assets/rocketbox/townsfolk/`. Mũ bảo vệ và đèn pin là mesh trong `scripts/security_guard.gd`.
- **Động tác (MIT, Rocketbox):** thêm `m_idle_look_around_01`, `m_listen_door`, `m_documents_check`, `m_documents_take` (thư mục `all_animations_max_motextr_static/`) và `m_walk_fast_01` (thư mục `all_animations_max_motextr_xy/`) vào `assets/rocketbox/animations/`, tải từ https://github.com/microsoft/Microsoft-Rocketbox. Chạy dùng `m_run_fast_01` có sẵn. Tay cầm đèn pin giơ ra trước được dựng bằng IK trong `humanoid_model.gd` (`hand_target`).
- **Âm thanh:** `guard_whistle.wav` (còi), `guard_keys.wav` (chùm chìa khóa), `floor_thud.wav` (đồ đổ trên tầng 3) tổng hợp bằng `tools/build_guard_audio.py`.

## Đêm 1: bãi kiting và đội

- **Model (CC0 1.0, Poly Haven), bản 1k:** `assets/polyhaven_kiting/`, gồm:
  - `SchoolDesk_01` (Ethan Place): bàn kê dưới cửa sổ để leo.
  - `wooden_bookshelf_worn` (Ulan Cabanilla): kệ để gạt đổ chặn lối.
  - `steel_frame_shelves_02` (James Ray Cock): kệ sắt trang trí.
  - `wooden_crate_01` (James Ray Cock) và `wooden_crate_02` (James Ray Cock, Jurita Burger): chồng thùng ở giữa vòng.

  Tải từ https://polyhaven.com qua API chính thức. URL từng file và SHA-256 ở `assets/polyhaven_kiting/sources.json`.
- **Tường bê tông và ván gỗ:** dùng lại texture Poly Haven có sẵn `dirty_concrete` và `rough_wood` (`assets/polyhaven_school/`).
- **Ba bạn đồng đội:** model Rocketbox (MIT) có sẵn `Male_Child_01`, `Female_Child_01`, `Male_Adult_08`.
- **Âm thanh:** dùng lại `floor_thud.wav` (kệ đổ), `chair_impact.wav` (phá ván), tiếng giày CC0 `assets/audio/guard_steps/`, `guard_keys.wav`, `guard_whistle.wav`.

## Giấc mơ — mặt nước (Đêm 0, sau bể nước)

Cảnh `scenes/dream_shore.tscn`, dựng trong `scripts/dream/dream_world.gd`. Mọi asset được chọn cùng một nguồn ảnh chụp PBR (Poly Haven) để ánh sáng, độ chi tiết và tỷ lệ khớp nhau; bàn ghế và gạch sàn dùng lại từ trường.

- **Poly Haven, CC0 1.0** (https://polyhaven.com/license), lấy ngày 2026-11-14, file gốc giữ nguyên trong `assets/polyhaven_dream/`, URL và SHA-256 ở `assets/polyhaven_dream/sources.json`:
  - Large Iron Gate: https://polyhaven.com/a/large_iron_gate (cổng trường, phóng 1.2 lần; trụ và tường dùng texture yellow_plaster có sẵn).
  - Modular Electricity Poles: https://polyhaven.com/a/modular_electricity_poles (dùng ba cột dựng sẵn preset_01..03; dây điện là mesh võng tự sinh).
  - Alarm Clock 01: https://polyhaven.com/a/alarm_clock_01 (phóng 34 lần, kim xoay về 05:52; lớp kính gốc được thay bằng kính trong vì phóng lớn nó che mất mặt số).
  - HDRI Qwantani Dusk 2 (Pure Sky): https://polyhaven.com/a/qwantani_dusk_2_puresky, bản 2K, cùng series với trời khu phố.
- Đồ trường học rải rác (`scripts/dream/dream_props.gd`), cùng Poly Haven CC0, cùng `sources.json`: Ceiling Fan, Football, Book Encyclopedia Set 01, Office Notepads (chỉ dùng tờ A4 trắng), Plastic Broom, Mounted Fluorescent Lights, Security Camera 01, Standing Chalkboard 01, Stationery Supplies (bút chì phóng 48 lần, ống bút), Wall Clock (kim xoay về 05:52). Trang: https://polyhaven.com/a/<tên>. Loại: két nhựa (có chữ thương hiệu), thùng rác kiểu Mỹ, sổ da.
- Dùng lại thêm: metal_office_desk (bàn giáo viên), television_02 và plastic_monobloc_chair_01 của khu phố.
- Đoạn lucid (`scripts/dream/lucid_sky.gd`) chỉ dùng lại asset ở trên: metal_office_desk, Book Encyclopedia Set 01 (phóng 9 lần), Office Notepads (phóng 9 lần), yellow_plaster cho khung cửa, `memory.wav` khi kéo hoặc thả vật. Mây là shader tự viết (`assets/materials/dream_cloud.gdshader`) trên nhiễu FastNoiseLite của Godot, không có file ảnh.
- Dùng lại: SchoolDesk_01, SchoolChair_01 (`assets/polyhaven_corridor/`), floor_tiles_08 và yellow_plaster (`assets/polyhaven_school/`), tiếng bước chân ướt (`assets/audio/steps/footstep_wet_*`).
- **Ambient Relaxing Loop**, isaiah658, CC0: https://opengameart.org/content/ambient-relaxing-loop — `assets/music/dream_ambient.ogg`, nguồn và hash ở `assets/music/dream_sources.json`. Cùng tác giả với tiếng pad dưới nước lúc chìm, nên hai đoạn nối liền.
- Đã cân nhắc và loại: biển "Wet Floor" (chữ tiếng Anh), đèn đường kiểu châu Âu, ghế băng kiểu nhà thờ của Poly Haven (không hợp bối cảnh trường Việt Nam).

## Giấc mơ — đồng cỏ (sau Đêm 1)

Cảnh `scenes/dream_meadow.tscn`, dựng trong `scripts/meadow/dream_meadow.gd`.

- **Poly Haven, CC0 1.0** (https://polyhaven.com/license), lấy ngày 2026-11-14, nằm trong `assets/polyhaven_meadow/`; URL và SHA-256 ghi ở `assets/polyhaven_meadow/sources.json`:
  - HDRI Kloofendal 48d Partly Cloudy (Pure Sky): https://polyhaven.com/a/kloofendal_48d_partly_cloudy_puresky, bản 2K, trời xanh lúc đã vào vùng sáng.
  - HDRI Farm Field (Pure Sky): https://polyhaven.com/a/farm_field_puresky, bản 2K, trời u ám lúc đầu (làm tối và ám xanh trong shader).
  - Island Tree 01: https://polyhaven.com/a/island_tree_01. Đã giảm lưới bằng Blender 5.2 từ 1.6 triệu xuống khoảng 0.4 triệu tam giác (61 MB còn 16 MB), texture giữ nguyên; cách làm ghi trong `sources.json` mục `derived`.
  - Gothic Bed 01: https://polyhaven.com/a/GothicBed_01 (cái giường).
  - Dandelion 01 (https://polyhaven.com/a/dandelion_01) và Shrub 01 (https://polyhaven.com/a/shrub_01), trồng quanh gốc cây.
  - Texture Leafy Grass: https://polyhaven.com/a/leafy_grass, làm hạt cho nền đất dưới cỏ.
- **Animated Fish Pack**, Quaternius, CC0: https://opengameart.org/content/animated-fish. Đã chuyển FBX sang GLB bằng Blender, giữ animation Swim; alpha vật liệu đặt về 1. Gồm ba loại cá nhỏ, cá đuối manta và cá voi, nằm ở `assets/meadow/fish/`.
- **Barramundi Fish**, Microsoft, Khronos glTF-Sample-Assets, CC0: https://github.com/KhronosGroup/glTF-Sample-Assets/tree/main/Models/BarramundiFish. Hash của cả bộ cá ghi ở `assets/meadow/fish/sources.json`.
- **Fantozzi's Footsteps (Grass/Sand & Stone)**, CC0: https://opengameart.org/content/fantozzis-footsteps-grasssand-stone. Dùng sáu tiếng bước "Sand" (nghe như bước trên cỏ), lưu thành `assets/audio/steps/grass_0*.ogg`, nguồn ở `grass_sources.json`.
- Dùng lại: cột điện Modular Electricity Poles (`assets/polyhaven_dream/`), nhạc `dream_ambient.ogg`, `memory.wav`.
- Tự viết trong shader, không có file ảnh: cỏ (`meadow_grass.gdshader`, mỗi ngọn được đặt bằng hash của INSTANCE_ID), các tia sáng, bong bóng, trời pha hai HDRI, hậu kỳ dreamcore (`dreamcore_post.gdshader`).
- Đã cân nhắc và loại: Jacaranda Tree (208 MB), các cụm cỏ Grass Medium (hơn 1 triệu đa giác mỗi cụm, không rải nổi cả cánh đồng).
