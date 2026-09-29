//+------------------------------------------------------------------+
//| ApexDrawdownZero_V12.mq5                                         |
//| Apex Drawdown Zero V12.00 — daily opening-range sweep /          |
//| displacement / retest EA with a hard risk firewall.              |
//|                                                                  |
//| Lineage: v7 entry styles -> v7.4 ATR stop -> v8 multi-pair       |
//| volatility-relative logic -> v9 presets -> v11 risk firewall,    |
//| partial TP, NY session (FX), trading modes, growth mode.         |
//| The full v11 measurement record is in CHANGELOG_V11.md.          |
//|                                                                  |
//| v12.00  DISTILLATION + NEW STRATEGIES.                           |
//|                                                                  |
//|   (a) Every v11 module that was measured and switched off has    |
//|       been REMOVED, not just defaulted off, so the EA only       |
//|       carries code with evidence behind it:                      |
//|         signal scoring + regime filter   (flipped EURUSD to loss)|
//|         chandelier trail                 -657                    |
//|         time stop                        -1846                   |
//|         profit-lock ladder               -1102                   |
//|         legacy R-trail                   (v7.30: cut winners)    |
//|         pyramiding                       (lost out of sample)    |
//|         range fade (S2)                  fired once in 8 months  |
//|         failed-break reversal (S3)       -648                    |
//|         risk de-escalation               -118                    |
//|         loss-streak cooldown             net cost                |
//|         Friday entry cutoff              -253                    |
//|       With the new strategies off, v12 reproduces v11.80 to the  |
//|       cent in all three trading modes (see CHANGELOG_V12.md).    |
//|                                                                  |
//|   (b) STRATEGY LANES. Each new strategy trades in its own lane   |
//|       (own magic, own position), so it can never take the slot a |
//|       core trade needed. Sharing the slot was measured first and |
//|       it cost the core up to 80% of its out-of-sample profit.    |
//|                                                                  |
//|   (c) Three new strategies, one shipped:                         |
//|         S4 trend pullback   SHIPPED (AUTO: metals, H1 modes)     |
//|         S5 prior-day break  OFF - fragile to its stop; EURUSD    |
//|                             out-of-sample -2040                  |
//|         S6 mean reversion   OFF - XAUUSD 2026 2956 -> 1704       |
//|                                                                  |
//|       VERIFIED, XAUUSD, shipped defaults:                        |
//|         DISCIPLINE 2026   2956 -> 4336   PF 2.60 -> 2.14         |
//|         DISCIPLINE 2025   1370 -> 4410   PF 1.30 -> 1.55         |
//|         GROWTH 3%  2026   +106% -> +191%                         |
//|         GROWTH 3%  2025   +46%  -> +116%  bal DD 16.4% -> 20.2%  |
//|       EURUSD and HIGH_FREQUENCY are unchanged to the cent.       |
//|                                                                  |
//| v12.10  BALLISTIC SNIPER lane (squeeze -> ignition bar -> limit  |
//|         at the 50% retrace, 3R). Tested 3 ways on XAUUSD; best   |
//|         (hold to SL/TP, 3R): 2026 4336 -> 4686, 2025 OOS 4410 -> |
//|         4275, PF lower and DD higher in both. Aug 2026 +286 but  |
//|         Sep -178. Not an edge -> shipped OFF. Defaults unchanged |
//|         (verified to the cent).                                  |
//|                                                                  |
//| v12.20  TDI (Traders Dynamic Index + RSI divergence, ported from |
//|         the TradingView study). Three ways, XAUUSD, 2026 / 2025: |
//|           V12 shipped            4336 / 4410                     |
//|           TDI signal lane        2328 / 3047  (10% DD halt)      |
//|           TDI + divergence lane  4214 / 4311                     |
//|           TDI filter on TPB      3063 / 3543                     |
//|         None beat V12 -> all OFF. Defaults unchanged.            |
//|                                                                  |
//| v12.30  PROFIT LEVERS measured. TPBMaxPerDay 2/3: OOS 4410 ->    |
//|         3620/3320 (default stays 1). DISCIPLINE risk 1.5%/2%:    |
//|         hits the 10% DD halt out of sample. GROWTH frontier,     |
//|         2026 / 2025 / 2025 bal DD: 2% +89/+91/14%, 3% +191/+116/ |
//|         20%, 4% +282/+117/27%, 5% halts. 3% stays the default.   |
//|         XAGUSD loses in both windows -> AUTO lanes gold-only,    |
//|         warning printed on silver.                               |
//|                                                                  |
//| v12.40-12.46  FTMO MODE (TradingMode = MODE_FTMO). Target lock,  |
//|         FTMO's static + daily floors (1% buffer), room-based     |
//|         sizing, min trading days, tester auto-stop, closed-      |
//|         balance target check (commission bug fix), Templar       |
//|         Cavalry dashboard. Real ticks, phase 1, 12 start dates:  |
//|         12/12 passed, 0 failed, median 38 days, worst day -4.06%.|
//|         Iteration log: versions/VERSIONS.md.                     |
//+------------------------------------------------------------------+
#property copyright "Apex Drawdown Zero"
#property version   "12.46"
#resource "Assets\\cavalry_background.bmp"   // v12.45 dashboard art (Templar Cavalry design)
#resource "Assets\\cavalry_badge.bmp"        // header badge
#property description "Apex Drawdown Zero V12.00 - opening-range breakout EA with a hard risk firewall."
#property description "Daily loss cap, drawdown cap, partial TP, break-even. H1. Demo-test before live use."

//====================================================================
//                 APEX DRAWDOWN ZERO V12.00 - USER GUIDE
//====================================================================
//
//  WHAT IT DOES
//    A breakout robot. Each day it builds an opening-range "box" from
//    the first hours of the session, then trades a sweep / displacement
//    / retest out of that range. Every trade carries a stop, and a risk
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
//    3) Check the dashboard shows "SCANNING" and "Guard ARMED".
//
//  THE RISK FIREWALL
//    DailyLossLimitPercent .. stop trading for the day at this loss  [ON]
//    MaxDrawdownPercent ..... stop the EA entirely at this drawdown
//                             from peak equity (needs manual restart) [ON]
//    EquityGuardPercent ..... emergency flatten on intraday equity drop [ON]
//    DailyProfitTargetPercent stop for the day once up this much     [off]
//    FlatBeforeWeekendHour .. close everything on Friday at this hour [off]
//    FirewallClosesTrades decides whether a tripped limit also
//    flattens open positions or just blocks new ones.
//
//    FlatBeforeWeekendHour is a judgement call: it lost 572 over 8
//    months, but a backtest window with no catastrophic weekend gap
//    cannot price the risk it exists to cover. Set it to 21 if you
//    would rather pay that premium, especially on gold.
//
//  EXITS
//    UsePartialTP ........... bank PartialClosePercent at PartialTP_RR [ON]
//    UseBreakEven ........... stop to entry at BreakEvenTriggerRR      [ON]
//    Nothing trails. Every trailing / time-based exit that was tried
//    cut the runners the 2R target depends on, and was removed.
//
//  TRADING CADENCE
//    TradingMode = MODE_DISCIPLINE  (default)
//      One qualified setup per strategy per day, H1. On XAUUSD ~23-28
//      trades/month: ~14 from the core plus ~9-12 from the trend-
//      pullback lane, which can hold a position alongside the core.
//    TradingMode = MODE_HIGH_FREQUENCY
//      M15, up to 30 setups per day, risk 0.35%. ~77-93 trades/month
//      on XAUUSD; profit factor 2.60 -> 1.29, drawdown 1.9% -> 7%.
//      Gold only - it lost money on EURUSD in both test windows.
//    TradingMode = MODE_AGGRESSIVE_GROWTH
//      Discipline setups sized at GrowthRiskPercent (default 3%), with
//      the drawdown cap widened to 35%. Do not raise this to 8% - with
//      the firewall on, 8% halted itself and lost 28% out of sample.
//
//  IMPORTANT
//    - Times are broker/server hours. If your server is not GMT+2/+3,
//      shift FirstEntryHour / LastEntryHour to the London + NY window.
//    - Several no-trade days per month are normal and intentional.
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
   MODE_AGGRESSIVE_GROWTH = 2, // H1 setups, compounding at a higher risk per trade
   MODE_FTMO = 3               // v12.40: prop-firm challenge - FTMO rules guarded, target locked
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

// how the trend-pullback lane is enabled (v12)
// MEASURED on XAUUSD, own lane: 2026 2956 -> 4336, 2025 OOS 1370 -> 4410,
// and every neighbouring parameter set also beat the core in both windows.
// On EURUSD it was one good window and one losing one (-333 / +3022), and
// in high-frequency mode it hurt 2026 (1963 -> 1026). AUTO keeps it where
// it verified twice: metals, in the two H1 modes.
enum LaneMode
{
   LANE_AUTO   = 0,   // gold in DISCIPLINE / GROWTH mode; off elsewhere (silver measured negative)
   LANE_ALWAYS = 1,   // every symbol and mode (not validated - see above)
   LANE_OFF    = 2
};

// which sub-strategy produced the live signal (v11.60)
enum StratId
{
   STRAT_CORE = 0,   // the v7-v11 opening-range sweep / displacement / retest
   STRAT_NY   = 1,   // second opening range built at the New York open
   STRAT_TPB  = 2,   // v12: trend pullback to the EMA, resumption entry
   STRAT_PDB  = 3,   // v12: prior-day high/low breakout
   STRAT_MR   = 4,   // v12: oversold/overbought snap-back inside a trend
   STRAT_BAL  = 5,   // v12.10: ballistic sniper - squeeze ignition, limit at the 50% retrace
   STRAT_TDI  = 6    // v12.20: Traders Dynamic Index cross (+ optional RSI divergence)
};
#define STRAT_COUNT 7
#define MinSlStepPoints 50   // smallest SL move worth sending (was the v9 TrailStepPoints input)

