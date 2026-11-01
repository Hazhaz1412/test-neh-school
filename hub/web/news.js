// The three fictional newspapers: original layouts built on common news-site conventions.
const fs = require('fs');
const path = require('path');
const { SITES } = require('./news-data');

const PHOTO_DIR = path.join(__dirname, '..', '..', 'docs');
const PHOTOS = new Set(['town-school.png', ...Object.values(SITES).flatMap((site) => site.articles.map((a) => a.photo).filter(Boolean))]);
for (const [host, site] of Object.entries(SITES)) for (const article of site.articles) article.host = host;

const SCENES = {
  city: '<path d="M0 150V90h40v60h20V60h50v90h30V80h60v70h40V50h50v100h30V100h80v50z" fill="#0006"/><path d="M0 150h400v30H0z" fill="#0005"/>',
  school: '<path d="M60 150V70h280v80zM170 70l30-26 30 26z" fill="#0007"/><path d="M90 90h30v24H90zm60 0h30v24h-30zm70 0h30v24h-30zm60 0h30v24h-30z" fill="#ffd97066"/>',
  field: '<path d="M0 120q200-50 400 0v60H0z" fill="#0005"/><circle cx="310" cy="50" r="24" fill="#fff7"/>',
  sky: '<circle cx="90" cy="50" r="26" fill="#fff7"/><path d="M240 60l50-26 14 50zM150 96l34-16 8 34z" fill="#fff6"/><path d="M0 150h400v30H0z" fill="#0005"/>',
  hall: '<path d="M60 150V60h280v90zM90 40h220v14H90z" fill="#0006"/><path d="M0 150h400v30H0z" fill="#0004"/>',
  food: '<ellipse cx="200" cy="112" rx="110" ry="30" fill="#0006"/><path d="M90 104a110 56 0 0 0 220 0z" fill="#fff5"/>',
  lab: '<rect x="120" y="36" width="160" height="100" rx="8" fill="#0006"/><path d="M142 60h116M142 82h80M142 104h100" stroke="#fff7" stroke-width="7"/>',
};
const TONES = [['#6b7f8c', '#2e3d47'], ['#8c7b5e', '#4a3a26'], ['#5e7d6b', '#2c4436'], ['#7c6b86', '#3a2e47'], ['#8c6a5e', '#4a2e26'], ['#5e6f8c', '#26344a']];

const escape = (text) => String(text).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
const fold = (text) => text.toLowerCase().normalize('NFD').replace(/\p{M}/gu, '').replace(/đ/g, 'd');
const slugify = (text) => fold(text).replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
const seedOf = (text) => [...text].reduce((sum, c) => sum + c.charCodeAt(0), 0);

function thumb(a) {
  if (a.photo) return `<span class="ph"><img src="https://${a.host}/anh/${a.photo}" alt="${escape(a.title)}"></span>`;
  const seed = seedOf(a.slug);
  const [from, to] = TONES[seed % TONES.length];
  return `<span class="ph"><svg viewBox="0 0 400 225" preserveAspectRatio="xMidYMid slice"><defs><linearGradient id="g${seed}" x1="0" y1="0" x2="1" y2="1"><stop stop-color="${from}"/><stop offset="1" stop-color="${to}"/></linearGradient></defs><rect width="400" height="225" fill="url(#g${seed})"/>${SCENES[a.scene]}</svg></span>`;
}

const age = (hours) => (hours < 24 ? `${hours} giờ trước` : `${Math.floor(hours / 24)} ngày trước`);
const clock = (hours) => new Intl.DateTimeFormat('vi-VN', { hour: '2-digit', minute: '2-digit' }).format(Date.now() - hours * 3600000);
const stamp = (hours) => new Intl.DateTimeFormat('vi-VN', { dateStyle: 'short', timeStyle: 'short' }).format(Date.now() - hours * 3600000);
const today = () => new Intl.DateTimeFormat('vi-VN', { dateStyle: 'full' }).format(Date.now());
const comments = (a) => seedOf(a.title) % 97;
const href = (a) => `/tin/${a.slug}`;
const sectionHref = (section) => `/chuyen-muc/${slugify(section)}`;
const link = (a, content = a.title) => `<a href="${href(a)}">${content}</a>`;
const count = (a) => (comments(a) > 12 ? `<span class="cm">${comments(a)}</span>` : '');
const newest = (site) => [...site.articles].sort((a, b) => a.hours - b.hours);
const inSection = (site, section) => newest(site).filter((a) => a.section === section);
const mostRead = (site) => [...site.articles].sort((a, b) => (seedOf(b.title) * 7) % 101 - (seedOf(a.title) * 7) % 101);

