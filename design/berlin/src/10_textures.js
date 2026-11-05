// ============================================================== textures
// Every texture is painted in code, so the district needs no image files and
// the weathering can be shaped around each facade's own windows and ledges.

const TEX = {};          // name -> {map, normal, rough?, size:[w,h] metres per tile}

function toTex(c, srgb = true, repeat = true) {
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = srgb ? THREE.SRGBColorSpace : THREE.NoColorSpace;
  if (repeat) t.wrapS = t.wrapT = THREE.RepeatWrapping;
  t.anisotropy = 8;
  t.needsUpdate = true;
  return t;
}

function grain(seed) { return makeFbm(seed, 8, 6, 0.55); }

// ---- lime plaster (Kalkputz): fine sand grain, trowel cloudiness
function texPlaster() {
  const N = 512, f = grain(11), g = makeFbm(12, 64, 2, 0.5), cl = makeFbm(13, 3, 4, 0.5);
  const h = paint(canvas(N, N), (u, v) => {
    const k = 0.55 * f(u, v) + 0.45 * g(u, v);
    const s = 255 * clamp01(k);
    return [s, s, s];
  });
  const a = paint(canvas(N, N), (u, v) => {
    const k = 0.9 + 0.1 * (cl(u, v) - 0.5) * 2 + 0.06 * (g(u, v) - 0.5);
    const s = 240 * clamp01(k);
    return [s, s, s];
  });
  TEX.plaster = { map: toTex(a), normal: toTex(heightToNormal(h, 2.2), false), size: [2, 2] };
}

// ---- band rustication for ground floors (Bandrustika): horizontal joints every 0.4 m
function texRustic() {
  const N = 512, f = grain(21), cl = makeFbm(22, 4, 4, 0.5);
  const band = 0.2;                 // tile is 2 m, so 0.4 m = 0.2 of the tile
  const groove = (v) => {
    const t = (v % band) / band;     // 0..1 within a band
    const d = Math.min(t, 1 - t) * band * 2;   // metres-ish/2 to the joint
    return clamp01(d / 0.025);
  };
  const h = paint(canvas(N, N), (u, v) => {
    const s = 255 * (0.25 + 0.65 * groove(v) + 0.1 * f(u, v));
    return [s, s, s];
  });
  const a = paint(canvas(N, N), (u, v) => {
    const k = (0.78 + 0.22 * groove(v)) * (0.92 + 0.12 * (cl(u, v) - 0.5)) + 0.05 * (f(u, v) - 0.5);
    const s = 235 * clamp01(k);
    return [s, s, s];
  });
  TEX.rustic = { map: toTex(a), normal: toTex(heightToNormal(h, 3), false), size: [2, 2] };
}

// ---- sandstone / cast stone for ornament
function texStone() {
  const N = 256, f = grain(31), b = makeFbm(32, 2, 3, 0.5);
  const h = paint(canvas(N, N), (u, v) => { const s = 255 * f(u, v); return [s, s, s]; });
  const a = paint(canvas(N, N), (u, v) => {
    const k = 0.88 + 0.12 * (b(u, v) - 0.5) * 2 + 0.08 * (f(u, v) - 0.5);
    return [238 * k, 232 * k, 222 * k];
  });
  TEX.stone = { map: toTex(a), normal: toTex(heightToNormal(h, 1.5), false), size: [1, 1] };
}

// ---- brick, NF format 24 x 7.1 cm, 1 cm joints. Tile = 2 m x 1 m (8 bricks, 12 courses)
function texBrick(name, palette, seed) {
  const W = 512, H = 256, rng = new Rng(seed), f = grain(seed + 1);
  const cA = canvas(W, H), ca = cA.getContext("2d");
  const cH = canvas(W, H), ch = cH.getContext("2d");
  ca.fillStyle = "#9a948a"; ca.fillRect(0, 0, W, H);          // mortar
  ch.fillStyle = "#202020"; ch.fillRect(0, 0, W, H);
  const pxm = W / 2, course = 0.0833, brickL = 0.25, joint = 0.01;
  for (let r = 0; r < 12; r++) {
    const y = H - (r + 1) * course * pxm;
    const off = (r % 2) * brickL / 2;
    for (let k = -1; k < 9; k++) {
      const x = (k * brickL + off) * pxm;
      const col = hexRgb(rng.pick(palette));
      const t = rng.range(-18, 14);
      ca.fillStyle = `rgb(${col[0] + t},${col[1] + t},${col[2] + t})`;
      const bw = (brickL - joint) * pxm, bh = (course - joint) * pxm;
      ca.fillRect(x, y, bw, bh); ca.fillRect(x - W, y, bw, bh); ca.fillRect(x + W, y, bw, bh);
      const hv = rng.int(150, 210);
      ch.fillStyle = `rgb(${hv},${hv},${hv})`;
      ch.fillRect(x, y, bw, bh); ch.fillRect(x - W, y, bw, bh); ch.fillRect(x + W, y, bw, bh);
    }
  }
  // speckle and soot over the bricks
  const d = ca.getImageData(0, 0, W, H);
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const i = (y * W + x) * 4, n = 0.86 + 0.28 * f(x / W, y / H);
    d.data[i] *= n; d.data[i + 1] *= n; d.data[i + 2] *= n;
  }
  ca.putImageData(d, 0, 0);
  ch.filter = "blur(1px)"; ch.drawImage(cH, 0, 0); ch.filter = "none";
  TEX[name] = { map: toTex(cA), normal: toTex(heightToNormal(cH, 3.5), false), size: [2, 1] };
}

