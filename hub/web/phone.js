// LAN side of the phone channel. The only service reachable from outside this machine: it serves
// the pairing page to a phone on the same Wi-Fi and relays its messages to the game. Every request
// needs the per-run token. The page is a placeholder for the phone-as-controller to come.
const https = require('https');
const fs = require('fs');
const os = require('os');
const path = require('path');
const crypto = require('crypto');
const { WebSocketServer } = require('ws');
const selfsigned = require('selfsigned');

const PORT = Number(process.env.NEH_PHONE_PORT ?? process.env.NEH_LENS_PORT) || 8787;
const SKIPPED_ADAPTER = /^(docker|br-|veth|tailscale|lo|virbr|vmnet|utun)/;

function lanAddress() {
  for (const [name, addresses] of Object.entries(os.networkInterfaces())) {
    if (SKIPPED_ADAPTER.test(name)) continue;
    const found = addresses.find((entry) => entry.family === 'IPv4' && !entry.internal);
    if (found) return found.address;
  }
  return '127.0.0.1';
}

const FILES = {
  '': [path.join(__dirname, 'phone-page.html'), 'text/html; charset=utf-8'],
  '/phone.js': [path.join(__dirname, 'phone-page.js'), 'text/javascript'],
};

// Phones only allow motion sensors and vibration on https, so the LAN address gets its own
// certificate. The file keeps its old name so a phone that accepted it once is not asked again.
async function certificate(address) {
  const file = path.join(os.homedir(), '.config', 'neh-school', 'lens-cert.json');
  const saved = fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, 'utf8')) : null;
  if (saved?.address === address) return saved;
  const pems = await selfsigned.generate([{ name: 'commonName', value: 'NEH Phone' }], {
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
    const { tap, report } = JSON.parse(data.toString());
    const update = {};
    if (typeof report === 'string') console.log(`Điện thoại: ${report.slice(0, 120)}`);
    if (tap === true) update.tap = true;
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
  const phones = new Set();
  const server = https.createServer({ key, cert }, (req, res) => {
    const file = req.url.startsWith(route) ? FILES[req.url.slice(route.length)] : null;
    if (!file) {
      res.writeHead(404);
      return res.end();
    }
    res.writeHead(200, { 'content-type': file[1], 'cache-control': 'no-store' });
    const body = fs.readFileSync(file[0]);
    // The page sits at /l/<token>, so its script needs the token as its base.
    return res.end(req.url === route ? body.toString().replace('<head>', `<head><base href="${route}/">`) : body);
  });
  const sockets = new WebSocketServer({ noServer: true });
  server.on('upgrade', (req, socket, head) => {
    if (req.url !== route || !req.headers.origin?.endsWith(`//${req.headers.host}`)) {
      socket.destroy();
      return;
    }
    sockets.handleUpgrade(req, socket, head, (ws) => {
      phones.add(ws);
      if (phones.size === 1) onChange(true);
      ws.on('message', (data) => {
        const update = readPhone(data);
        if (update && Object.keys(update).length) onPhone(update);
      });
      ws.on('close', () => {
        phones.delete(ws);
        if (phones.size === 0) onChange(false);
      });
    });
  });
  server.on('error', (error) => console.error(`Phone channel: ${error.message}`));
  server.listen(PORT, '0.0.0.0');
  return {
    url: `https://${address}:${PORT}${route}`,
    connected: () => phones.size > 0,
    send: (message) => phones.forEach((ws) => ws.send(JSON.stringify(message))),
    close: () => {
      sockets.close();
      server.close();
    },
  };
}

module.exports = { start };
