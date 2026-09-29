import { NodeIO } from '@gltf-transform/core';
import { ALL_EXTENSIONS } from '@gltf-transform/extensions';
const io = new NodeIO().registerExtensions(ALL_EXTENSIONS);
for (const f of process.argv.slice(2)) {
  const doc = await io.read(f);
  const r = doc.getRoot();
  const tris = r.listMeshes().reduce((n, m) => n + m.listPrimitives().reduce((k, p) => k + (p.getIndices()?.getCount() || 0) / 3, 0), 0);
  console.log(f.split(/[\/]/).pop());
  console.log('  meshes', r.listMeshes().length, 'triangles', Math.round(tris), 'skins', r.listSkins().length, 'joints', r.listSkins()[0]?.listJoints().length);
  console.log('  textures', r.listTextures().map((t) => `${t.getMimeType()} ${t.getSize()?.join('x')} ${(t.getImage().byteLength / 1e6).toFixed(1)}MB`).join(', '));
  console.log('  animations', r.listAnimations().map((a) => `${a.getName()} (${a.listChannels().length} ch)`).join(', '));
}