// ---- Silesian granite (salt and pepper) as a generic stone, for curbs and sockels
function graniteRGB(rng, base) {
  const r = rng.next();
  if (r < 0.12) return [40, 40, 44];                         // biotite
  if (r < 0.2) return [218, 214, 208];                       // quartz
  if (r < 0.27) return [178, 150, 140];                      // pink feldspar
  const t = base + rng.range(-14, 14);
  return [t, t, t + 3];
}
function texGranite() {
  const N = 256, rng = new Rng(41), f = makeFbm(42, 4, 3, 0.5);
  const a = paint(canvas(N, N), (u, v) => {
    const c = graniteRGB(rng, 150);
    const k = 0.9 + 0.2 * (f(u, v) - 0.5);
    return [c[0] * k, c[1] * k, c[2] * k];
  });
  const cH = canvas(N, N); const c2 = cH.getContext("2d"); c2.drawImage(a, 0, 0);
  TEX.granite = { map: toTex(a), normal: toTex(heightToNormal(cH, 0.6), false), size: [0.6, 0.6] };
}

// ---- the sidewalk's centre: two rows of 1 m Silesian granite slabs ("Schweinebauch"),
// lengths 1.2-2.2 m, joints offset between rows. Tile: 8 m along x 2 m across.
function texSlabs() {
  const W = 1024, H = 256, pxm = W / 8, rng = new Rng(51);
  const cA = canvas(W, H), ca = cA.getContext("2d");
  const cH = canvas(W, H), ch = cH.getContext("2d");
  ca.fillStyle = "#4e4b45"; ca.fillRect(0, 0, W, H);
  ch.fillStyle = "#000"; ch.fillRect(0, 0, W, H);
  const speck = canvas(256, 256);
  paint(speck, () => graniteRGB(rng, 152));
  const pat = ca.createPattern(speck, "repeat");
  for (let row = 0; row < 2; row++) {
    // lengths that sum to exactly 8 m so the tile repeats cleanly
    let lens = [], sum = 0;
    while (sum < 8 - 2.2) { const l = rng.range(1.2, 2.2); lens.push(l); sum += l; }
    lens.push(8 - sum);
    if (lens[lens.length - 1] < 0.9) { const x = lens.pop(); lens[lens.length - 1] += x; }
    let x = row * 0.6;
    for (const l of lens) {
      const tone = rng.range(-0.08, 0.08), worn = rng.range(0, 1);
      for (const dx of [0, -8, 8]) {
        const px = (x + dx) * pxm + 2, py = row * H / 2 + 2, pw = l * pxm - 4, ph = H / 2 - 4;
        ca.save(); ca.fillStyle = pat; ca.fillRect(px, py, pw, ph);
        ca.fillStyle = tone > 0 ? `rgba(255,250,240,${tone})` : `rgba(20,20,25,${-tone})`;
        ca.fillRect(px, py, pw, ph);
        // a polished, slightly darker wheel-worn band down the middle
        ca.fillStyle = `rgba(30,30,35,${0.05 + worn * 0.06})`; ca.fillRect(px, py + ph * 0.3, pw, ph * 0.4);
        ca.restore();
        const hv = 200 + rng.int(-20, 20);
        ch.fillStyle = `rgb(${hv},${hv},${hv})`; ch.fillRect(px, py, pw, ph);
      }
      x += l;
    }
  }
  // occasional crack and chewing gum spots
  for (let i = 0; i < 6; i++) {
    ca.strokeStyle = "rgba(30,28,25,0.6)"; ca.lineWidth = 1.2; ca.beginPath();
    let px = rng.range(0, W), py = rng.range(0, H); ca.moveTo(px, py);
    for (let k = 0; k < 6; k++) { px += rng.range(-14, 14); py += rng.range(-10, 10); ca.lineTo(px, py); }
    ca.stroke();
  }
  for (let i = 0; i < 40; i++) {
    ca.fillStyle = `rgba(${rng.int(40, 70)},${rng.int(40, 70)},${rng.int(40, 70)},0.55)`;
    ca.beginPath(); ca.arc(rng.range(0, W), rng.range(0, H), rng.range(1.2, 3), 0, 7); ca.fill();
  }
  ch.filter = "blur(1.5px)"; ch.drawImage(cH, 0, 0); ch.filter = "none";
  TEX.slabs = { map: toTex(cA), normal: toTex(heightToNormal(cH, 2.5), false), size: [8, 2] };
}

