# Apex Drawdown Zero — V11.80 → V12.00

Distillation, then new strategies. One new strategy shipped; two were rejected.

**Test rig (unchanged from V11):** MT5 Strategy Tester, RoboForex-Pro, H1,
1-minute OHLC, $10,000, 1:100. Two windows:

- **in-sample** 2026.01.05 → 2026.09.01
- **out-of-sample** 2025.01.06 → 2026.01.05

Reports for the shipped defaults are in `backtests/V12.00_*`.

---

## Why this pass

The V11.80 check on recent months showed September 2026 (to the 23rd) flat
to slightly down on gold: −54 in the default mode, −165 in growth mode, on
12–13 trades. You asked for extra strategies to fill the gaps and more
trades. Three weeks and a dozen trades are not evidence on their own, so every
change below was judged on the two full windows, not on September.

---

## 1. Distillation — dead code removed, behaviour unchanged

Every module V11 measured and switched off is now **removed**, not just
defaulted off:

| removed | why (V11 measurement) |
|---|---|
| signal scoring + regime filter | flipped EURUSD +634 → −322 |
| chandelier trail | −657 |
| time stop | −1 846 |
| profit-lock ladder | −1 102 |
| legacy R-trail | cut winners (v7.30) |
| pyramiding | lost out of sample |
| range fade (S2) | fired once in 8 months |
| failed-break reversal (S3) | −648, 51% win rate |
| risk de-escalation | −118 |
| loss-streak cooldown | net cost |
| Friday entry cutoff | −253 |

3 360 → ~2 600 lines before the new strategies went in.

**Parity: with the new strategies off, V12 reproduces V11.80 to the cent in
all 8 checks** — XAUUSD discipline 2 956.32 / 1 369.77, EURUSD 633.54 /
1 295.84, high-frequency 1 963.40 / 1 446.22, growth 10 590.90 / 4 602.24.

> Removed inputs: `.set` files saved from V11 that reference them will load
> with those lines ignored. Nothing that was ON by default was removed.

---

## 2. Three new strategies

All built to trade conditions the opening-range breakout sits out:

- **S4 trend pullback** — trend = price and EMA20 on one side of EMA200, EMA20
  sloping that way; price dipped to EMA20 within 5 bars; enter on the bar that
  closes beyond the previous bar's extreme. Stop 0.5 ATR beyond the dip, 2R.
- **S5 prior-day breakout** — first H1 close beyond yesterday's high/low with
  a strong body and EMA bias. 1.5 ATR stop, 2R.
- **S6 mean reversion** — RSI(2) below 10 in an uptrend (above 90 in a
  downtrend), 1.5 ATR stop, 1.0 ATR target, held to either.

Parameters were chosen up front, not tuned.

### First attempt: sharing the core's position slot — failed, and why

The EA held one position at a time. Every new strategy **made money on its
own trades but crowded out core trades**:

| 2025 OOS, XAUUSD | core trades | core P/L | new-strategy P/L | total |
|---|---:|---:|---:|---:|
| core only | 142 | 1 370 | — | 1 370 |
| + trend pullback | 106 | 264 | +1 486 | 1 750 |
| + mean reversion | 122 | 517 | +1 359 | 1 876 |

In 2026 the trend pullback earned +564 itself while costing the core −968.

### The fix: strategy lanes

Each new strategy now trades in **its own lane**: its own magic number
(`MagicNumber + id`), its own position, its own once-per-day budget. A lane
win does not trigger the core's StopAfterWin. The **firewall, day P/L,
drawdown cap and flatten cover every lane together.** The core with lanes
enabled still reproduces V11.80 to the cent.

### Results in lanes (XAUUSD, default mode)

| | 2026 net | PF | bal DD | 2025 OOS net | PF | bal DD |
|---|---:|---:|---:|---:|---:|---:|
| core only | 2 956 | 2.60 | 1.90% | 1 370 | 1.30 | 5.67% |
| **+ trend pullback** | **4 336** | 2.14 | 4.92% | **4 410** | **1.55** | **4.67%** |
| + prior-day breakout | 3 376 | 2.08 | 3.98% | 2 816 | 1.32 | 4.90% |
| + mean reversion | 1 704 | 1.31 | 6.14% | 2 448 | 1.24 | 6.74% |
| + TPB + PDB | 4 538 | 1.88 | 4.28% | 6 688 | 1.50 | 7.58% |

### Robustness — neighbours of the chosen settings