// why the firewall is blocking (0 = not blocking)
enum HaltReason
{
   HALT_NONE = 0,
   HALT_DAILY_LOSS,
   HALT_DAILY_TARGET,
   HALT_MAX_DRAWDOWN,
   HALT_EQUITY_GUARD,
   HALT_WEEKEND,
   HALT_TARGET_LOCK      // v12.40 FTMO mode: phase target reached, book closed
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

//--- MODE_FTMO (v12.40). Guards the prop firm's OWN rules rather than the
//--- EA's generic ones: FTMO's max loss is a STATIC floor under the initial
//--- balance (not a trailing peak), and its daily loss is measured from the
//--- day-start balance in units of the INITIAL balance.
input group           "=== FTMO mode ==="
input double          FTMORiskPercent          = 2.0;   // risk ceiling per trade; room sizing below usually binds first (~1.6%)
input double          FTMOPhaseTargetPercent   = 10.0;  // 10 = phase 1, 5 = phase 2, 0 = funded (no lock)
input double          FTMOInitialBalance       = 0.0;   // challenge size; 0 = balance when first attached (remembered)
input double          FTMOMaxLossPercent       = 10.0;  // firm's max loss, % of initial
input double          FTMODailyLossPercent     = 5.0;   // firm's daily loss, % of initial
input double          FTMOSafetyBufferPercent  = 1.0;   // EA stops this far BEFORE either firm limit
input int             FTMOMinTradingDays       = 4;     // firm's minimum; topped up after the target if short
input double          FTMORoomDivisor          = 2.5;   // a trade risks at most room-to-floor / this. 2.5: real ticks 12/12, median 38d. 3 = safer, 53d

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
input int             FlatBeforeWeekendHour    = 0;     // MEASURED -572 on XAUUSD. 0 = off. Turn ON if you want gap insurance (see changelog).


//--- ADAPTIVE EXIT ENGINE (V11.00)
input group           "=== Exits ==="
input bool            UsePartialTP             = true;  // bank part of the position at TP1, run the rest
input double          PartialTP_RR             = 1.00;  // TP1 as a fraction of target R
input int             PartialClosePercent      = 50;    // portion of the position closed at TP1


input bool            UseBreakEven             = true;
input double          BreakEvenTriggerRR       = 0.60;  // move SL to BE at this fraction of target R
input int             BreakEvenOffsetPoints    = 30;

//--- COMPLEMENTARY STRATEGIES
//--- Setups that trade situations the core strategy sits out. Each has
//--- its own switch and its own once-per-day slot.
input group           "=== Complementary strategies ==="
input int             MaxTradesPerDay          = 2;     // total across all strategies (OneTradePerDay must be true for this to bind)

//--- S1: New York opening range. Same proven mechanism, second session.
input NYMode          NYSession                = NY_AUTO;
input int             NYBoxStartHour           = 14;    // server hour the NY range starts building
input int             NYBoxCandles             = 2;     // bars in the NY range
input int             NYLastEntryHour          = 21;    // NY setups may fire later than the London cutoff

//--- S4 (v12): trend pullback. Buys a dip to the fast EMA inside an
//--- established trend, on the bar that resumes the trend. Trades in its
//--- own lane, so it adds to the core instead of competing for its slot.
input LaneMode        TrendPullback            = LANE_AUTO;
input int             TrendEMAPeriod           = 200;   // trend is defined against this EMA
input int             PullbackEMAPeriod        = 20;    // price must dip to this EMA
input int             PullbackLookback         = 5;     // bars in which the dip must have happened
input double          PullbackStopAtr          = 0.50;  // stop this far beyond the dip extreme, in ATR
input double          PullbackRR               = 2.0;
input int             TPBMaxPerDay             = 1;     // trend-pullback entries per day (one position at a time in its lane)

//--- S5 (v12): prior-day high/low breakout. A different reference level
//--- from the opening range: yesterday's full-session extreme.
input bool            UsePriorDayBreak         = false; // MEASURED: + on gold but only at this exact stop (1.0/2.0 ATR fell away); EURUSD OOS -2040. Off.
input double          PDBBufferAtr             = 0.10;  // close must clear the level by this much ATR
input double          PDBStopAtr               = 1.50;  // stop distance in ATR
input double          PDBRR                    = 2.0;

//--- S6 (v12): mean reversion. Short-term oversold dip in an uptrend
//--- (overbought pop in a downtrend), targeting a snap-back. The only
//--- non-breakout setup in the EA, so it should earn on different days.
input bool            UseMeanReversion         = false; // MEASURED: XAUUSD 2026 2956 -> 1704. Off.
input int             MRRsiPeriod              = 2;
input double          MRRsiLevel               = 10.0;  // buy below this, sell above 100 - this
input double          MRStopAtr                = 1.50;  // stop distance in ATR
input double          MRTargetAtr              = 1.00;  // target distance in ATR

//--- S7 (v12.10): BALLISTIC SNIPER. Three stages:
//---   1) compression - Bollinger(20,2) inside Keltner(EMA20 +/- k*ATR) for
//---      most of the last BALSqueezeLookback bars (TTM-squeeze idea)
//---   2) ignition    - one wide, full-bodied bar closes outside the band
//---   3) snipe       - a LIMIT order waits at BALRetrace of that bar, stop
//---      just beyond the bar's base. The stop is half a bar, not 2.5 ATR,
//---      so the same risk buys a far larger target.
input LaneMode        BallisticSniper          = LANE_OFF; // MEASURED: 2026 +349 but 2025 OOS -134, PF and DD worse both windows. Off.
input int             BALSqueezeLookback       = 10;    // bars checked for compression
input int             BALMinSqueezeBars        = 5;     // of which at least this many must be squeezed
input double          BALKeltnerMult           = 1.5;   // Keltner half-width in ATR
input double          BALIgnitionAtr           = 1.2;   // ignition bar range must be >= this x ATR
input double          BALRetrace               = 0.50;  // limit sits this far back into the ignition bar
input double          BALStopBufferAtr         = 0.10;  // stop this far beyond the ignition bar's base
input double          BALRR                    = 3.0;   // target in R from the limit price
input int             BALExpiryBars            = 4;     // unfilled limit is cancelled after this many bars
input bool            BALManaged               = false; // apply the core's partial TP + break-even (false = hold to SL/TP)

//--- S8 (v12.20): TRADERS DYNAMIC INDEX, ported from the LazyBear /
//--- JustUncleL / ZyadaCharts TradingView study. On RSI(14):
//---   mid ("yellow") = SMA(RSI,34), bands = mid +/- 1.6185 * stdev(RSI,34)
//---   green = SMA(RSI,2), red = SMA(RSI,7)
//---   LONG  = green crosses above red, red > mid and red > 50
//---   SHORT = green crosses below red, red < mid and red < 50
//--- Divergence: regular bull/bear RSI divergence on 5/5 pivots, previous
//--- pivot 5-60 bars back (the study's defaults).
input LaneMode        TDISignal                = LANE_OFF; // MEASURED: 2026 4336 -> 2328, hit the 10% DD halt. Off.
input int             TDIRsiPeriod             = 14;
input int             TDIBandLength            = 34;
input int             TDIRedMA                 = 7;     // "TSL signal" line
input int             TDIGreenMA               = 2;     // "RSI price line"
input bool            TDIRequireDivergence     = false; // only take a cross with a same-way regular divergence (measured: fires ~1/month, slightly negative)
input int             TDIDivWindow             = 10;    // ... printed within this many bars
input double          TDIStopAtr               = 1.50;
input double          TDIRR                    = 2.0;
input bool            TPBUseTDIFilter          = false; // trend pullback: buy only green > mid (MEASURED: 4336/4410 -> 3063/3543. Off.)


//--- visuals + telemetry
input group           "=== Visuals / journal ==="
input bool            ShowVisuals              = true;
input bool            ShowDashboard            = true;
input bool            WriteTradeJournal        = false; // append closed trades to a CSV in MQL5/Files
input string          DailyLogFile             = "";    // TESTER ONLY: per-day equity log to Common/Files (prop-firm audits)
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
   bool     managed;       // false = hold to SL/TP (mean reversion skips partial/BE)
};

CTrade trade;

TradeState g_states[];

//--- sub-strategy state (v11.60)
StratId    g_activeStrat = STRAT_CORE;   // which strategy armed g_signal
bool       g_stratDone[STRAT_COUNT];     // once-per-day slot per strategy
int        g_laneCount[STRAT_COUNT];     // lane entries today (TPBMaxPerDay)
int        g_tradesToday = 0;            // trades opened today, all strategies
double     g_nyBoxHigh = 0.0;
double     g_nyBoxLow = 0.0;
datetime   g_nyBoxStart = 0;
datetime   g_nyBoxEnd = 0;
bool       g_nyBoxReady = false;
bool       g_useNY = true;              // NYSession resolved against symbol class
bool       g_useTPB = false;            // TrendPullback resolved against class + mode
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
double     g_customSl = 0.0;             // strategy-supplied SL/TP (v12 strategies)
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
bool       g_boxReady = false;
bool       g_boxDrawn = false;
bool       g_tradedToday = false;
bool       g_wonToday = false;
bool       g_uiEnabled = true;
int        g_emaHandle = INVALID_HANDLE;
int        g_emaTrendHandle = INVALID_HANDLE;   // v12 strategies
int        g_emaFastHandle = INVALID_HANDLE;
int        g_rsiHandle = INVALID_HANDLE;
int        g_bandsHandle = INVALID_HANDLE;      // v12.10 ballistic sniper
bool       g_useBAL = false;
bool       g_useTDI = false;
double     g_ftmoInit = 0.0;            // v12.40 FTMO mode: challenge initial balance
datetime   g_ftmoStart = 0;             // ... and start time (trading-day count)
int        g_tdiRsiHandle = INVALID_HANDLE;
datetime   g_balExpiry = 0;
int        g_atrHandle = INVALID_HANDLE;

