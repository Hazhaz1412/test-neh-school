// The website Trường THPT NEH left behind, stuck in late 2009 like most provincial school sites.
const { escape, fold } = require('./text');
const { AN_ID } = require('./registry');

const DOMAIN = 'thptneh.edu.vn';
const GATE = '/anh/town-school.png';
const MENU = [['/', 'Trang chủ'], ['/gioi-thieu', 'Giới thiệu'], ['/tin-tuc', 'Tin tức'], ['/thong-bao', 'Thông báo'], ['/hoc-tap', 'Học tập'], ['/bang-vang', 'Bảng vàng'], ['/cau-lac-bo', 'Câu lạc bộ'], ['/van-ban', 'Văn bản'], ['/luu-but', 'Lưu bút'], ['/lien-he', 'Liên hệ']];
const NEWS = [
  { slug: 'khai-giang-2009', date: '05/09/2009', title: 'Lễ khai giảng năm học 2009 - 2010', lead: 'Sáng 05/09, toàn thể thầy cô và hơn 900 học sinh đã long trọng tổ chức lễ khai giảng tại sân trường.', body: ['Thầy Hiệu trưởng Phạm Văn Đức đọc thư của ngành giáo dục tỉnh và phát động phong trào “Mỗi ngày đến trường là một niềm vui”.', 'Sau phần lễ, học sinh các khối tham gia trò chơi dân gian. Nhà trường khen thưởng 42 học sinh đạt thành tích cao năm học trước.'] },
  { slug: 'ket-qua-hsg-tinh', date: '28/03/2009', title: 'Kết quả kỳ thi học sinh giỏi cấp tỉnh năm học 2008 - 2009', lead: 'Trường có 9 học sinh đạt giải, trong đó có 1 giải Nhất môn Toán của học sinh khối 10.', body: ['Danh sách đội tuyển xem tại mục Bảng vàng. Bản đăng ký dự thi nộp Sở được lưu ở mục Văn bản.', 'Nhà trường chúc mừng các em và thầy cô bồi dưỡng đội tuyển.'] },
  { slug: 'giai-co-vua-truong', date: '20/11/2008', title: 'Chung kết giải Cờ vua học sinh chào mừng 20/11', lead: 'Một học sinh lớp 10 lần đầu vô địch, đánh bại cả đàn anh lớp 12 trong ván chung kết kéo dài 1 giờ 40 phút.', body: ['Giải có 64 kỳ thủ tham dự. Em Nguyễn Bình An (10A6) thắng toàn bộ bảy ván.', 'Khi được hỏi, em chỉ nói ngắn gọn: “Em thích chơi cờ vua nhất. Trên bàn cờ, ai cũng phải đi đúng luật.”', 'Một số bạn trong đội thua đã bỏ về trước lễ trao giải.'] },
  { slug: 'hoi-thao-20-11', date: '18/11/2009', title: 'Hội thao chào mừng ngày Nhà giáo Việt Nam 20/11', lead: 'Các lớp thi kéo co, bóng chuyền và văn nghệ trong hai ngày cuối tuần.', body: ['Khối 12 tạm dẫn đầu toàn đoàn.', 'Do thời tiết xấu, phần bế mạc lùi sang tuần sau. Thời gian cụ thể sẽ thông báo lại.'] },
  { slug: 'an-toan-truong-hoc', date: '12/10/2009', title: 'Sinh hoạt dưới cờ: xây dựng trường học thân thiện', lead: 'Đoàn trường nhắc học sinh không tụ tập sau giờ học ở khu nhà A.', body: ['Giáo viên chủ nhiệm các lớp được đề nghị rà soát sĩ số hằng ngày.', 'Mọi mâu thuẫn học sinh được giải quyết trong nội bộ lớp.'] },
];
const NOTICES = [
  ['23/11/2009', 'Tạm dừng hoạt động các câu lạc bộ cho tới khi có thông báo mới'],
  ['20/11/2009', 'Khóa cửa cầu thang khu A sau 17 giờ'],
  ['09/11/2009', 'Lịch thi giữa học kỳ I khối 10, 11, 12'],
  ['02/11/2009', 'Thu học phí tháng 11 tại phòng Tài vụ'],
  ['14/09/2009', 'Danh sách lớp năm học 2009 - 2010'],
];
const TEAM = [
  ['1', 'Nguyễn Bình An', '10A6', 'Toán', 'Nhất', true],
  ['2', 'Lê Hoàng Phúc', '12A1', 'Vật lý', 'Nhì'],
  ['3', 'Trần Mỹ Duyên', '11A2', 'Ngữ văn', 'Nhì'],
  ['4', 'Vũ Đức Thịnh', '12A1', 'Toán', 'Ba'],
  ['5', 'Phan Khánh Linh', '11A1', 'Hóa học', 'Ba'],
  ['6', 'Đỗ Quang Huy', '12A3', 'Tin học', 'Ba'],
  ['7', 'Hồ Thu Trang', '11A5', 'Tiếng Anh', 'Khuyến khích'],
  ['8', 'Bùi Anh Tuấn', '12A2', 'Sinh học', 'Khuyến khích'],
  ['9', 'Mai Thanh Hà', '10A1', 'Lịch sử', 'Khuyến khích'],
];
const IDS = ['', '097090001532', '097191002886', '097091004120', '097192003375', '097090005741', '097191001209', '097090003618', '097193002954'];
const counts = { base: 1048572, now: 0 };

