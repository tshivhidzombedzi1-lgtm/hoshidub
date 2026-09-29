//+------------------------------------------------------------------+
//| ApexDrawdownZero_V11.mq5                                         |
//| Apex Drawdown Zero V11.60 — daily opening-range sweep /          |
//| displacement / retest EA with a hard risk firewall.              |
//|                                                                  |
//| Lineage: v7 entry styles -> v7.4 ATR stop -> v8 multi-pair       |
//| volatility-relative logic -> v9 presets. v10/v11 is the FULL     |
//| STRATEGY ENHANCEMENT pass, in four modules:                      |
//|                                                                  |
//| v10.00  RISK FIREWALL — the module the product name always       |
//|         implied but v9 never had. Day-start balance anchor,      |
//|         daily loss cap, peak-equity drawdown cap, intraday       |
//|         equity guard, consecutive-loss cooldown, risk de-        |
//|         escalation after losses, daily profit lock, Friday       |
//|         cutoff and a flat-before-weekend rule. When a limit      |
//|         trips the EA stops opening trades and (optionally)       |
//|         flattens what is open. This is a hard gate that sits in  |
//|         front of every entry path, not a suggestion.             |
//|                                                                  |
//| v10.50  SIGNAL QUALITY ENGINE — v9 treated every qualifying      |
//|         setup as equal. V11 scores each one 0-100 across six     |
//|         weighted components (opening-range quality, displacement |
//|         body, EMA bias distance, session, volatility regime,     |
//|         spread) and refuses anything under MinSignalScore.       |
//|         Optionally scales risk with the score, so A-grade        |
//|         setups get more size than marginal ones.                 |
//|                                                                  |
//| v11.00  ADAPTIVE EXIT ENGINE — v9 had one fixed TP plus an       |
//|         all-or-nothing R-trail that was disabled because it cut  |
//|         winners. V11 replaces it with: partial take-profit at    |
//|         TP1 (bank part of the trade, rest runs risk-free),       |
//|         an ATR chandelier trail on the runner that follows the   |
//|         excursion instead of the last price, and a time stop     |
//|         that releases capital from setups that stall. Position   |
//|         management is now per-ticket, so partials, pyramids and  |
//|         break-even no longer fight each other.                   |
//|                                                                  |
//| v11.50  AUTO-CALIBRATION + TELEMETRY — symbol classification     |
//|         (metal / major FX / JPY cross / index / crypto) replaces |
//|         the hardcoded 3-symbol preset table, so an unknown       |
//|         symbol gets a sane volatility-matched configuration      |
//|         instead of falling back to raw defaults. Dashboard v2    |
//|         reports firewall state, live setup score and running     |
//|         expectancy. Optional CSV trade journal.                  |
//|                                                                  |
//| v11.60  MEASURED PASS. The v11.50 defaults were backtested       |
//|         against v9.20 (XAUUSD + EURUSD, H1, 2026.01.05-09.01,    |
//|         1-min OHLC, 1% risk, $10k) and three of them were making |
//|         money WORSE. Each module was then ablated individually   |
//|         on XAUUSD and defaults were set from the result:         |
//|                                                                  |
//|           time stop        -1846   -> DEFAULT OFF                |
//|           weekend flatten   -572   -> DEFAULT OFF                |
//|           chandelier trail  -657   -> DEFAULT OFF                |
//|           Friday cutoff     -253   -> DEFAULT OFF                |
//|           risk de-escalation -118  -> DEFAULT OFF                |
//|           partial TP        -183   -> KEPT ON (buys -18% DD)     |
//|           score gate @50       0   -> RAISED TO 55 (50 never bound)|
//|           daily/DD hard caps    0   -> KEPT ON (free insurance)  |
//|                                                                  |
//|         The time stop and the chandelier were the same mistake   |
//|         v7.30 already found and fixed: on gold's intrabar noise, |
//|         anything that exits a winner early destroys the runners  |
//|         the 2R target depends on. Shipping them ON would have    |
//|         cut XAUUSD net profit by 70%.                            |
//|                                                                  |
//|         (that pass was v11.51; its score-gate-at-55 decision was |
//|         later reversed - see v11.60 below.)                      |
//|                                                                  |
//| v11.60  GIVEBACK STUDY + THREE COMPLEMENTARY STRATEGIES.         |
//|                                                                  |
//|         (a) THE GIVEBACK. Trades were observed to go into profit |
//|         and hand it back. An MFE log confirmed it: 50% of trades |
//|         reach 1.0R but only 38% reach the 2.0R target, mean MFE  |
//|         1.15R against a realised +0.16R average. Four fixes were |
//|         built and all four were rejected on measurement:         |
//|           profit-lock ladder  -1102  (simulated +19R, real -35%) |
//|           chandelier trail     -657                              |
//|           time stop           -1846                              |
//|           lower RR target      noise (1.75 spikes between two    |
//|                                worse neighbours - not an edge)   |
//|         CONCLUSION: the giveback is not a defect to be captured, |
//|         it is the cost of admission for the 38% that reach 2R.   |
//|         Every mechanism that tightens the exit converts large    |
//|         winners into small ones - win rate rises, profit falls.  |
//|         The ladder simulation looked strong because it was path- |
//|         blind; the real tester was not fooled.                   |
//|                                                                  |
//|         (b) THREE NEW STRATEGIES, one survived:                  |
//|           S1 NY session   KEPT (FX only - see below)             |
//|           S2 range fade   REJECTED - fired once in 8 months;     |
//|                           loosening the filters lost money       |
//|           S3 failed break REJECTED - -648, win rate 51%,         |
//|                           drawdown 2.29% -> 5.15%                |
//|                                                                  |
//|         S1 is gated by symbol class, and that gate is the most   |
//|         important finding of this pass. On XAUUSD it looked      |
//|         excellent in sample (3139 -> 3517) and then LOST out of  |
//|         sample (1443 -> -273). On EURUSD it improved both        |
//|         windows. One good window and one catastrophic window is  |
//|         not an edge, so NY_AUTO runs it on FX and not on metals. |
//|                                                                  |
//|         VERIFIED RESULT, shipped defaults, two windows:          |
//|           XAUUSD in-sample  3139 -> 2956  DD 2.29% -> 1.90%      |
//|           XAUUSD out-sample 1443 -> 1370  DD 6.14% -> 5.67%      |
//|           EURUSD in-sample  -401 ->  634  DD 12.50% -> 8.10%     |
//|           EURUSD out-sample  128 -> 1296  DD 9.40% -> 6.57%      |
//|           GBPUSD (unseen)  -1769 -> -676  DD 20.23% -> 9.82%     |
//|           USDJPY (unseen)  -2139 -> -881  DD 21.40% -> 9.42%     |
//|         Gold pays ~5% of net profit in BOTH windows and gets a   |
//|         lower drawdown, higher Sharpe and higher recovery factor |
//|         for it. FX improves outright. The two symbols the EA     |
//|         should not be traded on still lose, but lose about half  |
//|         as much with half the drawdown.                          |
//|                                                                  |
//| Backwards compatibility: every v9 input is still present with    |
//| its v9 meaning. Setting UseRiskFirewall / UsePartialTP to false  |
//| and NYSession to NY_OFF gives you v9.20 behaviour exactly -      |
//| verified in BOTH windows to the cent (3139.33 / 1443.08 XAUUSD,  |
//| 80 / 142 trades).                                                |
//+------------------------------------------------------------------+
#property copyright "Apex Drawdown Zero"
#property version   "11.80"
#resource "apex_logo.bmp"   // dashboard background art (300x254, pre-dimmed)
#property description "Apex Drawdown Zero V11.80 - opening-range breakout EA with a hard risk firewall."
#property description "Daily loss cap, drawdown cap, setup scoring, partial TP + chandelier trail. H1. Demo-test before live use."

//====================================================================
//                 APEX DRAWDOWN ZERO V11.80 - USER GUIDE
//====================================================================
//
//  WHAT IT DOES
//    A once-per-day breakout robot. Each day it builds an opening-range
//    "box" from the first hours of the session, then trades a sweep /
//    displacement / retest out of that range. Every setup is scored
//    before it is taken, every trade carries a stop, and a risk
//    firewall caps what the account can lose in a day and overall.
//    No martingale, no grid, no averaging.
//
//  SUPPORTED MARKETS
//    XAUUSD (Gold), EURUSD, EURJPY   -   Timeframe: H1
//    Other FX pairs run on auto-calibrated generic settings.
//    Not recommended on indices (e.g. US30) - the opening-range
//    premise did not hold there in testing.
//
//  HOW TO ATTACH  (3 steps)
//    1) Open an H1 chart of XAUUSD, EURUSD or EURJPY.
//    2) Drag the EA on and allow Algo Trading. Leave Preset = AUTO.
//    3) Check the dashboard shows "SCANNING" and "Firewall OK".
//
//  THE RISK FIREWALL  (new in V11 - read this)
//    DailyLossLimitPercent .. stop trading for the day at this loss  [ON]
//    MaxDrawdownPercent ..... stop the EA entirely at this drawdown
//                             from peak equity (needs manual restart) [ON]
//    EquityGuardPercent ..... emergency flatten on intraday equity drop [ON]
//    DailyProfitTargetPercent stop for the day once up this much     [off]
//    MaxConsecutiveLosses ... cooldown after a losing streak         [off]
//    UseRiskDeEscalation .... halve risk after each loss             [off]
//    FridayLastEntryHour / FlatBeforeWeekendHour  weekend handling   [off]
//    These are hard gates. FirewallClosesTrades decides whether a
//    tripped limit also flattens open positions or just blocks new ones.
//
//    The three caps that are ON cost nothing in the backtest (they never
//    triggered on a well-behaved account) and are pure tail insurance.
//    The ones that are OFF each measurably lost money on the test window
//    - see the v11.60 notes above before switching them on.
//
//    FlatBeforeWeekendHour is the one judgement call: it lost 572 over
//    8 months, but a backtest window with no catastrophic weekend gap
//    cannot price the risk it exists to cover. Set it to 21 if you would
//    rather pay that premium, especially on gold.
//
//  SETUP SCORING  (new in V11)
//    Each candidate setup gets 0-100 from six weighted components.
//    MinSignalScore rejects weak ones (default 55; at 50 it never
//    rejected anything on any tested pair, so it did nothing). With
//    UseScoreRiskScaling on, risk scales between RiskPercent and
//    RiskPercent * ScoreRiskMaxMult across the score range.
//    Raising it to 70 gave the best profit factor on XAUUSD (3.34) at
//    the cost of ~14% of the trades - a valid conservative alternative.
//
//  EXITS  (new in V11)
//    UsePartialTP ........... bank PartialClosePercent at PartialTP_RR [ON]
//    UseChandelierTrail ..... ATR trail on the runner                 [off]
//    UseTimeStop ............ close setups that stall                 [off]
//    UseBreakEven ........... unchanged from v9                       [ON]
//
//    Partial TP is the only new exit that survived testing: it costs a
//    little profit (-183) and buys a lower drawdown (2.29% -> 1.90%) and
//    a higher win rate. The other two cut winners and were switched off.
//
//  TRADING CADENCE  (V11.80)
//    TradingMode = MODE_DISCIPLINE  (default)
//      One qualified setup per day, H1. ~14 trades/month on XAUUSD.
//      This is the configuration every other number in this header
//      refers to, and the one with the best risk profile.
//    TradingMode = MODE_HIGH_FREQUENCY
//      Drops to M15 and allows up to 30 setups per day, with risk per
//      trade cut to 0.35% because the day now carries many more of them.
//      MEASURED on XAUUSD: 77-93 trades/month, profitable in both test
//      windows - but profit factor 2.60 -> 1.29 and max drawdown
//      1.90% -> 7%. It LOST money on EURUSD in both windows.
//      Use it on gold only, and only if you want the trade count more
//      than you want the risk profile.
//
//    TradingMode = MODE_AGGRESSIVE_GROWTH
//      Same H1 setups as MODE_DISCIPLINE (best profit factor, so the best
//      compounding engine), sized up via GrowthRiskPercent (default 3%)
//      with the drawdown cap widened to 35% so it is not halted constantly.
//      MEASURED on XAUUSD at 3%: +106% in the good test year, +46% in the
//      thin one, 7-16% drawdown, and the firewall never binds.
//
//      ON REACHING 5x FROM A SMALL ACCOUNT: at 8% risk the EA DID turn
//      10k into 58k in the good year - but ONLY with the risk controls
//      switched off. With the firewall on, 8% risk hits the 35% drawdown
//      cap, the EA halts, and the out-of-sample year ends at 7,216 - a
//      28% LOSS. Return stops scaling with risk long before drawdown
//      does. 3% compounds to 5x in roughly 2-3 years; 8% mostly finds
//      the drawdown cap. The frontier table is in the changelog.
//
//  IMPORTANT
//    - Times are broker/server hours. If your server is not GMT+2/+3,
//      shift FirstEntryHour / LastEntryHour to the London + NY window.
//    - Several no-trade days per month are normal and intentional.
//      With scoring on, expect fewer trades than v9.
//    - Always demo-test with your broker before going live. Trading
//      carries risk; past results do not guarantee future performance.
//====================================================================

#include <Trade/Trade.mqh>

//+------------------------------------------------------------------+
//| Enumerations                                                     |
//+------------------------------------------------------------------+
enum SignalType
{
   SIGNAL_NONE = 0,
   SIGNAL_BUY_SWEEP,
   SIGNAL_SELL_SWEEP,
   SIGNAL_BUY_CONTINUATION,
   SIGNAL_SELL_CONTINUATION
};

enum EntryStyleMode
{
   ENTRY_RETEST_LIMIT = 0,   // limit order at retest level (fills on touch)
   ENTRY_RETEST_CANDLE = 1,  // wait for confirming candle in retest zone
   ENTRY_IMMEDIATE = 2       // enter at market on signal bar close
};

enum PresetMode
{
   PRESET_AUTO = 0,          // detect the symbol and load its tuned preset
   PRESET_XAUUSD = 1,
   PRESET_EURUSD = 2,
   PRESET_EURJPY = 3,
   PRESET_GENERIC = 4,       // auto-calibrated from symbol class (V11.50)
   PRESET_MANUAL = 5         // ignore presets, use the raw inputs below
};

// symbol family, derived from the chart symbol (V11.50 auto-calibration)
enum SymbolClass
{
   SYMCLASS_METAL = 0,
   SYMCLASS_MAJOR_FX = 1,
   SYMCLASS_JPY_CROSS = 2,
   SYMCLASS_INDEX = 3,
   SYMCLASS_CRYPTO = 4,
   SYMCLASS_OTHER = 5
};

// overall trading cadence (v11.80)
enum TradeMode
{
   MODE_DISCIPLINE = 0,        // v9-v11 behaviour: one qualified setup per day
   MODE_HIGH_FREQUENCY = 1,    // intraday M15, many setups per day (XAUUSD only)
   MODE_AGGRESSIVE_GROWTH = 2  // H1 setups, compounding at a higher risk per trade
};

// how the NY session strategy is enabled (v11.60)
// MEASURED: NY helps FX in both test windows but destroyed XAUUSD out of
// sample (2025: +1443 -> -273) while helping it in sample. One good window
// and one catastrophic window is not an edge on metals, so AUTO excludes
// them and keeps the strategy where it verified twice.
enum NYMode
{
   NY_AUTO   = 0,   // on for FX, off for metals/crypto/indices
   NY_ALWAYS = 1,   // on everywhere (not recommended on gold - see above)
   NY_OFF    = 2
};

// which sub-strategy produced the live signal (v11.60)
enum StratId
{
   STRAT_CORE = 0,   // the v7-v11 opening-range sweep / displacement / retest
   STRAT_NY   = 1,   // second opening range built at the New York open
   STRAT_FADE = 2,   // compression-day fade of an opening range that holds
   STRAT_REV  = 3    // multi-bar failed-breakout reversal
};

// why the firewall is blocking (0 = not blocking)
enum HaltReason
{
   HALT_NONE = 0,
   HALT_DAILY_LOSS,
   HALT_DAILY_TARGET,
   HALT_MAX_DRAWDOWN,
   HALT_EQUITY_GUARD,
   HALT_COOLDOWN,
   HALT_WEEKEND
};

//+------------------------------------------------------------------+
//| Inputs                                                           |
//+------------------------------------------------------------------+

