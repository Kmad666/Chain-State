// ============================================================== utilities
// Seeded random numbers, tileable noise, canvas helpers and geometry helpers.

function mulberry32(seed) {
  let a = seed >>> 0;
  return function () {
    a |= 0; a = (a + 0x6D2B79F5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
class Rng {
  constructor(seed) { this.r = mulberry32(seed); }
  next() { return this.r(); }
  range(a, b) { return a + (b - a) * this.r(); }
  int(a, b) { return Math.floor(this.range(a, b + 1)); }
  pick(arr) { return arr[Math.floor(this.r() * arr.length)]; }
  chance(p) { return this.r() < p; }
  gauss() { return (this.r() + this.r() + this.r() - 1.5) / 1.5; }
}

// Tileable value noise: lattice of `period` cells wraps around.
class TileNoise {
  constructor(seed, period) {
    this.p = period;
    const r = mulberry32(seed);
    this.v = new Float32Array(period * period);
    for (let i = 0; i < this.v.length; i++) this.v[i] = r();
  }
  at(x, y) {   // x, y in lattice units
    const p = this.p;
    const xi = Math.floor(x), yi = Math.floor(y);
    const xf = x - xi, yf = y - yi;
    const x0 = ((xi % p) + p) % p, y0 = ((yi % p) + p) % p;
    const x1 = (x0 + 1) % p, y1 = (y0 + 1) % p;
    const u = xf * xf * (3 - 2 * xf), w = yf * yf * (3 - 2 * yf);
    const a = this.v[y0 * p + x0], b = this.v[y0 * p + x1], c = this.v[y1 * p + x0], d = this.v[y1 * p + x1];
    return a + (b - a) * u + (c - a) * w + (a - b - c + d) * u * w;
  }
}
// fbm over [0,1)^2 tile coordinates, seamless
function makeFbm(seed, basePeriod, octaves, gain = 0.5) {
  const layers = [];
  for (let o = 0; o < octaves; o++) layers.push(new TileNoise(seed + o * 101, basePeriod << o));
  return (u, v) => {
    let s = 0, amp = 1, norm = 0;
    for (let o = 0; o < octaves; o++) {
      const n = layers[o];
      s += amp * n.at(u * n.p, v * n.p); norm += amp; amp *= gain;
    }
    return s / norm;
  };
}

function canvas(w, h) {
  const c = document.createElement("canvas");
  c.width = w; c.height = h;
  return c;
}
const clamp01 = x => x < 0 ? 0 : x > 1 ? 1 : x;
const lerp = (a, b, t) => a + (b - a) * t;
function hexRgb(hex) {
  const c = parseInt(hex.replace("#", ""), 16);
  return [(c >> 16) & 255, (c >> 8) & 255, c & 255];
}
function rgbHex(r, g, b) {
  return "#" + [r, g, b].map(v => Math.max(0, Math.min(255, Math.round(v))).toString(16).padStart(2, "0")).join("");
}
function mixHex(a, b, t) {
  const A = hexRgb(a), B = hexRgb(b);
  return rgbHex(lerp(A[0], B[0], t), lerp(A[1], B[1], t), lerp(A[2], B[2], t));
}

// Height canvas (grey, R channel) -> tangent-space normal map canvas.
function heightToNormal(src, strength) {
  const w = src.width, h = src.height;
  const sd = src.getContext("2d").getImageData(0, 0, w, h).data;
  const out = canvas(w, h), oc = out.getContext("2d");
  const od = oc.createImageData(w, h);
  const H = (x, y) => sd[(((y + h) % h) * w + ((x + w) % w)) * 4] / 255;
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const dx = (H(x + 1, y) - H(x - 1, y)) * strength;
    const dy = (H(x, y + 1) - H(x, y - 1)) * strength;
    let nx = -dx, ny = dy, nz = 1;
    const l = Math.hypot(nx, ny, nz); nx /= l; ny /= l; nz /= l;
    const i = (y * w + x) * 4;
    od.data[i] = (nx * 0.5 + 0.5) * 255; od.data[i + 1] = (ny * 0.5 + 0.5) * 255;
    od.data[i + 2] = (nz * 0.5 + 0.5) * 255; od.data[i + 3] = 255;
  }
  oc.putImageData(od, 0, 0);
  return out;
}

// Fill a canvas per pixel: fn(u, v, x, y) -> [r,g,b] (0..255) or [r,g,b,a]
function paint(c, fn) {
  const ctx = c.getContext("2d");
  const w = c.width, h = c.height;
  const d = ctx.createImageData(w, h);
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const p = fn(x / w, y / h, x, y);
    const i = (y * w + x) * 4;
    d.data[i] = p[0]; d.data[i + 1] = p[1]; d.data[i + 2] = p[2]; d.data[i + 3] = p.length > 3 ? p[3] : 255;
  }
  ctx.putImageData(d, 0, 0);
  return c;
}

// ------------------------------------------------------------ geometry
// toNonIndexed on an already non-indexed geometry: just return it (and skip the warning)
const _toNonIndexed = THREE.BufferGeometry.prototype.toNonIndexed;
THREE.BufferGeometry.prototype.toNonIndexed = function () { return this.index ? _toNonIndexed.call(this) : this; };
const _m4 = new THREE.Matrix4();
const _q = new THREE.Quaternion();
const _e = new THREE.Euler();
const _s = new THREE.Vector3();
const _p = new THREE.Vector3();

// Box from min corner / size, in local facade space (x along, y up, z out).
function boxGeo(x, y, z, w, h, d) {
  const g = new THREE.BoxGeometry(w, h, d);
  g.translate(x + w / 2, y + h / 2, z + d / 2);
  return g;
}

// Planar UVs in metres, chosen per face by the dominant normal axis (box projection).
function boxUV(geo, scale = 1, offset = [0, 0]) {
  const pos = geo.attributes.position, nor = geo.attributes.normal;
  if (!nor) geo.computeVertexNormals();
  const n = geo.attributes.normal;
  const uv = new Float32Array(pos.count * 2);
  const su = Array.isArray(scale) ? scale[0] : scale, sv = Array.isArray(scale) ? scale[1] : scale;
  for (let i = 0; i < pos.count; i++) {
    const x = pos.getX(i), y = pos.getY(i), z = pos.getZ(i);
    const ax = Math.abs(n.getX(i)), ay = Math.abs(n.getY(i)), az = Math.abs(n.getZ(i));
    let u, v;
    if (az >= ax && az >= ay) { u = x; v = y; }
    else if (ax >= ay) { u = z; v = y; }
    else { u = x; v = z; }
    uv[i * 2] = u / su + offset[0]; uv[i * 2 + 1] = v / sv + offset[1];
  }
  geo.setAttribute("uv", new THREE.BufferAttribute(uv, 2));
  return geo;
}

// Collects geometry per material key, merges at the end.
class Bucket {
  constructor() { this.parts = new Map(); }
  add(key, geo, matrix) {
    if (!geo) return;
    let g = geo.index ? geo.toNonIndexed() : geo;
    if (matrix) g.applyMatrix4(matrix);
    if (!g.attributes.uv) boxUV(g);
    for (const k of Object.keys(g.attributes)) if (k !== "position" && k !== "normal" && k !== "uv") g.deleteAttribute(k);
    if (!this.parts.has(key)) this.parts.set(key, []);
    this.parts.get(key).push(g);
  }
  merge() {
    const out = new Map();
    for (const [k, list] of this.parts) {
      const m = mergeGeometries(list, false);
      if (m) out.set(k, m);
    }
    return out;
  }
}

// A matrix placing facade-local coordinates into the world: origin, along-direction (unit, horizontal).
function facadeMatrix(origin, along) {
  const x = new THREE.Vector3(along.x, 0, along.z).normalize();
  const y = new THREE.Vector3(0, 1, 0);
  // right-handed: z = x × y is the outward normal. A facade facing +Z runs along +X
  // (left to right as seen by someone standing in the street looking at it).
  const z = new THREE.Vector3().crossVectors(x, y);
  const m = new THREE.Matrix4().makeBasis(x, y, z);
  m.setPosition(origin);
  return m;
}
