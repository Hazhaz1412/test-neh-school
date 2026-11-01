// Fictional provincial registry of Hải Lâm. Answers only for the game's own citizens: what is
// typed here is compared and dropped, never stored, logged or echoed back.
const crypto = require('crypto');
const { escape, fold } = require('./text');

const DOMAIN = 'dancu.hailam.gov.vn';
const AN_ID = '097193004217';
const ANSWER = 'co vua';
const QUESTION = 'Môn bạn thích chơi nhất là gì?';
const MAX_SESSIONS = 32;
const sessions = new Map();

const SEAL = `<svg viewBox="0 0 80 80" aria-hidden="true"><circle cx="40" cy="40" r="38" fill="#b01c1c" stroke="#e9c15a" stroke-width="3"/><circle cx="40" cy="40" r="29" fill="none" stroke="#e9c15a"/><path d="M14 50q7-7 13 0t13 0 13 0 13 0v7q-7 7-13 0t-13 0-13 0-13 0z" fill="#e9c15a"/><path d="M40 16l13 25H27z" fill="#e9c15a"/><path d="M40 25l7 14H33z" fill="#b01c1c"/></svg>`;
const CSS = `*{box-sizing:border-box}body{margin:0;background:#eef1f5;color:#1f2933;font:15px/1.6 Arial,"Segoe UI",sans-serif}a{color:#0b4f9e}
.flag{height:5px;background:#b01c1c}.head{background:#fff;border-bottom:1px solid #d7dde4}.wrap{max-width:1080px;margin:0 auto;padding:0 20px}
.brand{display:flex;gap:14px;align-items:center;padding:14px 0}.brand svg{width:66px;height:66px;flex:none}.brand small{display:block;color:#5c6b7a;font-size:13px;letter-spacing:.3px}.brand b{display:block;color:#b01c1c;font-size:22px;line-height:1.25;text-transform:uppercase}
nav{background:#0b4f9e}nav .wrap{display:flex}nav a{color:#fff;text-decoration:none;padding:10px 16px;font-size:14px}nav a:hover,nav a.on{background:#083b76}
.notice{background:#fff8e1;border-bottom:1px solid #ecdca8;font-size:13px;padding:7px 0;color:#6b5512}
.grid{display:grid;grid-template-columns:1fr 300px;gap:20px;padding:22px 20px}.card{background:#fff;border:1px solid #d7dde4;border-radius:4px;padding:22px 26px}.card h1{font-size:21px;margin:0 0 4px;color:#0b4f9e}.card h2{font-size:16px;margin:0 0 10px;color:#0b4f9e;border-bottom:2px solid #0b4f9e;padding-bottom:6px}
.steps{display:flex;gap:6px;margin:14px 0 20px;font-size:13px}.steps span{flex:1;padding:7px 10px;background:#eef1f5;color:#6a7785;border-radius:3px}.steps .on{background:#0b4f9e;color:#fff}
label{display:block;font-weight:600;margin:12px 0 5px}input[type=text]{width:100%;height:42px;padding:0 12px;border:1px solid #aeb8c3;border-radius:3px;font:inherit}input:focus{outline:2px solid #0b4f9e55;border-color:#0b4f9e}
button{margin-top:14px;height:42px;padding:0 24px;background:#b01c1c;color:#fff;border:0;border-radius:3px;font:600 15px Arial,sans-serif;cursor:pointer}button.plain{background:#fff;color:#0b4f9e;border:1px solid #0b4f9e}
.bad{background:#fdecea;border-left:4px solid #b01c1c;padding:9px 13px;margin:12px 0;color:#8a1f1f}.ok{background:#e9f6ec;border-left:4px solid #2c8a47;padding:9px 13px;margin:12px 0;color:#1f6b36}.muted{color:#5c6b7a;font-size:13px}
ul.side{list-style:none;margin:0;padding:0;font-size:14px}ul.side li{padding:7px 0;border-bottom:1px dashed #d7dde4}
table{width:100%;border-collapse:collapse;font-size:14px;margin-bottom:18px}th,td{text-align:left;padding:8px 10px;border:1px solid #d7dde4;vertical-align:top}th{width:210px;background:#f4f6f9;font-weight:600}caption{caption-side:top;text-align:left;font-weight:700;color:#0b4f9e;padding:8px 0}
.hidden{background:#28303a;color:#28303a;border-radius:2px;user-select:none}.warn{color:#b01c1c;font-weight:700}
.foot{background:#10253f;color:#c7d3e0;font-size:13px;margin-top:24px;padding:18px 0}.foot p{margin:3px 0}`;

