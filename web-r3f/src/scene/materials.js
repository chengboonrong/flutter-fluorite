// Material table — the same PBR values the dependency-free WebGL build uses
// (see ../../../web/index.html, `const M = {...}`), re-expressed as
// meshPhysicalMaterial props. Keeping one table means the two web builds and
// the Fluorite/Flutter build all describe the console with the same numbers.
//
// WebGL build            → R3F / three.js
//   metallic             → metalness
//   rough                → roughness
//   clear (extra spec)   → clearcoat  (a real clearcoat lobe here, not a hack)

export const MAT = {
  bodyBlack: { color: '#0e1013', metalness: 0.15, roughness: 0.42, clearcoat: 0.6, clearcoatRoughness: 0.25 },
  bodyDark:  { color: '#171a1f', metalness: 0.1,  roughness: 0.5,  clearcoat: 0.4, clearcoatRoughness: 0.3 },
  joyLeft:   { color: '#058cc7', metalness: 0.05, roughness: 0.45, clearcoat: 0.5, clearcoatRoughness: 0.25 },
  joyRight:  { color: '#eb2933', metalness: 0.05, roughness: 0.45, clearcoat: 0.5, clearcoatRoughness: 0.25 },
  rail:      { color: '#4d525c', metalness: 0.9,  roughness: 0.28 },
  stick:     { color: '#0a0a0d', metalness: 0.1,  roughness: 0.6 },
  stickRing: { color: '#1f2126', metalness: 0.5,  roughness: 0.4 },
  btnLight:  { color: '#b8bccc', metalness: 0.2,  roughness: 0.5 },
  btnDark:   { color: '#1a1c21', metalness: 0.2,  roughness: 0.5 },
  metal:     { color: '#8c919e', metalness: 0.95, roughness: 0.25 },
  floor:     { color: '#0d0e12', metalness: 0.0,  roughness: 0.9 },
};

// The front glass gets a transmission lobe — the thing the hand-written GLSL
// could only approximate with a fresnel term.
export const GLASS = {
  color: '#05060a',
  metalness: 0,
  roughness: 0.06,
  clearcoat: 1,
  clearcoatRoughness: 0.02,
  transmission: 0.35,
  thickness: 0.4,
  ior: 1.5,
};
