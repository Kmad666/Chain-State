// ============================================================== materials
// Facade materials carry a per-facade weathering map. The shader works out where a
// pixel sits on its facade from its world position, so cornices, frames and the wall
// all pick up the same soot and the same run-off streaks below each sill.

const MAT = {};
let GRIME_ON = true;
const grimeUniformsAll = [];

function patchGrime(mat, g, brick) {
  const u = {
    gMap: { value: g.map },
    gOrigin: { value: g.origin.clone() },
    gAlong: { value: g.along.clone() },
    gSize: { value: new THREE.Vector2(g.width, g.height) },
    gOn: { value: GRIME_ON ? 1 : 0 },
    brickMap: { value: brick ? TEX.brick.map : null },
  };
  grimeUniformsAll.push(u);
  mat.userData.grime = u;
  mat.onBeforeCompile = (sh) => {
    Object.assign(sh.uniforms, u);
    sh.vertexShader = sh.vertexShader
      .replace("#include <common>", "#include <common>\nvarying vec3 vGW;")
      .replace("#include <project_vertex>", "#include <project_vertex>\nvGW = (modelMatrix * vec4(transformed, 1.0)).xyz;");
    sh.fragmentShader = sh.fragmentShader
      .replace("#include <common>", `#include <common>
varying vec3 vGW;
uniform sampler2D gMap; uniform vec3 gOrigin; uniform vec3 gAlong; uniform vec2 gSize; uniform float gOn;
${brick ? "uniform sampler2D brickMap;" : ""}`)
      .replace("#include <map_fragment>", `#include <map_fragment>
{
  float ga = dot(vGW - gOrigin, gAlong);
  vec2 gu = vec2(ga / gSize.x, (vGW.y - gOrigin.y) / gSize.y);
  vec4 gm = texture2D(gMap, clamp(gu, vec2(0.002), vec2(0.998)));
  ${brick ? `vec3 br = texture2D(brickMap, vec2(ga * 0.5, vGW.y)).rgb;
  diffuseColor.rgb = mix(br * vec3(0.95, 0.9, 0.86), diffuseColor.rgb, mix(1.0, gm.a, gOn));` : ""}
  diffuseColor.rgb *= mix(vec3(1.0), gm.rgb, gOn);
}`);
  };
  mat.customProgramCacheKey = () => "grime" + (brick ? "b" : "");
  return mat;
}

function texMat(name, color, opts = {}) {
  const t = TEX[name];
  const m = new THREE.MeshStandardMaterial({
    color: new THREE.Color(color), map: t.map, normalMap: t.normal || null,
    roughness: opts.roughness ?? 0.9, metalness: opts.metalness ?? 0,
  });
  if (t.normal) m.normalScale.set(opts.normal ?? 1, opts.normal ?? 1);
  return m;
}

// Materials for one facade segment, tinted and weathered.
function facadeMaterials(scheme, grime) {
  const wall = patchGrime(texMat("plaster", scheme.wall, { roughness: 0.93, normal: 0.8 }), grime, true);
  const orn = patchGrime(texMat("stone", scheme.orn, { roughness: 0.88, normal: 0.7 }), grime, false);
  const rustic = patchGrime(texMat("rustic", scheme.base, { roughness: 0.92 }), grime, true);
  const sockel = patchGrime(texMat("granite", scheme.sockel || "#8d8a85", { roughness: 0.8, normal: 0.5 }), grime, false);
  const res = { wall, orn, rustic, sockel };
  if (scheme.brick) res.brick = patchGrime(texMat(scheme.brick, "#ffffff", { roughness: 0.9 }), grime, false);
  return res;
}