const CSS = `*{box-sizing:border-box}body{margin:0;background:#c9d6e6 linear-gradient(#7fa3cf,#c9d6e6 340px) no-repeat;color:#222;font:13px/1.5 Tahoma,Verdana,Arial,sans-serif}a{color:#0a3f8f;text-decoration:none}a:hover{color:#d0231f;text-decoration:underline}
.site{width:1000px;margin:0 auto;background:#fff;box-shadow:0 0 8px #0005}
.banner{position:relative;height:168px;overflow:hidden;background:#0a3f8f}.banner img{position:absolute;right:0;top:0;width:560px;height:168px;object-fit:cover;object-position:center 42%;filter:sepia(.25) saturate(.85);-webkit-mask-image:linear-gradient(90deg,transparent,#000 40%)}
.crest{position:absolute;left:18px;top:26px;width:112px;height:112px}.names{position:absolute;left:144px;top:32px;color:#fff;text-shadow:1px 1px 2px #0009}.names small{display:block;font-size:13px;letter-spacing:.5px}.names b{display:block;font:bold 31px/1.2 "Times New Roman",serif;color:#ffe26a}.names i{font:italic 14px "Times New Roman",serif}
nav{display:flex;background:linear-gradient(#e0342d,#a71512);border-top:2px solid #ffd24a}nav a{flex:auto;text-align:center;color:#fff;font-weight:bold;font-size:12px;padding:8px 2px;border-right:1px solid #fff4}nav a:hover,nav a.on{background:#ffd24a;color:#7a0d0a;text-decoration:none}
.run{background:#fff8d6;border-bottom:1px solid #e5d58c;padding:4px 8px;display:flex;gap:8px;overflow:hidden;white-space:nowrap}.run b{color:#c1120f}.run span{display:inline-block;animation:run 34s linear infinite}@keyframes run{from{transform:translateX(780px)}to{transform:translateX(-100%)}}
.cols{display:grid;grid-template-columns:190px 1fr 210px;gap:10px;padding:10px}
.box{border:1px solid #9fb6d3;margin-bottom:10px}.box h3{margin:0;background:linear-gradient(#2f6fc4,#0a3f8f);color:#fff;font-size:12px;padding:5px 8px;text-transform:uppercase}.box div,.box ul{padding:7px 9px;margin:0}.box ul{list-style:none}.box li{padding:3px 0 3px 11px;border-bottom:1px dotted #bbc9db;background:radial-gradient(circle at 3px 11px,#d0231f 2px,transparent 3px)}
h1{font:bold 19px Tahoma,sans-serif;color:#0a3f8f;margin:0 0 4px}h2.t{font-size:13px;margin:0 0 8px;padding:5px 8px;background:#e6eefa;border-left:4px solid #d0231f;color:#0a3f8f;text-transform:uppercase}.date{color:#888;font-size:11px}
.item{display:grid;grid-template-columns:92px 1fr;gap:9px;padding:8px 0;border-bottom:1px dotted #bbc9db}.item svg,.item img{width:92px;height:66px;object-fit:cover;border:1px solid #bbb;padding:1px}.item a{font-weight:bold}.item p{margin:2px 0}
table{width:100%;border-collapse:collapse;margin:8px 0}th{background:#0a3f8f;color:#fff}th,td{border:1px solid #9fb6d3;padding:4px 7px;text-align:left}tr:nth-child(even) td{background:#f2f6fc}.gone{color:#b9b9b9;font-style:italic}.bar{background:#222;color:#222;user-select:none}
.teachers{display:grid;grid-template-columns:repeat(3,1fr);gap:8px;text-align:center;margin:8px 0}.teachers svg{width:74px;height:90px;background:#d8dde6;border:1px solid #aaa}.note{background:#fffbe6;border:1px solid #e5d58c;padding:7px 9px;margin:8px 0}
.say{border-bottom:1px dotted #bbc9db;padding:7px 0}.say b{color:#0a3f8f}form.fake input,form.fake textarea{width:100%;font:inherit;margin:3px 0;padding:4px;border:1px solid #9fb6d3}form.fake button{font:inherit;padding:3px 14px}
.count{font:bold 15px "Courier New",monospace;background:#111;color:#6dff7a;padding:2px 6px;letter-spacing:2px;display:inline-block}footer{background:#0a3f8f;color:#dce8f8;text-align:center;padding:9px;font-size:11px}`;

