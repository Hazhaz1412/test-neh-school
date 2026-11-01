extends RefCounted
# The three opponents of Góc Cờ; each one changes how the game is played, not only its strength.
const OPPONENTS := {
	"kid": {"name": "Tí Sún", "look": "Male_Child_01", "height": 1.3, "lift": 0.15, "level": "kid", "pay": 10, "minutes": 30, "rule": "Nó ăn gian. Bấm Bắt quả tang đúng lúc được phạt 5$.",
		"open": "Anh chơi hông? Em thắng là anh mua kem nha!", "win": "Hông chơi nữa! Má em kêu về!", "lose": "Hehe, anh thua thằng con nít kìa.", "draw": "Huề là em thắng nha.",
		"check": ["Ủa sao chiếu tướng em?", "Anh ăn gian!"], "taunt": ["Anh đi lẹ đi!", "Nước này em thấy rồi nha.", "Má em đánh còn hay hơn."]},
	"mid": {"name": "Khoa", "look": "Male_Adult_08", "height": 1.7, "level": "mid", "pay": 60, "minutes": 60, "rule": "Cờ chớp: anh chỉ có 5 phút. Hết giờ là thua.",
		"open": "Ván chớp nha. Đồng hồ chạy rồi đó.", "win": "Được. Hôm nay mày gặp may thôi.", "lose": "Hết phim. Đưa đây sáu chục.", "draw": "Thôi huề, đi cà phê.",
		"check": ["Ê khoan...", "Được đó."], "taunt": ["Nghĩ gì lâu dữ.", "Đồng hồ kìa.", "Tối nay mày qua bên kia cầu thiệt hả?"]},
	"hard": {"name": "Thầy Khải", "look": "Male_Adult_14", "height": 1.66, "level": "hard", "pay": 140, "minutes": 60, "rule": "Có người đứng sau lưng anh. Một lần mỗi ván, hãy lắng nghe.",
		"open": "Lâu lắm rồi mới có người dám ngồi xuống ghế đó.", "win": "Nước đó... có một đứa học trò từng đi y như vậy.", "lose": "Cậu nhìn quân, không nhìn người. Về tập thêm.", "draw": "Huề với tôi là khá lắm rồi.",
		"check": ["Hừm.", "Không tệ."], "taunt": ["Đừng vội.", "Trên bàn cờ, ai cũng phải đi đúng luật.", "Tôi dạy cờ ở Trường NEH mười bảy năm trước."]},
}
const LORE := [
	["Thầy Khải", "Hồi đó tôi phụ trách câu lạc bộ cờ. Có đứa lớp 10A6 thắng tôi bảy ván liền."],
	["Thầy Khải", "Thắng xong nó không cười. Nó chỉ xếp quân lại, thật ngay ngắn, rồi hỏi mai thầy có đánh nữa không."],
	["Thầy Khải", "Mấy đứa thua nó... thua nhiều thứ hơn một ván cờ, nên bắt nó trả. Tôi biết. Tôi đã không làm gì cả."],
	["Bạn", "Thầy đang nói về Bình An?"],
	["Thầy Khải", "Về đi. Tôi già rồi, chỉ còn nợ đứa nhỏ đó một ván."],
]
const CATCHES := ["Anh coi kìa, con chó nó cắn con mèo!", "Ủa anh, cái máy bay kìa!", "Anh ơi xe anh đổ kìa!"]
