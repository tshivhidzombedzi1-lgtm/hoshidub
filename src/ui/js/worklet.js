// Runs on the audio thread: mixes the player's audio to mono, resamples to 16 kHz, and posts 100 ms chunks.
class PcmTap extends AudioWorkletProcessor {
  constructor() {
    super();
    this.ratio = sampleRate / 16000;
    this.pos = 0;                      // fractional read position into the incoming stream
    this.prev = 0;                     // last sample of the previous block, for interpolation
    this.out = new Float32Array(1600);
    this.n = 0;
  }

  process(inputs) {
    const input = inputs[0];
    if (!input || input.length === 0 || input[0].length === 0) return true;
    const len = input[0].length;
    const mono = new Float32Array(len);
    for (const ch of input) for (let i = 0; i < len; i++) mono[i] += ch[i] / input.length;

    // box-filter + linear interpolation: cheap anti-aliasing that is plenty for speech recognition
    while (this.pos < len) {
      const i = Math.floor(this.pos);
      const f = this.pos - i;
      const a = i === 0 ? this.prev : mono[i - 1];
      const b = mono[i];
      this.out[this.n++] = a + (b - a) * f;
      if (this.n === this.out.length) {
        this.port.postMessage(this.out.buffer, [this.out.buffer]);
        this.out = new Float32Array(1600);
        this.n = 0;
      }
      this.pos += this.ratio;
    }
    this.pos -= len;
    this.prev = mono[len - 1];
    return true;
  }
}

registerProcessor('pcm-tap', PcmTap);