//--- trading cadence. MODE_HIGH_FREQUENCY drops to M15 and allows many
//--- setups per day. MEASURED on XAUUSD: ~77-93 trades/month, profitable
//--- in both test windows, but profit factor falls 2.60 -> 1.29 and max
//--- drawdown rises 1.90% -> 7%. It LOSES on EURUSD in both windows, so
//--- it is gold-only. See the v11.80 frequency table in the changelog.
input TradeMode       TradingMode              = MODE_DISCIPLINE;
//--- risk dial for the two non-default cadences. Kept SEPARATE from
//--- RiskPercent so switching mode cannot silently inherit a risk level
//--- that was tuned for a different trade count.
input double          GrowthRiskPercent        = 3.0;   // MODE_AGGRESSIVE_GROWTH risk per trade. Read the frontier table before raising this.
input double          HighFreqRiskPercent      = 0.35;  // MODE_HIGH_FREQUENCY risk per trade

//--- one-click preset (auto-tunes RR + session start per symbol)
input PresetMode      Preset                   = PRESET_AUTO;

//--- core strategy
input group           "=== Core strategy ==="
input ulong           MagicNumber              = 26070302;
input double          RiskPercent              = 1.0;
input double          MaxLots                  = 0.0;  // hard cap per trade (0 = no cap)
input int             BoxCandles               = 5;
input ENUM_TIMEFRAMES BoxTimeframe             = PERIOD_H1;
input ENUM_TIMEFRAMES EntryTimeframe           = PERIOD_H1;
input EntryStyleMode  EntryStyle               = ENTRY_IMMEDIATE;
input double          RiskReward               = 1.5;
input int             RetestTolerancePercent   = 25;
input int             ConfirmBodyPercent       = 60;
input int             SweepCloseBackPercent    = 20;   // sweep close must be back inside box by this % of box size
input int             BreakBufferPoints        = 50;   // fixed breakout buffer (used when BreakBufferAtr = 0)
input double          BreakBufferAtr           = 0.20; // breakout buffer = BreakBufferAtr * ATR (0 = use points)
input int             StopBufferPoints         = 80;   // fixed stop buffer (used when UseAtrStop = false)
input bool            UseAtrStop               = true; // size the stop from volatility (ATR) instead of a fixed buffer
input int             AtrPeriod                = 14;
input double          AtrStopMult              = 2.5;  // stop distance = AtrStopMult * ATR(AtrPeriod)
input int             MinBoxSizePoints         = 100;  // fixed min box (used when MinBoxAtr = 0)
input double          MinBoxAtr                = 1.50; // min box size = MinBoxAtr * ATR (0 = use points)
input double          MaxBoxAtr                = 4.00; // skip day if box > MaxBoxAtr * ATR (0 = off)
input int             MaxSignalAgeBars         = 6;
input int             FirstEntryHour           = 8;    // no new signals/entries before this hour
input int             LastEntryHour            = 20;   // no new signals/entries at or after this hour
input bool            UseBiasFilter            = true; // continuation trades only with EMA bias
input bool            ApplyBiasToSweeps        = true; // sweeps also require EMA bias
input int             BiasEMAPeriod            = 50;
input int             MaxSpreadPoints          = 350;
input bool            OneTradePerDay           = true;
input bool            StopAfterWin             = true;
input int             SlippagePoints           = 30;

//--- RISK FIREWALL (V11.00) - the drawdown-control core
input group           "=== Risk firewall (V11) ==="
input bool            UseRiskFirewall          = true;  // master switch for every limit below
input double          DailyLossLimitPercent    = 3.0;   // halt for the day at this % loss of day-start balance (0 = off)
input double          MaxDrawdownPercent       = 10.0;  // halt the EA at this % drawdown from peak equity (0 = off)
input double          EquityGuardPercent       = 5.0;   // emergency flatten if intraday equity drops this % (0 = off)
input double          DailyProfitTargetPercent = 0.0;   // stop for the day once up this % (0 = off)
input bool            FirewallClosesTrades     = true;  // a tripped limit also flattens open trades (false = block new entries only)
input int             MaxConsecutiveLosses     = 0;     // cooldown after N losses in a row (0 = off; measured as a net cost)
input int             CooldownDays             = 1;     // trading days skipped during a cooldown
input bool            UseRiskDeEscalation      = false; // MEASURED -118 on XAUUSD (slower recovery deepened DD). Off; see changelog.
input double          RiskFloorPercent         = 0.25;  // de-escalation never goes below this risk %
input int             FridayLastEntryHour      = 0;     // MEASURED -253 on XAUUSD: Friday setups were profitable. 0 = use LastEntryHour.
input int             FlatBeforeWeekendHour    = 0;     // MEASURED -572 on XAUUSD. 0 = off. Turn ON if you want gap insurance (see changelog).

//--- SIGNAL QUALITY ENGINE (V11.50)
input group           "=== Setup scoring (V11) ==="
input bool            UseSignalScore           = false; // MEASURED: helps XAUUSD PF but flips EURUSD +633 -> -322. Not robust across symbols. Off.
input int             MinSignalScore           = 55;    // reject setups scoring below this (50 never bound on any tested pair)
input bool            UseScoreRiskScaling      = false; // scale risk with score (off = flat RiskPercent)
input double          ScoreRiskMaxMult         = 1.50;  // risk multiplier at a perfect 100 score
input bool            UseRegimeFilter          = false; // tested together with the score gate; off for the same reason.
input int             AtrRegimeLookback        = 50;    // slow ATR period the regime ratio is measured against
input double          MinAtrRatio              = 0.60;  // reject when fast/slow ATR below this (dead market)
input double          MaxAtrRatio              = 2.20;  // reject when fast/slow ATR above this (news blowout)

//--- ADAPTIVE EXIT ENGINE (V11.00)
input group           "=== Adaptive exits (V11) ==="
input bool            UsePartialTP             = true;  // bank part of the position at TP1, run the rest
input double          PartialTP_RR             = 1.00;  // TP1 as a fraction of target R
input int             PartialClosePercent      = 50;    // portion of the position closed at TP1
input bool            UseChandelierTrail       = false; // MEASURED -657 on XAUUSD: still cut winners. Off (same lesson as v7.30).
input double          ChandelierAtrMult        = 2.00;  // trail distance behind the best price, in ATR
input double          TrailAfterRR             = 1.00;  // arm the chandelier at this fraction of target R
input bool            UseTimeStop              = false; // MEASURED -1846 on XAUUSD: it closed winners before they ran. Off.
//--- PROFIT-LOCK LADDER (v11.60). The giveback fix. Unlike a trail or a
//--- time stop it NEVER closes a trade early - it only raises the floor as
//--- the trade earns it, so a runner is still free to reach target.
input bool            UseProfitLadder          = false; // MEASURED -1102 on XAUUSD. See v11.60 notes: the giveback cannot be captured.
input double          Ladder1_MFE              = 1.00;  // once the trade has shown this many R ...
input double          Ladder1_Lock             = 0.50;  // ... the stop moves to this many R of locked profit
input double          Ladder2_MFE              = 1.50;
input double          Ladder2_Lock             = 1.00;
input int             TimeStopBars             = 8;     // bars after entry before the time stop can fire
input double          TimeStopMinRR            = 0.30;  // ... and it fires only if profit is below this R

//--- trade management (v9 behaviour, retained)
input group           "=== Break-even / legacy trailing ==="
input bool            UseBreakEven             = true;
input double          BreakEvenTriggerRR       = 0.60;  // move SL to BE at this fraction of target R
input int             BreakEvenOffsetPoints    = 30;
input bool            UseTrailing              = false; // legacy R-trailing (superseded by the chandelier)
input double          TrailStartRR             = 1.00;
input double          TrailDistanceRR          = 0.50;
input int             TrailStepPoints          = 50;

//--- pyramiding (scale into a winner)
input group           "=== Pyramiding ==="
input bool            UsePyramid               = false; // add a 2nd unit once in profit (off by default)
input double          PyramidTriggerRR         = 0.70;  // add when the base trade reaches this fraction of target R

//--- COMPLEMENTARY STRATEGIES (v11.60)
//--- Three additional setups that trade situations the core strategy
//--- sits out, so they add opportunity rather than re-cutting the same
//--- trades. Each has its own switch and its own once-per-day slot.
input group           "=== Complementary strategies (V11.60) ==="
input int             MaxTradesPerDay          = 2;     // total across all strategies (OneTradePerDay must be true for this to bind)

//--- S1: New York opening range. Same proven mechanism, second session.
input NYMode          NYSession                = NY_AUTO;
input int             NYBoxStartHour           = 14;    // server hour the NY range starts building
input int             NYBoxCandles             = 2;     // bars in the NY range
input int             NYLastEntryHour          = 21;    // NY setups may fire later than the London cutoff

//--- S2: compression-day fade. Trades the days the core never fires on:
//--- a narrow opening range that is still holding late in the session.
input bool            UseRangeFade             = false; // MEASURED: fires ~once in 8 months; loosened filters lost money. Off.
input int             FadeFromHour             = 12;    // only consider fades from this hour
input double          FadeMaxBoxAtr            = 1.60;  // range must be this narrow (x ATR) to count as compression
input int             FadeEdgePercent          = 15;    // enter within this % of box size from the edge
input int             FadeTargetPercent        = 55;    // target this % of the way across the box
input double          FadeStopAtr              = 0.80;  // stop this far beyond the edge, in ATR
input int             FadeMaxBreakBars         = 1;     // tolerate this many closes outside the range and still call it a range day

//--- S3: multi-bar failed breakout. The core sweep needs the break and the
//--- rejection inside ONE candle; this catches the slower version.
input bool            UseFailedBreak           = false; // MEASURED -648 on XAUUSD, win rate 51%, DD 2.29% -> 5.15%. Off.
input int             FailedBreakBars          = 3;     // break must have happened within this many bars
input double          FailedBreakMinPushAtr    = 0.30;  // how far outside the box the failed push had to reach

//--- visuals + telemetry
input group           "=== Visuals / journal ==="
input bool            ShowVisuals              = true;
input bool            ShowDashboard            = true;
input bool            WriteTradeJournal        = false; // append closed trades to a CSV in MQL5/Files
input int             PanelX                   = 12;
input int             PanelY                   = 28;
input color           BoxColor                 = clrSteelBlue;
input color           BullColor                = clrLimeGreen;
input color           BearColor                = clrTomato;

//+------------------------------------------------------------------+
//| Per-ticket management state                                      |
//| V11 manages every leg independently (base, pyramid add-on), so   |
//| partials, break-even and the chandelier no longer collide the    |
//| way v9's single-ticket manager did.                              |
//+------------------------------------------------------------------+
struct TradeState
{
   ulong    ticket;
   double   entry;
   double   initRisk;      // 1R in price terms
   double   bestPrice;     // max favourable excursion, drives the chandelier
   double   worstPrice;    // max adverse excursion (diagnostics only)
   datetime openTime;
   bool     partialDone;
   bool     beDone;
   bool     isBuy;
};

CTrade trade;

TradeState g_states[];

//--- sub-strategy state (v11.60)
StratId    g_activeStrat = STRAT_CORE;   // which strategy armed g_signal
bool       g_stratDone[4];               // once-per-day slot per strategy
int        g_tradesToday = 0;            // trades opened today, all strategies
double     g_nyBoxHigh = 0.0;
double     g_nyBoxLow = 0.0;
datetime   g_nyBoxStart = 0;
datetime   g_nyBoxEnd = 0;
bool       g_nyBoxReady = false;
bool       g_useNY = true;              // NYSession resolved against symbol class
//--- cadence-resolved working copies of the inputs TradingMode overrides.
//--- In MODE_DISCIPLINE every one equals its input, so behaviour is
//--- bit-identical to v11.60 (verified by the parity backtest).
ENUM_TIMEFRAMES g_boxTF = PERIOD_H1;
ENUM_TIMEFRAMES g_entryTF = PERIOD_H1;
bool       g_useBias = true;
bool       g_biasSweeps = true;
double     g_minBoxAtr = 1.50;
double     g_breakBufAtr = 0.20;
int        g_confirmBody = 60;
bool       g_oneTradePerDay = true;
bool       g_stopAfterWin = true;
int        g_maxTradesDay = 2;
double     g_riskPercent = 1.0;
double     g_dailyLossLimit = 3.0;
double     g_maxDrawdown = 10.0;
double     g_customSl = 0.0;             // level-based SL/TP for the fade
double     g_customTp = 0.0;
bool       g_useCustomLevels = false;

//--- daily / session state
datetime   g_dayStart = 0;
datetime   g_boxStart = 0;
datetime   g_boxEnd = 0;
datetime   g_lastSignalBarTime = 0;
datetime   g_lastEntryBarTime = 0;
datetime   g_pendingExpiry = 0;
double     g_boxHigh = 0.0;
double     g_boxLow = 0.0;
double     g_signalHigh = 0.0;
double     g_signalLow = 0.0;
double     g_retestLevel = 0.0;
SignalType g_signal = SIGNAL_NONE;
int        g_signalScore = 0;
bool       g_boxReady = false;
bool       g_boxDrawn = false;
bool       g_tradedToday = false;
bool       g_wonToday = false;
bool       g_addedToday = false;
bool       g_uiEnabled = true;
int        g_emaHandle = INVALID_HANDLE;
int        g_atrHandle = INVALID_HANDLE;
int        g_atrSlowHandle = INVALID_HANDLE;

//--- risk firewall state
double     g_dayStartBalance = 0.0;
double     g_dayStartEquity = 0.0;
double     g_dayPeakEquity = 0.0;
double     g_peakEquity = 0.0;
double     g_dayRealized = 0.0;
int        g_consecLosses = 0;
datetime   g_cooldownUntilDay = 0;
HaltReason g_haltDay = HALT_NONE;      // cleared at the next day roll
HaltReason g_haltAll = HALT_NONE;      // sticky until the EA is restarted
string     g_haltNote = "";

//--- running statistics (this account + symbol + magic)
int        g_statWins = 0;
int        g_statLosses = 0;
double     g_statProfit = 0.0;
double     g_statLoss = 0.0;
// highest deal ticket already folded into the stats/streak. Seeded by
// RebuildHistoryState so a mid-day restart does not count today's deals
// a second time on the first pass of UpdateClosedDeals.
ulong      g_lastSeenDeal = 0;

//--- active preset (working values; set by ApplyPreset)
PresetMode  g_presetMode = PRESET_AUTO;
SymbolClass g_symClass = SYMCLASS_OTHER;
double      g_riskReward = 1.5;
int         g_firstEntryHour = 8;
double      g_atrStopMult = 2.5;
int         g_minScore = 50;
string      g_presetName = "MANUAL";

//--- forward declarations (functions referenced before their definition)
string SignalText(SignalType s);
void   DrawSignal();
void   FlattenAll(const string reason);

//+------------------------------------------------------------------+
//| Day handling                                                     |
//+------------------------------------------------------------------+
datetime DayStart(datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
}

int CurrentHour()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return dt.hour;
}

bool IsFriday()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return dt.day_of_week == 5;
}

//--- session cutoff, with the earlier Friday override applied
int EffectiveLastEntryHour()
{
   if(UseRiskFirewall && IsFriday() && FridayLastEntryHour > 0)
      return MathMin(LastEntryHour, FridayLastEntryHour);
   return LastEntryHour;
}

bool IsNewDay()
{
   datetime today = DayStart(TimeCurrent());
   if(today == g_dayStart)
      return false;

   g_dayStart = today;
   g_boxStart = 0;
   g_boxEnd = 0;
   g_lastSignalBarTime = 0;
   g_lastEntryBarTime = 0;
   g_pendingExpiry = 0;
   g_boxHigh = 0.0;
   g_boxLow = 0.0;
   g_signalHigh = 0.0;
   g_signalLow = 0.0;
   g_retestLevel = 0.0;
   g_signal = SIGNAL_NONE;
   g_signalScore = 0;
   g_boxReady = false;
   g_boxDrawn = false;
   g_tradedToday = false;
   g_wonToday = false;
   g_addedToday = false;

   // sub-strategy slots
   for(int i = 0; i < 4; i++)
      g_stratDone[i] = false;
   g_tradesToday = 0;
   g_nyBoxHigh = 0.0;
   g_nyBoxLow = 0.0;
   g_nyBoxStart = 0;
   g_nyBoxEnd = 0;
   g_nyBoxReady = false;
   g_useCustomLevels = false;
   g_activeStrat = STRAT_CORE;

   // firewall: re-anchor the day, release the daily halt (a max-drawdown
   // or equity-guard halt is sticky and deliberately survives the roll)
   g_dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   g_dayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_dayPeakEquity = g_dayStartEquity;
   g_dayRealized = 0.0;
   g_haltDay = HALT_NONE;
   return true;
}

string DayTag()
{
   return TimeToString(g_dayStart, TIME_DATE);
}

