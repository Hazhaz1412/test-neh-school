// Marker-free lens: one guided sweep locates the screen in the room, then ARCore keeps it there.
const CAMERA_SCAN_WIDTH = 960;
const CAMERA_SCAN_MS = 90;
const GOOD_FIT_M = 0.02;
const ACCEPTABLE_FIT_M = 0.05;
const SETTLE_MS = 5000;

const VERTEX = `#version 300 es
in vec3 place; in vec2 corner; out vec2 uv; uniform mat4 viewProjection;
void main() { uv = corner; gl_Position = viewProjection * vec4(place, 1.0); }`;
const FRAGMENT = `#version 300 es
precision mediump float; in vec2 uv; out vec4 color; uniform sampler2D picture;
void main() { color = vec4(texture(picture, uv).rgb, 1.0); }`;
const COPY_VERTEX = `#version 300 es
out vec2 uv; void main() { vec2 p = vec2(gl_VertexID & 1, gl_VertexID >> 1) * 2.0; uv = p; gl_Position = vec4(p * 2.0 - 1.0, 0.0, 1.0); }`;

function program(gl, vertex, fragment) {
  const made = gl.createProgram();
  for (const [type, source] of [[gl.VERTEX_SHADER, vertex], [gl.FRAGMENT_SHADER, fragment]]) {
    const shader = gl.createShader(type);
    gl.shaderSource(shader, source);
    gl.compileShader(shader);
    gl.attachShader(made, shader);
  }
  gl.linkProgram(made);
  return made;
}

function invert(m) {
  const r = new DOMMatrix(Array.from(m)).inverse();
  return r.toFloat32Array();
}

const transform = (m, [x, y, z, w]) => [0, 1, 2, 3].map((i) => m[i] * x + m[i + 4] * y + m[i + 8] * z + m[i + 12] * w);

function multiply(a, b) {
  const out = new Float32Array(16);
  for (let c = 0; c < 4; c++) for (let r = 0; r < 4; r++) for (let k = 0; k < 4; k++) out[c * 4 + r] += a[k * 4 + r] * b[c * 4 + k];
  return out;
}

