import { useEffect, useMemo } from 'react';
import * as THREE from 'three';

// The console's display is a live canvas-2D texture — the Switch 2 home menu
// (with a real clock), two game splash screens, and System Settings. Ported
// straight from the dependency-free WebGL build so both web builds show the
// same UI. Because the material is emissive, whatever is drawn here is what
// the bloom pass picks up and blooms.

export const APPS = [
  {
    name: 'HOME',
    tiles: [
      { t: 'Mario Kart World', c: '#e8412e' },
      { t: 'Zelda: TotK', c: '#2e9e6b' },
      { t: 'Metroid Prime 4', c: '#c9962a' },
      { t: 'Splatoon', c: '#7a3bd6' },
      { t: 'Kirby Air', c: '#e86aa0' },
      { t: 'eShop', c: '#1f8fd6' },
    ],
  },
  { name: 'MARIO KART WORLD', hero: '#e8412e', sub: 'Press A to Start' },
  { name: 'THE LEGEND OF ZELDA', hero: '#2e9e6b', sub: 'Loading Hyrule…' },
  { name: 'SETTINGS', settings: true },
];

export const APP_LABELS = ['Home menu', 'Mario Kart World', 'Zelda: TotK', 'System Settings'];

function shade(hex, amt) {
  const n = parseInt(hex.slice(1), 16);
  const cl = (v) => Math.max(0, Math.min(255, v + amt));
  return `rgb(${cl((n >> 16) & 255)},${cl((n >> 8) & 255)},${cl(n & 255)})`;
}

function roundRect(c, x, y, w, h, r) {
  c.beginPath();
  c.moveTo(x + r, y);
  c.arcTo(x + w, y, x + w, y + h, r);
  c.arcTo(x + w, y + h, x, y + h, r);
  c.arcTo(x, y + h, x, y, r);
  c.arcTo(x, y, x + w, y, r);
  c.closePath();
}

