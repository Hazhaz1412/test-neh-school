// Local web stack. Runs on its own (`npm run web`) or inside the Electron hub;
// the browser reaches it through the fake domains and the game through /game.
const http = require('http');
const crypto = require('crypto');
const { WebSocketServer } = require('ws');
const sites = require('./sites');

function start({ port = 0, token = crypto.randomBytes(24).toString('hex'), onProfile = () => {}, searchWeb = async () => [] } = {}) {
  const story = { evidence: [], stage: '', game: false };
  const listeners = new Set();
  let gameSocket = null;
  let hostHeader = '';

  const announce = () => {
    for (const res of listeners) res.write(`data: ${JSON.stringify(story)}\n\n`);
  };

  const sendToGame = (message) => {
    if (!gameSocket) return false;
    gameSocket.send(JSON.stringify(message));
    return true;
  };

  const receive = (message) => {
    if (message?.type === 'profile') onProfile(message.id);
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
    const query = url.searchParams.get('q')?.trim();
    const results = query && !sites.isCrisis(query) ? await searchWeb(query) : [];
    return reply(res, ...sites.render(url, results));
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
      ws.on('message', (data) => receive(parse(data)));
      ws.on('close', () => {
        if (gameSocket !== ws) return;
        gameSocket = null;
        story.game = false;
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
        close: () => {
          for (const res of listeners) res.end();
          sockets.close();
          gameSocket?.terminate();
          server.close();
        },
      });
    });
  });
}

function reply(res, status, body) {
  res.writeHead(status, { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-store' });
  res.end(body);
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