const CREST = `<svg class="crest" viewBox="0 0 120 120" aria-hidden="true"><circle cx="60" cy="60" r="57" fill="#fff" stroke="#ffd24a" stroke-width="5"/><circle cx="60" cy="60" r="44" fill="#0a3f8f"/><path d="M32 76c9-5 19-5 28 0 9-5 19-5 28 0V44c-9-5-19-5-28 0-9-5-19-5-28 0z" fill="#fff"/><path d="M60 44v32" stroke="#0a3f8f" stroke-width="2"/><path d="M60 22l5 10 11 1-8 8 2 11-10-6-10 6 2-11-8-8 11-1z" fill="#ffd24a"/><text x="60" y="96" font-family="Tahoma" font-size="13" font-weight="bold" text-anchor="middle" fill="#ffd24a">NEH</text></svg>`;
const shade = (seed) => [['#6f93c4', '#30517f'], ['#7ca37e', '#3c6143'], ['#c49c6f', '#7f5a30'], ['#a48bb7', '#584368']][seed % 4];
const thumb = (seed) => { const [a, b] = shade(seed); return `<svg viewBox="0 0 92 66"><rect width="92" height="66" fill="${a}"/><path d="M0 50h92v16H0z" fill="${b}"/><path d="M14 50V26h64v24zM40 26l6-8 6 8z" fill="#fff8"/><path d="M22 32h8v8h-8zm16 0h8v8h-8zm16 0h8v8h-8z" fill="${b}"/></svg>`; };
const portrait = '<svg viewBox="0 0 74 90"><circle cx="37" cy="34" r="16" fill="#9aa3b2"/><path d="M8 90c2-26 16-34 29-34s27 8 29 34z" fill="#9aa3b2"/></svg>';

