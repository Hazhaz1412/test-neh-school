// Finds the game window in the camera picture and pins the other world onto exactly that plane.
const DETECT_WIDTH = 960;
const LOST_AFTER_MS = 400;
const MAX_ERROR_PX = 4;
const FOLLOW_MS = 45;

const video = document.getElementById('camera');
const world = document.getElementById('world');
const paint = world.getContext('2d');
const state = document.getElementById('state');
const hold = document.getElementById('hold');
const scanner = new Worker('scan.js');

let socket = null;
let layout = null;
let pictures = 0;
let lastSeen = 0;
let lastFrame = 0;
let target = null;
let shown = null;
let seen = 0;
let scanMs = 0;
let aiming = false;
let scanning = false;
let latestPicture = null;
const scan = { width: DETECT_WIDTH };

function connect() {
  socket = new WebSocket(location.href.replace(/^http/, 'ws'));
  socket.binaryType = 'blob';
  socket.onmessage = async (event) => {
    if (typeof event.data === 'string') {
      layout = JSON.parse(event.data);
      world.style.width = `${layout.width}px`;
      world.style.height = `${layout.height}px`;
      return;
    }
    const picture = await createImageBitmap(event.data);
    if (world.width !== picture.width || world.height !== picture.height) {
      world.width = picture.width;
      world.height = picture.height;
    }
    paint.drawImage(picture, 0, 0);
    latestPicture?.close();
    latestPicture = picture;
    pictures++;
  };
  socket.onclose = () => setTimeout(connect, 1000);
}

// Least squares for the 8 unknowns of a plane-to-plane mapping, normal equations by elimination.
function solveHomography(from, to) {
  const size = 8;
  const a = Array.from({ length: size }, () => new Float64Array(size + 1));
  const add = (row, value) => {
    for (let i = 0; i < size; i++) {
      for (let j = 0; j < size; j++) a[i][j] += row[i] * row[j];
      a[i][size] += row[i] * value;
    }
  };
  from.forEach(([x, y], index) => {
    const [u, v] = to[index];
    add([x, y, 1, 0, 0, 0, -x * u, -y * u], u);
    add([0, 0, 0, x, y, 1, -x * v, -y * v], v);
  });
  for (let pivot = 0; pivot < size; pivot++) {
    let best = pivot;
    for (let row = pivot + 1; row < size; row++) if (Math.abs(a[row][pivot]) > Math.abs(a[best][pivot])) best = row;
    [a[pivot], a[best]] = [a[best], a[pivot]];
    if (Math.abs(a[pivot][pivot]) < 1e-12) return null;
    for (let row = 0; row < size; row++) {
      if (row === pivot) continue;
      const factor = a[row][pivot] / a[pivot][pivot];
      for (let column = pivot; column <= size; column++) a[row][column] -= factor * a[pivot][column];
    }
  }
  return [...a.map((row, index) => row[size] / row[index]), 1];
}

const project = (h, [x, y]) => {
  const w = h[6] * x + h[7] * y + h[8];
  return [(h[0] * x + h[1] * y + h[2]) / w, (h[3] * x + h[4] * y + h[5]) / w];
};

function locateScreen(found) {
  const from = [];
  const to = [];
  for (const marker of found) {
    const spot = layout.markers.find((entry) => entry.id === marker.id);
    if (!spot) continue;
    const { x, y, size } = spot;
    [[x, y], [x + size, y], [x + size, y + size], [x, y + size]].forEach((corner, index) => {
      from.push(corner);
      to.push([marker.corners[index].x, marker.corners[index].y]);
    });
  }
  if (from.length < 4) return null;
  // Coordinates are scaled to about 1 so the elimination stays well conditioned.
  const norm = 1 / layout.width;
  const h = solveHomography(from.map(([x, y]) => [x * norm, y * norm]), to.map(([x, y]) => [x / scan.width, y / scan.width]));
  if (!h) return null;
  const error = from.reduce((sum, point, index) => {
    const [u, v] = project(h, [point[0] * norm, point[1] * norm]);
    return sum + Math.hypot(u * scan.width - to[index][0], v * scan.width - to[index][1]);
  }, 0) / from.length;
  return error > MAX_ERROR_PX ? null : { h, norm };
}

