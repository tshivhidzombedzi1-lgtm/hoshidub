import test from 'node:test';
import assert from 'node:assert';
import { SubtitleSync } from '../../src/ui/js/subsync.js';

const lines = [
  { start: 1.0, end: 3.0, text: 'Who are you?' },
  { start: 4.0, end: 6.0, text: 'We came to protect the village.' },
  { start: 7.0, end: 8.0, text: 'Hurry!' },
  { start: 20.0, end: 22.0, text: 'Let us go together.' },
];

function run(states) {
  const said = [];
  const s = new SubtitleSync({ lines, getState: null, onLine: (i, text, dur) => said.push([i, dur]) });
  for (const st of states) s.advance(st);
  return said;
}

test('speaks each line once as playback passes it', () => {
  const ts = [];
  for (let t = 0; t <= 9; t += 0.12) ts.push({ t, paused: false });
  assert.deepEqual(run(ts).map(([i]) => i), [0, 1, 2]);
});

test('nothing while paused', () => {
  assert.deepEqual(run([{ t: 0.9, paused: true }, { t: 1.1, paused: true }, { t: 1.2, paused: true }]), []);
});

test('rewinding replays the line; seeking forward does not burst-play skipped lines', () => {
  const said = run([
    { t: 0.9, paused: false }, { t: 1.05, paused: false },    // line 0
    { t: 0.5, paused: false }, { t: 1.1, paused: false },     // rewind → line 0 again
    { t: 19.9, paused: false }, { t: 20.1, paused: false },   // jump ahead past 1 and 2 → only line 3
  ]);
  assert.deepEqual(said.map(([i]) => i), [0, 0, 3]);
});

test('joining mid-line does not start a line that is nearly over', () => {
  assert.deepEqual(run([{ t: 5.5, paused: false }, { t: 5.6, paused: false }]), []);
});

test('duration follows playback speed', () => {
  const said = run([{ t: 0.9, paused: false, rate: 2 }, { t: 1.1, paused: false, rate: 2 }]);
  assert.deepEqual(said, [[0, 1]]);
});

test('announces upcoming lines once, ahead of time, so audio can be rendered early', () => {
  const prepared = [];
  const s = new SubtitleSync({ lines, getState: null, onLine: () => {}, onPrepare: (i) => prepared.push(i), lookahead: 6 });
  s.advance({ t: 0, paused: true });            // even while paused: get ready
  assert.deepEqual(prepared, [0, 1]);
  for (let t = 0; t < 9; t += 0.2) s.advance({ t, paused: false });
  assert.deepEqual(prepared, [0, 1, 2]);         // 20 s line is not yet within 6 s
});
