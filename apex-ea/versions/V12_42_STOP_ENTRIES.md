# V12.42 — stop-order entries ("side shot")

Source: `ApexDZ_V12_42.mq5`. Built on V12.41.

## What it adds
- `EntryStyle = ENTRY_BREAK_STOP` (3) for the core: a buy-stop
  `StopEntryBufferAtr` (0.05 ATR) above the signal bar's high (sell-stop below
  its low). Stop and target measured from the order price. Cancelled after
  `StopEntryExpiryBars` (3) bars unfilled. If price is already through the
  level, it enters at market.
- `LaneStopEntry = true` does the same for the trend-pullback lane, keeping
  the lane's structural stop.
- Lane resting orders now share one expiry/firewall manager (the sniper's was
  generalised).

Defaults are off: with them off it behaves exactly like V12.41.

## Test
Real ticks, phase 1, 12 starts — see `VERSIONS.md` for the result.

## Result — real ticks, phase 1 (+10%), 12 starts 2025-01 … 2026-08

| | pass | fail | median | worst day | lowest equity |
|---|---:|---:|---:|---:|---:|
| **V12.41 market entries** | 11/12 | 0 | **53 d** | **−3.14%** | **95.8%** |
| V12.42 stop entries | 12/12 | 0 | 72 d | **−4.81%** | 92.7% |

**REJECTED.** V12.41's one non-pass is the 2026-08 start, still open (no
breach) when the data ended — not a failure. Stop entries were 19 days slower
and, on real ticks, filled with slippage: one day reached −4.81%, 0.19% from
FTMO's 5% daily limit, through the EA's own 4% day floor. That risk is
invisible on 1-minute bars.