//--- risk firewall state
double     g_dayStartBalance = 0.0;
double     g_dayStartEquity = 0.0;
double     g_dayPeakEquity = 0.0;
double     g_peakEquity = 0.0;
double     g_dayRealized = 0.0;
int        g_consecLosses = 0;
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
string      g_presetName = "MANUAL";

//--- forward declarations (functions referenced before their definition)
string SignalText(SignalType s);
void   DrawSignal();
void   FlattenAll(const string reason);
void   CancelLanePendings(const string reason);
bool   IsRsiPivot(const double &r[], int p, int lb, bool low);

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
   g_boxReady = false;
   g_boxDrawn = false;
   g_tradedToday = false;
   g_wonToday = false;

   // sub-strategy slots
   for(int i = 0; i < STRAT_COUNT; i++)
   {
      g_stratDone[i] = false;
      g_laneCount[i] = 0;
   }
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
//| Strategy lanes (v12)                                             |
//| The core and NY share MagicNumber and one position, exactly as   |
//| in v11. Each v12 strategy trades in its own lane - its own magic |
//| (MagicNumber + strategy id) and its own position - so it can     |
//| never occupy the slot a core trade needed. Measured: sharing the |
//| slot cost the core up to 80% of its out-of-sample profit.        |
//| The firewall, day P/L and flatten cover every lane together.     |
//+------------------------------------------------------------------+
bool IsLaneStrat(StratId sid)
{
   return sid == STRAT_TPB || sid == STRAT_PDB || sid == STRAT_MR || sid == STRAT_BAL || sid == STRAT_TDI;
}

ulong MagicFor(StratId sid)
{
   return IsLaneStrat(sid) ? MagicNumber + (ulong)sid : MagicNumber;
}

bool IsOwnMagic(ulong m)
{
   return m == MagicNumber || m == MagicNumber + (ulong)STRAT_TPB ||
          m == MagicNumber + (ulong)STRAT_PDB || m == MagicNumber + (ulong)STRAT_MR ||
          m == MagicNumber + (ulong)STRAT_BAL || m == MagicNumber + (ulong)STRAT_TDI;
}

bool LaneHasPosition(StratId sid)
{
   ulong magic = MagicFor(sid);
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetTicket(i) == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (ulong)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Position / order helpers                                         |
//| OwnPositionTicket / HasOpenPosition / OwnPendingTicket are the   |
//| CORE lane only (they gate the core). OwnPositionTickets covers   |
//| every lane (management, flatten, firewall).                      |
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

//--- every ticket we own on this symbol, all lanes
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
      if(!IsOwnMagic((ulong)PositionGetInteger(POSITION_MAGIC)))
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

   // v12 strategies size their own target, so 1R comes from the stop while
   // it is still on the loss side. The opening-range trades keep the v9
   // reconstruction from TP / RR (unchanged, so parity holds).
   string cmt = PositionGetString(POSITION_COMMENT);
   bool ownLevels = StringFind(cmt, "ADZ12 TPB") == 0 || StringFind(cmt, "ADZ12 PDB") == 0 ||
                    StringFind(cmt, "ADZ12 MR") == 0 || StringFind(cmt, "ADZ12 BAL") == 0 ||
                    StringFind(cmt, "ADZ12 TDI") == 0;
   double initRisk = 0.0;
   if(ownLevels && sl > 0.0 && (isBuy ? sl < entry : sl > entry))
      initRisk = MathAbs(entry - sl);
   if(initRisk <= 0.0 && tp > 0.0 && g_riskReward > 0.0)
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
   g_states[n].managed     = StringFind(cmt, "ADZ12 MR") != 0 &&
                             (BALManaged || StringFind(cmt, "ADZ12 BAL") != 0);
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
      case HALT_WEEKEND:      return "WEEKEND FLAT";
      case HALT_TARGET_LOCK:  return "PHASE TARGET HIT";
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

//+------------------------------------------------------------------+
//| FTMO MODE (v12.40)                                               |
//|  - static floor: equity may not fall below init*(1-maxLoss)       |
//|  - daily floor:  equity may not fall below dayStartBalance -      |
//|                  dailyLoss * init                                 |
//|  The EA halts FTMOSafetyBufferPercent BEFORE either floor, sizes  |
//|  each trade so a full loss cannot cross them, and closes the book |
//|  and stops once the phase target is banked.                       |
//+------------------------------------------------------------------+
bool IsFtmo()
{
   return TradingMode == MODE_FTMO;
}

double FtmoFloor()
{
   return g_ftmoInit * (1.0 - (FTMOMaxLossPercent - FTMOSafetyBufferPercent) / 100.0);
}

double FtmoDayFloor()
{
   return g_dayStartBalance - (FTMODailyLossPercent - FTMOSafetyBufferPercent) / 100.0 * g_ftmoInit;
}

//--- distinct server days with at least one entry since the challenge began
int FtmoTradingDays()
{
   if(!HistorySelect(g_ftmoStart, TimeCurrent() + 60))
      return 0;
   datetime seen[];
   for(int i = 0; i < HistoryDealsTotal(); i++)
   {
      ulong d = HistoryDealGetTicket(i);
      if(d == 0 || !IsOwnMagic((ulong)HistoryDealGetInteger(d, DEAL_MAGIC)))
         continue;
      if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(d, DEAL_ENTRY) != DEAL_ENTRY_IN)
         continue;
      datetime day = DayStart((datetime)HistoryDealGetInteger(d, DEAL_TIME));
      bool dup = false;
      for(int k = 0; k < ArraySize(seen); k++)
         if(seen[k] == day) { dup = true; break; }
      if(!dup)
      {
         int n = ArraySize(seen);
         ArrayResize(seen, n + 1);
         seen[n] = day;
      }
   }
   return ArraySize(seen);
}

//--- after the target: the firm still needs N trading days. Open and
//--- immediately close one minimum lot per day until the count is met.
void FtmoTopUpTradingDay()
{
   static datetime doneDay = 0;
   if(doneDay == g_dayStart || FtmoTradingDays() >= FTMOMinTradingDays)
      return;
   int h = CurrentHour();
   if(h < g_firstEntryHour || h >= LastEntryHour)
      return;
   if((int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > MaxSpreadPoints)
      return;
   double lots = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(SlippagePoints);
   if(trade.Buy(lots, _Symbol, 0.0, 0.0, 0.0, "ADZ12 FTMO day"))
   {
      ulong t = OwnPositionTicket();
      if(t != 0)
         trade.PositionClose(t, SlippagePoints);
      doneDay = g_dayStart;
      Print("Apex Drawdown Zero [FTMO]: minimum-trading-day top-up placed");
   }
}

void UpdateFtmo()
{
   if(!IsFtmo() || !UseRiskFirewall || g_ftmoInit <= 0.0)
      return;
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);

   if(eq <= FtmoFloor())
      TripHalt(HALT_MAX_DRAWDOWN, true,
               StringFormat("FTMO floor: equity %.2f <= %.2f (max loss %.1f%% - buffer %.1f%%)",
                            eq, FtmoFloor(), FTMOMaxLossPercent, FTMOSafetyBufferPercent));

   if(eq <= FtmoDayFloor())
      TripHalt(HALT_DAILY_LOSS, false,
               StringFormat("FTMO daily floor: equity %.2f <= %.2f", eq, FtmoDayFloor()));

   // bank the phase: 0.1% cushion so the closed balance, not just equity,
   // clears the target after the closing spread
   if(FTMOPhaseTargetPercent > 0.0 && g_haltAll != HALT_TARGET_LOCK &&
      eq >= g_ftmoInit * (1.0 + (FTMOPhaseTargetPercent + 0.1) / 100.0))
      TripHalt(HALT_TARGET_LOCK, true,
               StringFormat("phase target +%.1f%% reached: equity %.2f on %.2f - book closed",
                            FTMOPhaseTargetPercent, eq, g_ftmoInit));
   // the target lock always closes the book, whatever FirewallClosesTrades says
   if(g_haltAll == HALT_TARGET_LOCK && !FirewallClosesTrades && OwnPositionCount() > 0)
      FlattenAll("phase target");

   // v12.43: FTMO judges the CLOSED balance. The lock fires on equity, and
   // the closing deals' commission can leave the balance just short of the
   // target (seen: 10 986 on a 11 000 target). If so, release the lock and
   // keep trading - otherwise the EA would sit at +9.9% forever.
   double target = g_ftmoInit * (1.0 + FTMOPhaseTargetPercent / 100.0);
   if(g_haltAll == HALT_TARGET_LOCK && OwnPositionCount() == 0 &&
      AccountInfoDouble(ACCOUNT_BALANCE) < target)
   {
      g_haltAll = HALT_NONE;
      g_haltNote = "";
      Print("Apex Drawdown Zero [FTMO]: balance ", DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2),
            " short of target ", DoubleToString(target, 2), " after costs - lock released, trading on");
   }

   if(g_haltAll == HALT_TARGET_LOCK && OwnPositionCount() == 0)
      FtmoTopUpTradingDay();

   // v12.41: in the tester a challenge is over once it passes (target +
   // minimum days, book flat) or hits the static floor - stop the run there
   // so real-tick challenge batches finish in minutes, not hours
   if(MQLInfoInteger(MQL_TESTER) && OwnPositionCount() == 0)
   {
      bool passed = g_haltAll == HALT_TARGET_LOCK && FtmoTradingDays() >= FTMOMinTradingDays &&
                    AccountInfoDouble(ACCOUNT_BALANCE) >= target;
      bool failed = g_haltAll == HALT_MAX_DRAWDOWN;
      if(passed || failed)
      {
         Print("Apex Drawdown Zero [FTMO]: challenge ", passed ? "PASSED" : "STOPPED AT FLOOR",
               " - tester stopped");
         TesterStop();
      }
   }
}