function shell(active, title, centre) {
  counts.now += 1;
  const nav = MENU.map(([href, text]) => `<a href="${href}"${href === active ? ' class="on"' : ''}>${text}</a>`).join('');
  const links = ['Sở Giáo dục tỉnh Hải Lâm', 'Báo Hải Lâm', 'Thư viện đề thi', 'Tra cứu điểm thi', 'Hộp thư giáo viên'].map((text) => `<li><a href="${text === 'Báo Hải Lâm' ? 'https://baohailam.vn/' : '/lien-he'}">${text}</a></li>`).join('');
  return `<!doctype html><html lang="vi"><head><meta charset="utf-8"><title>${escape(title)} - Trường THPT NEH</title><style>${CSS}</style></head><body><div class="site">
<header class="banner">${CREST}<div class="names"><small>SỞ GIÁO DỤC TỈNH HẢI LÂM</small><b>TRƯỜNG THPT NEH</b><i>Kỷ cương · Tình thương · Trách nhiệm</i></div><img src="${GATE}" alt=""></header><nav>${nav}</nav>
<div class="run"><b>Thông báo:</b><span>${NOTICES.slice(0, 3).map(([date, text]) => `${date}: ${escape(text)}`).join(' &nbsp;★&nbsp; ')}</span></div>
<div class="cols"><aside>
<section class="box"><h3>Danh mục</h3><ul>${MENU.slice(1, 8).map(([href, text]) => `<li><a href="${href}">${text}</a></li>`).join('')}</ul></section>
<section class="box"><h3>Đăng nhập</h3><div><form class="fake" onsubmit="return false"><input placeholder="Tài khoản"><input type="password" placeholder="Mật khẩu"><button>Đăng nhập</button></form><span class="date">Hệ thống đã khóa tài khoản từ 12/2009.</span></div></section>
<section class="box"><h3>Liên kết</h3><ul>${links}</ul></section></aside>
<main>${centre}</main>
<aside><section class="box"><h3>Thông báo mới</h3><ul>${NOTICES.map(([date, text]) => `<li><a href="/thong-bao">${escape(text)}</a> <span class="date">(${date})</span></li>`).join('')}</ul></section>
<section class="box"><h3>Thăm dò ý kiến</h3><div>Em có cảm thấy an toàn ở trường?<br><label><input type="radio" name="p"> Có</label><br><label><input type="radio" name="p"> Bình thường</label><br><label><input type="radio" name="p"> Không</label></div></section>
<section class="box"><h3>Thống kê truy cập</h3><div><span class="count">${String(counts.base + counts.now).padStart(8, '0')}</span><br>Đang trực tuyến: 2<br><span class="date">Cập nhật lần cuối: 23/11/2009</span></div></section></aside></div>
<footer>© 2006 - 2009 Trường THPT NEH · Đường Đồng Muối, phường Cổ Đằng, tỉnh Hải Lâm · Điện thoại: 0000 333 444<br>Thiết kế và quản trị: Tổ Tin học · Xem tốt nhất ở độ phân giải 1024x768</footer></div></body></html>`;
}

const newsList = (items) => items.map((n, i) => `<div class="item">${thumb(i)}<div><a href="/tin-tuc/${n.slug}">${escape(n.title)}</a> <span class="date">(${n.date})</span><p>${escape(n.lead)}</p></div></div>`).join('');

function home() {
  return shell('/', 'Trang chủ', `<h2 class="t">Tin tức nhà trường</h2>${newsList(NEWS.slice(0, 4))}<h2 class="t" style="margin-top:12px">Gương mặt tiêu biểu</h2><div class="note">Vinh danh học sinh đạt giải cấp tỉnh năm học 2008 - 2009. Xem tại <a href="/bang-vang">Bảng vàng</a>.</div>`);
}

function about() {
  const staff = [['Phạm Văn Đức', 'Hiệu trưởng'], ['Lê Quốc Trung', 'Phó Hiệu trưởng'], ['Đoàn Thị Nga', 'Bí thư Đoàn trường']].map(([name, role]) => `<div>${portrait}<br><b>${name}</b><br>${role}</div>`).join('');
  return shell('/gioi-thieu', 'Giới thiệu', `<h1>Giới thiệu về nhà trường</h1><p>Trường THPT NEH được thành lập năm 1986 trên đường Đồng Muối, bên kia cầu Mây, phục vụ con em các xã ven sông Trầu. Hiện trường có 27 lớp, hơn 900 học sinh và 64 cán bộ, giáo viên.</p><p>Cơ sở vật chất gồm khu A và khu B ba tầng, sân trường, phòng thí nghiệm, thư viện và sân thượng khu A dùng cho hoạt động ngoại khóa.</p><h2 class="t">Ban giám hiệu</h2><div class="teachers">${staff}</div><h2 class="t">Thành tích</h2><ul><li>Tập thể lao động tiên tiến cấp tỉnh các năm 2005, 2007.</li><li>Trường học thân thiện, học sinh tích cực năm 2008.</li></ul>`);
}

function article(slug) {
  const item = NEWS.find((n) => n.slug === slug);
  if (!item) return null;
  return shell('/tin-tuc', item.title, `<h1>${escape(item.title)}</h1><div class="date">Đăng ngày ${item.date} · Tổ Tin học</div><p><b>${escape(item.lead)}</b></p>${item.body.map((text) => `<p>${escape(text)}</p>`).join('')}<p><a href="/tin-tuc">« Các tin khác</a></p>`);
}

