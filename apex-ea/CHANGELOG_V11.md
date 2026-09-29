# Apex Drawdown Zero — V9.20 → V11.80

Two passes: a full strategy enhancement (v11.50), then a measured pass that
reversed most of it (v11.51), then a giveback study and three new strategies
of which one survived (v11.60).

**Test rig for every number below:** MT5 Strategy Tester, RoboForex-Pro, H1,
1-minute OHLC, $10,000, 1:100, 1% risk. Two windows:

- **in-sample** 2026.01.05 → 2026.09.01 (tuning window)
- **out-of-sample** 2025.01.06 → 2026.01.05 (never used for any decision)

Reports for the headline runs are in `backtests/`.

---

## Shipped result — v11.60 vs v9.20

| Symbol / window | metric | v9.20 | **v11.60** |
|---|---|---:|---:|
| **XAUUSD** in-sample | net profit | 3 139 | 2 956 |
| | profit factor | 2.65 | 2.60 |
| | **max drawdown** | 2.29% | **1.90%** |
| | win rate | 67.5% | **76.2%** |
| | recovery / Sharpe | 6.69 / 6.39 | **7.73 / 6.60** |
| **XAUUSD** out-of-sample | net profit | 1 443 | 1 370 |
| | **max drawdown** | 6.14% | **5.67%** |
| | win rate | 54.2% | **67.0%** |
| | recovery / Sharpe | 1.79 / 2.03 | **1.85 / 2.20** |
| **EURUSD** in-sample | net profit | **−401** | **+634** |
| | profit factor | 0.90 | **1.16** |
| | max drawdown | 12.50% | **8.10%** |
| **EURUSD** out-of-sample | net profit | +128 | **+1 296** |
| | profit factor | 1.02 | **1.22** |
| | max drawdown | 9.40% | **6.57%** |
| **GBPUSD** (symbol never used in tuning) | net profit | −1 769 | −676 |
| | max drawdown | 20.23% | **9.82%** |
| **USDJPY** (symbol never used in tuning) | net profit | −2 139 | −881 |
| | max drawdown | 21.40% | **9.42%** |

**Gold pays about 5% of net profit in both windows and buys a lower
drawdown, a higher Sharpe and a higher recovery factor.** FX improves
outright in both windows. The two symbols this EA should not be traded on
still lose money, but lose roughly half as much with half the drawdown.

---

## The giveback — measured, and deliberately not "fixed"

You observed trades going your way and then handing the profit back. That is
real and now quantified. An MFE (maximum favourable excursion) log was added
to the EA and run over the 80 in-sample gold trades:

| how far the trade ran | share of trades |
|---|---:|
| reached ≥ 0.50R | 79% |
| reached ≥ 1.00R | 50% |
| reached ≥ 1.50R | 38% |
| reached ≥ 2.00R (the target) | **0%** |

Mean MFE **1.15R**, median **1.02R**, realised average **+0.16R**. Of the 63
trades that got to 0.5R, **33 failed to reach target**.

Four fixes were built and all four were rejected on measurement (XAUUSD,
in-sample, vs the 3 139 baseline):

| attempted fix | result | verdict |
|---|---:|---|
| Profit-lock ladder (ratchet stop to 0.5R at 1.0R MFE) | **−1 102** | rejected |
| Chandelier ATR trail | **−657** | rejected |
| Time stop (close if < 0.3R after 8 bars) | **−1 846** | rejected |
| Lower RR target (1.25 / 1.50 / 1.75 / 2.00 / 2.25) | noise | rejected |

**The conclusion is that the giveback is not a defect. It is the cost of
admission for the 38% of trades that reach 2R.** Every mechanism that
tightens the exit converts large winners into small ones — in each test the
win rate went *up* while net profit went *down*. The ladder is the clearest
case: it simulated at +19R and lost 35% in the real tester, because the
simulation was path-blind. It assumed a stop at 0.5R below the peak would
only ever trigger at the end; in reality ordinary retracement takes it out
*before* the move continues to target.

On the RR sweep: 1.75 scored best (3 266) but sits between two worse
neighbours (1.50 → 2 449, 2.00 → 3 139). A non-monotone spike in a
five-point sweep is noise, not an edge, so the target stays at 2.0R.

---

## Three complementary strategies — one survived

Each was built behind its own switch and tested in isolation against a
verified-identical core.

### S1 — New York opening range — **KEPT, FX only**

A second opening range built at the NY open, traded with the same mechanism
that already works in London. Adds a setup on days the core's single slot was
already spent.

