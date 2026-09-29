// Liquid Glass refraction. For each .glass element we render a displacement map shaped like a convex glass
// bezel (flat in the middle, bending light near the rounded edge) and plug it into backdrop-filter through an
// SVG feDisplacementMap. Chromium-only technique, which is exactly what we ship.

const NS = 'http://www.w3.org/2000/svg';
let defs = null;
let seq = 0;

function ensureDefs() {
  if (defs) return defs;
  const svg = document.createElementNS(NS, 'svg');
  svg.setAttribute('width', '0');
  svg.setAttribute('height', '0');
  svg.setAttribute('aria-hidden', 'true');
  svg.style.position = 'absolute';
  defs = document.createElementNS(NS, 'defs');
  svg.appendChild(defs);
  document.body.appendChild(svg);
  return defs;
}

// Signed distance to a rounded rectangle, and its outward normal.
function sdf(px, py, hw, hh, r) {
  const qx = Math.abs(px) - (hw - r);
  const qy = Math.abs(py) - (hh - r);
  const ox = Math.max(qx, 0), oy = Math.max(qy, 0);
  const outside = Math.hypot(ox, oy);
  const d = outside + Math.min(Math.max(qx, qy), 0) - r;
  let nx, ny;
  if (qx > 0 && qy > 0) { nx = ox / (outside || 1); ny = oy / (outside || 1); }
  else if (qx > qy) { nx = 1; ny = 0; } else { nx = 0; ny = 1; }
  return [d, nx * Math.sign(px || 1), ny * Math.sign(py || 1)];
}

export function displacementMap(w, h, radius, bezel) {
  // render at half resolution: the filter scales it up and the result is smooth anyway
  const s = 0.5;
  const cw = Math.max(2, Math.round(w * s)), ch = Math.max(2, Math.round(h * s));
  const c = document.createElement('canvas');
  c.width = cw; c.height = ch;
  const ctx = c.getContext('2d');
  const img = ctx.createImageData(cw, ch);
  const hw = w / 2, hh = h / 2, r = Math.min(radius, hw, hh);
  for (let y = 0; y < ch; y++) {
    for (let x = 0; x < cw; x++) {
      const px = x / s - hw + 0.5, py = y / s - hh + 0.5;
      const [d, nx, ny] = sdf(px, py, hw, hh, r);
      const inside = -d;
      let mag = 0;
      if (inside >= 0 && inside < bezel) {
        const t = 1 - inside / bezel;           // 1 at the rim, 0 where the glass goes flat
        mag = t * t * (3 - 2 * t);              // smoothstep: a rounded bezel, no hard ring
      }
      const i = (y * cw + x) * 4;
      img.data[i] = 128 + nx * mag * 127;      // R: x displacement (sample from outside → bent edge)
      img.data[i + 1] = 128 + ny * mag * 127;  // G: y displacement
      img.data[i + 2] = 128;
      img.data[i + 3] = 255;
    }
  }
  ctx.putImageData(img, 0, 0);
  return c.toDataURL();
}

function applyTo(el) {
  const rect = el.getBoundingClientRect();
  const w = Math.round(rect.width), h = Math.round(rect.height);
  if (w < 8 || h < 8) return;
  const key = `${w}x${h}`;
  if (el.dataset.glassKey === key) return;
  el.dataset.glassKey = key;

  const radius = parseFloat(getComputedStyle(el).borderTopLeftRadius) || 20;
  const bezel = Math.min(Math.max(10, Math.min(w, h) * 0.18), 26);
  const scale = el.dataset.refract ? Number(el.dataset.refract) : Math.min(40, bezel * 1.6);

  const id = el.dataset.glassId || `lg-${++seq}`;
  el.dataset.glassId = id;
  let filter = document.getElementById(id);
  if (!filter) {
    filter = document.createElementNS(NS, 'filter');
    filter.id = id;
    filter.setAttribute('color-interpolation-filters', 'sRGB');
    filter.innerHTML = `<feImage result="map" preserveAspectRatio="none"/>
      <feDisplacementMap in="SourceGraphic" in2="map" xChannelSelector="R" yChannelSelector="G"/>`;
    ensureDefs().appendChild(filter);
  }
  filter.setAttribute('x', '0');
  filter.setAttribute('y', '0');
  filter.setAttribute('width', String(w));
  filter.setAttribute('height', String(h));
  filter.setAttribute('filterUnits', 'userSpaceOnUse');
  const image = filter.querySelector('feImage');
  image.setAttribute('href', displacementMap(w, h, radius, bezel));
  image.setAttribute('width', String(w));
  image.setAttribute('height', String(h));
  filter.querySelector('feDisplacementMap').setAttribute('scale', String(scale));
  el.style.setProperty('--glass-filter', `blur(14px) url(#${id}) saturate(175%) brightness(1.04)`);
}

let observer = null;

export function enableRefraction(root = document) {
  const reduce = matchMedia('(prefers-reduced-transparency: reduce)');
  const off = () => document.documentElement.classList.contains('reduce-transparency') || reduce.matches;
  if (off()) return;
  observer = new ResizeObserver((entries) => {
    for (const e of entries) {
      clearTimeout(e.target._glassT);
      e.target._glassT = setTimeout(() => !off() && applyTo(e.target), 120);   // settle during resizes
    }
  });
  root.querySelectorAll('.glass').forEach((el) => observer.observe(el));
}

export function refreshRefraction() {
  document.querySelectorAll('.glass').forEach((el) => {
    delete el.dataset.glassKey;
    if (document.documentElement.classList.contains('reduce-transparency')) el.style.removeProperty('--glass-filter');
    else applyTo(el);
  });
}
