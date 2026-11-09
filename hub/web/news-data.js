// Placeholder articles. Province, people and events are all invented; none refers to a real one.
const SITES = {
  'baohailam.vn': {
    name: 'Báo Hải Lâm',
    tagline: 'Thông tin chính thức của tỉnh Hải Lâm',
    address: 'Thành phố Hải Lâm, tỉnh Hải Lâm',
    layout: 'broadsheet',
    sections: ['Thời sự', 'Chính sách', 'Kinh tế', 'Giáo dục', 'Văn hóa'],
    articles: [
      { slug: 'hai-lam-thi-diem-den-duong-biet-chao', section: 'Thời sự', scene: 'city', hours: 2, author: 'Trần Văn Khiêm', title: 'Hải Lâm thí điểm đèn đường biết chào người đi bộ', sapo: 'Tỉnh Hải Lâm vừa lắp 40 cột đèn có loa tại phường Cổ Đằng, tự nói "chúc bà con buổi tối an lành" khi có người đi qua.', body: ['Sở Hạ tầng tỉnh cho biết chương trình nhằm tăng tính thân thiện của đô thị về đêm. Sau một tuần vận hành, nhiều hộ dân phản ánh đèn chào cả mèo và lá cây bay ngang.', 'Đơn vị thi công đang điều chỉnh độ nhạy và hứa sẽ giảm âm lượng sau 22 giờ.'], keywords: 'den duong co dang do thi' },
      { slug: 'quy-dinh-moi-ve-treo-quan-ao-ban-cong', section: 'Chính sách', scene: 'city', hours: 5, author: 'Lê Thị Huyền', title: 'Dự thảo quy định màu quần áo phơi ở ban công mặt phố', sapo: 'Dự thảo lấy ý kiến khuyến khích các gam màu trung tính nhằm giữ mỹ quan khu phố Bến Trầu, phường Cổ Đằng.', body: ['Theo tờ trình, người dân được khuyến khích phơi đồ theo màu đồng bộ từng tầng. Nội dung này không kèm chế tài xử phạt.', 'Thời hạn góp ý kết thúc vào cuối tháng; ý kiến gửi về bộ phận một cửa của phường.'], keywords: 'du thao quy dinh ban cong ben trau' },
      { slug: 'thu-hoach-dua-hau-vuong', section: 'Kinh tế', scene: 'field', hours: 9, author: 'Phạm Quốc Bảo', title: 'Nông dân Hải Lâm thu hoạch vụ dưa hấu vuông đầu tiên', sapo: 'Khoảng 3 ha dưa trồng trong khuôn gỗ đã cho trái, thương lái trả giá gấp đôi dưa tròn vì dễ xếp thùng.', body: ['Hợp tác xã Đồng Muối cho biết tỉ lệ dưa nứt còn cao nhưng đầu ra ổn định.', 'Vụ tới, hợp tác xã dự kiến thử dưa hình tam giác để phục vụ thị trường quà biếu.'], keywords: 'dua hau nong dan hop tac xa dong muoi' },
      { slug: 'le-hoi-tha-dieu-dem', section: 'Văn hóa', scene: 'sky', hours: 20, author: 'Đỗ Minh Tâm', title: 'Lễ hội thả diều đêm trở lại sau ba năm gián đoạn', sapo: 'Hơn 200 cánh diều gắn đèn sẽ bay trên bãi sông Trầu vào tối thứ Bảy tuần này.', body: ['Ban tổ chức khuyến cáo người xem không đứng gần đường dây điện.', 'Chương trình năm nay có thêm hạng mục diều kể chuyện dành cho học sinh.'], keywords: 'le hoi dieu song trau' },
      { slug: 'hop-giao-ban-thang', section: 'Thời sự', scene: 'hall', hours: 27, author: 'Trần Văn Khiêm', title: 'Giao ban tháng: thống nhất đổi giờ tưới cây công viên', sapo: 'Cuộc họp kéo dài bốn tiếng đã thống nhất lùi giờ tưới cây từ 5 giờ 30 sang 5 giờ 45.', body: ['Các đại biểu đánh giá 15 phút này sẽ giúp giảm tình trạng tưới trúng người tập thể dục.', 'Quyết định có hiệu lực từ đầu tháng sau.'], keywords: 'giao ban tuoi cay cong vien' },
    ],
  },
  'nhipcodang.vn': {
    name: 'Nhịp Cổ Đằng',
    tagline: 'Chuyện nóng phường Cổ Đằng',
    address: 'Khu phố Bến Trầu, phường Cổ Đằng',
    layout: 'tabloid',
    sections: ['Nóng', 'Đời sống', 'Học đường', 'Lạ', 'Giải trí'],
    articles: [
      { slug: 'con-ngong-doi-phi-gui-xe', section: 'Nóng', scene: 'city', hours: 1, author: 'Thanh Tít', title: 'Clip: con ngỗng đứng chắn cổng chung cư, không cho xe ra', sapo: 'Cư dân khu phố Bến Trầu dở khóc dở cười vì chú ngỗng cứ 7 giờ sáng lại ra đứng giữa lối đi như bảo vệ thực thụ.', body: ['Chủ của ngỗng chưa được xác định. Ban quản lý đã thử dụ bằng rau muống nhưng không thành công.', 'Clip đã đạt nửa triệu lượt xem trong một buổi tối.'], keywords: 'ngong chung cu clip ben trau co dang' },
      { slug: 'quan-pho-gia-1000', section: 'Đời sống', scene: 'food', hours: 6, author: 'Thanh Tít', title: 'Quán phở tính giá theo... tâm trạng khách', sapo: 'Một quán ở phố Bến Trầu: vui trả 40 nghìn, buồn được giảm còn 25 nghìn, thất tình miễn phí nếu kể được chuyện.', body: ['Chủ quán cho biết tuần đầu lỗ nặng vì ai cũng khai thất tình.', 'Hiện quán yêu cầu khách kể đủ ba chi tiết mới được xét.'], keywords: 'quan pho gia ben trau' },
      { slug: 'cay-xoai-ra-trai-mua-dong', section: 'Lạ', scene: 'field', hours: 11, author: 'Mai Rùa', title: 'Cây xoài trăm tuổi ra trái giữa mùa đông, cả xóm kéo đến xem', sapo: 'Chủ nhà đặt ghế nhựa mời khách và thu mỗi người một câu chúc.', body: ['Chuyên gia nông nghiệp địa phương cho rằng do thời tiết ấm bất thường.', 'Một số người xin lá về lấy may, chủ nhà phải căng dây bảo vệ.'], keywords: 'cay xoai mua dong' },
      { slug: 'ca-si-quen-loi-bai-cua-minh', section: 'Giải trí', scene: 'hall', hours: 18, author: 'Bống Kem', title: 'Ca sĩ Kai Mộc quên lời chính bài hit của mình trên sân khấu', sapo: 'Khán giả hát hộ cả bài, nam ca sĩ cúi đầu cảm ơn và xin "học thuộc lại trước tháng sau".', body: ['Ê-kíp cho biết đây không phải màn dàn dựng.', 'Bài hát sau đó tăng năm bậc trên bảng xếp hạng của tỉnh.'], keywords: 'ca si kai moc' },
      { slug: 'sinh-vien-ban-tra-da-bang-qr', section: 'Đời sống', scene: 'food', hours: 25, author: 'Bống Kem', title: 'Sinh viên mở quán trà đá, in mã QR lên từng chiếc ca', sapo: 'Mỗi lần quét mã, khách nhận một câu động viên ngẫu nhiên và giảm 500 đồng.', body: ['Câu được quét nhiều nhất là "Mai rồi tính".', 'Quán dự kiến mở thêm một ghế nhựa trong tháng tới.'], keywords: 'tra da sinh vien qr' },
    ],
  },
  'songtrau.vn': {
    name: 'Sóng Trầu',
    tagline: 'Dòng tin bên sông Trầu',
    address: 'Đường ven sông Trầu, tỉnh Hải Lâm',
    layout: 'feed',
    sections: ['Mới', 'Xã hội', 'Công nghệ', 'Thế giới lạ', 'Ý kiến'],
    articles: [
      { slug: 'ung-dung-nhac-uong-nuoc-doa-kien', section: 'Công nghệ', scene: 'lab', hours: 1, author: 'Vũ An Khang', title: 'Ứng dụng nhắc uống nước bị gỡ vì "giọng nhắc quá đáng sợ"', sapo: 'Người dùng phản ánh giọng đọc trầm lúc 3 giờ sáng khiến họ tỉnh hẳn và không ngủ lại được.', body: ['Nhóm phát triển xin lỗi và hứa đổi sang giọng vui vẻ hơn.', 'Một bộ phận người dùng lại kiến nghị giữ nguyên vì "uống nhiều nước hơn hẳn".'], keywords: 'ung dung nhac uong nuoc giong doc' },
      { slug: 'ban-do-so-ghi-sai-ao-ca', section: 'Công nghệ', scene: 'lab', hours: 8, author: 'Vũ An Khang', title: 'Bản đồ số chỉ đường xe khách xuống thẳng ao cá', sapo: 'Tài xế kịp phanh; chủ ao đề nghị bản đồ ghi rõ "có cá".', body: ['Dữ liệu đã được cập nhật sau hai ngày.', 'Ao cá vì thế thành điểm chụp ảnh của khách đi đường.'], keywords: 'ban do xe khach ao ca' },
      { slug: 'chim-sao-noi-duoc-gia-gia', section: 'Thế giới lạ', scene: 'sky', hours: 13, author: 'Hà Linh Chi', title: 'Chim sáo ở khu phố Bến Trầu hỏi "Ăn cơm chưa?" làm cả tiệm tạp hóa giật mình', sapo: 'Con sáo học được bảy câu hỏi quen thuộc và chỉ nói khi có khách mới.', body: ['Chủ tiệm cho biết doanh thu tăng nhẹ nhờ khách tò mò.', 'Câu nó nói nhiều nhất hiện là "Sao mua ít vậy?".'], keywords: 'chim sao tap hoa ben trau' },
      { slug: 'y-kien-nen-dat-ten-duong', section: 'Ý kiến', scene: 'hall', hours: 21, author: 'Tô Tiểu Nam', title: 'Có nên đặt tên ngõ theo món ăn nổi tiếng nhất?', sapo: 'Ngõ Bún Riêu nghe dễ nhớ hơn ngõ 12 ngách 4, nhưng chuyện gì xảy ra khi quán chuyển đi?', body: ['Tên gọi dân gian luôn đi trước bảng hiệu chính thức.', 'Điều đáng bàn là ai có quyền đặt tên cho ký ức của một con phố.'], keywords: 'y kien ten ngo mon an' },
      { slug: 'lop-hoc-ngu-trua', section: 'Xã hội', scene: 'school', hours: 30, author: 'Hà Linh Chi', title: 'Trường học thử cho học sinh ngủ trưa bằng tiếng mưa thu sẵn', sapo: 'Giáo viên kể học sinh ngủ nhanh hơn, còn một số thầy cô cũng ngủ theo.', body: ['Mô hình đang được theo dõi trong một học kỳ.', 'Phụ huynh đề xuất gửi tiếng mưa về nhà để dùng buổi tối.'], keywords: 'hoc sinh ngu trua truong' },
    ],
  },
};