// ---- Bernburger mosaic strip: 4-6 cm limestone/granite cubes in sand. Outer rows run
// parallel to the edges, the middle at 45 degrees. Tile: 2 m along x stripWidth across.
function texMosaic(name, stripW, seed) {
  const pxm = 384, W = 2 * pxm, H = Math.round(stripW * pxm), rng = new Rng(seed);
  const cA = canvas(W, H), ca = cA.getContext("2d");
  const cH = canvas(W, H), ch = cH.getContext("2d");
  ca.fillStyle = "#857c6c"; ca.fillRect(0, 0, W, H);       // sand joints
  ch.fillStyle = "#000"; ch.fillRect(0, 0, W, H);
  const tones = ["#b9b6ae", "#a9a8a3", "#9c9fa3", "#c5c1b5", "#8d9196", "#b2aa9a", "#7e8388"];
  const stone = (cx, cy, s, ang) => {
    const col = rng.pick(tones), hv = rng.int(150, 230);
    const pts = [];
    for (let k = 0; k < 4; k++) {
      const a = ang + k * Math.PI / 2 + Math.PI / 4 + rng.range(-0.12, 0.12);
      const r = s * 0.62 * rng.range(0.82, 1.08);
      pts.push([cx + Math.cos(a) * r, cy + Math.sin(a) * r]);
    }
    for (const dx of [0, -W, W]) {
      ca.fillStyle = col; ch.fillStyle = `rgb(${hv},${hv},${hv})`;
      for (const c of [ca, ch]) {
        c.beginPath(); pts.forEach((p, i) => i ? c.lineTo(p[0] + dx, p[1]) : c.moveTo(p[0] + dx, p[1])); c.closePath(); c.fill();
      }
    }
  };
  const s = 0.05 * pxm, gap = 0.009 * pxm, step = s + gap;
  // two parallel rows at each edge
  const edgeRows = [step / 2 + 2, step * 1.5 + 2, H - step / 2 - 2, H - step * 1.5 - 2];
  for (const y of edgeRows) for (let x = step / 2; x < W; x += step * rng.range(0.96, 1.04)) stone(x, y + rng.range(-1, 1), s * rng.range(0.85, 1.1), 0);
  // diagonal field between
  const y0 = step * 2 + 3, y1 = H - step * 2 - 3;
  const d = step * 1.0;
  for (let i = -H; i < W + H; i += d / Math.SQRT2 * 1.0) {
    for (let j = 0; j < (W + H) * 2; j += d / Math.SQRT2 * 1.0) {
      // lattice rotated 45 degrees
      const x = (i + j) * Math.SQRT1_2, y = (j - i) * Math.SQRT1_2;
      if (x < -s || x > W + s || y < y0 + s * 0.4 || y > y1 - s * 0.4) continue;
      stone(x + rng.range(-1.2, 1.2), y + rng.range(-1.2, 1.2), s * rng.range(0.85, 1.08), Math.PI / 4);
    }
  }
  // grime: darker near the house wall and in a worn path, weeds in the joints
  const g = ca.createLinearGradient(0, 0, 0, H);
  g.addColorStop(0, "rgba(40,36,30,0.18)"); g.addColorStop(0.3, "rgba(40,36,30,0)"); g.addColorStop(1, "rgba(40,36,30,0.08)");
  ca.fillStyle = g; ca.fillRect(0, 0, W, H);
  for (let i = 0; i < 25; i++) {
    ca.fillStyle = `rgba(${rng.int(70, 95)},${rng.int(95, 120)},${rng.int(50, 65)},0.55)`;
    const x = rng.range(0, W), y = rng.range(0, H);
    for (let k = 0; k < 5; k++) { ca.beginPath(); ca.arc(x + rng.range(-6, 6), y + rng.range(-6, 6), rng.range(1, 2.4), 0, 7); ca.fill(); }
  }
  ch.filter = "blur(2px)"; ch.drawImage(cH, 0, 0); ch.filter = "none";
  TEX[name] = { map: toTex(cA), normal: toTex(heightToNormal(cH, 3.5), false), size: [2, stripW] };
}

