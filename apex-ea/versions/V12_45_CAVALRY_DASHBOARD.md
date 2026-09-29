# V12.45 — Templar Cavalry dashboard

Source: `ApexDZ_V12_45.mq5`. Built on V12.44. **Presentation only** — no
entry, sizing or exit logic changed.

The dashboard design of the APEX Templar Cavalry package, carried over:
knight artwork background (`Assets/cavalry_background.bmp`), badge header
(`Assets/cavalry_badge.bmp`), gold-on-ink panels, Segoe UI, MIN / SHOW button,
1-second timer refresh, repaint throttled to 2/sec.

Panels, filled with this EA's state:
- header — APEX / Drawdown Zero V12
- status — symbol / H1 / trading mode; tester/offline/monitoring, or the
  firewall halt reason (target lock in gold)
- open P/L across all lanes, positions / lanes, lots
- balance and equity
- engines — 01 opening range, 02 trend pullback (with today's count),
  03 FTMO guard (floor / day floor / target) or the risk firewall in other modes
- footer — spread, effective risk per trade, closed-trade stats, server clock

The old preset-cycle button was dropped (the `Preset` input still works).
Assets folder copied with the artwork notes, icon and source PNGs.
Mock-up rendered from the real artwork: `V12_45_Dashboard_Mockup.png`.
