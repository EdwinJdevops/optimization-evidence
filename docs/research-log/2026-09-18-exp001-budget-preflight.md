# 2026-09-18 EXP-001 budget preflight stop

## Summary

The corrected EXP-001 infrastructure reached `CREATE_COMPLETE` with two healthy `c7i-flex.large` workers, the expected managed-node-group Auto Scaling Group, required Cluster Autoscaler discovery tags, CodeBuild runner, Pod Identity association, and no NAT Gateway.

Before baseline, the runbook budget stop condition was evaluated. AWS Budgets reported account-wide monthly gross actual spend of **USD 52.851** against the original **USD 20** ceiling. The budget had no cost filters, so the value could not be attributed to EXP-001.

No baseline, Arm A, or Arm B CodeBuild phase was started.

## Action

The lab stack was immediately deleted. This preserved the stop condition instead of moving the budget while paid experiment infrastructure remained alive.

After deletion began, the account-wide ceiling was rebased to **USD 70**. From the observed USD 52.851 baseline, that leaves approximately **USD 17.149** of gross-spend headroom. Notification thresholds were changed to 80%, 90%, and 100% and verified OK.

## Corrected guardrail semantics

The AWS Budget is a gross account-safety signal only. It is not a measurement of EXP-001 cost and it is not a hard cap.

Before baseline and before each later phase:

1. budget health must be `HEALTHY`;
2. calculated actual spend must be below the ceiling;
3. remaining gross-spend headroom must be at least USD 5.00.

If any condition fails, stop and tear down.

Actual EXP-001 financial attribution remains dependent on CUR 2.0 resource-level records, experiment timestamps, and the product attribution rules.

## Claim boundary

This event is an operational preflight stop. It establishes no optimization outcome, no capacity realization, and no realized savings.