// ---- carriageway setts (Großpflaster): granite setts ~16 cm in rows across the street.
// Tile: 3 m along the street (x) by 3 m across (y); rows run across the street.
function texSetts() {
  const pxm = 340, W = 3 * pxm, H = 3 * pxm, rng = new Rng(61);
  const cA = canvas(W, H), ca = cA.getContext("2d");
  const cH = canvas(W, H), ch = cH.getContext("2d");
  ca.fillStyle = "#3d3a35"; ca.fillRect(0, 0, W, H);
  ch.fillStyle = "#000"; ch.fillRect(0, 0, W, H);
  const tones = ["#7d7b78", "#6f6c69", "#86817a", "#5f6164", "#8b8277", "#74706a", "#6a6e72", "#8f8a84", "#7a6e66"];
  // rows across the street: widths that sum to 3 m
  let rows = [], sum = 0;
  while (sum < 3 - 0.2) { const w = rng.range(0.14, 0.18); rows.push(w); sum += w; }
  const k = 3 / sum; rows = rows.map(w => w * k);
  let x = 0;
  for (const rw of rows) {
    let lens = [], s2 = 0;
    while (s2 < 3 - 0.24) { const l = rng.range(0.15, 0.24); lens.push(l); s2 += l; }
    const kk = 3 / s2; lens = lens.map(l => l * kk);
    let y = rng.range(0, 0.2);
    for (const l of lens) {
      const col = hexRgb(rng.pick(tones)), t = rng.range(-10, 10);
      const jx = 0.012 * pxm, jy = 0.012 * pxm;
      const px = x * pxm + jx, pw = rw * pxm - 2 * jx, ph = l * pxm - 2 * jy;
      for (const dy of [0, -H, H]) {
        const py = y * pxm + jy + dy;
        // rounded rectangle stone with a lighter worn crown
        ca.fillStyle = `rgb(${col[0] + t},${col[1] + t},${col[2] + t})`;
        roundRect(ca, px, py, pw, ph, 6); ca.fill();
        const gr = ca.createRadialGradient(px + pw / 2, py + ph / 2, 2, px + pw / 2, py + ph / 2, Math.max(pw, ph) * 0.6);
        gr.addColorStop(0, "rgba(255,255,255,0.10)"); gr.addColorStop(1, "rgba(0,0,0,0.12)");
        ca.fillStyle = gr; roundRect(ca, px, py, pw, ph, 6); ca.fill();
        const hv = rng.int(170, 235);
        ch.fillStyle = `rgb(${hv},${hv},${hv})`; roundRect(ch, px, py, pw, ph, 8); ch.fill();
      }
      y += l;
    }
    x += rw;
  }
  // granite speckle over everything
  const d = ca.getImageData(0, 0, W, H);
  for (let i = 0; i < d.data.length; i += 4) {
    const r = rng.next();
    const m = r < 0.06 ? 0.6 : r < 0.1 ? 1.25 : 1 + rng.range(-0.05, 0.05);
    d.data[i] *= m; d.data[i + 1] *= m; d.data[i + 2] *= m;
  }
  ca.putImageData(d, 0, 0);
  ch.filter = "blur(4px)"; ch.drawImage(cH, 0, 0); ch.filter = "none";
  TEX.setts = { map: toTex(cA), normal: toTex(heightToNormal(cH, 5), false), size: [3, 3] };
}
function roundRect(c, x, y, w, h, r) {
  c.beginPath(); c.moveTo(x + r, y); c.lineTo(x + w - r, y); c.quadraticCurveTo(x + w, y, x + w, y + r);
  c.lineTo(x + w, y + h - r); c.quadraticCurveTo(x + w, y + h, x + w - r, y + h); c.lineTo(x + r, y + h);
  c.quadraticCurveTo(x, y + h, x, y + h - r); c.lineTo(x, y + r); c.quadraticCurveTo(x, y, x + r, y); c.closePath();
}

// ---- asphalt with aggregate, patches and cracks. Tile 6 m.
function texAsphalt() {
  const N = 1024, rng = new Rng(71), f = makeFbm(72, 6, 5, 0.55), b = makeFbm(73, 2, 3, 0.5);
  const a = paint(canvas(N, N), (u, v) => {
    const r = rng.next();
    let s = 104 + 26 * (f(u, v) - 0.5) + 16 * (b(u, v) - 0.5);
    if (r < 0.05) s += 34; else if (r < 0.1) s -= 22;
    return [s, s, s + 2];
  });
  const ca = a.getContext("2d");
  // a few repair patches with sharp edges, darker and smoother
  for (let i = 0; i < 3; i++) {
    const x = rng.range(0, N), y = rng.range(0, N), w = rng.range(60, 220), h = rng.range(40, 160);
    ca.fillStyle = "rgba(25,25,27,0.45)"; ca.fillRect(x, y, w, h);
    ca.strokeStyle = "rgba(15,15,15,0.6)"; ca.lineWidth = 2; ca.strokeRect(x, y, w, h);
  }
  // cracks
  ca.strokeStyle = "rgba(18,18,18,0.75)";
  for (let i = 0; i < 10; i++) {
    ca.lineWidth = rng.range(0.8, 2); ca.beginPath();
    let x = rng.range(0, N), y = rng.range(0, N); ca.moveTo(x, y);
    for (let k = 0; k < 14; k++) { x += rng.range(-20, 20); y += rng.range(-20, 20); ca.lineTo(x, y); }
    ca.stroke();
  }
  // oil drips
  for (let i = 0; i < 8; i++) {
    const g = ca.createRadialGradient(0, 0, 0, 0, 0, 1);
    const x = rng.range(0, N), y = rng.range(0, N), r = rng.range(10, 30);
    ca.fillStyle = `rgba(10,10,12,${rng.range(0.15, 0.3)})`; ca.beginPath(); ca.ellipse(x, y, r, r * 0.6, rng.range(0, 3), 0, 7); ca.fill();
  }
  const h = paint(canvas(512, 512), (u, v) => { const s = 255 * f(u * 4 % 1, v * 4 % 1); return [s, s, s]; });
  TEX.asphalt = { map: toTex(a), normal: toTex(heightToNormal(h, 1.2), false), size: [6, 6] };
}

