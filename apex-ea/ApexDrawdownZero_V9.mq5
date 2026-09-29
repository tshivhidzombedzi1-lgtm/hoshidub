//+------------------------------------------------------------------+
//| ApexDrawdownZero.mq5                                             |
//| Apex Drawdown Zero — daily separator box, sweep/displacement,    |
//| retest continuation EA.                                          |
//| v7: selectable entry style (retest limit / retest candle /       |
//|     immediate), EMA bias filter, last-entry-hour cutoff,         |
//|     looser R-based trailing, upgraded dashboard.                 |
//| v7.01: stops+freeze level guard on all modifies (MQL5 Market     |
//|        validation fix for "close to market" errors).             |
//| v7.02: free-margin check via OrderCalcMargin before every order, |
//|        volume auto-reduced to fit (MQL5 Market "no money" fix).  |
//| v7.03: SYMBOL_VOLUME_LIMIT cap on order volume (MQL5 Market      |
//|        "volume limit reached" fix).                              |
//| v7.04: MaxLots input — hard per-trade volume cap on top of       |
//|        risk-% sizing (0 = off).                                  |
//| v7.10: data-driven update (XAUUSD H1 Jan-Jul 2026 memorandum):   |
//|        box anchored to first traded bar of the day (metals open  |
//|        01:00 — midnight anchor left the box unbuilt most days),  |
//|        EMA bias optionally applied to sweeps (default on),       |
//|        defaults: ENTRY_IMMEDIATE, RR 2.0, last entry hour 18.    |
//| v7.20: pattern-quality pass (out-of-sample validated): sweeps    |
//|        must close back inside the box by SweepCloseBackPercent   |
//|        of box size (default 20), displacement body raised to 70. |
//| v7.30: win-rate pass (XAUUSD tick backtest Jun 26-Jul 13 2026):  |
//|        R-based trailing removed by default — it was cutting      |
//|        winners short on gold's intrabar noise and turning 2R     |
//|        runners into small scratches. Break-even now arms sooner  |
//|        (0.60R) with a small locked profit (30 pts) so more       |
//|        trades finish risk-free. Opening box widened to 5 candles |
//|        (cleaner levels, fewer false sweeps) and the entry window |
//|        extended to 20:00 to include the NY afternoon session.    |
//|        In-sample: win rate 56%->80%, +0.02R -> +6.1R / 10 days.  |
//| v7.40: volatility-adaptive stop (UseAtrStop, default on): stop   |
//|        distance = AtrStopMult * ATR(AtrPeriod) anchored to the   |
//|        entry, floored at the signal extreme so it is never       |
//|        tighter than structure. Normalises risk across calm/wild  |
//|        sessions. In-sample vs v7.30: +6.1R -> +7.0R, profit      |
//|        factor 4.0 -> 3.3, max drawdown 2.0% -> 1.0% over 10      |
//|        trades. Scale-out and multi-trade-per-day were tested and |
//|        rejected (both lowered expectancy on this data).          |
//| v7.50: pyramiding (UsePyramid, default on) — scale into a winner.|
//|        When the base trade reaches PyramidTriggerRR of target     |
//|        (default 0.70R) one add-on unit opens (own risk %, stop at |
//|        the base entry, same TP) and the base locks at break-even.|
//|        Adds once per day; hedging accounts only (netting averages |
//|        the legs, so it self-disables there). In-sample vs v7.40:  |
//|        +7.0R -> +15.3R, profit factor 3.3 -> 4.8, return          |
//|        +7.2% -> +16.1%, at the cost of win rate (70% -> 60%) and  |
//|        drawdown (1% -> 2%). Set UsePyramid=false for the calmer   |
//|        single-entry profile, or lower PyramidTriggerRR toward     |
//|        0.5 for more aggressive scaling.                           |
//| v8.00: MULTI-PAIR generalization (validated on 6 months of tick  |
//|        data: XAUUSD, EURUSD, EURJPY, US30). The breakout buffer   |
//|        and min-box filter are now volatility-relative — buffer =  |
//|        BreakBufferAtr*ATR, min box = MinBoxAtr*ATR — so the logic |
//|        self-scales to any symbol instead of using gold-calibrated |
//|        fixed points. Added FirstEntryHour to skip the thin Asian  |
//|        session. Pyramiding defaulted OFF (lost money out-of-      |
//|        sample). Retuned for robustness: RR 1.5, ATR stop x2.5,    |
//|        body 60. Out-of-sample results per pair (6 mo, 1% risk):   |
//|        EURUSD +13% PF1.5, EURJPY +7% PF1.2, XAUUSD +2% PF2.0,     |
//|        US30 -4.5% (indices don't fit the opening-range premise —  |
//|        do NOT trade US30 with this EA). vs the old gold-only build |
//|        which lost 10-14% on EURJPY/US30. See SETTINGS.md for      |
//|        recommended per-symbol input sets.                         |
//|        NOTE: 4-6 months is still a limited sample — re-validate    |
//|        in the Strategy Tester before trading live. FX edge is     |
//|        modest (PF ~1.2-1.5); size risk conservatively.            |
//| v8.10: machine-learning pass. A logistic-regression + gradient-  |
//|        boosting trade filter was trained on trade features across |
//|        all pairs and validated out-of-sample. VERDICT: a black-  |
//|        box filter did NOT generalise on the tradeable pairs (an   |
//|        apparent gain was a test-set artifact), so it was NOT      |
//|        shipped — avoiding an overfit. The one robust, inter-      |
//|        pretable finding (oversized opening ranges underperform)   |
//|        became the MaxBoxAtr filter (skip box > 4*ATR): small but  |
//|        safe lift to profit factor on FX. Honest ML > flashy ML.   |
//| v9.00: renamed ApexDrawdownZero -> Apex Drawdown Zero to reflect   |
//|        what it has become: a multi-pair, volatility-adaptive      |
//|        opening-range breakout EA. No logic change from v8.10 —    |
//|        identity/branding only (chart-object prefix ADZ_ -> ADZ_). |
//| v9.10: one-click presets. New 'Preset' input (default AUTO) auto- |
//|        loads the validated per-symbol tuning (XAUUSD/EURUSD/      |
//|        EURJPY) from the chart symbol — just drop the EA on a      |
//|        chart. A dashboard button cycles the preset live. Presets  |
//|        set risk:reward and session start (the only params that    |
//|        differ between the validated sets); all other tuned values |
//|        are the defaults. Unlisted symbols fall back to manual     |
//|        inputs with a warning. Also: brand art baked into the      |
//|        dashboard background.                                      |
//| v9.20: product name reverted to Apex Drawdown Zero (V9) for       |
//|        store branding. AUTO preset confirmed to load each pair's  |
//|        set automatically on attach; per-pair .set files shipped   |
//|        alongside for manual/store use.                            |
//+------------------------------------------------------------------+
#property copyright "Apex Drawdown Zero"
#property version   "9.20"
#resource "apex_logo.bmp"   // dashboard background art (300x254, pre-dimmed)
#property description "Apex Drawdown Zero V9 - drawdown-focused daily breakout EA for XAUUSD, EURUSD and EURJPY on H1."
#property description "One trade per day, fixed percent risk, ATR-adaptive stop, auto per-symbol presets. Demo-test before live use."

