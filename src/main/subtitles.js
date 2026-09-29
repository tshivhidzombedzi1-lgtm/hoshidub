// Parses the subtitle files streaming sites send the player (ASS/SSA, WebVTT, SRT) into spoken dialogue lines.
// Signs, song lyrics and positioned typesetting are dropped: only what a character says gets voiced.

const NON_DIALOGUE_STYLE = /\b(signs?|songs?|op|ed|opening|ending|kara(oke)?|titles?|typeset(ting)?|notes?|lyrics?|insert)\b/i;

function clean(text) {
  return text
    .replace(/\{[^}]*\}/g, '')          // ASS override tags {\i1\pos(..)}
    .replace(/<[^>]+>/g, '')            // VTT/SRT markup
    .replace(/\\[Nn]|\\h/g, ' ')
    .replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&nbsp;/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function assTime(s) {
  const m = s.trim().match(/^(\d+):(\d{1,2}):(\d{1,2})[.:](\d{1,3})$/);
  if (!m) return NaN;
  const frac = Number(m[4]) / 10 ** m[4].length;
  return Number(m[1]) * 3600 + Number(m[2]) * 60 + Number(m[3]) + frac;
}

function cueTime(s) {
  const m = s.trim().match(/^(?:(\d+):)?(\d{1,2}):(\d{2})[.,](\d{1,3})$/);
  if (!m) return NaN;
  return Number(m[1] || 0) * 3600 + Number(m[2]) * 60 + Number(m[3]) + Number(m[4]) / 10 ** m[4].length;
}

function parseAss(src) {
  const lines = [];
  let format = null;
  let inEvents = false;
  for (const raw of src.split(/\r?\n/)) {
    const line = raw.trim();
    if (/^\[.*\]$/.test(line)) { inEvents = /^\[events\]$/i.test(line); continue; }
    if (!inEvents) continue;
    if (/^format:/i.test(line)) { format = line.slice(7).split(',').map((f) => f.trim().toLowerCase()); continue; }
    if (!/^dialogue:/i.test(line) || !format) continue;
    const body = line.slice(line.indexOf(':') + 1);
    const parts = [];
    let rest = body;
    for (let i = 0; i < format.length - 1; i++) {    // the Text field may itself contain commas
      const at = rest.indexOf(',');
      parts.push(rest.slice(0, at));
      rest = rest.slice(at + 1);
    }
    parts.push(rest);
    const f = Object.fromEntries(format.map((k, i) => [k, (parts[i] || '').trim()]));
    const rawText = f.text || '';
    if (NON_DIALOGUE_STYLE.test(f.style || '') || /\\(pos|move|org)\s*\(/.test(rawText)) continue;
    const text = clean(rawText);
    const start = assTime(f.start || '');
    const end = assTime(f.end || '');
    if (text && start < end) lines.push({ start, end, text, speaker: f.name || '' });
  }
  return lines;
}

function parseCues(src) {
  const lines = [];
  const blocks = src.replace(/\r/g, '').split(/\n{2,}/);
  for (const block of blocks) {
    const rows = block.split('\n');
    const i = rows.findIndex((r) => r.includes('-->'));
    if (i < 0) continue;
    const [a, b] = rows[i].split('-->');
    const start = cueTime(a);
    const end = cueTime(b.trim().split(/\s+/)[0]);
    const text = clean(rows.slice(i + 1).join(' '));
    if (text && start < end) lines.push({ start, end, text, speaker: '' });
  }
  return lines;
}

function detectFormat(src, url = '') {
  if (/\[script info\]|\[events\]/i.test(src) || /\.(ass|ssa)(\?|$)/i.test(url)) return 'ass';
  if (/^﻿?WEBVTT/.test(src) || /\.vtt(\?|$)/i.test(url)) return 'vtt';
  if (/-->/.test(src)) return 'srt';
  return null;
}

// Share of letters that are Latin: English subtitles are ~100%, Japanese ones near 0.
function latinShare(lines) {
  const s = lines.map((l) => l.text).join(' ');
  const letters = s.match(/\p{L}/gu) || [];
  if (!letters.length) return 0;
  return letters.filter((c) => /[A-Za-z]/.test(c)).length / letters.length;
}

function parse(src, url = '') {
  const fmt = detectFormat(src, url);
  if (!fmt) return null;
  const lines = (fmt === 'ass' ? parseAss(src) : parseCues(src)).sort((a, b) => a.start - b.start);
  return { format: fmt, lines, english: lines.length > 0 && latinShare(lines) > 0.85 && /\b(the|you|i|and|to)\b/i.test(lines.map((l) => l.text).join(' ')) };
}

function looksLikeSubtitles(url, contentType = '') {
  return /\.(ass|ssa|vtt|srt)(\?|$)/i.test(url) || /(text\/x-ssa|text\/x-ass|text\/vtt|application\/x-subrip)/i.test(contentType);
}

// Players get their subtitle list inside a JSON response (e.g. {"subtitles":{"en-US":{"url":"…/x.ass"}}}).
// Walk any JSON and return subtitle file URLs, English first.
const SUB_URL = /^https?:\/\/[^\s"]+\.(ass|ssa|vtt|srt)(\?[^\s"]*)?$/i;
const ENGLISH_KEY = /(^|[^a-z])en([-_]?(us|gb))?([^a-z]|$)/i;

function findSubtitleUrls(json) {
  let data;
  try { data = typeof json === 'string' ? JSON.parse(json) : json; } catch { return []; }
  const found = [];
  const walk = (node, trail) => {
    if (typeof node === 'string') {
      const t = trail.join('.');
      // a subtitle file by extension, or any URL filed under a subtitles/captions key (not burned-in video)
      if (SUB_URL.test(node) || (/^https?:\/\//.test(node) && /subtitle|caption/i.test(t) && !/hard/i.test(t))) {
        found.push({ url: node, trail: t });
      }
      return;
    }
    if (!node || typeof node !== 'object') return;
    for (const [k, v] of Object.entries(node)) walk(v, [...trail, k]);
  };
  walk(data, []);
  const english = (f) => ENGLISH_KEY.test(f.trail) || ENGLISH_KEY.test(f.url.split('?')[0].split('/').pop());
  const unique = [...new Map(found.map((f) => [f.url, f])).values()];
  return unique.sort((a, b) => english(b) - english(a)).map((f) => ({ ...f, english: english(f) }));
}

module.exports = { parse, looksLikeSubtitles, clean, findSubtitleUrls };