// ---- roof covers
function texTiles() {   // Biberschwanz plain tiles, crown laying. Tile 2 m x 2 m
  const N = 512, pxm = N / 2, rng = new Rng(81);
  const cA = canvas(N, N), ca = cA.getContext("2d");
  const cH = canvas(N, N), ch = cH.getContext("2d");
  ca.fillStyle = "#3b2119"; ca.fillRect(0, 0, N, N); ch.fillStyle = "#000"; ch.fillRect(0, 0, N, N);
  const rowH = 0.145 * pxm, tw = 0.18 * pxm;
  const tones = ["#9a4a31", "#8a4029", "#a65638", "#7d3a28", "#94503a", "#6f3a2c"];
  for (let r = 0; r < Math.ceil(N / rowH) + 1; r++) {
    const y = r * rowH, off = (r % 2) * tw / 2;
    for (let x = -tw + off; x < N + tw; x += tw) {
      const col = rng.pick(tones);
      for (const c of [ca, ch]) {
        c.fillStyle = c === ca ? col : `rgb(${rng.int(140, 200)},0,0)`;
        c.beginPath(); c.moveTo(x + 1, y - rowH * 1.5); c.lineTo(x + tw - 1, y - rowH * 1.5);
        c.lineTo(x + tw - 1, y + rowH * 0.55); c.ellipse(x + tw / 2, y + rowH * 0.55, tw / 2 - 1, rowH * 0.45, 0, 0, Math.PI);
        c.closePath(); c.fill();
      }
      if (rng.chance(0.18)) { ca.fillStyle = "rgba(70,80,40,0.45)"; ca.beginPath(); ca.arc(x + tw * rng.next(), y, rng.range(2, 6), 0, 7); ca.fill(); }
      if (rng.chance(0.3)) { ca.fillStyle = "rgba(20,15,12,0.25)"; ca.fillRect(x, y - rowH, tw, rowH * 1.5); }
    }
  }
  // the tile rows overlap: shade the bottom edge of each row
  TEX.tiles = { map: toTex(cA), normal: toTex(heightToNormal(cH, 2.5), false), size: [2, 2] };
}
function texSlate() {   // slate scales / zinc. Tile 2 m
  const N = 512, pxm = N / 2, rng = new Rng(91);
  const cA = canvas(N, N), ca = cA.getContext("2d");
  const cH = canvas(N, N), ch = cH.getContext("2d");
  ca.fillStyle = "#1e2124"; ca.fillRect(0, 0, N, N); ch.fillStyle = "#000"; ch.fillRect(0, 0, N, N);
  const rowH = 0.12 * pxm, tw = 0.2 * pxm;
  for (let r = 0; r < N / rowH + 1; r++) {
    const off = (r % 2) * tw / 2;
    for (let x = -tw + off; x < N + tw; x += tw) {
      const t = rng.int(52, 78);
      ca.fillStyle = `rgb(${t},${t + 3},${t + 7})`; ca.fillRect(x + 1, r * rowH + 1, tw - 2, rowH - 1);
      ch.fillStyle = `rgb(${rng.int(150, 200)},0,0)`; ch.fillRect(x + 1, r * rowH + 1, tw - 2, rowH - 1);
    }
  }
  TEX.slate = { map: toTex(cA), normal: toTex(heightToNormal(cH, 2), false), size: [2, 2] };
}
function texZinc() {   // standing-seam zinc, seams every 0.5 m. Tile 2 m
  const N = 256, f = makeFbm(95, 3, 4, 0.5);
  const a = paint(canvas(N, N), (u, v) => {
    const s = 120 + 30 * (f(u, v) - 0.5) + (Math.abs((u * 4) % 1 - 0.5) > 0.47 ? 25 : 0);
    return [s * 0.92, s * 0.96, s];
  });
  const h = paint(canvas(N, N), (u) => { const s = Math.abs((u * 4) % 1 - 0.5) > 0.47 ? 255 : 40; return [s, s, s]; });
  TEX.zinc = { map: toTex(a), normal: toTex(heightToNormal(h, 2), false), size: [2, 2] };
}
function texCopper() {   // weathered copper: verdigris with dark run-offs. Tile 2 m
  const N = 256, f = makeFbm(97, 4, 5, 0.55), s = makeFbm(98, 16, 2, 0.5);
  const a = paint(canvas(N, N), (u, v) => {
    const k = f(u, v), st = s(u * 0.2, v);
    const base = [96, 152, 128], dark = [58, 82, 70];
    const t = clamp01((k - 0.35) * 1.8) * 0.6 + clamp01(st - 0.55) * 0.8;
    return [lerp(base[0], dark[0], t), lerp(base[1], dark[1], t), lerp(base[2], dark[2], t)];
  });
  TEX.copper = { map: toTex(a), normal: TEX.zinc.normal, size: [2, 2] };
}