//====================================================================
//                    APEX DRAWDOWN ZERO V9 - USER GUIDE
//====================================================================
//
//  WHAT IT DOES
//    A once-per-day breakout robot. Each day it builds an opening-range
//    "box" from the first hours of the session, then trades a sweep /
//    displacement / retest out of that range. One qualified trade per
//    day, fixed percent risk, and a stop-loss on every trade.
//    No martingale, no grid, no averaging.
//
//  SUPPORTED MARKETS
//    XAUUSD (Gold), EURUSD, EURJPY   -   Timeframe: H1
//    Not recommended on indices (e.g. US30) or untested symbols.
//
//  HOW TO ATTACH  (3 steps)
//    1) Open an H1 chart of XAUUSD, EURUSD or EURJPY.
//    2) Drag the EA on and allow Algo Trading. Leave Preset = AUTO.
//    3) Check the dashboard shows "SCANNING". That's it.
//
//  PRESETS (one-click)
//    Preset = AUTO  ->  the EA detects the symbol and loads its tuned
//    settings automatically. The dashboard button cycles presets live:
//    AUTO -> XAUUSD -> EURUSD -> EURJPY -> MANUAL.
//    Ready-made .set files are also provided per pair.
//
//  KEY INPUTS
//    RiskPercent ........ risk per trade as % of balance (default 1.0)
//    MaxLots ............ hard lot cap per trade (0 = off)
//    RiskReward ......... target as a multiple of risk (set by preset)
//    UseAtrStop/AtrStopMult  volatility-based stop distance
//    FirstEntryHour/LastEntryHour  session window (BROKER/SERVER hours)
//    OneTradePerDay / StopAfterWin  discipline controls
//    UseBreakEven ....... auto move to break-even in profit
//    UsePyramid ......... optional scale-in (OFF by default)
//
//  IMPORTANT
//    - Times are broker/server hours. If your server is not GMT+2/+3,
//      shift FirstEntryHour / LastEntryHour to the London + NY window.
//    - Several no-trade days per month are normal and intentional.
//    - Always demo-test with your broker before going live. Trading
//      carries risk; past results do not guarantee future performance.
//====================================================================

