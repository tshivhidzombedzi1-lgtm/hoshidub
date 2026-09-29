// Dialogue ducker: while English speaks, pull the Japanese *voices* down and leave music and effects alone.
//
// Anime dialogue is mixed to the centre and lives in the voice band; music and effects are wide and full-range.
// So we split stereo into mid (L+R) and side (L-R), cut only the voice band of the mid with two broad peaking
// filters, and rebuild L/R. Bass, highs, and anything wide in the stereo field pass through untouched.

const VOICE_BANDS = [
  { frequency: 700, Q: 0.8 },     // body of the voice
  { frequency: 2400, Q: 0.9 },    // consonants and presence
];

export class DialogueDucker {
  constructor(ctx) {
    this.ctx = ctx;
    this.input = ctx.createGain();
    this.output = ctx.createGain();
    this.input.channelCount = 2;
    this.input.channelCountMode = 'explicit';

    const split = ctx.createChannelSplitter(2);
    const merge = ctx.createChannelMerger(2);
    this.input.connect(split);

    const gain = (v) => { const g = ctx.createGain(); g.gain.value = v; return g; };
    // mid = (L + R) / 2, side = (L - R) / 2
    const mid = ctx.createGain();
    const side = ctx.createGain();
    split.connect(gain(0.5), 0).connect(mid);
    split.connect(gain(0.5), 1).connect(mid);
    split.connect(gain(0.5), 0).connect(side);
    split.connect(gain(-0.5), 1).connect(side);

    // the only thing that ever changes: how deep the voice band of the mid is cut
    this.filters = VOICE_BANDS.map(({ frequency, Q }) => {
      const f = ctx.createBiquadFilter();
      f.type = 'peaking';
      f.frequency.value = frequency;
      f.Q.value = Q;
      f.gain.value = 0;
      return f;
    });
    let node = mid;
    for (const f of this.filters) { node.connect(f); node = f; }

    // L = mid + side, R = mid - side
    const left = ctx.createGain();
    const right = ctx.createGain();
    node.connect(left);
    node.connect(right);
    side.connect(left);
    side.connect(gain(-1)).connect(right);
    left.connect(merge, 0, 0);
    right.connect(merge, 0, 1);
    merge.connect(this.output);
  }

  // level: how loud the Japanese voices stay while English speaks (0..1, 1 = untouched)
  duck(level, when = this.ctx.currentTime, timeConstant = 0.03) {
    // two overlapping bands: scale so the slider value is roughly how loud the voices end up
    const db = level >= 0.999 ? 0 : Math.max(-30, 1.3 * 20 * Math.log10(Math.max(level, 0.03)));
    for (const f of this.filters) f.gain.setTargetAtTime(db, when, timeConstant);
  }
}