Parameter robustness (XAUUSD in-sample) shows a plateau, not a spike:
NY start 13:00 → 2 704 · **14:00 → 3 517** · 15:00 → 3 373. Only the pre-NY
13:00 start fails, which is mechanistically sensible.

**But it is gated by symbol class, and that gate is the most important
finding of this pass:**

| | in-sample | out-of-sample |
|---|---:|---:|
| XAUUSD + NY | 3 139 → **3 517** | 1 443 → **−273** |
| EURUSD + NY | −401 → **+562** | 128 → **+841** |

On gold it looked excellent in sample and then **lost money out of sample**.
One good window and one catastrophic window is not an edge. `NYSession` now
defaults to `NY_AUTO`, which runs it on FX and JPY crosses and **not** on
metals, crypto or indices. `NY_ALWAYS` is available if you disagree, and the
numbers above are why I would not.

### S2 — Compression-day range fade — **REJECTED**

Fade a narrow opening range that never breaks, back toward the midpoint.
Intended to monetise the days the core sits out entirely.

Fired **once in eight months** (+1.50). With loosened filters
(`FadeMaxBoxAtr` 2.5, edge 20%, 2 break bars tolerated) it fired more and
lost money: 3 139 → 2 663. The premise — that compression days are
identifiable in advance and mean-revert reliably — did not hold.

### S3 — Multi-bar failed breakout — **REJECTED**

Catch the failed-break reversal when it takes two or three candles rather
than the single candle the core's sweep logic requires.

3 139 → **2 492**, win rate **51%**, drawdown 2.29% → **5.15%**. Adding the
score gate at 60 changed nothing. It adds losing trades.

---

## What is ON by default, and why

| Module | Default | Evidence |
|---|---|---|
| Core opening-range breakout | ON | the v7–v9 edge, unchanged |
| Partial TP (50% at 1.0R) | **ON** | the only exit change that generalised: better drawdown in all 4 symbol-windows |
| Daily loss + max DD + equity caps | **ON** | never triggered on a healthy account — free tail insurance |
| NY session (S1) | **AUTO** | FX only; verified in 2 windows there, rejected on metals on OOS evidence |
| `MaxTradesPerDay` | 2 | only ever binds when NY is active |
| Signal scoring | **OFF** | helped XAUUSD PF but flipped EURUSD +634 → −322. Not robust across symbols |
| Regime filter | OFF | tested with scoring, same reason |
| Profit-lock ladder | OFF | −1 102 |
| Chandelier trail | OFF | −657 |
| Time stop | OFF | −1 846 |
| Range fade (S2) | OFF | never fires / loses when it does |
| Failed break (S3) | OFF | −648, 51% win rate |
| Risk de-escalation | OFF | −118 |
| Friday cutoff / weekend flatten | OFF | −253 / −572 (but see the gap note below) |

> **`FlatBeforeWeekendHour` is the one judgement call.** It costs 572 over
> eight months, so it is off. A backtest window containing no catastrophic
> weekend gap cannot price the risk it exists to cover. Set it to `21` if you
> would rather pay that premium — on gold I would consider it.

---

## Anti-overfitting controls used

This is why I think the result is real rather than fitted:

1. **Core parity verified in both windows.** With every new module off, the
   build reproduces v9.20 to the cent in in-sample (3 139.33, 80 trades) and
   out-of-sample (1 443.08, 142 trades). Any difference is attributable.
2. **Most changes were rejected.** 5 of 7 v11.50 modules, 3 of 4 giveback
   fixes and 2 of 3 new strategies were switched off on measurement.
3. **The one kept strategy is restricted by out-of-sample failure**, not
   extended by in-sample success.
4. **Two unseen symbols** (GBPUSD, USDJPY) were checked; both improved on
   drawdown and loss magnitude.
5. **Parameter plateaus, not peaks**, were required (NY start hour).
6. A **real bug** was caught this way: a position carried overnight consumed
   the day's slot in v9 but not in the refactor. It produced 8 phantom trades
   and would have invalidated every comparison. Found because parity failed.

---

## Bugs fixed

- **Overnight-position slot leak** (above) — an inherited position now
  consumes a strategy slot, as it implicitly did in v9.
- **Stats/streak double-counting on a mid-day restart** — the restart
  recovery pass and the live deal walker both counted the same deals.
- **A failed firewall close was never retried** — the halt flag was set
  before the close succeeded, so a rejected close left positions open under a
  tripped limit indefinitely. Now retried on a 30-second timer.

---

## Still to do before this goes live

1. **One broker, one model, two windows.** All runs are 1-minute OHLC on
   RoboForex-Pro. Re-run on real ticks and on a second broker.
2. **EURJPY is untested** — no local history. It is one of the three
   advertised pairs, so it needs its own verdict before release.
