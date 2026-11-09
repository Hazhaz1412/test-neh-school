// Sợi Chỉ: an invented short-post network where people ask what the school will not answer.
// The layout follows today's text-thread apps; the name, logo and icons are our own.
// Replies marked with "contact" lead to /nhan-tin/<id>, which the web stack reports to the game.
const fs = require('fs');
const path = require('path');
const { escape, fold } = require('./text');

const DOMAIN = 'soichi.vn';
const HOME = `https://${DOMAIN}/`;
const DATA = JSON.parse(fs.readFileSync(path.join(__dirname, '..', '..', 'data', 'soichi_posts.json'), 'utf8'));
const COLOURS = ['#e0656b', '#4f8fd8', '#57a773', '#9b6fd1', '#d89b3c', '#3fa7a3', '#c45fa0'];
// Contacts a reply may hand out, and how their chat opens in the game: { id: { name, handle, ask,
// answer } }. Empty until the new story writes its posts.
const CONTACTS = {};

// A spool with a loose thread: the site's own mark.
const LOGO = `<svg viewBox="0 0 40 40" width="34" height="34" aria-label="Sợi Chỉ"><rect x="9" y="6" width="22" height="5" rx="2" fill="#111"/><rect x="9" y="29" width="22" height="5" rx="2" fill="#111"/><rect x="12" y="11" width="16" height="18" fill="#111"/><path d="M12 15h16M12 19h16M12 23h16" stroke="#fff" stroke-width="1.6"/><path d="M28 23c6 1 7 6 3 9s-9 2-9 5" fill="none" stroke="#111" stroke-width="2" stroke-linecap="round"/></svg>`;
const ICON = {
  home: '<path d="M4 11 12 4l8 7v9h-5v-6H9v6H4z"/>',
  search: '<circle cx="11" cy="11" r="6"/><path d="m16 16 4 4"/>',
  write: '<path d="M5 19h14M7 15l9-9 2 2-9 9H7z"/>',
  heart: '<path d="M12 20s-7-4.5-7-10a4 4 0 0 1 7-2.5A4 4 0 0 1 19 10c0 5.5-7 10-7 10z"/>',
  user: '<circle cx="12" cy="8" r="4"/><path d="M4 21c1-5 15-5 16 0"/>',
  reply: '<path d="M20 12a8 8 0 1 1-3-6.2L20 4v5h-5"/>',
  repost: '<path d="M6 9h11l-3-3M18 15H7l3 3"/>',
  share: '<path d="m4 12 16-8-6 16-3-7z"/>',
};
const icon = (name, size = 22) => `<svg viewBox="0 0 24 24" width="${size}" height="${size}" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round" stroke-linecap="round">${ICON[name]}</svg>`;

const CSS = `*{box-sizing:border-box}body{margin:0;background:#fafafa;color:#101010;font:15px/1.45 -apple-system,"Segoe UI",Roboto,Arial,sans-serif}a{color:inherit;text-decoration:none}
nav{position:fixed;left:0;top:0;bottom:0;width:76px;display:flex;flex-direction:column;align-items:center;gap:26px;padding:20px 0;color:#b8b8b8}nav .logo{margin-bottom:18px}nav a:hover,nav a.on{color:#101010}
.top{text-align:center;font-weight:700;padding:18px 0 12px}
.column{max-width:640px;margin:0 auto 40px;background:#fff;border:1px solid #e6e6e6;border-radius:24px;overflow:hidden}
.compose{display:flex;align-items:center;gap:12px;padding:16px 22px;border-bottom:1px solid #eee;color:#999}.compose span:last-child{margin-left:auto;border:1px solid #ddd;border-radius:10px;padding:6px 16px;color:#101010;font-weight:600}
.post{display:grid;grid-template-columns:40px 1fr;gap:12px;padding:16px 22px;border-bottom:1px solid #eee;position:relative}.post.thread::before{content:"";position:absolute;left:41px;top:60px;bottom:-4px;width:2px;background:#e3e3e3}
.post .face{width:38px;height:38px;border-radius:50%;display:grid;place-items:center;color:#fff;font-weight:700}
.post .head{display:flex;gap:8px;align-items:baseline}.post .head b{font-weight:600}.post .head small{color:#999}
.post p{margin:3px 0 9px;white-space:pre-wrap}.acts{display:flex;gap:18px;color:#444;align-items:center;font-size:13px}.acts span{display:flex;align-items:center;gap:5px}
.more{color:#999;font-size:14px}
a.post:hover{background:#fbfbfb}
.ib{display:inline-flex;align-items:center;gap:6px;margin-top:4px;border:1px solid #101010;border-radius:10px;padding:5px 14px;font-weight:600;font-size:14px}
.ib:hover{background:#101010;color:#fff}
.chat{padding:22px}.bubble{max-width:75%;padding:10px 14px;border-radius:18px;margin:8px 0}.mine{margin-left:auto;background:#101010;color:#fff}.theirs{background:#efefef}
.note{color:#777;font-size:13px;text-align:center;margin-top:18px}`;

