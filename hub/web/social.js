// Làng Ta, the invented social network of Hải Lâm. It shares its posts with the phone in the game.
const fs = require('fs');
const path = require('path');
const { escape, fold } = require('./text');

const DOMAIN = 'langta.vn';
const DATA = JSON.parse(fs.readFileSync(path.join(__dirname, '..', '..', 'data', 'social_posts.json'), 'utf8'));
const COLOURS = ['#b7632b', '#4e7d5b', '#7a5a8c', '#2f7c86', '#a0474c', '#8a7a33'];
const CSS = `*{box-sizing:border-box}body{margin:0;background:#f3efe6;color:#2b2722;font:15px/1.5 "Segoe UI",Roboto,Arial,sans-serif}a{color:inherit;text-decoration:none}
header{position:sticky;top:0;background:#37503f;color:#fbf6e9;display:flex;align-items:center;gap:18px;padding:9px 22px;z-index:2}header b{font:700 23px Georgia,serif}header input{flex:1;max-width:380px;height:34px;border:0;border-radius:6px;padding:0 12px;background:#4a6653;color:#fff}header input::placeholder{color:#d5ddd0}header span{margin-left:auto;font-size:14px}
.page{display:grid;grid-template-columns:250px minmax(0,620px);gap:22px;justify-content:center;padding:20px}aside{position:sticky;top:72px;align-self:start}aside h3{font-size:12px;letter-spacing:.8px;color:#7b7263;margin:0 0 8px;text-transform:uppercase}aside a{display:block;padding:8px 10px;border-radius:6px}aside a:hover,aside a.on{background:#e6dfcf}aside small{display:block;color:#7b7263}
.cover{background:#37503f;color:#fbf6e9;border-radius:8px;padding:22px;margin-bottom:14px}.cover h1{font:700 24px Georgia,serif;margin:0}
article{background:#fffdf8;border:1px solid #e3dbca;border-radius:8px;padding:15px 18px;margin-bottom:14px}.who{display:flex;gap:10px;align-items:center}.face{width:40px;height:40px;border-radius:8px;display:grid;place-items:center;color:#fff;font-weight:700;flex:none}.who small{display:block;color:#7b7263}.who b{display:block}
article p{margin:12px 0}.tally{display:flex;gap:16px;color:#6d6455;font-size:13px;border-top:1px solid #eee6d6;border-bottom:1px solid #eee6d6;padding:6px 0}.say{margin-top:9px;background:#f4eee1;border-radius:8px;padding:6px 11px;font-size:14px}.say b{display:block;font-size:13px}`;

const face = (name) => `<span class="face" style="background:${COLOURS[[...name].reduce((sum, c) => sum + c.charCodeAt(0), 0) % COLOURS.length]}">${escape(name[0])}</span>`;
const count = (n) => (n >= 1000 ? `${(n / 1000).toFixed(1).replace('.', ',')}K` : n);

const EMPTY = '<article>Chưa có bài viết nào.</article>';

function card(post) {
  const group = DATA.groups.find((g) => g.slug === post.group);
  const says = post.comments.map(([who, text]) => `<div class="say"><b>${escape(who)}</b>${escape(text)}</div>`).join('');
  return `<article><div class="who">${face(post.author)}<div><b>${escape(post.author)}</b><small><a href="/nhom/${group.slug}">${escape(group.name)}</a> · ${escape(post.time)}</small></div></div><p>${escape(post.text)}</p><div class="tally"><span>♥ Thương ${count(post.love)}</span><span>${post.comments.length} bình luận</span></div>${says}</article>`;
}

function page(title, active, body, query = '') {
  const groups = DATA.groups.map((g) => `<a href="/nhom/${g.slug}"${g.slug === active ? ' class="on"' : ''}>${escape(g.name)}<small>${escape(g.members)}</small></a>`).join('');
  return `<!doctype html><html lang="vi"><head><meta charset="utf-8"><title>${escape(title)} | Làng Ta</title><style>${CSS}</style></head><body><header><a href="/"><b>Làng Ta</b></a><form action="/tim" style="flex:1"><input name="q" value="${escape(query)}" placeholder="Tìm trong làng"></form><span>Peter</span></header><div class="page"><aside><h3>Nhóm của bạn</h3>${groups}</aside><main>${body}</main></div></body></html>`;
}

function render(url) {
  const pathName = url.pathname.replace(/\/$/, '') || '/';
  if (pathName === '/') return [200, page('Bảng tin', '', DATA.posts.map(card).join('') || EMPTY)];
  if (pathName === '/tim') {
    const query = url.searchParams.get('q') ?? '';
    const found = DATA.posts.filter((p) => fold(p.text + p.author).includes(fold(query)));
    return [200, page(query, '', found.map(card).join('') || '<article>Không tìm thấy bài viết nào.</article>', query)];
  }
  const group = DATA.groups.find((g) => pathName === `/nhom/${g.slug}`);
  if (!group) return [404, page('Không tìm thấy', '', '<article>Nội dung này không còn.</article>')];
  const posts = DATA.posts.filter((p) => p.group === group.slug);
  return [200, page(group.name, group.slug, `<div class="cover"><h1>${escape(group.name)}</h1>${escape(group.members)}</div>${posts.map(card).join('') || EMPTY}`)];
}

const WORDS = ['neh', 'lang ta', 'ben trau'];
const search = (query) => (WORDS.some((word) => fold(query).includes(word)) ? [{ title: 'Bến Trầu Ơi | Làng Ta', url: `https://${DOMAIN}/nhom/ben-trau-oi`, snippet: 'Nhóm của người dân khu phố Bến Trầu, phường Cổ Đằng.' }] : []);

module.exports = { DOMAIN, render, search };
