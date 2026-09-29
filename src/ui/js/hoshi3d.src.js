// Hoshi in 3D: renders the Meshy model with Three.js on a transparent canvas, so the glass shows through.
// Same interface as the SVG avatar (set, mood, jump, wave, lookAt, speak, destroy). Bundled by esbuild into
// hoshi3d.js because the page's CSP only allows local scripts.
import * as THREE from 'three';
import { GLTFLoader } from 'three/examples/jsm/loaders/GLTFLoader.js';
import { clone as cloneSkinned } from 'three/examples/jsm/utils/SkeletonUtils.js';

let modelPromise = null;
function loadModel() {
  modelPromise ||= new GLTFLoader().loadAsync('models/hoshi.glb');
  return modelPromise;
}

const reduced = () => matchMedia('(prefers-reduced-motion: reduce)').matches;
const lerp = (a, b, t) => a + (b - a) * t;

export class Hoshi3D {
  constructor(el, { wander = true, framing = 'full' } = {}) {
    this.el = el;
    this.wanderOn = wander;
    this.framing = framing;
    this.expr = 'neutral';
    this.level = 0;               // voice loudness while speaking, 0..1
    this.speaking = false;
    this.look = { x: 0, y: 0 };
    this.jumpT = -1;
    this.hopT = -1;
    this.target = 0;              // where she's walking to (stage units)
    this.x = 0;
    this.facing = 0;
    this.ready = this.init();
  }

  async init() {
    const canvas = document.createElement('canvas');
    canvas.className = 'hoshi-canvas';
    this.el.replaceChildren(canvas);
    this.renderer = new THREE.WebGLRenderer({ canvas, alpha: true, antialias: true, powerPreference: 'low-power' });
    this.renderer.setClearColor(0x000000, 0);
    this.renderer.outputColorSpace = THREE.SRGBColorSpace;
    this.renderer.toneMapping = THREE.ACESFilmicToneMapping;
    this.renderer.toneMappingExposure = 1.15;
    this.scene = new THREE.Scene();
    this.scene.add(new THREE.HemisphereLight(0xfff4fb, 0x8a7bb8, 1.9));
    const key = new THREE.DirectionalLight(0xffffff, 2.2);
    key.position.set(1.5, 3, 4);
    this.scene.add(key);
    const rim = new THREE.DirectionalLight(0xc9a8ff, 1.6);
    rim.position.set(-2.5, 2, -2);
    this.scene.add(rim);

    const gltf = await loadModel();
    this.model = cloneSkinned(gltf.scene);
    this.scene.add(this.model);
    const box = new THREE.Box3().setFromObject(this.model);
    const size = box.getSize(new THREE.Vector3());
    this.height = size.y;
    this.model.position.sub(new THREE.Vector3((box.min.x + box.max.x) / 2, box.min.y, (box.min.z + box.max.z) / 2));
    this.root = new THREE.Group();
    this.root.add(this.model);
    this.scene.add(this.root);

    this.bones = {};
    this.model.traverse((o) => {
      if (o.isBone) this.bones[o.name.replace('mixamorig:', '')] = o;
      if (o.isMesh) { o.frustumCulled = false; if (o.material) o.material.envMapIntensity = 0.6; }
    });
    this.mixer = new THREE.AnimationMixer(this.model);
    this.clips = Object.fromEntries(gltf.animations.map((c) => [c.name.toLowerCase(), c]));
    this.actions = {};
    for (const [name, clip] of Object.entries(this.clips)) this.actions[name] = this.mixer.clipAction(clip);
    // idle: hold the first, relaxed frame of the gesture clip until the model ships a real idle
    const idle = this.actions.idle || this.actions.agree_gesture;
    this.idle = idle;
    idle.play();
    if (!this.actions.idle) { idle.paused = true; idle.time = 0.05; }
    this.current = idle;

    this.camera = new THREE.PerspectiveCamera(this.framing === 'bust' ? 24 : 28, 1, 0.01, 50);
    this.resize();
    new ResizeObserver(() => this.resize()).observe(this.el);
    this.clock = new THREE.Timer();
    this.visible = true;
    new IntersectionObserver(([e]) => { this.visible = e.isIntersecting; }).observe(this.el);
    this.loop();
    if (this.wanderOn) this.wanderLoop();
    return this;
  }

  resize() {
    const r = this.el.getBoundingClientRect();
    if (!r.width || !this.renderer) return;
    this.renderer.setPixelRatio(Math.min(devicePixelRatio, 2));
    this.renderer.setSize(r.width, r.height, false);
    this.camera.aspect = r.width / r.height;
    const h = this.height;
    const bust = this.framing === 'bust';
    const lookY = bust ? h * 0.8 : h * 0.52;
    const dist = (bust ? h * 0.42 : h * 0.62) / Math.tan(THREE.MathUtils.degToRad(this.camera.fov / 2));
    this.camera.position.set(0, lookY + h * 0.04, dist);
    this.camera.lookAt(0, lookY, 0);
    this.camera.updateProjectionMatrix();
    this.stageWidth = h * 0.55 * this.camera.aspect;
  }