// ---- cast-iron balcony railing, alpha-tested. Tile 2 m wide, 1 m tall.
function texRailing(name, seed, style) {
  const W = 512, H = 256, pxm = W / 2, rng = new Rng(seed);
  const c = canvas(W, H), x = c.getContext("2d");
  x.clearRect(0, 0, W, H);
  x.strokeStyle = "#151515"; x.fillStyle = "#151515"; x.lineCap = "round";
  const bar = (x0, y0, x1, y1, w) => { x.lineWidth = w; x.beginPath(); x.moveTo(x0, y0); x.lineTo(x1, y1); x.stroke(); };
  bar(0, 6, W, 6, 9); bar(0, H - 8, W, H - 8, 7); bar(0, H * 0.22, W, H * 0.22, 4); bar(0, H * 0.8, W, H * 0.8, 4);
  const pitch = 0.12 * pxm;
  for (let i = 0; i <= W / pitch; i++) {
    const px = i * pitch;
    bar(px, 10, px, H - 10, 6);
    // a small spear head / collar on every bar
    x.beginPath(); x.arc(px, H * 0.5, 5, 0, 7); x.fill();
  }
  if (style === "scroll") {
    // frieze of C-scrolls between the top rails, and circles at the bottom band
    x.lineWidth = 3.5;
    for (let i = 0; i < W / pitch; i++) {
      const cx = (i + 0.5) * pitch, cy = H * 0.12;
      x.beginPath(); x.arc(cx - 8, cy, 9, Math.PI * 0.2, Math.PI * 1.8); x.stroke();
      x.beginPath(); x.arc(cx + 8, cy, 9, Math.PI * 1.2, Math.PI * 0.8); x.stroke();
      x.beginPath(); x.arc(cx, H * 0.89, 9, 0, 7); x.stroke();
    }
    // central medallion every 1 m
    for (const m of [0.5, 1.5]) {
      const cx = m * pxm, cy = H * 0.52;
      x.lineWidth = 4; x.beginPath(); x.ellipse(cx, cy, 34, 50, 0, 0, 7); x.stroke();
      x.lineWidth = 3; for (let k = 0; k < 4; k++) { x.beginPath(); x.arc(cx, cy + (k - 1.5) * 22, 12, 0, 7); x.stroke(); }
    }
  } else {
    // Jugendstil: flowing S-curves
    x.lineWidth = 3.5;
    for (let i = 0; i < 4; i++) {
      const cx = (i + 0.5) * W / 4;
      x.beginPath(); x.moveTo(cx - 40, H * 0.78);
      x.bezierCurveTo(cx - 40, H * 0.3, cx + 40, H * 0.7, cx + 40, H * 0.24); x.stroke();
      x.beginPath(); x.moveTo(cx + 40, H * 0.78);
      x.bezierCurveTo(cx + 40, H * 0.3, cx - 40, H * 0.7, cx - 40, H * 0.24); x.stroke();
    }
  }
  const t = toTex(c, true);
  TEX[name] = { map: t, size: [2, 1] };
}

// ---- net curtains (Gardinen), half transparent with folds
function texCurtain() {
  const W = 128, H = 256;
  const c = paint(canvas(W, H), (u, v) => {
    const fold = 0.5 + 0.5 * Math.sin(u * Math.PI * 14 + Math.sin(v * 6) * 0.6);
    const s = 205 + 40 * fold;
    const a = 150 + 70 * fold;
    return [s, s * 0.98, s * 0.94, a];
  });
  TEX.curtain = { map: toTex(c, true, false), size: [1, 1] };
}

// ---- signs and posters: text drawn onto canvases
function signTexture(text, opts = {}) {
  const W = opts.w || 1024, H = opts.h || 128;
  const c = canvas(W, H), x = c.getContext("2d");
  x.fillStyle = opts.bg || "#1d2b24"; x.fillRect(0, 0, W, H);
  if (opts.border) { x.strokeStyle = opts.border; x.lineWidth = 6; x.strokeRect(8, 8, W - 16, H - 16); }
  x.fillStyle = opts.fg || "#e9d8a6";
  x.font = `${opts.weight || 600} ${opts.size || 74}px ${opts.font || "Georgia, 'Times New Roman', serif"}`;
  x.textAlign = "center"; x.textBaseline = "middle";
  if (opts.spacing) x.letterSpacing = opts.spacing + "px";
  x.fillText(text, W / 2, H / 2 + 4);
  return toTex(c, true, false);
}