| variant | 2026 | 2025 OOS |
|---|---:|---:|
| **TPB as shipped** | **4 336** | **4 410** |
| fast EMA 15 | 3 884 | 3 218 |
| fast EMA 30 | 2 814 | 3 029 |
| RR 1.5 | 4 165 | 4 544 |
| RR 2.5 | 4 502 | 4 737 |
| trend EMA 100 | 4 193 | 3 963 |
| PDB stop 1.0 ATR | 3 010 | 1 940 (DD 9.7%) |
| **PDB as tested (1.5)** | 3 376 | 2 816 |
| PDB stop 2.0 ATR | 2 794 | 1 589 |

**Trend pullback is a plateau**: all 5 neighbours are profitable in both
windows, and 9 of 10 beat the core-only baseline. **Prior-day breakout is a
peak**: both neighbours fall away, one below the baseline.

### Symbol and mode transfer

| | 2026 | 2025 OOS | verdict |
|---|---:|---:|---|
| EURUSD core only | 634 | 1 296 | |
| EURUSD + TPB | **−333** | 3 022 | one good window, one losing → off on FX |
| EURUSD + PDB | 541 | **−744** (hit the 10% DD halt) | rejected |
| XAUUSD HF mode | 1 963 | 1 446 | |
| XAUUSD HF + TPB | **1 026** | 2 549 | mixed → off in HF |
| XAUUSD growth 3% | +106% | +46% | |
| **XAUUSD growth 3% + TPB** | **+191%** | **+116%** | ships |

---

## What shipped

`TrendPullback = LANE_AUTO` (default): **on for metals in DISCIPLINE and
AGGRESSIVE_GROWTH, off on FX and in HIGH_FREQUENCY.** `LANE_ALWAYS` /
`LANE_OFF` are available. `UsePriorDayBreak` and `UseMeanReversion` stay in
the code, **off**, with their measurements in the input comments.

Verified with nothing overridden but `TradingMode`:

| XAUUSD | 2026 | 2025 OOS |
|---|---:|---:|
| DISCIPLINE net | 2 956 → **4 336** | 1 370 → **4 410** |
| DISCIPLINE PF | 2.60 → 2.14 | 1.30 → **1.55** |
| DISCIPLINE bal DD | 1.90% → 4.92% | 5.67% → **4.67%** |
| DISCIPLINE Sharpe | 6.60 → 5.60 | 2.20 → **3.50** |
| GROWTH 3% final balance | 20 591 → **29 106** | 14 602 → **21 627** |
| GROWTH 3% bal / eq DD | 7.1 / 10.2% → 10.6 / 15.6% | 16.4 / 19.1% → 20.2 / 22.9% |

EURUSD and HIGH_FREQUENCY: identical to V11.80 to the cent.

Trade count on gold, default mode: ~14/month → **~23–28/month**.

## Recent months — the original question

| XAUUSD | V11.80 | **V12.00** |
|---|---:|---:|
| DISCIPLINE Aug 2026 | +470 (13 trades) | **+510** (24 trades) |
| DISCIPLINE Sep 1–23 | −54 (12) | −54 (18) |
| GROWTH 3% Aug 2026 | +1 442 | **+1 581** |
| GROWTH 3% Sep 1–23 | −165 | −181 (bal DD 10.0%) |

**V12 does not fix September.** The trend lane added trades in September and
they roughly broke even; that month is choppy with no trend to pull back into.
The case for V12 rests on the two full windows, where it improves both — not
on three weeks.

---

## Costs and caveats — read before shipping

1. **Two positions can be open at once** (core + trend lane). Worst-case open
   risk doubles: 2% in the default mode, **6% in growth mode**. The firewall
   caps are unchanged and apply to the total. In-sample drawdown rose
   (1.90% → 4.92% default; 10.2% → 15.6% equity in growth); out-of-sample it
   fell in the default mode.
2. **In-sample profit factor fell** (2.60 → 2.14). The new lane's trades are
   lower quality than the core's; the gain comes from volume.
3. **Growth mode peak drawdown is now 20.2% balance / 22.9% equity** in the thin
   year. Under the 35% cap, but a real number for a customer to sit through.
4. Same limits as V11: one broker, 1-minute OHLC, modelled spread, two
   windows. EURJPY untested. Demo-forward-test before live.
5. The per-strategy P/L split used in section 2 is only valid for the
   shared-slot runs; with lanes, positions overlap and the report cannot
   attribute them. The lane results are judged on account totals.

---

# v12.10 — Ballistic Sniper lane: built, tested, shipped OFF

You asked for a "ballistic" strategy with sniper entries that beats the
previous versions on everything.

**The strategy** (own lane, `BallisticSniper`):

