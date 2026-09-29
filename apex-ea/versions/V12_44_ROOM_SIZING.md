# V12.44 — adjustable room sizing

Source: `ApexDZ_V12_44.mq5`. Built on V12.43.

New input `FTMORoomDivisor` (default 3 = V12.43 behaviour): a trade risks at
most (room to the nearer FTMO floor) / divisor. At 2, two lanes stopping out
together on the same day land exactly on the EA's own day floor (4%), still
1% inside FTMO's 5%. Candidate tested: divisor 2, `FTMORiskPercent` 2.0.

## Result — divisor 2, risk 2.0 (1-minute OHLC, phase 1, 21 starts)
18/21 passed, 0 FTMO failures, **median 22 d** (V12.43: 48 d) — but **2
starts (2025-08, 2026-02) hit the EA's 91% safety floor and halted**, and the
worst day was −4.55%, 0.45% from FTMO's limit before real-tick slippage.
Too close. **Rejected at divisor 2**; divisor 2.5 tested next.

## Result — divisor 2.5, risk 2.0 (1-minute OHLC, phase 1, 21 starts)
20/21 passed, 0 failures, 0 halts, **median 38 d** (V12.43: 48 d), mean 50 d
(55 d). Worst day −4.22%, lowest equity 91.3% — 0.3% above the EA's 91% floor.
Slow starts got slower (2025-08: 174 d vs 132 d). Promising but thin margins
→ real-tick confirmation required (12 starts).

## Result — divisor 2.5, REAL TICKS, phase 1, 12 starts
| | pass | fail | median | mean | worst day | lowest eq |
|---|---:|---:|---:|---:|---:|---:|
| V12.43 (divisor 3) | 11/12 (last still open) | 0 | 53 d | 54 d | −3.14% | 95.8% |
| **divisor 2.5** | **12/12** | **0** | **38 d** | **40 d** | −4.06% | 95.0% |

Every start passed as fast or faster. The worst day stopped at the EA's own 4%
day floor (−4.06% after slippage), 0.94% inside FTMO's 5%. **KEPT — divisor
2.5 becomes the default in V12.46.**