//--- risk for the next trade. Outside FTMO mode this is the plain setting.
//--- In FTMO mode it is also capped at a third of the room left above the
//--- nearer firm floor, so no single loss - even with a second lane open -
//--- can cross it. Near the floor the EA trades small instead of stopping.
double EffectiveRiskPct()
{
   if(!IsFtmo() || g_ftmoInit <= 0.0)
      return g_riskPercent;
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   double eq  = AccountInfoDouble(ACCOUNT_EQUITY);
   double room = MathMin(eq - FtmoFloor(), eq - FtmoDayFloor());
   if(room <= 0.0 || bal <= 0.0)
      return 0.0;
   return MathMin(g_riskPercent, room / MathMax(1.0, FTMORoomDivisor) / bal * 100.0);
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

   UpdateFtmo();

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
   CancelLanePendings(reason);
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
   if(CurrentHour() >= LastEntryHour || CurrentHour() < g_firstEntryHour)
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

   g_signal = candidate;
   g_activeStrat = STRAT_CORE;
   g_useCustomLevels = false;
   g_signalHigh = sigHigh;
   g_signalLow = sigLow;
   g_retestLevel = retest;
   g_lastSignalBarTime = barTime;

   Print("Apex Drawdown Zero: ", SignalText(g_signal), " at ", TimeToString(barTime),
         " retest level ", DoubleToString(g_retestLevel, _Digits));
   DrawSignal();
}

//+------------------------------------------------------------------+
//| COMPLEMENTARY STRATEGIES                                         |
//|                                                                  |
//| The core strategy takes at most one opening-range break per day  |
//| and sits out everything else. These trade what it skips:         |
//|                                                                  |
//|   S1 NY session   - a second opening range at the New York open  |
//|                     (FX only: it lost out of sample on gold).    |
//|   S4 Trend pullback - dip to the fast EMA inside a trend.        |
//|   S5 Prior-day break - yesterday's high/low as the level.        |
//|   S6 Mean reversion - RSI(2) extreme against a trend, snap-back. |
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
      case STRAT_TPB:  return "TPB";
      case STRAT_PDB:  return "PDB";
      case STRAT_MR:   return "MR";
      case STRAT_BAL:  return "BAL";
      case STRAT_TDI:  return "TDI";
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

   g_signal = cand;
   g_activeStrat = STRAT_NY;
   g_signalHigh = high;
   g_signalLow = low;
   g_retestLevel = buy ? g_nyBoxHigh : g_nyBoxLow;
   g_lastSignalBarTime = barTime;
   g_useCustomLevels = false;
   Print("Apex Drawdown Zero [NY]: ", SignalText(g_signal),
         " NY box ", DoubleToString(g_nyBoxLow, _Digits), "-",
         DoubleToString(g_nyBoxHigh, _Digits));
}

//+------------------------------------------------------------------+
//| v12 strategies - shared plumbing                                 |
//+------------------------------------------------------------------+
double BufferValue(int handle, int shift)
{
   if(handle == INVALID_HANDLE)
      return 0.0;
   double v[1];
   if(CopyBuffer(handle, 0, shift, 1, v) == 1)
      return v[0];
   return 0.0;
}

//--- a lane's own daily budget: once per day in the H1 modes, re-arming
//--- in high-frequency mode (same rule the core follows)
bool LaneSlotFree(StratId sid)
{
   return !g_oneTradePerDay || !g_stratDone[(int)sid];
}

//--- gates for a v12 strategy: its own lane, plus the shared firewall
bool ExtraStrategyReady(StratId sid)
{
   if(g_signal != SIGNAL_NONE)
      return false;
   if(!LaneSlotFree(sid))
      return false;
   if(LaneHasPosition(sid))
      return false;
   if(FirewallBlocksEntry())
      return false;
   int h = CurrentHour();
   return h >= g_firstEntryHour && h < LastEntryHour;
}

//--- arm a signal that carries its own stop and target distances. The
//--- levels are anchored to the live price, because TryEnter goes to
//--- market on this same tick.
void ArmOwnLevels(StratId sid, bool buy, double stopDist, double targetDist)
{
   double entry = buy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   g_signal = buy ? SIGNAL_BUY_CONTINUATION : SIGNAL_SELL_CONTINUATION;
   g_activeStrat = sid;
   g_customSl = buy ? entry - stopDist : entry + stopDist;
   g_customTp = buy ? entry + targetDist : entry - targetDist;
   g_useCustomLevels = true;
   // deliberately leaves the core's signal-bar marker alone: sharing it
   // would stop the core re-reading a bar it had not finished with
   Print("Apex Drawdown Zero [", StratText(sid), "]: ", buy ? "BUY" : "SELL",
         " stop ", DoubleToString(g_customSl, _Digits),
         " target ", DoubleToString(g_customTp, _Digits));
}

//+------------------------------------------------------------------+
//| S4 - trend pullback                                              |
//| Trend: close and fast EMA both on the same side of the slow EMA, |
//| fast EMA sloping that way. Setup: within PullbackLookback bars   |
//| price dipped to the fast EMA. Trigger: a bar that closes back    |
//| beyond the previous bar's extreme, in the trend direction.       |
//+------------------------------------------------------------------+
void DetectTrendPullback()
{
   if(!g_useTPB || !ExtraStrategyReady(STRAT_TPB))
      return;

   static datetime lastBar = 0;
   datetime barTime = iTime(_Symbol, g_boxTF, 1);
   if(barTime == 0 || barTime == lastBar)
      return;
   lastBar = barTime;

   double atr = AtrValue();
   double slow = BufferValue(g_emaTrendHandle, 1);
   double fast = BufferValue(g_emaFastHandle, 1);
   double fastPrev = BufferValue(g_emaFastHandle, 1 + PullbackLookback);
   if(atr <= 0.0 || slow <= 0.0 || fast <= 0.0 || fastPrev <= 0.0)
      return;

   double open1  = iOpen(_Symbol, g_boxTF, 1);
   double high1  = iHigh(_Symbol, g_boxTF, 1);
   double low1   = iLow(_Symbol, g_boxTF, 1);
   double close1 = iClose(_Symbol, g_boxTF, 1);
   if(high1 - low1 > 2.5 * atr)           // news bar: not a pullback resumption
      return;

   bool up   = close1 > slow && fast > slow && fast > fastPrev;
   bool down = close1 < slow && fast < slow && fast < fastPrev;
   if(!up && !down)
      return;

   // did price dip to the fast EMA in the lookback, and how far did it go?
   bool touched = false;
   double ext = up ? DBL_MAX : -DBL_MAX;
   for(int k = 1; k <= PullbackLookback; k++)
   {
      double emaK = BufferValue(g_emaFastHandle, k);
      double hk = iHigh(_Symbol, g_boxTF, k);
      double lk = iLow(_Symbol, g_boxTF, k);
      if(emaK <= 0.0)
         return;
      if(up)
      {
         if(lk <= emaK + 0.10 * atr) touched = true;
         ext = MathMin(ext, lk);
      }
      else
      {
         if(hk >= emaK - 0.10 * atr) touched = true;
         ext = MathMax(ext, hk);
      }
   }
   if(!touched)
      return;

   // resumption bar
   bool trigger = up ? (close1 > open1 && close1 > iHigh(_Symbol, g_boxTF, 2) && close1 > fast)
                     : (close1 < open1 && close1 < iLow(_Symbol, g_boxTF, 2) && close1 < fast);
   if(!trigger)
      return;

   double entry = up ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double stop = up ? ext - PullbackStopAtr * atr : ext + PullbackStopAtr * atr;
   double dist = MathAbs(entry - stop);
   // a dip so shallow the stop sits in the spread, or so deep the trend is
   // in doubt, is not the setup
   if(dist < 0.75 * atr || dist > 3.0 * atr)
      return;

   if(TPBUseTDIFilter)
   {
      double g, r, m;
      if(!TdiAt(1, g, r, m))
         return;
      if(up ? g <= m : g >= m)
         return;
   }

   ArmOwnLevels(STRAT_TPB, up, dist, dist * PullbackRR);
}

//+------------------------------------------------------------------+
//| S5 - prior-day high/low breakout                                 |
//| The first bar of the day to close beyond yesterday's extreme,    |
//| with a strong body and the EMA bias behind it.                   |
//+------------------------------------------------------------------+
void DetectPriorDayBreak()
{
   if(!UsePriorDayBreak || !ExtraStrategyReady(STRAT_PDB))
      return;

   static datetime lastBar = 0;
   datetime barTime = iTime(_Symbol, g_boxTF, 1);
   if(barTime == 0 || barTime == lastBar || barTime < g_dayStart)
      return;
   lastBar = barTime;

   double atr = AtrValue();
   double pdh = iHigh(_Symbol, PERIOD_D1, 1);
   double pdl = iLow(_Symbol, PERIOD_D1, 1);
   if(atr <= 0.0 || pdh <= 0.0 || pdl <= 0.0)
      return;

   double open1  = iOpen(_Symbol, g_boxTF, 1);
   double high1  = iHigh(_Symbol, g_boxTF, 1);
   double low1   = iLow(_Symbol, g_boxTF, 1);
   double close1 = iClose(_Symbol, g_boxTF, 1);
   double close2 = iClose(_Symbol, g_boxTF, 2);
   double buf = PDBBufferAtr * atr;
   if(!StrongBody(open1, close1, high1, low1))
      return;

   bool buy = false, sell = false;
   if(close1 > pdh + buf && close2 <= pdh + buf && BiasOK(true))
      buy = true;
   else if(close1 < pdl - buf && close2 >= pdl - buf && BiasOK(false))
      sell = true;
   if(!buy && !sell)
      return;

   double dist = PDBStopAtr * atr;
   ArmOwnLevels(STRAT_PDB, buy, dist, dist * PDBRR);
}