1. **Compression** — Bollinger(20,2) inside Keltner(EMA20 ± 1.5 ATR) on at
   least 5 of the last 10 H1 bars (TTM-squeeze idea).
2. **Ignition** — one bar ≥ 1.2 ATR wide, strong body, closing outside the
   band, with the EMA bias.
3. **Snipe** — a limit order at the 50% retrace of the ignition bar, stop
   0.1 ATR beyond its base, 3R target, cancelled after 4 bars unfilled.

**Result — every variant tried (3), XAUUSD default mode:**

| | 2026 net | PF | 2025 OOS net | PF | OOS bal DD |
|---|---:|---:|---:|---:|---:|
| **V12.00 (shipped)** | 4 336 | **2.14** | **4 410** | **1.55** | **4.67%** |
| + sniper, core exits, 3R | 4 481 | 2.00 | 3 977 | 1.44 | 6.82% |
| + sniper, hold to SL/TP, 3R | 4 686 | 1.96 | 4 275 | 1.43 | 5.98% |
| + sniper, hold to SL/TP, 2R | 4 193 | 1.87 | 3 539 | 1.37 | 6.09% |

Other checks (core-exit version): growth 3% 2026 **19 106 → 17 401**, 2025
11 627 → 16 055; EURUSD 2026 **634 → −197**.

**Recent months (hold/3R version):**

| XAUUSD | V11.80 | V12.00 | V12 + sniper |
|---|---:|---:|---:|
| default, Aug 2026 | +470 | +510 | +796 |
| default, Sep 1–23 | −54 | −54 | **−232** |
| growth 3%, Aug 2026 | +1 442 | +1 581 | +2 610 |
| growth 3%, Sep 1–23 | −165 | −181 | **−335** |

**Verdict: rejected.** It adds in-sample profit and a strong August, and
loses the out-of-sample year, profit factor, drawdown and September. That is
the same one-good-window pattern that got NY-on-gold restricted in v11.60.
Stretching it with more parameter variants until one wins both windows would
be curve-fitting, so it stopped at three.

The code stays in (`BallisticSniper = LANE_OFF`, `BALManaged`, `BAL*`
inputs). With it off, v12.10 reproduces v12.00 to the cent
(4 336.43 / 4 409.56).

---

# v12.20 — TDI + RSI divergences: ported, tested, shipped OFF

The TradingView study you supplied (TDI by LazyBear / JustUncleL, extended by
ZyadaCharts) was ported to MQL5 line for line: RSI(14), mid = SMA(RSI,34),
bands at ±1.6185 population stdev, green = SMA(RSI,2), red = SMA(RSI,7);
LONG = green crosses above red with red > mid and > 50 (short mirrored);
regular divergences on 5/5 RSI pivots, previous pivot 5–60 bars back.

Three uses, fixed before testing, XAUUSD default mode:

| | 2026 net | PF | bal DD | 2025 OOS net | PF | Aug | Sep 1–23 |
|---|---:|---:|---:|---:|---:|---:|---:|
| **V12 shipped** | **4 336** | **2.14** | 4.92% | **4 410** | **1.55** | +510 | −54 |
| TDI signal, own lane | 2 328 | 1.75 | 8.84% (eq 10.0% → halt) | 3 047 | 1.22 | +240 | −343 |
| TDI signal + divergence | 4 214 | 2.00 | 5.48% | 4 311 | 1.52 | +558 | −54 |
| TDI as trend-pullback filter | 3 063 | 1.88 | 4.52% | 3 543 | 1.53 | +512 | −92 |

- **The raw TDI signal** fires ~40 times a month on H1 gold and loses edge
  after costs; in 2026 it drove equity drawdown to the 10% cap and the EA
  halted itself.
- **Requiring a divergence** makes it so rare (~1 trade/month) that it barely
  moves anything, and slightly negative in both windows.
- **As a filter** it removed good trend-pullback trades along with bad ones:
  −1 273 in 2026, −867 out of sample.

**Verdict: none beats V12 in either full window → all shipped OFF**
(`TDISignal = LANE_OFF`, `TDIRequireDivergence`, `TPBUseTDIFilter`). With
them off, v12.20 reproduces v12.00 to the cent (4 336.43 / 4 409.56).

---

# v12.30 — "More profit": the levers, measured

| lever | 2026 | 2025 OOS | verdict |
|---|---:|---:|---|
| V12 default mode (1%) | 4 336 | 4 410 | reference |
| trend pullback 2 / day | 4 377 | 3 620 | rejected — setup rarely repeats; OOS worse |
| trend pullback 3 / day | 4 377 | 3 320 | rejected |
| default mode at 1.5% risk | 7 097 | 3 540 | **hits the 10% DD halt** out of sample |
| default mode at 2% risk | 1 854 | 750 | halts within weeks |