function page(title, body, active = 'tra-cuu') {
  const menu = [['/', 'Trang chủ', 'home'], ['/', 'Tra cứu cư trú', 'tra-cuu'], ['/huong-dan', 'Hướng dẫn', 'huong-dan'], ['/lien-he', 'Liên hệ', 'lien-he']];
  return `<!doctype html><html lang="vi"><head><meta charset="utf-8"><title>${escape(title)} | Cổng dữ liệu dân cư tỉnh Hải Lâm</title><style>${CSS}</style></head><body>
<div class="flag"></div><header class="head"><div class="wrap brand">${SEAL}<div><small>ỦY BAN NHÂN DÂN TỈNH HẢI LÂM</small><b>Cổng dữ liệu dân cư</b><small>Trung tâm Dữ liệu và Chuyển đổi số tỉnh</small></div></div></header>
<nav><div class="wrap">${menu.map(([href, text, id]) => `<a href="${href}"${id === active ? ' class="on"' : ''}>${text}</a>`).join('')}</div></nav>
<div class="notice"><div class="wrap">Hệ thống bảo trì định kỳ từ 23:00 đến 05:00 thứ Bảy hằng tuần. Dữ liệu trước năm 2012 được số hóa từ sổ giấy.</div></div>
<main class="wrap grid">${body}</main>
<footer class="foot"><div class="wrap"><p><b>Trung tâm Dữ liệu và Chuyển đổi số tỉnh Hải Lâm</b></p><p>Số 01 đường Cầu Mây, thành phố Hải Lâm · Tổng đài hỗ trợ: 0000 111 222</p><p class="muted" style="color:#8ea1b5">Trang hư cấu trong trò chơi NEH School. Không nhập số giấy tờ thật của bạn.</p></div></footer></body></html>`;
}

const side = `<aside class="card"><h2>Lưu ý khi tra cứu</h2><ul class="side"><li>Số định danh gồm đúng 12 chữ số.</li><li>Công dân tự đặt câu hỏi xác minh khi đăng ký.</li><li>Sai câu trả lời không khóa hồ sơ.</li><li>Hồ sơ đã đóng chỉ còn phần được phép công khai.</li></ul></aside>`;
const steps = (current) => `<div class="steps">${['1. Nhập số định danh', '2. Câu hỏi xác minh', '3. Xem hồ sơ'].map((text, i) => `<span${i === current ? ' class="on"' : ''}>${text}</span>`).join('')}</div>`;

function home(message = '') {
  return page('Tra cứu thông tin cư trú', `<section class="card"><h1>Tra cứu thông tin cư trú</h1><p class="muted">Dành cho công dân và thân nhân có đăng ký tại tỉnh Hải Lâm.</p>${steps(0)}${message}
<form method="post" action="/tra-cuu" autocomplete="off"><label for="so">Số CCCD / số định danh cá nhân</label><input id="so" name="so" type="text" inputmode="numeric" maxlength="12" placeholder="12 chữ số" autocomplete="off" autofocus><button>Tra cứu</button></form></section>${side}`);
}

function challenge(message = '') {
  return page('Câu hỏi xác minh', `<section class="card"><h1>Xác minh chủ hồ sơ</h1><p class="muted">Số định danh hợp lệ. Trả lời câu hỏi do chủ hồ sơ đặt khi đăng ký.</p>${steps(1)}${message}
<form method="post" action="/xac-minh" autocomplete="off"><label for="dap">${escape(QUESTION)}</label><input id="dap" name="dap" type="text" maxlength="60" autocomplete="off" autofocus><button>Xác nhận</button></form>
<form method="post" action="/dang-xuat"><button class="plain">Hủy</button></form></section>${side}`);
}

const row = (name, value) => `<tr><th>${name}</th><td>${value}</td></tr>`;

function record() {
  return page('Hồ sơ công dân', `<section class="card"><h1>Hồ sơ công dân</h1>${steps(2)}<div class="ok">Xác minh thành công. Phiên làm việc sẽ tự đóng khi bạn đăng xuất.</div>
<table><caption>I. Thông tin nhân thân</caption>
${row('Họ và tên', 'NGUYỄN BÌNH AN')}${row('Ngày sinh', '14/03/1993')}${row('Giới tính', 'Nữ')}${row('Số định danh', AN_ID)}${row('Quê quán', 'Xã Đồng Muối, tỉnh Hải Lâm')}${row('Nơi thường trú', 'Số 8, Hẻm 12, khu phố Bến Trầu, phường Cổ Đằng')}${row('Trạng thái hồ sơ', '<span class="warn">ĐÃ ĐÓNG · 22/11/2009</span>')}${row('Lý do đóng hồ sơ', '<span class="hidden">được giữ kín theo yêu cầu</span> <span class="muted">(bị ẩn theo công văn 118/CV)</span>')}</table>
<table><caption>II. Thành viên hộ gia đình</caption>
${row('Mẹ', 'Trần Thị Mận, sinh 1968. Chuyển khỏi địa bàn tháng 01/2010, chưa cập nhật nơi ở mới.')}${row('Cha', 'Nguyễn Văn Bình, sinh 1965. Đã mất năm 2003.')}${row('Người liên hệ khác', 'Cô Lê Thị Thanh Hoa, giáo viên chủ nhiệm lớp 10A6, Trường THPT NEH')}</table>
<table><caption>III. Ghi chú liên quan từ cơ quan địa phương</caption>
${row('07/09/2009', 'Bà Trần Thị Mận đến phường phản ánh con bị nhóm học sinh chặn đường, lấy đồ dùng học tập. Chuyển nhà trường giải quyết.')}${row('19/10/2009', 'Lần phản ánh thứ hai. Nhà trường trả lời “mâu thuẫn bạn bè, đã nhắc nhở”. Không có biên bản kèm theo.')}${row('03/11/2009', 'Lần phản ánh thứ ba, kèm một trang vở viết tay. <span class="hidden">nội dung trang vở đã bị gỡ</span>')}${row('Bưu phẩm tồn', 'Một phong bì do công dân gửi tới “lớp 10A6”, chưa phát. Tình trạng: thất lạc.')}</table>
<form method="post" action="/dang-xuat"><button class="plain">Đăng xuất</button></form></section>
<aside class="card"><h2>Tài liệu kèm theo</h2><ul class="side"><li>Sổ hộ khẩu bản số hóa: <span class="muted">không còn tệp</span></li><li>Công văn 118/CV: <span class="muted">hạn chế truy cập</span></li><li>Hồ sơ học sinh: <a href="https://thptneh.edu.vn/">Trường THPT NEH</a></li></ul></aside>`);
}