//+------------------------------------------------------------------+
//| S6 - mean reversion                                              |
//| RSI(MRRsiPeriod) at an extreme against the slow-EMA trend: buy   |
//| the oversold dip in an uptrend, sell the overbought pop in a     |
//| downtrend. Fixed ATR stop and target, held to either (no BE or   |
//| partial - a snap-back trade has no runner to protect).           |
//+------------------------------------------------------------------+
void DetectMeanReversion()
{
   if(!UseMeanReversion || !ExtraStrategyReady(STRAT_MR))
      return;

   static datetime lastBar = 0;
   datetime barTime = iTime(_Symbol, g_boxTF, 1);
   if(barTime == 0 || barTime == lastBar)
      return;
   lastBar = barTime;

   double atr = AtrValue();
   double slow = BufferValue(g_emaTrendHandle, 1);
   double rsi = BufferValue(g_rsiHandle, 1);
   double close1 = iClose(_Symbol, g_boxTF, 1);
   if(atr <= 0.0 || slow <= 0.0 || rsi <= 0.0)
      return;

   bool buy = close1 > slow && rsi < MRRsiLevel;
   bool sell = close1 < slow && rsi > 100.0 - MRRsiLevel;
   if(!buy && !sell)
      return;

   ArmOwnLevels(STRAT_MR, buy, MRStopAtr * atr, MRTargetAtr * atr);
}

//+------------------------------------------------------------------+
//| S8 - TRADERS DYNAMIC INDEX (v12.20)                              |
//| Straight port of the TradingView study's maths. Pine's stdev is  |
//| the population form, so this one is too.                        |
//+------------------------------------------------------------------+
bool TdiAt(int shift, double &green, double &red, double &mid)
{
   int n = MathMax(TDIBandLength, MathMax(TDIRedMA, TDIGreenMA));
   double r[];
   ArraySetAsSeries(r, true);
   if(CopyBuffer(g_tdiRsiHandle, 0, shift, n, r) != n)
      return false;

   double sum = 0.0;
   for(int i = 0; i < TDIBandLength; i++) sum += r[i];
   mid = sum / TDIBandLength;

   sum = 0.0;
   for(int i = 0; i < TDIRedMA; i++) sum += r[i];
   red = sum / TDIRedMA;

   sum = 0.0;
   for(int i = 0; i < TDIGreenMA; i++) sum += r[i];
   green = sum / TDIGreenMA;
   return true;
}

//--- regular divergence confirmed within the last `window` closed bars.
//--- A pivot at shift p is confirmed lbR (=5) bars later, as in the study.
bool RecentDivergence(bool bull, int window)
{
   const int lb = 5, rangeLo = 5, rangeHi = 60;
   int need = window + lb + rangeHi + lb + 2;
   double r[];
   ArraySetAsSeries(r, true);
   if(CopyBuffer(g_tdiRsiHandle, 0, 0, need + 1, r) != need + 1)
      return false;

   for(int t = 1; t <= window; t++)
   {
      int p = t + lb;                       // the pivot bar that confirmed on bar t
      if(!IsRsiPivot(r, p, lb, bull))
         continue;
      // the previous pivot of the same kind
      for(int q = p + 1; q <= p + rangeHi && q + lb < need; q++)
      {
         if(!IsRsiPivot(r, q, lb, bull))
            continue;
         if(q - p < rangeLo)
            break;
         if(bull && r[p] > r[q] && iLow(_Symbol, g_boxTF, p) < iLow(_Symbol, g_boxTF, q))
            return true;
         if(!bull && r[p] < r[q] && iHigh(_Symbol, g_boxTF, p) > iHigh(_Symbol, g_boxTF, q))
            return true;
         break;                              // only the most recent previous pivot counts
      }
   }
   return false;
}

bool IsRsiPivot(const double &r[], int p, int lb, bool low)
{
   for(int k = 1; k <= lb; k++)
   {
      if(low  && (r[p] >= r[p - k] || r[p] >= r[p + k])) return false;
      if(!low && (r[p] <= r[p - k] || r[p] <= r[p + k])) return false;
   }
   return true;
}

void DetectTDI()
{
   if(!g_useTDI || !ExtraStrategyReady(STRAT_TDI))
      return;

   static datetime lastBar = 0;
   datetime barTime = iTime(_Symbol, g_boxTF, 1);
   if(barTime == 0 || barTime == lastBar)
      return;
   lastBar = barTime;

   double g1, r1, m1, g2, r2, m2;
   if(!TdiAt(1, g1, r1, m1) || !TdiAt(2, g2, r2, m2))
      return;

   bool buy  = g1 > r1 && g2 <= r2 && r1 > m1 && r1 > 50.0;
   bool sell = g1 < r1 && g2 >= r2 && r1 < m1 && r1 < 50.0;
   if(!buy && !sell)
      return;
   if(TDIRequireDivergence && !RecentDivergence(buy, TDIDivWindow))
      return;

   double atr = AtrValue();
   if(atr <= 0.0)
      return;
   double dist = TDIStopAtr * atr;
   ArmOwnLevels(STRAT_TDI, buy, dist, dist * TDIRR);
}

//+------------------------------------------------------------------+
//| S7 - BALLISTIC SNIPER (v12.10)                                   |
//| Unlike the other lanes this one does not chase: it arms a limit  |
//| order and lets price come back to it. An unfilled snipe costs    |
//| nothing, so the filter can be strict about what it waits for.    |
//+------------------------------------------------------------------+
ulong LanePendingTicket(StratId sid)
{
   ulong magic = MagicFor(sid);
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if(OrderGetString(ORDER_SYMBOL) == _Symbol && (ulong)OrderGetInteger(ORDER_MAGIC) == magic)
         return ticket;
   }
   return 0;
}

void CancelLanePendings(const string reason)
{
   ulong t = LanePendingTicket(STRAT_BAL);
   if(t != 0 && trade.OrderDelete(t))
      Print("Apex Drawdown Zero [BAL]: snipe cancelled (", reason, ")");
   g_balExpiry = 0;
}

//--- expiry + firewall for a resting snipe (runs every tick)
void ManageBallisticPending()
{
   if(LanePendingTicket(STRAT_BAL) == 0)
   {
      g_balExpiry = 0;
      return;
   }
   if(g_balExpiry == 0)   // orphan after a restart
      g_balExpiry = (datetime)((long)TimeCurrent() + (long)BALExpiryBars * PeriodSeconds(g_boxTF));
   if(FirewallBlocksEntry())
      CancelLanePendings("firewall");
   else if(TimeCurrent() > g_balExpiry)
      CancelLanePendings("expired unfilled");
}

//--- was bar `k` in a squeeze (Bollinger inside Keltner)?
bool SqueezedAt(int k)
{
   double up[1], lo[1];
   if(CopyBuffer(g_bandsHandle, 1, k, 1, up) != 1 || CopyBuffer(g_bandsHandle, 2, k, 1, lo) != 1)
      return false;
   double atr = BufferValue(g_atrHandle, k);
   if(atr <= 0.0)
      return false;
   return (up[0] - lo[0]) < 2.0 * BALKeltnerMult * atr;
}