//+------------------------------------------------------------------+
//| Broker distance guard                                            |
//| MQL5 Market validation: SL/TP may not be placed or modified      |
//| within max(stops level, freeze level) of the market; both can    |
//| report 0, so fall back to a spread-based distance.               |
//+------------------------------------------------------------------+
double GuardDistance()
{
   double stops  = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   double freeze = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL) * _Point;
   double spread = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID);
   return MathMax(MathMax(stops, freeze), 3.0 * spread);
}

//+------------------------------------------------------------------+
//| Position / order helpers                                         |
//+------------------------------------------------------------------+
ulong OwnPositionTicket()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;

      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (ulong)PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         return ticket;
   }
   return 0;
}

//--- every ticket we own on this symbol (V11 manages each leg separately)
int OwnPositionTickets(ulong &out[])
{
   ArrayResize(out, 0);
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != MagicNumber)
         continue;

      int n = ArraySize(out);
      ArrayResize(out, n + 1);
      out[n] = ticket;
   }
   return ArraySize(out);
}

int OwnPositionCount()
{
   ulong t[];
   return OwnPositionTickets(t);
}

bool HasOpenPosition()
{
   return OwnPositionTicket() != 0;
}

ulong OwnPendingTicket()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;

      if(OrderGetString(ORDER_SYMBOL) == _Symbol &&
         (ulong)OrderGetInteger(ORDER_MAGIC) == MagicNumber)
         return ticket;
   }
   return 0;
}

void CancelPending(const string reason)
{
   ulong ticket = OwnPendingTicket();
   if(ticket == 0)
      return;

   if(trade.OrderDelete(ticket))
      Print("Apex Drawdown Zero: pending order cancelled (", reason, ")");
   g_pendingExpiry = 0;
}

void ManagePendingExpiry()
{
   ulong ticket = OwnPendingTicket();
   if(ticket == 0)
   {
      g_pendingExpiry = 0;
      return;
   }

   // orphan pending after restart: give it until end of day
   if(g_pendingExpiry == 0)
      g_pendingExpiry = g_dayStart + 86400;

   if(TimeCurrent() > g_pendingExpiry)
      CancelPending("expired without fill");
}

//+------------------------------------------------------------------+
//| Per-ticket state table                                           |
//+------------------------------------------------------------------+
int FindState(ulong ticket)
{
   for(int i = 0; i < ArraySize(g_states); i++)
      if(g_states[i].ticket == ticket)
         return i;
   return -1;
}

//--- state for a ticket, created (and reconstructed) on first sight.
//--- After a terminal restart the initial risk is recovered from the
//--- position's own TP and the active RR, exactly as v9 did.
int EnsureState(ulong ticket)
{
   int idx = FindState(ticket);
   if(idx >= 0)
      return idx;

   if(!PositionSelectByTicket(ticket))
      return -1;

   bool   isBuy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
   double entry = PositionGetDouble(POSITION_PRICE_OPEN);
   double sl    = PositionGetDouble(POSITION_SL);
   double tp    = PositionGetDouble(POSITION_TP);

   double initRisk = 0.0;
   if(tp > 0.0 && g_riskReward > 0.0)
      initRisk = MathAbs(tp - entry) / g_riskReward;
   if(initRisk <= 0.0 && sl > 0.0)
      initRisk = MathAbs(entry - sl);
   if(initRisk <= 0.0)
      return -1;

   int n = ArraySize(g_states);
   ArrayResize(g_states, n + 1);
   g_states[n].ticket      = ticket;
   g_states[n].entry       = entry;
   g_states[n].initRisk    = initRisk;
   g_states[n].bestPrice   = entry;
   g_states[n].worstPrice  = entry;
   g_states[n].openTime    = (datetime)PositionGetInteger(POSITION_TIME);
   g_states[n].partialDone = false;
   g_states[n].beDone      = (sl != 0.0) && (isBuy ? sl >= entry : sl <= entry);
   g_states[n].isBuy       = isBuy;
   return n;
}

//--- drop state for tickets that are no longer open
//--- excursion diagnostics: how far a trade ran vs what it kept.
//--- This is what answers "it goes my way then gives it all back":
//--- MFE is the best it ever showed, in R.
void LogExcursion(int idx)
{
   if(!WriteTradeJournal || MQLInfoInteger(MQL_OPTIMIZATION))
      return;
   if(g_states[idx].initRisk <= 0.0)
      return;

   bool   isBuy = g_states[idx].isBuy;
   double entry = g_states[idx].entry;
   double risk  = g_states[idx].initRisk;
   double mfe = (isBuy ? g_states[idx].bestPrice - entry
                       : entry - g_states[idx].bestPrice) / risk;
   double mae = (isBuy ? entry - g_states[idx].worstPrice
                       : g_states[idx].worstPrice - entry) / risk;

   string file = StringFormat("ApexExcursion_%s.csv", _Symbol);
   bool fresh = !FileIsExist(file);
   int h = FileOpen(file, FILE_WRITE | FILE_READ | FILE_CSV | FILE_ANSI, ',');
   if(h == INVALID_HANDLE)
      return;
   if(fresh)
      FileWrite(h, "ticket", "dir", "open_time", "entry", "risk_px",
                "mfe_R", "mae_R", "partial", "be");
   else
      FileSeek(h, 0, SEEK_END);

   FileWrite(h, (string)g_states[idx].ticket, isBuy ? "BUY" : "SELL",
             TimeToString(g_states[idx].openTime, TIME_DATE | TIME_MINUTES),
             DoubleToString(entry, _Digits), DoubleToString(risk, _Digits),
             DoubleToString(mfe, 3), DoubleToString(mae, 3),
             g_states[idx].partialDone ? "1" : "0",
             g_states[idx].beDone ? "1" : "0");
   FileClose(h);
}

void PruneStates()
{
   for(int i = ArraySize(g_states) - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(g_states[i].ticket))
         continue;

      LogExcursion(i);

      int last = ArraySize(g_states) - 1;
      if(i != last)
         g_states[i] = g_states[last];
      ArrayResize(g_states, last);
   }
}

//+------------------------------------------------------------------+
//| Indicator reads                                                  |
//+------------------------------------------------------------------+

//--- current ATR (last closed bar); 0 if unavailable
double AtrValue()
{
   if(g_atrHandle == INVALID_HANDLE)
      return 0.0;
   double a[1];
   if(CopyBuffer(g_atrHandle, 0, 1, 1, a) == 1 && a[0] > 0.0)
      return a[0];
   return 0.0;
}

//--- slow ATR, the baseline the volatility regime is measured against
double AtrSlowValue()
{
   if(g_atrSlowHandle == INVALID_HANDLE)
      return 0.0;
   double a[1];
   if(CopyBuffer(g_atrSlowHandle, 0, 1, 1, a) == 1 && a[0] > 0.0)
      return a[0];
   return 0.0;
}

//--- fast/slow ATR ratio: ~1.0 is a normal session, <1 dead, >1 expanding
double AtrRegimeRatio()
{
   double fast = AtrValue();
   double slow = AtrSlowValue();
   if(fast <= 0.0 || slow <= 0.0)
      return 1.0;
   return fast / slow;
}

double EmaValue()
{
   if(g_emaHandle == INVALID_HANDLE)
      return 0.0;
   double ema[1];
   if(CopyBuffer(g_emaHandle, 0, 1, 1, ema) == 1)
      return ema[0];
   return 0.0;
}

bool BiasOK(bool buy)
{
   if(!g_useBias || g_emaHandle == INVALID_HANDLE)
      return true;

   double ema = EmaValue();
   if(ema <= 0.0)
      return true;

   double close = iClose(_Symbol, g_boxTF, 1);
   return buy ? close > ema : close < ema;
}

//+------------------------------------------------------------------+
//| RISK FIREWALL                                                    |
//| Every limit is evaluated here, once per tick, in front of the    |
//| entry logic. Two tiers: g_haltDay clears at the next day roll,   |
//| g_haltAll is sticky and requires a restart (it means the account |
//| has hit its structural drawdown limit, which is not a thing to   |
//| resume from automatically).                                      |
//+------------------------------------------------------------------+
string HaltText(HaltReason r)
{
   switch(r)
   {
      case HALT_DAILY_LOSS:   return "DAILY LOSS LIMIT";
      case HALT_DAILY_TARGET: return "DAILY TARGET MET";
      case HALT_MAX_DRAWDOWN: return "MAX DRAWDOWN";
      case HALT_EQUITY_GUARD: return "EQUITY GUARD";
      case HALT_COOLDOWN:     return "LOSS COOLDOWN";
      case HALT_WEEKEND:      return "WEEKEND FLAT";
   }
   return "OK";
}

//--- day P/L including open trades, as a % of the day-start balance
double DayPLPercent()
{
   if(g_dayStartBalance <= 0.0)
      return 0.0;
   double openPL = AccountInfoDouble(ACCOUNT_EQUITY) - AccountInfoDouble(ACCOUNT_BALANCE);
   return (g_dayRealized + openPL) / g_dayStartBalance * 100.0;
}

double DrawdownPercent()
{
   if(g_peakEquity <= 0.0)
      return 0.0;
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq >= g_peakEquity)
      return 0.0;
   return (g_peakEquity - eq) / g_peakEquity * 100.0;
}

void TripHalt(HaltReason reason, bool sticky, const string note)
{
   if(sticky)
   {
      if(g_haltAll != HALT_NONE)
         return;
      g_haltAll = reason;
   }
   else
   {
      if(g_haltDay != HALT_NONE)
         return;
      g_haltDay = reason;
   }

   g_haltNote = note;
   Print("Apex Drawdown Zero: FIREWALL - ", HaltText(reason), " - ", note);

   // a loss/drawdown halt flattens when asked to; either way the pending
   // order goes, because there is no case where we still want it to fill
   if(FirewallClosesTrades)
      FlattenAll(HaltText(reason));
   else
      CancelPending(HaltText(reason));
}

void UpdateFirewall()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);

   // peak equity drives the structural drawdown limit; persisted across
   // restarts in live trading so a restart cannot reset the high-water mark
   if(equity > g_peakEquity)
   {
      g_peakEquity = equity;
      if(!MQLInfoInteger(MQL_TESTER))
         GlobalVariableSet(StringFormat("ADZ11_peak_%I64u", MagicNumber), g_peakEquity);
   }
   if(equity > g_dayPeakEquity)
      g_dayPeakEquity = equity;

   if(!UseRiskFirewall)
      return;

   // --- weekend flat: get out before the gap
   if(FlatBeforeWeekendHour > 0 && IsFriday() && CurrentHour() >= FlatBeforeWeekendHour)
   {
      if(OwnPositionCount() > 0 || OwnPendingTicket() != 0)
      {
         FlattenAll("weekend flat");
         g_haltDay = HALT_WEEKEND;
         g_haltNote = "flat before the weekend gap";
      }
      else if(g_haltDay == HALT_NONE)
      {
         g_haltDay = HALT_WEEKEND;
         g_haltNote = "flat before the weekend gap";
      }
   }

   // --- structural drawdown from peak equity (sticky)
   if(g_maxDrawdown > 0.0)
   {
      double dd = DrawdownPercent();
      if(dd >= g_maxDrawdown)
         TripHalt(HALT_MAX_DRAWDOWN, true,
                  StringFormat("%.2f%% from peak %.2f - EA stopped, restart required",
                               dd, g_peakEquity));
   }

   // --- intraday equity guard: fastest-acting limit, measured from the
   //     day's own equity peak so a giveback triggers it, not just a loss
   if(EquityGuardPercent > 0.0 && g_dayPeakEquity > 0.0)
   {
      double giveback = (g_dayPeakEquity - equity) / g_dayPeakEquity * 100.0;
      if(giveback >= EquityGuardPercent)
         TripHalt(HALT_EQUITY_GUARD, false,
                  StringFormat("%.2f%% given back from today's equity peak", giveback));
   }

   // --- daily loss cap
   if(g_dailyLossLimit > 0.0)
   {
      double pl = DayPLPercent();
      if(pl <= -g_dailyLossLimit)
         TripHalt(HALT_DAILY_LOSS, false,
                  StringFormat("day P/L %.2f%% <= -%.2f%%", pl, g_dailyLossLimit));
   }

   // --- daily profit lock (never closes trades, only stops new ones)
   if(DailyProfitTargetPercent > 0.0)
   {
      double pl = DayPLPercent();
      if(pl >= DailyProfitTargetPercent && g_haltDay == HALT_NONE)
      {
         g_haltDay = HALT_DAILY_TARGET;
         g_haltNote = StringFormat("day P/L %.2f%% >= %.2f%%", pl, DailyProfitTargetPercent);
         Print("Apex Drawdown Zero: FIREWALL - DAILY TARGET MET - ", g_haltNote);
      }
   }

   // --- losing-streak cooldown
   if(MaxConsecutiveLosses > 0 && g_consecLosses >= MaxConsecutiveLosses &&
      g_cooldownUntilDay > g_dayStart && g_haltDay == HALT_NONE)
   {
      g_haltDay = HALT_COOLDOWN;
      g_haltNote = StringFormat("%d losses in a row, resumes %s",
                                g_consecLosses, TimeToString(g_cooldownUntilDay, TIME_DATE));
   }

   // --- a halt is only real once the book is actually flat. The first
   //     FlattenAll can fail (market closed, requote, off-quotes), and the
   //     halt flag would then stop it ever being retried, so retry here on
   //     a timer until nothing is left open.
   if(FirewallClosesTrades && HaltRequiresFlat() &&
      (OwnPositionCount() > 0 || OwnPendingTicket() != 0))
   {
      static datetime lastRetry = 0;
      if(TimeCurrent() - lastRetry >= 30)
      {
         lastRetry = TimeCurrent();
         FlattenAll("firewall retry");
      }
   }
}

//--- does the current halt state require the book to be flat?
//--- (a profit-target stop deliberately lets open winners keep running)
bool HaltRequiresFlat()
{
   if(!UseRiskFirewall)
      return false;
   if(g_haltAll != HALT_NONE)
      return true;
   return g_haltDay != HALT_NONE && g_haltDay != HALT_DAILY_TARGET;
}

//--- single gate every entry path goes through
bool FirewallBlocksEntry()
{
   if(!UseRiskFirewall)
      return false;
   return (g_haltAll != HALT_NONE) || (g_haltDay != HALT_NONE);
}

//--- close every position and pending order we own on this symbol
void FlattenAll(const string reason)
{
   ulong tickets[];
   int n = OwnPositionTickets(tickets);

   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(SlippagePoints);

   for(int i = 0; i < n; i++)
   {
      if(trade.PositionClose(tickets[i], SlippagePoints))
         Print("Apex Drawdown Zero: position ", tickets[i], " closed (", reason, ")");
      else
         Print("Apex Drawdown Zero: could not close ", tickets[i], " (", reason,
               ") retcode ", trade.ResultRetcode());
   }

   CancelPending(reason);
}

//--- risk % for the next trade after de-escalation and score scaling
double EffectiveRiskPercent(int score)
{
   double risk = g_riskPercent;

   // de-escalation: each consecutive loss halves the next trade's risk.
   // Rebuilding size only after a win is what keeps a losing run from
   // compounding into the drawdown limit.
   if(UseRiskFirewall && UseRiskDeEscalation && g_consecLosses > 0)
   {
      double factor = MathPow(0.5, (double)MathMin(g_consecLosses, 4));
      risk = MathMax(g_riskPercent * factor, MathMin(RiskFloorPercent, g_riskPercent));
   }

   // conviction scaling: only ever scales up, and only above the gate
   if(UseSignalScore && UseScoreRiskScaling && ScoreRiskMaxMult > 1.0 && score > g_minScore)
   {
      double span = MathMax(1.0, 100.0 - (double)g_minScore);
      double t = MathMin(1.0, (double)(score - g_minScore) / span);
      risk *= 1.0 + t * (ScoreRiskMaxMult - 1.0);
   }

   return MathMax(0.01, risk);
}

//+------------------------------------------------------------------+
//| Box construction                                                 |
//| Anchored to the first traded bar of the day, not midnight:      |
//| metals/indices often open 01:00+ server time, which left the    |
//| old [00:00, N bars) window permanently short of candles.        |
//+------------------------------------------------------------------+
bool BuildDailyBox()
{
   if(g_boxReady)
      return true;

   // locate the earliest bar of the current day (scan newest -> oldest)
   int firstShift = -1;
   for(int shift = 1; shift < 300; shift++)
   {
      datetime barTime = iTime(_Symbol, g_boxTF, shift);
      if(barTime == 0 || barTime < g_dayStart)
         break;
      firstShift = shift;
   }
   if(firstShift < 0)
      return false;

   int lastShift = firstShift - BoxCandles + 1;   // Nth bar of the day
   if(lastShift < 1)                              // Nth bar not closed yet
      return false;

   double high = -DBL_MAX;
   double low = DBL_MAX;
   for(int shift = lastShift; shift <= firstShift; shift++)
   {
      high = MathMax(high, iHigh(_Symbol, g_boxTF, shift));
      low = MathMin(low, iLow(_Symbol, g_boxTF, shift));
   }

   g_boxStart = iTime(_Symbol, g_boxTF, firstShift);
   g_boxEnd = iTime(_Symbol, g_boxTF, lastShift) + PeriodSeconds(g_boxTF);
   g_boxHigh = high;
   g_boxLow = low;
   g_boxReady = true;
   return true;
}

