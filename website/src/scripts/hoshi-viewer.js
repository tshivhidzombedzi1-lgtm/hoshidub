// Hoshi on the website: the same 3D model as the app, on a transparent canvas over the glass.
// Loaded only when her stage scrolls into view; the poster image stays if WebGL or motion isn't available.
import * as THREE from 'three';
import { GLTFLoader } from 'three/examples/jsm/loaders/GLTFLoader.js';

const lerp = (a, b, t) => a + (b - a) * t;

export async function mountHoshi(stage) {
  const reduced = matchMedia('(prefers-reduced-motion: reduce)').matches;
  const canvas = document.createElement('canvas');
  if (!canvas.getContext('webgl2')) return null;
  canvas.className = 'hoshi-canvas';
  canvas.setAttribute('aria-hidden', 'true');

  const renderer = new THREE.WebGLRenderer({ canvas, alpha: true, antialias: true, powerPreference: 'low-power' });
  renderer.setClearColor(0x000000, 0);
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.15;
  const scene = new THREE.Scene();
  scene.add(new THREE.HemisphereLight(0xfff4fb, 0x8a7bb8, 1.9));
  const key = new THREE.DirectionalLight(0xffffff, 2.2); key.position.set(1.5, 3, 4); scene.add(key);
  const rim = new THREE.DirectionalLight(0xc9a8ff, 1.6); rim.position.set(-2.5, 2, -2); scene.add(rim);

  const gltf = await new GLTFLoader().loadAsync('/models/hoshi.glb');
  const model = gltf.scene;
  const box = new THREE.Box3().setFromObject(model);
  const h = box.getSize(new THREE.Vector3()).y;
  model.position.sub(new THREE.Vector3((box.min.x + box.max.x) / 2, box.min.y, (box.min.z + box.max.z) / 2));
  model.traverse((o) => { if (o.isMesh) o.frustumCulled = false; });
  const rig = new THREE.Group(); rig.add(model); scene.add(rig);
  const bones = {};
  model.traverse((o) => { if (o.isBone) bones[o.name.replace('mixamorig:', '')] = o; });

  const mixer = new THREE.AnimationMixer(model);
  const clip = (n) => gltf.animations.find((c) => c.name.toLowerCase().includes(n));
  const gesture = mixer.clipAction(clip('agree') || gltf.animations[0]);
  const walk = clip('walk') ? mixer.clipAction(clip('walk')) : null;
  gesture.play(); gesture.paused = true; gesture.time = 0.05;          // relaxed standing pose
  let current = gesture;
  const to = (action, loop = true) => {
    if (!action || action === current) return;
    action.reset(); action.paused = false; action.setLoop(loop ? THREE.LoopRepeat : THREE.LoopOnce, Infinity);
    action.play(); current.crossFadeTo(action, 0.35, false); current = action;
  };
  const rest = () => { if (current === gesture && gesture.paused) return; gesture.reset(); gesture.play(); gesture.paused = true; gesture.time = 0.05; current.crossFadeTo(gesture, 0.4, false); current = gesture; };

  const camera = new THREE.PerspectiveCamera(26, 1, 0.01, 50);
  const resize = () => {
    const r = stage.getBoundingClientRect();
    renderer.setPixelRatio(Math.min(devicePixelRatio, 2));
    renderer.setSize(r.width, r.height, false);
    camera.aspect = r.width / r.height;
    const dist = (h * 0.6) / Math.tan(THREE.MathUtils.degToRad(13));
    camera.position.set(0, h * 0.56, dist);
    camera.lookAt(0, h * 0.5, 0);
    camera.updateProjectionMatrix();
  };
  stage.appendChild(canvas);
  resize();
  new ResizeObserver(resize).observe(stage);

  // she walks in from the side the first time she's seen, then waves hello
  let x = reduced ? 0 : -h * 0.9, target = 0, facing = 0, look = { x: 0, y: 0 }, jumpT = -1, visible = true;
  const timer = new THREE.Timer();
  new IntersectionObserver(([e]) => { visible = e.isIntersecting; }).observe(stage);
  stage.addEventListener('pointermove', (e) => {
    const r = stage.getBoundingClientRect();
    look = { x: ((e.clientX - r.left) / r.width - 0.5) * 2, y: ((e.clientY - r.top) / r.height - 0.4) * 1.2 };
  });
  stage.addEventListener('pointerleave', () => { look = { x: 0, y: 0 }; });
  const greet = () => { if (reduced) return; jumpT = 0; to(gesture); setTimeout(rest, 2800); };
  stage.addEventListener('click', greet);

  function frame() {
    requestAnimationFrame(frame);
    if (!visible || document.hidden) return;
    timer.update();
    const dt = Math.min(timer.getDelta(), 0.05), t = timer.getElapsed();
    const dx = target - x;
    if (Math.abs(dx) > h * 0.02) {
      to(walk);
      x += Math.sign(dx) * Math.min(Math.abs(dx), h * 0.32 * dt);
      facing = lerp(facing, Math.sign(dx) * Math.PI / 2, 0.12);
      if (Math.abs(target - x) <= h * 0.02) setTimeout(greet, 250);
    } else {
      if (current === walk) rest();
      facing = lerp(facing, 0, 0.08);
    }
    let y = 0;
    if (jumpT >= 0) { jumpT += dt / 0.7; y = Math.sin(Math.min(jumpT, 1) * Math.PI) * h * 0.1; if (jumpT >= 1) jumpT = -1; }
    rig.position.set(x, y, 0);
    rig.rotation.y = facing;
    mixer.update(dt);
    if (bones.Spine2) bones.Spine2.rotation.x += Math.sin(t * 2.1) * 0.012;
    if (bones.Head) { bones.Head.rotation.y += look.x * 0.35; bones.Head.rotation.x += look.y * 0.18; }
    renderer.render(scene, camera);
  }
  frame();
  renderer.render(scene, camera);                                    // first frame now, even before rAF ticks
  stage.classList.add('is-live');
  // still image of her standing centred (used to make the poster fallback)
  const snapshot = () => { rig.position.set(0, 0, 0); rig.rotation.y = 0; mixer.update(0); renderer.render(scene, camera); return canvas.toDataURL('image/png'); };
  return { greet, snapshot };
}
