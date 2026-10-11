# 2026-10-11 EXP-001 namespace preflight failure

## What failed

After the CodeBuild shell correction, the replacement-account baseline runner advanced through installation, exact Git checkout, AWS Budget preflight, EKS authentication, and server-side manifest validation.

The server-side dry-run then rejected the namespaced EXP-001 workload objects because the `optimization-evidence` namespace did not exist yet.

Representative API error:

`namespaces "optimization-evidence" not found`

## Scope

The failure occurred during manifest preflight. The baseline application was not applied, Arm A and Arm B did not run, and no optimization outcome was produced.

The runner's exit trap succeeded and uploaded the failure snapshot to the retained evidence bucket. The snapshot includes node, EC2, EKS, Auto Scaling, Kubernetes event, workload, budget-preflight, and metadata records. This confirms the failure-evidence path works independently of a successful experiment phase.

## Root cause

The workload manifests correctly declared `metadata.namespace: optimization-evidence`, but the experiment bootstrap had no declarative Namespace object. Server-side dry-run therefore attempted to validate child resources against a missing parent namespace.

## Correction

A dedicated `infra/k8s/exp001/namespace.yaml` manifest now owns the namespace as source-controlled experiment scaffolding.

The runner creates that namespace before validating namespaced manifests and includes the namespace manifest in the same server-side preflight set.

The namespace is experiment scaffolding only. Creating it does not change worker capacity, workload resource requests, autoscaling behavior, or outcome classification.

## Claim boundary

This is an orchestration/preflight defect, not an optimization failure. No baseline, Arm A, Arm B, capacity realization, or financial realization is inferred from it.