function info(path) {
  if (path === '/huong-dan') return page('Hướng dẫn', `<section class="card"><h1>Hướng dẫn tra cứu</h1><p>Bước 1. Nhập đủ 12 chữ số của số định danh cá nhân, thông tin này thường có trên giấy tờ học tập hoặc danh sách dự thi cũ.</p><p>Bước 2. Trả lời câu hỏi xác minh do chính chủ hồ sơ đặt, không phân biệt hoa thường và dấu.</p><p>Bước 3. Xem phần hồ sơ được phép công khai.</p></section>${side}`, 'huong-dan');
  return page('Liên hệ', `<section class="card"><h1>Liên hệ</h1><p>Bộ phận tiếp nhận làm việc từ 7:30 đến 17:00 các ngày trong tuần, trừ ngày lễ.</p><p>Tổng đài: 0000 111 222</p></section>${side}`, 'lien-he');
}

const cookieOf = (header) => /(?:^|;\s*)dancu=([a-f0-9]{32})/.exec(header ?? '')?.[1];
const redirect = (to, cookie) => [303, '', { location: to, ...(cookie ? { 'set-cookie': cookie } : {}) }];
const begin = () => {
  if (sessions.size >= MAX_SESSIONS) sessions.delete(sessions.keys().next().value);
  const token = crypto.randomBytes(16).toString('hex');
  sessions.set(token, { verified: false });
  return `dancu=${token}; HttpOnly; Path=/`;
};

function render(method, url, form, cookieHeader) {
  const token = cookieOf(cookieHeader);
  const session = sessions.get(token);
  const path = url.pathname;
  if (method === 'POST' && path === '/tra-cuu') {
    const typed = (form.get('so') ?? '').replace(/\s/g, '');
    if (typed === AN_ID) return redirect('/xac-minh', begin());
    const wrong = /^\d{12}$/.test(typed) ? 'Không tìm thấy công dân với số định danh này trên địa bàn tỉnh.' : 'Số định danh phải gồm đúng 12 chữ số.';
    return [200, home(`<div class="bad">${wrong}</div>`)];
  }
  if (method === 'POST' && path === '/xac-minh') {
    if (!session) return redirect('/');
    if (fold(form.get('dap') ?? '').trim().replace(/\s+/g, ' ') !== ANSWER) return [200, challenge('<div class="bad">Câu trả lời chưa đúng. Hãy thử lại.</div>')];
    session.verified = true;
    return redirect('/ho-so');
  }
  if (method === 'POST' && path === '/dang-xuat') {
    sessions.delete(token);
    return redirect('/');
  }
  if (method !== 'GET') return [405, home()];
  if (path === '/xac-minh') return session ? [200, challenge()] : redirect('/');
  if (path === '/ho-so') return session?.verified ? [200, record()] : redirect('/');
  if (path === '/huong-dan' || path === '/lien-he') return [200, info(path)];
  return path === '/' ? [200, home()] : [404, home('<div class="bad">Trang không tồn tại.</div>')];
}

const SEARCH = { title: 'Tra cứu thông tin cư trú | Cổng dữ liệu dân cư tỉnh Hải Lâm', url: `https://${DOMAIN}/`, snippet: 'Tra cứu hồ sơ cư trú bằng số định danh cá nhân và câu hỏi xác minh của chủ hồ sơ.', words: ['tra cuu', 'dan cu', 'cccd', 'can cuoc', 'dinh danh', 'cu tru', 'ho so', 'ho khau'] };
const search = (query) => (SEARCH.words.some((word) => fold(query).includes(word)) ? [SEARCH] : []);

module.exports = { DOMAIN, AN_ID, render, search };
