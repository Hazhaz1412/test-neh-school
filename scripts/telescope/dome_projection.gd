extends RefCounted
# Layer 1: 3D Celestial Sphere, Camera Frustum Culling (FOV = 30 deg),
# Gnomonic + Barrel Distortion Lens Projection, Geodesic Distance Matrix on V_real,
# and 12-Constellation Animal Emblem & Guidebook Data.

const FOV_DEG := 30.0
const FOV_RAD := deg_to_rad(30.0)
const COS_HALF_FOV := cos(deg_to_rad(15.0))
const TAN_HALF_FOV := tan(deg_to_rad(15.0))
const LOCK_TOLERANCE_DEG := 4.0
const LOCK_TOLERANCE := deg_to_rad(4.0)
const GAUSSIAN_SIGMA := 0.015
const BG_STAR_COUNT := 1500
const BARREL_K1 := 0.18
const BARREL_K2 := 0.04
const SAFE_PASSCODE := "598418"

# 12 Zodiac Constellations in the Astronomy Guidebook Atlas.
# Each entry includes:
# - `stars`: local offsets (da, dd) and Bayer Greek symbols (alpha, beta, gamma...)
# - `edges`: constellation line segments
# - `animal_name`: representative animal / figure
# - `main_stars_info`: guide for identifying real stars vs decoy stars
# - `lore`: astronomical & mythological information for the lower half of the guidebook page
# - `animal_strokes`: polygonal strokes in (da, dd) space drawing the representative animal figure
const ZODIAC_ATLAS := [
	{
		"id": "aries",
		"name": "Bạch Dương (Aries)",
		"animal_name": "Cừu Vàng Chrysomallus",
		"code": "14",
		"main_stars_info": "Sao chính: Hamal (α, độ sáng 2.0) ở trán cừu, Sheratan (β) và Mesarthim (γ) tạo thành đường cong sừng cừu đặc trưng.",
		"lore": "Chòm sao mở đầu hoàng đạo phương Bắc. Hình dáng gồm 4 ngôi sao tạo thành một cung cong nhẹ từ Tây Bắc xuống Đông Nam, không có nhánh rẽ phụ.",
		"stars": [
			{"symbol": "α", "name": "Hamal (α)", "da": -0.065, "dd": 0.032, "mag": 2.0},
			{"symbol": "β", "name": "Sheratan (β)", "da": -0.015, "dd": 0.016, "mag": 2.6},
			{"symbol": "γ", "name": "Mesarthim (γ)", "da": 0.028, "dd": -0.010, "mag": 3.9},
			{"symbol": "δ", "name": "Botein (δ)", "da": 0.072, "dd": -0.042, "mag": 4.3},
		],
		"edges": [[0, 1], [1, 2], [2, 3]],
		"animal_strokes": [
			[Vector2(-0.085, 0.045), Vector2(-0.065, 0.068), Vector2(-0.035, 0.055), Vector2(-0.045, 0.030)],
			[Vector2(-0.065, 0.032), Vector2(-0.015, 0.022), Vector2(0.055, 0.005), Vector2(0.078, -0.038), Vector2(0.035, -0.058), Vector2(-0.035, -0.045), Vector2(-0.065, 0.032)],
		]
	},
	{
		"id": "taurus",
		"name": "Kim Ngưu (Taurus)",
		"animal_name": "Bò Thần Trắng Taurus",
		"code": "27",
		"main_stars_info": "Sao chính: Aldebaran (α, sao đỏ rất sáng) nằm ở mắt bò, Elnath (β) và Tianguan (ζ) vươn dài làm hai đầu cặp sừng chữ V.",
		"lore": "Nổi bật với cụm sao Hyades tạo thành khuôn mặt chữ V của bò thần và cặp sừng dài vươn về phía Đông Bắc. Hãy bỏ qua các sao lẻ nằm ngoài hai nhánh sừng.",
		"stars": [
			{"symbol": "α", "name": "Aldebaran (α)", "da": 0.000, "dd": -0.010, "mag": 0.85},
			{"symbol": "β", "name": "Elnath (β)", "da": -0.078, "dd": 0.062, "mag": 1.65},
			{"symbol": "γ", "name": "Hyadum I (γ)", "da": 0.035, "dd": -0.042, "mag": 3.65},
			{"symbol": "δ", "name": "Hyadum II (δ)", "da": 0.018, "dd": -0.025, "mag": 3.76},
			{"symbol": "ζ", "name": "Tianguan (ζ)", "da": -0.065, "dd": -0.052, "mag": 3.00},
		],
		"edges": [[1, 3], [3, 2], [2, 0], [0, 4]],
		"animal_strokes": [
			[Vector2(-0.078, 0.062), Vector2(0.005, -0.005), Vector2(-0.065, -0.052)],
			[Vector2(0.000, -0.010), Vector2(0.048, -0.018), Vector2(0.075, -0.045), Vector2(0.035, -0.068), Vector2(0.000, -0.035), Vector2(0.000, -0.010)],
		]
	},
	{
		"id": "gemini",
		"name": "Song Tử (Gemini)",
		"animal_name": "Cặp Song Sinh Castor & Pollux",
		"code": "38",
		"main_stars_info": "Sao chính: Castor (α) và Pollux (β) sáng rực ở hai đỉnh đầu song song; Alhena (γ) nằm ở gót chân phải.",
		"lore": "Có hình chữ Π (hai thân người đứng song song nối ngang ở đỉnh đầu α–β). Mọi ngôi sao nằm giữa lòng hai đường song song đều là sao nhiễu.",
		"stars": [
			{"symbol": "α", "name": "Castor (α)", "da": -0.045, "dd": 0.065, "mag": 1.58},
			{"symbol": "β", "name": "Pollux (β)", "da": 0.045, "dd": 0.056, "mag": 1.14},
			{"symbol": "γ", "name": "Alhena (γ)", "da": 0.052, "dd": -0.062, "mag": 1.93},
			{"symbol": "μ", "name": "Tejat (μ)", "da": -0.050, "dd": -0.056, "mag": 2.87},
			{"symbol": "ε", "name": "Mebsuta (ε)", "da": -0.048, "dd": 0.005, "mag": 3.06},
			{"symbol": "δ", "name": "Wasat (δ)", "da": 0.048, "dd": -0.005, "mag": 3.53},
		],
		"edges": [[3, 4], [4, 0], [0, 1], [1, 5], [5, 2]],
		"animal_strokes": [
			[Vector2(-0.058, 0.065), Vector2(-0.032, 0.065), Vector2(-0.038, -0.056), Vector2(-0.060, -0.056), Vector2(-0.058, 0.065)],
			[Vector2(0.032, 0.056), Vector2(0.058, 0.056), Vector2(0.060, -0.062), Vector2(0.038, -0.062), Vector2(0.032, 0.056)],
			[Vector2(-0.038, 0.025), Vector2(0.038, 0.020)],
		]
	},
	{
		"id": "cancer",
		"name": "Cự Giải (Cancer)",
		"animal_name": "Cua Khổng Lồ Karkinos",
		"code": "42",
		"main_stars_info": "Sao chính: Acubens (α) và Altarf (β) tạo hai càng cua phía dưới; Asellus Borealis (γ) và Australis (δ) nằm ở tâm mai cua.",
		"lore": "Chòm sao có hình chữ Y ngược (hoặc chữ nhân Λ có trục thẳng đứng). Tâm chữ Y nằm tại sao δ, tỏa ra hai chân α, β và đỉnh ι.",
		"stars": [
			{"symbol": "α", "name": "Acubens (α)", "da": -0.055, "dd": -0.052, "mag": 4.25},
			{"symbol": "β", "name": "Altarf (β)", "da": 0.062, "dd": -0.058, "mag": 3.52},
			{"symbol": "γ", "name": "Asellus Borealis (γ)", "da": 0.005, "dd": 0.025, "mag": 4.66},
			{"symbol": "δ", "name": "Asellus Australis (δ)", "da": 0.000, "dd": -0.012, "mag": 3.94},
			{"symbol": "ι", "name": "Iota Cancri (ι)", "da": 0.008, "dd": 0.068, "mag": 4.02},
		],
		"edges": [[0, 3], [3, 1], [3, 2], [2, 4]],
		"animal_strokes": [
			[Vector2(-0.042, 0.015), Vector2(0.000, 0.042), Vector2(0.042, 0.015), Vector2(0.035, -0.028), Vector2(-0.035, -0.028), Vector2(-0.042, 0.015)],
			[Vector2(-0.035, 0.015), Vector2(-0.068, 0.055), Vector2(-0.045, 0.068)],
			[Vector2(0.035, 0.015), Vector2(0.068, 0.055), Vector2(0.045, 0.068)],
		]
	},
	{
		"id": "leo",
		"name": "Sư Tử (Leo)",
		"animal_name": "Sư Tử Vàng Nemea",
		"code": "59",
		"main_stars_info": "Sao chính: Regulus (α) ở tim sư tử, Algieba (γ) ở cổ bờm hình lưỡi liềm (dấu hỏi ngược), Denebola (β) ở chóp đuôi phía Đông.",
		"lore": "Mục tiêu quan trọng trên bầu trời Đông Bắc. Phần đầu và bờm sư tử tạo thành hình Lưỡi Liềm (μ–ζ–γ–η–α), nối sang phần thân tam giác (θ–δ–β). Các sao lẻ phía trên lưng là sao nhiễu.",
		"stars": [
			{"symbol": "α", "name": "Regulus (α)", "da": -0.058, "dd": -0.058, "mag": 1.35},
			{"symbol": "η", "name": "Al Jabhah (η)", "da": -0.052, "dd": -0.008, "mag": 3.48},
			{"symbol": "γ", "name": "Algieba (γ)", "da": -0.032, "dd": 0.038, "mag": 2.08},
			{"symbol": "ζ", "name": "Adhafera (ζ)", "da": -0.055, "dd": 0.074, "mag": 3.44},
			{"symbol": "μ", "name": "Rasalas (μ)", "da": -0.088, "dd": 0.062, "mag": 3.88},
			{"symbol": "δ", "name": "Zosma (δ)", "da": 0.038, "dd": 0.024, "mag": 2.56},
			{"symbol": "θ", "name": "Chertan (θ)", "da": 0.034, "dd": -0.028, "mag": 3.34},
			{"symbol": "β", "name": "Denebola (β)", "da": 0.088, "dd": -0.006, "mag": 2.14},
		],
		"edges": [[4, 3], [3, 2], [2, 1], [1, 0], [0, 6], [6, 5], [5, 7]],
		"animal_strokes": [
			# Lion head, mane, back, tail, and crouched paws around the Leo stars:
			[Vector2(-0.095, 0.058), Vector2(-0.075, 0.082), Vector2(-0.042, 0.082), Vector2(-0.018, 0.048), Vector2(0.042, 0.032), Vector2(0.092, -0.004), Vector2(0.042, -0.038), Vector2(-0.062, -0.066), Vector2(-0.092, -0.052), Vector2(-0.062, -0.012), Vector2(-0.095, 0.058)],
			[Vector2(0.088, -0.006), Vector2(0.105, 0.028), Vector2(0.092, 0.052)],
		]
	},
	{
		"id": "virgo",
		"name": "Xử Nữ (Virgo)",
		"animal_name": "Nữ Thần Đồng Nội Astraea",
		"code": "63",
		"main_stars_info": "Sao chính: Spica (α, bông lúa sáng nhất) ở phía dưới Tây Nam, Porrima (γ) ở tâm giao điểm và Zavijava (β) ở cánh tay phải.",
		"lore": "Hình dáng như cành lúa mạch phân nhánh tại sao γ (Porrima). Đường nối chuẩn đi dọc nhánh chính rồi rẽ tại γ.",
		"stars": [
			{"symbol": "α", "name": "Spica (α)", "da": -0.062, "dd": -0.065, "mag": 0.97},
			{"symbol": "γ", "name": "Porrima (γ)", "da": 0.000, "dd": -0.008, "mag": 2.74},
			{"symbol": "δ", "name": "Auva (δ)", "da": -0.022, "dd": 0.035, "mag": 3.38},
			{"symbol": "ε", "name": "Vindemiatrix (ε)", "da": -0.048, "dd": 0.075, "mag": 2.83},
			{"symbol": "β", "name": "Zavijava (β)", "da": 0.068, "dd": 0.015, "mag": 3.61},
		],
		"edges": [[0, 1], [1, 2], [2, 3], [1, 4]],
		"animal_strokes": [
			[Vector2(0.005, 0.068), Vector2(0.038, 0.022), Vector2(0.068, 0.015), Vector2(0.012, -0.018), Vector2(-0.062, -0.065), Vector2(-0.025, 0.015), Vector2(-0.048, 0.075), Vector2(0.005, 0.068)],
		]
	},
	{
		"id": "libra",
		"name": "Thiên Bình (Libra)",
		"animal_name": "Cán Cân Công Lý Themis",
		"code": "71",
		"main_stars_info": "Sao chính: Zubeneschamali (β) ở đỉnh cán cân, Zubenelgenubi (α) và Zubenelhakrabi (γ) ở hai đầu đòn cân.",
		"lore": "Chòm sao tứ giác cân đối duy nhất trên hoàng đạo, tượng trưng cho hai đĩa cân treo dưới đỉnh β.",
		"stars": [
			{"symbol": "α", "name": "Zubenelgenubi (α)", "da": 0.055, "dd": -0.010, "mag": 2.75},
			{"symbol": "β", "name": "Zubeneschamali (β)", "da": 0.005, "dd": 0.062, "mag": 2.61},
			{"symbol": "γ", "name": "Zubenelhakrabi (γ)", "da": -0.058, "dd": 0.005, "mag": 3.91},
			{"symbol": "σ", "name": "Brachium (σ)", "da": 0.012, "dd": -0.065, "mag": 3.29},
		],
		"edges": [[3, 0], [0, 1], [1, 2]],
		"animal_strokes": [
			[Vector2(-0.062, 0.005), Vector2(0.005, 0.066), Vector2(0.060, -0.008)],
			[Vector2(-0.078, -0.038), Vector2(-0.058, 0.005), Vector2(-0.038, -0.038), Vector2(-0.078, -0.038)],
			[Vector2(0.035, -0.052), Vector2(0.055, -0.010), Vector2(0.075, -0.052), Vector2(0.035, -0.052)],
		]
	},
	{
		"id": "scorpius",
		"name": "Thiên Yết (Scorpius)",
		"animal_name": "Bọ Cạp Khổng Lồ Scorpius",
		"code": "84",
		"main_stars_info": "Sao chính: Antares (α) đỏ rực ở tim bọ cạp, Acrab (β) ở đầu càng Tây Bắc, và Shaula (γ) ở ngòi độc uốn cong hình móc câu chữ J.",
		"lore": "Mục tiêu quan trọng trên bầu trời Tây Bắc. Chòm sao là một chuỗi 9 sao uốn lượn liên tục hình chữ J từ càng (β–δ) qua tim (α) xuống đuôi móc câu (ζ–η–θ–γ). Bỏ qua các sao lẻ nằm ngoài đường cong chữ J.",
		"stars": [
			{"symbol": "β", "name": "Acrab (β)", "da": -0.078, "dd": 0.068, "mag": 2.62},
			{"symbol": "δ", "name": "Dschubba (δ)", "da": -0.064, "dd": 0.032, "mag": 2.32},
			{"symbol": "α", "name": "Antares (α)", "da": -0.032, "dd": 0.012, "mag": 1.06},
			{"symbol": "τ", "name": "Paikauhale (τ)", "da": -0.010, "dd": -0.018, "mag": 2.82},
			{"symbol": "ε", "name": "Larawag (ε)", "da": 0.008, "dd": -0.054, "mag": 2.29},
			{"symbol": "ζ", "name": "Zeta Scorpii (ζ)", "da": 0.036, "dd": -0.076, "mag": 3.62},
			{"symbol": "η", "name": "Eta Scorpii (η)", "da": 0.068, "dd": -0.064, "mag": 3.33},
			{"symbol": "θ", "name": "Sargas (θ)", "da": 0.084, "dd": -0.030, "mag": 1.87},
			{"symbol": "γ", "name": "Shaula (γ)", "da": 0.064, "dd": 0.006, "mag": 1.62},
		],
		"edges": [[0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [5, 6], [6, 7], [7, 8]],
		"animal_strokes": [
			# Scorpion pincers, segmented body around Antares, and curved stinger tail:
			[Vector2(-0.096, 0.082), Vector2(-0.078, 0.068), Vector2(-0.064, 0.032), Vector2(-0.092, 0.022)],
			[Vector2(-0.052, 0.084), Vector2(-0.064, 0.032), Vector2(-0.018, 0.025), Vector2(0.012, -0.018), Vector2(0.024, -0.058), Vector2(0.068, -0.064), Vector2(0.088, -0.028), Vector2(0.064, 0.012), Vector2(0.048, -0.002)],
			[Vector2(-0.064, 0.032), Vector2(-0.045, -0.005), Vector2(-0.015, -0.035), Vector2(0.015, -0.068), Vector2(0.036, -0.076)],
		]
	},
	{
		"id": "sagittarius",
		"name": "Nhân Mã (Sagittarius)",
		"animal_name": "Cung Thủ Nhân Mã Chiron",
		"code": "96",
		"main_stars_info": "Sao chính: Rukbat (α) và Arkab (β) ở chân trước, Alnasl (γ) ở mũi tên, Kaus Borealis (λ) ở đỉnh cánh cung.",
		"lore": "Hình dáng nổi tiếng giống chiếc Ấm Trà (Teapot) hoặc cánh cung giương về phía Thiên Yết.",
		"stars": [
			{"symbol": "α", "name": "Rukbat (α)", "da": -0.065, "dd": -0.062, "mag": 3.97},
			{"symbol": "β", "name": "Arkab (β)", "da": -0.025, "dd": -0.032, "mag": 3.96},
			{"symbol": "γ", "name": "Alnasl (γ)", "da": 0.048, "dd": -0.015, "mag": 2.99},
			{"symbol": "δ", "name": "Kaus Media (δ)", "da": 0.012, "dd": 0.018, "mag": 2.70},
			{"symbol": "ε", "name": "Kaus Australis (ε)", "da": 0.022, "dd": -0.052, "mag": 1.85},
			{"symbol": "λ", "name": "Kaus Borealis (λ)", "da": -0.008, "dd": 0.065, "mag": 2.81},
		],
		"edges": [[0, 1], [1, 4], [4, 2], [2, 3], [3, 5]],
		"animal_strokes": [
			[Vector2(-0.008, 0.065), Vector2(0.032, 0.018), Vector2(0.022, -0.052), Vector2(-0.008, 0.065)],
			[Vector2(-0.045, 0.005), Vector2(0.058, -0.015)],
			[Vector2(-0.065, -0.062), Vector2(-0.025, -0.032), Vector2(0.022, -0.052)],
		]
	},
	{
		"id": "capricornus",
		"name": "Ma Kết (Capricornus)",
		"animal_name": "Dê Biển Thần Thoại Pricus",
		"code": "05",
		"main_stars_info": "Sao chính: Algedi (α) và Dabih (β) ở sừng dê phía Đông Bắc; Deneb Algedi (δ) ở chóp đuôi cá phía Tây Bắc.",
		"lore": "Có hình chiếc thuyền tam giác cong nối từ sừng dê (α–β) xuống bụng (ω) rồi vắt lên đuôi cá (γ–δ).",
		"stars": [
			{"symbol": "α", "name": "Algedi (α)", "da": 0.068, "dd": 0.055, "mag": 3.57},
			{"symbol": "β", "name": "Dabih (β)", "da": 0.052, "dd": 0.020, "mag": 3.08},
			{"symbol": "ω", "name": "Omega Cap (ω)", "da": 0.005, "dd": -0.058, "mag": 4.11},
			{"symbol": "γ", "name": "Nashira (γ)", "da": -0.045, "dd": -0.012, "mag": 3.68},
			{"symbol": "δ", "name": "Deneb Algedi (δ)", "da": -0.072, "dd": 0.022, "mag": 2.87},
		],
		"edges": [[0, 1], [1, 2], [2, 3], [3, 4]],
		"animal_strokes": [
			[Vector2(0.068, 0.055), Vector2(0.052, 0.020), Vector2(0.005, -0.058), Vector2(-0.072, 0.022), Vector2(0.068, 0.055)],
		]
	},
	{
		"id": "aquarius",
		"name": "Bảo Bình (Aquarius)",
		"animal_name": "Thủy Thần & Bình Nước Ngân Hà",
		"code": "18",
		"main_stars_info": "Sao chính: Sadalsuud (β) và Sadalmelik (α) ở vai người ôm bình, Sadachbia (γ) ở miệng bình nước chảy zigzag xuống Skat (δ) và Albali (ε).",
		"lore": "Mục tiêu quan trọng trên bầu trời Tây Nam. Gồm 8 ngôi sao nối thành dòng nước chảy hình zíc-zắc mềm từ Tây Bắc (β–α–γ–ζ–η) đổ xuống Đông Nam (θ–δ–ε). Loại bỏ các sao nhiễu nằm tách biệt phía dưới trái và trên phải.",
		"stars": [
			{"symbol": "β", "name": "Sadalsuud (β)", "da": -0.082, "dd": 0.046, "mag": 2.91},
			{"symbol": "α", "name": "Sadalmelik (α)", "da": -0.046, "dd": 0.068, "mag": 2.96},
			{"symbol": "γ", "name": "Sadachbia (γ)", "da": -0.014, "dd": 0.040, "mag": 3.84},
			{"symbol": "ζ", "name": "Zeta Aquarii (ζ)", "da": 0.016, "dd": 0.056, "mag": 3.65},
			{"symbol": "η", "name": "Eta Aquarii (η)", "da": 0.048, "dd": 0.030, "mag": 4.02},
			{"symbol": "θ", "name": "Ancha (θ)", "da": 0.024, "dd": -0.010, "mag": 4.16},
			{"symbol": "δ", "name": "Skat (δ)", "da": 0.046, "dd": -0.054, "mag": 3.27},
			{"symbol": "ε", "name": "Albali (ε)", "da": 0.082, "dd": -0.068, "mag": 3.77},
		],
		"edges": [[0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [5, 6], [6, 7]],
		"animal_strokes": [
			# Sacred Amphora / Water Urn and twin flowing celestial water streams:
			[Vector2(-0.086, 0.046), Vector2(-0.046, 0.074), Vector2(0.018, 0.062), Vector2(0.054, 0.032), Vector2(0.012, 0.012), Vector2(-0.048, 0.024), Vector2(-0.086, 0.046)],
			[Vector2(0.016, 0.056), Vector2(0.048, 0.030), Vector2(0.024, -0.010), Vector2(0.046, -0.054), Vector2(0.082, -0.068)],
			[Vector2(0.002, 0.044), Vector2(0.010, 0.002), Vector2(0.028, -0.042), Vector2(0.062, -0.072)],
		]
	},
	{
		"id": "pisces",
		"name": "Song Ngư (Pisces)",
		"animal_name": "Đôi Cá Thần Aphrodite",
		"code": "29",
		"main_stars_info": "Sao chính: Alrescha (α) tại nút thắt dây bạc ở góc dưới Tây Nam, nối hai nhánh dây về phía Alpherg (η) và Fumalsamakah (β).",
		"lore": "Hình chữ V lệch có đỉnh nhọn tại sao α (Alrescha), hai nhánh vươn lên tượng trưng cho sợi dây buộc đôi cá.",
		"stars": [
			{"symbol": "η", "name": "Alpherg (η)", "da": -0.062, "dd": 0.062, "mag": 3.62},
			{"symbol": "α", "name": "Alrescha (α)", "da": -0.055, "dd": -0.048, "mag": 3.82},
			{"symbol": "ω", "name": "Omega Psc (ω)", "da": 0.018, "dd": -0.020, "mag": 4.01},
			{"symbol": "γ", "name": "Gamma Psc (γ)", "da": 0.068, "dd": 0.012, "mag": 3.69},
			{"symbol": "β", "name": "Fumalsamakah (β)", "da": 0.082, "dd": 0.048, "mag": 4.53},
		],
		"edges": [[0, 1], [1, 2], [2, 3], [3, 4]],
		"animal_strokes": [
			[Vector2(-0.078, 0.055), Vector2(-0.062, 0.075), Vector2(-0.046, 0.055), Vector2(-0.062, 0.038), Vector2(-0.078, 0.055)],
			[Vector2(0.065, 0.045), Vector2(0.082, 0.065), Vector2(0.096, 0.045), Vector2(0.082, 0.028), Vector2(0.065, 0.045)],
		]
	}
]

# The 3 Target Anomaly Regions on the continuous 3D Celestial Sphere.
const ANOMALY_DEFS := [
	{
		"anomaly_index": 0,
		"anomaly_title": "Tọa độ Dị thường #1 · Vùng Đông Bắc (ψ ≈ 35°–50°, θ ≈ 22°–34°)",
		"hint_psi": deg_to_rad(36.0),
		"hint_theta": deg_to_rad(22.0),
		"center_alpha": deg_to_rad(42.0),
		"center_delta": deg_to_rad(28.0),
		"zodiac_id": "leo",
		"passcode_digits": "59",
		"decoys": [
			{"name": "Sao nhiễu N-1", "da": 0.002, "dd": 0.062, "mag": 2.9},
			{"name": "Sao nhiễu N-2", "da": -0.012, "dd": -0.068, "mag": 3.1},
			{"name": "Sao nhiễu N-3", "da": 0.072, "dd": 0.054, "mag": 2.8},
		]
	},
	{
		"anomaly_index": 1,
		"anomaly_title": "Tọa độ Dị thường #2 · Vùng Tây Bắc (ψ ≈ 140°–155°, θ ≈ 28°–40°)",
		"hint_psi": deg_to_rad(141.0),
		"hint_theta": deg_to_rad(28.0),
		"center_alpha": deg_to_rad(148.0),
		"center_delta": deg_to_rad(34.0),
		"zodiac_id": "scorpius",
		"passcode_digits": "84",
		"decoys": [
			{"name": "Sao nhiễu N-1", "da": -0.048, "dd": -0.056, "mag": 2.8},
			{"name": "Sao nhiễu N-2", "da": 0.022, "dd": 0.058, "mag": 3.0},
			{"name": "Sao nhiễu N-3", "da": 0.082, "dd": 0.048, "mag": 2.9},
		]
	},
	{
		"anomaly_index": 2,
		"anomaly_title": "Tọa độ Dị thường #3 · Vùng Tây Nam (ψ ≈ 252°–268°, θ ≈ 24°–36°)",
		"hint_psi": deg_to_rad(253.0),
		"hint_theta": deg_to_rad(24.0),
		"center_alpha": deg_to_rad(260.0),
		"center_delta": deg_to_rad(30.0),
		"zodiac_id": "aquarius",
		"passcode_digits": "18",
		"decoys": [
			{"name": "Sao nhiễu N-1", "da": -0.056, "dd": -0.036, "mag": 2.9},
			{"name": "Sao nhiễu N-2", "da": -0.008, "dd": -0.064, "mag": 3.1},
			{"name": "Sao nhiễu N-3", "da": 0.072, "dd": 0.058, "mag": 2.8},
		]
	}
]

var constellations: Array = []
var background_stars: Array[Dictionary] = []
var parallax_clouds: Array[Dictionary] = []
var dense_cluster_24: Dictionary = {}

func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261115
	_build_3d_celestial_sphere(rng)

func _build_3d_celestial_sphere(rng: RandomNumberGenerator) -> void:
	constellations.clear()
	for idx in range(ANOMALY_DEFS.size()):
		var adef: Dictionary = ANOMALY_DEFS[idx]
		var zinfo: Dictionary = get_zodiac_by_id(str(adef.zodiac_id))
		var c_alpha: float = float(adef.center_alpha)
		var c_delta: float = float(adef.center_delta)
		var center_vec := spherical_to_cartesian(c_alpha, c_delta)

		var stars_list: Array = []
		var real_templates: Array = zinfo.get("stars", [])
		var star_id := 0
		for st_tpl in real_templates:
			var alpha_i: float = c_alpha + float(st_tpl.da) / maxf(cos(c_delta), 0.35)
			var delta_i: float = c_delta + float(st_tpl.dd)
			var p_exact := spherical_to_cartesian(alpha_i, delta_i)
			var noise := Vector3(
				rng.randfn(0.0, GAUSSIAN_SIGMA * 0.12),
				rng.randfn(0.0, GAUSSIAN_SIGMA * 0.12),
				rng.randfn(0.0, GAUSSIAN_SIGMA * 0.12)
			)
			var p_vec := (p_exact + noise).normalized()
			stars_list.append({
				"id": star_id,
				"name": str(st_tpl.name),
				"symbol": str(st_tpl.symbol),
				"da": float(st_tpl.da),
				"dd": float(st_tpl.dd),
				"alpha": alpha_i,
				"delta": delta_i,
				"theta": alpha_i,
				"phi": delta_i,
				"mag": float(st_tpl.mag),
				"is_decoy": false,
				"pos_3d": p_vec
			})
			star_id += 1

		var decoys: Array = adef.get("decoys", [])
		for dec_tpl in decoys:
			var alpha_d: float = c_alpha + float(dec_tpl.da) / maxf(cos(c_delta), 0.35)
			var delta_d: float = c_delta + float(dec_tpl.dd)
			var p_dec := spherical_to_cartesian(alpha_d, delta_d, rng, GAUSSIAN_SIGMA)
			stars_list.append({
				"id": star_id,
				"name": str(dec_tpl.name),
				"symbol": "",
				"da": float(dec_tpl.da),
				"dd": float(dec_tpl.dd),
				"alpha": alpha_d,
				"delta": delta_d,
				"theta": alpha_d,
				"phi": delta_d,
				"mag": float(dec_tpl.mag),
				"is_decoy": true,
				"pos_3d": p_dec
			})
			star_id += 1

		constellations.append({
			"id": str(adef.zodiac_id),
			"anomaly_index": idx,
			"anomaly_title": str(adef.anomaly_title),
			"name": str(zinfo.name),
			"animal_name": str(zinfo.get("animal_name", "")),
			"subtitle": "Bitmask DP (D_ij = arccos(P_i·P_j) trên V_real)",
			"passcode_digits": str(adef.passcode_digits),
			"lock_alpha": c_alpha,
			"lock_delta": c_delta,
			"lock_theta": c_alpha,
			"lock_phi": c_delta,
			"center_3d": center_vec,
			"initial_theta": float(adef.hint_psi),
			"initial_phi": float(adef.hint_theta),
			"real_count": real_templates.size(),
			"decoy_count": decoys.size(),
			"stars": stars_list
		})

	background_stars.clear()
	background_stars.resize(BG_STAR_COUNT)
	for i in range(BG_STAR_COUNT):
		var alpha_bg := rng.randf_range(0.0, TAU)
		var u_elev := rng.randf_range(0.03, 0.98)
		var delta_bg := asin(u_elev)
		var p_bg := spherical_to_cartesian(alpha_bg, delta_bg, rng, GAUSSIAN_SIGMA)
		background_stars[i] = {
			"alpha": alpha_bg,
			"delta": delta_bg,
			"pos_3d": p_bg,
			"size": rng.randf_range(0.9, 2.3),
			"brightness": rng.randf_range(0.20, 0.82),
			"twinkle": rng.randf() * TAU
		}

	parallax_clouds.clear()
	for i in range(28):
		parallax_clouds.append({
			"base_x": rng.randf_range(-340.0, 340.0),
			"base_y": rng.randf_range(-260.0, 260.0),
			"radius": rng.randf_range(55.0, 125.0),
			"parallax": rng.randf_range(0.32, 0.78),
			"drift_speed": rng.randf_range(6.0, 15.0),
			"alpha": rng.randf_range(0.035, 0.075)
		})

	var cluster_stars: Array = []
	var c_a := deg_to_rad(310.0)
	var c_d := deg_to_rad(36.0)
	for k in range(24):
		var ring_idx := k / 8
		var r_ang := 0.045 * float(ring_idx + 1)
		var ang := TAU * float(k % 8) / 8.0 + float(ring_idx) * 0.35
		var sa := c_a + r_ang * cos(ang)
		var sd := c_d + r_ang * sin(ang)
		cluster_stars.append({
			"id": k,
			"name": "Tinh tú S-%02d" % (k + 1),
			"symbol": "",
			"alpha": sa,
			"delta": sd,
			"theta": sa,
			"phi": sd,
			"mag": 2.4 + float(k % 4) * 0.4,
			"is_decoy": false,
			"pos_3d": spherical_to_cartesian(sa, sd, rng, GAUSSIAN_SIGMA * 0.1)
		})
	dense_cluster_24 = {
		"id": "vela_carina",
		"name": "Quần Tinh Ngân Hà (N = 24)",
		"lock_alpha": c_a,
		"lock_delta": c_d,
		"lock_theta": c_a,
		"lock_phi": c_d,
		"stars": cluster_stars
	}

static func get_zodiac_by_id(zodiac_id: String) -> Dictionary:
	for z in ZODIAC_ATLAS:
		if str(z.id) == zodiac_id:
			return z
	return ZODIAC_ATLAS[0]

# Draws the celestial animal / figure illustration for a constellation onto any CanvasItem.
static func draw_constellation_animal(canvas: CanvasItem, zodiac_id: String, center: Vector2, scale_xy: Vector2, alpha_val: float) -> void:
	if alpha_val <= 0.01:
		return
	var zinfo := get_zodiac_by_id(zodiac_id)
	var strokes: Array = zinfo.get("animal_strokes", [])
	var glow_col := Color(1.0, 0.84, 0.38, 0.22 * alpha_val)
	var line_col := Color(1.0, 0.90, 0.48, 0.72 * alpha_val)
	var fill_col := Color(0.98, 0.82, 0.35, 0.11 * alpha_val)

	for stroke in strokes:
		var poly := PackedVector2Array()
		for pt: Vector2 in stroke:
			poly.append(center + Vector2(pt.x * scale_xy.x, -pt.y * scale_xy.y))
		if poly.size() >= 3 and poly[0].distance_to(poly[poly.size() - 1]) < 4.0:
			var closed := poly.duplicate()
			closed.resize(closed.size() - 1)
			if Geometry2D.triangulate_polygon(closed).size() > 0:
				canvas.draw_colored_polygon(closed, fill_col)
		for k in range(poly.size() - 1):
			canvas.draw_line(poly[k], poly[k + 1], glow_col, 7.0, true)
			canvas.draw_line(poly[k], poly[k + 1], line_col, 2.2, true)
		for pt_screen in poly:
			canvas.draw_circle(pt_screen, 3.0, Color(1.0, 0.92, 0.58, 0.45 * alpha_val))

static func spherical_to_cartesian(alpha: float, delta: float, rng: RandomNumberGenerator = null, sigma := 0.0) -> Vector3:
	var cd := cos(delta)
	var p := Vector3(cd * cos(alpha), sin(delta), cd * sin(alpha))
	if sigma > 0.0 and rng != null:
		p += Vector3(
			rng.randfn(0.0, sigma),
			rng.randfn(0.0, sigma),
			rng.randfn(0.0, sigma)
		)
	return p.normalized()

static func spherical_to_unit_vector(alpha: float, delta: float) -> Vector3:
	return spherical_to_cartesian(alpha, delta)

static func camera_forward(psi: float, theta: float) -> Vector3:
	return spherical_to_cartesian(psi, theta)

static func frustum_cull(p: Vector3, f_cam: Vector3, fov_rad := FOV_RAD) -> bool:
	return p.dot(f_cam) >= cos(fov_rad * 0.5)

static func project_point_3d(p: Vector3, cam_psi: float, cam_theta: float, lens_radius: float, center := Vector2.ZERO, fov_rad := FOV_RAD) -> Dictionary:
	var ct := cos(cam_theta)
	var st := sin(cam_theta)
	var cp := cos(cam_psi)
	var sp := sin(cam_psi)

	var f_cam := Vector3(ct * cp, st, ct * sp)
	var dot_f := p.dot(f_cam)
	var cos_half := cos(fov_rad * 0.5)
	if dot_f < cos_half or dot_f <= 0.05:
		return {"pos": center, "visible": false, "depth": dot_f, "gnomonic_uv": Vector2.ZERO}

	var r_cam := Vector3(-sp, 0.0, cp)
	var u_cam := Vector3(-st * cp, ct, -st * sp)

	var xc := p.dot(r_cam)
	var yc := p.dot(u_cam)
	var tan_half := tan(fov_rad * 0.5)

	var u := (xc / dot_f) / tan_half
	var v := (-yc / dot_f) / tan_half

	var r2 := u * u + v * v
	var barrel_scale := (1.0 + BARREL_K1 * r2 + BARREL_K2 * r2 * r2) / (1.0 + BARREL_K1 + BARREL_K2)
	var screen_offset := Vector2(u, v) * (barrel_scale * lens_radius)

	return {
		"pos": center + screen_offset,
		"visible": screen_offset.length() <= lens_radius - 4.0,
		"depth": dot_f,
		"gnomonic_uv": Vector2(u, v),
		"barrel_scale": barrel_scale
	}

static func project_star(alpha: float, delta: float, cam_psi: float, cam_theta: float, lens_radius: float, center := Vector2.ZERO) -> Dictionary:
	var p := spherical_to_cartesian(alpha, delta)
	return project_point_3d(p, cam_psi, cam_theta, lens_radius, center, FOV_RAD)

static func project_constellation(stars: Array, cam_psi: float, cam_theta: float, lens_radius: float, center := Vector2.ZERO) -> PackedVector2Array:
	var result := PackedVector2Array()
	result.resize(stars.size())
	for i in range(stars.size()):
		var star: Dictionary = stars[i]
		var p: Vector3 = star.get("pos_3d", spherical_to_cartesian(float(star.get("alpha", star.get("theta", 0.0))), float(star.get("delta", star.get("phi", 0.0)))))
		var proj := project_point_3d(p, cam_psi, cam_theta, lens_radius, center, FOV_RAD)
		result[i] = proj.pos
	return result

static func angular_error(cam_psi: float, cam_theta: float, target_alpha: float, target_delta: float) -> float:
	var u := spherical_to_cartesian(cam_psi, cam_theta)
	var v := spherical_to_cartesian(target_alpha, target_delta)
	return acos(clampf(u.dot(v), -1.0, 1.0))

static func is_locked_angle(cam_psi: float, cam_theta: float, target_alpha: float, target_delta: float, tolerance := LOCK_TOLERANCE) -> bool:
	return angular_error(cam_psi, cam_theta, target_alpha, target_delta) <= tolerance

func find_locked_constellation(cam_psi: float, cam_theta: float, tolerance := LOCK_TOLERANCE) -> int:
	var best_idx := -1
	var best_err := tolerance
	for i in range(constellations.size()):
		var c: Dictionary = constellations[i]
		var err := angular_error(cam_psi, cam_theta, float(c.lock_alpha), float(c.lock_delta))
		if err <= best_err:
			best_err = err
			best_idx = i
	return best_idx

static func compute_spherical_distance_matrix(stars: Array) -> Dictionary:
	var real_indices := PackedInt32Array()
	var real_vectors: Array[Vector3] = []
	for i in range(stars.size()):
		var st: Dictionary = stars[i]
		if not bool(st.get("is_decoy", false)):
			real_indices.append(i)
			var p: Vector3 = st.get("pos_3d", spherical_to_cartesian(float(st.get("alpha", st.get("theta", 0.0))), float(st.get("delta", st.get("phi", 0.0)))))
			real_vectors.append(p.normalized())

	var n := real_vectors.size()
	var flat := PackedFloat32Array()
	flat.resize(n * n)
	var matrix_2d: Array = []
	matrix_2d.resize(n)
	for i in range(n):
		var row := PackedFloat32Array()
		row.resize(n)
		var pi := real_vectors[i]
		for j in range(n):
			var d := 0.0
			if i != j:
				d = acos(clampf(pi.dot(real_vectors[j]), -1.0, 1.0))
			flat[i * n + j] = d
			row[j] = d
		matrix_2d[i] = row
	return {
		"n": n,
		"flat": flat,
		"matrix": matrix_2d,
		"real_indices": real_indices,
		"metric": "spherical_arccos"
	}

static func compute_distance_matrix(points_2d: PackedVector2Array) -> Dictionary:
	var n := points_2d.size()
	var flat := PackedFloat32Array()
	flat.resize(n * n)
	var matrix_2d: Array = []
	matrix_2d.resize(n)
	for i in range(n):
		var row := PackedFloat32Array()
		row.resize(n)
		var pi := points_2d[i]
		for j in range(n):
			var d := 0.0 if i == j else pi.distance_to(points_2d[j])
			flat[i * n + j] = d
			row[j] = d
		matrix_2d[i] = row
	return {
		"n": n,
		"flat": flat,
		"matrix": matrix_2d,
		"metric": "euclidean_2d"
	}
