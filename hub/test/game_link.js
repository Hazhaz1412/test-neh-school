// Real Godot against the real web stack: node hub/test/game_link.js
const { spawn } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');
const web = require('../web/server');

const ROOT = path.join(__dirname, '..', '..');
const TEMP = fs.mkdtempSync(path.join(os.tmpdir(), 'neh-hub-'));
const SESSION = path.join(TEMP, 'hub.json');
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function waitFor(condition, seconds = 60) {
  for (let i = 0; i < seconds * 10; i++) {
    if (condition()) return true;
    await sleep(100);
  }
  return false;
}

function check(ok, description) {
  console.log(`${ok ? 'PASS' : 'FAIL'} / ${description}`);
  if (!ok) process.exitCode = 1;
}

(async () => {
  const stack = await web.start();
  fs.writeFileSync(SESSION, JSON.stringify({ port: stack.port, token: stack.token }));

  const godot = spawn('godot', ['--headless', '--path', ROOT, '--script', 'tools/validate_arg_bridge.gd'], {
    env: { ...process.env, NEH_HUB_SESSION: SESSION },
    stdio: ['ignore', 'pipe', 'inherit'],
  });
  godot.stdout.on('data', (data) => {
    for (const line of data.toString().split('\n')) if (/^(PASS|FAIL) \//.test(line)) console.log(line);
  });
  const exit = new Promise((resolve) => godot.on('exit', resolve));

  check(await waitFor(() => stack.story.game), 'stack sees the game connect');
  check(await waitFor(() => stack.story.evidence.includes('bear')), 'stack receives the bear pickup');
  check(stack.story.stage === 'ROOM_LURE', `stage name arrives (${stack.story.stage})`);

  check(stack.sendToGame({ type: 'door_bang' }), 'stack sends an event to the game');

  check((await exit) === 0, 'game validation exits cleanly');
  check(await waitFor(() => !stack.story.game, 5), 'stack notices the game leaving');
  stack.close();
  fs.rmSync(TEMP, { recursive: true, force: true });
})();