function buildSharedMaterials() {
  const std = (o) => new THREE.MeshStandardMaterial(o);
  MAT.frame = std({ color: "#e9e6de", roughness: 0.55 });
  MAT.frameDark = std({ color: "#3b4038", roughness: 0.5 });
  MAT.frameBrown = std({ color: "#5a3e2b", roughness: 0.55 });
  MAT.frameCream = std({ color: "#d8cfb8", roughness: 0.55 });
  MAT.frameWood = std({ color: "#6b4a30", roughness: 0.6 });
  MAT.frameGreen = std({ color: "#3d5446", roughness: 0.55 });
  MAT.glass = std({ color: "#1b2024", roughness: 0.12, metalness: 0.0, envMapIntensity: 0.45 });
  MAT.glassLit = std({ color: "#1b2024", roughness: 0.12, metalness: 0.0, envMapIntensity: 0.45, emissive: new THREE.Color("#ffc27a"), emissiveIntensity: 0 });
  MAT.glassLit2 = std({ color: "#1b2024", roughness: 0.12, metalness: 0.0, envMapIntensity: 0.45, emissive: new THREE.Color("#ffe6c0"), emissiveIntensity: 0 });
  MAT.shopGlass = std({ color: "#1f262b", roughness: 0.03, metalness: 0.0, envMapIntensity: 0.9, transparent: true, opacity: 0.38, depthWrite: false });
  MAT.interior = std({ color: "#191714", roughness: 1 });
  MAT.shopInterior = std({ color: "#4a4038", roughness: 0.9, emissive: new THREE.Color("#2b2216"), emissiveIntensity: 0.5 });
  MAT.curtain = std({ map: TEX.curtain.map, transparent: true, opacity: 0.7, roughness: 1, side: THREE.DoubleSide, depthWrite: false });
  MAT.doorWood = std({ color: "#4b3324", roughness: 0.6 });
  MAT.doorGreen = std({ color: "#2f4535", roughness: 0.55 });
  MAT.iron = std({ color: "#1a1a1a", roughness: 0.5, metalness: 0.6 });
  MAT.railScroll = std({ map: TEX.railScroll.map, alphaTest: 0.35, alphaToCoverage: true, side: THREE.DoubleSide, roughness: 0.5, metalness: 0.5 });
  MAT.railNouveau = std({ map: TEX.railNouveau.map, alphaTest: 0.35, alphaToCoverage: true, side: THREE.DoubleSide, roughness: 0.5, metalness: 0.5 });
  MAT.tiles = texMat("tiles", "#ffffff", { roughness: 0.85 });
  MAT.slate = texMat("slate", "#ffffff", { roughness: 0.6 });
  MAT.gableRoof = MAT.slate;
  MAT.zinc = texMat("zinc", "#8f969c", { roughness: 0.55, metalness: 0.25 });
  MAT.copper = texMat("copper", "#ffffff", { roughness: 0.6, metalness: 0.15 });
  MAT.chimney = texMat("brick", "#f2c2a0", { roughness: 0.95 });
  MAT.brickRear = texMat("brick", "#a09080", { roughness: 0.95 });
  MAT.rearWall = texMat("plaster", "#b9b2a4", { roughness: 0.95 });
  MAT.firewall = texMat("plaster", "#9a958c", { roughness: 0.97 });
  MAT.granite = texMat("granite", "#ffffff", { roughness: 0.75, normal: 0.6 });
  MAT.setts = texMat("setts", "#ffffff", { roughness: 0.7, normal: 1.0 });
  MAT.asphalt = texMat("asphalt", "#ffffff", { roughness: 0.92 });
  MAT.slabs = texMat("slabs", "#ffffff", { roughness: 0.72 });
  MAT.mosaicHouse = texMat("mosaicHouse", "#ffffff", { roughness: 0.85 });
  MAT.mosaicCurb = texMat("mosaicCurb", "#ffffff", { roughness: 0.85 });
  MAT.steel = std({ color: "#8d8f92", roughness: 0.3, metalness: 0.9 });
  MAT.lampIron = std({ color: "#1f2a24", roughness: 0.45, metalness: 0.5 });
  MAT.lampGlass = std({ color: "#f3e7c8", roughness: 0.1, emissive: new THREE.Color("#ffcf7a"), emissiveIntensity: 0 });
  MAT.pumpGreen = std({ color: "#2e4a3a", roughness: 0.5, metalness: 0.4 });
  MAT.gold = std({ color: "#b8913d", roughness: 0.35, metalness: 0.9 });
  MAT.paintWhite = std({ color: "#e7e5df", roughness: 0.6 });
  MAT.courtyard = texMat("setts", "#d8d2c6", { roughness: 0.9 });
  MAT.grass = std({ color: "#55663b", roughness: 1 });
  MAT.grassDark = std({ color: "#3f5a2e", roughness: 1, flatShading: true });
  MAT.asphaltRoof = std({ color: "#4a4744", roughness: 0.95 });
  MAT.awningRed = std({ color: "#8e2c27", roughness: 0.85, side: THREE.DoubleSide });
  MAT.awningGreen = std({ color: "#2d5a46", roughness: 0.85, side: THREE.DoubleSide });
  MAT.awningCream = std({ color: "#d9cfb3", roughness: 0.85, side: THREE.DoubleSide });
  MAT.distant = std({ color: "#b8b2a6", roughness: 0.95 });
  MAT.distantRoof = std({ color: "#5d5149", roughness: 0.9 });
}

function tagMaterials() {
  for (let i = 0; i < 8; i++) MAT["tag" + i] = new THREE.MeshStandardMaterial({ map: tagTexture(700 + i * 13), transparent: true, depthWrite: false, roughness: 0.8, polygonOffset: true, polygonOffsetFactor: -3 });
}

const signMatCache = new Map();
function signMat(text, opts) {
  const key = text + JSON.stringify(opts || {});
  if (!signMatCache.has(key)) signMatCache.set(key, new THREE.MeshStandardMaterial({ map: signTexture(text, opts), roughness: 0.6 }));
  return signMatCache.get(key);
}

function setGrime(on) {
  GRIME_ON = on;
  for (const u of grimeUniformsAll) u.gOn.value = on ? 1 : 0;
}
