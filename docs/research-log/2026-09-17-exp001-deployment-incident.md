# 2026-09-17 EXP-001 first deployment incident

## Summary

The first live EXP-001 infrastructure deployment did not reach worker-node readiness. The EKS control plane and supporting resources were created, but the managed node group's Auto Scaling Group could not launch the configured `t3.medium` workers because the AWS account rejected that instance type as not Free Tier eligible.

The experiment was stopped before any workload phase ran. No baseline, Arm A, Arm B, capacity-realization, or savings result is claimed from this attempt.

## Timeline

All timestamps below are UTC and come from AWS resource events or Auto Scaling activity records.

- 15:54:37 — CloudFormation stack `optimization-evidence-exp001-lab` entered `CREATE_IN_PROGRESS`.
- 16:04:06 — EKS cluster `optimization-evidence-exp001` reached `CREATE_COMPLETE` / ACTIVE.
- 16:04:10 — managed node group creation started.
- 16:04:50 — first pair of worker launch attempts failed.
- 16:05:52 — repeated worker launch attempts failed with the same error.
- 16:07:55 — repeated worker launch attempts failed with the same error.
- after diagnosis — stack deletion was requested immediately to stop continued control-plane/resource burn while the source configuration was corrected.

## Failure

The Auto Scaling activity error was:

```text
InvalidParameterCombination - The specified instance type is not eligible for Free Tier. For a list of Free Tier instance types, run 'describe-instance-types' with the filter 'free-tier-eligible=true'.
```

The managed node group remained `CREATING`; its Auto Scaling Group had desired capacity 2 but zero instances.

This was not an EKS bootstrap, IAM, subnet, AMI, or Cluster Autoscaler discovery failure. The EC2 launch request itself was rejected before an instance existed.

## What the failed deployment still verified

The pre-deployment controls worked as intended:

- the exact merged Git commit was used as the infrastructure source;
- GitHub CI on the merged commit passed;
- CloudFormation `ValidateTemplate` succeeded;
- a fresh, non-executed change set reached `CREATE_COMPLETE` before execution;
- the reviewed change set contained 20 `Add` actions and no `Modify` or `Remove` actions.

AWS also verified one previously unproven runtime assumption. The EKS managed node group created Auto Scaling Group:

`eks-optimization-evidence-exp001-workers-80d0580e-36e8-0c4e-3102-83863f707e0d`

with the expected discovery tags:

```text
k8s.io/cluster-autoscaler/enabled=true
k8s.io/cluster-autoscaler/optimization-evidence-exp001=owned
kubernetes.io/cluster/optimization-evidence-exp001=owned
```

That means the Cluster Autoscaler discovery expression and the autoscaler IAM mutation conditions were aligned with the actual managed-node-group tags. This will still be verified again on the corrected deployment rather than assumed.

## Root cause

The design preflight verified EC2 pricing and EKS support, but it did not verify the account's **launch eligibility policy** for the selected worker type.

For this account, `t3.medium` is not currently launchable under the Free Tier restriction. A price catalog entry proves that a SKU exists and has a price; it does not prove that the current account is permitted to launch it.

That distinction is now part of the deployment gate.

## Corrective query

A fresh EC2 `DescribeInstanceTypes` call with `free-tier-eligible=true` returned exactly these six types in `us-east-1` at diagnosis time:

| Instance | vCPU | Memory | Architecture |
| --- | ---: | ---: | --- |
| t3.micro | 2 | 1 GiB | x86_64 |
| t4g.micro | 2 | 1 GiB | arm64 |
| t3.small | 2 | 2 GiB | x86_64 |
| t4g.small | 2 | 2 GiB | arm64 |
| c7i-flex.large | 2 | 4 GiB | x86_64 |
| m7i-flex.large | 2 | 8 GiB | x86_64 |

The corrected design selects `c7i-flex.large`: 2 vCPU, 4 GiB, x86_64. It preserves the intended worker memory/architecture envelope without introducing the 2-GiB memory-pressure variable of `t3.small` or the ARM64 variable of `t4g.*`.

AWS Price List verification at correction time returned USD 0.08479/hour for Linux On-Demand `c7i-flex.large` in `us-east-1`.

## Response and guardrail changes

1. Delete the failed experiment stack before attempting a replacement.
2. Verify no worker instances or EBS worker volumes were left behind.
3. Change the IaC source of truth; do not override the failed resource manually.
4. Update ADR-0003 and the EXP-001 cost model with the account constraint and corrected price.
5. Add instance launch eligibility to the pre-deployment gate.
6. Re-run CI and CloudFormation validation.
7. Create and inspect a fresh change set from the corrected merged commit.
8. Only then deploy again.

## Claim boundary

This deployment produced **no optimization result**.

It does not establish `OPERATIONALLY_VERIFIED`, `CAPACITY_REALIZED`, or `REALIZED`. It is a deployment incident and an additional piece of environment evidence.

The incident is retained because silently deleting failed attempts would weaken the auditability of the product and the later engineering article.