#include <Trade/Trade.mqh>

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
   PRESET_MANUAL = 4         // ignore presets, use the raw inputs below
};

//--- one-click preset (auto-tunes RR + session start per symbol)
input PresetMode      Preset                   = PRESET_AUTO;

//--- core strategy
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
input double          BreakBufferAtr           = 0.20; // breakout buffer = BreakBufferAtr * ATR (0 = use points). Volatility-relative so it scales to any symbol.
input int             StopBufferPoints         = 80;    // fixed stop buffer (used when UseAtrStop = false)
input bool            UseAtrStop               = true;  // size the stop from volatility (ATR) instead of a fixed buffer
input int             AtrPeriod                = 14;
input double          AtrStopMult              = 2.5;   // stop distance = AtrStopMult * ATR(AtrPeriod)
input int             MinBoxSizePoints         = 100;   // fixed min box (used when MinBoxAtr = 0)
input double          MinBoxAtr                = 1.50;  // min box size = MinBoxAtr * ATR (0 = use points)
input double          MaxBoxAtr                = 4.00;  // skip day if box > MaxBoxAtr * ATR (0 = off). ML-derived: oversized ranges underperform.
input int             MaxSignalAgeBars         = 6;
input int             FirstEntryHour           = 8;    // no new signals/entries before this hour (skip thin Asian session)
input int             LastEntryHour            = 20;   // no new signals/entries at or after this hour
input bool            UseBiasFilter            = true; // continuation trades only with EMA bias
input bool            ApplyBiasToSweeps        = true; // sweeps also require EMA bias
input int             BiasEMAPeriod            = 50;
input int             MaxSpreadPoints          = 350;
input bool            OneTradePerDay           = true;
input bool            StopAfterWin             = true;
input int             SlippagePoints           = 30;

//--- trade management
input bool            UseBreakEven             = true;
input double          BreakEvenTriggerRR       = 0.60;  // move SL to BE at this fraction of target R
input int             BreakEvenOffsetPoints    = 30;
input bool            UseTrailing              = false; // R-trailing off: it cut winners short on gold noise
input double          TrailStartRR             = 1.00;  // start trailing at this fraction of target R
input double          TrailDistanceRR          = 0.50;  // trail this fraction of R behind price
input int             TrailStepPoints          = 50;

//--- pyramiding (scale into a winner)
input bool            UsePyramid               = false; // add a 2nd unit once in profit (aggressive; lost money out-of-sample — off by default)
input double          PyramidTriggerRR         = 0.70;  // add when trade reaches this fraction of target R (lower = more aggressive)

//--- visuals
input bool            ShowVisuals              = true;
input bool            ShowDashboard            = true;
input int             PanelX                   = 12;
input int             PanelY                   = 28;
input color           BoxColor                 = clrSteelBlue;
input color           BullColor                = clrLimeGreen;
input color           BearColor                = clrTomato;

