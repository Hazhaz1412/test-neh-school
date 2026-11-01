// Fake browser shell. The address bar is our own UI; requests to the fake domains
// are answered here and never leave the machine.
const { app, BaseWindow, WebContentsView, ipcMain, session, Menu } = require('electron');
const { spawn } = require('child_process');
const fs = require('fs');
const http = require('http');
const os = require('os');
const path = require('path');
const { Readable } = require('stream');
const web = require('./web/server');
const sites = require('./web/sites');
const { DEFAULT, PROFILES } = require('./profiles');
const { searchWeb, isPublicHost } = require('./realweb');

const BAR_HEIGHT = 86;
const BOOKMARK_HEIGHT = 34;
const MENU = { width: 280, height: 200 };
// Peter's patience on a real page: each step is a random delay after the one before.
const VISIT = { loadCap: 8000, mild: [2000, 3000], annoyed: [5000, 8000], leave: [3000, 5000], lineShown: 3000, lastWord: 1800 };
const CLICK_WINDOW = 1500;
const BLOCKED_BY_CLIENT = -20;
const THOUGHT_HEIGHT = 110;
const SESSION_FILE = path.join(os.homedir(), '.config', 'neh-school', 'hub.json');
const FAKE = new Set(sites.DOMAINS);

let stack;
let game;
let setProfile = () => {};
let lastClick = 0;

function routeFakeWeb(ses) {
  const local = `http://127.0.0.1:${stack.port}`;
  // Node's client rather than net.fetch, which cannot hand a redirect back to the page.
  const forward = (target, method, headers, body) => new Promise((resolve, reject) => {
    const outgoing = http.request(target, { method, headers }, resolve);
    outgoing.on('error', reject);
    outgoing.end(body);
  });
  const handle = async (request) => {
    const url = new URL(request.url);
    if (!FAKE.has(url.hostname)) {
      return new Response(sites.offline(url.hostname), { headers: { 'content-type': 'text/html; charset=utf-8' } });
    }
    const site = `https://${url.hostname}/`;
    const headers = { 'x-fake-host': url.hostname };
    const type = request.headers.get('content-type');
    if (type) headers['content-type'] = type;
    // Protocol handlers bypass the cookie jar, so it is applied by hand.
    const cookies = await ses.cookies.get({ url: site });
    if (cookies.length) headers.cookie = cookies.map((c) => `${c.name}=${c.value}`).join('; ');
    const body = request.body ? Buffer.from(await request.arrayBuffer()) : undefined;
    const response = await forward(local + url.pathname + url.search, request.method, headers, body);

    for (const line of response.headers['set-cookie'] ?? []) {
      const [name, ...value] = line.split(';')[0].split('=');
      await ses.cookies.set({ url: site, name, value: value.join('='), httpOnly: true, secure: true });
    }
    const { location, 'content-type': contentType, 'cache-control': cacheControl } = response.headers;
    if (location) {
      response.resume();
      return new Response(null, { status: response.statusCode, headers: { location: new URL(location, url).href } });
    }
    const passed = { 'content-type': contentType, 'cache-control': cacheControl };
    return new Response(Readable.toWeb(response), { status: response.statusCode, headers: passed });
  };
  ses.protocol.handle('https', handle);
  ses.protocol.handle('http', handle);
  ses.setPermissionRequestHandler((_contents, _permission, callback) => callback(false));
}

function lockVisitSession() {
  const ses = session.fromPartition('visit');
  ses.setPermissionRequestHandler((_contents, _permission, callback) => callback(false));
  ses.on('will-download', (event) => event.preventDefault());
  // A form the player clicked is theirs and is not sent. Everything else stays, since
  // pages load data over background POST and bot checks submit forms on their own.
  ses.webRequest.onBeforeRequest((details, callback) => {
    if (details.resourceType === 'webSocket') return callback({});
    const document = details.resourceType === 'mainFrame' || details.resourceType === 'subFrame';
    const posted = details.method !== 'GET' && details.method !== 'HEAD';
    const byPlayer = document && posted && Date.now() - lastClick < CLICK_WINDOW;
    callback({ cancel: byPlayer || !isPublicHost(new URL(details.url).hostname) });
  });
}