async function openChannel() {
  const overlay = document.getElementById('overlay');
  const canvas = document.createElement('canvas');
  const gl = canvas.getContext('webgl2', { xrCompatible: true, alpha: true });
  const session = await navigator.xr.requestSession('immersive-ar', {
    requiredFeatures: ['local', 'camera-access'],
    optionalFeatures: ['dom-overlay'],
    domOverlay: { root: overlay },
  });
  session.updateRenderState({ baseLayer: new XRWebGLLayer(session, gl) });
  const binding = new XRWebGLBinding(session, gl);
  const space = await session.requestReferenceSpace('local');

  const showProgram = program(gl, VERTEX, FRAGMENT);
  const copyProgram = program(gl, COPY_VERTEX, FRAGMENT.replace('texture(picture, uv).rgb', 'texture(picture, uv).rgb'));
  const picture = gl.createTexture();
  gl.bindTexture(gl.TEXTURE_2D, picture);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
  const scanTexture = gl.createTexture();
  const scanFrame = gl.createFramebuffer();
  const places = gl.createBuffer();
  const uvs = gl.createBuffer();
  gl.bindBuffer(gl.ARRAY_BUFFER, uvs);
  gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([0, 0, 1, 0, 0, 1, 1, 1]), gl.STATIC_DRAW);

  let anchor = new ScreenAnchor();
  let quad = null;
  let busy = false;
  let lastScan = 0;
  let pending = null;
  let scanSize = null;
  let sentProgress = -1;

  let full = 0;
  const report = (text) => {
    arError = text;
    send({ report: text });
  };
  const send = (message) => { if (socket?.readyState === WebSocket.OPEN) socket.send(JSON.stringify(message)); };
  const beginSweep = () => {
    anchor = new ScreenAnchor();
    quad = null;
    full = 0;
    arError = '';
    aiming = false;
    sentProgress = -1;
    send({ calibrating: true, progress: 0, aim: false });
  };
  document.getElementById('again').addEventListener('click', beginSweep);
  session.addEventListener('end', () => send({ calibrating: false, aim: false }));
  beginSweep();

  scanner.onerror = (event) => report(`Lỗi dò: ${event.message}`);
  scanner.onmessage = ({ data }) => {
    busy = false;
    scanMs = data.ms;
    seen = data.found.length;
    if (!pending || quad) return;
    const { origin, toRoom, width, height } = pending;
    for (const { id, corners } of data.found) {
      corners.forEach(({ x, y }, index) => {
        const far = transform(toRoom, [(2 * x) / width - 1, 1 - (2 * y) / height, 1, 1]);
        anchor.add(id, index, origin, [0, 1, 2].map((i) => far[i] / far[3] - origin[i]));
      });
    }
    const progress = anchor.progress();
    if (Math.abs(progress - sentProgress) > 0.01) {
      sentProgress = progress;
      send({ calibrating: true, progress });
    }
    if (progress < 1 || !layout) {
      if (progress >= 1) report('Thiếu sơ đồ dấu từ game');
      return;
    }
    full = full || performance.now();
    const solved = anchor.solve(layout);
    const settled = performance.now() - full > SETTLE_MS;
    if (solved.corners && (solved.error <= GOOD_FIT_M || (settled && solved.error <= ACCEPTABLE_FIT_M))) {
      report(`Khớp ${solved.points}/${solved.seen} điểm, sai số ${(solved.error * 100).toFixed(1)} cm`);
      finishSweep(solved);
      return;
    }
    const why = solved.corners ? `sai số ${(solved.error * 100).toFixed(1)} cm` : solved.reason;
    report(settled ? `Không khớp: ${why}. Hiệu chỉnh lại, rà rộng hơn` : `Đang tinh chỉnh: ${why}`);
  };

  function finishSweep(solved) {
    quad = solved.corners;
    aiming = true;
    gl.bindBuffer(gl.ARRAY_BUFFER, places);
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([...quad[0], ...quad[1], ...quad[3], ...quad[2]]), gl.STATIC_DRAW);
    send({ calibrating: false, aim: true, anchored: true });
  }

  function scanCamera(view, time) {
    if (busy || !view.camera || time - lastScan < CAMERA_SCAN_MS) return;
    lastScan = time;
    busy = true;
    const width = CAMERA_SCAN_WIDTH;
    const height = Math.round((width * view.camera.height) / view.camera.width);
    if (!scanSize || scanSize[0] !== width || scanSize[1] !== height) {
      scanSize = [width, height];
      gl.bindTexture(gl.TEXTURE_2D, scanTexture);
      gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, width, height, 0, gl.RGBA, gl.UNSIGNED_BYTE, null);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    }
    gl.bindFramebuffer(gl.FRAMEBUFFER, scanFrame);
    gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, scanTexture, 0);
    gl.viewport(0, 0, width, height);
    gl.useProgram(copyProgram);
    gl.bindTexture(gl.TEXTURE_2D, binding.getCameraImage(view.camera));
    gl.drawArrays(gl.TRIANGLES, 0, 3);
    const pixels = new Uint8ClampedArray(width * height * 4);
    gl.readPixels(0, 0, width, height, gl.RGBA, gl.UNSIGNED_BYTE, pixels);
    pending = {
      width,
      height,
      origin: [view.transform.position.x, view.transform.position.y, view.transform.position.z],
      toRoom: multiply(view.transform.matrix, invert(view.projectionMatrix)),
    };
    scanner.postMessage({ width, height, pixels }, [pixels.buffer]);
  }

  function drawScreen(view) {
    gl.useProgram(showProgram);
    const stage = multiply(view.projectionMatrix, view.transform.inverse.matrix);
    gl.uniformMatrix4fv(gl.getUniformLocation(showProgram, 'viewProjection'), false, stage);
    gl.bindTexture(gl.TEXTURE_2D, picture);
    if (latestPicture) {
      gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, latestPicture);
      latestPicture.close();
      latestPicture = null;
    }
    const place = gl.getAttribLocation(showProgram, 'place');
    gl.bindBuffer(gl.ARRAY_BUFFER, places);
    gl.enableVertexAttribArray(place);
    gl.vertexAttribPointer(place, 3, gl.FLOAT, false, 0, 0);
    const corner = gl.getAttribLocation(showProgram, 'corner');
    gl.bindBuffer(gl.ARRAY_BUFFER, uvs);
    gl.enableVertexAttribArray(corner);
    gl.vertexAttribPointer(corner, 2, gl.FLOAT, false, 0, 0);
    gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
  }

  session.requestAnimationFrame(function onFrame(time, frame) {
    session.requestAnimationFrame(onFrame);
    const pose = frame.getViewerPose(space);
    if (!pose) return;
    const view = pose.views[0];
    if (!quad) scanCamera(view, time);
    const layer = session.renderState.baseLayer;
    gl.bindFramebuffer(gl.FRAMEBUFFER, layer.framebuffer);
    const box = layer.getViewport(view);
    gl.viewport(box.x, box.y, box.width, box.height);
    gl.clearColor(0, 0, 0, 0);
    gl.clear(gl.COLOR_BUFFER_BIT);
    if (quad) drawScreen(view);
  });
}