CTrade trade;

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
bool       g_addedToday = false;
bool       g_uiEnabled = true;
int        g_emaHandle = INVALID_HANDLE;
int        g_atrHandle = INVALID_HANDLE;

//--- active preset (working values; set by ApplyPreset from Preset + symbol)
PresetMode g_presetMode = PRESET_AUTO;
double     g_riskReward = 1.5;
int        g_firstEntryHour = 8;
string     g_presetName = "MANUAL";

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
   g_addedToday = false;
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
      datetime barTime = iTime(_Symbol, BoxTimeframe, shift);
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
      high = MathMax(high, iHigh(_Symbol, BoxTimeframe, shift));
      low = MathMin(low, iLow(_Symbol, BoxTimeframe, shift));
   }

   g_boxStart = iTime(_Symbol, BoxTimeframe, firstShift);
   g_boxEnd = iTime(_Symbol, BoxTimeframe, lastShift) + PeriodSeconds(BoxTimeframe);
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
   return (body / range * 100.0) >= ConfirmBodyPercent;
}

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

bool BiasOK(bool buy)
{
   if(!UseBiasFilter || g_emaHandle == INVALID_HANDLE)
      return true;

   double ema[1];
   if(CopyBuffer(g_emaHandle, 0, 1, 1, ema) != 1)
      return true;

   double close = iClose(_Symbol, BoxTimeframe, 1);
   return buy ? close > ema[0] : close < ema[0];
}

void ExpireSignal()
{
   if(g_signal == SIGNAL_NONE)
      return;

   datetime signalClose = g_lastSignalBarTime + PeriodSeconds(BoxTimeframe);
   if(TimeCurrent() - signalClose > (long)MaxSignalAgeBars * PeriodSeconds(BoxTimeframe))
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
   if(OneTradePerDay && g_tradedToday)
      return;
   if(StopAfterWin && g_wonToday)
      return;
   if(CurrentHour() >= LastEntryHour || CurrentHour() < g_firstEntryHour)
      return;

   double atr = AtrValue();
   double boxSize = g_boxHigh - g_boxLow;
   double minBox = (MinBoxAtr > 0.0 && atr > 0.0) ? MinBoxAtr * atr
                                                  : MinBoxSizePoints * _Point;
   if(boxSize < minBox)
      return;
   // ML-informed filter: skip abnormally wide opening ranges (they underperform)
   if(MaxBoxAtr > 0.0 && atr > 0.0 && boxSize > MaxBoxAtr * atr)
      return;

   datetime barTime = iTime(_Symbol, BoxTimeframe, 1);
   if(barTime <= g_dayStart || barTime == g_lastSignalBarTime)
      return;
   if(barTime < g_boxEnd)
      return;

   double open = iOpen(_Symbol, BoxTimeframe, 1);
   double high = iHigh(_Symbol, BoxTimeframe, 1);
   double low = iLow(_Symbol, BoxTimeframe, 1);
   double close = iClose(_Symbol, BoxTimeframe, 1);
   double buffer = (BreakBufferAtr > 0.0 && atr > 0.0) ? BreakBufferAtr * atr
                                                       : BreakBufferPoints * _Point;
   double closeBack = boxSize * SweepCloseBackPercent / 100.0;
   bool strong = StrongBody(open, close, high, low);

   if(high > g_boxHigh + buffer && close < g_boxHigh - closeBack &&
      (!ApplyBiasToSweeps || BiasOK(false)))
   {
      g_signal = SIGNAL_SELL_SWEEP;
      g_signalHigh = high;
      g_signalLow = low;
      g_retestLevel = g_boxHigh;
   }
   else if(low < g_boxLow - buffer && close > g_boxLow + closeBack &&
           (!ApplyBiasToSweeps || BiasOK(true)))
   {
      g_signal = SIGNAL_BUY_SWEEP;
      g_signalHigh = high;
      g_signalLow = low;
      g_retestLevel = g_boxLow;
   }
   else if(close > g_boxHigh + buffer && strong && BiasOK(true))
   {
      g_signal = SIGNAL_BUY_CONTINUATION;
      g_signalHigh = high;
      g_signalLow = low;
      g_retestLevel = MathMax(g_boxHigh, (open + close) / 2.0);
   }
   else if(close < g_boxLow - buffer && strong && BiasOK(false))
   {
      g_signal = SIGNAL_SELL_CONTINUATION;
      g_signalHigh = high;
      g_signalLow = low;
      g_retestLevel = MathMin(g_boxLow, (open + close) / 2.0);
   }

   if(g_signal != SIGNAL_NONE)
   {
      g_lastSignalBarTime = barTime;
      Print("Apex Drawdown Zero: ", SignalText(g_signal), " at ", TimeToString(barTime),
            " retest level ", DoubleToString(g_retestLevel, _Digits));
      DrawSignal();
   }
}

