# V12.40 — FTMO mode

Source: `ApexDZ_V12_40.mq5` (identical to `../ApexDrawdownZero_V12.mq5`).

## What it adds
`TradingMode = MODE_FTMO` (3):
- **Target lock** — closes the book and stops at the phase target
  (`FTMOPhaseTargetPercent`: 10 phase 1, 5 phase 2, 0 funded).
- **FTMO's own floors** — static max loss under the *initial* balance and the
  daily floor (day-start balance − 5% of initial). Halts `FTMOSafetyBufferPercent`
  (1%) before either. Replaces the EA's trailing-peak drawdown cap.
- **Room-based sizing** — risk per trade ≤ one third of the room left above the
  nearer floor, capped at `FTMORiskPercent` (1.5%).
- **Minimum trading days** — after the target, one min-lot open/close per day
  until `FTMOMinTradingDays` (4) is met.

## Test — 1-minute OHLC, 21 month starts (2025-01 … 2026-09), each a real run
| Phase 1 (+10%) | pass | fail | median | worst day | lowest equity |
|---|---:|---:|---:|---:|---:|
| plain 1% preset | 19/21 | 0 | 62 d | −2.59% | 93.7% |
| plain 1.5% preset | 20/21 | 0 | 44 d | −4.08% | **90.4%** |
| **MODE_FTMO** | **20/21** | **0** | 48 d | **−3.41%** | **92.2%** |

| Phase 2 (+5%) | pass | fail | median |
|---|---:|---:|---:|
| plain 1.5% preset | 20/21 | 0 | 20 d |
| **MODE_FTMO** | **20/21** | **0** | 19 d |

The one non-pass in each is the September 2026 start (21 days old, still open).
Same pass rate as the plain 1.5% preset with a wider safety margin: the plain
preset came within 0.4% of FTMO's 10% floor.
DISCIPLINE parity: 4 336.43 / 4 409.56 — other modes unchanged.
