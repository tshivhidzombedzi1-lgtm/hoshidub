# V12.43 — target-lock bug fix

Source: `ApexDZ_V12_43.mq5`. Built on V12.41.

## The bug (found in the V12.41 risk screen)
The phase target locks on **equity** (+10.1%). Closing the positions then pays
commission, which equity did not include. On the 2025-08 start the book closed
at a balance of **10 986.39 against a 11 000 target** — FTMO counts the closed
balance, so that is *not* a pass — but the EA considered itself done and
stopped trading permanently. Live, it would have sat at +9.9% forever.

## The fix
- After the lock, once flat, if the balance is short of the target the lock is
  **released** and the EA keeps trading.
- The tester only records PASSED when the closed balance clears the target.

## Also found
`EffectiveRiskPct` caps each trade at one third of the room above the daily
floor (4% → ~1.33%), so `FTMORiskPercent` above ~1.33 changes nothing: the
1.75% and 2% screens were identical to 1.5% start for start. See V12.44.

## Result — 1-minute OHLC, phase 1, 21 starts
| | pass | fail | halted | median | worst day | lowest eq |
|---|---:|---:|---:|---:|---:|---:|
| V12.41 | 19/21 | 0 | 0 | 47 d | −3.41% | 92.3% |
| **V12.43** | **20/21** | **0** | **0** | 48 d | −3.41% | 92.2% |

The 2025-08 start that V12.41 wrongly stopped at +9.9% now trades on and
passes (day 132). **KEPT — current best.** (Remaining non-pass: 2026-09 start,
21 days old.)
