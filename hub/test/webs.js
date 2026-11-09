// The fake school site and registry over real HTTP: node hub/test/webs.js
process.env.NEH_PHONE_PORT ??= '0';
const http = require('http');
const assert = require('assert');
const web = require('../web/server');
const { AN_ID } = require('../web/registry');

let stack;
function ask(host, path, { method = 'GET', form, cookie } = {}) {
  const body = form ? new URLSearchParams(form).toString() : undefined;
  return new Promise((resolve, reject) => {
    const request = http.request({ host: '127.0.0.1', port: stack.port, path, method, headers: { host: `127.0.0.1:${stack.port}`, 'x-fake-host': host, ...(body ? { 'content-type': 'application/x-www-form-urlencoded', 'content-length': Buffer.byteLength(body) } : {}), ...(cookie ? { cookie } : {}) } }, (res) => {
      let text = '';
      res.setEncoding('utf8');
      res.on('data', (part) => { text += part; });
      res.on('end', () => resolve({ status: res.statusCode, text, location: res.headers.location, cookie: res.headers['set-cookie']?.[0]?.split(';')[0] }));
    });
    request.on('error', reject);
    request.end(body);
  });
}

(async () => {
  stack = await web.start();
  const SCHOOL = 'thptneh.edu.vn';
  const GOV = 'dancu.hailam.gov.vn';
  for (const path of ['/', '/gioi-thieu', '/tin-tuc', '/thong-bao', '/hoc-tap', '/bang-vang', '/cau-lac-bo', '/van-ban', '/luu-but', '/lien-he', '/tin-tuc/giai-co-vua-truong']) {
    assert.equal((await ask(SCHOOL, path)).status, 200, path);
  }
  assert.ok(!(await ask(SCHOOL, '/bang-vang')).text.includes(AN_ID), 'the honour board hides the number');
  assert.ok((await ask(SCHOOL, '/van-ban/ds-du-thi-hsg-2009')).text.includes(AN_ID), 'the entry list reveals the number');
  assert.ok((await ask(SCHOOL, '/tin-tuc/giai-co-vua-truong')).text.includes('cờ vua'), 'the chess story gives the answer');
  assert.equal((await ask(SCHOOL, '/khong-co')).status, 404);
  assert.equal((await ask(GOV, '/ho-so')).status, 303, 'no record without login');
  const stranger = await ask(GOV, '/tra-cuu', { method: 'POST', form: { so: '012345678901' } });
  assert.ok(stranger.text.includes('Không tìm thấy') && !stranger.text.includes('012345678901'), 'other numbers are refused and never echoed');
  assert.ok((await ask(GOV, '/tra-cuu', { method: 'POST', form: { so: '123' } })).text.includes('12 chữ số'));
  const found = await ask(GOV, '/tra-cuu', { method: 'POST', form: { so: AN_ID } });
  assert.equal(found.location, '/xac-minh');
  const { cookie } = found;
  assert.ok((await ask(GOV, '/xac-minh', { cookie })).text.includes('Môn bạn thích chơi nhất là gì?'));
  assert.equal((await ask(GOV, '/ho-so', { cookie })).status, 303, 'the question cannot be skipped');
  assert.ok((await ask(GOV, '/xac-minh', { method: 'POST', form: { dap: 'bóng đá' }, cookie })).text.includes('chưa đúng'));
  for (const answer of ['cờ vua', 'CỜ VUA', 'co vua', '  Cờ   Vua ']) {
    const next = await ask(GOV, '/tra-cuu', { method: 'POST', form: { so: AN_ID } });
    const passed = await ask(GOV, '/xac-minh', { method: 'POST', form: { dap: answer }, cookie: next.cookie });
    assert.equal(passed.location, '/ho-so', answer);
    assert.ok((await ask(GOV, '/ho-so', { cookie: next.cookie })).text.includes('NGUYỄN BÌNH AN'));
  }
  assert.equal((await ask(GOV, '/xac-minh', { method: 'POST', form: { dap: 'cờ vua' }, cookie })).location, '/ho-so');
  assert.equal((await ask(GOV, '/dang-xuat', { method: 'POST', cookie })).location, '/');
  assert.equal((await ask(GOV, '/ho-so', { cookie })).status, 303, 'logging out closes the record');
  // The old story's posts were cleared: the feeds still serve, empty, until the new story fills them.
  assert.ok((await ask('langta.vn', '/')).text.includes('Chưa có bài viết nào'), 'the empty feed says so');
  assert.equal((await ask('langta.vn', '/nhom/cuu-hs-neh')).status, 200);
  assert.ok(!(await ask('langta.vn', '/')).text.includes('Chuyện Ma'), 'no ghost-story groups are left');
  assert.ok((await ask('gaaglu.com', '/search?q=l%C3%A0ng%20ta')).text.includes('langta.vn'), 'search finds the feed');
  const big = await ask(GOV, '/tra-cuu', { method: 'POST', form: { so: 'x'.repeat(9000) } }).catch(() => ({ status: 413 }));
  assert.equal(big.status, 413);
  assert.ok((await ask('gaaglu.com', '/search?q=tr%C6%B0%E1%BB%9Dng%20NEH')).text.includes(SCHOOL), 'search finds the school');
  assert.ok((await ask('gaaglu.com', '/search?q=tra%20c%E1%BB%A9u%20cccd')).text.includes(GOV), 'search finds the registry');
  // Sợi Chỉ: an empty feed, no contacts to message, and the game still links and hears the phone channel.
  const SOICHI = 'soichi.vn';
  assert.ok((await ask(SOICHI, '/')).text.includes('Chưa có sợi nào'), 'Sợi Chỉ shows its empty feed');
  assert.equal((await ask(SOICHI, '/nhan-tin/bayro')).status, 404, 'only known contacts can be messaged');
  assert.ok((await ask('gaaglu.com', '/search?q=s%E1%BB%A3i%20ch%E1%BB%89')).text.includes(SOICHI), 'search finds Sợi Chỉ');
  const WebSocket = require('ws');
  const game = new WebSocket(`ws://127.0.0.1:${stack.port}/game?token=${stack.token}`);
  const paired = await new Promise((resolve, reject) => {
    game.on('message', (data) => {
      const message = JSON.parse(data.toString());
      if (message.type === 'phone') resolve(message);
    });
    game.on('error', reject);
    setTimeout(() => reject(new Error('no phone message')), 3000);
  });
  assert.equal(paired.on, false, 'the game hears that no phone is paired');
  game.close();
  stack.close();
  console.log('webs OK');
  process.exit(0);
})().catch((error) => { console.error(error); process.exit(1); });
