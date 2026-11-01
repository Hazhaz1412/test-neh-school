// Simulated phone sweep: node hub/test/anchor.js
const { ScreenAnchor } = require('../web/lens-anchor');

const check = (ok, text) => { console.log(`${ok ? 'PASS' : 'FAIL'} / ${text}`); if (!ok) process.exitCode = 1; };
const layout = { width: 1280, height: 720, markers: [0, 1, 2, 3, 4, 5, 6, 7].map((id) => ({ id, size: 112, x: 28 + (id % 3) * 500, y: 28 + (id % 4) * 170 })) };
// A 0.6 m wide monitor, tilted, about a metre in front of the sweep.
const place = (x, y) => {
  const s = 0.6 / 1280;
  return [x * s * 0.94 - 0.28, -y * s + 0.2, -1.0 + x * s * 0.34];
};
const noisy = (amount) => (Math.random() - 0.5) * amount;

function sweep(noise) {
  const anchor = new ScreenAnchor();
  for (let frame = 0; frame < 160; frame++) {
    const origin = [-0.14 + (frame / 160) * 0.28, Math.sin(frame / 20) * 0.03, Math.cos(frame / 30) * 0.02];
    for (const { id, x, y, size } of layout.markers) {
      [[x, y], [x + size, y], [x + size, y + size], [x, y + size]].forEach(([px, py], corner) => {
        const target = place(px, py);
        anchor.add(id, corner, origin, target.map((v, i) => v - origin[i] + noisy(noise)));
      });
    }
  }
  return anchor;
}

const clean = sweep(0);
const result = clean.solve(layout);
check(result && result.points === 32, 'every marker corner is located');
check(result.error < 0.001, `clean sweep fits the plane (${(result.error * 1000).toFixed(2)} mm)`);
check(Math.hypot(...result.corners[0].map((v, i) => v - place(0, 0)[i])) < 0.002, 'screen corner lands in the right place');
const rough = sweep(0.004).solve(layout);
const miss = Math.max(...[[0, 0], [1280, 0], [1280, 720], [0, 720]].map(([x, y], index) => Math.hypot(...rough.corners[index].map((v, i) => v - place(x, y)[i]))));
check(miss < 0.015, `camera noise stays under 15 mm at the corners (${(miss * 1000).toFixed(1)} mm)`);
const spoiled = sweep(0.002);
for (let i = 0; i < 40; i++) spoiled.add(3, 1, [0, 0, 0], [0.5, 0.4, -1]);
const kept = spoiled.solve(layout);
check(kept.error < 0.01 && kept.points < 32, `a badly seen corner is dropped (${kept.points} points, ${(kept.error * 1000).toFixed(1)} mm)`);
const few = new ScreenAnchor();
few.add(0, 0, [0, 0, 0], [0, 0, -1]);
check(typeof few.solve(layout).reason === 'string', 'too little data reports why instead of failing silently');
const still = new ScreenAnchor();
for (let i = 0; i < 2000; i++) still.add(0, 0, [0, 0, 0], [0.1, 0.1, -1]);
check(still.progress() === 0, 'holding the phone still earns no progress');