// Filler so each paper feels busy. Generated the same way on every run.
const PLACES = ['Cổ Đằng', 'Bến Trầu', 'Đồng Muối', 'Cầu Mây', 'Lạc Thủy', 'Bãi Sông Trầu', 'Gò Sậy'];
const PATTERNS = {
  'Thời sự': ['Phường {p} họp dân về kế hoạch cuối năm', 'Mất điện diện rộng ở {p} trong đêm', 'Nước sông Trầu dâng cao, {p} sơ tán đồ đạc', 'Hải Lâm kiểm tra đột xuất khu vực {p}'],
  'Kinh tế': ['Giá rau ở chợ {p} tăng nhẹ trước mùa lễ', 'Tiểu thương {p} chuyển sang bán hàng trực tuyến', 'Một xưởng gỗ ở {p} tuyển thêm 30 lao động', 'Đất nền {p} bất ngờ chững lại'],
  'Giáo dục': ['Học sinh {p} đoạt giải toán cấp tỉnh', 'Trường ở {p} thử nghiệm sổ liên lạc mới', 'Phụ huynh {p} góp ý về giờ tan học', 'Thư viện lưu động về {p} cuối tuần này'],
  'Giao thông': ['Phân luồng đường {p} từ 22 giờ tối nay', 'Xe tải mắc kẹt dưới cầu {p} suốt ba giờ', 'Lắp thêm đèn tín hiệu tại ngã ba {p}', 'Tuyến buýt qua {p} đổi lộ trình'],
  'Sức khỏe': ['Trạm y tế {p} khám miễn phí cho người cao tuổi', 'Cảnh báo sốt xuất huyết tăng ở {p}', 'Bác sĩ khuyên người dân {p} không tự ý dùng thuốc'],
  'Văn hóa': ['Hội chợ quê {p} mở cửa ba ngày', 'Đoàn hát bội về diễn ở {p}', 'Triển lãm ảnh cũ về {p} thu hút người trẻ'],
  'Thể thao': ['Đội bóng phường {p} vào chung kết giải tỉnh', 'Giải chạy ven sông qua {p} thu hút 800 người', 'Câu lạc bộ cờ tướng {p} tuyển thành viên nhí'],
  'Pháp luật': ['Bắt nhóm trộm xe máy hoạt động ở {p}', 'Tranh chấp lối đi tại {p} ra tòa', 'Cảnh báo chiêu lừa gọi điện ở {p}'],
};
const AUTHORS = ['Minh Khoa', 'Thu Hà', 'Quốc Việt', 'Lan Phương', 'Đức Anh', 'Hải Yến'];
const SCENES_BY_SECTION = { 'Thời sự': 'city', 'Kinh tế': 'hall', 'Giáo dục': 'school', 'Giao thông': 'city', 'Sức khỏe': 'lab', 'Văn hóa': 'hall', 'Thể thao': 'field', 'Pháp luật': 'city' };
const ascii = (text) => text.toLowerCase().normalize('NFD').replace(/\p{M}/gu, '').replace(/đ/g, 'd').replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');

Object.values(SITES).forEach((site, siteIndex) => {
  let hours = 2;
  for (const [section, patterns] of Object.entries(PATTERNS)) {
    patterns.forEach((pattern, index) => {
      const place = PLACES[(index * 3 + siteIndex + section.length) % PLACES.length];
      const title = pattern.replace('{p}', place);
      hours += 2 + ((index + siteIndex) % 3);
      site.articles.push({
        slug: ascii(title), section, scene: SCENES_BY_SECTION[section], hours, filler: true,
        author: AUTHORS[(index + hours) % AUTHORS.length], title,
        sapo: `Thông tin ghi nhận tại ${place} trong ngày, người dân địa phương đang quan tâm theo dõi.`,
        body: [`Theo ghi nhận của phóng viên tại ${place}, sự việc diễn ra trong bầu không khí khá bình thường, người dân vẫn sinh hoạt như mọi ngày.`, 'Tòa soạn sẽ tiếp tục cập nhật khi có thêm thông tin từ cơ quan chức năng địa phương.'],
        keywords: ascii(place).replace(/-/g, ' '),
      });
    });
  }
  site.sections = [...new Set([...Object.keys(PATTERNS), ...site.articles.map((article) => article.section)])];
});

module.exports = { SITES };