function posterTexture(seed) {
  const W = 1024, H = 512, rng = new Rng(seed);
  const c = canvas(W, H), x = c.getContext("2d");
  x.fillStyle = "#d8d2c4"; x.fillRect(0, 0, W, H);
  const titles = ["KONZERT", "KABARETT", "AUSSTELLUNG", "THEATER", "TANZ", "LESUNG", "FLOHMARKT", "VARIETÉ", "ZIRKUS", "KINO", "OPER", "JAZZ"];
  const cols = ["#c0392b", "#1f3a68", "#e2b33c", "#2e6b4f", "#111111", "#e86f2c", "#6b2d5c", "#f2efe6", "#2b8aa3"];
  let px = 0;
  while (px < W) {
    const w = rng.range(130, 260), bg = rng.pick(cols);
    x.fillStyle = bg; x.fillRect(px, 0, w - 4, H);
    x.save(); x.beginPath(); x.rect(px, 0, w - 4, H); x.clip();
    const fg = bg === "#f2efe6" || bg === "#e2b33c" ? "#141414" : "#f4efe2";
    x.fillStyle = fg; x.textAlign = "center";
    x.font = `800 ${rng.int(34, 56)}px Impact, 'Arial Narrow', sans-serif`;
    x.fillText(rng.pick(titles), px + w / 2, rng.range(70, 140));
    x.font = `500 22px Arial, sans-serif`;
    for (let k = 0; k < 5; k++) x.fillRect(px + 16, 200 + k * 26 + rng.range(0, 6), (w - 40) * rng.range(0.4, 0.95), 7);
    x.fillStyle = rng.pick(cols); x.beginPath(); x.arc(px + w / 2, 390, rng.range(30, 60), 0, 7); x.fill();
    x.restore();
    // torn and weathered edges
    x.fillStyle = "rgba(240,235,220,0.5)";
    for (let k = 0; k < 6; k++) x.fillRect(px + rng.range(0, w), rng.range(0, H), rng.range(8, 30), rng.range(3, 12));
    px += w;
  }
  x.fillStyle = "rgba(60,50,40,0.12)"; x.fillRect(0, 0, W, H);
  return toTex(c, true, false);
}

// ---- the weathering of one facade: RGB multiplies the colour (soot, run-off streaks,
// rising damp, blotches); A marks intact plaster (0 = the plaster has fallen off and
// the brick shows). Painted in facade metres: x along, y up from the pavement.
function grimeTexture(spec, rng) {
  const { width, height, windows, ledges, cond } = spec;
  const PX = 16;                              // pixels per metre
  const W = Math.max(64, Math.ceil(width * PX)), H = Math.max(64, Math.ceil(height * PX));
  const c = canvas(W, H), x = c.getContext("2d");
  const X = m => m * PX, Y = m => H - m * PX;
  x.fillStyle = "#ffffff"; x.fillRect(0, 0, W, H);
  x.globalCompositeOperation = "multiply";
  const f = makeFbm(rng.int(1, 9999), 4, 4, 0.55);
  // blotchy dirt over the whole wall, heavier on unrenovated houses
  const blot = paint(canvas(W, H), (u, v) => {
    const k = 1 - (0.10 + 0.32 * cond) * clamp01((f(u * width / 12 % 1, v * height / 12 % 1) - 0.35) * 2.2);
    const s = 255 * k;
    return [s, s * 0.99, s * 0.97];
  });
  x.drawImage(blot, 0, 0);
  // soot under the main cornice and down from the top
  let g = x.createLinearGradient(0, 0, 0, H * 0.45);
  g.addColorStop(0, `rgba(${110 - cond * 40},${105 - cond * 40},${100 - cond * 40},1)`);
  g.addColorStop(1, "rgba(255,255,255,1)");
  x.fillStyle = g; x.fillRect(0, 0, W, H * 0.45);
  // rising damp: a darker band with a ragged top
  const damp = rng.range(0.5, 1.0) + cond * 0.5;
  x.fillStyle = `rgb(${190 - cond * 50},${188 - cond * 45},${175 - cond * 45})`;
  x.beginPath(); x.moveTo(0, H);
  for (let m = 0; m <= width; m += 0.3) x.lineTo(X(m), Y(damp + Math.sin(m * 2.1) * 0.12 + rng.range(-0.1, 0.1)));
  x.lineTo(W, H); x.closePath(); x.fill();
  // run-off streaks from each window sill's ends and from the ledges
  const streak = (sx, sy, len, wid, a) => {
    const gg = x.createLinearGradient(0, Y(sy), 0, Y(sy - len));
    gg.addColorStop(0, `rgba(${80},${76},${70},${a})`); gg.addColorStop(1, "rgba(255,255,255,0)");
    x.fillStyle = gg;
    x.beginPath();
    x.moveTo(X(sx - wid / 2), Y(sy)); x.lineTo(X(sx + wid / 2), Y(sy));
    x.lineTo(X(sx + wid * 0.3 + rng.range(-0.05, 0.05)), Y(sy - len)); x.lineTo(X(sx - wid * 0.3), Y(sy - len));
    x.closePath(); x.fill();
  };
  const sa = 0.35 + cond * 0.45;
  for (const w of windows) {
    streak(w.x + 0.1, w.y, rng.range(0.8, 2.6), 0.22, sa * rng.range(0.4, 1));
    streak(w.x + w.w - 0.1, w.y, rng.range(0.8, 2.6), 0.22, sa * rng.range(0.4, 1));
    if (rng.chance(0.5)) streak(w.x + w.w / 2, w.y, rng.range(0.4, 1.5), w.w * 0.8, sa * 0.35);
  }
  for (const ly of ledges) {
    for (let m = rng.range(0, 1.5); m < width; m += rng.range(0.8, 2.6)) streak(m, ly, rng.range(0.6, 2.2), rng.range(0.15, 0.5), sa * rng.range(0.3, 0.8));
  }
  x.globalCompositeOperation = "source-over";
  // patches of fallen plaster on houses that were never renovated (mask 0 shows brick).
  // Canvas pixels are stored premultiplied, so the mask goes into a raw RGBA array instead.
  const d = x.getImageData(0, 0, W, H);
  const out = new Uint8Array(W * H * 4);
  for (let i = 0; i < W * H; i++) { out[i * 4] = d.data[i * 4]; out[i * 4 + 1] = d.data[i * 4 + 1]; out[i * 4 + 2] = d.data[i * 4 + 2]; out[i * 4 + 3] = 255; }
  if (cond > 0.55) {
    const nP = Math.round((cond - 0.5) * width * 0.9);
    const patches = [];
    for (let i = 0; i < nP; i++) {
      patches.push({ x: rng.range(0.5, width - 0.5), y: rng.range(0.6, height * 0.92), r: rng.range(0.35, 1.3), e: rng.range(0.5, 1.6) });
    }
    const pf = makeFbm(rng.int(1, 9999), 8, 3, 0.5);
    for (let py = 0; py < H; py++) for (let px = 0; px < W; px++) {
      const mx = px / PX, my = (H - py) / PX;
      let k = 1;
      for (const p of patches) {
        const dx = (mx - p.x) / p.r, dy = (my - p.y) / (p.r * p.e);
        const dd = Math.hypot(dx, dy) + (pf(px / W, py / H) - 0.5) * 0.9;
        if (dd < 1) k = Math.min(k, clamp01((dd - 0.82) * 8));
      }
      out[(py * W + px) * 4 + 3] = 255 * k;
    }
  }
  // DataTexture rows run bottom-up, canvas rows top-down: flip
  const flipped = new Uint8Array(W * H * 4);
  for (let row = 0; row < H; row++) flipped.set(out.subarray(row * W * 4, (row + 1) * W * 4), (H - 1 - row) * W * 4);
  const t = new THREE.DataTexture(flipped, W, H, THREE.RGBAFormat);
  t.colorSpace = THREE.NoColorSpace;
  t.magFilter = THREE.LinearFilter; t.minFilter = THREE.LinearMipmapLinearFilter; t.generateMipmaps = true;
  t.wrapS = t.wrapT = THREE.ClampToEdgeWrapping;
  t.needsUpdate = true;
  return t;
}

