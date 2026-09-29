# V12.46 — final: FTMO mode tuned + Cavalry dashboard

Source: `ApexDZ_V12_46.mq5`, merged into `../ApexDrawdownZero_V12.mq5`.
= V12.45 (dashboard) with `FTMORoomDivisor` default 2.5 and `FTMORiskPercent`
ceiling 2.0.

Verified on the merged main file:
- DISCIPLINE XAUUSD 4 336.43 / 4 409.56, GROWTH 19 105.76 — unchanged.
- FTMO mode, defaults, 1-min: 2025-01 pass 47 d, 2025-03 22 d, 2025-08 174 d
  — identical to the divisor-2.5 screen.

Presets: `../presets/ApexV12_FTMO_Mode_Phase1.set`, `_Phase2.set`,
`_Phase1_Safe.set` (divisor 3).