//+------------------------------------------------------------------+
//| SIGNAL QUALITY ENGINE                                            |
//| v9 treated every qualifying setup as identical. The components   |
//| below are the same properties the v7-v8 research pass found to   |
//| separate good days from bad ones, expressed as a continuous      |
//| score instead of a set of hard yes/no cuts:                      |
//|                                                                  |
//|   range quality  25  opening range in the 1.5-3.0 ATR sweet spot |
//|   displacement   20  body share of the signal candle             |
//|   bias distance  20  how far the close sits the right side of EMA|
//|   session        15  London / NY-overlap hours score highest     |
//|   regime         10  fast/slow ATR near 1.0                      |
//|   spread         10  execution cost relative to the cap          |
//|                                                                  |
//| Each returns 0..weight; the total gates the trade and optionally |
//| scales its size.                                                 |
//+------------------------------------------------------------------+

//--- triangular score: full marks at the centre of [lo,hi], 0 outside
double BandScore(double value, double lo, double hi, double weight)
{
   if(value <= lo || value >= hi)
      return 0.0;
   double mid = (lo + hi) / 2.0;
   double half = (hi - lo) / 2.0;
   if(half <= 0.0)
      return 0.0;
   return weight * (1.0 - MathAbs(value - mid) / half);
}

double ScoreRangeQuality(double boxSize, double atr)
{
   if(atr <= 0.0 || boxSize <= 0.0)
      return 12.5;                       // no ATR: neutral, don't penalise
   double ratio = boxSize / atr;
   // 1.5-3.0 ATR is the productive band; wider ranges were the one robust
   // finding of the v8.10 ML pass (they underperform), narrower ones are noise
   return BandScore(ratio, 0.8, 4.0, 25.0);
}

double ScoreDisplacement(double open, double close, double high, double low)
{
   double range = high - low;
   if(range <= 0.0)
      return 0.0;
   double bodyPct = MathAbs(close - open) / range * 100.0;
   // 50% body scores nothing, 90%+ scores full marks
   double t = (bodyPct - 50.0) / 40.0;
   return 20.0 * MathMax(0.0, MathMin(1.0, t));
}

double ScoreBias(bool buy, double atr)
{
   if(!g_useBias || g_emaHandle == INVALID_HANDLE || atr <= 0.0)
      return 10.0;                       // filter off: neutral half marks

   double ema = EmaValue();
   if(ema <= 0.0)
      return 10.0;

   double close = iClose(_Symbol, g_boxTF, 1);
   double dist = (buy ? (close - ema) : (ema - close)) / atr;
   if(dist <= 0.0)
      return 0.0;                        // wrong side of the EMA
   // 0 -> 0, 1.5 ATR beyond the EMA -> full marks (trend has separation)
   return 20.0 * MathMin(1.0, dist / 1.5);
}

double ScoreSession(int hour)
{
   // London open and the London/NY overlap are where the opening-range
   // break has follow-through; the late-NY tail is thinner
   if(hour >= 8 && hour <= 11)  return 15.0;   // London
   if(hour >= 13 && hour <= 16) return 15.0;   // NY overlap
   if(hour == 12)               return 11.0;   // lunch lull
   if(hour >= 17 && hour <= 18) return 8.0;
   return 4.0;
}

double ScoreRegime(double ratio)
{
   // 1.0 = today's volatility matches its own baseline
   return BandScore(ratio, 0.4, 2.4, 10.0);
}

double ScoreSpread()
{
   int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(MaxSpreadPoints <= 0)
      return 5.0;
   double used = (double)spread / (double)MaxSpreadPoints;
   return 10.0 * MathMax(0.0, 1.0 - used);
}

//--- composite 0-100 for the candidate on bar 1
int ScoreSetup(bool buy, double open, double close, double high, double low,
               double boxSize, double atr)
{
   double total = 0.0;
   total += ScoreRangeQuality(boxSize, atr);
   total += ScoreDisplacement(open, close, high, low);
   total += ScoreBias(buy, atr);
   total += ScoreSession(CurrentHour());
   total += ScoreRegime(AtrRegimeRatio());
   total += ScoreSpread();
   return (int)MathRound(MathMax(0.0, MathMin(100.0, total)));
}

//+------------------------------------------------------------------+
//| Signal detection                                                 |
//+------------------------------------------------------------------+
bool StrongBody(double open, double close, double high, double low)
{
   double range = high - low;
   if(range <= 0.0)
      return false;

   double body = MathAbs(close - open);
   return (body / range * 100.0) >= g_confirmBody;
}

void ExpireSignal()
{
   if(g_signal == SIGNAL_NONE)
      return;

   datetime signalClose = g_lastSignalBarTime + PeriodSeconds(g_boxTF);
   if(TimeCurrent() - signalClose > (long)MaxSignalAgeBars * PeriodSeconds(g_boxTF))
   {
      Print("Apex Drawdown Zero: signal expired after ", MaxSignalAgeBars, " bars without retest");
      g_signal = SIGNAL_NONE;
      g_signalScore = 0;
   }
}

void DetectSignal()
{
   if(!g_boxReady || g_signal != SIGNAL_NONE)
      return;
   if(HasOpenPosition() || OwnPendingTicket() != 0)
      return;
   if(!SlotAvailable(STRAT_CORE))
      return;
   if(FirewallBlocksEntry())
      return;
   if(CurrentHour() >= EffectiveLastEntryHour() || CurrentHour() < g_firstEntryHour)
      return;

   double atr = AtrValue();
   double boxSize = g_boxHigh - g_boxLow;
   double minBox = (g_minBoxAtr > 0.0 && atr > 0.0) ? g_minBoxAtr * atr
                                                  : MinBoxSizePoints * _Point;
   if(boxSize < minBox)
      return;
   // ML-informed filter: skip abnormally wide opening ranges (they underperform)
   if(MaxBoxAtr > 0.0 && atr > 0.0 && boxSize > MaxBoxAtr * atr)
      return;

   // V11: volatility regime gate - a dead session has no follow-through and
   // a blown-out one (news spike) breaks the range premise entirely
   if(UseRegimeFilter)
   {
      double ratio = AtrRegimeRatio();
      if(ratio < MinAtrRatio || ratio > MaxAtrRatio)
         return;
   }

   datetime barTime = iTime(_Symbol, g_boxTF, 1);
   if(barTime <= g_dayStart || barTime == g_lastSignalBarTime)
      return;
   if(barTime < g_boxEnd)
      return;

   double open = iOpen(_Symbol, g_boxTF, 1);
   double high = iHigh(_Symbol, g_boxTF, 1);
   double low = iLow(_Symbol, g_boxTF, 1);
   double close = iClose(_Symbol, g_boxTF, 1);
   double buffer = (g_breakBufAtr > 0.0 && atr > 0.0) ? g_breakBufAtr * atr
                                                       : BreakBufferPoints * _Point;
   double closeBack = boxSize * SweepCloseBackPercent / 100.0;
   bool strong = StrongBody(open, close, high, low);

   SignalType candidate = SIGNAL_NONE;
   double sigHigh = high;
   double sigLow = low;
   double retest = 0.0;

   if(high > g_boxHigh + buffer && close < g_boxHigh - closeBack &&
      (!g_biasSweeps || BiasOK(false)))
   {
      candidate = SIGNAL_SELL_SWEEP;
      retest = g_boxHigh;
   }
   else if(low < g_boxLow - buffer && close > g_boxLow + closeBack &&
           (!g_biasSweeps || BiasOK(true)))
   {
      candidate = SIGNAL_BUY_SWEEP;
      retest = g_boxLow;
   }
   else if(close > g_boxHigh + buffer && strong && BiasOK(true))
   {
      candidate = SIGNAL_BUY_CONTINUATION;
      retest = MathMax(g_boxHigh, (open + close) / 2.0);
   }
   else if(close < g_boxLow - buffer && strong && BiasOK(false))
   {
      candidate = SIGNAL_SELL_CONTINUATION;
      retest = MathMin(g_boxLow, (open + close) / 2.0);
   }

   if(candidate == SIGNAL_NONE)
      return;

   bool buy = (candidate == SIGNAL_BUY_SWEEP || candidate == SIGNAL_BUY_CONTINUATION);
   int score = ScoreSetup(buy, open, close, high, low, boxSize, atr);

   if(UseSignalScore && score < g_minScore)
   {
      // burn the bar so the same candle is not re-scored every tick
      g_lastSignalBarTime = barTime;
      Print("Apex Drawdown Zero: ", SignalText(candidate), " rejected - score ",
            score, " < ", g_minScore);
      return;
   }

   g_signal = candidate;
   g_activeStrat = STRAT_CORE;
   g_useCustomLevels = false;
   g_signalScore = score;
   g_signalHigh = sigHigh;
   g_signalLow = sigLow;
   g_retestLevel = retest;
   g_lastSignalBarTime = barTime;

   Print("Apex Drawdown Zero: ", SignalText(g_signal), " at ", TimeToString(barTime),
         " score ", score, " retest level ", DoubleToString(g_retestLevel, _Digits));
   DrawSignal();
}

//+------------------------------------------------------------------+
//| COMPLEMENTARY STRATEGIES (v11.60)                                |
//|                                                                  |
//| The core strategy takes at most one opening-range break per day  |
//| and sits out everything else. These three trade what it skips:   |
//|                                                                  |
//|   S1 NY session  - a second opening range at the New York open.  |
//|                    The same mechanism that already works, applied|
//|                    to the session the core usually misses because|
//|                    its single slot was spent in London.          |
//|   S2 Range fade  - compression days where the range never breaks.|
//|                    The core produces no signal at all on these;  |
//|                    fading a held edge back toward the midpoint   |
//|                    monetises them, and is structurally           |
//|                    uncorrelated with the breakout book.          |
//|   S3 Failed break- the core sweep requires the push outside the  |
//|                    range AND the rejection back inside within a  |
//|                    single candle. Most real failures take two or |
//|                    three. This catches the slower version.       |
//|                                                                  |
//| Each owns a once-per-day slot; g_maxTradesDay caps the total.   |
//| Only one position is held at a time, so adding strategies adds   |
//| opportunities, not concurrent risk.                              |
//+------------------------------------------------------------------+

//--- shared trade-slot gate: may this strategy still open today?
bool SlotAvailable(StratId sid)
{
   if(g_stopAfterWin && g_wonToday)
      return false;

   // g_oneTradePerDay is the discipline mode the EA was built around: each
   // strategy fires at most once, and g_maxTradesDay caps the total.
   if(g_oneTradePerDay)
   {
      if(g_stratDone[(int)sid])
         return false;
      if(g_tradesToday >= MathMax(1, g_maxTradesDay))
         return false;
      return true;
   }

   // High-frequency mode: a strategy may re-arm on every fresh signal bar
   // for as long as the daily budget lasts. Trade count rises sharply; see
   // the v11.80 frequency table in the changelog for what that costs.
   return g_tradesToday < MathMax(1, g_maxTradesDay);
}

//--- claim the slot once an order is actually placed
void ClaimSlot(StratId sid)
{
   g_stratDone[(int)sid] = true;
   g_tradesToday++;
   g_tradedToday = true;
}

string StratText(StratId sid)
{
   switch(sid)
   {
      case STRAT_NY:   return "NY";
      case STRAT_FADE: return "FADE";
      case STRAT_REV:  return "REV";
   }
   return "CORE";
}

//+------------------------------------------------------------------+
//| S1 - New York opening range                                      |
//+------------------------------------------------------------------+
bool BuildNYBox()
{
   if(g_nyBoxReady)
      return true;
   if(CurrentHour() < NYBoxStartHour + NYBoxCandles)
      return false;

   // collect the NYBoxCandles closed bars starting at NYBoxStartHour today
   double high = -DBL_MAX, low = DBL_MAX;
   int found = 0;
   for(int shift = 1; shift < 200 && found < NYBoxCandles; shift++)
   {
      datetime bt = iTime(_Symbol, g_boxTF, shift);
      if(bt == 0 || bt < g_dayStart)
         break;
      MqlDateTime dt;
      TimeToStruct(bt, dt);
      if(dt.hour < NYBoxStartHour || dt.hour >= NYBoxStartHour + NYBoxCandles)
         continue;
      high = MathMax(high, iHigh(_Symbol, g_boxTF, shift));
      low  = MathMin(low,  iLow(_Symbol, g_boxTF, shift));
      if(found == 0)
         g_nyBoxEnd = bt + PeriodSeconds(g_boxTF);
      g_nyBoxStart = bt;
      found++;
   }
   if(found < NYBoxCandles)
      return false;

   g_nyBoxHigh = high;
   g_nyBoxLow = low;
   g_nyBoxReady = true;
   return true;
}

void DetectNYSignal()
{
   if(!g_useNY || g_signal != SIGNAL_NONE)
      return;
   if(!SlotAvailable(STRAT_NY))
      return;
   if(HasOpenPosition() || OwnPendingTicket() != 0)
      return;
   if(FirewallBlocksEntry())
      return;
   if(CurrentHour() >= NYLastEntryHour)
      return;
   if(!BuildNYBox())
      return;

   double atr = AtrValue();
   double boxSize = g_nyBoxHigh - g_nyBoxLow;
   if(boxSize <= 0.0)
      return;
   double minBox = (g_minBoxAtr > 0.0 && atr > 0.0) ? g_minBoxAtr * atr * 0.6
                                                  : MinBoxSizePoints * _Point;
   if(boxSize < minBox)
      return;
   if(MaxBoxAtr > 0.0 && atr > 0.0 && boxSize > MaxBoxAtr * atr)
      return;

   datetime barTime = iTime(_Symbol, g_boxTF, 1);
   if(barTime < g_nyBoxEnd || barTime == g_lastSignalBarTime)
      return;

   double open  = iOpen(_Symbol, g_boxTF, 1);
   double high  = iHigh(_Symbol, g_boxTF, 1);
   double low   = iLow(_Symbol, g_boxTF, 1);
   double close = iClose(_Symbol, g_boxTF, 1);
   double buffer = (g_breakBufAtr > 0.0 && atr > 0.0) ? g_breakBufAtr * atr
                                                       : BreakBufferPoints * _Point;
   if(!StrongBody(open, close, high, low))
      return;

   SignalType cand = SIGNAL_NONE;
   if(close > g_nyBoxHigh + buffer && BiasOK(true))
      cand = SIGNAL_BUY_CONTINUATION;
   else if(close < g_nyBoxLow - buffer && BiasOK(false))
      cand = SIGNAL_SELL_CONTINUATION;
   if(cand == SIGNAL_NONE)
      return;

   bool buy = (cand == SIGNAL_BUY_CONTINUATION);
   int score = ScoreSetup(buy, open, close, high, low, boxSize, atr);
   if(UseSignalScore && score < g_minScore)
   {
      g_lastSignalBarTime = barTime;
      return;
   }

   g_signal = cand;
   g_activeStrat = STRAT_NY;
   g_signalScore = score;
   g_signalHigh = high;
   g_signalLow = low;
   g_retestLevel = buy ? g_nyBoxHigh : g_nyBoxLow;
   g_lastSignalBarTime = barTime;
   g_useCustomLevels = false;
   Print("Apex Drawdown Zero [NY]: ", SignalText(g_signal), " score ", score,
         " NY box ", DoubleToString(g_nyBoxLow, _Digits), "-",
         DoubleToString(g_nyBoxHigh, _Digits));
}