// spray-painted tags for ground floors and hoardings (alpha cut-outs)
function tagTexture(seed) {
  const rng = new Rng(seed), W = 512, H = 256;
  const c = canvas(W, H), x = c.getContext("2d");
  const words = ["ZORA", "KIEZ", "MOKA", "BLN", "OSKI", "NEON", "RUBY", "KETTE", "SIX", "LUPO"];
  const word = rng.pick(words);
  const cols = [["#151515", "#e9e6e0"], ["#e8e8ea", "#151515"], ["#d64f8c", "#151515"], ["#2a64c8", "#f0f0f0"], ["#151515", "#d9b13b"], ["#9a9da2", "#111"]];
  const [fill, edge] = rng.pick(cols);
  x.translate(W / 2, H / 2); x.rotate(rng.range(-0.18, 0.12));
  x.font = `${rng.pick(["italic 800", "800", "italic 700"])} ${rng.int(110, 150)}px "Brush Script MT", "Comic Sans MS", Impact, cursive`;
  x.textAlign = "center"; x.textBaseline = "middle";
  x.lineJoin = "round"; x.lineWidth = 14; x.strokeStyle = edge; x.strokeText(word, 0, 0);
  x.fillStyle = fill; x.fillText(word, 0, 0);
  // a couple of drips and an underline swoosh
  x.strokeStyle = fill; x.lineWidth = 5; x.lineCap = "round";
  x.beginPath(); x.moveTo(-W * 0.35, H * 0.3); x.quadraticCurveTo(0, H * 0.45, W * 0.38, H * 0.22); x.stroke();
  for (let i = 0; i < 4; i++) { const dx = rng.range(-W * 0.3, W * 0.3); x.lineWidth = 3; x.beginPath(); x.moveTo(dx, H * 0.1); x.lineTo(dx, H * 0.1 + rng.range(15, 45)); x.stroke(); }
  return toTex(c, true, false);
}

function buildTextures(progress) {
  const steps = [
    ["plaster", texPlaster], ["rustication", texRustic], ["stone", texStone],
    ["red brick", () => texBrick("brick", ["#9c4a32", "#a8553a", "#8b3f2b", "#b3623f", "#7f3a2a", "#a24f36"], 101)],
    ["yellow brick", () => texBrick("brickYellow", ["#d8bf8a", "#cdb27c", "#e1c995", "#c4a873", "#d6ba86", "#bfa06e"], 111)],
    ["granite", texGranite], ["granite slabs", texSlabs],
    ["mosaic paving", () => { texMosaic("mosaicHouse", 1.5, 121); texMosaic("mosaicCurb", 1.2, 131); }],
    ["setts", texSetts], ["asphalt", texAsphalt], ["roof tiles", texTiles], ["slate", texSlate],
    ["zinc", texZinc], ["copper", texCopper],
    ["ironwork", () => { texRailing("railScroll", 141, "scroll"); texRailing("railNouveau", 151, "nouveau"); }],
    ["curtains", texCurtain],
  ];
  return steps;
}