const BASE = `*{box-sizing:border-box}body{margin:0;background:#fff;color:#222;font:15px/1.45 Arial,Helvetica,sans-serif}a{color:inherit;text-decoration:none}a:hover{color:var(--accent)}h1,h2,h3,p,ul,ol{margin:0;padding:0}li{list-style:none}
.box{max-width:1130px;margin:0 auto;padding:0 16px}
.ph{position:relative;display:block;aspect-ratio:16/9;overflow:hidden;background:#ccc}.ph svg,.ph img{display:block;width:100%;height:100%;object-fit:cover}.ph img{transform:scale(1.3)}.top>div>a>.ph{aspect-ratio:2/1}
.ph::after{content:"";position:absolute;inset:0;background:radial-gradient(ellipse at center,transparent 50%,#0004),url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='160' height='160'%3E%3Cfilter id='n'%3E%3CfeTurbulence baseFrequency='.9'/%3E%3C/filter%3E%3Crect width='160' height='160' filter='url(%23n)' opacity='.28'/%3E%3C/svg%3E");mix-blend-mode:multiply}
.util{font-size:12px;color:#666;border-bottom:1px solid #eee}.util .box{display:flex;gap:18px;height:30px;align-items:center}.util .push{margin-left:auto}
nav{border-bottom:1px solid #e3e3e3}nav .box{display:flex;gap:17px;height:38px;align-items:center;font-size:14px;font-weight:600;white-space:nowrap;overflow:hidden}
.cm{color:var(--accent);font-size:12px;font-weight:400;margin-left:5px}.cm::before{content:"💬 ";font-size:10px}
.head{display:flex;align-items:baseline;gap:14px;margin:0 0 10px;border-bottom:2px solid var(--accent);padding-bottom:5px;font-size:17px;font-weight:700;color:var(--accent)}
.mini{display:grid;grid-template-columns:110px 1fr;gap:9px;font-size:14px;font-weight:600;line-height:1.3;padding:9px 0;border-top:1px solid #eee}
.lines li{padding:7px 0;border-top:1px solid #eee;font-size:14px;line-height:1.35}.lines li:first-child{border-top:0}
.blocks{display:grid;grid-template-columns:repeat(4,1fr);gap:22px;padding:22px 16px}.block h3{font-size:15px;line-height:1.3;margin:7px 0 4px}
.rank{counter-reset:r}.rank li{counter-increment:r;display:grid;grid-template-columns:30px 1fr;padding:8px 0;border-top:1px solid #eee;font-size:14px;line-height:1.35}.rank li::before{content:counter(r);font-size:22px;font-weight:700;color:var(--accent);line-height:1}
.read{display:grid;grid-template-columns:1fr 300px;gap:32px;padding:18px 16px 40px}.crumb{font-size:13px;color:var(--accent);margin-bottom:10px;font-weight:600}.story h1{font-size:30px;line-height:1.25;margin-bottom:9px}.story .by{color:#777;font-size:13px;margin-bottom:12px}.story .sapo{font-weight:700;margin-bottom:14px;font-size:16px;line-height:1.5}.story figure{margin:0 0 14px}.story figcaption{font-size:13px;color:#666;padding:6px 0;text-align:center;background:#f4f4f4}.story>p{margin-bottom:13px;font-size:17px;line-height:1.65}
footer{margin-top:18px;background:#f2f2f2;font-size:12px;color:#666;padding:16px 0}`;

