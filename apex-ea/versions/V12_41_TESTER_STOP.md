# V12.41 — tester auto-stop

Source: `ApexDZ_V12_41.mq5`. Infrastructure only — **no trading change**.

In the Strategy Tester, FTMO mode calls `TesterStop()` once the challenge is
decided: target locked + minimum days met + book flat (PASSED), or the static
floor hit (STOPPED AT FLOOR). A real-tick challenge then costs ~5–8 minutes
instead of simulating to the end of the data.

Real-tick probe (every tick based on real ticks), phase 1 from 2025-01-01:
**PASS in 78 days**, 18.3M ticks, worst day −2.45%, lowest equity 95.8%.
(1-minute OHLC gave the same start a pass in 49 days — real ticks are slower
to the target, which is why every version from here is judged on real ticks.)