function honours() {
  const rows = TEAM.map(([no, name, cls, subject, prize, erased]) => (erased
    ? `<tr><td>${no}</td><td class="gone">[đã gỡ theo yêu cầu]</td><td>10A6</td><td>${subject}</td><td>${prize}</td></tr>`
    : `<tr><td>${no}</td><td>${name}</td><td>${cls}</td><td>${subject}</td><td>${prize}</td></tr>`)).join('');
  return shell('/bang-vang', 'Bảng vàng', `<h1>Bảng vàng thành tích</h1><p>Học sinh giỏi cấp tỉnh, năm học 2008 - 2009.</p><table><tr><th>TT</th><th>Họ và tên</th><th>Lớp</th><th>Môn</th><th>Giải</th></tr>${rows}</table><div class="note">Mục cũ đã chuyển sang <a href="/van-ban/ds-du-thi-hsg-2009">bản đăng ký dự thi</a>.</div>`);
}

function club() {
  return shell('/cau-lac-bo', 'Câu lạc bộ', `<h1>Câu lạc bộ học sinh</h1><table><tr><th>Câu lạc bộ</th><th>Phụ trách</th><th>Sinh hoạt</th></tr><tr><td>Bóng rổ</td><td>Thầy Tiến</td><td>Thứ Ba, sân trường</td></tr><tr><td>Tiếng Anh</td><td>Cô Hằng</td><td>Thứ Tư, phòng 103</td></tr><tr><td>Văn nghệ</td><td>Cô Nga</td><td>Thứ Năm, hội trường</td></tr><tr><td>Cờ vua</td><td>Thầy Khải</td><td>Thứ Sáu, phòng 205</td></tr></table><h2 class="t">Cờ vua</h2><p>Đương kim vô địch toàn trường: <a href="/tin-tuc/giai-co-vua-truong">Nguyễn Bình An, lớp 10A6</a>.</p><div class="note">Theo thông báo ngày 23/11/2009, mọi câu lạc bộ tạm dừng hoạt động.</div>`);
}

function documents() {
  const docs = [['/van-ban/ds-du-thi-hsg-2009', 'DS-07/2009', 'Danh sách đăng ký dự thi HSG cấp tỉnh 2008 - 2009', '10/02/2009'], ['/thong-bao', 'TB-31/2009', 'Lịch thi giữa học kỳ I', '09/11/2009'], ['/thong-bao', 'QĐ-12/2009', 'Nội quy học sinh năm học 2009 - 2010', '20/08/2009']];
  return shell('/van-ban', 'Văn bản', `<h1>Văn bản, biểu mẫu</h1><table><tr><th>Số hiệu</th><th>Trích yếu</th><th>Ngày</th></tr>${docs.map(([href, no, title, date]) => `<tr><td>${no}</td><td><a href="${href}">${title}</a></td><td>${date}</td></tr>`).join('')}</table>`);
}

function entryList() {
  const rows = TEAM.map(([no, name, cls, subject], i) => `<tr><td>${no}</td><td>${name}</td><td>${cls}</td><td>${subject}</td><td>${i === 0 ? AN_ID : IDS[i]}</td></tr>`).join('');
  return shell('/van-ban', 'Danh sách đăng ký dự thi', `<h1>Danh sách đăng ký dự thi HSG cấp tỉnh</h1><div class="date">Số hiệu DS-07/2009 · Bản nộp Sở Giáo dục · Tổ Tin học quét lại</div><table><tr><th>TT</th><th>Họ và tên</th><th>Lớp</th><th>Môn</th><th>Số định danh</th></tr>${rows}</table><div class="note">Bản lưu nội bộ. Đề nghị không đăng công khai số định danh.</div>`);
}

function notices() {
  return shell('/thong-bao', 'Thông báo', `<h1>Thông báo</h1><table><tr><th>Ngày</th><th>Nội dung</th></tr>${NOTICES.map(([date, text]) => `<tr><td>${date}</td><td>${escape(text)}</td></tr>`).join('')}</table>`);
}

