# 2026-10-11 EXP-001 Arm A availability-gate failure

## What happened

The first phase-scoped Arm A run applied the optimized resource requests while Cluster Autoscaler remained absent.

The workload rollout completed, two worker nodes remained Ready, and the managed node group remained at desired capacity 2. The phase-scoped synthetic probe window recorded 193 successful probes and one failed probe.

The failure was a two-second HTTP timeout during the rollout transition. Successful probes were observed immediately before and after it.

Because the authoritative Arm A contract required zero failed probes in the phase window, the runner failed the phase and uploaded a complete failure snapshot. The run is not classified as operationally verified.

## Why the gate is not being weakened

The failure is not being ignored, averaged away, or converted into a passing result. A request-sizing optimization that creates avoidable request failures during rollout is not operationally neutral.

Instead, the delivery scaffolding is being corrected symmetrically in both baseline and optimized workload definitions:

- require a pod to remain Ready for 5 seconds before Deployment progress treats it as available;
- keep a terminating Nginx pod serving for a 10-second pre-stop drain interval;
- retain a 30-second termination grace period.

The resource-request difference remains the economic variable: baseline requests remain 700m CPU / 512Mi memory and optimized requests remain 300m CPU / 256Mi memory. The rollout-drain controls are identical in both manifests.

## Rerun rule

The authoritative sequence restarts at baseline after this change. Arm A is not retried directly from the failed optimized state.

Baseline must again prove two Ready workers, four healthy replicas distributed across both workers, and a clean phase-scoped availability window before Arm A is attempted.

## Claim boundary

This Arm A attempt failed the operational safety gate. It proves neither NO_CASH_SAVING nor CAPACITY_REALIZED and is retained as failure evidence rather than overwritten.
