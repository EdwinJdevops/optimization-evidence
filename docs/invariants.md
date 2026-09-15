# System invariants

These rules are product behavior, not documentation preferences.

1. `REALIZED` is unreachable without `ATTRIBUTION_VERIFIED`.
2. `ATTRIBUTION_VERIFIED` is unreachable without provider billing evidence for the relevant observation window.
3. Kubernetes request or limit reduction is never sufficient evidence of cash savings.
4. Released schedulable capacity is not equivalent to removed billable capacity.
5. A lower bill without a causal link to the experiment is not attributable savings.
6. Operational regressions prevent successful realization classification even if the bill falls.
7. Missing, stale, or contradictory evidence produces a non-success terminal state; it must not be silently imputed.
8. Raw evidence is immutable and timestamped. Derived values record source IDs and calculation/rule version.
9. External identity joins must be explicit. Name similarity is not sufficient to join a workload to a resource or billing line item.
10. Terminal outcomes are immutable. Re-analysis creates a new decision version rather than rewriting historical truth.
11. Lab resources must have deterministic cleanup and project/experiment tags.
12. Gross experimental spend is tracked independently of promotional credits so credits cannot mask uncontrolled consumption.
