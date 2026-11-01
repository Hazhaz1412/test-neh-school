'use strict';
// Puts the Gaaglu shortcut and the note on the player's desktop, only after they agreed in the
// game. Everything written is recorded, so removing it never touches anything else.
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { execFileSync } = require('node:child_process');

const CONFIG = path.join(os.homedir(), '.config', 'neh-school');
const MANIFEST = path.join(CONFIG, 'installed.json');
const NOTE_NAME = 'Ghi chú.txt';
const NOTE = 'Chỉ khi kết nối với thế giới bên kia, mới có thể tìm thấy sự thật.\n';

function desktopFolder() {
  if (process.env.NEH_DESKTOP_DIR) return process.env.NEH_DESKTOP_DIR;
  if (process.platform === 'linux') {
    try {
      const folder = execFileSync('xdg-user-dir', ['DESKTOP'], { encoding: 'utf8' }).trim();
      if (folder) return folder;
    } catch { /* falls back below */ }
  }
  return path.join(os.homedir(), 'Desktop');
}

function linuxEntry(launch, icon) {
  const quoted = launch.map((part) => `"${part}"`).join(' ');
  return `[Desktop Entry]\nType=Application\nName=Gaaglu\nComment=Tìm kiếm\nExec=${quoted}\nIcon=${icon}\nTerminal=false\n`;
}

function linuxShortcut(file, launch, icon) {
  fs.writeFileSync(file, linuxEntry(launch, icon), { mode: 0o755 });
  try {
    // GNOME shows untrusted launchers as plain files.
    execFileSync('gio', ['set', file, 'metadata::trusted', 'true'], { stdio: 'ignore' });
  } catch { /* other desktops do not need it */ }
}

// launch: command and arguments that open the browser. makeWindowsLink comes from Electron.
function install({ launch, icon, makeWindowsLink }) {
  const folder = desktopFolder();
  fs.mkdirSync(folder, { recursive: true });
  fs.mkdirSync(CONFIG, { recursive: true });
  const written = [];
  const iconCopy = path.join(CONFIG, 'gaaglu.png');
  fs.copyFileSync(icon, iconCopy);
  written.push(iconCopy);
  const note = path.join(folder, NOTE_NAME);
  if (!fs.existsSync(note)) {
    fs.writeFileSync(note, NOTE);
    written.push(note);
  }
  const shortcut = path.join(folder, process.platform === 'win32' ? 'Gaaglu.lnk' : 'Gaaglu.desktop');
  if (process.platform === 'win32') makeWindowsLink(shortcut);
  else linuxShortcut(shortcut, launch, iconCopy);
  written.push(shortcut);
  if (process.platform === 'linux') {
    // The applications grid, so Gaaglu can be found like any installed program.
    const menu = path.join(os.homedir(), '.local', 'share', 'applications');
    fs.mkdirSync(menu, { recursive: true });
    const entry = path.join(menu, 'gaaglu.desktop');
    fs.writeFileSync(entry, linuxEntry(launch, iconCopy));
    written.push(entry);
  }
  fs.writeFileSync(MANIFEST, JSON.stringify(written, null, 1));
  return written;
}

function remove() {
  if (!fs.existsSync(MANIFEST)) return [];
  const written = JSON.parse(fs.readFileSync(MANIFEST, 'utf8'));
  for (const file of written) fs.rmSync(file, { force: true });
  fs.rmSync(MANIFEST, { force: true });
  return written;
}

if (require.main === module && process.argv.includes('--remove')) {
  console.log(`Đã gỡ ${remove().length} tệp.`);
}

module.exports = { install, remove, desktopFolder, NOTE, NOTE_NAME };
