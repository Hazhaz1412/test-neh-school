// Real search results, read from a search page in a hidden window: no API key, no server.
const { BrowserWindow } = require('electron');

const TIMEOUT_MS = 9000;
const MAX_RESULTS = 10;
const BLOCKED_HOST = /(^|\.)(porn|xxx|xvideos|xnxx|bet|casino)|\.(xxx|adult|porn)$/;
const cache = new Map();

// DuckDuckGo wraps each link in a redirect; the target sits in its uddg parameter.
const EXTRACT = `[...document.querySelectorAll('.result')].map((result) => {
  const link = result.querySelector('.result__a');
  if (!link) return null;
  const target = new URL(link.href).searchParams.get('uddg') ?? link.href;
  return { title: link.textContent.trim(), url: target, snippet: result.querySelector('.result__snippet')?.textContent.trim() ?? '' };
}).filter(Boolean)`;

function isPublicHost(host) {
  return !/^(localhost|127\.|10\.|192\.168\.|169\.254\.|172\.(1[6-9]|2\d|3[01])\.|\[|0\.)|\.local$/.test(host);
}

function usable({ url }) {
  try {
    const { protocol, hostname } = new URL(url);
    return protocol === 'https:' && isPublicHost(hostname) && !BLOCKED_HOST.test(hostname);
  } catch {
    return false;
  }
}

async function searchWeb(query) {
  if (cache.has(query)) return cache.get(query);
  const hidden = new BrowserWindow({ show: false, webPreferences: { partition: 'hidden-search', sandbox: true, contextIsolation: true } });
  let timer;
  try {
    const timeout = new Promise((_resolve, reject) => { timer = setTimeout(() => reject(new Error('search timed out')), TIMEOUT_MS); });
    await Promise.race([hidden.loadURL(`https://html.duckduckgo.com/html/?kp=1&kl=vn-vi&q=${encodeURIComponent(query)}`), timeout]);
    const results = (await Promise.race([hidden.webContents.executeJavaScript(EXTRACT), timeout])).filter(usable).slice(0, MAX_RESULTS);
    // An empty answer may be a CAPTCHA, so it is not remembered.
    if (results.length) cache.set(query, results);
    return results;
  } catch (error) {
    console.error(`Hidden search failed: ${error.message}`);
    return [];
  } finally {
    clearTimeout(timer);
    hidden.destroy();
  }
}

module.exports = { searchWeb, isPublicHost };
