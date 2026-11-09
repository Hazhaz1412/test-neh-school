# Máy ảnh và túi sáu ô

Máy ảnh dùng để **chụp lại bằng chứng**. Ở Đêm 0 nó chỉ dùng được ở phòng B-302, lúc bác bảo vệ dọn giấy tờ (`school_progression.camera_allowed`); ở nơi khác flash sẽ làm lộ người chơi nên bị khóa. Chọn máy ảnh rồi **chuột trái** để giơ lên ngắm và chụp. Cú chớp 0,55 giây làm sáng toàn cảnh. Một ảnh tốn **20 điểm phần trăm** pin dùng chung với đèn pin, màn trập hồi **1,5 giây**.

**1–6 / cuộn chuột** chọn ô, **chuột trái** dùng đồ, **Q** thả xuống sàn, **E** nhặt. Túi đúng sáu vật, không cộng dồn. Mỗi pin, sơ cứu, phấn chiếm một ô. Pin sạc **+50**; sơ cứu hồi 30 sức khỏe; không dùng pin khi đầy hay sơ cứu khi khỏe.

**G** chọn phấn; giữ G (hoặc chuột trái khi cầm phấn) tối đa 1,5 giây rồi thả để ném xa tới ×5. Tiếng phấn rơi kéo bác bảo vệ tới chỗ đó, nên phấn chỉ ném được trong đêm có bác săn (`world.night_hunt()`). Đổi đồ, nấp, mở giao diện, tạm dừng hoặc mất focus hủy lực mà không mất viên phấn.

Chỉnh node School → **Night · camera**: `camera_shot_cooldown`. Chi phí cố định nằm ở `player.gd`; ánh sáng ở `camera_flash.gd`, khung ngắm ở `camera_viewfinder.gd`, prop cầm ở `held_item.gd`, icon ở `compact_hud.gd`.

```sh
godot --headless --path . --script tools/validate_chalk.gd
```

- [Đang cầm máy ảnh](camera-ready-preview.png)
