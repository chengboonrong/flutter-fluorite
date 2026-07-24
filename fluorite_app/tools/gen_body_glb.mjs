// Generates a rounded-edge Nintendo Switch 2 body as a self-contained binary
// glTF (.glb) — no dependencies. Run with: node tools/gen_body_glb.mjs
//
// The mesh dimensions are baked in (width 9.4 · height 4.7 · depth 0.62,
// corner radius 0.42), so the GlbModel loads at scale (1,1,1) and every child
// entity parented to it keeps its authored local offset. A dark PBR material is
// embedded so no external material is needed.
//
// This is the same rounded-box construction used by the WebGL build in
// /web/index.html (6 face grids projected onto a rounded-box surface: flat
// faces, cylindrical edges, spherical corners — artifact free).

import { writeFileSync, mkdirSync } from 'node:fs';
import { dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const OUT = fileURLToPath(new URL('../assets/models/switch2_body.glb', import.meta.url));

// ---- rounded box -----------------------------------------------------------
function roundedBox(w, h, d, r, seg = 16) {
  const hx = w / 2, hy = h / 2, hz = d / 2;
  r = Math.min(r, hx, hy, hz);
  const core = [hx - r, hy - r, hz - r];
  const half = [hx, hy, hz];
  const clamp = (v, lo, hi) => (v < lo ? lo : v > hi ? hi : v);
  const norm = (a) => { const l = Math.hypot(a[0], a[1], a[2]) || 1; return [a[0] / l, a[1] / l, a[2] / l]; };
  const P = [], N = [], I = [];
  let base = 0;
  function face(a, s) {
    const b = (a + 1) % 3, c = (a + 2) % 3;
    for (let i = 0; i <= seg; i++) {
      for (let j = 0; j <= seg; j++) {
        const u = -half[b] + 2 * half[b] * i / seg;
        const v = -half[c] + 2 * half[c] * j / seg;
        const p = [0, 0, 0]; p[a] = s * half[a]; p[b] = u; p[c] = v;
        const q = [0, 0, 0]; q[a] = s * core[a]; q[b] = clamp(u, -core[b], core[b]); q[c] = clamp(v, -core[c], core[c]);
        const off = [p[0] - q[0], p[1] - q[1], p[2] - q[2]];
        const n = norm(off);
        P.push(q[0] + r * n[0], q[1] + r * n[1], q[2] + r * n[2]);
        N.push(n[0], n[1], n[2]);
      }
    }
    for (let i = 0; i < seg; i++) for (let j = 0; j < seg; j++) {
      const row = seg + 1, a0 = base + i * row + j, a1 = a0 + 1, a2 = a0 + row, a3 = a2 + 1;
      if (s > 0) I.push(a0, a2, a1, a1, a2, a3); else I.push(a0, a1, a2, a1, a3, a2);
    }
    base = P.length / 3;
  }
  for (let a = 0; a < 3; a++) { face(a, 1); face(a, -1); }
  return { position: P, normal: N, index: I };
}

// ---- pack into GLB ---------------------------------------------------------
const geo = roundedBox(9.4, 4.7, 0.62, 0.42, 18);
const pos = new Float32Array(geo.position);
const nrm = new Float32Array(geo.normal);
const idx = new Uint16Array(geo.index);

// min/max for the POSITION accessor (required by spec)
const min = [Infinity, Infinity, Infinity], max = [-Infinity, -Infinity, -Infinity];
for (let i = 0; i < pos.length; i += 3) for (let k = 0; k < 3; k++) {
  min[k] = Math.min(min[k], pos[i + k]); max[k] = Math.max(max[k], pos[i + k]);
}

const align4 = (n) => (n + 3) & ~3;
const posBytes = pos.byteLength;
const nrmBytes = nrm.byteLength;
const idxBytes = idx.byteLength;
const posOff = 0;
const nrmOff = posOff + posBytes;             // both float32 → 4-byte aligned
const idxOff = align4(nrmOff + nrmBytes);      // pad indices to 4-byte boundary
const binLen = align4(idxOff + idxBytes);

const bin = new Uint8Array(binLen);
bin.set(new Uint8Array(pos.buffer), posOff);
bin.set(new Uint8Array(nrm.buffer), nrmOff);
bin.set(new Uint8Array(idx.buffer), idxOff);

const gltf = {
  asset: { version: '2.0', generator: 'switch2 gen_body_glb.mjs' },
  scene: 0,
  scenes: [{ nodes: [0] }],
  nodes: [{ mesh: 0, name: 'switch2_body' }],
  meshes: [{
    name: 'switch2_body',
    primitives: [{ attributes: { POSITION: 0, NORMAL: 1 }, indices: 2, material: 0 }],
  }],
  materials: [{
    name: 'body_black',
    pbrMetallicRoughness: {
      baseColorFactor: [0.055, 0.06, 0.075, 1.0],
      metallicFactor: 0.15,
      roughnessFactor: 0.42,
    },
  }],
  buffers: [{ byteLength: binLen }],
  bufferViews: [
    { buffer: 0, byteOffset: posOff, byteLength: posBytes, target: 34962 }, // ARRAY_BUFFER
    { buffer: 0, byteOffset: nrmOff, byteLength: nrmBytes, target: 34962 },
    { buffer: 0, byteOffset: idxOff, byteLength: idxBytes, target: 34963 }, // ELEMENT_ARRAY_BUFFER
  ],
  accessors: [
    { bufferView: 0, componentType: 5126, count: pos.length / 3, type: 'VEC3', min, max }, // FLOAT
    { bufferView: 1, componentType: 5126, count: nrm.length / 3, type: 'VEC3' },
    { bufferView: 2, componentType: 5123, count: idx.length, type: 'SCALAR' },             // UNSIGNED_SHORT
  ],
};

// JSON chunk (padded with spaces to 4-byte)
let json = Buffer.from(JSON.stringify(gltf), 'utf8');
const jsonPad = align4(json.length) - json.length;
if (jsonPad) json = Buffer.concat([json, Buffer.from(' '.repeat(jsonPad))]);

const binBuf = Buffer.from(bin.buffer, bin.byteOffset, bin.byteLength);

const header = Buffer.alloc(12);
header.writeUInt32LE(0x46546c67, 0);                 // 'glTF'
header.writeUInt32LE(2, 4);                          // version
header.writeUInt32LE(12 + 8 + json.length + 8 + binBuf.length, 8); // total length

const jsonHeader = Buffer.alloc(8);
jsonHeader.writeUInt32LE(json.length, 0);
jsonHeader.writeUInt32LE(0x4e4f534a, 4);             // 'JSON'

const binHeader = Buffer.alloc(8);
binHeader.writeUInt32LE(binBuf.length, 0);
binHeader.writeUInt32LE(0x004e4942, 4);              // 'BIN\0'

const glb = Buffer.concat([header, jsonHeader, json, binHeader, binBuf]);

mkdirSync(dirname(OUT), { recursive: true });
writeFileSync(OUT, glb);
console.log(`wrote ${OUT}`);
console.log(`  vertices: ${pos.length / 3}, triangles: ${idx.length / 3}, bytes: ${glb.length}`);
