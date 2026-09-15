# Optimization Evidence

Optimization Evidence is an engineering research project for proving whether infrastructure optimization changes are both operationally safe and financially realized.

The core problem is not recommendation generation. Existing platforms can recommend rightsizing, scaling, or cleanup actions. The harder problem is causality: after an optimization is applied, can we prove which runtime capacity changed, whether service health remained acceptable, whether billable infrastructure actually disappeared, and whether the resulting billing change is attributable to that optimization rather than traffic, pricing, commitments, or unrelated changes?

## Product thesis

An optimization is not a realized saving because a request value changed or a recommendation was accepted. `REALIZED` requires operational evidence, capacity evidence, billing evidence, and an attribution decision.

The first validation target is AWS/EKS. The domain model is intentionally provider-neutral so later adapters can cover other cloud services, databases, GPU infrastructure, and other technology-spend surfaces.

## Non-goals

This repository is not another Kubernetes rightsizer, cost-allocation dashboard, autoscaler, or autonomous remediation engine. The first release does not compete on recommendation quality. It consumes optimization events and proves outcomes.

## Current phase

- AWS CUR 2.0 hourly resource-level evidence export: deployed and healthy.
- Account spend guardrail for EXP-001: USD 20 monthly gross-cost budget.
- Existing unrelated EKS lab: decommissioning to eliminate idle control-plane/NAT cost.
- EXP-001: defined, not yet executed.

See `docs/problem.md`, `docs/architecture.md`, `docs/invariants.md`, and `docs/experiments/EXP-001.md` before changing product behavior.
