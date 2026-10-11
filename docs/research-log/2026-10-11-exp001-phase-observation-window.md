# 2026-10-11 EXP-001 phase-scoped availability evidence

## Observation

The first successful replacement-account baseline produced one failed synthetic probe at workload startup followed by continuous successful probes. The failure happened before the service became ready and did not occur during the stable baseline interval.

The existing evidence collector counted the entire lifetime of the load-generator pod. Because that pod can survive across experiment phases, a cumulative failure count cannot be attributed cleanly to baseline, Arm A, or Arm B.

## Correction

Each experiment phase now establishes an explicit UTC observation-window start time.

Evidence collection preserves both:

- the full load-generator log; and
- a phase-scoped log beginning at the observation-window timestamp.

The runner fails a phase unless the phase window contains at least 60 successful probes and zero failed probes.

Baseline starts its observation window only after the four replicas are Ready and distributed across both workers.

Arm A starts its observation window before applying the optimized request change, so the rollout transition is included.

Arm B starts its observation window before enabling Cluster Autoscaler, so the scale-down transition and post-scale-down stabilization are included.

## Why this matters

Availability evidence must be attributable to the same phase as the capacity evidence. Cumulative logs from earlier phases would allow an old failure or success to contaminate a later outcome.

## Claim boundary

The earlier successful baseline remains useful infrastructure and scheduling evidence, but it is not the authoritative availability baseline for final attribution. Baseline will be rerun with phase-scoped availability evidence before Arm A.