//+------------------------------------------------------------------+
//| S2 - compression-day range fade                                  |
//| Only on days the core never armed: a narrow opening range that is|
//| still intact late in the session. Target is the midpoint area,   |
//| not an R multiple, so the fade carries its own SL/TP levels.     |
//+------------------------------------------------------------------+
void DetectFadeSignal()
{
   if(!UseRangeFade || g_signal != SIGNAL_NONE)
      return;
   if(!SlotAvailable(STRAT_FADE))
      return;
   if(HasOpenPosition() || OwnPendingTicket() != 0)
      return;
   if(FirewallBlocksEntry())
      return;
   if(!g_boxReady)
      return;
   if(CurrentHour() < FadeFromHour || CurrentHour() >= EffectiveLastEntryHour())
      return;
   // a fade is only valid while the range is still unbroken: if the core
   // already fired, or anything traded, this is a trending day, not a range
   if(g_stratDone[(int)STRAT_CORE] || g_tradesToday > 0)
      return;

   double atr = AtrValue();
   if(atr <= 0.0)
      return;
   double boxSize = g_boxHigh - g_boxLow;
   if(boxSize <= 0.0)
      return;
   if(boxSize > FadeMaxBoxAtr * atr)      // not a compression day
      return;

   // has price essentially stayed inside the range today? A day that never
   // once closed outside is much rarer than a compression day, so allow a
   // small number of pokes before disqualifying it.
   int outside = 0;
   for(int shift = 1; shift < 200; shift++)
   {
      datetime bt = iTime(_Symbol, g_boxTF, shift);
      if(bt == 0 || bt < g_boxEnd)
         break;
      double c = iClose(_Symbol, g_boxTF, shift);
      if(c > g_boxHigh || c < g_boxLow)
         outside++;
   }
   if(outside > FadeMaxBreakBars)
      return;                             // the range genuinely broke
   // and it must be back inside right now
   if(iClose(_Symbol, g_boxTF, 1) > g_boxHigh ||
      iClose(_Symbol, g_boxTF, 1) < g_boxLow)
      return;

   double edge = boxSize * FadeEdgePercent / 100.0;
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   bool fadeShort = (bid >= g_boxHigh - edge);
   bool fadeLong  = (ask <= g_boxLow + edge);
   if(!fadeShort && !fadeLong)
      return;

   bool buy = fadeLong;
   double entry = buy ? ask : bid;
   double sl = buy ? g_boxLow  - FadeStopAtr * atr
                   : g_boxHigh + FadeStopAtr * atr;
   double tp = buy ? g_boxLow  + boxSize * FadeTargetPercent / 100.0
                   : g_boxHigh - boxSize * FadeTargetPercent / 100.0;

   double guard = GuardDistance();
   if(MathAbs(entry - sl) <= guard || MathAbs(tp - entry) <= guard)
      return;
   // never take a fade whose reward is worse than half its risk
   if(MathAbs(tp - entry) < 0.5 * MathAbs(entry - sl))
      return;

   g_signal = buy ? SIGNAL_BUY_SWEEP : SIGNAL_SELL_SWEEP;
   g_activeStrat = STRAT_FADE;
   g_signalScore = g_minScore;            // fades are gated by structure, not score
   g_signalHigh = g_boxHigh;
   g_signalLow = g_boxLow;
   g_retestLevel = buy ? g_boxLow : g_boxHigh;
   g_customSl = sl;
   g_customTp = tp;
   g_useCustomLevels = true;
   g_lastSignalBarTime = iTime(_Symbol, g_boxTF, 1);
   Print("Apex Drawdown Zero [FADE]: ", buy ? "BUY" : "SELL",
         " at box edge, target ", DoubleToString(tp, _Digits),
         " stop ", DoubleToString(sl, _Digits));
}

//+------------------------------------------------------------------+
//| S3 - multi-bar failed breakout                                   |
//| A push outside the range that is rejected over the following one |
//| to FailedBreakBars candles. The core sweep only sees this when   |
//| the whole round trip fits inside a single candle.                |
//+------------------------------------------------------------------+
void DetectFailedBreakSignal()
{
   if(!UseFailedBreak || g_signal != SIGNAL_NONE)
      return;
   if(!SlotAvailable(STRAT_REV))
      return;
   if(HasOpenPosition() || OwnPendingTicket() != 0)
      return;
   if(FirewallBlocksEntry())
      return;
   if(!g_boxReady)
      return;
   if(CurrentHour() >= EffectiveLastEntryHour() || CurrentHour() < g_firstEntryHour)
      return;

   double atr = AtrValue();
   if(atr <= 0.0)
      return;
   double boxSize = g_boxHigh - g_boxLow;
   if(boxSize <= 0.0)
      return;

   datetime barTime = iTime(_Symbol, g_boxTF, 1);
   if(barTime == g_lastSignalBarTime || barTime < g_boxEnd)
      return;

   double close1 = iClose(_Symbol, g_boxTF, 1);
   // the confirming bar must have closed back INSIDE the range
   if(close1 > g_boxHigh || close1 < g_boxLow)
      return;

   double push = FailedBreakMinPushAtr * atr;
   bool brokeUp = false, brokeDown = false;

   for(int shift = 2; shift <= 1 + FailedBreakBars; shift++)
   {
      datetime bt = iTime(_Symbol, g_boxTF, shift);
      if(bt == 0 || bt < g_boxEnd)
         break;
      if(iHigh(_Symbol, g_boxTF, shift) > g_boxHigh + push) brokeUp = true;
      if(iLow(_Symbol, g_boxTF, shift)  < g_boxLow  - push) brokeDown = true;
   }
   if(brokeUp == brokeDown)          // neither, or both (chop): stand aside
      return;

   bool buy = brokeDown;             // failed downside break -> go long
   if(g_useBias && g_biasSweeps && !BiasOK(buy))
      return;

   double open = iOpen(_Symbol, g_boxTF, 1);
   double high = iHigh(_Symbol, g_boxTF, 1);
   double low  = iLow(_Symbol, g_boxTF, 1);
   int score = ScoreSetup(buy, open, close1, high, low, boxSize, atr);
   if(UseSignalScore && score < g_minScore)
   {
      g_lastSignalBarTime = barTime;
      return;
   }

   // the stop goes beyond the failed push extreme, not just this candle
   double ext = buy ? g_boxLow : g_boxHigh;
   for(int shift = 1; shift <= 1 + FailedBreakBars; shift++)
   {
      datetime bt = iTime(_Symbol, g_boxTF, shift);
      if(bt == 0 || bt < g_boxEnd)
         break;
      ext = buy ? MathMin(ext, iLow(_Symbol, g_boxTF, shift))
                : MathMax(ext, iHigh(_Symbol, g_boxTF, shift));
   }

   g_signal = buy ? SIGNAL_BUY_SWEEP : SIGNAL_SELL_SWEEP;
   g_activeStrat = STRAT_REV;
   g_signalScore = score;
   g_signalHigh = buy ? high : ext;
   g_signalLow  = buy ? ext  : low;
   g_retestLevel = buy ? g_boxLow : g_boxHigh;
   g_useCustomLevels = false;
   g_lastSignalBarTime = barTime;
   Print("Apex Drawdown Zero [REV]: failed ", brokeDown ? "downside" : "upside",
         " break, ", buy ? "BUY" : "SELL", " score ", score);
}

//+------------------------------------------------------------------+
//| Candle-confirmation entry (ENTRY_RETEST_CANDLE)                  |
//+------------------------------------------------------------------+
bool EntryConfirmation(bool buy)
{
   datetime barTime = iTime(_Symbol, g_entryTF, 1);
   if(barTime == 0 || barTime == g_lastEntryBarTime)
      return false;
   if(barTime < g_lastSignalBarTime + PeriodSeconds(g_boxTF))
      return false;

   double open = iOpen(_Symbol, g_entryTF, 1);
   double high = iHigh(_Symbol, g_entryTF, 1);
   double low = iLow(_Symbol, g_entryTF, 1);
   double close = iClose(_Symbol, g_entryTF, 1);
   double tolerance = (g_boxHigh - g_boxLow) * RetestTolerancePercent / 100.0;
   double minZone = g_retestLevel - tolerance;
   double maxZone = g_retestLevel + tolerance;

   if(buy)
      return low <= maxZone && low >= minZone && close > open && close >= g_retestLevel;

   return high >= minZone && high <= maxZone && close < open && close <= g_retestLevel;
}

//+------------------------------------------------------------------+
//| Sizing                                                           |
//+------------------------------------------------------------------+
int VolumeDigits()
{
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   int digits = 0;
   while(digits < 8 && MathAbs(step - MathRound(step)) > 1e-9)
   {
      step *= 10.0;
      digits++;
   }
   return digits;
}

double NormalizeVolume(double lots)
{
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   lots = MathMax(minLot, MathMin(maxLot, lots));
   if(step > 0.0)
      lots = MathFloor(lots / step) * step;

   return NormalizeDouble(lots, VolumeDigits());
}

double LotsForRisk(double entry, double stop, double riskPercent)
{
   double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * riskPercent / 100.0;
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double stopDistance = MathAbs(entry - stop);

   if(riskMoney <= 0.0 || tickValue <= 0.0 || tickSize <= 0.0 || stopDistance <= 0.0)
      return 0.0;

   double lossPerLot = stopDistance / tickSize * tickValue;
   if(lossPerLot <= 0.0)
      return 0.0;

   double lots = riskMoney / lossPerLot;
   if(MaxLots > 0.0 && lots > MaxLots)
      lots = MaxLots;

   return NormalizeVolume(lots);
}

//+------------------------------------------------------------------+
//| Total open + pending volume on this symbol (any magic) —         |
//| SYMBOL_VOLUME_LIMIT applies per symbol, not per EA.              |
//+------------------------------------------------------------------+
double SymbolExposure()
{
   double vol = 0.0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetTicket(i) == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol)
         vol += PositionGetDouble(POSITION_VOLUME);
   }

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderGetTicket(i) == 0)
         continue;
      if(OrderGetString(ORDER_SYMBOL) == _Symbol)
         vol += OrderGetDouble(ORDER_VOLUME_CURRENT);
   }

   return vol;
}

//+------------------------------------------------------------------+
//| Reduce volume to what the broker allows: SYMBOL_VOLUME_LIMIT     |
//| minus current exposure, then free margin via OrderCalcMargin     |
//| (MQL5 Market "volume limit" + "not enough money" checks).        |
//| Returns 0 if even min lot won't fit.                             |
//+------------------------------------------------------------------+
double CapLotsByMargin(bool buy, double price, double lots)
{
   if(lots <= 0.0)
      return 0.0;

   ENUM_ORDER_TYPE type = buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step <= 0.0)
      step = minLot;

   double volumeLimit = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);
   if(volumeLimit > 0.0)
   {
      double room = volumeLimit - SymbolExposure();
      if(room < minLot)
         return 0.0;
      if(lots > room)
         lots = NormalizeVolume(room);
   }

   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE) * 0.95;

   for(int i = 0; i < 1000 && lots >= minLot; i++)
   {
      double margin = 0.0;
      if(!OrderCalcMargin(type, _Symbol, lots, price, margin))
         return 0.0;
      if(margin <= freeMargin)
         return lots;

      // scale down toward what free margin can carry, then step-align
      double scaled = NormalizeVolume(lots * freeMargin / margin);
      double next = (scaled < lots) ? scaled : NormalizeVolume(lots - step);
      if(next >= lots)   // NormalizeVolume clamps at min lot: nothing smaller fits
         return 0.0;
      lots = next;
   }
   return 0.0;
}

//+------------------------------------------------------------------+
//| Stop placement                                                   |
//| ATR-adaptive when enabled (stop scales with volatility), else    |
//| the classic fixed buffer beyond the signal extreme. The ATR      |
//| distance is anchored to the entry price and floored at the       |
//| signal extreme so the stop is never tighter than the structure.  |
//+------------------------------------------------------------------+
double StopForEntry(bool buy, double entry)
{
   double stopBuffer = StopBufferPoints * _Point;
   double structural = buy ? g_signalLow - stopBuffer : g_signalHigh + stopBuffer;

   if(UseAtrStop && g_atrHandle != INVALID_HANDLE)
   {
      double atr = AtrValue();
      if(atr > 0.0)
      {
         double dist = atr * g_atrStopMult;
         double atrSl = buy ? entry - dist : entry + dist;
         // keep the wider (safer) of ATR and structural stop
         return buy ? MathMin(atrSl, structural) : MathMax(atrSl, structural);
      }
   }
   return structural;
}

//+------------------------------------------------------------------+
//| Entry                                                            |
//+------------------------------------------------------------------+
bool MarketEnter(bool buy)
{
   double entry = buy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   // the range fade prices its own stop and target off the box structure
   // rather than an R multiple, so it supplies them directly
   double sl = g_useCustomLevels ? g_customSl : StopForEntry(buy, entry);

   // never send SL/TP inside the broker's stops/freeze level (avoids "invalid stops")
   double guard = GuardDistance();
   if(buy  && entry - sl < guard) sl = entry - guard;
   if(!buy && sl - entry < guard) sl = entry + guard;

   double risk = MathAbs(entry - sl);
   if(risk <= 0.0)
      return false;

   double tp = g_useCustomLevels ? g_customTp
                                 : (buy ? entry + risk * g_riskReward
                                        : entry - risk * g_riskReward);
   if(buy  && tp - entry < guard) tp = entry + guard;
   if(!buy && entry - tp < guard) tp = entry - guard;
   sl = NormalizeDouble(sl, _Digits);
   tp = NormalizeDouble(tp, _Digits);

   double lots = LotsForRisk(entry, sl, EffectiveRiskPercent(g_signalScore));
   if(lots <= 0.0)
   {
      Print("Apex Drawdown Zero: sizing unavailable (tick value/size), trade skipped");
      return false;
   }

   lots = CapLotsByMargin(buy, entry, lots);
   if(lots <= 0.0)
   {
      Print("Apex Drawdown Zero: insufficient free margin even for min lot, trade skipped");
      return false;
   }

   string tag = StringFormat("ADZ11 %s %s s%d", StratText(g_activeStrat),
                             buy ? "buy" : "sell", g_signalScore);
   return buy ? trade.Buy(lots, _Symbol, entry, sl, tp, tag)
              : trade.Sell(lots, _Symbol, entry, sl, tp, tag);
}

bool PlaceRetestLimit(bool buy)
{
   double level = NormalizeDouble(g_retestLevel, _Digits);
   double sl = StopForEntry(buy, level);
   double risk = MathAbs(level - sl);
   if(risk <= 0.0)
      return false;

   double tp = buy ? level + risk * g_riskReward : level - risk * g_riskReward;
   double lots = LotsForRisk(level, sl, EffectiveRiskPercent(g_signalScore));
   if(lots <= 0.0)
   {
      Print("Apex Drawdown Zero: sizing unavailable (tick value/size), trade skipped");
      return false;
   }

   lots = CapLotsByMargin(buy, level, lots);
   if(lots <= 0.0)
   {
      Print("Apex Drawdown Zero: insufficient free margin even for min lot, trade skipped");
      return false;
   }

   double minStop = GuardDistance();
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // price already at/through the retest level: take it at market instead
   if(buy && ask - level < minStop)
      return MarketEnter(true);
   if(!buy && level - bid < minStop)
      return MarketEnter(false);

   sl = NormalizeDouble(sl, _Digits);
   tp = NormalizeDouble(tp, _Digits);

   string tag = StringFormat("ADZ11 %s retest s%d", buy ? "buy" : "sell", g_signalScore);
   bool ok = buy ? trade.BuyLimit(lots, level, _Symbol, sl, tp, ORDER_TIME_GTC, 0, tag)
                 : trade.SellLimit(lots, level, _Symbol, sl, tp, ORDER_TIME_GTC, 0, tag);

   if(ok)
   {
      long signalClose = (long)g_lastSignalBarTime + PeriodSeconds(g_boxTF);
      long expiry = signalClose + (long)MaxSignalAgeBars * PeriodSeconds(g_boxTF);
      long dayEnd = (long)g_dayStart + 86400;
      g_pendingExpiry = (datetime)MathMin(expiry, dayEnd);
      Print("Apex Drawdown Zero: retest limit placed at ", DoubleToString(level, _Digits),
            " expires ", TimeToString(g_pendingExpiry));
   }
   return ok;
}