const block = (site, section) => {
  const [first, ...more] = inSection(site, section);
  return first ? `<section class="block"><div class="head"><a href="${sectionHref(section)}">${section}</a></div>${link(first, thumb(first))}<h3>${link(first)}${count(first)}</h3>
<ul class="lines">${more.slice(0, 3).map((a) => `<li>${link(a)}</li>`).join('')}</ul></section>` : '';
};
const blocks = (site, skip = 0) => `<div class="box blocks">${site.sections.slice(skip, skip + 8).map((s) => block(site, s)).join('')}</div>`;
const util = (site, extra = '') => `<div class="util"><div class="box"><span>${today()}</span><span>Hải Lâm 29°C, nhiều mây</span>${extra}<a class="push" href="/">Đăng nhập</a><span>Tìm kiếm</span></div></div>`;
const navigation = (site) => `<nav><div class="box"><a href="/">⌂</a>${site.sections.map((s) => `<a href="${sectionHref(s)}">${s}</a>`).join('')}</div></nav>`;
const lead = (a, tag = 'h2') => `${link(a, thumb(a))}<${tag} class="lead">${link(a)}${count(a)}</${tag}><p class="sapo">${a.sapo}</p>`;

const LAYOUTS = {
  broadsheet: {
    css: `:root{--accent:#1c3f6e}
.mast{padding:16px 0 12px;text-align:center;border-bottom:1px solid #d8c88f}.flag{font:700 46px/1 Georgia,"Times New Roman",serif;color:#1c3f6e}.flag i{display:block;font:italic 13px Georgia,serif;color:#8a7433;margin-top:5px}
nav{background:#1c3f6e;color:#fff}nav a:hover{color:#f0d890}.tick{background:#faf6e8;border-bottom:1px solid #eadfba;font-size:13px}.tick .box{padding:6px 16px}.tick b{color:#a33;margin-right:8px}
.top{display:grid;grid-template-columns:225px 1fr 280px;gap:22px;padding:16px}.lead{font:700 28px/1.22 Georgia,serif;margin:10px 0 7px}.sapo{color:#444}
.subs{display:grid;grid-template-columns:1fr 1fr;gap:16px;margin-top:12px}.subs h3{font-size:15px;line-height:1.3;margin-top:6px}
.time{color:#a33;font-size:12px;display:block}.notice{background:#f5f7fa;padding:11px 13px;margin-bottom:14px;border-top:3px solid #1c3f6e}.block h3{font-family:Georgia,serif}`,
    home: (site, list) => `<div class="tick"><div class="box"><b>Tiêu điểm</b>${link(list[0])}</div></div>
<main class="box top"><aside><div class="head">Mới nhất</div><ul class="lines">${list.slice(3, 11).map((a) => `<li><span class="time">${clock(a.hours)}</span>${link(a)}</li>`).join('')}</ul></aside>
<div>${lead(list[0])}<div class="subs">${list.slice(1, 3).map((a) => `<div>${link(a, thumb(a))}<h3>${link(a)}</h3></div>`).join('')}</div></div>
<aside><div class="notice"><div class="head">Thông báo</div><ul class="lines">${inSection(site, 'Thời sự').slice(0, 4).map((a) => `<li>${link(a)}</li>`).join('')}</ul></div><div class="head">Đọc nhiều</div><ol class="rank">${mostRead(site).slice(0, 5).map((a) => `<li>${link(a)}</li>`).join('')}</ol></aside></main>${blocks(site)}`,
  },
  tabloid: {
    css: `:root{--accent:#d9480f}.mast{background:#fff;border-top:5px solid #d9480f}.mast .box{display:flex;align-items:center;gap:16px;height:66px}.flag{font:900 italic 34px/1 "Arial Black",Arial,sans-serif;color:#d9480f;letter-spacing:-1.5px}.flag i{font:13px Arial;color:#555;margin-left:8px;letter-spacing:0}
nav{background:#212529;color:#fff;border:0}nav a:hover{color:#ffb88a}.hot{background:#fff4ec;font-size:13px}.hot .box{display:flex;gap:9px;padding:7px 16px;white-space:nowrap;overflow:hidden}.hot b{color:#d9480f}.hot a{background:#fff;border:1px solid #f4d4c0;border-radius:12px;padding:1px 10px}
.top{display:grid;grid-template-columns:1fr 330px;gap:22px;padding:16px}.lead{font:800 30px/1.18 Arial,sans-serif;margin:10px 0 6px}.sapo{color:#444}.subs{display:grid;grid-template-columns:repeat(4,1fr);gap:12px;margin-top:14px}.subs h3{font-size:14px;line-height:1.28;margin-top:6px}
.video{background:#212529;color:#fff;padding:14px 0}.video .head{color:#ffb88a;border-color:#ffb88a}.reel{display:grid;grid-template-columns:repeat(4,1fr);gap:14px;font-size:14px;font-weight:600}.reel .ph::before{content:"▶";position:absolute;z-index:1;left:8px;bottom:6px;color:#fff;font-size:18px}.reel p{margin-top:6px}`,
    home: (site, list) => `<div class="hot"><div class="box"><b>Đang hot</b>${list.slice(0, 5).map((a) => link(a, a.title.split(' ').slice(0, 5).join(' '))).join('')}</div></div>
<main class="box top"><div>${lead(list[0])}<div class="subs">${list.slice(1, 5).map((a) => `<div>${link(a, thumb(a))}<h3>${link(a)}${count(a)}</h3></div>`).join('')}</div></div>
<aside><div class="head">Đọc nhiều</div><ol class="rank">${mostRead(site).slice(0, 8).map((a) => `<li>${link(a)}</li>`).join('')}</ol></aside></main>
<section class="video"><div class="box"><div class="head">Video</div><div class="reel">${list.slice(5, 9).map((a) => `<div>${link(a, thumb(a))}<p>${link(a)}</p></div>`).join('')}</div></div></section>${blocks(site)}`,
  },
  feed: {
    css: `:root{--accent:#3b3fa8}.mast .box{display:flex;align-items:flex-end;gap:10px;padding:14px 16px 10px}.flag{font:700 36px/1 "Trebuchet MS",Arial,sans-serif;color:#3b3fa8}.flag i{font:13px Arial;color:#777;margin-left:10px}
nav{border-top:1px solid #e3e3e3}.top{display:grid;grid-template-columns:270px 1fr 250px;gap:22px;padding:16px}.lead{font:700 27px/1.22 "Trebuchet MS",Arial,sans-serif;margin:10px 0 6px}.sapo{color:#444}
.flow li{display:grid;grid-template-columns:44px 1fr;gap:8px;padding:7px 0 7px;border-left:2px solid #d6d7f0;padding-left:9px;font-size:14px;line-height:1.33}.flow time{color:#3b3fa8;font-weight:700;font-size:12px}
.subs{display:grid;grid-template-columns:repeat(3,1fr);gap:12px;margin-top:14px}.subs h3{font-size:14px;line-height:1.28;margin-top:6px}
.voice{display:grid;grid-template-columns:42px 1fr;gap:9px;padding:9px 0;border-top:1px solid #eee;font-size:14px;font-weight:600;line-height:1.3}.voice b{display:grid;place-items:center;width:42px;height:42px;border-radius:50%;background:#3b3fa8;color:#fff}.voice small{display:block;font-weight:400;color:#777;margin-top:3px}`,
    home: (site, list) => `<main class="box top"><aside><div class="head">Dòng tin</div><ul class="flow">${list.slice(4, 14).map((a) => `<li><time>${clock(a.hours)}</time>${link(a)}</li>`).join('')}</ul></aside>
<div>${lead(list[0])}<div class="subs">${list.slice(1, 4).map((a) => `<div>${link(a, thumb(a))}<h3>${link(a)}${count(a)}</h3></div>`).join('')}</div></div>
<aside><div class="head">Góc nhìn</div>${list.slice(14, 19).map((a) => `<div class="voice"><b>${a.author[0]}</b><div>${link(a)}<small>${a.author}</small></div></div>`).join('')}<div class="head" style="margin-top:14px">Đọc nhiều</div><ol class="rank">${mostRead(site).slice(0, 4).map((a) => `<li>${link(a)}</li>`).join('')}</ol></aside></main>${blocks(site)}`,
  },
};

