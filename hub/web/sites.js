// Fake sites of the ARG. Every name and domain here is invented; add new sites to DOMAINS.
const fs = require('fs');
const path = require('path');
const news = require('./news');
const QRCode = require('qrcode');

const SEARCH = 'gaaglu.com';
const DOMAINS = [SEARCH, ...news.DOMAINS];
const HOME = `https://${SEARCH}/`;
const LOGO = fs.readFileSync(path.join(__dirname, '..', 'shell', 'logo.svg'), 'utf8');

const fold = (text) => text.toLowerCase().normalize('NFD').replace(/\p{M}/gu, '').replace(/đ/g, 'd');
// Fake or unreliable results here could do real harm, so these searches leave the fiction.
const CRISIS = /tu tu|tu sat|tu hai|tu ket lieu|muon chet|khong muon song|cach chet|suicide|kill myself|self harm/;
const isCrisis = (query) => CRISIS.test(fold(query));

const escape = (text) => String(text).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));

function page(title, body) {
  return `<!doctype html><html lang="vi"><head><meta charset="utf-8"><title>${escape(title)}</title>
<style>
body{margin:0;font:15px/1.6 "Segoe UI",Roboto,Arial,sans-serif;color:#222;background:#fff}
main{max-width:640px;margin:0 auto;padding:0 20px}
.logo{width:112px;height:112px;margin:150px auto 30px}
.search{display:block}.search input{font:inherit;width:100%;box-sizing:border-box;height:46px;padding:0 22px;border-radius:23px;border:1px solid #d5d9dc;box-shadow:0 1px 5px #0002;outline:0}
.meta{color:#777;font-size:13px}
.result{margin:22px 0}.result a{font-size:18px;color:#1a4fc0;text-decoration:none}.result a:hover{text-decoration:underline}.result .site{color:#4d5156;font-size:13px}.result p{margin:2px 0;color:#4d5156;font-size:14px}
.top{margin:18px 0 24px}.top h2{font-size:18px;font-weight:600;margin:0 0 10px}.cards{display:grid;grid-template-columns:repeat(3,1fr);gap:10px}
.news{display:block;border:1px solid #dfe3e6;border-radius:12px;overflow:hidden;color:#202124;text-decoration:none}.news:hover{box-shadow:0 1px 6px #0003}.news .ph{display:block;height:92px;overflow:hidden}.news .ph svg,.news .ph img{display:block;width:100%;height:100%;object-fit:cover}.news div{padding:8px 10px;font-size:13px;line-height:1.35}.news b{display:block;font-size:12px;font-weight:600;color:#4d5156;margin-bottom:3px}.news small{display:block;color:#70757a;margin-top:4px}
.support{border:1px solid #d5d9dc;border-radius:12px;padding:6px 22px;margin-top:20px}
</style></head><body>${body}</body></html>`;
}

function resultItem({ title, url, snippet }) {
  return `<div class="result"><div class="site">${escape(new URL(url).hostname)}</div><a href="${escape(url)}">${escape(title)}</a><p>${escape(snippet)}</p></div>`;
}

// Game stories lead: the best in a news box at the top, the rest spread between real results.
function storyBox(stories) {
  const cards = stories.map((s) => `<a class="news" href="${escape(s.url)}">${s.thumb}<div><b>${escape(s.siteName)}</b>${escape(s.title)}<small>${s.age}</small></div></a>`).join('');
  return `<section class="top"><h2>Tin hàng đầu</h2><div class="cards">${cards}</div></section>`;
}

function blend(query, results) {
  const stories = news.search(query);
  const lead = stories.slice(0, 3);
  const rest = stories.slice(3);
  const list = results.map(resultItem);
  rest.forEach((story, index) => list.splice(index * 3 + 1, 0, resultItem(story)));
  return (lead.length ? storyBox(lead) : '') + list.join('');
}

function search(url, results) {
  const query = (url.searchParams.get('q') ?? '').trim();
  const box = `<form class="search" action="/search"><input name="q" value="${escape(query)}" placeholder="Tìm trên Gaaglu" autofocus></form>`;
  if (!query) return page('Gaaglu', `<main><div class="logo">${LOGO}</div>${box}</main>`);
  if (isCrisis(query)) {
    return page(`${query} - Tìm trên Gaaglu`, `<main style="margin-top:20px">${box}<div class="support"><h3>Đây là thông tin thật, không thuộc trò chơi</h3>
<p>Nếu bạn hoặc người bạn quen đang nghĩ tới việc tự làm hại mình, hãy nói với một người bạn tin tưởng ngay bây giờ.</p>
<p>Tổng đài Quốc gia Bảo vệ Trẻ em: <b>111</b>. Nguy hiểm trước mắt: gọi cấp cứu <b>115</b>.</p></div></main>`);
  }
  const list = blend(query, results) || `<p>Không tìm thấy kết quả nào cho “${escape(query)}”.</p>`;
  return page(`${query} - Tìm trên Gaaglu`, `<main style="margin-top:20px">${box}${list}</main>`);
}

async function devicePage(lensUrl) {
  const code = await QRCode.toString(lensUrl, { type: 'svg', margin: 1, width: 320 });
  return page('Ghép điện thoại', `<main style="text-align:center"><h2 style="margin-top:40px">Quét để mở ống kính</h2><div style="width:320px;margin:0 auto">${code}</div>
<p class="meta">${escape(lensUrl)}</p><p>Điện thoại phải dùng cùng Wi-Fi với máy này.</p></main>`);
}

function offline(host) {
  return page('Không thể truy cập trang web', `<main><h2 style="margin-top:110px">Không thể truy cập trang web này</h2>
<p>Không tìm thấy địa chỉ của <b>${escape(host)}</b>.</p><p class="meta">DNS_PROBE_FINISHED_NXDOMAIN</p></main>`);
}

function render(host, url, results = []) {
  if (news.DOMAINS.includes(host)) return news.render(host, url);
  if (url.pathname !== '/' && url.pathname !== '/search') return [404, page('404', '<main><h2>404</h2><p>Trang này không tồn tại.</p></main>')];
  return [200, search(url, results)];
}

function isHome(address) {
  const url = new URL(address);
  return url.hostname === SEARCH && url.pathname === '/' && !url.search;
}

module.exports = { DOMAINS, HOME, render, offline, isHome, isCrisis, devicePage };