function study() {
  const days = ['Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7'];
  const lessons = [['Chào cờ', 'Toán', 'Văn', 'Anh', 'Lý', 'Toán'], ['Toán', 'Hóa', 'Văn', 'Sinh', 'Tin', 'Sử'], ['Văn', 'Anh', 'Toán', 'Địa', 'Hóa', 'Sinh hoạt'], ['Lý', 'Toán', 'GDCD', 'Văn', 'Anh', '']];
  return shell('/hoc-tap', 'Học tập', `<h1>Thời khóa biểu lớp 10A6</h1><div class="date">Áp dụng từ 12/10/2009. GVCN: Cô Lê Thị Thanh Hoa</div><table><tr><th>Tiết</th>${days.map((d) => `<th>${d}</th>`).join('')}</tr>${lessons.map((row, i) => `<tr><td>${i + 1}</td>${row.map((c) => `<td>${c}</td>`).join('')}</tr>`).join('')}</table>`);
}

function guestbook() {
  const notes = [['Cựu HS K2003', '15/09/2009', 'Chúc thầy cô năm học mới mạnh khỏe!'], ['Phụ huynh lớp 11A3', '02/10/2009', 'Đề nghị nhà trường sửa đèn hành lang khu A.'], ['khách', '19/11/2009', 'Có ai đọc mấy cái này không ạ?'], ['BQT', '23/11/2009', 'Mục lưu bút tạm khóa.'], ['Phụ huynh lớp 10A6', '21/11/2009', 'Nhà trường trả lời giúp phụ huynh về buổi họp lớp bị hoãn.']];
  return shell('/luu-but', 'Lưu bút', `<h1>Sổ lưu bút</h1>${notes.map(([who, date, text]) => `<div class="say"><b>${who}</b> <span class="date">${date}</span><br>${text}</div>`).join('')}<div class="note">Chức năng gửi lưu bút đã bị khóa.</div>`);
}

function contact() {
  return shell('/lien-he', 'Liên hệ', `<h1>Liên hệ</h1><p>Trường THPT NEH<br>Đường Đồng Muối, phường Cổ Đằng, tỉnh Hải Lâm<br>Văn phòng: 0000 333 444<br>Thư điện tử: vanphong@thptneh.edu.vn</p><p class="date">Không tìm thấy máy chủ thư.</p>`);
}

function render(url) {
  const path = url.pathname.replace(/\/$/, '') || '/';
  const pages = { '/': home, '/gioi-thieu': about, '/thong-bao': notices, '/hoc-tap': study, '/bang-vang': honours, '/cau-lac-bo': club, '/van-ban': documents, '/van-ban/ds-du-thi-hsg-2009': entryList, '/luu-but': guestbook, '/lien-he': contact, '/tin-tuc': () => shell('/tin-tuc', 'Tin tức', `<h2 class="t">Tin tức</h2>${newsList(NEWS)}`) };
  if (pages[path]) return [200, pages[path]()];
  const story = path.startsWith('/tin-tuc/') ? article(path.slice(9)) : null;
  return story ? [200, story] : [404, shell('', 'Không tìm thấy', '<h1>404</h1><p>Trang đã bị gỡ hoặc không tồn tại.</p>')];
}

const RESULTS = [
  { title: 'Trường THPT NEH - Trang thông tin điện tử', url: `https://${DOMAIN}/`, snippet: 'Website chính thức Trường THPT NEH, đường Đồng Muối, phường Cổ Đằng. Tin tức, thông báo, bảng vàng, câu lạc bộ.', words: ['neh', 'thpt', 'truong', '10a6'] },
  { title: 'Chung kết giải Cờ vua học sinh chào mừng 20/11 - Trường THPT NEH', url: `https://${DOMAIN}/tin-tuc/giai-co-vua-truong`, snippet: 'Em Nguyễn Bình An (10A6) thắng toàn bộ bảy ván của giải Cờ vua toàn trường.', words: ['nguyen binh an', 'binh an', 'co vua'] },
  { title: 'Bảng vàng thành tích - Trường THPT NEH', url: `https://${DOMAIN}/bang-vang`, snippet: 'Danh sách học sinh giỏi cấp tỉnh năm học 2008 - 2009.', words: ['bang vang', 'hoc sinh gioi', 'hsg', 'binh an'] },
];
const search = (query) => RESULTS.filter((r) => r.words.some((word) => fold(query).includes(word)));

module.exports = { DOMAIN, render, search };
