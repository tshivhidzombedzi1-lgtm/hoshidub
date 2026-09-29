# Apex Drawdown Zero — FTMO iteration log

Every version is its own source file here. A version is kept only if it beats
the one before it on the same test. Screening: 1-minute OHLC, 21 month starts.
Confirmation: **real ticks**, 12 starts (2025-01, 03, 05, 07, 09, 11, 2026-01,
03, 05, 06, 07, 08), phase 1 (+10%). Scored against FTMO rules by
`../backtests/ftmo_sim.py`-style replay of the EA's daily equity log.

| version | change | real-tick P1 result | verdict |
|---|---|---|---|
| V12.40 | FTMO mode: target lock, static floors, room sizing, min days | (1-min: 20/21, 0 fail, 48 d) | base |
| V12.41 | tester auto-stop (no trading change) | **11/12, 0 fail, 53 d, worst day −3.14%** | superseded by V12.43 |
| V12.42 | stop-order entries (core + trend lane) | 12/12, 0 fail, 72 d, worst day **−4.81%** | rejected |
| V12.43 | target-lock bug fix (closed balance must clear target) | 1-min: 20/21, 0 fail, 48 d | kept |
| V12.44 d2 | risk up to half the room, 2% | 1-min: 18/21, 2 halted at floor, 22 d, worst day −4.55% | rejected |
| V12.44 d2.5 | risk up to room / 2.5 | **12/12, 0 fail, 38 d, worst day −4.06%** (1-min 20/21, 38 d) | **kept** |
| V12.45 | Templar Cavalry dashboard (presentation only) | — | kept |
| V12.46 | final: divisor 2.5 default + dashboard, merged into main file | parity verified | superseded by V12.47 |
| V12.47 | buyer-facing labels, grouped inputs, experimental inputs hidden, icon, description | parity 4 336.43 / 4 409.56, FTMO 2025-03 pass 22 d (identical) | **SHIPPED** (client zip) |