  play(name, { loop = true, fade = 0.35, speed = 1 } = {}) {
    const next = this.actions[name];
    if (!next || next === this.current) return;
    next.reset();
    next.paused = false;
    next.setLoop(loop ? THREE.LoopRepeat : THREE.LoopOnce, Infinity);
    next.clampWhenFinished = !loop;
    next.timeScale = speed;
    next.play();
    this.current.crossFadeTo(next, fade, false);
    this.current = next;
  }

  rest() {
    if (this.current === this.idle) return;
    this.idle.reset();
    this.idle.play();
    if (!this.actions.idle) { this.idle.paused = true; this.idle.time = 0.05; }
    this.current.crossFadeTo(this.idle, 0.45, false);
    this.current = this.idle;
  }

  wanderLoop() {
    this.wanderTimer = setTimeout(() => {
      if (!reduced() && !this.speaking && this.jumpT < 0) {
        this.target = (Math.random() * 2 - 1) * this.stageWidth * 0.45;
      }
      this.wanderLoop();
    }, 6000 + Math.random() * 6000);
  }

  loop() {
    this.raf = requestAnimationFrame(() => this.loop());
    if (!this.visible || document.hidden) return;
    this.clock.update();
    const dt = Math.min(this.clock.getDelta(), 0.05);
    const t = this.clock.getElapsed();

    // walking about the stage, facing where she goes, then turning back to the viewer
    const dx = this.target - this.x;
    const walking = Math.abs(dx) > this.height * 0.02 && !this.speaking;
    if (walking) {
      this.play('walking', { speed: 1 });
      this.x += Math.sign(dx) * Math.min(Math.abs(dx), this.height * 0.28 * dt);
      this.facing = lerp(this.facing, Math.sign(dx) * Math.PI / 2, 0.12);
    } else {
      if (this.current === this.actions.walking) this.rest();
      this.facing = lerp(this.facing, 0, 0.08);
    }
    this.root.position.x = this.x;
    this.root.rotation.y = this.facing;

    // jumps and hops are drawn on top of whatever clip is playing
    let y = 0;
    if (this.jumpT >= 0) {
      this.jumpT += dt / 0.75;
      y = Math.sin(Math.min(this.jumpT, 1) * Math.PI) * this.height * 0.14;
      this.root.rotation.y += Math.min(this.jumpT, 1) * Math.PI * 2 * (this.spin ? 1 : 0);
      if (this.jumpT >= 1) { this.jumpT = -1; this.spin = false; }
    }
    if (this.hopT >= 0) {
      this.hopT += dt / 0.4;
      y += Math.sin(Math.min(this.hopT, 1) * Math.PI) * this.height * 0.04;
      if (this.hopT >= 1) this.hopT = -1;
    }
    this.root.position.y = y;
    this.mixer.update(dt);

    // procedural life after the clip: breathing, head follows the viewer, mood poses, talking nods
    const b = this.bones;
    const breathe = Math.sin(t * 2.1) * 0.02;
    if (b.Spine2) b.Spine2.rotation.x += breathe * 0.6;
    if (b.Spine) b.Spine.rotation.z += Math.sin(t * 0.9) * 0.015;
    const moodTilt = { sad: [0.28, 0], thinking: [-0.06, 0.22], surprised: [-0.12, 0], hype: [-0.05, 0] }[this.expr] || [0, 0];
    if (b.Head) {
      b.Head.rotation.x += moodTilt[0] + this.look.y * 0.18 + (this.speaking ? Math.sin(t * 9) * this.level * 0.12 : 0);
      b.Head.rotation.z += moodTilt[1];
      b.Head.rotation.y += this.look.x * 0.35;
    }
    if (b.Neck) b.Neck.rotation.y += this.look.x * 0.15;
    this.renderer.render(this.scene, this.camera);
  }

  // --- the avatar interface the app uses ------------------------------------------------
  set(expression) { this.expr = expression; }

  mood(mood) {
    this.set({ hype: 'hype', sad: 'sad', funny: 'happy', tense: 'surprised', calm: 'neutral' }[mood] || 'neutral');
    if (mood === 'hype') { this.spin = true; this.jump(); } else if (mood === 'funny') this.jump();
    else if (mood === 'tense') this.hopT = 0;
  }

  jump() { if (!reduced()) this.jumpT = 0; }

  wave() {
    if (reduced()) return;
    this.jump();
    this.play('agree_gesture', { speed: 1.2 });
    clearTimeout(this.waveTimer);
    this.waveTimer = setTimeout(() => { if (!this.speaking) this.rest(); }, 2600);
  }

  lookAt(x, y) { this.look = { x, y }; }

  speak(level) {
    if (level === null) {
      if (this.speaking) { this.speaking = false; this.level = 0; this.rest(); }
      return;
    }
    if (!this.speaking) { this.speaking = true; this.target = this.x; this.play('agree_gesture', { speed: 1 }); }
    this.level = lerp(this.level, Math.min(1, level), 0.3);
  }

  snapshot() { return this.renderer.domElement.toDataURL('image/png'); }

  destroy() {
    cancelAnimationFrame(this.raf);
    clearTimeout(this.wanderTimer);
    this.renderer?.dispose();
  }
}

export function webglAvailable() {
  try { return !!document.createElement('canvas').getContext('webgl2'); } catch { return false; }
}
