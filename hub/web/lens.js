// LAN side of the phone lens. The only service reachable from outside this machine: it serves
// the viewer page and relays frames, and every request needs the per-run token.
const https = require('https');
const fs = require('fs');
const os = require('os');
const path = require('path');
const crypto = require('crypto');
const { WebSocketServer } = require('ws');
const selfsigned = require('selfsigned');

const PORT = Number(process.env.NEH_LENS_PORT) || 8787;
const SKIPPED_ADAPTER = /^(docker|br-|veth|tailscale|lo|virbr|vmnet|utun)/;

function lanAddress() {
  for (const [name, addresses] of Object.entries(os.networkInterfaces())) {
    if (SKIPPED_ADAPTER.test(name)) continue;
    const found = addresses.find((entry) => entry.family === 'IPv4' && !entry.internal);
    if (found) return found.address;
  }
  return '127.0.0.1';
}

const WEB = path.join(__dirname);
const ARUCO = path.join(__dirname, '..', 'node_modules', 'js-aruco2', 'src');
const FILES = {
  '': [path.join(WEB, 'lens-page.html'), 'text/html; charset=utf-8'],
  '/lens.js': [path.join(WEB, 'lens-page.js'), 'text/javascript'],
  '/scan.js': [path.join(WEB, 'lens-scan.js'), 'text/javascript'],
  '/anchor.js': [path.join(WEB, 'lens-anchor.js'), 'text/javascript'],
  '/xr.js': [path.join(WEB, 'lens-xr.js'), 'text/javascript'],
  '/cv.js': [path.join(ARUCO, 'cv.js'), 'text/javascript'],
  '/aruco.js': [path.join(ARUCO, 'aruco.js'), 'text/javascript'],
};

// Phones only open the camera on https, so the LAN address gets its own certificate.
async function certificate(address) {
  const file = path.join(os.homedir(), '.config', 'neh-school', 'lens-cert.json');
  const saved = fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, 'utf8')) : null;
  if (saved?.address === address) return saved;
  const pems = await selfsigned.generate([{ name: 'commonName', value: 'NEH Lens' }], {
    keySize: 2048,
    extensions: [{ name: 'subjectAltName', altNames: [{ type: 7, ip: address }] }],
  });
  const made = { address, key: pems.private, cert: pems.cert };
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, JSON.stringify(made), { mode: 0o600 });
  return made;
}

// Only these fields reach the game; anything else a phone sends is dropped.
function readPhone(data) {
  try {
    const { aim, anchored, calibrating, progress, report } = JSON.parse(data.toString());
    const update = {};
    if (typeof report === 'string') console.log(`Ống kính: ${report.slice(0, 120)}`);
    if (anchored === true) update.anchored = true;
    if (typeof aim === 'boolean') update.aim = aim;
    if (typeof calibrating === 'boolean') update.calibrating = calibrating;
    if (Number.isFinite(progress)) update.progress = Math.min(1, Math.max(0, progress));
    return update;
  } catch {
    return null;
  }
}

async function start({ onChange, onPhone }) {
  const address = lanAddress();
  const { key, cert } = await certificate(address);
  const token = crypto.randomBytes(9).toString('base64url');
  const route = `/l/${token}`;
  const viewers = new Set();
  let layout = null;
  const server = https.createServer({ key, cert }, (req, res) => {
    const file = req.url.startsWith(route) ? FILES[req.url.slice(route.length)] : null;
    if (!file) {
      res.writeHead(404);
      return res.end();
    }
    res.writeHead(200, { 'content-type': file[1], 'cache-control': 'no-store' });
    const body = fs.readFileSync(file[0]);
    // The page sits at /l/<token>, so its scripts need the token as their base.
    return res.end(req.url === route ? body.toString().replace('<head>', `<head><base href="${route}/">`) : body);
  });
  const sockets = new WebSocketServer({ noServer: true });
  server.on('upgrade', (req, socket, head) => {
    if (req.url !== route || !req.headers.origin?.endsWith(`//${req.headers.host}`)) {
      socket.destroy();
      return;
    }
    sockets.handleUpgrade(req, socket, head, (ws) => {
      viewers.add(ws);
      if (layout) ws.send(layout);
      if (viewers.size === 1) onChange(true);
      ws.on('message', (data) => {
        const update = readPhone(data);
        if (update && Object.keys(update).length) onPhone(update);
      });
      ws.on('close', () => {
        onPhone({ aim: false, calibrating: false });
        viewers.delete(ws);
        if (viewers.size === 0) onChange(false);
      });
    });
  });
  server.on('error', (error) => console.error(`Lens server: ${error.message}`));
  server.listen(PORT, '0.0.0.0');
  return {
    url: `https://${address}:${PORT}${route}`,
    connected: () => viewers.size > 0,
    // A phone behind on the network skips frames instead of falling further behind.
    layout: (text) => {
      layout = text;
      viewers.forEach((ws) => ws.send(text));
    },
    frame: (jpeg) => viewers.forEach((ws) => { if (ws.bufferedAmount === 0) ws.send(jpeg); }),
    close: () => {
      sockets.close();
      server.close();
    },
  };
}

module.exports = { start };
