// Places the game screen in room space from camera rays seen at many phone positions.
const MIN_RAYS_PER_CORNER = 8;
const MIN_POINTS = 8;
const OUTLIER_FACTOR = 2.5;
const TARGET_BASELINE_M = 0.22;
const TARGET_RAYS = 900;

const dot = (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];

function solve3(m, v) {
  const a = [[...m[0], v[0]], [...m[1], v[1]], [...m[2], v[2]]];
  for (let p = 0; p < 3; p++) {
    let best = p;
    for (let r = p + 1; r < 3; r++) if (Math.abs(a[r][p]) > Math.abs(a[best][p])) best = r;
    [a[p], a[best]] = [a[best], a[p]];
    if (Math.abs(a[p][p]) < 1e-9) return null;
    for (let r = 0; r < 3; r++) {
      if (r === p) continue;
      const f = a[r][p] / a[p][p];
      for (let c = p; c < 4; c++) a[r][c] -= f * a[p][c];
    }
  }
  return [a[0][3] / a[0][0], a[1][3] / a[1][1], a[2][3] / a[2][2]];
}

class ScreenAnchor {
  constructor() {
    this.corners = new Map();
    this.low = [Infinity, Infinity, Infinity];
    this.high = [-Infinity, -Infinity, -Infinity];
    this.rays = 0;
  }

  // Each ray narrows down where one marker corner is: least squares over all of them.
  add(id, corner, origin, direction) {
    const key = `${id}:${corner}`;
    if (!this.corners.has(key)) {
      this.corners.set(key, { id, corner, count: 0, a: [[0, 0, 0], [0, 0, 0], [0, 0, 0]], b: [0, 0, 0] });
    }
    const entry = this.corners.get(key);
    const size = Math.sqrt(dot(direction, direction));
    const d = direction.map((value) => value / size);
    for (let i = 0; i < 3; i++) {
      for (let j = 0; j < 3; j++) {
        const term = (i === j ? 1 : 0) - d[i] * d[j];
        entry.a[i][j] += term;
        entry.b[i] += term * origin[j];
      }
      this.low[i] = Math.min(this.low[i], origin[i]);
      this.high[i] = Math.max(this.high[i], origin[i]);
    }
    entry.count++;
    this.rays++;
  }

  progress() {
    const span = Math.hypot(this.high[0] - this.low[0], this.high[1] - this.low[1], this.high[2] - this.low[2]);
    if (!Number.isFinite(span)) return 0;
    return Math.min(1, span / TARGET_BASELINE_M, this.rays / TARGET_RAYS);
  }

  // A flat screen is an exact affine map from game pixels to room space.
  // Badly seen corners are dropped until the rest agree.
  solve(layout) {
    let points = [];
    for (const entry of this.corners.values()) {
      if (entry.count < MIN_RAYS_PER_CORNER) continue;
      const spot = layout.markers.find((marker) => marker.id === entry.id);
      const world = spot && solve3(entry.a, entry.b);
      if (!world) continue;
      const x = spot.x + (entry.corner === 1 || entry.corner === 2 ? spot.size : 0);
      const y = spot.y + (entry.corner >= 2 ? spot.size : 0);
      points.push({ x, y, world });
    }
    const seen = points.length;
    if (seen < MIN_POINTS) return { reason: `chỉ thấy ${seen} góc dấu`, seen };
    for (;;) {
      const fit = fitPlane(points);
      if (!fit) return { reason: 'các điểm không tạo thành mặt phẳng', seen };
      const misses = points.map((point) => Math.hypot(...fit.at(point.x, point.y).map((v, i) => v - point.world[i])));
      const sorted = [...misses].sort((p, q) => p - q);
      const limit = Math.max(sorted[sorted.length >> 1] * OUTLIER_FACTOR, 0.005);
      const kept = points.filter((_point, index) => misses[index] <= limit);
      if (kept.length === points.length || kept.length < MIN_POINTS) {
        const error = Math.sqrt(misses.reduce((sum, miss) => sum + miss * miss, 0) / misses.length);
        return { error, seen, points: points.length, corners: [fit.at(0, 0), fit.at(layout.width, 0), fit.at(layout.width, layout.height), fit.at(0, layout.height)] };
      }
      points = kept;
    }
  }
}

function fitPlane(points) {
  const m = [[0, 0, 0], [0, 0, 0], [0, 0, 0]];
  const rhs = [[0, 0, 0], [0, 0, 0], [0, 0, 0]];
  for (const { x, y, world } of points) {
    // Pixels are scaled so the elimination's near-zero test stays meaningful.
    const row = [x / 1000, y / 1000, 1];
    for (let i = 0; i < 3; i++) {
      for (let j = 0; j < 3; j++) m[i][j] += row[i] * row[j];
      for (let axis = 0; axis < 3; axis++) rhs[axis][i] += row[i] * world[axis];
    }
  }
  const fit = rhs.map((v) => solve3(m, v));
  if (fit.some((axis) => !axis)) return null;
  return { at: (x, y) => fit.map(([u, v, o]) => (u * x) / 1000 + (v * y) / 1000 + o) };
}

if (typeof module !== 'undefined') module.exports = { ScreenAnchor };
