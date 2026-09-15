# Architecture

Status: proposed MVP architecture. Only the domain state machine and AWS billing evidence foundation are currently implemented.

## Architectural center

The primary aggregate is `OptimizationExperiment`, not `Recommendation`.

An experiment links a change to operational, capacity, billing, and attribution evidence. Core types remain provider-neutral:

- `Subject`: the thing being optimized;
- `ChangeSet`: the exact intended/applied change;
- `OperationalEvidence`: health and SLI observations;
- `CapacityEffect`: changes in schedulable or billable capacity;
- `CostEvidence`: immutable provider billing records;
- `Attribution`: the deterministic explanation connecting evidence to an outcome;
- `Outcome`: terminal classification.

## State machine

```text
OBSERVED
  -> MODELED
  -> APPROVED
  -> APPLIED
  -> OPERATIONALLY_VERIFIED
       -> NO_CASH_SAVING
       -> CAPACITY_REALIZED
            -> BILL_OBSERVED
                 -> ATTRIBUTION_VERIFIED
                      -> REALIZED
```

Any stage may terminate in `INCONCLUSIVE` where evidence is insufficient. Applied changes may terminate in `UNSAFE`/`ROLLED_BACK`; billing correlation may terminate in `ATTRIBUTION_FAILED`.

## MVP process boundary

Start as a modular monolith. One process owns the deterministic state machine, evidence normalization, and attribution rules. External systems are adapters, not separate services.

Initial adapters:

- Git/GitHub provenance for exact change identity;
- Kubernetes/EKS runtime identity and capacity observations;
- Prometheus-compatible operational metrics;
- EC2/Auto Scaling observations for billable node lifecycle;
- AWS CUR 2.0 for billing evidence.

Raw evidence should be append-only. Derived facts are versioned and reproducible from raw evidence plus rule version.

## Storage

Planned production shape:

- PostgreSQL: experiment state, identities, normalized facts, attribution decisions;
- object storage: immutable raw evidence payloads and CUR partitions;
- CUR 2.0 remains the authoritative AWS billing source for EXP-001.

Do not add Kafka, Temporal, ClickHouse, or additional services until measured workload characteristics justify them.

## Trust boundary

The MVP is read-heavy and does not autonomously optimize production. Optimization actions originate from GitOps, a human operator, or another optimizer. The lab harness may execute controlled mutations only against explicitly tagged experiment resources.

This separation is intentional: the product must first prove that it can classify outcomes correctly before earning mutation authority.