void TryEnter()
{
   if(g_signal == SIGNAL_NONE)
      return;
   if(FirewallBlocksEntry())
   {
      g_signal = SIGNAL_NONE;
      return;
   }
   if(HasOpenPosition() || OwnPendingTicket() != 0)
   {
      g_signal = SIGNAL_NONE;
      return;
   }
   if(!SlotAvailable(g_activeStrat))
   {
      g_signal = SIGNAL_NONE;
      return;
   }
   // the NY setup owns a later cutoff than the London session window
   int lastHour = (g_activeStrat == STRAT_NY) ? NYLastEntryHour : EffectiveLastEntryHour();
   int firstHour = (g_activeStrat == STRAT_NY) ? NYBoxStartHour : g_firstEntryHour;
   if(CurrentHour() >= lastHour || CurrentHour() < firstHour)
      return;

   int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread > MaxSpreadPoints)
      return;

   bool buy = (g_signal == SIGNAL_BUY_SWEEP || g_signal == SIGNAL_BUY_CONTINUATION);

   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(SlippagePoints);

   bool done = false;

   // a fade is triggered BY price being at its level, so it always goes to
   // market - a retest order would sit behind a level price already touched
   EntryStyleMode style = (g_activeStrat == STRAT_FADE) ? ENTRY_IMMEDIATE : EntryStyle;

   switch(style)
   {
      case ENTRY_IMMEDIATE:
         done = MarketEnter(buy);
         if(done)
            ClaimSlot(g_activeStrat);
         break;

      case ENTRY_RETEST_LIMIT:
         done = PlaceRetestLimit(buy);
         if(done)
            ClaimSlot(g_activeStrat);
         break;

      case ENTRY_RETEST_CANDLE:
         if(!EntryConfirmation(buy))
            return;
         done = MarketEnter(buy);
         if(done)
         {
            ClaimSlot(g_activeStrat);
            g_lastEntryBarTime = iTime(_Symbol, g_entryTF, 1);
         }
         break;
   }

   if(done)
   {
      g_signal = SIGNAL_NONE;
      g_useCustomLevels = false;
   }
}

//+------------------------------------------------------------------+
//| ADAPTIVE EXIT ENGINE                                             |
//| Per-ticket, so a pyramid add-on and a partially-closed base are  |
//| each managed on their own terms. Order of operations per ticket: |
//|   1) time stop   - is this setup going anywhere at all?          |
//|   2) partial TP  - bank PartialClosePercent at TP1               |
//|   3) break-even  - remove the remaining risk                     |
//|   4) chandelier  - trail the runner off its best excursion       |
//+------------------------------------------------------------------+

//--- safe SL modification: respects stops/freeze distance both for the
//--- new level and for the levels already attached to the position
bool SafeModifySL(ulong ticket, double newSl, double tp, bool isBuy, double price)
{
   double guard = GuardDistance();
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   if(tp > 0.0 && MathAbs(price - tp) <= guard)
      return false;
   if(isBuy && bid - newSl <= guard)
      return false;
   if(!isBuy && newSl - ask <= guard)
      return false;

   return trade.PositionModify(ticket, NormalizeDouble(newSl, _Digits), tp);
}

void ManageTicket(int idx)
{
   ulong ticket = g_states[idx].ticket;
   if(!PositionSelectByTicket(ticket))
      return;

   bool   isBuy = g_states[idx].isBuy;
   double entry = g_states[idx].entry;
   double initRisk = g_states[idx].initRisk;
   double sl = PositionGetDouble(POSITION_SL);
   double tp = PositionGetDouble(POSITION_TP);
   double volume = PositionGetDouble(POSITION_VOLUME);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double price = isBuy ? bid : ask;

   if(initRisk <= 0.0)
      return;

   double profitDist = isBuy ? price - entry : entry - price;
   double rNow = profitDist / initRisk;

   // track the maximum favourable excursion for the chandelier, and the
   // adverse one for the excursion diagnostics
   if(isBuy)
   {
      g_states[idx].bestPrice  = MathMax(g_states[idx].bestPrice, bid);
      g_states[idx].worstPrice = MathMin(g_states[idx].worstPrice, bid);
   }
   else
   {
      g_states[idx].bestPrice  = MathMin(g_states[idx].bestPrice, ask);
      g_states[idx].worstPrice = MathMax(g_states[idx].worstPrice, ask);
   }

   // --- 1) time stop: a setup that has not moved in TimeStopBars bars is
   //     dead money; close it and free the day rather than wait for the stop
   if(UseTimeStop && TimeStopBars > 0)
   {
      long age = (long)(TimeCurrent() - g_states[idx].openTime);
      long limit = (long)TimeStopBars * PeriodSeconds(g_boxTF);
      if(age >= limit && rNow < TimeStopMinRR)
      {
         if(trade.PositionClose(ticket, SlippagePoints))
         {
            Print("Apex Drawdown Zero: time stop closed ", ticket, " at ",
                  DoubleToString(rNow, 2), "R after ", TimeStopBars, " bars");
            return;
         }
      }
   }

   // --- 2) partial take-profit: bank part of the position at TP1 so the
   //     remainder can run without the trade ever turning into a loser
   if(UsePartialTP && !g_states[idx].partialDone && PartialClosePercent > 0 &&
      PartialTP_RR > 0.0 && rNow >= PartialTP_RR)
   {
      double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double closeVol = NormalizeVolume(volume * PartialClosePercent / 100.0);
      double remain = volume - closeVol;

      // only split when both halves are tradeable sizes
      if(closeVol >= minLot && remain >= minLot)
      {
         if(trade.PositionClosePartial(ticket, closeVol, SlippagePoints))
         {
            g_states[idx].partialDone = true;
            Print("Apex Drawdown Zero: partial TP ", DoubleToString(closeVol, VolumeDigits()),
                  " lots at ", DoubleToString(rNow, 2), "R, ",
                  DoubleToString(remain, VolumeDigits()), " left running");
            return;   // re-read the position on the next tick
         }
      }
      else
      {
         // position too small to split: don't retry every tick
         g_states[idx].partialDone = true;
      }
   }

   double newSl = sl;

   // --- 3) break-even
   if(UseBreakEven && rNow >= BreakEvenTriggerRR)
   {
      double be = isBuy ? entry + BreakEvenOffsetPoints * _Point
                        : entry - BreakEvenOffsetPoints * _Point;
      if(sl == 0.0 || (isBuy ? be > newSl : be < newSl))
         newSl = be;
   }

   // --- 3b) profit-lock ladder: the answer to "it goes my way and then
   //     hands it all back". Measured on the excursion log: half of all
   //     trades reach 1.0R but only 38% reach the 2.0R target, so the
   //     ground between them was being returned to the market. The ladder
   //     converts reached progress into a floor. It is a ratchet, not a
   //     trail: it never closes the position, so unlike the chandelier and
   //     the time stop it cannot truncate a trade that is still working.
   if(UseProfitLadder)
   {
      double mfeR = (isBuy ? g_states[idx].bestPrice - entry
                           : entry - g_states[idx].bestPrice) / initRisk;
      double lockR = 0.0;
      if(Ladder2_MFE > 0.0 && mfeR >= Ladder2_MFE)      lockR = Ladder2_Lock;
      else if(Ladder1_MFE > 0.0 && mfeR >= Ladder1_MFE) lockR = Ladder1_Lock;

      if(lockR > 0.0)
      {
         double lock = isBuy ? entry + lockR * initRisk
                             : entry - lockR * initRisk;
         if(sl == 0.0 || (isBuy ? lock > newSl : lock < newSl))
            newSl = lock;
      }
   }

   // --- 4a) chandelier trail on the runner: anchored to the best price
   //     reached, not the current one, so noise does not ratchet the stop
   if(UseChandelierTrail && rNow >= TrailAfterRR)
   {
      double atr = AtrValue();
      if(atr > 0.0)
      {
         double trail = isBuy ? g_states[idx].bestPrice - ChandelierAtrMult * atr
                              : g_states[idx].bestPrice + ChandelierAtrMult * atr;
         if(sl == 0.0 || (isBuy ? trail > newSl : trail < newSl))
            newSl = trail;
      }
   }

   // --- 4b) legacy R-trailing (kept for v9 parity; off by default)
   if(UseTrailing && rNow >= TrailStartRR)
   {
      double trail = isBuy ? price - TrailDistanceRR * initRisk
                           : price + TrailDistanceRR * initRisk;
      if(sl == 0.0 || (isBuy ? trail > newSl : trail < newSl))
         newSl = trail;
   }

   if(newSl == sl)
      return;
   if(sl != 0.0 && MathAbs(newSl - sl) < TrailStepPoints * _Point)
      return;

   // freeze guard: modification is rejected while the existing SL sits
   // within the freeze/stops distance of the market
   double guard = GuardDistance();
   if(sl != 0.0 && MathAbs(price - sl) <= guard)
      return;

   if(SafeModifySL(ticket, newSl, tp, isBuy, price))
   {
      bool locked = isBuy ? newSl >= entry : newSl <= entry;
      if(locked)
         g_states[idx].beDone = true;
   }
}

void ManageOpenTrades()
{
   PruneStates();

   ulong tickets[];
   int n = OwnPositionTickets(tickets);
   for(int i = 0; i < n; i++)
   {
      int idx = EnsureState(tickets[i]);
      if(idx >= 0)
         ManageTicket(idx);
   }
}

//+------------------------------------------------------------------+
//| Pyramiding — scale into a winner                                 |
//| When the base trade reaches PyramidTriggerRR of its target, open |
//| one add-on unit (own risk %, stop at the base entry / break-even,|
//| same TP) and lock the base position at break-even. Adds at most  |
//| once per day. Requires a hedging account: on netting, a second   |
//| market order averages into the base position instead of forming  |
//| a separate leg, so pyramiding is disabled there.                 |
//+------------------------------------------------------------------+
void ManagePyramid()
{
   if(!UsePyramid || g_addedToday)
      return;
   if(FirewallBlocksEntry())
      return;

   if(AccountInfoInteger(ACCOUNT_MARGIN_MODE) != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
   {
      static bool warned = false;
      if(!warned)
      {
         Print("Apex Drawdown Zero: pyramiding needs a hedging account - feature disabled.");
         warned = true;
      }
      return;
   }

   ulong ticket = OwnPositionTicket();
   if(ticket == 0 || !PositionSelectByTicket(ticket))
      return;

   bool isBuy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
   double entry = PositionGetDouble(POSITION_PRICE_OPEN);
   double tp = PositionGetDouble(POSITION_TP);
   if(tp <= 0.0 || g_riskReward <= 0.0)
      return;

   double initRisk = MathAbs(tp - entry) / g_riskReward;
   if(initRisk <= 0.0)
      return;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double price = isBuy ? bid : ask;
   double profitDist = isBuy ? price - entry : entry - price;

   if(profitDist < PyramidTriggerRR * initRisk)
      return;

   double addEntry = isBuy ? ask : bid;
   double addSl = isBuy ? entry + BreakEvenOffsetPoints * _Point
                        : entry - BreakEvenOffsetPoints * _Point;
   double guard = GuardDistance();
   if(MathAbs(addEntry - addSl) <= guard)   // add stop too close to market
      return;

   double lots = LotsForRisk(addEntry, addSl, EffectiveRiskPercent(g_signalScore));
   if(lots > 0.0)
      lots = CapLotsByMargin(isBuy, addEntry, lots);
   if(lots <= 0.0)
   {
      Print("Apex Drawdown Zero: pyramid add skipped (sizing/margin/volume limit)");
      g_addedToday = true;   // don't retry every tick
      return;
   }

   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(SlippagePoints);

   bool ok = isBuy
      ? trade.Buy(lots, _Symbol, addEntry, NormalizeDouble(addSl, _Digits), tp, "ADZ11 pyramid")
      : trade.Sell(lots, _Symbol, addEntry, NormalizeDouble(addSl, _Digits), tp, "ADZ11 pyramid");
   if(!ok)
      return;

   g_addedToday = true;
   Print("Apex Drawdown Zero: pyramid add-on opened ", DoubleToString(lots, VolumeDigits()),
         " lots @ ", DoubleToString(addEntry, _Digits));

   // lock the base position at break-even
   if(PositionSelectByTicket(ticket))
   {
      double oSl = PositionGetDouble(POSITION_SL);
      double oTp = PositionGetDouble(POSITION_TP);
      double be = isBuy ? entry + BreakEvenOffsetPoints * _Point
                        : entry - BreakEvenOffsetPoints * _Point;
      bool improve = (oSl == 0.0) || (isBuy ? be > oSl : be < oSl);
      bool roomOk = isBuy ? (bid - be > guard) : (be - ask > guard);
      if(improve && roomOk)
         trade.PositionModify(ticket, NormalizeDouble(be, _Digits), oTp);
   }
}

//+------------------------------------------------------------------+
//| Trade journal (optional CSV in MQL5/Files)                       |
//+------------------------------------------------------------------+
void JournalDeal(ulong deal, double profit)
{
   if(!WriteTradeJournal || MQLInfoInteger(MQL_OPTIMIZATION))
      return;

   string file = StringFormat("ApexDrawdownZero_%s_%I64u.csv", _Symbol, MagicNumber);
   bool fresh = !FileIsExist(file);

   int h = FileOpen(file, FILE_WRITE | FILE_READ | FILE_CSV | FILE_ANSI, ',');
   if(h == INVALID_HANDLE)
      return;

   if(fresh)
      FileWrite(h, "close_time", "symbol", "volume", "price", "profit",
                "day_pl_pct", "consec_losses", "preset");
   else
      FileSeek(h, 0, SEEK_END);

   FileWrite(h,
             TimeToString((datetime)HistoryDealGetInteger(deal, DEAL_TIME), TIME_DATE | TIME_MINUTES),
             _Symbol,
             DoubleToString(HistoryDealGetDouble(deal, DEAL_VOLUME), 2),
             DoubleToString(HistoryDealGetDouble(deal, DEAL_PRICE), _Digits),
             DoubleToString(profit, 2),
             DoubleToString(DayPLPercent(), 2),
             IntegerToString(g_consecLosses),
             g_presetName);
   FileClose(h);
}

//+------------------------------------------------------------------+
//| Daily result tracking + streak accounting                        |
//| Walks closed deals once per new deal. Feeds three things: the    |
//| day's realised P/L (the daily loss cap), the consecutive-loss    |
//| counter (cooldown + risk de-escalation) and the running stats    |
//| shown on the dashboard.                                          |
//+------------------------------------------------------------------+
void UpdateClosedDeals()
{
   static int lastTotal = -1;

   if(!HistorySelect(g_dayStart, TimeCurrent() + 60))
      return;

   int total = HistoryDealsTotal();
   if(total == lastTotal)
      return;
   lastTotal = total;

   double dayRealized = 0.0;

   for(int i = 0; i < total; i++)
   {
      ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
         continue;
      if((ulong)HistoryDealGetInteger(deal, DEAL_MAGIC) != MagicNumber)
         continue;
      if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY) != DEAL_ENTRY_OUT)
         continue;

      double profit = HistoryDealGetDouble(deal, DEAL_PROFIT)
                    + HistoryDealGetDouble(deal, DEAL_SWAP)
                    + HistoryDealGetDouble(deal, DEAL_COMMISSION);

      dayRealized += profit;
      if(profit > 0.0)
         g_wonToday = true;

      // streak + stats update, once per deal
      if(deal > g_lastSeenDeal)
      {
         g_lastSeenDeal = deal;

         if(profit > 0.0)
         {
            g_statWins++;
            g_statProfit += profit;
            g_consecLosses = 0;              // a win rebuilds full risk
         }
         else if(profit < 0.0)
         {
            g_statLosses++;
            g_statLoss += -profit;
            g_consecLosses++;

            if(UseRiskFirewall && MaxConsecutiveLosses > 0 &&
               g_consecLosses >= MaxConsecutiveLosses)
            {
               g_cooldownUntilDay = (datetime)((long)g_dayStart +
                                    (long)MathMax(1, CooldownDays) * 86400);
               Print("Apex Drawdown Zero: ", g_consecLosses,
                     " losses in a row - cooldown until ",
                     TimeToString(g_cooldownUntilDay, TIME_DATE));
            }
         }

         JournalDeal(deal, profit);
      }
   }

   g_dayRealized = dayRealized;
}

//--- rebuild the streak counter and lifetime stats after a restart, so
//--- de-escalation and the cooldown survive a terminal reboot
void RebuildHistoryState()
{
   if(!HistorySelect(TimeCurrent() - 90 * 86400, TimeCurrent() + 60))
      return;

   int total = HistoryDealsTotal();
   double results[];
   ArrayResize(results, 0);

   for(int i = 0; i < total; i++)
   {
      ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
         continue;
      if((ulong)HistoryDealGetInteger(deal, DEAL_MAGIC) != MagicNumber)
         continue;
      if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY) != DEAL_ENTRY_OUT)
         continue;

      double profit = HistoryDealGetDouble(deal, DEAL_PROFIT)
                    + HistoryDealGetDouble(deal, DEAL_SWAP)
                    + HistoryDealGetDouble(deal, DEAL_COMMISSION);

      if(profit > 0.0)      { g_statWins++;   g_statProfit += profit; }
      else if(profit < 0.0) { g_statLosses++; g_statLoss += -profit; }

      // mark this deal as already accounted for
      if(deal > g_lastSeenDeal)
         g_lastSeenDeal = deal;

      int n = ArraySize(results);
      ArrayResize(results, n + 1);
      results[n] = profit;
   }

   // consecutive losses = losing tail of the result series
   g_consecLosses = 0;
   for(int i = ArraySize(results) - 1; i >= 0; i--)
   {
      if(results[i] < 0.0)
         g_consecLosses++;
      else if(results[i] > 0.0)
         break;
   }

   if(g_consecLosses > 0)
      Print("Apex Drawdown Zero: restored loss streak = ", g_consecLosses,
            " (risk de-escalation active)");
}