// Moves from game pixels through scan pixels to the covered video on screen.
function toDisplay({ h, norm }) {
  const cover = Math.max(innerWidth / video.videoWidth, innerHeight / video.videoHeight);
  const shiftX = (innerWidth - video.videoWidth * cover) / 2;
  const shiftY = (innerHeight - video.videoHeight * cover) / 2;
  const scale = video.videoWidth * cover;
  return [
    h[0] * norm * scale + h[6] * norm * shiftX, h[1] * norm * scale + h[7] * norm * shiftX, h[2] * scale + shiftX,
    h[3] * norm * scale + h[6] * norm * shiftY, h[4] * norm * scale + h[7] * norm * shiftY, h[5] * scale + shiftY,
    h[6] * norm, h[7] * norm, 1,
  ];
}

scanner.onmessage = ({ data }) => {
  scanning = false;
  scan.width = data.width;
  scanMs = data.ms;
  seen = data.found.length;
  const screen = locateScreen(data.found);
  if (screen) {
    target = toDisplay(screen);
    lastSeen = performance.now();
  }
};

async function requestScan() {
  if (scanning || !aiming || !layout || !video.videoWidth) return;
  scanning = true;
  const height = Math.round((DETECT_WIDTH * video.videoHeight) / video.videoWidth);
  const bitmap = await createImageBitmap(video, { resizeWidth: DETECT_WIDTH, resizeHeight: height });
  scanner.postMessage(bitmap, [bitmap]);
}

// Detections arrive a few times a second; the picture glides between them every display frame.
function tick(now) {
  requestAnimationFrame(tick);
  requestScan();
  const delta = now - lastFrame;
  lastFrame = now;
  if (!aiming || now - lastSeen > LOST_AFTER_MS) {
    world.style.opacity = 0;
    target = null;
    shown = null;
    return;
  }
  if (!target) return;
  const follow = 1 - Math.exp(-delta / FOLLOW_MS);
  shown = shown ? shown.map((value, index) => value + (target[index] - value) * follow) : target;
  const s = shown;
  world.style.transform = `matrix3d(${s[0]},${s[3]},0,${s[6]},${s[1]},${s[4]},0,${s[7]},0,0,1,0,${s[2]},${s[5]},0,${s[8]})`;
  world.style.opacity = 1;
}

function setAiming(on) {
  aiming = on;
  hold.classList.toggle('on', on);
  if (socket?.readyState === WebSocket.OPEN) socket.send(JSON.stringify({ aim: on }));
}

hold.addEventListener('pointerdown', (event) => {
  event.preventDefault();
  hold.setPointerCapture(event.pointerId);
  setAiming(true);
});
for (const name of ['pointerup', 'pointercancel']) hold.addEventListener(name, () => setAiming(false));
hold.addEventListener('contextmenu', (event) => event.preventDefault());

// Tells whether this phone can keep the screen anchored without markers.
let arSupport = 'đang kiểm tra AR';
let arReady = false;
let arError = '';
(navigator.xr ? navigator.xr.isSessionSupported('immersive-ar') : Promise.resolve(false))
  .then((supported) => { arReady = supported; arSupport = supported ? 'AR: CÓ' : 'AR: KHÔNG'; })
  .catch(() => { arSupport = 'AR: KHÔNG'; });

async function openFallback() {
  video.srcObject = await navigator.mediaDevices.getUserMedia({ audio: false, video: { facingMode: 'environment', width: { ideal: 1280 }, height: { ideal: 720 } } });
  hold.hidden = false;
  requestAnimationFrame(tick);
}

document.getElementById('start').addEventListener('click', async (event) => {
  if (!navigator.mediaDevices) {
    state.textContent = 'Trang phải mở bằng https mới dùng được camera';
    return;
  }
  const button = event.target;
  try {
    if (arReady) {
      document.getElementById('again').hidden = false;
      await openChannel();
    } else {
      await openFallback();
    }
    button.remove();
  } catch (error) {
    document.getElementById('again').hidden = true;
    arError = `${error.name}: ${error.message}`;
    try {
      await openFallback();
      button.remove();
    } catch (cameraError) {
      state.textContent = `Không mở được camera: ${cameraError.name}`;
    }
  }
});

setInterval(() => {
  const status = layout ? `${seen} dấu · ${pictures} hình/giây · dò ${scanMs} ms` : 'Đang chờ game…';
  state.textContent = `${status} · ${arError || arSupport}`;
  pictures = 0;
}, 1000);
connect();