void DetectBallistic()
{
   if(!g_useBAL)
      return;
   if(!LaneSlotFree(STRAT_BAL) || LaneHasPosition(STRAT_BAL) || LanePendingTicket(STRAT_BAL) != 0)
      return;
   if(FirewallBlocksEntry())
      return;
   int h = CurrentHour();
   if(h < g_firstEntryHour || h >= LastEntryHour)
      return;

   static datetime lastBar = 0;
   datetime barTime = iTime(_Symbol, g_boxTF, 1);
   if(barTime == 0 || barTime == lastBar)
      return;
   lastBar = barTime;

   // 1) compression before the ignition bar
   int squeezed = 0;
   for(int k = 2; k <= 1 + BALSqueezeLookback; k++)
      if(SqueezedAt(k))
         squeezed++;
   if(squeezed < BALMinSqueezeBars)
      return;

   // 2) ignition: wide, full-bodied, closing outside the band
   double atr = AtrValue();
   double up[1], lo[1];
   if(atr <= 0.0 || CopyBuffer(g_bandsHandle, 1, 1, 1, up) != 1 || CopyBuffer(g_bandsHandle, 2, 1, 1, lo) != 1)
      return;
   double o = iOpen(_Symbol, g_boxTF, 1), hi = iHigh(_Symbol, g_boxTF, 1);
   double l = iLow(_Symbol, g_boxTF, 1),  c = iClose(_Symbol, g_boxTF, 1);
   double range = hi - l;
   if(range < BALIgnitionAtr * atr || !StrongBody(o, c, hi, l))
      return;

   bool buy = c > up[0] && c > o && BiasOK(true);
   bool sell = c < lo[0] && c < o && BiasOK(false);
   if(!buy && !sell)
      return;

   // 3) the snipe
   double level = buy ? hi - range * BALRetrace : l + range * BALRetrace;
   double sl    = buy ? l - BALStopBufferAtr * atr : hi + BALStopBufferAtr * atr;
   double risk  = MathAbs(level - sl);
   if(risk <= 0.0)
      return;
   double tp = buy ? level + BALRR * risk : level - BALRR * risk;

   double guard = GuardDistance();
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK), bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(buy ? (ask - level < guard) : (level - bid < guard))
      return;                          // already back at the level: no edge in chasing
   if(risk < guard)
      return;

   level = NormalizeDouble(level, _Digits);
   double lots = LotsForRisk(level, sl, EffectiveRiskPct());
   if(lots > 0.0)
      lots = CapLotsByMargin(buy, level, lots);
   if(lots <= 0.0)
      return;

   trade.SetExpertMagicNumber(MagicFor(STRAT_BAL));
   trade.SetDeviationInPoints(SlippagePoints);
   string tag = StringFormat("ADZ12 BAL %s", buy ? "buy" : "sell");
   bool ok = buy ? trade.BuyLimit(lots, level, _Symbol, NormalizeDouble(sl, _Digits),
                                  NormalizeDouble(tp, _Digits), ORDER_TIME_GTC, 0, tag)
                 : trade.SellLimit(lots, level, _Symbol, NormalizeDouble(sl, _Digits),
                                   NormalizeDouble(tp, _Digits), ORDER_TIME_GTC, 0, tag);
   trade.SetExpertMagicNumber(MagicNumber);
   if(!ok)
      return;

   g_stratDone[(int)STRAT_BAL] = true;
   g_balExpiry = (datetime)((long)barTime + (long)(1 + BALExpiryBars) * PeriodSeconds(g_boxTF));
   Print("Apex Drawdown Zero [BAL]: ", buy ? "BUY" : "SELL", " snipe at ",
         DoubleToString(level, _Digits), " stop ", DoubleToString(sl, _Digits),
         " target ", DoubleToString(tp, _Digits), " (", squeezed, "/", BALSqueezeLookback, " squeezed)");
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
   // v12 strategies price their own stop and target off their own
   // structure rather than the box, so they supply them directly
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

   double lots = LotsForRisk(entry, sl, EffectiveRiskPct());
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

   string tag = StringFormat("ADZ12 %s %s", StratText(g_activeStrat),
                             buy ? "buy" : "sell");
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
   double lots = LotsForRisk(level, sl, EffectiveRiskPct());
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

   string tag = StringFormat("ADZ12 %s retest", buy ? "buy" : "sell");
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

//--- a lane signal is taken or dropped on the tick it was armed; it never
//--- lingers in g_signal where it could block the core
void TryEnterLane()
{
   StratId sid = g_activeStrat;
   int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   int h = CurrentHour();
   bool ok = !FirewallBlocksEntry() && !LaneHasPosition(sid) && LaneSlotFree(sid) &&
             h >= g_firstEntryHour && h < LastEntryHour && spread <= MaxSpreadPoints;

   if(ok)
   {
      bool buy = (g_signal == SIGNAL_BUY_SWEEP || g_signal == SIGNAL_BUY_CONTINUATION);
      trade.SetExpertMagicNumber(MagicFor(sid));
      trade.SetDeviationInPoints(SlippagePoints);
      if(MarketEnter(buy))
      {
         g_laneCount[(int)sid]++;
         int cap = (sid == STRAT_TPB) ? MathMax(1, TPBMaxPerDay) : 1;
         if(g_laneCount[(int)sid] >= cap)
            g_stratDone[(int)sid] = true;
      }
      trade.SetExpertMagicNumber(MagicNumber);
   }

   g_signal = SIGNAL_NONE;
   g_useCustomLevels = false;
   g_activeStrat = STRAT_CORE;
}

void TryEnter()
{
   if(g_signal == SIGNAL_NONE)
      return;
   if(IsLaneStrat(g_activeStrat))
   {
      TryEnterLane();
      return;
   }
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
   int lastHour = (g_activeStrat == STRAT_NY) ? NYLastEntryHour : LastEntryHour;
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

   // v12 strategies carry their own levels and always go to market; the
   // retest styles only make sense for the opening-range breakouts
   EntryStyleMode style = g_useCustomLevels ? ENTRY_IMMEDIATE : EntryStyle;

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
//| EXIT MANAGEMENT                                                  |
//| Per-ticket. Order of operations per ticket:                      |
//|   1) partial TP  - bank PartialClosePercent at TP1               |
//|   2) break-even  - remove the remaining risk                     |
//| Trailing, time stops and profit ladders were all measured and    |
//| removed in v12: each one cut the runners the 2R target lives on. |
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

   // track the excursions for the diagnostics log
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

   if(!g_states[idx].managed)
      return;


   // --- 1) partial take-profit: bank part of the position at TP1 so the
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

   // --- 2) break-even
   if(UseBreakEven && rNow >= BreakEvenTriggerRR)
   {
      double be = isBuy ? entry + BreakEvenOffsetPoints * _Point
                        : entry - BreakEvenOffsetPoints * _Point;
      if(sl == 0.0 || (isBuy ? be > newSl : be < newSl))
         newSl = be;
   }

   if(newSl == sl)
      return;
   if(sl != 0.0 && MathAbs(newSl - sl) < MinSlStepPoints * _Point)
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
//| counter and the running stats                                    |
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
      ulong magic = (ulong)HistoryDealGetInteger(deal, DEAL_MAGIC);
      if(!IsOwnMagic(magic))
         continue;
      if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY) != DEAL_ENTRY_OUT)
         continue;

      double profit = HistoryDealGetDouble(deal, DEAL_PROFIT)
                    + HistoryDealGetDouble(deal, DEAL_SWAP)
                    + HistoryDealGetDouble(deal, DEAL_COMMISSION);

      dayRealized += profit;
      // StopAfterWin belongs to the core lane: a lane win must not end the
      // core's day, or the lanes would crowd the core out again
      if(profit > 0.0 && magic == MagicNumber)
         g_wonToday = true;

      // streak + stats update, once per deal
      if(deal > g_lastSeenDeal)
      {
         g_lastSeenDeal = deal;

         if(profit > 0.0)
         {
            g_statWins++;
            g_statProfit += profit;
            g_consecLosses = 0;
         }
         else if(profit < 0.0)
         {
            g_statLosses++;
            g_statLoss += -profit;
            g_consecLosses++;

         }

         JournalDeal(deal, profit);
      }
   }

   g_dayRealized = dayRealized;
}

//--- rebuild the streak counter and lifetime stats after a restart
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
      if(!IsOwnMagic((ulong)HistoryDealGetInteger(deal, DEAL_MAGIC)))
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
      Print("Apex Drawdown Zero: restored loss streak = ", g_consecLosses);
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

   // signal label
   string label = tag + "_txt";
   double labelPrice = buy ? arrowPrice - offset : arrowPrice + offset;
   if(ObjectFind(0, label) < 0)
      ObjectCreate(0, label, OBJ_TEXT, 0, g_lastSignalBarTime, labelPrice);
   ObjectSetString(0, label, OBJPROP_TEXT,
                   StringFormat("%s  [%s]", SignalText(g_signal), StratText(g_activeStrat)));
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
      ObjectSetString(0, full, OBJPROP_FONT, "Segoe UI");
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

//+------------------------------------------------------------------+
//| Dashboard v3 (v12.45) - the APEX Templar Cavalry design: knight  |
//| artwork, badge header, gold-on-ink panels, MIN / SHOW button.    |
//| Presentation only - no entry, sizing or exit calls in here.      |
//+------------------------------------------------------------------+
bool  g_knightCollapsed = false;
ulong g_knightLastPaint = 0;

void KnightRect(string key, int x, int y, int w, int h, color fill, color border)
{
   string n = "ADZ_UI_" + key;
   if(ObjectFind(0, n) < 0) ObjectCreate(0, n, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, n, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, n, OBJPROP_XSIZE, w);       ObjectSetInteger(0, n, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, n, OBJPROP_BGCOLOR, fill);  ObjectSetInteger(0, n, OBJPROP_COLOR, border);
   ObjectSetInteger(0, n, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, n, OBJPROP_BACK, false);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
}

void KnightBitmap(string key, string resource, int x, int y, int w, int h)
{
   string n = "ADZ_UI_" + key;
   if(ObjectFind(0, n) < 0) ObjectCreate(0, n, OBJ_BITMAP_LABEL, 0, 0, 0);
   ObjectSetInteger(0, n, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetString(0, n, OBJPROP_BMPFILE, resource);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, n, OBJPROP_XSIZE, w);       ObjectSetInteger(0, n, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, n, OBJPROP_BACK, false);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
}

string ModeText()
{
   switch(TradingMode)
   {
      case MODE_HIGH_FREQUENCY:    return "HIGH FREQUENCY";
      case MODE_AGGRESSIVE_GROWTH: return "GROWTH";
      case MODE_FTMO:              return "FTMO";
   }
   return "DISCIPLINE";
}