With two lanes able to hold positions together, the default mode's 10% cap
binds as soon as risk rises. **Size belongs in growth mode**, which widens the
caps for exactly this.

## V12 growth-mode frontier (XAUUSD, $10k)

| risk | 2026 | 2025 OOS | 2025 bal DD | 2025 eq DD |
|---:|---:|---:|---:|---:|
| 2% | +89% | +91% | 14.1% | 16.2% |
| **3% (default)** | **+191%** | **+116%** | **20.2%** | **22.9%** |
| 4% | +282% | +117% | 26.6% | 28.5% |
| 5% | +1% | +27% | 33.8% | 35.3% → halted |

**3% stays the default.** 4% adds nothing out of sample (+117% vs +116%) for
6 more points of drawdown. 5% self-terminates on the 35% cap — the same
lesson as the v11.80 frontier. 2% is the conservative alternative: 91% of the
3% out-of-sample return for 70% of the drawdown.

## Silver

| XAGUSD, default mode | 2026 | 2025 OOS |
|---|---:|---:|
| core only | −603 | −933 |
| V12 (core + trend lane) | −258 | −894 |

Both hit the 10% drawdown halt. The AUTO lanes (trend pullback, and the
off-by-default sniper / TDI) are now **gold-only** instead of metal-wide, and
the EA prints a warning on silver. Gold results unchanged to the cent
(4 336.43 / 4 409.56 default, 19 105.76 / 11 627.12 growth).

---

# FTMO 2-step test (v12.30)

**Method.** Added a tester-only daily equity log (`DailyLogFile`): each day's
start balance, **lowest intraday equity including floating loss**, end balance
and entries. One continuous XAUUSD run 2025-01-06 → 2026-09-23 per risk level,
then `backtests/ftmo_sim.py` replays an FTMO challenge from **every trading
day** (443 starts): +10% then +5%, daily loss = equity ≥ day-start balance −
5% of initial, max loss = equity ≥ 90% of initial, ≥ 4 trading days per
phase. The EA's trailing 10% DD halt was off in these runs so a halt would not
freeze later start dates; FTMO's limits are applied by the simulator.

| V12, XAUUSD | passed both / finished | failures | median days (P1 + P2) | worst day |
|---|---:|---|---:|---:|
| **1% risk, 3% daily cap** | **368 / 368 (100%)** | none | 71 + 45 ≈ 111 | −2.46% |
| **1.5% risk, 3.5% daily cap** | **382 / 385 (99%)** | 3 max-loss | 43 + 27 ≈ 74 | −4.00% |
| 2% risk, 4% daily cap | 288 / 404 (71%) | 116 (35 daily-loss) | 31 + 15 ≈ 56 | **−5.19%** |

Presets: `presets/ApexV12_FTMO_Safe_1pct.set`, `presets/ApexV12_FTMO_Fast_1.5pct.set`.

**Caveats.** FTMO's day resets at midnight CE(S)T, one hour before this
server's midnight. FTMO commission and real spreads are not modelled
(RoboForex-Pro spread, 1-minute OHLC). Starts that neither passed nor failed
before the data ended are excluded from the %; at 1% that is the most recent
75, none of which had failed. Part of the period (2026) is the in-sample
window. Verify the current FTMO rulebook before buying a challenge.

---

# v12.40 → v12.46 — FTMO mode

Full iteration log with every version's own source file: `versions/VERSIONS.md`.

`TradingMode = MODE_FTMO`: target lock (closes and stops at the phase target,
checked on the **closed balance**), FTMO's static and daily floors with a 1%
buffer, room-based sizing (a trade risks ≤ room-to-floor / 2.5), minimum
trading days, Templar Cavalry dashboard.

**Real ticks, phase 1 (+10%), 12 start dates Jan 2025 – Aug 2026:
12/12 passed, 0 failed, median 38 days, worst day −4.06%, lowest equity 95.0%.**

| step | finding |
|---|---|
| V12.42 stop-order entries | rejected on real ticks: 19 d slower, a −4.81% day from slippage |
| V12.43 | **bug fixed**: commission on the closing deals left the balance at 10 986 on a 11 000 target while the EA considered itself done |
| V12.44 | room divisor 3 → 2.5: median 53 d → 38 d on real ticks, 0 failures |

Presets: `presets/ApexV12_FTMO_Mode_Phase1.set`, `_Phase2.set`, `_Phase1_Safe.set`.
Non-FTMO modes verified unchanged to the cent.