function paint(c, W, H, { powered, appIndex }) {
  if (!powered) {
    c.fillStyle = '#000';
    c.fillRect(0, 0, W, H);
    return;
  }
  const app = APPS[appIndex];

  const g = c.createLinearGradient(0, 0, 0, H);
  if (app.hero) {
    g.addColorStop(0, shade(app.hero, -40));
    g.addColorStop(1, shade(app.hero, -75));
  } else {
    g.addColorStop(0, '#20252e');
    g.addColorStop(1, '#12151b');
  }
  c.fillStyle = g;
  c.fillRect(0, 0, W, H);

  // status bar — live clock + battery
  const now = new Date();
  const hh = String(now.getHours()).padStart(2, '0');
  const mm = String(now.getMinutes()).padStart(2, '0');
  c.fillStyle = 'rgba(255,255,255,0.92)';
  c.font = '600 30px system-ui, sans-serif';
  c.textBaseline = 'top';
  c.textAlign = 'left';
  c.fillText(`${hh}:${mm}`, 40, 30);
  c.textAlign = 'right';
  c.fillText('100%', W - 90, 30);
  c.strokeStyle = 'rgba(255,255,255,0.9)';
  c.lineWidth = 3;
  roundRect(c, W - 78, 32, 42, 22, 4);
  c.stroke();
  c.fillStyle = 'rgba(255,255,255,0.9)';
  c.fillRect(W - 36, 38, 5, 10);
  c.fillRect(W - 74, 36, 34, 14);
  c.textAlign = 'left';

  if (app.tiles) {
    const cols = 3, gapx = 36, gapy = 40, mx = 70, top = 140;
    const tw = (W - mx * 2 - gapx * (cols - 1)) / cols;
    const th = 150;
    app.tiles.forEach((tile, i) => {
      const cx = mx + (i % cols) * (tw + gapx);
      const cy = top + Math.floor(i / cols) * (th + gapy);
      const sel = i === 0;
      c.save();
      if (sel) {
        c.shadowColor = 'rgba(255,255,255,0.6)';
        c.shadowBlur = 26;
      }
      const tg = c.createLinearGradient(cx, cy, cx, cy + th);
      tg.addColorStop(0, shade(tile.c, 15));
      tg.addColorStop(1, shade(tile.c, -30));
      c.fillStyle = tg;
      roundRect(c, cx, cy, tw, th, 16);
      c.fill();
      c.restore();
      if (sel) {
        c.strokeStyle = '#fff';
        c.lineWidth = 5;
        roundRect(c, cx - 3, cy - 3, tw + 6, th + 6, 19);
        c.stroke();
      }
      c.fillStyle = 'rgba(0,0,0,0.28)';
      roundRect(c, cx, cy + th - 46, tw, 46, 0);
      c.fill();
      c.fillStyle = '#fff';
      c.font = '600 22px system-ui, sans-serif';
      c.fillText(tile.t, cx + 16, cy + th - 38, tw - 24);
    });
    c.fillStyle = 'rgba(255,255,255,0.85)';
    c.font = '700 34px system-ui, sans-serif';
    c.fillText('Nintendo Switch', 70, 84);
    c.fillStyle = '#37c3ff';
    c.fillText('2', 70 + c.measureText('Nintendo Switch ').width, 84);
  } else if (app.settings) {
    c.fillStyle = '#fff';
    c.font = '700 44px system-ui, sans-serif';
    c.fillText('System Settings', 70, 120);
    const items = [
      'Display  —  1080p / 120Hz',
      'Joy-Con 2  —  Magnetic attach',
      'GameChat  —  Ready',
      'Airplane Mode  —  Off',
      'Theme  —  Basic Black',
    ];
    items.forEach((t, i) => {
      const y = 210 + i * 72;
      c.fillStyle = 'rgba(255,255,255,0.06)';
      roundRect(c, 60, y, W - 120, 56, 12);
      c.fill();
      c.fillStyle = i === 0 ? '#37c3ff' : 'rgba(255,255,255,0.9)';
      c.font = '500 26px system-ui, sans-serif';
      c.fillText(t, 84, y + 15);
    });
  } else {
    c.fillStyle = 'rgba(255,255,255,0.96)';
    c.font = '800 64px system-ui, sans-serif';
    c.textAlign = 'center';
    c.fillText(app.name, W / 2, H / 2 - 70);
    c.font = '500 30px system-ui, sans-serif';
    c.fillStyle = 'rgba(255,255,255,0.8)';
    if (Math.floor(Date.now() / 600) % 2 === 0) c.fillText(app.sub || '', W / 2, H / 2 + 30);
    c.textAlign = 'left';
  }
}

/**
 * A CanvasTexture that repaints whenever `powered` / `appIndex` change, plus a
 * 1 Hz tick so the clock and the "Press A" blink stay live.
 */
export function useScreenTexture({ powered, appIndex }) {
  const { texture, canvas } = useMemo(() => {
    const cv = document.createElement('canvas');
    cv.width = 1024;
    cv.height = 640;
    const tex = new THREE.CanvasTexture(cv);
    tex.colorSpace = THREE.SRGBColorSpace;
    tex.anisotropy = 8;
    // The WebGL build flips the texture with UNPACK_FLIP_Y_WEBGL; three.js
    // flips by default, and the plane's UVs already match — so leave flipY on.
    return { texture: tex, canvas: cv };
  }, []);

  useEffect(() => {
    const ctx = canvas.getContext('2d');
    const redraw = () => {
      paint(ctx, canvas.width, canvas.height, { powered, appIndex });
      texture.needsUpdate = true;
    };
    redraw();
    const id = setInterval(redraw, 1000);
    return () => clearInterval(id);
  }, [canvas, texture, powered, appIndex]);

  useEffect(() => () => texture.dispose(), [texture]);

  return texture;
}