void UpdateDashboard()
{
   if(!g_uiEnabled || !ShowDashboard)
      return;
   const int x = PanelX, y = PanelY;
   const color gold = C'216,180,111', cream = C'241,231,211', muted = C'174,161,140';
   const color green = C'130,204,163', red = C'237,137,126', ink = C'18,20,23', edge = C'86,67,40';

   KnightRect("frame", x - 1, y - 1, 422, g_knightCollapsed ? 60 : 632, ink, edge);
   if(!g_knightCollapsed)
      KnightBitmap("art", "::Assets\\cavalry_background.bmp", x, y + 62, 420, 568);
   KnightRect("header", x, y, 420, 62, ink, edge);
   KnightBitmap("portrait", "::Assets\\cavalry_badge.bmp", x + 12, y + 8, 36, 45);
   PanelLabel("title", x + 60, y + 8, "APEX", gold, 17);
   PanelLabel("edition", x + 61, y + 32, "Drawdown Zero  V12", gold, 11);

   string button = "ADZ_UI_collapse";
   if(ObjectFind(0, button) < 0) ObjectCreate(0, button, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, button, OBJPROP_XDISTANCE, x + 367); ObjectSetInteger(0, button, OBJPROP_YDISTANCE, y + 16);
   ObjectSetInteger(0, button, OBJPROP_XSIZE, 41);          ObjectSetInteger(0, button, OBJPROP_YSIZE, 28);
   ObjectSetInteger(0, button, OBJPROP_BGCOLOR, C'39,33,25'); ObjectSetInteger(0, button, OBJPROP_BORDER_COLOR, edge);
   ObjectSetInteger(0, button, OBJPROP_COLOR, gold);        ObjectSetInteger(0, button, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, button, OBJPROP_FONT, "Segoe UI");
   ObjectSetString(0, button, OBJPROP_TEXT, g_knightCollapsed ? "SHOW" : "MIN");
   ObjectSetInteger(0, button, OBJPROP_HIDDEN, true);       ObjectSetInteger(0, button, OBJPROP_ZORDER, 100);
   ObjectSetInteger(0, button, OBJPROP_STATE, false);
   if(g_knightCollapsed)
      return;

   // --- status
   bool connected = (bool)TerminalInfoInteger(TERMINAL_CONNECTED);
   bool allowed = (bool)TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) && (bool)MQLInfoInteger(MQL_TRADE_ALLOWED) &&
                  (bool)AccountInfoInteger(ACCOUNT_TRADE_ALLOWED);
   bool tester = (bool)MQLInfoInteger(MQL_TESTER);
   string status = tester ? "STRATEGY TESTER" : (!connected ? "OFFLINE" : (!allowed ? "TRADING DISABLED" : "MONITORING"));
   bool halted = UseRiskFirewall && (g_haltAll != HALT_NONE || g_haltDay != HALT_NONE);
   if(halted)
      status = (g_haltAll != HALT_NONE ? "HALTED: " + HaltText(g_haltAll) : "PAUSED: " + HaltText(g_haltDay));
   KnightRect("status_bg", x + 16, y + 218, 388, 44, ink, edge);
   PanelLabel("market", x + 28, y + 223, _Symbol + "   /   H1   /   " + ModeText(), cream, 11);
   PanelLabel("status", x + 28, y + 244, status,
              halted ? (g_haltAll == HALT_TARGET_LOCK ? gold : red)
                     : ((!tester && (!connected || !allowed)) ? red : green), 8);

   // --- open P/L across every lane
   int core = 0, tpb = 0, other = 0;
   double openPL = 0.0, lots = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetTicket(i) == 0 || PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      ulong magic = (ulong)PositionGetInteger(POSITION_MAGIC);
      if(!IsOwnMagic(magic))
         continue;
      if(magic == MagicNumber)                      core++;
      else if(magic == MagicFor(STRAT_TPB))         tpb++;
      else                                          other++;
      lots += PositionGetDouble(POSITION_VOLUME);
      openPL += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   }
   string currency = AccountInfoString(ACCOUNT_CURRENCY);
   KnightRect("pnl_bg", x + 16, y + 277, 388, 78, ink, edge);
   PanelLabel("pnl_caption", x + 28, y + 285, "EA OPEN P/L  /  " + currency, muted, 8);
   PanelLabel("pnl", x + 28, y + 304, StringFormat("%+.2f", openPL), openPL >= 0.0 ? green : red, 24);
   PanelLabel("exposure", x + 238, y + 293, IntegerToString(core + tpb + other) + " / " +
              IntegerToString(g_useTPB ? 2 : 1) + " positions", cream, 10);
   PanelLabel("lots", x + 238, y + 322, DoubleToString(lots, 2) + " lots open", muted, 9);

   // --- account
   KnightRect("account_bg", x + 16, y + 366, 388, 62, ink, edge);
   PanelLabel("balance_caption", x + 28, y + 373, "ACCOUNT BALANCE", muted, 8);
   PanelLabel("equity_caption", x + 218, y + 373, "ACCOUNT EQUITY", muted, 8);
   PanelLabel("balance", x + 28, y + 394, DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2), cream, 14);
   PanelLabel("equity", x + 218, y + 394, DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2), cream, 14);

   // --- engines
   KnightRect("engines_bg", x + 16, y + 439, 388, 111, ink, edge);
   PanelLabel("core_title", x + 28, y + 445, "01  OPENING RANGE", gold, 9);
   color coreClr = muted;
   string coreState = StateText(coreClr);
   PanelLabel("core_state", x + 28, y + 460, core > 0 ? "POSITION OPEN" : coreState, core > 0 ? green : muted, 8);
   PanelLabel("core_count", x + 295, y + 460, IntegerToString(g_tradesToday) + " / " +
              IntegerToString(MathMax(1, g_maxTradesDay)) + " today", muted, 8);

   PanelLabel("tpb_title", x + 28, y + 479, "02  TREND PULLBACK", gold, 9);
   string tpbState = !g_useTPB ? "OFF  (gold, H1 modes only)"
                   : (tpb > 0 ? "POSITION OPEN"
                   : (LanePendingTicket(STRAT_TPB) != 0 ? "ORDER PENDING"
                   : (g_stratDone[STRAT_TPB] ? "DONE TODAY" : "MONITORING SIGNALS")));
   PanelLabel("tpb_state", x + 28, y + 494, tpbState, tpb > 0 ? green : muted, 8);
   PanelLabel("tpb_count", x + 295, y + 494, IntegerToString(g_laneCount[STRAT_TPB]) + " / " +
              IntegerToString(MathMax(1, TPBMaxPerDay)) + " today", muted, 8);

   if(IsFtmo() && g_ftmoInit > 0.0)
   {
      PanelLabel("guard_title", x + 28, y + 512, "03  FTMO GUARD", gold, 9);
      PanelLabel("guard_state", x + 28, y + 527, StringFormat("FLOOR %.0f   DAY %.0f   TARGET %.0f",
                 FtmoFloor(), FtmoDayFloor(), g_ftmoInit * (1.0 + FTMOPhaseTargetPercent / 100.0)),
                 halted ? red : muted, 8);
   }
   else
   {
      PanelLabel("guard_title", x + 28, y + 512, "03  RISK FIREWALL", gold, 9);
      PanelLabel("guard_state", x + 28, y + 527, !UseRiskFirewall ? "OFF"
                 : StringFormat("DAY %+.2f%% / -%.1f%%     DD %.2f%% / %.0f%%", DayPLPercent(),
                                g_dailyLossLimit, DrawdownPercent(), g_maxDrawdown),
                 halted ? red : muted, 8);
   }

   // --- footer
   int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   PanelLabel("spread", x + 20, y + 554, "SPREAD  " + IntegerToString(spread) + " / " +
              IntegerToString(MaxSpreadPoints) + " pts", spread > MaxSpreadPoints ? red : muted, 9);
   PanelLabel("size", x + 237, y + 554, StringFormat("RISK  %.2f%% / TRADE", EffectiveRiskPct()), muted, 9);
   int trades = g_statWins + g_statLosses;
   PanelLabel("profile", x + 20, y + 580, trades > 0
              ? StringFormat("%d TRADES  /  %.0f%% WIN  /  PF %.2f", trades, 100.0 * g_statWins / trades,
                             g_statLoss > 0.0 ? g_statProfit / g_statLoss : 0.0)
              : "NO CLOSED TRADES YET", gold, 8);
   PanelLabel("clock", x + 20, y + 605, "SERVER  " + TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS), muted, 8);
}

//--- throttled repaint (ticks can arrive far faster than anyone can read)
void KnightRefresh(bool force = false)
{
   if(!g_uiEnabled || !ShowDashboard)
      return;
   ulong now = GetTickCount64();
   if(!force && now - g_knightLastPaint < 500)
      return;
   g_knightLastPaint = now;
   UpdateDashboard();
   ChartRedraw();
}

