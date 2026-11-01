// Writes the ArUco bit patterns the game draws: node tools/build_lens_markers.js
const fs = require('fs');
const path = require('path');
const { AR } = require('../hub/node_modules/js-aruco2/src/aruco');

const COUNT = 8;
const dictionary = new AR.Dictionary('ARUCO_MIP_36h12');
const size = dictionary.markSize - 2;
const markers = [];
for (let id = 0; id < COUNT; id++) {
  markers.push({ id, bits: dictionary.codeList[id] });
}
fs.writeFileSync(path.join(__dirname, '..', 'assets', 'lens', 'markers.json'), JSON.stringify({ size, markers }));