3. **The 2025 window is only one out-of-sample period.** A third window
   (or walk-forward) would materially strengthen the NY-on-FX conclusion.
4. **GBPUSD and USDJPY still lose.** v11.60 halves the damage; that is not
   the same as making them tradeable. Do not trade them.
5. **Demo-test.** Nothing here replaces that.

Cleanup: `MQL5/Experts/ApexBuild/` exists in both terminal data folders and
`MQL5/Profiles/Tester/ApexDrawdownZero_V11.set` caches tester inputs — delete
that .set before any run where you want compiled defaults, or the tester will
silently use the last values you tested with.

---

# v11.70 — High-frequency mode

You asked for ~100 trades a month. The default takes ~14. That gap cannot be
closed on H1 with one setup per day — there are only ~22 trading days in a
month — so it needs a lower timeframe and multiple re-entries per day.

Built as a single switch: **`TradingMode`**.

| | MODE_DISCIPLINE (default) | MODE_HIGH_FREQUENCY |
|---|---|---|
| Timeframe | H1 | M15 |
| Setups per day | 1 per strategy, max 2 | up to 30 |
| Risk per trade | 1.0% | 0.35% |
| Bias filter | on | off |
| Min box / break buffer | 1.50 / 0.20 ATR | 0.50 / 0.10 ATR |
| Body confirmation | 60% | 35% |
| Daily loss cap | 3% | 8% |
| NY session | FX only | always on |

## The frequency ladder (XAUUSD, in-sample)

| Config | Trades | /month | Net profit | PF | Max DD |
|---|---:|---:|---:|---:|---:|
| Shipped H1, 1/day | 109 | 14 | 2 956 | **2.60** | **1.90%** |
| H1, max 4/day | 142 | 18 | 1 498 | 1.44 | 3.27% |
| M30, max 8/day | 182 | 23 | 1 198 | 1.26 | 5.23% |
| M15, max 12/day | 81 | 10 | −757 | 0.72 | 9.57% |
| **M15 high-frequency** | **607** | **77** | 1 963 | 1.29 | 6.94% |

On H1 the cap stops binding at 4/day — there simply are not more setups. The
timeframe is the only real lever.

## High-frequency mode, validated

| Symbol / window | Trades | /month | Net profit | PF | Max DD |
|---|---:|---:|---:|---:|---:|
| XAUUSD 2026 in-sample | 607 | 77 | **+1 963** | 1.29 | 6.94% |
| XAUUSD 2025 **out-of-sample** | 1 119 | **93** | **+1 446** | 1.15 | 8.13% |
| EURUSD 2026 in-sample | 702 | 89 | **−838** | 0.89 | 9.77% |
| EURUSD 2025 out-of-sample | 1 068 | 89 | **−845** | 0.92 | 9.94% |

**It works on gold and it is profitable in both windows.** It loses on EURUSD
in both windows, so the EA prints a warning if you run it on a non-metal.

## What it costs you

Against the default mode on XAUUSD: profit factor **2.60 → 1.29**, max
drawdown **1.90% → 6.94%**, Sharpe **6.60 → 2.70**, expectancy per trade
**27.12 → 3.23**. In-sample net profit is *lower* than the default despite
6x the trades; out-of-sample it is higher (1 446 vs 1 370).

So the honest summary: **high-frequency mode buys you the trade count you
asked for and roughly the same money, with substantially worse risk-adjusted
numbers.** It is off by default for that reason, and switching it on is a
one-line change when you want it.

One counter-intuitive detail worth knowing: **cutting risk per trade raised
the trade count** (586 → 1 119 out-of-sample). At 1% risk the 8% daily loss
cap halts the day early and blocks later setups; at 0.35% it rarely trips.

## Parity verified

- `MODE_DISCIPLINE` reproduces v11.60 to the cent in both windows
  (2 956.32 / 1 369.77, 109 / 197 trades).
- `MODE_HIGH_FREQUENCY` reproduces the manually-configured measured run to the
  cent (1 963.40 / 1 446.22, 607 / 1 119 trades).

The v11.70 refactor moved twelve inputs behind cadence-resolved working
globals; the parity runs are what prove it changed nothing.

## Caveat

The high-frequency parameter set was chosen from a six-point ladder on one
symbol and confirmed on one out-of-sample window. That is weaker evidence than
the v11.60 defaults carry. M15 also multiplies spread and commission cost —
these runs use RoboForex-Pro's modelled spread, and a worse execution
environment will hurt a 93-trade-a-month strategy far more than a 14-trade one.
**Forward-test this on demo before trusting it.**

---

