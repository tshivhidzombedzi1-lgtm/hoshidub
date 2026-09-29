const test = require('node:test');
const assert = require('node:assert');
const { parse, looksLikeSubtitles } = require('../../src/main/subtitles');

const ASS = `[Script Info]
Title: Episode 1
ScriptType: v4.00+

[V4+ Styles]
Format: Name, Fontname, Fontsize
Style: Default,Arial,20

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
Dialogue: 0,0:00:01.50,0:00:03.20,Default,Keita,0,0,0,,Who are you? What are you doing here?
Dialogue: 0,0:00:04.00,0:00:06.10,Default,,0,0,0,,{\\i1}We came to protect the village,\\Nplease believe us.{\\i0}
Dialogue: 0,0:00:05.00,0:00:09.00,Signs,,0,0,0,,{\\an8}VILLAGE OF KONOHA
Dialogue: 0,0:00:07.00,0:00:08.00,Default,,0,0,0,,{\\pos(320,50)}Bakery
Dialogue: 0,0:01:30.00,0:01:34.00,OP-English,,0,0,0,,Fly away into the sky
Dialogue: 0,0:00:10.00,0:00:12.50,Italics,,0,0,0,,Hurry, before night falls!
`;

test('ASS: keeps dialogue with commas and line breaks, drops signs, typesetting and songs', () => {
  const r = parse(ASS, 'https://cdn.example/ep1/en-US.ass');
  assert.equal(r.format, 'ass');
  assert.equal(r.english, true);
  assert.deepEqual(r.lines.map((l) => l.text), [
    'Who are you? What are you doing here?',
    'We came to protect the village, please believe us.',
    'Hurry, before night falls!',
  ]);
  assert.equal(r.lines[0].start, 1.5);
  assert.equal(r.lines[0].end, 3.2);
  assert.equal(r.lines[0].speaker, 'Keita');
});

test('WebVTT with hours, markup and cue settings', () => {
  const vtt = `WEBVTT

1
00:00:01.000 --> 00:00:02.500 align:center
<i>Where is everyone?</i>

00:01:02.250 --> 00:01:04.000
Let's go <b>together</b>!`;
  const r = parse(vtt);
  assert.equal(r.format, 'vtt');
  assert.deepEqual(r.lines.map((l) => [l.start, l.text]), [[1, 'Where is everyone?'], [62.25, "Let's go together!"]]);
});

test('SRT with comma decimals', () => {
  const srt = `1\n00:00:05,500 --> 00:00:07,000\nThat's a lie, isn't it?\n\n2\n00:00:08,000 --> 00:00:09,000\nI understand.`;
  const r = parse(srt);
  assert.equal(r.format, 'srt');
  assert.equal(r.lines[0].start, 5.5);
  assert.equal(r.lines.length, 2);
});

test('Japanese subtitles are not mistaken for English', () => {
  const r = parse('WEBVTT\n\n00:00:01.000 --> 00:00:02.000\nお前は誰だ？\n\n00:00:03.000 --> 00:00:04.000\n村を守るために来ました。');
  assert.equal(r.english, false);
});

test('recognises subtitle requests by URL or content type', () => {
  assert.ok(looksLikeSubtitles('https://x.test/subs/en-US.ass?sig=1'));
  assert.ok(looksLikeSubtitles('https://x.test/track', 'text/vtt; charset=utf-8'));
  assert.ok(!looksLikeSubtitles('https://x.test/video.mp4', 'video/mp4'));
  assert.equal(parse('<html>not subtitles</html>'), null);
});

test('finds English subtitle URLs inside a player JSON response', () => {
  const { findSubtitleUrls } = require('../../src/main/subtitles');
  const play = JSON.stringify({
    url: 'https://cdn.test/manifest.mpd',
    hardSubs: { 'es-419': { url: 'https://cdn.test/hard/es.mpd' } },
    subtitles: {
      'ja-JP': { format: 'ass', url: 'https://cdn.test/subs/ja-JP.ass?sig=1' },
      'en-US': { format: 'ass', url: 'https://cdn.test/subs/abc123.ass?sig=2' },
      'none': { format: null, url: null },
    },
  });
  const got = findSubtitleUrls(play);
  assert.equal(got.length, 2);
  assert.equal(got[0].url, 'https://cdn.test/subs/abc123.ass?sig=2');
  assert.equal(got[0].english, true);
  assert.equal(got[1].english, false);
  assert.deepEqual(findSubtitleUrls('not json'), []);
});