void OnTimer()
{
   KnightRefresh();
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

//--- gold specifically. Silver classifies as a metal, but v12.30 measured
//--- it losing in both windows (core and trend lane), so the AUTO lanes
//--- are gold-only rather than metal-wide.
bool IsGold()
{
   string s = _Symbol;
   StringToUpper(s);
   return StringFind(s, "XAU") >= 0 || StringFind(s, "GOLD") >= 0;
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
   else if(TradingMode == MODE_FTMO)
   {
      // Discipline setups (plus the gold trend lane) at FTMORiskPercent.
      // The EA's own daily cap sits inside the firm's; the trailing peak
      // drawdown cap is replaced by the firm's static floor (UpdateFtmo),
      // because trailing from a new high halted challenges that FTMO
      // itself would still have allowed.
      g_riskPercent    = MathMax(0.01, FTMORiskPercent);
      g_dailyLossLimit = MathMin(3.5, FTMODailyLossPercent - FTMOSafetyBufferPercent);
      g_maxDrawdown    = 0.0;
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

   // resolve the trend-pullback lane the same way
   if(TrendPullback == LANE_OFF)
      g_useTPB = false;
   else if(TrendPullback == LANE_ALWAYS)
      g_useTPB = true;
   else
      g_useTPB = (IsGold() && TradingMode != MODE_HIGH_FREQUENCY);

   if(BallisticSniper == LANE_OFF)
      g_useBAL = false;
   else if(BallisticSniper == LANE_ALWAYS)
      g_useBAL = true;
   else
      g_useBAL = (IsGold() && TradingMode != MODE_HIGH_FREQUENCY);

   if(TDISignal == LANE_OFF)
      g_useTDI = false;
   else if(TDISignal == LANE_ALWAYS)
      g_useTDI = true;
   else
      g_useTDI = (IsGold() && TradingMode != MODE_HIGH_FREQUENCY);

   // start from the raw inputs, then let the preset override what it tunes
   g_riskReward     = RiskReward;
   g_firstEntryHour = FirstEntryHour;
   g_atrStopMult    = AtrStopMult;

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
         // volatility-matched fallback by symbol family
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
               // the opening-range premise did not hold on indices
               g_riskReward = 1.5; g_firstEntryHour = 14; g_atrStopMult = 3.0;
               break;
            case SYMCLASS_CRYPTO:
               g_riskReward = 2.0; g_firstEntryHour = 0;  g_atrStopMult = 3.0;
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
      if(g_symClass == SYMCLASS_METAL && !IsGold())
         Print("Apex Drawdown Zero: WARNING - '", _Symbol, "' is not gold. On XAGUSD ",
               "the EA LOST money in both test windows (2026 -603, 2025 -933) and hit ",
               "the 10% drawdown halt. Trend pullback is off here. Not recommended.");
      if(g_symClass == SYMCLASS_INDEX)
         Print("Apex Drawdown Zero: '", _Symbol, "' is an index. The opening-range ",
               "premise did not hold on indices in testing - not recommended.");
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
      Print("Apex Drawdown Zero V12.40: NY session ", g_useNY ? "ON" : "off",
            ", trend pullback ", g_useTPB ? "ON" : "off",
            ", ballistic sniper ", g_useBAL ? "ON" : "off", " (", SymbolClassText(), ")");
      Print("Apex Drawdown Zero V12.40: preset ", g_presetName,
            "  RR=", DoubleToString(g_riskReward, 2),
            "  firstEntryHour=", g_firstEntryHour,
            "  atrStop=", DoubleToString(g_atrStopMult, 2));
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

   // ATR drives the volatility-adaptive stop and the volatility-relative
   // breakout buffer / min-box filter
   g_atrHandle = iATR(_Symbol, g_boxTF, AtrPeriod);

   // v12 strategies: only create what the enabled ones read
   if(g_useTPB || UseMeanReversion)
      g_emaTrendHandle = iMA(_Symbol, g_boxTF, TrendEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   if(g_useTPB)
      g_emaFastHandle = iMA(_Symbol, g_boxTF, PullbackEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   if(UseMeanReversion)
      g_rsiHandle = iRSI(_Symbol, g_boxTF, MRRsiPeriod, PRICE_CLOSE);
   if(g_useBAL)
      g_bandsHandle = iBands(_Symbol, g_boxTF, 20, 0, 2.0, PRICE_CLOSE);
   if(g_useTDI || (g_useTPB && TPBUseTDIFilter))
      g_tdiRsiHandle = iRSI(_Symbol, g_boxTF, TDIRsiPeriod, PRICE_CLOSE);
   if(g_atrHandle == INVALID_HANDLE)
      Print("Apex Drawdown Zero: ATR handle failed, falling back to fixed point buffers");


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

   // FTMO mode: fix the challenge's initial balance and start. Remembered
   // across restarts in live trading, so a mid-challenge restart does not
   // move the floors.
   if(IsFtmo())
   {
      string kInit = StringFormat("ADZ12_ftmo_init_%I64u", MagicNumber);
      string kStart = StringFormat("ADZ12_ftmo_start_%I64u", MagicNumber);
      bool live = !MQLInfoInteger(MQL_TESTER);
      if(FTMOInitialBalance > 0.0)
         g_ftmoInit = FTMOInitialBalance;
      else if(live && GlobalVariableCheck(kInit))
         g_ftmoInit = GlobalVariableGet(kInit);
      else
         g_ftmoInit = AccountInfoDouble(ACCOUNT_BALANCE);
      if(live && GlobalVariableCheck(kStart))
         g_ftmoStart = (datetime)(long)GlobalVariableGet(kStart);
      else
         g_ftmoStart = TimeCurrent();
      if(live)
      {
         GlobalVariableSet(kInit, g_ftmoInit);
         GlobalVariableSet(kStart, (double)(long)g_ftmoStart);
         Print("Apex Drawdown Zero [FTMO]: initial ", DoubleToString(g_ftmoInit, 2),
               ", target +", DoubleToString(FTMOPhaseTargetPercent, 1), "%, floor ",
               DoubleToString(FtmoFloor(), 2), ", risk ", DoubleToString(g_riskPercent, 2), "%");
      }
   }

   IsNewDay();

   if(UseRiskFirewall && !MQLInfoInteger(MQL_TESTER))
      Print("Apex Drawdown Zero: risk firewall ARMED - daily -",
            DoubleToString(g_dailyLossLimit, 2), "%, max DD ",
            DoubleToString(g_maxDrawdown, 2), "%, equity guard ",
            DoubleToString(EquityGuardPercent, 2), "%");

   if(g_uiEnabled && ShowDashboard)
   {
      EventSetTimer(1);        // keeps the clock / P&L live between ticks
      KnightRefresh(true);
   }

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Daily equity log (tester only)                                   |
//| One row per server day: start balance/equity, the LOWEST equity  |
//| seen intraday (floating losses included - what prop firms        |
//| measure), end balance/equity and entries opened. Used to replay  |
//| prop-firm challenges from every possible start date.             |
//+------------------------------------------------------------------+
datetime g_dlDay = 0;
double   g_dlStartBal = 0.0, g_dlStartEq = 0.0, g_dlMinEq = 0.0;
int      g_dlHandle = INVALID_HANDLE;

void DailyLogWrite()
{
   if(g_dlHandle == INVALID_HANDLE)
   {
      g_dlHandle = FileOpen(DailyLogFile, FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_COMMON, ',');
      if(g_dlHandle == INVALID_HANDLE)
         return;
      FileWrite(g_dlHandle, "date", "start_bal", "start_eq", "min_eq", "end_bal", "end_eq", "entries");
   }
   int entries = 0;
   if(HistorySelect(g_dlDay, g_dlDay + 86400 - 1))
      for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
      {
         ulong d = HistoryDealGetTicket(i);
         if(d != 0 && IsOwnMagic((ulong)HistoryDealGetInteger(d, DEAL_MAGIC)) &&
            (ENUM_DEAL_ENTRY)HistoryDealGetInteger(d, DEAL_ENTRY) == DEAL_ENTRY_IN)
            entries++;
      }
   FileWrite(g_dlHandle, TimeToString(g_dlDay, TIME_DATE),
             DoubleToString(g_dlStartBal, 2), DoubleToString(g_dlStartEq, 2),
             DoubleToString(g_dlMinEq, 2),
             DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2),
             DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2), IntegerToString(entries));
}

void DailyLogTick()
{
   if(DailyLogFile == "" || !MQLInfoInteger(MQL_TESTER))
      return;
   datetime today = DayStart(TimeCurrent());
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(today != g_dlDay)
   {
      if(g_dlDay != 0)
         DailyLogWrite();
      g_dlDay = today;
      g_dlStartBal = AccountInfoDouble(ACCOUNT_BALANCE);
      g_dlStartEq = eq;
      g_dlMinEq = eq;
   }
   if(eq < g_dlMinEq)
      g_dlMinEq = eq;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   if(g_dlDay != 0 && DailyLogFile != "" && MQLInfoInteger(MQL_TESTER))
      DailyLogWrite();
   if(g_dlHandle != INVALID_HANDLE)
      FileClose(g_dlHandle);

   if(g_emaHandle != INVALID_HANDLE)
      IndicatorRelease(g_emaHandle);
   if(g_atrHandle != INVALID_HANDLE)
      IndicatorRelease(g_atrHandle);
   if(g_emaTrendHandle != INVALID_HANDLE)
      IndicatorRelease(g_emaTrendHandle);
   if(g_emaFastHandle != INVALID_HANDLE)
      IndicatorRelease(g_emaFastHandle);
   if(g_rsiHandle != INVALID_HANDLE)
      IndicatorRelease(g_rsiHandle);
   if(g_bandsHandle != INVALID_HANDLE)
      IndicatorRelease(g_bandsHandle);
   if(g_tdiRsiHandle != INVALID_HANDLE)
      IndicatorRelease(g_tdiRsiHandle);
   ObjectsDeleteAll(0, "ADZ_");
   ChartRedraw();
}

void OnTick()
{
   DailyLogTick();
   if(IsNewDay())
      CancelPending("new trading day");

   UpdateClosedDeals();
   UpdateFirewall();          // must run before any entry path
   ManagePendingExpiry();
   ManageBallisticPending();

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

   if(BuildDailyBox())
   {
      DrawDailyBox();
      ExpireSignal();

      // priority order: the core breakout first (it is the proven edge),
      // then the NY range, then the v12 strategies
      DetectSignal();
      DetectNYSignal();
      TryEnter();

      // v12 lanes: each is armed and entered (or dropped) in turn, so a
      // lane never waits behind another lane's signal
      DetectTrendPullback();
      TryEnter();
      DetectPriorDayBreak();
      TryEnter();
      DetectMeanReversion();
      TryEnter();
      DetectTDI();
      TryEnter();
      DetectBallistic();      // places its own limit; never uses g_signal
   }

   KnightRefresh();
}

//+------------------------------------------------------------------+
//| Dashboard MIN / SHOW button                                      |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_OBJECT_CLICK && sparam == "ADZ_UI_collapse")
   {
      g_knightCollapsed = !g_knightCollapsed;
      ObjectsDeleteAll(0, "ADZ_UI_");
      KnightRefresh(true);
   }
}
