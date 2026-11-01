// Marker detection off the main thread, so a slow phone never stalls the camera picture.
importScripts('cv.js', 'aruco.js');
// The dictionary's default tolerance reads noise and mirrored markers as valid codes, which
// looks like success and hides an upside-down image. Only the game's own ids are accepted.
const detector = new AR.Detector({ dictionaryName: 'ARUCO_MIP_36h12', maxHammingDistance: 5 });
const GAME_MARKERS = 8;
const detect = (image) => detector.detect(image).filter(({ id }) => id < GAME_MARKERS);
let canvas = null;
let context = null;

// Raw camera pixels may arrive upside down; a marker only decodes the right way up.
function flip({ width, height, data }) {
  const out = new Uint8ClampedArray(data.length);
  const row = width * 4;
  for (let y = 0; y < height; y++) out.set(data.subarray((height - 1 - y) * row, (height - y) * row), y * row);
  return { width, height, data: out };
}

let upsideDown = false;

function detectPixels({ width, height, pixels }) {
  const started = performance.now();
  const image = { width, height, data: pixels };
  // Whichever way up worked last time is tried first.
  let found = detect(upsideDown ? flip(image) : image);
  if (!found.length) {
    const other = detect(upsideDown ? image : flip(image));
    if (other.length) {
      found = other;
      upsideDown = !upsideDown;
    }
  }
  postMessage({ width, ms: Math.round(performance.now() - started), found: found.map(({ id, corners }) => ({ id, corners })) });
}

onmessage = ({ data }) => {
  if (data.pixels) detectPixels(data);
  else detectBitmap(data);
};

function detectBitmap(bitmap) {
  if (!canvas || canvas.width !== bitmap.width || canvas.height !== bitmap.height) {
    canvas = new OffscreenCanvas(bitmap.width, bitmap.height);
    context = canvas.getContext('2d', { willReadFrequently: true });
  }
  context.drawImage(bitmap, 0, 0);
  const { width, height } = bitmap;
  bitmap.close();
  const started = performance.now();
  const found = detect(context.getImageData(0, 0, width, height));
  postMessage({ width, ms: Math.round(performance.now() - started), found: found.map(({ id, corners }) => ({ id, corners })) });
}