function frame(site, title, content) {
  const mast = `<header class="mast"><div class="box"><a class="flag" href="/">${site.name}<i>${site.tagline}</i></a></div></header>`;
  return `<!doctype html><html lang="vi"><head><meta charset="utf-8"><title>${escape(title)}</title><style>${BASE}${LAYOUTS[site.layout].css}</style></head>
<body>${util(site)}${mast}${navigation(site)}${content}<footer><div class="box"><b>${site.name}</b> · Tòa soạn: ${site.address}</div></footer></body></html>`;
}

function articlePage(site, a) {
  const related = inSection(site, a.section).filter((other) => other !== a).slice(0, 4);
  return frame(site, `${a.title} - ${site.name}`, `<main class="box read"><article class="story"><div class="crumb"><a href="${sectionHref(a.section)}">${a.section}</a></div><h1>${a.title}</h1>
<p class="by">${a.author} · ${stamp(a.hours)}${count(a)}</p><p class="sapo">${a.sapo}</p><figure>${thumb(a)}<figcaption>Ảnh: ${a.author}</figcaption></figure>${a.body.map((p) => `<p>${p}</p>`).join('')}
${related.length ? `<div class="head" style="margin-top:22px">Tin liên quan</div>${related.map((r) => `<div class="mini">${link(r, thumb(r))}${link(r)}</div>`).join('')}` : ''}</article>
<aside><div class="head">Đọc nhiều</div><ol class="rank">${mostRead(site).slice(0, 8).map((r) => `<li>${link(r)}</li>`).join('')}</ol></aside></main>`);
}