# v11.80 — Aggressive growth mode, and the honest answer on 10k → 50k

You asked for 50k from 10k. **10k → 50k is +400%.** I measured the full
risk/return frontier rather than guessing, and the answer has a sting in it.

## Yes, it hit 50k — with the safety off

XAUUSD, 2026 in-sample, 8 months, **firewall halts disabled**:

| Risk/trade | Final balance | Return | PF | Balance DD | Equity DD |
|---:|---:|---:|---:|---:|---:|
| 1% | 12,956 | +30% | 2.60 | 1.90% | 3.00% |
| 2% | 16,136 | +61% | 2.35 | 4.45% | 6.33% |
| 3% | 20,591 | +106% | 2.29 | 7.10% | 10.15% |
| 5% | 31,521 | +215% | 2.25 | 11.92% | 16.54% |
| **8%** | **58,414** | **+484%** | 2.20 | 19.09% | 25.63% |
| 12% | 123,870 | +1139% | 2.14 | 28.88% | 36.77% |

## And here is why that number is not real

The same risk levels in the **out-of-sample** year, where profit factor is
only 1.30:

| Risk/trade | Final balance | Return | Balance DD |
|---:|---:|---:|---:|
| 1% | 11,370 | +14% | 5.67% |
| 3% | 14,602 | +46% | 16.38% |
| 5% | 17,522 | +75% | 27.22% |
| **8%** | **21,579** | **+116%** | **42.17%** |
| 12% | 23,864 | +139% | 59.42% |

8% risk does **not** reach 50k out of sample — it reaches 21.6k, and it does
it through a **42% drawdown**. Note also that 8% → 12% adds 23 points of
return and 17 points of drawdown: **return stops scaling with risk long
before drawdown does.** That is textbook past-optimal-f, and it is the
clearest signal in this whole study that 8% is the wrong side of the curve.

## Worse: with the firewall ON, 8% risk destroys itself

The 58,414 run only exists because I disabled the risk controls to see the
raw curve. With growth mode's own firewall active (35% drawdown cap):

| | firewall OFF | **firewall ON (as shipped)** |
|---|---:|---:|
| 8% risk, 2026 | 58,414 (+484%) | **14,487 (+45%)** |
| 8% risk, 2025 OOS | 21,579 (+116%) | **7,216 (−28%)** |
| 3% risk, 2026 | 20,591 | 20,591 *(identical)* |
| 3% risk, 2025 OOS | 14,602 | 14,602 *(identical)* |

At 8% the account hits the drawdown cap, the EA performs its sticky halt and
**stops trading for the rest of the year** — 45 trades instead of 200, ending
the out-of-sample year down 28%. At 3% the firewall never binds at all, which
is the definition of a risk level the strategy can actually carry.

And the same 8% setting on a symbol the EA trades badly (GBPUSD, 2026):
**4,630 — down 54%, with a 63% drawdown.**

## What shipped

`TradingMode = MODE_AGGRESSIVE_GROWTH`, with `GrowthRiskPercent` **default 3%**
and the drawdown cap auto-widened to 35%.

| | 2026 in-sample | 2025 out-of-sample |
|---|---:|---:|
| Final balance | **20,591** | **14,602** |
| Return | **+106%** | **+46%** |
| Profit factor | 2.29 | 1.25 |
| Max drawdown | 7.10% | 16.38% |

Sizing is balance-based, so it compounds automatically. Blending the two
windows to roughly **+100%/year**, 10k → 50k is about **2 to 3 years** of
compounding. That is the real path to 50k: time at a survivable risk level,
not leverage. Leverage got there once, in the good year, with the brakes off.

## Also fixed in v11.80

**`RiskPercent` was a no-op in high-frequency mode.** v11.70 hard-capped it at
0.35%, so every risk level produced byte-identical results — I caught this
when the whole HF risk ladder returned the same number five times. There is
now a separate `HighFreqRiskPercent` dial. (Turning it up is not advised: at
2% the 8% daily cap halts the day almost immediately, giving 28 trades and
−3%.)

## Parity

`MODE_DISCIPLINE` and `MODE_HIGH_FREQUENCY` both still reproduce their
previous measured runs to the cent (12,956 / 109 trades and 11,963 / 607
trades) after the v11.80 refactor.

## The recommendation

Run `MODE_AGGRESSIVE_GROWTH` at **3%**, or **5%** if you accept a ~27%
drawdown in a thin year. Do not run 8% — the backtest says it either halts
itself or hands back more than it makes, and that is on the symbol this EA is
*best* at. And every number above is one broker, two windows, modelled
spread. Demo-forward-test before risking 3% of a real account per trade.