const face = (name) => `<span class="face" style="background:${COLOURS[[...name].reduce((sum, c) => sum + c.charCodeAt(0), 0) % COLOURS.length]}">${escape(name[0].toUpperCase())}</span>`;
const count = (n) => (n >= 1000 ? `${(n / 1000).toFixed(1).replace('.', ',')}K` : String(n));

function page(title, body, active = 'home') {
  const link = (name, href) => `<a href="${href}"${active === name ? ' class="on"' : ''}>${icon(name, 26)}</a>`;
  return `<!doctype html><html lang="vi"><head><meta charset="utf-8"><title>${escape(title)} • Sợi Chỉ</title><style>${CSS}</style></head><body>
<nav><a class="logo" href="/">${LOGO}</a>${link('home', '/')}${link('search', '/tim')}${link('write', '/')}${link('heart', '/')}${link('user', '/')}</nav>
<div class="top">${escape(title)}</div><div class="column">${body}</div></body></html>`;
}

function postRow(post, href, thread = false) {
  const tag = href ? `a href="${href}"` : 'div';
  return `<${tag} class="post${thread ? ' thread' : ''}">${face(post.name)}<div><div class="head"><b>${escape(post.handle)}</b><small>${escape(post.time)}</small></div><p>${escape(post.text)}</p>
<div class="acts"><span>${icon('heart', 19)}${count(post.likes)}</span><span>${icon('reply', 19)}${post.replies.length}</span><span>${icon('repost', 19)}</span><span>${icon('share', 19)}</span></div></div></${href ? 'a' : 'div'}>`;
}

function replyRow(reply) {
  const ib = reply.contact ? `<a class="ib" href="/nhan-tin/${escape(reply.contact)}">Nhắn tin cho ${escape(CONTACTS[reply.contact].name)}</a>` : '';
  return `<div class="post">${face(reply.name)}<div><div class="head"><b>${escape(reply.handle)}</b><small>${escape(reply.time)}</small></div><p>${escape(reply.text)}</p>${ib}</div></div>`;
}

const feed = (posts) => `<div class="compose">${face('Peter')}<span>Có gì mới?</span><span>Đăng</span></div>${posts.map((p) => postRow(p, `/bai/${p.id}`)).join('')}`;

// The id of the contact a URL asks to message, or null. The web stack tells the game.
function contactOf(url) {
  const match = url.pathname.match(/^\/nhan-tin\/([a-z]+)\/?$/);
  return match && Object.hasOwn(CONTACTS, match[1]) ? match[1] : null;
}

function render(url) {
  const pathName = url.pathname.replace(/\/$/, '') || '/';
  if (pathName === '/') return [200, page('Dành cho bạn', feed(DATA.posts) + (DATA.posts.length ? '' : '<div class="chat note">Chưa có sợi nào.</div>'))];
  if (pathName === '/tim') {
    const query = url.searchParams.get('q') ?? '';
    const box = `<form class="compose" action="/tim">${icon('search', 18)}<input name="q" value="${escape(query)}" placeholder="Tìm kiếm" style="border:0;outline:0;font:inherit;flex:1"></form>`;
    const found = query ? DATA.posts.filter((p) => fold(p.text + p.handle + p.replies.map((r) => r.text).join(' ')).includes(fold(query))) : [];
    return [200, page('Tìm kiếm', box + found.map((p) => postRow(p, `/bai/${p.id}`)).join(''), 'search')];
  }
  const post = DATA.posts.find((p) => pathName === `/bai/${p.id}`);
  if (post) return [200, page('Sợi', postRow(post, null, post.replies.length > 0) + post.replies.map(replyRow).join(''))];
  const who = contactOf(url);
  if (who) {
    const contact = CONTACTS[who];
    return [200, page(contact.name, `<div class="chat"><div class="bubble mine">${escape(contact.ask)}</div><div class="bubble theirs">${escape(contact.answer)}</div>
<p class="note">${escape(contact.name)} đã gửi cho bạn liên hệ Tili.</p></div>`)];
  }
  return [404, page('Không tìm thấy', '<div class="chat">Sợi này không còn nữa.</div>')];
}

const WORDS = ['neh', 'soi chi'];
const search = (query) => (WORDS.some((word) => fold(query).includes(word)) ? [{ title: 'Sợi Chỉ · Dành cho bạn', url: HOME, snippet: 'Những gì học sinh Trường THPT NEH không dám hỏi thành tiếng.' }] : []);

module.exports = { DOMAIN, HOME, render, search, contactOf };
