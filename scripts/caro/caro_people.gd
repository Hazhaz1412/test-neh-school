extends RefCounted
# Bảy Rô keeps what the player needs for the night; he tells it only to someone who beats him.
# A confident, never-give-up competitor who talks in football terms and celebrates loudly.
# Lines here are the offline voice, used whenever the AI bridge is off or fails. REVEAL is story
# text and is never sent to, or written by, the model.
const BARO := {"name": "Bảy Rô"}
# His cry when he wins a game or plays a move the engine confirms is strong.
const SIU := "SIUUUUUUUUU"
const LINES := {
	"open_first": [
		"Ngồi đi. Muốn nghe chuyện thì phải thắng tôi trước. Tôi chưa từng vào sân để thua.",
		"Caro cũng như bóng đá: tập luyện, tập trung, rồi ghi bàn. Cậu đi trước.",
		"Năm quân liền là thắng. Bảy Rô sẵn sàng rồi, còn cậu?",
	],
	"open_again": [
		"Lại là cậu à. Tốt, tôi thích đối thủ không bỏ cuộc. Lần này tôi sẽ chú ý hơn.",
		"Quay lại rồi đấy. Nhà vô địch nào cũng từng thua, quan trọng là đứng dậy.",
		"Cậu lì thật. Giống tôi hồi trẻ, tập tới khuya mới về.",
		"Ván trước chưa đủ hả? Được, hiệp hai bắt đầu.",
	],
	"good_move": [
		"Nước đi hay đấy. Có tố chất.",
		"Ồ, cú đó đẹp như sút phạt. Tôi tôn trọng.",
		"Được đấy, cậu khá hơn tôi nghĩ.",
		"Chỗ này đúng chỗ. Bảy Rô phải nghĩ lại.",
	],
	"threat_created": [
		"Ba quân thoáng hai đầu. Cậu đang dâng cao đội hình đấy.",
		"Đang phản công tôi đấy à? Hay lắm.",
		"Thế này thì Bảy Rô phải lùi về phòng ngự rồi.",
	],
	"missed_block": [
		"Cậu để trống hàng phòng ngự rồi. Nhìn kỹ lại đi.",
		"Tôi mà là cậu thì đã chặn chỗ kia rồi.",
		"Đừng chỉ nhìn khung thành đối phương, nhìn cả đường tôi đang lên bóng.",
	],
	"baro_strong": [
		"Nhìn đường này đi. SIUUUUUUUUU!",
		"Bóng đã vào chân tôi rồi. SIUUUUUUUUU!",
		"Tập luyện mỗi ngày là để có nước này. SIUUUUUUUUU!",
	],
	"win": [
		"Được, cậu thắng. Tôi thua tâm phục, và Bảy Rô luôn giữ lời.",
		"Ván đẹp. Hôm nay cậu là người hay nhất trên sân.",
		"Thôi được. Thắng thì được nghe. Nhưng tôi sẽ về tập lại đấy.",
	],
	"lose": [
		"SIUUUUUUUUU! Đừng buồn, cậu chơi hay đấy. Ván nữa không?",
		"SIUUUUUUUUU! Thua để học. Ngồi lại ván nữa đi.",
		"SIUUUUUUUUU! Gần rồi đấy. Tôi còn ngồi đây cả ngày.",
	],
}

# The model is told when to cry out; this makes sure it never forgets.
static func with_siu(line: String) -> String:
	return line if line.to_upper().contains("SIU") else (line + " " + SIU + "!").strip_edges()

# Story text for Night 1, shown line by line after the player wins. DRAFT: awaiting review.
const REVEAL := [
	["Bảy Rô", "Năm 2009 tôi bán nước trước cổng NEH. Chiều nào cũng có con bé ngồi lại sân, xếp cờ một mình."],
	["Bảy Rô", "Nó hay trốn lên sân thượng khu A. Bảo trên đó không ai giật đồ của nó."],
	["Bảy Rô", "Mấy đứa bắt nạt nó đeo huy chương của nó lên cổ mà cười. Giờ đêm nào trong trường cũng có tiếng huy chương va nhau. Thứ đó thèm mọi thứ sáng như phần thưởng."],
	["Bảy Rô", "Nếu nó dừng lại trước chỗ cậu trốn để nghe... thì nín thở. Đừng thở cho tới khi nó đi."],
	["Bạn", "Sao chú biết mấy chuyện này?"],
	["Bảy Rô", "Vì tôi đã thấy mà không dám nói, mười bảy năm rồi. Trường vẫn dạy, vẫn bảo an toàn. Đi đi, và đừng đi tay không."],
]
const GATE_HINT := "Chưa nên vào. Bảy Rô đang đợi ở Góc Cờ, ông ấy biết điều gì đó."
