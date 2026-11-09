// Local web stack. Runs on its own (`npm run web`) or inside the Electron hub;
// the browser reaches it through the fake domains and the game through /game.
const http = require('http');
const crypto = require('crypto');
const { WebSocketServer } = require('ws');
const sites = require('./sites');
const news = require('./news');
const phoneChannel = require('./phone');
const soichi = require('./soichi');

async function start({ port = 0, token = crypto.randomBytes(24).toString('hex'), onProfile = () => {}, onInstall = () => {}, onGameGone = () => {}, searchWeb = async () => [] } = {}) {
  const story = { evidence: [], stage: '', game: false };
  const listeners = new Set();
  let gameSocket = null;
  let hostHeader = '';
  // A contact asked for while the game is away is handed over when it comes back.
  let pendingContact = null;

  const announce = () => {
    for (const res of listeners) res.write(`data: ${JSON.stringify(story)}\n\n`);
  };

  const sendToGame = (message) => {
    if (!gameSocket) return false;
    gameSocket.send(JSON.stringify(message));
    return true;
  };

  const phone = await phoneChannel.start({
    onChange: (on) => sendToGame({ type: 'phone', on }),
    onPhone: (update) => sendToGame({ type: 'phone_input', ...update }),
  });

  const receive = (message) => {
    if (message?.type === 'profile') onProfile(message.id);
    // The game sends this only after the player agreed to desktop changes.
    if (message?.type === 'install_gaaglu' && message.consent === true) onInstall();
    if (message?.type !== 'state') return;
    story.evidence = Array.isArray(message.evidence) ? message.evidence : [];
    story.stage = String(message.stage ?? '');
    announce();
  };

  const server = http.createServer(async (req, res) => {
    // Any website in the player's real browser can reach loopback ports, so only
    // our own Host is served. This also stops DNS rebinding.
    if (req.headers.host !== hostHeader) return reply(res, 403, 'Forbidden');
    const url = new URL(req.url, `http://${hostHeader}`);
    if (url.pathname === '/events') return openEvents(req, res);
    if (url.pathname.startsWith('/anh/')) {
      const photo = news.readPhoto(url.pathname.slice(5));
      if (!photo) return reply(res, 404, 'Not found');
      res.writeHead(200, { 'content-type': 'image/png', 'cache-control': 'max-age=3600' });
      return res.end(photo);
    }
    if (url.pathname === '/thiet-bi') return reply(res, 200, await sites.devicePage(phone.url));
    const host = req.headers['x-fake-host'];
    const contact = host === soichi.DOMAIN ? soichi.contactOf(url) : null;
    if (contact && !sendToGame({ type: 'contact', id: contact })) pendingContact = contact;
    const query = host === sites.HOME_HOST ? url.searchParams.get('q')?.trim() : null;
    const results = query && !sites.isCrisis(query) ? await searchWeb(query) : [];
    const form = req.method === 'POST' ? await readForm(req) : null;
    if (req.method === 'POST' && !form) return reply(res, 413, 'Too large');
    return reply(res, ...sites.render(host, url, results, { method: req.method, form, cookie: req.headers.cookie }));
  });

  const openEvents = (req, res) => {
    res.writeHead(200, { 'content-type': 'text/event-stream', 'cache-control': 'no-store' });
    res.write(`data: ${JSON.stringify(story)}\n\n`);
    listeners.add(res);
    req.on('close', () => listeners.delete(res));
  };

  const sockets = new WebSocketServer({ noServer: true });
  server.on('upgrade', (req, socket, head) => {
    const url = new URL(req.url, `http://${hostHeader}`);
    // Godot sends no Origin; a browser page always does.
    if (url.pathname !== '/game' || url.searchParams.get('token') !== token || req.headers.origin) {
      socket.destroy();
      return;
    }
    sockets.handleUpgrade(req, socket, head, (ws) => {
      gameSocket?.close();
      gameSocket = ws;
      story.game = true;
      announce();
      sendToGame({ type: 'phone', on: phone.connected() });
      if (pendingContact) {
        sendToGame({ type: 'contact', id: pendingContact });
        pendingContact = null;
      }
      ws.on('message', (data, isBinary) => { if (!isBinary) receive(parse(data)); });
      ws.on('close', () => {
        if (gameSocket !== ws) return;
        gameSocket = null;
        story.game = false;
        onGameGone();
        announce();
      });
    });
  });

  return new Promise((resolve) => {
    server.listen(port, '127.0.0.1', () => {
      const bound = server.address().port;
      hostHeader = `127.0.0.1:${bound}`;
      resolve({
        port: bound,
        token,
        story,
        sendToGame,
        phoneUrl: phone.url,
        close: () => {
          phone.close();
          for (const res of listeners) res.end();
          sockets.close();
          gameSocket?.terminate();
          server.close();
        },
      });
    });
  });
}

function reply(res, status, body, headers = {}) {
  res.writeHead(status, { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-store', ...headers });
  res.end(body);
}

const FORM_LIMIT = 4096;

// Forms stay in memory for one comparison; no site keeps what was typed.
function readForm(req) {
  return new Promise((resolve) => {
    let text = '';
    req.setEncoding('utf8');
    req.on('data', (part) => {
      text += part;
      if (text.length > FORM_LIMIT) {
        req.destroy();
        resolve(null);
      }
    });
    req.on('end', () => resolve(new URLSearchParams(text)));
    req.on('error', () => resolve(null));
  });
}

function parse(data) {
  try {
    return JSON.parse(data.toString());
  } catch {
    return null;
  }
}

module.exports = { start };

if (require.main === module) {
  start({ port: Number(process.env.PORT) || 5173 }).then(({ port, token }) => {
    console.log(`NEH web stack: http://127.0.0.1:${port}  token=${token}`);
  });
}
