# ADR-0001: Evidence before recommendations

Status: accepted

## Context

Cloud and Kubernetes ecosystems already contain recommendation and automation systems. Competing on another p95/p99 rightsizing formula would place this project in a crowded feature category and would not solve the harder question of whether a change produced attributable economic value.

## Decision

Optimization Evidence will not generate recommendations in the MVP. It will ingest or register optimization changes and classify their outcomes from independent evidence.

## Consequences

Positive: the product can verify outcomes from native cloud recommendations, third-party optimizers, GitOps, or human changes rather than competing with each source.

Negative: value depends on difficult identity correlation and delayed billing evidence. The system must handle `INCONCLUSIVE` honestly.