function sectionPage(site, section, list) {
  const [first, ...more] = list;
  return frame(site, `${section} - ${site.name}`, `<main class="box read"><div><div class="head">${section}</div><h2 class="lead">${link(first)}</h2>${link(first, thumb(first))}<p class="sapo" style="margin:8px 0">${first.sapo}</p>
${more.map((a) => `<div class="mini">${link(a, thumb(a))}<div>${link(a)}${count(a)}</div></div>`).join('')}</div><aside><div class="head">Đọc nhiều</div><ol class="rank">${mostRead(site).slice(0, 8).map((a) => `<li>${link(a)}</li>`).join('')}</ol></aside></main>`);
}

function render(host, url) {
  const site = SITES[host];
  // Written stories lead the front page; filler only pads it.
  const front = [...newest(site).filter((a) => !a.filler), ...newest(site).filter((a) => a.filler)];
  if (url.pathname === '/') return [200, frame(site, site.name, LAYOUTS[site.layout].home(site, front))];
  const [, kind, slug] = url.pathname.split('/');
  if (kind === 'tin') {
    const article = site.articles.find((a) => a.slug === slug);
    if (article) return [200, articlePage(site, article)];
  }
  if (kind === 'chuyen-muc') {
    const section = site.sections.find((s) => slugify(s) === slug);
    const list = inSection(site, section);
    if (list.length) return [200, sectionPage(site, section, list)];
  }
  return [404, frame(site, 'Không tìm thấy trang', '<main class="box read"><article class="story"><h1>404</h1><p>Bài viết không tồn tại hoặc đã bị gỡ.</p></article></main>')];
}

const photoPath = (name) => (PHOTOS.has(name) ? path.join(PHOTO_DIR, name) : null);
const readPhoto = (name) => (photoPath(name) ? fs.readFileSync(photoPath(name)) : null);

const STOP = ['và', 'là', 'của', 'có', 'các', 'những', 'một', 'ở', 'thế', 'nào', 'gì', 'về', 'tin', 'báo'];
const words = (text) => text.toLowerCase().split(/[^\p{L}\p{N}]+/u).filter(Boolean);

// Whole words only. A query typed with accents keeps them, so "đằng" never matches "đang";
// a query typed without them matches either. Keywords are unaccented and match both ways.
function search(query) {
  const accented = fold(query) !== query.toLowerCase();
  const shape = accented ? (text) => text : fold;
  const stop = new Set(STOP.map(shape));
  const wanted = words(query).map(shape).filter((word) => word.length > 1 && !stop.has(word));
  if (!wanted.length) return [];
  const needed = Math.ceil(wanted.length / 2);
  const found = [];
  for (const site of Object.values(SITES)) {
    for (const a of site.articles) {
      const title = new Set(words(a.title).map(shape));
      const sapo = new Set(words(a.sapo).map(shape));
      const keywords = new Set(words(a.keywords));
      const hits = wanted.filter((word) => title.has(word) || sapo.has(word) || keywords.has(fold(word)));
      if (hits.length < needed) continue;
      const score = hits.reduce((sum, word) => sum + (title.has(word) ? 3 : 1), a.filler ? 0 : 2);
      found.push({ score, hours: a.hours, title: a.title, snippet: a.sapo, age: age(a.hours), siteName: site.name, url: `https://${a.host}${href(a)}`, thumb: thumb(a) });
    }
  }
  return found.sort((a, b) => b.score - a.score || a.hours - b.hours);
}

module.exports = { DOMAINS: Object.keys(SITES), render, search, readPhoto };