//+------------------------------------------------------------------+
//| Chart visualization                                              |
//+------------------------------------------------------------------+
string SignalText(SignalType s)
{
   switch(s)
   {
      case SIGNAL_BUY_SWEEP:          return "BUY SWEEP";
      case SIGNAL_SELL_SWEEP:         return "SELL SWEEP";
      case SIGNAL_BUY_CONTINUATION:   return "BUY CONTINUATION";
      case SIGNAL_SELL_CONTINUATION:  return "SELL CONTINUATION";
   }
   return "NONE";
}

string EntryStyleText()
{
   switch(EntryStyle)
   {
      case ENTRY_RETEST_LIMIT:  return "RETEST LIMIT";
      case ENTRY_RETEST_CANDLE: return "RETEST CANDLE";
      case ENTRY_IMMEDIATE:     return "IMMEDIATE";
   }
   return "?";
}

string SymbolClassText()
{
   switch(g_symClass)
   {
      case SYMCLASS_METAL:     return "metal";
      case SYMCLASS_MAJOR_FX:  return "fx";
      case SYMCLASS_JPY_CROSS: return "jpy";
      case SYMCLASS_INDEX:     return "index";
      case SYMCLASS_CRYPTO:    return "crypto";
   }
   return "other";
}

void TrendSeg(const string name, datetime t1, double p1, datetime t2, double p2,
              color clr, ENUM_LINE_STYLE style, int width)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t2, p2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
}

void DrawDailyBox()
{
   if(!g_uiEnabled || !ShowVisuals || g_boxDrawn || !g_boxReady)
      return;

   datetime boxEnd = g_boxEnd;
   datetime dayEnd = g_dayStart + 86400;
   string tag = "ADZ_box_" + DayTag();

   if(ObjectFind(0, tag) < 0)
      ObjectCreate(0, tag, OBJ_RECTANGLE, 0, g_boxStart, g_boxHigh, boxEnd, g_boxLow);
   ObjectSetInteger(0, tag, OBJPROP_COLOR, BoxColor);
   ObjectSetInteger(0, tag, OBJPROP_FILL, true);
   ObjectSetInteger(0, tag, OBJPROP_BACK, true);
   ObjectSetInteger(0, tag, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, tag, OBJPROP_HIDDEN, true);

   TrendSeg(tag + "_high", boxEnd, g_boxHigh, dayEnd, g_boxHigh, BoxColor, STYLE_DASH, 1);
   TrendSeg(tag + "_low", boxEnd, g_boxLow, dayEnd, g_boxLow, BoxColor, STYLE_DASH, 1);

   g_boxDrawn = true;
}

void DrawSignal()
{
   if(!g_uiEnabled || !ShowVisuals || g_signal == SIGNAL_NONE)
      return;

   bool buy = (g_signal == SIGNAL_BUY_SWEEP || g_signal == SIGNAL_BUY_CONTINUATION);
   color clr = buy ? BullColor : BearColor;
   datetime dayEnd = g_dayStart + 86400;
   double tolerance = (g_boxHigh - g_boxLow) * RetestTolerancePercent / 100.0;
   double offset = MathMax((g_boxHigh - g_boxLow) * 0.10, 10 * _Point);
   string tag = "ADZ_sig_" + (string)(long)g_lastSignalBarTime;

   // arrow on the signal bar
   string arrow = tag + "_arr";
   double arrowPrice = buy ? g_signalLow - offset : g_signalHigh + offset;
   if(ObjectFind(0, arrow) < 0)
      ObjectCreate(0, arrow, OBJ_ARROW, 0, g_lastSignalBarTime, arrowPrice);
   ObjectSetInteger(0, arrow, OBJPROP_ARROWCODE, buy ? 233 : 234);
   ObjectSetInteger(0, arrow, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, arrow, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, arrow, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, arrow, OBJPROP_HIDDEN, true);

   // signal label, now carrying the setup score
   string label = tag + "_txt";
   double labelPrice = buy ? arrowPrice - offset : arrowPrice + offset;
   if(ObjectFind(0, label) < 0)
      ObjectCreate(0, label, OBJ_TEXT, 0, g_lastSignalBarTime, labelPrice);
   ObjectSetString(0, label, OBJPROP_TEXT,
                   StringFormat("%s  [%d]", SignalText(g_signal), g_signalScore));
   ObjectSetString(0, label, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, label, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, label, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, label, OBJPROP_ANCHOR, buy ? ANCHOR_UPPER : ANCHOR_LOWER);
   ObjectSetInteger(0, label, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, label, OBJPROP_HIDDEN, true);

   // retest zone + level, drawn forward to end of day
   string zone = tag + "_zone";
   if(ObjectFind(0, zone) < 0)
      ObjectCreate(0, zone, OBJ_RECTANGLE, 0, g_lastSignalBarTime,
                   g_retestLevel + tolerance, dayEnd, g_retestLevel - tolerance);
   ObjectSetInteger(0, zone, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, zone, OBJPROP_FILL, false);
   ObjectSetInteger(0, zone, OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, zone, OBJPROP_BACK, true);
   ObjectSetInteger(0, zone, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, zone, OBJPROP_HIDDEN, true);

   TrendSeg(tag + "_retest", g_lastSignalBarTime, g_retestLevel, dayEnd, g_retestLevel,
            clr, STYLE_DASHDOT, 2);
}

