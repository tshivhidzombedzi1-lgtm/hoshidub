// Measures the dialogue ducker with test tones: Japanese voices must drop a lot, the soundtrack must not.
const { test, expect } = require('@playwright/test');
const { launch } = require('./helpers');

test('while English speaks: voices drop, music and effects stay', async () => {
  const { app, ui } = await launch();
  const r = await ui.evaluate(async () => {
    const { DialogueDucker } = await import('./js/ducker.js');
    const sr = 48000;
    const n = sr;                                  // 1 s

    // render a stereo signal through the ducker at a given level and return output RMS (dB)
    async function level(make, duck) {
      const ctx = new OfflineAudioContext(2, n, sr);
      const buf = ctx.createBuffer(2, n, sr);
      const [L, R] = [buf.getChannelData(0), buf.getChannelData(1)];
      for (let i = 0; i < n; i++) { const [l, rr] = make(i / sr); L[i] = l; R[i] = rr; }
      const src = ctx.createBufferSource();
      src.buffer = buf;
      const d = new DialogueDucker(ctx);
      d.duck(duck, 0, 0.0001);
      src.connect(d.input);
      d.output.connect(ctx.destination);
      src.start();
      const out = await ctx.startRendering();
      let s = 0, c = 0;
      for (let ch = 0; ch < 2; ch++) {
        const x = out.getChannelData(ch);
        for (let i = sr / 4; i < n; i++) { s += x[i] * x[i]; c++; }     // skip the filter settling time
      }
      return 10 * Math.log10(s / c + 1e-12);
    }
    const sin = (f, t) => Math.sin(2 * Math.PI * f * t) * 0.3;
    const cases = {
      voice: (t) => [sin(1000, t), sin(1000, t)],              // centred 1 kHz: dialogue
      bass: (t) => [sin(80, t), sin(80, t)],                   // centred bass line / drums
      hihat: (t) => [sin(9000, t), sin(9000, t)],              // centred cymbals / sparkle
      wideMusic: (t) => [sin(1000, t), -sin(1000, t)],         // strings/synths spread wide
    };
    const drop = {};
    for (const [k, make] of Object.entries(cases)) drop[k] = (await level(make, 1)) - (await level(make, 0.25));
    return drop;
  });
  console.log('dB lowered while English speaks:', JSON.stringify(Object.fromEntries(Object.entries(r).map(([k, v]) => [k, +v.toFixed(1)]))));
  expect(r.voice).toBeGreaterThan(12);         // Japanese dialogue gets out of the way
  expect(r.bass).toBeLessThan(1.5);            // soundtrack body intact
  expect(r.hihat).toBeLessThan(2);
  expect(Math.abs(r.wideMusic)).toBeLessThan(0.5);
  await app.close();
});