// The bar accepts what a real one does: a domain goes there, anything else is a search.
function toUrl(input) {
  const text = input.trim();
  if (/^https?:\/\//i.test(text)) return text;
  if (/^[^\s/:]+\.[^\s/:]+(\/\S*)?$/.test(text)) return `https://${text}`;
  return `${sites.HOME}search?q=${encodeURIComponent(text)}`;
}

function openBrowser() {
  const win = new BaseWindow({ width: 1240, height: 800, minWidth: 620, minHeight: 400, frame: false, title: 'Cú Đêm', backgroundColor: '#dfe3e6' });
  const bar = new WebContentsView({
    webPreferences: { preload: path.join(__dirname, 'shell', 'preload.js'), contextIsolation: true, sandbox: true },
  });
  const menu = new WebContentsView({
    webPreferences: { preload: path.join(__dirname, 'shell', 'preload.js'), contextIsolation: true, sandbox: true },
  });
  menu.setBackgroundColor('#00000000');
  win.contentView.addChildView(bar);

  const bookmarksFile = path.join(app.getPath('userData'), 'bookmarks.json');
  const savedBookmarks = fs.existsSync(bookmarksFile) ? JSON.parse(fs.readFileSync(bookmarksFile, 'utf8')) : {};
  const bookmarks = () => (savedBookmarks[profileId] ??= []);
  let profileId = DEFAULT;
  let menuOpen = false;
  let menuClosedAt = 0;
  const cover = new WebContentsView({
    webPreferences: { preload: path.join(__dirname, 'shell', 'preload.js'), contextIsolation: true, sandbox: true },
  });
  cover.setBackgroundColor('#00000000');
  let visit = null;
  const lines = {};
  const barHeight = () => BAR_HEIGHT + (bookmarks().length ? BOOKMARK_HEIGHT : 0);

  const tabs = [];
  let active = null;
  let nextId = 1;

  const layout = () => {
    const { width, height } = win.getContentBounds();
    bar.setBounds({ x: 0, y: 0, width, height: barHeight() });
    const content = { x: 0, y: barHeight(), width, height: height - barHeight() };
    active?.view.setBounds(content);
    visit?.view.setBounds(content);
    cover.setBounds({ ...content, y: height - THOUGHT_HEIGHT, height: THOUGHT_HEIGHT });
    menu.setBounds({ x: width - MENU.width - 8, y: BAR_HEIGHT - 4, ...MENU });
  };

  const pushState = () => {
    if (!active) return;
    const page = active.view.webContents;
    const url = visit?.url ?? page.getURL();
    win.setTitle(`${page.getTitle()} · Cú Đêm`);
    const state = {
      url: !url || (!visit && sites.isHome(url)) ? '' : url,
      visiting: Boolean(visit),
      canBack: Boolean(visit) || page.navigationHistory.canGoBack(),
      canForward: page.navigationHistory.canGoForward(),
      profile: PROFILES[profileId],
      bookmarks: bookmarks(),
      bookmarked: bookmarks().some((bookmark) => bookmark.url === url),
      tabs: tabs.map((tab) => ({
        id: tab.id,
        title: tab.view.webContents.getTitle() || 'Tab mới',
        loading: tab.view.webContents.isLoading(),
        active: tab === active,
      })),
    };
    bar.webContents.send('state', state);
    menu.webContents.send('state', state);
  };

  const closeMenu = () => {
    if (!menuOpen) return;
    menuOpen = false;
    menuClosedAt = Date.now();
    win.contentView.removeChildView(menu);
  };

  const nextLine = (kind) => {
    const list = PROFILES[profileId].thoughts[kind];
    lines[kind] = (lines[kind] ?? 0) + 1;
    return list[(lines[kind] - 1) % list.length];
  };

  const endVisit = () => {
    if (!visit) return;
    const { view, timers } = visit;
    timers.forEach(clearTimeout);
    visit = null;
    cover.webContents.send('thought', '');
    win.contentView.removeChildView(cover);
    win.contentView.removeChildView(view);
    view.webContents.close();
    session.fromPartition('visit').clearStorageData();
    pushState();
  };

  const between = ([low, high]) => low + Math.random() * (high - low);

  // Trip to a real site: the player can scroll and click but never type, while the
  // character loses patience and finally storms back to the search page.
  const startVisit = (url) => {
    endVisit();
    closeMenu();
    const view = new WebContentsView({
      webPreferences: { partition: 'visit', contextIsolation: true, nodeIntegration: false, sandbox: true },
    });
    const page = view.webContents;
    visit = { url, view, timers: [], leaving: false, started: false };
    const current = visit;
    const later = (delay, action) => current.timers.push(setTimeout(action, delay));

    const say = (kind) => {
      win.contentView.addChildView(cover);
      cover.webContents.send('thought', { text: nextLine(kind), kind });
    };
    const quiet = () => {
      cover.webContents.send('thought', null);
      if (!current.leaving) win.contentView.removeChildView(cover);
    };
    const leave = (kind) => {
      if (current.leaving) return;
      current.leaving = true;
      current.timers.forEach(clearTimeout);
      say(kind);
      later(VISIT.lastWord, endVisit);
    };
    const speakThenFade = (kind) => {
      if (current.leaving) return;
      say(kind);
      later(VISIT.lineShown, quiet);
    };
    const loseMyPatience = () => {
      const mild = between(VISIT.mild);
      const annoyed = mild + between(VISIT.annoyed);
      later(mild, () => speakThenFade('mild'));
      later(annoyed, () => speakThenFade('annoyed'));
      later(annoyed + between(VISIT.leave), () => leave('done'));
    };

    page.setAudioMuted(true);
    page.setWindowOpenHandler(() => ({ action: 'deny' }));
    page.on('before-input-event', (event, input) => {
      event.preventDefault();
      if (input.type === 'keyDown' && input.key === 'Escape') endVisit();
    });
    page.on('before-mouse-event', (_event, mouse) => {
      if (mouse.type === 'mouseDown') lastClick = Date.now();
    });
    page.on('context-menu', (event) => event.preventDefault());
    page.on('did-navigate', (_event, target) => {
      current.url = target;
      if (!current.started) loseMyPatience();
      current.started = true;
      pushState();
    });
    page.on('did-navigate-in-page', (_event, target, isMainFrame) => {
      if (!isMainFrame) return;
      current.url = target;
      pushState();
    });
    page.on('did-fail-load', (_event, code, _text, _url, isMainFrame) => {
      if (!isMainFrame || code === -3) return;
      if (code !== BLOCKED_BY_CLIENT) return leave('failed');
      // The player clicked a form: stay on the page instead of showing an error document.
      speakThenFade('refused');
      if (page.navigationHistory.canGoBack()) page.navigationHistory.goBack();
    });
    // A click must never open the native picker and hand a real file to a website.
    page.debugger.attach();
    page.debugger.sendCommand('Page.setInterceptFileChooserDialog', { enabled: true }).catch(() => {});

    later(VISIT.loadCap, () => {
      if (!current.started) leave('failed');
    });
    win.contentView.addChildView(view);
    layout();
    page.focus();
    pushState();
    page.loadURL(url).catch(() => {});
  };

  const open = (url) => {
    const { protocol, hostname } = new URL(url);
    const real = !FAKE.has(hostname) && /^https?:$/.test(protocol) && isPublicHost(hostname);
    if (real) startVisit(url);
    else active.view.webContents.loadURL(url);
  };

  const activate = (tab) => {
    closeMenu();
    endVisit();
    if (active) win.contentView.removeChildView(active.view);
    active = tab;
    win.contentView.addChildView(tab.view);
    layout();
    pushState();
  };

  const shortcuts = (_event, input) => {
    if (input.type !== 'keyDown') return;
    // View source and devtools are part of the puzzles.
    if (input.key === 'F12') active.view.webContents.toggleDevTools();
    if (!input.control) return;
    const key = input.key.toLowerCase();
    if (key === 't') openTab(sites.HOME);
    if (key === 'w') closeTab(active);
    if (key === 'l') bar.webContents.send('focus-address');
  };

  function openTab(url) {
    // Page content stays isolated: no preload and no Node, whatever a forum post contains.
    const view = new WebContentsView({
      webPreferences: { partition: 'persist:fakeweb', contextIsolation: true, nodeIntegration: false, sandbox: true },
    });
    const tab = { id: nextId++, view };
    const page = view.webContents;
    for (const event of ['did-navigate', 'did-navigate-in-page', 'page-title-updated', 'did-start-loading', 'did-stop-loading']) {
      page.on(event, pushState);
    }
    page.setWindowOpenHandler((details) => {
      openTab(details.url);
      return { action: 'deny' };
    });
    page.on('before-input-event', shortcuts);
    page.on('will-navigate', (event) => {
      if (FAKE.has(new URL(event.url).hostname)) return;
      event.preventDefault();
      open(event.url);
    });
    tabs.push(tab);
    activate(tab);
    page.loadURL(url);
    if (url === sites.HOME) bar.webContents.send('focus-address');
  }

  function closeTab(tab) {
    const index = tabs.indexOf(tab);
    tabs.splice(index, 1);
    if (!tabs.length) return win.close();
    if (tab === active) {
      win.contentView.removeChildView(tab.view);
      active = null;
      activate(tabs[Math.min(index, tabs.length - 1)]);
    }
    tab.view.webContents.close();
    pushState();
  }

  const tabById = (id) => tabs.find((tab) => tab.id === id);

  // The account is story state: only the game changes it, never the player.
  setProfile = (id) => {
    if (!PROFILES[id]) return;
    profileId = id;
    layout();
    pushState();
  };

  ipcMain.on('go', (_event, input) => {
    if (!input.trim()) return;
    endVisit();
    open(toUrl(input));
  });
  ipcMain.on('ready', pushState);
  ipcMain.on('bookmark', () => {
    const page = active.view.webContents;
    const list = bookmarks();
    const index = list.findIndex((bookmark) => bookmark.url === page.getURL());
    if (index >= 0) list.splice(index, 1);
    else list.push({ title: page.getTitle(), url: page.getURL() });
    fs.writeFileSync(bookmarksFile, JSON.stringify(savedBookmarks));
    layout();
    pushState();
  });
  ipcMain.on('menu', () => {
    // Clicking the avatar blurs the open menu first, which must not reopen it.
    if (menuOpen || Date.now() - menuClosedAt < 250) return closeMenu();
    menuOpen = true;
    win.contentView.addChildView(menu);
    menu.webContents.focus();
  });
  ipcMain.on('nav', (_event, action) => {
    if (visit) {
      const history = visit.view.webContents.navigationHistory;
      if (action === 'back') return history.canGoBack() ? history.goBack() : endVisit();
      return undefined;
    }
    const page = active.view.webContents;
    if (action === 'back') page.navigationHistory.goBack();
    if (action === 'forward') page.navigationHistory.goForward();
    if (action === 'reload') page.reload();
  });
  ipcMain.on('tab', (_event, action, id) => {
    if (action === 'new') openTab(sites.HOME);
    if (action === 'select' && tabById(id)) activate(tabById(id));
    if (action === 'close' && tabById(id)) closeTab(tabById(id));
  });
  ipcMain.on('window', (_event, action) => {
    if (action === 'minimize') win.minimize();
    if (action === 'maximize') win.isMaximized() ? win.unmaximize() : win.maximize();
    if (action === 'close') win.close();
  });

  win.on('resize', () => {
    layout();
    pushState();
  });
  win.on('closed', () => app.quit());
  bar.webContents.on('before-input-event', shortcuts);
  menu.webContents.on('blur', closeMenu);
  bar.webContents.once('did-finish-load', () => openTab(sites.HOME));
  bar.webContents.loadFile(path.join(__dirname, 'shell', 'bar.html'));
  menu.webContents.loadFile(path.join(__dirname, 'shell', 'menu.html'));
  cover.webContents.loadFile(path.join(__dirname, 'shell', 'cover.html'));
}

function writeSessionFile() {
  fs.mkdirSync(path.dirname(SESSION_FILE), { recursive: true });
  fs.writeFileSync(SESSION_FILE, JSON.stringify({ port: stack.port, token: stack.token }), { mode: 0o600 });
}

function launchGame() {
  const binary = process.env.NEH_GAME ?? 'godot';
  const args = process.env.NEH_GAME ? [] : ['--path', path.join(__dirname, '..')];
  game = spawn(binary, args, { stdio: 'inherit' });
  game.on('error', (error) => console.error(`Cannot start game: ${error.message}`));
}

app.whenReady().then(async () => {
  Menu.setApplicationMenu(null);
  app.userAgentFallback = app.userAgentFallback.replace(/ (neh-hub|Electron)\/\S+/g, '');
  stack = await web.start({ onProfile: (id) => setProfile(id), searchWeb });
  writeSessionFile();
  console.log(`Ống kính điện thoại: ${stack.lensUrl}  (mã QR tại gaaglu.com/thiet-bi)`);
  routeFakeWeb(session.fromPartition('persist:fakeweb'));
  lockVisitSession();
  openBrowser();
  if (process.argv.includes('--game')) launchGame();
});

app.on('before-quit', () => {
  fs.rmSync(SESSION_FILE, { force: true });
  stack?.close();
  game?.kill();
});