//+------------------------------------------------------------------+
//| Dashboard v2                                                     |
//+------------------------------------------------------------------+
void PanelLabel(const string name, const int x, const int y,
                const string text, const color clr, const int size = 9)
{
   string full = "ADZ_UI_" + name;
   if(ObjectFind(0, full) < 0)
   {
      ObjectCreate(0, full, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, full, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetString(0, full, OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, full, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, full, OBJPROP_HIDDEN, true);
   }
   ObjectSetInteger(0, full, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, full, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, full, OBJPROP_FONTSIZE, size);
   ObjectSetString(0, full, OBJPROP_TEXT, text);
   ObjectSetInteger(0, full, OBJPROP_COLOR, clr);
}

void PanelBackground(const int x, const int y, const int w, const int h)
{
   string full = "ADZ_UI_bg";
   if(ObjectFind(0, full) < 0)
   {
      ObjectCreate(0, full, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, full, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, full, OBJPROP_BGCOLOR, C'18,22,30');
      ObjectSetInteger(0, full, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, full, OBJPROP_COLOR, C'70,84,105');
      ObjectSetInteger(0, full, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, full, OBJPROP_HIDDEN, true);
   }
   ObjectSetInteger(0, full, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, full, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, full, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, full, OBJPROP_YSIZE, h);
}

string StateText(color &clr)
{
   if(g_haltAll != HALT_NONE)          { clr = clrRed;      return "HALTED: " + HaltText(g_haltAll); }
   if(g_haltDay != HALT_NONE)          { clr = clrOrange;   return "PAUSED: " + HaltText(g_haltDay); }
   if(!g_boxReady)                     { clr = clrSilver;   return "BUILDING BOX"; }
   if(HasOpenPosition())               { clr = clrGold;     return "IN TRADE"; }
   if(OwnPendingTicket() != 0)         { clr = clrDeepSkyBlue; return "ORDER PENDING"; }
   if(g_stopAfterWin && g_wonToday)      { clr = BullColor;   return "DONE (won today)"; }
   if(g_oneTradePerDay && g_tradedToday) { clr = clrSilver;   return "DONE (traded today)"; }
   if(g_signal != SIGNAL_NONE)
   {
      bool buy = (g_signal == SIGNAL_BUY_SWEEP || g_signal == SIGNAL_BUY_CONTINUATION);
      clr = buy ? BullColor : BearColor;
      return "SIGNAL ARMED";
   }
   clr = clrSilver;
   return "SCANNING";
}

void UpdateDashboard()
{
   if(!g_uiEnabled || !ShowDashboard)
      return;

   const int x = PanelX;
   int y = PanelY;
   const int rowH = 17;
   const color dim = clrSilver;
   const color bright = clrWhite;

   PanelBackground(x - 6, y - 6, 300, 19 * rowH + 16);

   // brand background art (compiled-in resource), drawn over the panel
   // rectangle and beneath the text labels (created after it, so on top)
   string bgimg = "ADZ_UI_bgimg";
   if(ObjectFind(0, bgimg) < 0)
   {
      ObjectCreate(0, bgimg, OBJ_BITMAP_LABEL, 0, 0, 0);
      ObjectSetInteger(0, bgimg, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetString(0, bgimg, OBJPROP_BMPFILE, "::apex_logo.bmp");
      ObjectSetInteger(0, bgimg, OBJPROP_BACK, false);
      ObjectSetInteger(0, bgimg, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, bgimg, OBJPROP_HIDDEN, true);
   }
   ObjectSetInteger(0, bgimg, OBJPROP_XDISTANCE, x - 6);
   ObjectSetInteger(0, bgimg, OBJPROP_YDISTANCE, y - 6);

   PanelLabel("title", x, y, "APEX DRAWDOWN ZERO V11.80", clrGold, 10);
   y += rowH + 3;

   color stateClr = dim;
   string state = StateText(stateClr);
   PanelLabel("state", x, y, "State  " + state, stateClr, 10);
   y += rowH;

   // --- firewall block (the headline feature of V11)
   double dayPL = DayPLPercent();
   double dd = DrawdownPercent();
   color plClr = dayPL >= 0.0 ? BullColor : BearColor;

   string fwLine;
   color fwClr;
   if(!UseRiskFirewall)                { fwLine = "Guard  OFF"; fwClr = clrOrange; }
   else if(g_haltAll != HALT_NONE)     { fwLine = "Guard  " + HaltText(g_haltAll); fwClr = clrRed; }
   else if(g_haltDay != HALT_NONE)     { fwLine = "Guard  " + HaltText(g_haltDay); fwClr = clrOrange; }
   else                                { fwLine = "Guard  ARMED"; fwClr = BullColor; }
   PanelLabel("fw", x, y, fwLine, fwClr);
   y += rowH;

   PanelLabel("daypl", x, y, StringFormat("Day    %+.2f%% / limit -%.2f%%",
              dayPL, g_dailyLossLimit), plClr);
   y += rowH;

   PanelLabel("dd", x, y, StringFormat("DD     %.2f%% / max %.2f%%   peak %.0f",
              dd, g_maxDrawdown, g_peakEquity),
              (g_maxDrawdown > 0.0 && dd > g_maxDrawdown * 0.6) ? BearColor : dim);
   y += rowH;

   double riskNow = EffectiveRiskPercent(g_signalScore);
   PanelLabel("risk", x, y, StringFormat("Risk   %.2f%%  streak L%d%s",
              riskNow, g_consecLosses,
              (g_consecLosses > 0 && UseRiskDeEscalation) ? " (cut)" : ""),
              g_consecLosses > 0 ? clrOrange : dim);
   y += rowH;

   PanelLabel("mode", x, y, StringFormat("Mode   %s  %s  bias:%s", EntryStyleText(),
              SymbolClassText(),
              g_useBias ? "EMA" + IntegerToString(BiasEMAPeriod) : "off"), dim);
   y += rowH;

   string boxLine = g_boxReady
      ? StringFormat("Box    %s / %s  (%d pts)",
                     DoubleToString(g_boxHigh, _Digits),
                     DoubleToString(g_boxLow, _Digits),
                     (int)MathRound((g_boxHigh - g_boxLow) / _Point))
      : "Box    building...";
   PanelLabel("box", x, y, boxLine, g_boxReady ? bright : dim);
   y += rowH;

   bool buySignal = (g_signal == SIGNAL_BUY_SWEEP || g_signal == SIGNAL_BUY_CONTINUATION);
   color sigClr = (g_signal == SIGNAL_NONE) ? dim : (buySignal ? BullColor : BearColor);
   PanelLabel("signal", x, y, g_signal == SIGNAL_NONE
              ? "Signal NONE"
              : StringFormat("Signal %s [%s]", SignalText(g_signal),
                             StratText(g_activeStrat)), sigClr);
   y += rowH;

   PanelLabel("slots", x, y, StringFormat("Setups %s%s%s%s  %d/%d today",
              g_stratDone[0] ? "-" : "C", g_useNY        ? (g_stratDone[1] ? "-" : "N") : ".",
              UseFailedBreak ? (g_stratDone[3] ? "-" : "R") : ".",
              UseRangeFade   ? (g_stratDone[2] ? "-" : "F") : ".",
              g_tradesToday, MathMax(1, g_maxTradesDay)), dim);
   y += rowH;

   PanelLabel("score", x, y, g_signal == SIGNAL_NONE
              ? StringFormat("Score  --  (min %d)  regime %.2f", g_minScore, AtrRegimeRatio())
              : StringFormat("Score  %d  (min %d)  regime %.2f", g_signalScore, g_minScore,
                             AtrRegimeRatio()),
              (g_signalScore >= g_minScore + 15) ? BullColor : dim);
   y += rowH;

   string age = "Age    --";
   if(g_signal != SIGNAL_NONE)
   {
      int bars = (int)((TimeCurrent() - g_lastSignalBarTime) / PeriodSeconds(g_boxTF));
      age = StringFormat("Age    %d / %d bars", bars, MaxSignalAgeBars);
   }
   PanelLabel("age", x, y, age, dim);
   y += rowH;

   int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   PanelLabel("spread", x, y, StringFormat("Spread %d / %d pts", spread, MaxSpreadPoints),
              spread > MaxSpreadPoints ? BearColor : dim);
   y += rowH;

   ulong ticket = OwnPositionTicket();
   ulong pending = OwnPendingTicket();
   if(ticket != 0 && PositionSelectByTicket(ticket))
   {
      bool isBuy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      double lots = PositionGetDouble(POSITION_VOLUME);
      double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);
      double pl = PositionGetDouble(POSITION_PROFIT);
      color posClr = isBuy ? BullColor : BearColor;

      PanelLabel("pos", x, y, StringFormat("Pos    %s %s @ %s  (%d leg)",
                 isBuy ? "BUY" : "SELL", DoubleToString(lots, VolumeDigits()),
                 DoubleToString(entry, _Digits), OwnPositionCount()), posClr);
      y += rowH;
      PanelLabel("levels", x, y, StringFormat("SL/TP  %s / %s",
                 DoubleToString(sl, _Digits), DoubleToString(tp, _Digits)), dim);
      y += rowH;
      PanelLabel("pl", x, y, StringFormat("P/L    %.2f %s", pl,
                 AccountInfoString(ACCOUNT_CURRENCY)), pl >= 0.0 ? BullColor : BearColor);
      y += rowH;

      int idx = FindState(ticket);
      bool locked = (sl != 0.0) && (isBuy ? sl >= entry : sl <= entry);
      string exitState = locked ? "LOCKED" : "armed";
      if(idx >= 0 && g_states[idx].partialDone)
         exitState += " +TP1 banked";
      if(!UseBreakEven && !UseChandelierTrail && !UseTrailing && !UsePartialTP)
         exitState = "off";
      PanelLabel("trail", x, y, "Exit   " + exitState, locked ? BullColor : dim);
      y += rowH;
   }
   else if(pending != 0 && OrderSelect(pending))
   {
      bool isBuy = (OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_LIMIT);
      double lots = OrderGetDouble(ORDER_VOLUME_CURRENT);
      double price = OrderGetDouble(ORDER_PRICE_OPEN);
      color posClr = isBuy ? BullColor : BearColor;

      PanelLabel("pos", x, y, StringFormat("Pos    %s LIMIT %s @ %s",
                 isBuy ? "BUY" : "SELL", DoubleToString(lots, VolumeDigits()),
                 DoubleToString(price, _Digits)), posClr);
      y += rowH;
      PanelLabel("levels", x, y, StringFormat("SL/TP  %s / %s",
                 DoubleToString(OrderGetDouble(ORDER_SL), _Digits),
                 DoubleToString(OrderGetDouble(ORDER_TP), _Digits)), dim);
      y += rowH;
      PanelLabel("pl", x, y, "Expiry " + (g_pendingExpiry > 0
                 ? TimeToString(g_pendingExpiry, TIME_DATE | TIME_MINUTES) : "--"), dim);
      y += rowH;
      PanelLabel("trail", x, y, "Exit   waiting for fill", dim);
      y += rowH;
   }
   else
   {
      PanelLabel("pos", x, y, "Pos    FLAT", dim);
      y += rowH;
      PanelLabel("levels", x, y, "SL/TP  --", dim);
      y += rowH;
      PanelLabel("pl", x, y, "P/L    --", dim);
      y += rowH;
      PanelLabel("trail", x, y, "Exit   " +
                 string((UseBreakEven || UseChandelierTrail || UsePartialTP) ? "armed" : "off"), dim);
      y += rowH;
   }

   // --- running expectancy
   int trades = g_statWins + g_statLosses;
   double winRate = trades > 0 ? 100.0 * g_statWins / trades : 0.0;
   double pf = g_statLoss > 0.0 ? g_statProfit / g_statLoss : 0.0;
   PanelLabel("stats", x, y, trades > 0
              ? StringFormat("Stats  %d trades  %.0f%% win  PF %.2f", trades, winRate, pf)
              : "Stats  no closed trades yet", dim);
   y += rowH;

   PanelLabel("acct", x, y, StringFormat("Bal    %.2f   Eq %.2f",
              AccountInfoDouble(ACCOUNT_BALANCE), AccountInfoDouble(ACCOUNT_EQUITY)), bright);
   y += rowH;

   // one-click preset selector
   string pbtn = "ADZ_UI_preset";
   if(ObjectFind(0, pbtn) < 0)
   {
      ObjectCreate(0, pbtn, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, pbtn, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, pbtn, OBJPROP_XSIZE, 288);
      ObjectSetInteger(0, pbtn, OBJPROP_YSIZE, 16);
      ObjectSetInteger(0, pbtn, OBJPROP_BGCOLOR, C'40,52,70');
      ObjectSetInteger(0, pbtn, OBJPROP_BORDER_COLOR, C'90,110,140');
      ObjectSetInteger(0, pbtn, OBJPROP_COLOR, clrGold);
      ObjectSetString(0, pbtn, OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, pbtn, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, pbtn, OBJPROP_HIDDEN, true);
   }
   ObjectSetInteger(0, pbtn, OBJPROP_XDISTANCE, x - 3);
   ObjectSetInteger(0, pbtn, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, pbtn, OBJPROP_TEXT, "PRESET: " + g_presetName + "   (click to change)");
   ObjectSetInteger(0, pbtn, OBJPROP_STATE, false);
}

//+------------------------------------------------------------------+
//| Symbol classification + preset resolution (V11.50)               |
//| v9 knew three symbols and dropped everything else onto raw       |
//| defaults. V11 classifies the symbol first, so an unlisted pair   |
//| still gets a configuration matched to its volatility character   |
//| rather than gold's numbers.                                      |
//+------------------------------------------------------------------+
SymbolClass ClassifySymbol()
{
   string s = _Symbol;
   StringToUpper(s);

   if(StringFind(s, "XAU") >= 0 || StringFind(s, "GOLD") >= 0 ||
      StringFind(s, "XAG") >= 0 || StringFind(s, "SILVER") >= 0)
      return SYMCLASS_METAL;

   if(StringFind(s, "BTC") >= 0 || StringFind(s, "ETH") >= 0)
      return SYMCLASS_CRYPTO;

   if(StringFind(s, "US30") >= 0 || StringFind(s, "NAS") >= 0 ||
      StringFind(s, "SPX") >= 0 || StringFind(s, "US500") >= 0 ||
      StringFind(s, "GER") >= 0 || StringFind(s, "DAX") >= 0 ||
      StringFind(s, "UK100") >= 0 || StringFind(s, "JP225") >= 0)
      return SYMCLASS_INDEX;

   if(StringFind(s, "JPY") >= 0)
      return SYMCLASS_JPY_CROSS;

   if(StringFind(s, "EUR") >= 0 || StringFind(s, "GBP") >= 0 ||
      StringFind(s, "USD") >= 0 || StringFind(s, "AUD") >= 0 ||
      StringFind(s, "NZD") >= 0 || StringFind(s, "CAD") >= 0 ||
      StringFind(s, "CHF") >= 0)
      return SYMCLASS_MAJOR_FX;

   return SYMCLASS_OTHER;
}

void ApplyPreset()
{
   g_symClass = ClassifySymbol();

   PresetMode m = g_presetMode;
   if(m == PRESET_AUTO)
   {
      string s = _Symbol;
      StringToUpper(s);
      if(g_symClass == SYMCLASS_METAL)        m = PRESET_XAUUSD;
      else if(StringFind(s, "EURJPY") >= 0)   m = PRESET_EURJPY;
      else if(StringFind(s, "EURUSD") >= 0)   m = PRESET_EURUSD;
      else                                    m = PRESET_GENERIC;
   }

   // ---- resolve the trading cadence first: MODE_DISCIPLINE mirrors every
   // input exactly, MODE_HIGH_FREQUENCY substitutes the measured intraday set
   g_boxTF          = BoxTimeframe;
   g_entryTF        = EntryTimeframe;
   g_useBias        = UseBiasFilter;
   g_biasSweeps     = ApplyBiasToSweeps;
   g_minBoxAtr      = MinBoxAtr;
   g_breakBufAtr    = BreakBufferAtr;
   g_confirmBody    = ConfirmBodyPercent;
   g_oneTradePerDay = OneTradePerDay;
   g_stopAfterWin   = StopAfterWin;
   g_maxTradesDay   = MaxTradesPerDay;
   g_riskPercent    = RiskPercent;
   g_dailyLossLimit = DailyLossLimitPercent;
   g_maxDrawdown    = MaxDrawdownPercent;

   if(TradingMode == MODE_HIGH_FREQUENCY)
   {
      g_boxTF          = PERIOD_M15;
      g_entryTF        = PERIOD_M15;
      g_useBias        = false;
      g_biasSweeps     = false;
      g_minBoxAtr      = 0.50;
      g_breakBufAtr    = 0.10;
      g_confirmBody    = 35;
      g_oneTradePerDay = false;
      g_stopAfterWin   = false;
      g_maxTradesDay   = 30;
      g_dailyLossLimit = 8.0;
      // risk per trade is cut because the day now carries many more of them.
      // Counter-intuitively this also RAISES the trade count: the daily loss
      // cap halts the day less often, so more setups get taken.
      g_riskPercent    = MathMax(0.01, HighFreqRiskPercent);
   }
   else if(TradingMode == MODE_AGGRESSIVE_GROWTH)
   {
      // Same H1 setups as MODE_DISCIPLINE - that cadence has by far the best
      // profit factor (2.60 vs 1.29), so it is the better compounding engine.
      // The ONLY change is size, and the firewall is widened to match, because
      // the standard 3% daily / 10% total caps would halt this mode constantly.
      g_riskPercent    = MathMax(0.01, GrowthRiskPercent);
      g_dailyLossLimit = MathMax(DailyLossLimitPercent, 10.0);
      g_maxDrawdown    = MathMax(MaxDrawdownPercent, 35.0);
   }

   // resolve the NY session strategy against the symbol family
   if(NYSession == NY_OFF)
      g_useNY = false;
   else if(NYSession == NY_ALWAYS)
      g_useNY = true;
   else if(TradingMode == MODE_HIGH_FREQUENCY)
      g_useNY = true;      // part of the measured high-frequency set
   else
      g_useNY = (g_symClass == SYMCLASS_MAJOR_FX || g_symClass == SYMCLASS_JPY_CROSS);

   // start from the raw inputs, then let the preset override what it tunes
   g_riskReward     = RiskReward;
   g_firstEntryHour = FirstEntryHour;
   g_atrStopMult    = AtrStopMult;
   g_minScore       = MinSignalScore;

   switch(m)
   {
      case PRESET_XAUUSD:
         g_riskReward = 2.0; g_firstEntryHour = 8;  g_atrStopMult = 2.5;
         g_presetName = "XAUUSD";
         break;

      case PRESET_EURUSD:
         g_riskReward = 1.5; g_firstEntryHour = 8;  g_atrStopMult = 2.5;
         g_presetName = "EURUSD";
         break;

      case PRESET_EURJPY:
         g_riskReward = 1.5; g_firstEntryHour = 12; g_atrStopMult = 2.5;
         g_presetName = "EURJPY";
         break;

      case PRESET_GENERIC:
         // volatility-matched fallback by symbol family. Wider stops and a
         // higher score bar on the classes that behaved worst in testing.
         switch(g_symClass)
         {
            case SYMCLASS_METAL:
               g_riskReward = 2.0; g_firstEntryHour = 8;  g_atrStopMult = 2.5;
               break;
            case SYMCLASS_JPY_CROSS:
               g_riskReward = 1.5; g_firstEntryHour = 12; g_atrStopMult = 2.5;
               break;
            case SYMCLASS_MAJOR_FX:
               g_riskReward = 1.5; g_firstEntryHour = 8;  g_atrStopMult = 2.5;
               break;
            case SYMCLASS_INDEX:
               // the opening-range premise did not hold on indices; if the
               // user insists, demand a much better setup and a wider stop
               g_riskReward = 1.5; g_firstEntryHour = 14; g_atrStopMult = 3.0;
               g_minScore = MathMax(MinSignalScore, 70);
               break;
            case SYMCLASS_CRYPTO:
               g_riskReward = 2.0; g_firstEntryHour = 0;  g_atrStopMult = 3.0;
               g_minScore = MathMax(MinSignalScore, 65);
               break;
            default:
               g_riskReward = 1.5; g_firstEntryHour = 8;  g_atrStopMult = 2.5;
               break;
         }
         g_presetName = "GENERIC:" + SymbolClassText();
         break;

      default:
         g_presetName = "MANUAL";
         break;
   }

   if(g_presetMode == PRESET_AUTO)
      g_presetName += " (auto)";

   // status to the journal (live only; keep the Strategy Tester journal clean)
   if(!MQLInfoInteger(MQL_TESTER))
   {
      if(g_symClass == SYMCLASS_INDEX)
         Print("Apex Drawdown Zero: '", _Symbol, "' is an index. The opening-range ",
               "premise did not hold on indices in testing - not recommended. ",
               "Running with a raised score bar (", g_minScore, ") if you continue.");
      else if(m == PRESET_GENERIC)
         Print("Apex Drawdown Zero: '", _Symbol, "' is not one of the validated pairs ",
               "(XAUUSD/EURUSD/EURJPY) - using the auto-calibrated ", SymbolClassText(),
               " profile. Backtest it before trading live.");

      if(TradingMode == MODE_AGGRESSIVE_GROWTH)
      {
         Print("Apex Drawdown Zero: AGGRESSIVE GROWTH MODE - risk ",
               DoubleToString(g_riskPercent, 2), "% per trade, drawdown cap widened to ",
               DoubleToString(g_maxDrawdown, 1), "%.");
         Print("Apex Drawdown Zero: at 3% risk XAUUSD returned +106% in the good ",
               "test year and +46% in the thin one, for 7-16% drawdown. At 8% it ",
               "returned +484% and +116% for 19-42% drawdown. Return stops scaling ",
               "with risk long before drawdown does - see the frontier table.");
         if(g_symClass != SYMCLASS_METAL)
            Print("Apex Drawdown Zero: WARNING - growth-mode risk on a symbol this EA ",
                  "does not trade well is how accounts are lost. At 8% risk GBPUSD ",
                  "ended the test down 54% with a 63% drawdown.");
      }
      if(TradingMode == MODE_HIGH_FREQUENCY)
      {
         Print("Apex Drawdown Zero: HIGH-FREQUENCY MODE - M15, up to ", g_maxTradesDay,
               " setups/day, risk cut to ", DoubleToString(g_riskPercent, 2),
               "%. Expect ~77-93 trades/month.");
         if(g_symClass != SYMCLASS_METAL)
            Print("Apex Drawdown Zero: WARNING - high-frequency mode was only ",
                  "validated on XAUUSD. On EURUSD it LOST money in both test ",
                  "windows (-838 and -845). '", _Symbol, "' is not a metal. ",
                  "Backtest it yourself before running this mode live.");
      }
      Print("Apex Drawdown Zero V11.80: NY session ", g_useNY ? "ON" : "off",
            " (", SymbolClassText(), ")");
      Print("Apex Drawdown Zero V11.80: preset ", g_presetName,
            "  RR=", DoubleToString(g_riskReward, 2),
            "  firstEntryHour=", g_firstEntryHour,
            "  atrStop=", DoubleToString(g_atrStopMult, 2),
            "  minScore=", g_minScore);
   }
}

//+------------------------------------------------------------------+
//| Lifecycle                                                        |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(MagicNumber);
   g_uiEnabled = !MQLInfoInteger(MQL_OPTIMIZATION);

   g_presetMode = Preset;
   ApplyPreset();

   if(g_useBias)
   {
      g_emaHandle = iMA(_Symbol, g_boxTF, BiasEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
      if(g_emaHandle == INVALID_HANDLE)
         Print("Apex Drawdown Zero: EMA handle failed, bias filter disabled");
   }

   // ATR drives the volatility-adaptive stop, the volatility-relative
   // breakout buffer / min-box filter, the chandelier trail and the score
   g_atrHandle = iATR(_Symbol, g_boxTF, AtrPeriod);
   if(g_atrHandle == INVALID_HANDLE)
      Print("Apex Drawdown Zero: ATR handle failed, falling back to fixed point buffers");

   if(UseRegimeFilter || UseSignalScore)
   {
      g_atrSlowHandle = iATR(_Symbol, g_boxTF, MathMax(AtrPeriod + 1, AtrRegimeLookback));
      if(g_atrSlowHandle == INVALID_HANDLE)
         Print("Apex Drawdown Zero: slow ATR handle failed, regime filter neutralised");
   }

   // --- risk firewall anchors
   g_dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   g_dayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_dayPeakEquity = g_dayStartEquity;

   string peakKey = StringFormat("ADZ11_peak_%I64u", MagicNumber);
   if(!MQLInfoInteger(MQL_TESTER) && GlobalVariableCheck(peakKey))
      g_peakEquity = GlobalVariableGet(peakKey);
   if(g_peakEquity < g_dayStartEquity)
      g_peakEquity = g_dayStartEquity;

   ArrayResize(g_states, 0);
   RebuildHistoryState();

   IsNewDay();

   if(UseRiskFirewall && !MQLInfoInteger(MQL_TESTER))
      Print("Apex Drawdown Zero: risk firewall ARMED - daily -",
            DoubleToString(g_dailyLossLimit, 2), "%, max DD ",
            DoubleToString(g_maxDrawdown, 2), "%, equity guard ",
            DoubleToString(EquityGuardPercent, 2), "%");

   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_emaHandle != INVALID_HANDLE)
      IndicatorRelease(g_emaHandle);
   if(g_atrHandle != INVALID_HANDLE)
      IndicatorRelease(g_atrHandle);
   if(g_atrSlowHandle != INVALID_HANDLE)
      IndicatorRelease(g_atrSlowHandle);
   ObjectsDeleteAll(0, "ADZ_");
   ChartRedraw();
}

void OnTick()
{
   if(IsNewDay())
      CancelPending("new trading day");

   UpdateClosedDeals();
   UpdateFirewall();          // must run before any entry path
   ManagePendingExpiry();

   // A position inherited from the previous day (or a restart) consumes a
   // slot. v9 did this implicitly through g_tradedToday; the slot table has
   // to be told explicitly or a carried-over trade would let the core fire
   // a second time on a day it had already committed to.
   if(!g_tradedToday && HasOpenPosition())
   {
      g_tradedToday = true;
      g_stratDone[(int)STRAT_CORE] = true;
      if(g_tradesToday == 0)
         g_tradesToday = 1;
   }

   ManageOpenTrades();
   ManagePyramid();

   if(BuildDailyBox())
   {
      DrawDailyBox();
      ExpireSignal();

      // priority order: the core breakout first (it is the proven edge),
      // then the NY range, then the slower failed-break reversal, and the
      // compression fade last because it only applies when nothing broke
      DetectSignal();
      DetectNYSignal();
      DetectFailedBreakSignal();
      DetectFadeSignal();

      TryEnter();
   }

   if(g_uiEnabled && ShowDashboard)
   {
      UpdateDashboard();
      ChartRedraw();
   }
}

//+------------------------------------------------------------------+
//| Dashboard button: cycle the active preset on click               |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id != CHARTEVENT_OBJECT_CLICK || sparam != "ADZ_UI_preset")
      return;

   // AUTO -> XAU -> EURUSD -> EURJPY -> GENERIC -> MANUAL -> AUTO
   g_presetMode = (PresetMode)(((int)g_presetMode + 1) % 6);
   ApplyPreset();

   ObjectSetInteger(0, "ADZ_UI_preset", OBJPROP_STATE, false);
   if(g_uiEnabled && ShowDashboard)
   {
      UpdateDashboard();
      ChartRedraw();
   }
}
