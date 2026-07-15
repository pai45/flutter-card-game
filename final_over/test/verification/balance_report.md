# Deterministic MVP balance report

Command:

```text
dart run tool/simulate_matches.dart --matches=10000
```

Configuration: target 14, seeds 1 through 10,000, fixed 16,667 microsecond
simulation steps. The competent bot selects the highest documented shot
compatibility, follows the 20/50/22/6/2 timing distribution, runs on SAFE,
runs on CLOSE only under late-match pressure, and never runs on DANGER.

| Gate | Measured | Required | Result |
| --- | ---: | ---: | --- |
| Win rate | 48.27% | 35–65% | Pass |
| Boundary per contact | 36.69% | 18–38% | Pass |
| Wicket per legal ball | 9.53% | 7–18% | Pass |
| Wide per physical ball | 3.65% | 2–8% | Pass |
| No-ball per physical ball | 1.49% | 0.5–4% | Pass |
| Maximum duration | 61.98 s | Below 120 s | Pass |
| DANGER runs started | 0 | 0 | Pass |

Additional observations: average match duration was 38.28 seconds, average
score was 12.06, 60.81% of legal balls scored, 16,396 running runs completed,
and the deterministic report fingerprint was `2965a4490f7cd755`.
