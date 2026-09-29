// Merge Meshy exports (one GLB per animation, each with a full copy of the character) into one light model:
// one mesh, every animation, app-sized WebP textures and a simplified mesh.
//   node tools/build-hoshi-model.mjs <folder with Meshy *.glb> [out.glb]
import fs from 'fs';
import path from 'path';
import { NodeIO } from '@gltf-transform/core';
import { ALL_EXTENSIONS } from '@gltf-transform/extensions';
import { dedup, prune, resample, simplify, textureCompress, weld } from '@gltf-transform/functions';
import { MeshoptSimplifier } from 'meshoptimizer';
import sharp from 'sharp';

const [dir, out = 'src/ui/models/hoshi.glb'] = process.argv.slice(2);
const files = fs.readdirSync(dir).filter((f) => f.endsWith('.glb')).map((f) => path.join(dir, f));
const io = new NodeIO().registerExtensions(ALL_EXTENSIONS);

const base = await io.read(files[0]);
const root = base.getRoot();
const nodeByName = new Map(root.listNodes().map((n) => [n.getName(), n]));
const clipName = (a, file) => (a.getName() || path.basename(file)).replace(/^.*Animation_/, '').replace(/_withSkin.*$/, '');
root.listAnimations().forEach((a) => a.setName(clipName(a, files[0])));
const buffer = root.listBuffers()[0];

// copy every other file's animation onto the base skeleton, matching bones by name
for (const file of files.slice(1)) {
  const doc = await io.read(file);
  for (const src of doc.getRoot().listAnimations()) {
    const anim = base.createAnimation(clipName(src, file));
    for (const ch of src.listChannels()) {
      const target = nodeByName.get(ch.getTargetNode()?.getName());
      if (!target) continue;
      const s = ch.getSampler();
      const copy = (acc) => base.createAccessor().setType(acc.getType()).setArray(acc.getArray().slice()).setBuffer(buffer);
      const sampler = base.createAnimationSampler().setInput(copy(s.getInput())).setOutput(copy(s.getOutput()))
        .setInterpolation(s.getInterpolation());
      anim.addSampler(sampler).addChannel(base.createAnimationChannel().setTargetNode(target)
        .setTargetPath(ch.getTargetPath()).setSampler(sampler));
    }
  }
}

await MeshoptSimplifier.ready;
await base.transform(
  dedup(),
  weld(),
  simplify({ simplifier: MeshoptSimplifier, ratio: 0.4, error: 0.0015 }),
  resample(),
  // colour stays crisp at 2048, the rest drop to 1024: she's never shown larger than ~400 px tall
  textureCompress({ encoder: sharp, targetFormat: 'webp', resize: [2048, 2048], slots: /baseColor/, quality: 88 }),
  textureCompress({ encoder: sharp, targetFormat: 'webp', resize: [1024, 1024], slots: /^(?!baseColor)/, quality: 85 }),
  prune(),
);

fs.mkdirSync(path.dirname(out), { recursive: true });
await io.write(out, base);
const r = base.getRoot();
const tris = r.listMeshes().reduce((n, m) => n + m.listPrimitives().reduce((k, p) => k + (p.getIndices()?.getCount() || 0) / 3, 0), 0);
console.log(`wrote ${out}: ${(fs.statSync(out).size / 1e6).toFixed(1)} MB, ${Math.round(tris)} triangles, animations: ${r.listAnimations().map((a) => a.getName()).join(', ')}`);