//+------------------------------------------------------------------+
//| Candle-confirmation entry (ENTRY_RETEST_CANDLE)                  |
//+------------------------------------------------------------------+
bool EntryConfirmation(bool buy)
{
   datetime barTime = iTime(_Symbol, EntryTimeframe, 1);
   if(barTime == 0 || barTime == g_lastEntryBarTime)
      return false;
   if(barTime < g_lastSignalBarTime + PeriodSeconds(BoxTimeframe))
      return false;

   double open = iOpen(_Symbol, EntryTimeframe, 1);
   double high = iHigh(_Symbol, EntryTimeframe, 1);
   double low = iLow(_Symbol, EntryTimeframe, 1);
   double close = iClose(_Symbol, EntryTimeframe, 1);
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

double LotsForRisk(double entry, double stop)
{
   double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * RiskPercent / 100.0;
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
      double atr[1];
      if(CopyBuffer(g_atrHandle, 0, 1, 1, atr) == 1 && atr[0] > 0.0)
      {
         double dist = atr[0] * AtrStopMult;
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
   double sl = StopForEntry(buy, entry);

   // never send SL/TP inside the broker's stops/freeze level (avoids "invalid stops")
   double guard = GuardDistance();
   if(buy  && entry - sl < guard) sl = entry - guard;
   if(!buy && sl - entry < guard) sl = entry + guard;

   double risk = MathAbs(entry - sl);
   if(risk <= 0.0)
      return false;

   double tp = buy ? entry + risk * g_riskReward : entry - risk * g_riskReward;
   if(buy  && tp - entry < guard) tp = entry + guard;
   if(!buy && entry - tp < guard) tp = entry - guard;
   sl = NormalizeDouble(sl, _Digits);
   tp = NormalizeDouble(tp, _Digits);

   double lots = LotsForRisk(entry, sl);
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

   return buy ? trade.Buy(lots, _Symbol, entry, sl, tp, "ApexDrawdownZero buy")
              : trade.Sell(lots, _Symbol, entry, sl, tp, "ApexDrawdownZero sell");
}

bool PlaceRetestLimit(bool buy)
{
   double level = NormalizeDouble(g_retestLevel, _Digits);
   double sl = StopForEntry(buy, level);
   double risk = MathAbs(level - sl);
   if(risk <= 0.0)
      return false;

   double tp = buy ? level + risk * g_riskReward : level - risk * g_riskReward;
   double lots = LotsForRisk(level, sl);
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

   bool ok = buy ? trade.BuyLimit(lots, level, _Symbol, sl, tp, ORDER_TIME_GTC, 0, "ApexDrawdownZero buy retest")
                 : trade.SellLimit(lots, level, _Symbol, sl, tp, ORDER_TIME_GTC, 0, "ApexDrawdownZero sell retest");

   if(ok)
   {
      long signalClose = (long)g_lastSignalBarTime + PeriodSeconds(BoxTimeframe);
      long expiry = signalClose + (long)MaxSignalAgeBars * PeriodSeconds(BoxTimeframe);
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
   if(HasOpenPosition() || OwnPendingTicket() != 0)
   {
      g_signal = SIGNAL_NONE;
      return;
   }
   if((OneTradePerDay && g_tradedToday) || (StopAfterWin && g_wonToday))
   {
      g_signal = SIGNAL_NONE;
      return;
   }
   if(CurrentHour() >= LastEntryHour || CurrentHour() < g_firstEntryHour)
      return;

   int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread > MaxSpreadPoints)
      return;

   bool buy = (g_signal == SIGNAL_BUY_SWEEP || g_signal == SIGNAL_BUY_CONTINUATION);

   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(SlippagePoints);

   bool done = false;

   switch(EntryStyle)
   {
      case ENTRY_IMMEDIATE:
         done = MarketEnter(buy);
         if(done)
            g_tradedToday = true;
         break;

      case ENTRY_RETEST_LIMIT:
         done = PlaceRetestLimit(buy);
         break;

      case ENTRY_RETEST_CANDLE:
         if(!EntryConfirmation(buy))
            return;
         done = MarketEnter(buy);
         if(done)
         {
            g_tradedToday = true;
            g_lastEntryBarTime = iTime(_Symbol, EntryTimeframe, 1);
         }
         break;
   }

   if(done)
      g_signal = SIGNAL_NONE;
}

//+------------------------------------------------------------------+
//| Break-even + trailing stop                                       |
//| Initial risk is recovered from the fixed TP: risk = |TP-entry|/RR|
//+------------------------------------------------------------------+
void ManagePosition()
{
   if(!UseBreakEven && !UseTrailing)
      return;

   // once a pyramid add-on is live, both legs carry fixed stops (original
   // locked at break-even, add-on at its own stop) — leave them untouched
   // so this single-ticket manager doesn't fight the two-leg arrangement
   if(UsePyramid && g_addedToday)
      return;

   ulong ticket = OwnPositionTicket();
   if(ticket == 0 || !PositionSelectByTicket(ticket))
      return;

   long type = PositionGetInteger(POSITION_TYPE);
   bool isBuy = (type == POSITION_TYPE_BUY);
   double entry = PositionGetDouble(POSITION_PRICE_OPEN);
   double sl = PositionGetDouble(POSITION_SL);
   double tp = PositionGetDouble(POSITION_TP);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double price = isBuy ? bid : ask;

   double initRisk = (tp > 0.0 && g_riskReward > 0.0) ? MathAbs(tp - entry) / g_riskReward
                                                    : MathAbs(entry - sl);
   if(initRisk <= 0.0)
      return;

   double profitDist = isBuy ? price - entry : entry - price;
   double newSl = sl;

   if(UseBreakEven && profitDist >= BreakEvenTriggerRR * initRisk)
   {
      double be = isBuy ? entry + BreakEvenOffsetPoints * _Point
                        : entry - BreakEvenOffsetPoints * _Point;
      if(sl == 0.0 || (isBuy ? be > newSl : be < newSl))
         newSl = be;
   }

   if(UseTrailing && profitDist >= TrailStartRR * initRisk)
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

   double guard = GuardDistance();

   // freeze guard: modification is rejected while the existing SL/TP
   // sits within the freeze/stops distance of the market
   if(tp > 0.0 && MathAbs(price - tp) <= guard)
      return;
   if(sl != 0.0 && MathAbs(price - sl) <= guard)
      return;

   // the new SL must also respect the minimum distance
   if(isBuy && bid - newSl <= guard)
      return;
   if(!isBuy && newSl - ask <= guard)
      return;

   trade.PositionModify(ticket, NormalizeDouble(newSl, _Digits), tp);
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

   double lots = LotsForRisk(addEntry, addSl);
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
      ? trade.Buy(lots, _Symbol, addEntry, NormalizeDouble(addSl, _Digits), tp, "ApexDrawdownZero pyramid")
      : trade.Sell(lots, _Symbol, addEntry, NormalizeDouble(addSl, _Digits), tp, "ApexDrawdownZero pyramid");
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
//| Daily result tracking                                            |
//+------------------------------------------------------------------+
void UpdateClosedDeals()
{
   static int lastDealCount = -1;

   if(!HistorySelect(g_dayStart, TimeCurrent() + 60))
      return;

   int total = HistoryDealsTotal();
   if(total == lastDealCount)
      return;
   lastDealCount = total;

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
      if(profit > 0.0)
         g_wonToday = true;
   }
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
   ObjectSetString(0, label, OBJPROP_TEXT, SignalText(g_signal));
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
//| Dashboard                                                        |
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
   if(!g_boxReady)                     { clr = clrSilver;   return "BUILDING BOX"; }
   if(HasOpenPosition())               { clr = clrGold;     return "IN TRADE"; }
   if(OwnPendingTicket() != 0)         { clr = clrDeepSkyBlue; return "ORDER PENDING"; }
   if(StopAfterWin && g_wonToday)      { clr = BullColor;   return "DONE (won today)"; }
   if(OneTradePerDay && g_tradedToday) { clr = clrSilver;   return "DONE (traded today)"; }
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

   PanelBackground(x - 6, y - 6, 300, 15 * rowH + 16);

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

   PanelLabel("title", x, y, "APEX DRAWDOWN ZERO V9", clrGold, 10);
   y += rowH + 3;

   color stateClr = dim;
   string state = StateText(stateClr);
   PanelLabel("state", x, y, "State  " + state, stateClr, 10);
   y += rowH;

   PanelLabel("mode", x, y, StringFormat("Mode   %s  bias:%s", EntryStyleText(),
              UseBiasFilter ? "EMA" + IntegerToString(BiasEMAPeriod) : "off"), dim);
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
   PanelLabel("signal", x, y, "Signal " + SignalText(g_signal), sigClr);
   y += rowH;

   string retest = (g_signal == SIGNAL_NONE)
      ? "Retest --"
      : StringFormat("Retest %s  (zone +/-%d%%)",
                     DoubleToString(g_retestLevel, _Digits), RetestTolerancePercent);
   PanelLabel("retest", x, y, retest, sigClr);
   y += rowH;

   string age = "Age    --";
   if(g_signal != SIGNAL_NONE)
   {
      int bars = (int)((TimeCurrent() - g_lastSignalBarTime) / PeriodSeconds(BoxTimeframe));
      age = StringFormat("Age    %d / %d bars", bars, MaxSignalAgeBars);
   }
   PanelLabel("age", x, y, age, dim);
   y += rowH;

   int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   PanelLabel("spread", x, y, StringFormat("Spread %d / %d pts", spread, MaxSpreadPoints),
              spread > MaxSpreadPoints ? BearColor : dim);
   y += rowH;

   PanelLabel("today", x, y, StringFormat("Today  traded:%s  won:%s  pyr:%s",
              g_tradedToday ? "Y" : "N", g_wonToday ? "Y" : "N",
              !UsePyramid ? "off" : (g_addedToday ? "ADDED" : "arm")), dim);
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

      PanelLabel("pos", x, y, StringFormat("Pos    %s %s @ %s",
                 isBuy ? "BUY" : "SELL", DoubleToString(lots, VolumeDigits()),
                 DoubleToString(entry, _Digits)), posClr);
      y += rowH;
      PanelLabel("levels", x, y, StringFormat("SL/TP  %s / %s",
                 DoubleToString(sl, _Digits), DoubleToString(tp, _Digits)), dim);
      y += rowH;
      PanelLabel("pl", x, y, StringFormat("P/L    %.2f %s", pl,
                 AccountInfoString(ACCOUNT_CURRENCY)), pl >= 0.0 ? BullColor : BearColor);
      y += rowH;

      bool locked = (sl != 0.0) && (isBuy ? sl >= entry : sl <= entry);
      string trailState = locked ? "LOCKED (BE/trailing)"
                                 : (UseBreakEven || UseTrailing ? "armed" : "off");
      PanelLabel("trail", x, y, "Trail  " + trailState, locked ? BullColor : dim);
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
      PanelLabel("trail", x, y, "Trail  waiting for fill", dim);
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
      PanelLabel("trail", x, y, "Trail  " +
                 (UseBreakEven || UseTrailing ? string("armed") : string("off")), dim);
      y += rowH;
   }

   PanelLabel("acct", x, y, StringFormat("Bal    %.2f   Eq %.2f",
              AccountInfoDouble(ACCOUNT_BALANCE), AccountInfoDouble(ACCOUNT_EQUITY)), bright);
   y += rowH;

   // one-click preset selector: click to cycle AUTO -> XAU -> EUR/USD -> EUR/JPY -> MANUAL
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
//| Preset resolution                                                |
//| Auto-tunes the two parameters that differ between the validated  |
//| per-symbol sets (risk:reward and session start). All other tuned |
//| values are identical across presets and come from the (default)  |
//| inputs. PRESET_AUTO picks the set from the chart symbol.          |
//+------------------------------------------------------------------+
void ApplyPreset()
{
   PresetMode m = g_presetMode;
   if(m == PRESET_AUTO)
   {
      string s = _Symbol;
      if(StringFind(s, "XAU") >= 0 || StringFind(s, "GOLD") >= 0) m = PRESET_XAUUSD;
      else if(StringFind(s, "EURJPY") >= 0)                       m = PRESET_EURJPY;
      else if(StringFind(s, "EURUSD") >= 0)                       m = PRESET_EURUSD;
      else                                                        m = PRESET_MANUAL;
   }

   switch(m)
   {
      case PRESET_XAUUSD: g_riskReward = 2.0; g_firstEntryHour = 8;  g_presetName = "XAUUSD"; break;
      case PRESET_EURUSD: g_riskReward = 1.5; g_firstEntryHour = 8;  g_presetName = "EURUSD"; break;
      case PRESET_EURJPY: g_riskReward = 1.5; g_firstEntryHour = 12; g_presetName = "EURJPY"; break;
      default:            g_riskReward = RiskReward; g_firstEntryHour = FirstEntryHour; g_presetName = "MANUAL"; break;
   }

   if(g_presetMode == PRESET_AUTO)
      g_presetName += " (auto)";

   // status to the journal (live only; keep the Strategy Tester journal clean)
   if(!MQLInfoInteger(MQL_TESTER))
   {
      if(g_presetMode == PRESET_AUTO && m == PRESET_MANUAL)
         Print("Apex Drawdown Zero: '", _Symbol, "' is not in the validated set ",
               "(XAUUSD/EURUSD/EURJPY) - using manual inputs. Indices such as US30 ",
               "are not recommended for this strategy.");
      Print("Apex Drawdown Zero: preset ", g_presetName, "  RR=", DoubleToString(g_riskReward,2),
            "  firstEntryHour=", g_firstEntryHour);
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

   if(UseBiasFilter)
   {
      g_emaHandle = iMA(_Symbol, BoxTimeframe, BiasEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
      if(g_emaHandle == INVALID_HANDLE)
         Print("Apex Drawdown Zero: EMA handle failed, bias filter disabled");
   }

   // ATR drives the volatility-adaptive stop AND the volatility-relative
   // breakout buffer / min-box filter, so build it whenever any of those use it
   if(UseAtrStop || BreakBufferAtr > 0.0 || MinBoxAtr > 0.0)
   {
      g_atrHandle = iATR(_Symbol, BoxTimeframe, AtrPeriod);
      if(g_atrHandle == INVALID_HANDLE)
         Print("Apex Drawdown Zero: ATR handle failed, falling back to fixed point buffers");
   }

   IsNewDay();
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_emaHandle != INVALID_HANDLE)
      IndicatorRelease(g_emaHandle);
   if(g_atrHandle != INVALID_HANDLE)
      IndicatorRelease(g_atrHandle);
   ObjectsDeleteAll(0, "ADZ_");
   ChartRedraw();
}

void OnTick()
{
   if(IsNewDay())
      CancelPending("new trading day");

   UpdateClosedDeals();
   ManagePendingExpiry();

   if(!g_tradedToday && HasOpenPosition())
      g_tradedToday = true;

   ManagePosition();
   ManagePyramid();

   if(BuildDailyBox())
   {
      DrawDailyBox();
      ExpireSignal();
      DetectSignal();
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

   g_presetMode = (PresetMode)(((int)g_presetMode + 1) % 5);   // AUTO->XAU->EURUSD->EURJPY->MANUAL->AUTO
   ApplyPreset();

   ObjectSetInteger(0, "ADZ_UI_preset", OBJPROP_STATE, false);
   if(g_uiEnabled && ShowDashboard)
   {
      UpdateDashboard();
      ChartRedraw();
   }
}
