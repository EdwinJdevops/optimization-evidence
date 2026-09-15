# AGENTS.md

## Mission

Build a system that can defend every optimization outcome with evidence. Correctness is more important than feature count, UI polish, or optimistic savings claims.

## Engineering rules

1. Never label modeled, recommended, allocated, or released capacity as `REALIZED` savings.
2. Every state transition must be explicit, validated, and testable.
3. Contradictory or incomplete evidence yields `INCONCLUSIVE`, `NO_CASH_SAVING`, or `ATTRIBUTION_FAILED`; never infer success to make a demo look better.
4. Raw external evidence is immutable. Derived facts must retain provenance to the source evidence and calculation version.
5. Core domain types must not encode AWS-, EKS-, or Kubernetes-specific assumptions unless they are inside adapters.
6. The product does not mutate production infrastructure in the MVP. Controlled lab mutations belong to experiment harnesses or external systems such as GitOps.
7. No destructive AWS operation outside resources explicitly tagged for this project or explicitly authorized for cleanup.
8. Every AWS experiment must have a spend guardrail, deterministic teardown, and resource tags: `Project=optimization-evidence`, `Experiment=<id>`, `Environment=research`.
9. No LLM is allowed in the evidence decision path. An LLM may summarize evidence only after deterministic outcome classification exists.
10. Do not add distributed systems components until one-process architecture has a measured bottleneck requiring them.

## Toolchain

- Python 3.13
- pytest
- ruff
- mypy
- CloudFormation for AWS account-level/billing foundation
- Kubernetes manifests/Helm only when EXP-001 requires them

## Required gates

Before merging behavior changes:

- `ruff check .`
- `mypy src`
- `pytest -q`
- state-machine tests for every added transition
- explicit documentation for any changed invariant

## Evidence standard

Claims in README/docs must be one of: verified observation, documented assumption, hypothesis, or proposed target. Never write proposed architecture as if it is already implemented.
